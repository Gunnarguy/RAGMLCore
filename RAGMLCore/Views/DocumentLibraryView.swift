//
//  DocumentLibraryView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentLibraryView: View {
    @ObservedObject var ragService: RAGService
    @State private var showingFilePicker = false
    @State private var showingProcessingSummary = false
    @State private var lastProcessedSummary: ProcessingSummary?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Knowledge Base")) {
                    if ragService.documents.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No documents added yet")
                                .font(.headline)
                            Text("Add PDF, text, or markdown files to build your knowledge base")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(ragService.documents) { document in
                            NavigationLink(destination: DocumentDetailsView(document: document)) {
                                DocumentRow(document: document)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        try? await ragService.removeDocument(document)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        Section(footer: Text("\(ragService.totalChunksStored) total chunks stored")) {
                            EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilePicker = true }) {
                        Label("Add Document", systemImage: "plus")
                    }
                    .disabled(ragService.isProcessing)
                }
                
                if !ragService.documents.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(role: .destructive) {
                            Task {
                                try? await ragService.clearAllDocuments()
                            }
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker { url in
                    Task {
                        try? await ragService.addDocument(at: url)
                    }
                }
            }
            .alert("Error Processing Document", isPresented: .constant(ragService.lastError != nil)) {
                Button("OK", role: .cancel) {
                    ragService.lastError = nil
                }
            } message: {
                if let error = ragService.lastError {
                    Text(error)
                }
            }
            .overlay {
                if ragService.isProcessing {
                    ProcessingOverlay(status: ragService.processingStatus)
                }
            }
            .sheet(isPresented: Binding(
                get: { ragService.lastProcessingSummary != nil },
                set: { if !$0 { ragService.lastProcessingSummary = nil } }
            )) {
                if let summary = ragService.lastProcessingSummary {
                    ProcessingSummaryView(summary: summary)
                }
            }
        }
    }
}

struct DocumentRow: View {
    let document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconName(for: document.contentType))
                    .foregroundColor(.accentColor)
                Text(document.filename)
                    .font(.headline)
            }
            
            HStack {
                Text("\(document.totalChunks) chunks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(document.addedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconName(for type: DocumentType) -> String {
        switch type {
        // Documents
        case .pdf:
            return "doc.fill"
        case .text:
            return "doc.text.fill"
        case .markdown:
            return "doc.richtext.fill"
        case .rtf:
            return "doc.richtext.fill"
            
        // Images
        case .png, .jpeg, .heic, .tiff, .gif, .image:
            return "photo.fill"
            
        // Code files
        case .swift:
            return "swift"
        case .python:
            return "chevron.left.forwardslash.chevron.right"
        case .javascript, .typescript:
            return "curlybraces"
        case .java, .cpp, .c, .objc, .go, .rust, .ruby, .php:
            return "chevron.left.forwardslash.chevron.right"
        case .html, .css, .xml:
            return "chevron.left.forwardslash.chevron.right"
        case .json, .yaml:
            return "curlybraces.square.fill"
        case .sql:
            return "cylinder.fill"
        case .shell, .code:
            return "terminal.fill"
            
        // Office documents
        case .word:
            return "doc.text.fill"
        case .excel, .csv:
            return "tablecells.fill"
        case .powerpoint:
            return "rectangle.3.group.fill"
        case .pages:
            return "doc.richtext.fill"
        case .numbers:
            return "tablecells.fill"
        case .keynote:
            return "rectangle.3.group.fill"
            
        case .unknown:
            return "doc.questionmark"
        }
    }
}

struct ProcessingOverlay: View {
    let status: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
                
                VStack(spacing: 8) {
                    // Main status message
                    if !status.isEmpty {
                        let components = status.split(separator: "•", maxSplits: 1)
                        
                        if components.count >= 2 {
                            // Show filename
                            Text(String(components[0]).trimmingCharacters(in: .whitespaces))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            // Show detailed progress
                            HStack(spacing: 6) {
                                Image(systemName: progressIcon(for: String(components[1])))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Text(String(components[1]).trimmingCharacters(in: .whitespaces))
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                        } else {
                            Text(status)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Subtle hint text
                    Text("Processing document...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
        }
    }
    
    private func progressIcon(for status: String) -> String {
        let lowerStatus = status.lowercased()
        
        if lowerStatus.contains("loading") {
            return "arrow.down.circle.fill"
        } else if lowerStatus.contains("extracting") || lowerStatus.contains("page") {
            return "doc.text.magnifyingglass"
        } else if lowerStatus.contains("ocr") {
            return "text.viewfinder"
        } else if lowerStatus.contains("chunking") {
            return "scissors"
        } else if lowerStatus.contains("embedding") {
            return "brain.head.profile"
        } else if lowerStatus.contains("storing") {
            return "cylinder.fill"
        } else {
            return "sparkles"
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf,
            .plainText,
            .text,
            UTType(filenameExtension: "md") ?? .plainText,
            .rtf
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing a security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource")
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Copy to app's document directory
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
            
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: url, to: destinationURL)
                parent.onDocumentPicked(destinationURL)
            } catch {
                print("Error copying document: \(error)")
            }
        }
    }
}

// MARK: - Processing Summary View

struct ProcessingSummaryView: View {
    let summary: ProcessingSummary
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Success header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Document Processed!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(summary.filename)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // File Info Section
                    InfoSection(title: "File Information", icon: "doc.fill", color: .blue) {
                        InfoRow(label: "File Size", value: summary.fileSize)
                        InfoRow(label: "Type", value: summary.documentType.rawValue.capitalized)
                        if let pageCount = summary.pageCount {
                            InfoRow(label: "Pages", value: "\(pageCount)")
                        }
                        if let ocrPages = summary.ocrPagesUsed {
                            InfoRow(label: "OCR Used", value: "\(ocrPages) pages")
                        }
                    }
                    
