//
//  RAGService.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import Foundation
import Combine
import NaturalLanguage

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Main orchestrator for the RAG (Retrieval-Augmented Generation) pipeline
/// Coordinates document processing, embedding, retrieval, and generation
class RAGService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let documentProcessor: DocumentProcessor
    private let embeddingService: EmbeddingService
    private let vectorDatabase: VectorDatabase
    
    /// Helper to get document name by ID
    @MainActor
    func getDocumentName(for documentId: UUID) -> String {
        return documents.first(where: { $0.id == documentId })?.filename ?? "Unknown"
    }
    
    /// Enrich retrieved chunks with source information for citations
    @MainActor
    private func addSourceInfo(_ chunks: [RetrievedChunk]) -> [RetrievedChunk] {
        return chunks.map { retrieved in
            let docName = documents.first(where: { $0.id == retrieved.chunk.documentId })?.filename ?? "Unknown"
            let pageNum = retrieved.chunk.metadata.pageNumber
            return RetrievedChunk(
                chunk: retrieved.chunk,
                similarityScore: retrieved.similarityScore,
                rank: retrieved.rank,
                sourceDocument: docName,
                pageNumber: pageNum
            )
        }
    }
    
    // MARK: - Published State (MainActor-isolated for SwiftUI)
    
    @MainActor @Published var documents: [Document] = []
    @MainActor @Published var isProcessing: Bool = false
    @MainActor @Published var processingStatus: String = ""
    @MainActor @Published var lastError: String? = nil // User-facing error message
    @MainActor @Published var lastProcessingSummary: ProcessingSummary? = nil // Detailed completion stats
    
    private(set) var totalChunksStored: Int = 0
    
    // MARK: - Public Access (for Settings)
    
    var llmService: LLMService {
        return _llmService
    }
    
    private var _llmService: LLMService
    
    // MARK: - Initialization
    
    init(
        documentProcessor: DocumentProcessor? = nil,
        embeddingService: EmbeddingService? = nil,
        vectorDatabase: VectorDatabase? = nil,
        llmService: LLMService? = nil
    ) {
        self.documentProcessor = documentProcessor ?? DocumentProcessor()
        self.embeddingService = embeddingService ?? EmbeddingService()
        self.vectorDatabase = vectorDatabase ?? PersistentVectorDatabase()
        
        // Priority order for LLM selection:
        // 1. Custom service provided by caller
        // 2. OpenAI Direct (if API key configured)
        // 3. Apple ChatGPT Extension (iOS 18.1+ with user consent)
        // 4. On-Device Analysis (extractive QA, always available)
        
        if let service = llmService {
            // User provided custom service (e.g., from Settings)
            self._llmService = service
            Log.info("✓ Using custom LLM service: \(service.modelName)", category: .initialization)
        } else {
            // Check user's selected model from Settings
            let selectedModelRaw = UserDefaults.standard.string(forKey: "selectedLLMModel") ?? "apple_intelligence"
            
            Log.info("🔧 Initializing with user's selected model: \(selectedModelRaw)", category: .initialization)
            
            // Try to instantiate the user's selected model first
            var service: LLMService?
            
            switch selectedModelRaw {
            case "openai":
                if let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey"),
                   !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let model = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o-mini"
                    service = OpenAILLMService(apiKey: apiKey, model: model)
                    print("✓ Using OpenAI Direct: \(model)")
                }
                
            case "apple_intelligence":
                #if canImport(FoundationModels)
                if #available(iOS 26.0, *) {
                    let foundationService = AppleFoundationLLMService()
                    if foundationService.isAvailable {
                        service = foundationService
                        foundationService.startWarmup()  // Start preloading model
                        print("✓ Using Apple Foundation Models (on-device + PCC)")
                        print("  🔥 Preloading model in background for instant first query")
                    }
                }
                #endif
                
            case "chatgpt_extension":
                if #available(iOS 18.1, *) {
                    let chatGPTService = AppleChatGPTExtensionService()
                    if chatGPTService.isAvailable {
                        service = chatGPTService
                        print("✓ Using ChatGPT Extension (Apple Intelligence)")
                    } else {
                        print("⚠️  ChatGPT Extension not available - check Settings > Apple Intelligence & Siri")
                    }
                }
                
            case "on_device_analysis":
                service = OnDeviceAnalysisService()
                print("✓ Using On-Device Analysis (extractive QA)")
                
            default:
                print("⚠️  Unknown model type: \(selectedModelRaw)")
            }
            
            // If selected model unavailable, try fallback order
            if service == nil {
                print("⚠️  Selected model '\(selectedModelRaw)' unavailable, trying fallbacks...")
                
                // Fallback order: Apple Intelligence → OpenAI → On-Device Analysis
                #if canImport(FoundationModels)
                if #available(iOS 26.0, *) {
                    let foundationService = AppleFoundationLLMService()
                    if foundationService.isAvailable {
                        service = foundationService
                        print("✓ Fallback: Using Apple Foundation Models")
                    }
                }
                #endif
                
                if service == nil,
                   let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey"),
                   !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let model = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o-mini"
                    service = OpenAILLMService(apiKey: apiKey, model: model)
                    print("✓ Fallback: Using OpenAI Direct: \(model)")
                }
                
                if service == nil {
                    service = OnDeviceAnalysisService()
                    print("✓ Fallback: Using On-Device Analysis (extractive QA)")
                }
            }
            
            // Assign the service (guaranteed to be non-nil at this point)
            self._llmService = service!
            
            // Connect tool handler for agentic RAG (Foundation Models only)
            self._llmService.toolHandler = self
            print("🔗 Tool handler connected for agentic RAG")
        }
        
        // Load persisted documents metadata
        loadDocumentsFromDisk()
    }
    
    // MARK: - Document Persistence
    
    private var documentsStorageURL: URL {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDirectory = appSupportURL.appendingPathComponent("RAGMLCore", isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory.appendingPathComponent("documents_metadata.json")
    }
    
    private func loadDocumentsFromDisk() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: documentsStorageURL.path) else {
            print("ℹ️  [RAGService] No existing documents metadata found")
            return
        }
        
        do {
            let data = try Data(contentsOf: documentsStorageURL)
            let decoder = JSONDecoder()
            let loadedDocuments = try decoder.decode([Document].self, from: data)
            
            Task { @MainActor in
                self.documents = loadedDocuments
                self.totalChunksStored = loadedDocuments.reduce(0) { $0 + $1.totalChunks }
                print("✅ [RAGService] Loaded \(loadedDocuments.count) documents (\(totalChunksStored) chunks)")
            }
        } catch {
            print("❌ [RAGService] Failed to load documents metadata: \(error.localizedDescription)")
        }
    }
    
    private func saveDocumentsToDisk() {
        Task {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(documents)
                try data.write(to: documentsStorageURL, options: .atomic)
                print("💾 [RAGService] Saved \(documents.count) documents metadata")
            } catch {
                print("❌ [RAGService] Failed to save documents metadata: \(error.localizedDescription)")
            }
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
        TelemetryCenter.emit(
            .ingestion,
            title: "Ingestion started",
            metadata: ["file": filename]
        )
        
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

            TelemetryCenter.emit(
                .ingestion,
                title: "Extraction complete",
                metadata: [
                    "file": filename,
                    "chunks": "\(textChunks.count)",
                    "words": "\(totalWords)"
                ],
                duration: extractionTime
            )
            
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
            TelemetryCenter.emit(
                .embedding,
                title: "Embeddings generated",
                metadata: [
                    "file": filename,
                    "chunks": "\(textChunks.count)",
                    "dimensions": "\(embeddings.first?.count ?? 0)"
                ],
                duration: embeddingTime
            )
            
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
            TelemetryCenter.emit(
                .storage,
                title: "Chunks prepared",
                metadata: [
                    "file": filename,
                    "count": "\(documentChunks.count)"
                ],
                duration: chunkingTime
            )
            
            // Step 4: Store chunks in vector database
            try await vectorDatabase.storeBatch(chunks: documentChunks)
            TelemetryCenter.emit(
                .storage,
                title: "Chunks stored",
                metadata: [
                    "file": filename,
                    "count": "\(documentChunks.count)"
                ]
            )
            
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

            TelemetryCenter.emit(
                .ingestion,
                title: "Document indexed",
                metadata: [
                    "file": filename,
                    "chunks": "\(documentChunks.count)",
                    "size": fileSizeStr
                ],
                duration: totalTime
            )
            
            // Save documents metadata to disk
            saveDocumentsToDisk()
            
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
            TelemetryCenter.emit(
                .ingestion,
                severity: .error,
                title: "Ingestion failed",
                metadata: [
                    "file": filename,
                    "error": error.localizedDescription
                ]
            )
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
        
        saveDocumentsToDisk()
        
        print("✓ Removed document: \(document.filename)")
    }
    
    /// Clear all documents from the knowledge base
    func clearAllDocuments() async throws {
        try await vectorDatabase.clear()
        
        await MainActor.run {
            documents.removeAll()
            totalChunksStored = 0
        }
        
        saveDocumentsToDisk()
        
        print("✓ Cleared all documents from knowledge base")
    }
    
    // MARK: - RAG Query Pipeline
    
    /// Execute a RAG query: expand query → embed → hybrid search → re-rank → generate response
    func query(_ question: String, topK: Int = 3, config: InferenceConfig? = nil) async throws -> RAGResponse {
        let inferenceConfig = config ?? InferenceConfig()
        // Query heuristics for short/generic prompts
        let queryWords = question.split(separator: " ").count
        let effectiveTopK = max(1, (queryWords <= 2) ? min(topK, 3) : min(topK, 10))
        // Fetch current stored chunk count from vector database (fallback to cached total)
        let totalStored = (try? await vectorDatabase.count()) ?? totalChunksStored
        
        Log.box(
            "ENHANCED RAG QUERY PIPELINE",
            level: .info,
            category: .pipeline,
            content: [
                "📝 Query: \(question)",
                "🎯 Retrieving top \(effectiveTopK) chunks from \(totalStored) total"
            ]
        )

        TelemetryCenter.emit(
            .system,
            title: "Query received",
            metadata: [
                "question": String(question.prefix(80))
            ]
        )
        
        do {
            // Clear any previous errors
            await MainActor.run {
                lastError = nil
            }
            
            // Edge case: Empty query
            guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Log.error("❌ [RAGService] Empty query string", category: .pipeline)
                TelemetryCenter.emit(
                    .system,
                    severity: .error,
                    title: "Query rejected",
                    metadata: ["reason": "Empty input"]
                )
                throw RAGServiceError.emptyQuery
            }
            
            let pipelineStartTime = Date()
            let ragQuery = RAGQuery(query: question, topK: effectiveTopK)
            
            // Small-talk/direct-chat bypass for trivial inputs (no RAG)
            let lowerQ = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if queryWords <= 2 {
                let smallTalkSet: Set<String> = ["hi","hello","hey","yo","sup","ok","thanks","thank you","bye","goodbye","hola","hiya"]
                if smallTalkSet.contains(lowerQ) {
                    return try await generateDirectChatResponse(
                        question: question,
                        ragQuery: ragQuery,
                        inferenceConfig: inferenceConfig,
                        pipelineStartTime: pipelineStartTime,
                        retrievalTime: 0,
                        fallbackNote: "Short greeting detected; replied without document retrieval."
                    )
                }
            }
            
            // Check if we have documents for RAG or just direct LLM chat (use live DB count)
            let hasDocuments = totalStored > 0
            
            if hasDocuments {
                // ENHANCED RAG pipeline with query expansion + hybrid search + re-ranking
                
                // Step 1: Query Expansion
                Log.section("Step 1: Query Expansion", level: .info, category: .pipeline)
                let expansionStartTime = Date()
                let queryEnhancer = QueryEnhancementService()
                let expandedQueries = queryEnhancer.expandQuery(question)
                let expansionTime = Date().timeIntervalSince(expansionStartTime)
                Log.info("✓ Expanded to \(expandedQueries.count) query variations in \(String(format: "%.0f", expansionTime * 1000))ms", category: .pipeline)
                TelemetryCenter.emit(
                    .retrieval,
                    title: "Query expanded",
                    metadata: [
                        "variants": "\(expandedQueries.count)"
                    ],
                    duration: expansionTime
                )
                
                // Step 2: Embed the user's query (primary query only)
                Log.section("Step 2: Query Embedding", level: .info, category: .pipeline)
                let embeddingStartTime = Date()
                let queryEmbedding = try await embeddingService.generateEmbedding(for: question)
                let embeddingTime = Date().timeIntervalSince(embeddingStartTime)
            
                let embeddingMagnitude = sqrt(queryEmbedding.map { $0 * $0 }.reduce(0, +))
                Log.info("✓ Generated \(queryEmbedding.count)-dimensional embedding", category: .embedding)
                Log.debug("  Vector magnitude: \(String(format: "%.4f", embeddingMagnitude))", category: .embedding)
                Log.debug("  Time: \(String(format: "%.0f", embeddingTime * 1000))ms", category: .performance)
                TelemetryCenter.emit(
                    .embedding,
                    title: "Query embedding",
                    metadata: [
                        "dimensions": "\(queryEmbedding.count)"
                    ],
                    duration: embeddingTime
                )
                
                // Step 3: Hybrid Search (vector + BM25 keyword search with RRF fusion)
                Log.section("Step 3: Hybrid Search (Vector + BM25)", level: .info, category: .pipeline)
                let retrievalStartTime = Date()
                let hybridSearch = HybridSearchService(vectorDatabase: vectorDatabase)
                // Use expanded queries for keyword search (original for vector)
                let retrievedChunks = try await hybridSearch.search(
                    query: expandedQueries.joined(separator: " "),  // Combine expansions
                    embedding: queryEmbedding,
                    topK: effectiveTopK * 2  // Retrieve 2x for re-ranking (clamped)
                )
                
                // Measure retrieval time before any MainActor work
                let retrievalTime = Date().timeIntervalSince(retrievalStartTime)
                
                // Edge case: No relevant chunks found - gracefully fallback to direct chat
                if retrievedChunks.isEmpty {
                    Log.warning("⚠️  [RAGService] No chunks retrieved (database may be empty)", category: .retrieval)
                    TelemetryCenter.emit(
                        .retrieval,
                        severity: .warning,
                        title: "No chunks retrieved",
                        metadata: [
                            "question": String(question.prefix(60))
                        ],
                        duration: retrievalTime
                    )
                    // Fallback to direct LLM chat mode
                    return try await generateDirectChatResponse(
                        question: question,
                        ragQuery: ragQuery,
                        inferenceConfig: inferenceConfig,
                        pipelineStartTime: pipelineStartTime,
                        retrievalTime: retrievalTime,
                        fallbackNote: "No relevant document context found; replied without RAG context."
                    )
                }
                
                // Add source information for citations with a safe MainActor snapshot
                let docsSnapshot = await MainActor.run { self.documents }
                let chunksWithSources: [RetrievedChunk] = retrievedChunks.map { retrieved in
                    let docName = docsSnapshot.first(where: { $0.id == retrieved.chunk.documentId })?.filename ?? "Unknown"
                    let pageNum = retrieved.chunk.metadata.pageNumber
                    return RetrievedChunk(
                        chunk: retrieved.chunk,
                        similarityScore: retrieved.similarityScore,
                        rank: retrieved.rank,
                        sourceDocument: docName,
                        pageNumber: pageNum
                    )
                }
                
                TelemetryCenter.emit(
                    .retrieval,
                    title: "Hybrid retrieval",
                    metadata: [
                        "candidates": "\(chunksWithSources.count)",
                        "topK": "\(effectiveTopK * 2)"
                    ],
                    duration: retrievalTime
                )
                
                
                
                Log.info("✓ Retrieved \(chunksWithSources.count) chunks with hybrid fusion", category: .retrieval)
                Log.debug("  Time: \(String(format: "%.0f", retrievalTime * 1000))ms", category: .performance)
                if let topChunk = chunksWithSources.first {
                    Log.debug("  Top semantic score: \(String(format: "%.4f", topChunk.similarityScore))", category: .retrieval)
                    if !topChunk.sourceDocument.isEmpty {
                        Log.debug("  Source: \(topChunk.sourceDocument)\(topChunk.pageNumber.map { " (p. \($0))" } ?? "")", category: .retrieval)
                    }
                    // BM25 and fusion scores would be displayed here once metadata storage is enhanced
                }
                
                // Step 4: Re-rank results with multiple signals
                Log.section("Step 4: Multi-Signal Re-ranking", level: .info, category: .pipeline)
                let engine = RAGEngine()
                let rerankStartTime = Date()
                let rerankedChunks = await engine.rerank(
                    chunks: chunksWithSources,
                    query: question,
                    topK: effectiveTopK * 3  // Get more candidates for MMR diversification (clamped)
                )
                let rerankTime = Date().timeIntervalSince(rerankStartTime)
                Log.info("✓ Re-ranked to top \(rerankedChunks.count) in \(String(format: "%.0f", rerankTime * 1000))ms", category: .retrieval)
                TelemetryCenter.emit(
                    .retrieval,
                    title: "Re-ranking complete",
                    metadata: [
                        "candidates": "\(rerankedChunks.count)"
                    ],
                    duration: rerankTime
                )
                
                if rerankedChunks.isEmpty {
                    Log.warning("⚠️  [RAGService] Re-ranking yielded no candidates; falling back to direct chat", category: .retrieval)
                    return try await generateDirectChatResponse(
                        question: question,
                        ragQuery: ragQuery,
                        inferenceConfig: inferenceConfig,
                        pipelineStartTime: pipelineStartTime,
                        retrievalTime: retrievalTime,
                        fallbackNote: "No re-ranked candidates; replied without RAG context."
                    )
                }
                
                // Step 4.3: Filter low-confidence chunks (critical for medical accuracy)
                let minSimilarity: Float = 0.35  // Threshold: chunks below this are likely not relevant
                let filteredChunks = await engine.filterBySimilarity(
                    chunks: rerankedChunks,
                    min: minSimilarity
                )
                
                if filteredChunks.count < rerankedChunks.count {
                    let dropped = rerankedChunks.count - filteredChunks.count
                    Log.warning("   ⚠️  Filtered out \(dropped) low-confidence chunks (< \(String(format: "%.2f", minSimilarity)))", category: .retrieval)
                    TelemetryCenter.emit(
                        .retrieval,
                        severity: .warning,
                        title: "Low-confidence filtered",
                        metadata: ["dropped": "\(dropped)"]
                    )
                }
                
                // Edge case: No high-confidence chunks
                guard !filteredChunks.isEmpty else {
                    Log.error("   ❌ No high-confidence chunks found (all below threshold)", category: .retrieval)
                    TelemetryCenter.emit(
                        .retrieval,
                        severity: .error,
                        title: "No high-confidence context",
                        metadata: [
                            "threshold": String(format: "%.2f", minSimilarity)
                        ]
                    )
                    throw RAGServiceError.noRelevantContext
                }
                
                // Step 4.5: Apply MMR for diversity (critical for medical/comprehensive coverage)
                Log.section("Step 4.5: MMR Diversification", level: .info, category: .pipeline)
                let mmrStartTime = Date()
                let diverseChunks = await engine.applyMMR(
                    candidates: filteredChunks,
                    queryEmbedding: queryEmbedding,
                    topK: effectiveTopK,  // Clamped for short queries
                    lambda: 0.7  // 0.7 = balance relevance vs diversity (higher = more relevance)
                )
                let mmrTime = Date().timeIntervalSince(mmrStartTime)
                Log.info("✓ Selected \(diverseChunks.count) diverse chunks in \(String(format: "%.0f", mmrTime * 1000))ms", category: .retrieval)
                Log.debug("  λ=0.7 (70% relevance, 30% diversity)", category: .retrieval)
                TelemetryCenter.emit(
                    .retrieval,
                    title: "MMR diversification",
                    metadata: [
                        "selected": "\(diverseChunks.count)",
                        "lambda": "0.7"
                    ],
                    duration: mmrTime
                )
                
                if diverseChunks.isEmpty {
                    Log.warning("⚠️  [RAGService] MMR returned no candidates; falling back to direct chat", category: .retrieval)
                    return try await generateDirectChatResponse(
                        question: question,
                        ragQuery: ragQuery,
                        inferenceConfig: inferenceConfig,
                        pipelineStartTime: pipelineStartTime,
                        retrievalTime: retrievalTime,
                        fallbackNote: "No diverse candidates after MMR; replied without RAG context."
                    )
                }
                
                Log.verbose("\nFinal diverse chunks:", category: .retrieval)
                for (index, chunk) in diverseChunks.enumerated() {
                    let preview = chunk.chunk.content.prefix(80).replacingOccurrences(of: "\n", with: " ")
                    let source = chunk.sourceDocument.isEmpty ? "" : " | \(chunk.sourceDocument)\(chunk.pageNumber.map { " p.\($0)" } ?? "")"
                    Log.verbose("  [\(index + 1)] Similarity: \(String(format: "%.4f", chunk.similarityScore))\(source)", category: .retrieval)
                    Log.verbose("      \"\(preview)...\"", category: .retrieval)
                }
                
                // Step 5: Construct context from diverse chunks (off-main)
                // Note: rawContext assembly is handled via engine.assembleContext with size limits
                
                // Smart context assembly: Use as many chunks as fit within the model's context window
                // Apple Intelligence: ~3500 chars for on-device/PCC (leaves room for prompt + response)
                // OpenAI Context Windows:
                //   - GPT-4o: 128K tokens (~512K chars)
                //   - GPT-5: 400K tokens (~1.6M chars) 🚀
                let maxContextChars: Int
                if llmService is OpenAILLMService {
                    // GPT-5 has 400K token context (~1.6M chars theoretical)
                    // Use 200K chars conservatively (leaves ~200K for prompt + response)
                    maxContextChars = 200000  // 200K chars = ~50K tokens
                } else if llmService is AppleFoundationLLMService {
                    // Tighter context for Apple FM to leave room for tool scaffolding and output
                    maxContextChars = 1500
                } else {
                    maxContextChars = 3500
                }
                
                
                let (context, actualChunksUsed) = await engine.assembleContext(
                    chunks: diverseChunks,
                    maxChars: maxContextChars
                )
                Log.info("   ✓ Using \(actualChunksUsed)/\(diverseChunks.count) chunks (\(context.count) chars)", category: .pipeline)
                
                let contextSize = context.count
                let contextWords = context.split(separator: " ").count
                
                Log.section("Step 5: Context Assembly Complete", level: .info, category: .pipeline)
                Log.info("✓ Final context: \(contextSize) chars, \(contextWords) words from \(actualChunksUsed) chunks", category: .pipeline)
                TelemetryCenter.emit(
                    .retrieval,
                    title: "Context assembled",
                    metadata: [
                        "chunks": "\(actualChunksUsed)",
                        "chars": "\(contextSize)"
                    ]
                )
                
                // If context is empty, fallback to direct chat to avoid downstream failures
                if actualChunksUsed == 0 || context.isEmpty {
                    Log.warning("⚠️  [RAGService] Empty context after assembly; falling back to direct chat", category: .retrieval)
                    return try await generateDirectChatResponse(
                        question: question,
                        ragQuery: ragQuery,
                        inferenceConfig: inferenceConfig,
                        pipelineStartTime: pipelineStartTime,
                        retrievalTime: retrievalTime,
                        fallbackNote: "Empty assembled context; replied without RAG context."
                    )
                }
                
                // Step 6: Generate response using LLM with augmented context
                Log.section("Step 6: LLM Generation", level: .info, category: .pipeline)
                let generationStartTime = Date()
                
                // Token budgeting for Apple FM (conservative ~4K window)
                var genConfig = inferenceConfig
                do {
                    let window = 4000
                    let safety = 400
                    let estPromptTokens = max(0, (question.count + context.count) / 4)
                    let available = max(128, window - safety - estPromptTokens)
                    if genConfig.maxTokens > available {
                        genConfig.maxTokens = available
                    }
                }
                
                // Attempt generation with retry on context-overflow
                var llmResponse: LLMResponse
                do {
                    llmResponse = try await llmService.generate(
                        prompt: question,
                        context: context,
                        config: genConfig
                    )
                } catch {
                    let message = error.localizedDescription.lowercased()
                    if message.contains("context") && (message.contains("exceed") || message.contains("exceeded")) {
                        // Retry with halved context and smaller maxTokens
                        let reducedMax = max(512, genConfig.maxTokens / 2)
                        let (context2, _) = await engine.assembleContext(
                            chunks: diverseChunks,
                            maxChars: max(800, maxContextChars / 2)
                        )
                        var retryConfig = genConfig
                        retryConfig.maxTokens = reducedMax
                        TelemetryCenter.emit(
                            .system,
                            severity: .warning,
                            title: "Retry due to context overflow",
                            metadata: ["initialTokens": "\(genConfig.maxTokens)", "reducedTokens": "\(reducedMax)"]
                        )
                        llmResponse = try await llmService.generate(
                            prompt: question,
                            context: context2,
                            config: retryConfig
                        )
                    } else {
                        throw error
                    }
                }
                
                let generationTime = Date().timeIntervalSince(generationStartTime)
                TelemetryCenter.emit(
                    .generation,
                    title: "Response generated",
                    metadata: [
                        "model": llmService.modelName,
                        "tokens": "\(llmResponse.tokensGenerated)"
                    ],
                    duration: generationTime
                )
                
                // Wrap all printing in error handling to prevent crashes
                do {
                    Log.info("✓ Response generated", category: .llm)
                    Log.info("  Model: \(llmService.modelName)", category: .llm)
                    Log.info("  Generation time: \(String(format: "%.2f", generationTime))s", category: .performance)
                    
                    // Access response text safely
                    let responseText = llmResponse.text
                    Log.debug("  Response length: \(responseText.count) chars", category: .llm)
                    
                    if llmResponse.tokensGenerated > 0 {
                        Log.debug("  Tokens: \(llmResponse.tokensGenerated)", category: .llm)
                        if let tps = llmResponse.tokensPerSecond {
                            Log.debug("  Speed: \(String(format: "%.1f", tps)) tokens/sec", category: .performance)
                        }
                    }
                    
                    // Verify we got a response
                    guard !responseText.isEmpty else {
                        Log.warning("⚠️  Warning: LLM returned empty response", category: .llm)
                        throw RAGServiceError.modelNotAvailable
                    }
                    
                    // Step 7: Calculate confidence score and quality warnings
                    Log.section("Step 7: Quality Assessment", level: .info, category: .pipeline)
                    let totalDocsCount = await MainActor.run { documents.count }
                    let (confidenceScore, qualityWarnings) = await engine.assessResponseQuality(
                        chunks: diverseChunks,
                        query: question,
                        totalDocs: totalDocsCount
                    )
                    
                    if !qualityWarnings.isEmpty {
                        Log.warning("⚠️  Quality Warnings:", category: .pipeline)
                        for warning in qualityWarnings {
                            Log.warning("   • \(warning)", category: .pipeline)
                        }
                    }
                    
                    Log.info("📊 Confidence Score: \(String(format: "%.1f", confidenceScore * 100))%", category: .pipeline)
                    TelemetryCenter.emit(
                        .system,
                        title: "Response evaluated",
                        metadata: [
                            "confidence": String(format: "%.2f", confidenceScore)
                        ]
                    )
                    
                    // Step 8: Package results
                    let pipelineTotalTime = Date().timeIntervalSince(pipelineStartTime)
                    
                    Log.box(
                        "ENHANCED PIPELINE COMPLETE ✓",
                        level: .info,
                        category: .pipeline,
                        content: [
                            "Total time: \(String(format: "%.2f", pipelineTotalTime))s",
                            "  - Query Expansion: \(String(format: "%.0f", expansionTime * 1000))ms",
                            "  - Embedding: \(String(format: "%.0f", embeddingTime * 1000))ms",
                            "  - Hybrid Retrieval: \(String(format: "%.0f", retrievalTime * 1000))ms",
                            "  - Re-ranking: \(String(format: "%.0f", rerankTime * 1000))ms",
                            "  - MMR Diversification: \(String(format: "%.0f", mmrTime * 1000))ms",
                            "  - Quality Assessment: <1ms",
                            "  - Generation: \(String(format: "%.2f", generationTime))s"
                        ]
                    )
                    TelemetryCenter.emit(
                        .system,
                        title: "Query complete",
                        metadata: [
                            "duration": String(format: "%.2f", pipelineTotalTime),
                            "chunks": "\(diverseChunks.count)"
                        ],
                        duration: pipelineTotalTime
                    )
                    
                    // Step 9: Create response metadata
                    let metadata = ResponseMetadata(
                        timeToFirstToken: llmResponse.timeToFirstToken,
                        totalGenerationTime: llmResponse.totalTime,
                        tokensGenerated: llmResponse.tokensGenerated,
                        tokensPerSecond: llmResponse.tokensPerSecond,
                        modelUsed: llmResponse.modelName ?? llmService.modelName,
                        retrievalTime: retrievalTime
                    )
                    
                    let response = RAGResponse(
                        queryId: ragQuery.id,
                        retrievedChunks: diverseChunks,
                        generatedResponse: responseText,
                        metadata: metadata,
                        confidenceScore: confidenceScore,
                        qualityWarnings: qualityWarnings
                    )
                    
                    let totalTime = Date().timeIntervalSince(pipelineStartTime)
                    print("✅ [RAGService] Enhanced RAG pipeline complete in \(String(format: "%.2f", totalTime))s")
                    printQueryStats(query: question, response: response)
                    
                    return response
                    
                } catch {
                    print("❌ Error during response processing: \(error)")
                    // Still try to return something
                    let metadata = ResponseMetadata(
                        timeToFirstToken: nil,
                        totalGenerationTime: generationTime,
                        tokensGenerated: 0,
                        tokensPerSecond: nil,
                        modelUsed: llmService.modelName,
                        retrievalTime: retrievalTime
                    )
                    
                    return RAGResponse(
                        queryId: ragQuery.id,
                        retrievedChunks: diverseChunks,
                        generatedResponse: "Error processing response",
                        metadata: metadata,
                        confidenceScore: 0.0,
                        qualityWarnings: ["Error occurred during response processing"]
                    )
                }
                
            } else {
                // Direct LLM chat without documents
                Log.info("ℹ️  No documents loaded - using direct LLM chat mode", category: .pipeline)
                TelemetryCenter.emit(
                    .system,
                    title: "Direct chat mode",
                    metadata: ["model": llmService.modelName]
                )
                
                Log.section("Direct LLM Generation (No RAG)", level: .info, category: .pipeline)
                let generationStartTime = Date()
                
                let llmResponse = try await llmService.generate(
                    prompt: question,
                    context: nil,  // No document context
                    config: inferenceConfig
                )
                
                let generationTime = Date().timeIntervalSince(generationStartTime)
                TelemetryCenter.emit(
                    .generation,
                    title: "Response generated",
                    metadata: [
                        "model": llmService.modelName,
                        "tokens": "\(llmResponse.tokensGenerated)"
                    ],
                    duration: generationTime
                )
                
                Log.info("✓ Response generated", category: .llm)
                Log.info("  Model: \(llmService.modelName)", category: .llm)
                Log.info("  Generation time: \(String(format: "%.2f", generationTime))s", category: .performance)
                Log.debug("  Tokens: \(llmResponse.tokensGenerated)", category: .llm)
                Log.debug("  Speed: \(String(format: "%.1f", llmResponse.tokensPerSecond ?? 0)) tokens/sec", category: .performance)
                
                let metadata = ResponseMetadata(
                    timeToFirstToken: llmResponse.timeToFirstToken,
                    totalGenerationTime: llmResponse.totalTime,
                    tokensGenerated: llmResponse.tokensGenerated,
                    tokensPerSecond: llmResponse.tokensPerSecond,
                    modelUsed: llmResponse.modelName ?? llmService.modelName,  // Use actual execution location if available
                    retrievalTime: 0  // No retrieval in direct chat mode
                )
                
                let response = RAGResponse(
                    queryId: ragQuery.id,
                    retrievedChunks: [],  // No chunks in direct chat mode
                    generatedResponse: llmResponse.text,
                    metadata: metadata
                )
                
                let totalTime = Date().timeIntervalSince(pipelineStartTime)
                Log.info("✅ [RAGService] Direct chat complete in \(String(format: "%.2f", totalTime))s", category: .pipeline)
                TelemetryCenter.emit(
                    .system,
                    title: "Query complete",
                    metadata: [
                        "duration": String(format: "%.2f", totalTime),
                        "mode": "direct"
                    ],
                    duration: totalTime
                )
                
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
            TelemetryCenter.emit(
                .error,
                severity: .error,
                title: "Query failed",
                metadata: ["reason": error.localizedDescription]
            )
            throw error
        }
    }
    
    // MARK: - Direct Chat Fallback Helper
    
    /// Generate a direct LLM response without document context.
    /// Used as a graceful fallback when retrieval returns no results or documents are unavailable.
    private func generateDirectChatResponse(
        question: String,
        ragQuery: RAGQuery,
        inferenceConfig: InferenceConfig,
        pipelineStartTime: Date,
        retrievalTime: TimeInterval,
        fallbackNote: String? = nil
    ) async throws -> RAGResponse {
        Log.info("ℹ️  Falling back to direct LLM chat mode", category: .pipeline)
        TelemetryCenter.emit(
            .system,
            title: "Direct chat mode",
            metadata: ["model": llmService.modelName]
        )
        
        Log.section("Direct LLM Generation (No RAG)", level: .info, category: .pipeline)
        let generationStartTime = Date()
        
        let llmResponse = try await llmService.generate(
            prompt: question,
            context: nil,  // No document context
            config: inferenceConfig
        )
        
        let generationTime = Date().timeIntervalSince(generationStartTime)
        TelemetryCenter.emit(
            .generation,
            title: "Response generated",
            metadata: [
                "model": llmService.modelName,
                "tokens": "\(llmResponse.tokensGenerated)"
            ],
            duration: generationTime
        )
        
        Log.info("✓ Response generated", category: .llm)
        Log.info("  Model: \(llmService.modelName)", category: .llm)
        Log.info("  Generation time: \(String(format: "%.2f", generationTime))s", category: .performance)
        Log.debug("  Tokens: \(llmResponse.tokensGenerated)", category: .llm)
        Log.debug("  Speed: \(String(format: "%.1f", llmResponse.tokensPerSecond ?? 0)) tokens/sec", category: .performance)
        
        let metadata = ResponseMetadata(
            timeToFirstToken: llmResponse.timeToFirstToken,
            totalGenerationTime: llmResponse.totalTime,
            tokensGenerated: llmResponse.tokensGenerated,
            tokensPerSecond: llmResponse.tokensPerSecond,
            modelUsed: llmResponse.modelName ?? llmService.modelName,
            retrievalTime: retrievalTime
        )
        
        var warnings: [String] = []
        if let note = fallbackNote { warnings.append(note) }
        
        let response = RAGResponse(
            queryId: ragQuery.id,
            retrievedChunks: [],
            generatedResponse: llmResponse.text,
            metadata: metadata,
            confidenceScore: 1.0,
            qualityWarnings: warnings
        )
        
        let totalTime = Date().timeIntervalSince(pipelineStartTime)
        Log.info("✅ [RAGService] Direct chat complete in \(String(format: "%.2f", totalTime))s", category: .pipeline)
        TelemetryCenter.emit(
            .system,
            title: "Query complete",
            metadata: [
                "duration": String(format: "%.2f", totalTime),
                "mode": "direct"
            ],
            duration: totalTime
        )
        
        return response
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
    
    
    /// Print query statistics for debugging
    nonisolated private func printQueryStats(query: String, response: RAGResponse) {
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
    
    // MARK: - Response Quality Assessment
    
    /// Calculate confidence score and identify quality warnings
    /// Critical for medical/high-stakes information retrieval
    /// - Parameters:
    ///   - chunks: Retrieved chunks for this response
    ///   - query: Original user query
    /// - Returns: Tuple of (confidence score 0-1, array of warnings)
    @MainActor
    private func assessResponseQuality(
        chunks: [RetrievedChunk],
        query: String
    ) -> (Float, [String]) {
        var warnings: [String] = []
        
        // Factor 1: Semantic similarity of top chunks
        let topSimilarity = chunks.first?.similarityScore ?? 0
        
        if topSimilarity < 0.4 {
            warnings.append("Low relevance: Best match only \(String(format: "%.1f", topSimilarity * 100))% similar")
        } else if topSimilarity < 0.6 {
            warnings.append("Moderate relevance: Consider rephrasing query for better results")
        }
        
        // Factor 2: Number of supporting chunks
        let chunkCount = chunks.count
        if chunkCount < 3 {
            warnings.append("Limited context: Only \(chunkCount) relevant chunks found")
        }
        
        // Factor 3: Source diversity (multiple documents = higher confidence)
        let uniqueSources = Set(chunks.map { $0.sourceDocument })
        let sourceCount = uniqueSources.count
        
        if sourceCount == 1 && documents.count > 1 {
            warnings.append("Single source: Information from only one document")
        }
        
        // Factor 4: Query quality
        let queryWords = query.split(separator: " ").count
        if queryWords <= 2 {
            warnings.append("Generic query: Try more specific questions for better accuracy")
        }
        
        // Calculate aggregate confidence (weighted average)
        let similarityWeight: Float = 0.5
        let chunkCountWeight: Float = 0.2
        let sourceDiversityWeight: Float = 0.2
        let queryQualityWeight: Float = 0.1
        
        let similarityScore = min(topSimilarity / 0.8, 1.0)  // Normalize: 0.8+ = full confidence
        let chunkScore = min(Float(chunkCount) / 5.0, 1.0)  // 5+ chunks = full confidence
        let diversityScore = min(Float(sourceCount) / Float(max(documents.count, 1)), 1.0)
        let queryScore = min(Float(queryWords) / 5.0, 1.0)  // 5+ words = full confidence
        
        let confidence = (
            similarityScore * similarityWeight +
            chunkScore * chunkCountWeight +
            diversityScore * sourceDiversityWeight +
            queryScore * queryQualityWeight
        )
        
        return (confidence, warnings)
    }
    
    // MARK: - MMR (Maximal Marginal Relevance) for Diversity
    
    
}

// MARK: - Device Capability Detection

extension RAGService {
    
    /// Comprehensive device capability detection for Apple Intelligence ecosystem
    @MainActor
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
            // Simulator: Foundation Models not available
            capabilities.supportsFoundationModels = false
            capabilities.foundationModelUnavailableReason = "Foundation Models not available in Simulator"
            capabilities.supportsAppleIntelligence = false
            capabilities.appleIntelligenceUnavailableReason = "Not available in Simulator"
            print("ℹ️  Running in Simulator - Foundation Models unavailable")
            #else
            // Real device: Check Foundation Models availability
            // SystemLanguageModel.default must be accessed synchronously on main thread
            guard Thread.isMainThread else {
                // Fallback: not on main thread
                capabilities.supportsFoundationModels = false
                capabilities.foundationModelUnavailableReason = "Internal error: not called from main thread"
                capabilities.supportsAppleIntelligence = false
                capabilities.appleIntelligenceUnavailableReason = "Internal error: not called from main thread"
                print("❌ checkDeviceCapabilities() not called from main thread")
                
                // Skip Foundation Models check, continue with rest
                capabilities.supportsPrivateCloudCompute = false
                capabilities.supportsWritingTools = false
                capabilities.supportsImagePlayground = false
                
                // Jump to post-Foundation Models setup
                if hasAppleIntelligenceOS {
                    capabilities.supportsAppleIntelligence = capabilities.deviceChip.supportsAppleIntelligence
                    capabilities.supportsPrivateCloudCompute = true
                    capabilities.supportsWritingTools = true
                    capabilities.supportsImagePlayground = capabilities.deviceChip.supportsAppleIntelligence
                    if !capabilities.supportsAppleIntelligence {
                        capabilities.appleIntelligenceUnavailableReason = "Requires A17 Pro+ or M-series"
                    }
                }
                
                // Skip to embedding check
                capabilities.supportsEmbeddings = true
                capabilities.supportsCoreML = true
                capabilities.supportsAppIntents = true
                capabilities.supportsVision = true
                capabilities.supportsVisionKit = true
                capabilities.deviceTier = determineDeviceTier(
                    chip: capabilities.deviceChip,
                    hasAppleIntelligence: capabilities.supportsAppleIntelligence,
                    hasEmbeddings: capabilities.supportsEmbeddings
                )
                return capabilities
            }
            
            let systemModel = SystemLanguageModel.default
            
            switch systemModel.availability {
            case .available:
                capabilities.supportsFoundationModels = true
                capabilities.foundationModelUnavailableReason = nil
                capabilities.supportsAppleIntelligence = true
                capabilities.appleIntelligenceUnavailableReason = nil
                print("✅ Foundation Models available on device")
                
            case .unavailable(let reason):
                capabilities.supportsFoundationModels = false
                capabilities.supportsAppleIntelligence = false
                
                switch reason {
                case .deviceNotEligible:
                    let message = "Device not eligible (requires A17 Pro+ or M-series)"
                    capabilities.foundationModelUnavailableReason = message
                    capabilities.appleIntelligenceUnavailableReason = message
                    print("❌ Device not eligible for Foundation Models")
                    
                case .appleIntelligenceNotEnabled:
                    let message = "Apple Intelligence not enabled - go to Settings > Apple Intelligence & Siri"
                    capabilities.foundationModelUnavailableReason = message
                    capabilities.appleIntelligenceUnavailableReason = message
                    print("⚠️  Apple Intelligence not enabled in Settings")
                    print("   💡 Go to Settings > Apple Intelligence & Siri to enable")
                    
                case .modelNotReady:
                    let message = "Model downloading or initializing - check iPhone Storage"
                    capabilities.foundationModelUnavailableReason = message
                    capabilities.appleIntelligenceUnavailableReason = message
                    print("⏳ Foundation Models not ready (downloading or initializing)")
                    print("   💡 Check Settings > General > iPhone Storage for download progress")
                    
                @unknown default:
                    let message = "Foundation Models unavailable (unknown reason)"
                    capabilities.foundationModelUnavailableReason = message
                    capabilities.appleIntelligenceUnavailableReason = message
                    print("❌ Foundation Models unavailable (unknown reason)")
                }
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
        if identifier.hasPrefix("iPhone") {
            let components = identifier.split(separator: ",")
            let family = components.first.map(String.init) ?? "iPhone"
            let variant = components.count > 1 ? String(components[1]) : ""
            switch family {
            case "iPhone17":
                // iPhone 16 line (2024) – Pro models run A18 Pro, non-Pro run A18
                if ["1", "2"].contains(variant) {
                    return .a18Pro
                } else {
                    return .a18
                }
            case "iPhone16":
                // iPhone 15 line (2023) – Pro models run A17 Pro, non-Pro run A16
                if ["1", "2"].contains(variant) {
                    return .a17Pro
                } else {
                    return .a16Bionic
                }
            case "iPhone15":
                // iPhone 14 line (2022) – Pro models run A16, standard models run A15
                if ["2", "3"].contains(variant) {
                    return .a16Bionic
                } else {
                    return .a15Bionic
                }
            case "iPhone14":
                return .a15Bionic
            case "iPhone13":
                return .a14Bionic
            case "iPhone12":
                return .a13Bionic
            default:
                return .older
            }
        }
        
        // iPad identifiers
        if identifier.hasPrefix("iPad") {
            if identifier.contains("iPad16") || identifier.contains("iPad17") {
                return .mSeries
            } else if identifier.contains("iPad15") {
                return .a17Pro
            } else if identifier.contains("iPad14") || identifier.contains("iPad13") {
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
    case a18Pro = "A18 Pro"
    case a18 = "A18"
    case a17Pro = "A17 Pro"
    case a17 = "A17"
    case a16Bionic = "A16 Bionic"
    case a15Bionic = "A15 Bionic"
    case a14Bionic = "A14 Bionic"
    case a13Bionic = "A13 Bionic"
    case older = "A12 or Older"
    
    var supportsAppleIntelligence: Bool {
        switch self {
        case .mSeries, .a18Pro, .a18, .a17Pro:
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
        case .a18Pro:
            return "Elite"
        case .a18:
            return "Very Good"
        case .a17Pro:
            return "Excellent"
        case .a17:
            return "Very Good"
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
    
    var neuralEnginePerformance: String {
        switch self {
        case .mSeries:
            return "16-core, 15.8 TOPS"
        case .a18Pro:
            return "16-core, 45 TOPS"
        case .a18:
            return "16-core, 20 TOPS"
        case .a17Pro:
            return "16-core, 35 TOPS"
        case .a17:
            return "16-core, 18 TOPS"
        case .a16Bionic:
            return "16-core, 17 TOPS"
        case .a15Bionic:
            return "16-core, 15.8 TOPS"
        case .a14Bionic:
            return "16-core, 11 TOPS"
        case .a13Bionic:
            return "8-core, 6 TOPS"
        case .older:
            return "Not available"
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
    
    // Hardware Features
    var hasNeuralEngine: Bool {
        return deviceChip.supportsNeuralEngine
    }

    // Computed Properties
    var deviceTier: DeviceTier = .low

    /// Estimated maximum context tokens Apple Intelligence can allocate on this hardware
    /// - Returns ≈50K tokens once Foundation Models are active (PCC available)
    /// - Returns ≈900 tokens for on-device-only execution while models download
    var appleIntelligenceContextTokens: Int {
        if supportsFoundationModels {
            return 50_000 // ≈200K characters before prompt+response overhead
        } else if supportsAppleIntelligence {
            return 900 // ≈3.5K characters processed purely on-device
        } else {
            return 0
        }
    }

    /// Human-readable summary of the Apple Intelligence context behaviour for this device
    var appleIntelligenceContextDescription: String? {
        if supportsFoundationModels {
            return "≈3.5K characters on-device, automatically expanding to ≈200K characters (~50K tokens) via Private Cloud Compute when queries demand it."
        } else if supportsAppleIntelligence {
            return "≈3.5K characters (~900 tokens) handled fully on-device while Foundation Models finish downloading."
        } else {
            return nil
        }
    }

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
    case noRelevantContext
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Query cannot be empty"
        case .noDocumentsAvailable:
            return "No documents have been added to the knowledge base"
        case .noRelevantContext:
            return "No relevant information found in documents. Try rephrasing your query."
        case .retrievalFailed:
            return "Failed to retrieve relevant chunks"
        case .modelNotAvailable:
            return "The selected LLM model is not available"
        }
    }
}

// MARK: - RAGService Tool Handler Implementation
// This enables agentic RAG where the LLM can decide when to search documents

extension RAGService: RAGToolHandler {
    
    /// Search documents for relevant information
    /// Called by the LLM when it needs information from the document library
    func searchDocuments(query: String) async throws -> String {
        print("🔧 [Tool Call] search_documents(query: \"\(query)\")")
        
        // Use the existing RAG pipeline to search
        let queryEmbedding = try await embeddingService.generateEmbedding(for: query)
        
        let retrievedChunks = try await vectorDatabase.search(
            embedding: queryEmbedding,
            topK: 3  // Return top 3 chunks for tool call
        )
        
        if retrievedChunks.isEmpty {
            return "No relevant information found for: \(query)"
        }
        
        // Format retrieved chunks for LLM consumption
        var result = "Found \(retrievedChunks.count) relevant chunks:\n\n"
        
        for (index, retrieved) in retrievedChunks.enumerated() {
            let docName = await getDocumentName(for: retrieved.chunk.documentId)
            result += "[\(index + 1)] From \(docName)"
            if let page = retrieved.chunk.metadata.pageNumber {
                result += " (Page \(page))"
            }
            result += " (Relevance: \(String(format: "%.1f%%", retrieved.similarityScore * 100))):\n"
            let fullText = retrieved.chunk.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = fullText.count > 600 ? String(fullText.prefix(600)) + " [...]" : fullText
            result += preview  // Truncated preview to control token usage
            result += "\n\n"
        }
        
        print("✅ [Tool Call] Returned \(retrievedChunks.count) chunks")
        return result
    }
    
    /// List all available documents
    /// Called by the LLM when user asks what documents are available
    func listDocuments() async throws -> String {
        print("🔧 [Tool Call] list_documents()")
        
        if documents.isEmpty {
            return "No documents available in the library."
        }
        
        var result = "Available documents (\(documents.count)):\n\n"
        
        for (index, doc) in documents.enumerated() {
            result += "\(index + 1). \(doc.filename)\n"
            if let pages = doc.processingMetadata?.pagesProcessed {
                result += "   - Pages: \(pages)\n"
            }
            result += "   - Chunks: \(doc.totalChunks)\n"
            result += "   - Added: \(formatDate(doc.addedAt))\n"
            result += "\n"
        }
        
        print("✅ [Tool Call] Listed \(documents.count) documents")
        return result
    }
    
    /// Get summary of a specific document
    /// Called by the LLM when user asks about a specific document
    func getDocumentSummary(documentName: String) async throws -> String {
        print("🔧 [Tool Call] get_document_summary(documentName: \"\(documentName)\")")
        
        guard let doc = documents.first(where: { $0.filename.lowercased().contains(documentName.lowercased()) }) else {
            return "Document not found: \(documentName)"
        }
        
        var result = "Document: \(doc.filename)\n"
        if let pages = doc.processingMetadata?.pagesProcessed {
            result += "- Pages: \(pages)\n"
        }
        result += "- Chunks: \(doc.totalChunks)\n"
        result += "- Added: \(formatDate(doc.addedAt))\n"
        result += "- File Type: \(doc.contentType.rawValue)"
        
        print("✅ [Tool Call] Returned summary for \(doc.filename)")
        return result
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
