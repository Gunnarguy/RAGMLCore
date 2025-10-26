# NaturalLanguage Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's NaturalLanguage documentation. For RAGMLCore's embedding and tokenization pipeline, start with the `essentials/` folder and sections below – it highlights the APIs we use inside `EmbeddingService.swift`.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| NLEmbedding | Word-level embeddings for semantic search | `essentials/documentation_naturallanguage_nlembedding.json` |
| Word Embeddings | Generate 512-dim vectors for text chunks | `essentials/documentation_naturallanguage_nlembedding_wordembedding(for:).json` |
| Vector Operations | Calculate cosine similarity between embeddings | `essentials/documentation_naturallanguage_nlembedding_distance(between:and:distancetype:).json` |
| Tagging | Part-of-speech and entity recognition | `essentials/documentation_naturallanguage_nltagger.json` |
| Language Detection | Identify language of text | `essentials/documentation_naturallanguage_nltagger_dominantlanguage.json` |

## Related Files Per Topic

- **NLEmbedding:** `essentials/documentation_naturallanguage_nlembedding_init(contentsof:).json`, `essentials/documentation_naturallanguage_nlembedding_revision.json`
- **Word Embeddings:** `essentials/documentation_naturallanguage_nlembedding_wordembedding(for:).json`, `essentials/documentation_naturallanguage_nlembedding_vector(for:).json`
- **Vector Operations:** `essentials/documentation_naturallanguage_nlembedding_neighbors(for:maximumcount:distancetype:).json`, `essentials/documentation_naturallanguage_nlembedding_distance(between:and:distancetype:).json`
- **Tagging:** `essentials/documentation_naturallanguage_nltagger_init(tagschemes:).json`, `essentials/documentation_naturallanguage_nltagger_enumeratetags(in:unit:scheme:options:using:).json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/naturallanguage/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the embedding/NLP code paths we care about remain one click away.
