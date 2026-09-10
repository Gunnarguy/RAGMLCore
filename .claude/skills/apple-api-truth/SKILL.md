---
name: apple-api-truth
description: Answer any question about an Apple framework, API, type, availability, or SDK capability from the SDK on this machine and Apple's live documentation, never from memory. Use before writing code against FoundationModels, CoreML, Vision, VisionKit, AppIntents, StoreKit or any Apple framework; before claiming an API does or does not exist; before saying a capability is unavailable; and whenever the user pastes a developer.apple.com URL, which means the previous answer was guessed. Also use when a claim needs an evidence tag naming an Apple source.
---

# Apple API truth

Every model's training data predates the current SDK. In this repository that has produced
confidently wrong answers about Apple APIs repeatedly, and the user has had to correct them by
pasting documentation URLs. **A pasted developer.apple.com link is a bug report about the previous
answer.** This skill exists so the answer is looked up first.

The rule is in the global `CLAUDE.md` and it is absolute: versions, pricing, availability and
parameter names are never answered from memory.

## The two ground truths, in order of authority

1. **The SDK on disk.** It is what the compiler will actually accept. It cannot be out of date
   relative to the installed Xcode, and it cannot be marketing.
2. **Apple's documentation.** It explains intent, gives capability tables and states requirements
   the headers do not carry, such as entitlements and eligibility.

When they disagree, the SDK wins on what exists and the docs win on what it means.

## Reading the SDK, which is faster than the web

```bash
xcode-select -p                                    # which toolchain is active RIGHT NOW
ls -d /Applications/Xcode*.app                     # what else is installed
```

`xcode-select` has pointed at different Xcodes on different days here. Check it; do not assume.

Platform SDK roots:

```text
<Xcode>/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
<Xcode>/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
```

**Swift frameworks** publish a complete public interface. This is the single highest-value file
for any Swift API question, and it carries exact availability annotations:

```bash
SDK=/Applications/Xcode-beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
SI="$SDK/System/Library/Frameworks/FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64e-apple-ios.swiftinterface"

grep -oE "(class|struct|enum|protocol|actor) [A-Za-z_][A-Za-z0-9_]*" "$SI" | sort -u   # every type
sed -n '/public struct ContextOptions/,/^}/p' "$SI"                                     # one type in full
grep -n -B3 "public struct ContextOptions" "$SI"                                        # its @available line
```

The `@available` line immediately above a declaration is the answer to "can I use this", compared
against the deployment target. Read it every time.

**Objective-C frameworks** publish headers instead:

```bash
grep -rh "@interface\|@property\|^- (\|^+ (" "$SDK/System/Library/Frameworks/CoreML.framework/Headers/"*.h
```

**Does any framework offer this at all?** Sweep every public Swift interface at once. This is how
"no public framework exposes a model tier" was established as fact rather than opinion:

```bash
find "$SDK/System/Library/Frameworks" -name "*.swiftinterface" | while read -r f; do
  n=$(grep -c "YourSymbol" "$f" 2>/dev/null)
  [ "$n" -gt 0 ] && echo "$n  $(echo "$f" | sed 's|.*/Frameworks/||;s|/Modules.*||')"
done | sort -rn
```

Zero hits across every framework is strong evidence something is not public API.

## Reading Apple's documentation as data

`WebFetch` on developer.apple.com usually returns only the page title, because the site renders
client-side. **Use the JSON behind it**, which is the same content the page uses:

```text
https://developer.apple.com/tutorials/data/documentation/<path>.json
```

The `<path>` is whatever follows `/documentation/` in the normal URL.

```bash
curl -s "https://developer.apple.com/tutorials/data/documentation/foundationmodels/privatecloudcomputelanguagemodel.json" \
 | python3 -c "
import json,sys
d=json.load(sys.stdin)
def texts(o,acc):
    if isinstance(o,dict):
        for k,v in o.items():
            if k=='text' and isinstance(v,str): acc.append(v)
            elif k=='code' and isinstance(v,list): acc.append(chr(10).join(v))
            else: texts(v,acc)
    elif isinstance(o,list):
        for i in o: texts(i,acc)
acc=[]; texts(d.get('abstract'),acc); texts(d.get('primaryContentSections'),acc)
print(' '.join(acc)[:3000])
"
```

Nested types live at their own paths, suffixed `-data.dictionary`, and the parent's `references`
block lists them:

```bash
curl -s ".../inapppurchasepriceschedulecreaterequest.json" \
 | python3 -c "import json,sys; [print(k) for k in json.load(sys.stdin).get('references',{})]"
```

Other reliable sources:

