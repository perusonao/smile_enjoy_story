import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/presentation/build_info.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

void main() {
  const sha = 'c4beb9e3681ca90e7e0a6481109c71b925dfc72d';

  testWidgets('renders PR number and seven-character SHA', (tester) async {
    final info = BuildInfo.fromValues(commitSha: sha, prNumber: '95');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: BuildInfoLabel(buildInfo: info)),
        ),
      ),
    );

    expect(find.text('Deploy: PR #95 · c4beb9e'), findsOneWidget);
  });

  testWidgets('falls back to SHA when PR number is unavailable', (
    tester,
  ) async {
    final info = BuildInfo.fromValues(commitSha: sha);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: BuildInfoLabel(buildInfo: info)),
        ),
      ),
    );

    expect(find.text('Deploy: c4beb9e'), findsOneWidget);
  });

  testWidgets('missing or invalid metadata fails safely', (tester) async {
    for (final info in [
      BuildInfo.fromValues(),
      BuildInfo.fromValues(commitSha: 'not-a-sha', prNumber: '95'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: BuildInfoLabel(buildInfo: info)),
          ),
        ),
      );
      expect(find.byKey(const Key('build-info-label')), findsNothing);
    }
  });

  test('invalid PR metadata is ignored without hiding a valid SHA', () {
    final info = BuildInfo.fromValues(commitSha: sha, prNumber: 'PR #95');
    expect(info.displayLabel, 'Deploy: c4beb9e');
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('Public Demo header stays compact at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: PublicDemo01PlaceholderScreen(
            buildInfo: BuildInfo.fromValues(commitSha: sha, prNumber: '95'),
          ),
        ),
      );

      expect(find.text('S.E.S. Public Demo 0.1'), findsOneWidget);
      expect(find.text('Deploy: PR #95 · c4beb9e'), findsOneWidget);
      expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
      expect(tester.takeException(), isNull);
    });
  }
}
