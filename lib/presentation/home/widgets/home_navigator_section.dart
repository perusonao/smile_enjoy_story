import 'package:flutter/material.dart';

import '../models/home_navigator_display.dart';

/// Every dimension the navigator uses, in one place.
///
/// Follows the shape HOME-RUNTIME-2B established for
/// `HomeOfficeStageMetrics`: the layout budget is the reason this section
/// is allowed to sit above the legacy content, so the numbers are named and
/// asserted against by the layout tests rather than scattered through the
/// tree as literals.
///
/// **None of these is a height for text.** Every value below is either a
/// padding, a gap, or the size of the portrait image — the one box on this
/// card whose contents are not glyphs. The card's own height is whatever
/// its children need, which is what keeps an increased system text scale
/// growing the card instead of slicing the greeting. That is the exact
/// defect Codex found in the Office Stage's title row (a fixed
/// `SizedBox(height: 20)` around scalable text), and it is not repeated
/// here.
class HomeNavigatorMetrics {
  const HomeNavigatorMetrics._();

  /// Below this screen width the navigator switches to [compact]. The same
  /// threshold the Office Stage uses, and for the same reason: it sits
  /// between the two required targets (360 and 390) rather than on either,
  /// so neither target is decided by an exact-equality comparison.
  static const double compactWidthThreshold = 375;

  static const HomeNavigatorLayout compact = HomeNavigatorLayout(
    portraitSize: 44,
    nameFontSize: 12,
    roleFontSize: 10,
    messageFontSize: 11.5,
    horizontalGap: 10,
  );

  static const HomeNavigatorLayout normal = HomeNavigatorLayout(
    portraitSize: 48,
    nameFontSize: 13,
    roleFontSize: 10.5,
    messageFontSize: 12,
    horizontalGap: 10,
  );

  static const double cardPaddingVertical = 8;
  static const double cardPaddingHorizontal = 10;

  /// Gap between the name/role line and the greeting below it.
  static const double textGap = 3;

  /// What the card is expected to measure at the default text scale.
  ///
  /// A **target for the tests to check against, never a constraint applied
  /// to the widget** — nothing reads this value at build time. The design
  /// asks for "≈64pt"; the compact layout lands at the portrait's 44pt plus
  /// 16pt of padding when the greeting fits in two lines, which is where
  /// this number comes from.
  static const double compactTargetHeight = 64;

  /// The height at which the navigator would be costing the first view more
  /// than a fixed greeting is worth at the default text scale.
  ///
  /// A ceiling, not a target, in the same sense as the Office Stage's: it
  /// exists so growth shows up as a failing test rather than as a silently
  /// worse screen. It applies at scale 1.0 only — at larger text scales the
  /// card is *supposed* to grow past it, because the design explicitly
  /// permits the navigator to be pushed out of the first view rather than
  /// have its text truncated.
  static const double compactCeiling = 84;

  static HomeNavigatorLayout of(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactWidthThreshold
      ? compact
      : normal;
}

/// The size-dependent half of [HomeNavigatorMetrics].
@immutable
class HomeNavigatorLayout {
  const HomeNavigatorLayout({
    required this.portraitSize,
    required this.nameFontSize,
    required this.roleFontSize,
    required this.messageFontSize,
    required this.horizontalGap,
  });

  final double portraitSize;
  final double nameFontSize;
  final double roleFontSize;
  final double messageFontSize;
  final double horizontalGap;

