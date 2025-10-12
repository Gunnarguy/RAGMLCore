//
//  SettingsView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/10/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var ragService: RAGService
    @AppStorage("selectedLLMModel") private var selectedModel: LLMModelType = .appleIntelligence {
        didSet {
            // Auto-apply when model changes (use Task for async call)
            Task {
                await applySettings()
            }
        }
    }
    @AppStorage("openaiAPIKey") private var openaiAPIKey: String = ""
    @AppStorage("openaiModel") private var openaiModel: String = "gpt-4o-mini"
    @AppStorage("preferPrivateCloudCompute") private var preferPrivateCloudCompute: Bool = false
    @AppStorage("allowPrivateCloudCompute") private var allowPrivateCloudCompute: Bool = true
    @AppStorage("executionContext") private var executionContextRaw: String = "automatic"
    @AppStorage("llmTemperature") private var temperature: Double = 0.7
    @AppStorage("llmMaxTokens") private var maxTokens: Int = 500
    @AppStorage("retrievalTopK") private var topK: Int = 3
    @AppStorage("enableFirstFallback") private var enableFirstFallback: Bool = true
    @AppStorage("enableSecondFallback") private var enableSecondFallback: Bool = true
    @AppStorage("firstFallbackModel") private var firstFallbackRaw: String = LLMModelType.onDeviceAnalysis.rawValue
    @AppStorage("secondFallbackModel") private var secondFallbackRaw: String = LLMModelType.openAIDirect.rawValue
    
    @State private var showingAPIKeyInfo = false
    @State private var isApplyingSettings = false
    @State private var deviceCapabilities = DeviceCapabilities()
    @State private var pipelineStages: [ModelPipelineStage] = []
    
    private var executionContext: ExecutionContext {
        get {
            switch executionContextRaw {
            case "automatic": return .automatic
            case "onDeviceOnly": return .onDeviceOnly
            case "preferCloud": return .preferCloud
            case "cloudOnly": return .cloudOnly
            default: return .automatic
            }
        }
        set {
            switch newValue {
            case .automatic: executionContextRaw = "automatic"
            case .onDeviceOnly: executionContextRaw = "onDeviceOnly"
            case .preferCloud: executionContextRaw = "preferCloud"
            case .cloudOnly: executionContextRaw = "cloudOnly"
            }
        }
    }

    private var firstFallback: LLMModelType {
        get { LLMModelType(rawValue: firstFallbackRaw) ?? .onDeviceAnalysis }
        set { firstFallbackRaw = newValue.rawValue }
    }
    
    private var secondFallback: LLMModelType {
        get { LLMModelType(rawValue: secondFallbackRaw) ?? .openAIDirect }
        set { secondFallbackRaw = newValue.rawValue }
    }
    
    private var firstFallbackOptions: [LLMModelType] {
        LLMModelType.allCases.filter { $0 != selectedModel }
    }
    
    private var secondFallbackOptions: [LLMModelType] {
        LLMModelType.allCases.filter { $0 != selectedModel && $0 != firstFallback }
    }
    
    private var firstFallbackBinding: Binding<LLMModelType> {
        Binding(
            get: { self.firstFallback },
            set: { self.firstFallbackRaw = $0.rawValue }
        )
    }
    
    private var secondFallbackBinding: Binding<LLMModelType> {
        Binding(
            get: { self.secondFallback },
            set: { self.secondFallbackRaw = $0.rawValue }
        )
    }
    
    var body: some View {
        Form {
                // MARK: - AI Model Selection
                Section {
                    Picker("AI Model", selection: $selectedModel) {
                        // Always provide Apple Intelligence tag (conditional label only)
                        if deviceCapabilities.supportsFoundationModels {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Apple Foundation Models")
                                    Text("iOS 26+ on-device + cloud")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "brain.head.profile")
                            }
                            .tag(LLMModelType.appleIntelligence)
                        } else if deviceCapabilities.supportsAppleIntelligence {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Apple Intelligence")
                                    Text("Auto on-device/cloud - zero data retention")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "sparkles")
                            }
                            .tag(LLMModelType.appleIntelligence)
                        } else {
                            // Fallback: Always provide tag even when unavailable (for default selection)
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Apple Intelligence")
                                    Text("Checking availability...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "sparkles.rectangle.stack")
                            }
                            .tag(LLMModelType.appleIntelligence)
                        }
                        
                        Label {
                            VStack(alignment: .leading) {
                                Text("OpenAI Direct")
                                Text("Your own API key")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "key.fill")
                        }
                        .tag(LLMModelType.openAIDirect)
                        
                        Label {
                            VStack(alignment: .leading) {
                                Text("On-Device Analysis")
                                Text("No AI model needed - extractive QA")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        .tag(LLMModelType.onDeviceAnalysis)
                    }
                    .pickerStyle(.navigationLink)
                    
                    // Model details
                    ModelInfoCard(modelType: selectedModel, capabilities: deviceCapabilities)
                    
                } header: {
                    Text("AI Model")
                } footer: {
                    Text(modelFooterText)
                }
                
                Section {
                    Toggle("Enable First Fallback", isOn: $enableFirstFallback)
                    if enableFirstFallback {
                        Picker("First Fallback", selection: firstFallbackBinding) {
                            ForEach(firstFallbackOptions, id: \.self) { option in
                                Label(option.displayName, systemImage: option.iconName)
                                    .tag(option)
                            }
                        }
                    }
                    Toggle("Enable Second Fallback", isOn: $enableSecondFallback)
                    if enableSecondFallback {
                        Picker("Second Fallback", selection: secondFallbackBinding) {
                            ForEach(secondFallbackOptions, id: \.self) { option in
                                Label(option.displayName, systemImage: option.iconName)
                                    .tag(option)
                            }
                        }
                    }
                } header: {
                    Text("Fallback Strategy")
                } footer: {
                    Text("Customize the order of model fallbacks. Disabled stages are skipped unless all other stages fail, in which case the app uses on-device analysis to stay responsive.")
                
                // MARK: - Private Cloud Compute Settings (iOS 18.1+)
                if deviceCapabilities.supportsPrivateCloudCompute && 
                   (selectedModel == .appleIntelligence || deviceCapabilities.supportsFoundationModels) {
                    Section {
                        // Master toggle for PCC permission
                        Toggle(isOn: $allowPrivateCloudCompute) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Allow Private Cloud Compute")
                                    Image(systemName: allowPrivateCloudCompute ? "checkmark.shield.fill" : "xmark.shield.fill")
                                        .foregroundColor(allowPrivateCloudCompute ? .green : .orange)
                                        .font(.caption)
                                }
                                Text("Permission to use Apple's secure cloud servers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if allowPrivateCloudCompute {
                            // Granular execution context control
                            Picker("Execution Strategy", selection: Binding<ExecutionContext>(
                                get: { executionContext },
                                set: { newValue in
                                    switch newValue {
                                    case .automatic: executionContextRaw = "automatic"
                                    case .onDeviceOnly: executionContextRaw = "onDeviceOnly"
                                    case .preferCloud: executionContextRaw = "preferCloud"
                                    case .cloudOnly: executionContextRaw = "cloudOnly"
                                    }
                                    Task { await applySettings() }
                                }
                            )) {
                                ForEach([ExecutionContext.automatic, .onDeviceOnly, .preferCloud, .cloudOnly], id: \.self) { context in
                                    HStack {
                                        Text(context.emoji)
                                        Text(context.description)
                                    }
                                    .tag(context)
                                }
                            }
                            .pickerStyle(.navigationLink)
                            
                            // Explain current setting
                            switch executionContext {
                            case .automatic:
                                InfoRow(
                                    icon: "🔄",
                                    title: "Automatic (Recommended)",
                                    description: "System decides: on-device for simple queries, cloud for complex ones"
                                )
                            case .onDeviceOnly:
                                InfoRow(
                                    icon: "📱",
                                    title: "On-Device Only",
                                    description: "Never uses cloud. Complex queries may fail or return lower quality."
                                )
                            case .preferCloud:
                                InfoRow(
                                    icon: "☁️",
                                    title: "Prefer Cloud",
                                    description: "Uses PCC when possible for better quality. Falls back to on-device if offline."
                                )
                            case .cloudOnly:
                                InfoRow(
                                    icon: "🌐",
                                    title: "Cloud Only",
                                    description: "Always uses PCC. Requires internet connection."
                                )
                            }
                        }
                        
                    } header: {
                        HStack {
                            Image(systemName: "cloud.fill")
                            Text("Execution Location")
                        }
                    } footer: {
                        if allowPrivateCloudCompute {
                            Text("Private Cloud Compute runs on Apple Silicon servers with cryptographically enforced zero data retention. Your data is never stored, logged, or accessible to Apple.")
                        } else {
                            Text("All processing happens on-device. Complex queries may take longer or return lower quality responses.")
                        }
                    }
                }
                
                // MARK: - OpenAI Settings (if selected)
                if selectedModel == .openAIDirect {
                    Section {
                        HStack {
                            TextField("API Key", text: $openaiAPIKey)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                            
                            Button {
                                showingAPIKeyInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        Picker("Model", selection: $openaiModel) {
                            Text("GPT-5 (Latest)").tag("gpt-5")
                            Text("o1 (Reasoning)").tag("o1")
                            Text("o1-mini (Fast Reasoning)").tag("o1-mini")
                            Text("GPT-4o (Balanced)").tag("gpt-4o")
                            Text("GPT-4o Mini (Fast)").tag("gpt-4o-mini")
                            Text("GPT-4 Turbo").tag("gpt-4-turbo-preview")
                        }
                        
                    } header: {
                        Text("OpenAI Configuration")
                    } footer: {
                        if openaiAPIKey.isEmpty {
                            Text("⚠️ API key required. Get one at platform.openai.com")
                                .foregroundColor(.orange)
                        } else {
                            Text("✓ API key configured")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // MARK: - LLM Parameters
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.2f", temperature))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $temperature, in: 0...1, step: 0.1)
                    }
                    
                    Stepper("Max Tokens: \(maxTokens)", value: $maxTokens, in: 100...2000, step: 100)
                    
                } header: {
                    Text("Generation Parameters")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature: Lower = more focused, Higher = more creative")
                        Text("Max Tokens: Maximum response length")
                    }
                    .font(.caption)
                }
                
                // MARK: - RAG Settings
                Section {
                    Stepper("Retrieved Chunks: \(topK)", value: $topK, in: 1...10)
                    
                } header: {
                    Text("Retrieval Settings")
                } footer: {
                    Text("Number of document chunks to retrieve for each query")
                }
                
                // MARK: - Apply Button
                Section {
                    Button {
                        Task {
                            await applySettings()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isApplyingSettings {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Apply Settings")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isApplyingSettings || (selectedModel == .openAIDirect && openaiAPIKey.isEmpty))
                }
                
                // MARK: - Current Status
                Section {
                    LabeledContent("Active Model", value: ragService.llmService.modelName)
                    LabeledContent("Documents", value: "\(ragService.documents.count)")
                    LabeledContent("Total Chunks", value: "\(ragService.totalChunksStored)")
                    
                } header: {
                    Text("Current Status")
                }
                
                // MARK: - About
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About RAGMLCore", systemImage: "info.circle")
                    }
                    
                    Link(destination: URL(string: "https://www.apple.com/apple-intelligence/")!) {
                        Label("Learn About Apple Intelligence", systemImage: "apple.logo")
                    }
                    
                } header: {
                    Text("Information")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Check device capabilities and refresh pipeline
                // Perform capability check asynchronously to avoid blocking UI
                Task {
                    let caps = RAGService.checkDeviceCapabilities()
                    await MainActor.run {
                        deviceCapabilities = caps
                        refreshModelPipeline()
                    }
                }
            }
            .onChange(of: selectedModel) {
                refreshModelPipeline()
            }
            .onChange(of: openaiAPIKey) {
                refreshModelPipeline()
            }
            .onChange(of: openaiModel) {
                refreshModelPipeline()
            }
            .onChange(of: enableFirstFallback) {
                refreshModelPipeline()
                Task { await applySettings() }
            }
            .onChange(of: enableSecondFallback) {
                refreshModelPipeline()
                Task { await applySettings() }
            }
            .onChange(of: firstFallbackRaw) {
                refreshModelPipeline()
                Task { await applySettings() }
            }
            .onChange(of: secondFallbackRaw) {
                refreshModelPipeline()
                Task { await applySettings() }
            }
            .alert("OpenAI API Key", isPresented: $showingAPIKeyInfo) {
                Button("Get API Key") {
                    if let url = URL(string: "https://platform.openai.com/api-keys") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("You'll need an OpenAI API key to use OpenAI Direct. Sign up at platform.openai.com to get one. The API is pay-as-you-go.")
            }
        } // Form
    } // body
    
    private var modelFooterText: String {
        switch selectedModel {
        case .appleIntelligence:
            return "Primary: Apple Foundation Models when available. Automatic fallback to On-Device Analysis keeps responses working even if Apple Intelligence is unavailable."
        case .onDeviceAnalysis:
            return "Extracts relevant sentences from your documents using NaturalLanguage framework. No AI model needed, works on all devices, 100% private."
        case .openAIDirect:
            return "Primary: OpenAI GPT models using your key. If the API is unavailable, we fall back to On-Device Analysis so the chat never goes silent."
        }
    }
    
    @MainActor
    private func applySettings() async {
        guard !isApplyingSettings else { return }
        isApplyingSettings = true
        defer { isApplyingSettings = false }
        let newService = buildLLMService()
        await ragService.updateLLMService(newService)
        refreshModelPipeline()
    }

    private func normalizeFallbacks() {
        if !firstFallbackOptions.contains(firstFallback) {
            firstFallbackRaw = (firstFallbackOptions.first ?? .onDeviceAnalysis).rawValue
        }
        if !secondFallbackOptions.contains(secondFallback) {
            secondFallbackRaw = (secondFallbackOptions.first ?? .onDeviceAnalysis).rawValue
        }
    }

    private func buildLLMService() -> any LLMService {
        normalizeFallbacks()
        let preferences = preferredModelPreferences()
        for preference in preferences where preference.enabled {
            if let service = instantiateService(for: preference.type) {
                return service
            }
        }
        return OnDeviceAnalysisService()
    }

    @MainActor
    private func refreshModelPipeline() {
        normalizeFallbacks()
        let preferences = preferredModelPreferences()
        var stages: [ModelPipelineStage] = []
        for (index, preference) in preferences.enumerated() {
            let role: ModelPipelineStage.Role = index == 0 ? .primary : (preference.userSelected ? .fallback : .optional)
            switch preference.type {
            case .appleIntelligence:
                stages.append(makeFoundationStage(role: role, isEnabled: preference.enabled))
            case .onDeviceAnalysis:
                stages.append(makeOnDeviceStage(role: role, isEnabled: preference.enabled))
            case .openAIDirect:
                stages.append(makeOpenAIStage(role: role, isEnabled: preference.enabled))
            }
        }
        pipelineStages = stages
    }

    private func preferredModelPreferences() -> [(type: LLMModelType, enabled: Bool, userSelected: Bool)] {
        var seen = Set<LLMModelType>()
        var preferences: [(LLMModelType, Bool, Bool)] = []
        let primary = (selectedModel, true, true)
        let first = (firstFallback, enableFirstFallback, true)
        let second = (secondFallback, enableSecondFallback, true)
        for entry in [primary, first, second] {
            if !seen.contains(entry.0) {
                preferences.append(entry)
                seen.insert(entry.0)
            }
        }
        let safetyStages: [LLMModelType] = [.onDeviceAnalysis, .appleIntelligence, .openAIDirect]
        for type in safetyStages where !seen.contains(type) {
            preferences.append((type, false, false))
            seen.insert(type)
        }
        return preferences
    }

    private func instantiateService(for type: LLMModelType) -> LLMService? {
        switch type {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let service = AppleFoundationLLMService()
                return service.isAvailable ? service : nil
            }
            #endif
            return nil
        case .onDeviceAnalysis:
            return OnDeviceAnalysisService()
        case .openAIDirect:
            let trimmedKey = openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKey.isEmpty else { return nil }
            return OpenAILLMService(apiKey: trimmedKey, model: openaiModel)
        }
    }

    private func makeFoundationStage(role: ModelPipelineStage.Role, isEnabled: Bool) -> ModelPipelineStage {
        let detail = "On-device Apple Intelligence with Private Cloud Compute"
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let isActive = ragService.llmService is AppleFoundationLLMService
            if isActive {
                return ModelPipelineStage(name: "Apple Foundation Models", role: role, detail: detail, status: .active, icon: "brain.head.profile")
            }
            if !isEnabled {
                return ModelPipelineStage(name: "Apple Foundation Models", role: role, detail: detail, status: .disabled, icon: "brain.head.profile")
            }
            if deviceCapabilities.supportsFoundationModels {
                return ModelPipelineStage(name: "Apple Foundation Models", role: role, detail: detail, status: .available, icon: "brain.head.profile")
            }
            let reason = deviceCapabilities.foundationModelUnavailableReason ?? "Requires supported hardware and iOS 26"
            return ModelPipelineStage(name: "Apple Foundation Models", role: role, detail: detail, status: .unavailable(reason: reason), icon: "brain.head.profile")
        }
        return ModelPipelineStage(name: "Apple Foundation Models", role: role, detail: detail, status: isEnabled ? .unavailable(reason: "Requires iOS 26") : .disabled, icon: "brain.head.profile")
        #else
        // When building without iOS 26 SDK, check if Apple Intelligence is available (iOS 18.1+)
        if !isEnabled {
            return ModelPipelineStage(name: "Apple Intelligence", role: role, detail: detail, status: .disabled, icon: "brain.head.profile")
        }
        if deviceCapabilities.supportsAppleIntelligence {
            // Apple Intelligence available on iOS 18.1+ with A17 Pro+/M-series
            let name = "Apple Intelligence"
            let status: ModelPipelineStage.Status = .requiresConfiguration(detail: "Requires iOS 26 SDK for Foundation Models. Using system Apple Intelligence APIs.")
            return ModelPipelineStage(name: name, role: role, detail: "Private Cloud Compute + Writing Tools + ChatGPT", status: status, icon: "brain.head.profile")
        } else if let reason = deviceCapabilities.appleIntelligenceUnavailableReason {
            return ModelPipelineStage(name: "Apple Intelligence", role: role, detail: detail, status: .unavailable(reason: reason), icon: "brain.head.profile")
        }
        return ModelPipelineStage(name: "Apple Intelligence", role: role, detail: detail, status: .unavailable(reason: "Build with iOS 26 SDK to enable Foundation Models"), icon: "brain.head.profile")
        #endif
    }

    private func makeOnDeviceStage(role: ModelPipelineStage.Role, isEnabled: Bool) -> ModelPipelineStage {
        let isActive = ragService.llmService is OnDeviceAnalysisService
        if isActive {
            return ModelPipelineStage(name: "On-Device Analysis", role: role, detail: "Runs entirely on-device using NaturalLanguage", status: .active, icon: "doc.text.magnifyingglass")
        }
        if !isEnabled {
            return ModelPipelineStage(name: "On-Device Analysis", role: role, detail: "Runs entirely on-device using NaturalLanguage", status: .disabled, icon: "doc.text.magnifyingglass")
        }
        let detail = role == .primary ? "Runs entirely on-device using NaturalLanguage" : "Fallback extractive QA when generative models are unavailable"
        return ModelPipelineStage(name: "On-Device Analysis", role: role, detail: detail, status: .available, icon: "doc.text.magnifyingglass")
    }

    private func makeOpenAIStage(role: ModelPipelineStage.Role, isEnabled: Bool) -> ModelPipelineStage {
        let trimmedKey = openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let isActive = ragService.llmService is OpenAILLMService
        if isActive {
            return ModelPipelineStage(
                name: "OpenAI Direct",
                role: role,
                detail: "Currently configured for \(openaiModel)",
                status: .active,
                icon: "key.fill"
            )
        }
        if !isEnabled {
            return ModelPipelineStage(
                name: "OpenAI Direct",
                role: role,
                detail: "Connect to GPT-4/5 using your API key",
                status: .disabled,
                icon: "key.fill"
            )
        }
        if trimmedKey.isEmpty {
            return ModelPipelineStage(
                name: "OpenAI Direct",
                role: role,
                detail: "Connect to GPT-4/5 using your API key",
                status: .requiresConfiguration(message: "Add API key to enable"),
                icon: "key.fill"
            )
        }
        return ModelPipelineStage(
            name: "OpenAI Direct",
            role: role,
            detail: "Currently configured for \(openaiModel)",
            status: .available,
            icon: "key.fill"
        )
    }
}

