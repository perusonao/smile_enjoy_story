// Issue #168 Finding B: regression coverage for the causal loop the founding
// engineer sales/training rule was always *supposed* to support end-to-end —
// "研修 → 実力60到達 → 営業再開" — but that
// `public_demo_01_suzuki_sales_lock_test.dart` never actually proves,
// because that test trains Suzuki (eng-02, capability 52) exactly once (in
// April) and then only drives the game forward to July, never far enough for
// one +1/month `internalTraining` gain to cross
// `fieldSalesCapabilityRequirement` (60). This file trains her every month —
// starting with the May training card Finding B adds (see
// `public_demo_01_placeholder_screen.dart`'s `_buildEmployeesTab`, the
// `s.month >= 5` unconditional training-card block) — through the real
// production UI, and proves the *existing*, unmodified July-February
// re-render window (`_buildEmployeesTab`'s `s.month >= 7 && s.month <= 14`
// `ec(i, showTrainingCard: false)` loop, RECOVERY-LOOP-1) already reopens
// her SkillSheet/営業 route once she actually reaches the threshold — no
// Suzuki-only branch, no changed threshold, no changed growth rate.
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
const _trainingCardKey = Key('public-demo-internal-training-$_suzukiId');
const _lockKey = Key('public-demo-field-sales-lock-$_suzukiId');

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

Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView);
  for (var i = 0; i < 10; i++) {
    final rect = tester.getRect(finder);
    if (rect.top >= 0 && rect.bottom <= tester.view.physicalSize.height) {
      break;
    }
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
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

/// Trains Suzuki this month via the real `研修する` action (whichever card
/// currently renders it — April's embedded `ec(i)` card or the standalone
/// `internalTrainingCard`, both the exact same key) and closes the month via
/// [closeLabel], proceeding past any real Month Guard warning exactly like
/// every other Public Demo suite that is not itself testing that warning.
Future<void> _trainSuzukiAndCloseMonth(
  WidgetTester tester,
  String closeLabel,
) async {
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
  await tapFinder(tester, find.byKey(_trainingActionKey));
  await switchPublicDemoTab(tester, PublicDemoTab.home);
  await tapAndSettle(tester, closeLabel);
  await dismissMonthGuardIfPresent(tester);
}

void main() {
  testWidgets('training Suzuki every month starting with the May training card '
      'Finding B adds eventually crosses the field-sales threshold, and the '
      'existing July-February re-render window (no Suzuki-only branch, no '
      'changed threshold, no changed growth rate) puts SkillSheet確認 back on '
      'screen for her', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PublicDemo01PlaceholderScreen()),
    );
    await tester.pumpAndSettle();

    // ---- April: sell Sato (the one founding engineer who can meet the
    // threshold on day one) for Revenue, and take Suzuki's one and only
    // April training opportunity. The employee sales-progression card is
    // on 社員 (PUBLIC-DEMO-HOME-UI-3B).
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 52);
    expect(find.byKey(_lockKey), findsOneWidget);
    expect(actionButton('SkillSheet確認'), findsOneWidget);

    await tapAndSettle(tester, 'SkillSheet確認');
    await tapAndSettle(tester, '営業開始');
    await tapAndSettle(tester, '案件紹介');
    await tapAndSettle(tester, '上位会社面談');
    await dismissDialog(tester, '確認');
    await tapAndSettle(tester, '客先面談');
    await dismissDialog(tester, '確認');
    await tapAndSettle(tester, '受注');
    await dismissDialog(tester, '確認');

    final cashBeforeTraining = currentState(tester).cash;
    await tapFinder(tester, find.byKey(_trainingActionKey));
    expect(
      currentState(tester).cash,
      cashBeforeTraining - 30000,
      reason: 'selecting training charges its ¥30,000 cost immediately',
    );

    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await tapAndSettle(tester, '4月を終了して5月へ');
    await dismissMonthGuardIfPresent(tester);
    await dismissDialog(tester, '確認');
    expect(find.text('1年目 5月'), findsOneWidget);
    expect(
      currentState(tester).runtimeFor(_suzukiId).actualCapability,
      53,
      reason: 'April training applies its +1 at month-end close',
    );

    // ---- May: Finding B's own fix. Before it, nothing on this tab
    // rendered a training card in May at all (April's `ec(i)` and the
    // June-onward unconditional block left May as the one gap in the
    // loop) — Suzuki lost a full month of `internalTraining` growth on
    // the way to the threshold for no domain reason. Assert the card now
    // exists, then use it exactly like every other month's.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(
      find.byKey(_trainingCardKey),
      findsOneWidget,
      reason:
          'Finding B: May must offer the same training card as every '
          'other waiting month',
    );
    expect(
      actionButton('SkillSheet確認'),
      findsNothing,
      reason: 'May never renders a founding-engineer sales card at all',
    );
    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await _trainSuzukiAndCloseMonth(tester, '5月を終了して6月へ');
    expect(find.text('1年目 6月'), findsOneWidget);
    expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 54);

    // ---- June: accept July's continuation for Sato (Revenue funds the
    // rest of this playthrough's training spend — see
    // `public_demo_01_assignment_carryforward_test.dart`'s own class doc
    // for the same carry-forward contract and cash trajectory) and take
    // June's training slot. June's founding-engineer sales card is scoped
    // to newly joined applicants (`joinedApplicantIds`), which excludes
    // Suzuki by design — only the standalone training card renders for
    // her here.
    await switchPublicDemoTab(tester, PublicDemoTab.sales);
    await tapAndSettle(tester, '7月分の発注を確認');
    expect(find.text('7月分発注あり'), findsOneWidget);
    await tapAndSettle(tester, '受注する');
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(actionButton('SkillSheet確認'), findsNothing);
    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await _trainSuzukiAndCloseMonth(tester, '6月を終了して7月へ');
    expect(find.text('1年目 7月'), findsOneWidget);
    expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 55);

    // ---- July: train, then close past the mandatory (default "none")
    // summer bonus decision — mirrors
    // `public_demo_01_fiscal_year_progression_test.dart`'s own July step.
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

    // ---- August-October: three more ordinary-month trainings. Still
    // below the threshold, so still no SkillSheet確認 for her yet — the
    // corrected lock banner never claimed a specific month, and this is
    // exactly why: reaching the threshold takes real, repeated play.
    await _trainSuzukiAndCloseMonth(tester, '8月を終了して翌月へ');
    expect(find.text('1年目 9月'), findsOneWidget);
    expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 57);
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(actionButton('SkillSheet確認'), findsNothing);
    expect(find.byKey(_lockKey), findsOneWidget);

    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await _trainSuzukiAndCloseMonth(tester, '9月を終了して翌月へ');
    expect(find.text('1年目 10月'), findsOneWidget);
    expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 58);

    await _trainSuzukiAndCloseMonth(tester, '10月を終了して翌月へ');
    expect(find.text('1年目 11月'), findsOneWidget);
    expect(currentState(tester).runtimeFor(_suzukiId).actualCapability, 59);

    // ---- November: the eighth and final training closes exactly on the
    // threshold (52 + 8 x (+1/month) = 60).
    await _trainSuzukiAndCloseMonth(tester, '11月を終了して翌月へ');
    expect(find.text('1年目 12月'), findsOneWidget);
    final suzukiInDecember = currentState(tester).runtimeFor(_suzukiId);
    expect(
      suzukiInDecember.actualCapability,
      PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement,
    );
    expect(suzukiInDecember.isReadyForFieldSales, isTrue);

    // ---- December: the causal loop's payoff. No rule changed to make
    // this happen — `_buildEmployeesTab`'s existing July-February
    // `ec(i, showTrainingCard: false)` loop already re-renders every
    // still-`waiting`, unassigned engineer every month in that window;
    // it simply never had a ready Suzuki to render for before. The lock
    // banner is gone and her SkillSheet route is back.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(find.byKey(_lockKey), findsNothing);
    expect(actionButton('SkillSheet確認'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
