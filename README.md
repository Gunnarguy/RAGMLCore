# RAGMLCore

**Privacy-first RAG for iOS 26**. Import documents, ask questions, get grounded answers that stay on your device whenever possible.

- Native SwiftUI app that orchestrates document ingestion → semantic search → LLM generation.
- Single orchestrator (`RAGService`) keeps state predictable and debuggable.
- Designed to run privately by default with graceful fallbacks when cloud access is required.

---

## Quick Start

1. Clone the repo and open `RAGMLCore.xcodeproj` with Xcode 16 or newer.
2. Select the `RAGMLCore` target and run the app (⌘R).
3. Head to **Settings → AI Model** and choose your primary pathway:
     - Apple Intelligence (auto on-device with Private Cloud Compute fallback)
     - OpenAI Direct (bring your own API key)
     - On-Device Analysis (extractive QA, always available)
4. Import PDFs or text files in the **Documents** tab.
5. Ask grounded questions from the **Chat** tab; telemetry and retrieval details stream live.

> Need sample content? Try the curated documents in `TestDocuments/`.

---

## App Tour

- **Chat** – Streaming assistant responses with retrieved context, metrics (TTFT, tokens/sec), and chunk viewer.
- **Documents** – File picker, ingestion status overlay, per-document stats, and swipe-to-delete.
- **Settings** – Model picker, fallback chain, Private Cloud Compute toggle, OpenAI config, retrieval tuning, diagnostics.
- **Telemetry Dashboard** – Real-time event feed, performance charts, and quick validation tools.

Each surface is tuned for large knowledge bases: pagination keeps the chat performant, ingestion streams progress, and settings expose every lever without overwhelming new users.

---

## Pipeline Overview

```text
User Document → DocumentProcessor → SemanticChunker
                         → EmbeddingService (NLEmbedding, 512 dim)
                         → VectorDatabase (cosine search, cached norms)
                         → RAGService orchestrates query
Query → EmbeddingService → VectorDatabase → Context Builder → LLMService
Result → Streaming response + metrics + retrieved citations
```

### Model Flow & Fallbacks

**Privacy-first RAG for iOS 26** · Import documents · Ask natural-language questions · Get answers grounded in your own content.

---

## What You Experience

- **Document Library** – Drop in PDFs, Markdown, or Office docs and watch a live progress overlay while they are parsed, chunked, and embedded on-device.
- **Chat Workspace** – Ask follow-up questions, inspect retrieved context snippets, and view real-time telemetry (TTFT, tokens/sec, retrieval cost).
- **Settings Hub** – Toggle between Apple Intelligence, OpenAI, and local extractive QA, configure fallbacks, API keys, and Private Cloud Compute permissions.
- **Telemetry Dashboard** – Inspect the pipeline timeline, throughput, and latency when validating larger corpora or tuning the system.

Everything is private by default; nothing leaves the device unless you explicitly connect an external LLM.

## Feature Highlights

- Universal document ingestion with PDFKit + Vision OCR, plain-text, Markdown, code, CSV, and Office formats.
- Semantic chunking (400 words · 50 word overlap) backed by `NLEmbedding` for 512‑dim vectors generated on-device.
- Vector search with cached cosine similarity and pre-computed norms for fast retrieval.
- Multiple LLM pathways with automatic fallbacks: Apple Foundation Models → OpenAI Direct → On-Device Analysis.
- SwiftUI interface optimised for performance (message pagination, streaming, telemetry overlays).

## Architecture Snapshot

```text
User
 │      ChatView · DocumentLibrary · Settings · Telemetry
 ▼
@MainActor RAGService (state + orchestration)
 ├─ DocumentProcessor      → PDFKit / Vision / TextKit
 ├─ EmbeddingService       → NLEmbedding (512-dim)
 ├─ VectorDatabase         → In-memory cosine search + cache
 └─ LLMService (protocol)  → Apple FM · OpenAI · On-Device QA
```

- **RAGService** manages ingestion, querying, live status, and telemetry.
- **Protocol-based services** let you swap vector stores or LLMs without touching UI code.
- **Async/await throughout** keeps the UI responsive; all @Published state is updated on the main actor.

### Concurrency and Performance

