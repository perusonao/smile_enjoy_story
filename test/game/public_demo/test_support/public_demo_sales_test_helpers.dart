import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';

/// Test-only helper that mints [engineer]'s genuine client-interview-pass
/// record through the real, sanctioned
/// [PublicDemoEngineerSales.recordInterviewOutcome] entry point
/// (WORKFLOW-STATE-1AB FIX6 P1) — the only way to mint a genuine
/// [PublicDemoEngineerInterviewRecord]. `lastInterviewScore != null` alone
/// was FIX5's original (insufficient) assignment-eligibility proof; FIX6
/// replaced it with this unforgeable record, mirroring
/// `completeTestInterview` in public_demo_offer_test_helpers.dart for
/// applicants.
PublicDemoEngineerSales recordTestClientInterviewPass(
  PublicDemoEngineerSales engineer, {
  int score = 80,
}) => engineer.recordInterviewOutcome(
  type: PublicDemoInterviewType.client,
  passed: true,
  score: score,
);
