# CoreImage Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's CoreImage documentation. For RAGMLCore's image processing in OCR pipeline, start with the `essentials/` folder and sections below – it highlights the APIs we use inside `DocumentProcessor.swift`.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| CIImage | Immutable image container for Vision | `essentials/documentation_coreimage_ciimage.json` |
| Image Loading | Load images from URLs/data | `essentials/documentation_coreimage_ciimage_init(contentsof:).json` |
| Image Extent | Query image dimensions and properties | `essentials/documentation_coreimage_ciimage_extent.json` |
| Image Filters | Apply preprocessing before OCR | `essentials/documentation_coreimage_cifilter-swift.class.json` |
| CIContext | Rendering context for image operations | `essentials/documentation_coreimage_cicontext.json` |

## Related Files Per Topic

- **CIImage:** `essentials/documentation_coreimage_ciimage_init(color:).json`
- **Image Loading:** `essentials/documentation_coreimage_ciimage_init(contentsof:).json`
- **Image Extent:** `essentials/documentation_coreimage_ciimage_extent.json`
- **Image Filters:** `essentials/documentation_coreimage_cifilter-swift.class_name.json`, `essentials/documentation_coreimage_cifilter-swift.class_attributes.json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/coreimage/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the image processing code paths we care about remain one click away.