// MARK: - Model Type Enum

enum LLMModelType: String, CaseIterable {
    case appleIntelligence = "apple_intelligence"  // On-device + PCC automatic
    case onDeviceAnalysis = "on_device_analysis"   // Extractive QA, always works
    case openAIDirect = "openai"
}

// MARK: - Model Info Card

struct ModelInfoCard: View {
    let modelType: LLMModelType
    let capabilities: DeviceCapabilities
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                icon
                    .font(.title)
                    .foregroundColor(.accentColor)
                
                Spacer()
                
                availabilityBadge
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(feature)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !isAvailable {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text(unavailabilityReason)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var icon: Image {
        switch modelType {
        case .appleIntelligence:
            if capabilities.supportsFoundationModels {
                return Image(systemName: "brain.head.profile")
            } else {
                return Image(systemName: "sparkles")
            }
        case .onDeviceAnalysis:
            return Image(systemName: "doc.text.magnifyingglass")
        case .openAIDirect:
            return Image(systemName: "key.fill")
        }
    }
    
    private var availabilityBadge: some View {
        Group {
            if isAvailable {
                Text("Available")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            } else {
                Text("Unavailable")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
            }
        }
    }
    
    private var isAvailable: Bool {
        switch modelType {
        case .appleIntelligence:
            return capabilities.supportsAppleIntelligence || capabilities.supportsFoundationModels
        case .onDeviceAnalysis:
            return true
        case .openAIDirect:
            return true
        }
    }
    
    private var unavailabilityReason: String {
        switch modelType {
        case .appleIntelligence:
            if capabilities.supportsAppleIntelligence || capabilities.supportsFoundationModels {
                return ""
            }
            if capabilities.iOSMajor < 18 {
                return "Requires iOS 18.1 or later"
            }
            if let reason = capabilities.appleIntelligenceUnavailableReason {
                return reason
            }
            if let reason = capabilities.foundationModelUnavailableReason {
                return reason
            }
            return "Enable Apple Intelligence in Settings"
        default:
            return ""
        }
    }
    
    private var features: [String] {
        switch modelType {
        case .appleIntelligence:
            if capabilities.supportsFoundationModels {
                return [
                    "Foundation Models (iOS 26+)",
                    "On-device + Private Cloud Compute",
                    "~3B parameters, 8K context",
                    "Zero data retention",
                    "Works offline for simple queries"
                ]
            } else {
                return [
                    "Apple Intelligence platform",
                    "Automatic on-device/cloud routing",
                    "Zero data retention (PCC)",
                    "No API key needed",
                    "Private and secure"
                ]
            }
        case .onDeviceAnalysis:
            return [
                "Extracts key sentences from documents",
                "NaturalLanguage framework",
                "No AI model needed",
                "Works on all devices",
                "100% private, no network"
            ]
        case .openAIDirect:
            return [
                "Use your own OpenAI API key",
                "Access latest GPT models (GPT-5, o1)",
                "Pay-as-you-go pricing",
                "Full control over usage",
                "128K context window"
            ]
        }
    }
}

// MARK: - Model Flow Diagnostics

private struct ModelPipelineStage: Identifiable {
    enum Role {
        case primary
        case fallback
        case optional
    }
    
