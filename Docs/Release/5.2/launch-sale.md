# 5.2 launch sale: exact steps

Written 2026-09-09. The app side is built, tested and merged. This file is the part that happens
in App Store Connect, in order, on the day.

The sale is deliberately **not** required for 5.2 to ship. If any of it slips, 5.2 releases at
full price and nothing in the binary claims otherwise.

---

## The price

**Lifetime Cohort only.** Set the **USA** price; Apple generates the other 174 storefronts.

| Product | Regular (USA) | Sale (USA) | Off |
|---|---|---|---|
| Lifetime Cohort | $59.99 | **$39.99** | 33% |
| Pro Annual | $29.99 | unchanged | none |
| Pro Monthly | $5.99 | unchanged | none |

$39.99 is confirmed to exist as an App Store price point. Do not round to $40.00: crossing the
leading digit downward is the whole point, and the left-digit effect only fires when the
leftmost digit changes.

### Why the subscriptions are left alone

Two independent reasons, both verified against Apple's documentation on 2026-09-09.

- **Pro Annual has already spent its introductory offer.** The 7-day free trial is one, and a
  customer may redeem only one introductory offer per subscription group. A discount offer would
  displace the trial rather than add to it.
- **A subscription price cut creates a price increase later.** When the price reverts, everyone
  who subscribed at the sale price faces an increase at renewal. Apple requires consent in
  several cases, and a subscriber who does not consent has their subscription **expire** at the
  end of the current cycle. Paying for that a year from now to discount 5% of revenue is a bad
  trade.

Lifetime is a non-consumable. It reverts with no consequence to anyone who already bought, and
it is 83% of revenue.

---

## Step 1. Check the price table has not drifted

```bash
zsh -ic 'python3 scripts/verify_sale_prices.py'
```

The paywall shows a struck-through "was" price from a table compiled into the app. Apple
recalculates its generated prices when tax and exchange rates move, so this confirms the table
still matches App Store Connect before you rely on it. It must print `ok` for every currency.
If it reports drift, update `LaunchSale.regularLifetimePrices` and rebuild before continuing.
`schedule_sale.py` does not check this for you; it is a separate question from whether the
sale is scheduled correctly.

## Step 2. Schedule the price change, and match the app to it

One command does both halves: the temporary price change in App Store Connect, and the
`LaunchSale.window` the app compiles in. Doing them together is the point. Setting one and
mistyping the other is the only way this breaks.

**The window half has to happen before the 5.2 build.** It is compiled into the binary. Running
this at release day and expecting the shipped app to notice is the mistake this paragraph exists
to prevent, so `Docs/ai/RUNBOOK.md` sets the window at step 2b, before Build, and schedules the
price at 5b. To write the Swift dates and no pricing, leave `--confirm` off:

```bash
zsh -ic 'python3 scripts/schedule_sale.py --start YYYY-MM-DD --end YYYY-MM-DD --write-window'
```

The end date is the half that must be exact, because the paywall prints it as a deadline. The
start may sit a few days early: the banner also requires the live price to be below the regular
price, so it stays silent until the price change really begins, and that slack absorbs a slow
review.

Look first. This changes no pricing:

```bash
zsh -ic 'python3 scripts/schedule_sale.py --start YYYY-MM-DD --end YYYY-MM-DD'
```

Every mode reads from App Store Connect, including this one, so it needs credentials and will
fail without them. It prints the live schedule it found, the resolved price points, your proceeds
at each, what customers in nine territories would see, and the exact JSON it would send.

It also refuses outright, before offering to write anything, if the live standing price is not
the $59.99 this repo is built around, or if a hand-set price exists in a territory other than the
USA. Both would mean the submission silently changes or deletes a real price, because the POST
replaces the schedule rather than adding to it. Then run it for real:

```bash
zsh -ic 'python3 scripts/schedule_sale.py --start YYYY-MM-DD --end YYYY-MM-DD --confirm --write-window'
```

`--write-window` edits `LaunchSale.swift` to the same dates. Commit that and ship the build.

Before either write it saves the current schedule to `.sale-snapshots/`, which is tracked in git
on purpose, and prints the command that puts it back:

```bash
zsh -ic 'python3 scripts/schedule_sale.py --restore .sale-snapshots/<file>.json --confirm'
```

### Why the script and not the API by hand

A price schedule is replaced wholesale. There is no "add a price change" call. The POST submits
the entire schedule and at least one price in it must carry `startDate: null`, which is the
standing price. So the request has to contain **two** rows:

| Price | startDate | endDate | Role |
|---|---|---|---|
| $59.99 | null | null | the standing price, and what it reverts to |
| $39.99 | sale start | sale end | the sale |

