// Phase 3A UX review (P2-3): a cash-runway warning must be visually
// distinguishable from a routine same-priority task, and every severity
// tier must carry its own short recommended response — not just color.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/widgets/task_card.dart';

Future<void> _pumpCard(WidgetTester tester, HomeTask task) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: TaskCard(task: task, onTap: () {}))));
}

Container _decoratedContainer(WidgetTester tester) => tester.widget<Container>(find.byType(Container).first);

void main() {
  testWidgets('a cash warning uses a distinct icon from a routine warning at the same priority', (tester) async {
    await _pumpCard(
      tester,
      const HomeTask(id: 'cash-runway-caution', priority: TaskPriority.warning, title: '資金余命が6か月を切っています', subtitle: '案件参画・採用のバランスを見直すタイミングです'),
    );
    expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pumpCard(
      tester,
      const HomeTask(id: 'interview-pending', priority: TaskPriority.warning, title: '面接待ちの応募者が1名います'),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.savings_outlined), findsNothing);
  });

  testWidgets('a cash warning has a heavier border than a routine warning at the same priority (severity is not color-only)', (tester) async {
    await _pumpCard(
      tester,
      const HomeTask(id: 'cash-runway-caution', priority: TaskPriority.warning, title: '資金余命が6か月を切っています'),
    );
    final cashDecoration = _decoratedContainer(tester).decoration as BoxDecoration;
    final cashBorderWidth = cashDecoration.border!.top.width;

    await tester.pumpWidget(const SizedBox());
    await _pumpCard(
      tester,
      const HomeTask(id: 'interview-pending', priority: TaskPriority.warning, title: '面接待ちの応募者が1名います'),
    );
    final routineDecoration = _decoratedContainer(tester).decoration as BoxDecoration;
    final routineBorderWidth = routineDecoration.border!.top.width;

    expect(cashBorderWidth, greaterThan(routineBorderWidth));
  });

  testWidgets('critical severity is visually heavier than warning severity at the same task type (color-only would fail this)', (tester) async {
    await _pumpCard(
      tester,
      const HomeTask(id: 'cash-runway-danger', priority: TaskPriority.critical, title: '資金余命が3か月を切っています', subtitle: '早めに案件を決めて収入を確保しましょう'),
    );
    final dangerDecoration = _decoratedContainer(tester).decoration as BoxDecoration;

    await tester.pumpWidget(const SizedBox());
    await _pumpCard(
      tester,
      const HomeTask(id: 'cash-runway-caution', priority: TaskPriority.warning, title: '資金余命が6か月を切っています'),
    );
    final cautionDecoration = _decoratedContainer(tester).decoration as BoxDecoration;

    expect(dangerDecoration.border!.top.width, greaterThan(cautionDecoration.border!.top.width));
  });

  testWidgets('every cash-runway severity tier shows a short recommended response, not just a title', (tester) async {
    for (final task in [
      const HomeTask(id: 'cash-danger', priority: TaskPriority.critical, title: 'このままだと月末に資金がショートします', subtitle: '今月の支払い予定が入金予定を上回っています'),
      const HomeTask(id: 'cash-runway-danger', priority: TaskPriority.critical, title: '資金余命が3か月を切っています', subtitle: '早めに案件を決めて収入を確保しましょう'),
      const HomeTask(id: 'cash-runway-caution', priority: TaskPriority.warning, title: '資金余命が6か月を切っています', subtitle: '案件参画・採用のバランスを見直すタイミングです'),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await _pumpCard(tester, task);
      expect(task.subtitle, isNotNull, reason: '${task.id} should carry a short recommended response');
      expect(find.text(task.subtitle!), findsOneWidget);
    }
  });
}
