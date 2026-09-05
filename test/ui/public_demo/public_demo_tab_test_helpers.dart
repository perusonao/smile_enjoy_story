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

/// Issue #168 FIRST-FUN-YEAR-ONBOARDING-1: April/May/June's month-close CTA
/// now runs the same `PublicDemoMonthGuardWarningDialog` confirmation
/// `closeOrdinaryMonth()` (August-March) already used — a fixture that
/// leaves any genuinely outstanding, already-legal action untouched (e.g. an
/// applicant whose résumé a success-path test never reviews) now sees this
/// dialog before the month actually closes. A no-op when nothing is
/// outstanding, so every existing caller of this helper stays correct
/// whether or not this particular close attempt has anything to warn about.
/// Always proceeds rather than reviewing — recommended items are, by
/// design, always safe to bypass (see `public_demo_01_month_guard_
/// recommended_test.dart`'s own "このまま月末処理を進める" coverage), and a
/// fixture's own success/failure narrative is already established by the
/// real domain actions it took earlier, not by this dialog.
Future<void> dismissMonthGuardIfPresent(WidgetTester tester) async {
  final dialog = find.byKey(
    const Key('public-demo-month-guard-warning-dialog'),
  );
  if (dialog.evaluate().isEmpty) return;
  await tester.tap(find.byKey(const Key('public-demo-month-guard-proceed')));
  // The month-close attempt this dialog paused now resumes past its own
  // `_precacheEventImage`/`showDialog` event sequence (if any) — the same
  // real-time image-decode wait window every other event-dialog caller in
  // this suite already gives it (fake-clock pumps never resolve
  // `MultiFrameImageStreamCompleter` on their own).
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
