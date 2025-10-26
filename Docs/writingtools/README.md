# WritingTools Framework Reference Guide

Apple hasn't published WritingTools JSON dumps through the same endpoint used for the other frameworks yet—the fetch returns a 404 for every symbol. As a result, `raw/` and `essentials/` stay empty in this directory.

For implementation details today:

- Use Xcode's built-in documentation browser for `WritingTools` symbols.
- Reference the SwiftUI input field guides (`Docs/swiftui/README.md`) for usage patterns until JSON dumps land.
- Track the fetch script so we can drop the real JSON files in place as soon as Apple exposes them.

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Once Apple exposes JSON docs, add the files in `raw/` and mirror any high-priority ones inside `essentials/`.
2. Document new references in this README so the helper script can pull them into the subset automatically.

With this layout, the firehose stays inside `raw/`, while the text enhancement APIs remain one click away.
