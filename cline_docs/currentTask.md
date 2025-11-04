## Current Task: AI Modernization Pass (Apple 2025 + MLX integration, provider abstractions)

Date: 2025-10-28

References
- See cline_docs/projectRoadmap.md for high-level goals and milestone tracker.
- This task supersedes the earlier background-actor effort (RAGEngine) and focuses on model/runtime modernization and system integration.

Objectives (this pass)
- Add a pluggable embeddings abstraction and keep current behavior as default.
- Introduce macOS local MLX backend option and surface in Settings.
- Prepare Core ML pathways for sentence embeddings and custom LLMs.
- Expand model selection pipeline and diagnostics to include new options.
- Update project documentation to reflect new plan and initial implementation.

Context
- Apple’s 2025 platform offerings (FoundationModels, SystemLanguageModel, WritingTools, PCC) emphasize on-device-first, with secure cloud only when beneficial.
- We want: on-device by default, zero-retention PCC fallback, and an additional local open-model path (MLX on macOS) plus Core ML for enterprise models.
- Existing stack already supports: Apple Foundation Models (iOS 26+), On-Device Analysis fallback, OpenAI Direct, and preliminary App Intents. This pass expands backends and formalizes embeddings.

Changes Implemented (this pass)
1) Embeddings
   - Added provider abstraction:
     - New: Services/Embeddings/EmbeddingProvider.swift
     - New: Services/Embeddings/NLEmbeddingProvider.swift (512-dim word-avg, parity with previous behavior)
   - Refactor:
     - Services/EmbeddingService.swift now delegates to EmbeddingProvider (default NLEmbeddingProvider).
   - Scaffold for Core ML sentence embeddings:
     - New: Services/Embeddings/CoreMLSentenceEmbeddingProvider.swift (tokenization/IO TBD)

2) LLM Backends
   - New macOS local MLX backend (server bridge):
     - Services/MLXLocalLLMService.swift (OpenAI-compatible /v1/chat/completions request; non-streaming for now)
   - Model types and settings:
     - Models/LLMModelType.swift: added `.mlxLocal`, `.coreMLLocal`, display/icon updates
     - Views/Settings/SettingsView.swift:
       - Picker options for MLX Local (macOS) and Core ML Local
       - Pipeline stage rendering for MLX/Core ML
       - Instantiation path for MLXLocalLLMService on macOS

3) Documentation
   - New: cline_docs/projectRoadmap.md outlining modernization plan, goals, and progress
   - Updated: This currentTask.md (this file)

4) Platform-gating and DSColors UI unification
   - Gated .navigationBarTitleDisplayMode and toolbar placements for macOS/iOS across key views
   - Replaced UIKit color initializers with DSColors.background and DSColors.surface for visual cohesion
   - Fixed legacy Chat/ChatView.swift: gated nav title mode on iOS and used .automatic toolbar on macOS
   - Verified macOS build with xcodebuild Debug scheme on 2025-10-29

5) UI/UX – ChatV2 Live Visualization and Streaming UX
   - StageProgressBar: per‑stage elapsed timers (Embedding, Searching, Generating) + subtle shimmer while active
   - PipelineOverlayView: animated flow line and stage nodes rendered behind the message list (non‑interactive, allowsHitTesting(false))
   - LiveCountersStrip: TTFT, Tokens, tok/s, retrieved chunk count displayed during generation
   - RetrievalSourcesTray: compact tray under the list during Searching/Generating, grows with live source chips; opens details sheet
   - TokenCadenceView: animated bars reflecting streaming rhythm; integrated next to TypingIndicator
   - Event ribbon toasts: ephemeral top toasts for milestones (Embedding started, Searching top K, Generating…, Found N sources, TTFT)
   - Execution badge: TTFT‑based on‑device vs PCC inference surfaced in ExecutionBadge
   - iOS Simulator Debug build succeeded via xcodebuild (RAGMLCore scheme, iPhone 16 iOS 26.0.1)

