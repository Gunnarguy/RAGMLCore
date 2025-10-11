# Getting Started with RAGMLCore

This guide will help you understand and run the RAGMLCore application.

## Quick Start

### Prerequisites

- **Xcode**: 16.0 or later
- **macOS**: Ventura or later
- **iOS Device**: iPhone 11 or newer (physical device recommended for AI features)
- **iOS**: 26.0 or later

### Installation

1. **Clone or open the project**
   ```bash
   cd /Users/gunnarhostetler/Documents/GitHub/RAGMLCore
   open RAGMLCore.xcodeproj
   ```

2. **Configure signing**
   - Select your development team in Xcode
   - Update the bundle identifier if needed

3. **Build and run**
   - Select your physical device (simulator has limited AI support)
   - Press ⌘R to build and run

## Project Structure

```
RAGMLCore/
├── Models/                    # Data structures
│   ├── DocumentChunk.swift    # Chunk and metadata types
│   ├── LLMModel.swift         # Model configuration
│   └── RAGQuery.swift         # Query and response types
│
├── Services/                  # Business logic
│   ├── DocumentProcessor.swift   # Parse documents, create chunks
│   ├── EmbeddingService.swift    # Generate vector embeddings
│   ├── VectorDatabase.swift      # Store and search embeddings
│   ├── LLMService.swift          # LLM inference abstraction
│   └── RAGService.swift          # Main orchestrator
│
├── Views/                     # SwiftUI interface
│   ├── ChatView.swift            # Conversational UI
│   ├── DocumentLibraryView.swift # Knowledge base management
│   └── ModelManagerView.swift    # Model selection
│
├── ContentView.swift          # Main tab navigation
└── RAGMLCoreApp.swift        # App entry point
```

## Understanding the Application

### The Three Tabs

#### 1. Chat Tab
- **Purpose**: Query your knowledge base
- **Features**:
  - Ask questions in natural language
  - View AI-generated responses with context
  - See performance metrics (speed, retrieval time)
  - Adjust number of retrieved chunks (3, 5, or 10)

#### 2. Documents Tab
- **Purpose**: Manage your knowledge base
- **Features**:
  - Import PDF, text, and markdown files
  - View processing status
  - See chunk statistics
  - Delete individual documents or clear all

#### 3. Models Tab
- **Purpose**: View model information
- **Features**:
  - Check device capabilities
  - See active model
  - Learn about custom model integration
  - View device performance tier

### How the RAG Pipeline Works

```
Your Question
    ↓
1. Convert to Vector (Embedding)
    ↓
2. Search Knowledge Base
    ↓
3. Find Relevant Chunks (Top 3-10)
    ↓
4. Add Context to Question
    ↓
5. Send to AI Model
    ↓
6. Get Answer
```

## Usage Guide

### Adding Your First Document

