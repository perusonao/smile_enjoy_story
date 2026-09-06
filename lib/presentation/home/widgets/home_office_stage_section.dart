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
/// portraits overlaid on it), then (SES HOME Final Touch) a row of real
/// employee cards with the office photo shrunk to a small decorative icon
/// beside the title.
///
/// SES HOME Visual SSOT Exact Layout Match: the approved Visual SSOT draws
/// the office photo as its own real panel — a third column beside the
/// employee cards, not a title-row glyph. [_OfficePhotoPanel] replaces the
/// former `_OfficeIcon`; `iconSize` is gone from [HomeOfficeStageLayout]
/// because the photo no longer lives in the title row at all (see
/// [HomeOfficeStageSection.build] for exactly when it renders as the
/// row's trailing column). `compactComponentHeight` / `normalComponentHeight`
/// / `safetyCeiling` keep the same meaning and the same names the existing
/// layout-safety tests assert against; only what they add up to internally
/// has changed.
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
  );

  /// 390x844.
  static const HomeOfficeStageLayout normal = HomeOfficeStageLayout(
    portraitSize: 54,
    nameFontSize: 13,
    statusFontSize: 10.5,
    horizontalGap: 8,
  );

  /// Height the card spends on everything that is not the employee cards
  /// row itself: the title row (label + optional headcount chip) plus the
  /// card's own vertical padding and the gap above the row.
  static const double chromeHeight =
      _cardPaddingTop + _titleRowHeight + _titleGap + _cardPaddingBottom;

  static const double _cardPaddingTop = 1;
  static const double _cardPaddingBottom = 1;
  static const double _cardPaddingHorizontal = 12;
  // A *minimum*, not a fixed size — see the title row's own ConstrainedBox
  // in the widget body below for why this must stay a floor, not a cap.
  //
  // SES HOME Visual SSOT Exact Layout Match: back down from 28 to 20 — the
  // office photo moved out of this row entirely into its own column (see
  // the class doc above), so this row is plain text + the headcount chip
  // again, the same real minimum every other single-line HOME title row
  // uses.
  static const double _titleRowHeight = 20;
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
  });

  final double portraitSize;
  final double nameFontSize;
  final double statusFontSize;
  final double horizontalGap;

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
/// order, with which portraits/status, and whether the office photo panel
/// has a free column to render in are all already decided (or, for the
/// office photo, computed here from [HomeOfficeStageDisplay.visibleSlotCount]
/// alone — see [_showOfficePhoto]'s own doc) by the time this widget draws
/// them. That split is what makes "the same state always draws the same
/// scene" testable without pumping a widget at all.
///
/// Deliberately not coupled to the legacy cards below it: nothing here
/// reads, measures, or positions itself relative to the per-employee
/// blocks, so when 2D/2E migrate those away this section keeps standing on
/// its own.
class HomeOfficeStageSection extends StatelessWidget {
  const HomeOfficeStageSection({super.key, required this.display});

  final HomeOfficeStageDisplay display;

  /// Whether the office photo gets its own column in the content row.
  ///
  /// SES HOME Visual SSOT Exact Layout Match: the approved Visual SSOT's
  /// "Employee Scene" is three columns — up to two real employees, plus the
  /// office photo as a real third panel, not a title-row glyph. Today's
  /// real April roster (two engineers) is exactly this shape. A real
  /// employee always wins that slot over the photo, though: once the
  /// roster genuinely fills every slot [HomeOfficeStageDisplay
  /// .visibleSlotCount] allows (three people, or two people plus the "+N"
  /// overflow chip once a fourth exists), the row is already at its
  /// intended width budget and the photo is dropped rather than forcing a
  /// fourth/fifth column that would cramp every real person's own name and
  /// portrait — "employees are the visual subject" (this file's own
  /// long-standing rule) still wins the slot when the two collide, which is
  /// only for a roster this section does not draw at 360x800 today (3+
  /// employees).
  bool get _showOfficePhoto {
    final rendered =
        display.visibleMembers.length +
        (display.hiddenMemberCount > 0 ? 1 : 0);
    return rendered < HomeOfficeStageDisplay.visibleSlotCount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = HomeOfficeStageMetrics.of(context);
    final visible = display.visibleMembers;
    final hidden = display.hiddenMemberCount;
    final showOfficePhoto = _showOfficePhoto;

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
            // Title row: the "社員の様子" label and — when supplied — the
            // truthful aggregate headcount chip. A *minimum* height, not a
            // fixed one, so an increased text scale grows the row instead
            // of clipping it. No icon here any more — the office photo is
            // its own column below (see [_showOfficePhoto]'s doc).
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: HomeOfficeStageMetrics._titleRowHeight,
              ),
              child: Row(
                children: [
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
            // SES HOME Visual SSOT Exact Layout Match: `IntrinsicHeight` +
            // `stretch` — the same fix `PublicDemoImportantTasksSection`
            // already uses for its own two-column row — so the office
            // photo column (which has no natural height of its own to
            // negotiate with) always fills exactly the height the real
            // employee cards need, never forcing the row taller or leaving
            // it a sliver.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (visible.isEmpty)
                    const Expanded(child: _EmptyOffice())
                  else
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) SizedBox(width: layout.horizontalGap),
                      // Loose flex: each card keeps its natural width when
                      // it fits and shrinks instead of overflowing when it
                      // does not, which is what keeps a long name from
                      // painting past the card edge at 360pt.
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
                  if (showOfficePhoto) ...[
                    SizedBox(width: layout.horizontalGap),
                    Expanded(
                      child: _OfficePhotoPanel(
                        assetPath: display.backgroundAssetPath,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The office, as its own real photo panel — a third column beside the
/// employee cards (see [HomeOfficeStageSection._showOfficePhoto]'s doc for
/// when it renders at all), not a title-row glyph and not a full-bleed
/// background behind the employees. Falls back to a plain icon if the
/// bundled image cannot be decoded, so a missing or corrupt asset degrades
/// instead of throwing during layout.
class _OfficePhotoPanel extends StatelessWidget {
  const _OfficePhotoPanel({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Icon(
      Icons.apartment,
      key: const Key('home-office-stage-background-fallback'),
      color: scheme.onSurfaceVariant,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: SizedBox.expand(
          child: Semantics(
            label: 'オフィスの様子',
            image: true,
            child: Image.asset(
              assetPath,
              key: const Key('home-office-stage-background'),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Center(child: fallback),
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
