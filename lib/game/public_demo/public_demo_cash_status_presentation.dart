import 'public_demo_cash_forecast.dart';

/// Pure presentation model for Issue #148 Phase 1B.1: the minimum
/// cash-status facts a later HOME widget/advice layer can safely consume,
/// derived from [PublicDemoCashForecastResult] (Phase 1A's confirmed-
/// information-only forecast) and nothing else.
///
/// Deliberately limited to the three states a cash-negative fact actually
/// supports — [PublicDemoCashStatus.safe], [PublicDemoCashStatus.shortage],
/// [PublicDemoCashStatus.unavailable] — with no extra "注意"/"危険"-style
/// threshold invented on top of [PublicDemoCashForecastResult.isNegative].
/// Carries no Japanese display copy: only the confirmed status/shortage-
/// month facts a later presentation layer would phrase.
class PublicDemoCashStatusPresentation {
  const PublicDemoCashStatusPresentation._({
    required this.status,
    this.shortageMonth,
  });

  /// [PublicDemoCashForecastResult.months] was empty (a close-blocked
  /// state: fiscal year completed, or an already-terminal financial
  /// status) — there is no forecasted window to judge safety from, so this
  /// is reported distinctly from [PublicDemoCashStatus.safe] rather than
  /// conflated with it.
  factory PublicDemoCashStatusPresentation.fromForecast(
    PublicDemoCashForecastResult forecast,
  ) {
    if (forecast.months.isEmpty) {
      return const PublicDemoCashStatusPresentation._(
        status: PublicDemoCashStatus.unavailable,
      );
    }
    if (forecast.hasShortage) {
      return PublicDemoCashStatusPresentation._(
        status: PublicDemoCashStatus.shortage,
        shortageMonth: forecast.firstShortageMonth,
      );
    }
    return const PublicDemoCashStatusPresentation._(
      status: PublicDemoCashStatus.safe,
    );
  }

  final PublicDemoCashStatus status;

  /// The first month [forecast] goes cash-negative, held exactly as
  /// [PublicDemoCashForecastResult.firstShortageMonth] reported it — never
  /// recomputed or adjusted. Only ever non-null when [status] is
  /// [PublicDemoCashStatus.shortage]; always null for
  /// [PublicDemoCashStatus.safe] and [PublicDemoCashStatus.unavailable].
  final int? shortageMonth;
}

/// The only three cash-status outcomes Issue #148 Phase 1B.1 recognizes.
enum PublicDemoCashStatus {
  /// The forecast window has at least one projected month, and none of them
  /// goes cash-negative.
  safe,

  /// The forecast reported a first cash-negative month
  /// ([PublicDemoCashForecastResult.firstShortageMonth]).
  shortage,

  /// The forecast window itself is empty (fiscal year completed, or an
  /// already-terminal financial status) — there is no further close to
  /// judge.
  unavailable,
}
