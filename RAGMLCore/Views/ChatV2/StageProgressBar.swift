//
//  StageProgressBar.swift
//  RAGMLCore
//
//  Visual indicator for embedding → searching → generating stages with execution badge
//  Created by Cline on 10/28/25.
//

import SwiftUI

struct StageProgressBar: View {
    let stage: ChatProcessingStage
    let execution: ChatExecutionLocation
    let ttft: TimeInterval?
    
    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.md) {
                StagePill(icon: "brain.head.profile", label: "Embedding", active: stage == .embedding || stage == .searching || stage == .generating)
                StageConnector(active: stage == .searching || stage == .generating)
                StagePill(icon: "magnifyingglass", label: "Searching", active: stage == .searching || stage == .generating)
                StageConnector(active: stage == .generating)
                StagePill(icon: "sparkles", label: "Generating", active: stage == .generating)
            }
            
            HStack(spacing: DSSpacing.sm) {
                ExecutionBadge(execution: execution, ttft: ttft)
                Spacer()
                if stage == .generating {
                    TypingIndicator()
                }
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(DSColors.surfaceElevated)
        .overlay(
            Rectangle()
                .fill(DSColors.surface.opacity(0.6))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

// MARK: - Stage Elements

private struct StagePill: View {
    let icon: String
    let label: String
    let active: Bool
    
    var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(active ? DSColors.accent : DSColors.secondaryText)
            Text(label)
                .font(DSTypography.meta)
                .foregroundColor(active ? DSColors.accent : DSColors.secondaryText)
        }
        .padding(.horizontal, DSSpacing.xs)
        .padding(.vertical, 6)
        .background(active ? DSColors.chipBackground(for: DSColors.accent) : DSColors.surface)
        .cornerRadius(DSCorners.chip)
        .animation(DSAnimations.fastEase, value: active)
    }
}

private struct StageConnector: View {
    let active: Bool
    var body: some View {
        Capsule()
            .fill(active ? DSColors.accent : DSColors.secondaryText.opacity(0.3))
            .frame(width: 24, height: 3)
            .animation(DSAnimations.fastEase, value: active)
    }
}

// MARK: - Execution Badge

struct ExecutionBadge: View {
    let execution: ChatExecutionLocation
    let ttft: TimeInterval?
    
    var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            Image(systemName: execution.icon)
                .font(.caption2)
                .foregroundColor(execution.color)
            Text(execution.displayName)
                .font(DSTypography.meta)
                .foregroundColor(execution.color)
            if let ttft {
                Text("•")
                    .font(DSTypography.meta)
                    .foregroundColor(DSColors.secondaryText)
                Text(String(format: "%.2fs", ttft))
                    .font(DSTypography.meta)
                    .foregroundColor(DSColors.secondaryText)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, DSSpacing.xs)
        .padding(.vertical, 6)
        .background(execution.color.opacity(0.1))
        .cornerRadius(DSCorners.chip)
        .animation(DSAnimations.fastEase, value: execution.displayName)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        StageProgressBar(stage: .embedding, execution: .unknown, ttft: nil)
        StageProgressBar(stage: .searching, execution: .onDevice, ttft: 0.42)
        StageProgressBar(stage: .generating, execution: .privateCloudCompute, ttft: 1.33)
    }
    .background(DSColors.background)
}
