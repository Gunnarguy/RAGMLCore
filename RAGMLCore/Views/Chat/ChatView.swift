//
//  ChatView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import SwiftUI
#if canImport(WritingTools)
import WritingTools
#endif

struct ChatView: View {
    @ObservedObject var ragService: RAGService
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var processingStage: ProcessingStage = .idle
    @State private var streamingText = ""
    @State private var executionLocation: ExecutionLocation = .unknown
    @State private var timeToFirstToken: TimeInterval?
    @State private var rewriteSuggestions: [String] = []
    @State private var showingRewriteSuggestions = false
    @State private var showWritingToolsMenu = false
    @State private var isProcessingWritingTools = false
    
    // PERFORMANCE: Pagination and memory management
    @State private var visibleMessageCount: Int = 50  // Show last 50 messages by default
    @State private var shouldAutoScroll = true
    private let maxMessagesInMemory = 200  // Keep max 200 messages, delete older ones
    
    // Writing Tools service
    private let writingToolsService = WritingToolsService()
    
    // Read settings from @AppStorage (synchronized with SettingsView)
    @AppStorage("retrievalTopK") private var retrievalTopK: Int = 3
    @AppStorage("llmTemperature") private var temperature: Double = 0.7
    @AppStorage("llmMaxTokens") private var maxTokens: Int = 500
    @AppStorage("allowPrivateCloudCompute") private var allowPrivateCloudCompute: Bool = true
    @AppStorage("executionContextRaw") private var executionContextRaw: String = "automatic"
    
    @FocusState private var isInputFocused: Bool
    
    // Execution location tracking
    enum ExecutionLocation {
        case unknown
        case onDevice
        case privateCloudCompute
        
        var icon: String {
            switch self {
            case .unknown: return "questionmark.circle"
            case .onDevice: return "iphone"
            case .privateCloudCompute: return "cloud.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .onDevice: return .green
            case .privateCloudCompute: return .blue
            }
        }
        
        var displayName: String {
            switch self {
            case .unknown: return "Detecting..."
            case .onDevice: return "On-Device"
            case .privateCloudCompute: return "Private Cloud"
            }
        }
        
        var badge: String {
            switch self {
            case .unknown: return "🔍"
            case .onDevice: return "📱"
            case .privateCloudCompute: return "☁️"
            }
        }
    }
    
    // Processing stages for visual feedback
    enum ProcessingStage {
        case idle
        case embedding
        case searching
        case generating
        case complete
        
