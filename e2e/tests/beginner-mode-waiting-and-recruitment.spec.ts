// Phase 3A UX review follow-up: real-UI E2E coverage for the two
// BeginnerMilestone dialogs the general Playwright playthrough
// (beginner-mode-april-june.spec.ts) never actually triggers in practice —
// `waitingCostExplained` and `recruitmentTradeoffExplained`. Both require a
// player choice (post a *second* recruitment listing; hire an applicant and
// leave them unassigned for a week) that the general auto-player has no
// reason to make on its own, so unit tests constructing GameState directly
// were the only coverage either milestone had until this file.
//
// That gap was not just a missing test: driving this scenario for real
// turned up a genuine engine bug (see the `recruitmentTradeoffExplained`
// fix in beginner_mode_engine.dart / the new `GameStats.
// recruitmentListingsPosted` counter) that every existing unit test missed,
// because those tests construct `listings` directly instead of going
// through `GameEngine.advanceWeek`'s weekly active-listings pruning. This
// file is the reason that bug is fixable at all — §0 of the Phase 3A UX
// review: "単体テストだけで完了扱いにしないでください" (don't consider this
// done via unit tests alone).
import { test, expect } from '@playwright/test';
import { playFoundingToFirstAssignment } from '../helpers/ses-player';
import { snapshotScreen, hasText, enabledButton, findDoubledParticles, type ScreenSnapshot } from '../helpers/game-state';
import { watchForErrors, captureMilestone } from '../helpers/artifacts';
import { parseSeeds } from '../helpers/seeds';

// Deterministic under a fixed seed (RNG salts include `state.seed` and
// `state.week`) — a single seed is enough to prove both dialogs really
// fire in the real UI; override with SES_E2E_WAITING_RECRUITMENT_SEEDS for
// a wider batch.
const DEFAULT_SEEDS = [100001];
const parsedSeeds = parseSeeds(process.env.SES_E2E_WAITING_RECRUITMENT_SEEDS, DEFAULT_SEEDS);

const FOUNDING_MAX_WEEKS = 12;
const FOUNDING_MAX_ACTIONS = 100;
const IDLE_TIMEOUT_MS = 30_000;
const STALL_REPEAT_THRESHOLD = 5;

// Dialogs whose dismiss button is always safe to tap without losing
// anything under test — mirrors the CLOSE list every other Phase 3A E2E
// driver already uses (beginner-mode-player.ts, founding-first-assignment
// helpers), duplicated locally rather than exported/shared because this
// file's own poll loop (settleAndScan, below) needs to *inspect* each
// dialog's text before dismissing it, which the shared drivers don't do.
const CLOSE = ['閉じる', 'OK', '会社状況を見る', '面談依頼を見る', '採用を見る', '社員環境を見る', 'それでも進む', '社員に任せて進む'];

/** Dismisses every dialog currently stacked on screen, recording each one's
 * full text (for the doubled-particle scan) along the way, and stops the
 * instant [stopWhen] matches a dialog's own text — leaving that dialog
 * still on screen for the caller to assert against before dismissing it
 * itself. Returns the snapshot [stopWhen] matched, or `null` if the queue
 * drained without a match. */
async function settleAndScan(
  page: import('@playwright/test').Page,
  textOffenders: string[],
  stopWhen?: (snap: ScreenSnapshot) => boolean,
): Promise<ScreenSnapshot | null> {
  for (let i = 0; i < 15; i++) {
    const snap = await snapshotScreen(page);
    textOffenders.push(...findDoubledParticles(snap));
    if (stopWhen?.(snap)) return snap;
    const close = snap.buttons.find((b) => b.enabled && CLOSE.includes(b.name));
    if (!close) return null;
    await page.getByRole('button', { name: close.name, exact: true }).click();
    await page.waitForTimeout(500);
    const homeTab = page.getByRole('tab', { name: 'ホーム', exact: true });
    if (await homeTab.count()) {
      const cur = await snapshotScreen(page);
      if (!cur.buttons.some((b) => b.name.startsWith('次の週へ'))) {
        await homeTab.click().catch(() => {});
        await page.waitForTimeout(400);
      }
    }
  }
  return null;
}

/** Taps "次の週へ" (after clearing anything already pending) and returns the
 * first dialog matching [stopWhen] that appears as a *result* of that
 * advance, still on screen — or `null` if the week advanced cleanly with no
 * such dialog. */
