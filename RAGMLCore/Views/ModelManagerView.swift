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
        NavigationView {
            List {
                Section(header: Text("Device Capabilities")) {
                    CapabilityRow(
                        icon: "cpu",
                        label: "Apple Intelligence",
                        isSupported: deviceCapabilities.supportsAppleIntelligence
                    )
                    CapabilityRow(
                        icon: "chart.bar.doc.horizontal",
                        label: "On-Device Embeddings",
                        isSupported: deviceCapabilities.supportsEmbeddings
                    )
                    CapabilityRow(
                        icon: "brain",
                        label: "Core ML Support",
                        isSupported: deviceCapabilities.supportsCoreML
                    )
                    
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.secondary)
                        Text("Device Tier")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(tierDescription(deviceCapabilities.deviceTier))
                            .fontWeight(.medium)
                            .foregroundColor(tierColor(deviceCapabilities.deviceTier))
                    }
                }
                
                Section(header: Text("Active Model")) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ragService.currentModelName)
                                .font(.headline)
                            Text(ragService.isLLMAvailable ? "Available" : "Unavailable")
                                .font(.caption)
                                .foregroundColor(ragService.isLLMAvailable ? .green : .red)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text("Available Models")) {
                    if deviceCapabilities.supportsAppleIntelligence {
                        ModelRow(model: LLMModel(
                            name: "Apple Foundation Model",
                            modelType: .appleFoundation,
                            parameterCount: "~3B",
                            contextLength: 8192,
                            isAvailable: true
                        ))
                    }
                    
                    if availableModels.isEmpty {
                        Text("No custom models installed")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(availableModels) { model in
                            ModelRow(model: model)
                        }
                    }
                }
                
                Section(header: Text("Add Custom Models")) {
                    Button(action: {
                        showingModelInfo = true
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("How to Add Custom Models")
                        }
                    }
                }
            }
            .navigationTitle("Models")
            .onAppear {
                deviceCapabilities = RAGService.checkDeviceCapabilities()
                loadAvailableModels()
            }
            .sheet(isPresented: $showingModelInfo) {
                CustomModelInstructionsView()
            }
        }
    }
    
    private func loadAvailableModels() {
        // Future enhancement: Scan app directory for .mlpackage and .gguf files
        availableModels = []
    }
    
    private func tierDescription(_ tier: DeviceCapabilities.DeviceTier) -> String {
        switch tier {
        case .high:
            return "High Performance"
        case .medium:
            return "Medium Performance"
        case .low:
            return "Limited Support"
        }
    }
    
    private func tierColor(_ tier: DeviceCapabilities.DeviceTier) -> Color {
        switch tier {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .red
        }
    }
}

struct CapabilityRow: View {
    let icon: String
    let label: String
    let isSupported: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSupported ? .green : .red)
        }
    }
}

struct ModelRow: View {
    let model: LLMModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.name)
                    .font(.headline)
                Spacer()
                if model.isAvailable {
                    Text("Available")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: 16) {
                Label(model.parameterCount, systemImage: "number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(model.contextLength) tokens", systemImage: "text.alignleft")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let quantization = model.quantization {
                    Label(quantization, systemImage: "dial.medium")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(model.modelType.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
