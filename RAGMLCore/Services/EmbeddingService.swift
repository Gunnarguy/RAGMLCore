//
//  EmbeddingService.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import Foundation
import NaturalLanguage

/// Service for generating semantic embeddings from text using Apple's on-device models
class EmbeddingService {
    
    // MARK: - Properties
    
    private let embedding: NLEmbedding?
    private let embeddingDimension: Int
    
    // MARK: - Initialization
    
    init() {
        // Initialize Apple's BERT-based contextual embedding model
        self.embedding = NLEmbedding.wordEmbedding(for: .english)
        
        // Apple's model produces 512-dimensional embeddings
        self.embeddingDimension = 512
        
        if embedding == nil {
            print("⚠️ Warning: NLEmbedding not available on this device")
        }
    }
    
    // MARK: - Public API
    
    /// Check if embedding generation is available on this device
    var isAvailable: Bool {
        return embedding != nil
    }
    
    /// Generate a semantic embedding for a text chunk
    /// Returns a 512-dimensional vector representing the semantic meaning
    func generateEmbedding(for text: String) async throws -> [Float] {
        guard let embedding = embedding else {
            print("❌ [EmbeddingService] Model unavailable")
            throw EmbeddingError.modelUnavailable
        }
        
        // Edge case: Empty or whitespace-only text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            print("❌ [EmbeddingService] Empty input text")
            throw EmbeddingError.emptyInput
        }
        
        // Edge case: Very long text (>10k words) - log warning
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count > 10000 {
            print("⚠️  [EmbeddingService] Very long text (\(words.count) words) - may be slow")
        }
        
        guard !words.isEmpty else {
            print("❌ [EmbeddingService] No words after filtering")
            throw EmbeddingError.emptyInput
        }
        
        var wordVectors: [[Double]] = []
        var wordsProcessed = 0
        var wordsSkipped = 0
        
        for word in words {
            // Try original word first, then lowercase
            if let vector = embedding.vector(for: word) {
                wordVectors.append(vector)
                wordsProcessed += 1
            } else if let vector = embedding.vector(for: word.lowercased()) {
                wordVectors.append(vector)
                wordsProcessed += 1
            } else {
                wordsSkipped += 1
            }
        }
        
        // Log coverage for debugging
        if wordsSkipped > 0 && wordsSkipped > words.count / 2 {
            print("⚠️  [EmbeddingService] Low coverage: \(wordsProcessed)/\(words.count) words have embeddings")
        }
        
        // If no word vectors found, use fallback strategy
        let chunkEmbedding: [Float]
        if wordVectors.isEmpty {
            print("⚠️  [EmbeddingService] No vectors returned - using fallback embedding")
            print("   💡 Text: \"\(trimmedText.prefix(50))...\"")
            chunkEmbedding = createFallbackEmbedding(for: trimmedText)
        } else {
            // Average all word embeddings to get a single chunk-level embedding
            chunkEmbedding = self.averageEmbeddings(wordVectors)
        }
        
        // Validate embedding quality
        try validateEmbedding(chunkEmbedding)
        
