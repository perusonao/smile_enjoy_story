import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'app/app_entry.dart';
import 'app/app_experience.dart';
import 'app/game_controller.dart';
import 'app/game_scope.dart';
import 'app/nav_scope.dart';
import 'app/public_demo_session_marker.dart';
import 'game/game.dart';
import 'game/persistence/public_demo_opening_marker.dart';
import 'game/persistence/public_demo_save_service.dart';
import 'game/persistence/save_service.dart';
import 'ui/main_shell.dart';
import 'ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'ui/prologue/prologue_screen.dart';
import 'ui/result/game_over_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/phone_frame.dart';
import 'ui/widgets/start_choice_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final launchParams = Uri.base.queryParameters;
  final experience = resolveAppExperience(Uri.base);

  // QA/E2E-only hook (Playwright harness — see /e2e/README.md), never set by
  // a real player's URL. Flutter Web paints to a bare <canvas> with no DOM
  // text at all until something enables the semantics tree (normally a
  // screen-reader user tapping the "Enable accessibility" placeholder);
  // headless CDP automation can't reliably trigger that placeholder click,
  // so `?e2e=1` force-enables semantics up front instead. This only changes
  // what's exposed to the accessibility tree/DOM for automation — it alters
  // no game logic, no probabilities, and nothing a normal player sees.
  if (launchParams['e2e'] == '1') {
    SemanticsBinding.instance.ensureSemantics();
  }

  // QA/E2E-only market-seed override (`?seed=12345`), threaded into the
  // existing `PrologueEngine`/`GameEngine` `seed` parameter so a Playwright
  // run can reproduce one specific playthrough on demand. `null` for every
  // normal launch, which keeps drawing a fresh random seed exactly as
  // before this hook existed.
  final seedParam = launchParams['seed'];
  final debugSeed = seedParam != null ? int.tryParse(seedParam) : null;

  runApp(
    SesApp(
      experience: experience,
      controller: GameController(
        debugSeed: debugSeed,
        saveService: SaveService.forExperience(experience),
      ),
      // FIRST-FUN-YEAR P1 (Issue #229): the persisted Opening Context marker
      // is opt-out, not opt-in, for exactly the one existing QA/E2E flag
      // above — every real player's URL, and every curated CI smoke/heavy
      // Playwright spec (all of which already navigate through `?e2e=1`,
      // see e2e/helpers/public-demo-player.ts's own `PUBLIC_DEMO_PATH`),
      // stay on opposite sides of this without needing any e2e spec edited.
      // A genuinely fresh e2e run would otherwise see the same Opening
      // Context a genuinely fresh player does and then immediately try to
      // interact with HOME — exactly the interactive-on-first-load contract
      // those specs already assert.
      openingMarker: launchParams['e2e'] == '1'
          ? const PublicDemoOpeningMarker()
          : const PublicDemoOpeningMarker.persistent(),
    ),
  );
}

class SesApp extends StatelessWidget {
  SesApp({
    super.key,
    required this.controller,
    this.experience = AppExperience.development,
    this.openingMarker = const PublicDemoOpeningMarker.persistent(),
  });

  final GameController controller;
  final AppExperience experience;

  /// Threaded straight through to [PublicDemo01PlaceholderScreen] — see
  /// [PublicDemoOpeningMarker]'s own doc for why this defaults to
  /// [PublicDemoOpeningMarker.persistent] here (every real/e2e entry point
  /// goes through this constructor) while that screen's own bare default
  /// stays the inert marker (every widget test that constructs it directly
  /// instead).
  final PublicDemoOpeningMarker openingMarker;
  final ValueNotifier<int> _tabIndex = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    return GameScope(
      controller: controller,
      child: NavScope(
        tabIndex: _tabIndex,
        child: MaterialApp(
          title: 'S.E.S. - Smile. Enjoy. Story.',
          debugShowCheckedModeBanner: false,
          theme: SesTheme.build(),
          home: _GameRoot(
            experience: experience,
            openingMarker: openingMarker,
          ),
        ),
      ),
    );
  }
}