async function advanceWeekAndFind(
  page: import('@playwright/test').Page,
  textOffenders: string[],
  stopWhen: (snap: ScreenSnapshot) => boolean,
): Promise<ScreenSnapshot | null> {
  await settleAndScan(page, textOffenders);
  const snap = await snapshotScreen(page);
  const nextBtn = snap.buttons.find((b) => b.enabled && b.name.startsWith('次の週へ'));
  if (!nextBtn) return null;
  await page.getByRole('button', { name: nextBtn.name, exact: true }).click();
  await page.waitForTimeout(700);
  return settleAndScan(page, textOffenders, stopWhen);
}

if (parsedSeeds.error) {
  test('SES_E2E_WAITING_RECRUITMENT_SEEDS is invalid', () => {
    throw new Error(parsedSeeds.error!);
  });
}

for (const seed of parsedSeeds.seeds) {
  test(`Phase 3A: waiting-cost and recruitment-tradeoff dialogs fire in real UI (seed ${seed})`, async ({ page }, testInfo) => {
    test.setTimeout(6 * 60 * 1000);
    const errors = watchForErrors(page);
    const textOffenders: string[] = [];

    await page.goto(`/?e2e=1&seed=${seed}`);
    await playFoundingToFirstAssignment(page, {
      maxWeeks: FOUNDING_MAX_WEEKS,
      maxActions: FOUNDING_MAX_ACTIONS,
      idleTimeoutMs: IDLE_TIMEOUT_MS,
      stallRepeatThreshold: STALL_REPEAT_THRESHOLD,
    });
    await page.getByRole('button', { name: '経営を始める', exact: true }).click({ timeout: 5000 }).catch(() => {});
    await page.waitForTimeout(1000);
    await settleAndScan(page, textOffenders);

    // Recruitment unlocks `UnlockEngine.weeksBeforeCompanyGrowth` (2) weeks
    // after the first assignment — advance a handful of weeks to get there,
    // same as the real player would.
    for (let i = 0; i < 4; i++) {
      await advanceWeekAndFind(page, textOffenders, () => false);
    }
    await captureMilestone(page, testInfo, '01-recruitment-unlocked');

    // --- recruitmentTradeoffExplained -------------------------------
    // Post a second listing (Free Work, ¥0 — always affordable) — a real
    // post-founding *growth* decision, not the March founding hire itself.
    await page.getByRole('tab', { name: '採用', exact: true }).click();
    await page.waitForTimeout(500);
    await page.getByRole('button', { name: '掲載する', exact: true }).first().click();
    await page.waitForTimeout(600);
    const after = await snapshotScreen(page);
    // Confirms the click actually posted (not a silent no-op) before
    // trusting the milestone assertion below to mean anything.
    expect(after.buttons.some((b) => b.name.startsWith('掲載中')), 'second listing did not actually post').toBe(true);

    await page.getByRole('tab', { name: 'ホーム', exact: true }).click();
    await page.waitForTimeout(500);
    const tradeoffDialog = await advanceWeekAndFind(page, textOffenders, (snap) => hasText(snap, '採用のトレードオフ'));
    expect(tradeoffDialog, `採用のトレードオフ dialog never appeared after posting a second listing (seed=${seed})`).not.toBeNull();
    expect(hasText(tradeoffDialog!, '固定支出')).toBe(true);
    await captureMilestone(page, testInfo, '02-recruitment-tradeoff-dialog');
    await settleAndScan(page, textOffenders);

    // --- waitingCostExplained ----------------------------------------
    // Interview and hire not-yet-interviewed applicants (matched by
    // role+name via the accessibility tree directly — see the
    // ApplicantDetailScreen investigation this test grew out of: the
    // ListView's own outer Semantics group ends up with an
    // over-long/truncated aria-label that makes Playwright's
    // ariaSnapshot()-based `snapshotScreen` unable to see these cards as
    // *text*, even though each card is individually a well-labelled
    // `role=button` node the accessibility tree still exposes — so
    // `getByRole` here, not `snapshotScreen`, is deliberate).
    //
    // The hire-result dialog (`RecruitmentInterviewScreen._decide`'s
    // `showDialog` + `ResultReveal`) is deliberately *not* asserted on here:
    // a real, human-paced tap sees it (that path is covered by
    // `test/ui/interview_navigation_test.dart`'s widget tests), but a
    // synthetic Playwright click resolves to the post-decision screen state
    // faster than even a single 100ms poll can observe it — confirmed by
    // direct investigation (screenshots taken every 100ms from click never
    // once caught the dialog on screen). Whether *this* particular
    // applicant's offer was accepted (`RecruitmentEngine.rollAcceptance` is
    // a real per-seed roll) is instead read back afterwards from the actual
    // GameState signal Beginner Mode's own milestone depends on — a
    // `waitingCount > 0` employee — across a small pool of candidates,
    // rather than from this unreliable-to-observe transient dialog.
    await page.getByRole('tab', { name: '採用', exact: true }).click();
    await page.waitForTimeout(500);

    const HIRE_ATTEMPTS = 5;
    for (let attempt = 0; attempt < HIRE_ATTEMPTS; attempt++) {
      const candidate = page.getByRole('button', { name: /未面接/ }).first();
      if ((await candidate.count()) === 0) break;
      await candidate.click({ timeout: 8000 });
      await page.waitForTimeout(500);
      const interviewBtn = enabledButton(await snapshotScreen(page), '面接する');
      if (!interviewBtn) {
        await page.getByRole('tab', { name: '採用', exact: true }).click();
        continue;
      }
      await page.getByRole('button', { name: '面接する', exact: true }).click();
      await page.waitForTimeout(800);

      for (let step = 0; step < 8; step++) {
        const snap = await snapshotScreen(page);
        textOffenders.push(...findDoubledParticles(snap));
        if (hasText(snap, '面接まとめ')) {
          await page.getByRole('button', { name: '採用する', exact: true }).click();
          await page.waitForTimeout(500);
          // Best-effort: dismiss the result dialog if this poll happens to
          // still catch it (real/slower browsers) — a no-op the rest of the
          // time, per the comment above.
          const resultSnap = await snapshotScreen(page);
          const back = enabledButton(resultSnap, '採用画面へ戻る');
          if (back) {
            await page.getByRole('button', { name: '採用画面へ戻る', exact: true }).click();
            await page.waitForTimeout(500);
          }
          break;
        }
        const anyBtn = snap.buttons.find((b) => b.enabled && b.name !== 'back');
        if (!anyBtn) break;
        await page.getByRole('button', { name: anyBtn.name, exact: true }).click();
        await page.waitForTimeout(500);
      }
      await page.getByRole('tab', { name: '採用', exact: true }).click();
      await page.waitForTimeout(300);
    }
    await captureMilestone(page, testInfo, '03-applicants-interviewed');

    // At least one of the `HIRE_ATTEMPTS` offers must have been accepted for
    // any of what follows to mean anything — a per-seed
    // `RecruitmentEngine.rollAcceptance` roll, read back once GameState
    // actually reflects it (not from the unreliable-to-observe transient
    // dialog above): a joined-and-waiting employee is exactly the fact
    // `waitingCostExplained` itself depends on, so the advance-week loop
    // below is both the acceptance check and the milestone wait in one —
    // a pending hire needs its own `joinWeek` (1-3 weeks out) to pass
    // *and* a further week spent still unassigned before the milestone's
    // own condition (`waitingStreak >= 1`) is satisfied.
    await page.getByRole('tab', { name: 'ホーム', exact: true }).click();
    await page.waitForTimeout(500);
    let waitingCostDialog: ScreenSnapshot | null = null;
    for (let i = 0; i < 8 && !waitingCostDialog; i++) {
      waitingCostDialog = await advanceWeekAndFind(page, textOffenders, (snap) => hasText(snap, '待機社員にも給与が発生しています'));
    }
    expect(
      waitingCostDialog,
      `待機社員にも給与が発生しています dialog never appeared after ${HIRE_ATTEMPTS} hire attempts + waiting (seed=${seed}) — ` +
        'either every offer was declined, or the milestone itself regressed',
    ).not.toBeNull();
    expect(hasText(waitingCostDialog!, '待機社員')).toBe(true);
    await captureMilestone(page, testInfo, '04-waiting-cost-dialog');
    await settleAndScan(page, textOffenders);

    expect(errors.pageErrors, `uncaught page errors (seed=${seed})`).toEqual([]);
    expect(errors.crashed, `page crashed (seed=${seed})`).toBe(false);
    expect(errors.consoleErrors, `unallowlisted console.error (seed=${seed})`).toEqual([]);
    expect(textOffenders, `doubled-particle text observed (seed=${seed}): ${JSON.stringify(textOffenders)}`).toEqual([]);
  });
}
