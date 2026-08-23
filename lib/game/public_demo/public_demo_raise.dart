import '../../domain/models/employee_relationship_event.dart';
import 'public_demo_recruitment.dart';

/// A deliberately small, Public-Demo-only compensation decision.  It is kept
/// separate from the Engineer runtime until that system has a formal bridge.
class PublicDemoRaiseRequest {
  const PublicDemoRaiseRequest({
    required this.currentMonthlySalary,
    required this.requestedMonthlySalary,
  });

  final int currentMonthlySalary;
  final int requestedMonthlySalary;

  int salaryFor(PublicDemoRaiseDecision decision) => switch (decision) {
        PublicDemoRaiseDecision.hold => currentMonthlySalary,
        PublicDemoRaiseDecision.smallRaise => currentMonthlySalary + 20000,
        PublicDemoRaiseDecision.requestedRaise => requestedMonthlySalary,
      };

  String reasonFor(PublicDemoRaiseDecision decision) => switch (decision) {
        PublicDemoRaiseDecision.hold => '昇給希望を今回は据え置き',
        PublicDemoRaiseDecision.smallRaise => '昇給希望に小幅昇給で応答',
        PublicDemoRaiseDecision.requestedRaise => '昇給希望額で応答',
      };

  int moraleDeltaFor(PublicDemoRaiseDecision decision) => switch (decision) {
        PublicDemoRaiseDecision.hold => -4,
        PublicDemoRaiseDecision.smallRaise => 2,
        PublicDemoRaiseDecision.requestedRaise => 5,
      };

  int trustDeltaFor(PublicDemoRaiseDecision decision) => switch (decision) {
        PublicDemoRaiseDecision.hold => -5,
        PublicDemoRaiseDecision.smallRaise => 2,
        PublicDemoRaiseDecision.requestedRaise => 4,
      };

  static PublicDemoRaiseRequest forApplicant(PublicDemoApplicant applicant) {
    final current = applicant.acceptedMonthlySalary!;
    return PublicDemoRaiseRequest(
      currentMonthlySalary: current,
      // The request remains meaningfully above a previously generous offer.
      requestedMonthlySalary: current + 60000,
    );
  }
}

extension PublicDemoRaiseApplicant on PublicDemoApplicant {
  /// This is purely an in-window/decision-already-made check: [PublicDemoApplicant]
  /// has no reference to [PublicDemoState] and so cannot know whether the
  /// fiscal year is completed. Enforcing that terminal-state guard is
  /// [PublicDemoRaiseTransaction]'s job — it takes the actual state as a
  /// required parameter, so completion can never be skipped by a caller
  /// omitting or overriding a flag here (POST-12MONTH-1-FIX1 P1-1). Do not
  /// call [decideRaise] directly from UI or transaction code; go through
  /// [PublicDemoRaiseTransaction.execute] instead.
  bool canRequestRaiseIn(int month) =>
      hasJoined && month >= 6 && raiseDecision == null;

  int salaryForMonth(int month) {
    if (raiseEffectiveMonth != null && month >= raiseEffectiveMonth!) {
      return raisedMonthlySalary!;
    }
    return acceptedMonthlySalary ?? requestedMonthlySalary;
  }

  /// Applies both the decision and its relationship effect exactly once.
  /// A second tap is harmless: the already-decided immutable record is
  /// returned unchanged. This has no notion of the fiscal year being
  /// completed (see [canRequestRaiseIn]) — callers must gate on
  /// [PublicDemoRaiseTransaction] instead of calling this directly.
  PublicDemoApplicant decideRaise({
    required int decisionMonth,
    required int week,
    required PublicDemoRaiseDecision decision,
  }) {
    if (!canRequestRaiseIn(decisionMonth)) return this;
    final request = PublicDemoRaiseRequest.forApplicant(this);
    final event = EmployeeRelationshipEvent(
      week: week,
      reason: request.reasonFor(decision),
      moraleDelta: request.moraleDeltaFor(decision),
      trustDelta: request.trustDeltaFor(decision),
    );
    return copyWith(
      raiseDecision: decision,
      raisedMonthlySalary: request.salaryFor(decision),
      raiseEffectiveMonth: decisionMonth + 1,
      employeeMorale: (employeeMorale! + event.moraleDelta).clamp(0, 100),
      employeeCompanyTrust:
          (employeeCompanyTrust! + event.trustDelta).clamp(0, 100),
      relationshipHistory: [...relationshipHistory, event],
    );
  }
}
