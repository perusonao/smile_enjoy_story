// Founding First Assignment — the single most important S.E.S. E2E scenario
// (§5 of the E2E brief): from a brand-new game to the first案件参画,
// driven purely by following the Guided Founding UI, exactly as a
// first-time player would.
import { test, expect } from '@playwright/test';
import { emptyPlayResult, playFoundingToFirstAssignment, type PlayResult } from '../helpers/ses-player';
import { buildResultJson, captureMilestone, watchForErrors, writeArtifacts } from '../helpers/artifacts';

// §24: "最低10ゲーム、異なるseedで" — the full 10-seed batch is the
// project's own validation deliverable (see e2e/README.md "10-seed
// validation") and runs on demand via `SES_E2E_SEEDS`/workflow_dispatch.
// The default here (checked on every PR, §20) is a fast 3-seed sample of
// that same set so day-to-day CI stays quick without weakening what a
// developer sees on every push.
const DEFAULT_SEEDS = [100001, 100002, 100003, 100004, 100005, 100006, 100007, 100008, 100009, 100010];
const SEEDS = process.env.SES_E2E_SEEDS
  ? process.env.SES_E2E_SEEDS.split(',').map((s) => Number(s.trim())).filter((n) => Number.isFinite(n))
  : DEFAULT_SEEDS.slice(0, 3);

// §13: existing tool/simulate_prologue.dart buckets its own "eventual"
// first-assignment rate at prologueWeek <= 12 (assignedApril3) — reused
// here rather than inventing a separate cap, since it's the one number in
// the repo already calibrated against this exact flow.
const MAX_WEEKS = 12;
const MAX_ACTIONS = 100;
const IDLE_TIMEOUT_MS = 30_000;
const STALL_REPEAT_THRESHOLD = 5;

const MILESTONE_SCREEN_LABELS: Record<string, string> = {
  'start-choice': '01-game-start',
  'sales-start': '02-sales-start',
  'interview-request': '03-interview-request',
  'upper-interview': '04-client-interview',
};

for (const seed of SEEDS) {
  test(`Founding First Assignment (seed ${seed})`, async ({ page }, testInfo) => {
    const errors = watchForErrors(page);
    const startedAt = Date.now();
    let result: PlayResult | null = null;
    let playError: unknown = null;

    // try/finally (Codex follow-up §15): result.json/action-trace.json must
    // land even if something throws before the normal end of the test body
    // — Playwright's own video/screenshot/trace still get produced either
    // way, but the custom artifacts previously didn't.
    try {
      await page.goto(`/?e2e=1&seed=${seed}`);

      const seenMilestones = new Set<string>();
      result = await playFoundingToFirstAssignment(page, {
        maxWeeks: MAX_WEEKS,
        maxActions: MAX_ACTIONS,
        idleTimeoutMs: IDLE_TIMEOUT_MS,
        stallRepeatThreshold: STALL_REPEAT_THRESHOLD,
        onScreen: async (screen) => {
          const label = MILESTONE_SCREEN_LABELS[screen];
          if (label && !seenMilestones.has(label)) {
            seenMilestones.add(label);
            await captureMilestone(page, testInfo, label);
          }
        },
      });

      await captureMilestone(page, testInfo, result.completed ? '05-first-assignment' : '99-stopped-here');
    } catch (err) {
      playError = err;
    } finally {
      const finalResult = result ?? emptyPlayResult(`playFoundingToFirstAssignment threw before returning: ${String(playError)}`);
      const resultJson = buildResultJson({
        scenario: 'founding-first-assignment',
        device: testInfo.project.name,
        seed,
        play: finalResult,
        errors,
        durationMs: Date.now() - startedAt,
      });
      await writeArtifacts(testInfo, resultJson, finalResult.actionTrace);

      if (!finalResult.completed || finalResult.stallDetected || errors.pageErrors.length > 0 || errors.consoleErrors.length > 0 || playError) {
        // eslint-disable-next-line no-console
        console.log(`[SES E2E] seed=${seed} device=${testInfo.project.name} FAILED — reproduce with ?e2e=1&seed=${seed}`, JSON.stringify(resultJson, null, 2));
      }
    }

    if (playError) throw playError;

    // Error policy (§8 of the Codex follow-up): pageerror/crash/an
    // unallowlisted console.error all fail the test — a silent JS
    // exception or error-level log mid-playthrough is not a pass just
    // because a button happened to still be clickable after it.
    expect(errors.pageErrors, `uncaught page errors (seed=${seed})`).toEqual([]);
    expect(errors.crashed, `page crashed (seed=${seed})`).toBe(false);
    expect(errors.consoleErrors, `unallowlisted console.error (seed=${seed})`).toEqual([]);

    // The actual thing this scenario exists to prove (§0, §29): the player
    // was never stuck, and reached the first assignment.
    expect(result!.stallDetected, `dead-end/stall (seed=${seed}): ${result!.stallReason}`).toBe(false);
    expect(result!.completed, `did not reach first assignment within ${MAX_ACTIONS} actions / ${MAX_WEEKS} weeks (seed=${seed})`).toBe(true);
  });
}
