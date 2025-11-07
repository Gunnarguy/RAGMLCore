//
//  SettingsStore.swift
//  RAGMLCore
//
//  Centralized settings state and persistence.
//  Bridges SwiftUI bindings to UserDefaults-backed storage keys used across the app.
//  Debounces change notifications for downstream application (e.g., model switching).
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    // MARK: - Keys (mirror existing @AppStorage in SettingsRootView.swift)
    private enum Keys {
        static let selectedModel = "selectedLLMModel"  // LLMModelType.rawValue
        static let openaiAPIKey = "openaiAPIKey"
        static let openaiModel = "openaiModel"
        static let preferPCC = "preferPrivateCloudCompute"
        static let allowPCC = "allowPrivateCloudCompute"
        static let execContext = "executionContext"  // "automatic" | "onDeviceOnly" | "preferCloud" | "cloudOnly"
        static let temperature = "llmTemperature"  // Double
        static let maxTokens = "llmMaxTokens"  // Int
        static let topK = "retrievalTopK"  // Int
        static let lenient = "lenientRetrievalMode"  // Bool
        static let enableFB1 = "enableFirstFallback"  // Bool
        static let enableFB2 = "enableSecondFallback"  // Bool
        static let firstFB = "firstFallbackModel"  // LLMModelType.rawValue
        static let secondFB = "secondFallbackModel"  // LLMModelType.rawValue
    static let primaryModelUserOverride = "primaryModelUserOverride"

        // Responses API options
        static let responsesIncludeReasoning = "responsesIncludeReasoning"
        static let responsesIncludeVerbosity = "responsesIncludeVerbosity"
        static let responsesIncludeCoT = "responsesIncludeCoT"
        static let responsesIncludeMaxTokens = "responsesIncludeMaxTokens"
    }

    // MARK: - Published Settings (bind from UI)
    @Published var selectedModel: LLMModelType
    @Published var openaiAPIKey: String
    @Published var openaiModel: String

    @Published var preferPrivateCloudCompute: Bool
    @Published var allowPrivateCloudCompute: Bool
    @Published var executionContext: ExecutionContext

    @Published var temperature: Double
    @Published var maxTokens: Int
    @Published var topK: Int

    @Published var lenientRetrievalMode: Bool

    @Published var enableFirstFallback: Bool
    @Published var enableSecondFallback: Bool
    @Published var firstFallback: LLMModelType
    @Published var secondFallback: LLMModelType

    // Responses API (OpenAI) options
    @Published var responsesIncludeReasoning: Bool
    @Published var responsesIncludeVerbosity: Bool
    @Published var responsesIncludeCoT: Bool
    @Published var responsesIncludeMaxTokens: Bool


    // MARK: - Infra
    private let defaults: UserDefaults
    private let ragService: RAGService
    private let deviceCapabilities: DeviceCapabilities
    private var cancellables = Set<AnyCancellable>()
    private let applySubject = PassthroughSubject<Void, Never>()
    private var hasUserPrimaryOverride: Bool
    private var isApplyingProgrammaticSelection = false

    // MARK: - Model Availability
    var primaryModelOptions: [LLMModelType] {
        var options: [LLMModelType] = []

        if deviceCapabilities.supportsAppleIntelligence
            || deviceCapabilities.supportsFoundationModels
        {
            options.append(.appleIntelligence)
        }


        #if os(iOS)
            // Include GGUF Local if runtime is available OR if a GGUF model is installed
            // This prevents the Picker from going blank when a model is activated
            if LlamaCPPiOSLLMService.runtimeAvailable
                || !ModelRegistry.shared.installed.filter({ $0.backend == .gguf }).isEmpty
            {
                options.append(.ggufLocal)
            }
        #endif

        if deviceCapabilities.supportsCoreML {
            #if os(iOS)
                let hasCoreMLCartridge = ModelRegistry.shared.installed.contains {
                    $0.backend == .coreML
                }
                if hasCoreMLCartridge || CoreMLLLMService.selectionIsReady() {
                    options.append(.coreMLLocal)
                }
            #else
                options.append(.coreMLLocal)
            #endif
        }

        if !options.contains(selectedModel) {
            options.append(selectedModel)
        }

        return options
    }

    private var fallbackBaseOptions: [LLMModelType] {
        var ordered: [LLMModelType] = []
        var seen = Set<LLMModelType>()

        func append(_ type: LLMModelType) {
            guard !seen.contains(type) else { return }
            seen.insert(type)
            ordered.append(type)
        }

        primaryModelOptions.forEach { append($0) }
        append(.onDeviceAnalysis)

        #if os(iOS)
            if deviceCapabilities.supportsAppleIntelligence {
                append(.chatGPTExtension)
            }
        #else
            if deviceCapabilities.supportsAppleIntelligence {
                append(.chatGPTExtension)
            }
        #endif

        #if os(macOS)
            append(.openAIDirect)
        #endif

        return ordered
    }

    func fallbackOptions(excluding disallowed: Set<LLMModelType>) -> [LLMModelType] {
        var ordered: [LLMModelType] = []
        var seen = Set<LLMModelType>()

        func appendIfNeeded(_ type: LLMModelType) {
            guard !disallowed.contains(type), !seen.contains(type) else { return }
            seen.insert(type)
            ordered.append(type)
        }

        fallbackBaseOptions.forEach { appendIfNeeded($0) }
        appendIfNeeded(firstFallback)
        appendIfNeeded(secondFallback)

        return ordered
    }

    private func setSelectedModelProgrammatically(_ newValue: LLMModelType) {
        guard selectedModel != newValue else { return }
        isApplyingProgrammaticSelection = true
        selectedModel = newValue
        isApplyingProgrammaticSelection = false
    }

    private func isPrimarySelectionAvailable(_ selection: LLMModelType) -> Bool {
        switch selection {
        case .appleIntelligence:
            return deviceCapabilities.supportsAppleIntelligence
                || deviceCapabilities.supportsFoundationModels
        case .ggufLocal:
            #if os(iOS)
                let hasInstalledGGUF = ModelRegistry.shared.installed.contains { $0.backend == .gguf }
                return LlamaCPPiOSLLMService.runtimeAvailable && hasInstalledGGUF
            #else
                return false
            #endif
        case .coreMLLocal:
            guard deviceCapabilities.supportsCoreML else { return false }
            #if os(iOS)
                let hasCoreMLCartridge = ModelRegistry.shared.installed.contains { $0.backend == .coreML }
                return hasCoreMLCartridge || CoreMLLLMService.selectionIsReady()
            #else
                return true
            #endif
        case .chatGPTExtension:
            #if os(iOS)
                return deviceCapabilities.supportsAppleIntelligence
            #else
                return false
            #endif
        case .onDeviceAnalysis:
            return true
        default:
            return true
        }
    }

    // MARK: - Init
    init(defaults: UserDefaults = .standard, ragService: RAGService) {
        self.defaults = defaults
        self.ragService = ragService
        self.deviceCapabilities = RAGService.checkDeviceCapabilities()

        // Load persisted values with sensible defaults
        if let raw = defaults.string(forKey: Keys.selectedModel),
            let t = LLMModelType(rawValue: raw)
        {
            self.selectedModel = t
        } else {
            self.selectedModel = .appleIntelligence
        }

        self.openaiAPIKey = defaults.string(forKey: Keys.openaiAPIKey) ?? ""
        self.openaiModel = defaults.string(forKey: Keys.openaiModel) ?? "gpt-4o-mini"

        self.preferPrivateCloudCompute = defaults.bool(forKey: Keys.preferPCC)
        self.allowPrivateCloudCompute = defaults.object(forKey: Keys.allowPCC) as? Bool ?? true

        let execRaw = defaults.string(forKey: Keys.execContext) ?? "automatic"
        self.executionContext = ExecutionContext.from(raw: execRaw)

        self.temperature = (defaults.object(forKey: Keys.temperature) as? Double) ?? 0.7
        self.maxTokens = (defaults.object(forKey: Keys.maxTokens) as? Int) ?? 500
        self.topK = (defaults.object(forKey: Keys.topK) as? Int) ?? 3

        self.lenientRetrievalMode = defaults.object(forKey: Keys.lenient) as? Bool ?? false

        self.enableFirstFallback = defaults.object(forKey: Keys.enableFB1) as? Bool ?? true
        self.enableSecondFallback = defaults.object(forKey: Keys.enableFB2) as? Bool ?? true

        if let raw1 = defaults.string(forKey: Keys.firstFB),
            let t1 = LLMModelType(rawValue: raw1)
        {
            self.firstFallback = t1
        } else {
            self.firstFallback = .onDeviceAnalysis
        }

        if let raw2 = defaults.string(forKey: Keys.secondFB),
            let t2 = LLMModelType(rawValue: raw2)
        {
            self.secondFallback = t2
        } else {
            #if os(iOS)
                self.secondFallback = .chatGPTExtension
            #else
                self.secondFallback = .onDeviceAnalysis
            #endif
        }

        self.responsesIncludeReasoning =
            defaults.object(forKey: Keys.responsesIncludeReasoning) as? Bool ?? true
        self.responsesIncludeVerbosity =
            defaults.object(forKey: Keys.responsesIncludeVerbosity) as? Bool ?? true
        self.responsesIncludeCoT =
            defaults.object(forKey: Keys.responsesIncludeCoT) as? Bool ?? true
        self.responsesIncludeMaxTokens =
            defaults.object(forKey: Keys.responsesIncludeMaxTokens) as? Bool ?? true
        self.hasUserPrimaryOverride =
            defaults.object(forKey: Keys.primaryModelUserOverride) as? Bool ?? false

        if selectedModel == .ggufLocal,
            !hasUserPrimaryOverride,
            isPrimarySelectionAvailable(.appleIntelligence)
        {
            setSelectedModelProgrammatically(.appleIntelligence)
        }
        sanitizeModelSelectionForPlatform()
        setupPipelines()
    }

    // MARK: - Pipelines
    private func setupPipelines() {
        $selectedModel
            .sink { [weak self] _ in
                guard let self else { return }
                if self.isApplyingProgrammaticSelection { return }
                if !self.hasUserPrimaryOverride {
                    self.hasUserPrimaryOverride = true
                    self.defaults.set(true, forKey: Keys.primaryModelUserOverride)
                }
            }
            .store(in: &cancellables)

        // Persist each setting change; coalesce downstream apply
        let publishers: [AnyPublisher<Void, Never>] = [
            $selectedModel.map { _ in () }.eraseToAnyPublisher(),
            $openaiAPIKey.map { _ in () }.eraseToAnyPublisher(),
            $openaiModel.map { _ in () }.eraseToAnyPublisher(),
            $preferPrivateCloudCompute.map { _ in () }.eraseToAnyPublisher(),
            $allowPrivateCloudCompute.map { _ in () }.eraseToAnyPublisher(),
            $executionContext.map { _ in () }.eraseToAnyPublisher(),
            $temperature.map { _ in () }.eraseToAnyPublisher(),
            $maxTokens.map { _ in () }.eraseToAnyPublisher(),
            $topK.map { _ in () }.eraseToAnyPublisher(),
            $lenientRetrievalMode.map { _ in () }.eraseToAnyPublisher(),
            $enableFirstFallback.map { _ in () }.eraseToAnyPublisher(),
            $enableSecondFallback.map { _ in () }.eraseToAnyPublisher(),
            $firstFallback.map { _ in () }.eraseToAnyPublisher(),
            $secondFallback.map { _ in () }.eraseToAnyPublisher(),
            $responsesIncludeReasoning.map { _ in () }.eraseToAnyPublisher(),
            $responsesIncludeVerbosity.map { _ in () }.eraseToAnyPublisher(),
            $responsesIncludeCoT.map { _ in () }.eraseToAnyPublisher(),
            $responsesIncludeMaxTokens.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(publishers)
            .sink { [weak self] in
                guard let self else { return }
                self.persistAll()
                self.applySubject.send()
            }
            .store(in: &cancellables)

        // Observe ModelRegistry changes to refresh available model options
        ModelRegistry.shared.$installed
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
                self.sanitizeModelSelectionForPlatform()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .installedModelAutoSelected)
            .compactMap { notification -> ModelBackend? in
                guard
                    let raw = notification.userInfo?[ModelAutoSelectionPayload.backend] as? String,
                    let backend = ModelBackend(rawValue: raw)
                else { return nil }
                return backend
            }
            .sink { [weak self] backend in
                guard let self else { return }
                self.applyAutoSelectionIfEligible(for: backend)
            }
            .store(in: &cancellables)

        // Debounced apply (lightweight for now; can be expanded to actually swap services)
        applySubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.applySettingsDebounced()
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence
    private func persistAll() {
        defaults.set(selectedModel.rawValue, forKey: Keys.selectedModel)
        defaults.set(openaiAPIKey, forKey: Keys.openaiAPIKey)
        defaults.set(openaiModel, forKey: Keys.openaiModel)

        defaults.set(preferPrivateCloudCompute, forKey: Keys.preferPCC)
        defaults.set(allowPrivateCloudCompute, forKey: Keys.allowPCC)
        defaults.set(executionContext.rawString, forKey: Keys.execContext)

        defaults.set(temperature, forKey: Keys.temperature)
        defaults.set(maxTokens, forKey: Keys.maxTokens)
        defaults.set(topK, forKey: Keys.topK)

        defaults.set(lenientRetrievalMode, forKey: Keys.lenient)

        defaults.set(enableFirstFallback, forKey: Keys.enableFB1)
        defaults.set(enableSecondFallback, forKey: Keys.enableFB2)
        defaults.set(firstFallback.rawValue, forKey: Keys.firstFB)
        defaults.set(secondFallback.rawValue, forKey: Keys.secondFB)

        defaults.set(responsesIncludeReasoning, forKey: Keys.responsesIncludeReasoning)
        defaults.set(responsesIncludeVerbosity, forKey: Keys.responsesIncludeVerbosity)
        defaults.set(responsesIncludeCoT, forKey: Keys.responsesIncludeCoT)
        defaults.set(responsesIncludeMaxTokens, forKey: Keys.responsesIncludeMaxTokens)
        defaults.set(hasUserPrimaryOverride, forKey: Keys.primaryModelUserOverride)
    }

    // MARK: - Side Effects (Debounced)
    private func applySettingsDebounced() {
        // Phase 1: Emit lightweight telemetry and return
        // Phase 2: Wire model switching here (extract shared logic from SettingsRootView)
        TelemetryCenter.emit(
            .system, title: "Settings changed",
            metadata: [
                "model": selectedModel.rawValue,
                "exec": executionContext.rawString,
                "openaiModel": openaiModel,
                "fallbacks":
                    "\(enableFirstFallback ? "1" : "0")\(enableSecondFallback ? "+1" : "")",
            ])
    }
}

