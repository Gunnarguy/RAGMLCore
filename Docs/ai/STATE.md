# Current State

Updated: 2026-09-10, 09:20
Branch/worktree: main (primary checkout)
Last verified commit: d1ece6a

## Objective

**5.2, the Private Cloud Compute release, is staged and now testable on TestFlight.** The sale
that accompanies it is scheduled and live in App Store Connect. Two things block a real 5.2
submission: Apple has not put the release Xcode 27 on Xcode Cloud, and this repository cannot
currently run its own test suite.

## Status

### 2026-09-10 session: what changed, and what is now blocked

**A PCC-capable 5.2 is already on TestFlight.** Build 444, version 5.2, both iOS and macOS,
`internalBuildState: IN_BETA_TESTING`, uploaded 2026-09-09 16:02 PDT. It was produced by Xcode
Cloud run #444 from commit `c45e078`; every push to `main` triggers a build, so this was
incidental rather than deliberate. It genuinely carries Private Cloud Compute: `ci_post_xcodebuild.sh`
Gate 1 exits 1 for any version at or above 5.2 with zero `PrivateCloudCompute` symbols, and it
requires a non-zero `SystemLanguageModel` control first, so a passing 5.2 build is proof the
symbols are linked. `[evidence_level: build_verified, confidence: exact]`

**The machine can now run PCC.** macOS is 27.0 build 26A428, the release candidate, updated
2026-09-10. The iPhone 16 Pro Max was last seen on iOS 27.0 build 24A5418b, a beta. Xcode locally
is still 26.6 (Swift 6.3.3) with the 27 beta 1 (27A5194q, Swift 6.4) alongside; `xcode-select`
points at 26.6. Xcode Cloud still offers nothing newer than Xcode 27 beta 6, checked three times
on 2026-09-10.

**Shipped this session:** commit `d1ece6a`, reasoning level now reaches Apple on every path that
produces a user answer. `ContextOptions.reasoningLevel` is a defaulted argument on every `respond`
and `streamResponse` overload, so omitting it silently runs at Apple's default effort; one of
twenty-five call sites passed it. Deep Think and Maximum will now be materially more expensive on
the PCC path than they were.

**BLOCKER: `xcodebuild test` cannot link the Engine target.** `OpenIntelligenceEngine` declares no
`packageProductDependencies` while referencing `Tokenizers` symbols, so linking it standalone for
the test action fails on `AutoTokenizer.from(directory:)`. Reproduced with the working tree
stashed at `c45e078`, so it is not caused by recent work, and it survived both a clean
`-derivedDataPath` and `xcodebuild -resolvePackageDependencies`. The suite passed earlier the same
day, and the macOS 27 RC update happened in that window. **The fix needs `project.pbxproj`, a
hard-boundary file.** Until it is fixed, no session can verify anything by test.

**Verification that did run:** `bash scripts/build_simulator_smoke.sh` (green), and a Swift 6.4
build with `DEVELOPER_DIR=/Applications/Xcode-beta.app` for `generic/platform=iOS` (green), which
matters because the smoke build runs on Swift 6.3.3 where every `#if compiler(>=6.4)` branch
compiles out and therefore proves nothing about PCC code. The Swift 6.4 binary links 8
`ContextOptions`, 19 `PrivateCloudCompute` and 32 `SystemLanguageModel` symbols. Also green:
`python3 scripts/secret_scan.py`, `scripts/check_icloud_conflicts.sh`,
`zsh -ic 'python3 scripts/verify_sale_prices.py'`.

**The launch sale is live in App Store Connect**, scheduled not running: Lifetime Cohort 59.99
until 2026-09-15, 39.99 from 09-15 to 09-30, 59.99 from 09-30 with no end date. `LaunchSale.window`
in the shipped source matches, and the paywall will read "ends September 29".

### Correction to a claim made earlier in this session

The Engine's code **does** ship inside the app. There is no `OpenIntelligenceEngine.framework` in
the bundle and no `Frameworks/` directory; the Engine is linked into the app binary, which is why
`nm` finds its symbols there. The link failure above is only about resolving the Engine as a
standalone unit during the test action.


**Shipped:** iOS 5.1 and macOS 5.1, both `READY_FOR_SALE` on 2026-09-02, build 433. Nothing is in
review.

**5.2 records exist and carry their copy.** The owner created both version records on
2026-09-02 at 22:37 (macOS `b5d4f680-79de-4fd6-9221-dbe8b8393bdc`, iOS
`b724cdfc-444c-4c70-b5ba-fd0255443cf3`), `PREPARE_FOR_SUBMISSION`, release type `AFTER_APPROVAL`,
screenshots and the iPhone preview carried over from 5.1. `push_metadata version:5.2` ran for both
platforms at 22:42 and What's New, promotional text and the present-tense description read back
exact. **Release day is therefore: repoint toolchain, build, attach, submit.**

