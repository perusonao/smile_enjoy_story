// SES First Fun Quarter AI Replay Audit #3 P1 fix: before this fix, the
// candidate card's "評価" label rendered [PublicDemoApplicant.interviewScore]
// -- fixed at candidate generation, before the interactive interview even
// starts -- and the 合格・給与提示 offer button's `>= 60` gate read that exact
// same pre-interview number. Neither ever read anything the interactive Q&A
// produced, so no answer heard during the interview, and no question the
// player chose to ask, ever changed whether an offer became possible. This
// file proves both halves of the fix directly against the real UI: (1) the
// "評価" label never appears before the player has actually decided "採用候補
// として進める" in the interactive interview, and (2) for the exact same
// candidate, asking a different, real set of 3 questions produces a
// genuinely different final evaluation -- and therefore a different
// offer-button enabled state -- proving the Q&A now has real causal power
// over the outcome, not a coin flip and not zero effect.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/models/recruitment_interview.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import 'public_demo_interview_test_helpers.dart';
import 'public_demo_tab_test_helpers.dart';

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

const _expense = 800000;

/// Seed 555's first `engineer`-medium candidate, genuinely-interviewed via
/// the real production path (`recruit` -> `completeInterview`) -- chosen
/// because, with the real [RecruitmentInterviewEngine] answer generation,
/// this candidate's own baseline `interviewScore` (62) sits close enough to
/// the 60 pass line that the two question sets below land on opposite sides
/// of it (verified directly against
/// [PublicDemoRecruitmentInterview.finalEvaluationScore] before writing this
/// test): asking (technical, career, reasonForChange) yields 67 (pass), and
/// asking (futureCareer, teamwork, workStyle) yields 53 (fail).
({PublicDemoAggregate aggregate, String applicantId}) _seed555Applicant() {
  final started = PublicDemoAggregate.initial(
    runSeed: 555,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = started.recruit(PublicDemoRecruitmentMedium.engineer);
  final game = recruited.aggregate!;
  final applicant = game.workflow.applicants.firstWhere(
    (candidate) => candidate.id.startsWith('recruitment-'),
  );
  final result = game.completeInterview(applicant.id);
  return (aggregate: result.aggregate, applicantId: applicant.id);
}

Future<void> _pumpToSalesTab(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Force a full unmount before mounting the next fixture: two structurally
  // identical widget trees pumped back-to-back in the same test would
  // otherwise have their `PublicDemo01PlaceholderScreen` State reused
  // (same type, same slot, no distinguishing Key) instead of re-running
  // `initState`'s save-load, silently keeping the *first* fixture's
  // aggregate.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
}

Future<void> _openInterviewDialog(
  WidgetTester tester,
  String applicantId,
) async {
  final openButton = find.byKey(
    ValueKey('public-demo-interview-open-$applicantId'),
  );
  await tester.ensureVisible(openButton);
  await tester.pumpAndSettle();
  await tester.tap(openButton);
  await tester.pumpAndSettle();
}

Future<void> _answerQuestions(
  WidgetTester tester,
  List<InterviewQuestionCategory> categories,
) async {
  for (final category in categories) {
    final card = find.byKey(ValueKey('question-card-${category.name}'));
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

void main() {
  testWidgets(
    'no "評価" label before the interactive interview is decided '
    '(面談前に結果を先取りして見せない)',
    (tester) async {
      final fixture = _seed555Applicant();
      await _pumpToSalesTab(tester, fixture.aggregate);

      // The card is already at stage `interviewed` (採用面談 was completed by
      // the fixture) with no session started yet -- exactly the moment the
      // pre-fix bug showed a pass/fail "評価" before any Q&A happened.
      expect(find.textContaining('評価:'), findsNothing);
      expect(find.text('面談を行う'), findsOneWidget);

      // Still nothing revealed once the dialog is open but not yet
      // completed (mid-question-selection).
      await _openInterviewDialog(tester, fixture.applicantId);
      final firstCard = find.byKey(
        const ValueKey('question-card-technical'),
      );
      await tester.scrollUntilVisible(
        firstCard,
        200,
        scrollable: interviewDialogScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(firstCard);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('public-demo-interview-close')));
      await tester.pumpAndSettle();
      expect(find.textContaining('評価:'), findsNothing);
    },
  );

  testWidgets(
    'asking a good-fit question set passes, the exact same candidate asked '
    'a different real question set fails -- the Q&A genuinely decides it',
    (tester) async {
      // Set A: technical / career / reasonForChange -> final evaluation 67
      // (baseline interviewScore 62) -- passes the 60 line.
      final passFixture = _seed555Applicant();
      await _pumpToSalesTab(tester, passFixture.aggregate);
      await _openInterviewDialog(tester, passFixture.applicantId);
      await _answerQuestions(tester, const [
        InterviewQuestionCategory.technical,
        InterviewQuestionCategory.career,
        InterviewQuestionCategory.reasonForChange,
      ]);
      expect(find.text('評価: 採用基準を満たしています'), findsOneWidget);
      final passButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '合格・給与提示'),
      );
      expect(
        passButton.onPressed,
        isNotNull,
        reason: 'set A answers must make the offer button usable',
      );

      // Set B: futureCareer / teamwork / workStyle -> final evaluation 53 --
      // fails the exact same 60 line, for the exact same candidate
      // (identical runSeed/id/baseline interviewScore), purely because a
      // different, real set of questions was asked and answered.
      final failFixture = _seed555Applicant();
      expect(failFixture.applicantId, passFixture.applicantId);
      await _pumpToSalesTab(tester, failFixture.aggregate);
      await _openInterviewDialog(tester, failFixture.applicantId);
      await _answerQuestions(tester, const [
        InterviewQuestionCategory.futureCareer,
        InterviewQuestionCategory.teamwork,
        InterviewQuestionCategory.workStyle,
      ]);
      expect(find.text('評価: 採用基準を下回っています'), findsOneWidget);
      final failButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '合格・給与提示'),
      );
      expect(
        failButton.onPressed,
        isNull,
        reason: 'set B answers must leave the offer button disabled',
      );
    },
  );
}
