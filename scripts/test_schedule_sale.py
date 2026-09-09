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
    """Every one of these would, unguarded, change the real price customers pay.

    The schedule is a partition of the timeline, so the row that matters for "what is the
    regular price" is the open-ended one, the interval with no end date. That is what customers
    pay once every scheduled change has expired.
    """

    def test_accepts_a_plain_schedule_with_one_open_ended_interval(self):
        ss.check_live_schedule([row(59.99)], 59.99)   # must not raise

    def test_refuses_when_the_price_it_reverts_to_is_not_what_the_constant_says(self):
        # The scenario: Lifetime was raised to 69.99 and REGULAR_PRICE was never updated.
        # Writing would silently drop the real price by ten dollars, permanently.
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(69.99)], 59.99)

    def test_refuses_when_a_manual_price_exists_in_another_territory(self):
        # The POST re-sends USA only, so a hand-set price elsewhere would be destroyed.
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(59.99), row(54.99, territory="CAN")], 59.99)

    def test_refuses_when_no_interval_runs_forever(self):
        # Apple requires the rightmost interval to be open-ended, so a schedule without one
        # means we are reading something we do not understand.
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(39.99, start="2026-09-15", end="2026-09-30")], 59.99)

    def test_refuses_when_two_intervals_run_forever(self):
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(59.99), row(49.99)], 59.99)

    def test_refuses_when_the_open_ended_interval_cannot_be_resolved(self):
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([row(None)], 59.99)

    def test_allows_replacing_a_sale_that_is_already_scheduled(self):
        # Re-running to change the dates is legitimate. This is the three-interval shape the
        # script itself writes, read back.
        ss.check_live_schedule([
            row(59.99, end="2026-09-15"),
            row(39.99, start="2026-09-15", end="2026-09-30"),
            row(59.99, start="2026-09-30"),
        ], 59.99)

    def test_refuses_when_a_scheduled_sale_would_revert_to_the_wrong_price(self):
        # The dangerous variant of the above: the tail interval is not the regular price, so
        # re-sending 59.99 there would be a change rather than a preservation.
        with self.assertRaises(SystemExit):
            ss.check_live_schedule([
                row(59.99, end="2026-09-15"),
                row(39.99, start="2026-09-15", end="2026-09-30"),
                row(49.99, start="2026-09-30"),
            ], 59.99)


class RequestBody(unittest.TestCase):
    """Apple rejects anything that is not a clean partition of the timeline.

    Measured 2026-09-09: a two-row body of [null -> null] plus [start -> end] drew both
    ENTITY_ERROR.INVALID_INTERVAL ("Adjacent intervals must not intersect") and
    ENTITY_ERROR.INVALID_END_DATE ("Rightmost interval must not have an end date").
    """

    SALE = [
        {"id": "before", "pricePointId": "REG", "startDate": None, "endDate": "2026-09-15"},
        {"id": "sale", "pricePointId": "SALE",
         "startDate": "2026-09-15", "endDate": "2026-09-30"},
        {"id": "after", "pricePointId": "REG", "startDate": "2026-09-30", "endDate": None},
    ]

    def intervals(self):
        body = ss.body_for(self.SALE)
        return [(i["attributes"]["startDate"], i["attributes"]["endDate"])
                for i in body["included"]]

    def test_covers_the_timeline_with_no_gap(self):
        iv = self.intervals()
        self.assertIsNone(iv[0][0], "the first interval must be open at the start of time")
        for (_, prev_end), (next_start, _) in zip(iv, iv[1:]):
            self.assertEqual(prev_end, next_start, "a gap between intervals is rejected")

    def test_the_last_interval_never_ends(self):
        self.assertIsNone(self.intervals()[-1][1])

    def test_no_interval_overlaps_another(self):
        iv = self.intervals()
        for (_, prev_end), (next_start, _) in zip(iv, iv[1:]):
            self.assertLessEqual(prev_end, next_start)

    def test_the_regular_price_holds_both_ends(self):
        body = ss.body_for(self.SALE)
        pp = [i["relationships"]["inAppPurchasePricePoint"]["data"]["id"] for i in body["included"]]
        self.assertEqual(pp[0], pp[-1], "before and after the sale must be the same price")
        self.assertNotEqual(pp[0], pp[1], "the middle interval is the sale price")

    def test_every_declared_row_is_included(self):
        body = ss.body_for(self.SALE)
        declared = {r["id"] for r in body["data"]["relationships"]["manualPrices"]["data"]}
        self.assertEqual(declared, {i["id"] for i in body["included"]})
        self.assertEqual(body["data"]["type"], "inAppPurchasePriceSchedules")


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
