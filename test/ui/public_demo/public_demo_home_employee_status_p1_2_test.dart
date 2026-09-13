// SES First Fun Quarter AI Replay Audit #2 P1-2 Fresh Audit fix.
//
// Repro: an applicant who joins already carrying a pre-entry order (the
// real `preEntryPartnerPassed -> preEntryClientPassed -> juneOrdered ->
// closeMay` path) becomes an engineer at `PublicDemoSalesStage.waiting`
// (`PublicDemoEngineerSales.fromApplicant` never inherits the applicant's
// own pipeline stage) in the very same close that
// `PublicDemoWorkflowState.assignOrderedForMay` also adds them to the
// assignment roster. HOME's `_officeStageStatusFor` only special-cased
// `stage == ordered`, so this genuinely-participating new joiner fell
// through to the stale raw `engineerStatus` label (待機) there, while the
// 社員 tab's own 参画中案件 section (gated purely on assignment membership,
// never `stage`) already showed 参画中 for the same person.
//
// This suite drives the real production pipeline (recruit/interview/offer/
// pre-entry sales/closeMay -- no fabricated applicant/engineer/assignment
// is ever constructed directly) and proves HOME and 社員 read the same
// authoritative fact and agree, at the exact month boundary the repro
// describes, and that this holds across save/reload and does not regress
// the one other real "waiting but currently assigned" case (an assignment
// ended mid-month).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
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

/// `runSeed` 2's real `engineer`-medium May candidate, driven through the
/// genuine pre-entry sales pipeline to a real order and joined at closeMay
/// -- confirmed (never asserted to) that this seed's real partner/client
/// interviews both pass, landing the applicant at `juneOrdered` before
/// `closeMay` joins them and `assignOrderedForMay` assigns them, all inside
/// that same close.
({PublicDemoAggregate aggregate, String engineerId})
_juneWithOneJoinedAndAssignedEngineer() {
  var aggregate = PublicDemoAggregate.initial(
    runSeed: 2,
  ).closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses);
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  aggregate = recruited.aggregate!;
  final applicantId = aggregate.workflow.applicants.first.id;
  aggregate = aggregate.completeInterview(applicantId).aggregate;
  final applicant = aggregate.workflow.applicants.first;
  aggregate = aggregate.acceptOffer(
    applicantId: applicantId,
    offer: PublicDemoSalaryOffer(
      requestedMonthlySalary: applicant.requestedMonthlySalary,
      offeredMonthlySalary: applicant.requestedMonthlySalary,
      acceptanceScore: 100,
      motivationDelta: 0,
      trustDelta: 0,
    ),
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
  );
  aggregate = aggregate.beginPreEntrySkillSheet(applicantId);
  aggregate = aggregate.beginPreEntrySelling(applicantId);
  aggregate = aggregate.introducePreEntryProject(applicantId);
  aggregate = aggregate.recordPreEntryPartnerInterviewResult(applicantId);
  aggregate = aggregate.recordPreEntryClientInterviewResult(applicantId);
  aggregate = aggregate.recordJuneOrder(applicantId);
  final ordered = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == applicantId,
  );
  expect(
    ordered.stage.name,
    'juneOrdered',
    reason: 'fixture sanity: runSeed 2 must genuinely pass both real '
        'pre-entry interviews, not be asserted to',
  );

  aggregate = aggregate.closeMay(
    week: 9,
    monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
  );
  expect(aggregate.state.month, 6, reason: 'fixture sanity');
  final joined = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == applicantId,
  );
  expect(joined.hasJoined, isTrue, reason: 'fixture sanity');
  final engineer = aggregate.workflow.engineers.firstWhere(
    (e) => e.id == applicantId,
  );
  expect(
    engineer.stage,
    PublicDemoSalesStage.waiting,
    reason: 'fixture sanity: the exact "joined at waiting despite a real '
        'order" case this fix is about',
  );
  expect(
    aggregate.workflow.assignedEngineerIds(month: 6),
    contains(applicantId),
    reason: 'fixture sanity: genuinely counted as participating this month',
  );
  return (aggregate: aggregate, engineerId: applicantId);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String? _homeOfficeStageStatusFor(WidgetTester tester, String engineerId) {
  final finder = find.byKey(
    ValueKey('home-office-stage-status-$engineerId'),
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).data;
}

