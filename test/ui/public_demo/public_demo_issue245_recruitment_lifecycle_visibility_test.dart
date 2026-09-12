// Issue #245 Finding #12/#13 (採用応募者 lifecycle / 所在の可視化):
//
// Finding #12 — once an applicant joins, the 営業タブ applicant funnel
// (`_S._salesApplicantProgressCards`) rightly stops rendering their card
// (Issue #241 — their story continues on 社員, never a stale pre-join
// badge), but before this change that meant simply vanishing with no
// acknowledgement at all: a player scanning 営業 alone had no way to tell
// "採用面談後、この人はどうなったか" from a genuine bug.
//
// Finding #13 — every not-yet-joined applicant rendered as one flat,
// undifferentiated list: a candidate still needing player action sat
// visually indistinguishable from one whose *employment* outcome was
// already final and unsuccessful (不採用/内定辞退, which render no button at
// all) and from one simply waiting for the month-end join boundary.
//
// PR #252 Codex review (P2): the first version of this fix classified
// `preEntryPartnerFailed`/`preEntryClientFailed` as `closed` alongside
// `rejected`/`offerDeclined`, reusing `_applicantStatusTone`'s "negative"
// set. That set is about the *sales* outcome (this one pre-entry interview
// failed), not the *employment* outcome: `PublicDemoApplicant.join` only
// excludes `hasJoined` and `stage == offerDeclined` — a failed pre-entry
// partner/client interview never touches `bindingOffer` (minted once, at
// offer acceptance, before the pre-entry sales chain even starts) — so
// `joinAcceptedForFiscalClose` still joins such an applicant at month-end
// exactly like any other accepted offer. Labeling their card
// "結果確定（不採用・辞退）" falsely told the player their employment outcome
// was final and negative when they were, in truth, still `入社予定`. Moved
// to `awaitingJoin` — see the dedicated group below for the regression
// tests this added.
//
// This suite exercises the purely-presentational fixes for both findings —
// `_S._salesOverviewSection`'s new 入社済み summary line, and
// `_S._salesApplicantProgressCards`'s new active/awaitingJoin/closed
// grouping — entirely through real production `PublicDemoAggregate`
// commands (`recruit`/`completeInterview`/interactive interview
// session/`acceptOffer`/pre-entry-sales chain/`recordJuneOrder`/`closeMay`),
// exactly like `public_demo_sales_ui_phase1_test.dart` and
// `public_demo_issue248_applicant_engineer_continuity_test.dart` this suite
// borrows its fixture techniques from. No fabricated applicant/stage is
// ever constructed directly.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/models/recruitment_interview.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import 'public_demo_tab_test_helpers.dart';

const _expense = 800000;

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

