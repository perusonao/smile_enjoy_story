// SES First Fun Quarter P1-2 (Issue #122 Fresh Audit — "採用面談→条件提示→
// 承諾後、翌月入社まで人物が消えないようにする"): coverage for the 社員タブ's
// new 入社予定 section (`_pendingJoinRosterSection`/`_pendingJoinCard`).
//
// Every fixture here drives the exact same production commands the
// domain suite (`public_demo_post_may_join_lifecycle_test.dart`) already
// exercises — `recruit` → `completeInterview` → `acceptOffer` → the
// pre-entry sales chain (`beginPreEntrySkillSheet` →
// `beginPreEntrySelling` → `introducePreEntryProject` →
// `recordPreEntryPartnerInterviewResult` →
// `recordPreEntryClientInterviewResult` → `recordJuneOrder`) — never a
// hand-built applicant record. That chain always lands the applicant in
// one of `juneOrdered`/`preEntryPartnerFailed`/`preEntryClientFailed`
// regardless of the (seed-dependent) pass/fail outcome at each step, all
// three of which `_applicantLifecycleBucket` already buckets as
// `awaitingJoin` — the same bucket the 採用 tab's own "結果待ち・入社予定"
// group reads, so this section is a second read-only view of that
// existing authority, never a new candidate/employee record.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

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

/// Mirrors `public_demo_post_may_join_lifecycle_test.dart`'s own
/// `recruitAndAccept` fixture exactly: recruits via the real `engineer`
/// medium, interviews, and accepts a deliberately hand-built
/// `acceptanceScore: 100` offer so this fixture always accepts regardless
/// of the generated applicant's own seed-dependent acceptanceScore.
({PublicDemoAggregate aggregate, String applicantId}) recruitAndAccept(
  PublicDemoAggregate aggregate,
) {
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);
  expect(recruited.isSuccess, isTrue);
  var next = recruited.aggregate!;
  final applicantId = next.workflow.applicants.first.id;
  final interview = next.completeInterview(applicantId);
  expect(interview.isCompleted, isTrue);
  next = interview.aggregate;
  final applicant = next.workflow.applicants.firstWhere(
    (candidate) => candidate.id == applicantId,
  );
  final offer = PublicDemoSalaryOffer(
    requestedMonthlySalary: applicant.requestedMonthlySalary,
    offeredMonthlySalary: applicant.requestedMonthlySalary,
    acceptanceScore: 100,
    motivationDelta: 0,
    trustDelta: 0,
  );
  final beforeAccept = next.state.month;
  next = next.acceptOffer(
    applicantId: applicantId,
    offer: offer,
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(beforeAccept),
  );
  final accepted = next.workflow.applicants.firstWhere(
    (candidate) => candidate.id == applicantId,
  );
  expect(
    accepted.stage,
    PublicDemoApplicantStage.offerAccepted,
    reason: 'acceptanceScore: 100 must always accept',
  );
  return (aggregate: next, applicantId: applicantId);
}

/// Walks [applicantId] through the pre-entry pipeline — always lands in
/// `juneOrdered`/`preEntryPartnerFailed`/`preEntryClientFailed`
/// regardless of pass/fail, all three of which `_applicantLifecycleBucket`
/// already buckets as `awaitingJoin`.
PublicDemoAggregate walkPreEntryChain(
  PublicDemoAggregate aggregate,
  String applicantId,
) => aggregate
    .beginPreEntrySkillSheet(applicantId)
    .beginPreEntrySelling(applicantId)
    .introducePreEntryProject(applicantId)
    .recordPreEntryPartnerInterviewResult(applicantId)
    .recordPreEntryClientInterviewResult(applicantId)
    .recordJuneOrder(applicantId);

/// Builds a May-accepted, pre-entry-chain-walked applicant — genuinely in
/// the `awaitingJoin` bucket at month 5 (May), one month before joining at
/// `closeMay`.
({PublicDemoAggregate aggregate, String applicantId}) awaitingJoinFixture() {
  var aggregate = PublicDemoAggregate.initial().closeApril(
    monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
  );
  final hired = recruitAndAccept(aggregate);
  aggregate = walkPreEntryChain(hired.aggregate, hired.applicantId);
  return (aggregate: aggregate, applicantId: hired.applicantId);
}

