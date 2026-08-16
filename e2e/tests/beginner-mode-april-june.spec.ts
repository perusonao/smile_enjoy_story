// Phase 3A (S.E.S. Development Plan §3.2, §3.9): real-UI E2E coverage for
// the April-June Beginner Mode continuation — company setup -> hiring ->
// first assignment -> April -> first revenue/receivable -> month-end
// payment -> first cash collection -> May -> June, driven purely by
// following whatever the production UI presents, exactly like
// founding-first-assignment.spec.ts does for the March founding itself.
import { test, expect } from '@playwright/test';
import { emptyPlayResult, playFoundingToFirstAssignment, type PlayResult } from '../helpers/ses-player';
import { playBeginnerModeThroughJune, type BeginnerModePlayResult } from '../helpers/beginner-mode-player';
import { buildResultJson, captureMilestone, watchForErrors, writeArtifacts } from '../helpers/artifacts';
import { parseSeeds } from '../helpers/seeds';
import fs from 'fs';
import path from 'path';

// A smaller, fast default (§18: "可能なら複数seedで確認") — two of the same
// seed pool founding-first-assignment.spec.ts already validates the March
// half against, kept short here because each run also drives 12 further
// weeks of Home (April-June), which is materially slower than the founding
// scenario alone. Override with SES_E2E_BEGINNER_SEEDS for a fuller batch.
const DEFAULT_SEEDS = [100001, 100002];
const parsedSeeds = parseSeeds(process.env.SES_E2E_BEGINNER_SEEDS, DEFAULT_SEEDS);

const FOUNDING_MAX_WEEKS = 12;
const FOUNDING_MAX_ACTIONS = 100;
const IDLE_TIMEOUT_MS = 30_000;
const STALL_REPEAT_THRESHOLD = 5;

// Phase 3A's own window (BeginnerModeEngine.lastWeek) — the end of June.
const BEGINNER_TARGET_WEEK = 12;
const BEGINNER_MAX_ACTIONS = 200;

if (parsedSeeds.error) {
  test('SES_E2E_BEGINNER_SEEDS is invalid', () => {
    throw new Error(parsedSeeds.error!);
  });
}

for (const seed of parsedSeeds.seeds) {
  test(`Phase 3A: founding -> first assignment -> April-June (seed ${seed})`, async ({ page }, testInfo) => {
    test.setTimeout(8 * 60 * 1000);
    const errors = watchForErrors(page);
    const startedAt = Date.now();
    let foundingResult: PlayResult | null = null;
    let beginnerResult: BeginnerModePlayResult | null = null;
    let playError: unknown = null;

    const seenMilestones = new Set<string>();
    const capture = async (name: string) => {
      if (seenMilestones.has(name)) return;
      seenMilestones.add(name);
      await captureMilestone(page, testInfo, name);
    };

    try {
      await page.goto(`/?e2e=1&seed=${seed}`);

      // Phase 1: 会社設立 -> 採用 -> 初案件参画 (reuses the same, already
      // validated founding driver founding-first-assignment.spec.ts uses —
      // §0 of the Phase 3A brief: don't reimplement what already works).
      foundingResult = await playFoundingToFirstAssignment(page, {
        maxWeeks: FOUNDING_MAX_WEEKS,
        maxActions: FOUNDING_MAX_ACTIONS,
        idleTimeoutMs: IDLE_TIMEOUT_MS,
        stallRepeatThreshold: STALL_REPEAT_THRESHOLD,
      });
      await capture('01-first-assignment');

      if (foundingResult.completed && !foundingResult.stallDetected) {
        // Phase 2: 4月 -> 初売上/売掛金 -> 月末支払 -> 初入金 -> 5月 -> 6月.
        let lastWeekSeen = -1;
        beginnerResult = await playBeginnerModeThroughJune(page, {
          targetWeek: BEGINNER_TARGET_WEEK,
          maxActions: BEGINNER_MAX_ACTIONS,
          idleTimeoutMs: IDLE_TIMEOUT_MS,
          onScreen: async (snap, week) => {
            if (week !== null && week !== lastWeekSeen) {
              lastWeekSeen = week;
              if (week === 1) await capture('02-april-week1');
              if (week === 5) await capture('03-may-week1');
              if (week === 9) await capture('04-june-week1');
            }
            if (snap.texts.some((t) => t.includes('初心者経営編') || t.includes('初心者経営期間'))) await capture('05-beginner-mode-card');
            if (snap.texts.some((t) => t.includes('売上が発生しました'))) await capture('06-revenue-vs-cash');
            if (snap.texts.some((t) => t.includes('月次決算'))) await capture('07-monthly-closing');
            if (snap.texts.some((t) => t.includes('初入金'))) await capture('08-first-collection');
          },
        });
        await capture('09-end-of-june');
      }
    } catch (err) {
      playError = err;
    } finally {
      const finalFounding = foundingResult ?? emptyPlayResult(`playFoundingToFirstAssignment threw before returning: ${String(playError)}`);
      const resultJson = buildResultJson({
        scenario: 'beginner-mode-april-june',
        device: testInfo.project.name,
        seed,
        play: finalFounding,
        errors,
        durationMs: Date.now() - startedAt,
      });
      await writeArtifacts(testInfo, resultJson, finalFounding.actionTrace);

      const beginnerPath = path.join(testInfo.outputDir, 'beginner-mode-result.json');
      fs.mkdirSync(testInfo.outputDir, { recursive: true });
      fs.writeFileSync(beginnerPath, JSON.stringify(beginnerResult, null, 2), 'utf-8');
      await testInfo.attach('beginner-mode-result.json', { path: beginnerPath, contentType: 'application/json' });

      if (!finalFounding.completed || finalFounding.stallDetected || !beginnerResult?.completed || beginnerResult?.stallDetected || errors.pageErrors.length > 0 || errors.consoleErrors.length > 0 || playError) {
        // eslint-disable-next-line no-console
        console.log(`[SES E2E Phase 3A] seed=${seed} device=${testInfo.project.name} FAILED — reproduce with ?e2e=1&seed=${seed}`, JSON.stringify({ resultJson, beginnerResult }, null, 2));
      }
    }

    if (playError) throw playError;

    expect(errors.pageErrors, `uncaught page errors (seed=${seed})`).toEqual([]);
    expect(errors.crashed, `page crashed (seed=${seed})`).toBe(false);
    expect(errors.consoleErrors, `unallowlisted console.error (seed=${seed})`).toEqual([]);

    expect(foundingResult!.stallDetected, `founding dead-end/stall (seed=${seed}): ${foundingResult!.stallReason}`).toBe(false);
    expect(foundingResult!.completed, `did not reach first assignment (seed=${seed})`).toBe(true);

    expect(beginnerResult, `Beginner Mode driver never ran (seed=${seed})`).not.toBeNull();
    expect(beginnerResult!.stallDetected, `Phase 3A dead-end/stall (seed=${seed}): ${beginnerResult!.stallReason}`).toBe(false);
    expect(beginnerResult!.completed, `did not reach week ${BEGINNER_TARGET_WEEK} (seed=${seed})`).toBe(true);
    expect(beginnerResult!.finalWeek, `seed=${seed}`).toBeGreaterThanOrEqual(BEGINNER_TARGET_WEEK);

    // §5/§9 of the Phase 3A brief: "revenue != cash" must actually have been
    // taught somewhere along the way (the first-assignment celebration or
    // the first-AR tutorial, whichever fires first for this seed's timing).
    expect(beginnerResult!.milestones.revenueVsCashExplained, `売上≠現金 was never shown (seed=${seed})`).toBe(true);
  });
}