Future<void> _pumpSalesTab(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: PublicDemo01PlaceholderScreen(
          saveService: _FixedSaveService(aggregate),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
}

const _activeHeader = '対応が必要な候補者';
const _awaitingHeader = '結果待ち・入社予定';
const _closedHeader = '結果確定（不採用・辞退）';
const _joinedSummaryKey = Key('public-demo-sales-joined-summary');

/// A May aggregate with one real, free-medium applicant left untouched at
/// `applied` — the same fixture technique as
/// `public_demo_sales_ui_phase1_test.dart`'s `mayWithApplicants`.
PublicDemoAggregate _mayWithOneActiveApplicant() {
  final started = PublicDemoAggregate.initial(
    runSeed: 1,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = started.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  return recruited.aggregate!;
}

/// Drives one real, seeded applicant all the way through the actual
/// production reject decision — `recruit` -> `completeInterview` -> the
/// interactive recruitment-interview session -> `concludeInterviewSession
/// (InterviewOutcome.rejected)` — the same "見送る" path
/// `public_demo_recruitment_interview_test.dart`'s own "reject/decline
/// path" test exercises. Never fabricates `PublicDemoApplicantStage
/// .rejected` directly.
PublicDemoAggregate _mayWithOneRejectedApplicant() {
  var aggregate = _mayWithOneActiveApplicant();
  final id = aggregate.workflow.applicants.first.id;
  aggregate = aggregate.completeInterview(id).aggregate;
  aggregate = aggregate
      .startInterviewSession(id)
      .askInterviewQuestion(id, InterviewQuestionCategory.technical)
      .askInterviewQuestion(id, InterviewQuestionCategory.career)
      .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
      .answerInterviewReverseQuestion(id, 0);
  aggregate = aggregate.concludeInterviewSession(
    id,
    InterviewOutcome.rejected,
  );
  expect(
    aggregate.workflow.applicants.first.stage.name,
    'rejected',
    reason: 'fixture sanity',
  );
  return aggregate;
}

/// Recruits the real engineer-medium pair (runSeed 1 — already relied on
/// elsewhere, see `public_demo_issue248_applicant_engineer_continuity_test
/// .dart`, as a seed whose first candidate clears every real formula this
/// chain depends on) and drives ONLY the first candidate through the real
/// production pre-entry-sales chain up to `recordJuneOrder` — deliberately
/// NOT calling `closeMay`, so this applicant is genuinely `juneOrdered` but
/// not yet [PublicDemoApplicant.hasJoined]. The second candidate is left
/// untouched at `applied`, giving one aggregate with both an `active` and
/// an `awaitingJoin` applicant at once.
PublicDemoAggregate _mayWithActiveAndAwaitingJoinApplicants() {
  var aggregate = PublicDemoAggregate.initial(runSeed: 1)
      .recruit(PublicDemoRecruitmentMedium.engineer)
      .aggregate!
      .closeApril(monthlyExpenses: _expense);
  final ordering = aggregate.workflow.applicants.first;
  final stillActive = aggregate.workflow.applicants[1];

  aggregate = aggregate.completeInterview(ordering.id).aggregate;
  final interviewed = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == ordering.id,
  );
  final offer = PublicDemoSalaryOfferEvaluator.evaluate(
    applicant: interviewed,
    offeredMonthlySalary: interviewed.requestedMonthlySalary,
  );
  aggregate = aggregate.acceptOffer(
    applicantId: ordering.id,
    offer: offer,
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
  );
  aggregate = aggregate
      .beginPreEntrySkillSheet(ordering.id)
      .beginPreEntrySelling(ordering.id)
      .introducePreEntryProject(ordering.id)
      .recordPreEntryPartnerInterviewResult(ordering.id)
      .recordPreEntryClientInterviewResult(ordering.id)
      .recordJuneOrder(ordering.id);

  final orderedApplicant = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == ordering.id,
  );
  expect(
    orderedApplicant.stage.name,
    'juneOrdered',
    reason: 'fixture sanity',
  );
  expect(orderedApplicant.hasJoined, isFalse, reason: 'fixture sanity');
  expect(
    aggregate.workflow.applicants
        .firstWhere((a) => a.id == stillActive.id)
        .stage
        .name,
    'applied',
    reason: 'fixture sanity',
  );
  return aggregate;
}

/// Issue #241 fixture (matches `public_demo_sales_ui_phase1_test.dart`'s
/// own `juneWithJoinedHire`): the May free-medium applicant's offer is
/// accepted and genuinely joined at `closeMay`.
PublicDemoAggregate _juneWithOneJoinedApplicant() {
  final game = _mayWithOneActiveApplicant();
  final applicantId = game.workflow.applicants.first.id;
  final interview = game.completeInterview(applicantId);
  var next = interview.aggregate;
  final applicant = next.workflow.applicants.firstWhere(
    (a) => a.id == applicantId,
  );
  next = next.acceptOffer(
    applicantId: applicantId,
    offer: PublicDemoSalaryOffer(
      requestedMonthlySalary: applicant.requestedMonthlySalary,
      offeredMonthlySalary: applicant.requestedMonthlySalary,
      acceptanceScore: 100,
      motivationDelta: 0,
      trustDelta: 0,
    ),
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(next.state.month),
  );
  return next.closeMay(week: 9, monthlyExpenses: _expense);
}

/// A genuinely declined offer — `PublicDemoSalaryOffer.accepted` is real
/// (`acceptanceScore >= 60`), so an `acceptanceScore` of 0 (same direct-
/// construction technique [_juneWithOneJoinedApplicant] already uses with
/// `acceptanceScore: 100` for the opposite outcome) drives
/// `PublicDemoOfferAcceptance.accept` to its real `offerDeclined` branch,
/// never a fabricated stage. Confirms `offerDeclined` still classifies as
/// `closed` after the PR #252 Codex review P2 fix (unlike
/// `preEntryPartnerFailed`/`preEntryClientFailed`, a declined offer never
/// mints a [PublicDemoApplicant.bindingOffer] at all, so it genuinely never
/// joins — see [PublicDemoApplicant.join]'s own `stage == offerDeclined`
/// guard).
PublicDemoAggregate _mayWithOneDeclinedApplicant() {
  final game = _mayWithOneActiveApplicant();
  final applicantId = game.workflow.applicants.first.id;
  final interview = game.completeInterview(applicantId);
  var next = interview.aggregate;
  final applicant = next.workflow.applicants.firstWhere(
    (a) => a.id == applicantId,
  );
  next = next.acceptOffer(
    applicantId: applicantId,
    offer: PublicDemoSalaryOffer(
      requestedMonthlySalary: applicant.requestedMonthlySalary,
      offeredMonthlySalary: applicant.requestedMonthlySalary,
      acceptanceScore: 0,
      motivationDelta: 0,
      trustDelta: 0,
    ),
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(next.state.month),
  );
  final declined = next.workflow.applicants.firstWhere(
    (a) => a.id == applicantId,
  );
  expect(declined.stage.name, 'offerDeclined', reason: 'fixture sanity');
  expect(declined.hasBindingOffer, isFalse, reason: 'fixture sanity');
  return next;
}

