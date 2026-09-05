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
  ///
  /// SES-ISSUE-124 (Screen Verification follow-up): shrunk from the
  /// original 108/120 so the "社員の様子" photo no longer spends most of
  /// the initial portrait viewport it shares with the duplicate "社員ステ
  /// ージ" list below it — the two are consolidated by PublicDemo01's own
  /// compaction of that legacy card, not by anything in this file. Sized
  /// to still clear each portrait + its name pill with margin (see the
  /// per-mode figure-height math in the class doc history), never to the
  /// safety ceiling.
  // HOME-COMPACT-1B.4: compact shrunk again, from 64, so the whole card can
  // fit back inside the unscrolled initial view alongside 月/KPI/ひより/月次
  // CTA — see the acceptance criteria this phase's result report records.
  // 60 is the floor: a compact portrait (28pt, an image — does not grow
  // with text scale) plus its name pill needs ~46pt inside the scene's 6pt
  // figure padding (see `_MemberFigure` and the bottom-left figure Row's
  // own padding) once the pill's own `textScaler.clamp(maxScaleFactor:
  // 1.15)` is accounted for — every ambient scale at or above 1.15 clamps
  // to that same effective 1.15, so this floor already covers every larger
  // scale too, not only the default. Going lower overflows that Column,
  // caught by this exact suite (and the runtime HOME navigator viewport
  // suite, at 1.15x+) when this was tried smaller.
  static const double compactSceneHeight = 60;
  static const double normalSceneHeight = 70;

  /// 360x800 — the smaller of the two required targets.
  static const HomeOfficeStageLayout compact = HomeOfficeStageLayout(
    sceneHeight: compactSceneHeight,
    portraitSize: 28,
    nameFontSize: 8,
    horizontalGap: 6,
  );

  /// 390x844.
  static const HomeOfficeStageLayout normal = HomeOfficeStageLayout(
    sceneHeight: normalSceneHeight,
    portraitSize: 32,
    nameFontSize: 9,
    horizontalGap: 8,
  );

  /// Height the card spends on everything that is not the scene itself:
  /// the title row plus the card's own vertical padding. Constant across
  /// both modes, so `component = scene + chrome` holds in both.
  ///
  /// SES-ISSUE-124: the padding/gap below is trimmed from the original
  /// 10/8/10 alongside the scene shrink above — same reason, same budget.
  static const double chromeHeight =
      _cardPaddingTop + _titleRowHeight + _titleGap + _cardPaddingBottom;

  // PUBLIC-DEMO-HOME-UI-3C: trimmed from 3/3/2 as part of "slightly compact
  // employee summary" (Issue #173) — the same real-slack-not-text-floor
  // reasoning HOME-COMPACT-1B.4 already used for this padding/gap pair.
  static const double _cardPaddingTop = 2;
  static const double _cardPaddingBottom = 2;
  static const double _cardPaddingHorizontal = 12;
  // _titleRowHeight is kept at 20 rather than shrunk further: it is a
  // MINIMUM constraint on the title row (see the widget body below), not a
  // fixed size, so lowering it below the title text's own intrinsic height
  // would not save any real space — it would only make this formula
  // under-count the actual rendered height, which is exactly what broke
  // the layout-safety tests during SES-ISSUE-124's first pass at this.
  // HOME-COMPACT-1B.4 trims _titleGap (a real gap, not a text-height floor)
  // from 8 for the same reason it trims the paddings above.
  static const double _titleRowHeight = 20;
  static const double _titleGap = 1;

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
                    // HOME-COMPACT-1B.4: the aggregate headcount/waiting
                    // summary — see [HomeOfficeStageDisplay.hasHeadcountSummary]'s
                    // own doc for what this is a claim about. Painted as an
                    // overlay on the scene itself, not a new row below the
                    // title, so this card's total height is exactly what it
                    // was before this addition — the layout-safety tests
                    // pin the card to the same [HomeOfficeStageMetrics]
                    // budget this phase does not get to spend more of.
                    if (display.hasHeadcountSummary)
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: _HeadcountSummaryChip(
                            employeeCount: display.employeeCount!,
                            waitingCount: display.waitingCount!,
                            layout: layout,
                          ),
                        ),
                      ),
                    if (visible.isEmpty)
                      const _EmptyOffice()
                    else
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          // HOME-COMPACT-1B.4: trimmed from 8 alongside
                          // compactSceneHeight's own shrink — see its doc.
                          padding: const EdgeInsets.all(6),
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

/// The aggregate "社員N名 ・ 待機N名" pill — see
/// [HomeOfficeStageDisplay.hasHeadcountSummary]'s doc for its authority and
/// for why this is deliberately the whole company's totals, never a
/// per-employee label.
class _HeadcountSummaryChip extends StatelessWidget {
  const _HeadcountSummaryChip({
    required this.employeeCount,
    required this.waitingCount,
    required this.layout,
  });

  final int employeeCount;
  final int waitingCount;
  final HomeOfficeStageLayout layout;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        '社員$employeeCount名・待機$waitingCount名',
        key: const Key('home-office-stage-headcount-summary'),
        style: TextStyle(
          color: Colors.white,
          fontSize: layout.nameFontSize,
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
          //
          // SES-ISSUE-124: the scene itself is now sized to the compacted
          // HOME budget, not to the original design's generous 2x-scale
          // margin — so this caption's own text-scale growth is capped
          // rather than left unbounded. The name is never the only place
          // it appears (the portrait itself, plus the always-present, fully
          // scaling per-employee cards below), so a capped decorative
          // caption over a photo does not cost legibility the way an
          // uncapped body-text control would.
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
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.15),
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
                  // SES-ISSUE-124: same capped-caption reasoning as
                  // _MemberFigure's own name label — see its doc comment.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.15),
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
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.15),
          ),
        ],
      ),
    );
  }
}