- The project opts into Swift 6 concurrency with `-default-isolation=MainActor`. Pure CPU work is offloaded to a dedicated background actor `RAGEngine` to avoid main-thread stalls.
- MMR diversification and context assembly now execute on `RAGEngine`, reducing time spent on the main actor during Step 4.5 and Step 5 of the pipeline.
- Embedding generation and LLM generation are invoked off-main via `Task.detached` when safe (no main-actor–isolated calls).
- The background actor includes cooperative cancellation checks to keep long loops preemptible for future UI-driven cancel.

## Service Layer (TL;DR)

| Module | Responsibility | Key Notes |
| --- | --- | --- |
| `DocumentProcessor` | Parse + chunk documents | PDFKit, Vision OCR fallback, semantic paragraphs |
| `EmbeddingService` | Generate embeddings + cosine similarity | Validates NaNs, caches norms |
| `VectorDatabase` | Store/search chunk vectors | Thread-safe, LRU cache, ready for swap-in persistence |
| `LLMService` | Abstract generation | Apple Intelligence, OpenAI, On-Device Analysis, future CoreML |
| `RAGService` | Orchestrator + state | Manages ingestion, query flow, errors, telemetry |

## UI Layer Map

```text
Views/
├─ Chat/                # ChatView + supporting components
├─ Documents/           # DocumentLibraryView
├─ Settings/
│  ├─ SettingsView
│  ├─ DeveloperSettingsView
│  └─ Components/      # ModelInfoCard, InfoRow, etc.
├─ ModelManagement/     # ModelManagerView
├─ Telemetry/           # TelemetryDashboardView, LiveTelemetryStatsView
└─ Diagnostics/         # CoreValidationView
```

Shared models (e.g. `LLMModelType`, `RAGQuery`) live under `Models/`. Services remain inside `Services/` for easy discoverability.

## End-to-End Pipeline

1. **Import** – User selects a document. Security-scoped resource access is established.
2. **Parse & Chunk** – `DocumentProcessor` extracts text, builds semantic chunks (overlap keeps answers grounded).
3. **Embed** – `EmbeddingService` calls `NLEmbedding.wordEmbedding`, averages token vectors, and caches norms.
4. **Index** – `VectorDatabase` stores chunk metadata + embeddings.
5. **Ask** – User query is embedded, nearest neighbours fetched, and context is trimmed to fit the selected LLM.
6. **Generate** – `LLMService` routes to the preferred model (Apple FM / OpenAI / On-device QA) and streams tokens back.
7. **Present** – Chat UI renders streaming output with retrieved snippets and telemetry metrics.

## Build & Run

1. Open `RAGMLCore.xcodeproj` in Xcode 16 or later.
2. Select an iOS 26 simulator or device (A17 Pro or M-series recommended).
3. `⌘ + R` to run. The app launches into the chat workspace.

### Optional Configuration

- **OpenAI**: Enter your API key under Settings → OpenAI Configuration. Pick models such as `gpt-4o-mini`, `o1`, or `gpt-5`.
- **Private Cloud Compute**: Toggle permission and execution context (automatic / on-device / prefer cloud / cloud only).
- **Fallbacks**: Choose up to two LLM fallbacks; the pipeline automatically uses on-device analysis if all else fails.

## Privacy Checklist

- Document parsing, embeddings, and vector search are strictly on-device.
- Apple Intelligence uses Private Cloud Compute only for complex prompts; PCC enforces zero retention cryptographically.
- OpenAI integration is opt-in and only sends the user prompt plus retrieved context.
- No analytics or telemetry leave the device.

## Reference Material

Historical design docs, performance logs, and roadmap notes now live in `docs/reference/`. Key files include:

- `ARCHITECTURE.md` – Extended diagrams and rationale.
- `IMPLEMENTATION_STATUS.md` – Feature-by-feature progress.
- `PERFORMANCE_OPTIMIZATIONS.md` – Benchmark data and tuning notes.
- `ROADMAP.md` – Backlog ideas and future enhancements.

## Contributing

1. Branch from `main`.
2. Implement your change using async/await, avoid blocking the main actor, and follow the protocol-first patterns.
3. Run `xcodebuild -scheme RAGMLCore -project RAGMLCore.xcodeproj -destination 'platform=iOS,name=iPhone 17 Pro Max' build` (or from Xcode) to ensure a clean build.
4. Update documentation if you touch architecture, privacy, or user-facing flows.
5. Open a PR with screenshots or logs for any UI/UX changes.

## License

MIT License – see `LICENSE` for details.

---

**Status** · Core RAG pipeline production ready · Apple Foundation Models awaiting physical device validation.  
**Version** · v0.1.0  
**Last Updated** · October 2025
