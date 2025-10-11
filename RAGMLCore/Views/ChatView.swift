//
//  ChatView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var ragService: RAGService
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    
    // Read settings from @AppStorage (synchronized with SettingsView)
    @AppStorage("retrievalTopK") private var retrievalTopK: Int = 3
    @AppStorage("llmTemperature") private var temperature: Double = 0.7
    @AppStorage("llmMaxTokens") private var maxTokens: Int = 500
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if messages.isEmpty {
                                EmptyStateView()
                            } else {
                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onTapGesture {
                        // Dismiss keyboard when tapping chat area
                        isInputFocused = false
                    }
                }
                
                Divider()
                
                // Input area
                HStack(spacing: 12) {
                    TextField(ragService.documents.isEmpty ? "Chat with AI (no documents loaded)..." : "Ask a question about your documents...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .disabled(isProcessing)
                    
                    // Show keyboard dismiss button when keyboard is visible
                    if isInputFocused {
                        Button(action: {
                            isInputFocused = false
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(canSend ? .accentColor : .gray)
                    }
                    .disabled(!canSend)
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
            }
            .navigationTitle("RAG Chat")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Keyboard dismiss button in toolbar (appears when keyboard is up)
                    if isInputFocused {
                        Button(action: {
                            isInputFocused = false
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Retrieved Chunks", selection: $retrievalTopK) {
                            Text("3 chunks").tag(3)
                            Text("5 chunks").tag(5)
                            Text("10 chunks").tag(10)
                        }
                        
                        Button(role: .destructive) {
                            messages.removeAll()
                        } label: {
                            Label("Clear Chat", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Query Error", isPresented: .constant(ragService.lastError != nil)) {
                Button("OK", role: .cancel) {
                    ragService.lastError = nil
                }
            } message: {
                if let error = ragService.lastError {
                    Text(error)
                }
            }
        }
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isProcessing &&
        ragService.isLLMAvailable
    }
    
    private func sendMessage() {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: query)
        messages.append(userMessage)
        
        inputText = ""
        isProcessing = true
        
        Task {
            do {
                // Use settings from SettingsView (synchronized via @AppStorage)
                let config = InferenceConfig(
                    maxTokens: maxTokens,
                    temperature: Float(temperature)
                )
                
                let response = try await ragService.query(query, topK: retrievalTopK, config: config)
                
                // Add assistant response
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: response.generatedResponse,
                    metadata: response.metadata,
                    retrievedChunks: response.retrievedChunks
                )
                
                await MainActor.run {
                    messages.append(assistantMessage)
                    isProcessing = false
                }
            } catch {
                // Error is already set in RAGService.lastError
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    var metadata: ResponseMetadata?
    var retrievedChunks: [RetrievedChunk]?
    
    enum Role {
        case user
        case assistant
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showingDetails = false
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.accentColor : Color(uiColor: .systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
                if message.role == .assistant, let metadata = message.metadata {
                    Button(action: { showingDetails.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                            Text(showingDetails ? "Hide Details" : "Show Details")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    if showingDetails {
                        ResponseDetailsView(
                            metadata: metadata,
                            retrievedChunks: message.retrievedChunks ?? []
                        )
                    }
                }
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

struct ResponseDetailsView: View {
    let metadata: ResponseMetadata
    let retrievedChunks: [RetrievedChunk]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            performanceMetricsSection
            
            if !retrievedChunks.isEmpty {
                retrievedContextSection
            }
        }
    }
    
    // MARK: - Performance Metrics Section
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .foregroundColor(.blue)
                Text("Performance Metrics")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            metricsRows
        }
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var metricsRows: some View {
        VStack(spacing: 4) {
            DetailMetricRow(
                icon: "cpu",
                label: "Model",
                value: metadata.modelUsed,
                color: .purple
            )
            
            DetailMetricRow(
                icon: "magnifyingglass",
                label: "Retrieval Time",
                value: String(format: "%.0f ms", metadata.retrievalTime * 1000),
                color: .green
            )
            
            DetailMetricRow(
                icon: "text.bubble",
                label: "Generation Time",
                value: String(format: "%.2f s", metadata.totalGenerationTime),
                color: .orange
            )
            
            DetailMetricRow(
                icon: "number",
                label: "Tokens Generated",
                value: "\(metadata.tokensGenerated)",
                color: .cyan
            )
            
            if let tps = metadata.tokensPerSecond {
                DetailMetricRow(
                    icon: "speedometer",
                    label: "Generation Speed",
                    value: String(format: "%.1f tok/s", tps),
                    color: .red
                )
            }
        }
    }
    
    // MARK: - Retrieved Context Section
    private var retrievedContextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            retrievedContextHeader
            
            ForEach(Array(retrievedChunks.enumerated()), id: \.offset) { index, chunk in
                chunkView(chunk: chunk, index: index)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var retrievedContextHeader: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundColor(.green)
            Text("Retrieved Context")
                .font(.caption)
                .fontWeight(.semibold)
            Spacer()
            Text("\(retrievedChunks.count) chunks")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func chunkView(chunk: RetrievedChunk, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            chunkHeader(chunk: chunk, index: index)
            chunkContentPreview(chunk: chunk)
            chunkMetadata(chunk: chunk)
        }
        .padding(10)
        .background(Color.green.opacity(0.03))
        .cornerRadius(10)
    }
    
    private func chunkHeader(chunk: RetrievedChunk, index: Int) -> some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "sparkle")
                    .font(.caption2)
                    .foregroundColor(similarityColor(Double(chunk.similarityScore)))
                Text("Chunk \(index + 1)")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            similarityIndicator(score: Double(chunk.similarityScore))
        }
    }
    
    private func similarityIndicator(score: Double) -> some View {
        HStack(spacing: 4) {
            Text(String(format: "%.1f%%", score * 100))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(similarityColor(score))
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(similarityColor(score))
                        .frame(width: geo.size.width * CGFloat(score))
                }
            }
            .frame(width: 40, height: 4)
            .cornerRadius(2)
        }
    }
    
    private func chunkContentPreview(chunk: RetrievedChunk) -> some View {
        let preview = chunk.chunk.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let displayText = preview.count > 150 ? preview.prefix(150) + "..." : preview
        
        return Text(displayText)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(8)
    }
    
    private func chunkMetadata(chunk: RetrievedChunk) -> some View {
        HStack(spacing: 12) {
            Label("\(chunk.chunk.content.count) chars", systemImage: "text.alignleft")
            Label("\(chunk.chunk.content.split(separator: " ").count) words", systemImage: "textformat")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    
    private func similarityColor(_ score: Double) -> Color {
        if score >= 0.8 {
            return .green
        } else if score >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

struct DetailMetricRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Start a Conversation")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Ask questions and get AI-powered answers.\n\n💡 Add documents for context-aware responses with RAG.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ChatView(ragService: RAGService())
}
