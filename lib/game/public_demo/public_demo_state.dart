/// Minimal state for Public Demo 0.1 MVP-A.
///
/// Public Demo deliberately owns its month progression and sales capacity
/// instead of reusing the development build's weekly calendar.
class PublicDemoState {
  const PublicDemoState({
    required this.month,
    required this.cash,
    required this.engineerCount,
    required this.adminCount,
    required this.salesCapacity,
    required this.salesUsed,
    required this.engineersWaiting,
  });

  factory PublicDemoState.aprilStart() => const PublicDemoState(
        month: 4,
        cash: 3000000,
        engineerCount: 2,
        adminCount: 1,
        salesCapacity: 4,
        salesUsed: 0,
        engineersWaiting: 2,
      );

  final int month;
  final int cash;
  final int engineerCount;
  final int adminCount;
  final int salesCapacity;
  final int salesUsed;
  final int engineersWaiting;

  int get salesRemaining => salesCapacity - salesUsed;

  PublicDemoState useSalesSlot() {
    if (salesRemaining <= 0) return this;
    return copyWith(salesUsed: salesUsed + 1);
  }

  PublicDemoState advanceToMay({required int monthlyExpenses}) {
    if (month != 4) return this;
    return copyWith(
      month: 5,
      cash: cash - monthlyExpenses,
      salesUsed: 0,
    );
  }

  PublicDemoState copyWith({
    int? month,
    int? cash,
    int? engineerCount,
    int? adminCount,
    int? salesCapacity,
    int? salesUsed,
    int? engineersWaiting,
  }) =>
      PublicDemoState(
        month: month ?? this.month,
        cash: cash ?? this.cash,
        engineerCount: engineerCount ?? this.engineerCount,
        adminCount: adminCount ?? this.adminCount,
        salesCapacity: salesCapacity ?? this.salesCapacity,
        salesUsed: salesUsed ?? this.salesUsed,
        engineersWaiting: engineersWaiting ?? this.engineersWaiting,
      );
}
