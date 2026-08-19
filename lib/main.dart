import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'app/app_entry.dart';
import 'app/app_experience.dart';
import 'app/game_controller.dart';
import 'app/game_scope.dart';
import 'app/nav_scope.dart';
import 'game/game.dart';
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

  runApp(SesApp(
    experience: experience,
    controller: GameController(
      debugSeed: debugSeed,
      saveService: SaveService.forExperience(experience),
    ),
  ));
}

class SesApp extends StatelessWidget {
  SesApp({super.key, required this.controller, this.experience = AppExperience.development});

  final GameController controller;
  final AppExperience experience;
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
          home: _GameRoot(experience: experience),
        ),
      ),
    );
  }
}

/// Swaps between the loading state, the main game shell, and the
/// end-of-game screens based on [GameController.state.status].
class _GameRoot extends StatelessWidget {
  const _GameRoot({required this.experience});

  final AppExperience experience;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: context.game,
      builder: (context, _) {
        final controller = context.game;
        if (controller.isLoading) {
          return const PhoneFrame(
            child: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        if (experience == AppExperience.publicDemo01) {
          return const PhoneFrame(child: PublicDemo01PlaceholderScreen());
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