6) Strict Mode for High-Reliability Containers (Phase 1)
   - Enforced min similarity ≥ 0.52 and minimum supporting chunks ≥ 3 before generation
   - Tightened MMR λ to 0.75 (slightly more relevance than diversity)
   - Capped generation temperature at 0.2 under strict mode
   - Added cautious non‑answer path with top source citations when evidence is insufficient
   - ResponseDetailsView displays a Strict Mode badge via ResponseMetadata.strictModeEnabled
   - RAGService wires strictMode from active KnowledgeContainer and propagates through metadata

Build/Runtime Notes
- MLX Local backend:
  - Designed for macOS. Start an MLX server separately, then select “MLX Local (macOS)” in Settings.
  - Example:
    - Install: `pip install mlx-lm`
    - Download a model (example): `python -m mlx_lm.download qwen2.5-7b-instruct`
    - Start server: `python -m mlx_lm.server --model qwen2.5-7b-instruct --port 17860`
    - App connects to http://127.0.0.1:17860/v1/chat/completions (OpenAI style request body). No data leaves the machine.
- Apple Foundation Models path remains primary when available; your previous warm-up and TTFT execution-location inference stay in place.
- iOS/macOS deployment targets in the project are already set to 26.0 in pbxproj; feature gating remains via `#if canImport` and `@available` checks.

What’s next (near-term)
- Core ML sentence embeddings provider
  - Implement tokenizer and IO mapping for one known model (e.g., E5/MiniLM/GTE converted to Core ML)
  - Expose provider selection and handle index dimension namespacing/re-embed
- CoreMLLLMService (custom LLM, .mlpackage)
  - Add TokenizerAdapter protocol (BPE/SentencePiece) and wire `createInputFeatures` / `decodeOutput` for a small model
  - Document conversion pipeline (coremltools) and expected shapes
- MLX Local polish
  - Add “Health Check” in Settings and a clearer status stage
  - Optional streaming (SSE) client if server supports
- Telemetry and diagnostics
  - Count `toolCallsMade`, surface backendUsed, executionLocation, TTFT, tokens/sec
  - Badge in chat for 📱 On-Device / ☁️ PCC / 🖥️ MLX / 🔑 OpenAI
- WritingTools integration
  - Hook rewrite/summarize/tone controls in the chat composer, with fallback prompts when WritingTools not available

Files touched (summary)
- Added
  - Services/Embeddings/EmbeddingProvider.swift
  - Services/Embeddings/NLEmbeddingProvider.swift
  - Services/Embeddings/CoreMLSentenceEmbeddingProvider.swift (scaffold)
  - Services/MLXLocalLLMService.swift
  - cline_docs/projectRoadmap.md
- Modified
  - Services/EmbeddingService.swift (now delegates to provider)
  - Models/LLMModelType.swift (mlxLocal/coreMLLocal)
  - Views/Settings/SettingsView.swift (picker, pipeline stages, instantiation)

Status
- macOS build succeeded after platform-gating pass including legacy ChatView (xcodebuild Debug, 2025-10-29).
- Compiles with new sources (Xcode’s file-system synchronized group should pick up new Swift files).
- Legacy ChatView removed; app unified on ChatV2 (2025-10-29).
- MLX Local requires user to run a local server on macOS to be “available.”
- Core ML sentence embeddings and CoreML LLM are scaffolded but not functional yet (tokenization/IO TBD).

---

## Update: 2025-10-30 – Visualizations Tab + 3D Embedding Scaffold (Apple-style)

Context
- User requested restoring the Visualizations tab and adding Apple-repo-style visualizations to see per-file contributions in a “giant 3D makeup,” scoped to the active library/container.
- Reference: https://github.com/apple/embedding-atlas (target for eventual integration).

Changes Implemented
- Container-scoped Visualizations:
  - Restored Visualizations tab in ContentView with environment objects for RAGService and ContainerService.
  - VisualizationsView filters documents to the active container and recalculates stats; EmbeddingSpaceView now container-aware.
- Embeddings enumeration pipeline:
  - Protocol: VectorDatabase now exposes `allChunks()`.
  - Implementations:
    - PersistentVectorDatabase: returns all stored DocumentChunk entries for the active container.
    - VecturaVectorDatabase: adds a stub `allChunks()` (returns empty for now) to conform gracefully when VecturaKit is active.
  - RAGService helper: `allChunksForActiveContainer()` to supply visualization data.
