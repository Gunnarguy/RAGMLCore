## Codebase Summary – RAGMLCore

Last updated: 2025-10-28

## Key Components and Their Interactions
- Views
  - ChatView: main chat UI, triggers RAGService.query
  - SettingsView: model selection, PCC controls, fallbacks, pipeline visualization
  - Diagnostics: CoreValidationView, TelemetryDashboardView for testing and telemetry
- Services
  - RAGService: orchestrates the RAG pipeline (ingestion, retrieval, generation)
  - LLMService implementations:
    - AppleFoundationLLMService (iOS 26+ FoundationModels with PCC)
    - AppleChatGPTExtensionService (iOS 18.1+ AppIntents; entitlement-dependent)
    - OpenAILLMService (direct HTTP API to OpenAI)
    - OnDeviceAnalysisService (extractive QA fallback using NaturalLanguage)
    - CoreMLLLMService (scaffold for custom Core ML LLMs)
    - MLXLocalLLMService (new, macOS-only HTTP bridge to local mlx-lm)
  - Embeddings (new abstraction)
    - EmbeddingService: delegates to EmbeddingProvider
    - EmbeddingProvider protocol: pluggable backends
    - NLEmbeddingProvider: 512-dim word-avg (parity with prior behavior)
    - CoreMLSentenceEmbeddingProvider: scaffold for sentence encoders (384/768)
  - RAGEngine: background actor for MMR, context assembly, re-ranking helpers
  - HybridSearchService, VectorDatabase, DocumentProcessor, QueryEnhancementService, SemanticChunker: indexing, retrieval, chunking infrastructure
- Models
  - LLMModelType: enumerates selectable backends (now includes mlxLocal, coreMLLocal)
  - InferenceConfig, RAGQuery, DocumentChunk, RetrievedChunk: data structures for pipeline state

## Data Flow
1. Ingestion
   - DocumentProcessor parses documents (PDFKit, Vision OCR if needed)
   - SemanticChunker creates chunks with metadata
   - EmbeddingService generates embeddings via provider; stored in VectorDatabase
2. Query
   - ChatView calls RAGService.query(question, config)
   - Query enhancement (optional), embed query, hybrid search (vector + BM25), re-ranking (RRF/MMR via RAGEngine), context assembly
3. Generation
   - LLMService chosen by user preferences and availability (Apple FM → ChatGPT Ext → OpenAI → OnDeviceAnalysis; now MLX/ Core ML are options)
   - Apple FM may run on-device or via PCC based on complexity; OpenAI uses HTTPS; MLX local calls a local server on macOS
4. Response
   - Telemetry planned for tokens/sec, TTFT, execution location; UI badges to indicate privacy/execution path

## External Dependencies
- Apple frameworks: FoundationModels (iOS 26+), AppIntents, NaturalLanguage, Vision/VisionKit (planned upgrades), CoreML, PDFKit, AVFoundation/Speech (planned), SwiftUI
- OpenAI API (HTTPS) when user-configured
- MLX (macOS): local Python server `mlx_lm.server` exposed with OpenAI-style endpoints

## Recent Significant Changes
- Added EmbeddingProvider abstraction and NLEmbeddingProvider to preserve behavior and enable future sentence encoders
- Refactored EmbeddingService to delegate to provider (no public API break)
- Added CoreMLSentenceEmbeddingProvider scaffold (tokenization/IO TBD)
- Implemented MLXLocalLLMService (macOS-only local server bridge; OpenAI-compatible request body)
- Extended LLMModelType with `.mlxLocal` and `.coreMLLocal`
- Updated SettingsView to include MLX/Core ML options and corresponding pipeline stages

## User Feedback Integration and Impact on Development
- Request: adopt latest Apple 2025 AI stack and avoid deprecated paths; ensure on-device-first, PCC fallback, local open-models (MLX) and Core ML support
- Impact:
  - Provided new model options and routing in Settings
  - Preserved privacy-first design while enabling larger local models (MLX) on macOS
  - Established embeddings abstraction to support better multilingual sentence encoders and future providers

## Notes / Next Steps
- Core ML sentence encoder: implement tokenizer and IO mapping for one known model
- CoreMLLLMService: implement TokenizerAdapter and end-to-end generation for at least one small LLM
- TelemetryCenter: record backendUsed, executionLocation, TTFT, tokens/sec, toolCallsMade
- WritingTools: integrate into composer with fallbacks
- VisionKit scanning and improved OCR settings
- UI: show execution-location badges (📱/☁️/🖥️/🔑) and “why unavailable” diagnostics
