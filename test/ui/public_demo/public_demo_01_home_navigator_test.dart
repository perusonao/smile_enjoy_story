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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_navigator_display.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/home_navigator_section.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/home_office_stage_section.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';
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
  if (text == 'SkillSheet確認') {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
}

Future<void> pumpDemoAt(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  AssetBundle? assetBundle,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  Widget screen = const PublicDemo01PlaceholderScreen();
  if (assetBundle != null) {
    screen = DefaultAssetBundle(bundle: assetBundle, child: screen);
  }

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fails to load exactly the navigator's portrait and nothing else —
/// every other asset (the Office Stage background, its engineer portraits,
/// fonts) is served by the real bundle. P2-2 asks for an *isolated*
/// navigator asset failure on the real screen, not a screen where every
/// image is broken; a bundle that failed everything would leave this test
/// unable to tell "the navigator's fallback works" apart from "the whole
/// screen degraded and happened not to crash".
class _NavigatorPortraitOnlyFailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == AssetPaths.navigatorHomeCompact) {
      throw FlutterError('simulated asset failure: $key');
    }
    return rootBundle.load(key);
  }
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
  group('NAVIGATOR-1D: real HOME expression and CTA ownership', () {
    testWidgets('neutral advice renders the normal portrait', (tester) async {
      await pumpDemoAt(tester);
      final section = tester.widget<HomeNavigatorSection>(
        find.byType(HomeNavigatorSection),
      );
      expect(section.expression, NavigatorExpression.normal);
      final provider =
          tester
                  .widget<Image>(
                    find.byKey(const Key('home-navigator-portrait')),
                  )
                  .image
              as AssetImage;
      expect(provider.assetName, AssetPaths.navigatorHomeCompact);
    });

    testWidgets(
      'P3: tapping the real HOME Navigator CTA invokes its existing owner once',
      (tester) async {
        await pumpDemoAt(tester);
        final before = workflowSnapshot(tester);
        // SES-FIRST-FUN-YEAR-UI-PHASE-2: the CTA is now always visible on
        // the merged navigator card — no "詳しく見る" tap is needed to reach
        // it first.
        await tester.ensureVisible(ctaFinder);
        await tester.tap(ctaFinder);
        await settle(tester);

        expect(workflowSnapshot(tester), before);
        await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
        await tester.pumpAndSettle();

        expect(
          workflowSnapshot(tester),
          isNot(before),
          reason: 'one tap must reach the existing Recommended Action owner',
        );
        expect(
          currentWorkflow(tester).engineers.first.stage,
          PublicDemoSalesStage.skillSheet,
          reason:
              'one Navigator tap advances exactly the same first workflow step as the legacy Recommended Action CTA',
        );
      },
    );
  });

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
      expect(find.byKey(const Key('home-navigator-message')), findsOneWidget);
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

  group('C, D: company status → Navigator (with its resolved action) → '
      'Employee Status', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('C: at $label the navigator states the resolved action '
          'and its CTA in one card', (tester) async {
        await pumpDemoAt(tester, size: size);

        // SES-FIRST-FUN-YEAR-UI-PHASE-2: the CTA used to live in a
        // separate RecommendedActionSection card below the navigator.
        // The merge folds it into the same card, so the CTA is now a
        // descendant of the navigator rather than sitting below it.
        expect(
          find.descendant(of: navigatorFinder, matching: ctaFinder),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('home-navigator-message-label')),
          findsOneWidget,
        );
        expect(find.textContaining('SkillSheet'), findsWidgets);
      });

      testWidgets('D: at $label the office strip follows the navigator card', (
        tester,
      ) async {
        await pumpDemoAt(tester, size: size);

        final stage = tester.getRect(stageFinder);
        final navigator = tester.getRect(navigatorFinder);
        expect(
          stage.top,
          greaterThanOrEqualTo(navigator.bottom),
          reason: 'Employee Status follows the primary action',
        );
      });

      testWidgets('at $label the full hierarchy holds in one reading', (
        tester,
      ) async {
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
        expect(dashboard, lessThan(navigator));
        expect(navigator, lessThan(stage));
      });
    }

    testWidgets('the navigator belongs inside the dashboard hierarchy, '
        'but not inside the Employee Status office strip', (tester) async {
      await pumpDemoAt(tester);

      expect(
        find.descendant(
          of: find.byType(PublicDemoHomeDashboardSection),
          matching: find.byType(HomeNavigatorSection),
        ),
        findsOneWidget,
        reason:
            'Hiyori belongs between company status and the action she explains',
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

    testWidgets(
      // PUBLIC-DEMO-HOME-UI-3A: the "詳しく見る"/"閉じる" local toggle is
      // gone — the approved visual target shows the explanation open at
      // all times, never gated behind a tap that must be opened before it
      // renders at all. HOME-COMPACT-1B.4 FIX2 (Codex P2) later added a
      // one-way "続きを読む" control that can appear when an explanation
      // would overflow two lines, but it only *reveals more of text that
      // is already on screen* — it never has to be tapped to see the
      // headline, the guidance line, or the explanation in the first
      // place, and it is never a collapse-back toggle like the removed
      // one. Reading the already-visible text changes no state, and the
      // Recommended Action CTA remains the gameplay entry point.
      'the explanation is visible without opening anything; reading it '
      'is presentation-only and the Recommended Action CTA remains the '
      'gameplay entry point',
      (tester) async {
        await pumpDemoAt(tester);
        final before = stateSnapshot(tester);
        final workflowBefore = workflowSnapshot(tester);

        expect(find.text('佐藤 健のSkillSheetを確認'), findsOneWidget);
        expect(find.text('SkillSheetの内容を確認しましょう。'), findsOneWidget);
        expect(
          find.text('SkillSheetは、経験やスキルを案件へ伝えるための資料です。内容を確認して次の手続きに備えます。'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('home-navigator-open-advice')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('home-navigator-close-advice')),
          findsNothing,
        );

        expect(stateSnapshot(tester), before);
        expect(workflowSnapshot(tester), workflowBefore);
        expect(ctaFinder, findsOneWidget);
      },
    );

    testWidgets('the always-visible advice leaves the existing CTA '
        'available and its real owner dispatch still progresses workflow', (
      tester,
    ) async {
      await pumpDemoAt(tester);
      final before = workflowSnapshot(tester);
      await tapAndSettle(tester, 'SkillSheet確認');
      expect(workflowSnapshot(tester), isNot(before));
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

      // 1A's "reads nothing" claim is about the navigator's own identity
      // and expression, not about the guidance text — that legitimately
      // follows the resolved action (NAVIGATOR-1C onward). Name, role and
      // expression are what stay fixed.
      expect(find.text('佐倉 ひより'), findsOneWidget);
      expect(find.text('総務'), findsOneWidget);
      expect(find.byKey(const Key('home-navigator-message')), findsOneWidget);
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
            lessThan(treeIndexOf(tester, find.byType(HomeOfficeStageSection))),
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('P2-2: a Navigator asset failure cannot block HOME progression', () {
    testWidgets('with the navigator portrait failing to load, the fallback '
        'renders AND the real Recommended Action CTA still dispatches the '
        'real production handler', (tester) async {
      // 1. Render the real HOME with exactly the navigator's asset failing
      // — every other asset (Office Stage background/portraits, fonts) is
      // served normally, so a failure elsewhere in the screen cannot be
      // mistaken for the property this test is about.
      await pumpDemoAt(
        tester,
        assetBundle: _NavigatorPortraitOnlyFailingBundle(),
      );
      // The decode failure surfaces asynchronously; give it real wall-clock
      // time to land, the way the existing Public Demo image suites do.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'a broken navigator asset must not throw out of layout',
      );

      // 2. The navigator itself degraded to its silhouette fallback rather
      // than disappearing or crashing the section around it. The `Image`
      // widget itself is still constructed (its asset path is non-null —
      // this is a decode failure, not a missing-artwork case) but its
      // errorBuilder took over what it renders, which is what the fallback
      // key appearing proves.
      expect(find.byType(HomeNavigatorSection), findsOneWidget);
      expect(
        find.byKey(const Key('home-navigator-portrait-fallback')),
        findsOneWidget,
        reason:
            'the errorBuilder fallback must render in place of the '
            'failed image',
      );
      expect(find.text('佐倉 ひより'), findsOneWidget);
      expect(find.text('総務'), findsOneWidget);
      expect(find.byKey(const Key('home-navigator-message')), findsOneWidget);

      // 3. The existing Recommended Action CTA is unaffected — still
      // present, still inside the same navigator card, still the real
      // production widget (not a stand-in).
      expect(ctaFinder, findsOneWidget);
      final ctaLabel = tester.widget<Text>(
        find.descendant(of: ctaFinder, matching: find.byType(Text)).first,
      );
      expect(ctaLabel.data, isNotEmpty);

      // 4. Actually tap it — no mocking of the HOME action path, no
      // stand-in handler. This is the same `SkillSheet確認` production
      // button the existing playthrough suites open with.
      final workflowBefore = workflowSnapshot(tester);
      expect(
        currentWorkflow(tester).engineers.first.stage,
        PublicDemoSalesStage.waiting,
        reason:
            'the trajectory this test drives assumes April\'s opening '
            'state — 佐藤健 still waiting',
      );

      await tapAndSettle(tester, 'SkillSheet確認');

      // 5. The expected existing destination/action actually occurred: the
      // real owner dispatch ran `_startSkillSheetReview`, advancing the
      // real workflow's sales stage — the same authoritative effect this
      // button has with no navigator on screen at all.
      expect(
        workflowSnapshot(tester),
        isNot(workflowBefore),
        reason:
            'the real Recommended Action CTA must still reach the real '
            'production handler and move real workflow state, proving '
            'Navigator presentation failure did not become a gameplay or '
            'navigation failure',
      );
      expect(
        currentWorkflow(tester).engineers.first.stage,
        PublicDemoSalesStage.skillSheet,
        reason: 'SkillSheet確認 must have run its real effect',
      );

      // The navigator itself is unmoved by the state change that just
      // happened — still exactly one, still the fixed identity, still the
      // fallback (the asset never becomes loadable mid-test).
      expect(find.byType(HomeNavigatorSection), findsOneWidget);
      expect(
        find.byKey(const Key('home-navigator-portrait-fallback')),
        findsOneWidget,
      );
      expect(find.text('佐倉 ひより'), findsOneWidget);
    });
  });
}
