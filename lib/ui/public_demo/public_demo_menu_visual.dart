import 'package:flutter/material.dart';

// SES NON-HOME-UI MENU Visual Complete: メニュータブ-local visual building
// blocks for the Canonical Visual Reference
// (`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/` —
// `07_Menu_DetailedLayout.png` / `03_FiveTabs_LayoutOverview.png`) — a
// shared card shape, a low-emphasis build-identity row, a tappable list-row
// for the collapsible dev/test menu toggle, and a warning-tone card for the
// destructive test-only restart control.
//
// Deliberately its own file, mirroring `public_demo_employee_visual.dart` /
// `public_demo_sales_visual.dart` / `public_demo_accounting_visual.dart`'s
// own isolation note: imported only from the メニュータブ's own widgets, so
// none of it can be reached from `lib/presentation/home/` (HOME Freeze) and
// none of it touches the app-wide `SesTheme` (`lib/ui/theme.dart`) other
// tabs/HOME also read. The coloring values here are independently defined
// (not imported from the Employee/Sales/Accounting visual files) — the same
// deliberate per-tab duplication those files already established, so a
// future change to one tab's palette never silently reaches another.
//
// Every widget here is presentation-only: it renders values or callbacks
// its caller already owns (a [BuildInfo], a toggle's expanded flag and
// [VoidCallback], an already-built [child]) and never invents new
// player-facing functionality, wording, or gameplay/restart authority of
// its own.

/// The shared card shape every メニュータブ body element now uses — white
/// surface, rounded corners, a subtle border — matching the uniform card
/// treatment Employee/Sales/Accounting Visual Complete already established
/// (kept as an independent constant here rather than a shared import, per
/// this file's own isolation note above).
class PublicDemoMenuCard extends StatelessWidget {
  const PublicDemoMenuCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

/// A low-emphasis row for the build/deploy identity (`BuildInfoLabel`),
/// matching the Canonical Visual Reference's subdued treatment of
/// secondary/diagnostic content — a small icon plus the caller's
/// [buildInfoLabel]. Renders nothing when [isAvailable] is false: the caller
/// (BuildInfoLabel's own [BuildInfo.isAvailable]) already decides whether
/// there is anything to show, and this widget must not paint an empty
/// bordered card when there is nothing inside it.
class PublicDemoMenuBuildInfoRow extends StatelessWidget {
  const PublicDemoMenuBuildInfoRow({
    super.key,
    required this.isAvailable,
    required this.buildInfoLabel,
  });

  final bool isAvailable;
  final Widget buildInfoLabel;

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(child: buildInfoLabel),
      ],
    );
  }
}

/// A tappable list-row (icon + label + trailing expand/collapse chevron)
/// matching the Canonical Visual Reference's list-item treatment, used for
/// the collapsible "開発・テストメニュー" toggle. Purely presentational —
/// [onTap] is the caller's own existing toggle callback; this widget invents
/// no new behavior and does not itself gate what is destructive.
class PublicDemoMenuListRow extends StatelessWidget {
  const PublicDemoMenuListRow({
    super.key,
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// A warning-toned card for destructive/test-only controls (テスト用操作,
/// 4月からやり直す) — an icon-led header plus [child], matching the amber
/// "caution" treatment `PublicDemoAccountingAlertCard` already established
/// for 会計タブ (colors independently redefined here per this file's own
/// isolation note above). This widget only supplies the icon/background/
/// border treatment; it never changes the restart/test authority its caller
/// already owns.
class PublicDemoMenuWarningCard extends StatelessWidget {
  const PublicDemoMenuWarningCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFFF0CC);
    const foreground = Color(0xFF8A5A00);
    const border = Color(0xFFE8C468);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