/// Swaps between the loading state, the main game shell, and the
/// end-of-game screens based on [GameController.state.status].
///
/// SES-FIRST-FUN-YEAR-RELOAD-1 (P0 PLAYTHROUGH BLOCKER — 復帰不能): also
/// resolves the [AppExperience.development] → [AppExperience.publicDemo01]
/// save-based fallback (see [resolveAppExperienceWithSaveFallback]'s own
/// doc in app_entry.dart for the full root-cause) from *inside* this
/// widget's [State.initState], not from `main()` before [runApp]. A save
/// check that early was tried first and reproducibly returned "no save"
/// even for a save that was genuinely present in `localStorage` moments
/// earlier — `SharedPreferences`'s Flutter-Web plugin registration is not
/// guaranteed complete that early in the engine boot sequence. Running the
/// exact same check from a mounted widget's `initState` instead matches
/// the one already-proven-reliable place this codebase does this kind of
/// check (`PublicDemo01PlaceholderScreen._restoreAggregate`, exercised by
/// every real playthrough this session ran).
class _GameRoot extends StatefulWidget {
  const _GameRoot({required this.experience, required this.openingMarker});

  final AppExperience experience;
  final PublicDemoOpeningMarker openingMarker;

  @override
  State<_GameRoot> createState() => _GameRootState();
}

class _GameRootState extends State<_GameRoot> {
  late AppExperience _resolvedExperience = widget.experience;

  /// True only while the one-time save-based fallback check (below) is
  /// still in flight — never true at all when the URL already resolved to
  /// something other than [AppExperience.development], so a normal
  /// Public-Demo or Development launch never waits on this.
  late bool _checkingPublicDemoFallback =
      widget.experience == AppExperience.development;

  @override
  void initState() {
    super.initState();
    // PR #164 review (merge blocker, P1): mark this tab as "showing Public
    // Demo" the moment an explicit `#/public-demo-01` URL lands here, not
    // only when the save-based fallback below picks Public Demo. Without
    // this, a first-ever explicit Public Demo visit would leave no marker
    // for its own later same-tab reload to find — see
    // [resolveAppExperienceWithSaveFallback]'s doc in app_entry.dart.
    if (widget.experience == AppExperience.publicDemo01) {
      writePublicDemoSessionMarker();
    }
    if (_checkingPublicDemoFallback) {
      unawaited(_resolvePublicDemoFallback());
    }
  }

  Future<void> _resolvePublicDemoFallback() async {
    final hasPublicDemoSave =
        await const PublicDemoSaveService().load() != null;
    if (!mounted) return;
    final resolved = resolveAppExperienceWithSaveFallback(
      fromUrl: widget.experience,
      hasPublicDemoSave: hasPublicDemoSave,
      wasPublicDemoThisSession: readPublicDemoSessionMarker(),
    );
    if (resolved == AppExperience.publicDemo01) {
      // Keep the marker fresh so a *later* reload of this same tab still
      // resolves correctly, exactly like the initState write above.
      writePublicDemoSessionMarker();
    }
    setState(() {
      _resolvedExperience = resolved;
      _checkingPublicDemoFallback = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: context.game,
      builder: (context, _) {
        final controller = context.game;
        if (controller.isLoading || _checkingPublicDemoFallback) {
          return const PhoneFrame(
            child: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        if (_resolvedExperience == AppExperience.publicDemo01) {
          // FIRST-FUN-YEAR P1 (Issue #229): [widget.openingMarker] is
          // [SesApp]'s own persisted-by-default marker, except under `?e2e=1`
          // (see `main()`'s own doc) — see [PublicDemoOpeningMarker]'s doc
          // for why every existing widget test constructing
          // [PublicDemo01PlaceholderScreen] directly instead keeps its inert
          // default, unaffected by this.
          return PhoneFrame(
            child: PublicDemo01PlaceholderScreen(
              openingMarker: widget.openingMarker,
            ),
          );
        }
        if (controller.showStartChoice) {
          return const PhoneFrame(child: StartChoiceScreen());
        }
        switch (controller.state.status) {
          case GameStatus.playing:
            if (controller.state.prologueState.active) {
              return const PhoneFrame(child: PrologueScreen());
            }
            return const MainShell();
          case GameStatus.finished:
            return const PhoneFrame(child: ResultScreen());
          case GameStatus.bankrupt:
            return const PhoneFrame(child: GameOverScreen());
        }
      },
    );
  }
}
