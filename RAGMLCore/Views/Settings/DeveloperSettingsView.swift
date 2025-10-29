//
//  DeveloperSettingsView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/19/25.
//

import SwiftUI

struct DeveloperSettingsView: View {
    @AppStorage("loggingLevel") private var loggingLevelRaw: Int = LoggingConfiguration.Level.info.rawValue
    @AppStorage("enablePipelineLogs") private var enablePipelineLogs: Bool = true
    @AppStorage("enablePerformanceLogs") private var enablePerformanceLogs: Bool = true
    @AppStorage("enableLLMLogs") private var enableLLMLogs: Bool = true
    @AppStorage("enableStreamingLogs") private var enableStreamingLogs: Bool = false
    @AppStorage("enableVectorDBLogs") private var enableVectorDBLogs: Bool = true
    @AppStorage("enableTelemetryLogs") private var enableTelemetryLogs: Bool = true
    
    private var loggingLevel: LoggingConfiguration.Level {
        get { LoggingConfiguration.Level(rawValue: loggingLevelRaw) ?? .info }
        set {
            loggingLevelRaw = newValue.rawValue
            applyLoggingSettings()
        }
    }
    
    var body: some View {
        Form {
            // MARK: - Logging Level
            Section {
                Picker("Logging Level", selection: $loggingLevelRaw) {
                    Text("Silent (Production)").tag(LoggingConfiguration.Level.silent.rawValue)
                    Text("Error Only").tag(LoggingConfiguration.Level.error.rawValue)
                    Text("Warning").tag(LoggingConfiguration.Level.warning.rawValue)
                    Text("Info (Default)").tag(LoggingConfiguration.Level.info.rawValue)
                    Text("Debug (Verbose)").tag(LoggingConfiguration.Level.debug.rawValue)
                    Text("Verbose (Maximum)").tag(LoggingConfiguration.Level.verbose.rawValue)
                }
                .pickerStyle(.menu)
                
                currentLevelInfo
                
            } header: {
                Text("Console Logging Level")
            } footer: {
                Text("Controls overall verbosity of console output. Set to 'Silent' for production to minimize log spam.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Category Toggles
            Section {
                Toggle(isOn: $enablePipelineLogs) {
                    Label("RAG Pipeline", systemImage: "arrow.triangle.branch")
                }
                .onChange(of: enablePipelineLogs) { applyLoggingSettings() }
                
                Toggle(isOn: $enablePerformanceLogs) {
                    Label("Performance Metrics", systemImage: "gauge")
                }
                .onChange(of: enablePerformanceLogs) { applyLoggingSettings() }
                
                Toggle(isOn: $enableLLMLogs) {
                    Label("LLM Generation", systemImage: "brain.head.profile")
                }
                .onChange(of: enableLLMLogs) { applyLoggingSettings() }
                
                Toggle(isOn: $enableStreamingLogs) {
                    Label("Token Streaming", systemImage: "waveform")
                }
                .onChange(of: enableStreamingLogs) { applyLoggingSettings() }
                
                Toggle(isOn: $enableVectorDBLogs) {
                    Label("Vector Database", systemImage: "network")
                }
                .onChange(of: enableVectorDBLogs) { applyLoggingSettings() }
                
                Toggle(isOn: $enableTelemetryLogs) {
                    Label("Telemetry Events", systemImage: "chart.xyaxis.line")
                }
                .onChange(of: enableTelemetryLogs) { applyLoggingSettings() }
                
            } header: {
                Text("Logging Categories")
            } footer: {
                Text("Enable or disable specific logging categories. Disabling 'Token Streaming' dramatically reduces console spam during response generation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Presets
            Section {
                Button(action: applyProductionPreset) {
                    Label("Production (Minimal)", systemImage: "checkmark.shield.fill")
                }
                
                Button(action: applyDevelopmentPreset) {
                    Label("Development (Balanced)", systemImage: "hammer.fill")
                }
                
                Button(action: applyDebugPreset) {
                    Label("Debug (Maximum)", systemImage: "ant.fill")
                }
                
            } header: {
                Text("Presets")
            } footer: {
                Text("Quick presets for common scenarios. Production: errors only. Development: key logs enabled. Debug: everything enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - System Warnings
            Section {
                Toggle(isOn: .constant(false)) {
                    Label("Suppress iOS Warnings", systemImage: "exclamationmark.triangle")
                }
                .disabled(true)
                
                Text("Note: System warnings (NSMapGet, UIKeyboard, Metal HUD, etc.) are generated by iOS frameworks and cannot be suppressed from app code. Use Xcode's console filter to hide them.")
                    .font(.caption2)
                    .foregroundColor(.orange)
                
            } header: {
                Text("System Logs")
            }
            
            // MARK: - Current Settings
            Section {
                HStack {
                    Text("Active Level:")
                    Spacer()
                    Text(loggingLevel.description)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Categories Enabled:")
                    Spacer()
                    Text("\(enabledCategoriesCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Estimated Log Volume:")
                    Spacer()
                    Text(estimatedLogVolume)
                        .foregroundColor(logVolumeColor)
                }
                
            } header: {
                Text("Current Configuration")
            }
        }
        .navigationTitle("Developer Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            applyLoggingSettings()
        }
    }
    
    // MARK: - Computed Properties
    
    @ViewBuilder
    private var currentLevelInfo: some View {
        switch loggingLevel {
        case .silent:
            InfoBox(icon: "moon.zzz.fill", text: "All console output disabled (production mode)", color: .gray)
        case .error:
            InfoBox(icon: "xmark.circle.fill", text: "Only critical errors will be logged", color: .red)
        case .warning:
            InfoBox(icon: "exclamationmark.triangle.fill", text: "Errors and warnings will be logged", color: .orange)
        case .info:
            InfoBox(icon: "info.circle.fill", text: "Errors, warnings, and key operations (recommended)", color: .blue)
        case .debug:
            InfoBox(icon: "ant.circle.fill", text: "Verbose logging for development and debugging", color: .purple)
        case .verbose:
            InfoBox(icon: "text.bubble.fill", text: "Maximum verbosity - all logs including streaming", color: .green)
        }
    }
    
    private var enabledCategoriesCount: Int {
        var count = 0
        if enablePipelineLogs { count += 1 }
        if enablePerformanceLogs { count += 1 }
        if enableLLMLogs { count += 1 }
        if enableStreamingLogs { count += 1 }
        if enableVectorDBLogs { count += 1 }
        if enableTelemetryLogs { count += 1 }
        return count
    }
    
    private var estimatedLogVolume: String {
        if loggingLevel == .silent { return "None" }
        if loggingLevel == .error { return "Very Low" }
        
        let categoryMultiplier = Double(enabledCategoriesCount) / 6.0
        
        switch loggingLevel {
        case .warning:
            return categoryMultiplier > 0.5 ? "Low-Medium" : "Low"
        case .info:
            return categoryMultiplier > 0.7 ? "Medium" : "Medium-Low"
        case .debug:
            return enableStreamingLogs ? "Very High" : "High"
        case .verbose:
            return "Extreme"
        default:
            return "Unknown"
        }
    }
    
    private var logVolumeColor: Color {
        switch estimatedLogVolume {
        case "None", "Very Low", "Low": return .green
        case "Low-Medium", "Medium-Low", "Medium": return .blue
        case "High": return .orange
        case "Very High", "Extreme": return .red
        default: return .gray
        }
    }
    
    // MARK: - Actions
    
    private func applyLoggingSettings() {
        // Update global logging configuration
        LoggingConfiguration.currentLevel = loggingLevel
        
        // Update enabled categories
        var categories: Set<LoggingConfiguration.Category> = []
        if enablePipelineLogs { categories.insert(.pipeline) }
        if enablePerformanceLogs { categories.insert(.performance) }
        if enableLLMLogs { categories.insert(.llm) }
        if enableStreamingLogs { categories.insert(.streaming) }
        if enableVectorDBLogs { categories.insert(.vectorDB) }
        if enableTelemetryLogs { categories.insert(.telemetry) }
        
        LoggingConfiguration.enabledCategories = categories
        
        print("✅ [Developer Settings] Logging configuration updated")
        print("   Level: \(loggingLevel)")
        print("   Categories: \(categories.map { "\($0)" }.joined(separator: ", "))")
    }
    
    private func applyProductionPreset() {
        loggingLevelRaw = LoggingConfiguration.Level.error.rawValue
        enablePipelineLogs = false
        enablePerformanceLogs = false
        enableLLMLogs = false
        enableStreamingLogs = false
        enableVectorDBLogs = false
        enableTelemetryLogs = false
        applyLoggingSettings()
    }
    
    private func applyDevelopmentPreset() {
        loggingLevelRaw = LoggingConfiguration.Level.info.rawValue
        enablePipelineLogs = true
        enablePerformanceLogs = true
        enableLLMLogs = true
        enableStreamingLogs = false  // Keep disabled to reduce spam
        enableVectorDBLogs = true
        enableTelemetryLogs = false
        applyLoggingSettings()
    }
    
    private func applyDebugPreset() {
        loggingLevelRaw = LoggingConfiguration.Level.verbose.rawValue
        enablePipelineLogs = true
        enablePerformanceLogs = true
        enableLLMLogs = true
        enableStreamingLogs = true
        enableVectorDBLogs = true
        enableTelemetryLogs = true
        applyLoggingSettings()
    }
}

// MARK: - Supporting Views

struct InfoBox: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Extensions

extension LoggingConfiguration.Level: CustomStringConvertible {
    var description: String {
        switch self {
        case .silent: return "Silent"
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Info"
        case .debug: return "Debug"
        case .verbose: return "Verbose"
        }
    }
}

#Preview {
    NavigationView {
        DeveloperSettingsView()
    }
}
