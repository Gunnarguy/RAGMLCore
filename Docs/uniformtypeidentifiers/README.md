# UniformTypeIdentifiers Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's UniformTypeIdentifiers documentation. For RAGMLCore's file type handling, start with the `essentials/` folder and sections below – it highlights APIs for document identification.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| UTType Overview | Understand the type system we query | `essentials/documentation_uniformtypeidentifiers_uttype-swift.struct.json` |
| Defining Types | Declare custom ingest formats | `essentials/documentation_uniformtypeidentifiers_defining-file-and-data-types-for-your-app.json` |
| System Catalog | Reference Apple's built-in identifiers | `essentials/documentation_uniformtypeidentifiers_system-declared-uniform-type-identifiers.json` |
| PDF Type | Identify PDF documents | `essentials/documentation_uniformtypeidentifiers_uttypepdf.json` |
| Plain Text | Identify text documents | `essentials/documentation_uniformtypeidentifiers_uttypeplaintext.json` |

## Related Files Per Topic

- **UTType Overview:** `essentials/documentation_uniformtypeidentifiers_uttype-swift.struct.json`, `essentials/documentation_uniformtypeidentifiers_uniformtypeidentifiers-constants.json`
- **Defining Types:** `essentials/documentation_uniformtypeidentifiers_defining-file-and-data-types-for-your-app.json`, `essentials/documentation_uniformtypeidentifiers_uttype-swift.struct_aliasfile.json`
- **System Catalog:** `essentials/documentation_uniformtypeidentifiers_system-declared-uniform-type-identifiers.json`
- **Known Types:** `essentials/documentation_uniformtypeidentifiers_uttypepdf.json`, `essentials/documentation_uniformtypeidentifiers_uttypeplaintext.json`, `essentials/documentation_uniformtypeidentifiers_uttypertf.json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/uniformtypeidentifiers/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the file type detection APIs remain one click away.
