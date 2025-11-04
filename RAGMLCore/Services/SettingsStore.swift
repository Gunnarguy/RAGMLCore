//
//  SettingsStore.swift
//  RAGMLCore
//
//  Centralized settings state and persistence.
//  Bridges SwiftUI bindings to UserDefaults-backed storage keys used across the app.
//  Debounces change notifications for downstream application (e.g., model switching).
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    // MARK: - Keys (mirror existing @AppStorage in SettingsRootView.swift)
    private enum Keys {
        static let selectedModel = "selectedLLMModel"          // LLMModelType.rawValue
        static let openaiAPIKey = "openaiAPIKey"
        static let openaiModel  = "openaiModel"
        static let preferPCC    = "preferPrivateCloudCompute"
        static let allowPCC     = "allowPrivateCloudCompute"
        static let execContext  = "executionContext"           // "automatic" | "onDeviceOnly" | "preferCloud" | "cloudOnly"
        static let temperature  = "llmTemperature"             // Double
        static let maxTokens    = "llmMaxTokens"               // Int
        static let topK         = "retrievalTopK"              // Int
        static let wifiOnly     = "modelsWiFiOnly"             // Bool
        static let lenient      = "lenientRetrievalMode"       // Bool
        static let enableFB1    = "enableFirstFallback"        // Bool
        static let enableFB2    = "enableSecondFallback"       // Bool
        static let firstFB      = "firstFallbackModel"         // LLMModelType.rawValue
        static let secondFB     = "secondFallbackModel"        // LLMModelType.rawValue

    // Responses API options
    static let responsesIncludeReasoning = "responsesIncludeReasoning"
    static let responsesIncludeVerbosity = "responsesIncludeVerbosity"
    static let responsesIncludeCoT       = "responsesIncludeCoT"
    static let responsesIncludeMaxTokens = "responsesIncludeMaxTokens"

        // macOS local providers
        static let mlxBaseURL   = "mlxBaseURL"
        static let mlxModel     = "mlxModel"
        static let mlxStream    = "mlxStream"
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

    @Published var modelsWiFiOnly: Bool
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

    #if os(macOS)
    @Published var mlxBaseURLString: String
    @Published var mlxModel: String
    @Published var mlxStream: Bool
    #endif

    // MARK: - Infra
    private let defaults: UserDefaults
    private let ragService: RAGService
    private let deviceCapabilities: DeviceCapabilities
    private var cancellables = Set<AnyCancellable>()
    private let applySubject = PassthroughSubject<Void, Never>()

    // MARK: - Model Availability
    var primaryModelOptions: [LLMModelType] {
        var options: [LLMModelType] = []

        if deviceCapabilities.supportsAppleIntelligence || deviceCapabilities.supportsFoundationModels {
            options.append(.appleIntelligence)
        }

        #if os(iOS)
        if #available(iOS 18.1, *), deviceCapabilities.supportsAppleIntelligence {
            options.append(.chatGPTExtension)
        }
        #endif

        options.append(.onDeviceAnalysis)

        #if os(iOS)
        if LlamaCPPiOSLLMService.runtimeAvailable {
            options.append(.ggufLocal)
        }
        #endif

        if deviceCapabilities.supportsCoreML {
            options.append(.coreMLLocal)
        }

        return options
    }

    func fallbackOptions(excluding disallowed: Set<LLMModelType>) -> [LLMModelType] {
        primaryModelOptions.filter { !disallowed.contains($0) }
    }

    // MARK: - Init
    init(defaults: UserDefaults = .standard, ragService: RAGService) {
        self.defaults = defaults
        self.ragService = ragService
        self.deviceCapabilities = RAGService.checkDeviceCapabilities()

        // Load persisted values with sensible defaults
        if let raw = defaults.string(forKey: Keys.selectedModel),
           let t = LLMModelType(rawValue: raw) {
            self.selectedModel = t
        } else {
            self.selectedModel = .appleIntelligence
        }

        self.openaiAPIKey = defaults.string(forKey: Keys.openaiAPIKey) ?? ""
        self.openaiModel  = defaults.string(forKey: Keys.openaiModel)  ?? "gpt-4o-mini"

        self.preferPrivateCloudCompute = defaults.bool(forKey: Keys.preferPCC)
        self.allowPrivateCloudCompute  = defaults.object(forKey: Keys.allowPCC) as? Bool ?? true

        let execRaw = defaults.string(forKey: Keys.execContext) ?? "automatic"
        self.executionContext = ExecutionContext.from(raw: execRaw)

        self.temperature = (defaults.object(forKey: Keys.temperature) as? Double) ?? 0.7
        self.maxTokens   = (defaults.object(forKey: Keys.maxTokens)   as? Int)    ?? 500
        self.topK        = (defaults.object(forKey: Keys.topK)        as? Int)    ?? 3

        self.modelsWiFiOnly      = defaults.object(forKey: Keys.wifiOnly) as? Bool ?? true
        self.lenientRetrievalMode = defaults.object(forKey: Keys.lenient) as? Bool ?? false

        self.enableFirstFallback  = defaults.object(forKey: Keys.enableFB1) as? Bool ?? true
        self.enableSecondFallback = defaults.object(forKey: Keys.enableFB2) as? Bool ?? true

        if let raw1 = defaults.string(forKey: Keys.firstFB),
           let t1 = LLMModelType(rawValue: raw1) {
            self.firstFallback = t1
        } else {
            self.firstFallback = .onDeviceAnalysis
        }

        if let raw2 = defaults.string(forKey: Keys.secondFB),
           let t2 = LLMModelType(rawValue: raw2) {
            self.secondFallback = t2
        } else {
            #if os(iOS)
            self.secondFallback = .chatGPTExtension
            #else
            self.secondFallback = .onDeviceAnalysis
            #endif
        }

        self.responsesIncludeReasoning = defaults.object(forKey: Keys.responsesIncludeReasoning) as? Bool ?? true
        self.responsesIncludeVerbosity = defaults.object(forKey: Keys.responsesIncludeVerbosity) as? Bool ?? true
        self.responsesIncludeCoT       = defaults.object(forKey: Keys.responsesIncludeCoT)       as? Bool ?? true
        self.responsesIncludeMaxTokens = defaults.object(forKey: Keys.responsesIncludeMaxTokens) as? Bool ?? true

        #if os(macOS)
        self.mlxBaseURLString = defaults.string(forKey: Keys.mlxBaseURL) ?? "http://127.0.0.1:17860"
        self.mlxModel         = defaults.string(forKey: Keys.mlxModel)   ?? "local-mlx-model"
        self.mlxStream        = defaults.object(forKey: Keys.mlxStream)  as? Bool ?? false
        #endif

        sanitizeModelSelectionForPlatform()
        setupPipelines()
    }

    // MARK: - Pipelines
    private func setupPipelines() {
        // Persist each setting change; coalesce downstream apply
        var publishers: [AnyPublisher<Void, Never>] = [
            $selectedModel.map { _ in () }.eraseToAnyPublisher(),
            $openaiAPIKey.map { _ in () }.eraseToAnyPublisher(),
            $openaiModel.map { _ in () }.eraseToAnyPublisher(),
            $preferPrivateCloudCompute.map { _ in () }.eraseToAnyPublisher(),
            $allowPrivateCloudCompute.map { _ in () }.eraseToAnyPublisher(),
            $executionContext.map { _ in () }.eraseToAnyPublisher(),
            $temperature.map { _ in () }.eraseToAnyPublisher(),
            $maxTokens.map { _ in () }.eraseToAnyPublisher(),
            $topK.map { _ in () }.eraseToAnyPublisher(),
            $modelsWiFiOnly.map { _ in () }.eraseToAnyPublisher(),
            $lenientRetrievalMode.map { _ in () }.eraseToAnyPublisher(),
            $enableFirstFallback.map { _ in () }.eraseToAnyPublisher(),
            $enableSecondFallback.map { _ in () }.eraseToAnyPublisher(),
            $firstFallback.map { _ in () }.eraseToAnyPublisher(),
            $secondFallback.map { _ in () }.eraseToAnyPublisher(),
            $responsesIncludeReasoning.map { _ in () }.eraseToAnyPublisher(),
            $responsesIncludeVerbosity.map { _ in () }.eraseToAnyPublisher(),
            $responsesIncludeCoT.map { _ in () }.eraseToAnyPublisher(),
            $responsesIncludeMaxTokens.map { _ in () }.eraseToAnyPublisher()
        ]
        #if os(macOS)
        publishers.append(contentsOf: [
            $mlxBaseURLString.map { _ in () }.eraseToAnyPublisher(),
            $mlxModel.map { _ in () }.eraseToAnyPublisher(),
            $mlxStream.map { _ in () }.eraseToAnyPublisher()
        ])
        #endif

        Publishers.MergeMany(publishers)
            .sink { [weak self] in
                guard let self else { return }
                self.persistAll()
                self.applySubject.send()
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
        defaults.set(allowPrivateCloudCompute,  forKey: Keys.allowPCC)
        defaults.set(executionContext.rawString, forKey: Keys.execContext)

        defaults.set(temperature, forKey: Keys.temperature)
        defaults.set(maxTokens,   forKey: Keys.maxTokens)
        defaults.set(topK,        forKey: Keys.topK)

        defaults.set(modelsWiFiOnly,       forKey: Keys.wifiOnly)
        defaults.set(lenientRetrievalMode, forKey: Keys.lenient)

        defaults.set(enableFirstFallback,  forKey: Keys.enableFB1)
        defaults.set(enableSecondFallback, forKey: Keys.enableFB2)
        defaults.set(firstFallback.rawValue,  forKey: Keys.firstFB)
        defaults.set(secondFallback.rawValue, forKey: Keys.secondFB)

    defaults.set(responsesIncludeReasoning, forKey: Keys.responsesIncludeReasoning)
    defaults.set(responsesIncludeVerbosity, forKey: Keys.responsesIncludeVerbosity)
    defaults.set(responsesIncludeCoT,       forKey: Keys.responsesIncludeCoT)
    defaults.set(responsesIncludeMaxTokens, forKey: Keys.responsesIncludeMaxTokens)

        #if os(macOS)
        defaults.set(mlxBaseURLString, forKey: Keys.mlxBaseURL)
        defaults.set(mlxModel,         forKey: Keys.mlxModel)
        defaults.set(mlxStream,        forKey: Keys.mlxStream)
        #endif
    }

    // MARK: - Side Effects (Debounced)
    private func applySettingsDebounced() {
        // Phase 1: Emit lightweight telemetry and return
    // Phase 2: Wire model switching here (extract shared logic from SettingsRootView)
        TelemetryCenter.emit(.system, title: "Settings changed", metadata: [
            "model": selectedModel.rawValue,
            "exec": executionContext.rawString,
            "openaiModel": openaiModel,
            "fallbacks": "\(enableFirstFallback ? "1" : "0")\(enableSecondFallback ? "+1" : "")"
        ])
    }
}

