import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_candidate_skill_sheet_sheet.dart';

/// PR #210 merge-blocker follow-up (item 4): a focused regression test that
/// [PublicDemoCandidateSkillSheetSheet] — the pre-hire "スキルシートを確認"
/// dialog a Sales-tab applicant card opens — never renders
/// [PublicDemoApplicant.interviewScore], [PublicDemoApplicant.acceptanceScore],
/// or [PublicDemoApplicant.salesSkillFit].
///
/// [PublicDemoCandidateSkillSheetDisplayFactory]
/// (public_demo_candidate_skill_sheet_display_projection.dart) already
/// excludes these three fields *by construction* — its display data class
/// has no field for any of them, so there is nothing for the sheet to read.
/// That is a real, structural guarantee (a future edit would need to add a
/// new field before it could leak one of these), but nothing previously
/// exercised the actual rendered widget tree to confirm it — this closes
/// that gap the same way `public_demo_skill_sheet_display_projection_test
/// .dart` (the joined-employee counterpart) already covers its own
/// `HiddenParameters` boundary.
///
/// The three values below are deliberately distinctive two-digit numbers
/// chosen so they cannot coincidentally appear as a substring of any of the
/// applicant's other, legitimately-displayed fields (résumé text, the
/// experience label, the requested-salary label) — see the fixture's own
/// comment for the exact values those format to.
void main() {
  // Distinctive, mutually-exclusive from every other rendered value below:
  // experienceMonths (36) formats to "3 年" and requestedMonthlySalary
  // (300000) formats to "30万円" — neither "91", "84", nor "67" is a
  // substring of "3", "年", "30", "万円", or the résumé text, so a plain
  // find.text/textContaining check for each hidden value is unambiguous.
  const hiddenInterviewScore = 91;
  const hiddenAcceptanceScore = 84;
  const hiddenSalesSkillFit = 67;

  final applicant = const PublicDemoApplicant(
    id: 'app-hidden-fields-test',
    name: '非表示検証 太郎',
    resumeSummary: 'Java 5年 / Spring 2年 / 基本設計〜テスト',
    interviewScore: hiddenInterviewScore,
    acceptanceScore: hiddenAcceptanceScore,
    salesSkillFit: hiddenSalesSkillFit,
    experienceMonths: 36,
    requestedMonthlySalary: 300000,
  );

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicDemoCandidateSkillSheetSheet(applicant: applicant),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the candidate SkillSheet sheet never renders interviewScore, '
    'acceptanceScore, or salesSkillFit — only the applicant-facing fields',
    (tester) async {
      await pumpSheet(tester);

      // Sanity: the sheet actually rendered real applicant content, so a
      // false pass (e.g. an empty/broken sheet) cannot masquerade as this
      // test succeeding.
      expect(find.text('非表示検証 太郎\nスキルシート'), findsOneWidget);
      expect(find.text(applicant.resumeSummary), findsOneWidget);
      expect(find.textContaining('3 年'), findsOneWidget, reason: '経験 row');
      expect(find.textContaining('30万円'), findsOneWidget, reason: '希望給与 row');

      // The actual regression guard: none of the three interview-only
      // scores appears anywhere in the rendered widget tree, whether alone
      // or embedded in a longer string.
      for (final hidden in [
        hiddenInterviewScore,
        hiddenAcceptanceScore,
        hiddenSalesSkillFit,
      ]) {
        expect(
          find.text('$hidden'),
          findsNothing,
          reason: 'exact match for hidden score $hidden',
        );
        expect(
          find.textContaining('$hidden'),
          findsNothing,
          reason: 'substring match for hidden score $hidden',
        );
      }

      // Belt-and-suspenders: walk every Text widget actually painted and
      // confirm none of its text contains any hidden score, so a future
      // change that wraps a score inside a RichText/Row of separate spans
      // still cannot slip past the checks above unnoticed.
      final allText = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join('\n');
      for (final hidden in [
        hiddenInterviewScore,
        hiddenAcceptanceScore,
        hiddenSalesSkillFit,
      ]) {
        expect(allText, isNot(contains('$hidden')));
      }
    },
  );
}