    enum Status {
        case active
        case available
        case unavailable(reason: String)
        case requiresConfiguration(message: String)
        case disabled
    }
    
    let id = UUID()
    let name: String
    let role: Role
    let detail: String
    let status: Status
    let icon: String
}

private struct ModelPipelineRow: View {
    let stage: ModelPipelineStage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: stage.icon)
                    .font(.title3)
                    .foregroundColor(color(for: stage.status))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(stage.name)
                            .font(.headline)
                        roleBadge
                    }
                    Text(stage.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    statusLabel
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var roleBadge: some View {
        Text(stage.role.title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stage.role.tint.opacity(0.15))
            .foregroundColor(stage.role.tint)
            .clipShape(Capsule())
    }
    
    @ViewBuilder
    private var statusLabel: some View {
        switch stage.status {
        case .active:
            Label("Active", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .available:
            Label("Ready", systemImage: "bolt.circle")
                .font(.caption)
                .foregroundColor(.blue)
        case .unavailable(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.orange)
        case .requiresConfiguration(let message):
            Label(message, systemImage: "key.fill")
                .font(.caption)
                .foregroundColor(.orange)
        case .disabled:
            Label("Disabled in Settings", systemImage: "slash.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func color(for status: ModelPipelineStage.Status) -> Color {
        switch status {
        case .active:
            return .green
        case .available:
            return .blue
        case .unavailable:
            return .orange
        case .requiresConfiguration:
            return .orange
        case .disabled:
            return .secondary
        }
    }
}

private extension ModelPipelineStage.Role {
    var title: String {
        switch self {
        case .primary:
            return "Primary"
        case .fallback:
            return "Fallback"
        case .optional:
            return "Optional"
        }
    }
    
    var tint: Color {
        switch self {
        case .primary:
            return .green
        case .fallback:
            return .blue
        case .optional:
            return .secondary
        }
    }
}

private extension LLMModelType {
    var displayName: String {
        switch self {
        case .appleIntelligence:
            return "Apple Intelligence"
        case .onDeviceAnalysis:
            return "On-Device Analysis"
        case .openAIDirect:
            return "OpenAI Direct"
        }
    }
    
    var iconName: String {
        switch self {
        case .appleIntelligence:
            return "sparkles"
        case .onDeviceAnalysis:
            return "doc.text.magnifyingglass"
        case .openAIDirect:
            return "key.fill"
        }
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - About View

struct AboutView: View {
    @State private var deviceCapabilities = DeviceCapabilities()
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RAGMLCore")
                        .font(.title.bold())
                    Text("Privacy-First RAG Application")
                        .foregroundColor(.secondary)
                    Text("Version 0.1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Device & Capabilities
            Section("Your Device") {
                LabeledContent("Device Chip", value: deviceCapabilities.deviceChip.rawValue)
                LabeledContent("iOS Version", value: deviceCapabilities.iOSVersion)
                LabeledContent("Performance", value: deviceCapabilities.deviceChip.performanceRating)
                LabeledContent("AI Tier", value: deviceCapabilities.deviceTier.description)
            }
            
            Section("AI Capabilities") {
                HStack {
                    Text("Apple Intelligence")
                    Spacer()
                    Image(systemName: deviceCapabilities.supportsAppleIntelligence ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(deviceCapabilities.supportsAppleIntelligence ? .green : .secondary)
                }
                
                HStack {
                    Text("Foundation Models")
                    Spacer()
                    Image(systemName: deviceCapabilities.supportsFoundationModels ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(deviceCapabilities.supportsFoundationModels ? .green : .secondary)
                }
                
                HStack {
                    Text("Private Cloud Compute")
                    Spacer()
                    Image(systemName: deviceCapabilities.supportsPrivateCloudCompute ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(deviceCapabilities.supportsPrivateCloudCompute ? .green : .secondary)
                }
                
                HStack {
                    Text("Writing Tools")
                    Spacer()
                    Image(systemName: deviceCapabilities.supportsWritingTools ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(deviceCapabilities.supportsWritingTools ? .green : .secondary)
                }
            }
            
            Section("Features") {
                FeatureRow(icon: "doc.text.fill", title: "Document Processing", description: "Import PDFs, text files, and more")
                FeatureRow(icon: "cpu", title: "On-Device Processing", description: "OCR, chunking, and embeddings run locally")
                FeatureRow(icon: "brain", title: "Multiple AI Pathways", description: "Foundation Models, OpenAI, or extractive QA")
                FeatureRow(icon: "lock.shield.fill", title: "Privacy First", description: "Your data stays on your device by default")
            }
            
            Section("Technology") {
                LabeledContent("RAG Pipeline", value: "Semantic search + LLM")
                LabeledContent("Embeddings", value: "NLEmbedding (512-dim)")
                LabeledContent("Vector Store", value: "In-memory cosine similarity")
                LabeledContent("Minimum iOS", value: "18.0")
                LabeledContent("Optimized for", value: "iOS 26.0+")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                let caps = RAGService.checkDeviceCapabilities()
                await MainActor.run {
                    deviceCapabilities = caps
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView(ragService: RAGService())
}