/// Drives one real, seeded applicant through the actual production
/// pre-entry-sales chain up to a genuine `recordPreEntryPartnerInterviewResult`
/// **failure** — `recordPreEntryPartnerInterviewResult` derives pass/fail
/// itself from the applicant's own real `salesSkillFit` (never a
/// caller-supplied outcome), so [runSeed] 4's free-medium May candidate
/// (`salesSkillFit` 49, confirmed below threshold 60) is used specifically
/// because it fails this real formula, not because a stage is asserted
/// directly. Deliberately NOT calling `closeMay` — see
/// [PublicDemoAggregate.join]'s own doc: [PublicDemoApplicant.bindingOffer]
/// (minted by `acceptOffer`, before this failure) is untouched by a failed
/// pre-entry interview, so this applicant genuinely still joins at
/// month-end (PR #252 Codex review P2) — this fixture stops one step short
/// of `closeMay` so a test can assert the pre-join classification, and a
/// second test (below) calls `closeMay` on top of it to assert the actual
/// join.
PublicDemoAggregate _mayWithOnePreEntryPartnerFailedApplicant() {
  const seed = 4;
  var aggregate = PublicDemoAggregate.initial(
    runSeed: seed,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  aggregate = recruited.aggregate!;
  final id = aggregate.workflow.applicants.first.id;
  final salesSkillFit = aggregate.workflow.applicants.first.salesSkillFit;
  expect(
    salesSkillFit,
    lessThan(60),
    reason: 'fixture sanity: runSeed $seed must genuinely fail the real '
        'partner-interview threshold, not be asserted to fail',
  );

  aggregate = aggregate.completeInterview(id).aggregate;
  final interviewed = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == id,
  );
  final offer = PublicDemoSalaryOfferEvaluator.evaluate(
    applicant: interviewed,
    offeredMonthlySalary: interviewed.requestedMonthlySalary,
  );
  aggregate = aggregate.acceptOffer(
    applicantId: id,
    offer: offer,
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
  );
  aggregate = aggregate
      .beginPreEntrySkillSheet(id)
      .beginPreEntrySelling(id)
      .introducePreEntryProject(id)
      .recordPreEntryPartnerInterviewResult(id);

  final failed = aggregate.workflow.applicants.firstWhere((a) => a.id == id);
  expect(
    failed.stage.name,
    'preEntryPartnerFailed',
    reason: 'fixture sanity',
  );
  expect(failed.hasBindingOffer, isTrue, reason: 'fixture sanity');
  expect(failed.hasJoined, isFalse, reason: 'fixture sanity');
  return aggregate;
}

/// Same technique as [_mayWithOnePreEntryPartnerFailedApplicant], but
/// [runSeed] 2's free-medium May candidate (`salesSkillFit` 60 — clears the
/// real partner threshold of 60, then genuinely fails the real client
/// threshold of 65) reaches `recordPreEntryClientInterviewResult`'s
/// **failure** instead — a genuinely different real-formula outcome, not a
/// second assertion of the same one.
PublicDemoAggregate _mayWithOnePreEntryClientFailedApplicant() {
  const seed = 2;
  var aggregate = PublicDemoAggregate.initial(
    runSeed: seed,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  aggregate = recruited.aggregate!;
  final id = aggregate.workflow.applicants.first.id;
  final salesSkillFit = aggregate.workflow.applicants.first.salesSkillFit;
  expect(
    salesSkillFit,
    allOf(greaterThanOrEqualTo(60), lessThan(65)),
    reason: 'fixture sanity: runSeed $seed must genuinely pass the real '
        'partner threshold and fail the real client threshold',
  );

  aggregate = aggregate.completeInterview(id).aggregate;
  final interviewed = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == id,
  );
  final offer = PublicDemoSalaryOfferEvaluator.evaluate(
    applicant: interviewed,
    offeredMonthlySalary: interviewed.requestedMonthlySalary,
  );
  aggregate = aggregate.acceptOffer(
    applicantId: id,
    offer: offer,
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
  );
  aggregate = aggregate
      .beginPreEntrySkillSheet(id)
      .beginPreEntrySelling(id)
      .introducePreEntryProject(id)
      .recordPreEntryPartnerInterviewResult(id);
  expect(
    aggregate.workflow.applicants.firstWhere((a) => a.id == id).stage.name,
    'preEntryPartnerPassed',
    reason: 'fixture sanity',
  );
  aggregate = aggregate.recordPreEntryClientInterviewResult(id);

  final failed = aggregate.workflow.applicants.firstWhere((a) => a.id == id);
  expect(failed.stage.name, 'preEntryClientFailed', reason: 'fixture sanity');
  expect(failed.hasBindingOffer, isTrue, reason: 'fixture sanity');
  expect(failed.hasJoined, isFalse, reason: 'fixture sanity');
  return aggregate;
}