        var description: String {
            switch self {
            case .idle: return ""
            case .embedding: return "🧠 Embedding query..."
            case .searching: return "🔍 Searching knowledge base..."
            case .generating: return "✨ Generating response..."
            case .complete: return "✅ Complete"
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return ""
            case .embedding: return "brain.head.profile"
            case .searching: return "magnifyingglass"
            case .generating: return "sparkles"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }
    
    private var executionContext: ExecutionContext {
        switch executionContextRaw {
        case "automatic": return .automatic
        case "onDeviceOnly": return .onDeviceOnly
        case "preferCloud": return .preferCloud
        case "cloudOnly": return .cloudOnly
        default: return .automatic
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages with optimized rendering
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if messages.isEmpty {
                            EmptyStateView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // PERFORMANCE: Show "Load More" button if there are older messages
                            if messages.count > visibleMessageCount {
                                Button(action: loadMoreMessages) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up.circle.fill")
                                        Text("Load \(min(50, messages.count - visibleMessageCount)) older messages")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(DSColors.surface)
                                    .cornerRadius(16)
                                }
                                .id("loadMore")
                            }
                            
                            // PERFORMANCE: Only render visible messages (last N messages)
                            ForEach(visibleMessages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // Show processing indicator when generating
                            if isProcessing {
                                VStack(spacing: 16) {
                                    // Live telemetry stats overlay
                                    LiveTelemetryStatsView()
                                        .transition(.scale.combined(with: .opacity))
                                    
                                    // Traditional processing indicator (kept for streaming text)
                                    if !streamingText.isEmpty {
                                        StreamingResponseView(
                                            streamingText: streamingText,
                                            executionLocation: executionLocation,
                                            timeToFirstToken: timeToFirstToken
                                        )
                                    }
                                }
                                .id("processing")
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    // PERFORMANCE: Only auto-scroll if we're near the bottom
                    if shouldAutoScroll {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
                .onChange(of: streamingText) {
                    // PERFORMANCE: Throttle scroll during streaming (every 10 chars)
                    if isProcessing && !streamingText.isEmpty && streamingText.count % 10 == 0 {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
                .onTapGesture {
                    // Dismiss keyboard when tapping chat area
                    isInputFocused = false
                }
            }
            
            Divider()
            
            Divider()
            
            // Input area - refined layout
            VStack(spacing: 0) {
                // Document status bar (if docs loaded)
                if ragService.documents.count > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text("\(ragService.documents.count) document\(ragService.documents.count == 1 ? "" : "s") • \(ragService.totalChunksStored) chunks")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(retrievalTopK) chunks per query")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.05))
                }
                
                HStack(alignment: .bottom, spacing: 12) {
                    messageTextField
                    
                    Button(action: sendMessage) {
                        ZStack {
                            Circle()
                                .fill(canSend ? Color.accentColor : Color.gray.opacity(0.3))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: isProcessing ? "stop.fill" : "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(!canSend)
                    .animation(.spring(response: 0.3), value: canSend)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(DSColors.background)
        }
        .navigationTitle("Chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
        #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Writing Tools submenu
                    if writingToolsService.isAvailable {
                        Menu {
                            Button(action: { proofreadInput() }) {
                                Label("Proofread Query", systemImage: "checkmark.circle")
                            }
                            .disabled(inputText.isEmpty || isProcessingWritingTools)
                            
                            Button(action: { rewriteInput() }) {
                                Label("Rewrite Query", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(inputText.isEmpty || isProcessingWritingTools)
                            
                            Button(action: { makeConciseInput() }) {
                                Label("Make Concise", systemImage: "text.badge.minus")
                            }
                            .disabled(inputText.isEmpty || isProcessingWritingTools)
                        } label: {
                            Label("Writing Tools", systemImage: "pencil.and.list.clipboard")
                        }
                        
                        Divider()
                    }
                    
                    Picker("Retrieved Chunks", selection: $retrievalTopK) {
                        Text("3 chunks").tag(3)
                        Text("5 chunks").tag(5)
                        Text("10 chunks").tag(10)
                    }
                    
                    Button(role: .destructive) {
                        clearChat()
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        #else
            ToolbarItem(placement: .automatic) {
                Menu {
                    // Writing Tools submenu
                    if writingToolsService.isAvailable {
                        Menu {
                            Button(action: { proofreadInput() }) {
                                Label("Proofread Query", systemImage: "checkmark.circle")
                            }
                            .disabled(inputText.isEmpty || isProcessingWritingTools)
                            
                            Button(action: { rewriteInput() }) {
                                Label("Rewrite Query", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(inputText.isEmpty || isProcessingWritingTools)
                            
                            Button(action: { makeConciseInput() }) {
                                Label("Make Concise", systemImage: "text.badge.minus")
                            }
                            .disabled(inputText.isEmpty || isProcessingWritingTools)
                        } label: {
                            Label("Writing Tools", systemImage: "pencil.and.list.clipboard")
                        }
                        
                        Divider()
                    }
                    
                    Picker("Retrieved Chunks", selection: $retrievalTopK) {
                        Text("3 chunks").tag(3)
                        Text("5 chunks").tag(5)
                        Text("10 chunks").tag(10)
                    }
                    
                    Button(role: .destructive) {
                        clearChat()
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        #endif
        }
        .onAppear {
            // PERFORMANCE: Cleanup old messages on appear
            cleanupOldMessages()
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
        .confirmationDialog("Choose a rewrite", isPresented: $showingRewriteSuggestions, titleVisibility: .visible) {
            ForEach(rewriteSuggestions, id: \.self) { suggestion in
                Button(suggestion) {
                    inputText = suggestion
                }
            }
            Button("Cancel", role: .cancel) {}
        }

    }

    // PERFORMANCE: Computed property for visible messages slice
    private var visibleMessages: ArraySlice<ChatMessage> {
        let startIndex = max(0, messages.count - visibleMessageCount)
        return messages[startIndex...]
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isProcessing &&
        ragService.isLLMAvailable
    }
    
    // MARK: - Performance Optimizations
    
    /// Load more historical messages (pagination)
    private func loadMoreMessages() {
        withAnimation {
            visibleMessageCount = min(visibleMessageCount + 50, messages.count)
        }
    }
    
    /// Scroll to bottom with optional animation
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        let scroll = {
            if isProcessing {
                proxy.scrollTo("processing", anchor: .bottom)
            } else if let lastMessage = messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
        
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                scroll()
            }
        } else {
            scroll()
        }
    }
    
    /// Cleanup old messages to prevent memory bloat
    private func cleanupOldMessages() {
        if messages.count > maxMessagesInMemory {
            let removeCount = messages.count - maxMessagesInMemory
            messages.removeFirst(removeCount)
            print("🧹 Cleaned up \(removeCount) old messages (keeping last \(maxMessagesInMemory))")
        }
    }
    
    /// Clear all messages
    private func clearChat() {
        messages.removeAll()
        visibleMessageCount = 50
        shouldAutoScroll = true
    }
    
    @ViewBuilder
    private var messageTextField: some View {
        let placeholder = ragService.documents.isEmpty 
            ? "Message AI..." 
            : "Ask about your documents..."
        
        let baseTextField = TextField(placeholder, text: $inputText, axis: .vertical)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DSColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isInputFocused ? Color.accentColor.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
            .focused($isInputFocused)
            .lineLimit(1...6)
            .disabled(isProcessing)
            .animation(.easeInOut(duration: 0.2), value: isInputFocused)
        
        #if canImport(WritingTools)
        if #available(iOS 18.1, *) {
            baseTextField
                .writingToolsEnabled(true)
                .onWritingToolsAction(handleWritingToolsAction(_:))
        } else {
            baseTextField
        }
        #else
        baseTextField
        #endif
    }
    
    private func sendMessage() {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: query)
        messages.append(userMessage)
        
        // PERFORMANCE: Cleanup old messages after adding new ones
        cleanupOldMessages()
        
        inputText = ""
        isProcessing = true
        streamingText = ""
        processingStage = .embedding
        executionLocation = .unknown
        timeToFirstToken = nil
        shouldAutoScroll = true  // Always auto-scroll when user sends message
        
        // Capture necessary values for the detached task
        let capturedQuery = query
        let capturedRagService = ragService
        let capturedRetrievalTopK = retrievalTopK
        let capturedMaxTokens = maxTokens
        let capturedTemperature = temperature
        let capturedExecutionContext = executionContext
        let capturedAllowPCC = allowPrivateCloudCompute
        
        Task(priority: .userInitiated) {
            do {
                // Stage 1: Embedding
                await MainActor.run { [self] in self.processingStage = .embedding }
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3s for visual feedback
                
                // Stage 2: Searching
                await MainActor.run { [self] in self.processingStage = .searching }
                
                // Use settings from SettingsView (synchronized via @AppStorage)
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
                await MainActor.run { [self] in self.processingStage = .generating }
                
                let response = try await capturedRagService.query(capturedQuery, topK: capturedRetrievalTopK, config: config)
                
                // Detect execution location from time to first token
                if let ttft = response.metadata.timeToFirstToken {
                    await MainActor.run { [self] in
                        self.timeToFirstToken = ttft
                        if ttft < 1.0 {
                            self.executionLocation = .onDevice
                        } else {
                            self.executionLocation = .privateCloudCompute
                        }
                    }
                }
                
                // PERFORMANCE: Stream in chunks instead of char-by-char for better performance
                let responseText = response.generatedResponse
                let chunkSize = 10  // Show 10 chars at a time
                let chunks = stride(from: 0, to: responseText.count, by: chunkSize).map {
                    String(responseText[responseText.index(responseText.startIndex, offsetBy: $0)..<responseText.index(responseText.startIndex, offsetBy: min($0 + chunkSize, responseText.count))])
                }
                
                for chunk in chunks {
                    await MainActor.run { [self] in
                        self.streamingText.append(chunk)
                    }
                    try? await Task.sleep(nanoseconds: 20_000_000) // 0.02s per chunk
                }
                
                // Stage 4: Complete
                await MainActor.run { [self] in self.processingStage = .complete }
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2s to show complete state
                
                // Add assistant response
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: response.generatedResponse,
                    metadata: response.metadata,
                    retrievedChunks: response.retrievedChunks
                )
                
                await MainActor.run { [self] in
                    self.messages.append(assistantMessage)
                    self.isProcessing = false
                    self.processingStage = .idle
                    self.streamingText = ""
                    
                    // PERFORMANCE: Cleanup after response
                    self.cleanupOldMessages()
                }
            } catch {
                // Error is already set in RAGService.lastError
                await MainActor.run { [self] in
                    self.isProcessing = false
                    self.processingStage = .idle
                    self.streamingText = ""
                }
            }
        }
    }
    
    // MARK: - Writing Tools Actions
    
    private func proofreadInput() {
        guard !inputText.isEmpty else { return }
        
        isProcessingWritingTools = true
        
        Task {
            do {
                let corrected = try await writingToolsService.proofread(inputText)
                await MainActor.run {
                    inputText = corrected
                    isProcessingWritingTools = false
                }
            } catch {
                print("⚠️ Proofread failed: \(error.localizedDescription)")
                await MainActor.run {
                    isProcessingWritingTools = false
                }
            }
        }
    }
    
    private func rewriteInput() {
        guard !inputText.isEmpty else { return }
        
        isProcessingWritingTools = true
        
        Task {
            do {
                let alternatives = try await writingToolsService.rewrite(inputText, tone: .professional)
                await MainActor.run {
                    rewriteSuggestions = alternatives
                    showingRewriteSuggestions = true
                    isProcessingWritingTools = false
                }
            } catch {
                print("⚠️ Rewrite failed: \(error.localizedDescription)")
                await MainActor.run {
                    isProcessingWritingTools = false
                }
            }
        }
    }
    
    private func makeConciseInput() {
        guard !inputText.isEmpty else { return }
        
        isProcessingWritingTools = true
        
        Task {
            do {
                let concise = try await writingToolsService.makeConcise(inputText)
                await MainActor.run {
                    inputText = concise
                    isProcessingWritingTools = false
                }
            } catch {
                print("⚠️ Make concise failed: \(error.localizedDescription)")
                await MainActor.run {
                    isProcessingWritingTools = false
                }
            }
        }
    }
}

#if canImport(WritingTools)
@available(iOS 18.1, *)
private extension ChatView {
    func handleWritingToolsAction(_ action: WritingToolsAction) {
        switch action {
        case .proofread(let correctedText):
            inputText = correctedText
        case .rewrite(let alternatives):
            rewriteSuggestions = alternatives
            showingRewriteSuggestions = true
        case .summarize(let summary):
            inputText = summary
        @unknown default:
            break
        }
    }
}
#endif


struct MessageBubble: View {
    let message: ChatMessage
    @State private var showingDetails = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            if message.role == .assistant {
                // AI avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // PERFORMANCE: Text selection disabled by default (enable only when needed)
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(messageBubbleBackground)
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(20, corners: message.role == .user 
                        ? [.topLeft, .topRight, .bottomLeft]
                        : [.topLeft, .topRight, .bottomRight])
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                if message.role == .assistant, let metadata = message.metadata {
                    detailsButton
                    
                    if showingDetails {
                        ChatResponseDetailsView(
                            metadata: metadata,
                            retrievedChunks: message.retrievedChunks ?? []
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
    
    // PERFORMANCE: Extract computed properties to reduce body complexity
    @ViewBuilder
    private var messageBubbleBackground: some View {
        if message.role == .user {
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            DSColors.surface
        }
    }
    
    private var detailsButton: some View {
        Button(action: { 
            withAnimation(.spring(response: 0.3)) {
                showingDetails.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: showingDetails ? "chevron.up.circle.fill" : "info.circle.fill")
                Text(showingDetails ? "Hide" : "Details")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

#if canImport(UIKit)
// Custom corner radius modifier (UIKit path with per-corner support)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#else
// macOS fallback: provide a compatible UIRectCorner and uniform rounded rectangle
struct UIRectCorner: OptionSet {
    let rawValue: Int
    static let topLeft     = UIRectCorner(rawValue: 1 << 0)
    static let topRight    = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft  = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        // Note: Per-corner rounding not natively supported here; using uniform rounding fallback
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}
#endif

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
            .background(DSColors.surface)
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

private struct MetricRow: View {
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

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .blue.opacity(0.2)],
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
            
            VStack(spacing: 12) {
                Text("Ready to Chat")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Ask anything or load documents for context-aware RAG responses")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ChatFeatureRow(
                    icon: "brain.head.profile",
                    title: "Semantic Search",
                    description: "Find relevant context across your documents"
                )
                
                ChatFeatureRow(
                    icon: "sparkles",
                    title: "AI Generation",
                    description: "Get accurate answers powered by your data"
                )
                
                ChatFeatureRow(
                    icon: "lock.shield",
                    title: "Privacy First",
                    description: "On-device or Private Cloud Compute"
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ChatFeatureRow: View {
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

struct StreamingResponseView: View {
    let streamingText: String
    let executionLocation: ChatView.ExecutionLocation
    let timeToFirstToken: TimeInterval?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // AI Avatar
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 10) {
                // Execution Location Badge
                if executionLocation != .unknown {
                    HStack(spacing: 6) {
                        Image(systemName: executionLocation.icon)
                            .font(.caption2)
                            .foregroundColor(executionLocation.color)
                        
                        Text(executionLocation.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(executionLocation.color)
                        
                        if let ttft = timeToFirstToken {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(String(format: "%.2fs", ttft))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(executionLocation.color.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Streaming text bubble
                VStack(alignment: .leading, spacing: 8) {
                    Text(streamingText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                    
                    // Typing indicator
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.accentColor.opacity(0.6))
                                .frame(width: 6, height: 6)
                                .scaleEffect(typingDotScale(for: index))
                                .animation(
                                    Animation
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: streamingText.count
                                )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DSColors.surface)
                .cornerRadius(20, corners: [.topLeft, .topRight, .bottomRight])
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 8)
    }
    
    private func typingDotScale(for index: Int) -> CGFloat {
        let phase = (Double(streamingText.count) / 10.0) + Double(index) * 0.3
        return 1.0 + 0.5 * sin(phase)
    }
}

#Preview {
    ChatView(ragService: RAGService())
}