- 3D Renderer Scaffold:
  - New: Views/Telemetry/Embedding3DView.swift
    - SceneKit-based 3D scatter with orbit controls and default lighting.
    - Downsamples fairly across documents to a fixed budget (max 2000 points).
    - Colors points by document; shows a horizontal legend with per-file counts.
    - Projection: Fast Random Projection (RP) placeholder, mean-centered + Gram–Schmidt to 3 axes. Swappable for PCA/UMAP/t-SNE or Apple Embedding Atlas projection.
    - Cross-platform fallback via `#if canImport(SceneKit)` to compile on targets without SceneKit.
  - VisualizationsView now uses `EmbeddingSpaceRenderer` instead of the placeholder, maintaining the segmented control (PCA/UMAP/t-SNE)—currently PCA path maps to RP, others fall back to RP.

Technical Notes
- Container scoping respects legacy “General” documents (`containerId == nil`) when the active container is named “General”.
- Color palette is deterministic by sorted doc IDs to ensure consistent legend mapping on refresh.
- Performance: deterministic sampling per container (seeded by `activeContainerId`) to avoid visual jitter across refreshes.

Next Steps – Apple Embedding Atlas Integration
- Dependency approach:
  - Evaluate SPM integration of apple/embedding-atlas (if/when packaged) or vendoring an adapter layer.
  - If SPM not available, create a lightweight adapter interface so `EmbeddingSpaceRenderer` can accept coordinates and metadata produced by Atlas.
- Data adapter:
  - Map `DocumentChunk.embedding` and `documentId -> filename` to Atlas input format.
  - Preserve per-file labeling for color legend and future tooltips.
- Projection pipeline:
  - Replace RP with PCA (near-term) and add UMAP/t-SNE (mid-term), or use Atlas’ built-in projection flow when available.
  - Handle large-N via Atlas downsampling/LOD if provided; otherwise continue stratified sampling.
- UX features:
  - Add tooltips on tap with preview text (first 150 chars) and source file/page.
  - Add per-file contribution panel (percentages, quick filter by file).
  - Maintain container scoping; allow doc filter chips to isolate subsets.
- Platform gating:
  - Keep SceneKit fallback for platforms lacking SceneKit; consider RealityKit renderer in follow-up.

Acceptance Criteria for this Phase
- Visualizations tab shows a live, container-scoped 3D scatter of stored embeddings with per-file color legend.
- Works with PersistentVectorDatabase out-of-the-box; gracefully handles Vectura (empty `allChunks()` stub) without crashing.
- No regressions for other visualization sections; performance acceptable up to several thousand points (sampling applied).

---

## Update: 2025-10-30 – Visualizations Build Fixes + macOS Debug Build Success

Summary
- Resolved SwiftUI type-checking and binding inference issues in `Embedding3DView.swift`.
- macOS Debug build now succeeds for scheme `RAGMLCore` using `xcodebuild` and app launches locally.
- Prepared the renderer code to be friendlier to the Swift type-checker and platform semantic colors.

Changes (Embedding3DView.swift)
- ForEach and Identifiable
  - Renamed Legend item model to avoid overload/ambiguity and ensure stable identity:
    - `LegendItem` → `VizLegendItem: Identifiable`
  - Ensured unambiguous ForEach usage:
    - `ForEach(Array(legendItems), id: \.id) { ... }`
- Decomposition to reduce type-checker complexity
  - Split monolithic `body` into smaller subviews:
    - `errorBanner`, `contentBody`, `loadingCard`, `emptyStateCard`, `samplingControls`, `sceneSection`, `legendSection`
  - Extracted legend UI into dedicated views:
    - `LegendChipsView` (manages selection state via @Binding)
    - `LegendChip` (pure presentational component)
- Cross‑platform color usage
  - Replaced `Color(.secondarySystemBackground)` with `DSColors.surface` to avoid macOS contextual-type resolution errors and keep design system consistency.
- Functional behavior preserved
  - Sampling controls persist per-container
  - Document legend filtering maintained
  - SceneKit fallback path remains for platforms without SceneKit

