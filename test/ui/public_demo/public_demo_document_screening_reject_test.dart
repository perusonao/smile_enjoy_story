// SES First Fun Quarter Mission Phase 4 — Document Screening: widget
// coverage for the "見送る" button on a `resumeReviewed`-stage applicant
// card (public_demo_01_placeholder_screen.dart's `ac(i)`). Mirrors
// `public_demo_issue245_recruitment_lifecycle_visibility_test.dart`'s own
// fixture technique: real production `PublicDemoAggregate` commands only,
// pumped through the real `PublicDemo01PlaceholderScreen`, never a
// fabricated applicant/stage.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import 'public_demo_tab_test_helpers.dart';

const _expense = 800000;

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

Future<void> _pumpSalesTab(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: PublicDemo01PlaceholderScreen(
          saveService: _FixedSaveService(aggregate),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
}

/// A May aggregate with one real, engineer-medium applicant already moved
/// to `resumeReviewed` via the real `reviewResume` command.
PublicDemoAggregate _mayWithResumeReviewedApplicant() {
  final started = PublicDemoAggregate.initial(
    runSeed: 1,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = started.recruit(PublicDemoRecruitmentMedium.engineer).aggregate!;
  final applicantId = recruited.workflow.applicants.first.id;
  return recruited.reviewResume(applicantId);
}

void main() {
  testWidgets(
    '見送る button is present on a resumeReviewed applicant card, alongside 採用面談',
    (tester) async {
      final aggregate = _mayWithResumeReviewedApplicant();
      final applicantId = aggregate.workflow.applicants.first.id;
      await _pumpSalesTab(tester, aggregate);

      expect(
        find.byKey(Key('public-demo-applicant-reject-$applicantId')),
        findsOneWidget,
      );
      expect(find.text('採用面談'), findsOneWidget);
      expect(find.text('見送る'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping 見送る commits a real domain reject: status badge becomes 不採用 '
    'and no CTA button remains on that card',
    (tester) async {
      final aggregate = _mayWithResumeReviewedApplicant();
      final applicantId = aggregate.workflow.applicants.first.id;
      await _pumpSalesTab(tester, aggregate);

      await tester.tap(find.byKey(Key('public-demo-applicant-reject-$applicantId')));
      await tester.pumpAndSettle();

      expect(find.text('不採用'), findsOneWidget);
      expect(find.text('採用面談'), findsNothing);
      expect(find.text('見送る'), findsNothing);
      expect(
        find.byKey(Key('public-demo-applicant-reject-$applicantId')),
        findsNothing,
      );
    },
  );

  testWidgets('見送る is not offered before the résumé has been reviewed '
      '(applied stage only has スキルシート確認)', (tester) async {
    final started = PublicDemoAggregate.initial(
      runSeed: 1,
    ).closeApril(monthlyExpenses: _expense);
    final recruited = started.recruit(PublicDemoRecruitmentMedium.engineer).aggregate!;
    final applicantId = recruited.workflow.applicants.first.id;
    await _pumpSalesTab(tester, recruited);

    expect(
      find.byKey(Key('public-demo-applicant-reject-$applicantId')),
      findsNothing,
    );
    expect(find.text('スキルシート確認'), findsWidgets);
  });

  group('360×800 / 390×844 × TextScaler 1.0/1.3 — no overflow with the '
      'reject button present', () {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} @${textScale}x', (
          tester,
        ) async {
          final aggregate = _mayWithResumeReviewedApplicant();
          await _pumpSalesTab(tester, aggregate, size: size, textScale: textScale);

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
