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
  //
  // SES HOME Final Visual Match: raised again, from 60/68, to match the
  // Visual SSOT's "大きなひより画像" — an 88×88pt portrait at 360×800. Still
  // free in height: the text column stays the taller of the two (see
  // [compactCeiling]) and this only narrows the column's own width, which
  // the section's widget test (measured before/after) confirms does not
  // push its wrapped text past the existing budget.
  //
  // SES HOME Final Visual Match (structural pass): a circular 80/88pt crop
  // of [AssetPaths.navigatorHomeCompact] (a 512×768 upper-body portrait)
  // still read as "a small icon", not "the navigator" — a circle that size
  // shows mostly just her face. `portraitWidth`/`portraitHeight` below
  // replace the single square `portraitSize` with a portrait-oriented
  // rounded rectangle instead, so `BoxFit.cover` keeps her shoulders/torso
  // in frame the way the Visual SSOT's own tall photo does. No new asset —
  // same bundled file, just no longer forced into a circle.
  //
  // SES HOME Visual SSOT Exact Layout Match: `portraitHeight` raised again,
  // from 150/158 to 160/163 — the approved Visual SSOT draws her as a
  // clearly large, present figure. This is deliberately short of this
  // card's own text-column height (171/174pt at 360x800/390x844 — see
  // [compactCeiling]'s doc): 170/173 (right up against that ceiling) still
  // fit the ordinary April 360x800/390x844 no-scroll budget on their own,
  // but overflowed the tighter HOME-COMPACT-1B.4 FIX1 actual-cash-shortage
  // 360x800 scenario (`public_demo_01_issue_124_screen_verification_test
  // .dart`) by several pixels — that scenario adds its own card above HOME
  // and has less spare room to begin with. 160/163 is the largest pair
  // confirmed to fit every existing 360x800/390x844 no-scroll budget,
  // including that one.
  //
  // `portraitWidth` deliberately stays at 80/94, not widened to match:
  // measured at 84pt (a mere +4), the narrower text column it leaves pushes
  // [HomeNavigatorAdvice.message] (never `maxLines`-capped, by design — see
  // the always-visible `Text` below) onto a second line, which is not free
  // — it grows the card by the exact same amount and reopens the 360x800
  // no-scroll overflow this and the Office Stage's own budget together
  // already spend down to a few spare pixels. Per this phase's own stated
  // priority order, 360x800 no-scroll outranks matching the Visual SSOT's
  // portrait width exactly; the height increase alone is still a real,
  // deliberate step toward it.
  static const HomeNavigatorLayout compact = HomeNavigatorLayout(
    portraitWidth: 80,
    portraitHeight: 160,
    nameFontSize: 12,
    roleFontSize: 10,
    messageFontSize: 11.5,
    horizontalGap: 10,
  );

  static const HomeNavigatorLayout normal = HomeNavigatorLayout(
    portraitWidth: 94,
    portraitHeight: 163,
    nameFontSize: 13,
    roleFontSize: 10.5,
    messageFontSize: 12,
    horizontalGap: 10,
  );

  // HOME-COMPACT-1B.4: trimmed from 8 to help fit 社員概要 back into the
  // unscrolled initial view — see [compactCeiling]'s own doc for why the
  // bigger portrait this phase also adds costs nothing on top of this.
  //
  // PUBLIC-DEMO-HOME-UI-3C: trimmed again, from 6, as part of bringing
  // 今月の重要タスク into the unscrolled 360x800 initial view — see the
  // Issue #173 result report for the measured before/after top position.
  //
  // SES HOME Final Density: trimmed again, from 4 to 0 — this card is this
  // phase's single biggest lever for closing the remaining gap to
  // クイックアクセス/Bottom Nav in the unscrolled view. Real card padding,
  // not text height.
  static const double cardPaddingVertical = 0;
  static const double cardPaddingHorizontal = 10;

  /// Gap between the name/role line and the greeting below it.
  ///
  /// HOME-COMPACT-1B.4: trimmed from 3 — this constant is reused at every
  /// internal seam in the card's text column, so shaving one point here
  /// gives back real room across all of them at once.
  ///
  /// SES HOME Final Density: trimmed again, from 2 to 1, for the same
  /// reason.
  ///
  /// SES HOME One-Screen Final Fit: trimmed once more, from 1 to 0 — the
  /// initial 360x800/390x844 April view must fit with no scroll at all,
  /// and every remaining internal seam gap in this card is real slack,
  /// never text/touch-target room.
  static const double textGap = 0;

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
    required this.portraitWidth,
    required this.portraitHeight,
    required this.nameFontSize,
    required this.roleFontSize,
    required this.messageFontSize,
    required this.horizontalGap,
  });

  final double portraitWidth;
  final double portraitHeight;
  final double nameFontSize;
  final double roleFontSize;
  final double messageFontSize;
  final double horizontalGap;

  bool get isCompact =>
      portraitWidth == HomeNavigatorMetrics.compact.portraitWidth;
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
                    // SES HOME Final Density: the eyebrow and the headline
                    // used to be two separately-stacked `Text` lines, each
                    // with its own gap. They are two distinct facts (which
                    // of the two roles this line plays vs. the concrete
                    // headline itself — never both, and never a third card
                    // restating either), but they do not need a whole line
                    // each: at 360-390pt the short eyebrow ("次にやること"/
                    // "今月やること") and the headline routinely fit on one
                    // visual row together, exactly the same `Wrap` idiom
                    // the name/role row above already uses. Neither text is
                    // shortened or clipped by this — a headline too long to
                    // share the row simply starts its own line below the
                    // eyebrow, still wrapping to up to 2 lines itself, the
                    // same as before this change.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: HomeNavigatorMetrics.textGap,
                      children: [
                        Text(
                          advice.ctaLabel != null ? '次にやること' : '今月やること',
                          key: const Key('home-navigator-message-label'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (advice.headline case final headline?)
                          Text(
                            headline,
                            key: const Key('home-recommended-action-headline'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    const SizedBox(height: HomeNavigatorMetrics.textGap),
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
                      // PUBLIC-DEMO-HOME-UI-3C: trimmed from 6 — the CTA
                      // itself is unchanged (its height comes from
                      // `minimumSize`, not this gap), so this only removes
                      // slack between it and the message above.
                      // SES HOME Final Density: trimmed again, from 4, then 2.
                      const SizedBox(height: 1),
                      // SES HOME Final Touch: a real device screenshot found
                      // this button visually dominating the card — full
                      // card width and a 48pt/vertical-12 minimum — leaving
                      // the advice bubble below it too little room to stay
                      // unellipsized (see `_AdviceBubble`'s own doc for the
                      // exact defect this was causing). The
                      // `FractionallySizedBox` below narrows the button's
                      // own footprint instead of stretching it across the
                      // full card — both without touching what it does or
                      // where it goes (`advice.onCtaPressed` is untouched).
                      //
                      // Codex review (PR #184, P2): the first cut of this
                      // fix floored the height at 40pt — a real device with
                      // a short label (e.g. "研修する") would then render
                      // (and hit-test) at exactly 40pt, under this app's
                      // own established >=48pt touch-target floor (every
                      // other CTA this file/repo tests pins that number).
                      // 44pt is the largest floor that still fits the
                      // 360x800 no-scroll budget alongside this phase's
                      // other two fixes (the office photo's own size, and
                      // the advice bubble's raised line cap) — verified
                      // against both the normal-April and the tighter
                      // actual-cash-shortage 360x800 scenarios (see
                      // `public_demo_01_issue_124_screen_verification_test
                      // .dart`'s HOME-COMPACT-1B.4 FIX1 group). Still a
                      // real, deliberate reduction from the original 48
                      // (Apple's own HIG accessible-minimum is 44pt), not
                      // the ad-hoc 40pt the first cut used.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.86,
                          child: FilledButton.icon(
                            key: const Key('home-recommended-action-cta'),
                            style: theme.filledButtonTheme.style?.copyWith(
                              minimumSize: const WidgetStatePropertyAll(
                                Size(0, 44),
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              // Material buttons otherwise pad their tap
                              // target up to the platform's accessibility
                              // floor (48pt) regardless of `minimumSize` —
                              // `shrinkWrap` is what actually lets the
                              // button render at the smaller size above
                              // instead of silently staying 48pt tall.
                              // `minimumSize` still floors it at a real
                              // 44pt tap target — see the doc above this
                              // widget for why 44, not 40 or 48.
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: advice.onCtaPressed,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text(
                              ctaLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (advice.secondaryLabel case final secondaryLabel?) ...[
                      // PUBLIC-DEMO-HOME-UI-3C: trimmed from 6, same
                      // reasoning as the primary CTA's own gap above — the
                      // 48pt minimum height is untouched.
                      // SES HOME Final Density: trimmed again, from 4, then 2.
                      const SizedBox(height: 1),
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
/// HOME-COMPACT-1B.4: tightened padding and a two-line cap on the
/// explanation itself — the acceptance criteria ask this bubble not to
/// press against the card's height budget the way an unbounded paragraph
/// could. The message above it (never capped — see the `Text` in [build]
/// above this class) still states the actual guidance in full; this stays
/// what it already was, the optional educational "why", just shown at a
/// size that cannot grow past three lines by default.
///
/// HOME-COMPACT-1B.4 FIX2 (Codex P2): the two-line cap above silently
/// truncated real copy — several existing explanation strings (43-56
/// characters, e.g. April's own SkillSheet guidance) run past two lines at
/// the target widths and painted with a trailing `…` and no way to read
/// the rest, which is exactly the "same fact, permanently harder to read"
/// regression PUBLIC-DEMO-HOME-UI-3A's own removal of the old "詳しく見る"
/// toggle was trying to avoid in the other direction. This restores a
/// one-way reveal — never a collapse-back toggle, so it is not the same
/// control PUBLIC-DEMO-HOME-UI-3A removed — and only when [explanation]
/// would genuinely overflow the cap at the bubble's real width: a short
/// explanation that already fits gets no button at all. Expanding costs
/// exactly the card height the full text needs, the same way an increased
/// text scale is already allowed to grow this card (see
/// [HomeNavigatorMetrics.compactCeiling]'s own doc) — never a fixed height
/// around text.
///
/// SES HOME Final Touch: the cap itself raises from two lines to three. A
/// real device screenshot (real NotoSansJP glyphs, not `flutter test`'s
/// substituted ones — see this file's own doc a few lines below for why
/// that gap exists) found April's own explanation above still needing a
/// "続きを読む" reveal it should not have — the room this phase buys back
/// from the primary CTA's shrink (see the `home-recommended-action-cta`
/// button's own doc) goes here, so the same explanation that used to need
/// a tap now reads in full immediately for anyone whose text fits three
/// lines.
class _AdviceBubble extends StatefulWidget {
  const _AdviceBubble({required this.advice});

  final HomeNavigatorAdvice advice;

  @override
  State<_AdviceBubble> createState() => _AdviceBubbleState();
}

class _AdviceBubbleState extends State<_AdviceBubble> {
  bool _expanded = false;

  /// SES HOME Final Touch: raised from 2 — see the class doc above for why.
  static const int _collapsedMaxLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final explanationStyle = theme.textTheme.bodySmall?.copyWith(
      height: 1.25,
      fontSize: 11,
      color: scheme.onSurfaceVariant,
    );
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
          // PUBLIC-DEMO-HOME-UI-3C: trimmed vertical padding from 3 — the
          // bubble is the last thing inside a card whose height is already
          // budgeted, and this is real slack, not a text-height floor.
          // SES HOME Final Density: trimmed again, from 2, then 1.
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
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
              if (widget.advice.explanation case final explanation?)
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Real overflow check, not a character-count guess: a
                    // 43-character explanation can fit three lines at 390pt
                    // and overflow at 360pt, so whether the reveal control
                    // renders at all is decided against the bubble's own
                    // measured width, in this build's own text direction
                    // and ambient text-scale — the same way `didExceedMaxLines`
                    // already backs this file's other clipping tests.
                    final overflows =
                        !_expanded &&
                        (TextPainter(
                              text: TextSpan(
                                text: explanation,
                                style: explanationStyle,
                              ),
                              maxLines: _collapsedMaxLines,
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                            )..layout(maxWidth: constraints.maxWidth))
                            .didExceedMaxLines;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          explanation,
                          key: const Key('home-navigator-advice-explanation'),
                          style: explanationStyle,
                          maxLines: _expanded ? null : _collapsedMaxLines,
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                        if (overflows)
                          InkWell(
                            key: const Key('home-navigator-advice-expand'),
                            onTap: () => setState(() => _expanded = true),
                            child: Text(
                              '続きを読む',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                                fontSize: 10,
                                height: 1,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
      size: widget.layout.portraitWidth * 0.6,
      color: scheme.onSurfaceVariant,
    );

    return SizedBox(
      height: widget.layout.portraitHeight,
      width: widget.layout.portraitWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
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
