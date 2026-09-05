// Issue #168 Finding B (Codex P2, PR #177): the lock banner's month-agnostic
// "reaching the threshold reopens sales from around that point on" line
// (added by Finding B) is false at the fiscal-year boundary. `_buildEmployeesTab`
// only ever re-renders the waiting/skillSheet sales-flow card
// (`ec(...)`, RECOVERY-LOOP-1) through internal month 14 (February,
// `PublicDemoRecoveryEligibility.lastEligibleMonth`) — training selected in
// February applies its growth at month-end, entering March (15), which no
// later `ec(...)` render ever covers, and this fix deliberately does not
// extend the sales window into March (no balance/domain/save change, no
// widened Finding B scope).
//
// This test drives Suzuki (eng-02, capability 52) to exactly 59 by October,
// leaves her untrained through November-January so she is still 59 entering
// February, and proves:
//  - the lock banner, shown in February, states the truthful "no more
//    chances this fiscal year" fact instead of Finding B's forward-looking
//    promise, which would be false here;
//  - training in February (her 8th selection) still raises her to exactly
//    60 at month-end, same as every other month (growth rate untouched);
//  - March genuinely offers no route back — no lock banner, no
//    SkillSheet確認 — confirming the corrected copy is honest about the
//    boundary rather than the sales window having been silently extended.
//
// Hiring Takahashi (app-01) in May, mirroring
// public_demo_01_success_playthrough_test.dart's own May block, is not
// Finding B behavior — it exists purely so this playthrough carries enough
// Revenue to stay solvent through February's own training charge. A
// single-founding-engineer playthrough (public_demo_01_assignment_
// carryforward_test.dart's own contract) has essentially zero cash margin
// left entering February even with no extra spending at all — this test's
// own probe confirmed baseline cash is exactly ¥0 entering February — so
// the 7 extra ¥30,000 training charges this scenario needs before February
// would otherwise trip `isFinanciallyRestricted` a month early and block
// the very training this test exists to prove is not month-blocked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

const _suzukiId = 'eng-02';
const _trainingActionKey = Key(
  'public-demo-internal-training-action-$_suzukiId',
);
const _lockKey = Key('public-demo-field-sales-lock-$_suzukiId');
const _forwardLookingLine = '実力が基準に達すれば、その月以降に営業を再開できます。';
const _lastChanceLine = '実力が基準に達しても、今年度中の営業再開はもう見込めません。';

PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

Future<void> _settleAfterPossiblePrecache(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Taps the first match — this suite's own resume/offer/order flows can
/// briefly have more than one candidate action with identical text on
/// screen at once (e.g. two pre-seeded May applicants both showing
/// `経歴書確認`), exactly like `public_demo_01_success_playthrough_test.dart`'s
/// own `tapAndSettle`.
Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView);
  for (var i = 0; finder.evaluate().isNotEmpty && i < 10; i++) {
    final rect = tester.getRect(finder.first);
    if (rect.top >= 0 && rect.bottom <= tester.view.physicalSize.height) {
      break;
    }
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await _settleAfterPossiblePrecache(tester);
}

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  await tapFinder(tester, actionButton(text));
  if (text == 'SkillSheet確認') {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
}

Future<void> dismissDialog(WidgetTester tester, String confirmLabel) async {
  final confirm = find.widgetWithText(FilledButton, confirmLabel);
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }
}

/// Closes the current month via [closeLabel] (no training this month),
/// proceeding past any real Month Guard warning exactly like every other
/// Public Demo suite that is not itself testing that warning.
Future<void> _closeMonth(WidgetTester tester, String closeLabel) async {
  await switchPublicDemoTab(tester, PublicDemoTab.home);
  await tapAndSettle(tester, closeLabel);
  await dismissMonthGuardIfPresent(tester);
}

/// Trains Suzuki this month, then closes via [closeLabel].
Future<void> _trainSuzukiAndCloseMonth(
  WidgetTester tester,
  String closeLabel,
) async {
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
  await tapFinder(tester, find.byKey(_trainingActionKey));
  await _closeMonth(tester, closeLabel);
}

