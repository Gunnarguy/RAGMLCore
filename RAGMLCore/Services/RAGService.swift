//
//  RAGService.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import Foundation
import Combine
import NaturalLanguage

/// Main orchestrator for the RAG (Retrieval-Augmented Generation) pipeline
/// Coordinates document processing, embedding, retrieval, and generation
class RAGService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let documentProcessor: DocumentProcessor
    private let embeddingService: EmbeddingService
    private let vectorDatabase: VectorDatabase
    
    // MARK: - Published State
    
    @Published var documents: [Document] = []
    @Published var isProcessing: Bool = false
    @Published var processingStatus: String = ""
    @Published var lastError: String? = nil // User-facing error message
    @Published var lastProcessingSummary: ProcessingSummary? = nil // Detailed completion stats
    
    private(set) var totalChunksStored: Int = 0
    
    // MARK: - Public Access (for Settings)
    
    var llmService: LLMService {
        return _llmService
    }
    
    private var _llmService: LLMService
    
    // MARK: - Initialization
    
    init(
        documentProcessor: DocumentProcessor = DocumentProcessor(),
        embeddingService: EmbeddingService = EmbeddingService(),
        vectorDatabase: VectorDatabase = InMemoryVectorDatabase(),
        llmService: LLMService? = nil
    ) {
        self.documentProcessor = documentProcessor
        self.embeddingService = embeddingService
        self.vectorDatabase = vectorDatabase
        
        // Priority order for LLM selection:
        // 1. Custom service provided by caller
        // 2. OpenAI Direct (if API key configured)
        // 3. Apple ChatGPT Extension (iOS 18.1+ with user consent)
        // 4. On-Device Analysis (extractive QA, always available)
        
        if let service = llmService {
            // User provided custom service (e.g., from Settings)
            self._llmService = service
            print("✓ Using custom LLM service: \(service.modelName)")
        } else {
            // Priority order for automatic LLM selection:
            // 1. Apple Foundation Models (iOS 26+, on-device + PCC)
            // 2. OpenAI Direct API (user's key)
            // 3. Apple ChatGPT Extension (iOS 18.1+)
            // 4. On-Device Analysis (extractive QA, always available)
            
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *),
               AppleFoundationLLMService().isAvailable {
                // Priority 1: Apple's Foundation Models with on-device + PCC
                self._llmService = AppleFoundationLLMService()
                print("✓ Using Apple Foundation Models (on-device + PCC)")
            } else if let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey"),
                      !apiKey.isEmpty {
                // Priority 2: OpenAI Direct API with user's key
                let selectedModel = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o-mini"
                self._llmService = OpenAILLMService(apiKey: apiKey, model: selectedModel)
                print("✓ Using OpenAI Direct: \(selectedModel)")
            } else {
                // Priority 3: On-Device Analysis (extractive QA, no AI model needed)
                self._llmService = OnDeviceAnalysisService()
                print("✓ Using On-Device Analysis (extractive QA)")
                print("   💡 For AI generation, add OpenAI API key in Settings or upgrade to iOS 26")
            }
            #else
            if let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey"),
               !apiKey.isEmpty {
                // Priority 2: OpenAI Direct API with user's key
                let selectedModel = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o-mini"
                self._llmService = OpenAILLMService(apiKey: apiKey, model: selectedModel)
                print("✓ Using OpenAI Direct: \(selectedModel)")
            } else {
                // Priority 3: On-Device Analysis (extractive QA, no AI model needed)
                self._llmService = OnDeviceAnalysisService()
                print("✓ Using On-Device Analysis (extractive QA)")
                print("   💡 For AI generation, add OpenAI API key in Settings")
            }
            #endif
        }
    }
    
    // MARK: - LLM Service Management
    
    /// Dynamically updates the LLM service (called from Settings)
    func updateLLMService(_ newService: LLMService) async {
        await MainActor.run {
            self._llmService = newService
            print("✓ Switched to: \(newService.modelName)")
        }
    }
    
    // MARK: - Document Management
    
    /// Add a document to the knowledge base
    /// This performs the full ingestion pipeline: parse → chunk → embed → store
    func addDocument(at url: URL) async throws {
        let filename = url.lastPathComponent
        let pipelineStartTime = Date()
        
        await MainActor.run {
            isProcessing = true
            processingStatus = "\(filename) • Loading"
        }
        
        // Give UI time to show the overlay (testing delay)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 full second
        
        // Set up progress handler for real-time updates
        documentProcessor.progressHandler = { [weak self] progress in
            Task { @MainActor in
                self?.processingStatus = "\(filename) • Extracting (\(progress))"
            }
        }
        
        do {
            // Step 1: Parse document and extract chunks
            let extractionStartTime = Date()
            let (document, textChunks) = try await documentProcessor.processDocument(at: url)
            let extractionTime = Date().timeIntervalSince(extractionStartTime)
            
            let totalChars = textChunks.reduce(0) { $0 + $1.count }
            let totalWords = textChunks.reduce(0) { $0 + $1.split(separator: " ").count }
            
            await MainActor.run {
                processingStatus = "\(filename) • Chunking (\(textChunks.count) chunks, \(totalWords) words)"
            }
            
            print("\n🔢 [RAGService] Chunking complete:")
            print("   \(textChunks.count) chunks, \(totalChars) chars, \(totalWords) words")
            
            // Small delay to show the chunking message
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            
            // Step 2: Generate embeddings with progress updates
            print("\n🧠 [RAGService] Generating embeddings...")
            var embeddings: [[Float]] = []
            let embeddingStartTime = Date()
            
            for (index, text) in textChunks.enumerated() {
                await MainActor.run {
                    processingStatus = "\(filename) • Embedding (\(index + 1)/\(textChunks.count))"
                }
                
                let chunkStartTime = Date()
                let embedding = try await embeddingService.generateEmbedding(for: text)
                let chunkTime = Date().timeIntervalSince(chunkStartTime)
                
                embeddings.append(embedding)
                print("   ✓ Chunk \(index + 1)/\(textChunks.count): \(embedding.count)-dim vector (\(String(format: "%.0f", chunkTime * 1000))ms)")
            }
            
            let embeddingTime = Date().timeIntervalSince(embeddingStartTime)
            let avgTimePerChunk = embeddingTime / Double(textChunks.count)
            print("   ✅ All embeddings generated in \(String(format: "%.2f", embeddingTime))s (avg \(String(format: "%.0f", avgTimePerChunk * 1000))ms/chunk)")
            
            await MainActor.run {
                processingStatus = "\(filename) • Storing"
            }
            
            // Step 3: Create DocumentChunk objects with embeddings
            let chunkingStartTime = Date()
            let documentChunks = zip(textChunks, embeddings).enumerated().map { index, pair in
                let (text, embedding) = pair
                return DocumentChunk(
                    documentId: document.id,
                    content: text,
                    embedding: embedding,
                    metadata: ChunkMetadata(
                        chunkIndex: index,
                        startPosition: 0, // Could be enhanced with actual positions
                        endPosition: text.count
                    )
                )
            }
            let chunkingTime = Date().timeIntervalSince(chunkingStartTime)
            
            // Step 4: Store chunks in vector database
            try await vectorDatabase.storeBatch(chunks: documentChunks)
            
            // Calculate total pipeline time
            let totalTime = Date().timeIntervalSince(pipelineStartTime)
            
            // Calculate chunk statistics
            let chunkSizes = textChunks.map { $0.count }
            let avgChunkSize = chunkSizes.reduce(0, +) / chunkSizes.count
            let minChunkSize = chunkSizes.min() ?? 0
            let maxChunkSize = chunkSizes.max() ?? 0
            
            // Get file size
            let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
            let fileSizeMB: Double
            let fileSizeStr: String
            if let size = fileSize {
                fileSizeMB = Double(size) / (1024.0 * 1024.0)
                if size < 1024 {
                    fileSizeStr = "\(size) B"
                } else if size < 1024 * 1024 {
                    fileSizeStr = String(format: "%.2f KB", Double(size) / 1024.0)
                } else {
                    fileSizeStr = String(format: "%.2f MB", fileSizeMB)
                }
            } else {
                fileSizeMB = 0
                fileSizeStr = "Unknown"
            }
            
            // Update document with embedding time and complete metadata
            var updatedDocument = document
            if let existingMetadata = document.processingMetadata {
                // Create new metadata with embedding time added
                let completeMetadata = ProcessingMetadata(
                    fileSizeMB: fileSizeMB,
                    totalCharacters: existingMetadata.totalCharacters,
                    totalWords: existingMetadata.totalWords,
                    extractionTimeSeconds: existingMetadata.extractionTimeSeconds,
                    chunkingTimeSeconds: existingMetadata.chunkingTimeSeconds,
                    embeddingTimeSeconds: embeddingTime,
                    totalProcessingTimeSeconds: totalTime,
                    pagesProcessed: existingMetadata.pagesProcessed,
                    ocrPagesCount: existingMetadata.ocrPagesCount,
                    chunkStats: existingMetadata.chunkStats
                )
                
                updatedDocument = Document(
                    id: document.id,
                    filename: document.filename,
                    fileURL: document.fileURL,
                    contentType: document.contentType,
                    addedAt: document.addedAt,
                    totalChunks: document.totalChunks,
                    processingMetadata: completeMetadata
                )
            }
            
            // Create processing summary
            let summary = ProcessingSummary(
                filename: filename,
                fileSize: fileSizeStr,
                documentType: document.contentType,
                pageCount: nil, // TODO: Extract from DocumentProcessor
                ocrPagesUsed: nil, // TODO: Extract from DocumentProcessor
                totalChars: totalChars,
                totalWords: totalWords,
                chunksCreated: textChunks.count,
                extractionTime: extractionTime,
                chunkingTime: chunkingTime,
                embeddingTime: embeddingTime,
                totalTime: totalTime,
                chunkStats: ProcessingSummary.ChunkStatistics(
                    avgChars: avgChunkSize,
                    minChars: minChunkSize,
                    maxChars: maxChunkSize
                )
            )
            
            // Step 5: Update state
            await MainActor.run {
                documents.append(updatedDocument)
                totalChunksStored += documentChunks.count
                processingStatus = ""
                lastProcessingSummary = summary
            }
            
            // Small success flash
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            await MainActor.run {
                isProcessing = false
            }
            
            print("✅ [RAGService] Document ingestion complete:")
            print("   Filename: \(updatedDocument.filename)")
            print("   Chunks created: \(textChunks.count)")
            print("   Total chunks in database: \(totalChunksStored)")

            
        } catch {
            // Reset processing state on error
            await MainActor.run {
                isProcessing = false
                processingStatus = ""
                
                // Set user-friendly error message
                lastError = error.localizedDescription
            }
            
            // Re-throw with context
            print("❌ [RAGService] Failed to add document: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Remove a document from the knowledge base
    func removeDocument(_ document: Document) async throws {
        try await vectorDatabase.deleteChunks(forDocument: document.id)
        
        await MainActor.run {
            documents.removeAll { $0.id == document.id }
            totalChunksStored -= document.totalChunks
        }
        
        print("✓ Removed document: \(document.filename)")
    }
    
    /// Clear all documents from the knowledge base
    func clearAllDocuments() async throws {
        try await vectorDatabase.clear()
        
        await MainActor.run {
            documents.removeAll()
            totalChunksStored = 0
        }
        
        print("✓ Cleared all documents from knowledge base")
    }
    
    // MARK: - RAG Query Pipeline
    
    /// Execute a RAG query: embed query → retrieve context → generate response
    func query(_ question: String, topK: Int = 3, config: InferenceConfig? = nil) async throws -> RAGResponse {
        let inferenceConfig = config ?? InferenceConfig()
        
        print("\n╔══════════════════════════════════════════════════════════════╗")
        print("║ RAG QUERY PIPELINE                                           ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print("\n📝 Query: \(question)")
        print("🎯 Retrieving top \(topK) chunks from \(totalChunksStored) total")
        
        do {
            // Clear any previous errors
            await MainActor.run {
                lastError = nil
            }
            
            // Edge case: Empty query
            guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("❌ [RAGService] Empty query string")
                throw RAGServiceError.emptyQuery
            }
            
            let pipelineStartTime = Date()
            let ragQuery = RAGQuery(query: question, topK: topK)
            
            // Check if we have documents for RAG or just direct LLM chat
            let hasDocuments = totalChunksStored > 0
            
            if hasDocuments {
                // Full RAG pipeline with document retrieval
                // Step 1: Embed the user's query
                print("\n━━━ Step 1: Query Embedding ━━━")
                let embeddingStartTime = Date()
                let queryEmbedding = try await embeddingService.generateEmbedding(for: question)
                let embeddingTime = Date().timeIntervalSince(embeddingStartTime)
            
                let embeddingMagnitude = sqrt(queryEmbedding.map { $0 * $0 }.reduce(0, +))
                print("✓ Generated \(queryEmbedding.count)-dimensional embedding")
                print("  Vector magnitude: \(String(format: "%.4f", embeddingMagnitude))")
                print("  Time: \(String(format: "%.0f", embeddingTime * 1000))ms")
                
                // Step 2: Retrieve most similar chunks from vector database
                print("\n━━━ Step 2: Vector Search ━━━")
                let retrievalStartTime = Date()
                let retrievedChunks = try await vectorDatabase.search(embedding: queryEmbedding, topK: topK)
                let retrievalTime = Date().timeIntervalSince(retrievalStartTime)
                
                // Edge case: No relevant chunks found (shouldn't happen with proper database)
                guard !retrievedChunks.isEmpty else {
                    print("⚠️  [RAGService] No chunks retrieved (database may be empty)")
                    throw RAGServiceError.retrievalFailed
                }
                
                print("✓ Retrieved \(retrievedChunks.count) chunks in \(String(format: "%.0f", retrievalTime * 1000))ms")
                print("\nRetrieved chunks (ranked by similarity):")
                for (index, chunk) in retrievedChunks.enumerated() {
                    let preview = chunk.chunk.content.prefix(80).replacingOccurrences(of: "\n", with: " ")
                    print("  [\(index + 1)] Score: \(String(format: "%.4f", chunk.similarityScore))")
                    print("      \"\(preview)...\"\n")
                }
                
                // Step 3: Construct context from retrieved chunks
                let rawContext = formatContext(retrievedChunks)
                
                // Smart context truncation for Apple Intelligence (limited context window ~4K chars)
                let maxContextChars = 3500  // Leave room for prompt + response
                let context: String
                if rawContext.count > maxContextChars {
                    print("\n⚠️  Context too large (\(rawContext.count) chars), truncating to \(maxContextChars) chars")
                    // Take only the top-ranked chunks until we hit the limit
                    var truncatedContext = ""
                    var chunkCount = 0
                    for retrieved in retrievedChunks {
                        let chunkText = "Document excerpt (relevance: \(String(format: "%.2f", retrieved.similarityScore))):\n\(retrieved.chunk.content)\n\n"
                        if truncatedContext.count + chunkText.count <= maxContextChars {
                            truncatedContext += chunkText
                            chunkCount += 1
                        } else {
                            break
                        }
                    }
                    context = truncatedContext
                    print("✓ Using top \(chunkCount) chunks (\(context.count) chars)")
                } else {
                    context = rawContext
                }
                
                let contextSize = context.count
                let contextWords = context.split(separator: " ").count
                
                print("━━━ Step 3: Context Assembly ━━━")
                print("✓ Assembled context: \(contextSize) chars, \(contextWords) words")
                
                // Step 4: Generate response using LLM with augmented context
                print("\n━━━ Step 4: LLM Generation ━━━")
                let generationStartTime = Date()
                let llmResponse = try await llmService.generate(
                    prompt: question,
                    context: context,
                    config: inferenceConfig
                )
                let generationTime = Date().timeIntervalSince(generationStartTime)
                
                print("✓ Response generated")
                print("  Model: \(llmService.modelName)")
                print("  Generation time: \(String(format: "%.2f", generationTime))s")
                print("  Tokens: \(llmResponse.tokensGenerated)")
                print("  Speed: \(String(format: "%.1f", llmResponse.tokensPerSecond ?? 0)) tokens/sec")
                
                // Step 5: Package results
                let pipelineTotalTime = Date().timeIntervalSince(pipelineStartTime)
                
                print("\n╔══════════════════════════════════════════════════════════════╗")
                print("║ PIPELINE COMPLETE ✓                                          ║")
                print("╚══════════════════════════════════════════════════════════════╝")
                print("Total time: \(String(format: "%.2f", pipelineTotalTime))s")
                print("  - Embedding: \(String(format: "%.0f", embeddingTime * 1000))ms")
                print("  - Retrieval: \(String(format: "%.0f", retrievalTime * 1000))ms")
                print("  - Generation: \(String(format: "%.2f", generationTime))s")
                print("")
                
                let metadata = ResponseMetadata(
                    timeToFirstToken: llmResponse.timeToFirstToken,
                    totalGenerationTime: llmResponse.totalTime,
                    tokensGenerated: llmResponse.tokensGenerated,
                    tokensPerSecond: llmResponse.tokensPerSecond,
                    modelUsed: llmService.modelName,
                    retrievalTime: retrievalTime
                )
                
                let response = RAGResponse(
                    queryId: ragQuery.id,
                    retrievedChunks: retrievedChunks,
                    generatedResponse: llmResponse.text,
                    metadata: metadata
                )
                
                let totalTime = Date().timeIntervalSince(pipelineStartTime)
                print("✅ [RAGService] RAG pipeline complete in \(String(format: "%.2f", totalTime))s")
                printQueryStats(query: question, response: response)
                
                return response
                
            } else {
                // Direct LLM chat without documents
                print("ℹ️  No documents loaded - using direct LLM chat mode")
                
                print("\n━━━ Direct LLM Generation (No RAG) ━━━")
                let generationStartTime = Date()
                let llmResponse = try await llmService.generate(
                    prompt: question,
                    context: nil,  // No document context
                    config: inferenceConfig
                )
                let generationTime = Date().timeIntervalSince(generationStartTime)
                
                print("✓ Response generated")
                print("  Model: \(llmService.modelName)")
                print("  Generation time: \(String(format: "%.2f", generationTime))s")
                print("  Tokens: \(llmResponse.tokensGenerated)")
                print("  Speed: \(String(format: "%.1f", llmResponse.tokensPerSecond ?? 0)) tokens/sec")
                
                let metadata = ResponseMetadata(
                    timeToFirstToken: llmResponse.timeToFirstToken,
                    totalGenerationTime: llmResponse.totalTime,
                    tokensGenerated: llmResponse.tokensGenerated,
                    tokensPerSecond: llmResponse.tokensPerSecond,
                    modelUsed: llmService.modelName,
                    retrievalTime: 0  // No retrieval in direct chat mode
                )
                
                let response = RAGResponse(
                    queryId: ragQuery.id,
                    retrievedChunks: [],  // No chunks in direct chat mode
                    generatedResponse: llmResponse.text,
                    metadata: metadata
                )
                
                let totalTime = Date().timeIntervalSince(pipelineStartTime)
                print("✅ [RAGService] Direct chat complete in \(String(format: "%.2f", totalTime))s\n")
                
                return response
            }
            
        } catch {
            // Set user-friendly error message
            await MainActor.run {
                // Make error messages more user-friendly
                if error.localizedDescription.contains("No embedding vectors were returned") {
                    lastError = "Could not understand your query. Try using common words or longer phrases (e.g., 'What is the document about?')"
                } else {
                    lastError = error.localizedDescription
                }
            }
            
            print("❌ [RAGService] Query failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Model Management
    
    /// Switch to a different LLM implementation
    /// Note: Use updateLLMService() for async/MainActor-safe switching
    func switchModel(to service: LLMService) async {
        await MainActor.run {
            self._llmService = service
            print("✓ Switched to model: \(service.modelName)")
        }
    }
    
    /// Check if the current LLM is available
    var isLLMAvailable: Bool {
        llmService.isAvailable
    }
    
    var currentModelName: String {
        llmService.modelName
    }
    
    // MARK: - Private Helpers
    
    /// Format retrieved chunks into a context string for the LLM
    private func formatContext(_ chunks: [RetrievedChunk]) -> String {
        guard !chunks.isEmpty else { return "" }
        
        return chunks.enumerated().map { index, retrieved in
            """
            [Document Chunk \(index + 1), Similarity: \(String(format: "%.3f", retrieved.similarityScore))]
            \(retrieved.chunk.content)
            """
        }.joined(separator: "\n\n---\n\n")
    }
    
    /// Print query statistics for debugging
    private func printQueryStats(query: String, response: RAGResponse) {
        print("\n📊 RAG Query Statistics:")
        print("  Query: \(query.prefix(50))...")
        print("  Retrieved chunks: \(response.retrievedChunks.count)")
        print("  Retrieval time: \(String(format: "%.2f", response.metadata.retrievalTime))s")
        print("  Generation time: \(String(format: "%.2f", response.metadata.totalGenerationTime))s")
        if let ttft = response.metadata.timeToFirstToken {
            print("  Time to first token: \(String(format: "%.2f", ttft))s")
        }
        if let tps = response.metadata.tokensPerSecond {
            print("  Tokens per second: \(String(format: "%.1f", tps))")
        }
        print("  Model: \(response.metadata.modelUsed)")
        print("  Total time: \(String(format: "%.2f", response.metadata.retrievalTime + response.metadata.totalGenerationTime))s\n")
    }
}

// MARK: - Device Capability Detection

extension RAGService {
    
    /// Comprehensive device capability detection for Apple Intelligence ecosystem
    static func checkDeviceCapabilities() -> DeviceCapabilities {
        var capabilities = DeviceCapabilities()
        
        // Get iOS version
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        capabilities.iOSVersion = "\(systemVersion.majorVersion).\(systemVersion.minorVersion).\(systemVersion.patchVersion)"
        capabilities.iOSMajor = systemVersion.majorVersion
        capabilities.iOSMinor = systemVersion.minorVersion
        let hasAppleIntelligenceOS = (systemVersion.majorVersion > 18) || (systemVersion.majorVersion == 18 && systemVersion.minorVersion >= 1)
        
        // Detect device/chip tier based on available features
        // This is an approximation since we can't directly query chip model
        capabilities.deviceChip = detectDeviceChip()
        
        // Check Apple Intelligence availability (requires A17 Pro+/M-series + iOS 18.1+)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // iOS 26+ with Foundation Models
            #if targetEnvironment(simulator)
            capabilities.supportsFoundationModels = false
            capabilities.foundationModelUnavailableReason = "Foundation Models not available in Simulator"
            capabilities.supportsAppleIntelligence = false
            capabilities.appleIntelligenceUnavailableReason = "Not available in Simulator"
            #else
            // Check hardware capability only - don't actually instantiate SystemLanguageModel
            // (accessing SystemLanguageModel.default can crash if Apple Intelligence not enabled)
            if capabilities.deviceChip.supportsAppleIntelligence {
                // Device has capable hardware (A17 Pro+/M-series) and iOS 26+
                // Assume Foundation Models are potentially available
                // Actual availability will be checked when AppleFoundationLLMService is used
                capabilities.supportsFoundationModels = true
                capabilities.foundationModelUnavailableReason = nil
                capabilities.supportsAppleIntelligence = true
                capabilities.appleIntelligenceUnavailableReason = nil
                
                print("📱 Hardware supports Foundation Models (A18 Pro/A17 Pro+/M-series detected)")
                print("   ℹ️  Actual model availability will be verified when used")
                print("   💡 If not working, check Settings > Apple Intelligence & Siri")
            } else {
                // Device doesn't have capable hardware
                capabilities.supportsFoundationModels = false
                capabilities.foundationModelUnavailableReason = "Requires A17 Pro+ or M-series chip"
                capabilities.supportsAppleIntelligence = false
                capabilities.appleIntelligenceUnavailableReason = "Requires A17 Pro+ or M-series chip"
            }
            #endif
            
            // iOS 26 includes all iOS 18.1+ features
            capabilities.supportsPrivateCloudCompute = true
            capabilities.supportsWritingTools = true
            capabilities.supportsImagePlayground = capabilities.deviceChip.supportsAppleIntelligence
        } else if hasAppleIntelligenceOS {
            // iOS 18.1+ has Apple Intelligence (PCC, Writing Tools, ChatGPT)
            // but no Foundation Models yet
            capabilities.supportsAppleIntelligence = capabilities.deviceChip.supportsAppleIntelligence
            capabilities.supportsPrivateCloudCompute = true
            capabilities.supportsWritingTools = true
            capabilities.supportsImagePlayground = capabilities.deviceChip.supportsAppleIntelligence
            capabilities.foundationModelUnavailableReason = "Requires iOS 26"
            if !capabilities.supportsAppleIntelligence {
                capabilities.appleIntelligenceUnavailableReason = "Requires A17 Pro+ or M-series"
            }
        } else {
            capabilities.foundationModelUnavailableReason = "Requires iOS 26"
            capabilities.appleIntelligenceUnavailableReason = "Requires iOS 18.1+"
        }
        #else
        if hasAppleIntelligenceOS {
            capabilities.supportsAppleIntelligence = capabilities.deviceChip.supportsAppleIntelligence
            capabilities.supportsPrivateCloudCompute = true
            capabilities.supportsWritingTools = true
            capabilities.supportsImagePlayground = capabilities.deviceChip.supportsAppleIntelligence
            capabilities.foundationModelUnavailableReason = "Build with iOS 26 SDK to enable"
            if !capabilities.supportsAppleIntelligence {
                capabilities.appleIntelligenceUnavailableReason = "Requires A17 Pro+ or M-series"
            }
        } else {
            capabilities.foundationModelUnavailableReason = "Build with iOS 26 SDK to enable"
            capabilities.appleIntelligenceUnavailableReason = "Requires iOS 18.1+"
        }
        #endif
        
        // Check NaturalLanguage embedding support
        // NLEmbedding is available on iOS 13+, so we can assume it's available
        // Rather than risk crashing by initializing the model here
        capabilities.supportsEmbeddings = true
        
        // Core ML is always available
        capabilities.supportsCoreML = true
        
        // App Intents (Siri) available on all iOS versions
        capabilities.supportsAppIntents = true
        
        // Vision framework available on all devices
        capabilities.supportsVision = true
        
        // VisionKit (document scanning) available on all devices
        capabilities.supportsVisionKit = true
        
        // Determine device tier
        capabilities.deviceTier = determineDeviceTier(
            chip: capabilities.deviceChip,
            hasAppleIntelligence: capabilities.supportsAppleIntelligence,
            hasEmbeddings: capabilities.supportsEmbeddings
        )
        
        // Note: canRunRAG is a computed property based on supportsEmbeddings
        
        return capabilities
    }
    
    /// Detect device chip based on available features
    private static func detectDeviceChip() -> DeviceChip {
        // Check for Neural Engine and performance characteristics
        // This is an approximation - we can't directly query the chip model in iOS
        
        // Simulator gets conservative capabilities to avoid crashes
        #if targetEnvironment(simulator)
        return .a14Bionic // Don't claim Apple Intelligence support in simulator
        #else
        
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else {
            // If uname fails, return conservative fallback
            return .a14Bionic
        }
        
        let modelCode = withUnsafeBytes(of: &systemInfo.machine) { bytes -> String? in
            guard let cString = bytes.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                return nil
            }
            return String(cString: cString)
        }
        
        let identifier = modelCode ?? "unknown"
        
        // iPhone identifiers
        if identifier.contains("iPhone") {
            // Extract iPhone model number
            if identifier.contains("iPhone16") || identifier.contains("iPhone17") {
                // iPhone 16 Pro/Max (A18 Pro), iPhone 15 Pro/Max (A17 Pro), or newer
                return .a17ProOrNewer
            } else if identifier.contains("iPhone15") {
                // iPhone 14 Pro (A16)
                return .a16Bionic
            } else if identifier.contains("iPhone14") {
                // iPhone 13 Pro (A15)
                return .a15Bionic
            } else if identifier.contains("iPhone13") {
                // iPhone 12 Pro (A14)
                return .a14Bionic
            } else if identifier.contains("iPhone12") {
                // iPhone 11 Pro (A13)
                return .a13Bionic
            } else {
                return .older
            }
        }
        
        // iPad identifiers
        if identifier.contains("iPad") {
            if identifier.contains("iPad14") || identifier.contains("iPad15") || identifier.contains("iPad16") {
                // iPad with M-series or A17+
                return .mSeries
            } else if identifier.contains("iPad13") {
                // iPad with A15/A16
                return .a16Bionic
            } else {
                return .a14Bionic
            }
        }
        
        // Mac identifiers (Mac Catalyst)
        if identifier.contains("Mac") || identifier.contains("x86") || identifier.contains("arm64") {
            return .mSeries
        }
        
        // Conservative fallback for devices we don't recognize
        return .a14Bionic
        #endif
    }
    
    /// Determine device performance tier
    private static func determineDeviceTier(chip: DeviceChip, hasAppleIntelligence: Bool, hasEmbeddings: Bool) -> DeviceCapabilities.DeviceTier {
        if hasAppleIntelligence && chip.supportsAppleIntelligence {
            return .high // A17 Pro+ or M-series with full Apple Intelligence
        } else if hasEmbeddings {
            return .medium // A13+ with embedding support
        } else {
            return .low // Older devices
        }
    }
}

// MARK: - Device Chip Detection

enum DeviceChip: String {
    case mSeries = "Apple Silicon (M1+)"
    case a17ProOrNewer = "A17 Pro / A18"
    case a16Bionic = "A16 Bionic"
    case a15Bionic = "A15 Bionic"
    case a14Bionic = "A14 Bionic"
    case a13Bionic = "A13 Bionic"
    case older = "A12 or Older"
    
    var supportsAppleIntelligence: Bool {
        switch self {
        case .mSeries, .a17ProOrNewer:
            return true
        default:
            return false
        }
    }
    
    var supportsNeuralEngine: Bool {
        // A11+ has Neural Engine
        return self != .older
    }
    
    var performanceRating: String {
        switch self {
        case .mSeries:
            return "Exceptional"
        case .a17ProOrNewer:
            return "Excellent"
        case .a16Bionic:
            return "Very Good"
        case .a15Bionic, .a14Bionic:
            return "Good"
        case .a13Bionic:
            return "Moderate"
        case .older:
            return "Limited"
        }
    }
}

// MARK: - Device Capabilities Structure

struct DeviceCapabilities {
    // Device Information
    var deviceChip: DeviceChip = .a14Bionic
    var iOSVersion: String = "Unknown"
    var iOSMajor: Int = 0
    var iOSMinor: Int = 0

    // Apple Intelligence Features (iOS 18.1+)
    var supportsAppleIntelligence = false
    var supportsPrivateCloudCompute = false
    var supportsWritingTools = false
    var supportsImagePlayground = false
    var appleIntelligenceUnavailableReason: String? = nil

    // Foundation Models (iOS 26.0+)
    var supportsFoundationModels = false
    var foundationModelUnavailableReason: String? = nil

    // Core AI Frameworks
    var supportsEmbeddings = false
    var supportsCoreML = false
    var supportsAppIntents = false
    var supportsVision = false
    var supportsVisionKit = false

    // Computed Properties
    var deviceTier: DeviceTier = .low

    var canRunRAG: Bool { supportsEmbeddings }

    var canRunAdvancedAI: Bool { supportsAppleIntelligence || supportsFoundationModels }

    var appleIntelligenceStatus: String {
        if supportsFoundationModels {
            return "Foundation Models Available"
        } else if supportsAppleIntelligence {
            return "Apple Intelligence Available"
        } else if let reason = appleIntelligenceUnavailableReason {
            return reason
        } else if iOSMajor >= 18 {
            return "Requires A17 Pro+ or M-series"
        } else {
            return "Requires iOS 18.1+"
        }
    }

    enum DeviceTier {
        case low    // Pre-A13, minimal AI support
        case medium // A13-A16, embeddings + Core ML
        case high   // A17 Pro+ or M-series, full Apple Intelligence

        var description: String {
            switch self {
            case .high:
                return "Premium (Full AI Capabilities)"
            case .medium:
                return "Standard (Good AI Support)"
            case .low:
                return "Basic (Limited AI Support)"
            }
        }

        var color: String {
            switch self {
            case .high:
                return "green"
            case .medium:
                return "blue"
            case .low:
                return "orange"
            }
        }
    }
}

// MARK: - Errors

enum RAGServiceError: LocalizedError {
    case emptyQuery
    case noDocumentsAvailable
    case retrievalFailed
    case modelNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Query cannot be empty"
        case .noDocumentsAvailable:
            return "No documents have been added to the knowledge base"
        case .retrievalFailed:
            return "Failed to retrieve relevant chunks"
        case .modelNotAvailable:
            return "The selected LLM model is not available"
        }
    }
}
