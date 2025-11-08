# Roadmap

## Completed
- Core RAG pipeline complete
- Universal document support
- OpenAI integration (production)
- On-device extractive QA
- SwiftUI interface
- Apple Foundation Models (tool calling + fallbacks)
- Private Cloud Compute toggle + telemetry
- Persistent vector database per container
- ChatGPT Extension integration
- Hybrid search (vector + BM25 + MMR)
- GGUF local cartridges + Core ML cartridge manager (beta)
- Writing Tools API surface
- Siri App Intents beta

## Next Priorities

1. Ship GGUF/Core ML cartridge manager to GA (stability, download UX) (12-16h)
2. Local inference auto-tuning (temperature/top-p presets per backend) (6-8h)
3. Vector DB persistence hardening (incremental compaction, integrity checks) (8-12h)
4. Hybrid search analytics (per-query diagnostics UI + tuning controls) (6-8h)
5. Writing Tools extensibility (third-party plug-ins, sandboxing) (8-10h)
6. Siri App Intents v1 GA (voice shortcuts, background execution sync) (6-8h)

## Future

- Multi-language embeddings (language-aware chunking + locale UI) (16-24h)
- Core ML autoregressive loop (bring-your-own decoder/encoder) (20-30h)
- Advanced vector backends (Vectura HNSW GA, SQLite/Metal fallback) (12-18h)
- Offline evaluation harness (golden Q&A sets, drift tracking) (10-14h)
- Custom tokenizer tooling (UI for Core ML/gguf tokenizer swaps) (12-16h)
- Private Cloud Compute analytics dashboard (7-9h)
- Performance budget: latency regression suite + telemetry alerts (10-12h)
- Multi-tenant knowledge containers (shared datasets, ACLs) (20-32h)