  bool get isCompact =>
      portraitSize == HomeNavigatorMetrics.compact.portraitSize;
}

/// NAVIGATOR-1A — 佐倉 ひより, on HOME.
///
/// This is a **presentation layer and nothing else**, and in this phase it
/// is a stricter one than either section above it:
///
///  * It takes no data. Not a projection, not a state, not an aggregate —
///    its constructor accepts only an [expression], which defaults to
///    [NavigatorExpression.normal] and which nothing in this phase ever
///    passes anything else for. There is therefore no value HOME could
///    project that would change a single pixel of this widget, which is the
///    strongest available form of "the navigator does not read game state".
///  * It takes no callback and builds no gesture, button, `InkWell`,
///    `ListTile` or `IconButton`. It is inert. The Recommended Action CTA
///    remains HOME's single mutation entry point exactly as
///    HOME-RUNTIME-2C left it.
///  * It says one fixed sentence. Selecting what to say from finance,
///    sales, recruitment or the calendar is NAVIGATOR-1B and later; saying
///    anything conditional here would put a second, weaker adviser next to
///    the Recommended Action, which is the authority on what to do next.
///
/// She is the existing general-affairs employee made visible, not a fourth
/// hire — see [HomeNavigatorIdentity] for why that costs the domain
/// nothing.
class HomeNavigatorSection extends StatelessWidget {
  const HomeNavigatorSection({
    super.key,
    this.expression = NavigatorExpression.normal,
  });

  /// Which portrait to draw. NAVIGATOR-1A never passes anything but the
  /// default; the parameter exists so a later phase adds artwork rather
  /// than re-shapes this widget.
  final NavigatorExpression expression;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = HomeNavigatorMetrics.of(context);

    return Card(
      key: const Key('home-navigator'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HomeNavigatorMetrics.cardPaddingHorizontal,
          vertical: HomeNavigatorMetrics.cardPaddingVertical,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NavigatorPortrait(expression: expression, layout: layout),
            SizedBox(width: layout.horizontalGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wrap, not Row: at a large text scale the name and the
                  // role badge stop fitting side by side, and wrapping to a
                  // second line is the behaviour that keeps both fully
                  // readable. A Row would have had to ellipsise one of the
                  // two facts this phase exists to display.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        HomeNavigatorIdentity.name,
                        key: const Key('home-navigator-name'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: layout.nameFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _RoleBadge(layout: layout),
                    ],
                  ),
                  const SizedBox(height: HomeNavigatorMetrics.textGap),
                  // No maxLines and no ellipsis, deliberately. The greeting
                  // is fixed and short, so at the default scale it settles
                  // in two lines; at 1.3x or 2.0x it takes more, and the
                  // card grows to hold them. Truncating instead would trade
                  // a readable navigator for a first view the design
                  // already said it is willing to lose at large text
                  // scales.
                  Text(
                    HomeNavigatorIdentity.greeting,
                    key: const Key('home-navigator-message'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: layout.messageFontSize,
                      height: 1.25,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 総務 — her department, on a quiet badge so it reads as a role rather
/// than as part of her name.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.layout});

  final HomeNavigatorLayout layout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        // Padding only — the badge is sized by the glyphs inside it, so it
        // grows with the text scale instead of clipping 総務.
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          HomeNavigatorIdentity.role,
          key: const Key('home-navigator-role'),
          style: TextStyle(
            fontSize: layout.roleFontSize,
            fontWeight: FontWeight.w600,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Her portrait — or a silhouette when there is no asset for [expression]
/// (every expression but `normal`, in this phase) or when the bundled image
/// fails to decode.
///
/// Both cases resolve to the same inert fallback, which is why a broken or
/// missing image cannot stop HOME: the card keeps its shape, the name, the
/// role and the greeting all still render, and nothing throws during
/// layout.
class _NavigatorPortrait extends StatelessWidget {
  const _NavigatorPortrait({required this.expression, required this.layout});

  final NavigatorExpression expression;
  final HomeNavigatorLayout layout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = HomeNavigatorIdentity.portraitAssetFor(expression);

    final fallback = Icon(
      Icons.person,
      key: const Key('home-navigator-portrait-fallback'),
      size: layout.portraitSize * 0.6,
      color: scheme.onSurfaceVariant,
    );

    return SizedBox(
      height: layout.portraitSize,
      width: layout.portraitSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ClipOval(
          child: path == null
              ? Center(child: fallback)
              : Semantics(
                  label:
                      '${HomeNavigatorIdentity.role}の'
                      '${HomeNavigatorIdentity.name}',
                  image: true,
                  child: Image.asset(
                    path,
                    key: const Key('home-navigator-portrait'),
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
