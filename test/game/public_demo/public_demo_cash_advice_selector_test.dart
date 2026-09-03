import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_advice_selector.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_forecast.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_status_presentation.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_internal_training_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// Builds a [PublicDemoCashStatusPresentation] with an explicit
/// [PublicDemoCashStatus] and shortage month, going through the real
/// [PublicDemoCashStatusPresentation.fromForecast] mapper (Phase 1B.1) so
/// this test never depends on a private constructor.
PublicDemoCashStatusPresentation _statusOf(
  PublicDemoCashStatus status, {
  int? shortageMonth,
}) {
  switch (status) {
    case PublicDemoCashStatus.safe:
      return PublicDemoCashStatusPresentation.fromForecast(
        const PublicDemoCashForecastResult(
          startMonth: 4,
          months: [
            PublicDemoCashForecastMonth(
              month: 4,
              openingCash: 1000,
              cashReceived: 0,
              revenueRecognized: 0,
              monthlyExpenses: 100,
              bonusPaid: 0,
              closingCash: 900,
            ),
          ],
          firstShortageMonth: null,
        ),
      );
    case PublicDemoCashStatus.unavailable:
      return PublicDemoCashStatusPresentation.fromForecast(
        const PublicDemoCashForecastResult(
          startMonth: 15,
          months: [],
          firstShortageMonth: null,
        ),
      );
    case PublicDemoCashStatus.shortage:
      final month = shortageMonth ?? 6;
      return PublicDemoCashStatusPresentation.fromForecast(
        PublicDemoCashForecastResult(
          startMonth: 4,
          months: [
            PublicDemoCashForecastMonth(
              month: month,
              openingCash: 100,
              cashReceived: 0,
              revenueRecognized: 0,
              monthlyExpenses: 500,
              bonusPaid: 0,
              closingCash: -400,
            ),
          ],
          firstShortageMonth: month,
        ),
      );
  }
}

PublicDemoWorkflowState _workflowWithEngineers(
  List<PublicDemoEngineerSales> engineers,
) => PublicDemoWorkflowState(applicants: const [], engineers: engineers);

/// eng-01's fixed runtime capability (78) already clears the field-sales
/// threshold (60); eng-02's (52) does not — see
/// `publicDemoInitialEngineerRuntimes`.
final _readyEngineer = publicDemoInitialEngineers.firstWhere(
  (engineer) => engineer.id == 'eng-01',
);
final _notReadyEngineer = publicDemoInitialEngineers.firstWhere(
  (engineer) => engineer.id == 'eng-02',
);

