import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PUBLIC-DEMO-HOME-UI-3B: shared test helper for switching the Public
/// Demo screen's real bottom-navigation tab. HOME stopped being the one
/// screen everything lived on — content a test used to reach by scrolling
/// (`ensureVisible`) now lives on a different tab and is not built at all
/// unless that tab is selected (see `PublicDemo01PlaceholderScreen.build`'s
/// own doc). Every test that interacts with content now living outside
/// HOME switches tabs through this same helper, which taps the exact
/// `NavigationDestination` the app itself renders — never a shortcut that
/// bypasses the real navigation the production code uses.
enum PublicDemoTab { home, employees, sales, accounting, menu }

extension PublicDemoTabKey on PublicDemoTab {
  Key get navKey => switch (this) {
    PublicDemoTab.home => const Key('public-demo-nav-home'),
    PublicDemoTab.employees => const Key('public-demo-nav-employees'),
    PublicDemoTab.sales => const Key('public-demo-nav-sales'),
    PublicDemoTab.accounting => const Key('public-demo-nav-accounting'),
    PublicDemoTab.menu => const Key('public-demo-nav-menu'),
  };
}

/// Taps the bottom-navigation destination for [tab] and settles. This is
/// the one mechanism PUBLIC-DEMO-HOME-UI-3B provides for reaching another
/// tab's content — it never scrolls, and it never touches game state.
Future<void> switchPublicDemoTab(WidgetTester tester, PublicDemoTab tab) async {
  await tester.tap(find.byKey(tab.navKey));
  await tester.pumpAndSettle();
}