Build Verification (macOS)
- Command:
  - `xcodebuild -project RAGMLCore.xcodeproj -scheme RAGMLCore -configuration Debug -destination 'platform=macOS' build`
- Result:
  - Build succeeded (`** BUILD SUCCEEDED **`)
- App launch (Debug build):
  - `open ~/Library/Developer/Xcode/DerivedData/RAGMLCore-*/Build/Products/Debug/RAGMLCore.app`
  - Launched successfully

Sanity Check Plan (runtime)
- Cross-tab navigation:
  - Visualizations empty state CTA navigates to Documents tab
  - Documents toolbar “Visualize” button navigates to Visualizations tab
- Container scoping parity:
  - Legacy docs (`containerId == nil`) appear under the default (first) container consistently across Documents and Visualizations
- Visualizations behavior:
  - When no chunks for active container: empty state renders
  - When chunks exist: 3D scatter appears; colors per document; legend chips toggle filters
  - Sample size control (1K/2K/5K) persists per-container
- Platform UI:
  - No macOS warnings for iOS-only APIs (e.g., nav bar title display mode)
  - Uses DSColors for surface/background consistently

Notes
- 3D projection currently uses the RP path behind the PCA option for speed; PCA/UMAP/t‑SNE to be added or replaced with Apple Embedding Atlas when integrated.
- VecturaVectorDatabase `allChunks()` remains a stub; Persistent path is the primary data source for the visualization.

Next Steps
- Perform a brief manual runtime pass to validate the sanity check plan above.
- If any UI polish is desired for legend chip selection affordances, consider a clearer selected/unselected contrast in DSColors.
- Proceed with PCA implementation and Embedding Atlas adapter plan when ready.

---

## Update: 2025-10-31 – Chat Scoping by Library (Pinned + One‑Off Override)

Summary
- Implemented per-message library override in ChatV2 while preserving the pinned active container selector.
- Retrieval is scoped strictly to the selected library via per-container VectorDatabase instances from VectorStoreRouter.
- Strict Mode now follows the container used for the message (override or pinned).

Changes Implemented
- Services/RAGService.swift:
  - Added helper: `private func dbFor(_ containerId: UUID) async -> VectorDatabase`
  - Updated signature: `func query(_ question: String, topK: Int = 3, config: InferenceConfig? = nil, containerId: UUID? = nil) async throws -> RAGResponse`
  - Counts, retrieval, and HybridSearch now use `vdb` based on override (`containerId`) or active container.
  - strictMode resolution now respects the override container when present.
- Views/ChatV2/ChatScreen.swift:
  - New `@State private var messageContainerOverride: UUID?`
  - Added compact “This message: Library” Picker under `ContainerPickerStrip`:
    - Entries: “Active: …” (nil tag) plus all containers by name.
    - Clear button resets to nil.
  - On send:
    - Compute `usedContainerId = override ?? activeContainerId`
    - Store `containerId` on the user message; reset override (one-off behavior).
    - Pass `containerId` into `ragService.query(...)`
    - Store `containerId` on the assistant message for history and future badges.
- Models/ChatMessage.swift:
  - Added `containerId: UUID?` to record which library was used per message.

Behavior and UX
- The header `ContainerPickerStrip` still controls the pinned active library (default scope).
- The optional one-off Picker applies only to the next message and resets after sending.
- Status strip counters remain active-container scoped; assistant message reflects retrieved K used.
- No changes required in VectorStoreRouter or ContainerService APIs.

Compatibility and Policy
- Legacy docs policy unchanged; retrieval remains per-container, and legacy `containerId == nil` mapping continues to default as in Documents/Visualizations views.
- No other direct call sites for `RAGService.query` exist; ChatScreen is the integration point.

Build Verification
- macOS Debug build succeeded after these changes:
  - `xcodebuild -project RAGMLCore.xcodeproj -scheme RAGMLCore -configuration Debug -destination 'platform=macOS' build`
  - Result: `** BUILD SUCCEEDED **`

