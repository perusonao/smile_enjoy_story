// SES First Fun Quarter Mission System Phase 1 — widget coverage for
// [PublicDemoMissionScreen] itself: pumped directly with already-resolved
// [PublicDemoMissionStatusEntry] lists, mirroring how
// `PublicDemo01PlaceholderScreen._openMissionScreen` actually constructs it
// (resolve first, then push a screen that only ever renders the result —
// see that method's own doc). No live aggregate is held by this screen, so
// these tests never need one either.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_mission_resolver.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_mission_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

List<PublicDemoMissionStatusEntry> _freshChain() => [
  for (var i = 0; i < publicDemoAprilMissionChain.length; i++)
    PublicDemoMissionStatusEntry(
      id: publicDemoAprilMissionChain[i],
      status: i == 0
          ? PublicDemoMissionStatus.available
          : PublicDemoMissionStatus.locked,
    ),
];

List<PublicDemoMissionStatusEntry> _partiallyDoneChain() => [
  for (var i = 0; i < publicDemoAprilMissionChain.length; i++)
    PublicDemoMissionStatusEntry(
      id: publicDemoAprilMissionChain[i],
      status: i < 3
          ? PublicDemoMissionStatus.completed
          : (i == 3 ? PublicDemoMissionStatus.available : PublicDemoMissionStatus.locked),
      engineerId: i < 3 ? 'eng-01' : null,
    ),
];

List<PublicDemoMissionStatusEntry> _completeChain() => [
  for (final id in publicDemoAprilMissionChain)
    PublicDemoMissionStatusEntry(
      id: id,
      status: PublicDemoMissionStatus.completed,
      engineerId: 'eng-01',
    ),
];

Widget _wrap(
  List<PublicDemoMissionStatusEntry> missions, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) => MaterialApp(
  theme: SesTheme.build(),
  home: MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: PublicDemoMissionScreen(missions: missions),
  ),
);

void main() {
  group('fresh chain rendering', () {
    testWidgets('shows the April headline, progress 0/8, and the locked '
        'chain', (tester) async {
      await tester.pumpWidget(_wrap(_freshChain()));
      await tester.pumpAndSettle();

      expect(find.text('4月の目標'), findsOneWidget);
      expect(find.text('技術者1名を案件に参画させよう'), findsOneWidget);
      expect(find.text('進捗 0 / 8'), findsOneWidget);
      expect(
        find.byKey(const Key('public-demo-mission-tile-viewSkillSheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('public-demo-mission-complete-banner')),
        findsNothing,
      );
    });
  });

  group('partial progress rendering', () {
    testWidgets('shows progress 3/8 and the current step highlighted', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_partiallyDoneChain()));
      await tester.pumpAndSettle();

      expect(find.text('進捗 3 / 8'), findsOneWidget);
      expect(
        find.byKey(const Key('public-demo-mission-complete-banner')),
        findsNothing,
      );
    });
  });

  group('Mission Complete display', () {
    testWidgets(
      'a fully-completed chain shows MISSION COMPLETE + Hiyori causal '
      'explanation instead of the progress header, exactly once',
      (tester) async {
        // Tall enough that the whole chain + banner + placeholder fit
        // without scrolling — the assertions below just need every widget
        // built, not a specific device size (covered separately by the
        // overflow matrix below).
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(_completeChain(), size: const Size(390, 1600)));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('public-demo-mission-complete-banner')),
          findsOneWidget,
        );
        expect(find.text('MISSION COMPLETE'), findsOneWidget);
        expect(find.text('初めての案件参画！'), findsOneWidget);
        expect(
          find.textContaining('参画すると売上が発生します'),
          findsWidgets,
          reason:
              'the causal 参画→売上, 売上≠入金 explanation must appear '
              'somewhere on completion (banner and/or the final tile\'s own '
              'Hiyori line)',
        );
        // No duplicate main-mission-header banner shown alongside completion.
        expect(
          find.byKey(const Key('public-demo-mission-main-header')),
          findsNothing,
        );
        // "next goal" placeholder does not invent a Phase-1-out-of-scope
        // mission — just a deferred placeholder line.
        expect(find.text('次の経営目標は今後解放されます。'), findsOneWidget);
      },
    );
  });

  group('390x844 / 360x800, TextScaler 1.0/1.3: renders without overflow', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      for (final textScale in [1.0, 1.3]) {
        for (final chain in [_freshChain(), _partiallyDoneChain(), _completeChain()]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(tester.view.reset);

              await tester.pumpWidget(
                _wrap(chain, size: size, textScale: textScale),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });
}
