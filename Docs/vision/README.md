# Vision Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's Vision documentation. For RAGMLCore's OCR pipeline, start with the `essentials/` folder and sections below – it highlights the APIs we touch inside `DocumentProcessor.swift`.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| Image Request Handlers | Process CIImage for text recognition | `essentials/documentation_vision_vnimagerequesthandler.json` |
| Text Recognition | Extract text via OCR from PDFs/images | `essentials/documentation_vision_vnrecognizetextrequest.json` |
| Text Observations | Parse OCR results as recognized text | `essentials/documentation_vision_vnrecognizedtextobservation.json` |
| VN Framework Core | Request base protocol and types | `essentials/documentation_vision.json` |
| Core Image Integration | CIImage input to Vision requests | `essentials/documentation_visionkit.json` |

## Related Files Per Topic

- **Image Request Handlers:** `essentials/documentation_vision_vnimagerequesthandler_init(ciimage:options:).json`, `essentials/documentation_vision_vnimagerequesthandler_perform(_:).json`
- **Text Recognition:** `essentials/documentation_vision_vnrecognizetextrequest_supportedrecognitionlanguages().json`, `essentials/documentation_vision_vnrecognizetextrequest_useslanguagecorrection.json`, `essentials/documentation_vision_vnrecognizetextrequest_recognitionlanguages.json`
- **Text Observations:** `essentials/documentation_vision_vnrecognizedtextobservation_topcandidates(_:).json`, `essentials/documentation_vision_vnrecognizedtext.json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/vision/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the OCR code paths we care about remain one click away.
