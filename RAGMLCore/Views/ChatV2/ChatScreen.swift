//
//  ChatScreen.swift
//  RAGMLCore
//
//  Created by Cline on 10/28/25.
//

import SwiftUI

// ChatV2 entry point (feature-flagged from ContentView)
struct ChatScreen: View {
    @ObservedObject var ragService: RAGService
    @AppStorage("retrievalTopK") private var retrievalTopK: Int = 3
    @State private var showScrollToBottom: Bool = false
    @State private var messages: [ChatMessage] = []
    @State private var streamingText: String = ""
    
    // Processing State
    @State private var isProcessing: Bool = false
    @State private var stage: ChatProcessingStage = .idle
    @State private var execution: ChatExecutionLocation = .unknown
    @State private var ttft: TimeInterval?
    
    // Settings (synchronized with SettingsView via @AppStorage)
    @AppStorage("llmTemperature") private var temperature: Double = 0.7
    @AppStorage("llmMaxTokens") private var maxTokens: Int = 500
    @AppStorage("allowPrivateCloudCompute") private var allowPrivateCloudCompute: Bool = true
    @AppStorage("executionContextRaw") private var executionContextRaw: String = "automatic"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeader(onNewChat: { newChat() }, onClearChat: { clearChat() })

            // Context / Status Bar
            ContextStatusBarView(
                docCount: ragService.documents.count,
                chunkCount: ragService.totalChunksStored,
                retrievalTopK: retrievalTopK
            )

            Divider()

            // Message list
            MessageListView(messages: $messages)
            
            // Streaming row (verbose but clean)
            if isProcessing && !streamingText.isEmpty {
                HStack(alignment: .top, spacing: DSSpacing.xs) {
                    AvatarView(kind: .assistant)
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        Text(streamingText)
                            .font(DSTypography.body)
                            .foregroundColor(DSColors.primaryText)
                            .padding(.horizontal, DSSpacing.sm)
                            .padding(.vertical, DSSpacing.sm)
                            .background(DSColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: DSCorners.bubble, style: .continuous))
                            .bubbleShadow()
                        TypingIndicator()
                    }
                    Spacer(minLength: 48)
                }
                .padding(.horizontal, DSSpacing.md)
                .transition(.opacity.combined(with: .scale))
            }
            
            // Live telemetry strip during generation
            if isProcessing {
                LiveTelemetryStatsView()
            }
            
            // Stage indicator + execution badge
            StageProgressBar(stage: stage, execution: execution, ttft: ttft)

            Divider()

            // Composer (will evolve with Writing Tools and actions)
            ChatComposer(
                isProcessing: isProcessing,
                onSend: sendMessage
            )
        }
        .navigationTitle("Chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    // MARK: - Execution Context mapping
    private var executionContext: ExecutionContext {
        switch executionContextRaw {
        case "automatic": return .automatic
        case "onDeviceOnly": return .onDeviceOnly
        case "preferCloud": return .preferCloud
        case "cloudOnly": return .cloudOnly
        default: return .automatic
        }
    }
    
    // MARK: - Send Message
    private func newChat() {
        messages.removeAll()
        isProcessing = false
        stage = .idle
        execution = .unknown
        ttft = nil
        streamingText = ""
    }
    
    private func clearChat() {
        messages.removeAll()
        streamingText = ""
    }
    
    private func sendMessage(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        // Append user message
        let userMessage = ChatMessage(role: .user, content: query)
        messages.append(userMessage)
        
        // Reset and start processing
        isProcessing = true
        stage = .embedding
        execution = .unknown
        ttft = nil
        
        // Capture values for async task
        let capturedQuery = query
        let capturedTopK = retrievalTopK
        let capturedMaxTokens = maxTokens
        let capturedTemperature = temperature
        let capturedExecutionContext = executionContext
        let capturedAllowPCC = allowPrivateCloudCompute
        let capturedService = ragService
        
        Task(priority: .userInitiated) {
            do {
                // Stage 1: Embedding
                await MainActor.run { self.stage = .embedding }
                try? await Task.sleep(nanoseconds: 250_000_000)
                
                // Stage 2: Searching
                await MainActor.run { self.stage = .searching }
                
                let config = InferenceConfig(
                    maxTokens: capturedMaxTokens,
                    temperature: Float(capturedTemperature),
                    topP: 0.9,
                    topK: 40,
                    useKVCache: true,
                    executionContext: capturedExecutionContext,
                    allowPrivateCloudCompute: capturedAllowPCC
                )
                
                // Stage 3: Generating
                await MainActor.run { self.stage = .generating }
                
                let response = try await capturedService.query(capturedQuery, topK: capturedTopK, config: config)
                
                // Simulated streaming of the full response in chunks for a responsive UI
                let responseText = response.generatedResponse
                let chunkSize = 12
                for i in stride(from: 0, to: responseText.count, by: chunkSize) {
                    let start = responseText.index(responseText.startIndex, offsetBy: i)
                    let end = responseText.index(responseText.startIndex, offsetBy: min(i + chunkSize, responseText.count))
                    let chunk = String(responseText[start..<end])
                    await MainActor.run { self.streamingText.append(chunk) }
                    try? await Task.sleep(nanoseconds: 20_000_000) // 0.02s per chunk
                }
                
                // Update execution badge based on TTFT heuristic
                if let first = response.metadata.timeToFirstToken {
                    await MainActor.run {
                        self.ttft = first
                        self.execution = first < 1.0 ? .onDevice : .privateCloudCompute
                    }
                }
                
                let assistant = ChatMessage(
                    role: .assistant,
                    content: response.generatedResponse,
                    metadata: response.metadata,
                    retrievedChunks: response.retrievedChunks
                )
                
                await MainActor.run {
                    self.messages.append(assistant)
                    self.stage = .complete
                }
                
                try? await Task.sleep(nanoseconds: 200_000_000)
                
                await MainActor.run {
                    self.isProcessing = false
                    self.stage = .idle
                    self.streamingText = ""
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.stage = .idle
                }
            }
        }
    }
}

// MARK: - Header

struct ChatHeader: View {
    let onNewChat: () -> Void
    let onClearChat: () -> Void
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Chat")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()

            Menu {
                Button {
                    onNewChat()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                Button(role: .destructive) {
                    onClearChat()
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Context / Status Bar

struct ContextStatusBarView: View {
    let docCount: Int
    let chunkCount: Int
    let retrievalTopK: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.caption2)
                .foregroundColor(.green)

            Text("\(docCount) document\(docCount == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("\(chunkCount) chunks")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Text("\(retrievalTopK) chunks/query")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.05))
    }
}

// MARK: - Optional Placeholder (not used, kept for reference)

struct MessageListEmptyContent: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.15), .blue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("New Chat UI (V2)")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("A modern, modular interface is being enabled behind a feature flag. This is the initial scaffold.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ChatV2FeatureRow(icon: "brain.head.profile", title: "Semantic Search", description: "Context-aware retrieval from your documents.")
                    ChatV2FeatureRow(icon: "sparkles", title: "AI Generation", description: "Grounded answers with clear citations.")
                    ChatV2FeatureRow(icon: "lock.shield", title: "Privacy First", description: "On-Device or Private Cloud Compute.")
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

struct ChatV2FeatureRow: View {
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
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Composer Placeholder (legacy stub, not used in flow)

struct ComposerStub: View {
    @State private var text: String = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message AI...", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DSColors.surface)
                )

            Button {
                // Send (disabled in scaffold)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 36)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .disabled(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DSColors.background)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ChatScreen(ragService: RAGService())
    }
    #if os(iOS)
    .navigationViewStyle(.stack)
    #endif
}
