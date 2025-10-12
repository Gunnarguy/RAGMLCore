# RAGMLCore

**Privacy-first on-device RAG for iOS 26** - Import documents, ask questions, get AI-powered answers using your own knowledge base.

## Features

- **Universal document support**: PDF (with OCR), text, Markdown, RTF, code files, CSV, Office docs
- **On-device embeddings**: NLEmbedding generates 512-dimensional vectors locally
- **Multiple LLM pathways**: Apple Intelligence, OpenAI Direct, on-device extractive QA
- **SwiftUI interface**: Chat, document library, settings, model management
- **Protocol-based architecture**: Easy to extend with custom models

## LLM Services

| Service | Platform | Privacy | Status |
|---------|----------|---------|--------|
| **Apple Foundation Models** | iOS 26+, A17 Pro / M-series | On-device + PCC | Ready (needs device validation) |
| **OpenAI Direct API** | Network + API key | Cloud API | ✅ Production-ready |
| **On-Device Analysis** | All devices | Fully local | ✅ Always available fallback |
| **ChatGPT Extension** | iOS 18.1+ | Cloud API | Stub only |
| **Core ML Custom** | .mlpackage models | Fully local | Skeleton (needs tokenizer) |

**Auto-selection priority**: Apple Foundation Models → OpenAI → On-Device Extractive QA

## Requirements

- **iOS 26.0+** / Xcode 16+
- **Recommended**: A17 Pro or M-series chip for on-device inference
- **Optional**: OpenAI API key (for OpenAI pathway)

## Quick Start

1. Open `RAGMLCore.xcodeproj` in Xcode
2. Build and run (⌘R)
3. **Settings tab**: Add OpenAI API key (optional) or select "On-Device Analysis"
4. **Documents tab**: Import PDFs or text files
5. **Chat tab**: Ask questions about your documents

## Architecture

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for:
- Component diagrams and data flow
- Service responsibilities and implementations
- Privacy architecture
- Performance targets

## Implementation Status

See [`IMPLEMENTATION_STATUS.md`](IMPLEMENTATION_STATUS.md) for:
- Feature completion matrix (100% core features)
- Testing status
- Optional enhancements
- Known limitations

## Roadmap

See [`ROADMAP.md`](ROADMAP.md) for:
- Next priority tasks (6 items, 2-4 hours each)
- Future enhancements (custom models, GGUF, advanced features)
- Timeline and effort estimates

## Privacy & Security

- **Documents processed locally**: PDFKit, Vision, and NLEmbedding run on-device
- **Apple Intelligence**: Stays on-device by default; Private Cloud Compute only for complex queries (cryptographically enforced zero retention)
- **OpenAI pathway**: Explicit user consent; sends query + retrieved context only
- **No telemetry**: Zero data collection or analytics

## Project Structure

```
RAGMLCore/
├── Services/          # Core RAG pipeline (2,830 lines)
│   ├── DocumentProcessor.swift    # Universal parsing + chunking
│   ├── EmbeddingService.swift     # NLEmbedding 512-dim vectors
│   ├── VectorDatabase.swift       # Protocol + in-memory impl
│   ├── LLMService.swift           # 5 LLM implementations (933 lines)
│   └── RAGService.swift           # Pipeline orchestrator
├── Models/            # Data structures
│   ├── DocumentChunk.swift
│   ├── LLMModel.swift
│   └── RAGQuery.swift
└── Views/             # SwiftUI interface
    ├── ChatView.swift
    ├── DocumentLibraryView.swift
    ├── SettingsView.swift
    ├── ModelManagerView.swift
    └── CoreValidationView.swift
```

## Contributing

1. Create feature branch from `main`
2. Test thoroughly (add test documents to `TestDocuments/` if needed)
3. Update documentation if changing architecture or adding features
4. Submit PR with clear description

## License

MIT License - see LICENSE file for details

---

**Current Status**: Core RAG pipeline complete (100%). OpenAI integration production-ready. Apple Foundation Models ready for device validation.

**Build Status**: ✅ Zero errors, zero warnings  
**Version**: v0.1.0  
**Last Updated**: October 2025
