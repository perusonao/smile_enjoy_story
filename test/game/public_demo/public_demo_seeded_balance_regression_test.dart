import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_matching_fit.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

import 'test_support/public_demo_seeded_playthrough_bot.dart';

/// CORE-GAMEPLAY Phase 8 (Seeded Balance Verification, Issue #217):
/// deterministic regression coverage for the fixed guardrail seeds the
/// issue names — `0, 1, 42, 13, 666, 315, 2147483000` — plus the
/// seed-independent static facts (initial capabilities, zero-revenue cash
/// runway) the issue's guardrails describe.
///
/// See `docs/reports/SES_CORE-GAMEPLAY_Phase8_Seeded-Balance-Verification_Result.md`
/// for the full analysis (including a broader, non-CI seed sweep via
/// `tool/simulate_public_demo_seeded_balance.dart`) and for which findings
/// here are confirmed VIOLATIONS of the issue's own guardrails (kept as
/// explicit regression locks — not silently "fixed" by rewriting the
/// assertion — rather than balance-formula changes this Issue's own scope
/// ("最小変更に限定する", generator/Matching formulas excluded) does not
/// authorize without a follow-up decision).
void main() {
  group('static guardrail facts (seed-independent, unchanged by this Issue)', () {
    test('Sato (eng-01) starts at capability 78, Suzuki (eng-02) at 52 — '
        'the requirement is 60 (unchanged authored ground truth)', () {
      final sato = publicDemoInitialEngineerRuntimes.firstWhere(
        (r) => r.engineerId == 'eng-01',
      );
      final suzuki = publicDemoInitialEngineerRuntimes.firstWhere(
        (r) => r.engineerId == 'eng-02',
      );
      expect(sato.actualCapability, 78);
      expect(suzuki.actualCapability, 52);
      expect(PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement, 60);
      // Sato clears the field-sales bar immediately; Suzuki starts below
      // it — confirms the issue's own "鈴木 actualSkill 52 / requirement
      // 60" guardrail line is still an accurate description of current
      // data.
      expect(sato.actualCapability, greaterThanOrEqualTo(60));
      expect(suzuki.actualCapability, lessThan(60));
    });

    test('a company with nobody ever assigned (zero revenue every month) '
        'survives on baseline cash through August (5 months) before '
        'entering cashShortage in September and bankruptcy in October — '
        'the issue\'s own "ゼロ売上でも約6か月は耐えられる" guardrail holds', () {
      var aggregate = PublicDemoAggregate.initial();
      final expenses = PublicDemoSalary.baselineMonthlyExpenses;

      aggregate = aggregate.closeApril(monthlyExpenses: expenses); // month 5
      aggregate = aggregate.closeMay(week: 9, monthlyExpenses: expenses); // 6
      aggregate = aggregate.closeJune(assignedInJuly: 0, monthlyExpenses: expenses); // 7
      aggregate = aggregate.closeJuly(monthlyExpenses: expenses); // 8
      expect(aggregate.state.cash, greaterThan(0));
      expect(aggregate.state.financialStatus, PublicDemoFinancialStatus.normal);

      aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: expenses); // August, month 9
      expect(aggregate.state.cash, 0);
      expect(aggregate.state.financialStatus, PublicDemoFinancialStatus.normal);

      aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: expenses); // September
      expect(aggregate.state.cash, lessThan(0));
      expect(aggregate.state.financialStatus, PublicDemoFinancialStatus.cashShortage);

      aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: expenses); // October
      expect(aggregate.state.financialStatus, PublicDemoFinancialStatus.bankruptcy);
      expect(aggregate.state.isCloseBlocked, isTrue);
    });
  });

  group('April Matching-fit guardrail per required seed (CONFIRMED FINDING)', () {
    // "April は初期の実用可能な佐藤に適合する案件が最低1件存在すること" —
    // checked here against the real Phase 5 Matching-fit computation
    // (PublicDemoEngineerProjectFit / PublicDemoSeededProjectGenerator),
    // independent of the generic (pre-Matching) interview path this file's
    // playthrough bot uses — see this file's own class doc and the result
    // report for why both are checked separately.
    //
    // seed 1 is a CONFIRMED VIOLATION: all 4 of its April project
    // candidates rate PublicDemoMatchingProspect.low for Sato — zero
    // "viable" (medium/high) options. This is a real, reproducible,
    // seed-driven (Controlled Randomness) finding — see the result report.
    // Kept here as an exact regression lock (not silently loosened) so a
    // future project-generator change is forced to re-examine this seed
    // rather than pass unnoticed.
    const expectedViableCount = {
      0: 1,
      1: 0, // CONFIRMED VIOLATION of the "at least 1" guardrail.
      42: 3,
      13: 3,
      666: 3,
      315: 1,
      2147483000: 2,
    };

    for (final entry in expectedViableCount.entries) {
      test('seed ${entry.key}: ${entry.value} of April\'s 4 candidates are '
          'non-low prospect for Sato', () {
        final sato = publicDemoInitialEngineerRuntimes.firstWhere(
          (r) => r.engineerId == 'eng-01',
        );
        final candidates = PublicDemoSeededProjectGenerator.forMonth(
          runSeed: entry.key,
          month: 4,
        );
        expect(candidates, hasLength(4));
        final viable = candidates
            .map(
              (c) => PublicDemoEngineerProjectFit.compute(
                runtime: sato,
                project: c.project,
              ),
            )
            .where((fit) => fit.prospect != PublicDemoMatchingProspect.low)
            .length;
        expect(viable, entry.value);
      });
    }
  });

  group('post-May recruitment structural dead end (Issue #221 FIX)', () {
    test('an applicant recruited AFTER May, walked through the entire '
        'hire/pre-entry/order pipeline, now genuinely joins as an engineer '
        'and is staffed at the next month-end close — previously CONFIRMED '
        'as a structural dead end (recruit() after May spent real '
        'cash/sales-slot budget for zero possible return, since '
        'joinAndKeepOnly/assignOrderedForMay only ever ran inside closeMay); '
        'fixed by generalizing the join step to every month-end close (see '
        'PublicDemoAggregate._joinAcceptedApplicants and '
        'PublicDemoWorkflowState.joinAcceptedForFiscalClose)', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 46)
          .closeApril(monthlyExpenses: 10000)
          .closeMay(week: 9, monthlyExpenses: 10000)
          .closeJune(assignedInJuly: 0, monthlyExpenses: 10000)
          .closeJuly(monthlyExpenses: 10000); // month 8 (August)
      final engineersBefore = aggregate.workflow.engineers.length;

      final recruitResult = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);
      expect(recruitResult.isSuccess, isTrue);
      aggregate = recruitResult.aggregate!;
      final applicantId = aggregate.workflow.applicants.first.id;

      final interview = aggregate.completeInterview(applicantId);
      expect(interview.isCompleted, isTrue);
      aggregate = interview.aggregate;
      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == applicantId,
      );
      aggregate = aggregate.acceptOffer(
        applicantId: applicantId,
        offer: PublicDemoSalaryOfferEvaluator.evaluate(
          applicant: applicant,
          offeredMonthlySalary: applicant.requestedMonthlySalary,
        ),
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
      );
      aggregate = aggregate
          .beginPreEntrySkillSheet(applicantId)
          .beginPreEntrySelling(applicantId)
          .introducePreEntryProject(applicantId)
          .recordPreEntryPartnerInterviewResult(applicantId)
          .recordPreEntryClientInterviewResult(applicantId)
          .recordJuneOrder(applicantId);
      final beforeClose = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == applicantId,
      );
      expect(beforeClose.stage, PublicDemoApplicantStage.juneOrdered);
      // The "order" is genuinely won — every real pipeline precondition
      // passed — but joining itself only happens at the next month-end
      // close, exactly like May's own cohort.
      expect(beforeClose.hasJoined, isFalse);
      expect(aggregate.state.joinedApplicantIds, isNot(contains(applicantId)));

      aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
      final joinedApplicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == applicantId,
      );
      expect(joinedApplicant.hasJoined, isTrue);
      expect(aggregate.workflow.engineers, hasLength(engineersBefore + 1));
      expect(
        aggregate.workflow.engineers.any((e) => e.id == applicantId),
        isTrue,
      );
      expect(aggregate.state.joinedApplicantIds, contains(applicantId));
      expect(aggregate.state.engineerCount, engineersBefore + 1);

      // PR #222 review finding: the already-won juneOrdered pre-entry
      // order must survive into a real assignment — not be silently
      // downgraded to a plain waiting engineer who has to redo
      // Sales/Matching/interviews for an order they already earned.
      expect(
        aggregate.workflow.assignments.any((a) => a.engineerId == applicantId),
        isTrue,
      );
      expect(aggregate.state.engineersAssigned, greaterThanOrEqualTo(1));

      // Closing the next ordinary month again re-processes this same
      // already-joined applicant (idempotent — no double-join, no
      // duplicate engineer, no double-counted headcount, no duplicate
      // assignment).
      final retried = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
      expect(
        retried.workflow.engineers.where((e) => e.id == applicantId).length,
        1,
      );
      expect(
        retried.state.joinedApplicantIds.where((id) => id == applicantId).length,
        1,
      );
      expect(
        retried.workflow.assignments
            .where((a) => a.engineerId == applicantId)
            .length,
        1,
      );
    });
  });

  group('monthlyExpenses recomputation regression (Codex P1 fix, PR #218)', () {
    // The bot's first version computed `monthlyExpenses` once, in May,
    // from a PRE-close snapshot of applicants who were still
    // `hasJoined == false` at that moment — `PublicDemoSalary
    // .currentMonthlySalaryFor` requires `hasJoined`, so that snapshot
    // silently contributed ¥0 per hire, and the stale value was then reused
    // unchanged for every month June-March, so no May hire's salary was
    // ever actually deducted. These tests exercise the fix directly
    // against real production `PublicDemoAggregate`/`PublicDemoSalaryFinance`
    // — the exact same formula the bot's own `_monthlyExpensesFor` helper
    // calls, never a bot-authored substitute — independent of the bot's
    // own emergent month-by-month play.
    test('no May hire: the recomputed June expenses equal exactly the '
        'baseline — no phantom hire is ever charged', () {
      final aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          );
      expect(aggregate.workflow.joinedApplicants, isEmpty);
      final juneExpenses = PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: aggregate.workflow.joinedApplicants,
        month: aggregate.state.month,
      );
      expect(juneExpenses, PublicDemoSalary.baselineMonthlyExpenses);
    });

    test('one May hire: joins by closeMay, and the recomputed June expenses '
        'increase by exactly that hire\'s own accepted salary — May\'s own '
        'close itself is unaffected (the hire is not on payroll for the '
        'month they joined)', () {
      // Mirrors the recorded `public_demo_balance_regression_test.dart`
      // runSeed-46 fixture ordering exactly: recruit() in April, THEN
      // closeApril, THEN the interview/offer (now at month 5 — the SAME
      // month closeMay itself will run at). Accepting the offer before
      // closeApril would mint a May applicant against an April
      // PublicDemoFiscalCloseId — stale by the time closeMay checks it,
      // silently failing the join (PublicDemoJoinTransaction.join's own
      // "stale fiscal close" guard) — a real ordering bug this test itself
      // caught in an earlier draft.
      var aggregate = PublicDemoAggregate.initial(runSeed: 46)
          .recruit(PublicDemoRecruitmentMedium.engineer)
          .aggregate!
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses);
      final applicantId = aggregate.workflow.applicants.first.id;
      final interview = aggregate.completeInterview(applicantId);
      expect(interview.isCompleted, isTrue);
      aggregate = interview.aggregate;
      final applicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == applicantId,
      );
      aggregate = aggregate.acceptOffer(
        applicantId: applicantId,
        offer: PublicDemoSalaryOfferEvaluator.evaluate(
          applicant: applicant,
          offeredMonthlySalary: applicant.requestedMonthlySalary,
        ),
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
      );
      aggregate = aggregate.closeMay(
        week: 9,
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      );
      final hire = aggregate.workflow.joinedApplicants.single;
      expect(hire.id, applicantId);
      final juneExpenses = PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: aggregate.workflow.joinedApplicants,
        month: aggregate.state.month,
      );
      expect(
        juneExpenses,
        PublicDemoSalary.baselineMonthlyExpenses + hire.acceptedMonthlySalary!,
      );
      // Matches the already-locked runSeed-46 fixture value in
      // public_demo_balance_regression_test.dart — same hire, same salary.
      expect(juneExpenses, 1120000);
    });

    test('two May hires: both are included in the recomputed expenses', () {
      // See the previous test's own comment: recruit() in April, THEN
      // closeApril, THEN interview/offer at month 5 — never accept an
      // offer before closeApril, or its PublicDemoFiscalCloseId goes stale
      // by the time closeMay checks it.
      var aggregate = PublicDemoAggregate.initial(runSeed: 46)
          .recruit(PublicDemoRecruitmentMedium.engineer)
          .aggregate!
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses);
      for (final applicantId in aggregate.workflow.applicants
          .map((candidate) => candidate.id)
          .toList()) {
        final interview = aggregate.completeInterview(applicantId);
        expect(interview.isCompleted, isTrue);
        aggregate = interview.aggregate;
        final applicant = aggregate.workflow.applicants.firstWhere(
          (candidate) => candidate.id == applicantId,
        );
        final offer = PublicDemoSalaryOfferEvaluator.evaluate(
          applicant: applicant,
          offeredMonthlySalary: applicant.requestedMonthlySalary,
        );
        expect(offer.accepted, isTrue, reason: applicantId);
        aggregate = aggregate.acceptOffer(
          applicantId: applicantId,
          offer: offer,
          fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
        );
      }
      aggregate = aggregate.closeMay(
        week: 9,
        monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
      );
      expect(aggregate.workflow.joinedApplicants, hasLength(2));
      final juneExpenses = PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: aggregate.workflow.joinedApplicants,
        month: aggregate.state.month,
      );
      final expectedTotal = PublicDemoSalary.baselineMonthlyExpenses +
          aggregate.workflow.joinedApplicants
              .fold<int>(0, (sum, a) => sum + a.acceptedMonthlySalary!);
      expect(juneExpenses, expectedTotal);
      expect(juneExpenses, 1530000); // 800000 baseline + 320000 + 410000
    });

    test('an applicant whose offer is never accepted contributes nothing '
        'to the recomputed expenses (never joins)', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 46)
          .recruit(PublicDemoRecruitmentMedium.engineer)
          .aggregate!
          .closeApril(monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses)
          .closeMay(
            week: 9,
            monthlyExpenses: PublicDemoSalary.baselineMonthlyExpenses,
          );
      expect(aggregate.workflow.joinedApplicants, isEmpty);
      final juneExpenses = PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: aggregate.workflow.joinedApplicants,
        month: aggregate.state.month,
      );
      expect(juneExpenses, PublicDemoSalary.baselineMonthlyExpenses);
    });
  });

  group('required-seed playthrough (deterministic bot, reproducibility)', () {
    const requiredSeeds = [0, 1, 42, 13, 666, 315, 2147483000];

    for (final seed in requiredSeeds) {
      test('seed $seed: the seeded bot playthrough is byte-identical on a '
          'second run', () {
        final first = PublicDemoSeededPlaythroughBot.run(seed);
        final second = PublicDemoSeededPlaythroughBot.run(seed);
        expect(
          second.finalAggregate.toJson().toString(),
          first.finalAggregate.toJson().toString(),
        );
        expect(second.cashByMonth, first.cashByMonth);
        expect(second.reachedMarch, first.reachedMarch);
        expect(second.terminalStatus, first.terminalStatus);
      });
    }

    // Exact per-seed outcomes, locked as a characterization/regression
    // test (CORE-GAMEPLAY Phase 7A/7B/Recovery/Growth/Finance formulas are
    // all unchanged by this Issue — see the result report). Re-measured
    // after the Codex P1 fix (PR #218: monthlyExpenses now recomputed every
    // month from the real, authoritative joinedApplicants roster) — every
    // figure here changed from the pre-fix version of this file, because
    // the pre-fix numbers never actually deducted a May hire's salary.
    //
    // Re-measured again for Issue #223 (FIRST-FUN-YEAR Seeded Balance Fix):
    // PublicDemoRevenue.ratePerAssignedEngineer (500,000 -> 600,000) and
    // PublicDemoGrowthEngine's internal-training rate (1.2 -> 2.0) both
    // change every figure below — 6 of the 7 required seeds now reach March
    // with this bot's own single ("always recruit once in May, train any
    // under-threshold waiting engineer, accept every generic-path order")
    // policy, up from 1 of 7 before this Issue's tuning. See
    // docs/reports/SES_FIRST-FUN-YEAR_Seeded-Balance-Fix_Result.md for the
    // full before/after rationale and the additional Balanced/Growth/Poor-
    // decisions strategy comparison this Issue's new
    // `PublicDemoStrategyBot` harness provides. A future balance change to
    // Phase 7A/7B/Recovery/Growth/Finance is expected to change these
    // numbers again; when it does, re-run
    // `tool/simulate_public_demo_seeded_balance.dart` and this file
    // together and update both intentionally, never one without
    // re-examining the other.
    const expected = {
      0: (reachedMarch: true, terminal: null, joinedInMay: 1, finalCash: 920000),
      1: (reachedMarch: true, terminal: null, joinedInMay: 2, finalCash: 2370000),
      42: (reachedMarch: true, terminal: null, joinedInMay: 2, finalCash: 1770000),
      13: (reachedMarch: true, terminal: null, joinedInMay: 1, finalCash: 6280000),
      666: (reachedMarch: true, terminal: null, joinedInMay: 1, finalCash: 480000),
      315: (reachedMarch: true, terminal: null, joinedInMay: 2, finalCash: 2930000),
      2147483000: (
        reachedMarch: false,
        terminal: PublicDemoFinancialStatus.bankruptcy,
        joinedInMay: 2,
        finalCash: -720000,
      ),
    };

    for (final entry in expected.entries) {
      final seed = entry.key;
      final e = entry.value;
      test('seed $seed: reachedMarch=${e.reachedMarch} '
          'terminal=${e.terminal} joinedInMay=${e.joinedInMay} '
          'finalCash=${e.finalCash}', () {
        final result = PublicDemoSeededPlaythroughBot.run(seed);
        expect(result.reachedMarch, e.reachedMarch);
        expect(result.terminalStatus, e.terminal);
        expect(result.engineersJoinedInMay, e.joinedInMay);
        expect(result.finalAggregate.state.cash, e.finalCash);
      });
    }

    test('April and May cash are identical across every required seed — '
        'the seeded bot policy never lets a founding engineer\'s April/May '
        'order outcome depend on runSeed (the generic interview path scores '
        'purely from the engineer\'s own fixed profile/capability, never '
        'project data) — see the result report\'s scope note on this', () {
      for (final seed in requiredSeeds) {
        final result = PublicDemoSeededPlaythroughBot.run(seed);
        expect(result.cashByMonth[4], 3170000, reason: 'seed $seed month 4');
        expect(result.cashByMonth[5], 2240000, reason: 'seed $seed month 5');
      }
    });

    test('Sato (eng-01) never has a no-order month in any required seed — '
        'the generic-path partner+client interview always passes '
        'immediately in April given the fixed founding profile', () {
      for (final seed in requiredSeeds) {
        final result = PublicDemoSeededPlaythroughBot.run(seed);
        expect(
          result.longestNoOrderStreak('eng-01'),
          0,
          reason: 'seed $seed',
        );
      }
    });

    test('Suzuki (eng-02) has exactly a 4-month no-order streak in every '
        'required seed — Issue #223\'s internal-training-rate fix (1.2 -> '
        '2.0, see PublicDemoGrowthEngine) RESOLVES the previously-confirmed '
        'violation of the issue\'s own "5か月連続no-orderは実質的に禁止" '
        'guardrail (every required seed used to show >=6, and up to the '
        'full 8-month structural minimum). Seed-INDEPENDENT (Suzuki\'s path '
        'never touches the seeded project/recruitment generators at all — '
        'only the deterministic training-growth formula: growthPotential:4 '
        '-> +2 capability/month -> exactly 4 monthly training purchases '
        'crosses the 52->60 field-sales bar), and now uniform across every '
        'required seed because every one of them also reaches March (see '
        'the required-seed table above) — the streak is never truncated by '
        'an early bankruptcy for this bot\'s policy anymore. See '
        'docs/reports/SES_FIRST-FUN-YEAR_Seeded-Balance-Fix_Result.md for '
        'the full before/after analysis.', () {
      for (final seed in requiredSeeds) {
        final result = PublicDemoSeededPlaythroughBot.run(seed);
        expect(
          result.longestNoOrderStreak('eng-02'),
          4,
          reason: 'seed $seed',
        );
      }
    });
  });
}