/// Mirrors `_S._interviewDecidedHired`'s own read exactly
/// (`workflow.interviewSessions.any((s) => s.applicantId == applicantId &&
/// s.completed && s.outcome == InterviewOutcome.hired)`) — used only for
/// fixture-sanity assertions in this file, never as production logic.
bool _decidedHired(PublicDemoAggregate aggregate, String applicantId) =>
    aggregate.workflow.interviewSessions.any(
      (session) =>
          session.applicantId == applicantId &&
          session.completed &&
          session.outcome == InterviewOutcome.hired,
    );

/// PR #252 Codex review (P2, second finding): drives one real, seeded
/// applicant through the actual production interactive interview session to
/// a genuine "採用候補として進める" decision (`concludeInterviewSession
/// (InterviewOutcome.hired)`) while their real `interviewScore` (`runSeed`
/// 18's free-medium May candidate — confirmed below 60, never asserted) is
/// below the real 60 threshold `ac(i)`'s own offer button
/// (`onPressed: a.interviewScore >= 60 ? () => offer(i) : null`) and
/// `_addApplicantStageCandidate`'s identical `interviewed` branch both gate
/// on. `concludeInterviewSession` itself never checks `interviewScore` at
/// all (only [PublicDemoAggregate.completeInterview]'s slot-consumption
/// guard applies earlier), so a genuinely low-scoring applicant can reach
/// this "decided hired, but no legal offer possible" dead end through
/// ordinary play. Stage stays `interviewed` forever — nothing in this
/// pipeline ever moves it, and the interview session, once `completed`,
/// never reopens.
PublicDemoAggregate _mayWithOneStalledBelowThresholdInterviewedApplicant() {
  const seed = 18;
  var aggregate = PublicDemoAggregate.initial(
    runSeed: seed,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  aggregate = recruited.aggregate!;
  final id = aggregate.workflow.applicants.first.id;
  final interviewScore = aggregate.workflow.applicants.first.interviewScore;
  expect(
    interviewScore,
    lessThan(60),
    reason: 'fixture sanity: runSeed $seed must genuinely fall below the '
        'real offer threshold, not be asserted to',
  );

  aggregate = aggregate.completeInterview(id).aggregate;
  aggregate = aggregate
      .startInterviewSession(id)
      .askInterviewQuestion(id, InterviewQuestionCategory.technical)
      .askInterviewQuestion(id, InterviewQuestionCategory.career)
      .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
      .answerInterviewReverseQuestion(id, 0);
  aggregate = aggregate.concludeInterviewSession(id, InterviewOutcome.hired);

  final stalled = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == id,
  );
  expect(stalled.stage.name, 'interviewed', reason: 'fixture sanity');
  expect(_decidedHired(aggregate, id), isTrue, reason: 'fixture sanity');
  expect(stalled.interviewScore, lessThan(60), reason: 'fixture sanity');
  return aggregate;
}

/// The non-stalled counterpart: same technique, but `runSeed` 1's real
/// `interviewScore` clears the real 60 threshold, so the offer button stays
/// legally pressable (`active`) after the exact same "採用候補として進める"
/// decision.
PublicDemoAggregate _mayWithOneDecidedHiredAboveThresholdApplicant() {
  const seed = 1;
  var aggregate = PublicDemoAggregate.initial(
    runSeed: seed,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  aggregate = recruited.aggregate!;
  final id = aggregate.workflow.applicants.first.id;
  final interviewScore = aggregate.workflow.applicants.first.interviewScore;
  expect(
    interviewScore,
    greaterThanOrEqualTo(60),
    reason: 'fixture sanity: runSeed $seed must genuinely clear the real '
        'offer threshold, not be asserted to',
  );

  aggregate = aggregate.completeInterview(id).aggregate;
  aggregate = aggregate
      .startInterviewSession(id)
      .askInterviewQuestion(id, InterviewQuestionCategory.technical)
      .askInterviewQuestion(id, InterviewQuestionCategory.career)
      .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
      .answerInterviewReverseQuestion(id, 0);
  aggregate = aggregate.concludeInterviewSession(id, InterviewOutcome.hired);

  final decided = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == id,
  );
  expect(decided.stage.name, 'interviewed', reason: 'fixture sanity');
  expect(_decidedHired(aggregate, id), isTrue, reason: 'fixture sanity');
  expect(decided.interviewScore, greaterThanOrEqualTo(60), reason: 'fixture sanity');
  return aggregate;
}