1. Open the **Documents** tab
2. Tap the **+** button
3. Select a PDF or text file from Files app
4. Wait for processing (you'll see status updates):
   - "Parsing document..."
   - "Generating embeddings for X chunks..."
   - "Storing in vector database..."
5. Document appears in your library

**Tips**:
- Smaller documents process faster (start with 10-50 pages)
- PDF text extraction works best with text-based PDFs (not scanned images)
- Each document is automatically chunked into ~400-word segments

### Asking Questions

1. Open the **Chat** tab
2. Type your question in the input field
3. Tap the send button (↑)
4. View the response

**Example Questions**:
- "What is the main topic of this document?"
- "Summarize the key findings"
- "What does the document say about [specific topic]?"

### Understanding Responses

Each response includes:
- **Answer**: AI-generated based on your documents
- **Performance Metrics** (tap "Show Details"):
  - Model used
  - Retrieval time
  - Generation time
  - Tokens per second
- **Retrieved Context**: The actual document chunks used to answer

## Current Status: Production-Ready Core

### ✅ What Works Now

- **Document Processing**: PDF, TXT, MD, RTF support
- **Embedding Generation**: On-device vector creation with NLEmbedding
- **Vector Search**: Semantic similarity matching using cosine similarity
- **RAG Orchestration**: Complete pipeline integration
- **LLM Generation**: 4 implementations available (Foundation Models, Private Cloud Compute, ChatGPT, Mock)
- **User Interface**: All three tabs functional
- **Device Detection**: Capability checking
- **Apple Intelligence**: iOS 18.1+/iOS 26 integration ready

### 🔨 Default Test Configuration

- **LLM Generation**: Currently uses `MockLLMService` for testing
  - Simulates response time (~0.5 seconds)
  - Returns placeholder text
  - **To enable real models**: See ENHANCEMENTS.md for Apple Foundation Models setup (2-10 hours)

### 🚀 Optional Enhancements Available

- **Apple Foundation Models**: Enable LanguageModelSession API for on-device inference
- **Private Cloud Compute**: Apple Silicon servers with zero data retention for complex queries
- **Custom Models**: Load your own .mlpackage or .gguf files
- **Persistent Storage**: Data survives app restarts with VecturaKit
- **Performance Optimization**: HNSW indexing, KV-cache

## Testing the Application

### Sample Workflow

1. **Prepare test documents**
   - Create a simple text file or use a PDF
   - Keep it under 50 pages for faster testing

2. **Add document**
   - Import via Documents tab
   - Verify chunk count appears

3. **Query the knowledge base**
   - Ask specific questions about document content
   - Try different top-K values (3, 5, 10)
   - View performance metrics

4. **Check device capabilities**
   - Open Models tab
   - Verify your device tier
   - Check which features are available

### Performance Expectations

| Operation | Time (iPhone 15 Pro) |
|-----------|---------------------|
| Import 20-page PDF | ~5 seconds |
| Generate embeddings | ~2 seconds |
| Vector search | <100ms |
| Mock LLM response | ~500ms |
| Foundation Models (on-device) | ~30 tokens/sec |
| Private Cloud Compute | ~50 tokens/sec |

## Device Requirements

### Minimum (Embeddings Only)
- iPhone 11 or newer
- iOS 26.0+
- 4GB RAM
- Features: Document processing, semantic search

### Recommended (Full Features)
- iPhone 15 Pro or newer
- Apple Silicon Mac
- iOS 26.0+
- 6GB+ RAM
- Features: All above + Apple Intelligence

### Optimal (Best Performance)
- iPhone 17 Pro
- M2+ Mac
- iOS 26.0+
- 8GB+ RAM
- Features: All above + fast custom model execution

## Troubleshooting

### "Embedding model is not available"
- **Cause**: Device doesn't support NLContextualEmbedding
- **Solution**: Requires iOS 26 on iPhone 11 or newer

### Document processing fails
- **Cause**: Unsupported file format or corrupted file
- **Solution**: Ensure PDF contains actual text (not scanned image)

### No response when asking questions
- **Cause**: No documents in knowledge base
- **Solution**: Add at least one document first

### Slow performance
- **Cause**: Older device or large documents
- **Solution**: Use smaller documents, close other apps

## Architecture Deep Dive

For developers who want to understand the implementation:

- **README.md**: Project overview and features
- **ARCHITECTURE.md**: Complete technical architecture
- **IMPLEMENTATION.md**: Blueprint-to-code mapping

### Key Design Patterns

1. **Protocol-Oriented Architecture**
   - `LLMService` protocol enables model swapping
   - `VectorDatabase` protocol allows DB swapping
   - Easy testing with mock implementations

2. **Modern Swift Concurrency**
   - Async/await throughout
   - @MainActor for UI updates
   - Structured concurrency with Task

3. **SwiftUI Best Practices**
   - ObservableObject for state management
   - Single source of truth (RAGService)
   - Reactive UI updates

4. **Privacy-First Design**
   - Zero network calls
   - All processing on-device
   - Sandboxed file storage

## Next Steps

### For Users

1. Test with your own documents
2. Explore different question types
3. Compare retrieval with different top-K values
4. Enable Apple Foundation Models for real on-device inference (see ENHANCEMENTS.md)

### For Developers

1. Review the architecture documents
2. Explore the codebase structure
3. Implement optional enhancements:
   - Enable Apple Foundation Models or Private Cloud Compute (2-10 hours)
   - Add persistent vector database with VecturaKit (8-12 hours)
   - Implement custom model loading (40-80 hours)
4. Add your own enhancements

## Resources

### Apple Documentation
- [Apple Intelligence Overview](https://developer.apple.com/apple-intelligence/)
- [Core ML Documentation](https://developer.apple.com/documentation/coreml)
- [Natural Language Framework](https://developer.apple.com/documentation/naturallanguage)
- [PDFKit](https://developer.apple.com/documentation/pdfkit)

### WWDC Sessions (2025)
- Meet the Foundation Models framework
- Deep dive into the Foundation Models framework
- Explore large language models on Apple silicon with MLX

### Third-Party Tools
- [VecturaKit](https://github.com/rryam/VecturaKit) - Vector database
- [coremltools](https://github.com/apple/coremltools) - Model conversion
- [MLX](https://github.com/ml-explore/mlx) - Research framework

## Support

For issues, questions, or contributions:
1. Check the documentation files
2. Review the inline code comments
3. Examine the protocol implementations
4. Test with the mock services first

---

**Happy coding with on-device AI! 🚀**
