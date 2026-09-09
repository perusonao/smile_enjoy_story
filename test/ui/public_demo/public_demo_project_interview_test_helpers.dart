import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #219 (Fresh Audit / Fix: 案件面談の通常プレイ到達性): before this
/// fix, `客先面談` always opened the pre-Phase-6 generic pass/fail dialog
/// (dismissed with a single '確認' tap) for every fixture in this suite,
/// because `案件紹介` never created a real Phase 5 [PublicDemoMatchingProposal]
/// on its own. `案件紹介` now auto-proposes a real project whenever the
/// engineer doesn't already have one, so `客先面談` opens the real
/// interactive Phase 6 mini-game ([PublicDemoProjectInterviewDialog], titled
/// `案件面談`) for the same guided per-engineer flow every fixture below
/// already drives — see `public_demo_01_placeholder_screen.dart`'s own
/// `_introduceProject` doc for the production-side change.
///
/// This single shared helper replaces every fixture's own "tap '客先面談'
/// then dismiss with 確認" step: it detects whichever dialog actually opened
/// (the interactive mini-game, or — still possible on the separate pre-entry
/// applicant pipeline this fix does not touch — the old generic dialog) and
/// drives either to completion, so no fixture has to know or care which one
/// it gets. The mini-game path answers every follow-up question with
/// `letEmployeeHandle` — [ClientInterviewEngine.evaluate]'s one choice with
/// no category-specific risk/mismatch penalty, the same safe default
/// `public_demo_01_success_playthrough_test.dart` uses — then dismisses the
/// result with '続ける'.
Future<void> dismissClientInterview(WidgetTester tester) async {
  if (find.text('案件面談').evaluate().isNotEmpty) {
    final letEmployeeHandle = find.byKey(
      const Key('public-demo-project-interview-follow-letEmployeeHandle'),
    );
    for (var i = 0; i < 6; i++) {
      if (find.text('続ける').evaluate().isNotEmpty) break;
      await tester.ensureVisible(letEmployeeHandle);
      await tester.pumpAndSettle();
      await tester.tap(letEmployeeHandle);
      await tester.pumpAndSettle();
    }
    expect(find.text('続ける'), findsOneWidget);
    await tester.tap(find.text('続ける'));
    await tester.pumpAndSettle();
    return;
  }
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}
