# RAGMLCore Apple Intelligence Reference

A quick map from the frameworks used in the app to the local documentation we scraped. Use this as the first stop before diving into hundreds of JSON files.

| Module | What We Use It For | Key Entry Points in Repo | Local Docs Folder |
| ------ | ------------------ | ------------------------ | ----------------- |
| FoundationModels | Apple Intelligence LLM with PCC fallback, tool calling | `Services/LLMService.swift`, `Services/RAGService.swift` | `Docs/foundationmodels` |
| AppIntents | Siri / system intent routing, function-calling tool metadata | `Services/RAGAppIntents.swift`, intent helpers in `LLMService.swift` | `Docs/appintents` |
| NaturalLanguage | Embeddings (`NLEmbedding`), semantic chunking, query boosts | `Services/EmbeddingService.swift`, `Services/SemanticChunker.swift`, `Services/QueryEnhancementService.swift` | `Docs/naturallanguage` |
| CoreML | Core ML fallback / custom model execution | `Services/LLMService.swift` (CoreML section) | `Docs/coreml` |
| Vision | OCR for PDFs, layout analysis | `Services/DocumentProcessor.swift` | `Docs/vision` |
| PDFKit | Native PDF parsing, page text extraction | `Services/DocumentProcessor.swift` | `Docs/pdfkit` |
| UniformTypeIdentifiers | Document type detection, file import filters | `Services/DocumentProcessor.swift`, `Views/DocumentLibraryView.swift` | `Docs/uniformtypeidentifiers` |
| CoreImage | Image preprocessing for OCR pipelines | `Services/DocumentProcessor.swift` | `Docs/coreimage` |
| UIKit | Legacy text tools, image APIs used in document prep | `Services/DocumentProcessor.swift`, `Services/LLMService.swift` | `Docs/uikit` |
| SwiftUI | Entire UI layer, writing tools entry points | `Views/*.swift`, `RAGMLCoreApp.swift` | `Docs/swiftui` |
| Combine | ObservableObject pipelines, state propagation | `Services/RAGService.swift` | `Docs/combine` |
| WritingTools | System proofreading/rewriting/summarisation | `Services/WritingToolsService.swift`, `Views/ChatView.swift` | *(Apple endpoint currently 404s – no local dump)* |
| VecturaKit *(optional)* | Persistent vector DB swap-in (disabled) | `Services/VectorDatabase.swift` (commented) | *(not scraped)* |

## Finding Specific Symbols

Each folder mirrors Apple’s documentation path. For example:

- `Docs/foundationmodels/languagemodelsession.json` – API surface we use in `AppleFoundationLLMService`.
- `Docs/naturallanguage/nlembedding.json` – word embedding API used by `EmbeddingService`.
- `Docs/coreml/mlmodel.json` – references for the Core ML fallback.

Most JSON files include `title`, `abstract`, and `topics`. Open them directly or pipe through `jq` for a structured view, e.g.:

```sh
jq '.abstract' Docs/foundationmodels/languagemodelsession.json
```

## Regenerating / Extending the Doc Cache

Use `fetch_module_docs.py` inside `Docs/`:

```sh
cd Docs
python3 fetch_module_docs.py <module-name> [limit]
```

- Omit `limit` to fetch the entire tree. Add one (e.g. `200`) to cap downloads while exploring.
- Known gap: `writingtools` currently returns 404 from Apple. Re-run periodically in case the endpoint appears.

## Next Additions To Consider

1. `Speech` or `CoreSpeech` – for voice input or dictation support.
2. `SiriKit` – if we expand App Intents beyond the existing RAG intents.
3. `CreateML` – model authoring on-device if we ship fine-tuning tools.

Keep this cheat sheet updated when new frameworks land in the project so the doc cache stays in sync with the codebase.
