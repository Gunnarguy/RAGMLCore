//
//  ModelPipelineStage.swift
//  RAGMLCore
//
//  Created by GitHub Copilot on 10/24/25.
//

import SwiftUI

/// Describes one stage in the model execution pipeline including fallbacks.
struct ModelPipelineStage: Identifiable {
    enum Role {
        case primary
        case fallback
        case optional

        var title: String {
            switch self {
            case .primary:
                return "Primary"
            case .fallback:
                return "Fallback"
            case .optional:
                return "Optional"
            }
        }

        var tint: Color {
            switch self {
            case .primary:
                return .green
            case .fallback:
                return .blue
            case .optional:
                return .secondary
            }
        }
    }

    enum Status {
        case active
        case available
        case unavailable(reason: String)
        case requiresConfiguration(message: String)
        case disabled
    }

    let id: String
    let name: String
    let role: Role
    let detail: String
    let status: Status
    let icon: String

    init(name: String, role: Role, detail: String, status: Status, icon: String) {
        self.id = name
        self.name = name
        self.role = role
        self.detail = detail
        self.status = status
        self.icon = icon
    }
}
