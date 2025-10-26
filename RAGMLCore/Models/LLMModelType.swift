//
//  LLMModelType.swift
//  RAGMLCore
//
//  Created by GitHub Copilot on 10/24/25.
//

import Foundation

/// Supported high-level LLM integrations that can power the chat experience.
enum LLMModelType: String, CaseIterable {
    case appleIntelligence = "apple_intelligence"  // On-device + PCC automatic
    case chatGPTExtension = "chatgpt_extension"    // Apple Intelligence ChatGPT (iOS 18.1+)
    case onDeviceAnalysis = "on_device_analysis"   // Extractive QA, always available
    case openAIDirect = "openai"                   // User-provided OpenAI API key
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
        }
    }
}
