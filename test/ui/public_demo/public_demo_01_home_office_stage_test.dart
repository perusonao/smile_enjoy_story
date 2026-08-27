// HOME-RUNTIME-2B: the Office Stage on the REAL Public Demo screen.
//
// The component suite (test/presentation/home/home_office_stage_section_test
// .dart) pins the widget and its display model in isolation. This suite
// pins the things only the real screen can answer:
//
//  * where the section sits in the runtime HOME order,
//  * that the roster it draws is the authority's own employee list rather
//    than a second, drifting copy of it,
//  * that HOME-RUNTIME-2C's Recommended Action is untouched — same slot,
//    same CTA, same dispatch — after a whole visual layer was added under
//    it,
//  * and that the section added no mutation authority to a screen whose
//    single whitelisted mutation entry point is that CTA.
//
// Every trajectory below drives the real screen, and therefore the real
// PublicDemoAggregate behind it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_office_stage_display.dart';
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

HomeOfficeStageDisplay stageDisplay(WidgetTester tester) => tester
    .widget<HomeOfficeStageSection>(find.byType(HomeOfficeStageSection))
    .display;

Finder get stageFinder => find.byKey(const Key('home-office-stage'));

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

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

Future<void> dismiss(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

Future<void> pumpDemoAt(
  WidgetTester tester, [
  Size size = const Size(390, 844),
]) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  await tester.pumpAndSettle();
}

/// April, played to a won May order for 佐藤 健 — the shared opening of the
/// existing playthrough suites.
Future<void> playApril(WidgetTester tester) async {
  await tapAndSettle(tester, 'SkillSheet確認');
  await tapAndSettle(tester, '営業開始');
  await tapAndSettle(tester, '案件紹介');
  await tapAndSettle(tester, '上位会社面談');
  await dismiss(tester);
  await tapAndSettle(tester, '客先面談');
  await dismiss(tester);
  await tapAndSettle(tester, '受注');
  await dismiss(tester);
}

