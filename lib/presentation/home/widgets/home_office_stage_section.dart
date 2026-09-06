import 'package:flutter/material.dart';

import '../models/home_office_stage_display.dart';

/// Every dimension the Office Stage uses, in one place.
///
/// HOME-RUNTIME-2B's layout budget is not a style preference — it is the
/// reason the section is allowed to exist above the legacy content at all,
/// so the numbers live in a named class that the layout tests assert
/// against directly, rather than being scattered through the widget tree as
/// literals nobody can check.
///
/// SES HOME Final Visual Match (structural pass): this used to describe a
/// single wide "scene" (a big office-banner photo with small circular
/// portraits overlaid on it). The Visual SSOT asks employees to be the
/// visual subject, not the office backdrop, so the layout is now a row of
/// real employee cards (portrait, full name, truthful status) with the
/// office photo shrunk to a small decorative icon beside the title —
/// present and still bundled/customizable exactly as before, just no
/// longer the dominant visual element. `compactComponentHeight` /
/// `normalComponentHeight` / `safetyCeiling` keep the same meaning and the
/// same names the existing layout-safety tests assert against; only what
/// they add up to internally has changed.
class HomeOfficeStageMetrics {
  const HomeOfficeStageMetrics._();

  /// Below this screen width the stage switches to [compact].
  ///
  /// Sits between the two target widths (360 and 390) rather than at either
  /// of them, so neither target is decided by an exact-equality comparison.
  static const double compactWidthThreshold = 375;

  /// 360x800 — the smaller of the two required targets.
  static const HomeOfficeStageLayout compact = HomeOfficeStageLayout(
    portraitSize: 48,
    nameFontSize: 12,
    statusFontSize: 10,
    horizontalGap: 6,
    // SES HOME Final Touch: raised from 20 — a real device screenshot
    // found this office photo too small to read as a photo at all (it
    // registered as a plain, indistinct dot next to the title). See
    // [_OfficeIcon]'s own doc for the same asset shown larger, not a new
    // or different one.
    iconSize: 30,
  );

  /// 390x844.
  static const HomeOfficeStageLayout normal = HomeOfficeStageLayout(
    portraitSize: 54,
    nameFontSize: 13,
    statusFontSize: 10.5,
    horizontalGap: 8,
    // SES HOME Final Touch: raised from 22 — see [compact.iconSize]'s own
    // doc above.
    iconSize: 32,
  );

  /// Height the card spends on everything that is not the employee cards
  /// row itself: the title row (icon + label + optional headcount chip)
  /// plus the card's own vertical padding and the gap above the row.
  static const double chromeHeight =
      _cardPaddingTop + _titleRowHeight + _titleGap + _cardPaddingBottom;

  static const double _cardPaddingTop = 1;
  static const double _cardPaddingBottom = 1;
  static const double _cardPaddingHorizontal = 12;
  // A *minimum*, not a fixed size — see the title row's own ConstrainedBox
  // in the widget body below for why this must stay a floor, not a cap.
  //
  // SES HOME Final Touch: raised from 20 to [normal.iconSize] (32, the
  // larger of the two office-icon sizes now that it is a real photo, not a
  // small glyph) — the title row's actual rendered height is governed by
  // whichever child is tallest, and the enlarged icon is now that child at
  // both target widths. Keeping this at the larger of the two keeps
  // [compactComponentHeight]/[normalComponentHeight] a real, conservative
  // prediction of the rendered height at either width, not an estimate the
  // bigger icon has already outgrown.
  static const double _titleRowHeight = 32;
  static const double _titleGap = 2;

  /// What the whole card is designed to measure at each target — the
  /// chrome above plus one employee-card row's own height (portrait +
  /// name + status, stacked).
  static double get compactComponentHeight =>
      _cardsRowHeight(compact) + chromeHeight;
  static double get normalComponentHeight =>
      _cardsRowHeight(normal) + chromeHeight;

  static double _cardsRowHeight(HomeOfficeStageLayout layout) =>
      layout.portraitSize + 4 + layout.nameFontSize * 1.3 + 2 + 18;

  /// The absolute maximum total height the Office Stage may occupy at
  /// 360x800 before it starts costing the first view more than it is worth.
  ///
  /// This is a **ceiling, not a target**. [compactComponentHeight] is
  /// deliberately well under it: designing to the ceiling would leave no
  /// room for a longer name, a larger text scale, or the next phase's
  /// additions, and the first thing that grew would blow the budget with no
  /// warning. The layout test asserts both — that the real height is at or
  /// under the *target*, and that the target leaves real margin under this.
  static const double safetyCeiling = 213;

