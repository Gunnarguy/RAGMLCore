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
    @AppStorage("llmTemperature") private var temperature: Double = 0.7
    @AppStorage("llmMaxTokens") private var maxTokens: Int = 500
    @AppStorage("retrievalTopK") private var topK: Int = 3
    
    @State private var showingAPIKeyInfo = false
    @State private var isApplyingSettings = false
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - AI Model Selection
                Section {
                    Picker("AI Model", selection: $selectedModel) {
                        if #available(iOS 18.0, *) {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Apple Intelligence")
                                    Text("Auto on-device/cloud - zero data retention")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "brain.head.profile")
                            }
                            .tag(LLMModelType.appleIntelligence)
                        }
                        
                        if #available(iOS 18.1, *) {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("ChatGPT")
                                    Text("Via Apple Intelligence")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                            }
                            .tag(LLMModelType.appleChatGPT)
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
                                Text("Mock (Testing)")
                                Text("For development")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "hammer.fill")
                        }
                        .tag(LLMModelType.mock)
                    }
                    .pickerStyle(.navigationLink)
                    
                    // Model details
                    ModelInfoCard(modelType: selectedModel)
                    
                } header: {
                    Text("AI Model")
                } footer: {
                    Text(modelFooterText)
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
                            Text("GPT-4o Mini (Fast)").tag("gpt-4o-mini")
                            Text("GPT-4o (Balanced)").tag("gpt-4o")
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
        }
    }
    
    private var modelFooterText: String {
        switch selectedModel {
        case .appleIntelligence:
            return "Apple Intelligence automatically runs on-device for simple queries and seamlessly escalates to Private Cloud Compute for complex ones. Cryptographically enforced privacy with zero data retention."
        case .appleChatGPT:
            return "Uses ChatGPT via Apple Intelligence. Requires user consent. Data goes to OpenAI but not stored by Apple."
        case .openAIDirect:
            return "Connect directly to OpenAI's API using your own key. You control costs and have access to the latest models."
        case .mock:
            return "For testing only. Generates placeholder responses without real AI."
        }
    }
    
    private func applySettings() async {
        let newService: any LLMService
        
        switch selectedModel {
        case .appleIntelligence:
            if #available(iOS 18.0, *) {
                newService = AppleIntelligenceService()
            } else {
                newService = MockLLMService()
            }
            
        case .appleChatGPT:
            if #available(iOS 18.1, *) {
                // TODO: Implement ChatGPTService when API available
                newService = MockLLMService()
            } else {
                newService = MockLLMService()
            }
            
        case .openAIDirect:
            // TODO: Implement OpenAIService with API key
            newService = MockLLMService()
            
        case .mock:
            newService = MockLLMService()
        }
        
        await ragService.updateLLMService(newService)
    }
}

// MARK: - Model Type Enum

enum LLMModelType: String, CaseIterable {
    case appleIntelligence = "apple_intelligence"  // On-device + PCC automatic
    case appleChatGPT = "chatgpt"
    case openAIDirect = "openai"
    case mock = "mock"
}

// MARK: - Model Info Card

struct ModelInfoCard: View {
    let modelType: LLMModelType
    
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
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var icon: Image {
        switch modelType {
        case .appleIntelligence:
            return Image(systemName: "brain.head.profile")
        case .appleChatGPT:
            return Image(systemName: "bubble.left.and.bubble.right.fill")
        case .openAIDirect:
            return Image(systemName: "key.fill")
        case .mock:
            return Image(systemName: "hammer.fill")
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
            if #available(iOS 18.0, *) {
                return true
            }
            return false
        case .appleChatGPT:
            if #available(iOS 18.1, *) {
                return true
            }
            return false
        case .openAIDirect, .mock:
            return true
        }
    }
    
    private var features: [String] {
        switch modelType {
        case .appleIntelligence:
            return [
                "Automatic on-device/cloud routing",
                "Zero data retention (PCC)",
                "No API key needed",
                "Works offline for simple queries"
            ]
        case .appleChatGPT:
            return [
                "GPT-4 level intelligence",
                "No API key needed",
                "Web-connected knowledge",
                "User consent required"
            ]
        case .openAIDirect:
            return [
                "Your own API key",
                "Latest GPT models",
                "Pay-as-you-go pricing",
                "Full control"
            ]
        case .mock:
            return [
                "For testing only",
                "No real AI",
                "Fast responses",
                "No network required"
            ]
        }
    }
}

// MARK: - About View

struct AboutView: View {
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
            
            Section("Features") {
                FeatureRow(icon: "doc.text.fill", title: "Document Processing", description: "Import PDFs, text files, and more")
                FeatureRow(icon: "cpu", title: "On-Device Processing", description: "OCR, chunking, and embeddings run locally")
                FeatureRow(icon: "brain", title: "Apple Intelligence", description: "Multiple AI pathways for different needs")
                FeatureRow(icon: "lock.shield.fill", title: "Privacy First", description: "Your data stays on your device by default")
            }
            
            Section("Technology") {
                LabeledContent("RAG Pipeline", value: "Semantic search + LLM")
                LabeledContent("Embeddings", value: "NLEmbedding (512-dim)")
                LabeledContent("Vector Store", value: "In-memory cosine similarity")
                LabeledContent("Minimum iOS", value: "18.0")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
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