- `https://developer.apple.com/news/releases/` for exact build numbers and release dates.
- `https://developer.apple.com/news/rss/news.rss` parses cleanly when the HTML page does not.
- `https://developer.apple.com/documentation/updates/<framework>` for "what changed this year",
  which is the fastest way to find capability the app is not using.

## When an API is Apple's own app doing it, not you

Apple's first-party apps use private frameworks. Seeing a capability in Siri, Shortcuts or Settings
proves nothing about what a third-party app can call. Settle it by sweeping every public
`.swiftinterface` for the symbol, and separately by searching the running system:

```bash
CACHE=/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e
strings -a "$CACHE" | grep -cF "Some UI String"
```

System framework binaries live in the shared cache, not on disk as separate files, so `grep` over
`/System/Library/PrivateFrameworks` finds nothing and proves nothing.

## Facts already established here, with their evidence

Re-verify anything below when the toolchain changes; the date is the point.

| Fact | Verified |
|---|---|
| `FoundationModels` is the only public framework naming a language model. 92 references there, zero in every other framework interface. | 2026-09-10, iOS 27 SDK, Xcode 27A5194q |
| One server model class exists, `PrivateCloudComputeLanguageModel`. No "Cloud Pro", no tier or variant type in any public framework. Apple's Shortcuts picker shows tiers it does not expose. | 2026-09-10 |
| `ContextOptions` is `@available(iOS 27.0, macOS 27.0, ...)`, with `ReasoningLevel` cases `.light`, `.moderate`, `.deep`, `.custom(String)`. It is a **defaulted** argument on every `respond` and `streamResponse` overload, so omitting it silently runs at Apple's default effort. | 2026-09-10 |
| The guided-generation overloads default `includeSchemaInPrompt` to `true`; the plain ones leave it `nil`. Supplying any `ContextOptions` replaces that default wholesale. | 2026-09-10 |
| Reasoning is "not supported" on-device and "multiple levels" on PCC; context 4K vs 32K. PCC is unlimited-free on-device vs a daily limit, upgradable with iCloud+. | Apple capability table, `adding-server-side-intelligence-with-private-cloud-compute`, 2026-09-10 |
| `LanguageModelSession.Response` carries `content`, `rawContent`, `transcriptEntries`, `usage`. **Nothing names the backend.** An app cannot ask Apple which model answered. | 2026-09-10 |
| `Response.usage` is new in iOS 27 and carries `reasoningTokenCount`. Non-zero is the cheapest proof reasoning ran. | 2026-09-10 |
| `MLComputePlan` (iOS 17+) exposes `computeDeviceUsage(for:)` giving `preferred` and `supported` devices per layer, plus `cost(of:)`. Types: `MLCPUComputeDevice`, `MLGPUComputeDevice`, `MLNeuralEngineComputeDevice`. | 2026-09-10, CoreML headers |
| No public API reports live per-unit ANE/GPU/CPU utilization. That needs `powermetrics` with root on macOS, or private API. | 2026-09-10 |
| Apple replaced the on-device model in iOS 27 and tells developers to re-test prompts. | `updates/foundationmodels`, 2026-09-10 |
| iOS 27 also added: the `LanguageModel` protocol for plugging in any model, images in prompts, `toolCallingMode`, dynamic profiles, and an updated Foundation Models Instruments template. | 2026-09-10 |
| Apple Intelligence needs iPhone 15 Pro or later, iPad with M1 or A17 Pro or later, Apple silicon Mac. iPad Air 4 (A14) is excluded. | support.apple.com/121115, 2026-09-10 |

## Evidence tags

This repository requires `[evidence_level: ..., confidence: ...]` on durable claims. For Apple
facts:

- `code_verified` when read from a `.swiftinterface` or header on disk. Name the Xcode build.
- `documented` when read from developer.apple.com. Give the URL and the fetch date.
- `measured` when observed from a real API response or a built binary.
- `inferred` for anything reasoned rather than read. A forum thread is `inferred`, never
  `code_verified`, and that distinction has already cost a failed live API write here.

Always record the SDK build, because "the iOS 27 SDK" means something different in beta 1 than in
the RC.

## Two failures this skill exists to prevent

**2026-09-09.** A request body was built from an Apple developer forum thread because Apple's own
reference documents field names but not request semantics. The thread wrote ids as `$random_id`,
shell placeholder syntax, and the literal requirement was `${local-id}`. Two live API writes failed
before the format was read from the error message instead of guessed. Where Apple documents names
but not behaviour, say so in the evidence tag rather than borrowing someone's example.

**2026-09-10.** The claim "there is no Cloud Pro for third-party apps" was correct but was first
asserted before it was checked, and only survived because the user pushed back and the SDK sweep
was then actually run. Run the sweep first. It takes seconds.
