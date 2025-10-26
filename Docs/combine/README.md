# Combine Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's Combine documentation. For RAGMLCore's reactive state management, start with the `essentials/` folder and sections below – it highlights the APIs we use inside `RAGService.swift` and other services.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| Observable Objects | @MainActor state container protocol | `essentials/documentation_combine_observableobject.json` |
| Published Property | Reactive @Published for SwiftUI binding | `essentials/documentation_combine_published.json` |
| AnyCancellable | Lifetime management for subscriptions | `essentials/documentation_combine_anycancellable.json` |
| Publishers | Core async/await pattern foundation | `essentials/documentation_combine_publisher.json` |
| Subjects | PassthroughSubject / CurrentValueSubject | `essentials/documentation_combine_subject.json` |

## Related Files Per Topic

- **Observable Objects:** `essentials/documentation_combine_observableobjectpublisher.json`
- **Published Property:** `essentials/documentation_combine_processing-published-elements-with-subscribers.json`
- **AnyCancellable:** `essentials/documentation_combine_cancellable_cancel().json`
- **Publishers:** `essentials/documentation_combine_publisher_receive(on:options:).json`, `essentials/documentation_combine_publishers_subscribeon.json`
- **Subjects:** `essentials/documentation_combine_passthroughsubject.json`, `essentials/documentation_combine_currentvaluesubject.json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/combine/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the reactive patterns we care about remain one click away.
