//
//  AboutView.swift
//  RAGMLCore
//
//  Created by GitHub Copilot on 10/24/25.
//

import SwiftUI

/// Presents product metadata and device-specific capability information.
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

            Section("Your Device") {
                LabeledContent("Device Chip", value: deviceCapabilities.deviceChip.rawValue)
                LabeledContent("iOS Version", value: deviceCapabilities.iOSVersion)
                LabeledContent("Performance", value: deviceCapabilities.deviceChip.performanceRating)
                LabeledContent("AI Tier", value: deviceCapabilities.deviceTier.description)
            }

            Section("AI Capabilities") {
                capabilityRow(title: "Apple Intelligence", condition: deviceCapabilities.supportsAppleIntelligence)
                capabilityRow(title: "Foundation Models", condition: deviceCapabilities.supportsFoundationModels)
                capabilityRow(title: "Private Cloud Compute", condition: deviceCapabilities.supportsPrivateCloudCompute)
                capabilityRow(title: "Writing Tools", condition: deviceCapabilities.supportsWritingTools)
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
            DispatchQueue.main.async {
                deviceCapabilities = RAGService.checkDeviceCapabilities()
            }
        }
    }

    private func capabilityRow(title: String, condition: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: condition ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(condition ? .green : .secondary)
        }
    }
}
