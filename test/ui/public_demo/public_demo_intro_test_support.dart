import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// SES_PUBLIC-DEMO-INTRO-1A test support.
///
/// The fresh-start intro dialog (`PublicDemoIntroDialog`) now appears,
/// barrier-dismissible false, over any `PublicDemo01PlaceholderScreen` that
/// restores with no prior save. Call this once, immediately after the
/// screen's first pump, before any test drives an interaction with the
/// screen underneath — it settles the dialog's entrance if one is showing,
/// dismisses it, and settles again. Safe to call unconditionally: a test
/// whose save service returns an existing aggregate never shows the
/// dialog, so this is a no-op wait-and-check for those.
Future<void> dismissPublicDemoIntroIfPresent(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final confirm = find.byKey(const Key('public-demo-intro-dialog-confirm'));
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }
}
