//
//  ChatMessage.swift
//  RAGMLCore
//
//  Extracted shared chat message model used by ChatV2 (and legacy).
//

import Foundation

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
