# Apple Foundation Models 2025 – Embeddings and RAG Integration Summary

Last reviewed: 2025-10-30

## Snapshot Source
This summary reflects the local Apple docs snapshot in this repo under `Docs/`:
- FoundationModels overview and `SystemLanguageModel` pages
- `LanguageModelSession` and streaming APIs
- Availability and PCC (Private Cloud Compute) information

## Key Findings

1) Language model execution (LLM) – Available and documented
- `LanguageModelSession`: on-device text generation with optional streaming (`ResponseStream`)
- Tool-calling: supported (already integrated in AppleFoundationLLMService)
- PCC fallback: automatic for complex tasks; device availability depends on chip tier and OS settings
- Availability reasons: `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady` are documented and already surfaced in our capability checks

2) Embeddings API – Not published in our snapshot
- No documented FoundationModels endpoint for sentence embeddings was found
- Implication: Continue using on-device `NLEmbedding` and Core ML converted sentence encoders for RAG
- We’ve scaffolded `AppleFMEmbeddingProvider` that reports `isAvailable = false` and throws `.notImplemented` until Apple publishes a public embedding interface

3) Private Cloud Compute (PCC) behavior
- Zero retention by design; invoked based on complexity
- We already surface on-device vs PCC heuristics via TTFT and a UI badge
- Next: unify telemetry to include explicit `executionLocation` + container info

## Integration Status in RAGMLCore

- LLM (Apple FM): Implemented via AppleFoundationLLMService (on-device + PCC fallback)
- Tool-calling: Implemented; RAG tools wired and accounted in telemetry counters
- Embeddings: 
  - NLEmbeddingProvider (512-dim) — shipping, default
  - CoreMLSentenceEmbeddingProvider — scaffolded, tokenizer/IO pending
  - AppleFMEmbeddingProvider — scaffolded (unavailable until API exists)
- Vector store: Per-container routing and dimension safety via `VectorStoreRouter`
- UI/UX: Multi-container libraries with container picker + management sheet

## Plan if Apple Embeddings Ship

- Add AppleFMEmbeddingProvider real implementation:
  - Implement `embed(text:)`/`embedBatch(texts:)`
  - Confirm dimensions and normalization behavior
  - Respect execution location and telemetry (On-Device vs PCC)
- Container settings:
  - Allow selecting provider `apple_fm_embed` when available (per library)
  - Enforce dimension checks and re-embed workflow as needed
- Telemetry:
  - Emit `embeddingProvider`, `embeddingDim`, `executionLocation`, and timings per stage

## Strict Mode Defaults (Medical Context) – Placement
Even before Apple embeddings arrive:
- minSimilarity: 0.52
- minSupportingChunks: ≥ 3
- MMR λ: 0.75 (relevance-biased)
- Temperature: 0.2 (+ low variability)
- Enforce inline citations for claims; otherwise fallback to cautious response with sources

## Open Questions to Revisit on Next WWDC/SDK Drop
- Official embeddings API name and types (FoundationModels?)
- Supported dimensions, multilingual coverage, normalization specifics
- On-device vs PCC routing for embeddings + quotas/rate limits
- Cost/perf relative to NLEmbedding and common Core ML sentence encoders

## Verification Checklist
- Device capability gating for FoundationModels remains accurate
- Telemetry shows execution location and TTFT consistently for Apple FM
- If Apple publishes embeddings, enable provider behind `canImport(FoundationModels)` and availability checks
