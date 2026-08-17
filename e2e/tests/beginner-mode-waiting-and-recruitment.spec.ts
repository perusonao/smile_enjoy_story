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
 * before the pop actually happens.
 *
 * A first fix here (20 iterations × 300ms ≈ 6s of dismiss-and-poll) still
 * failed on CI (GitHub Actions run 32004253788, both browsers on the first
 * attempt, `Error: 採用 tab never became visible after hire attempt 0`) —
 * *not* a missing dialog label (every dialog this chain can show
 * — 'OK'/'社員環境を見る'/'採用画面へ戻る' — was already in CLOSE) but
 * genuinely not enough real time. Reproduced directly, not guessed, the
 * same way `e2e/README.md`'s Company Setup fix was: a CDP
 * `Emulation.setCPUThrottlingRate` sweep on this exact hire-decision step
 * measured how long the tab bar *actually* takes to reappear once the
 * hire/reject decision is made —
 *   6x  throttle → 2.4s
 *   15x throttle → 5.3s   (already past this function's old ~6s budget)
 *   25x throttle → 12.2s
 *   40x throttle → 20.1s
 * — an almost exactly linear ~0.5s per throttle-x, confirming this is
 * genuinely CPU-bound work (ResultReveal's own 650ms reveal delay +
 * Flutter Web's widget rebuild + semantics-tree recomputation, chained
 * across up to two dialogs), not a stuck/dead state — it always resolves,
 * just proportionally slower under contention. CI's real `workers: 2`
 * (mobile-chromium *and* mobile-webkit running their own full Flutter Web
 * engine simultaneously on a shared 2-core runner, §e2e/playwright.config.ts)
 * plausibly lands somewhere past 15x-equivalent contention, which is
 * exactly where the old 6s budget stopped being enough.
 *
 * Sized to comfortably clear the reproduced 40x/20.1s worst case with real
 * margin, while staying a bounded loop with a real per-iteration recovery
 * action (never README's own explicitly-rejected "unbounded loop of the
 * same submit") — see the same-shaped precedent in `helpers/ses-player.ts`
 * (`fillCompanySetupField`'s confirm-and-retry loop). */
async function waitForTabBar(page: import('@playwright/test').Page, textOffenders: string[], tabName: string): Promise<boolean> {
  const tab = page.getByRole('tab', { name: tabName, exact: true });
  for (let i = 0; i < 60; i++) {
    if (await tab.count()) return true;
    // Cheap, targeted `.count()` checks per known dialog label — not a
    // full `snapshotScreen()` (`ariaSnapshot()`) dump of the whole page
    // every iteration. That was itself real, avoidable CPU work fighting
    // for the same contended CPU this loop exists to wait out — plausibly
    // *self-defeating* under CI's real load, and the likeliest explanation
    // left for why even a ~30s budget (already well past the reproduced
    // 40x-throttle/20s worst case, §doc comment history) still failed
    // 100% reproducibly, but only ever at the *first* hire decision
    // (`recruitmentInterviewCelebration` — a one-time dialog only that
    // first decision ever shows — meaning attempt 0 alone carries the
    // extra dialog *and* the extra snapshot cost stacked together).
    let dismissed = false;
    for (const label of CLOSE) {
      const btn = page.getByRole('button', { name: label, exact: true });
      if (await btn.count()) {
        await btn.click().catch(() => {});
        dismissed = true;
        break;
      }
    }
    // Also tries the AppBar back arrow directly (prefix/case-insensitive —
    // Flutter Web's own accessible name for it is confirmed to vary: plain
    // "Back" on some renders, doubled "Back Back" on others, see
    // `/^Back\b/i` used the same way below at each hire-attempt call
    // site) — safe and idempotent to attempt even when not needed; a
    // route with nothing to pop simply ignores it.
    if (!dismissed) {
      await page.getByRole('button', { name: /^Back\b/i }).first().click({ timeout: 500 }).catch(() => {});
    }
    // Every 5th otherwise-idle iteration, also nudge the target tab
    // directly with a *fresh* locator (never the same held reference
    // across an `await`, which is what caused CI's earlier "element was
    // detached from the DOM, retrying" — see this function's own doc
    // comment history) — safe/idempotent even if the tab isn't needed yet
    // or is already selected, and recovers from any dialog/route shape
    // this file's fixed dismiss list hasn't seen before.
    if (!dismissed && i % 5 === 4) {
      await page.getByRole('tab', { name: tabName, exact: true }).click({ timeout: 500 }).catch(() => {});
    }
    await page.waitForTimeout(500);
  }
  return (await tab.count()) > 0;
}

// Total/per-attempt budget for `clickResilient`, matching
// playwright.config.ts's own `actionTimeout` (15s) — the same "budget
// unchanged, behavior changed" shape as `ses-player.ts`'s
// `clickDecisionResilient`.
const CLICK_RESILIENT_TOTAL_MS = 15_000;
const CLICK_RESILIENT_ATTEMPT_MS = 3_000;

/** Clicks the button named [name], but — unlike a bare `.click()` — never
 * trusts that a target present when the caller decided to click it is still
 * there by the time the click actually lands (CI run 32027667292, HEAD
 * 13800f5: `clickAndWaitForChange`'s bare click timed out the full 15s
 * waiting for "面接する" on mobile-chromium's retry — the exact same "戻る
 * race" shape already root-caused and fixed in `ses-player.ts`'s
 * `clickDecisionResilient`, just on a different button in this file's own
 * click sites). On a timeout, dismisses any currently-stacked known dialog
 * (the same [CLOSE] list `settleAndScan`/`waitForTabBar` already use) and
 * retries, instead of just re-querying the same possibly-gone-for-good
 * locator — total budget unchanged (15s), never a longer timeout. */
async function clickResilient(page: import('@playwright/test').Page, name: string): Promise<void> {
  const deadline = Date.now() + CLICK_RESILIENT_TOTAL_MS;
  while (true) {
    const remaining = deadline - Date.now();
    const attemptTimeout = Math.max(500, Math.min(CLICK_RESILIENT_ATTEMPT_MS, remaining));
    try {
      await page.getByRole('button', { name, exact: true }).first().click({ timeout: attemptTimeout });
      return;
    } catch (err) {
      if (Date.now() >= deadline) throw err;
      const snap = await snapshotScreen(page);
      const close = snap.buttons.find((b) => b.enabled && CLOSE.includes(b.name) && b.name !== name);
      if (close) {
        await page.getByRole('button', { name: close.name, exact: true }).click().catch(() => {});
        await page.waitForTimeout(300);
      }
      // Otherwise just loop straight back to a fresh click attempt — the
      // target may simply need another beat to (re)appear.
    }
  }
}

/** Polls (bounded) until at least one real, enabled action button is on
 * screen — used after a navigation that can transiently render a loading
 * state first (`RecruitmentInterviewScreen` shows a bare
 * `CircularProgressIndicator` while `c.interviewApplicant(applicantId)`'s
 * `postFrameCallback` is still pending, `ApplicantDetailScreen` while its
 * route is still transitioning in). A fixed sleep before checking risked
 * reading that loading frame under CI's demonstrated contention (see
 * `clickAndWaitForChange`'s doc comment) and finding zero enabled buttons
 * — which the interview-Q&A loop treats as "nothing left to do here" and
 * exits immediately, well before ever reaching "面接まとめ". */
async function waitForAnyEnabledButton(page: import('@playwright/test').Page): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  // Same ~30s order of magnitude as `waitForTabBar` (see its own doc
  // comment for the CPU-throttling reproduction this is sized against) —
  // a route transition or `postFrameCallback` resolving is exactly the
  // same class of CPU-bound work, just a different screen.
  for (let i = 0; i < 40 && !snap.buttons.some((b) => b.enabled && b.name !== 'back'); i++) {
    await page.waitForTimeout(300);
    snap = await snapshotScreen(page);
  }
  return snap;
}

/** Clicks [buttonName] and actively polls (bounded) until the screen's own
 * text content actually differs from [beforeSnap] — never a single fixed
 * `waitForTimeout`. Root-caused directly: raising `waitForTabBar`'s own
 * budget (above) did *not* fix CI run 32007245654's identical, 100%-
 * reproducing (both browsers, both the first try and the retry) failure at
 * the very same "hire attempt 0" point — which only made sense if the
 * interview Q&A step loop that runs *before* any hire/reject decision was
 * itself never actually reaching "面接まとめ" at all under CI's real
 * contention, not `waitForTabBar` failing to wait long enough for a
 * decision that had already been made.
 *
 * Reproduced directly (not guessed), the same CPU-throttling methodology
 * as `waitForTabBar` and `e2e/README.md`'s own Company Setup fix: at just
 * 15x throttle, the gap between one interview-question click and the next
 * question actually rendering measured 2354-5035ms *per step* — the
 * original loop's fixed `waitForTimeout(500)` between clicks was almost an
 * order of magnitude too short, so under real contention it could click a
 * still-stale screen (or simply exhaust its 8-iteration budget) well
 * before ever reaching "面接まとめ" — meaning `waitForTabBar` afterwards
 * was correctly reporting "no tab bar", because the hire/reject decision
 * that would have produced one had never actually been made. */
async function clickAndWaitForChange(
  page: import('@playwright/test').Page,
  buttonName: string,
  beforeSnap: ScreenSnapshot,
): Promise<ScreenSnapshot> {
  await clickResilient(page, buttonName);
  const beforeKey = JSON.stringify(beforeSnap.texts);
  for (let i = 0; i < 40; i++) {
    await page.waitForTimeout(300);
    const snap = await snapshotScreen(page);
    if (JSON.stringify(snap.texts) !== beforeKey) return snap;
  }
  return snapshotScreen(page);
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

    // `RecruitmentEngine.acceptanceRate` (60 + credit*0.2 + (impression-50)*
    // 0.55, clamped 5-95) puts a fresh company's real per-candidate
    // acceptance chance in roughly the 50-70% range. An earlier version of
    // this comment theorized the repeated "0 accepted" CI failures were a
    // genuine, if unlucky, statistical outcome (all N candidates declining)
    // and raised HIRE_ATTEMPTS from 5 to 9 to shrink that odds. That theory
    // does not hold up: a direct replay of this exact seed's click
    // sequence — both a pure-engine (Dart) reproduction and a real local
    // browser run — shows 8 of 9 offers ACCEPTED and the milestone firing
    // cleanly at week 7 (PR #15 CI run 32023887460 investigation). The
    // repeated CI failures were click-target staleness under CI's real
    // `workers: 2` contention (`clickAndWaitForChange`/'面接する' timing
    // out mid-interview, matching the "戻る race" already root-caused in
    // `ses-player.ts` — see `clickResilient`, above), not a statistics
    // problem — HIRE_ATTEMPTS stays at 9 for real margin against genuine
    // decline streaks, not as a workaround for that bug class.
    const HIRE_ATTEMPTS = 9;
    for (let attempt = 0; attempt < HIRE_ATTEMPTS; attempt++) {
      const candidate = page.getByRole('button', { name: /未面接/ }).first();
      if ((await candidate.count()) === 0) break;
      await candidate.click({ timeout: 8000 });
      const interviewBtn = enabledButton(await waitForAnyEnabledButton(page), '面接する');
      if (!interviewBtn) {
        // Already interviewed with nothing left to click (e.g. re-opened
        // mid-interview) — no hire/reject decision happens on this path,
        // so unlike the two other call sites below, the app never
        // auto-switches back to the Recruitment tab here: `waitForTabBar`
        // would just spin its whole budget with nothing to dismiss on a
        // bare pushed `ApplicantDetailScreen` route (root-caused from CI
        // run 32013541813's chromium retry, which timed out exactly this
        // way). Pop the route directly via its own back button instead —
        // Flutter Web's auto-inserted AppBar back arrow's accessible name
        // is confirmed to vary by browser: literally "Back Back" (doubled)
        // on Chromium via a raw ariaSnapshot() dump — the same doubling
        // `helpers/game-state.ts`'s own `CHROME_BUTTON_NAME` regex,
        // `(back\s*)+`, already exists to recognize — but CI's WebKit run
        // still failed here even after matching that exact string,
        // implying WebKit's own accessible name differs again (plausibly
        // plain "Back", un-doubled — Flutter Web's semantics-to-native-a11y
        // bridging is engine-specific). A prefix/case-insensitive
        // `/^Back\b/i` covers "Back", "Back Back", or any further
        // variation uniformly, instead of hardcoding one exact string this
        // file has already been wrong about once.
        await page.getByRole('button', { name: /^Back\b/i }).first().click().catch(() => {});
        expect(await waitForTabBar(page, textOffenders, '採用'), `採用 tab never became visible after skipping attempt ${attempt} (seed=${seed})`).toBe(true);
        continue;
      }
      await clickResilient(page, '面接する');
      await waitForAnyEnabledButton(page);

      // Bounded at 12 (3 questions + 1 reverse-question + occasional
      // incidental taps like the "過去の回答" history expansion tile, with
      // real margin) — each click uses `clickAndWaitForChange`'s own
      // confirm-and-retry poll instead of a fixed sleep, so this loop's
      // total real time scales with how long the app actually takes under
      // whatever contention is present, the same way `waitForTabBar` does.
      for (let step = 0; step < 12; step++) {
        const snap = await snapshotScreen(page);
        textOffenders.push(...findDoubledParticles(snap));
        if (hasText(snap, '面接まとめ')) {
          await clickResilient(page, '採用する');
          break;
        }
        const anyBtn = snap.buttons.find((b) => b.enabled && b.name !== 'back');
        if (!anyBtn) break;
        await clickAndWaitForChange(page, anyBtn.name, snap);
      }

      // Drains the hire/reject result dialog — and any one-time tutorial
      // dialog chained after it — until the app's own
      // `navigator.popUntil` has actually run and the tab bar is back.
      // Never a blind, unguarded `.click()` (see `waitForTabBar`'s doc
      // comment for why that was the real bug this replaced).
      //
      // Deliberately *no* explicit tab click after this: `_decide()`
      // itself already sets `tabIndex.value = SesTab.recruitment`
      // unconditionally (both hire and reject) as the very last step of
      // completing the decision, so by the time `waitForTabBar` finds the
      // "採用" tab present, we are already on it. Clicking it again here
      // used to race Flutter Web's own semantics-tree churn right after
      // that switch — root-caused from CI run 32013541813's mobile-webkit
      // failure: `waitForTabBar` correctly found the tab
      // (`aria-selected="true"`, i.e. already active), but the very next
      // `.click()` failed for the full 15s with "element was detached
      // from the DOM, retrying" — a redundant click on an already-current,
      // still-settling tab, not a missing navigation.
      expect(
        await waitForTabBar(page, textOffenders, '採用'),
        `採用 tab never became visible after hire attempt ${attempt} (seed=${seed}) — see waitForTabBar`,
      ).toBe(true);
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
    for (let i = 0; i < 10 && !waitingCostDialog; i++) {
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