// MARK: - Platform Normalisation

private extension SettingsStore {
    /// Ensures persisted selections remain valid for the running platform.
    func sanitizeModelSelectionForPlatform() {
        let allowed = primaryModelOptions

        guard let firstAllowed = allowed.first else {
            selectedModel = .onDeviceAnalysis
            firstFallback = .onDeviceAnalysis
            secondFallback = .onDeviceAnalysis
            enableFirstFallback = false
            enableSecondFallback = false
            return
        }

        if !allowed.contains(selectedModel) {
            selectedModel = firstAllowed
        }

        let firstCandidates = allowed.filter { $0 != selectedModel }
        if !firstCandidates.contains(firstFallback) {
            if let candidate = firstCandidates.first {
                firstFallback = candidate
            } else {
                firstFallback = selectedModel
                enableFirstFallback = false
            }
        }

        if firstFallback == selectedModel {
            if let candidate = firstCandidates.first {
                firstFallback = candidate
            } else {
                enableFirstFallback = false
            }
        }

        let secondCandidates = firstCandidates.filter { $0 != firstFallback }
        if !secondCandidates.contains(secondFallback) {
            if let candidate = secondCandidates.first {
                secondFallback = candidate
            } else {
                enableSecondFallback = false
                if let reuse = firstCandidates.first {
                    secondFallback = reuse
                } else {
                    secondFallback = selectedModel
                }
            }
        }

        if secondFallback == selectedModel || secondFallback == firstFallback {
            if let candidate = secondCandidates.first {
                secondFallback = candidate
            } else {
                enableSecondFallback = false
            }
        }

        if !enableSecondFallback {
            if let candidate = secondCandidates.first {
                secondFallback = candidate
            }
        }
    }
}

// MARK: - ExecutionContext Raw Mapping

private extension ExecutionContext {
    var rawString: String {
        switch self {
        case .automatic:   return "automatic"
        case .onDeviceOnly:return "onDeviceOnly"
        case .preferCloud: return "preferCloud"
        case .cloudOnly:   return "cloudOnly"
        }
    }

    static func from(raw: String) -> ExecutionContext {
        switch raw {
        case "onDeviceOnly": return .onDeviceOnly
        case "preferCloud":  return .preferCloud
        case "cloudOnly":    return .cloudOnly
        default:             return .automatic
        }
    }
}