void main() {
  group('PublicDemoCashAdviceSelector.select — safe/unavailable', () {
    test('never returns a candidate when the cash status is safe', () {
      final candidate = PublicDemoCashAdviceSelector.select(
        cashStatus: _statusOf(PublicDemoCashStatus.safe),
        workflow: _workflowWithEngineers([_notReadyEngineer]),
        state: PublicDemoState.aprilStart(),
      );
      expect(candidate, isNull);
    });

    test('never returns a candidate when the cash status is unavailable', () {
      final candidate = PublicDemoCashAdviceSelector.select(
        cashStatus: _statusOf(PublicDemoCashStatus.unavailable),
        workflow: _workflowWithEngineers([_notReadyEngineer]),
        state: PublicDemoState.aprilStart(),
      );
      expect(candidate, isNull);
    });
  });

  group(
    'PublicDemoCashAdviceSelector.select — waiting employees before sales',
    () {
      test('a waiting engineer whose measured capability has not yet reached '
          'the field-sales threshold is recommended internal training', () {
        final candidate = PublicDemoCashAdviceSelector.select(
          cashStatus: _statusOf(
            PublicDemoCashStatus.shortage,
            shortageMonth: 6,
          ),
          workflow: _workflowWithEngineers([_notReadyEngineer]),
          state: PublicDemoState.aprilStart(),
        );
        expect(candidate, isNotNull);
        expect(candidate!.employeeId, 'eng-02');
        expect(
          candidate.actionType,
          PublicDemoAdviceActionType.startInternalTraining,
        );
        expect(
          candidate.reason,
          PublicDemoAdviceReason.waitingBelowFieldSalesReadiness,
        );
        expect(candidate.shortageMonth, 6);
      });

      test('a waiting engineer already field-sales ready is recommended '
          'SkillSheet confirmation instead of training', () {
        final candidate = PublicDemoCashAdviceSelector.select(
          cashStatus: _statusOf(
            PublicDemoCashStatus.shortage,
            shortageMonth: 7,
          ),
          workflow: _workflowWithEngineers([_readyEngineer]),
          state: PublicDemoState.aprilStart(),
        );
        expect(candidate, isNotNull);
        expect(candidate!.employeeId, 'eng-01');
        expect(
          candidate.actionType,
          PublicDemoAdviceActionType.confirmSkillSheet,
        );
        expect(
          candidate.reason,
          PublicDemoAdviceReason.waitingReadyForSkillSheet,
        );
      });

      test('a waiting engineer not yet field-sales ready but who already has a '
          'training selection this month is never recommended a second '
          'training purchase, and never falls back to SkillSheet confirmation '
          'either — that action is not actually available until capability '
          'genuinely rises at monthly close (Codex P2 finding)', () {
        final state = PublicDemoState.aprilStart().selectInternalTraining(
          'eng-02',
        );
        expect(state.trainingSelections.containsKey('eng-02'), isTrue);
        expect(
          state.engineerRuntimes
              .firstWhere((r) => r.engineerId == 'eng-02')
              .isReadyForFieldSales,
          isFalse,
        );

        final candidate = PublicDemoCashAdviceSelector.select(
          cashStatus: _statusOf(
            PublicDemoCashStatus.shortage,
            shortageMonth: 6,
          ),
          workflow: _workflowWithEngineers([_notReadyEngineer]),
          state: state,
        );
        expect(candidate, isNull);
      });

      test('a not-yet-ready waiting engineer who already has a training '
          'selection this month is skipped in favor of another waiting '
          'engineer who does have a valid action', () {
        final trainingState = PublicDemoState.aprilStart()
            .selectInternalTraining('eng-02');
        final candidate = PublicDemoCashAdviceSelector.select(
          cashStatus: _statusOf(
            PublicDemoCashStatus.shortage,
            shortageMonth: 6,
          ),
          workflow: _workflowWithEngineers([_notReadyEngineer, _readyEngineer]),
          state: trainingState,
        );
        expect(candidate, isNotNull);
        expect(candidate!.employeeId, 'eng-01');
        expect(
          candidate.actionType,
          PublicDemoAdviceActionType.confirmSkillSheet,
        );
      });

      test(
        'a not-yet-ready waiting engineer is never recommended training when '
        'cash is below the transaction cost — the domain would reject it '
        '(Codex P1 finding)',
        () {
          final state = PublicDemoState.aprilStart().copyWith(
            cash: PublicDemoInternalTrainingTransaction.cost - 1,
          );
          final candidate = PublicDemoCashAdviceSelector.select(
            cashStatus: _statusOf(
              PublicDemoCashStatus.shortage,
              shortageMonth: 6,
            ),
            workflow: _workflowWithEngineers([_notReadyEngineer]),
            state: state,
          );
          expect(candidate, isNull);
        },
      );

      test(
        'a not-yet-ready waiting engineer is never recommended training '
        'while financially restricted (cash-shortage grace period or a '
        'terminal status) — the domain would reject it (Codex P1 finding)',
        () {
          final state = PublicDemoState.aprilStart().copyWith(
            financialStatus: PublicDemoFinancialStatus.cashShortage,
          );
          expect(state.isFinanciallyRestricted, isTrue);

          final candidate = PublicDemoCashAdviceSelector.select(
            cashStatus: _statusOf(
              PublicDemoCashStatus.shortage,
              shortageMonth: 6,
            ),
            workflow: _workflowWithEngineers([_notReadyEngineer]),
            state: state,
          );
          expect(candidate, isNull);
        },
      );

      test('a not-yet-ready waiting engineer IS recommended training once cash '
          'and financial status both clear the domain preconditions', () {
        final state = PublicDemoState.aprilStart().copyWith(
          cash: PublicDemoInternalTrainingTransaction.cost,
        );
        final candidate = PublicDemoCashAdviceSelector.select(
          cashStatus: _statusOf(
            PublicDemoCashStatus.shortage,
            shortageMonth: 6,
          ),
          workflow: _workflowWithEngineers([_notReadyEngineer]),
          state: state,
        );
        expect(candidate, isNotNull);
        expect(
          candidate!.actionType,
          PublicDemoAdviceActionType.startInternalTraining,
        );
      });
    },
  );

  group(
    'PublicDemoCashAdviceSelector.select — sales-ready-but-unsold employee',
    () {
      test('an engineer who completed SkillSheet review but never went up for '
          'sale is recommended beginSelling', () {
        final skillSheetReady = _readyEngineer.copyWith(
          stage: PublicDemoSalesStage.skillSheet,
        );
        final candidate = PublicDemoCashAdviceSelector.select(
          cashStatus: _statusOf(
            PublicDemoCashStatus.shortage,
            shortageMonth: 8,
          ),
          workflow: _workflowWithEngineers([skillSheetReady]),
          state: PublicDemoState.aprilStart(),
        );
        expect(candidate, isNotNull);
        expect(candidate!.employeeId, skillSheetReady.id);
        expect(candidate.actionType, PublicDemoAdviceActionType.beginSelling);
        expect(
          candidate.reason,
          PublicDemoAdviceReason.skillSheetReadyToBeginSelling,
        );
        expect(candidate.shortageMonth, 8);
      });

      test('a waiting engineer takes priority over a skillSheet-ready one when '
          'both exist', () {
        final skillSheetReady = _notReadyEngineer.copyWith(
          stage: PublicDemoSalesStage.skillSheet,
        );
        final candidate = PublicDemoCashAdviceSelector.select(
          cashStatus: _statusOf(
            PublicDemoCashStatus.shortage,
            shortageMonth: 6,
          ),
          workflow: _workflowWithEngineers([skillSheetReady, _readyEngineer]),
          state: PublicDemoState.aprilStart(),
        );
        expect(candidate, isNotNull);
        expect(candidate!.employeeId, _readyEngineer.id);
        expect(
          candidate.actionType,
          PublicDemoAdviceActionType.confirmSkillSheet,
        );
      });
    },
  );

  group(
    'PublicDemoCashAdviceSelector.select — no unsafe re-selling candidate',
    () {
      for (final stage in [
        PublicDemoSalesStage.selling,
        PublicDemoSalesStage.introduced,
        PublicDemoSalesStage.partnerInterviewFailed,
        PublicDemoSalesStage.partnerInterviewPassed,
        PublicDemoSalesStage.clientInterviewFailed,
        PublicDemoSalesStage.clientInterviewPassed,
        PublicDemoSalesStage.ordered,
      ]) {
        test('an engineer at stage $stage is never chosen as a re-selling '
            'candidate', () {
          final engineer = _readyEngineer.copyWith(stage: stage);
          final candidate = PublicDemoCashAdviceSelector.select(
            cashStatus: _statusOf(
              PublicDemoCashStatus.shortage,
              shortageMonth: 6,
            ),
            workflow: _workflowWithEngineers([engineer]),
            state: PublicDemoState.aprilStart(),
          );
          expect(candidate, isNull);
        });
      }

      test('returns null when every engineer is already selling, screening, or '
          'assigned, even under a shortage status', () {
        final engineers = [
          _readyEngineer.copyWith(stage: PublicDemoSalesStage.selling),
          _notReadyEngineer.copyWith(stage: PublicDemoSalesStage.ordered),
        ];
        final candidate = PublicDemoCashAdviceSelector.select(
          cashStatus: _statusOf(
            PublicDemoCashStatus.shortage,
            shortageMonth: 9,
          ),
          workflow: _workflowWithEngineers(engineers),
          state: PublicDemoState.aprilStart(),
        );
        expect(candidate, isNull);
      });
    },
  );

  group('PublicDemoCashAdviceSelector.select — determinism and purity', () {
    test(
      'calling it twice with identical inputs returns an identical candidate',
      () {
        final workflow = _workflowWithEngineers([
          _notReadyEngineer,
          _readyEngineer,
        ]);
        final state = PublicDemoState.aprilStart();
        final cashStatus = _statusOf(
          PublicDemoCashStatus.shortage,
          shortageMonth: 6,
        );

        final first = PublicDemoCashAdviceSelector.select(
          cashStatus: cashStatus,
          workflow: workflow,
          state: state,
        );
        final second = PublicDemoCashAdviceSelector.select(
          cashStatus: cashStatus,
          workflow: workflow,
          state: state,
        );
        expect(first!.employeeId, second!.employeeId);
        expect(first.actionType, second.actionType);
        expect(first.reason, second.reason);
        expect(first.shortageMonth, second.shortageMonth);
      },
    );

    test('never mutates the input workflow or state', () {
      final workflow = _workflowWithEngineers([
        _notReadyEngineer,
        _readyEngineer,
      ]);
      final state = PublicDemoState.aprilStart();
      final beforeWorkflowJson = workflow.toJson();
      final beforeStateJson = state.toJson();

      PublicDemoCashAdviceSelector.select(
        cashStatus: _statusOf(PublicDemoCashStatus.shortage, shortageMonth: 6),
        workflow: workflow,
        state: state,
      );

      expect(workflow.toJson(), beforeWorkflowJson);
      expect(state.toJson(), beforeStateJson);
    });
  });
}