  static HomeOfficeStageLayout of(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactWidthThreshold
      ? compact
      : normal;
}

/// The size-dependent half of [HomeOfficeStageMetrics].
@immutable
class HomeOfficeStageLayout {
  const HomeOfficeStageLayout({
    required this.portraitSize,
    required this.nameFontSize,
    required this.statusFontSize,
    required this.horizontalGap,
    required this.iconSize,
  });

  final double portraitSize;
  final double nameFontSize;
  final double statusFontSize;
  final double horizontalGap;

  /// The small decorative office-photo icon's side length — see this
  /// class's own file-level doc for why the office scene is now an icon,
  /// not a background.
  final double iconSize;

  double get componentHeight =>
      HomeOfficeStageMetrics._cardsRowHeight(this) +
      HomeOfficeStageMetrics.chromeHeight;

  bool get isCompact =>
      portraitSize == HomeOfficeStageMetrics.compact.portraitSize;
}

/// HOME-RUNTIME-2B — the company, as people.
///
/// This is a **presentation layer and nothing else**. It renders up to
/// [HomeOfficeStageDisplay.visibleSlotCount] employees (portrait, full
/// name, and each employee's own truthful status — see
/// [HomeOfficeStageMember.status]'s own doc for why that is safe to show
/// here) and the minimum state needed to read the scene. It holds no
/// state, takes no callback, exposes no gesture, and has no path back into
/// `PublicDemoAggregate` — the Recommended Action CTA above it remains
/// HOME's single mutation entry point, exactly as HOME-RUNTIME-2C left it.
///
/// It also does not *choose* anything. Which employees appear, in which
/// order, with which portraits/status, and which office photo icon is
/// shown are all already decided in [HomeOfficeStageDisplay] by the time
/// this widget sees them. That split is what makes "the same state always
/// draws the same scene" testable without pumping a widget at all.
///
/// Deliberately not coupled to the legacy cards below it: nothing here
/// reads, measures, or positions itself relative to the per-employee
/// blocks, so when 2D/2E migrate those away this section keeps standing on
/// its own.
class HomeOfficeStageSection extends StatelessWidget {
  const HomeOfficeStageSection({super.key, required this.display});

  final HomeOfficeStageDisplay display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = HomeOfficeStageMetrics.of(context);
    final visible = display.visibleMembers;
    final hidden = display.hiddenMemberCount;

