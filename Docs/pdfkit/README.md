# PDFKit Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's PDFKit documentation. For RAGMLCore's PDF extraction pipeline, start with the `essentials/` folder and sections below – it highlights the APIs we touch inside `DocumentProcessor.swift`.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| PDF Document | Load and parse PDF files | `essentials/documentation_pdfkit_pdfdocument.json` |
| PDF Page | Extract text and render pages | `essentials/documentation_pdfkit_pdfpage.json` |
| Page Extraction | Get text from individual PDF pages | `essentials/documentation_pdfkit_pdfpage_string.json` |
| Page Rendering | Render PDF pages as images for OCR | `essentials/documentation_pdfkit_pdfpage_thumbnail(of:for:).json` |
| Annotation Support | Handle PDF annotations/metadata | `essentials/documentation_pdfkit_pdfannotation.json` |

## Related Files Per Topic

- **PDF Document:** `essentials/documentation_pdfkit_pdfdocument_init(url:).json`, `essentials/documentation_pdfkit_pdfdocument_pagecount.json`, `essentials/documentation_pdfkit_pdfdocument_page(at:).json`
- **PDF Page:** `essentials/documentation_pdfkit_pdfpage_init().json`, `essentials/documentation_pdfkit_pdfpage_string.json`, `essentials/documentation_pdfkit_pdfpage_attributedstring.json`
- **Page Extraction:** `essentials/documentation_pdfkit_pdfpage_characterindex(at:).json`, `essentials/documentation_pdfkit_pdfpage_selection(for:).json`
- **Page Rendering:** `essentials/documentation_pdfkit_pdfpage_thumbnail(of:for:).json`, `essentials/documentation_pdfkit_pdfpage_draw(with:to:).json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/pdfkit/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the PDF text extraction code paths we care about remain one click away.
