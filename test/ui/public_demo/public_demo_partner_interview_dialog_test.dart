// Issue #245 Phase B2 (Partner Interview Gameplay): widget coverage for
// PublicDemoProjectInterviewDialog(type: PublicDemoInterviewType.partner) —
// the interactive 上位会社面談 opened one pipeline stage earlier than the
// existing Phase 6 客先面談 mini-game. Mirrors
// public_demo_project_interview_dialog_test.dart's own coverage shape
// (question/follow-up flow, dismiss-never-commits regression, viewport/
// TextScaler safety) for the partner leg specifically, plus a same-widget
// key-prefix isolation check so the two legs are verified to never collide.
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
  final project = aggregate.projectCandidatesForMonth(aggregate.state.month).first;
  aggregate = aggregate.proposeMatch(engineerId: 'eng-01', projectId: project.id);
  return aggregate;
}

/// Mounts the dialog exactly as production code does — via [showDialog] from
/// a real route — mirrors
/// public_demo_project_interview_dialog_test.dart's own `_pump`.
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
                  type: PublicDemoInterviewType.partner,
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

final _followUpButton = find.byWidgetPredicate(
  (widget) =>
      widget is OutlinedButton &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(
        'public-demo-partner-interview-follow-',
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
    testWidgets('renders the first question and answer under the '
        '上位会社面談 title, and choosing a follow-up advances toward the '
        'result', (tester) async {
      PublicDemoAggregate? committed;
      await _pump(
        tester,
        _readyAggregate(),
        size: const Size(390, 844),
        onCommit: (next) => committed = next,
      );

      expect(find.text('上位会社面談'), findsWidgets);
      expect(find.text('面接官'), findsOneWidget);
      // Never labeled as the (unrelated) client-facing 案件面談 mini-game.
      expect(find.text('案件面談'), findsNothing);
      expect(committed, isNotNull); // startPartnerInterview committed on init.

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

      for (var i = 0; i < 6; i++) {
        if (find.text('続ける').evaluate().isNotEmpty) break;
        await _tapFirstFollowUp(tester);
      }

      expect(find.text('続ける'), findsOneWidget);
      expect(find.textContaining('合格'), findsWidgets);
      // HIDDEN-PARAMS-1: no raw score/percentage anywhere in the result.
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('点'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('続ける'));
      await tester.pumpAndSettle();

      // A genuine pass/fail was actually committed to the sales pipeline —
      // never a purely cosmetic dialog.
      final engineer = aggregate.workflow.engineers.firstWhere(
        (e) => e.id == 'eng-01',
      );
      expect(
        engineer.stage.name,
        anyOf('partnerInterviewPassed', 'partnerInterviewFailed'),
      );
    });
  });

  group('dismiss never commits a pass/fail outcome (Issue #245 Finding #9, '
      'partner leg)', () {
    testWidgets(
      'closing via the [X] button before any follow-up leaves the engineer '
      'stage and session exactly as before, and reopening resumes the same '
      'in-progress session rather than starting a fresh one',
      (tester) async {
        PublicDemoAggregate aggregate = _readyAggregate();
        await _pump(
          tester,
          aggregate,
          size: const Size(390, 844),
          onCommit: (next) => aggregate = next,
        );

        final stageBeforeClose = aggregate.workflow.engineers
            .firstWhere((e) => e.id == 'eng-01')
            .stage;
        final sessionBeforeClose = aggregate.projectInterviewSessionFor(
          'eng-01',
        );
        expect(sessionBeforeClose, isNotNull);
        expect(sessionBeforeClose!.completed, isFalse);
        expect(sessionBeforeClose.playerFollowUps, isEmpty);

        await tester.tap(
          find.byKey(const Key('public-demo-partner-interview-close')),
        );
        await tester.pumpAndSettle();

        expect(
          aggregate.workflow.engineers
              .firstWhere((e) => e.id == 'eng-01')
              .stage,
          stageBeforeClose,
        );
        final sessionAfterClose = aggregate.projectInterviewSessionFor(
          'eng-01',
        );
        expect(sessionAfterClose, isNotNull);
        expect(sessionAfterClose!.completed, isFalse);
        expect(sessionAfterClose.result, isNull);
        expect(sessionAfterClose.playerFollowUps, isEmpty);
        expect(sessionAfterClose.id, sessionBeforeClose.id);

        // Reopening resumes the exact same in-progress session.
        await _pump(
          tester,
          aggregate,
          size: const Size(390, 844),
          onCommit: (next) => aggregate = next,
        );
        expect(find.text('上位会社面談'), findsWidgets);
        final sessionAfterReopen = aggregate.projectInterviewSessionFor(
          'eng-01',
        );
        expect(sessionAfterReopen!.id, sessionBeforeClose.id);
        expect(sessionAfterReopen.completed, isFalse);

        await _tapFirstFollowUp(tester);
        expect(tester.takeException(), isNull);
        expect(
          aggregate.projectInterviewSessionFor('eng-01')!.playerFollowUps,
          isNotEmpty,
        );
      },
    );

    testWidgets(
      'the Android/system back gesture (pop route) is exactly as safe as '
      'the [X] button — no commit, session resumable',
      (tester) async {
        PublicDemoAggregate aggregate = _readyAggregate();
        await _pump(
          tester,
          aggregate,
          size: const Size(390, 844),
          onCommit: (next) => aggregate = next,
        );

        final stageBeforeBack = aggregate.workflow.engineers
            .firstWhere((e) => e.id == 'eng-01')
            .stage;

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(
          aggregate.workflow.engineers
              .firstWhere((e) => e.id == 'eng-01')
              .stage,
          stageBeforeBack,
        );
        final session = aggregate.projectInterviewSessionFor('eng-01');
        expect(session, isNotNull);
        expect(session!.completed, isFalse);
        expect(session.result, isNull);
      },
    );

    testWidgets(
      'double-tapping the [X] close button in quick succession never '
      'double-pops or double-commits',
      (tester) async {
        PublicDemoAggregate aggregate = _readyAggregate();
        await _pump(
          tester,
          aggregate,
          size: const Size(390, 844),
          onCommit: (next) => aggregate = next,
        );
        final stageBefore = aggregate.workflow.engineers
            .firstWhere((e) => e.id == 'eng-01')
            .stage;

        final closeButton = find.byKey(
          const Key('public-demo-partner-interview-close'),
        );
        await tester.tap(closeButton);
        await tester.tap(closeButton, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          aggregate.workflow.engineers
              .firstWhere((e) => e.id == 'eng-01')
              .stage,
          stageBefore,
        );
      },
    );
  });

  group('viewport / TextScaler safety', () {
    for (final size in const [Size(390, 844), Size(360, 800)]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets(
          'no overflow at ${size.width.toInt()}x${size.height.toInt()} '
          'textScale $scale',
          (tester) async {
            await _pump(tester, _readyAggregate(), size: size, textScale: scale);
            expect(tester.takeException(), isNull);

            await _tapFirstFollowUp(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
