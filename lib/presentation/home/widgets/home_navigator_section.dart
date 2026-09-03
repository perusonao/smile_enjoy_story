import 'package:flutter/material.dart';

import '../../../ui/asset_paths.dart';
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

  // HOME-COMPACT-1B.4: raised from 44/48. The approved 経営ダッシュボード +
  // 案内役 visual target asks Hiyori to read as a companion who sits beside
  // the card's guidance, not a small status icon — real-device review of
  // the pre-1B.4 build found the 44/48pt circle too small to register as a
  // character at a glance. The text column next to her (eyebrow + message,
  // often headline + CTA + advice bubble too) already measures well past
  // either size, so growing the portrait costs no extra card height — see
  // [compactCeiling]'s own doc for the measured total.
  static const HomeNavigatorLayout compact = HomeNavigatorLayout(
    portraitSize: 60,
    nameFontSize: 12,
    roleFontSize: 10,
    messageFontSize: 11.5,
    horizontalGap: 10,
  );

  static const HomeNavigatorLayout normal = HomeNavigatorLayout(
    portraitSize: 68,
    nameFontSize: 13,
    roleFontSize: 10.5,
    messageFontSize: 12,
    horizontalGap: 10,
  );

  // HOME-COMPACT-1B.4: trimmed from 8 to help fit 社員概要 back into the
  // unscrolled initial view — see [compactCeiling]'s own doc for why the
  // bigger portrait this phase also adds costs nothing on top of this.
  static const double cardPaddingVertical = 6;
  static const double cardPaddingHorizontal = 10;

  /// Gap between the name/role line and the greeting below it.
  ///
  /// HOME-COMPACT-1B.4: trimmed from 3 — this constant is reused at every
  /// internal seam in the card's text column, so shaving one point here
  /// gives back real room across all of them at once.
  static const double textGap = 2;

  /// The height at which the navigator would be costing the first view more
  /// than a compact identity plus its advice is worth at the default text
  /// scale.
  ///
  /// A ceiling, not a target, in the same sense as the Office Stage's: it
  /// exists so growth shows up as a failing test rather than as a silently
  /// worse screen. It applies at scale 1.0 only — at larger text scales the
  /// card is *supposed* to grow past it, because the design explicitly
  /// permits the navigator to be pushed out of the first view rather than
  /// have its text truncated.
  ///
  /// PUBLIC-DEMO-HOME-UI-3A raises this from 140: the approved visual
  /// target requires the advice explanation bubble to be always visible
  /// (replacing the former "詳しく見る" tap-to-reveal control), which is a
  /// real, required structural addition, not slack. The default (neutral,
  /// no CTA) card now measures ~171pt at 360x800; 200pt keeps real margin
  /// while still failing the moment something else is added to the card.
  ///
  /// HOME-COMPACT-1B.4 keeps this same number unraised: the bigger portrait
  /// above and the compacted [_AdviceBubble] below are a wash at 360x800 —
  /// the text column, not the portrait, already decided this card's height,
  /// and the bubble's own tighter padding/`maxLines` gives back roughly what
  /// the portrait spent.
  static const double compactCeiling = 200;

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
/// SES-FIRST-FUN-YEAR-UI-PHASE-2 merges what used to be two stacked cards
/// (this navigator card, plus a separate `RecommendedActionSection` right
/// below it) into one. The two cards said the same thing twice — "here is
/// the next action" — in two different wordings, one of them hidden behind
/// a "詳しく見る" tap. Now there is exactly one always-visible guidance line
/// plus, directly under it, the one CTA button: nothing about the resolved
/// action is stated twice, and nothing actionable requires an extra tap to
/// reveal. Only the optional educational *why* ([HomeNavigatorAdvice.
/// explanation]) stays behind a local expand control, so a future phase can
/// still grow that into a modal without this card's always-visible contract
/// changing.
///
/// This is a **presentation layer and nothing else**:
///
///  * It takes no data beyond [expression] and [advice] — not a state, not
///    an aggregate. Every value [advice] carries (headline, message,
///    explanation, CTA) was already resolved by the owning screen (via
///    [navigatorAdviceFor]) before this widget ever sees it.
///  * Its only local interaction is the optional explanation expand/collapse
///    control. The CTA it renders is the same already-bound owner callback
///    [advice] carries — Recommended Action remains HOME's single mutation
///    entry point exactly as HOME-RUNTIME-2C left it; this card only moved
///    where that CTA is drawn, not who dispatches it.
///
/// She is the existing general-affairs employee made visible, not a fourth
/// hire — see [HomeNavigatorIdentity] for why that costs the domain
/// nothing.
///
/// PUBLIC-DEMO-HOME-UI-3A: the approved visual target shows the "ひよりから
/// のアドバイス" explanation open by default, with no collapse control — so
/// this is now a [StatelessWidget]. The former "詳しく見る"/"閉じる" local
/// toggle is gone entirely; [_AdviceBubble] renders unconditionally whenever
/// [HomeNavigatorAdvice.explanation] is non-null.
class HomeNavigatorSection extends StatelessWidget {
  const HomeNavigatorSection({
    super.key,
    this.expression = NavigatorExpression.normal,
    this.advice = HomeNavigatorAdvice.neutral,
  });

  /// Which portrait to draw. NAVIGATOR-1A never passes anything but the
  /// default; the parameter exists so a later phase adds artwork rather
  /// than re-shapes this widget.
  final NavigatorExpression expression;

