import 'package:flutter/material.dart';

import 'app/game_controller.dart';
import 'app/game_scope.dart';
import 'game/game.dart';
import 'ui/main_shell.dart';
import 'ui/result/game_over_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/phone_frame.dart';

void main() {
  runApp(SesApp(controller: GameController()));
}

class SesApp extends StatelessWidget {
  const SesApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return GameScope(
      controller: controller,
      child: MaterialApp(
        title: 'S.E.S. - Smile. Enjoy. Story.',
        debugShowCheckedModeBanner: false,
        theme: SesTheme.build(),
        home: const _GameRoot(),
      ),
    );
  }
}

/// Swaps between the loading state, the main game shell, and the
/// end-of-game screens based on [GameController.state.status].
class _GameRoot extends StatelessWidget {
  const _GameRoot();

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
        switch (controller.state.status) {
          case GameStatus.playing:
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
