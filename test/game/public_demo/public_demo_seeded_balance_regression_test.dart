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

  group('post-May recruitment structural dead end (CONFIRMED FINDING)', () {
    test('an applicant recruited AFTER May can be walked through the '
        'entire hire/pre-entry/order pipeline to juneOrdered, but never '
        'joins as an engineer and is never staffed — recruit() after May '
        'spends real cash/sales-slot budget for zero possible return '
        '(see the result report for the root cause: joinAndKeepOnly / '
        'assignOrderedForMay only ever run inside closeMay)', () {
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
      final finalApplicant = aggregate.workflow.applicants.firstWhere(
        (candidate) => candidate.id == applicantId,
      );
      expect(finalApplicant.stage, PublicDemoApplicantStage.juneOrdered);
      // The "order" is genuinely won — every real pipeline precondition
      // passed — yet:
      expect(finalApplicant.hasJoined, isFalse);

      aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
      expect(aggregate.workflow.engineers, hasLength(engineersBefore));
      expect(aggregate.workflow.assignments, isEmpty);
      expect(
        aggregate.workflow.applicants
            .firstWhere((candidate) => candidate.id == applicantId)
            .stage,
        PublicDemoApplicantStage.juneOrdered, // frozen forever — never joins
      );
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
    // all unchanged by this Issue — see the result report). A future
    // balance change to any of those is expected to change these numbers;
    // when it does, re-run `tool/simulate_public_demo_seeded_balance.dart`
    // and this file together and update both intentionally, never one
    // without re-examining the other.
    const expected = {
      0: (reachedMarch: true, terminal: null, joinedInMay: 1, finalCash: 470000),
      1: (reachedMarch: true, terminal: null, joinedInMay: 2, finalCash: 4260000),
      42: (reachedMarch: true, terminal: null, joinedInMay: 2, finalCash: 4260000),
      13: (reachedMarch: true, terminal: null, joinedInMay: 1, finalCash: 5060000),
      666: (
        reachedMarch: false,
        terminal: PublicDemoFinancialStatus.bankruptcy,
        joinedInMay: 1,
        finalCash: -20000,
      ),
      315: (reachedMarch: true, terminal: null, joinedInMay: 2, finalCash: 4760000),
      2147483000: (
        reachedMarch: false,
        terminal: PublicDemoFinancialStatus.bankruptcy,
        joinedInMay: 2,
        finalCash: -400000,
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

    test('Suzuki (eng-02) has an 8-month no-order streak in every required '
        'seed (April through November) before training-driven Growth '
        'finally clears the field-sales/client-interview threshold — a '
        'CONFIRMED VIOLATION of the issue\'s own "5か月連続no-orderは実質的に '
        '禁止" guardrail, and seed-INDEPENDENT (Suzuki\'s path never '
        'touches the seeded project/recruitment generators at all — only '
        'the deterministic training-growth formula). See the result '
        'report for the root-cause analysis and recommended follow-up.', () {
      for (final seed in requiredSeeds) {
        final result = PublicDemoSeededPlaythroughBot.run(seed);
        expect(
          result.longestNoOrderStreak('eng-02'),
          8,
          reason: 'seed $seed',
        );
      }
    });
  });
}