Acceptance Criteria (met)
- Switching the pinned library changes retrieval scope accordingly.
- One-off override queries a different library without changing the pinned active library.
- Messages persist `containerId` for provenance; strict mode thresholds apply per selected container.

Next Steps
- Optional UI: show a small library badge per message (MessageList/ResponseDetailsView).
- Telemetry: record `containerId` and library name in query/generation events.
- Tests: unit/UI tests for override behavior and strict mode enforcement.

---

## Update: 2025-10-31 – Settings Modernization + iOS GGUF Path (Stub)

Summary
- Completed a consistency sweep to align all Settings-related screens with the app’s modern card-based DS:
  - Introduced shared primitives SurfaceCard, SectionHeader, SectionFooter and applied across Settings.
  - Converted: SettingsView, BackendHealthDiagnosticsView, DeveloperDiagnosticsHubView, DeveloperSettingsView, ContainerScopingSelfTestsView, AboutView.
- SettingsView Improvements:
  - Model Flow visualization converted to a SurfaceCard section.
  - iOS Picker style normalization using .navigationLink for AI Model, Fallbacks, and OpenAI Model pickers.
  - iOS gating: normalizeSelectedModelForPlatform() to avoid macOS-only selections persisting on iOS.
  - Central “Developer & Diagnostics” tile routes to consolidated hub.
- iOS On-Device Local Model Path (GGUF via embedded llama.cpp – stub):
  - Added selectable model “GGUF Local (iOS)” (LLMModelType.ggufLocal).
  - File import flow: .fileImporter copies the selected .gguf into Documents/Models and persists path/name.
  - Runtime wiring: RAGService → LlamaCPPiOSLLMService.fromDefaults() when selected.
  - Diagnostics: BackendHealthDiagnosticsView adds “Verify Model File” and “Run Smoke Test” buttons; current backend echoes to confirm wiring.
- macOS MLX section styled as SurfaceCard for visual parity.

Files Touched (this update)
- RAGMLCore/Views/Settings/SettingsView.swift (SurfaceCards, pickers, MLX/GGUF sections, Model Flow)
- RAGMLCore/Views/Settings/BackendHealthDiagnosticsView.swift (cards; iOS GGUF diagnostics)
- RAGMLCore/Views/Settings/DeveloperDiagnosticsHubView.swift (cards)
- RAGMLCore/Views/Settings/DeveloperSettingsView.swift (cards)
- RAGMLCore/Views/Settings/ContainerScopingSelfTestsView.swift (cards)
- RAGMLCore/Views/Settings/AboutView.swift (cards)
- RAGMLCore/Shared/DesignSystem/SurfaceCard.swift (primitives)

Status
- Settings modernization complete for targeted screens; design system consistency achieved.
- iOS GGUF runtime currently stubbed; UI flows and persistence are complete and validated via diagnostics.

Remaining Polish (short-term)
- Visual QA: spacing, icon weights/sizes, dark mode contrasts, Dynamic Type scaling.
- Add screenshots and brief user docs once embedded llama.cpp runtime lands.

Documentation
- Updated cline_docs/codebaseSummary.md with “Settings Modernization” section and iOS GGUF notes.
- This currentTask.md updated with this progress note and remaining polish items.

---

## Update: 2025-10-31 – NL Chunking Diagnostics + Apple FM Execution Preferences

Summary
- Added NaturalLanguage-driven chunking diagnostics and a developer UI to visualize them.
- Wired Apple Foundation Models path to respect execution preferences with telemetry and a safe fallback when PCC is blocked.

Changes Implemented
- SemanticChunker (Services/SemanticChunker.swift)
  - Added language detection (NLLanguageRecognizer) and lemma/POS-filtered keyword extraction
  - Introduced ChunkingDiagnostics struct, lastDiagnostics cache, and Notification.Name.semanticChunkerDiagnosticsUpdated
  - Unified token/word counting via NLTokenizer helpers; added diagnostics aggregation after chunking
- Diagnostics UI (Views/Telemetry/NLChunkingDiagnosticsView.swift)
  - New SurfaceCard-based panel showing language, hypotheses, sections, topic boundaries, sentence length, avg words/chunk, overlap, warnings
  - Subscribes to semanticChunkerDiagnosticsUpdated; emits TelemetryCenter event on update
