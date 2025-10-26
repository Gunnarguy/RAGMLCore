# FoundationModels Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's FoundationModels documentation (iOS 26+). For RAGMLCore's on-device LLM inference, start with the `essentials/` folder and sections below – it highlights the APIs for Apple Intelligence integration.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| Language Model Session | Configure on-device inference | `essentials/documentation_foundationmodels_languagemodelsession.json` |
| System Language Model | Detect device capability & guardrails | `essentials/documentation_foundationmodels_systemlanguagemodel.json` |
| Respond API | Generate completions on-device | `essentials/documentation_foundationmodels_languagemodelsession_respond(options:prompt:).json` |
| Streaming Responses | Stream tokens for chat UI | `essentials/documentation_foundationmodels_languagemodelsession_streamresponse(options:prompt:).json` |
| Availability & Use Cases | Decide on PCC fallback and adapters | `essentials/documentation_foundationmodels_systemlanguagemodel_availability-swift.property.json` |

## Related Files Per Topic

- **Language Model Session:** `essentials/documentation_foundationmodels_languagemodelsession_init(model:tools:instructions:).json`, `essentials/documentation_foundationmodels_languagemodelsession_isresponding.json`
- **System Language Model:** `essentials/documentation_foundationmodels_systemlanguagemodel_isavailable.json`, `essentials/documentation_foundationmodels_systemlanguagemodel_guardrails.json`
- **Respond API:** `essentials/documentation_foundationmodels_languagemodelsession_respond(options:prompt:).json`, `essentials/documentation_foundationmodels_languagemodelsession_respond(to:generating:includeschemainprompt:options:).json`
- **Streaming Responses:** `essentials/documentation_foundationmodels_languagemodelsession_streamresponse(options:prompt:).json`, `essentials/documentation_foundationmodels_languagemodelsession_responsestream.json`
- **Availability & Use Cases:** `essentials/documentation_foundationmodels_systemlanguagemodel_availability-swift.enum.json`, `essentials/documentation_foundationmodels_systemlanguagemodel_usecase.json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/foundationmodels/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the iOS 26 Apple Intelligence LLM APIs we care about remain one click away.
