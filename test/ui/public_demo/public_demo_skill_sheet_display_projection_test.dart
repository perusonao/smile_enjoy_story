import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/domain/models/programming_language.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_skill_sheet_display_projection.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_skill_sheet_sheet.dart';

/// SKILLSHEET-UX-2A P2 fix (round 2): regression coverage for
/// https://github.com/perusonao/smile_enjoy_story/pull/158#discussion_r3922332482
/// — an experienced hire's SkillSheet must never present the applicant's
/// aggregate `experienceMonths` as if it were confirmed, language-specific
/// (e.g. Java) experience.
void main() {
  group('PublicDemoSkillSheetDisplayFactory language experience', () {
    test('app-02 (Flutter/JavaScript résumé) never shows a fabricated Java '
        'chip or experience row', () {
      final applicant = publicDemoMayApplicants.firstWhere(
        (a) => a.id == 'app-02',
      );
      // Guard the fixture itself: this is the exact profile the review
      // comment named (Flutter 2年 / JavaScript 3年, 36 total months).
      expect(applicant.resumeSummary, contains('Flutter'));
      expect(applicant.resumeSummary, contains('JavaScript'));
      expect(applicant.resumeSummary, isNot(contains('Java ')));
      expect(applicant.experienceMonths, 36);
      expect(applicant.isInexperienced, isFalse);

      final runtime = PublicDemoEngineerRuntime.fromApplicant(applicant);
      final engineer = PublicDemoEngineerSales.fromApplicant(applicant);
      final data = PublicDemoSkillSheetDisplayFactory.create(
        engineer: engineer,
        statusLabel: '営業準備中',
        runtime: runtime,
        currentAssignment: null,
      );

      // No fabricated Java identity or months anywhere in the structured
      // display data — this is what feeds the header chip and the
      // "経験" section's actual-vs-displayed comparison row.
      expect(data.primaryLanguageLabel, isNull);
      expect(data.experienceComparisons, isEmpty);
      expect(data.summaryChips, isNot(contains('Java')));
      expect(data.summaryChips.any((chip) => chip.contains('Java')), isFalse);

      // The applicant's real résumé text is still shown verbatim — the
      // honest source of truth stays visible, just not restructured into
      // a fabricated per-language figure.
      expect(data.summaryText, applicant.resumeSummary);

      // The underlying capability score (gates field-sales readiness,
      // Issue #148's cash advice logic, and EG-2 growth) is untouched by
      // this display-only fix.
      expect(runtime.actualCapability, applicant.salesSkillFit);
    });

    test(
      'a Java-résumé experienced hire (app-01) gets the same honest empty '
      'state — free-text résumé wording is not confirmed structured data',
      () {
        final applicant = publicDemoMayApplicants.firstWhere(
          (a) => a.id == 'app-01',
        );
        expect(applicant.resumeSummary, contains('Java'));

        final runtime = PublicDemoEngineerRuntime.fromApplicant(applicant);
        final engineer = PublicDemoEngineerSales.fromApplicant(applicant);
        final data = PublicDemoSkillSheetDisplayFactory.create(
          engineer: engineer,
          statusLabel: '営業準備中',
          runtime: runtime,
          currentAssignment: null,
        );

        expect(data.primaryLanguageLabel, isNull);
        expect(data.experienceComparisons, isEmpty);
        expect(runtime.actualCapability, applicant.salesSkillFit);
      },
    );

    test('a genuinely inexperienced hire (experienceMonths == 0) keeps its '
        'pre-existing confirmed 0-month display unchanged', () {
      const applicant = PublicDemoApplicant(
        id: 'junior-regression',
        name: '未経験候補者',
        resumeSummary: 'ITスクール修了（実務未経験）',
        interviewScore: 64,
        acceptanceScore: 76,
        salesSkillFit: 26,
        experienceMonths: 0,
      );
      expect(applicant.isInexperienced, isTrue);

      final runtime = PublicDemoEngineerRuntime.fromApplicant(applicant);
      final engineer = PublicDemoEngineerSales.fromApplicant(applicant);
      final data = PublicDemoSkillSheetDisplayFactory.create(
        engineer: engineer,
        statusLabel: '営業準備中',
        runtime: runtime,
        currentAssignment: null,
      );

      expect(data.primaryLanguageLabel, 'Java');
      expect(data.experienceComparisons, hasLength(1));
      expect(data.experienceComparisons.single.actualMonths, 0);
      expect(data.experienceComparisons.single.displayedMonths, 0);
    });

    test('a genuinely confirmed static seed (eng-01) still shows its real '
        'language experience', () {
      final runtime = publicDemoInitialEngineerRuntimes.firstWhere(
        (r) => r.engineerId == 'eng-01',
      );
      expect(runtime.confirmedLanguages, contains(ProgrammingLanguage.java));

      final data = PublicDemoSkillSheetDisplayFactory.create(
        engineer: const PublicDemoEngineerSales(
          id: 'eng-01',
          name: '既存社員',
          summary: '既存社員のプロフィール',
          interviewProfile: PublicDemoInterviewProfile(
            skillFit: 78,
            humanity: 60,
            morale: 60,
            clientTrust: 60,
          ),
        ),
        statusLabel: '営業準備中',
        runtime: runtime,
        currentAssignment: null,
      );

      expect(data.primaryLanguageLabel, 'Java');
      expect(data.experienceComparisons, hasLength(1));
      expect(data.experienceComparisons.single.actualMonths, 36);
      expect(data.experienceComparisons.single.displayedMonths, 36);
    });
  });

  group(
    'PublicDemoSkillSheetSheet renders app-02 with no fabrication or overflow',
    () {
      for (final size in const [Size(360, 800), Size(390, 844)]) {
        testWidgets('at ${size.width.toInt()}px width', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final applicant = publicDemoMayApplicants.firstWhere(
            (a) => a.id == 'app-02',
          );
          final runtime = PublicDemoEngineerRuntime.fromApplicant(applicant);
          final engineer = PublicDemoEngineerSales.fromApplicant(applicant);

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: size),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: PublicDemoSkillSheetSheet(
                      engineer: engineer,
                      statusLabel: '営業準備中',
                      runtime: runtime,
                      currentAssignment: null,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Expand the collapsed "経験" section (ExpansionTile children stay
          // mounted but offstage while collapsed) to inspect its content.
          await tester.tap(find.text('経験'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // No RenderFlex overflow or any other rendering exception at this
          // width. The applicant's own résumé text legitimately mentions
          // "JavaScript" (which contains "Java" as a substring), so the
          // fabrication check is specifically against an exact "Java" chip
          // label/comparison-row, not the substring — see the non-widget
          // tests above for the precise structured-data assertions.
          expect(find.text('Java'), findsNothing);
          expect(find.text('経験年数の記録を確認できません。'), findsOneWidget);
        });
      }
    },
  );
}
