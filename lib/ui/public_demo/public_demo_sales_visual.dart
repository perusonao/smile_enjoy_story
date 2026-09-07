import 'package:flutter/material.dart';

// SES NON-HOME-UI SALES Visual Complete: 営業タブ-local visual building
// blocks for the Canonical Visual Reference
// (`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/` —
// `04_Sales_DetailedLayout.png` / `05_Sales_ScreenFlow.png` /
// `03_FiveTabs_LayoutOverview.png`) — status badge colors, a compact
// overview stat tile, and a neutral/authoritative-asset avatar.
//
// Deliberately its own file (mirrors `public_demo_employee_visual.dart`'s
// isolation, not imported from it) so none of it can be reached from
// `lib/presentation/home/` (HOME Freeze) and none of it touches the
// app-wide `SesTheme` (`lib/ui/theme.dart`) other tabs/HOME also read.
//
// Every widget here is presentation-only: it renders values its caller
// already computed from authoritative Public Demo state and never reads
// PublicDemoAggregate/PublicDemoState/PublicDemoWorkflowState itself, so it
// cannot invent a status, a client, a rate, or a match score on its own.

/// The 4 tones a 営業タブ status badge can visually fall into. This is a
/// *coloring* concern only — the badge's own text always stays whatever the
/// caller's authoritative status string already is (e.g. `applicantStatus`/
/// `julyResult`'s existing Japanese labels); no new status vocabulary is
/// introduced.
enum PublicDemoSalesStatusTone {
  /// A closed/won/staffed outcome (e.g. 内定承諾, 参画中, 継続予定,
  /// 入社・参画予定, 現案件を継続) — the same facts the pipeline already
  /// treats as a successful stage.
  positive,

  /// Actively moving through the pipeline (e.g. 応募, 書類確認済,
  /// 採用面談済, 営業中, 案件紹介済) — neither won nor lost yet.
  inProgress,

  /// Still needs sales action this cycle (e.g. 待機（営業が必要）) — a
  /// truthful "not yet" state, not a failure.
  caution,

  /// A lost/declined outcome (e.g. 不採用, 内定辞退, 上位面談不合格,
  /// 客先面談不合格).
  negative,
}

/// A colored status pill. Renders [label] verbatim (so every existing text
/// assertion against the pipeline's status text keeps matching byte-for-byte)
/// inside a [tone]-colored background.
class PublicDemoSalesStatusBadge extends StatelessWidget {
  const PublicDemoSalesStatusBadge({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final PublicDemoSalesStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      PublicDemoSalesStatusTone.positive => (
        const Color(0xFFDDF3E4),
        const Color(0xFF1B7A3B),
      ),
      PublicDemoSalesStatusTone.inProgress => (
        const Color(0xFFDCE8FB),
        const Color(0xFF14508F),
      ),
      PublicDemoSalesStatusTone.caution => (
        const Color(0xFFFFF0CC),
        const Color(0xFF8A5A00),
      ),
      PublicDemoSalesStatusTone.negative => (
        const Color(0xFFFBE0DE),
        const Color(0xFFB3261E),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      // Some 営業タブ status strings run longer than 社員's (e.g.
      // '待機（営業が必要）', '上位面談不合格') — `maxLines`/`overflow` here keep
      // the badge itself from ever forcing a RenderFlex overflow at
      // TextScaler 1.3/2.0 on a 360px-wide card row; callers still place
      // this inside a `Flexible`/`Expanded` so the badge can shrink before
      // that ellipsis is ever needed in practice.
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

/// A small circular portrait for an applicant/engineer named on a 営業タブ
/// card.
///
/// [assetPath] must be an existing, already-bundled authoritative asset
/// (Public Demo's `home_office_stage_display.dart`'s
/// `homeOfficeStagePortraitFor` — the same deterministic per-id pick HOME's
/// own Office Stage and the 社員タブ's roster already render); passing
/// `null` falls back to a neutral person icon rather than any generated/
/// fabricated portrait, per the Visual SSOT's fake-data-0 rule.
class PublicDemoSalesAvatar extends StatelessWidget {
  const PublicDemoSalesAvatar({
    super.key,
    required this.assetPath,
    this.radius = 18,
  });

  final String? assetPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = assetPath;
    if (path == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          Icons.person,
          color: scheme.onSecondaryContainer,
          size: radius,
        ),
      );
    }
    return CircleAvatar(radius: radius, backgroundImage: AssetImage(path));
  }
}

/// One compact stat in the always-visible overview row (現在の営業・採用状況)
/// — an icon plus the caller's already-computed fact text. [primaryText] is
/// rendered verbatim as a single `Text` (never split across widgets), so it
/// stays exactly the wording/format existing regression tests already match
/// with `find.textContaining` (e.g. `'営業残 4回'`, `'候補者 0名'`,
/// `'案件 1件'`) — this widget only adds an icon, tile shape, and an
/// optional truthful [secondaryText] detail line (e.g. `'上限4回'`,
/// `'うち検討中 1件'`) below it. [emphasize] only changes [primaryText]'s
/// color (used when a count means "needs attention now", e.g. 検討中 > 0) —
/// it never changes which value is shown.
class PublicDemoSalesStatTile extends StatelessWidget {
  const PublicDemoSalesStatTile({
    super.key,
    required this.icon,
    required this.primaryText,
    this.secondaryText,
    this.emphasize = false,
  });

  final IconData icon;
  final String primaryText;
  final String? secondaryText;
  final bool emphasize;

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
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            primaryText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: emphasize ? const Color(0xFF8A5A00) : scheme.onSurface,
            ),
          ),
          if (secondaryText != null) ...[
            const SizedBox(height: 2),
            Text(
              secondaryText!,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// The shared card shape every 営業タブ pipeline card (求人媒体, 応募者,
/// 案件/参画) now uses — white surface, rounded corners, a subtle border —
/// matching the Canonical Visual Reference's uniform card treatment and the
/// same shape `public_demo_employee_visual.dart`'s roster card already
/// established for 社員 (kept as an independent constant here rather than a
/// shared import, per this file's own isolation note above).
class PublicDemoSalesCard extends StatelessWidget {
  const PublicDemoSalesCard({super.key, required this.child});

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