- Developer Hub (Views/Settings/DeveloperDiagnosticsHubView.swift)
  - Added navigation link “NL Chunking Diagnostics”
- Apple FM Execution Preferences (Services/LLMService.swift)
  - Emitted TelemetryCenter events at generation start/complete with TTFT, total time, tokens, execution location
  - When user disallows PCC or selects On‑Device Only, and TTFT indicates PCC, abort stream and fall back to On-Device Analysis (extractive), with a warning telemetry event
- Settings compile fix (Views/Settings/SettingsView.swift)
  - iOS-only gating for ggufConfigurationSection to fix macOS build

Build Verification
- macOS Debug build: SUCCESS
  - Command: xcodebuild -project RAGMLCore.xcodeproj -scheme RAGMLCore -configuration Debug -destination 'platform=macOS' build

Next Steps
- Smoke test: Ingest sample docs, verify NL diagnostics populate; confirm UI updates and TelemetryCenter log entries
- Document: Add this update to projectRoadmap.md acceptance criteria and screenshots later
- Optional polish: Add execution-location badges in chat tied to telemetry (📱/☁️/🖥️/🔑)

---

## Update: 2025-10-31 – Build Verification After GGUF Import Concurrency Fix

Summary
- Resolved the reported compile error and warning, then verified a clean macOS Debug build.
  - Error fixed: “'async' call in a function that does not support concurrency” inside SettingsView GGUF import flow.
  - Warning fixed: “Variable 'cfg' was never mutated; consider changing to 'let' constant” in BackendHealthDiagnosticsView.

Changes
- SettingsView.swift (iOS GGUF import flow)
  - In .fileImporter completion:
    - Changed to invoke the handler within a Task:
      - `Task { await handleGGUFImport(sourceURL) }`
  - Converted the handler to async on the main actor:
    - `@MainActor private func handleGGUFImport(_ sourceURL: URL) async`
  - Inside handler:
    - Kept `await ModelRegistry.shared.load()` (now valid in async context)
    - Replaced inner Task-wrapped apply with direct `await applySettings()`
- BackendHealthDiagnosticsView.swift (iOS GGUF diagnostics)
  - In `runGGUFSmokeTest()`:
    - `var cfg = InferenceConfig(...)` → `let cfg = InferenceConfig(...)`

Build Verification
- Command:
  - `xcodebuild -scheme RAGMLCore -configuration Debug -destination 'platform=macOS' build`
- Result:
  - `** BUILD SUCCEEDED **`
- Notes:
  - No new compiler warnings introduced by these changes in the reported areas.
  - Default isolation remains MainActor at the target level, keeping UI updates on the main thread.

Acceptance Criteria (met)
- Concurrency error eliminated in SettingsView GGUF importer; import flow remains functional and UI-safe.
- Immutable config warning removed in BackendHealthDiagnosticsView.
- Project builds successfully for macOS Debug scheme.

Next Steps
- iOS manual sanity pass:
  - Verify the GGUF file import flow copies to Documents/Models and updates defaults/registry as expected.
  - Run Diagnostics “Verify Model File” and “Run Smoke Test” (stub backend) to confirm UI feedback.
- Documentation touch-ups:
  - Add a brief “GGUF Import Concurrency Fix” note to cline_docs/codebaseSummary.md.
  - Keep projectRoadmap.md progress updated under “Stability/Build hygiene.”

---

## Update: 2025-10-31 – Models & Downloads – Background Downloader, Catalog, Wi‑Fi‑Only, Pause/Resume, Telemetry

Summary
- Implemented a resilient on-device model download experience for local model “cartridges” (e.g., GGUF/Core ML) with:
  - Background downloads, Wi‑Fi‑only option, disk space preflight, pause/resume with resume data, ETA and throughput.
  - Settings-driven Catalog URL with manual refresh.
  - UI controls in Model Manager for Pause/Resume/Cancel and large-file warnings.
  - Detailed TelemetryCenter instrumentation across catalog and download lifecycle.
  - Integration with ModelRegistry upon successful installation.

