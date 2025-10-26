# SwiftUI Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's SwiftUI documentation. For RAGMLCore's UI layer, start with the `essentials/` folder and sections below – it highlights the APIs we use across all view files.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| View Protocol | Base protocol for all SwiftUI views | `essentials/documentation_swiftui_view.json` |
| Layout Fundamentals | Control sizing and alignment | `essentials/documentation_swiftui_layout-fundamentals.json` |
| Lists | Present retrieved chunks and history | `essentials/documentation_swiftui_lists.json` |
| Navigation | Manage tab and detail flows | `essentials/documentation_swiftui_navigation.json` |
| Common Modifiers | Frequently used view transforms | `essentials/documentation_swiftui_view_padding(_:).json` |

## Related Files Per Topic

- **View Protocol:** `essentials/documentation_swiftui_view_fixedsize().json`, `essentials/documentation_swiftui_view_layoutpriority(_:).json`
- **Layout Fundamentals:** `essentials/documentation_swiftui_view_offset(x:y:).json`, `essentials/documentation_swiftui_view_frame(width:height:alignment:).json`
- **Lists:** `essentials/documentation_swiftui_lists.json`, `essentials/documentation_swiftui_dynamicviewcontent.json`
- **Navigation:** `essentials/documentation_swiftui_navigation.json`, `essentials/documentation_swiftui_view_scenepadding(_:edges:).json`
- **Common Modifiers:** `essentials/documentation_swiftui_view_padding(_:).json`, `essentials/documentation_swiftui_view_safeareapadding(_:).json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/swiftui/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the view building code paths we care about remain one click away.
