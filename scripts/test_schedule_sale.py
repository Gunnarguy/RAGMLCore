#!/usr/bin/env python3
"""Tests for the parts of scripts/schedule_sale.py that do not need Apple.

    python3 scripts/test_schedule_sale.py

`window_literal` rewrites a Swift source file that states a deadline to customers, and
`check_live_schedule` is the guard standing between a stale constant and a permanent change to
the real price. Both are pure functions over data, so both are testable here.

The API paths are not covered. They need App Store Connect and a live product, and the design
answer to that is `--confirm` being required, the snapshot, and the post-write verification,
not a mock that would only prove the mock agrees with itself.
"""

import datetime as dt
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT = ROOT / "OpenIntelligence/Features/Billing/LaunchSale.swift"

spec = importlib.util.spec_from_file_location("schedule_sale", ROOT / "scripts/schedule_sale.py")
ss = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ss)


FIXTURE = """
    static let window: DateInterval? = {
        var calendar = Calendar(identifier: .gregorian)
        guard
            let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)),
            let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))
        else { return nil }
        return DateInterval(start: start, end: end)
    }()
"""


class WindowLiteral(unittest.TestCase):
    def test_rewrites_both_dates(self):
        out = ss.window_literal(FIXTURE, dt.date(2026, 10, 3), dt.date(2026, 10, 17))
        self.assertIn("year: 2026, month: 10, day: 3)", out)
        self.assertIn("year: 2026, month: 10, day: 17)", out)
        self.assertNotIn("day: 15", out)
        self.assertNotIn("day: 30", out)

    def test_changes_nothing_else(self):
        out = ss.window_literal(FIXTURE, dt.date(2027, 1, 2), dt.date(2027, 1, 20))
        before = [l for l in FIXTURE.splitlines() if "DateComponents" not in l]
        after = [l for l in out.splitlines() if "DateComponents" not in l]
        self.assertEqual(before, after)

    def test_single_digit_days_do_not_merge_into_the_group_reference(self):
        # \\g<3> followed by "1" must not be read as group 31.
        out = ss.window_literal(FIXTURE, dt.date(2026, 1, 1), dt.date(2026, 2, 2))
        self.assertIn("year: 2026, month: 1, day: 1)", out)
        self.assertIn("year: 2026, month: 2, day: 2)", out)

    def test_refuses_rather_than_writing_a_file_it_did_not_understand(self):
        with self.assertRaises(ValueError):
            ss.window_literal("static let window: DateInterval? = nil", dt.date(2026, 9, 1),
                              dt.date(2026, 9, 2))

    def test_is_idempotent(self):
        once = ss.window_literal(FIXTURE, dt.date(2026, 11, 5), dt.date(2026, 11, 19))
        twice = ss.window_literal(once, dt.date(2026, 11, 5), dt.date(2026, 11, 19))
        self.assertEqual(once, twice)

    def test_matches_the_real_swift_file(self):
        # The fixture above is only useful if it still resembles the file being edited.
        out = ss.window_literal(SWIFT.read_text(encoding="utf-8"),
                                dt.date(2026, 12, 1), dt.date(2026, 12, 15))
        self.assertIn("year: 2026, month: 12, day: 1)", out)
        self.assertIn("year: 2026, month: 12, day: 15)", out)


def row(price, territory="USA", start=None, end=None, pp="x"):
    return {"pricePointId": pp, "territory": territory, "customerPrice": price,
            "startDate": start, "endDate": end}


