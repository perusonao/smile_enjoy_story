import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recovery.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';
import 'test_support/public_demo_sales_test_helpers.dart';

/// RECOVERY-LOOP-1: pure eligibility unit tests for
/// [PublicDemoRecoveryEligibility.isEligible]/[isMonthEligible] — no full
/// [PublicDemoAggregate] chaining is needed here since both
/// [PublicDemoState] and [PublicDemoWorkflowState] have safe public
/// constructors for exactly this purpose (mirrors
/// public_demo_junior_field_sales_reentry_test.dart).
void main() {
  const engineerId = 'eng-recovery';

  PublicDemoEngineerSales orderedGenuineEngineer() =>
      recordTestClientInterviewPass(
        const PublicDemoEngineerSales(
          id: engineerId,
          name: 'テスト太郎',
          summary: 'テスト用エンジニア',
          interviewProfile: PublicDemoInterviewProfile(
            skillFit: 90,
            humanity: 90,
            morale: 90,
            clientTrust: 90,
          ),
        ),
      );

  PublicDemoWorkflowState orderedWorkflow() => PublicDemoWorkflowState(
    applicants: const [],
    engineers: [orderedGenuineEngineer()],
  ).recordOrder(engineerId);

  PublicDemoState eligibleState({int month = 7}) => PublicDemoState(
    month: month,
    cash: 1000000,
    engineerCount: 1,
    adminCount: 1,
    salesCapacity: 4,
    salesUsed: 0,
    engineersWaiting: 1,
    engineersAssigned: 0,
    engineerRuntimes: [publicDemoRecoveryRuntime(engineerId)],
  );

  group('month window', () {
    test('months 7 (July) through 14 (February) are all month-eligible', () {
      for (var month = 7; month <= 14; month++) {
        expect(
          PublicDemoRecoveryEligibility.isMonthEligible(month),
          isTrue,
          reason: 'month $month must be inside the Recovery window',
        );
      }
    });

    test('June (6) is excluded — before the Recovery window', () {
      expect(PublicDemoRecoveryEligibility.isMonthEligible(6), isFalse);
    });

    test('March (15) is excluded — the fiscal year ends there', () {
      expect(PublicDemoRecoveryEligibility.isMonthEligible(15), isFalse);
    });
  });

  group('isEligible', () {
    test('a genuinely-ordered, runtime-ready, waiting engineer is eligible '
        'in July', () {
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: eligibleState(month: 7),
          workflow: orderedWorkflow(),
          engineerId: engineerId,
        ),
        isTrue,
      );
    });

    test('the same engineer is eligible in February (14)', () {
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: eligibleState(month: 14),
          workflow: orderedWorkflow(),
          engineerId: engineerId,
        ),
        isTrue,
      );
    });

    test('March (15) excludes an otherwise-eligible engineer', () {
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: eligibleState(month: 15),
          workflow: orderedWorkflow(),
          engineerId: engineerId,
        ),
        isFalse,
      );
    });

    test('a terminal financial status excludes an otherwise-eligible '
        'engineer even inside the month window', () {
      final terminalState = eligibleState(
        month: 9,
      ).copyWith(financialStatus: PublicDemoFinancialStatus.bankruptcy);
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: terminalState,
          workflow: orderedWorkflow(),
          engineerId: engineerId,
        ),
        isFalse,
      );
    });

    test('a fiscal-year-completed company excludes an otherwise-eligible '
        'engineer', () {
      final completedState = eligibleState(
        month: 9,
      ).copyWith(fiscalYearCompleted: true);
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: completedState,
          workflow: orderedWorkflow(),
          engineerId: engineerId,
        ),
        isFalse,
      );
    });

    test('training-selected engineer is excluded', () {
      final trainingState = eligibleState().copyWith(
        trainingSelections: const {
          engineerId: PublicDemoGrowthSource.internalTraining,
        },
      );
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: trainingState,
          workflow: orderedWorkflow(),
          engineerId: engineerId,
        ),
        isFalse,
      );
    });

    test('an engineer still counted assigned this month is excluded '
        '(non-waiting)', () {
      final alreadyAssignedWorkflow = orderedWorkflow()
          .recoverLateYearAssignment(engineerId, month: 7);
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: eligibleState(),
          workflow: alreadyAssignedWorkflow,
          engineerId: engineerId,
        ),
        isFalse,
        reason:
            'once recovered, the engineer is counted assigned — Recovery '
            'must not treat them as eligible again',
      );
    });

    test('a runtime below the field-sales capability requirement excludes '
        'the engineer', () {
      final notReadyState = PublicDemoState(
        month: 7,
        cash: 1000000,
        engineerCount: 1,
        adminCount: 1,
        salesCapacity: 4,
        salesUsed: 0,
        engineersWaiting: 1,
        engineersAssigned: 0,
        engineerRuntimes: [
          publicDemoRecoveryRuntime(engineerId, capability: 40),
        ],
      );
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: notReadyState,
          workflow: orderedWorkflow(),
          engineerId: engineerId,
        ),
        isFalse,
      );
    });

    test('an unknown engineer id is excluded', () {
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: eligibleState(),
          workflow: orderedWorkflow(),
          engineerId: 'does-not-exist',
        ),
        isFalse,
      );
    });

    test('an engineer still mid-pipeline (not yet ordered) is excluded', () {
      final sellingWorkflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: [
          orderedGenuineEngineer().copyWith(
            stage: PublicDemoSalesStage.selling,
          ),
        ],
      );
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: eligibleState(),
          workflow: sellingWorkflow,
          engineerId: engineerId,
        ),
        isFalse,
      );
    });

    test('stage forced to ordered without a genuine interview record is '
        'still excluded (defense in depth)', () {
      // PublicDemoEngineerSales.stage/copyWith remain intentionally
      // forgeable (see that class's own docs) — only
      // hasGenuineInterviewRecord is unforgeable, which is exactly what
      // this asserts Recovery still checks.
      final forgedWorkflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: [
          const PublicDemoEngineerSales(
            id: engineerId,
            name: 'テスト太郎',
            summary: 'テスト用エンジニア',
            interviewProfile: PublicDemoInterviewProfile(
              skillFit: 90,
              humanity: 90,
              morale: 90,
              clientTrust: 90,
            ),
            stage: PublicDemoSalesStage.ordered,
          ),
        ],
      );
      expect(
        PublicDemoRecoveryEligibility.isEligible(
          state: eligibleState(),
          workflow: forgedWorkflow,
          engineerId: engineerId,
        ),
        isFalse,
      );
    });
  });
}
