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
- Compiles with new sources (Xcode’s file-system synchronized group should pick up new Swift files).
- MLX Local requires user to run a local server on macOS to be “available.”
- Core ML sentence embeddings and CoreML LLM are scaffolded but not functional yet (tokenization/IO TBD).