Leave the first row out and the regular price is not preserved, it is removed. That is the whole
reason this is a script with a snapshot rather than a curl one-liner.

### The discount is not 33% everywhere

Apple rounds each territory to its own price point, so a single US price change lands differently
around the world. Measured from the equalizations Apple returns for the $39.99 US price point on
2026-09-09:

| Territory | Regular | Sale | Off |
|---|---|---|---|
| USA | $59.99 | $39.99 | 33% |
| United Kingdom | £59.99 | £39.99 | 33% |
| Germany | €69.99 | €44.99 | 35% |
| Canada | CA$79.99 | CA$49.99 | 37% |
| Australia | A$99.99 | A$59.99 | 40% |
| Japan | ¥10000 | ¥6000 | 40% |
| India | ₹5900 | ₹3999 | 32% |
| Brazil | R$399.90 | R$249.90 | 37% |
| Mexico | MX$1299 | MX$899 | 30% |

The paywall computes each customer's percentage from their own two prices, so an Australian is
told 40% and an American is told 33%. Neither is shown the other's number. Marketing copy that
has to be true everywhere should say "a third off", which is the floor across these nine.

## Step 3. The App Store Connect UI, if you would rather click

Monetization → In-App Purchases → Lifetime Cohort → Pricing → **Schedule a price change** →
**Temporary price change**. Base country United States, price **$39.99**, your start and end
dates. Save.

If you do it this way, `LaunchSale.window` still has to be set by hand to the same dates, or
run the script afterwards with `--write-window` and no `--confirm`.

## Step 4. Promotional text, once the sale is live

Promotional text is the 170-character field above the description. It can be changed at any time
**without a new build and without review**, which makes it the right place for a deadline.

```
Private Cloud Compute is on for iOS and macOS 27. Launch sale: Lifetime is a third off until September 29.
```

Change the date to your real end date, and say "a third off" rather than a percentage: 33% is
the US figure and an Australian customer is getting 40%, so a percentage is only true in some
storefronts.

**The two platforms do not share this file, and the lane does not switch on `platform:`.**
`push_metadata` always reads `fastlane/metadata/`, whichever platform you pass, so
"repeat with `platform:ios`" would push the macOS text to iOS. Edit both copies, push macOS,
then swap the iOS copy in:

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 fastlane push_metadata version:5.2 platform:osx
```

```bash
M=fastlane/metadata/en-US
cp "$M/promotional_text.txt" /tmp/mac_pt.bak
trap 'cp /tmp/mac_pt.bak "$M/promotional_text.txt"' EXIT
cp fastlane/metadata-ios/en-US/promotional_text.txt "$M/promotional_text.txt"
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 fastlane push_metadata version:5.2 platform:ios
```

The `trap` matters: a failure mid-run must not leave the canonical macOS copy holding iOS text.
The full version of this, including release notes, is in `Docs/ai/RUNBOOK.md`.

The UTF-8 locale is required; without it `deliver` dies on the bullet characters in the release
notes before it contacts Apple. Do not touch the release notes themselves, which are about
Private Cloud Compute and already approved.

---

## When the sale ends

Apple reverts the price and the banner disappears on its own, twice over: the window closes and
the price is no longer below regular. Two things do not revert themselves.

1. **Promotional text.** Put the original back.
2. **Any sale copy you added to the three websites.**

`LaunchSale.window` needs no action. Dates in the past are what turns it off.

---

## Afterwards: offer codes, not another price cut

Offer codes now cover non-consumables, so the same discount can go to a named group without
touching the list price, and every redemption is attributable. That is the right tool for the
roughly 270 people who downloaded and did not buy.

Limits: 10 active offers per app, 1,000,000 codes per app per quarter, one-time-use batches of
500 to 25,000, 6-month maximum expiry, one redemption per customer per offer. Promo codes for
in-app purchases were retired on 2026-03-26.

Run it a week or two **after** the public sale ends so the two never overlap.

---

## What the numbers say to expect

Measured over the ten Lifetime sales to date: blended net is **66.4%** of list, not the 85% US
rate, because several storefronts quote VAT-inclusive prices. Conversion from first-time
download to Lifetime is **3.5%** (10 of 285).

| Price | Net per unit | Units needed to match full-price revenue |
|---|---|---|
| $59.99 | $39.56 | 1.00× |
| $39.99 | $26.55 | 1.49× |

The sale pays for itself at roughly **1.5× the Lifetime units** it would otherwise have sold. On
a launch-traffic spike that is a reasonable bet; on flat traffic it is not, which is why it is
tied to the iOS 27 window and time-boxed.

The larger lever remains traffic, not price. At 3.5% and full price a download is worth $1.39 in
Lifetime revenue alone, so 500 launch downloads at full price would exceed the app's entire
revenue to date with no discount at all.