  /// `null` is the already-resolved suppression outcome, without a reason.
  final HomeNavigatorAdvice? advice;

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
                  if (advice case final advice?) ...[
                    // The eyebrow names which of the two roles this line
                    // plays: a concrete next step (a CTA follows) or the
                    // month's general goal (nothing is eligible right now).
                    // Never both, and never a third card restating either.
                    Text(
                      advice.ctaLabel != null ? '次にやること' : '今月やること',
                      key: const Key('home-navigator-message-label'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: HomeNavigatorMetrics.textGap),
                    if (advice.headline case final headline?) ...[
                      Text(
                        headline,
                        key: const Key('home-recommended-action-headline'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: HomeNavigatorMetrics.textGap),
                    ],
                    // No maxLines and no ellipsis, deliberately: the whole
                    // point of the merge is that this line is never
                    // truncated behind a "詳しく見る" tap the way the old
                    // rationale line was — at a larger text scale the card
                    // grows to hold it instead.
                    Semantics(
                      label: 'ひよりからの案内: ${advice.message}',
                      child: Text(
                        advice.message,
                        key: const Key('home-navigator-message'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: layout.messageFontSize,
                          height: 1.25,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (advice.ctaLabel case final ctaLabel?) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('home-recommended-action-cta'),
                          style: theme.filledButtonTheme.style?.copyWith(
                            minimumSize: const WidgetStatePropertyAll(
                              Size(0, 48),
                            ),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          onPressed: advice.onCtaPressed,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            ctaLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                    if (advice.secondaryLabel case final secondaryLabel?) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          key: const Key('home-navigator-secondary-cta'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onPressed: advice.onSecondaryPressed,
                          child: Text(
                            secondaryLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                    // PUBLIC-DEMO-HOME-UI-3A: the approved visual target
                    // shows this explanation open, always, with no collapse
                    // control — the former "詳しく見る" tap-to-reveal is
                    // gone. A `null` explanation still renders nothing here.
                    if (advice.explanation != null) ...[
                      const SizedBox(height: HomeNavigatorMetrics.textGap),
                      _AdviceBubble(advice: advice),
                    ],
                  ] else
                    // Suppressed (advice is null — a terminal financial
                    // state or the fiscal year is over): no action to
                    // recommend and no month goal left to pursue, so she
                    // falls back to her one fixed line instead of stating
                    // either.
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

/// The optional "why" — [HomeNavigatorAdvice.explanation] alone.
///
/// SES-FIRST-FUN-YEAR-UI-PHASE-2: this used to also restate [advice.title]
/// and [advice.message] and carry its own nested CTA button. All three are
/// gone: the message is now always visible above, and the CTA is a single
/// always-visible button in the same card — duplicating either here would
/// recreate the exact "same fact, shown twice" problem the merge exists to
/// remove. What is left here is genuinely additional: the educational
/// explanation, which the always-visible line deliberately does not state.
///
/// PUBLIC-DEMO-HOME-UI-3A: this bubble is now always rendered (whenever
/// [HomeNavigatorAdvice.explanation] is non-null) instead of behind a
/// collapse tap — the approved visual target shows "ひよりからのアドバイス"
/// permanently on screen, so there is no `onCollapse` control left to wire.
///
/// HOME-COMPACT-1B.4: tightened padding and a two-line cap on the
/// explanation itself — the acceptance criteria ask this bubble not to
/// press against the card's height budget the way an unbounded paragraph
/// could. The message above it (never capped — see the `Text` in [build]
/// above this class) still states the actual guidance in full; this stays
/// what it already was, the optional educational "why", just shown at a
/// size that cannot grow past two lines. At the default text scale every
/// existing explanation string already fits within that.
class _AdviceBubble extends StatelessWidget {
  const _AdviceBubble({required this.advice});

  final HomeNavigatorAdvice advice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: 'ひよりからの補足説明',
      child: DecoratedBox(
        key: const Key('home-navigator-advice-bubble'),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  // Flexible, not a bare Text: at a large text scale the
                  // title alone can exceed the bubble's width, and this is
                  // what lets it wrap instead of overflowing the Row.
                  Flexible(
                    child: Text(
                      'ひよりからのアドバイス',
                      key: const Key('home-navigator-advice-title'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              if (advice.explanation case final explanation?)
                Text(
                  explanation,
                  key: const Key('home-navigator-advice-explanation'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.25,
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
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
class _NavigatorPortrait extends StatefulWidget {
  const _NavigatorPortrait({required this.expression, required this.layout});

  final NavigatorExpression expression;
  final HomeNavigatorLayout layout;

  @override
  State<_NavigatorPortrait> createState() => _NavigatorPortraitState();
}

class _NavigatorPortraitState extends State<_NavigatorPortrait> {
  bool _useNormalFallback = false;

  /// The image actually shown for [NavigatorExpression.normal] — the single
  /// source of truth this class's own fallback also retries, so a rename of
  /// that asset (HOME-COMPACT-1B.3 moved it to
  /// [AssetPaths.navigatorHomeCompact]) never needs a second edit here.
  static final String _normalPath = HomeNavigatorIdentity.portraitAssetFor(
    NavigatorExpression.normal,
  )!;

  void _fallbackFrom(String path) {
    if (path == _normalPath || _useNormalFallback) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _useNormalFallback = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final requestedPath = HomeNavigatorIdentity.portraitAssetFor(
      widget.expression,
    );
    final path = _useNormalFallback ? _normalPath : requestedPath;

    final fallback = Icon(
      Icons.person,
      key: const Key('home-navigator-portrait-fallback'),
      size: widget.layout.portraitSize * 0.6,
      color: scheme.onSurfaceVariant,
    );

    return SizedBox(
      height: widget.layout.portraitSize,
      width: widget.layout.portraitSize,
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
                    errorBuilder: (context, error, stackTrace) {
                      _fallbackFrom(path);
                      return Center(child: fallback);
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
