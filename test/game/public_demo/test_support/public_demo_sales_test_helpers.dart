import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';

/// Test-only helper that mints [engineer]'s genuine client-interview-pass
/// record through the real, sanctioned
/// [PublicDemoEngineerSales.evaluateInterview] entry point (WORKFLOW-STATE-
/// 1AB FIX7 P2, replacing the old `recordInterviewOutcome`-based helper,
/// which injected `passed: true, score: ...` directly — exactly the
/// literal API this fix closed) — the only way to mint a genuine
/// [PublicDemoEngineerInterviewRecord]. `lastInterviewScore != null` alone
/// was FIX5's original (insufficient) assignment-eligibility proof; FIX6
/// replaced it with this unforgeable record, mirroring
/// `completeTestInterview` in public_demo_offer_test_helpers.dart for
/// applicants.
///
/// [engineer] is moved to `partnerInterviewPassed` first — the stage
/// [evaluateInterview] requires before it will even attempt a client
/// interview — then the real evaluator runs against [engineer]'s own
/// [PublicDemoEngineerSales.interviewProfile]/[actualCapability], so the
/// resulting pass is a genuine, formula-derived outcome, not an asserted
/// one. Callers needing a specific score should tune [actualCapability]
/// and/or the profile passed to [engineer] so the real formula clears the
/// pass threshold, rather than asserting a score directly.
PublicDemoEngineerSales recordTestClientInterviewPass(
  PublicDemoEngineerSales engineer, {
  int? actualCapability,
}) => engineer
    .copyWith(stage: PublicDemoSalesStage.partnerInterviewPassed)
    .evaluateInterview(
      type: PublicDemoInterviewType.client,
      actualCapability: actualCapability ?? engineer.interviewProfile.skillFit,
    );
