//
//  SettingsView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/10/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

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
    @State private var isValidatingAPIKey = false
    @State private var apiKeyValidationStatus: APIKeyValidationStatus = .unknown
    
    enum APIKeyValidationStatus {
        case unknown
        case validating
        case valid
        case invalid
        
        var icon: String {
            switch self {
            case .unknown: return "questionmark.circle"
            case .validating: return "hourglass"
            case .valid: return "checkmark.circle.fill"
            case .invalid: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .validating: return .blue
            case .valid: return .green
            case .invalid: return .red
            }
        }
        
        var message: String {
            switch self {
            case .unknown: return "Not validated"
            case .validating: return "Validating..."
            case .valid: return "API key is valid"
            case .invalid: return "Invalid API key"
            }
        }
    }
    
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
        ZStack {
            // Subtle modern gradient background
            LinearGradient(
                colors: [
                    DSColors.background,
                    DSColors.surface.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            Form {
                modelSelectionSection
                
                fallbackStrategySection

                if !pipelineStages.isEmpty {
                    Section {
                        ForEach(pipelineStages) { stage in
                            ModelPipelineRow(stage: stage)
                        }
                    } header: {
                        Text("Model Flow")
                    } footer: {
                        Text("The app checks each stage in order. If the primary model fails, the next enabled fallback takes over automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                privateCloudComputeSection
                
                openAIConfigurationSection
                
                llmParametersSection
                
                ragSettingsSection
                
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

                // MARK: - Diagnostics
                Section {
                    NavigationLink {
                        CoreValidationView(ragService: ragService)
                    } label: {
                        Label("Core Validation", systemImage: "checkmark.circle")
                    }
                    
                    NavigationLink {
                        TelemetryDashboardView()
                    } label: {
                        Label("Telemetry Dashboard", systemImage: "waveform.path.ecg")
                    }
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("Run tests to validate document processing, embeddings, vector search, and end-to-end RAG pipeline.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Developer Settings
                Section {
                    NavigationLink {
                        DeveloperSettingsView()
                    } label: {
                        Label("Developer Settings", systemImage: "hammer.fill")
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Advanced settings for debugging and development. Control console logging verbosity and performance monitoring.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
            .overlay(lifecycleHooks)
    } // body

    // Extracted alert components to reduce type-checker load
    private var apiKeyAlertMessage: Text {
        Text("You'll need an OpenAI API key to use OpenAI Direct. Sign up at platform.openai.com to get one. The API is pay-as-you-go.")
    }

    @ViewBuilder
    private var apiKeyAlertButtons: some View {
        Button("Get API Key") {
            if let url = URL(string: "https://platform.openai.com/api-keys") {
                #if canImport(UIKit)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
        }
        Button("OK", role: .cancel) {}
    }

    // Encapsulated lifecycle hooks to reduce type-check complexity on main chain
    @ViewBuilder
    private var lifecycleHooks: some View {
        Color.clear
            .onAppear {
                // Check device capabilities and refresh pipeline
                // Perform capability check on main queue (Foundation Models requires actual DispatchQueue.main)
                DispatchQueue.main.async {
                    let caps = RAGService.checkDeviceCapabilities()
                    deviceCapabilities = caps
                    refreshModelPipeline()
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
                apiKeyAlertButtons
            } message: {
                apiKeyAlertMessage
            }
    }
    
    // Extracted to reduce type-checker load
    @ViewBuilder
    private var modelSelectionSection: some View {
        // MARK: - AI Model Selection
        Section {
            Picker("AI Model", selection: $selectedModel) {
                aiModelOptions()
            }
            #if os(iOS)
            .pickerStyle(.navigationLink)
            #endif

            // Model details
            ModelInfoCard(modelType: selectedModel, capabilities: deviceCapabilities)

        } header: {
            Text("AI Model")
        } footer: {
            Text(modelFooterText)
        }
    }
    
    // MARK: - Helper & Pipeline Logic

    // Break down complex Picker options into a small @ViewBuilder to help Swift type-check faster.
    @ViewBuilder
    private func aiModelOptions() -> some View {
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

        // ChatGPT Extension (iOS 18.1+ Apple Intelligence)
        if #available(iOS 18.1, *) {
            Label {
                VStack(alignment: .leading) {
                    Text("ChatGPT Extension")
                    Text("Via Apple Intelligence - free tier, no account needed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } icon: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
            }
            .tag(LLMModelType.chatGPTExtension)
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

        // macOS-only local MLX backend
        Label {
            VStack(alignment: .leading) {
                Text("MLX Local (macOS)")
                Text("Connect to a local mlx-lm server")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } icon: {
            Image(systemName: "server.rack")
        }
        .tag(LLMModelType.mlxLocal)

        // Custom Core ML model backend
        Label {
            VStack(alignment: .leading) {
                Text("Core ML Local")
                Text("Run a converted .mlpackage on-device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } icon: {
            Image(systemName: "cpu")
        }
        .tag(LLMModelType.coreMLLocal)
    }

    // Pre-declare Binding to simplify Picker selection and reduce type-check work.
    private var executionContextBinding: Binding<ExecutionContext> {
        Binding<ExecutionContext>(
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
        )
    }
    
    // Extract fallback strategy section to reduce type-checker complexity
    @ViewBuilder
    private var fallbackStrategySection: some View {
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
        }
    }
    
    // Extract Private Cloud Compute section to reduce type-checker complexity
    @ViewBuilder
    private var privateCloudComputeSection: some View {
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
                    Picker("Execution Strategy", selection: executionContextBinding) {
                        ForEach([ExecutionContext.automatic, .onDeviceOnly, .preferCloud, .cloudOnly], id: \.self) { context in
                            HStack {
                                Text(context.emoji)
                                Text(context.description)
                            }
                            .tag(context)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #endif
                    
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
    }
    
    // Extract OpenAI Configuration section to reduce type-checker complexity
    @ViewBuilder
    private var openAIConfigurationSection: some View {
        Section {
            // API Key Input with Show/Hide
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showingAPIKeyInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                    }
                }
                
                HStack {
                    SecureField("sk-proj-...", text: $openaiAPIKey)
                        .textContentType(.password)
                        #if canImport(UIKit)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        #endif
                        .onChange(of: openaiAPIKey) { _, _ in
                            apiKeyValidationStatus = .unknown
                        }
                    
                    if !openaiAPIKey.isEmpty {
                        Button(action: {
                            openaiAPIKey = ""
                            apiKeyValidationStatus = .unknown
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Validation Status
                if !openaiAPIKey.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: apiKeyValidationStatus.icon)
                            .foregroundColor(apiKeyValidationStatus.color)
                            .font(.caption)
                        
                        Text(apiKeyValidationStatus.message)
                            .font(.caption)
                            .foregroundColor(apiKeyValidationStatus.color)
                        
                        Spacer()
                        
                        if apiKeyValidationStatus != .validating {
                            Button("Validate") {
                                Task {
                                    await validateAPIKey()
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
            
            Picker("Model", selection: $openaiModel) {
                Text("GPT-5 (Latest)").tag("gpt-5")
                Text("o1 (Reasoning)").tag("o1")
                Text("o1-mini (Fast Reasoning)").tag("o1-mini")
                Text("GPT-4o (Balanced)").tag("gpt-4o")
                Text("GPT-4o Mini (Fast)").tag("gpt-4o-mini")
                Text("GPT-4 Turbo").tag("gpt-4-turbo-preview")
            }
            
            // Show note for reasoning models (o1 and GPT-5)
            if openaiModel.hasPrefix("o1") {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain")
                        .foregroundColor(.blue)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("o1 Reasoning Model")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("o1 models use extended thinking and don't support temperature adjustment. They automatically determine their reasoning approach.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else if openaiModel.hasPrefix("gpt-5") {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GPT-5 Reasoning Model")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("GPT-5 uses reasoning tokens (like o1) and doesn't support temperature. Supports verbosity control and advanced reasoning via Responses API.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
        } header: {
            Text("OpenAI Configuration")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                if openaiAPIKey.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Key Required")
                                .fontWeight(.semibold)
                            Text("Get your API key from platform.openai.com/api-keys")
                            Text("Configure your key here, then select 'OpenAI Direct' above to use it.")
                                .font(.caption2)
                        }
                    }
                    .padding(.vertical, 4)
                } else if apiKeyValidationStatus == .valid {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("API key validated successfully. Select 'OpenAI Direct' in Model Selection to use it.")
                    }
                    .padding(.vertical, 4)
                } else if apiKeyValidationStatus == .invalid {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Key Invalid")
                                .fontWeight(.semibold)
                            Text("Please check your API key and try again.")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // Extract LLM Parameters section to reduce type-checker complexity
    @ViewBuilder
    private var llmParametersSection: some View {
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
            
            Stepper("Max Tokens: \(maxTokens)", value: $maxTokens, in: 100...8000, step: 100)
            
        } header: {
            Text("Generation Parameters")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Temperature: Lower = more focused, Higher = more creative")
                Text("Max Tokens: Maximum response length")
            }
            .font(.caption)
        }
    }
    
    // Extract RAG Settings section to reduce type-checker complexity
    @ViewBuilder
    private var ragSettingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Stepper("Retrieved Chunks: \(topK)", value: $topK, in: 1...50)
                
                // Visual indicator of retrieval strategy
                HStack(spacing: 4) {
                    Image(systemName: topK <= 5 ? "sparkles" : topK <= 15 ? "star.fill" : "crown.fill")
                        .font(.caption2)
                        .foregroundColor(topK <= 5 ? .orange : topK <= 15 ? .blue : .purple)
                    
                    Text(retrievalStrategyDescription(for: topK))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
            
        } header: {
            Text("Retrieval Settings")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Initial number of chunks to retrieve. The system will automatically truncate to fit the ~3500 character context window for Apple Intelligence (or up to ~8K completion tokens for OpenAI, based on the setting below).")
                
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                    Text("Higher values = more context but may hit size limits. The RAG pipeline retrieves 2x this amount, then re-ranks to the top results.")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
        }
    }

    private func retrievalStrategyDescription(for chunks: Int) -> String {
        switch chunks {
        case 1...3:
            return "Focused (fastest, most precise)"
        case 4...7:
            return "Balanced (good context, fast)"
        case 8...15:
            return "Comprehensive (rich context)"
        case 16...30:
            return "Extensive (maximum context)"
        default:
            return "All available (may hit limits)"
        }
    }

    private var modelFooterText: String {
        switch selectedModel {
        case .appleIntelligence:
            return "Primary: Apple Foundation Models when available. Automatic fallback to On-Device Analysis keeps responses working even if Apple Intelligence is unavailable."
        case .chatGPTExtension:
            return "Uses Apple's system-level ChatGPT integration (iOS 18.1+). Requires user consent per request. Free tier available, no OpenAI account needed."
        case .onDeviceAnalysis:
            return "Extracts relevant sentences from your documents using NaturalLanguage framework. No AI model needed, works on all devices, 100% private."
        case .openAIDirect:
            return "Primary: OpenAI GPT models using your key. If the API is unavailable, we fall back to On-Device Analysis so the chat never goes silent."
        case .mlxLocal:
            return "Runs a local LLM via MLX on macOS. Start mlx_lm.server locally; no data leaves your machine."
        case .coreMLLocal:
            return "Runs a custom Core ML LLM (.mlpackage) fully on-device. Requires selecting a compatible model."
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
    private func validateAPIKey() async {
        guard !openaiAPIKey.isEmpty else {
            apiKeyValidationStatus = .unknown
            return
        }

        apiKeyValidationStatus = .validating

        do {
            let testService = OpenAILLMService(
                apiKey: openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
                model: openaiModel
            )

            let config = InferenceConfig(
                maxTokens: 5,
                temperature: 0.7
            )

            let response = try await testService.generate(
                prompt: "Say 'Hello'",
                context: nil,
                config: config
            )

            if !response.text.isEmpty {
                apiKeyValidationStatus = .valid
            } else {
                apiKeyValidationStatus = .invalid
            }
        } catch {
            apiKeyValidationStatus = .invalid
        }
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
            case .chatGPTExtension:
                stages.append(makeChatGPTStage(role: role, isEnabled: preference.enabled))
            case .onDeviceAnalysis:
                stages.append(makeOnDeviceStage(role: role, isEnabled: preference.enabled))
            case .openAIDirect:
                stages.append(makeOpenAIStage(role: role, isEnabled: preference.enabled))
            case .mlxLocal:
                stages.append(makeMLXStage(role: role, isEnabled: preference.enabled))
            case .coreMLLocal:
                stages.append(makeCoreMLStage(role: role, isEnabled: preference.enabled))
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
        case .chatGPTExtension:
            if #available(iOS 18.1, *) {
                let service = AppleChatGPTExtensionService()
                return service.isAvailable ? service : nil
            }
            return nil
        case .onDeviceAnalysis:
            return OnDeviceAnalysisService()
        case .openAIDirect:
            let trimmedKey = openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKey.isEmpty else { return nil }
            return OpenAILLMService(apiKey: trimmedKey, model: openaiModel)
        case .mlxLocal:
            #if os(macOS)
            return MLXLocalLLMService()
            #else
            return nil
            #endif
        case .coreMLLocal:
            // Requires user to select a Core ML model URL; not configured here yet.
            return nil
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
        if !isEnabled {
            return ModelPipelineStage(name: "Apple Intelligence", role: role, detail: detail, status: .disabled, icon: "brain.head.profile")
        }
        if deviceCapabilities.supportsAppleIntelligence {
            let name = "Apple Intelligence"
            let status: ModelPipelineStage.Status = .requiresConfiguration(message: "Requires iOS 26 SDK for Foundation Models. Using system Apple Intelligence APIs.")
            return ModelPipelineStage(name: name, role: role, detail: "Private Cloud Compute + Writing Tools + ChatGPT", status: status, icon: "brain.head.profile")
        } else if let reason = deviceCapabilities.appleIntelligenceUnavailableReason {
            return ModelPipelineStage(name: "Apple Intelligence", role: role, detail: detail, status: .unavailable(reason: reason), icon: "brain.head.profile")
        }
        return ModelPipelineStage(name: "Apple Intelligence", role: role, detail: detail, status: .unavailable(reason: "Build with iOS 26 SDK to enable Foundation Models"), icon: "brain.head.profile")
        #endif
    }

    private func makeChatGPTStage(role: ModelPipelineStage.Role, isEnabled: Bool) -> ModelPipelineStage {
        let detail = "Apple's system-level ChatGPT integration (iOS 18.1+)"
        let isActive = ragService.llmService is AppleChatGPTExtensionService
        
        if isActive {
            return ModelPipelineStage(
                name: "ChatGPT Extension",
                role: role,
                detail: detail,
                status: .active,
                icon: "bubble.left.and.bubble.right.fill"
            )
        }
        
        if !isEnabled {
            return ModelPipelineStage(
                name: "ChatGPT Extension",
                role: role,
                detail: detail,
                status: .disabled,
                icon: "bubble.left.and.bubble.right.fill"
            )
        }
        
        // Check iOS 18.1+ availability
        if #available(iOS 18.1, *) {
            if deviceCapabilities.supportsAppleIntelligence {
                return ModelPipelineStage(
                    name: "ChatGPT Extension",
                    role: role,
                    detail: detail,
                    status: .requiresConfiguration(message: "Enable in Settings > Apple Intelligence & Siri > ChatGPT"),
                    icon: "bubble.left.and.bubble.right.fill"
                )
            } else {
                return ModelPipelineStage(
                    name: "ChatGPT Extension",
                    role: role,
                    detail: detail,
                    status: .unavailable(reason: "Requires Apple Intelligence (A17 Pro+ or M1+)"),
                    icon: "bubble.left.and.bubble.right.fill"
                )
            }
        } else {
            return ModelPipelineStage(
                name: "ChatGPT Extension",
                role: role,
                detail: detail,
                status: .unavailable(reason: "Requires iOS 18.1+"),
                icon: "bubble.left.and.bubble.right.fill"
            )
        }
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

    private func makeMLXStage(role: ModelPipelineStage.Role, isEnabled: Bool) -> ModelPipelineStage {
        #if os(macOS)
        let name = "MLX Local"
        let detail = "Local MLX server on macOS (no data leaves device)"
        let isActive = ragService.llmService is MLXLocalLLMService
        if isActive {
            return ModelPipelineStage(name: name, role: role, detail: detail, status: .active, icon: "server.rack")
        }
        if !isEnabled {
            return ModelPipelineStage(name: name, role: role, detail: detail, status: .disabled, icon: "server.rack")
        }
        return ModelPipelineStage(name: name, role: role, detail: detail, status: .requiresConfiguration(message: "Start mlx_lm.server locally"), icon: "server.rack")
        #else
        return ModelPipelineStage(name: "MLX Local", role: role, detail: "Local MLX server on macOS", status: .unavailable(reason: "macOS only"), icon: "server.rack")
        #endif
    }

    private func makeCoreMLStage(role: ModelPipelineStage.Role, isEnabled: Bool) -> ModelPipelineStage {
        let name = "Core ML Local"
        let detail = "Custom Core ML LLM (.mlpackage) fully on-device"
        let isActive = ragService.llmService is CoreMLLLMService
        if isActive {
            return ModelPipelineStage(name: name, role: role, detail: detail, status: .active, icon: "cpu")
        }
        if !isEnabled {
            return ModelPipelineStage(name: name, role: role, detail: detail, status: .disabled, icon: "cpu")
        }
        return ModelPipelineStage(name: name, role: role, detail: detail, status: .requiresConfiguration(message: "Select a Core ML model to enable"), icon: "cpu")
    }
}
#Preview {
    SettingsView(ragService: RAGService())
}
