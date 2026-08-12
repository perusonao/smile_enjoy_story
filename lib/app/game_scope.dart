import 'package:flutter/widgets.dart';

import 'game_controller.dart';

/// Makes a single [GameController] available to the whole widget tree.
///
/// Deliberately hand-rolled (no external state-management package) to keep
/// this prototype's dependency surface small.
class GameScope extends InheritedNotifier<GameController> {
  const GameScope({super.key, required GameController controller, required super.child})
    : super(notifier: controller);

  static GameController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<GameScope>();
    assert(scope != null, 'No GameScope found in context');
    return scope!.notifier!;
  }
}

extension GameScopeContext on BuildContext {
  GameController get game => GameScope.of(this);
}
