//
//  ModelManagerView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import SwiftUI

struct ModelManagerView: View {
    @ObservedObject var ragService: RAGService
    @State private var availableModels: [LLMModel] = []
    @State private var selectedModel: LLMModel?
    @State private var showingModelInfo = false
    @State private var deviceCapabilities = DeviceCapabilities()
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    DSColors.background,
                    DSColors.surface.opacity(0.95),
                    DSColors.background.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: []) {
                    // Hero Status Card
                    ragPipelineStatusCard
                    
                    // Intelligence Stack
                    intelligenceStackCard
                    
                    // Active RAG Configuration
                    ragConfigurationCard
                    
                    // Device Capabilities (Compact)
                    deviceCapabilitiesCard
                    
                    // Performance Metrics
                    performanceMetricsCard
                    
                    // Available Models (Focused)
                    availableModelsCard
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("RAG Intelligence")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onAppear {
            DispatchQueue.main.async {
                let caps = RAGService.checkDeviceCapabilities()
                deviceCapabilities = caps
                loadAvailableModels()
            }
        }
        .sheet(isPresented: $showingModelInfo) {
            CustomModelInstructionsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            loadAvailableModels()
        }
    }

    // MARK: - Section Builders
    
    @ViewBuilder
    private var ragPipelineStatusCard: some View {
        VStack(spacing: 0) {
            // Hero gradient header
            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.8),
                        Color.accentColor.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("RAG Pipeline Active")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(ragService.isLLMAvailable ? "Ready for Intelligent Queries" : "Configuration Required")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.vertical, 32)
            }
            .frame(maxWidth: .infinity)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
            
            // Stats grid
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    QuickStatCell(
                        value: "\(ragService.documents.count)",
                        label: "Documents",
                        icon: "doc.text.fill",
                        color: .blue
                    )
                    
                    Divider()
                    
                    QuickStatCell(
                        value: "\(ragService.totalChunksStored)",
                        label: "Chunks",
                        icon: "square.stack.3d.up.fill",
                        color: .purple
                    )
                }
                .frame(height: 90)
                
                Divider()
                
                HStack(spacing: 0) {
                    QuickStatCell(
                        value: estimatedMemoryUsage,
                        label: "Memory",
                        icon: "memorychip",
                        color: .orange
                    )
                    
                    Divider()
                    
                    QuickStatCell(
                        value: "512-dim",
                        label: "Embeddings",
                        icon: "waveform.path.ecg",
                        color: .green
                    )
                }
                .frame(height: 90)
            }
            .background(DSColors.surface)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
        }
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
    
    @ViewBuilder
    private var intelligenceStackCard: some View {
        ModelManagerCardView(icon: "sparkles", title: "Intelligence Stack", caption: "RAG Pipeline Layers") {
            VStack(spacing: 14) {
                IntelligenceLayerRow(
                    number: 1,
                    icon: "doc.viewfinder.fill",
                    title: "Document Processing",
                    status: .active,
                    detail: "PDFKit + Vision OCR → Semantic Chunking"
                )
                
                IntelligenceLayerRow(
                    number: 2,
                    icon: "chart.bar.doc.horizontal",
                    title: "Embedding Generation",
                    status: .active,
                    detail: "NLEmbedding (Word2Vec) → 512-dim vectors"
                )
                
                IntelligenceLayerRow(
                    number: 3,
                    icon: "cylinder.fill",
                    title: "Vector Database",
                    status: .active,
                    detail: "Cosine similarity search → Top-K retrieval"
                )
                
                IntelligenceLayerRow(
                    number: 4,
                    icon: ragService.isLLMAvailable ? "brain.head.profile" : "exclamationmark.triangle.fill",
                    title: "LLM Generation",
                    status: ragService.isLLMAvailable ? .active : .warning,
                    detail: ragService.currentModelName
                )
                
                if deviceCapabilities.supportsPrivateCloudCompute && ragService.isLLMAvailable {
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "cloud.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Automatic PCC Fallback Enabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var ragConfigurationCard: some View {
        ModelManagerCardView(icon: "gearshape.2.fill", title: "Active Configuration", caption: "Current RAG settings") {
            VStack(spacing: 12) {
                ConfigRow(
                    icon: "brain.head.profile",
                    label: "Primary Model",
                    value: ragService.currentModelName,
                    accent: .accentColor
                )
                
                ConfigRow(
                    icon: "arrow.down.doc.fill",
                    label: "Retrieval Strategy",
                    value: "Top-\(UserDefaults.standard.integer(forKey: "retrievalTopK") > 0 ? UserDefaults.standard.integer(forKey: "retrievalTopK") : 3) chunks",
                    accent: .purple
                )
                
                ConfigRow(
                    icon: "thermometer.medium",
                    label: "Temperature",
                    value: String(format: "%.2f", UserDefaults.standard.double(forKey: "llmTemperature") > 0 ? UserDefaults.standard.double(forKey: "llmTemperature") : 0.7),
                    accent: .orange
                )
                
                ConfigRow(
                    icon: "text.word.spacing",
                    label: "Max Tokens",
                    value: "\(UserDefaults.standard.integer(forKey: "llmMaxTokens") > 0 ? UserDefaults.standard.integer(forKey: "llmMaxTokens") : 500)",
                    accent: .blue
                )
                
                if deviceCapabilities.supportsPrivateCloudCompute {
                    ConfigRow(
                        icon: "cloud.fill",
                        label: "Execution Mode",
                        value: executionModeDisplay,
                        accent: .green
                    )
                }
                
                Divider()
                
                Button {
                    // Navigate to settings
                } label: {
                    HStack {
                        Text("Modify in Settings")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    @ViewBuilder
    private var deviceCapabilitiesCard: some View {
        ModelManagerCardView(icon: "cpu", title: "Device Intelligence", caption: deviceCapabilities.deviceChip.rawValue) {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deviceCapabilities.deviceTier.description.uppercased() + " TIER")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(deviceTierColor)
                        Text(deviceCapabilities.deviceChip.performanceRating)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("iOS \(deviceCapabilities.iOSVersion)")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DSColors.surface)
                        .cornerRadius(8)
                }
                
                Divider()
                
                VStack(spacing: 6) {
                    CompactCapabilityRow(
                        icon: deviceCapabilities.supportsFoundationModels ? "brain.head.profile" : "sparkles",
                        label: deviceCapabilities.supportsFoundationModels ? "Foundation Models" : "Apple Intelligence",
                        isSupported: deviceCapabilities.supportsFoundationModels || deviceCapabilities.supportsAppleIntelligence
                    )
                    
                    CompactCapabilityRow(
                        icon: "cloud.fill",
                        label: "Private Cloud Compute",
                        isSupported: deviceCapabilities.supportsPrivateCloudCompute
                    )
                    
                    CompactCapabilityRow(
                        icon: "cpu",
                        label: "Neural Engine",
                        isSupported: deviceCapabilities.hasNeuralEngine
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var performanceMetricsCard: some View {
        ModelManagerCardView(icon: "gauge.with.dots.needle.67percent", title: "Performance Metrics", caption: "Real-time system stats") {
            VStack(spacing: 10) {
                if let lastSummary = ragService.lastProcessingSummary {
                    MetricRow(
                        label: "Last Processing Time",
                        value: String(format: "%.2fs", lastSummary.totalTime),
                        icon: "clock.arrow.circlepath",
                        color: .pink
                    )
                    
                    MetricRow(
                        label: "Average Chunk Size",
                        value: "\(lastSummary.chunkStats.avgChars) chars",
                        icon: "text.alignleft",
                        color: .indigo
                    )
                }
                
                MetricRow(
                    label: "Vector Store Size",
                    value: estimatedMemoryUsage,
                    icon: "externaldrive.fill",
                    color: .teal
                )
                
                MetricRow(
                    label: "Embedding Model",
                    value: "NLEmbedding (Word2Vec)",
                    icon: "function",
                    color: .purple
                )
                
                if deviceCapabilities.hasNeuralEngine {
                    MetricRow(
                        label: "Neural Engine",
                        value: deviceCapabilities.deviceChip.neuralEnginePerformance,
                        icon: "cpu.fill",
                        color: .green
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var availableModelsCard: some View {
        ModelManagerCardView(icon: "server.rack", title: "Available Models", caption: "Ready for RAG queries") {
            VStack(spacing: 12) {
                if availableModels.isEmpty {
                    Text("Loading model information...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                } else {
                    ForEach(availableModels) { model in
                        ModernModelRow(model: model)
                        if model.id != availableModels.last?.id {
                            Divider()
                        }
                    }
                }
                
                Divider()
                
                Button {
                    showingModelInfo = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Custom Model")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    // MARK: - Helper Properties & Methods
    
    private var executionModeDisplay: String {
        let rawValue = UserDefaults.standard.string(forKey: "executionContext") ?? "automatic"
        switch rawValue {
        case "automatic": return "Automatic (Hybrid)"
        case "onDeviceOnly": return "On-Device Only"
        case "preferCloud": return "Prefer Cloud"
        case "cloudOnly": return "Cloud Only"
        default: return "Automatic"
        }
    }
    
    private var deviceTierColor: Color {
        switch deviceCapabilities.deviceTier {
        case .high:
            return .green
        case .medium:
            return .blue
        case .low:
            return .orange
        }
    }
    
    private var estimatedMemoryUsage: String {
        // Each chunk: 512 floats (4 bytes each) + metadata (~500 bytes)
        let bytesPerChunk = (512 * 4) + 500
        let totalBytes = bytesPerChunk * ragService.totalChunksStored
        
        if totalBytes < 1024 {
            return "\(totalBytes) B"
        } else if totalBytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(totalBytes) / 1024.0)
        } else {
            return String(format: "%.2f MB", Double(totalBytes) / (1024.0 * 1024.0))
        }
    }
    
    private func loadAvailableModels() {
        var models: [LLMModel] = []
        let foundationAvailable = deviceCapabilities.supportsFoundationModels
        let appleContextTokens = deviceCapabilities.appleIntelligenceContextTokens
        let appleContextDescription = deviceCapabilities.appleIntelligenceContextDescription ?? "Not available on this device."

        let foundationNote: String
        if foundationAvailable {
            foundationNote = "Neural Engine (\(deviceCapabilities.deviceChip.neuralEnginePerformance)) handles on-device context; PCC expands automatically for complex or lengthy prompts."
        } else if deviceCapabilities.supportsAppleIntelligence {
            foundationNote = deviceCapabilities.appleIntelligenceUnavailableReason ?? "Apple Intelligence enabled; Foundation Models are still preparing on this device."
        } else {
            foundationNote = deviceCapabilities.appleIntelligenceUnavailableReason ?? "Requires iOS 18.1+ and A17 Pro, A18, or M-series hardware."
        }
        models.append(
            LLMModel(
                name: "Apple Intelligence (Hybrid)",
                modelType: .appleHybrid,
                parameterCount: "~3B on-device / server-grade in PCC",
                quantization: "Neural Engine optimized",
                contextLength: appleContextTokens,
                contextDescription: appleContextTokens > 0 ? appleContextDescription : "Not available on this device.",
                availabilityNote: foundationNote,
                isAvailable: foundationAvailable
            )
        )

        let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let openAIAvailable = !apiKey.isEmpty
        let openAINote = openAIAvailable ? "Reasoning models (gpt-5, o1) with ~400K-token context and ~12K completion target." : "Add your OpenAI API key in Settings → OpenAI to enable GPT-5 access."
        models.append(
            LLMModel(
                name: "OpenAI GPT-5 (Reasoning)",
                modelType: .openAI,
                parameterCount: "Proprietary (GPT-5)",
                quantization: "Cloud inference",
                contextLength: 400_000,
                contextDescription: "400K-token context window, optimized for long RAG prompts with reasoning traces.",
                availabilityNote: openAINote,
                isAvailable: openAIAvailable
            )
        )

        let extractiveNote = "Extracts answers directly from retrieved text without generative hallucinations."
        models.append(
            LLMModel(
                name: "On-Device Analysis (Extractive QA)",
                modelType: .onDeviceAnalysis,
                parameterCount: "N/A",
                quantization: "Deterministic",
                contextLength: max(appleContextTokens, 900),
                contextDescription: "Uses similarity search only; ideal offline fallback when generative models are unavailable.",
                availabilityNote: extractiveNote,
                isAvailable: true
            )
        )

        availableModels = models
    }

}

// MARK: - Supporting Components

private struct QuickStatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct IntelligenceLayerRow: View {
    let number: Int
    let icon: String
    let title: String
    let status: LayerStatus
    let detail: String
    
    enum LayerStatus {
        case active, warning, inactive
        
        var color: Color {
            switch self {
            case .active: return .green
            case .warning: return .orange
            case .inactive: return .secondary
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .inactive: return "circle"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundColor(status.color)
            }
            
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

private struct ConfigRow: View {
    let icon: String
    let label: String
    let value: String
    let accent: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(accent)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}

private struct CompactCapabilityRow: View {
    let icon: String
    let label: String
    let isSupported: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(isSupported ? .accentColor : .secondary)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(isSupported ? .primary : .secondary)
            
            Spacer()
            
            Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSupported ? .green : .red)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}

private struct MetricRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}

private struct ModernModelRow: View {
    let model: LLMModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(model.isAvailable ? Color.accentColor.opacity(0.15) : DSColors.surface)
                    .frame(width: 48, height: 48)
                
                Image(systemName: modelIcon)
                    .font(.title3)
                    .foregroundColor(model.isAvailable ? .accentColor : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                    Spacer()
                    if model.isAvailable {
                        Text("Ready")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(6)
                    } else {
                        Text("Unavailable")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                }
                
                if let contextDescription = model.contextDescription {
                    Text(contextDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 10) {
                    Label(formatContextLength(model.contextLength), systemImage: "doc.text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let quantization = model.quantization {
                        Label(quantization, systemImage: "cpu")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private var modelIcon: String {
        switch model.modelType {
        case .appleFoundation:
            return "brain.head.profile"
        case .appleHybrid:
            return "sparkles"
        case .openAI:
            return "key.fill"
        case .onDeviceAnalysis:
            return "doc.text.magnifyingglass"
        case .coreMLPackage:
            return "cpu"
        case .gguf:
            return "doc.badge.gearshape"
        }
    }
    
    private func formatContextLength(_ length: Int) -> String {
        if length <= 0 {
            return "N/A"
        }
        if length >= 1000 {
            return "\(length / 1000)K tokens"
        }
        return "\(length) tokens"
    }
}

// MARK: - Shared Card Styling

private struct ModelManagerCardView<Content: View>: View {
    let icon: String?
    let title: String
    let caption: String?
    let content: Content
    
    init(icon: String? = nil, title: String, caption: String? = nil, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.caption = caption
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if icon != nil || !title.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        if let caption, !caption.isEmpty {
                            Text(caption)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DSColors.surface)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

private struct CustomModelInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    InstructionSection(
                        title: "Pathway B1: Core ML Models",
                        icon: "cpu",
                        steps: [
                            "Download a PyTorch or TensorFlow model",
                            "Use coremltools Python library to convert to .mlpackage format",
                            "Apply optimizations: quantization and KV-caching",
                            "Transfer the .mlpackage file to your iOS device",
                            "The app will automatically detect and load it"
                        ]
                    )
                    
                    Divider()
                    
                    InstructionSection(
                        title: "Pathway B2: GGUF Models",
                        icon: "doc.badge.gearshape",
                        steps: [
                            "Download any GGUF-formatted model from Hugging Face",
                            "Transfer the .gguf file to your iOS device",
                            "Select it in the app's model picker",
                            "Requires llama.cpp integration (optional feature - see ENHANCEMENTS.md)"
                        ]
                    )
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommended Models")
                            .font(.headline)
                        
                        Text("• Llama 3.1 (8B, 4-bit quantized)")
                        Text("• Phi-3 Mini (3.8B)")
                        Text("• Mistral 7B (4-bit quantized)")
                        Text("• Gemma 2B")
                    }
                    .font(.body)
                    .padding()
                    .background(DSColors.surface)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Custom Models")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #elseif os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

private struct InstructionSection: View {
    let title: String
    let icon: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                    Text(step)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.body)
            }
        }
    }
}

#Preview {
    ModelManagerView(ragService: RAGService())
}
