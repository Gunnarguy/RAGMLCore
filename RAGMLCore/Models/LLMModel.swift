//
//  LLMModel.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import Foundation

/// Represents an available LLM that can be used for generation
struct LLMModel: Identifiable, Codable {
    let id: UUID
    let name: String
    let modelType: ModelType
    let filePath: URL?
    let parameterCount: String
    let quantization: String?
    let contextLength: Int
    let isAvailable: Bool
    
    init(id: UUID = UUID(), 
         name: String, 
         modelType: ModelType, 
         filePath: URL? = nil,
         parameterCount: String,
         quantization: String? = nil,
         contextLength: Int,
         isAvailable: Bool) {
        self.id = id
        self.name = name
        self.modelType = modelType
        self.filePath = filePath
        self.parameterCount = parameterCount
        self.quantization = quantization
        self.contextLength = contextLength
        self.isAvailable = isAvailable
    }
}

enum ModelType: String, Codable {
    case appleFoundation = "Apple Foundation"
    case coreMLPackage = "Core ML Package"
    case gguf = "GGUF"
}

/// Represents the execution pathway for LLM inference
enum InferencePathway {
    case foundationModels  // Pathway A: Apple's integrated solution
    case coreMLConverted   // Pathway B1: Official Core ML conversion
    case ggufDirect        // Pathway B2: Direct GGUF execution via llama.cpp
}

/// Configuration for model inference performance
struct InferenceConfig {
    var maxTokens: Int = 512
    var temperature: Float = 0.7
    var topP: Float = 0.9
    var topK: Int = 40
    var useKVCache: Bool = true
    
    // Apple Intelligence Execution Context (iOS 26+)
    var executionContext: ExecutionContext = .automatic
    var allowPrivateCloudCompute: Bool = true  // User-controlled PCC permission
}

/// Defines where Apple Foundation Models should execute
enum ExecutionContext {
    case automatic      // Let system decide (on-device → PCC fallback)
    case onDeviceOnly   // Force on-device only (will fail if too complex)
    case preferCloud    // Prefer Private Cloud Compute for better quality
    case cloudOnly      // Force PCC (requires network)
    
    var description: String {
        switch self {
        case .automatic:
            return "Automatic (Hybrid)"
        case .onDeviceOnly:
            return "On-Device Only"
        case .preferCloud:
            return "Prefer Cloud"
        case .cloudOnly:
            return "Cloud Only"
        }
    }
    
    var emoji: String {
        switch self {
        case .automatic:
            return "🔄"
        case .onDeviceOnly:
            return "📱"
        case .preferCloud:
            return "☁️"
        case .cloudOnly:
            return "🌐"
        }
    }
}
