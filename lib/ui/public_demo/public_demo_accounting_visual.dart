import 'package:flutter/material.dart';

// SES NON-HOME-UI ACCOUNTING Visual Complete: 会計タブ-local visual building
// blocks for the Canonical Visual Reference
// (`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/` —
// `06_Accounting_DetailedLayout.png` / `03_FiveTabs_LayoutOverview.png`) —
// a cash hero, status badge colors, a compact stat tile, a shared card
// shape, an alert card, and a simple forecast bar.
//
// Deliberately its own file, mirroring `public_demo_employee_visual.dart`'s
// and `public_demo_sales_visual.dart`'s own isolation note: imported only
// from the 会計タブ's own widgets, so none of it can be reached from
// `lib/presentation/home/` (HOME Freeze) and none of it touches the
// app-wide `SesTheme` (`lib/ui/theme.dart`) other tabs/HOME also read. The
// coloring values here are independently defined (not imported from the
// Employee/Sales visual files) — the same deliberate per-tab duplication
// those two files already established, so a future change to one tab's
// palette never silently reaches another.
//
// Every widget here is presentation-only: it renders values its caller
// already computed from authoritative Public Demo state
// ([PublicDemoState]/[PublicDemoCashForecast]/[PublicDemoMonthlyCashFlow])
// and never reads those models itself, so it cannot invent a cash figure,
// a status, or a forecast month on its own.

/// The 3 tones a 会計タブ status badge/alert can visually fall into. This is
/// a *coloring* concern only — the caller's own authoritative label/message
/// text is always rendered verbatim; no new status vocabulary is
/// introduced.
enum PublicDemoAccountingTone {
  /// A healthy/safe fact (e.g. 健全, 資金不足はありません).
  positive,

  /// Needs attention but not yet a hard failure (e.g. 資金不足（猶予期間中）).
  caution,

  /// A terminal/negative fact (e.g. 倒産, 年度末資金不足, a forecasted
  /// shortage month).
  negative,
}

(Color, Color) _toneColors(PublicDemoAccountingTone tone) => switch (tone) {
  PublicDemoAccountingTone.positive => (
    const Color(0xFFDDF3E4),
    const Color(0xFF1B7A3B),
  ),
  PublicDemoAccountingTone.caution => (
    const Color(0xFFFFF0CC),
    const Color(0xFF8A5A00),
  ),
  PublicDemoAccountingTone.negative => (
    const Color(0xFFFBE0DE),
    const Color(0xFFB3261E),
  ),
};

/// A colored status pill. Renders [label] verbatim (so every existing text
/// assertion against the accounting tab's status text keeps matching
/// byte-for-byte) inside a [tone]-colored background.
class PublicDemoAccountingStatusBadge extends StatelessWidget {
  const PublicDemoAccountingStatusBadge({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final PublicDemoAccountingTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}

/// The shared card shape every 会計タブ section body now uses — white
/// surface, rounded corners, a subtle border — matching the Canonical
/// Visual Reference's uniform card treatment and the same shape
/// `public_demo_employee_visual.dart`/`public_demo_sales_visual.dart`
/// already established for 社員/営業 (kept as an independent constant here
/// rather than a shared import, per this file's own isolation note above).
class PublicDemoAccountingCard extends StatelessWidget {
  const PublicDemoAccountingCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

/// One compact stat tile (今月の売上 / 今月の支出 / 入金予定 etc.) — an icon
/// plus the caller's already-computed fact text, matching
/// `PublicDemoSalesStatTile`'s shape. [primaryText] is rendered verbatim as
/// a single `Text` so it stays exactly the wording/format existing
/// regression tests already match with `find.textContaining`. [emphasize]
/// only changes [primaryText]'s color — it never changes which value is
/// shown.
class PublicDemoAccountingStatTile extends StatelessWidget {
  const PublicDemoAccountingStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.primaryText,
    this.emphasize = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String primaryText;
  final bool emphasize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor ?? scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // SES ACCOUNTING VISUAL COMPLETE: a 7-digit yen figure at
          // TextScaler 2.0 can exceed a narrow tile's width — `FittedBox`
          // only scales the painted glyphs down to fit, it never changes
          // the underlying text data, so `find.text(primaryText)` still
          // matches (mirrors `public_demo_monthly_cash_flow_card.dart`'s
          // own `_Row` pattern).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              primaryText,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: emphasize ? const Color(0xFF8A5A00) : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The always-visible cash hero (現在の現金) — a large icon, the current
/// cash figure at a prominent size, and an optional truthful 先月の資金増減
/// delta line (SES HUMAN-REPLAY PRE-FIX P1: renamed from 前月比 — see the
/// call site's own doc for why that label no longer matched what
/// [netCashMovement] actually describes once mid-month spend follows a
/// close). [cashText]/[deltaText] are rendered verbatim from values the
/// caller already computed from authoritative state
/// ([PublicDemoState.cash] / [PublicDemoMonthlyCashFlow.netCashMovement]) —
/// this widget never recomputes a cash figure or a delta itself.
///
/// [deltaText]/[deltaPositive] are both null before the first monthly close
/// (no prior close to compare against yet) — the caller omits the delta
/// entirely rather than fabricating a "no change" value.
class PublicDemoAccountingCashHero extends StatelessWidget {
  const PublicDemoAccountingCashHero({
    super.key,
    required this.label,
    required this.cashText,
    this.deltaText,
    this.deltaPositive,
  });

  /// The caption above [cashText] — the caller's own verbatim label (e.g.
  /// the pre-existing `'現在の現預金'` text a regression suite already
  /// matches with `find.textContaining`), rendered as its own `Text` so
  /// exactly one widget carries that exact substring.
  final String label;
  final String cashText;
  final String? deltaText;
  final bool? deltaPositive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delta = deltaText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF3E4),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(
            Icons.savings_outlined,
            color: Color(0xFF1B7A3B),
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  cashText,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      deltaPositive == true
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 12,
                      color: deltaPositive == true
                          ? const Color(0xFF1B7A3B)
                          : const Color(0xFFB3261E),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        delta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: deltaPositive == true
                              ? const Color(0xFF1B7A3B)
                              : const Color(0xFFB3261E),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A tone-colored alert/advice card (アラート・アドバイス) — an icon plus
/// [child], the caller's own already-computed truthful text. This widget
/// only supplies the icon/background/border treatment; it never invents or
/// rewrites the message.
class PublicDemoAccountingAlertCard extends StatelessWidget {
  const PublicDemoAccountingAlertCard({
    super.key,
    required this.tone,
    required this.icon,
    required this.child,
  });

  final PublicDemoAccountingTone tone;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _toneColors(tone);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A single forecasted month's closing-cash bar (簡易forecast graph). Purely
/// a rendering choice: [fraction] must already be computed by the caller as
/// `closingCash / scaleMax` (clamped 0..1 — a negative closing cash is
/// [isNegative] instead, rendered as an empty/zero bar plus the caller's own
/// negative-value text elsewhere) so this widget never derives a threshold
/// or a scale of its own.
class PublicDemoAccountingForecastBar extends StatelessWidget {
  const PublicDemoAccountingForecastBar({
    super.key,
    required this.fraction,
    required this.isNegative,
  });

  final double fraction;
  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: isNegative ? 0 : fraction.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          isNegative ? const Color(0xFFB3261E) : const Color(0xFF1B7A3B),
        ),
      ),
    );
  }
}
