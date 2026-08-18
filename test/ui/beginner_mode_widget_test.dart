// Phase 3A UI regression: the "初心者経営期間" card (BeginnerModeCard) must
// render on Home once a Beginner Mode playthrough reaches its first
// assignment, without overflowing at the project's target mobile widths
// (§16 of the Phase 3A brief), and must disappear once Phase 3A's window
// (week <= BeginnerModeEngine.lastWeek) has passed.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/main.dart';

import '../game/prologue_engine_test.dart' show playThroughPrologue;
import '../game/test_helpers.dart';

const _widths = [360.0, 390.0];

Future<void> _pumpHome(WidgetTester tester, GameState state, double width) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
  await tester.pumpWidget(SesApp(controller: GameController()));
  await tester.pumpAndSettle();
}

void main() {
  group('BeginnerModeCard on Home', () {
    for (final width in _widths) {
      testWidgets('renders the 今月の経営ポイント teaching label, no overflow at ${width}px', (tester) async {
        var state = playThroughPrologue(11);
        state = ProgressionEngine.reconcile(PrologueEngine.completePrologue(state));

        // Give it something concrete going on: a pending AR (next expected
        // collection) and a genuinely waiting second employee. Home
        // layout整理 (§3-4) moved 待機社員の給与負担/資金状況 to "会社の状況"
        // and "重要なお知らせ" (no longer duplicated here) — but 次回入金予定
        // stays on this card (Codex review on PR #22: no other screen shows
        // which specific AR entry is due when, only the aggregate 売掛金).
        final waiter = buildEngineer(id: 'waiter-widget', salary: 320000, status: EngineerStatus.waiting);
        state = state.copyWith(
          engineers: [...state.engineers, waiter],
          company: state.company.copyWith(engineerIds: [...state.company.engineerIds, waiter.id]),
          accountsReceivable: [
            AccountsReceivable(
              id: 'ar-widget-1',
              clientId: state.activeAssignments.first.project.clientId,
              projectId: state.activeAssignments.first.project.id,
              employeeId: state.activeAssignments.first.engineerId,
              amount: 600000,
              generatedMonth: 1,
              dueMonth: 2,
            ),
          ],
        );
        state = BeginnerModeEngine.reconcile(state);
        expect(BeginnerModeEngine.isPhase3AActive(state), isTrue);

        await _pumpHome(tester, state, width);

        expect(find.textContaining('初心者経営期間'), findsOneWidget);
        expect(find.text(BeginnerModeEngine.currentThemeLabel(state)), findsOneWidget);
        // 次回入金予定 is the one fact kept on this card (see the class doc
        // comment) — 待機社員の給与負担/資金状況 stay gone, now covered
        // exactly once each elsewhere on Home (§4, §11).
        expect(find.textContaining('次回入金予定'), findsOneWidget);
        expect(find.textContaining('待機社員の給与負担'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    // CI investigation follow-up (PR #15): beginner-mode-waiting-and-
    // recruitment.spec.ts's real-UI E2E proves the *milestone condition*
    // fires (see test/game/beginner_mode_test.dart's "Test E2"), but never
    // exercised the actual dialog rendering through a real "次の週へ" tap —
    // that only ever happened downstream of a probabilistic 9-candidate
    // interview loop. This closes that gap deterministically: constructs a
    // PendingHire directly (as GameEngine.hireApplicant would after a
    // successful accept roll — no interview UI, no RNG) with `joinWeek`
    // one week out, taps "次の週へ" once via the real GameController/
    // HomeScreen path, and asserts the actual waitingCostExplained dialog
    // (not just the milestone-pending fact) appears with real content.
    testWidgets('次の週へ shows the waitingCostExplained dialog once a PendingHire joins and stays waiting (no interview/RNG involved)', (tester) async {
      var state = playThroughPrologue(11);
      state = ProgressionEngine.reconcile(PrologueEngine.completePrologue(state));
      expect(state.pendingHires, isEmpty);

      final applicant = buildApplicant(id: 'widget-pending-applicant-1', name: 'ウィジェット 応募者');
      state = state.copyWith(
        pendingHires: [
          PendingHire(
            id: 'widget-pending-hire-1',
            applicant: applicant,
            salary: 340000,
            decisionWeek: state.week,
            joinWeek: state.week + 1,
          ),
        ],
      );
      // `_onNextWeek` shows any pending `ProgressionEngine.weeklyEvents`
      // dialog (e.g. `firstAssignmentCelebration`, normally marked seen
      // inline on the Prologue's own completion screen, which this test
      // never renders) *before* checking Beginner Mode's own milestones —
      // pre-mark them all seen so this test's single "次の週へ" tap isn't
      // blocked behind an unrelated founding-tutorial dialog first.
      for (final event in ProgressionEngine.weeklyEvents) {
        state = GameEngine.markTutorialSeen(state, event);
      }

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
      await tester.pumpWidget(SesApp(controller: GameController()));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('次の週へ'));
      await tester.pumpAndSettle();

      expect(find.text('待機社員にも給与が発生しています'), findsOneWidget);
      expect(find.textContaining('現在の待機社員: 1名'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Symmetric coverage (PR #15 CI investigation follow-up) for
    // `recruitmentTradeoffExplained` — deterministic already (posting a 2nd
    // listing, no RNG), but until now only checked at the engine level
    // (`beginner_mode_test.dart`'s "recruitment tradeoff guidance appears
    // once a listing is posted post-assignment" test); this closes the same
    // "does the real dialog actually render" gap the waitingCostExplained
    // test above closes.
    testWidgets('次の週へ shows the recruitmentTradeoffExplained dialog once a 2nd listing is posted post-assignment', (tester) async {
      var state = playThroughPrologue(11);
      state = ProgressionEngine.reconcile(PrologueEngine.completePrologue(state));
      expect(state.beginnerModeState.has(BeginnerMilestone.recruitmentTradeoffExplained), isFalse);

      // playThroughPrologue already posted a 無料求人 listing in March to
      // find the founding hire — post a *different* medium so it actually
      // lands as a new listing (postRecruitmentMedia refuses to double-post
      // an already-active listing of the same type), mirroring the engine
      // test's own setup.
      state = GameEngine.postRecruitmentMedia(state, RecruitmentMediaType.engineerCareer);
      state = BeginnerModeEngine.reconcile(ProgressionEngine.reconcile(state));
      expect(BeginnerModeEngine.pendingMilestones(state, BeginnerModeEngine.weeklyMilestones), contains(BeginnerMilestone.recruitmentTradeoffExplained));
      for (final event in ProgressionEngine.weeklyEvents) {
        state = GameEngine.markTutorialSeen(state, event);
      }

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({'ses_playable_save_v1': jsonEncode(state.toJson())});
      await tester.pumpWidget(SesApp(controller: GameController()));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('次の週へ'));
      await tester.pumpAndSettle();

      expect(find.text('採用のトレードオフ'), findsOneWidget);
      expect(find.textContaining('固定支出'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disappears once Phase 3A\'s window has passed (week > lastWeek)', (tester) async {
      var state = playThroughPrologue(11);
      state = ProgressionEngine.reconcile(PrologueEngine.completePrologue(state));
      state = state.copyWith(company: state.company.copyWith(currentWeek: BeginnerModeEngine.lastWeek + 1));
      expect(BeginnerModeEngine.isPhase3AActive(state), isFalse);

      await _pumpHome(tester, state, 390);

      expect(find.textContaining('初心者経営期間'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