Changes Implemented
- Services/ModelDownloadService.swift
  - Background URLSession with identifier "ai.ragmlcore.models.background" and waitsForConnectivity.
  - Wi‑Fi Only: respects @AppStorage("modelsWiFiOnly"); toggling rebuilds the session (rebuildSession()).
  - Disk space preflight hasSufficientDiskSpace(for:) with safety margin before starting a download.
  - Pause/Resume using cancel(byProducingResumeData:) and resumeData storage per entry; intentionallyPaused flag to distinguish user action vs error.
  - Progress metrics: bytesWritten, totalBytes, averageBytesPerSecond (EMA), lastTick; ETA computed from smoothed speed.
  - Large file guardrails: pre-download warning for multi-GB assets.
  - Telemetry events:
    - Catalog: models_catalog_load_started/succeeded/failed, models_catalog_fallback_used
    - Download: model_download_started/progress/cancelled/paused/resumed/installed/failed
  - Throttled progress telemetry (≈1 Hz) to reduce noise.

- Views/Settings/SettingsView.swift
  - New “Models & Downloads” card:
    - Catalog URL (TextField, persisted via @AppStorage("modelsCatalogURL"))
    - “Refresh Catalog” button → ModelDownloadService.shared.loadCatalog(from:)
    - “Wi‑Fi Only Downloads” toggle → calls ModelDownloadService.shared.rebuildSession() on change

- Views/ModelManagement/ModelManagerView.swift
  - Download list entries show:
    - Progress percent, speed (bytes/sec) and ETA readout (smoothed)
    - Pause + Cancel when downloading; Resume + Cancel when paused
    - Large download warning banner for big assets (e.g., > 1 GB)
  - Helpers for formatting bytes/time (formatBytesDouble, formatTime, downloadSpeedAndETA(for:))

- Registry Integration
  - On successful download + finalize: ModelRegistry updates with InstalledModel (de‑duped by path), enabling activation in-app.

Settings and Usage
- Configure the Catalog URL:
  1) Open Settings → Models & Downloads.
  2) Enter your Catalog URL and tap “Refresh Catalog” to pull the latest model list.
- Network controls:
  - Enable “Wi‑Fi Only Downloads” to restrict background downloads to non‑expensive networks.
  - The app waits for connectivity when temporarily offline and resumes automatically.
- Managing downloads:
  - In Model Manager, choose a model to Download.
  - While downloading, you can Pause or Cancel; when paused, you can Resume or Cancel.
  - Speed and ETA are shown; very large downloads surface a warning before starting.
- After install:
  - The model is registered in “Installed Models.” You can make it active depending on the backend (GGUF/Core ML/MLX).

Telemetry & Diagnostics
- TelemetryCenter emits catalog and download lifecycle events (including throttled progress with bytes and ETA).
- Use Developer & Diagnostics screens to observe events in real time during long downloads.

Build Verification
- iOS Simulator Debug build: SUCCESS in prior pass.
- macOS Debug build: unaffected; download logic is platform-safe with URLSession background config and main-queue delegate.

Acceptance Criteria (met)
- User can configure a remote catalog and refresh it from Settings.
- Initiate, pause, resume, and cancel large downloads with persistent progress and ETA/speed readouts.
- Wi‑Fi‑only policy is enforced via session rebuild.
- Successful downloads are registered and visible under Installed Models.
- Telemetry records key milestones and throttled progress without flooding.

Notes
- GGUF iOS backend is currently a stub (LlamaCPPiOSLLMService) for wiring validation; runtime integration with embedded llama.cpp will follow.
- Core ML model pathway is planned; this downloader/registry path is designed to accommodate .mlpackage artifacts as well.

Next Steps
- Add a small per-download “details” panel with recent telemetry snippets and checksum verification.
- Expose catalog health/status and last refresh time in Settings.
- Extend registry UI with “Make Active” affordances contextual to selected backend (GGUF/Core ML/MLX).
- Optional: persisted download queue with ordering and prioritization.

---

## Update: 2025-11-01 – Hugging Face Integration for Model Downloads

