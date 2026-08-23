import 'public_demo_state.dart';

/// Pure, all-or-nothing internal-training purchase for one waiting engineer.
class PublicDemoInternalTrainingTransaction {
  const PublicDemoInternalTrainingTransaction();

  static const cost = 30000;

  PublicDemoInternalTrainingTransactionResult execute({
    required PublicDemoState state,
    required String engineerId,
    required Set<String> assignedEngineerIds,
  }) {
    final runtimeExists = state.engineerRuntimes.any(
      (runtime) => runtime.engineerId == engineerId,
    );
    if (!runtimeExists) {
      return _failure(
        state,
        engineerId,
        PublicDemoInternalTrainingStatus.unknownEngineer,
      );
    }
    // POST-12MONTH-1: once the fiscal year is closed out, Public Demo 0.1
    // is a read-only terminal state — no training purchase may charge cash
    // or select a training source. Checked before the cash guard below so
    // cash is never deducted for a rejected purchase.
    if (state.fiscalYearCompleted) {
      return _failure(
        state,
        engineerId,
        PublicDemoInternalTrainingStatus.fiscalYearCompleted,
      );
    }
    if (assignedEngineerIds.contains(engineerId)) {
      return _failure(
        state,
        engineerId,
        PublicDemoInternalTrainingStatus.assigned,
      );
    }
    if (state.trainingSelections.containsKey(engineerId)) {
      return _failure(
        state,
        engineerId,
        PublicDemoInternalTrainingStatus.alreadySelected,
      );
    }
    if (state.cash < cost) {
      return _failure(
        state,
        engineerId,
        PublicDemoInternalTrainingStatus.insufficientCash,
      );
    }
    return PublicDemoInternalTrainingTransactionResult.success(
      state: state
          .copyWith(cash: state.cash - cost)
          .recordTrainingSpend(cost)
          .selectInternalTraining(engineerId),
      engineerId: engineerId,
    );
  }

  PublicDemoInternalTrainingTransactionResult _failure(
    PublicDemoState state,
    String engineerId,
    PublicDemoInternalTrainingStatus status,
  ) => PublicDemoInternalTrainingTransactionResult.failure(
    state: state,
    engineerId: engineerId,
    status: status,
  );
}

class PublicDemoInternalTrainingTransactionResult {
  const PublicDemoInternalTrainingTransactionResult._({
    required this.state,
    required this.engineerId,
    required this.chargedAmount,
    required this.status,
  });

  factory PublicDemoInternalTrainingTransactionResult.success({
    required PublicDemoState state,
    required String engineerId,
  }) => PublicDemoInternalTrainingTransactionResult._(
    state: state,
    engineerId: engineerId,
    chargedAmount: PublicDemoInternalTrainingTransaction.cost,
    status: PublicDemoInternalTrainingStatus.success,
  );

  factory PublicDemoInternalTrainingTransactionResult.failure({
    required PublicDemoState state,
    required String engineerId,
    required PublicDemoInternalTrainingStatus status,
  }) => PublicDemoInternalTrainingTransactionResult._(
    state: state,
    engineerId: engineerId,
    chargedAmount: 0,
    status: status,
  );

  final PublicDemoState state;
  final String engineerId;
  final int chargedAmount;
  final PublicDemoInternalTrainingStatus status;

  bool get isSuccess => status == PublicDemoInternalTrainingStatus.success;
}

enum PublicDemoInternalTrainingStatus {
  success,
  unknownEngineer,
  assigned,
  alreadySelected,
  insufficientCash,
  fiscalYearCompleted,
}
