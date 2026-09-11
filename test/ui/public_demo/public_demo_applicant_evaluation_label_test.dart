// Issue #245 Finding #8: `評価 ${a.interviewScore}` used to render
// PublicDemoApplicant.interviewScore as a bare, unexplained number in the
// Sales-tab applicant card (`ac(i)` in public_demo_01_placeholder_screen.dart).
// publicDemoApplicantEvaluationLabel replaces it with a truthful, qualitative
// statement of the exact same `>= 60` pass line the offer button already
// enforces — never a raw score, never a new threshold the domain does not
// already have.
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

void main() {
  group('publicDemoApplicantEvaluationLabel', () {
    test('never renders a raw digit for any score in range', () {
      for (var score = 0; score <= 100; score++) {
        final label = publicDemoApplicantEvaluationLabel(score);
        expect(
          RegExp(r'\d').hasMatch(label),
          isFalse,
          reason: 'label for score $score must contain no digits: "$label"',
        );
      }
    });

    test('exactly mirrors the existing >= 60 offer-button gate', () {
      expect(
        publicDemoApplicantEvaluationLabel(60),
        '評価: 採用基準を満たしています',
      );
      expect(
        publicDemoApplicantEvaluationLabel(100),
        '評価: 採用基準を満たしています',
      );
      expect(
        publicDemoApplicantEvaluationLabel(59),
        '評価: 採用基準を下回っています',
      );
      expect(
        publicDemoApplicantEvaluationLabel(0),
        '評価: 採用基準を下回っています',
      );
    });
  });
}
