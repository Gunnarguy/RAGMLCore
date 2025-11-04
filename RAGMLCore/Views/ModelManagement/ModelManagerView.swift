//
//  ModelManagerView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import SwiftUI

struct ModelManagerView: View {
    @ObservedObject var ragService: RAGService
    @EnvironmentObject private var settings: SettingsStore
    @State private var availableModels: [LLMModel] = []
    @State private var selectedModel: LLMModel?
    @State private var showingModelInfo = false
    @State private var deviceCapabilities = DeviceCapabilities()
    @StateObject private var downloadService = ModelDownloadService.shared
    @StateObject private var modelRegistry = ModelRegistry.shared
    
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

                    // Model Gallery (Downloads)
                    modelGalleryCard

                    // Installed Models
                    installedModelsCard
                    
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
                Task {
                    await ModelDownloadService.shared.loadCatalog(from: nil)
                    await ModelRegistry.shared.load()
                }
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
    private var modelGalleryCard: some View {
        ModelManagerCardView(icon: "tray.and.arrow.down.fill", title: "Model Gallery", caption: "Tap to download curated on-device models") {
            VStack(spacing: 12) {
                if downloadService.isLoadingCatalog {
                    HStack {
                        ProgressView()
                        Text("Loading models...")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else if let err = downloadService.catalogError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 8)
                } else if downloadService.catalog.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No models available")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(downloadService.catalog) { entry in
                        DownloadableModelRow(
                            entry: entry,
                            state: downloadService.downloads[entry.id],
                            onDownload: { downloadService.download(entry: entry) },
                            onPause: { downloadService.pause(entryID: entry.id) },
                            onResume: { downloadService.resume(entryID: entry.id) },
                            onCancel: { downloadService.cancel(entryID: entry.id) },
                            formatBytes: formatBytes,
                            downloadSpeedAndETA: downloadSpeedAndETA
                        )
                        if entry.id != downloadService.catalog.last?.id { 
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var installedModelsCard: some View {
        ModelManagerCardView(icon: "shippingbox.fill", title: "Installed Models", caption: "Hot‑swappable cartridges") {
            VStack(spacing: 10) {
                if modelRegistry.all().isEmpty {
                    Text("No local models installed yet. Use the Model Gallery to download.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(modelRegistry.all()) { installed in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: {
                                    switch installed.backend {
                                    case .gguf: return "doc.badge.gearshape"
                                    case .coreML: return "cpu"
                                    case .mlxServer: return "server.rack"
                                    }
                                }())
                                .foregroundColor(.accentColor)
                                Text(installed.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                if let vendor = installed.vendor {
                                    Text(vendor)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            HStack(spacing: 10) {
                                if let size = installed.sizeBytes {
                                    Label(formatBytes(size), systemImage: "externaldrive.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if let q = installed.quantization {
                                    Label(q, systemImage: "cpu")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Label(installed.backend.displayName, systemImage: installed.backend.iconName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 10) {
                                switch installed.backend {
                                case .gguf:
                                    if let url = installed.localURL, FileManager.default.fileExists(atPath: url.path) {
                                        Button {
                                            Task {
                                                await ModelActivationService.activate(installed, ragService: ragService, settings: settings)
                                                await MainActor.run { loadAvailableModels() }
                                            }
                                        } label: {
                                            Label("Make Active", systemImage: "play.circle.fill")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    } else {
                                        Button {
                                            // disabled placeholder
                                        } label: {
                                            Label("Missing File", systemImage: "exclamationmark.triangle")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(true)
                                    }
                                case .coreML:
                                    if let url = installed.localURL, FileManager.default.fileExists(atPath: url.path) {
                                        Button {
                                            Task {
                                                await ModelActivationService.activate(installed, ragService: ragService, settings: settings)
                                                await MainActor.run { loadAvailableModels() }
                                            }
                                        } label: {
                                            Label("Make Active", systemImage: "play.circle")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    } else {
                                        Button {
                                            // disabled placeholder
                                        } label: {
                                            Label("Configure", systemImage: "gear")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(true)
                                    }
                                case .mlxServer:
                                    Button {
                                        // Future activation flow for MLX servers
                                    } label: {
                                        Label("Not Supported Yet", systemImage: "ellipsis.circle")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(true)
                                }

                                Button(role: .destructive) {
                                    modelRegistry.remove(id: installed.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 6)
                        if installed.id != modelRegistry.all().last?.id { Divider() }
                    }
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

    private func splitOwnerRepo(_ input: String) -> (String, String)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let comps = trimmed.split(separator: "/").map(String.init)
        guard comps.count == 2, !comps[0].isEmpty, !comps[1].isEmpty else { return nil }
        return (comps[0], comps[1])
    }

    private func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes = bytes else { return "—" }
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024.0
        if mb < 1024.0 { return String(format: "%.2f MB", mb) }
        let gb = mb / 1024.0
        return String(format: "%.2f GB", gb)
    }

    private func formatBytesDouble(_ bytes: Double) -> String {
        if bytes < 1024 { return String(format: "%.0f B", bytes) }
        let kb = bytes / 1024.0
        if kb < 1024.0 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024.0
        if mb < 1024.0 { return String(format: "%.2f MB", mb) }
        let gb = mb / 1024.0
        return String(format: "%.2f GB", gb)
    }

    private func formatTime(_ seconds: Double) -> String {
        if seconds.isNaN || seconds.isInfinite { return "—" }
        let s = Int(max(0, seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
        }
    }

    private func downloadSpeedAndETA(for st: DownloadState) -> String {
        guard let bps = st.averageBytesPerSecond, bps > 0 else { return "Calculating…" }
        let remaining = max(0, st.totalBytes - st.bytesWritten)
        let etaSec = bps > 0 ? Double(remaining) / bps : 0
        return "\(formatBytesDouble(bps))/s • \(formatTime(etaSec))"
    }
    
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

        #if canImport(AppIntents)
        if #available(iOS 18.1, macOS 15.1, *), deviceCapabilities.supportsAppleIntelligence {
            let chatGPTNote = deviceCapabilities.appleIntelligenceUnavailableReason ?? "Enable ChatGPT in Settings → Apple Intelligence & Siri to activate system-managed access."
            models.append(
                LLMModel(
                    name: "ChatGPT (Apple Intelligence)",
                    modelType: .appleChatGPT,
                    parameterCount: "System-managed",
                    quantization: "Apple Intelligence service",
                    contextLength: appleContextTokens,
                    contextDescription: "System-level ChatGPT with Apple consent prompts and Private Cloud Compute safeguards.",
                    availabilityNote: chatGPTNote,
                    isAvailable: deviceCapabilities.supportsAppleIntelligence
                )
            )
        }
        #endif

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

        if deviceCapabilities.supportsCoreML {
            let hasCoreML = modelRegistry.installed.contains { $0.backend == .coreML }
            let coreMLNote = hasCoreML ? "Custom Core ML packages ready for offline inference." : "Import a .mlpackage via Files to enable custom Core ML models."
            models.append(
                LLMModel(
                    name: "Core ML (Custom Package)",
                    modelType: .coreMLPackage,
                    parameterCount: "Varies",
                    quantization: "Core ML runtime",
                    contextLength: 8_000,
                    contextDescription: "Bring your own converted Core ML LLM (.mlpackage).",
                    availabilityNote: coreMLNote,
                    isAvailable: hasCoreML
                )
            )
        }

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
        case .appleChatGPT:
            return "bubble.left.and.sparkles"
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

// MARK: - Downloadable Model Row

struct DownloadableModelRow: View {
    let entry: ModelCatalogEntry
    let state: DownloadState?
    let onDownload: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let formatBytes: (Int64?) -> String
    let downloadSpeedAndETA: (DownloadState) -> String
    
    var body: some View {
        VStack(spacing: 12) {
            // Model info header
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBackgroundColor)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(iconColor)
                }
                
                // Model details
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    
                    // Metadata badges
                    HStack(spacing: 8) {
                        if let vendor = entry.vendor, !vendor.isEmpty {
                            MetadataBadge(icon: "tag.fill", text: vendor)
                        }
                        if let sz = entry.sizeBytes {
                            MetadataBadge(icon: "externaldrive.fill", text: formatBytes(sz))
                        }
                        if let quant = entry.quantization {
                            MetadataBadge(icon: "cpu", text: quant)
                        }
                    }
                    
                    // Backend type
                    HStack(spacing: 4) {
                        Image(systemName: entry.backend.iconName)
                            .font(.caption2)
                        Text(entry.backend.displayName)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Large download warning
            if let sz = entry.sizeBytes, sz > 1_000_000_000 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Large download (~\(formatBytes(sz)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Download status and controls
            downloadStatusView
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var downloadStatusView: some View {
        switch state?.status {
        case .downloading:
            VStack(spacing: 8) {
                // Progress bar
                ProgressView(value: state?.progress ?? 0.0)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                
                // Progress details
                HStack {
                    Text(String(format: "%.0f%%", (state?.progress ?? 0.0) * 100.0))
                        .font(.caption.weight(.medium))
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    if let st = state {
                        Text(downloadSpeedAndETA(st))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Control buttons
                HStack(spacing: 10) {
                    Button(action: onPause) {
                        Label("Pause", systemImage: "pause.circle.fill")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: onCancel) {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    
                    Spacer()
                }
            }
            
        case .paused:
            HStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paused")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                    if let progress = state?.progress {
                        Text(String(format: "%.0f%% complete", progress * 100.0))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onResume) {
                    Label("Resume", systemImage: "play.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
        case .verifying:
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.9)
                Text("Verifying integrity...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(12)
            .background(DSColors.surface)
            .cornerRadius(12)
            
        case .registering:
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.9)
                Text("Installing model...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(12)
            .background(DSColors.surface)
            .cornerRadius(12)
            
        case .completed:
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Installed Successfully")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                    Text("Ready to use in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
        case .failed(let msg):
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download Failed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.red)
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                
                Button(action: onDownload) {
                    Label("Retry Download", systemImage: "arrow.clockwise.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
            
        case .cancelled:
            HStack(spacing: 12) {
                Image(systemName: "bolt.slash.circle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                
                Text("Download Cancelled")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
            .background(DSColors.surface)
            .cornerRadius(12)
            
        default:
            // Idle - show download button
            Button(action: onDownload) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                    Text("Download Model")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let sz = entry.sizeBytes {
                        Text(formatBytes(sz))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
    
    private var iconName: String {
        switch entry.backend {
        case .gguf: return "doc.badge.gearshape"
        case .coreML: return "cpu"
        case .mlxServer: return "server.rack"
        }
    }
    
    private var iconColor: Color {
        if case .completed = state?.status {
            return .green
        }
        return .accentColor
    }
    
    private var iconBackgroundColor: Color {
        if case .completed = state?.status {
            return Color.green.opacity(0.15)
        }
        return Color.accentColor.opacity(0.15)
    }
}

private struct MetadataBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
}

#Preview {
    let service = RAGService()
    return ModelManagerView(ragService: service)
        .environmentObject(SettingsStore(ragService: service))
}
