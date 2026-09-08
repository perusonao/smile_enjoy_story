import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CORE-GAMEPLAY Phase 3: shared test helper for driving Public Demo's new
/// interactive recruitment-interview dialog from question selection through
/// to a hire/reject decision.
///
/// Before this phase, tapping '採用面談' immediately made '合格・給与提示'
/// available on the same applicant card — every UI test exercising the
/// success/offer path relied on that. This phase inserts a real interactive
/// interview (question selection -> reverse question -> summary/decision)
/// between those two steps; this helper reproduces the same end state
/// ('採用候補として進める' decided) so those existing tests can continue past
/// it with a minimal, behavior-preserving change, exactly the way
/// CORE-GAMEPLAY Phase 2's own report rewrote assertions pinned to the
/// mechanism it replaced rather than the outcome those tests actually cared
/// about.
final Finder interviewDialogScrollable = find.descendant(
  of: find.byKey(const Key('public-demo-interview-dialog')),
  matching: find.byType(Scrollable),
);

/// Taps whichever of '面談を行う'/'面談を続ける' is currently on screen,
/// opening the interview dialog. Callers that already opened the dialog
/// themselves (e.g. to assert on its very first frame) should call
/// [continueRecruitmentInterviewToHireDecision] directly instead.
Future<void> openRecruitmentInterviewDialog(WidgetTester tester) async {
  await tester.tap(find.textContaining('面談を'));
  await tester.pumpAndSettle();
}

/// Drives an already-open interview dialog from the question-selection
/// phase through to '採用候補として進める', leaving the dialog closed.
Future<void> continueRecruitmentInterviewToHireDecision(
  WidgetTester tester,
) async {
  // Ask exactly 3 of the 6 question-card categories (fixed, arbitrary
  // choice -- this helper only needs to get through the interview, not
  // exercise which categories were chosen) to reach the reverse-question
  // phase.
  for (final category in const ['technical', 'career', 'reasonForChange']) {
    final card = find.byKey(ValueKey('question-card-$category'));
    // The dialog's content is a scrollable ListView inside a
    // height-constrained Dialog -- an off-screen category card may not be
    // built into the element tree at all yet (Sliver lazy child creation),
    // so `ensureVisible` (which requires the element to already exist) is
    // not enough; `scrollUntilVisible` drags the list until it appears.
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: interviewDialogScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  final reverseChoice = find.byKey(
    const ValueKey('public-demo-interview-reverse-choice-0'),
  );
  await tester.scrollUntilVisible(
    reverseChoice,
    200,
    scrollable: interviewDialogScrollable,
  );
  await tester.pumpAndSettle();
  await tester.tap(reverseChoice);
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(const ValueKey('public-demo-interview-decision-proceed')),
  );
  await tester.pumpAndSettle();
}

/// Opens the interview dialog and drives it through to '採用候補として進め
/// る' in one call -- for callers that have not already opened it.
Future<void> driveRecruitmentInterviewToHireDecision(
  WidgetTester tester,
) async {
  await openRecruitmentInterviewDialog(tester);
  await continueRecruitmentInterviewToHireDecision(tester);
}
