// CORE-GAMEPLAY Phase 3 (Recruitment Interview): overflow/textScale
// coverage for the new interactive interview modal
// (PublicDemoRecruitmentInterviewDialog) across every phase (question
// selection, reverse question, summary/decision) at both required phone
// viewports and both required TextScaler factors.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import 'public_demo_interview_test_helpers.dart';
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

const _expense = 800000;

/// Reaches May with a seeded engineer-medium applicant already
/// genuinely-interviewed (`recruit` -> `completeInterview`, the exact
/// production path the "採用面談" button itself triggers) -- so the fixture
/// starts right at the point where opening the interactive interview dialog
/// is the card's own next action.
({PublicDemoAggregate aggregate, String applicantId})
mayWithInterviewedSeededApplicant(int runSeed) {
  final started = PublicDemoAggregate.initial(
    runSeed: runSeed,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = started.recruit(PublicDemoRecruitmentMedium.engineer);
  final game = recruited.aggregate!;
  final applicant = game.workflow.applicants.firstWhere(
    (candidate) => candidate.id.startsWith('recruitment-'),
  );
  final result = game.completeInterview(applicant.id);
  return (aggregate: result.aggregate, applicantId: applicant.id);
}

Future<void> _pumpToInterviewDialog(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
  String applicantId, {
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: PublicDemo01PlaceholderScreen(
          saveService: _FixedSaveService(aggregate),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
  final openButton = find.byKey(
    ValueKey('public-demo-interview-open-$applicantId'),
  );
  await tester.ensureVisible(openButton);
  await tester.pumpAndSettle();
  await tester.tap(openButton);
  await tester.pumpAndSettle();
}

void main() {
  group(
    'recruitment interview dialog: no overflow across viewports/textScale',
    () {
      for (final size in const [Size(360, 800), Size(390, 844)]) {
        for (final textScale in [1.0, 1.3, 2.0]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: full interview flow renders with no overflow',
            (tester) async {
              final fixture = mayWithInterviewedSeededApplicant(2024);
              await _pumpToInterviewDialog(
                tester,
                fixture.aggregate,
                fixture.applicantId,
                size: size,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull);

              // Question-selection phase: every visible category card's close
              // button and content stay within the physical viewport.
              expect(
                find.byKey(const Key('public-demo-interview-close')),
                findsOneWidget,
              );
              final closeButtonRect = tester.getRect(
                find.byKey(const Key('public-demo-interview-close')),
              );
              expect(closeButtonRect.right, lessThanOrEqualTo(size.width));
              expect(closeButtonRect.left, greaterThanOrEqualTo(0.0));

              await continueRecruitmentInterviewToHireDecision(tester);
              expect(tester.takeException(), isNull);

              // After the decision, the dialog is closed and the (unchanged,
              // pre-existing) 合格・給与提示 button becomes usable -- no
              // overflow on that return trip either.
              final offerButton = find.text('合格・給与提示');
              expect(offerButton, findsOneWidget);
              final offerRect = tester.getRect(offerButton);
              expect(offerRect.left, greaterThanOrEqualTo(0.0));
              expect(offerRect.right, lessThanOrEqualTo(size.width));
            },
          );
        }
      }
    },
  );

  group('recruitment interview dialog: reject path has no overflow either', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()}: 見送る closes the '
        'dialog with no overflow and no offer button afterward',
        (tester) async {
          final fixture = mayWithInterviewedSeededApplicant(4242);
          await _pumpToInterviewDialog(
            tester,
            fixture.aggregate,
            fixture.applicantId,
            size: size,
            textScale: 1.0,
          );

          for (final category in const [
            'technical',
            'career',
            'reasonForChange',
          ]) {
            final card = find.byKey(ValueKey('question-card-$category'));
            await tester.scrollUntilVisible(
              card,
              200,
              scrollable: interviewDialogScrollable,
            );
            await tester.pumpAndSettle();
            await tester.tap(card);
            await tester.pumpAndSettle();
          }
          final reverseChoice = find.byKey(
            const ValueKey('public-demo-interview-reverse-choice-0'),
          );
          await tester.scrollUntilVisible(
            reverseChoice,
            200,
            scrollable: interviewDialogScrollable,
          );
          await tester.pumpAndSettle();
          await tester.tap(reverseChoice);
          await tester.pumpAndSettle();

          await tester.tap(
            find.byKey(const Key('public-demo-interview-decision-reject')),
          );
          await tester.pumpAndSettle();
          // Confirmation dialog (見送りますか？) -- confirm.
          await tester.tap(find.text('見送る').last);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('合格・給与提示'), findsNothing);
          expect(find.text('不採用'), findsOneWidget);
        },
      );
    }
  });
}
