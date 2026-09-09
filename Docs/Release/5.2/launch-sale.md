# 5.2 launch sale — exact steps

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

## Step 1 — Check the price table has not drifted

```bash
zsh -ic 'python3 scripts/verify_sale_prices.py'
```

The paywall shows a struck-through "was" price from a table compiled into the app. Apple
recalculates its generated prices when tax and exchange rates move, so this confirms the table
still matches App Store Connect before you rely on it. It must print `ok` for every currency.
If it reports drift, update `LaunchSale.regularLifetimePrices` and rebuild before continuing.

## Step 2 — Schedule the price change

App Store Connect → the app → **Monetization → In-App Purchases → Lifetime Cohort → Pricing**.

1. **Schedule a price change**, and choose **Temporary price change**, not permanent.
2. Base country **United States**, price **$39.99**.
3. Start date: the day 5.2 goes live. End date: **10 to 14 days later**.
4. Glance at the generated prices for other territories. A third off the current figures lands
   near AUD 69.99, EUR 44.99, CAD 54.99, GBP 39.99.
5. Save.

The price reverts on its own at the end date. You cannot forget to put it back, and the maximum
length Apple allows is one year.

## Step 3 — Match the dates in the app

`OpenIntelligence/Features/Billing/LaunchSale.swift`, `LaunchSale.window`. It currently reads
**15 to 30 September 2026, Pacific**. Change both to whatever you set in step 2, then ship.

Getting this wrong is survivable. The banner also requires StoreKit's price to be below the
regular price before it says anything, so a wrong date produces a wrong deadline and never a
false discount. Keep the window slightly **narrower** than the real price change rather than
wider.

## Step 4 — Promotional text, once the sale is live

Promotional text is the 170-character field above the description. It can be changed at any time
**without a new build and without review**, which makes it the right place for a deadline.

```
Private Cloud Compute is on for iOS and macOS 27. Launch sale: Lifetime is a third off until September 29.
```

Edit `fastlane/metadata/en-US/promotional_text.txt`, then:

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 fastlane push_metadata version:5.2 platform:osx
```

Repeat with `platform:ios`. The UTF-8 locale is required; without it `deliver` dies on the
bullet characters in the release notes before it contacts Apple. Do not touch the release notes
themselves, which are about Private Cloud Compute and already approved.

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