        return chunkEmbedding
    }
    
    /// Generate embeddings for multiple text chunks in batch
    func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        print("🔢 [EmbeddingService] Generating embeddings for \(texts.count) chunks...")
        let startTime = Date()
        
        var embeddings: [[Float]] = []
        embeddings.reserveCapacity(texts.count)
        
        for (index, text) in texts.enumerated() {
            let embedding = try await generateEmbedding(for: text)
            embeddings.append(embedding)
            
            // Progress indicator for large batches
            if (index + 1) % 50 == 0 {
                print("   Progress: \(index + 1)/\(texts.count) embeddings generated")
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let avgTime = totalTime / Double(texts.count)
        print("✅ [EmbeddingService] Complete: \(texts.count) embeddings in \(String(format: "%.2f", totalTime))s")
        print("   Average: \(String(format: "%.0f", avgTime * 1000))ms per embedding")
        
        return embeddings
    }
    
    // MARK: - Validation
    
    /// Validate that an embedding is well-formed
    private func validateEmbedding(_ embedding: [Float]) throws {
        // Check dimensionality
        guard embedding.count == embeddingDimension else {
            print("❌ [EmbeddingService] Invalid dimension: \(embedding.count) (expected \(embeddingDimension))")
            throw EmbeddingError.invalidDimension(expected: embeddingDimension, actual: embedding.count)
        }
        
        // Check for NaN or Inf values
        for (index, value) in embedding.enumerated() {
            if value.isNaN {
                print("❌ [EmbeddingService] NaN detected at index \(index)")
                throw EmbeddingError.containsNaN
            }
            if value.isInfinite {
                print("❌ [EmbeddingService] Infinite value detected at index \(index)")
                throw EmbeddingError.containsInfinite
            }
        }
        
        // Check that embedding is not all zeros (likely indicates an error)
        let magnitude = embedding.reduce(0.0) { $0 + $1 * $1 }
        if magnitude < 0.0001 { // Very small threshold
            print("⚠️  [EmbeddingService] Warning: Near-zero embedding vector")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Average multiple token embeddings into a single chunk-level embedding
    /// This produces a fixed-size representation regardless of input length
    private func averageEmbeddings(_ vectors: [[Double]]) -> [Float] {
        guard !vectors.isEmpty else {
            return Array(repeating: 0.0, count: embeddingDimension)
        }
        
        let count = vectors.count
        var averaged = Array(repeating: 0.0, count: embeddingDimension)
        
        // Sum all vectors
        for vector in vectors {
            for (i, value) in vector.enumerated() {
                if i < embeddingDimension {
                    averaged[i] += value
                }
            }
        }
        
        // Divide by count to get average
        for i in 0..<embeddingDimension {
            averaged[i] /= Double(count)
        }
        
        // Convert to Float for efficient storage
        return averaged.map { Float($0) }
    }
    
    /// Create a fallback embedding for text with no word vectors
    /// Uses character-level and structural features to create a synthetic embedding
    private func createFallbackEmbedding(for text: String) -> [Float] {
        var embedding = Array(repeating: Float(0.0), count: embeddingDimension)
        
        // Use a simple hash-based approach to create a deterministic embedding
        // This ensures the same text always gets the same embedding
        let normalized = text.lowercased()
        
        // Populate embedding with character frequency features (first 256 dimensions)
        for (index, char) in normalized.unicodeScalars.prefix(256).enumerated() {
            if index < embeddingDimension {
                // Use Unicode value normalized to [-1, 1] range
                embedding[index] = Float(char.value % 256) / 128.0 - 1.0
            }
        }
        
        // Add text length feature (dimension 256-260)
        if embeddingDimension > 256 {
            embedding[256] = Float(min(text.count, 1000)) / 1000.0
        }
        
        // Add word count feature (dimension 261-265)
        if embeddingDimension > 261 {
            let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            embedding[261] = Float(min(wordCount, 100)) / 100.0
        }
        
        // Add numeric content indicator (dimension 266-270)
        if embeddingDimension > 266 {
            let hasNumbers = text.rangeOfCharacter(from: .decimalDigits) != nil
            embedding[266] = hasNumbers ? 1.0 : -1.0
        }
        
        // Normalize to unit length (standard for embeddings)
        let magnitude = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }
        
        return embedding
    }
    
    /// Calculate cosine similarity between two embedding vectors
    /// Returns a value between -1 (opposite) and 1 (identical)
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else {
            print("⚠️ Warning: Embedding dimension mismatch")
            return 0.0
        }
        
        var dotProduct: Float = 0.0
        var magnitudeA: Float = 0.0
        var magnitudeB: Float = 0.0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            magnitudeA += a[i] * a[i]
            magnitudeB += b[i] * b[i]
        }
        
        let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)
        
        guard magnitude > 0 else {
            return 0.0
        }
        
        return dotProduct / magnitude
    }
}

// MARK: - Errors

enum EmbeddingError: LocalizedError {
    case modelUnavailable
    case emptyInput
    case generationFailed(String)
    case noVectorsReturned
    case invalidDimension(expected: Int, actual: Int)
    case containsNaN
    case containsInfinite
    
    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Embedding model is not available on this device"
        case .emptyInput:
            return "Cannot generate embedding for empty text"
        case .generationFailed(let message):
            return "Embedding generation failed: \(message)"
        case .noVectorsReturned:
            return "No embedding vectors were returned"
        case .invalidDimension(let expected, let actual):
            return "Invalid embedding dimension: expected \(expected), got \(actual)"
        case .containsNaN:
            return "Embedding contains NaN values"
        case .containsInfinite:
            return "Embedding contains infinite values"
        }
    }
}
