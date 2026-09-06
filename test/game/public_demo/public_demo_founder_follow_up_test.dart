import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_founder_follow_up.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';

/// Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1 tests: the founder
/// follow-up decision for a founding engineer who has been continuously
/// assigned through the August-February stretch the full-year playtest
/// audit (PR #164) found became a passive month-advance loop.
void main() {
  /// Builds a [PublicDemoWorkflowState] with `eng-01` genuinely assigned and
  /// accepted for July onward — directly via the same named, precondition-
  /// gated transitions production code uses (mirrors
  /// public_demo_workflow_state_test.dart's own fixture style), never a
  /// reconstruction shortcut.
  PublicDemoWorkflowState assignedWorkflow({String engineerId = 'eng-01'}) =>
      PublicDemoWorkflowState.initial()
          .startSkillSheetReview(engineerId)
          .beginSelling(engineerId)
          .introduceProject(engineerId)
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.partner,
            actualCapability: 90,
          )
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.client,
            actualCapability: 90,
          )
          .recordOrder(engineerId)
          .assignOrderedForMay()
          .withAssignmentUpdate(
            engineerId,
            nextOrderStatus: PublicDemoNextOrderStatus.accepted,
          );

  group('PublicDemoFounderFollowUp.isEligible — trigger conditions', () {
    test('a founding engineer, assigned, in window, undecided is eligible', () {
      final workflow = assignedWorkflow();
      final engineer = workflow.engineers.firstWhere((e) => e.id == 'eng-01');
      for (final month in [8, 9, 10, 11, 12, 13, 14]) {
        expect(
          PublicDemoFounderFollowUp.isEligible(
            engineer: engineer,
            month: month,
            assignedEngineerIds: workflow.assignedEngineerIds(month: month),
          ),
          isTrue,
          reason: 'month $month should be inside the eligible window',
        );
      }
    });
  });

  group('PublicDemoFounderFollowUp.isEligible — non-trigger conditions', () {
    test('outside the August-February window is never eligible', () {
      final workflow = assignedWorkflow();
      final engineer = workflow.engineers.firstWhere((e) => e.id == 'eng-01');
      for (final month in [4, 5, 6, 7, 15]) {
        expect(
          PublicDemoFounderFollowUp.isEligible(
            engineer: engineer,
            month: month,
            assignedEngineerIds: workflow.assignedEngineerIds(month: month),
          ),
          isFalse,
          reason: 'month $month is outside the eligible window',
        );
      }
    });

    test('a non-founding engineer (a later hire) is never eligible', () {
      const hire = PublicDemoEngineerSales(
        id: 'post-join-hire',
        name: 'Post Join Hire',
        summary: 'Java 2年',
        interviewProfile: PublicDemoInterviewProfile(
          skillFit: 80,
          humanity: 70,
          morale: 70,
          clientTrust: 60,
        ),
      );
      expect(
        PublicDemoFounderFollowUp.isEligible(
          engineer: hire,
          month: 9,
          assignedEngineerIds: {'post-join-hire'},
        ),
        isFalse,
      );
    });

    test('an engineer not currently assigned is never eligible', () {
      final workflow = PublicDemoWorkflowState.initial();
      final engineer = workflow.engineers.firstWhere((e) => e.id == 'eng-01');
      expect(
        PublicDemoFounderFollowUp.isEligible(
          engineer: engineer,
          month: 9,
          assignedEngineerIds: const {},
        ),
        isFalse,
      );
    });

    test('already decided this fiscal year is never eligible again', () {
      final workflow = assignedWorkflow();
      final decided = workflow.applyFounderFollowUpDecision(
        'eng-01',
        month: 9,
        decision: PublicDemoFounderFollowUpDecision.checkIn,
      );
      final engineer = decided.engineers.firstWhere((e) => e.id == 'eng-01');
      expect(engineer.founderFollowUpMonth, 9);
      for (final month in [9, 10, 14]) {
        expect(
          PublicDemoFounderFollowUp.isEligible(
            engineer: engineer,
            month: month,
            assignedEngineerIds: decided.assignedEngineerIds(month: month),
          ),
          isFalse,
        );
      }
    });
  });

  group('PublicDemoFounderFollowUp choice trade-offs', () {
    test('holdBack is free but costs mental/trust', () {
      expect(
        PublicDemoFounderFollowUp.costFor(
          PublicDemoFounderFollowUpDecision.holdBack,
        ),
        0,
      );
      expect(
        PublicDemoFounderFollowUp.mentalDeltaFor(
          PublicDemoFounderFollowUpDecision.holdBack,
        ),
        lessThan(0),
      );
      expect(
        PublicDemoFounderFollowUp.trustDeltaFor(
          PublicDemoFounderFollowUpDecision.holdBack,
        ),
        lessThan(0),
      );
    });

    test('checkIn is free and modestly positive', () {
      expect(
        PublicDemoFounderFollowUp.costFor(
          PublicDemoFounderFollowUpDecision.checkIn,
        ),
        0,
      );
      expect(
        PublicDemoFounderFollowUp.mentalDeltaFor(
          PublicDemoFounderFollowUpDecision.checkIn,
        ),
        greaterThan(0),
      );
    });

    test('investSupport costs cash but is the strongest improvement', () {
      expect(
        PublicDemoFounderFollowUp.costFor(
          PublicDemoFounderFollowUpDecision.investSupport,
        ),
        PublicDemoFounderFollowUp.investSupportCost,
      );
      expect(
        PublicDemoFounderFollowUp.costFor(
          PublicDemoFounderFollowUpDecision.investSupport,
        ),
        greaterThan(0),
      );
      expect(
        PublicDemoFounderFollowUp.mentalDeltaFor(
          PublicDemoFounderFollowUpDecision.investSupport,
        ),
        greaterThan(
          PublicDemoFounderFollowUp.mentalDeltaFor(
            PublicDemoFounderFollowUpDecision.checkIn,
          ),
        ),
      );
      expect(
        PublicDemoFounderFollowUp.trustDeltaFor(
          PublicDemoFounderFollowUpDecision.investSupport,
        ),
        greaterThan(
          PublicDemoFounderFollowUp.trustDeltaFor(
            PublicDemoFounderFollowUpDecision.checkIn,
          ),
        ),
      );
    });

    test('every decision explains a distinct reason', () {
      final reasons = PublicDemoFounderFollowUpDecision.values
          .map(PublicDemoFounderFollowUp.reasonFor)
          .toSet();
      expect(reasons, hasLength(PublicDemoFounderFollowUpDecision.values.length));
    });
  });

  group('PublicDemoWorkflowState.applyFounderFollowUpDecision', () {
    test('applies the mental/trust delta and sets the one-time guard', () {
      final workflow = assignedWorkflow();
      final before = workflow.engineers.firstWhere((e) => e.id == 'eng-01');
      final next = workflow.applyFounderFollowUpDecision(
        'eng-01',
        month: 9,
        decision: PublicDemoFounderFollowUpDecision.investSupport,
      );
      final after = next.engineers.firstWhere((e) => e.id == 'eng-01');
      expect(after.mental, before.mental + 6);
      expect(after.trust, before.trust + 5);
      expect(after.founderFollowUpMonth, 9);
      // Every other engineer is untouched.
      expect(
        next.engineers.firstWhere((e) => e.id == 'eng-02'),
        workflow.engineers.firstWhere((e) => e.id == 'eng-02'),
      );
    });

    test('clamps mental/trust to [0, 100]', () {
      final workflow = assignedWorkflow();
      final lowered = PublicDemoWorkflowState(
        applicants: workflow.applicants,
        engineers: [
          for (final engineer in workflow.engineers)
            if (engineer.id == 'eng-01')
              engineer.copyWith(mental: 1, trust: 1)
            else
              engineer,
        ],
      ).assignOrderedForMay().withAssignmentUpdate(
        'eng-01',
        nextOrderStatus: PublicDemoNextOrderStatus.accepted,
      );
      final next = lowered.applyFounderFollowUpDecision(
        'eng-01',
        month: 9,
        decision: PublicDemoFounderFollowUpDecision.holdBack,
      );
      expect(next.engineers.firstWhere((e) => e.id == 'eng-01').mental, 0);
      expect(next.engineers.firstWhere((e) => e.id == 'eng-01').trust, 0);
    });

    test('a second decision this fiscal year is a no-op (one-time guard)', () {
      final workflow = assignedWorkflow();
      final once = workflow.applyFounderFollowUpDecision(
        'eng-01',
        month: 9,
        decision: PublicDemoFounderFollowUpDecision.checkIn,
      );
      final twice = once.applyFounderFollowUpDecision(
        'eng-01',
        month: 10,
        decision: PublicDemoFounderFollowUpDecision.investSupport,
      );
      final onceEngineer = once.engineers.firstWhere((e) => e.id == 'eng-01');
      final twiceEngineer = twice.engineers.firstWhere(
        (e) => e.id == 'eng-01',
      );
      expect(twiceEngineer.mental, onceEngineer.mental);
      expect(twiceEngineer.trust, onceEngineer.trust);
      expect(twiceEngineer.founderFollowUpMonth, onceEngineer.founderFollowUpMonth);
    });

    test('is a no-op for an engineer that is not currently assigned', () {
      final workflow = PublicDemoWorkflowState.initial();
      final next = workflow.applyFounderFollowUpDecision(
        'eng-01',
        month: 9,
        decision: PublicDemoFounderFollowUpDecision.checkIn,
      );
      expect(
        next.engineers.firstWhere((e) => e.id == 'eng-01').founderFollowUpMonth,
        isNull,
      );
    });
  });

  group('PublicDemoEngineerSales persistence backward compatibility', () {
    test('round-trips founderFollowUpMonth through toJson/fromJson', () {
      final workflow = assignedWorkflow();
      final decided = workflow.applyFounderFollowUpDecision(
        'eng-01',
        month: 9,
        decision: PublicDemoFounderFollowUpDecision.checkIn,
      );
      final engineer = decided.engineers.firstWhere((e) => e.id == 'eng-01');
      final restored = PublicDemoEngineerSales.fromJson(engineer.toJson());
      expect(restored.founderFollowUpMonth, 9);
    });

    test('defaults to null when the field is absent (legacy save)', () {
      final workflow = PublicDemoWorkflowState.initial();
      final engineer = workflow.engineers.first;
      final legacyJson = engineer.toJson()..remove('founderFollowUpMonth');
      final restored = PublicDemoEngineerSales.fromJson(legacyJson);
      expect(restored.founderFollowUpMonth, isNull);
    });
  });

  group('PublicDemoAggregate.applyFounderFollowUpDecision', () {
    /// Advances `eng-01` to a genuinely assigned/accepted state inside a
    /// real [PublicDemoAggregate], via the exact same month-close commands
    /// production code uses (mirrors `publicDemoAggregateAtMonth` in
    /// public_demo_recovery_test_helpers.dart, customized to keep one
    /// engineer genuinely participating instead of economically waiting).
    PublicDemoAggregate assignedAggregateAtMonth(
      int targetMonth, {
      int monthlyExpenses = 10000,
    }) {
      var aggregate = publicDemoAdvanceEngineerToOrdered(
        PublicDemoAggregate.initial(),
        'eng-01',
      );
      aggregate = aggregate.closeApril(monthlyExpenses: monthlyExpenses);
      if (targetMonth == 5) return aggregate;
      aggregate = aggregate.closeMay(week: 9, monthlyExpenses: monthlyExpenses);
      if (targetMonth == 6) return aggregate;
      aggregate = aggregate.withAssignmentUpdate(
        'eng-01',
        nextOrderStatus: PublicDemoNextOrderStatus.accepted,
      );
      aggregate = aggregate.closeJune(
        assignedInJuly: 1,
        monthlyExpenses: monthlyExpenses,
      );
      if (targetMonth == 7) return aggregate;
      aggregate = aggregate.closeJuly(monthlyExpenses: monthlyExpenses);
      for (var month = 8; month < targetMonth; month++) {
        aggregate = aggregate.closeOrdinaryMonth(
          monthlyExpenses: monthlyExpenses,
        );
      }
      return aggregate;
    }

    test('commits the free checkIn decision and never touches cash', () {
      final aggregate = assignedAggregateAtMonth(9);
      expect(
        aggregate.workflow.assignedEngineerIds(
          month: aggregate.state.month,
        ),
        contains('eng-01'),
      );
      final cashBefore = aggregate.state.cash;
      final next = aggregate.applyFounderFollowUpDecision(
        engineerId: 'eng-01',
        decision: PublicDemoFounderFollowUpDecision.checkIn,
      );
      expect(next.state.cash, cashBefore);
      expect(
        next.workflow.engineers.firstWhere((e) => e.id == 'eng-01').founderFollowUpMonth,
        aggregate.state.month,
      );
    });

    test(
      'rejects investSupport when cash is insufficient, but the free '
      'checkIn choice remains available (Failure Recovery: no dead end)',
      () {
        var aggregate = assignedAggregateAtMonth(8);
        // One large one-time expense shock crashes cash without needing many
        // months of decline — the same production `closeOrdinaryMonth`
        // command, just with a deliberately large `monthlyExpenses` for this
        // single close.
        aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000000);
        expect(aggregate.state.month, 9);
        expect(
          aggregate.state.cash,
          lessThan(PublicDemoFounderFollowUp.investSupportCost),
        );

        final rejected = aggregate.applyFounderFollowUpDecision(
          engineerId: 'eng-01',
          decision: PublicDemoFounderFollowUpDecision.investSupport,
        );
        expect(rejected.state.cash, aggregate.state.cash);
        expect(
          rejected.workflow.engineers
              .firstWhere((e) => e.id == 'eng-01')
              .founderFollowUpMonth,
          isNull,
        );

        final checkedIn = aggregate.applyFounderFollowUpDecision(
          engineerId: 'eng-01',
          decision: PublicDemoFounderFollowUpDecision.checkIn,
        );
        expect(
          checkedIn.workflow.engineers
              .firstWhere((e) => e.id == 'eng-01')
              .founderFollowUpMonth,
          9,
        );
      },
    );

    test('is a no-op when the engineer already decided this fiscal year', () {
      final aggregate = assignedAggregateAtMonth(9);
      final once = aggregate.applyFounderFollowUpDecision(
        engineerId: 'eng-01',
        decision: PublicDemoFounderFollowUpDecision.checkIn,
      );
      final twice = once.applyFounderFollowUpDecision(
        engineerId: 'eng-01',
        decision: PublicDemoFounderFollowUpDecision.investSupport,
      );
      expect(twice.state.cash, once.state.cash);
      expect(
        twice.workflow.engineers.firstWhere((e) => e.id == 'eng-01').mental,
        once.workflow.engineers.firstWhere((e) => e.id == 'eng-01').mental,
      );
    });

    test('month transition/close is unaffected by an outstanding decision', () {
      final aggregate = assignedAggregateAtMonth(9);
      final closed = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
      expect(closed.state.month, aggregate.state.month + 1);
    });

    test('save/reload preserves the guard through PublicDemoSaveCodec', () {
      const codec = PublicDemoSaveCodec();
      final aggregate = assignedAggregateAtMonth(9).applyFounderFollowUpDecision(
        engineerId: 'eng-01',
        decision: PublicDemoFounderFollowUpDecision.investSupport,
      );
      final restored = codec.decode(codec.encode(aggregate));
      expect(restored, isNotNull);
      expect(codec.toJson(restored!), codec.toJson(aggregate));
      final restoredEngineer = restored.workflow.engineers.firstWhere(
        (e) => e.id == 'eng-01',
      );
      expect(restoredEngineer.founderFollowUpMonth, 9);
      expect(restoredEngineer.mental, aggregate.workflow.engineers
          .firstWhere((e) => e.id == 'eng-01')
          .mental);
    });
  });
}
