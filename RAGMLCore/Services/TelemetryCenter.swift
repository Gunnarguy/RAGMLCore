import Foundation
import Combine

enum TelemetryCategory: String, CaseIterable {
    case ingestion
    case embedding
    case retrieval
    case generation
    case storage
    case system
    case error

    var symbolName: String {
        switch self {
        case .ingestion: return "tray.and.arrow.down"
        case .embedding: return "brain.head.profile"
        case .retrieval: return "magnifyingglass"
        case .generation: return "sparkles"
        case .storage: return "externaldrive"
        case .system: return "gear"
        case .error: return "exclamationmark.triangle"
        }
    }
}

enum TelemetrySeverity: String, CaseIterable {
    case info
    case warning
    case error

    var tint: String {
        switch self {
        case .info: return "info"
        case .warning: return "warning"
        case .error: return "error"
        }
    }
}

struct TelemetryEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: TelemetryCategory
    let severity: TelemetrySeverity
    let title: String
    let metadata: [String: String]
    let duration: TimeInterval?

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        return String(format: "%.2fs", duration)
    }
}

@MainActor
final class TelemetryCenter: ObservableObject {
    static let shared = TelemetryCenter()

    @Published private(set) var events: [TelemetryEvent] = []

    private let maxEvents = 500

    func log(
        _ category: TelemetryCategory,
        severity: TelemetrySeverity = .info,
        title: String,
        metadata: [String: String] = [:],
        duration: TimeInterval? = nil
    ) {
        let event = TelemetryEvent(
            timestamp: Date(),
            category: category,
            severity: severity,
            title: title,
            metadata: metadata,
            duration: duration
        )
        append(event)
    }

    func append(_ event: TelemetryEvent) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    func clear() {
        events.removeAll()
    }

    nonisolated static func emit(
        _ category: TelemetryCategory,
        severity: TelemetrySeverity = .info,
        title: String,
        metadata: [String: String] = [:],
        duration: TimeInterval? = nil
    ) {
        Task { @MainActor in
            shared.log(
                category,
                severity: severity,
                title: title,
                metadata: metadata,
                duration: duration
            )
        }
    }
}