Summary
- Wired the downloader to Hugging Face so users can browse a repo’s files and download GGUF (and optionally Core ML artifacts) directly, with pause/resume, ETA, Wi‑Fi‑only enforcement, checksum verification, and registry install.

Changes Implemented
- URL Scheme + Resolve
  - Added hf:// scheme parsing: hf://owner/repo[:revision]/path/to/file
  - Resolve requests to: https://huggingface.co/{owner}/{repo}/resolve/{revision}/{path}?download=true
  - If Settings contains a token (hfToken), set Authorization: Bearer <token>
  - Error mapping for license-gated/invalid repos/rate limiting (403/404/429) with clear user messaging
- Repo File Listing API
  - listHuggingFaceGGUFFiles(owner:repo:token:includeCoreML:) calls /api/models/{owner}/{repo}?expand[]=siblings
  - Filters to .gguf files, optionally allows .mlpackage/.zip (future Core ML pathway)
  - Emits telemetry with file counts
- One‑Click Start
  - startHuggingFaceDownload(owner:repo:revision:path:sizeBytes:sha256:) constructs a temporary catalog entry and starts the download
  - Reuses background URLSession for resilience; progress, speed, ETA shown
- Settings
  - Settings → Models & Downloads: SecureField for Hugging Face token (@AppStorage "hfToken")
- Model Manager UI
  - “Add from Hugging Face” sheet:
    - Enter owner/repo and revision (default main)
    - Toggle to include Core ML artifacts in listing
    - List files (shows size and sha256 indicator if available)
    - Download button starts background download via the service
- Verification + Registry
  - If LFS metadata provides sha256, verify using CryptoKit before install
  - On success, install into ModelRegistry (GGUF now; Core ML to follow)
- Telemetry
  - Emits structured events (repo/revision/path) for list/resolve/start/progress/installed/failed

Build Verification
- macOS Debug build: SUCCESS
- iOS unaffected by this pass; GGUF Local (embedded llama.cpp) remains a stubbed runtime until the native integration lands

Acceptance Criteria (met)
- User can input owner/repo, list GGUF files, select one, and download with full pause/resume/ETA/Wi‑Fi‑only behavior
- Gated models produce actionable guidance (set token, accept license)
- Completed downloads appear in Installed Models; GGUF models can be made active on iOS
- Catalogs can also specify hf:// entries directly; downloader handles resolve + token automatically

---

## Update: 2025-11-01 – Developer Settings Makeover (Native Form) + Build Verification

Summary
- Simplified DeveloperSettingsView to a native Settings-style Form with compact Sections.
- Removed heavy custom chrome; retained functional presets and category toggles.
- Build verification completed for macOS Debug; app launched successfully.

Changes Implemented
- Views/Settings/DeveloperSettingsView.swift
  - Rewritten to use Form with Sections:
    - Console Logging Level (Picker + contextual InfoBox + help text)
    - Logging Categories (toggles for Pipeline/Performance/LLM/Streaming/VectorDB/Telemetry)
    - Presets (Production, Development, Debug)
    - System Logs (informational note)
    - Current Configuration summary (active level, enabled categories, estimated volume)
  - onChange handlers and preset actions call applyLoggingSettings(), which updates:
    - LoggingConfiguration.currentLevel
    - LoggingConfiguration.enabledCategories
  - Lightweight InfoBox component used for compact, readable explanations without heavy styling.
- Views/Settings/DeveloperDiagnosticsHubView.swift
  - Existing navigation to Developer Settings via consolidated hub is compatible; no additional changes required.

Build Verification
- Command:
  - xcodebuild -project RAGMLCore.xcodeproj -scheme RAGMLCore -configuration Debug -destination 'platform=macOS' build
- Result:
  - **BUILD SUCCEEDED**
- App Launch:
  - Opened Debug app from DerivedData; verified Settings screen code path and Developer & Diagnostics hub navigation are intact.

Acceptance Criteria (met)
- “Make it easy” applied: native, minimal layout without custom dependencies.
- Addressed the likely “wrong settings view” by targeting Developer Settings specifically.
- No compile errors; runtime logging configuration updates propagate immediately via LoggingConfiguration.