void main() {
  group('A: the Office Stage renders after the Recommended Action', () {
    testWidgets('it is present on the runtime HOME from the first frame', (
      tester,
    ) async {
      await pumpDemoAt(tester);
      expect(find.byType(HomeOfficeStageSection), findsOneWidget);
      expect(stageFinder, findsOneWidget);
      expect(
        find.byKey(const Key('home-office-stage-background')),
        findsOneWidget,
      );
    });

    testWidgets('the order is Recommended Action, then Office Stage, then '
        'the legacy content', (tester) async {
      await pumpDemoAt(tester);

      final recommended = tester.getRect(find.byType(RecommendedActionSection));
      final stage = tester.getRect(stageFinder);
      final legacy = tester.getRect(actionButton('SkillSheet確認'));

      // The primary interaction stays above the visual layer. This is the
      // one ordering rule the phase must not trade away for a better
      // looking screen.
      expect(
        stage.top,
        greaterThanOrEqualTo(recommended.bottom),
        reason:
            'the Office Stage must never rise above the Recommended '
            'Action: $stage vs $recommended',
      );
      expect(stage.bottom, lessThanOrEqualTo(legacy.top));
    });

    testWidgets('it is a sibling of the HOME projection mount, not a child', (
      tester,
    ) async {
      // The read-only dashboard section is the boundary the projection
      // crosses; the Office Stage is resolved by the owner separately (it
      // needs workflow facts the projection deliberately cannot see), so it
      // must not appear inside that subtree.
      await pumpDemoAt(tester);
      expect(
        find.descendant(
          of: find.byType(PublicDemoHomeDashboardSection),
          matching: find.byType(HomeOfficeStageSection),
        ),
        findsNothing,
      );
    });
  });

  group('D-G: the roster is the authority\'s, not a second copy', () {
    testWidgets('April: both founding employees are on the stage, waiting', (
      tester,
    ) async {
      await pumpDemoAt(tester);

      final display = stageDisplay(tester);
      final workflow = currentWorkflow(tester);

      expect(display.members.length, workflow.engineers.length);
      expect(
        display.members.map((m) => m.id).toList(),
        workflow.engineers.map((e) => e.id).toList(),
        reason: 'roster order must be the authority\'s emission order',
      );
      expect(
        display.members.map((m) => m.name).toList(),
        workflow.engineers.map((e) => e.name).toList(),
      );
      expect(display.hiddenMemberCount, 0);
      expect(display.members.length, currentState(tester).engineerCount);

      expect(find.text('佐藤 健'), findsWidgets);
      expect(find.text('鈴木 葵'), findsWidgets);
    });

    testWidgets('the roster keeps agreeing with the headcount authority '
        'across a real trajectory into May and June', (tester) async {
      await pumpDemoAt(tester);

      void assertRosterMatchesAuthority(String where) {
        final display = stageDisplay(tester);
        final state = currentState(tester);
        final workflow = currentWorkflow(tester);

        expect(
          display.members.map((m) => m.id).toList(),
          workflow.engineers.map((e) => e.id).toList(),
          reason: 'roster drifted from the authority at $where',
        );
        // The Office Stage sits directly under the KPI's 社員 tile, so a
        // roster that could disagree with `engineerCount` would put two
        // different headcounts on one screen.
        expect(
          display.members.length,
          state.engineerCount,
          reason: 'headcount disagreed with the KPI authority at $where',
        );
      }

      assertRosterMatchesAuthority('April open');

      await playApril(tester);
      assertRosterMatchesAuthority('April, order won');

      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      expect(currentState(tester).month, 5);
      assertRosterMatchesAuthority('May');

      await tapAndSettle(tester, '5月終了→6月');
      expect(currentState(tester).month, 6);
      assertRosterMatchesAuthority('June');
    });

    testWidgets('the stage states no participation split of its own', (
      tester,
    ) async {
      // The KPI above owns 参画/待機. Three authorities disagree about the
      // per-employee version of that fact at different points in a month
      // (notably: in May the finance count already reads 1 while
      // `workflow.assignments` is still empty until closeMay builds it), so
      // 2B renders none of them rather than contradicting the row above.
      await pumpDemoAt(tester);
      expect(
        find.descendant(of: stageFinder, matching: find.textContaining('参画')),
        findsNothing,
      );
      expect(
        find.descendant(of: stageFinder, matching: find.textContaining('待機')),
        findsNothing,
      );
    });

    testWidgets('every drawn employee has a real bundled portrait', (
      tester,
    ) async {
      await pumpDemoAt(tester);
      for (final member in stageDisplay(tester).members) {
        expect(member.portraitAssetPath, isNotNull);
        expect(
          member.portraitAssetPath,
          homeOfficeStagePortraitFor(member.id),
          reason: 'portraits must come from the deterministic mapping',
        );
      }
    });

    testWidgets('the same screen state redraws the same stage', (tester) async {
      await pumpDemoAt(tester);
      final first = stageDisplay(tester);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(stageDisplay(tester), first);
    });
  });

  group('L: HOME-RUNTIME-2C is unchanged', () {
    testWidgets('the Recommended Action slot, CTA and headline are intact', (
      tester,
    ) async {
      await pumpDemoAt(tester);

      expect(find.byType(RecommendedActionSection), findsOneWidget);
      expect(find.byKey(const Key('home-recommended-action')), findsOneWidget);
      expect(
        find.byKey(const Key('home-recommended-action-cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home-recommended-action-headline')),
        findsOneWidget,
      );
      // April's recommendation is still 2C's SkillSheet step, with 2C's
      // own CTA label — unchanged by 2B.
      expect(
        find.descendant(
          of: find.byKey(const Key('home-recommended-action-cta')),
          matching: find.text('SkillSheetを確認'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the CTA still dispatches the same domain command', (
      tester,
    ) async {
      await pumpDemoAt(tester);

      final before = currentWorkflow(tester).engineers.first.stage;
      await tester.tap(find.byKey(const Key('home-recommended-action-cta')));
      await settle(tester);

      expect(
        currentWorkflow(tester).engineers.first.stage,
        isNot(before),
        reason: 'the 2C CTA must still move the real workflow',
      );
      // ...and the recommendation moves on to the next step, as in 2C.
      expect(
        find.descendant(
          of: find.byKey(const Key('home-recommended-action-cta')),
          matching: find.text('営業を開始'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the Office Stage did not move the CTA', (tester) async {
      // The Office Stage is placed below the CTA precisely so that adding
      // it costs the CTA's position nothing. Pinned as an equality against
      // the section above it, not as a magic number.
      await pumpDemoAt(tester, const Size(360, 800));
      final cta = tester.getRect(
        find.byKey(const Key('home-recommended-action-cta')),
      );
      final home = tester.getRect(find.byType(PublicDemoHomeDashboardSection));
      expect(cta.bottom, lessThan(home.bottom));
      expect(tester.getRect(stageFinder).top, greaterThan(home.bottom));
    });
  });

  group('M, N: no new authority, no overflow on the real screen', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('N: the runtime HOME lays out without overflow at $label', (
        tester,
      ) async {
        await pumpDemoAt(tester, size);
        expect(tester.takeException(), isNull);

        final stage = tester.getRect(stageFinder);
        expect(stage.left, greaterThanOrEqualTo(0));
        expect(stage.right, lessThanOrEqualTo(size.width));
        expect(
          stage.height,
          lessThan(HomeOfficeStageMetrics.safetyCeiling),
          reason: '${stage.height}pt exceeds the 360x800 safety ceiling',
        );
      });
    }

    testWidgets('M: the Office Stage subtree holds no interactive element on '
        'the real screen', (tester) async {
      await pumpDemoAt(tester);
      for (final type in [ButtonStyleButton, InkWell, GestureDetector]) {
        expect(
          find.descendant(of: stageFinder, matching: find.byType(type)),
          findsNothing,
          reason: 'found a $type inside the Office Stage',
        );
      }
    });

    testWidgets('M: adding the Office Stage did not add a second mutation '
        'path — HOME still has exactly one CTA', (tester) async {
      await pumpDemoAt(tester);

      final home = find.byType(PublicDemoHomeDashboardSection);
      expect(
        find.descendant(
          of: home,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsOneWidget,
      );
      // And the visual layer contributes none of its own.
      expect(
        find.descendant(
          of: stageFinder,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsNothing,
      );
    });

    testWidgets('M: the stage state is untouched by rebuilds it does not '
        'cause', (tester) async {
      // Presentation-only means the section cannot originate a state
      // change: pumping frames must not alter the roster.
      await pumpDemoAt(tester);
      final before = stageDisplay(tester);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(stageDisplay(tester), before);
      expect(currentState(tester).month, 4);
    });
  });
}
