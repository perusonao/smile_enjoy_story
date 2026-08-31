// Issue #118 (PUBLIC-DEMO-NAV-1A): the Public Demo HOME used to render two
// month-advance controls at once — the canonical
// [PublicDemoMonthlyPrimaryCtaSection] (`Key('public-demo-monthly-primary-
// cta')`) plus a legacy per-month `OutlinedButton` (e.g. `'4月終了→5月'`)
// further down the same screen, both wired to the exact same
// `PublicDemoAggregate` month-close command. This suite pins the fix: at
// every month this screen can be in, and in the terminal (close-blocked)
// state, there is at most one month-advance control on screen, and the old
// dash-arrow label format never reappears.
//
// State is built by chaining the same real `PublicDemoAggregate` commands
// production uses (per that class's own test-fixture contract), then
// injected via a save-service fake — the same technique
// `public_demo_01_persistence_test.dart` and `public_demo_01_bankruptcy_ux_
// test.dart` already use to reach a specific month without re-driving every
// UI step.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

/// The single canonical month-advance CTA's key
/// ([PublicDemoMonthlyPrimaryCtaSection]'s own — never duplicated).
const _canonicalCtaKey = Key('public-demo-monthly-primary-cta');

/// The dash-arrow label format the removed legacy per-month buttons used
/// (e.g. `'4月終了→5月'`, `'3月終了→第1期終了'`). The canonical CTA never uses
/// `'→'` in its own labels (`'4月を終了して5月へ'`, `'...を終了して翌月へ'`,
/// `'3月を終了して第1期を完了'`), so any match here is a resurrected legacy
/// control, not a false positive against the canonical wording.
final _legacyArrowLabel = RegExp('終了→');

Future<void> _pump(WidgetTester tester, PublicDemoAggregate aggregate) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Asserts the screen currently exposes at most one month-advance CTA:
/// exactly the canonical key when [blocked] is false, and neither the
/// canonical CTA nor any legacy arrow-labelled control when it is true.
void _expectSingleOrNoMonthAdvanceCta(
  WidgetTester tester, {
  required bool blocked,
}) {
  expect(
    find.byKey(_canonicalCtaKey),
    blocked ? findsNothing : findsOneWidget,
    reason: blocked
        ? 'a close-blocked screen must expose no month-advance CTA at all'
        : 'exactly one canonical month-advance CTA must be on screen',
  );
  expect(
    find.byWidgetPredicate(
      (widget) => widget is Text && _legacyArrowLabel.hasMatch(widget.data ?? ''),
    ),
    findsNothing,
    reason: 'no legacy dash-arrow month-advance label may ever reappear',
  );
}

void main() {
  final expense = PublicDemoSalary.baselineMonthlyExpenses;

  testWidgets('April: exactly one month-advance CTA', (tester) async {
    await _pump(tester, PublicDemoAggregate.initial());
    _expectSingleOrNoMonthAdvanceCta(tester, blocked: false);
  });

  testWidgets('May: exactly one month-advance CTA', (tester) async {
    final aggregate = PublicDemoAggregate.initial().closeApril(
      monthlyExpenses: expense,
    );
    expect(aggregate.state.month, 5);
    await _pump(tester, aggregate);
    _expectSingleOrNoMonthAdvanceCta(tester, blocked: false);
  });

  testWidgets('June: exactly one month-advance CTA', (tester) async {
    final aggregate = PublicDemoAggregate.initial()
        .closeApril(monthlyExpenses: expense)
        .closeMay(week: 9, monthlyExpenses: expense);
    expect(aggregate.state.month, 6);
    await _pump(tester, aggregate);
    _expectSingleOrNoMonthAdvanceCta(tester, blocked: false);
  });

  testWidgets('July (before summer bonus decision): exactly one '
      'month-advance CTA', (tester) async {
    final aggregate = PublicDemoAggregate.initial()
        .closeApril(monthlyExpenses: expense)
        .closeMay(week: 9, monthlyExpenses: expense)
        .closeJune(assignedInJuly: 0, monthlyExpenses: expense);
    expect(aggregate.state.month, 7);
    await _pump(tester, aggregate);
    _expectSingleOrNoMonthAdvanceCta(tester, blocked: false);
  });

  testWidgets('July (summer bonus none confirmed): exactly one '
      'month-advance CTA, and tapping it closes into August exactly once', (
    tester,
  ) async {
    final aggregate = PublicDemoAggregate.initial()
        .closeApril(monthlyExpenses: expense)
        .closeMay(week: 9, monthlyExpenses: expense)
        .closeJune(assignedInJuly: 0, monthlyExpenses: expense)
        .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none);
    expect(aggregate.state.month, 7);
    expect(aggregate.state.summerBonusDecisionConfirmed, isTrue);
    await _pump(tester, aggregate);
    _expectSingleOrNoMonthAdvanceCta(tester, blocked: false);

    await tester.ensureVisible(find.byKey(_canonicalCtaKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_canonicalCtaKey));
    await tester.pumpAndSettle();

    final screenState =
        (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
                .s
            as PublicDemoState;
    expect(screenState.month, 8, reason: 'one tap must reach August, not skip or repeat');
    expect(screenState.summerBonusPaidAmount, 0, reason: 'none plan pays ¥0');
  });

  testWidgets('August (ordinary month): exactly one month-advance CTA', (
    tester,
  ) async {
    final aggregate = PublicDemoAggregate.initial()
        .closeApril(monthlyExpenses: expense)
        .closeMay(week: 9, monthlyExpenses: expense)
        .closeJune(assignedInJuly: 0, monthlyExpenses: expense)
        .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none)
        .closeJuly(monthlyExpenses: expense);
    expect(aggregate.state.month, 8);
    await _pump(tester, aggregate);
    _expectSingleOrNoMonthAdvanceCta(tester, blocked: false);
  });

  testWidgets('a close-blocked (terminal) screen exposes no month-advance '
      'CTA at all', (tester) async {
    // Driving August..March with the baseline expenses and zero revenue
    // reliably exhausts cash before month 15, reaching a terminal
    // (isCloseBlocked) financial status — a legitimate way to reach the
    // terminal case this suite must also cover.
    var aggregate = PublicDemoAggregate.initial()
        .closeApril(monthlyExpenses: expense)
        .closeMay(week: 9, monthlyExpenses: expense)
        .closeJune(assignedInJuly: 0, monthlyExpenses: expense)
        .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none)
        .closeJuly(monthlyExpenses: expense);
    while (!aggregate.state.isCloseBlocked && aggregate.state.month <= 15) {
      aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: expense);
    }
    expect(
      aggregate.state.isCloseBlocked,
      isTrue,
      reason: 'the driven trajectory must actually reach a terminal state',
    );
    await _pump(tester, aggregate);
    _expectSingleOrNoMonthAdvanceCta(tester, blocked: true);
  });
}
