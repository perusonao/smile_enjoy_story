import 'package:flutter/material.dart';

import '../models/home_office_stage_display.dart';

/// Every dimension the Office Stage uses, in one place.
///
/// HOME-RUNTIME-2B's layout budget is not a style preference — it is the
/// reason the section is allowed to exist above the legacy content at all,
/// so the numbers live in a named class that the layout tests assert
/// against directly, rather than being scattered through the widget tree as
/// literals nobody can check.
class HomeOfficeStageMetrics {
  const HomeOfficeStageMetrics._();

  /// Below this screen width the stage switches to [compact].
  ///
  /// Sits between the two target widths (360 and 390) rather than at either
  /// of them, so neither target is decided by an exact-equality comparison.
  static const double compactWidthThreshold = 375;

  /// The scene (background + figures) height at each mode. Declared as
  /// plain constants so the component-height totals below stay
  /// compile-time constants too.
  static const double compactSceneHeight = 108;
  static const double normalSceneHeight = 120;

  /// 360x800 — the smaller of the two required targets.
  static const HomeOfficeStageLayout compact = HomeOfficeStageLayout(
    sceneHeight: compactSceneHeight,
    portraitSize: 54,
    nameFontSize: 10,
    horizontalGap: 8,
  );

  /// 390x844.
  static const HomeOfficeStageLayout normal = HomeOfficeStageLayout(
    sceneHeight: normalSceneHeight,
    portraitSize: 62,
    nameFontSize: 11,
    horizontalGap: 10,
  );

  /// Height the card spends on everything that is not the scene itself:
  /// the title row plus the card's own vertical padding. Constant across
  /// both modes, so `component = scene + chrome` holds in both.
  static const double chromeHeight =
      _cardPaddingTop + _titleRowHeight + _titleGap + _cardPaddingBottom;

  static const double _cardPaddingTop = 10;
  static const double _cardPaddingBottom = 10;
  static const double _cardPaddingHorizontal = 12;
  static const double _titleRowHeight = 20;
  static const double _titleGap = 8;

  /// What the whole card is designed to measure at each target.
  static const double compactComponentHeight =
      compactSceneHeight + chromeHeight;
  static const double normalComponentHeight = normalSceneHeight + chromeHeight;

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
    required this.sceneHeight,
    required this.portraitSize,
    required this.nameFontSize,
    required this.horizontalGap,
  });

  final double sceneHeight;
  final double portraitSize;
  final double nameFontSize;
  final double horizontalGap;

  double get componentHeight =>
      sceneHeight + HomeOfficeStageMetrics.chromeHeight;

  bool get isCompact =>
      sceneHeight == HomeOfficeStageMetrics.compactSceneHeight;
}

/// HOME-RUNTIME-2B — the company, as a picture.
///
/// This is a **presentation layer and nothing else**. It renders an office
/// background, up to [HomeOfficeStageDisplay.visibleSlotCount] employees,
/// and the minimum state needed to read the scene. It holds no state,
/// takes no callback, exposes no gesture, and has no path back into
/// `PublicDemoAggregate` — the Recommended Action CTA above it remains
/// HOME's single mutation entry point, exactly as HOME-RUNTIME-2C left it.
///
/// It also does not *choose* anything. Which employees appear, in which
/// order, with which portraits, and which background is behind them are all
/// already decided in [HomeOfficeStageDisplay] by the time this widget sees
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
            // Title only. A 参画/待機 summary belonged here at first and was
            // removed: the KPI row two widgets above already owns that
            // fact, and HOME-RUNTIME-2A's rule is that each fact has
            // exactly one place on screen.
            // A *minimum*, not a fixed height: at an increased system text
            // scale `labelLarge`'s line height exceeds 20pt, and a fixed
            // box would clip the heading rather than let the card grow —
            // which is one of the growths the safety ceiling's margin is
            // there to absorb (the card measures 196pt at 2x scale,
            // still under 213).
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: HomeOfficeStageMetrics._titleRowHeight,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '社員の様子',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: HomeOfficeStageMetrics._titleGap),
            SizedBox(
              height: layout.sceneHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _OfficeBackground(assetPath: display.backgroundAssetPath),
                    // Darkens only the lower band the figures stand in, so
                    // the office itself stays the subject while the name
                    // labels keep their contrast.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                          stops: [0.45, 1.0],
                        ),
                      ),
                    ),
                    if (visible.isEmpty)
                      const _EmptyOffice()
                    else
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < visible.length; i++) ...[
                                if (i > 0)
                                  SizedBox(width: layout.horizontalGap),
                                // Loose flex: each figure keeps its natural
                                // width when it fits and shrinks instead of
                                // overflowing when it does not, which is
                                // what keeps a long name from painting past
                                // the card edge at 360pt.
                                Flexible(
                                  child: _MemberFigure(
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
                                Flexible(
                                  child: _MoreMembersChip(
                                    hiddenCount: hidden,
                                    layout: layout,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The office scene. Falls back to a flat surface colour if the bundled
/// image cannot be decoded, so a missing or corrupt asset degrades to a
/// plain background instead of throwing during layout.
class _OfficeBackground extends StatelessWidget {
  const _OfficeBackground({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      key: const Key('home-office-stage-background-fallback'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    return Semantics(
      label: 'オフィスの様子',
      image: true,
      child: Image.asset(
        assetPath,
        key: const Key('home-office-stage-background'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _EmptyOffice extends StatelessWidget {
  const _EmptyOffice();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          '社員はまだいません',
          key: Key('home-office-stage-empty'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// One employee: a portrait and the name under it.
class _MemberFigure extends StatelessWidget {
  const _MemberFigure({super.key, required this.member, required this.layout});

  final HomeOfficeStageMember member;
  final HomeOfficeStageLayout layout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.portraitSize,
      child: Column(
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
                  color: Colors.black26,
                  shape: BoxShape.rectangle,
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(layout.portraitSize / 2),
                ),
                child: _Portrait(member: member),
              ),
            ),
          ),
          const SizedBox(height: 3),
          // The label is a single ellipsised line on a translucent pill: it
          // must never wrap into the portrait above it, and never widen the
          // figure past the portrait it belongs to.
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                member.name,
                key: ValueKey('home-office-stage-name-${member.id}'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: layout.nameFontSize,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
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
    if (path == null) return _silhouette(member.id);
    return Semantics(
      label: member.name,
      image: true,
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _silhouette(member.id),
      ),
    );
  }

  static Widget _silhouette(String id) => Icon(
    Icons.person,
    key: ValueKey('home-office-stage-silhouette-$id'),
    color: Colors.white70,
  );
}

/// `+N名` — the employees the stage did not draw.
class _MoreMembersChip extends StatelessWidget {
  const _MoreMembersChip({required this.hiddenCount, required this.layout});

  final int hiddenCount;
  final HomeOfficeStageLayout layout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.portraitSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: layout.portraitSize,
            width: layout.portraitSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 2),
              ),
              child: Center(
                child: Text(
                  '+$hiddenCount',
                  key: const Key('home-office-stage-more'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: layout.nameFontSize + 3,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '他$hiddenCount名',
            style: TextStyle(
              color: Colors.white,
              fontSize: layout.nameFontSize,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
