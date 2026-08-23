/// Immutable, presentation-neutral record of one closed month's cash
/// movement for Public Demo 0.1 (FINANCE-UX-1).
///
/// Every field here is a fact [PublicDemoMonthlyClose] already computed (or
/// received) while closing the month — this class carries those facts
/// forward for display, it does not recompute salary, revenue, or
/// pendingRevenue itself. [salaryPaid]/[fixedCostsPaid] split the caller's
/// `monthlyExpenses` by subtracting the known
/// [PublicDemoSalary.otherMonthlyFixedCost] constant — every real caller's
/// `monthlyExpenses` always equals payroll plus that exact constant (FIX1),
/// so this is a subtraction of a known fixed value, not a recomputation of
/// payroll. [openingCash]/[closingCash] always satisfy the core accounting
/// contract:
///
/// openingCash + cashReceived - salaryPaid - fixedCostsPaid - bonusPaid -
/// trainingCost - recruitmentCost == closingCash
///
/// [revenue] is this month's newly recognized billing (30-day site);
/// [receivables] is the same amount carried forward as the balance next
/// month's close will collect — Public Demo 0.1's single billing cycle
/// means these two are always equal, but they are kept as separate named
/// fields so the UI can explain the 30-day relationship without the reader
/// having to infer it from one number playing two roles.
class PublicDemoMonthlyCashFlow {
  const PublicDemoMonthlyCashFlow({
    required this.month,
    required this.openingCash,
    required this.cashReceived,
    required this.salaryPaid,
    required this.fixedCostsPaid,
    required this.bonusPaid,
    required this.trainingCost,
    required this.recruitmentCost,
    required this.closingCash,
    required this.revenue,
    required this.receivables,
  });

  /// The internal month number (4-15) that was closed.
  final int month;
  final int openingCash;

  /// Cash collected this close from last month's [receivables].
  final int cashReceived;
  final int salaryPaid;

  /// The non-payroll portion of `monthlyExpenses` (rent, utilities, etc.) —
  /// every month, not just some (FIX1).
  final int fixedCostsPaid;

  /// July only; 0 in every other month.
  final int bonusPaid;
  final int trainingCost;
  final int recruitmentCost;
  final int closingCash;

  /// Revenue newly recognized this month (this month's billing).
  final int revenue;

  /// Receivable balance carried into next month; next month's close will
  /// collect exactly this amount as [cashReceived].
  final int receivables;

  int get totalOutflow =>
      salaryPaid + fixedCostsPaid + bonusPaid + trainingCost + recruitmentCost;

  int get netCashMovement => closingCash - openingCash;

  Map<String, dynamic> toJson() => {
    'month': month,
    'openingCash': openingCash,
    'cashReceived': cashReceived,
    'salaryPaid': salaryPaid,
    'fixedCostsPaid': fixedCostsPaid,
    'bonusPaid': bonusPaid,
    'trainingCost': trainingCost,
    'recruitmentCost': recruitmentCost,
    'closingCash': closingCash,
    'revenue': revenue,
    'receivables': receivables,
  };

  factory PublicDemoMonthlyCashFlow.fromJson(Map<String, dynamic> json) =>
      PublicDemoMonthlyCashFlow(
        month: json['month'] as int,
        openingCash: json['openingCash'] as int,
        cashReceived: json['cashReceived'] as int,
        salaryPaid: json['salaryPaid'] as int,
        fixedCostsPaid: json['fixedCostsPaid'] is int
            ? json['fixedCostsPaid'] as int
            : 0,
        bonusPaid: json['bonusPaid'] as int,
        trainingCost: json['trainingCost'] as int,
        recruitmentCost: json['recruitmentCost'] as int,
        closingCash: json['closingCash'] as int,
        revenue: json['revenue'] as int,
        receivables: json['receivables'] as int,
      );
}