class LiveScheduleGuard(unittest.TestCase):
    """Every one of these would, unguarded, change the real price customers pay."""

    def test_accepts_the_shape_the_script_knows_how_to_replace(self):
        ss.check_live_schedule([row(59.99)], 59.99)   # must not raise

    def test_refuses_when_the_standing_price_is_not_what_the_constant_says(self):
        # The scenario: Lifetime was raised to 69.99 and REGULAR_PRICE was never updated.
        # Writing would silently drop the real price by ten dollars, permanently.
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(69.99)], 59.99)

    def test_refuses_when_a_manual_price_exists_in_another_territory(self):
        # The POST re-sends USA only, so a hand-set price elsewhere would be destroyed.
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(59.99), row(54.99, territory="CAN")], 59.99)

    def test_refuses_when_there_is_no_standing_price(self):
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(39.99, start="2026-09-14", end="2026-09-28")], 59.99)

    def test_refuses_when_there_are_two_standing_prices(self):
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(59.99), row(49.99)], 59.99)

    def test_refuses_when_the_standing_price_cannot_be_resolved(self):
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(None)], 59.99)

    def test_allows_replacing_a_sale_that_is_already_scheduled(self):
        # Re-running to change the dates is legitimate; the dated row is replaced, not added to.
        ss.check_live_schedule(
            [row(59.99), row(39.99, start="2026-09-14", end="2026-09-28")], 59.99)


class RequestBody(unittest.TestCase):
    def test_always_carries_a_standing_price(self):
        body = ss.body_for([
            {"id": "regular", "pricePointId": "a", "startDate": None, "endDate": None},
            {"id": "sale", "pricePointId": "b",
             "startDate": "2026-09-14", "endDate": "2026-09-28"},
        ])
        starts = [i["attributes"]["startDate"] for i in body["included"]]
        self.assertIn(None, starts, "Apple requires one price with a null startDate")
        self.assertEqual(len(body["data"]["relationships"]["manualPrices"]["data"]), 2)
        self.assertEqual(body["data"]["type"], "inAppPurchasePriceSchedules")

    def test_every_declared_row_is_included(self):
        body = ss.body_for([
            {"id": "regular", "pricePointId": "a", "startDate": None, "endDate": None},
            {"id": "sale", "pricePointId": "b", "startDate": "2026-09-14", "endDate": "2026-09-28"},
        ])
        declared = {r["id"] for r in body["data"]["relationships"]["manualPrices"]["data"]}
        self.assertEqual(declared, {i["id"] for i in body["included"]})


class LocalIds(unittest.TestCase):
    """Apple rejects a bare string with HTTP 409 ENTITY_ERROR.INCLUDED.INVALID_ID.

    Cost a real failed POST on 2026-09-09. The forum example this was built from wrote the ids
    as `$random_id`, which was shell placeholder syntax in their prose rather than the literal
    format Apple wants.
    """

    def test_ids_carry_the_dollar_brace_form(self):
        self.assertEqual(ss.local_id("regular"), "${regular}")

    def test_request_uses_local_ids_in_both_places(self):
        body = ss.body_for([
            {"id": "regular", "pricePointId": "a", "startDate": None, "endDate": None},
            {"id": "sale", "pricePointId": "b", "startDate": "2026-09-15", "endDate": "2026-09-30"},
        ])
        declared = [r["id"] for r in body["data"]["relationships"]["manualPrices"]["data"]]
        included = [i["id"] for i in body["included"]]
        self.assertEqual(declared, ["${regular}", "${sale}"])
        self.assertEqual(included, ["${regular}", "${sale}"])
        # Apple matches the two lists by this string, so they must agree exactly.
        self.assertEqual(declared, included)

    def test_restore_ids_are_local_too(self):
        body = ss.body_for([
            {"id": "restore0", "pricePointId": "a", "startDate": None, "endDate": None},
        ])
        self.assertEqual(body["included"][0]["id"], "${restore0}")


class Constants(unittest.TestCase):
    def test_window_cap_keeps_the_swift_suite_green(self):
        # LaunchSaleTests asserts the compiled window is under 90 days.
        self.assertLess(ss.MAX_WINDOW_DAYS, 90)

    def test_sale_price_is_below_the_regular_price(self):
        self.assertLess(ss.SALE_PRICE, ss.REGULAR_PRICE)

    def test_regular_price_matches_the_swift_table(self):
        # Same number, four homes. This pins two of them to each other.
        text = SWIFT.read_text(encoding="utf-8")
        self.assertIn(f'"USD": {ss.REGULAR_PRICE}', text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
