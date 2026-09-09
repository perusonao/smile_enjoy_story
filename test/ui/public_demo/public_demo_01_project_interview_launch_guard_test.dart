// CORE-GAMEPLAY Phase 6 (Project Interview Gameplay): Codex P2-2 fix
// (PR #214) coverage — rapid double activation of the screen's own real
// `客先面談` action must never push [PublicDemoProjectInterviewDialog]
// twice. See `_S._openProjectInterview`'s own doc
// (public_demo_01_placeholder_screen.dart) for the exact race this guards
// against: two independently-pushed dialogs each capture their own
// `aggregate: _game` snapshot at build time, and whichever closes last
// would otherwise commit its own stale, pre-first-result snapshot over the
// genuine first outcome.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_project_interview_dialog.dart';

import 'public_demo_tab_test_helpers.dart';

/// A fake [PublicDemoSaveService] that hands back exactly [restored] on
/// [load] and otherwise records/accepts writes — mirrors
/// `public_demo_01_persistence_test.dart`'s own `_RecordingSaveService`
/// (private to that file, so re-declared here rather than imported).
class _FakeSaveService extends PublicDemoSaveService {
  _FakeSaveService(this.restored);

  PublicDemoAggregate? restored;

  @override
  Future<PublicDemoAggregate?> load() async => restored;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {
    restored = aggregate;
  }

  @override
  Future<bool> clear() async {
    restored = null;
    return true;
  }
}

/// An `eng-01` aggregate sitting exactly at `partnerInterviewPassed` with a
/// genuine Phase 5 matching proposal already in place — the one
/// precondition that routes `客先面談` through `_openProjectInterview`
/// (the interactive dialog) instead of the pre-Phase-6 generic evaluator.
/// Mirrors `public_demo_project_interview_dialog_test.dart`'s own
/// `_readyAggregate` exactly (same seed, same command sequence, verified by
/// that file's own 8 passing widget tests to reach a genuine pass here).
PublicDemoAggregate _readyAggregate({int runSeed = 5}) {
  var aggregate = PublicDemoAggregate.initial(runSeed: runSeed);
  aggregate = aggregate.startSkillSheetReview('eng-01');
  aggregate = aggregate.beginSelling('eng-01');
  aggregate = aggregate.introduceProject('eng-01');
  aggregate = aggregate.recordEngineerInterviewResult(
    engineerId: 'eng-01',
    type: PublicDemoInterviewType.partner,
  );
  final project = aggregate.projectCandidatesForMonth(aggregate.state.month).first;
  aggregate = aggregate.proposeMatch(engineerId: 'eng-01', projectId: project.id);
  return aggregate;
}

/// `_openProjectInterview` awaits `_precacheEventImage` (a real
/// `precacheImage` decode) before ever reaching `showDialog`.
/// `MultiFrameImageStreamCompleter` only resolves via real wall-clock
/// scheduling — `tester.pump()`/`pumpAndSettle()`'s fake clock never
/// completes it on its own — so this gives the decode a real-time window
/// via `runAsync`, exactly mirroring
/// `public_demo_01_success_playthrough_test.dart`'s own
/// `_settleAfterPossiblePrecache` helper (private to that file, so
/// re-declared here rather than imported).
Future<void> _settleAfterPossiblePrecache(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Codex P2-2 fix (PR #214): rapid double activation of 客先面談 opens only '
    'one project-interview dialog',
    (tester) async {
      final service = _FakeSaveService(_readyAggregate());
      await tester.pumpWidget(
        MaterialApp(home: PublicDemo01PlaceholderScreen(saveService: service)),
      );
      await tester.pump();
      await switchPublicDemoTab(tester, PublicDemoTab.employees);

      final button = find.widgetWithText(FilledButton, '客先面談');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      // Two activations back-to-back, with no `pump()`/`await` in between —
      // `tester.tap` resolves a plain single-tap `onPressed` synchronously
      // within the call itself, so the second call reaches
      // `_openProjectInterview` while the first is still suspended inside
      // its own `await _precacheEventImage(...)`, exactly the window the
      // original race exploited (the guard is set *before* that await, so
      // by the time this second call runs, `_projectInterviewLaunchInProgress`
      // is already `true` and it is a no-op).
      await tester.tap(button);
      await tester.tap(button);
      await _settleAfterPossiblePrecache(tester);

      expect(find.byType(PublicDemoProjectInterviewDialog), findsOneWidget);
    },
  );

  testWidgets(
    'Codex P2-2 fix (PR #214): after the dialog closes, a fresh 客先面談 '
    'activation opens normally (the guard does not outlive its own dialog)',
    (tester) async {
      final service = _FakeSaveService(_readyAggregate());
      await tester.pumpWidget(
        MaterialApp(home: PublicDemo01PlaceholderScreen(saveService: service)),
      );
      await tester.pump();
      await switchPublicDemoTab(tester, PublicDemoTab.employees);

      final button = find.widgetWithText(FilledButton, '客先面談');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await _settleAfterPossiblePrecache(tester);
      expect(find.byType(PublicDemoProjectInterviewDialog), findsOneWidget);

      // Close the dialog without completing the interview (the player
      // backing out) via the barrier's own Navigator.pop equivalent: tap the
      // dialog's own close affordance if present, otherwise pop directly —
      // this test only needs the route gone, not any particular outcome.
      final state = tester.state<NavigatorState>(find.byType(Navigator).first);
      state.pop();
      await tester.pumpAndSettle();
      expect(find.byType(PublicDemoProjectInterviewDialog), findsNothing);

      // A brand-new activation now must open a fresh dialog rather than
      // being silently swallowed by a guard that never got released.
      await tester.tap(button);
      await _settleAfterPossiblePrecache(tester);
      expect(find.byType(PublicDemoProjectInterviewDialog), findsOneWidget);
    },
  );
}
