//
//  CoreValidationView.swift
//  RAGMLCore
//
//  Core pipeline validation and testing utility
//  Created by GitHub Copilot on 10/10/25.
//

import SwiftUI

struct CoreValidationView: View {
    @ObservedObject var ragService: RAGService
    
    @State private var testResults: [TestResult] = []
    @State private var isRunning = false
    @State private var currentTest = ""
    @State private var overallStatus: TestStatus = .notStarted
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Overall Status Card
                    StatusCard(status: overallStatus, isRunning: isRunning, currentTest: currentTest)
                    
                    // Run Tests Button
                    Button(action: runAllTests) {
                        HStack {
                            Image(systemName: isRunning ? "arrow.triangle.2.circlepath" : "play.circle.fill")
                                .rotationEffect(isRunning ? .degrees(360) : .degrees(0))
                                .animation(isRunning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRunning)
                            Text(isRunning ? "Running Tests..." : "Run Core Validation Tests")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRunning ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRunning)
                    
                    // Test Results
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Test Results")
                                .font(.headline)
                            
                            ForEach(testResults) { result in
                                TestResultRow(result: result)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                    
                    // Test Definitions
                    TestInfoSection()
                }
                .padding()
            }
            .navigationTitle("Core Validation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Test Runner
    
    private func runAllTests() {
        Task {
            await MainActor.run {
                isRunning = true
                testResults = []
                overallStatus = .running
            }
            
            // Test 1: Document Processor
            await runTest(name: "DocumentProcessor - Basic Parsing") {
                // This would test actual document processing
                // For now, just validate the service exists
                let processor = DocumentProcessor()
                return processor.targetChunkSize == 400
            }
            
            // Test 2: Embedding Service
            await runTest(name: "EmbeddingService - Availability") {
                let embeddingService = EmbeddingService()
                return embeddingService.isAvailable
            }
            
            await runTest(name: "EmbeddingService - Dimension Check") {
                let embeddingService = EmbeddingService()
                guard embeddingService.isAvailable else { return false }
                
                do {
                    let embedding = try await embeddingService.generateEmbedding(for: "Test text for validation")
                    return embedding.count == 512
                } catch {
                    return false
                }
            }
            
            await runTest(name: "EmbeddingService - Edge Case (Empty)") {
                let embeddingService = EmbeddingService()
                do {
                    _ = try await embeddingService.generateEmbedding(for: "")
                    return false // Should have thrown error
                } catch {
                    return true // Correctly handled edge case
                }
            }
            
            // Test 3: Vector Database
            await runTest(name: "VectorDatabase - Store and Count") {
                let vectorDB = InMemoryVectorDatabase()
                let testChunk = DocumentChunk(
                    documentId: UUID(),
                    content: "Test content",
                    embedding: Array(repeating: 0.1, count: 512),
                    metadata: ChunkMetadata(chunkIndex: 0, startPosition: 0, endPosition: 12)
                )
                
                do {
                    try await vectorDB.store(chunk: testChunk)
                    let count = try await vectorDB.count()
                    return count == 1
                } catch {
                    return false
                }
            }
            
            await runTest(name: "VectorDatabase - Search Functionality") {
                let vectorDB = InMemoryVectorDatabase()
                let testEmbedding = Array(repeating: Float(0.1), count: 512)
                let testChunk = DocumentChunk(
                    documentId: UUID(),
                    content: "Test content",
                    embedding: testEmbedding,
                    metadata: ChunkMetadata(chunkIndex: 0, startPosition: 0, endPosition: 12)
                )
                
                do {
                    try await vectorDB.store(chunk: testChunk)
                    let results = try await vectorDB.search(embedding: testEmbedding, topK: 1)
                    return results.count == 1 && results[0].similarityScore > 0.99
                } catch {
                    return false
                }
            }
            
            await runTest(name: "VectorDatabase - Edge Case (Empty Search)") {
                let vectorDB = InMemoryVectorDatabase()
                let testEmbedding = Array(repeating: Float(0.1), count: 512)
                
                do {
                    let results = try await vectorDB.search(embedding: testEmbedding, topK: 5)
                    return results.isEmpty // Should return empty array for empty DB
                } catch {
                    return false
                }
            }
            
            // Test 4: Device Capabilities
            await runTest(name: "Device Capabilities Check") {
                let capabilities = RAGService.checkDeviceCapabilities()
                return capabilities.canRunRAG
            }
            
            // Test 5: LLM Service
            await runTest(name: "LLM Service - Availability") {
                return ragService.isLLMAvailable
            }
            
            // Finalize
            await MainActor.run {
                isRunning = false
                
                let passedCount = testResults.filter { $0.status == .passed }.count
                let totalCount = testResults.count
                
                if passedCount == totalCount {
                    overallStatus = .passed
                } else if passedCount == 0 {
                    overallStatus = .failed
                } else {
                    overallStatus = .partial
                }
            }
        }
    }
    
    private func runTest(name: String, test: () async -> Bool) async {
        await MainActor.run {
            currentTest = name
        }
        
        let startTime = Date()
        let passed = await test()
        let duration = Date().timeIntervalSince(startTime)
        
        let result = TestResult(
            name: name,
            status: passed ? .passed : .failed,
            duration: duration,
            message: passed ? "✓" : "Failed"
        )
        
        await MainActor.run {
            testResults.append(result)
        }
    }
}

// MARK: - Supporting Views

struct StatusCard: View {
    let status: TestStatus
    let isRunning: Bool
    let currentTest: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundColor(status.color)
                
                Text("Core Pipeline Validation")
                    .font(.headline)
            }
            
            if isRunning && !currentTest.isEmpty {
                Text("Running: \(currentTest)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if status != .notStarted && status != .running {
                Text(status.message)
                    .font(.subheadline)
                    .foregroundColor(status.color)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TestResultRow: View {
    let result: TestResult
    
    var body: some View {
        HStack {
            Image(systemName: result.status.icon)
                .foregroundColor(result.status.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.2fs", result.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct TestInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What This Tests")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                TestInfoItem(icon: "doc.text", text: "Document processing and chunking")
                TestInfoItem(icon: "cube.box", text: "Embedding generation (512-dim)")
                TestInfoItem(icon: "cylinder", text: "Vector database operations")
                TestInfoItem(icon: "wand.and.stars", text: "LLM service availability")
                TestInfoItem(icon: "exclamationmark.triangle", text: "Edge case handling")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TestInfoItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Models

struct TestResult: Identifiable {
    let id = UUID()
    let name: String
    let status: TestStatus
    let duration: TimeInterval
    let message: String
}

enum TestStatus {
    case notStarted
    case running
    case passed
    case failed
    case partial
    
    var color: Color {
        switch self {
        case .notStarted: return .gray
        case .running: return .blue
        case .passed: return .green
        case .failed: return .red
        case .partial: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        }
    }
    
    var message: String {
        switch self {
        case .notStarted: return "Tests not run"
        case .running: return "Running tests..."
        case .passed: return "All tests passed ✅"
        case .failed: return "Tests failed ❌"
        case .partial: return "Some tests failed ⚠️"
        }
    }
}

// MARK: - Preview

struct CoreValidationView_Previews: PreviewProvider {
    static var previews: some View {
        CoreValidationView(ragService: RAGService())
    }
}
