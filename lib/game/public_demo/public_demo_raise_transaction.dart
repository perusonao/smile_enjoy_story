import 'public_demo_raise.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_state.dart';

/// The single sanctioned entry point for deciding a raise
/// (POST-12MONTH-1-FIX1 P1-1).
///
/// [PublicDemoApplicant.decideRaise] cannot enforce the fiscal-year-
/// completion guard itself — it has no reference to [PublicDemoState]. A
/// prior fix threaded a caller-supplied `fiscalYearCompleted` bool through
/// it instead, but that let any caller bypass the guard simply by omitting
/// the flag or passing `false`. This transaction closes that gap by taking
/// [state] as a required parameter and reading `state.fiscalYearCompleted`
/// directly — the actual state is the only authority, never a flag a caller
/// could forget or override.
class PublicDemoRaiseTransaction {
  const PublicDemoRaiseTransaction();

  PublicDemoRaiseTransactionResult execute({
    required PublicDemoState state,
    required PublicDemoApplicant applicant,
    required int decisionMonth,
    required int week,
    required PublicDemoRaiseDecision decision,
  }) {
    if (state.fiscalYearCompleted) {
      return PublicDemoRaiseTransactionResult._(
        applicant: applicant,
        status: PublicDemoRaiseTransactionStatus.fiscalYearCompleted,
      );
    }
    if (!applicant.canRequestRaiseIn(decisionMonth)) {
      return PublicDemoRaiseTransactionResult._(
        applicant: applicant,
        status: PublicDemoRaiseTransactionStatus.notEligible,
      );
    }
    return PublicDemoRaiseTransactionResult._(
      applicant: applicant.decideRaise(
        decisionMonth: decisionMonth,
        week: week,
        decision: decision,
      ),
      status: PublicDemoRaiseTransactionStatus.success,
    );
  }
}

class PublicDemoRaiseTransactionResult {
  const PublicDemoRaiseTransactionResult._({
    required this.applicant,
    required this.status,
  });

  final PublicDemoApplicant applicant;
  final PublicDemoRaiseTransactionStatus status;

  bool get isSuccess => status == PublicDemoRaiseTransactionStatus.success;
}

enum PublicDemoRaiseTransactionStatus {
  success,
  notEligible,
  fiscalYearCompleted,
}