// MARK: - Platform Normalisation

extension SettingsStore {
    /// Ensures persisted selections remain valid for the running platform.
    fileprivate func sanitizeModelSelectionForPlatform() {
        let primaryOptions = primaryModelOptions
        let fallbackUniverse = fallbackBaseOptions

        if primaryOptions.isEmpty {
            setSelectedModelProgrammatically(fallbackUniverse.first ?? .onDeviceAnalysis)
        } else if !isPrimarySelectionAvailable(selectedModel) {
            if let firstValid = primaryOptions.first(where: { isPrimarySelectionAvailable($0) }) {
                setSelectedModelProgrammatically(firstValid)
            } else {
                setSelectedModelProgrammatically(fallbackUniverse.first ?? .onDeviceAnalysis)
            }
        } else if !hasUserPrimaryOverride,
            selectedModel != .appleIntelligence,
            isPrimarySelectionAvailable(.appleIntelligence)
        {
            setSelectedModelProgrammatically(.appleIntelligence)
        }

        let firstCandidates = fallbackUniverse.filter { $0 != selectedModel }
        if firstCandidates.isEmpty {
            firstFallback = selectedModel
            enableFirstFallback = false
        } else if !firstCandidates.contains(firstFallback) {
            firstFallback = firstCandidates.first!
        }

        let secondCandidates = fallbackUniverse.filter { $0 != selectedModel && $0 != firstFallback }
        if secondCandidates.isEmpty {
            secondFallback = firstFallback
            enableSecondFallback = false
        } else if !secondCandidates.contains(secondFallback) {
            secondFallback = secondCandidates.first!
        }
    }