/// Decides and accepts every still-undecided July continuation on 営業 —
/// both Sato's and Takahashi's assignments are undecided simultaneously
/// entering June, so the generic `決定→受注` pair is repeated once per
/// assignment rather than assuming a single (ambiguous) `7月分の発注を確認`
/// match.
Future<void> _acceptAllJulyContinuations(WidgetTester tester) async {
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
  while (actionButton('7月分の発注を確認').evaluate().isNotEmpty) {
    final decide = actionButton('7月分の発注を確認');
    await tester.ensureVisible(decide.first);
    await tester.pumpAndSettle();
    await tester.tap(decide.first);
    await _settleAfterPossiblePrecache(tester);
    final accept = actionButton('受注する');
    await tester.ensureVisible(accept.first);
    await tester.pumpAndSettle();
    await tester.tap(accept.first);
    await _settleAfterPossiblePrecache(tester);
  }
}

void main() {
  testWidgets(
    'the lock banner truthfully names February as the last chance instead '
    "of Finding B's forward-looking promise, training still raises her to "
    '60 at month-end, and March genuinely offers no SkillSheet/営業 route '
    'back (no sales-window extension into March)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PublicDemo01PlaceholderScreen()),
      );
      await tester.pumpAndSettle();

      // ---- April: sell Sato and take Suzuki's first training.
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 52);

      await tapAndSettle(tester, 'SkillSheet確認');
      await tapAndSettle(tester, '営業開始');
      await tapAndSettle(tester, '案件紹介');
      await tapAndSettle(tester, '上位会社面談');
      await dismissDialog(tester, '確認');
      await tapAndSettle(tester, '客先面談');
      await dismissDialog(tester, '確認');
      await tapAndSettle(tester, '受注');
      await dismissDialog(tester, '確認');

      await tapFinder(tester, find.byKey(_trainingActionKey));
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '4月を終了して5月へ');
      await dismissMonthGuardIfPresent(tester);
      await dismissDialog(tester, '確認');
      expect(find.text('1年目 5月'), findsOneWidget);
      expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 53);

      // ---- May: hire and sell Takahashi (app-01), mirroring
      // public_demo_01_success_playthrough_test.dart's own May block
      // verbatim — this is solvency setup, not Finding B behavior (see
      // this file's class doc) — then take Suzuki's second training via
      // Finding B's own May training card.
      await switchPublicDemoTab(tester, PublicDemoTab.sales);
      await tapAndSettle(tester, '経歴書確認');
      await tapAndSettle(tester, '採用面談');
      await tapAndSettle(tester, '合格・給与提示');
      await tester.tap(
        find.byKey(const Key('public-demo-salary-offer-320000')),
      );
      await tester.pumpAndSettle();
      await tapAndSettle(tester, '入社前SkillSheet');
      await tapAndSettle(tester, '入社前営業');
      await tapAndSettle(tester, '案件紹介');
      await tapAndSettle(tester, '上位会社面談');
      await dismissDialog(tester, '確認');
      await tapAndSettle(tester, '客先面談');
      await dismissDialog(tester, '確認');
      await tapAndSettle(tester, '6月受注');
      await dismissDialog(tester, '確認');

      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      await tapFinder(tester, find.byKey(_trainingActionKey));
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '5月を終了して6月へ');
      await dismissMonthGuardIfPresent(tester);
      await dismissDialog(tester, '確認'); // 入社・初参画！
      expect(find.text('1年目 6月'), findsOneWidget);
      expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 54);

      // ---- June: accept both Sato's and Takahashi's July continuations
      // (Revenue for the rest of this playthrough) and take June's
      // training slot.
      await _acceptAllJulyContinuations(tester);
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      await tapFinder(tester, find.byKey(_trainingActionKey));
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '6月を終了して7月へ');
      await dismissMonthGuardIfPresent(tester);
      expect(find.text('1年目 7月'), findsOneWidget);
      expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 55);

      // ---- July: train, then close past the mandatory (default "none")
      // summer bonus decision.
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      await tapFinder(tester, find.byKey(_trainingActionKey));
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '7月を終了して8月へ');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, '7月を終了して8月へ');
      await dismissMonthGuardIfPresent(tester);
      expect(find.text('1年目 8月'), findsOneWidget);
      expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 56);

      // ---- August-October: three more ordinary-month trainings reach
      // exactly 59 by October's close — one short of the threshold,
      // deliberately.
      await _trainSuzukiAndCloseMonth(tester, '8月を終了して翌月へ');
      expect(find.text('1年目 9月'), findsOneWidget);
      await _trainSuzukiAndCloseMonth(tester, '9月を終了して翌月へ');
      expect(find.text('1年目 10月'), findsOneWidget);
      await _trainSuzukiAndCloseMonth(tester, '10月を終了して翌月へ');
      expect(find.text('1年目 11月'), findsOneWidget);
      expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 59);

      // ---- November-January: deliberately leave her untrained. She stays
      // at 59 entering February — the exact boundary scenario Codex named.
      await _closeMonth(tester, '11月を終了して翌月へ');
      expect(find.text('1年目 12月'), findsOneWidget);
      await _closeMonth(tester, '12月を終了して翌月へ');
      expect(find.text('1年目 1月'), findsOneWidget);
      await _closeMonth(tester, '1月を終了して翌月へ');
      expect(find.text('1年目 2月'), findsOneWidget);
      final suzukiInFebruary = currentState(tester).runtimeFor(_suzukiId);
      expect(suzukiInFebruary.actualCapability, 59);
      expect(suzukiInFebruary.isReadyForFieldSales, isFalse);

      // ---- February (internal month 14,
      // PublicDemoRecoveryEligibility.lastEligibleMonth): the lock banner
      // must state the truthful year-end fact, not Finding B's
      // forward-looking promise — training now cannot reopen her route
      // before this fiscal year ends.
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      final lock = find.byKey(_lockKey);
      expect(lock, findsOneWidget);
      expect(
        find.descendant(of: lock, matching: find.text(_lastChanceLine)),
        findsOneWidget,
        reason:
            'Codex P2: February must not promise a route this build '
            'cannot offer',
      );
      expect(
        find.descendant(of: lock, matching: find.text(_forwardLookingLine)),
        findsNothing,
        reason:
            'the false, unqualified promise must not appear in '
            'February',
      );

      // Training in February is still the same, unmodified command — it
      // still charges its cost and still raises capability by the same
      // amount at month-end. Nothing about the growth rule or the
      // affordability guard changed — this also empirically proves this
      // playthrough's Revenue kept it solvent enough for the charge to
      // actually go through (see this file's class doc on the ¥0 margin).
      final cashBeforeFebruaryTraining = currentState(tester).cash;
      expect(
        currentState(tester).isFinanciallyRestricted,
        isFalse,
        reason: 'training must not already be blocked entering February',
      );
      await tapFinder(tester, find.byKey(_trainingActionKey));
      expect(
        currentState(tester).cash,
        cashBeforeFebruaryTraining - 30000,
        reason:
            'training in the last eligible month is not blocked or '
            'special-cased',
      );

      // ---- Close February into March. `2月を終了して翌月へ` is the
      // ordinary-month close label for internal month 14 (publicDemoMonthLabel
      // maps 14 -> "2月").
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      await tapAndSettle(tester, '2月を終了して翌月へ');
      await dismissMonthGuardIfPresent(tester);
      expect(find.text('1年目 3月'), findsOneWidget);

      // ---- March: growth applied exactly as every other month — 8
      // trainings total (April, May, June, July, August, September,
      // October, February) x +1/month = 52 + 8 = 60, exactly the
      // threshold — but this build's sales window (RECOVERY-LOOP-1,
      // through February) does not extend here. No lock banner (it only
      // ever renders inside `ec(...)`, which `_buildEmployeesTab` never
      // calls for month 15) and no SkillSheet確認 button either — the
      // scoped fix corrects the copy's honesty, it does not add the route
      // Codex's finding said this build cannot actually offer.
      final suzukiInMarch = currentState(tester).runtimeFor(_suzukiId);
      expect(
        suzukiInMarch.actualCapability,
        PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement,
      );
      expect(suzukiInMarch.isReadyForFieldSales, isTrue);
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(find.byKey(_lockKey), findsNothing);
      expect(actionButton('SkillSheet確認'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
