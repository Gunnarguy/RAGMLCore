//
//  VectorDatabase.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import Foundation

/// Protocol defining the interface for any vector database implementation
/// This abstraction allows swapping between VecturaKit, ObjectBox, SVDB, etc.
protocol VectorDatabase {
    /// Store a document chunk with its embedding
    func store(chunk: DocumentChunk) async throws
    
    /// Store multiple chunks in batch
    func storeBatch(chunks: [DocumentChunk]) async throws
    
    /// Search for the k most similar chunks to a query embedding
    func search(embedding: [Float], topK: Int) async throws -> [RetrievedChunk]
    
    /// Delete all chunks for a specific document
    func deleteChunks(forDocument documentId: UUID) async throws
    
    /// Clear the entire database
    func clear() async throws
    
    /// Get total count of stored chunks
    func count() async throws -> Int
}

/// In-memory vector database implementation
/// For production scale, consider VecturaKit, ObjectBox, or SVDB for persistent storage and HNSW indexing
class InMemoryVectorDatabase: VectorDatabase {
    
    // MARK: - Storage
    
    private var chunks: [UUID: DocumentChunk] = [:]
    private let queue = DispatchQueue(label: "com.ragmlcore.vectordb", attributes: .concurrent)
    
    // MARK: - VectorDatabase Protocol
    
    func store(chunk: DocumentChunk) async throws {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.chunks[chunk.id] = chunk
                continuation.resume()
            }
        }
    }
    
    func storeBatch(chunks: [DocumentChunk]) async throws {
        print("💾 [VectorDatabase] Storing \(chunks.count) chunks...")
        let startTime = Date()
        
        // Validate embeddings before storing
        for (index, chunk) in chunks.enumerated() {
            guard chunk.embedding.count == 512 else {
                print("❌ [VectorDatabase] Invalid embedding dimension at index \(index): \(chunk.embedding.count)")
                throw VectorDatabaseError.invalidEmbedding
            }
        }
        
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                for chunk in chunks {
                    self.chunks[chunk.id] = chunk
                }
                continuation.resume()
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("✅ [VectorDatabase] Stored \(chunks.count) chunks in \(String(format: "%.2f", totalTime))s")
        print("   Total chunks in database: \(self.chunks.count)")
    }
    
    func search(embedding: [Float], topK: Int) async throws -> [RetrievedChunk] {
        let startTime = Date()
        
        // Edge case: Empty database
        guard chunks.count > 0 else {
            print("⚠️  [VectorDatabase] Search on empty database")
            return []
        }
        
        // Edge case: topK larger than database size
        let effectiveTopK = min(topK, chunks.count)
        if effectiveTopK < topK {
            print("⚠️  [VectorDatabase] Requested topK=\(topK) but only \(chunks.count) chunks available")
        }
        
        // Validate query embedding
        guard embedding.count == 512 else {
            print("❌ [VectorDatabase] Invalid query embedding dimension: \(embedding.count)")
            throw VectorDatabaseError.invalidEmbedding
        }
        
        print("🔍 [VectorDatabase] Searching \(chunks.count) chunks for top \(effectiveTopK)...")
        
        return await withCheckedContinuation { continuation in
            queue.async {
                // Calculate similarity scores for all chunks
                var scoredChunks: [(chunk: DocumentChunk, score: Float)] = []
                
                for (_, chunk) in self.chunks {
                    let similarity = self.cosineSimilarity(embedding, chunk.embedding)
                    scoredChunks.append((chunk, similarity))
                }
                
                // Sort by similarity (descending) and take top K
                let topChunks = scoredChunks
                    .sorted { $0.score > $1.score }
                    .prefix(effectiveTopK)
                    .enumerated()
                    .map { index, element in
                        RetrievedChunk(
                            chunk: element.chunk,
                            similarityScore: element.score,
                            rank: index + 1
                        )
                    }
                
                let searchTime = Date().timeIntervalSince(startTime)
                print("✅ [VectorDatabase] Search complete in \(String(format: "%.0f", searchTime * 1000))ms")
                
                // Log top results for debugging
                if !topChunks.isEmpty {
                    print("   Top result: score=\(String(format: "%.3f", topChunks[0].similarityScore))")
                    if topChunks.count > 1 {
                        print("   Score range: \(String(format: "%.3f", topChunks.last!.similarityScore)) - \(String(format: "%.3f", topChunks[0].similarityScore))")
                    }
                }
                
                continuation.resume(returning: Array(topChunks))
            }
        }
    }
    
    func deleteChunks(forDocument documentId: UUID) async throws {
        let beforeCount = chunks.count
        
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.chunks = self.chunks.filter { $0.value.documentId != documentId }
                continuation.resume()
            }
        }
        
        let deletedCount = beforeCount - chunks.count
        print("🗑️  [VectorDatabase] Deleted \(deletedCount) chunks for document \(documentId)")
    }
    
    func clear() async throws {
        let count = chunks.count
        
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.chunks.removeAll()
                continuation.resume()
            }
        }
        
        print("🗑️  [VectorDatabase] Cleared all \(count) chunks")
    }
    
    func count() async throws -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.chunks.count)
            }
        }
    }
    
    // MARK: - Similarity Calculation
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var magnitudeA: Float = 0.0
        var magnitudeB: Float = 0.0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            magnitudeA += a[i] * a[i]
            magnitudeB += b[i] * b[i]
        }
        
        let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)
        guard magnitude > 0 else { return 0.0 }
        
        return dotProduct / magnitude
    }
}

// MARK: - Errors

enum VectorDatabaseError: LocalizedError {
    case invalidEmbedding
    case dimensionMismatch
    case storeFailed(String)
    case searchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmbedding:
            return "Invalid embedding format or dimension"
        case .dimensionMismatch:
            return "Embedding dimension does not match database requirements"
        case .storeFailed(let message):
            return "Failed to store chunk: \(message)"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        }
    }
}

// MARK: - VecturaKit Integration (Optional Enhancement)
// Uncomment when VecturaKit is added via Swift Package Manager

/*
import VecturaKit

class VecturaVectorDatabase: VectorDatabase {
    private let vectura: VecturaDB
    
    init() throws {
        // Initialize VecturaKit with hybrid search enabled
        self.vectura = try VecturaDB(
            dimension: 512,
            enableHybridSearch: true
        )
    }
    
    func store(chunk: DocumentChunk) async throws {
        try await vectura.insert(
            id: chunk.id.uuidString,
            vector: chunk.embedding,
            metadata: [
                "content": chunk.content,
                "documentId": chunk.documentId.uuidString,
                "chunkIndex": chunk.metadata.chunkIndex
            ]
        )
    }
    
    func search(embedding: [Float], topK: Int) async throws -> [RetrievedChunk] {
        let results = try await vectura.search(
            query: embedding,
            topK: topK,
            filter: nil
        )
        
        // Map VecturaKit results to RetrievedChunk
        return results.enumerated().map { index, result in
            // Reconstruct chunk from metadata
            // Implementation details depend on VecturaKit's API
            // This is a placeholder structure
            RetrievedChunk(
                chunk: reconstructChunk(from: result),
                similarityScore: result.score,
                rank: index + 1
            )
        }
    }
    
    // Additional implementations...
}
*/