void main() {
  testWidgets(
    'join + assignment (month boundary): a June-viewed, May-end joined '
    'applicant who already won a pre-entry order reads 参画中 on HOME -- not '
    '待機 -- matching 社員\'s own 参画中案件 card for the same person',
    (tester) async {
      final fixture = _juneWithOneJoinedAndAssignedEngineer();
      final aggregate = fixture.aggregate;
      final engineerId = fixture.engineerId;
      await _pumpScreen(tester, aggregate);

      await switchPublicDemoTab(tester, PublicDemoTab.home);
      final homeStatus = _homeOfficeStageStatusFor(tester, engineerId);
      expect(
        homeStatus,
        '参画中',
        reason: 'HOME must read the same assignment-membership fact 社員 '
            'already does, not the stale stage==ordered-only check',
      );

      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(
        find.descendant(
          of: find.byKey(Key('public-demo-employee-roster-row-$engineerId')),
          matching: find.text('参画中'),
        ),
        findsOneWidget,
        reason: "社員's own roster row must agree",
      );
      // The 参画中案件 card (gated purely on assignment membership) already
      // showed this correctly before this fix -- still true, not just the
      // roster row above.
      expect(
        find.byKey(Key('public-demo-active-project-status-$engineerId')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'save/reload: the same 参画中 status survives a toJson/fromJson round '
    'trip on both HOME and 社員 -- nothing here is recomputed differently on '
    'reload',
    (tester) async {
      final fixture = _juneWithOneJoinedAndAssignedEngineer();
      final reloaded = PublicDemoAggregate.fromJson(fixture.aggregate.toJson());
      final engineerId = fixture.engineerId;
      await _pumpScreen(tester, reloaded);

      await switchPublicDemoTab(tester, PublicDemoTab.home);
      expect(_homeOfficeStageStatusFor(tester, engineerId), '参画中');

      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(
        find.descendant(
          of: find.byKey(Key('public-demo-employee-roster-row-$engineerId')),
          matching: find.text('参画中'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'assignment終了/待機復帰 regression guard: an `ordered` engineer whose '
    'assignment is ended mid-month while this month\'s revenue still counts '
    'them reads 待機 (not a stale 参画中) on BOTH HOME and 社員 -- the fix '
    'must not resurrect the case its own resolver doc already protects '
    'against',
    (tester) async {
      // 佐藤健 (runSeed 1's first founding engineer) deterministically clears
      // both real interviews and wins an order.
      var aggregate = PublicDemoAggregate.initial(
        runSeed: 1,
      ).closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses);
      final engineerId = aggregate.workflow.engineers.first.id;
      aggregate = aggregate.startSkillSheetReview(engineerId);
      aggregate = aggregate.beginSelling(engineerId);
      aggregate = aggregate.introduceProject(engineerId);
      aggregate = aggregate.recordEngineerInterviewResult(
        engineerId: engineerId,
        type: PublicDemoInterviewType.partner,
      );
      aggregate = aggregate.recordEngineerInterviewResult(
        engineerId: engineerId,
        type: PublicDemoInterviewType.client,
      );
      aggregate = aggregate.recordOrder(engineerId);
      final ordered = aggregate.workflow.engineers.firstWhere(
        (e) => e.id == engineerId,
      );
      expect(ordered.stage, PublicDemoSalesStage.ordered, reason: 'fixture sanity');

      // `assignOrderedForMay` (and therefore the real `PublicDemoAssignment`
      // row `withAssignmentUpdate`/`endAssignment` both need) only
      // materializes at month-end close -- closes May so June (still < 7,
      // the exact pre-July "row kept" window this case is about) has a real
      // assignment row to act on.
      aggregate = aggregate.closeMay(
        week: 9,
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      );
      expect(aggregate.state.month, 6, reason: 'fixture sanity');

      // Ends the assignment before month 7 -- endAssignment's own
      // precondition ("nextOrderStatus == notOffered") is required first.
      aggregate = aggregate.withAssignmentUpdate(
        engineerId,
        nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
      );
      aggregate = aggregate.endAssignment(engineerId);
      final released = aggregate.workflow.engineers.firstWhere(
        (e) => e.id == engineerId,
      );
      expect(
        released.stage,
        PublicDemoSalesStage.waiting,
        reason: 'fixture sanity: released back to waiting',
      );
      expect(
        aggregate.workflow.assignedEngineerIds(month: aggregate.state.month),
        contains(engineerId),
        reason: 'fixture sanity: still counted this month per '
            'endAssignment\'s own documented pre-July behavior',
      );

      await _pumpScreen(tester, aggregate);
      await switchPublicDemoTab(tester, PublicDemoTab.home);
      expect(
        _homeOfficeStageStatusFor(tester, engineerId),
        isNot('参画中'),
        reason: 'a released engineer must never show a stale 参画中 on HOME',
      );

      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(
        find.descendant(
          of: find.byKey(Key('public-demo-employee-roster-row-$engineerId')),
          matching: find.text('参画中'),
        ),
        findsNothing,
      );
    },
  );
}
