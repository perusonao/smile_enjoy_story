// Issue #12 P2 (Codex review on PR #13): MonthlyClosing.fromJson must keep
// `cashAfter - cashBefore == monthCashMovement` true for both current-format
// JSON and legacy saves that predate the `monthCashMovement` field.
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/game.dart';

Map<String, dynamic> _closingJson({
  int recruitmentCost = 0,
  int cashDelta = 0,
  int cashBefore = 1000000,
  int cashAfter = 1000000,
  int? monthCashMovement,
}) => {
  'month': 1,
  'week': 4,
  'label': '2026年 4月',
  'projectRevenue': 0,
  'accountsReceivableGenerated': 0,
  'cashCollected': 0,
  'salaryPaid': 0,
  'rentPaid': 0,
  'otherFixedCost': 0,
  'recruitmentCost': recruitmentCost,
  'accountingProfit': 0,
  'cashDelta': cashDelta,
  'cashBefore': cashBefore,
  'cashAfter': cashAfter,
  if (monthCashMovement != null) 'monthCashMovement': monthCashMovement,
};

void main() {
  group('MonthlyClosing.fromJson', () {
    test('current-format JSON (monthCashMovement present) round-trips cashBefore as-is', () {
      final closing = MonthlyClosing.fromJson(_closingJson(
        cashDelta: -50000,
        recruitmentCost: 30000,
        cashBefore: 900000,
        cashAfter: 920000,
        monthCashMovement: 20000,
      ));
      expect(closing.monthCashMovement, 20000);
      expect(closing.cashBefore, 900000);
      expect(closing.cashAfter, 920000);
      expect(closing.cashAfter - closing.cashBefore, closing.monthCashMovement);
    });

    test('legacy JSON (no monthCashMovement, no recruitment cost) migrates cleanly: cashBefore was already correct', () {
      // Pre-Issue-#12 closings with no recruitment spend that month have no
      // discrepancy to correct — cashBefore was already the true month-start
      // balance.
      final closing = MonthlyClosing.fromJson(_closingJson(
        cashDelta: -50000,
        recruitmentCost: 0,
        cashBefore: 950000,
        cashAfter: 900000,
      ));
      expect(closing.monthCashMovement, -50000);
      expect(closing.cashBefore, 950000);
      expect(closing.cashAfter - closing.cashBefore, closing.monthCashMovement);
    });

    test('legacy JSON with recruitment spend: cashBefore is reconstructed from cashAfter - monthCashMovement, not trusted as stored', () {
      // A pre-Issue-#12 closing for a month with paid recruitment media: the
      // stored `cashBefore` is the *pre-settlement* balance (recruitment
      // spend already deducted), which would break the invariant if trusted
      // as-is — Codex's exact finding on PR #13.
      final legacyCashBeforeSettlement = 870000; // already net of mediaCost
      final closing = MonthlyClosing.fromJson(_closingJson(
        cashDelta: -50000, // settlement-only: salary+rent+fixedCost vs cashCollected
        recruitmentCost: 30000,
        cashBefore: legacyCashBeforeSettlement,
        cashAfter: 820000, // cashBefore(870000) + cashDelta(-50000)
      ));
      // Reconstructed monthCashMovement: cashDelta - recruitmentCost.
      expect(closing.monthCashMovement, -80000);
      // cashBefore must be re-derived (900000 = cashAfter - monthCashMovement),
      // NOT the legacy stored 870000 — otherwise cashAfter - cashBefore
      // would be -50000, disagreeing with monthCashMovement's -80000.
      expect(closing.cashBefore, 900000);
      expect(closing.cashAfter - closing.cashBefore, closing.monthCashMovement);
    });

    test('toJson -> fromJson round-trip is exact for a closing built with the current fields', () {
      const original = MonthlyClosing(
        month: 3,
        week: 12,
        label: '2026年 6月',
        projectRevenue: 800000,
        accountsReceivableGenerated: 800000,
        cashCollected: 400000,
        salaryPaid: 680000,
        rentPaid: 100000,
        otherFixedCost: 100000,
        recruitmentCost: 50000,
        accountingProfit: -130000,
        cashDelta: -480000,
        monthCashMovement: -530000,
        cashBefore: 2000000,
        cashAfter: 1470000,
      );
      final roundTripped = MonthlyClosing.fromJson(original.toJson());
      expect(roundTripped.monthCashMovement, original.monthCashMovement);
      expect(roundTripped.cashBefore, original.cashBefore);
      expect(roundTripped.cashAfter, original.cashAfter);
      expect(roundTripped.cashAfter - roundTripped.cashBefore, roundTripped.monthCashMovement);
    });
  });
}
