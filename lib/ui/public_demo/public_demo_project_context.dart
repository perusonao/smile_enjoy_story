/// The resolved player-facing project context for one engineer: a
/// stage-appropriate label plus the real project's own truthful facts,
/// always produced together by [PublicDemoProjectContextResolver] (its own
/// file) so they can never disagree — mirrors
/// `PublicDemoEmployeeStatusDisplay`'s own label+tone pairing convention in
/// `public_demo_employee_status_resolver.dart`.
class PublicDemoProjectContext {
  const PublicDemoProjectContext({
    required this.label,
    required this.title,
    required this.clientName,
    required this.monthlyRate,
  });

  /// 提案中の案件 / 受注案件 / 参画中案件 — never itself a lifecycle-authority
  /// claim, purely which noun phrase truthfully describes this reference.
  final String label;

  /// The real [Project.title] — never [PublicDemoAssignment.projectName]'s
  /// generic placeholder.
  final String title;

  /// The real [Client.name] this project's client.
  final String clientName;

  /// The real [Project.monthlyRate] — never
  /// `PublicDemoRevenue.ratePerAssignedEngineer`'s flat company-wide
  /// constant.
  final int monthlyRate;
}
