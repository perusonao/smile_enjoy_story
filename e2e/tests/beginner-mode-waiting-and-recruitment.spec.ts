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
//
// '採用画面へ戻る' (RecruitmentInterviewScreen._decide's own hire/reject
// result dialog) is included here — see `waitForTabBar`'s own doc comment
// for why a one-off, non-looping dismiss of that specific button (this
// file's original approach) was the actual root cause of a real CI
// failure, not a flaky timeout.
const CLOSE = ['閉じる', 'OK', '会社状況を見る', '面談依頼を見る', '採用を見る', '社員環境を見る', 'それでも進む', '社員に任せて進む', '採用画面へ戻る'];

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

/** Repeatedly dismisses any known dialog until the bottom tab bar's
 * [tabName] tab is actually present, or a bounded number of iterations is
 * exhausted — root-caused from a real PR #15 CI failure (GitHub Actions run
 * 32000987476, both mobile-chromium and mobile-webkit, reproducing
 * identically on retry): `getByRole('tab', { name: '採用' }).click()` right
 * after a hire/reject decision timed out at 15s with a Call Log reading
 * only "waiting for getByRole(...)" — the locator never matched *anything*,
 * not "matched but was covered/unclickable".
 *
 * Root cause: `RecruitmentInterviewScreen._decide` only runs its trailing
 * `navigator.popUntil((route) => route.isFirst)` (the thing that actually
 * brings the bottom tab bar back — `ApplicantDetailScreen`/
 * `RecruitmentInterviewScreen` are both full `Navigator.push` routes with
 * no tab bar of their own) *after* its own `showDialog` future resolves,
 * which only happens once the player taps the dialog's own "採用画面へ戻る"
 * button — and that dialog can chain into a *second* one-time tutorial
 * dialog (`recruitmentInterviewCelebration`/`welfareUnlockCelebration`)
 * before the pop actually happens. This file's original approach undid
 * that first, then either (a) skipped the tap for a dialog it happened not
 * to see within a single, fixed-delay check, or (b) never accounted for
 * the second, chained dialog — leaving the run stuck on a still-pushed
 * route with genuinely no tab bar, indefinitely. CI's slower/2-worker
 * (`workers: 2` in CI, §e2e/playwright.config.ts) contended timing made
 * that gap land inside the observation window far more reliably than this
 * sandbox's single-worker local runs ever did — not a flaky retry-away
 * timing fluke, a real gap in this file's own screen-state handling. Fixed
 * by looping the *general* dismiss-known-dialogs logic
 * (`settleAndScan`/`CLOSE`, which now also lists '採用画面へ戻る') until
 * the target tab is actually confirmed present via a non-blocking
 * `.count()` check, only then handing off to a real `.click()` — never a
 * blind single click that can wait the full per-action timeout against a
 * locator that will never resolve. */
async function waitForTabBar(page: import('@playwright/test').Page, textOffenders: string[], tabName: string): Promise<boolean> {
  for (let i = 0; i < 20; i++) {
    if (await page.getByRole('tab', { name: tabName, exact: true }).count()) return true;
    const snap = await snapshotScreen(page);
    textOffenders.push(...findDoubledParticles(snap));
    const close = snap.buttons.find((b) => b.enabled && CLOSE.includes(b.name));
    if (close) await page.getByRole('button', { name: close.name, exact: true }).click().catch(() => {});
    await page.waitForTimeout(300);
  }
  return (await page.getByRole('tab', { name: tabName, exact: true }).count()) > 0;
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
    // The hire-result dialog itself is deliberately never asserted on by
    // *content* here (that path is covered live by
    // `test/ui/interview_navigation_test.dart`'s widget tests) — only
    // dismissed, via `waitForTabBar`'s general dialog-draining loop, which
    // is also what actually fixes returning to the tab bar afterwards (see
    // its own doc comment for the real CI failure this replaced). Whether
    // *this* particular applicant's offer was accepted
    // (`RecruitmentEngine.rollAcceptance` is a real per-seed roll) is read
    // back afterwards from the actual GameState signal Beginner Mode's own
    // milestone depends on — a `waitingCount > 0` employee — across a small
    // pool of candidates, rather than from the transient dialog itself.
    expect(await waitForTabBar(page, textOffenders, '採用'), '採用 tab never became visible before the first hire attempt').toBe(true);
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
        expect(await waitForTabBar(page, textOffenders, '採用'), `採用 tab never became visible after skipping attempt ${attempt} (seed=${seed})`).toBe(true);
        await page.getByRole('tab', { name: '採用', exact: true }).click();
        await page.waitForTimeout(300);
        continue;
      }
      await page.getByRole('button', { name: '面接する', exact: true }).click();
      await page.waitForTimeout(800);

      for (let step = 0; step < 8; step++) {
        const snap = await snapshotScreen(page);
        textOffenders.push(...findDoubledParticles(snap));
        if (hasText(snap, '面接まとめ')) {
          await page.getByRole('button', { name: '採用する', exact: true }).click();
          break;
        }
        const anyBtn = snap.buttons.find((b) => b.enabled && b.name !== 'back');
        if (!anyBtn) break;
        await page.getByRole('button', { name: anyBtn.name, exact: true }).click();
        await page.waitForTimeout(500);
      }

      // Drains the hire/reject result dialog — and any one-time tutorial
      // dialog chained after it — until the app's own
      // `navigator.popUntil` has actually run and the tab bar is back.
      // Never a blind, unguarded `.click()` (see `waitForTabBar`'s doc
      // comment for why that was the real bug this replaced).
      expect(
        await waitForTabBar(page, textOffenders, '採用'),
        `採用 tab never became visible after hire attempt ${attempt} (seed=${seed}) — see waitForTabBar`,
      ).toBe(true);
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
