# RAGMLCore - On-Device RAG Application for iOS 26

An advanced, privacy-first Retrieval-Augmented Generation (RAG) application for **iOS 26 (RELEASED October 2025)**, leveraging Apple Intelligence with Foundation Models, Private Cloud Compute, and optional ChatGPT integration.

## 🎯 Overview

RAGMLCore is a native iOS application that implements a complete RAG pipeline with Apple Intelligence, allowing users to:

- **Build Private Knowledge Bases**: Import PDF, text, and markdown documents
- **Semantic Search**: Find relevant information using vector embeddings
- **AI-Powered Answers**: Generate responses using Apple's Foundation Models with retrieved context
- **Hybrid Inference**: Automatic on-device + Private Cloud Compute fallback for complex queries
- **Optional ChatGPT**: Integrate OpenAI models with user consent
- **Model Flexibility**: Choose between Foundation Models, Private Cloud Compute, or custom LLMs

## 🚀 Apple Intelligence Features

**iOS 26 IS RELEASED** - All features available NOW:

- ✅ **Foundation Models** - On-device ~3B param model (LanguageModelSession API)
- ✅ **Private Cloud Compute (PCC)** - Apple Silicon servers, zero data retention, automatic fallback
- ✅ **ChatGPT Integration** - Optional third-party model (iOS 18.1+)
- ✅ **Writing Tools API** - System-wide proofreading, rewriting, summarization
- ✅ **App Intents** - Siri integration ("Hey Siri, query my documents about...")
- ✅ **Privacy-First** - On-device processing by default, cryptographic PCC guarantees

## 🏗️ Architecture

The application follows a modular, protocol-oriented architecture with clear separation of concerns:

### Core Components

```
RAGMLCore/
├── Models/
│   ├── DocumentChunk.swift      # Data structures for document chunks
│   ├── LLMModel.swift            # LLM model definitions
│   └── RAGQuery.swift            # Query and response types
├── Services/
│   ├── DocumentProcessor.swift   # Document parsing and chunking
│   ├── EmbeddingService.swift    # Vector embedding generation
│   ├── VectorDatabase.swift      # Vector storage and retrieval
│   ├── LLMService.swift          # LLM inference abstraction
│   └── RAGService.swift          # Main orchestrator
└── Views/
    ├── ChatView.swift            # Conversational interface
    ├── DocumentLibraryView.swift # Knowledge base management
    └── ModelManagerView.swift    # Model selection and info
```

### Implementation Pathways

The architecture supports multiple LLM execution pathways:

#### Pathway A: Apple Foundation Models (iOS 26 - AVAILABLE NOW)

- **Framework**: FoundationModels (iOS 26+)
- **Model**: Apple's proprietary ~3B parameter on-device model
- **Advantages**: Zero-setup, optimized performance, automatic privacy
- **Limitations**: No model customization
- **Device Requirements**: A17 Pro+ or M-series chips
- **Status**: ✅ Ready for production deployment

#### Pathway A+: Private Cloud Compute (iOS 26 - AVAILABLE NOW)

- **Framework**: FoundationModels with .cloud execution context
- **Infrastructure**: Apple Silicon servers with zero data retention
- **Advantages**: Higher token limits, better performance for complex queries, same privacy guarantees
- **Automatic**: Seamlessly falls back from on-device when needed
- **Status**: ✅ Ready for production deployment

#### Pathway A++: ChatGPT Integration (iOS 18.1+ - AVAILABLE NOW)

- **Framework**: Apple's ChatGPT integration framework
- **Model**: GPT-4 (no OpenAI account required)
- **Advantages**: Web-connected queries, higher capability
- **Privacy**: User consent required per query, data sent to OpenAI
- **Status**: ✅ Available for implementation

#### Pathway B1: Core ML Custom Models (Optional Enhancement)

- **Framework**: Core ML
- **Model**: User-provided .mlpackage files
- **Workflow**: PyTorch/TensorFlow → coremltools conversion → optimization → deployment
- **Advantages**: Deep hardware optimization (Neural Engine support)
- **Complexity**: High (requires Python toolchain)

#### Pathway B2: Direct GGUF Execution (Optional Enhancement)

- **Framework**: llama.cpp integration
- **Model**: User-provided .gguf files
- **Advantages**: Direct compatibility with community models
- **Complexity**: Medium (native library integration)

## 🔄 RAG Pipeline Flow

```
1. Document Ingestion
   ├─ Parse document (PDF, TXT, MD, RTF)
   ├─ Intelligent chunking (paragraphs with overlap)
   └─ Extract metadata

2. Embedding Generation
   ├─ Use NLContextualEmbedding (Apple's BERT model)
   ├─ Generate 512-dimensional vectors
   └─ Average token embeddings for chunk representation

3. Vector Storage
   ├─ Store chunks with embeddings
   └─ Enable similarity search

4. Query Processing
   ├─ Embed user query
   ├─ Retrieve top-k similar chunks (cosine similarity)
   └─ Construct augmented prompt

5. Response Generation
   ├─ Feed context + query to LLM
   ├─ Generate response
   └─ Return with performance metrics
```

## 🚀 Current Status

### ✅ Production-Ready Core Features

