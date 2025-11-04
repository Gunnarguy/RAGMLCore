# RAGMLCore AI Instructions

**Privacy-first iOS 26 RAG app** - Document ingestion → Semantic search → LLM generation  
**Status**: Production-ready (v0.1.0) | **Build**: ✅ Zero errors

## Architecture Essentials

- **Single orchestrator**: `RAGService` (@MainActor, ObservableObject) - all state flows through here
- **Protocol-based**: Every service (LLM, VectorDB, Embedding) uses protocols - swap implementations freely
- **5 LLM options**: AppleFoundationLLM (iOS 26+ with function calling), OpenAI (production), OnDeviceAnalysis (fallback), CoreML (custom), ChatGPT (stub)
- **Pipeline**: PDF/Text → PDFKit → SemanticChunker (400w chunks, 50w overlap) → NLEmbedding (512-dim) → VectorDB → Cosine search → LLM

```
RAGMLCore/
├── Services/         # All logic (RAGService, LLMService, DocumentProcessor, EmbeddingService, VectorDatabase)
├── Models/           # Pure data (DocumentChunk, LLMModel, RAGQuery)
└── Views/            # SwiftUI (ChatView, DocumentLibraryView, SettingsView, ModelManagerView)
```

## Code Patterns You Must Follow

**1. Async/await everywhere** - No completion handlers, no blocking

```swift
func processDocument(_ url: URL) async throws -> [DocumentChunk]  // ✅
func processDocument(_ url: URL) throws -> [DocumentChunk]         // ❌ Blocks UI
```

**2. @MainActor for UI state** - RAGService is @MainActor, all @Published updates must be on main

```swift
@MainActor class RAGService: ObservableObject {
    @Published var documents: [Document] = []  // Auto-triggers SwiftUI updates
}
```

**3. Protocol conformance** - Extend protocols, not implementations

```swift
protocol LLMService { func generate(...) async throws -> LLMResponse }
// Add new LLM? Implement protocol. RAGService doesn't change.
```

**4. iOS 17+ SwiftUI** - Zero-param closures for onChange

```swift
.onChange(of: messages) { scrollToBottom() }          // ✅
.onChange(of: messages) { newValue in ... }           // ❌ Old API
```

**5. Settings via @AppStorage** - Shared between views, synchronized automatically

```swift
@AppStorage("llmTemperature") private var temperature: Double = 0.7
@AppStorage("selectedLLMModel") private var selectedModel: String = "apple_intelligence"
```

**6. Telemetry over print()** - Use structured logging with categories

```swift
TelemetryCenter.emit(.embedding, severity: .info, title: "Generated embedding",
                     metadata: ["dimension": "512"], duration: 0.045)
Log.section("Step 1: Query Embedding", level: .info, category: .pipeline)  // Boxed logs
```

**7. Performance-first views** - Pagination, lazy loading, cached computed properties

```swift
// Only render visible messages (ChatView pattern)
@State private var visibleMessageCount: Int = 50
private var visibleMessages: ArraySlice<ChatMessage> {
    let startIndex = max(0, messages.count - visibleMessageCount)
    return messages[startIndex...]
}
```

## iOS 26 Function Calling (Agentic RAG)

AppleFoundationLLMService uses native `@Tool` for function calling - LLM decides when to search:

```swift
@available(iOS 26.0, *)
struct SearchDocumentsTool: Tool {
    @Generable struct Arguments { var query: String }
    func call(arguments: Arguments) async throws -> String { ... }
}

let session = LanguageModelSession(
    model: model,
    tools: [SearchDocumentsTool(), ListDocumentsTool(), GetDocumentSummaryTool()],
    instructions: Instructions("...")
)
```

**Pattern**: RAGService implements `RAGToolHandler` protocol, tools hold weak reference to RAGService.  
**Flow**: User query → Model decides → If needed: call tool → RAGService executes → Model synthesizes response.

## Performance Patterns

**Vector DB optimizations** (VectorDatabase.swift):

- Pre-computed embedding norms (50% faster cosine similarity)
- LRU cache for recent searches (20 entries, 5min expiration)
- Array pre-allocation: `reserveCapacity()` before loops

**ChatView optimizations**:

- Message pagination: Only render last 50 messages
- Auto-cleanup: Keep max 200 messages, prune older
- Throttled scrolling: Update every 10 chars during streaming
- Chunked streaming: 10-char chunks instead of char-by-char

**Pattern**: All optimizations documented in `PERFORMANCE_OPTIMIZATIONS.md`

## Critical "Don'ts"

- ❌ Don't use `NLContextualEmbedding` (deprecated) → Use `NLEmbedding.wordEmbedding`
- ❌ Don't add explicit init to `InferenceConfig` (causes MainActor isolation issues)
- ❌ Don't forget `import Combine` in RAGService (needed for @Published)
- ❌ Don't block main thread - all heavy work is `async`
- ❌ Functions over 50 lines need refactoring
- ❌ Don't use print() in Services/ - use `TelemetryCenter.emit()` or `Log.*`
- ❌ Don't skip array pre-allocation in hot loops - use `reserveCapacity()`

## Key Files

- **RAGService.swift** (1813 lines) - Orchestrates everything, query() and addDocument() are your entry points
- **LLMService.swift** (1580 lines) - 5 implementations, AppleFoundationLLMService is the production target
- **DocumentProcessor.swift** (839 lines) - Multi-format parsing (PDF, text, Office), SemanticChunker integration
- **VectorDatabase.swift** - Protocol + PersistentVectorDatabase with LRU cache and pre-computed norms
- **TelemetryCenter.swift** - Structured logging with @MainActor singleton, emits to UI dashboard
- **IMPLEMENTATION_STATUS.md** - What's done, what's next, performance metrics
- **ARCHITECTURE.md** - Why we made these design decisions
- **PERFORMANCE_OPTIMIZATIONS.md** - All optimization patterns with before/after metrics

## Testing

```bash
open RAGMLCore.xcodeproj
# ⌘ + B to build | ⌘ + R to run
# DEFAULT SIMULATOR: iPhone 17 Pro Max (unless user specifies otherwise)
```

Manual checks:

- Documents tab (import) → Verify "Processing..." overlay with real-time status
- Chat tab (query) → Check live telemetry stats panel, streaming response
- Settings tab (LLM selection) → Switch between OpenAI/Apple/OnDevice
- Telemetry Dashboard → View event log, performance metrics, category filters

## Common Tasks

**Add new LLM**: Implement `LLMService` protocol → Update `RAGService.init()` selection logic  
**Change chunking**: Modify `SemanticChunker.ChunkingConfig` (default: 400w/50w overlap)  
**Swap vector DB**: Implement `VectorDatabase` protocol (current: PersistentVectorDatabase)  
**Add telemetry**: Use `TelemetryCenter.emit()` with category/severity/metadata  
**Add logging**: Use `Log.section()` for boxed logs, `Log.info/error/debug()` for inline  
**Optimize search**: Pre-compute norms, add to LRU cache, use SIMD for dot products

## Privacy First

- On-device by default (Foundation Models, NLEmbedding, PDFKit)
- Private Cloud Compute = Apple servers, zero retention (user can disable)
- OpenAI pathway = explicit user consent per query
- Zero analytics/telemetry

---

_Last Updated: October 2025_  
_iOS 26 Status: RELEASED with full Apple Intelligence support_  
_Project Version: v0.1.0 (Ready for Production Deployment)_