                    // Content Statistics Section
                    InfoSection(title: "Content Statistics", icon: "text.alignleft", color: .green) {
                        InfoRow(label: "Characters", value: String(format: "%,d", summary.totalChars))
                        InfoRow(label: "Words", value: String(format: "%,d", summary.totalWords))
                        InfoRow(label: "Chunks Created", value: "\(summary.chunksCreated)")
                        InfoRow(label: "Avg Chunk Size", value: "\(summary.chunkStats.avgChars) chars")
                        InfoRow(label: "Size Range", value: "\(summary.chunkStats.minChars) - \(summary.chunkStats.maxChars) chars")
                    }
                    
                    // Performance Section
                    InfoSection(title: "Performance Metrics", icon: "speedometer", color: .orange) {
                        InfoRow(label: "Extraction Time", value: String(format: "%.2f s", summary.extractionTime))
                        InfoRow(label: "Chunking Time", value: String(format: "%.3f s", summary.chunkingTime))
                        InfoRow(label: "Embedding Time", value: String(format: "%.2f s", summary.embeddingTime))
                        InfoRow(label: "Avg per Chunk", value: String(format: "%.0f ms", (summary.embeddingTime / Double(summary.chunksCreated)) * 1000))
                        Divider()
                        InfoRow(label: "Total Time", value: String(format: "%.2f s", summary.totalTime), highlight: true)
                    }
                }
                .padding()
            }
            .navigationTitle("Processing Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(highlight ? .bold : .regular)
                .foregroundColor(highlight ? .primary : .primary)
        }
        .font(highlight ? .body : .subheadline)
    }
}

// MARK: - Document Details View

struct DocumentDetailsView: View {
    let document: Document
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: iconName(for: document.contentType))
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text(document.filename)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(document.contentType.rawValue.uppercased())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack {
                        Label("Added \(document.addedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(12)
                
                // Basic Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Basic Information")
                        .font(.headline)
                    
                    DetailRow(icon: "doc.text", label: "Total Chunks", value: "\(document.totalChunks)")
                    DetailRow(icon: "calendar", label: "Added", value: document.addedAt.formatted(date: .abbreviated, time: .shortened))
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(12)
                
                // Processing Metadata (if available)
                if let metadata = document.processingMetadata {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Processing Details")
                            .font(.headline)
                        
                        DetailRow(icon: "doc.on.doc", label: "File Size", value: String(format: "%.2f MB", metadata.fileSizeMB))
                        DetailRow(icon: "character", label: "Characters", value: metadata.totalCharacters.formatted())
                        DetailRow(icon: "text.word.spacing", label: "Words", value: metadata.totalWords.formatted())
                        
                        if let pages = metadata.pagesProcessed {
                            DetailRow(icon: "doc.plaintext", label: "Pages", value: "\(pages)")
                        }
                        
                        if let ocrPages = metadata.ocrPagesCount, ocrPages > 0 {
                            DetailRow(icon: "text.viewfinder", label: "OCR Pages", value: "\(ocrPages)", highlight: true)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance")
                            .font(.headline)
                        
                        DetailRow(icon: "gauge", label: "Extraction Time", value: String(format: "%.2f s", metadata.extractionTimeSeconds))
                        DetailRow(icon: "scissors", label: "Chunking Time", value: String(format: "%.3f s", metadata.chunkingTimeSeconds))
                        DetailRow(icon: "brain.head.profile", label: "Embedding Time", value: String(format: "%.2f s", metadata.embeddingTimeSeconds))
                        DetailRow(icon: "clock", label: "Total Time", value: String(format: "%.2f s", metadata.totalProcessingTimeSeconds), highlight: true)
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Chunk Statistics")
                            .font(.headline)
                        
                        DetailRow(icon: "chart.bar", label: "Average Size", value: "\(metadata.chunkStats.averageChars) chars")
                        DetailRow(icon: "arrow.down.to.line", label: "Minimum Size", value: "\(metadata.chunkStats.minChars) chars")
                        DetailRow(icon: "arrow.up.to.line", label: "Maximum Size", value: "\(metadata.chunkStats.maxChars) chars")
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Document Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func iconName(for type: DocumentType) -> String {
        switch type {
        case .pdf: return "doc.fill"
        case .text: return "doc.text.fill"
        case .markdown: return "doc.richtext.fill"
        case .rtf: return "doc.richtext.fill"
        case .png, .jpeg, .heic, .tiff, .gif, .image: return "photo.fill"
        case .swift: return "swift"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .javascript, .typescript: return "curlybraces"
        case .java, .cpp, .c, .objc, .go, .rust, .ruby, .php: return "chevron.left.forwardslash.chevron.right"
        case .html, .css, .xml: return "chevron.left.forwardslash.chevron.right"
        case .json, .yaml: return "curlybraces.square.fill"
        case .sql: return "cylinder.fill"
        case .shell, .code: return "terminal.fill"
        case .word: return "doc.text.fill"
        case .excel: return "tablecells.fill"
        case .powerpoint: return "rectangle.3.group.fill"
        case .pages: return "doc.text.fill"
        case .numbers: return "tablecells.fill"
        case .keynote: return "rectangle.3.group.fill"
        case .csv: return "tablecells.fill"
        case .unknown: return "doc.questionmark"
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var highlight: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.accentColor)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(highlight ? .semibold : .regular)
                .foregroundColor(highlight ? .accentColor : .primary)
        }
        .font(.subheadline)
    }
}

#Preview {
    DocumentLibraryView(ragService: RAGService())
}
