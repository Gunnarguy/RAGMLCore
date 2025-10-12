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
        List {
                // MARK: - Device Information
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cpu")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deviceCapabilities.deviceChip.rawValue)
                                    .font(.headline)
                                Text(deviceCapabilities.deviceChip.performanceRating)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(deviceCapabilities.deviceTier.description)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(deviceTierColor.opacity(0.2))
                                .foregroundColor(deviceTierColor)
                                .cornerRadius(8)
                        }
                        
                        Divider()
                        
                        HStack {
                            Image(systemName: "iphone.gen3")
                                .foregroundColor(.secondary)
                            Text("iOS \(deviceCapabilities.iOSVersion)")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(deviceCapabilities.appleIntelligenceStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Device Information")
                }
                
                // MARK: - Apple Intelligence Features
                Section {
                    // Foundation Models (iOS 26+)
                    CapabilityRow(
                        icon: "brain.head.profile",
                        label: "Foundation Models",
                        sublabel: "On-device LLM (iOS 26+)",
                        isSupported: deviceCapabilities.supportsFoundationModels,
                        badge: deviceCapabilities.supportsFoundationModels ? "iOS 26" : nil
                    )
                    
                    // Apple Intelligence Platform (iOS 18.1+)
                    CapabilityRow(
                        icon: "sparkles",
                        label: "Apple Intelligence",
                        sublabel: "A17 Pro+ or M-series required",
                        isSupported: deviceCapabilities.supportsAppleIntelligence,
                        badge: deviceCapabilities.supportsAppleIntelligence ? "iOS 18.1+" : nil
                    )
                    
                    // Private Cloud Compute (iOS 18.1+)
                    CapabilityRow(
                        icon: "cloud.fill",
                        label: "Private Cloud Compute",
                        sublabel: "Secure cloud inference",
                        isSupported: deviceCapabilities.supportsPrivateCloudCompute,
                        badge: deviceCapabilities.supportsPrivateCloudCompute ? "Available" : nil
                    )
                    
                    // Writing Tools (iOS 18.1+)
                    CapabilityRow(
                        icon: "pencil.and.list.clipboard",
                        label: "Writing Tools",
                        sublabel: "Proofreading & rewriting",
                        isSupported: deviceCapabilities.supportsWritingTools,
                        badge: deviceCapabilities.supportsWritingTools ? "iOS 18.1+" : nil
                    )
                    
                    // Image Playground (iOS 18.1+, requires A17 Pro+)
                    CapabilityRow(
                        icon: "photo.on.rectangle.angled",
                        label: "Image Playground",
                        sublabel: "On-device image generation",
                        isSupported: deviceCapabilities.supportsImagePlayground,
                        badge: deviceCapabilities.supportsImagePlayground ? "Available" : nil
                    )
                } header: {
                    Text("Apple Intelligence")
                } footer: {
                    if !deviceCapabilities.supportsAppleIntelligence {
                        Text("Apple Intelligence requires iOS 18.1+ and A17 Pro, A18, or M-series chip. Foundation Models require iOS 26.0+.")
                    }
                }
                
                // MARK: - Core AI Frameworks
                Section {
                    CapabilityRow(
                        icon: "chart.bar.doc.horizontal",
                        label: "NaturalLanguage Embeddings",
                        sublabel: "512-dim semantic vectors",
                        isSupported: deviceCapabilities.supportsEmbeddings,
                        badge: "On-Device"
                    )
                    
                    CapabilityRow(
                        icon: "gearshape.2.fill",
                        label: "Core ML",
                        sublabel: "Neural Engine optimization",
                        isSupported: deviceCapabilities.supportsCoreML,
                        badge: "Available"
                    )
                    
                    CapabilityRow(
                        icon: "eye.fill",
                        label: "Vision Framework",
                        sublabel: "Image & document analysis",
                        isSupported: deviceCapabilities.supportsVision,
                        badge: "Available"
                    )
                    
                    CapabilityRow(
                        icon: "doc.viewfinder.fill",
                        label: "VisionKit",
                        sublabel: "Document scanning",
                        isSupported: deviceCapabilities.supportsVisionKit,
                        badge: "Available"
                    )
                    
                    CapabilityRow(
                        icon: "waveform.path.ecg",
                        label: "App Intents (Siri)",
                        sublabel: "Voice-activated queries",
                        isSupported: deviceCapabilities.supportsAppIntents,
                        badge: "Available"
                    )
                } header: {
                    Text("AI Frameworks")
                }
                
                // MARK: - Active Model
                Section {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ragService.currentModelName)
                                .font(.headline)
                            Text(ragService.isLLMAvailable ? "Ready for queries" : "Unavailable")
                                .font(.caption)
                                .foregroundColor(ragService.isLLMAvailable ? .green : .orange)
                            
                            // Show specific unavailability reason for Foundation Models
                            if !ragService.isLLMAvailable {
                                #if canImport(FoundationModels)
                                if #available(iOS 26.0, *),
                                   let service = ragService.llmService as? AppleFoundationLLMService,
                                   let reason = service.unavailabilityReason {
                                    Text(reason)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                #endif
                            }
                        }
                        Spacer()
                        Image(systemName: ragService.isLLMAvailable ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(ragService.isLLMAvailable ? .green : .orange)
                            .font(.title3)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Active Model")
                } footer: {
                    Text("Change the active model in Settings → AI Model")
                }
                
                // MARK: - Available Models
                Section {
                    if deviceCapabilities.supportsFoundationModels {
                        ModelRow(model: LLMModel(
                            name: "Apple Foundation Model",
                            modelType: .appleFoundation,
                            parameterCount: "~3B",
                            contextLength: 8192,
                            isAvailable: true
                        ))
                    }
                    
                    // OpenAI Direct (always available if user has API key)
                    ModelRow(model: LLMModel(
                        name: "OpenAI Direct",
                        modelType: .coreMLPackage, // Using as generic type
                        parameterCount: "Varies",
                        contextLength: 128000,
                        isAvailable: true
                    ))
                    
                    // On-Device Analysis (always available)
                    ModelRow(model: LLMModel(
                        name: "On-Device Analysis",
                        modelType: .coreMLPackage,
                        parameterCount: "N/A",
                        contextLength: 8192,
                        isAvailable: true
                    ))
                    
                    if !availableModels.isEmpty {
                        ForEach(availableModels) { model in
                            ModelRow(model: model)
                        }
                    }
                } header: {
                    Text("Available Models")
                } footer: {
                    Text("Select your preferred model in Settings. Custom Core ML and GGUF models can be added for advanced users.")
                }
                
                // MARK: - Add Custom Models
                Section {
                    Button(action: {
                        showingModelInfo = true
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("How to Add Custom Models")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Advanced")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Models & Capabilities")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    let caps = RAGService.checkDeviceCapabilities()
                    await MainActor.run {
                        deviceCapabilities = caps
                        loadAvailableModels()
                    }
                }
            }
            .sheet(isPresented: $showingModelInfo) {
                CustomModelInstructionsView()
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
    
    private func loadAvailableModels() {
        // Future enhancement: Scan app directory for .mlpackage and .gguf files
        availableModels = []
    }
}

// MARK: - Capability Row Component

struct CapabilityRow: View {
    let icon: String
    let label: String
    var sublabel: String? = nil
    let isSupported: Bool
    var badge: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isSupported ? .accentColor : .secondary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .foregroundColor(isSupported ? .primary : .secondary)
                if let sublabel = sublabel {
                    Text(sublabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let badge = badge, isSupported {
                Text(badge)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)
            }
            
            Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSupported ? .green : .red)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}

struct ModelRow: View {
    let model: LLMModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on model type
            Image(systemName: modelIcon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                    Spacer()
                    if model.isAvailable {
                        Text("Available")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(6)
                    }
                }
                
                HStack(spacing: 12) {
                    Label(model.parameterCount, systemImage: "number.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(formatContextLength(model.contextLength))", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let quantization = model.quantization {
                        Label(quantization, systemImage: "dial.medium.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(model.modelType.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(uiColor: .systemGray5))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var modelIcon: String {
        switch model.modelType {
        case .appleFoundation:
            return "brain.head.profile"
        case .coreMLPackage:
            return "cpu"
        case .gguf:
            return "doc.badge.gearshape"
        }
    }
    
    private func formatContextLength(_ length: Int) -> String {
        if length >= 1000 {
            return "\(length / 1000)K ctx"
        } else {
            return "\(length) ctx"
        }
    }
}

struct CustomModelInstructionsView: View {
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
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Custom Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionSection: View {
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
