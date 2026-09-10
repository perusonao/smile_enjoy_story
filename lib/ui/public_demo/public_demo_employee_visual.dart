import 'package:flutter/material.dart';

// SES NON-HOME-UI EMPLOYEE Visual Complete: 社員タブ-local visual building
// blocks for the Canonical Visual Reference
// (`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`) — badge
// colors, a neutral/authoritative-asset avatar, and a capability progress
// bar. Deliberately its own file, imported only from the 社員タブ's own
// widgets, so none of it can be reached from `lib/presentation/home/`
// (HOME Freeze) and none of it touches the app-wide `SesTheme`
// (`lib/ui/theme.dart`) other tabs/HOME also read.
//
// Every widget here is presentation-only: it renders values its caller
// already computed from authoritative Public Demo state and never reads
// PublicDemoAggregate/PublicDemoState itself, so it cannot invent a status,
// a capability number, or a growth delta on its own.

/// The authoritative buckets a 社員タブ status badge can visually fall
/// into. This is a *coloring* concern only — the badge's own text always
/// stays whatever the caller's authoritative status string already is
/// (e.g. `engineerStatus`/`_currentEmployeeStatusLabel`'s '待機'/'参画中'/
/// '営業中'/'研修が必要'/'営業可能'/etc.); no new status vocabulary is
/// introduced here — this enum only maps an existing label to a color.
enum PublicDemoEmployeeStatusTone {
  /// Currently assigned to a project — the same fact
  /// `_currentlyAssignedEngineerIds` already backs.
  assigned,

  /// Needs attention before the next step can happen: either this month's
  /// internal training is already selected
  /// (`PublicDemoState.trainingSelections`, a real, existing per-month
  /// authoritative fact) OR — Issue #231 FIRST-FUN-YEAR P1 Fresh Audit — a
  /// still-`waiting` engineer's own `PublicDemoEngineerRuntime
  /// .isReadyForFieldSales` is genuinely `false` (below
  /// `fieldSalesCapabilityRequirement`), which is exactly why training is
  /// the recommended next action for them.
  training,

  /// Issue #231 FIRST-FUN-YEAR P1: a still-`waiting` engineer whose own
  /// `PublicDemoEngineerRuntime.isReadyForFieldSales` is genuinely `true` —
  /// distinguishes "can start selling right now" from [assigned] (already
  /// on a project) at a glance, without opening the SkillSheet.
  readyForSales,

  /// Anything else on the waiting/selling/interviewing path.
  waiting,
}

/// A colored status pill. Renders [label] verbatim (so every existing text
/// assertion against the roster's status text keeps matching byte-for-byte)
/// inside a [tone]-colored background.
class PublicDemoEmployeeStatusBadge extends StatelessWidget {
  const PublicDemoEmployeeStatusBadge({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final PublicDemoEmployeeStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      PublicDemoEmployeeStatusTone.assigned => (
        const Color(0xFFDDF3E4),
        const Color(0xFF1B7A3B),
      ),
      PublicDemoEmployeeStatusTone.training => (
        const Color(0xFFFBE0DE),
        const Color(0xFFB3261E),
      ),
      PublicDemoEmployeeStatusTone.readyForSales => (
        const Color(0xFFDCEBFB),
        const Color(0xFF1155A6),
      ),
      PublicDemoEmployeeStatusTone.waiting => (
        const Color(0xFFFFF0CC),
        const Color(0xFF8A5A00),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}

/// A small circular employee portrait.
///
/// [assetPath] must be an existing, already-bundled authoritative asset
/// (Public Demo's `home_office_stage_display.dart`'s
/// `homeOfficeStagePortraitFor` — the same deterministic per-employee-id
/// pick HOME's own Office Stage already renders); passing `null` (no
/// authoritative asset resolvable) falls back to a neutral person icon
/// rather than any generated/fabricated portrait, per the Visual SSOT's
/// fake-data-0 rule.
class PublicDemoEmployeeAvatar extends StatelessWidget {
  const PublicDemoEmployeeAvatar({
    super.key,
    required this.assetPath,
    this.radius = 24,
  });

  final String? assetPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (assetPath == null) {
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
    return CircleAvatar(radius: radius, backgroundImage: AssetImage(assetPath!));
  }
}

/// A single confirmed-skill progress bar: `$languageLabel $capability` (plus
/// a `beforeCapability → capability (+delta)` growth line when the caller
/// has a genuine [PublicDemoMonthlyGrowth] event for this engineer this
/// month). [capability] is a plain 0-100 value already produced by
/// `PublicDemoEngineerRuntime.actualCapability`; the bar's fixed 0-100 scale
/// is a rendering choice, not a fabricated number — the text label always
/// shows the real value even past 100.
class PublicDemoEmployeeSkillBar extends StatelessWidget {
  const PublicDemoEmployeeSkillBar({
    super.key,
    required this.languageLabel,
    required this.capability,
    this.beforeCapability,
  });

  final String languageLabel;
  final int capability;

  /// Non-null only when an authoritative growth event for this engineer
  /// this month exists ([PublicDemoState.latestGrowthResults]).
  final int? beforeCapability;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = (capability / 100).clamp(0.0, 1.0);
    final before = beforeCapability;
    final label = before == null
        ? '$languageLabel $capability'
        : '$languageLabel $before→$capability (${capability - before >= 0 ? '+' : ''}'
              '${capability - before})';
    // A single row (label + inline bar), not a stacked Column: keeps this
    // one text-line tall so a roster full of these cards does not push the
    // 社員一覧 section (and everything below it) further down the scroll
    // than the Visual SSOT's "excessive scrolling" rule intends.
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}