**5.2 is fully staged in this commit and cannot be built until Apple publishes the release Xcode
27.** The Xcode Cloud `Default` workflow is pinned by id to Xcode 26.6 (Swift 6.3). Every push to
`main` from now until release day fails in `ci_post_clone.sh` in seconds with "version 5.2
requires Swift 6.4"; that is intended. Xcode Cloud offers Xcode 27 beta 6 today
(`27A5252f`); betas cannot be submitted and the owner declined a TestFlight rehearsal.

**Release day is scripted.** `Docs/ai/RUNBOOK.md`, "Enabling Private Cloud Compute", "Release day,
in order": the records and copy are already done, so it is repoint, build, attach, submit. The scheduled routine
`openintelligence-51-pcc-flip` (renamed in description to the 5.2 release routine, daily at 09:00
from now) runs steps 1 to 4 the morning Xcode 27 appears and reports; the owner runs the two
submit commands because the permission classifier blocks `fastlane submit_latest` from an agent.
After approval the routine runs step 6, the claim flip.

**Notion.** v5.1: 5 rows `Completed`, `Shipped On: iOS, macOS`. v5.2 (option added 2026-09-02):
[Private Cloud Compute ships](https://app.notion.com/p/3cf49a74d54f8185ae8ddaf991244d0a) `To Do`,
and [How It Works told iOS 26 users the app asks before sending](https://app.notion.com/p/3d049a74d54f81439d82f10955226ba0)
`Completed` in code, `Shipped On` empty until 5.2 is live. Future Backlog 73.

## Completed this cycle

- **Learning set, docs only, by the "OpenIntelligence comprehensive documentation" session
  (2026-09-02, restored here after this file was rewritten over it).** `Docs/Engineering/FULL_SYSTEM_TRACE.md`
  is the execution trace with file:line and requested silicon per stage; `Docs/STUDY_GUIDE.md` is
  the course over the 612-term word bank; the five `PASS_*` files under `Docs/Audio/` are the spoken
  version, 76 minutes, with the word bank in `Audio/Reference_word_bank/` for lookup only. Two
  source documents live under `Docs/Research/`. One finding filed to Future Backlog as
  [The SpeechAnalyzer transcription branch never compiles](https://app.notion.com/p/3cf49a74d54f812c962cf52805ffdb34):
  `canImport` of a module that does not exist; `SFSpeechRecognizer` runs instead, so nothing is broken.
  `Docs/EdgeToEdge/` (2026-09-02) is the owner's complete explainer: all 612 word-bank concepts, seven-rung
  module ladders, three rungs per concept, symbols grepped and constants verified; the full paste is
  `EdgeToEdge/EDGE_TO_EDGE_FULL.md`. Thirteen corrections to the earlier documents are tabled in `00_START_HERE.md`.
- **Release guards are version-aware.** `ci_scripts/ci_post_xcodebuild.sh` Gate 1: below 5.2 fail
  on any `PrivateCloudCompute` symbol, from 5.2 fail on zero, always against a live
  `SystemLanguageModel` control. `ci_scripts/ci_post_clone.sh`: fail fast when the CHANGELOG
  version is 5.2+ and the runner's Swift is below 6.4. The `## 5.2` heading is the single switch.
- **`scripts/xcode_cloud_toolchain.rb`** lists Xcode Cloud's toolchains and repoints the workflow
  (`--set 'Xcode 27'`). API PATCH verified accepted 2026-09-02.
- **In-app copy flips on the compiler.** `DeviceCapabilities.pccRoutingCompiledIn` (RAGService)
  drives `supportsPrivateCloudCompute`, which now means "this build can route to PCC and the OS is
  27"; before, it meant "the OS has Apple Intelligence" and four screens misread it. The metrics
  bar footer, Settings PCC row and capability list, Glossary token/context/PCC/routing entries, and
  the three sample guides (`SamplePCCCopy`, seven interpolation points) all read it.
- **5.2 copy written:** `CHANGELOG.md` `## 5.2 <!-- unreleased -->` with four entries;
  `Docs/USER_CHANGELOG.md` `## v5.2 - unreleased` (byte-copied to
  `OpenIntelligence/Resources/VersionHistory.md`); `WHATS_NEW.md`; `WhatsNewStore` 5.2 sheet;
  `fastlane/metadata*/en-US/release_notes.txt` and `promotional_text.txt` (both platforms, same
  text); `description.txt` PCC sentence in present tense (per-version in ASC, so safe to push to
  the 5.2 records only).
- **5.1 cut:** `unreleased` marker off `## 5.1`; `Docs/RELEASE_NOTES.md` v5.1 section;
  `USER_CHANGELOG` dated; `SHIPPED_VERSION.json` 5.1 both, preparing 5.2.
- **Site patches held, not applied:** `Docs/Release/5.2/sites/{Fascinaiting,Gunzino,Gunnarguy-Portfolio}.patch`,
  each verified with `git apply --check` in its checkout. They flip every future-tense PCC sentence
  on the three sites; apply after 5.2 approval (routine step 6). Fascinaiting's roadmap re-synced
  today (236 rows, `shipped_on` exported, 5.1 lane now Shipped).

## Active Constraints

- **`fastlane/metadata*` now hold 5.2 copy.** Running `push_metadata version:5.1` would overwrite
  the live 5.1 listing with 5.2 text. Do not.
- **Do not repoint Xcode Cloud at a beta.** `xcode_cloud_toolchain.rb` warns; the owner declined
  the rehearsal.
- **Do not remove the `unreleased` marker from `## 5.2`** until 5.2 is live (router reads it).
- **Do not build a release on this Mac** (prerelease `BuildMachineOSBuild`, ITMS-90111).
- **The Gunnarguy-Portfolio checkout carries another session's uncommitted changes** (four
  `snapshot.html`, `Analytics.astro`). Stay out of it; apply the patch there only via the routine.
- **`fastlane/Fastfile` is unchanged**; the iOS metadata swap remains manual (RUNBOOK).

## Working Set

| File | Why it matters |
|---|---|
| `Docs/ai/RUNBOOK.md` "Enabling Private Cloud Compute" | The release-day list. Read it before doing anything on 5.2. |
| `scripts/xcode_cloud_toolchain.rb` | Step 1 and 2 of release day. |
| `ci_scripts/ci_post_clone.sh`, `ci_scripts/ci_post_xcodebuild.sh` | The guards; their messages name the fix when they fail. |
| `CHANGELOG.md` | `## 5.2 <!-- unreleased -->` first; the marker comes off when live. `next-version: 5.3`. |
| `Docs/Release/5.2/sites/*.patch` | The website flips, held. |
| `Docs/SHIPPED_CAPABILITIES.json` | `private_cloud_compute.status` flips to `shipping` at approval, not before. |
| `OpenIntelligence/Services/RAG/Orchestration/RAGService.swift` | `DeviceCapabilities.pccRoutingCompiledIn`. |
| `OpenIntelligence/Features/Documents/Library/SampleDocumentManager.swift` | `SamplePCCCopy`. |

## Verification

Run 2026-09-02 evening, output read, all against the staged 5.2 tree:

- `bash scripts/build_simulator_smoke.sh` → **Simulator smoke build succeeded**.
- `xcodebuild test`, iOS 27 simulator → **392 tests, 3 skipped, 0 failures**.
- `python3 scripts/verify_doc_claims.py` → all pass. `scripts/secret_scan.py` → clean.
  `scripts/verify_capabilities.py` → all anchors present. `bash scripts/test_enforce_docs_hook.sh`
  → 10 passed.
- Guard logic dry-run: `sort -V` compare marks 5.1 and 5.1.1 as PCC-forbidden, 5.2/5.10/6.0 as
  PCC-required; release Xcode reports Swift 6.3 (fails the 5.2 clone check), Xcode-beta reports
  6.4 (passes).
- `repoos_router.py preflight` → active release `v5.2`, in_development, last shipped `v5.1`.
- `git apply --check` of each site patch in its own checkout → applies cleanly.

**Not verified:** any PCC behaviour on a 5.2 binary, because none exists yet. The compiled-in
copy branches were parsed, built (the simulator build uses Xcode-beta, Swift 6.4, so
`pccRoutingCompiledIn` was `true` there and the suite passed with it) but not read on a device.

## Blockers / Unknowns

1. **Apple has not published the release Xcode 27.** Everything waits on it. The routine checks
   daily.
2. **Xcode Cloud will fail every push until release day.** Expected; the failure message says why.
   If a 5.1 hotfix is ever needed, see the RUNBOOK caveat.
3. **PCC context window.** Glossary and Settings no longer assert a number for PCC; the app reads
   it from the SDK at runtime. Nobody has recorded what iOS 27 reports. Read it from Settings on
   the first 5.2 device install.
4. **The 5.2 What's New says "Requires iOS, iPadOS or macOS 27"** for the PCC step; on 26 the
   same binary runs fully on device. True by construction (`#available(iOS 27)` inside the
   compiled-in paths); confirm on the first 5.2 build on an iOS 26 device if one is at hand.

## Exact Next Action

**One command, and it is the blocker.** Ask the owner to name `project.pbxproj`, then add the
`TransformersTokenizers` package product to the `OpenIntelligenceEngine` target so the suite can
link. Nothing else in this repository can be verified by test until that is done.

```bash
xcodebuild test -scheme OpenIntelligence -destination "platform=iOS Simulator,id=DA9536BA-F048-4352-92AA-66A7E1A464BA" -derivedDataPath /private/tmp/oi-build
```

That destination is an iPhone 17 Pro on iOS 26.5. No iOS 27 simulator runtime is installed, so
even a green suite does not exercise the `#if compiler(>=6.4)` paths. Installing Xcode 27 RC would
provide one.

**Not blocking, and available now:** build 444 is installable from TestFlight on this Mac, which
runs macOS 27.0 RC. Opening it and asking a question is the only way to device-verify the
reasoning-level change, and the cheapest observation is `Response.usage.reasoningTokenCount`,
which the app does not currently read. Worth running this at the same time to settle whether
Apple logs the route itself, which would make a planned logging change unnecessary:

```bash
log stream --style compact --predicate 'subsystem CONTAINS[c] "foundationmodel" OR subsystem CONTAINS[c] "privatecloud"'
```

