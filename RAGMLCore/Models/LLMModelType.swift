//
//  LLMModelType.swift
//  RAGMLCore
//
//  Created by GitHub Copilot on 10/24/25.
//

import Foundation

/// Supported high-level LLM integrations that can power the chat experience.
enum LLMModelType: String, CaseIterable {
    case appleIntelligence = "apple_intelligence"   // On-device + PCC automatic
    case chatGPTExtension = "chatgpt_extension"     // Apple Intelligence ChatGPT (iOS 18.1+)
    case onDeviceAnalysis = "on_device_analysis"    // Extractive QA, always available
    case openAIDirect = "openai"                    // User-provided OpenAI API key
    case mlxLocal = "mlx_local"                     // macOS-only local MLX server
    case llamaCppLocal = "llama_cpp_local"          // macOS-only local llama.cpp server
    case ollamaLocal = "ollama_local"               // macOS-only local Ollama server
    case ggufLocal = "gguf_local"                   // iOS-only local GGUF via llama.cpp (in-process)
    case coreMLLocal = "coreml_local"               // Custom Core ML model
}

extension LLMModelType {
    /// User-facing name surfaced inside pickers and diagnostics.
    var displayName: String {
        switch self {
        case .appleIntelligence:
            return "Apple Intelligence"
        case .chatGPTExtension:
            return "ChatGPT Extension"
        case .onDeviceAnalysis:
            return "On-Device Analysis"
        case .openAIDirect:
            return "OpenAI Direct"
        case .mlxLocal:
            return "MLX Local"
        case .llamaCppLocal:
            return "llama.cpp Local"
        case .ollamaLocal:
            return "Ollama Local"
        case .ggufLocal:
            return "GGUF Local (iOS)"
        case .coreMLLocal:
            return "Core ML Local"
        }
    }

    /// SF Symbol identifier used when rendering this model inside pickers.
    var iconName: String {
        switch self {
        case .appleIntelligence:
            return "sparkles"
        case .chatGPTExtension:
            return "bubble.left.and.bubble.right.fill"
        case .onDeviceAnalysis:
            return "doc.text.magnifyingglass"
        case .openAIDirect:
            return "key.fill"
        case .mlxLocal:
            return "server.rack"
        case .llamaCppLocal:
            return "server.rack"
        case .ollamaLocal:
            return "server.rack"
        case .ggufLocal:
            return "doc.badge.gearshape"
        case .coreMLLocal:
            return "cpu"
        }
    }
}