/// Month-boundary regression for the same PR #252 P2 dead end: recruits in
/// **June** (`runSeed` 3's real free-medium June candidate, `interviewScore`
/// 48 — confirmed below 60), specifically because `closeMay`'s own
/// `joinAndKeepOnly` prunes any not-yet-`accepted` May cohort applicant
/// (a documented, one-time, May-to-June cutoff unrelated to this fix — an
/// `interviewed`-stage applicant is never in that `accepted()` set either
/// way), which would make a *May*-recruited stalled applicant vanish at
/// June regardless of this classification fix and mask what this test
/// wants to prove. A June-or-later recruit uses
/// [PublicDemoWorkflowState.joinAcceptedForFiscalClose] at every later
/// close instead (never pruning), so this fixture drives all the way
/// through `closeJune` (May is closed first, with zero applicants pending,
/// so nothing is pruned there) to confirm the stalled applicant survives
/// the June→July boundary still present and still correctly classified.
PublicDemoAggregate _juneWithOneStalledBelowThresholdApplicantAfterClose() {
  const seed = 3;
  var aggregate = PublicDemoAggregate.initial(runSeed: seed)
      .closeApril(monthlyExpenses: _expense)
      .closeMay(week: 9, monthlyExpenses: _expense);
  expect(aggregate.state.month, 6, reason: 'fixture sanity');
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  aggregate = recruited.aggregate!;
  final id = aggregate.workflow.applicants.first.id;
  expect(
    aggregate.workflow.applicants.first.interviewScore,
    lessThan(60),
    reason: 'fixture sanity: runSeed $seed must genuinely fall below the '
        'real offer threshold at June, not be asserted to',
  );

  aggregate = aggregate.completeInterview(id).aggregate;
  aggregate = aggregate
      .startInterviewSession(id)
      .askInterviewQuestion(id, InterviewQuestionCategory.technical)
      .askInterviewQuestion(id, InterviewQuestionCategory.career)
      .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
      .answerInterviewReverseQuestion(id, 0);
  aggregate = aggregate.concludeInterviewSession(id, InterviewOutcome.hired);
  expect(_decidedHired(aggregate, id), isTrue, reason: 'fixture sanity');

  final closedJune = aggregate.closeJune(
    assignedInJuly: 0,
    monthlyExpenses: _expense,
  );
  expect(closedJune.state.month, 7, reason: 'fixture sanity');
  final survived = closedJune.workflow.applicants
      .where((a) => a.id == id)
      .toList();
  expect(
    survived,
    hasLength(1),
    reason: 'fixture sanity: unlike closeMay, closeJune must never prune a '
        'not-yet-accepted applicant',
  );
  expect(survived.first.stage.name, 'interviewed', reason: 'fixture sanity');
  expect(survived.first.hasJoined, isFalse, reason: 'fixture sanity');
  return closedJune;
}

