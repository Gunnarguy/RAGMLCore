#!/usr/bin/env python3
"""Re-read the Lifetime regular prices from App Store Connect and report drift.

    zsh -ic 'python3 scripts/verify_sale_prices.py'

WHY THIS EXISTS

`LaunchSale.regularLifetimePrices` is a table of pre-sale prices compiled into the app. The
paywall shows a struck-through "was" figure from it, so a stale entry is a false claim about
money. Two things can make it stale:

  1. Apple recalculates its generated per-territory prices when tax rates or exchange rates
     move. Nothing in the repo notices.
  2. A permanent price change that nobody mirrored back into the Swift table.

It also re-checks the assumption that makes keying by currency safe at all: that every
territory sharing a currency carries the same price. That held across all 177 generated
territories on 2026-09-09, but it is a property of this price schedule, not a promise from
Apple.

Run this before scheduling any sale. Exit code 0 means the table matches App Store Connect.

Reads APP_STORE_CONNECT_API_KEY_ID, _ISSUER_ID and _API_KEY_PATH from the environment, which
~/.zshrc exports, so run it through `zsh -ic`. See Docs/ai/RUNBOOK.md.
"""

import base64
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_TABLE = ROOT / "OpenIntelligence/Features/Billing/LaunchSale.swift"
LIFETIME_IAP = "6756638872"

# Territories whose currency we record. Restricted to the ones the Swift table covers; the
# API returns all 175 storefronts and we only need to prove these are internally consistent.
TERRITORY_CURRENCY = {
    "USA": "USD", "GBR": "GBP", "CAN": "CAD", "AUS": "AUD", "IND": "INR",
    "JPN": "JPY", "BRA": "BRL", "MEX": "MXN",
    "DEU": "EUR", "FRA": "EUR", "ITA": "EUR", "ESP": "EUR", "NLD": "EUR", "AUT": "EUR",
    "BEL": "EUR", "IRL": "EUR", "PRT": "EUR", "FIN": "EUR", "GRC": "EUR", "SVK": "EUR",
    "SVN": "EUR", "LTU": "EUR", "LVA": "EUR", "EST": "EUR", "LUX": "EUR", "CYP": "EUR",
    "MLT": "EUR", "HRV": "EUR",
}


def swift_table():
    """The currency -> price map as the app currently compiles it."""
    text = SWIFT_TABLE.read_text(encoding="utf-8")
    block = re.search(
        r"regularLifetimePrices:\s*\[String:\s*Decimal\]\s*=\s*\[(.*?)\]", text, re.S
    )
    if not block:
        sys.exit(f"could not find regularLifetimePrices in {SWIFT_TABLE}")
    return {
        m.group(1): float(m.group(2))
        for m in re.finditer(r'"([A-Z]{3})"\s*:\s*([0-9.]+)', block.group(1))
    }


def decode_territory(price_point_id):
    padded = price_point_id + "=" * (-len(price_point_id) % 4)
    try:
        return json.loads(base64.b64decode(padded).decode()).get("t")
    except Exception:
        return None


def live_prices(client):
    """currency -> set of prices Apple currently charges, across all territories."""
    by_currency = defaultdict(set)
    url = f"/v1/inAppPurchasePriceSchedules/{LIFETIME_IAP}/automaticPrices"
    params = {
        "include": "inAppPurchasePricePoint",
        "limit": 200,
        "fields[inAppPurchasePricePoints]": "customerPrice,proceeds,territory",
    }
    page = 0
    while url and page < 12:
        payload = client.get_json(url, params) if page == 0 else client.get_json(url)
        points = {
            item["id"]: item["attributes"]
            for item in payload.get("included", [])
            if item["type"] == "inAppPurchasePricePoints"
        }
        for row in payload.get("data", []):
            rel = (row.get("relationships", {}).get("inAppPurchasePricePoint") or {}).get("data")
            if not rel or rel["id"] not in points:
                continue
            territory = decode_territory(rel["id"])
            currency = TERRITORY_CURRENCY.get(territory) if territory else None
            if currency:
                by_currency[currency].add(float(points[rel["id"]]["customerPrice"]))
        nxt = (payload.get("links") or {}).get("next")
        if not nxt:
            break
        url = nxt.replace("https://api.appstoreconnect.apple.com", "")
        params = None
        page += 1

    # USA is set by hand, so it is a manual price rather than a generated one.
    manual = client.get_json(
        f"/v1/inAppPurchasePriceSchedules/{LIFETIME_IAP}/manualPrices",
        {
            "include": "inAppPurchasePricePoint",
            "limit": 200,
            "filter[territory]": "USA",
            "fields[inAppPurchasePricePoints]": "customerPrice",
        },
    )
    for item in manual.get("included", []):
        if item["type"] == "inAppPurchasePricePoints":
            by_currency["USD"].add(float(item["attributes"]["customerPrice"]))
    return by_currency


def main():
    asc = os.path.expanduser("~/ASC")
    if not os.path.isdir(asc):
        sys.exit(f"{asc} not found; that is where the App Store Connect client lives")
    sys.path.insert(0, asc)
    try:
        from asc.client import Client, load_config  # noqa: E402
    except ImportError as exc:
        sys.exit(f"could not import the ASC client from {asc}: {exc}")

    recorded = swift_table()
    live = live_prices(Client(load_config()))

    problems = []

    # 1. Does any currency carry more than one price? If so, keying by currency is unsound.
    for currency, prices in sorted(live.items()):
        if len(prices) > 1:
            listed = ", ".join(str(p) for p in sorted(prices))
            problems.append(
                f"{currency}: territories disagree ({listed}). Keying LaunchSale by currency "
                f"is no longer safe; key by territory or drop {currency} from the table."
            )

    # 2. Does the compiled table still match what Apple charges?
    print(f"{'currency':<10}{'in app':>12}{'App Store':>12}   status")
    for currency in sorted(set(recorded) | set(live)):
        in_app = recorded.get(currency)
        apple = sorted(live.get(currency, []))
        shown = apple[0] if len(apple) == 1 else (apple or ["-"])
        if in_app is None:
            status = "not in app (fine, no banner shown there)"
        elif not apple:
            status = "NOT FOUND in App Store Connect"
            problems.append(f"{currency}: recorded in the app but absent from App Store Connect")
        elif len(apple) == 1 and abs(in_app - apple[0]) < 0.005:
            status = "ok"
        else:
            status = "DRIFTED"
            problems.append(
                f"{currency}: app says {in_app}, App Store Connect says {shown}. "
                f"Update LaunchSale.regularLifetimePrices before running a sale."
            )
        print(f"{currency:<10}{str(in_app if in_app is not None else '-'):>12}{str(shown):>12}   {status}")

    print()
    if problems:
        print("DRIFT FOUND. The paywall would misstate a saving:\n")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print("Every recorded currency matches App Store Connect, and no currency has two prices.")
    print("Remember this proves the table is current, not that a sale is scheduled.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
