// SES First Fun Quarter Mission System Phase 1 — AppBar entry point
// coverage (Fresh Audit §9 Option E / Implementation Plan §3.5): the
// `public-demo-app-bar-mission` IconButton is reachable from every tab
// (Scaffold-level chrome, not HOME content) and opens
// [PublicDemoMissionScreen] via a real [Navigator.push] resolving against
// the currently-committed aggregate — plus a HOME Freeze regression check
// (criterion 7 of the Implementation Plan's own §3.6 test plan): HOME's own
// content is unaffected by this feature.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import '../../game/public_demo/test_support/public_demo_recovery_test_helpers.dart'
    show
        publicDemoAdvanceEngineerToOrdered,
        publicDemoAggregateAtMonth;
import 'public_demo_tab_test_helpers.dart';

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

Future<void> _pumpDemo(WidgetTester tester, PublicDemoAggregate aggregate) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      home: PublicDemo01PlaceholderScreen(saveService: _FixedSaveService(aggregate)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const missionButtonKey = Key('public-demo-app-bar-mission');

  group('AppBar Mission entry point', () {
    testWidgets('is present on HOME and opens the Mission screen showing '
        'the fresh April chain', (tester) async {
      await _pumpDemo(tester, PublicDemoAggregate.initial());

      expect(find.byKey(missionButtonKey), findsOneWidget);

      await tester.tap(find.byKey(missionButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('4月の目標'), findsOneWidget);
      expect(find.text('技術者1名を案件に参画させよう'), findsOneWidget);
      expect(find.text('進捗 0 / 8'), findsOneWidget);

      // Navigates back to the real HOME screen underneath — a real
      // Navigator.push, not a replacement of the whole screen.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('S.E.S. Public Demo 0.1'), findsOneWidget);
    });

    for (final tab in PublicDemoTab.values) {
      testWidgets('is present on the ${tab.name} tab, not only HOME', (
        tester,
      ) async {
        await _pumpDemo(tester, PublicDemoAggregate.initial());
        await switchPublicDemoTab(tester, tab);

        expect(
          find.byKey(missionButtonKey),
          findsOneWidget,
          reason: 'the AppBar (Scaffold-level chrome) is shared across every '
              'tab body, so this button must not disappear on a non-HOME tab',
        );
      });
    }

    testWidgets(
      'resolves against the currently-committed aggregate: an already '
      'assigned engineer shows MISSION COMPLETE immediately, no re-play '
      'needed',
      (tester) async {
        var aggregate = publicDemoAdvanceEngineerToOrdered(
          PublicDemoAggregate.initial(),
          'eng-01',
        );
        aggregate = aggregate.closeApril(monthlyExpenses: 800000);

        await _pumpDemo(tester, aggregate);
        await tester.tap(find.byKey(missionButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('public-demo-mission-complete-banner')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'reopening the Mission screen does not accumulate duplicate '
      'MISSION COMPLETE banners (re-resolved fresh each open, never '
      'cached)',
      (tester) async {
        var aggregate = publicDemoAdvanceEngineerToOrdered(
          PublicDemoAggregate.initial(),
          'eng-01',
        );
        aggregate = aggregate.closeApril(monthlyExpenses: 800000);
        await _pumpDemo(tester, aggregate);

        for (var i = 0; i < 2; i++) {
          await tester.tap(find.byKey(missionButtonKey));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('public-demo-mission-complete-banner')),
            findsOneWidget,
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
      },
    );
  });

  group('Mission-visibility badge (Phase 2 Progressive Onboarding)', () {
    const badgeKey = Key('public-demo-app-bar-mission-badge');

    testWidgets(
      'a fresh game shows the badge before the Mission screen has ever '
      'been opened this session',
      (tester) async {
        await _pumpDemo(tester, PublicDemoAggregate.initial());

        expect(find.byKey(badgeKey), findsOneWidget);
      },
    );

    testWidgets(
      'opening the Mission screen once clears the badge for the current '
      'chain front, and it stays cleared while nothing has changed',
      (tester) async {
        await _pumpDemo(tester, PublicDemoAggregate.initial());
        expect(find.byKey(badgeKey), findsOneWidget);

        await tester.tap(find.byKey(missionButtonKey));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byKey(badgeKey), findsNothing);
      },
    );

    testWidgets(
      'the badge reappears once the chain genuinely advances past the '
      'acknowledged front (Mission #1 completing unlocks Mission #2) — the '
      'Just-in-time nudge for the next step, never a modal',
      (tester) async {
        // eng-01 confirms SkillSheet — Mission #1 (viewSkillSheet)
        // completes, so the chain front moves from index 0 to index 1
        // (SES First Fun Quarter Mission Phase 3: editSkillSheet, inserted
        // ahead of beginSelling), which the AppBar has not yet acknowledged.
        final aggregate = PublicDemoAggregate.initial().startSkillSheetReview(
          'eng-01',
        );
        await _pumpDemo(tester, aggregate);
        expect(find.byKey(badgeKey), findsOneWidget);

        await tester.tap(find.byKey(missionButtonKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('public-demo-mission-tile-viewSkillSheet')),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.byKey(badgeKey),
          findsNothing,
          reason: 'acknowledged at the current front (editSkillSheet, index 1)',
        );
      },
    );

    testWidgets(
      'SES First Fun Quarter Mission Phase 4: further, real Recruitment '
      'chain progress re-shows the badge even while the April chain is '
      'still stuck incomplete (both founding engineers untouched) — a '
      'single combined front index over both chains concatenated would '
      'stay pinned at April\'s own unmoved front (position 0) forever, '
      'masking every later Recruitment-only advance; independent per-'
      'chain acknowledgement does not',
      (tester) async {
        // Both founding engineers stay at `waiting` throughout — April's
        // own front never moves off `viewSkillSheet` (index 0). Recruit
        // one applicant and get them to `resumeReviewed` before the first
        // mount, so the Recruitment chain already shows real progress
        // (front index 2: postRecruitmentMedium + viewApplicantSkillSheet
        // completed, screenApplicantResume available) the first time the
        // Mission screen is opened.
        var aggregate = PublicDemoAggregate.initial().closeApril(
          monthlyExpenses: 800000,
        );
        aggregate = aggregate.recruit(PublicDemoRecruitmentMedium.engineer).aggregate!;
        final applicantId = aggregate.workflow.applicants.first.id;
        aggregate = aggregate.reviewResume(applicantId);
        // A ListView only mounts children within its viewport/cacheExtent
        // — a tall viewport lets the Mission screen's Recruitment section
        // (below April's own 8 tiles) mount without needing a scroll.
        tester.view.physicalSize = const Size(390, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await _pumpDemo(tester, aggregate);

        // Acknowledge both chains' current fronts (April: 0, Recruitment: 2).
        await tester.tap(find.byKey(missionButtonKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('public-demo-mission-recruitment-header')),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(badgeKey), findsNothing);

        // Real, live progress on the Recruitment chain ONLY (見送る —
        // Required Feature A's own button): screenApplicantResume
        // completes, Recruitment front advances from 2 to 3. April is
        // completely untouched by this action.
        await switchPublicDemoTab(tester, PublicDemoTab.sales);
        await tester.tap(
          find.byKey(Key('public-demo-applicant-reject-$applicantId')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(badgeKey),
          findsOneWidget,
          reason:
              'Recruitment chain genuinely advanced past its own '
              'acknowledged front — a combined index stuck at April\'s '
              'own unmoved front (0) would incorrectly still read as '
              'acknowledged and hide this',
        );
      },
    );
  });

  group('Phase 2: mid-game restored saves never re-show Opening', () {
    testWidgets(
      'a restored May save (already past April, no Mission progress) '
      'skips Opening entirely and the Mission entry still reflects the '
      'real, current chain state',
      (tester) async {
        final aggregate = publicDemoAggregateAtMonth(5);
        await _pumpDemo(tester, aggregate);

        expect(
          find.byKey(const Key('public-demo-opening-context-screen')),
          findsNothing,
        );
        expect(find.byKey(const Key('public-demo-bottom-nav')), findsOneWidget);

        await tester.tap(find.byKey(missionButtonKey));
        await tester.pumpAndSettle();
        expect(find.text('進捗 0 / 8'), findsOneWidget);
      },
    );

    testWidgets(
      'a restored save already at the April headline mission\'s completion '
      '(pre-Mission-System equivalent) skips Opening and shows MISSION '
      'COMPLETE immediately, per Fresh Audit §10.5 retroactive detection',
      (tester) async {
        var aggregate = publicDemoAdvanceEngineerToOrdered(
          PublicDemoAggregate.initial(),
          'eng-01',
        );
        aggregate = aggregate.closeApril(monthlyExpenses: 800000);

        await _pumpDemo(tester, aggregate);

        expect(
          find.byKey(const Key('public-demo-opening-context-screen')),
          findsNothing,
        );
        await tester.tap(find.byKey(missionButtonKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('public-demo-mission-complete-banner')),
          findsOneWidget,
        );
      },
    );
  });

  group('HOME Freeze regression (Implementation Plan §3.6 criterion 7)', () {
    testWidgets(
      'HOME tab content and the 5-item bottom nav are unaffected by the '
      'Mission System — no 6th tab, no HOME body change',
      (tester) async {
        await _pumpDemo(tester, PublicDemoAggregate.initial());

        expect(find.text('S.E.S. Public Demo 0.1'), findsOneWidget);
        expect(find.text('1年目 4月'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('public-demo-bottom-nav')),
            matching: find.byType(NavigationDestination),
          ),
          findsNWidgets(5),
          reason: 'Mission System Phase 1 must not add a 6th bottom-nav tab',
        );
        // The Mission chain/copy never leaks into HOME's own body — it only
        // ever renders inside the pushed PublicDemoMissionScreen.
        expect(find.text('4月の目標'), findsNothing);
        expect(find.byKey(missionButtonKey), findsOneWidget);
      },
    );
  });
}
