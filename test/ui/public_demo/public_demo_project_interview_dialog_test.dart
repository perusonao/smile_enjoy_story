// CORE-GAMEPLAY Phase 6 (Project Interview Gameplay): widget coverage for
// PublicDemoProjectInterviewDialog — the interactive 案件面談 opened from a
// real Phase 5 matching-proposal handoff. Verifies the question/follow-up
// flow actually renders and advances, the result phase never leaks a raw
// score, and the dialog stays overflow-free at the required mobile-portrait
// viewports and TextScaler levels (390x844 target, 360x800 usable, 1.0/1.3/
// 2.0).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_project_interview_dialog.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

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

/// Mounts the dialog exactly as production code does — via [showDialog]
/// from a real route — rather than embedding the bare [Dialog] widget
/// directly in a body, so this test exercises the same
/// constraints/`MediaQuery` a genuine [Navigator] overlay route provides.
Future<void> _pump(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  required Size size,
  double textScale = 1.0,
  ValueChanged<PublicDemoAggregate>? onCommit,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (context) => PublicDemoProjectInterviewDialog(
                  engineerId: 'eng-01',
                  aggregate: aggregate,
                  onCommit: onCommit ?? (_) {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// A follow-up choice button, matched by its stable key prefix. A large
/// `TextScaler` on a small viewport can genuinely push it below the fold of
/// the dialog's own scrollable content (expected, real mobile behavior —
/// this is exactly why that content is a scrollable `ListView`, not a fixed
/// `Column`), so this scrolls it into view first rather than assuming it is
/// already built/visible.
final _followUpButton = find.byWidgetPredicate(
  (widget) =>
      widget is OutlinedButton &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(
        'public-demo-project-interview-follow-',
      ),
);

Future<void> _tapFirstFollowUp(WidgetTester tester) async {
  await tester.ensureVisible(_followUpButton.first);
  await tester.pumpAndSettle();
  await tester.tap(_followUpButton.first);
  await tester.pumpAndSettle();
}

void main() {
  group('question/follow-up flow', () {
    testWidgets('renders the first question and answer, and choosing a '
        'follow-up advances toward the result', (tester) async {
      PublicDemoAggregate? committed;
      await _pump(
        tester,
        _readyAggregate(),
        size: const Size(390, 844),
        onCommit: (next) => committed = next,
      );

      expect(find.text('案件面談'), findsOneWidget);
      expect(find.text('面接官'), findsOneWidget);
      expect(committed, isNotNull); // startProjectInterview committed on init.

      await _tapFirstFollowUp(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('answering every question reaches a pass/fail result that '
        'never shows a raw numeric score', (tester) async {
      PublicDemoAggregate aggregate = _readyAggregate();
      await _pump(
        tester,
        aggregate,
        size: const Size(390, 844),
        onCommit: (next) => aggregate = next,
      );

      // Repeatedly tap the first available follow-up until the dialog
      // reaches its result phase (bounded — a real session never has more
      // than a handful of questions).
      for (var i = 0; i < 6; i++) {
        if (find.text('続ける').evaluate().isNotEmpty) break;
        await _tapFirstFollowUp(tester);
      }

      expect(find.text('続ける'), findsOneWidget);
      expect(find.textContaining('合格'), findsWidgets);
      // HIDDEN-PARAMS-1: no raw score/percentage anywhere in the result.
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('続ける'));
      await tester.pumpAndSettle();
    });
  });

  group('viewport / TextScaler safety', () {
    for (final size in const [Size(390, 844), Size(360, 800)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        testWidgets(
          'no overflow at ${size.width.toInt()}x${size.height.toInt()} '
          'textScale $scale',
          (tester) async {
            await _pump(tester, _readyAggregate(), size: size, textScale: scale);
            expect(tester.takeException(), isNull);

            // Drive one follow-up choice too — the most content-heavy state
            // (question + answer + interviewer reaction + choice buttons).
            await _tapFirstFollowUp(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