    /// Aligns UI selection with auto-selected cartridges when the user has not made an explicit override.
    private func applyAutoSelectionIfEligible(for backend: ModelBackend) {
        if isPrimarySelectionAvailable(selectedModel) {
            return
        }
        if hasUserPrimaryOverride {
            return
        }
        switch backend {
        case .gguf:
            guard selectedModel != .ggufLocal else { return }
            guard primaryModelOptions.contains(.ggufLocal) else { return }
            let autoEligible: Set<LLMModelType> = [.appleIntelligence, .onDeviceAnalysis]
            guard autoEligible.contains(selectedModel) else { return }
            setSelectedModelProgrammatically(.ggufLocal)
            AutoTuneService.tuneForSelection(selectedModel: .ggufLocal)
        case .coreML:
            guard selectedModel != .coreMLLocal else { return }
            guard primaryModelOptions.contains(.coreMLLocal) else { return }
            let autoEligible: Set<LLMModelType> = [.appleIntelligence, .onDeviceAnalysis]
            guard autoEligible.contains(selectedModel) else { return }
            setSelectedModelProgrammatically(.coreMLLocal)
            AutoTuneService.tuneForSelection(selectedModel: .coreMLLocal)
        case .mlxServer:
            Log.info("Ignoring auto-selection for legacy MLX server", category: .llm)
        }
    }
}

// MARK: - ExecutionContext Raw Mapping

extension ExecutionContext {
    fileprivate var rawString: String {
        switch self {
        case .automatic: return "automatic"
        case .onDeviceOnly: return "onDeviceOnly"
        case .preferCloud: return "preferCloud"
        case .cloudOnly: return "cloudOnly"
        }
    }

    fileprivate static func from(raw: String) -> ExecutionContext {
        switch raw {
        case "onDeviceOnly": return .onDeviceOnly
        case "preferCloud": return .preferCloud
        case "cloudOnly": return .cloudOnly
        default: return .automatic
        }
    }
}