    return Card(
      key: const Key('home-office-stage'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HomeOfficeStageMetrics._cardPaddingHorizontal,
          HomeOfficeStageMetrics._cardPaddingTop,
          HomeOfficeStageMetrics._cardPaddingHorizontal,
          HomeOfficeStageMetrics._cardPaddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row: a small office-photo icon (see the class doc for
            // why the office scene shrank from a background to this), the
            // "社員の様子" label, and — when supplied — the truthful
            // aggregate headcount chip. A *minimum* height, not a fixed
            // one, so an increased text scale grows the row instead of
            // clipping it.
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: HomeOfficeStageMetrics._titleRowHeight,
              ),
              child: Row(
                children: [
                  _OfficeIcon(
                    assetPath: display.backgroundAssetPath,
                    size: layout.iconSize,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '社員の様子',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (display.hasHeadcountSummary) ...[
                    const SizedBox(width: 6),
                    _HeadcountSummaryChip(
                      employeeCount: display.employeeCount!,
                      waitingCount: display.waitingCount!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: HomeOfficeStageMetrics._titleGap),
            if (visible.isEmpty)
              const _EmptyOffice()
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) SizedBox(width: layout.horizontalGap),
                    // Loose flex: each card keeps its natural width when it
                    // fits and shrinks instead of overflowing when it does
                    // not, which is what keeps a long name from painting
                    // past the card edge at 360pt.
                    Expanded(
                      child: _MemberCard(
                        key: ValueKey(
                          'home-office-stage-member-${visible[i].id}',
                        ),
                        member: visible[i],
                        layout: layout,
                      ),
                    ),
                  ],
                  if (hidden > 0) ...[
                    SizedBox(width: layout.horizontalGap),
                    Expanded(
                      child: _MoreMembersChip(
                        hiddenCount: hidden,
                        layout: layout,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The office scene, shrunk to a small decorative icon — see
/// [HomeOfficeStageMetrics]'s own file-level doc for why. Falls back to a
/// plain icon if the bundled image cannot be decoded, so a missing or
/// corrupt asset degrades instead of throwing during layout.
class _OfficeIcon extends StatelessWidget {
  const _OfficeIcon({required this.assetPath, required this.size});

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Icon(
      Icons.apartment,
      key: const Key('home-office-stage-background-fallback'),
      size: size * 0.7,
      color: scheme.onSurfaceVariant,
    );
    // SES HOME Final Touch: a thin frame — the same idea [_MemberCard]'s
    // own portrait border already uses — around the now-larger photo, so
    // it reads as a small picture rather than a plain, borderless icon
    // glyph. Same asset, same position; only the size and this frame are
    // new.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: size,
          height: size,
          child: Semantics(
            label: 'オフィスの様子',
            image: true,
            child: Image.asset(
              assetPath,
              key: const Key('home-office-stage-background'),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
          ),
        ),
      ),
    );
  }
}

/// The aggregate "社員N名 ・ 待機N名" pill — see
/// [HomeOfficeStageDisplay.hasHeadcountSummary]'s doc for its authority and
/// for why this is deliberately the whole company's totals, distinct from
/// any individual employee's own [HomeOfficeStageMember.status].
class _HeadcountSummaryChip extends StatelessWidget {
  const _HeadcountSummaryChip({
    required this.employeeCount,
    required this.waitingCount,
  });

  final int employeeCount;
  final int waitingCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '社員$employeeCount名・待機$waitingCount名',
          key: const Key('home-office-stage-headcount-summary'),
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.15),
        ),
      ),
    );
  }
}

class _EmptyOffice extends StatelessWidget {
  const _EmptyOffice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '社員はまだいません',
          key: const Key('home-office-stage-empty'),
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// One employee, large: a real portrait photo, their full name, and —
/// when truthfully known — their own status. This is the Visual SSOT's
/// "employees as the visual subject" composition: the office photo is an
/// icon now (see [HomeOfficeStageMetrics]'s doc), and each card here is
/// sized to actually register as a person, not a small avatar.
class _MemberCard extends StatelessWidget {
  const _MemberCard({super.key, required this.member, required this.layout});

  final HomeOfficeStageMember member;
  final HomeOfficeStageLayout layout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: layout.portraitSize,
          width: layout.portraitSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(layout.portraitSize / 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.rectangle,
                border: Border.all(color: scheme.outlineVariant, width: 2),
                borderRadius: BorderRadius.circular(layout.portraitSize / 2),
              ),
              child: _Portrait(member: member),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          member.name,
          key: ValueKey('home-office-stage-name-${member.id}'),
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: layout.nameFontSize,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.15),
        ),
        if (member.status case final status?) ...[
          const SizedBox(height: 2),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              child: Text(
                status,
                key: ValueKey('home-office-stage-status-${member.id}'),
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontSize: layout.statusFontSize,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.15),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Portrait, or the generic silhouette when there is no asset for this
/// employee — or when the one there is fails to decode.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.member});

  final HomeOfficeStageMember member;

  @override
  Widget build(BuildContext context) {
    final path = member.portraitAssetPath;
    if (path == null) return _silhouette(context, member.id);
    return Semantics(
      label: member.name,
      image: true,
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _silhouette(context, member.id),
      ),
    );
  }

  static Widget _silhouette(BuildContext context, String id) => Icon(
    Icons.person,
    key: ValueKey('home-office-stage-silhouette-$id'),
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

/// `+N名` — the employees the stage did not draw, in the same card shape
/// the real employees use so it reads as one consistent row.
class _MoreMembersChip extends StatelessWidget {
  const _MoreMembersChip({required this.hiddenCount, required this.layout});

  final int hiddenCount;
  final HomeOfficeStageLayout layout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: layout.portraitSize,
          width: layout.portraitSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant, width: 2),
            ),
            child: Center(
              child: Text(
                '+$hiddenCount',
                key: const Key('home-office-stage-more'),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: layout.nameFontSize + 2,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                // SES-ISSUE-124: same capped-caption reasoning as
                // _MemberCard's own name label — see its doc comment.
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.15),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '他$hiddenCount名',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: layout.nameFontSize,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.15),
        ),
      ],
    );
  }
}
