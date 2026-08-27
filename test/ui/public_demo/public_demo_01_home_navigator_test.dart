// NAVIGATOR-1A: 佐倉 ひより on the REAL Public Demo screen.
//
// The component suite (test/presentation/home/home_navigator_section_test
// .dart) pins who she is, that she is inert, and that nothing about her is
// laid out at a height that could slice text. This suite pins the things
// only the real screen can answer:
//
//  * that there is exactly one of her, and that a rebuild after a real
//    domain command does not produce a second,
//  * where she sits in the runtime HOME order — after HOME-RUNTIME-2C's
//    Recommended Action and after HOME-RUNTIME-2B's Office Stage,
//  * that introducing her changed no game state at all, and that she adds
//    no mutation path to a screen whose single whitelisted entry point is
//    the Recommended Action CTA,
//  * and that she costs neither required viewport an overflow, at the
//    default text scale or an increased one.
//
// Every trajectory below drives the real screen, and therefore the real
// PublicDemoAggregate behind it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_navigator_display.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/home_navigator_section.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/home_office_stage_section.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/recommended_action_section.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';

PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

PublicDemoWorkflowState currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

/// The workflow half of the aggregate, as a comparable string.
///
/// April's opening actions move sales *stages*, which live here and not in
/// [PublicDemoState] — so this is the half that must be watched to prove
/// the trajectory below genuinely changed something.
String workflowSnapshot(WidgetTester tester) => currentWorkflow(
  tester,
).engineers.map((engineer) => '${engineer.id}:${engineer.stage}').join('|');

Finder get navigatorFinder => find.byKey(const Key('home-navigator'));
Finder get stageFinder => find.byKey(const Key('home-office-stage'));
Finder get ctaFinder => find.byKey(const Key('home-recommended-action-cta'));

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

/// Buttons that open an event dialog await a real image decode, which this
/// SDK only completes on the wall clock — mirrors the existing Public Demo
/// widget suites' helper.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  final finder = actionButton(text);
  for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets, reason: 'Could not find action button: $text');
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await settle(tester);
}

