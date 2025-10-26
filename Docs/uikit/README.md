# UIKit Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's UIKit documentation. For RAGMLCore's optional iOS 17 compatibility layer, start with the `essentials/` folder and sections below – it highlights core UIKit APIs.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| View Controllers | Manage UIKit navigation stacks | `essentials/documentation_uikit_view-controllers.json` |
| Views & Controls | Class hierarchy and key components | `essentials/documentation_uikit_views-and-controls.json` |
| Layout System | Understand Auto Layout primitives | `essentials/documentation_uikit_view-layout.json` |
| Text Display | Legacy rich text rendering | `essentials/documentation_uikit_text-display-and-fonts.json` |
| Menus & Actions | Modern menu and command handling | `essentials/documentation_uikit_menus-and-shortcuts.json` |

## Related Files Per Topic

- **View Controllers:** `essentials/documentation_uikit_uiresponder.json`, `essentials/documentation_uikit_windows-and-screens.json`
- **Views & Controls:** `essentials/documentation_uikit_uibutton.json`, `essentials/documentation_uikit_uimenu.json`
- **Layout System:** `essentials/documentation_uikit_nslayoutconstraint.json`, `essentials/documentation_uikit_nslayoutanchor.json`
- **Text Display:** `essentials/documentation_uikit_text-display-and-fonts.json`, `essentials/documentation_uikit_uilabel.json`
- **Menus & Actions:** `essentials/documentation_uikit_uiaction.json`, `essentials/documentation_uikit_adopting-menus-and-uiactions-in-your-user-interface.json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/uikit/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the legacy iOS controller code paths remain one click away.