Future<void> pumpEmployeesTabAt(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
}

void main() {
  testWidgets(
    '内定承諾済み・pre-entry sales中の応募者は、社員タブの「入社予定」セクションに'
    '「6月入社予定」として表示され、消えない',
    (tester) async {
      final fixture = awaitingJoinFixture();
      final applicant = fixture.aggregate.workflow.applicants.firstWhere(
        (a) => a.id == fixture.applicantId,
      );
      expect(applicant.hasJoined, isFalse);

      await pumpEmployeesTabAt(tester, fixture.aggregate);

      expect(
        find.byKey(const Key('public-demo-employee-pending-join-section')),
        findsOneWidget,
      );
      final rowKey = Key(
        'public-demo-employee-pending-join-row-${fixture.applicantId}',
      );
      expect(find.byKey(rowKey), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(rowKey), matching: find.text(applicant.name)),
        findsOneWidget,
      );
      // Accepted in May (month 5); the next month-end close is June (6) —
      // states the specific month, not just a generic "入社予定".
      expect(
        find.descendant(
          of: find.byKey(rowKey),
          matching: find.text('6月入社予定'),
        ),
        findsOneWidget,
      );

      // This applicant has not joined yet, so they must not already appear
      // on the technician roster (Section 1) — the two sections must never
      // double-count the same person.
      expect(
        find.byKey(
          Key('public-demo-employee-roster-row-${fixture.applicantId}'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    '月次締め（closeMay）で入社すると、「入社予定」セクションから消え、'
    '社員一覧（Section 1）に現れる（月境界）',
    (tester) async {
      final fixture = awaitingJoinFixture();
      final closed = fixture.aggregate.closeMay(
        week: 9,
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      );
      final joined = closed.workflow.applicants.firstWhere(
        (a) => a.id == fixture.applicantId,
      );
      expect(joined.hasJoined, isTrue);
      expect(
        closed.workflow.engineers.any((e) => e.id == fixture.applicantId),
        isTrue,
      );

      await pumpEmployeesTabAt(tester, closed);

      expect(
        find.byKey(
          Key('public-demo-employee-pending-join-row-${fixture.applicantId}'),
        ),
        findsNothing,
        reason: 'a joined applicant must not still render as 入社予定',
      );
      expect(
        find.byKey(
          Key('public-demo-employee-roster-row-${fixture.applicantId}'),
        ),
        findsOneWidget,
        reason: 'the same person must now appear on the technician roster',
      );
    },
  );

  test(
    '重複締め（closeMayを2回）しても二重入社にならない（idempotent close）',
    () {
      final fixture = awaitingJoinFixture();
      final closedOnce = fixture.aggregate.closeMay(
        week: 9,
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      );
      final closedTwice = closedOnce.closeMay(
        week: 9,
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      );
      expect(
        closedTwice.workflow.engineers
            .where((e) => e.id == fixture.applicantId)
            .length,
        1,
        reason: 'a retried month close must never double-join the same '
            'applicant',
      );
    },
  );

  testWidgets(
    'save/reload（toJson/fromJson往復）後も「入社予定」の表示が正しく復元される',
    (tester) async {
      final fixture = awaitingJoinFixture();
      final reloaded = PublicDemoAggregate.fromJson(fixture.aggregate.toJson());

      await pumpEmployeesTabAt(tester, reloaded);

      expect(
        find.byKey(
          Key('public-demo-employee-pending-join-row-${fixture.applicantId}'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            Key('public-demo-employee-pending-join-row-${fixture.applicantId}'),
          ),
          matching: find.text('6月入社予定'),
        ),
        findsOneWidget,
      );
    },
  );

  for (final size in [const Size(360, 800), const Size(390, 844)]) {
    testWidgets(
      '入社予定セクション・社員一覧の営業可能/研修が必要サマリーは '
      '${size.width.toInt()}x${size.height.toInt()} でoverflowしない',
      (tester) async {
        final fixture = awaitingJoinFixture();
        await pumpEmployeesTabAt(tester, fixture.aggregate, size: size);

        expect(
          find.byKey(const Key('public-demo-employee-pending-join-section')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('public-demo-employee-roster-readiness-summary'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