void main() {
  group('Finding #13: 採用・候補者進捗 lifecycle grouping', () {
    testWidgets(
      'a single in-progress applicant renders only the 対応が必要 header, '
      'with the correct count and no other bucket header',
      (tester) async {
        await _pumpSalesTab(tester, _mayWithOneActiveApplicant());

        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_awaitingHeader), findsNothing);
        expect(find.textContaining(_closedHeader), findsNothing);
      },
    );

    testWidgets(
      'a genuinely rejected applicant renders only the 結果確定 header, '
      'keeps its 不採用 badge, and never renders a button',
      (tester) async {
        final aggregate = _mayWithOneRejectedApplicant();
        await _pumpSalesTab(tester, aggregate);

        expect(find.text('$_closedHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_activeHeader), findsNothing);
        expect(find.textContaining(_awaitingHeader), findsNothing);
        expect(find.text('不採用'), findsOneWidget);
        expect(
          find.text(aggregate.workflow.applicants.first.name),
          findsOneWidget,
          reason: 'a rejected (not-yet-joined) applicant must still be '
              'visible on the funnel — only a joined one disappears',
        );
      },
    );

    testWidgets(
      'an active applicant and a juneOrdered-but-not-yet-joined applicant '
      'render under separate headers, each with count 1, and mutual '
      'exclusion holds (no 結果確定 header)',
      (tester) async {
        final aggregate = _mayWithActiveAndAwaitingJoinApplicants();
        await _pumpSalesTab(tester, aggregate);

        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.text('$_awaitingHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_closedHeader), findsNothing);

        // Both applicants are still genuinely on the funnel (neither has
        // joined yet) -- Issue #241's own exclusion rule only fires once
        // `hasJoined` is true.
        for (final applicant in aggregate.workflow.applicants) {
          expect(find.text(applicant.name), findsOneWidget);
        }
      },
    );

    testWidgets(
      'the active header renders above the awaitingJoin header (same '
      'left-to-right reading order as the pipeline itself)',
      (tester) async {
        await _pumpSalesTab(
          tester,
          _mayWithActiveAndAwaitingJoinApplicants(),
        );

        final activeHeaderY = tester
            .getTopLeft(find.text('$_activeHeader（1名）'))
            .dy;
        final awaitingHeaderY = tester
            .getTopLeft(find.text('$_awaitingHeader（1名）'))
            .dy;
        expect(activeHeaderY, lessThan(awaitingHeaderY));
      },
    );
  });

  group(
    'PR #252 Codex review P2: preEntryPartnerFailed/preEntryClientFailed '
    'are 入社予定 (awaitingJoin), not 結果確定 (closed)',
    () {
      testWidgets(
        'a genuine preEntryPartnerFailed applicant renders under '
        '結果待ち・入社予定, not 結果確定, and keeps its own 上位面談不合格 '
        'sales-failure badge/tone unchanged',
        (tester) async {
          final aggregate = _mayWithOnePreEntryPartnerFailedApplicant();
          await _pumpSalesTab(tester, aggregate);

          expect(find.text('$_awaitingHeader（1名）'), findsOneWidget);
          expect(find.textContaining(_closedHeader), findsNothing);
          expect(find.textContaining(_activeHeader), findsNothing);
          expect(
            find.text('上位面談不合格'),
            findsOneWidget,
            reason: 'the sales-failure status itself must stay exactly as '
                'it was -- only the group header changes',
          );
          expect(
            find.text(aggregate.workflow.applicants.first.name),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'a genuine preEntryClientFailed applicant renders under '
        '結果待ち・入社予定, not 結果確定, and keeps its own 客先面談不合格 '
        'sales-failure badge/tone unchanged',
        (tester) async {
          final aggregate = _mayWithOnePreEntryClientFailedApplicant();
          await _pumpSalesTab(tester, aggregate);

          expect(find.text('$_awaitingHeader（1名）'), findsOneWidget);
          expect(find.textContaining(_closedHeader), findsNothing);
          expect(find.textContaining(_activeHeader), findsNothing);
          expect(find.text('客先面談不合格'), findsOneWidget);
        },
      );

      testWidgets(
        'rejected and offerDeclined still classify as 結果確定 -- the fix '
        'narrows `closed` to genuinely-final employment outcomes, it does '
        'not remove them',
        (tester) async {
          await _pumpSalesTab(tester, _mayWithOneRejectedApplicant());
          expect(find.text('$_closedHeader（1名）'), findsOneWidget);
        },
      );

      testWidgets(
        'a genuinely declined offer (offerDeclined) still classifies as '
        '結果確定, and never joins at closeMay (unlike the two failed '
        'pre-entry stages)',
        (tester) async {
          final declined = _mayWithOneDeclinedApplicant();
          await _pumpSalesTab(tester, declined);
          expect(find.text('$_closedHeader（1名）'), findsOneWidget);

          final applicantId = declined.workflow.applicants.first.id;
          final closed = declined.closeMay(week: 9, monthlyExpenses: _expense);
          // `closeMay` specifically prunes `workflow.applicants` down to the
          // May cohort's accepted subset (`joinAndKeepOnly` -- a documented,
          // one-time May-to-June cutoff, unrelated to this fix). An
          // `offerDeclined` applicant is therefore usually pruned out
          // entirely rather than merely left `hasJoined: false` -- either
          // way, the one fact this test cares about is that they are never
          // among the genuinely joined.
          expect(
            closed.workflow.applicants
                .where((a) => a.id == applicantId && a.hasJoined)
                .toList(),
            isEmpty,
            reason: 'an offerDeclined applicant must never join, unlike a '
                'failed pre-entry interview',
          );
        },
      );

      testWidgets(
        'month close (closeMay) genuinely joins a preEntryPartnerFailed '
        'applicant -- the overview\'s 入社済み summary line takes over and '
        'the funnel section disappears, exactly like any other accepted '
        'offer',
        (tester) async {
          final before = _mayWithOnePreEntryPartnerFailedApplicant();
          final applicantId = before.workflow.applicants.first.id;
          final closed = before.closeMay(week: 9, monthlyExpenses: _expense);
          final joined = closed.workflow.applicants.firstWhere(
            (a) => a.id == applicantId,
          );
          expect(joined.hasJoined, isTrue, reason: 'fixture sanity');
          expect(
            joined.stage.name,
            'preEntryPartnerFailed',
            reason: 'join() never rewrites stage -- fixture sanity',
          );

          await _pumpSalesTab(tester, closed);

          final summary = tester.widget<Text>(find.byKey(_joinedSummaryKey));
          expect(summary.data, '入社済み 1名（社員タブで活動中）');
          expect(
            find.byKey(
              const Key('public-demo-sales-applicant-progress-section'),
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'month close (closeMay) genuinely joins a preEntryClientFailed '
        'applicant the same way',
        (tester) async {
          final before = _mayWithOnePreEntryClientFailedApplicant();
          final applicantId = before.workflow.applicants.first.id;
          final closed = before.closeMay(week: 9, monthlyExpenses: _expense);
          expect(
            closed.workflow.applicants
                .firstWhere((a) => a.id == applicantId)
                .hasJoined,
            isTrue,
          );

          await _pumpSalesTab(tester, closed);
          final summary = tester.widget<Text>(find.byKey(_joinedSummaryKey));
          expect(summary.data, '入社済み 1名（社員タブで活動中）');
        },
      );

      testWidgets(
        'save/reload (toJson -> fromJson) preserves the awaitingJoin '
        'classification for both preEntryPartnerFailed and '
        'preEntryClientFailed',
        (tester) async {
          final partnerFailed = PublicDemoAggregate.fromJson(
            _mayWithOnePreEntryPartnerFailedApplicant().toJson(),
          );
          await _pumpSalesTab(tester, partnerFailed);
          expect(find.text('$_awaitingHeader（1名）'), findsOneWidget);
          expect(find.textContaining(_closedHeader), findsNothing);
        },
      );
    },
  );

  group(
    'PR #252 Codex review P2 (second finding, r3995477975): a completed, '
    'below-threshold interviewed applicant with no legal next action is '
    'never 対応が必要',
    () {
      testWidgets(
        'interviewed + interviewScore < 60 + decided "採用候補として進める": '
        'no legal offer button exists (disabled) and no HOME action is '
        'emitted, so this applicant must not render under 対応が必要',
        (tester) async {
          final aggregate =
              _mayWithOneStalledBelowThresholdInterviewedApplicant();
          await _pumpSalesTab(tester, aggregate);

          expect(find.textContaining(_activeHeader), findsNothing);
          expect(find.text('$_closedHeader（1名）'), findsOneWidget);
          // The card itself is untouched: still renders, still shows the
          // permanently-disabled offer button -- only its group header
          // changed.
          expect(
            find.text(aggregate.workflow.applicants.first.name),
            findsOneWidget,
          );
          final offerButton = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, '合格・給与提示'),
          );
          expect(
            offerButton.onPressed,
            isNull,
            reason: 'fixture sanity: the offer button must genuinely have '
                'no legal action, matching the review finding exactly',
          );
        },
      );

      testWidgets(
        'interviewed + interviewScore >= 60 + decided "採用候補として進める": '
        'the real offer button is legally pressable, so this applicant '
        'stays 対応が必要 -- the fix narrows `closed`, it does not widen it '
        'to every decided-hired interviewed applicant',
        (tester) async {
          final aggregate =
              _mayWithOneDecidedHiredAboveThresholdApplicant();
          await _pumpSalesTab(tester, aggregate);

          expect(find.text('$_activeHeader（1名）'), findsOneWidget);
          expect(find.textContaining(_closedHeader), findsNothing);
          final offerButton = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, '合格・給与提示'),
          );
          expect(
            offerButton.onPressed,
            isNotNull,
            reason: 'fixture sanity: a real, legally pressable offer button '
                'must still exist for this applicant',
          );
        },
      );

      testWidgets(
        'month boundary: a June-recruited stalled applicant survives '
        'closeJune (unlike closeMay\'s one-time May-cohort prune) and '
        'still classifies as 結果確定, not 対応が必要, after the close',
        (tester) async {
          final afterClose =
              _juneWithOneStalledBelowThresholdApplicantAfterClose();
          await _pumpSalesTab(tester, afterClose);

          expect(find.textContaining(_activeHeader), findsNothing);
          expect(find.text('$_closedHeader（1名）'), findsOneWidget);
        },
      );

      testWidgets(
        'save/reload (toJson -> fromJson) preserves the closed '
        'classification for a stalled below-threshold interviewed '
        'applicant',
        (tester) async {
          final reloaded = PublicDemoAggregate.fromJson(
            _mayWithOneStalledBelowThresholdInterviewedApplicant().toJson(),
          );
          await _pumpSalesTab(tester, reloaded);

          expect(find.textContaining(_activeHeader), findsNothing);
          expect(find.text('$_closedHeader（1名）'), findsOneWidget);
        },
      );

      testWidgets(
        'a stalled below-threshold applicant never joins at closeMay or '
        'closeJune -- unlike preEntryPartnerFailed/preEntryClientFailed, '
        'this dead end never had a binding offer at all',
        (tester) async {
          final afterClose =
              _juneWithOneStalledBelowThresholdApplicantAfterClose();
          final applicantId = afterClose.workflow.applicants.first.id;
          expect(
            afterClose.workflow.applicants
                .where((a) => a.id == applicantId && a.hasJoined)
                .toList(),
            isEmpty,
          );
          await _pumpSalesTab(tester, afterClose);
          expect(find.byKey(_joinedSummaryKey), findsNothing);
        },
      );
    },
  );

  group('Finding #12: 入社済み summary line', () {
    testWidgets(
      'once the only applicant joins, the overview section states the '
      'joined count truthfully, the funnel section disappears entirely, '
      'and the applicant\'s own name never renders again on 営業 (Issue '
      '#241 regression)',
      (tester) async {
        final joined = _juneWithOneJoinedApplicant();
        final joinedApplicant = joined.workflow.applicants.first;
        expect(joinedApplicant.hasJoined, isTrue, reason: 'fixture sanity');

        await _pumpSalesTab(tester, joined);

        final summary = tester.widget<Text>(find.byKey(_joinedSummaryKey));
        expect(summary.data, '入社済み 1名（社員タブで活動中）');
        expect(
          find.text(joinedApplicant.name),
          findsNothing,
          reason: 'the joined-count summary must never repeat the '
              'applicant\'s own name -- Issue #241 explicitly requires it '
              'never render on 営業 again',
        );
        expect(
          find.byKey(
            const Key('public-demo-sales-applicant-progress-section'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'before anyone has joined, no 入社済み summary line renders at all '
      '-- the fact stays genuinely absent, never a fabricated "0名"',
      (tester) async {
        await _pumpSalesTab(tester, _mayWithOneActiveApplicant());

        expect(find.byKey(_joinedSummaryKey), findsNothing);
      },
    );

    testWidgets(
      'a joined applicant coexisting with a still-active one: the summary '
      'line and the active funnel card both render together, truthfully',
      (tester) async {
        // Build on top of the already-joined fixture by recruiting a fresh
        // June applicant via the real production `recruit` command.
        var aggregate = _juneWithOneJoinedApplicant();
        expect(aggregate.state.month, 6, reason: 'fixture sanity');
        final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
        expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
        aggregate = recruited.aggregate!;
        final newApplicant = aggregate.workflow.applicants.firstWhere(
          (a) => !a.hasJoined,
        );

        await _pumpSalesTab(tester, aggregate);

        final summary = tester.widget<Text>(find.byKey(_joinedSummaryKey));
        expect(summary.data, '入社済み 1名（社員タブで活動中）');
        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.text(newApplicant.name), findsOneWidget);
      },
    );
  });

  group('State integrity: save/reload and duplicate action', () {
    testWidgets(
      'save/reload (toJson -> fromJson) preserves the exact same grouping '
      'and joined summary -- the grouping is purely derived from '
      'already-persisted stage/hasJoined facts, never its own state',
      (tester) async {
        final before = _mayWithActiveAndAwaitingJoinApplicants();
        final reloaded = PublicDemoAggregate.fromJson(before.toJson());

        await _pumpSalesTab(tester, reloaded);

        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.text('$_awaitingHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_closedHeader), findsNothing);
      },
    );

    testWidgets(
      'double tap on スキルシート確認 (duplicate action): the applicant '
      'advances exactly once, stays counted exactly once under 対応が必要, '
      'and no exception is thrown',
      (tester) async {
        await _pumpSalesTab(tester, _mayWithOneActiveApplicant());

        final button = find.text('スキルシート確認');
        await tester.tap(button);
        await tester.pump();
        // A second, rapid tap before the first has settled -- the same
        // duplicate/double-tap shape the task's own verification
        // requirements call out.
        if (tester.any(button)) {
          await tester.tap(button);
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_awaitingHeader), findsNothing);
        expect(find.textContaining(_closedHeader), findsNothing);
      },
    );
  });

  group(
    '360x800 / 390x844, TextScaler 1.0/1.3: grouping headers never overflow',
    () {
      for (final size in const [Size(360, 800), Size(390, 844)]) {
        for (final textScale in [1.0, 1.3]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: active + awaitingJoin headers stay within bounds',
            (tester) async {
              await _pumpSalesTab(
                tester,
                _mayWithActiveAndAwaitingJoinApplicants(),
                size: size,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull);

              for (final text in [
                '$_activeHeader（1名）',
                '$_awaitingHeader（1名）',
              ]) {
                final rect = tester.getRect(find.text(text));
                expect(rect.left, greaterThanOrEqualTo(0.0));
                expect(rect.right, lessThanOrEqualTo(size.width));
              }
            },
          );

          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: 入社済み summary line stays within bounds',
            (tester) async {
              await _pumpSalesTab(
                tester,
                _juneWithOneJoinedApplicant(),
                size: size,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull);

              final rect = tester.getRect(find.byKey(_joinedSummaryKey));
              expect(rect.left, greaterThanOrEqualTo(0.0));
              expect(rect.right, lessThanOrEqualTo(size.width));
            },
          );
        }
      }
    },
  );
}
