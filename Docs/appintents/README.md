# AppIntents Reference Guide

The `raw/` folder contains the full JSON dump from Apple’s App Intents documentation. For day-to-day development, start with the `essentials/` folder and the sections below – it highlights the handful of APIs we actually touch inside `RAGAppIntents.swift`.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| Declaring an intent | Base protocol requirements (`perform()`, `static` metadata) | `essentials/documentation_appintents_appintent.json` |
| Talking to Siri | Configure prompt text and categories | `essentials/documentation_appintents_intentdescription.json` |
| Crafting responses | Building spoken/dialog answers | `essentials/documentation_appintents_intentdialog.json` |
| Returning results | How `.result(dialog:view:)` and friends behave | `essentials/documentation_appintents_intentresult.json` |
| Siri UI protocols | Snippet / dialog conformance for SwiftUI views | `essentials/documentation_appintents_providesdialog.json` |
| Parameters | `@Parameter` behaviour and summaries | `essentials/documentation_appintents_intentparameter.json` |
| Shortcuts tiles | Registering shortcuts for the Shortcuts app | `essentials/documentation_appintents_appshortcut.json` |
| App Shortcuts builders | DSL used by `RAGAppShortcutsProvider` | `essentials/documentation_appintents_appshortcutsbuilder.json` |

## Related Files Per Topic

- **Talking to Siri:** `essentials/documentation_appintents_intentdescription_init(_:categoryname:searchkeywords:).json`
- **Crafting responses:** `essentials/documentation_appintents_intentdialog_init(_:).json`, `essentials/documentation_appintents_intentdialog_init(full:systemimagename:).json`, `essentials/documentation_appintents_intentdialog_init(full:supporting:).json`, `essentials/documentation_appintents_intentdialog_init(full:supporting:systemimagename:).json`
- **Returning results:** `essentials/documentation_appintents_intentresult_result(dialog:).json`, `essentials/documentation_appintents_intentresult_result(dialog:view:).json`, `essentials/documentation_appintents_intentresult_result(value:dialog:).json`, `essentials/documentation_appintents_intentresult_result(value:dialog:view:).json`, `essentials/documentation_appintents_intentresult_result(dialog:snippetintent:).json`
- **Siri UI protocols:** `essentials/documentation_appintents_showssnippetview.json`
- **Parameters:** `essentials/documentation_appintents_intentparametersummary.json`, `essentials/documentation_appintents_intentparametersummary_init(_:).json`, `essentials/documentation_appintents_intentparametersummary_init(_:table:).json`
- **Shortcuts tiles:** `essentials/documentation_appintents_appshortcutsprovider.json`, `essentials/documentation_appintents_appshortcutsprovider_appshortcuts.json`, `essentials/documentation_appintents_appshortcutsprovider_summary.json`, `essentials/documentation_appintents_appshortcutsprovider_title.json`, `essentials/documentation_appintents_appshortcutsprovider_updateappshortcutparameters().json`
- **App Shortcuts builders:** `essentials/documentation_appintents_appshortcutsbuilder_buildblock().json`, `essentials/documentation_appintents_appshortcutsbuilder_buildblock(_:)-110ow.json`, `essentials/documentation_appintents_appshortcutsbuilder_buildexpression(_:)-31qci.json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple’s documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/appintents/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout the firehose stays inside `raw/`, while the intent code paths we care about remain one click away.
