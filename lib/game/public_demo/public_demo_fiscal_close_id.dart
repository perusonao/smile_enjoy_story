/// Authoritative identity for a Public Demo 0.1 fiscal close.
///
/// Wraps the existing *internal* month value ([PublicDemoState.month]),
/// never the UI display label ([publicDemoMonthLabel]). Public Demo 0.1
/// already has internal months (13/14/15) that display as January/
/// February/March, so identity must key off the internal value — collapsing
/// it into the display label would make July's internal month 7 and a
/// future month that also displays "7月" indistinguishable (WORKFLOW-STATE-1
/// §10). This intentionally carries no wall-clock timestamp: Public Demo 0.1
/// is a pure turn-based simulation with no real-time notion of "now".
class PublicDemoFiscalCloseId {
  const PublicDemoFiscalCloseId._(this.internalMonth);

  /// Public Demo 0.1's single fiscal year runs internal months 4-15
  /// ([PublicDemoState.aprilStart] through fiscal-year completion).
  factory PublicDemoFiscalCloseId.forMonth(int internalMonth) {
    if (internalMonth < 4 || internalMonth > 15) {
      throw ArgumentError.value(
        internalMonth,
        'internalMonth',
        'must be within Public Demo 0.1\'s fiscal year (4-15)',
      );
    }
    return PublicDemoFiscalCloseId._(internalMonth);
  }

  /// The internal month this identity was captured for. This is the same
  /// value [PublicDemoState.month] and [PublicDemoMonthlyClose] already key
  /// on, not a recomputed or display-facing month.
  final int internalMonth;

  @override
  bool operator ==(Object other) =>
      other is PublicDemoFiscalCloseId && other.internalMonth == internalMonth;

  @override
  int get hashCode => internalMonth.hashCode;

  @override
  String toString() => 'PublicDemoFiscalCloseId(internalMonth: $internalMonth)';
}
