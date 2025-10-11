//
//  RAGQuery.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import Foundation

/// Represents a user query in the RAG pipeline
struct RAGQuery {
    let id: UUID
    let query: String
    let timestamp: Date
    let topK: Int
    
    init(id: UUID = UUID(), query: String, timestamp: Date = Date(), topK: Int = 3) {
        self.id = id
        self.query = query
        self.timestamp = timestamp
        self.topK = topK
    }
}

/// Result of a RAG query including retrieved context and generated response
struct RAGResponse {
    let id: UUID
    let queryId: UUID
    let retrievedChunks: [RetrievedChunk]
    let generatedResponse: String
    let metadata: ResponseMetadata
    
    init(id: UUID = UUID(), queryId: UUID, retrievedChunks: [RetrievedChunk], generatedResponse: String, metadata: ResponseMetadata) {
        self.id = id
        self.queryId = queryId
        self.retrievedChunks = retrievedChunks
        self.generatedResponse = generatedResponse
        self.metadata = metadata
    }
}

/// A document chunk retrieved for context with its similarity score
struct RetrievedChunk {
    let chunk: DocumentChunk
    let similarityScore: Float
    let rank: Int
}

/// Performance and execution metadata for a RAG response
struct ResponseMetadata {
    let timeToFirstToken: TimeInterval?
    let totalGenerationTime: TimeInterval
    let tokensGenerated: Int
    let tokensPerSecond: Float?
    let modelUsed: String
    let retrievalTime: TimeInterval
    
    init(timeToFirstToken: TimeInterval? = nil,
         totalGenerationTime: TimeInterval,
         tokensGenerated: Int,
         tokensPerSecond: Float? = nil,
         modelUsed: String,
         retrievalTime: TimeInterval) {
        self.timeToFirstToken = timeToFirstToken
        self.totalGenerationTime = totalGenerationTime
        self.tokensGenerated = tokensGenerated
        self.tokensPerSecond = tokensPerSecond
        self.modelUsed = modelUsed
        self.retrievalTime = retrievalTime
    }
}