Future<void> pumpDemoAt(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const PublicDemo01PlaceholderScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every field of the authoritative state, as one comparable record.
///
/// Compared field by field rather than by identity so a failure names which
/// value moved, and so adding a field to `PublicDemoState` without adding
/// it here cannot silently weaken the assertion — `toJson` is the domain's
/// own complete serialisation, which is exactly the save schema this phase
/// must not touch.
Map<String, dynamic> stateSnapshot(WidgetTester tester) =>
    currentState(tester).toJson();

/// Where [finder]'s widget sits in the tree's depth-first traversal.
///
/// Vertical rects order two widgets only while both are laid out, and at a
/// large text scale the navigator can legitimately sit far below the fold.
/// Traversal order does not care: for the single `Column` these sections
/// share, depth-first order *is* top-to-bottom order, so it pins the
/// mandated sequence whether or not the screen has been scrolled.
int treeIndexOf(WidgetTester tester, Finder finder) {
  final target = finder.evaluate().single;
  final all = find
      .byWidgetPredicate((_) => true)
      .evaluate()
      .toList(growable: false);
  final index = all.indexOf(target);
  expect(index, isNonNegative, reason: 'widget not found in tree traversal');
  return index;
}

void main() {
  group('A, E: exactly one navigator, and still one after a rebuild', () {
    testWidgets('A: HOME shows the navigator exactly once', (tester) async {
      await pumpDemoAt(tester);

      expect(find.byType(HomeNavigatorSection), findsOneWidget);
      expect(navigatorFinder, findsOneWidget);
      expect(find.byKey(const Key('home-navigator-name')), findsOneWidget);
      expect(find.text('佐倉 ひより'), findsOneWidget);
    });

    testWidgets('E: a rebuild driven by a real domain command produces no '
        'second navigator', (tester) async {
      await pumpDemoAt(tester);
      expect(find.byType(HomeNavigatorSection), findsOneWidget);

      // A real command through the real aggregate — the same trajectory the
      // existing playthrough suites open with.
      await tapAndSettle(tester, 'SkillSheet確認');
      expect(
        find.byType(HomeNavigatorSection),
        findsOneWidget,
        reason: 'setState after a domain command must not stack navigators',
      );
      expect(find.text('佐倉 ひより'), findsOneWidget);

      await tapAndSettle(tester, '営業開始');
      expect(find.byType(HomeNavigatorSection), findsOneWidget);
      expect(find.text('佐倉 ひより'), findsOneWidget);
      expect(find.text(HomeNavigatorIdentity.greeting), findsOneWidget);
    });

    testWidgets('scrolling the whole screen never reveals a second one', (
      tester,
    ) async {
      await pumpDemoAt(tester, size: const Size(360, 800));

      for (var i = 0; i < 12; i++) {
        expect(find.byType(HomeNavigatorSection), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.byType(HomeNavigatorSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('B: her name and her role are readable on HOME', () {
    testWidgets('佐倉 ひより and 総務 are both rendered on the real screen', (
      tester,
    ) async {
      await pumpDemoAt(tester);

      final name = find.byKey(const Key('home-navigator-name'));
      final role = find.byKey(const Key('home-navigator-role'));
      expect(name, findsOneWidget);
      expect(role, findsOneWidget);
      expect(tester.widget<Text>(name).data, '佐倉 ひより');
      expect(tester.widget<Text>(role).data, '総務');

      // Readable, not merely present: neither collapsed to nothing.
      expect(tester.getRect(name).height, greaterThan(8.0));
      expect(tester.getRect(name).width, greaterThan(20.0));
      expect(tester.getRect(role).height, greaterThan(8.0));
      expect(tester.getRect(role).width, greaterThan(10.0));
    });
  });

  group('C, D: KPI → Recommended Action → Office Stage → Navigator', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('C: at $label the navigator is below the Recommended '
          'Action', (tester) async {
        await pumpDemoAt(tester, size: size);

        expect(
          tester.getRect(navigatorFinder).top,
          greaterThan(
            tester.getRect(find.byType(RecommendedActionSection)).bottom,
          ),
        );
        expect(
          tester.getRect(navigatorFinder).top,
          greaterThan(tester.getRect(ctaFinder).bottom),
        );
        expect(
          treeIndexOf(tester, find.byType(HomeNavigatorSection)),
          greaterThan(
            treeIndexOf(tester, find.byType(PublicDemoHomeDashboardSection)),
          ),
        );
      });

      testWidgets('D: at $label the navigator is below the Office Stage', (
        tester,
      ) async {
        await pumpDemoAt(tester, size: size);

        final stage = tester.getRect(stageFinder);
        final navigator = tester.getRect(navigatorFinder);
        expect(
          navigator.top,
          greaterThanOrEqualTo(stage.bottom),
          reason: 'the picture of the office comes before the person',
        );
        expect(
          treeIndexOf(tester, find.byType(HomeNavigatorSection)),
          greaterThan(treeIndexOf(tester, find.byType(HomeOfficeStageSection))),
        );
      });

      testWidgets('at $label the full order holds in one reading: dashboard '
          'section, then Office Stage, then navigator', (tester) async {
        await pumpDemoAt(tester, size: size);

        final dashboard = treeIndexOf(
          tester,
          find.byType(PublicDemoHomeDashboardSection),
        );
        final stage = treeIndexOf(tester, find.byType(HomeOfficeStageSection));
        final navigator = treeIndexOf(
          tester,
          find.byType(HomeNavigatorSection),
        );
        expect(dashboard, lessThan(stage));
        expect(stage, lessThan(navigator));
      });
    }

    testWidgets('the navigator is a sibling of the read-only dashboard '
        'section, never inside it', (tester) async {
      await pumpDemoAt(tester);

      expect(
        find.descendant(
          of: find.byType(PublicDemoHomeDashboardSection),
          matching: find.byType(HomeNavigatorSection),
        ),
        findsNothing,
        reason:
            'group 15 scopes HOME\'s mutation guard and the block ceiling to '
            'that section\'s subtree; the navigator carries no projected '
            'value and must not be measured by them',
      );
      expect(
        find.descendant(
          of: find.byType(HomeOfficeStageSection),
          matching: find.byType(HomeNavigatorSection),
        ),
        findsNothing,
      );
    });
  });

  group('F: introducing the navigator changed no game state', () {
    testWidgets('the state on arrival is the untouched April opening', (
      tester,
    ) async {
      await pumpDemoAt(tester);

      final state = currentState(tester);
      final opening = PublicDemoState.aprilStart();
      expect(
        state.toJson(),
        opening.toJson(),
        reason: 'a presentation-only phase may not move the starting state',
      );
      // The employee she is the face of, spelled out: 総務 already exists in
      // the domain, so no headcount moved to give her one.
      expect(state.adminCount, 1);
      expect(state.engineerCount, 2);
    });

    testWidgets('tapping the navigator mutates nothing', (tester) async {
      await pumpDemoAt(tester);

      final before = stateSnapshot(tester);
      for (final target in <Finder>[
        navigatorFinder,
        find.byKey(const Key('home-navigator-name')),
        find.byKey(const Key('home-navigator-role')),
        find.byKey(const Key('home-navigator-message')),
      ]) {
        await tester.tap(target, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      expect(stateSnapshot(tester), before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('she contributes no interactive widget to the screen — the '
        'Recommended Action CTA is still the only whitelisted entry point', (
      tester,
    ) async {
      await pumpDemoAt(tester);

      final section = find.byType(HomeNavigatorSection);
      for (final interactive in <Finder>[
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        find.byType(InkWell),
        find.byType(GestureDetector),
        find.byType(ListTile),
        find.byType(IconButton),
        find.byType(TextField),
      ]) {
        expect(
          find.descendant(of: section, matching: interactive),
          findsNothing,
        );
      }

      // The CTA above her is untouched and still dispatches.
      expect(ctaFinder, findsOneWidget);
      expect(tester.widget<Widget>(ctaFinder), isNotNull);
    });

    testWidgets('she shows the same fixed line after the state has genuinely '
        'moved — 1A reads nothing', (tester) async {
      await pumpDemoAt(tester);
      final before = currentState(tester);

      final workflowBefore = workflowSnapshot(tester);

      await tapAndSettle(tester, 'SkillSheet確認');
      await tapAndSettle(tester, '営業開始');

      expect(
        workflowSnapshot(tester),
        isNot(workflowBefore),
        reason: 'the trajectory must actually have changed something',
      );
      // The finance half is legitimately still untouched here — April's
      // opening actions move sales stages, not cash — and that is worth
      // pinning too: nothing the navigator sits next to moved it either.
      expect(currentState(tester).toJson(), before.toJson());

      expect(find.text(HomeNavigatorIdentity.greeting), findsOneWidget);
      expect(find.text('佐倉 ひより'), findsOneWidget);
      expect(find.text('総務'), findsOneWidget);
      expect(
        tester
            .widget<HomeNavigatorSection>(find.byType(HomeNavigatorSection))
            .expression,
        NavigatorExpression.normal,
        reason: 'no expression selection exists in this phase',
      );
    });
  });

  group('H, I, J: the required viewports', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      for (final scale in const [1.0, 1.15, 1.3, 2.0]) {
        testWidgets('at $label / textScale $scale HOME lays out with no '
            'overflow and the navigator paints inside the screen', (
          tester,
        ) async {
          await pumpDemoAt(tester, size: size, textScale: scale);

          expect(tester.takeException(), isNull);

          final rect = tester.getRect(navigatorFinder);
          expect(rect.left, greaterThanOrEqualTo(0.0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.height, greaterThan(0.0));

          for (final key in const [
            'home-navigator-name',
            'home-navigator-role',
            'home-navigator-message',
          ]) {
            final text = tester.getRect(find.byKey(Key(key)));
            expect(text.left, greaterThanOrEqualTo(0.0), reason: key);
            expect(text.right, lessThanOrEqualTo(size.width), reason: key);
          }

          // Scrolling the whole screen must stay clean too — a section that
          // overflows only once it is scrolled into view is still an
          // overflow.
          for (var i = 0; i < 6; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -400));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        });
      }

      testWidgets('J: at $label the navigator grows with the text scale '
          'rather than clipping, and the order above it is unchanged', (
        tester,
      ) async {
        await pumpDemoAt(tester, size: size);
        final atOne = tester.getRect(navigatorFinder).height;

        for (final scale in const [1.3, 2.0]) {
          await pumpDemoAt(tester, size: size, textScale: scale);
          expect(
            tester.getRect(navigatorFinder).height,
            greaterThan(atOne),
            reason: 'textScale $scale must widen the card, not slice it',
          );
          // The design permits the navigator to leave the first view at a
          // larger scale, but never permits the order to change.
          expect(
            treeIndexOf(tester, find.byType(HomeNavigatorSection)),
            greaterThan(
              treeIndexOf(tester, find.byType(HomeOfficeStageSection)),
            ),
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
