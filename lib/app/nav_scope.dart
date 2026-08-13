import 'package:flutter/widgets.dart';

/// Makes the bottom-navigation tab index available (and settable) from
/// anywhere in the widget tree, so a Home task can jump straight to the
/// relevant tab (Playable 0.2 §5) without MainShell owning that state
/// privately.
class NavScope extends InheritedWidget {
  const NavScope({super.key, required this.tabIndex, required super.child});

  final ValueNotifier<int> tabIndex;

  static ValueNotifier<int> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NavScope>();
    assert(scope != null, 'No NavScope found in context');
    return scope!.tabIndex;
  }

  @override
  bool updateShouldNotify(NavScope oldWidget) => tabIndex != oldWidget.tabIndex;
}

extension NavScopeContext on BuildContext {
  /// Switches the bottom-navigation tab to [index].
  void switchTab(int index) => NavScope.of(this).value = index;
}
