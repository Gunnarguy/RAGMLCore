## Current Task: Offload pure compute from RAGService.query to a background actor

Date: 2025-10-24

Context
- Objective: Reduce main-thread work in the RAG pipeline without violating Swift 6 actor isolation (project uses -default-isolation=MainActor).
- Focus: Move pure, CPU-heavy stages off the main actor while keeping actor-isolated services (HybridSearchService, LLM, etc.) on the main actor as required by current isolation.
- Entry points: ChatView.sendMessage() → RAGService.query(_:topK:config:).

Changes Implemented
1) New background actor
   - File: RAGMLCore/Services/RAGEngine.swift
   - Type: actor RAGEngine
   - Responsibilities:
     - applyMMR(candidates:queryEmbedding:topK:lambda:) async -> [RetrievedChunk]
     - formatContext(_:) async -> String
   - Both methods include cancellation checks (Task.isCancelled) to be cooperative under cancellation.

2) Wire-in from RAGService
   - File: RAGMLCore/Services/RAGService.swift
   - In query pipeline Step 4.5 and Step 5:
     - Replaced in-place MMR and context assembly with:
       - let engine = RAGEngine()
       - let diverseChunks = await engine.applyMMR(...)
       - let rawContext = await engine.formatContext(diverseChunks)
   - Removed private helpers from RAGService:
     - formatContext(_:), applyMMR(...), cosineSimilarity(_:_:)

3) Concurrency hygiene
   - File: RAGMLCore/Models/RAGQuery.swift
   - Added Sendable to: RAGQuery, RAGResponse, RetrievedChunk, ResponseMetadata.
   - Under Swift 6 with InferSendableFromCaptures and NonisolatedNonsendingByDefault, these value types have only Sendable members and are safe for cross-actor use.

Why this is safe and effective
- We do not call main-actor–isolated services from background executors.
- We relocate only pure compute (MMR selection, large-string context building) into a dedicated actor with its own executor, reducing main-thread stalls.
- Cancellation points make long loops responsive to user-initiated cancel in future work.

Build Status
- Local xcodebuild for iOS Simulator (Debug) reports: BUILD SUCCEEDED after changes.

How to validate UI responsiveness (manual smoke test)
1) Run the app on Simulator or device.
2) In ChatView, trigger a query over an indexed corpus (≥ a few hundred chunks if possible).
3) Observe:
   - UI remains responsive while “MMR Diversification” and “Context assembly” stages run (logs show timings).
   - No actor isolation warnings in console.
4) Optional: Use Instruments “Main Thread Checker” + Time Profiler to confirm reduced time spent on main during Step 4.5 and Step 5.

Notes / Flags
- Project uses -default-isolation=MainActor globally. Explicit actor (RAGEngine) runs on its own executor by design and is not main-actor isolated.
- RetrievedChunk and related model structs are value types; with Sendable conformance they are safe across actors.

Next Steps (deferred)
- Stage 2 (optional): Move QueryEnhancementService.rerank pure scoring into RAGEngine to further reduce main-thread compute. Requires relocating keyword/proximity helpers.
- Add Task handles for query cancellation from ChatView and propagate cancellation; engine methods already cooperate with Task.isCancelled.
- Repo tidy pass (separate effort): SettingsStore, consolidated Diagnostics/Telemetry hub, reusable views, README consolidation.

Files touched
- Added: RAGMLCore/Services/RAGEngine.swift
- Modified: RAGMLCore/Services/RAGService.swift (engine usage, removed private helpers)
- Modified: RAGMLCore/Models/RAGQuery.swift (Sendable conformances)