- [x] Document processing with PDFKit support
- [x] On-device embedding generation (NLEmbedding)
- [x] In-memory vector database with cosine similarity search
- [x] RAG orchestration layer
- [x] LLM service abstraction with 4 implementations (Foundation Models, PCC, ChatGPT, Mock)
- [x] SwiftUI interface (Chat, Documents, Models)
- [x] Device capability detection
- [x] Apple Intelligence integration (iOS 18.1+/iOS 26)

### 🔨 Optional Enhancements (See ENHANCEMENTS.md)

- [ ] Core ML custom model loading infrastructure
- [ ] Model conversion utilities documentation
- [ ] GGUF direct execution (llama.cpp integration)
- [ ] Persistent vector database (VecturaKit/ObjectBox integration)
- [ ] Model performance benchmarking
- [ ] Advanced chunking strategies
- [ ] Multi-document query support

## 📱 Device Requirements

### Minimum Requirements (Embeddings Only)
- **iOS**: 26.0+
- **Chip**: A13 Bionic or newer (iPhone 11+)
- **Features**: Document ingestion, embedding generation, vector search

### Recommended (Full Apple Intelligence)
- **iOS**: 26.0+
- **Chip**: A17 Pro or M-series
- **Features**: Full RAG pipeline with Apple Foundation Model

### Optimal (Custom Models)
- **iOS**: 26.0+
- **Chip**: A19 Pro or M2+
- **Features**: High-performance custom LLM execution

## 🔧 Key Technologies

### Apple Frameworks
- **FoundationModels**: High-level LLM API (iOS 26)
- **Core ML**: Low-level model execution
- **NaturalLanguage**: Contextual embeddings
- **PDFKit**: Document parsing
- **SwiftUI**: Modern declarative UI

### Third-Party Integration Points
- **VecturaKit**: Production vector database (planned)
- **ObjectBox**: Alternative HNSW-based vector DB (planned)
- **coremltools**: Python library for model conversion
- **llama.cpp**: Direct GGUF execution engine (future)

## 📊 Performance Characteristics

### Apple Foundation Model
- **Speed**: ~30 tokens/second (iPhone 15 Pro)
- **Latency**: Low time-to-first-token
- **Memory**: Optimized with 2-bit quantization

### Custom Models (Optimized)
- **8B Model**: ~33 tokens/second (M1 Max)
- **Optimizations Required**: Int4 quantization + KV-caching + SDPA fusion
- **Memory**: ~2-4GB depending on quantization

## 🏃 Getting Started

### Prerequisites
1. Xcode 16.0+
2. iOS 26 SDK
3. Physical device with A13+ (simulator has limited AI features)

### Build Instructions
1. Open `RAGMLCore.xcodeproj` in Xcode
2. Select your development team
3. Build and run on device

### Testing the Pipeline
1. **Add Documents**: Use the Documents tab to import PDF or text files
2. **Wait for Processing**: The app will chunk, embed, and store the content
3. **Ask Questions**: Switch to Chat tab and query your documents
4. **View Metrics**: Expand response details to see performance stats

## 🔐 Privacy & Security

- **On-Device First**: All processing occurs locally by default with Foundation Models
- **Private Cloud Compute**: When needed, Apple Silicon servers with cryptographic zero-retention guarantee
- **ChatGPT Consent**: Explicit user approval required for every OpenAI query (optional pathway)
- **No Analytics**: Zero data collection or telemetry
- **Sandboxed Storage**: Documents stored in app's private container
- **Secure File Access**: Proper security-scoped resource handling
- **Verifiable Privacy**: PCC architecture allows independent security research

## 📚 References

### WWDC 2025 Sessions
- Meet the Foundation Models framework
- Deep dive into the Foundation Models framework
- Explore large language models on Apple silicon with MLX
- Code-along: Bring on-device AI to your app

### Documentation
- [Apple Intelligence Overview](https://developer.apple.com/apple-intelligence/)
- [Core ML Documentation](https://developer.apple.com/documentation/coreml)
- [Natural Language Framework](https://developer.apple.com/documentation/naturallanguage)

### Research Papers
- Apple: Deploying Llama 3.1 with Core ML (2024)
- KV-Cache Optimization Techniques
- Quantization-Aware Training at Scale

## 🤝 Contributing

This is a reference implementation based on the architectural blueprint. Contributions for:
- Custom model integration examples
- Performance optimization techniques
- Alternative vector database implementations
- Advanced RAG patterns (multi-hop, fusion, etc.)

## 📄 License

MIT License - See LICENSE file for details

## ⚠️ Important Notes

1. **iOS 26 Released**: iOS 26 available now (October 2025) with full Apple Intelligence support
2. **Hardware Dependencies**: Full features require A17 Pro+ or M-series
3. **Production-Ready Core**: App ready to deploy with Foundation Models, PCC, and ChatGPT support
4. **Vector Database**: In-memory implementation for prototyping - replace with persistent solution for production scale

## 🎓 Learning Resources

This project demonstrates:
- Modern Swift concurrency (async/await)
- Protocol-oriented architecture
- SwiftUI best practices
- Core ML integration patterns
- Privacy-preserving AI design
- RAG system architecture

Perfect for developers learning to build sophisticated on-device AI applications!

---

**Built with ❤️ for the Apple Intelligence era**
