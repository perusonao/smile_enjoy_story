// Issue #248 FIRST-FUN-YEAR: Applicant->Engineer Data Preservation / SkillSheet
// Expansion, Phase 2 (Recruitment comparison UX).
//
// Before this change, an applicant's card showed only their name, free-text
// résumé, and status badge until AFTER the player spent an interview action
// on them -- requested salary and a structured experience figure only
// appeared once `stage == interviewed`. Both facts are already documented as
// résumé-level, non-hidden data (see
// docs/reports/SES_CORE-GAMEPLAY_Phase2_Random-Recruitment_Result.md,
// "Visible vs. interview-hidden fields": only interviewScore/acceptanceScore/
// salesSkillFit require the interview step), so gating them behind an
// interview was a presentation gap, not an intentional design boundary. This
// suite proves the new "経験 ｜ 希望給与" row appears from the very first card
// render (no new field, no schema change -- read verbatim from the existing
// PublicDemoApplicant.experienceMonths/requestedMonthlySalary), and does not
// overflow at either required phone viewport/TextScaler.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

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

Future<void> _pumpSalesTab(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
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
}

void main() {
  group('Issue #248: recruitment applicant card comparison row', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale: experience/salary row is visible before any '
          'interview action, with no overflow',
          (tester) async {
            final aggregate = PublicDemoAggregate.initial(runSeed: 1)
                .recruit(PublicDemoRecruitmentMedium.engineer)
                .aggregate!;
            final applicant = aggregate.workflow.applicants.first;

            await _pumpSalesTab(
              tester,
              aggregate,
              size: size,
              textScale: textScale,
            );
            expect(tester.takeException(), isNull);

            final row = find.byKey(
              Key('public-demo-applicant-card-compensation-${applicant.id}'),
            );
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            expect(
              row,
              findsOneWidget,
              reason:
                  'requested salary is already visible, non-hidden résumé '
                  'data at application time — it must not require spending '
                  'an interview action first',
            );
            final rowText = tester.widget<Text>(row).data ?? '';
            expect(rowText, contains('希望給与'));
            expect(rowText, contains('経験'));

            final rect = tester.getRect(row);
            expect(rect.left, greaterThanOrEqualTo(0.0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'the same fact is not duplicated once interviewed — the row switches '
      'to it exactly once, and the interview\'s own evaluation/offer flow '
      'is unaffected',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial(runSeed: 1)
            .recruit(PublicDemoRecruitmentMedium.engineer)
            .aggregate!;
        final applicant = aggregate.workflow.applicants.first;
        final interviewed = aggregate.completeInterview(applicant.id).aggregate;

        await _pumpSalesTab(
          tester,
          interviewed,
          size: const Size(390, 844),
          textScale: 1.0,
        );

        final salaryText = '希望給与 ${applicant.requestedMonthlySalary ~/ 10000}万円';
        expect(
          find.textContaining(salaryText),
          findsOneWidget,
          reason:
              'still shown exactly once (in the comparison row) after the '
              'interviewed-stage evaluation text appears — no duplicate '
              'line was left behind',
        );
        expect(
          find.byKey(ValueKey('public-demo-interview-open-${applicant.id}')),
          findsOneWidget,
          reason: 'the interview flow itself is unaffected by this change',
        );
      },
    );
  });
}
