// Home layout整理 (S.E.S. Development Plan §1-6, §11-13): Home's job moves
// from "show everything about the company" to "tell the player what to do
// next", organized into exactly three tiers — ① 今やること (one hero card),
// ② 重要なお知らせ (a handful of short notices), ③ 会社の状況（要約）(a
// compact numbers card). This file covers the widget-test checklist from
// that plan's §13:
//   A. no overflow at 360px/390px
//   B. "今やること" renders as exactly one prominent card
//   C. Beginner Mode shows "今月の経営ポイント"
//   D. Free Mode shows no Beginner-only guidance
//   E. BeginnerModeCard / TaskCard / 重要なお知らせ don't repeat the same
//      fact (資金危険, 待機社員, 入金予定)
//   G ("F", Critical Task week-send guard; "G", Phase 3A widget tests) are
//     already covered unmodified by next_week_guard_test.dart and the rest
//     of test/ui/*_test.dart — not duplicated here.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/game_controller.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/main.dart';
import 'package:smile_enjoy_story/ui/widgets/task_card.dart';

import '../game/prologue_engine_test.dart' show playThroughPrologue;
import '../game/test_helpers.dart';

const _widths = [360.0, 390.0];

Future<void> _pumpHome(
  WidgetTester tester,
  GameState state,
  double width,
) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({
    'ses_playable_save_v1': jsonEncode(state.toJson()),
  });
  await tester.pumpWidget(SesApp(controller: GameController()));
  await tester.pumpAndSettle();
}

/// A free-management (skipped tutorial) state with several waiting
/// employees at different streak lengths — enough for [TaskEngine] to
/// generate well more than 3 tasks, so the "今やること"/"重要なお知らせ"
/// cap actually gets exercised instead of trivially passing on an empty
/// task list.
GameState _busyFreeManagementState() {
  var state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 5));
  final waiters = [
    buildEngineer(id: 'busy-1', salary: 380000, status: EngineerStatus.waiting),
    buildEngineer(id: 'busy-2', salary: 360000, status: EngineerStatus.waiting),
    buildEngineer(id: 'busy-3', salary: 340000, status: EngineerStatus.waiting),
  ];
  state = state.copyWith(
    engineers: [...state.engineers, ...waiters],
    company: state.company.copyWith(
      engineerIds: [...state.company.engineerIds, ...waiters.map((e) => e.id)],
    ),
    waitingStreak: {'busy-1': 5, 'busy-2': 3, 'busy-3': 2},
  );
  return state;
}

void main() {
  group('A/B: 今やること is a single hero card, no overflow (free management)', () {
    for (final width in _widths) {
      testWidgets(
        'exactly one "今やること" card renders even with many pending tasks at ${width.toInt()}px',
        (tester) async {
          final state = _busyFreeManagementState();
          await _pumpHome(tester, state, width);

          expect(find.text('今やること'), findsOneWidget);
          // "重要なお知らせ" holds at most 2 more — never every task at equal
          // weight (§2, §4). The rest (if any) is reachable via "すべて見る".
          expect(find.byType(TaskCard).evaluate().length, lessThanOrEqualTo(3));
          expect(find.text('会社の状況'), findsOneWidget);
          expect(find.text('技術者'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group(
    'B: 今やること is a single hero card, no overflow (guided founding tutorial)',
    () {
      for (final width in _widths) {
        testWidgets(
          'exactly one "今やること" card renders during the guided tutorial at ${width.toInt()}px',
          (tester) async {
            final state = GameEngine.newGame(seed: 2);
            await _pumpHome(tester, state, width);

            expect(find.text('今やること'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    },
  );

  group('C: Beginner Mode shows 今月の経営ポイント', () {
    for (final width in _widths) {
      testWidgets('shown exactly once during Phase 3A at ${width.toInt()}px', (
        tester,
      ) async {
        var state = playThroughPrologue(11);
        state = ProgressionEngine.reconcile(
          PrologueEngine.completePrologue(state),
        );
        state = BeginnerModeEngine.reconcile(state);
        expect(BeginnerModeEngine.isPhase3AActive(state), isTrue);

        await _pumpHome(tester, state, width);

        expect(find.text('今月の経営ポイント'), findsOneWidget);
        expect(
          find.text(BeginnerModeEngine.currentThemeLabel(state)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('D: Free Mode shows no Beginner-only guidance', () {
    testWidgets('a free-management save shows no 今月の経営ポイント / 初心者経営期間 card', (
      tester,
    ) async {
      final state = GameEngine.skipFoundingTutorial(
        GameEngine.newGame(seed: 6),
      );
      expect(BeginnerModeEngine.isBeginnerJourney(state), isFalse);

      await _pumpHome(tester, state, 390);

      expect(find.text('今月の経営ポイント'), findsNothing);
      expect(find.textContaining('初心者経営期間'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('E: no duplicate facts between BeginnerModeCard / 重要なお知らせ / 会社の状況', () {
    testWidgets(
      'waiting-cost fact stays gone from BeginnerModeCard; 次回入金予定 stays (no other screen shows it)',
      (tester) async {
        var state = playThroughPrologue(11);
        state = ProgressionEngine.reconcile(
          PrologueEngine.completePrologue(state),
        );
        final waiter = buildEngineer(
          id: 'dup-check-waiter',
          salary: 320000,
          status: EngineerStatus.waiting,
        );
        state = state.copyWith(
          engineers: [...state.engineers, waiter],
          company: state.company.copyWith(
            engineerIds: [...state.company.engineerIds, waiter.id],
          ),
          accountsReceivable: [
            AccountsReceivable(
              id: 'dup-check-ar',
              clientId: state.activeAssignments.first.project.clientId,
              projectId: state.activeAssignments.first.project.id,
              employeeId: state.activeAssignments.first.engineerId,
              amount: 500000,
              generatedMonth: 1,
              dueMonth: 2,
            ),
          ],
        );
        state = BeginnerModeEngine.reconcile(state);
        expect(BeginnerModeEngine.isPhase3AActive(state), isTrue);

        await _pumpHome(tester, state, 390);

        // 待機社員の給与負担 used to appear both in BeginnerModeCard's own
        // Facts row and (for the waiting case) in TaskEngine's own notices —
        // now it lives in exactly one place: 重要なお知らせ/すべて見る via
        // TaskCard. 次回入金予定 stays on BeginnerModeCard (Codex review on
        // PR #22, confirmed real: no other screen shows which specific AR
        // entry is due when) — findsOneWidget confirms it's still there, and
        // exactly once, not duplicated a second time elsewhere.
        expect(find.textContaining('次回入金予定'), findsOneWidget);
        expect(find.textContaining('待機社員の給与負担'), findsNothing);
        // 技術者 label is the HOME KPI; 資金余命 itself still appears, but
        // exactly once (会社の状況 only).
        expect(find.text('技術者'), findsOneWidget);
        expect(find.text('資金余命'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
