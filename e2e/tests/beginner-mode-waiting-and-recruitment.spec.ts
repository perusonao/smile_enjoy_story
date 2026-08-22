// Phase 3A UX review follow-up: real-UI E2E coverage for the recruitment
// flow the general Playwright playthrough (beginner-mode-april-june.spec.ts)
// never actually exercises — posting a *second* recruitment listing, and
// interviewing/hiring post-founding applicants. Unit tests constructing
// GameState directly were the only coverage either of Beginner Mode's
// recruitment-related milestones had until this file first existed.
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
//
// Responsibility split (PR #15 CI investigation, run 32029449859 —
// repeated CI-only failures on `waitingCostExplained` traced to a real-per-
// seed `RecruitmentEngine.rollAcceptance` RNG roll, not a bug, but this
// file kept treating "at least one of N candidates accepts" as something a
// real-UI E2E should *guarantee*): this file no longer asserts that any
// specific candidate's offer is accepted, or that `waitingCostExplained`'s
// dialog appears — that would make a real-UI integration test's pass/fail
// depend on a probabilistic roll, which is exactly the test-design mistake
// this split fixes.
//   - "Does the milestone actually fire, given the right GameState facts?"
//     -> test/game/beginner_mode_test.dart's Test E2 (a directly-
//     constructed PendingHire, no interview UI, no RNG) and the matching
//     widget test in test/ui/beginner_mode_widget_test.dart (asserts the
//     real dialog renders from a real "次の週へ" tap). Deterministic,
//     seconds to run, exercise the exact GameEngine.advanceWeek join path.
//   - "Is the recruitment flow actually operable in the real UI, and does
//     it never dead-end?" -> this file. What it *does* still assert, every
//     run, regardless of any candidate's RNG roll: the recruitment tab
//     stays reachable, an interview can be started and completed for
//     multiple candidates in a row, the app always returns to a legitimate
//     screen afterwards (never stuck on a dead route), and there are no
//     uncaught errors / unallowlisted console.error / doubled-particle
//     text anywhere along the way.
// `recruitmentTradeoffExplained` is different: its condition (posting a
// 2nd listing) is not RNG-gated, so asserting its dialog fires here is a
// real, deterministic "does this happen in the live UI" check, not a
// probabilistic one — kept as a hard assertion below. It also already has
// its own deterministic engine-level coverage (`beginner_mode_test.dart`'s
// "recruitment tradeoff guidance appears once a listing is posted
// post-assignment" test).
import { test, expect } from '@playwright/test';
import { playFoundingToFirstAssignment } from '../helpers/ses-player';
import { snapshotScreen, stableSnapshotScreen, hasText, enabledButton, extractInterviewCandidateName, findDoubledParticles, firstEnabledDialogButton, clickDialogCtaAndWaitForRoute, returnToHome, selectCurrentTab, type ScreenSnapshot } from '../helpers/game-state';
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
const RECRUITMENT_UNLOCK_MAX_ADVANCES = 6;

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
//
// A bare name match against this list is *not* enough on its own (Home
// layout整理 follow-up, PR #22 root cause): "採用を見る" is also
// `_HeroTaskCard`'s real, non-dialog Home CTA text. `settleAndScan`/
// `clickResilient` below always resolve a `CLOSE` match through
// `firstEnabledDialogButton` (game-state.ts), which additionally requires
// the match to be nested under a real `dialog`/`alertdialog` a11y node —
// `waitForTabBar` does the equivalent with a scoped locator instead (it
// deliberately avoids a full `snapshotScreen()` per iteration, see its own
// doc comment) — never against `CLOSE` directly.
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
    // A caller that is explicitly waiting for a result dialog must see that
    // current dialog before the generic live-dialog cleanup closes it.
    // This snapshot is intentionally reacquired at the start of every
    // iteration; it is never retained across a dialog action.
    if (stopWhen) {
      const current = await stableSnapshotScreen(page);
      textOffenders.push(...findDoubledParticles(current));
      if (stopWhen(current)) return current;
    }
    // WebKit can expose a newly-opened AlertDialog's content before its
    // ariaSnapshot indentation becomes dialog-scoped. Check the live dialog
    // container first, so a known modal always wins over normal-page state.
    const dialogScope = page.locator('[role="dialog"], [role="alertdialog"]');
    let dismissedLiveDialog = false;
    for (const label of CLOSE) {
      const button = dialogScope.getByRole('button', { name: label, exact: true }).first();
      if (await button.count()) {
        // This locator is created and used in this one synchronous branch
        // only. If the dialog disappears between the checks and click, that
        // is a successful external transition, not a stale-target retry.
        if (label === '採用を見る') {
          dismissedLiveDialog = await clickDialogCtaAndWaitForRoute(
            page,
            label,
            (state) => state.classification === 'rootStable' && state.selectedTab === '採用',
          ).catch(() => false);
        } else {
          dismissedLiveDialog = await clickDialogCtaAndWaitForRoute(page, label).catch(() => false);
        }
        break;
      }
    }
    if (dismissedLiveDialog) {
      continue;
    }
    const snap = await snapshotScreen(page);
    textOffenders.push(...findDoubledParticles(snap));
    if (stopWhen?.(snap)) return snap;
    const close = firstEnabledDialogButton(snap, CLOSE);
    if (!close) return null;
    // The live operation above owned every currently-present dialog CTA.
    // Do not replay a label whose dialog vanished between that operation and
    // this snapshot; it is an external transition, not a stale click target.
    if ((await page.locator('[role="dialog"], [role="alertdialog"]').count()) === 0) continue;
    // The name came from a dialog-scoped snapshot. Re-resolve it inside a
    // live dialog too: a global role lookup can otherwise pick a same-named
    // background CTA after Flutter has started dismissing this dialog.
    await clickDialogCtaAndWaitForRoute(page, close.name).catch(() => {});
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
  await clickResilient(page, byButton(page, nextBtn.name), nextBtn.name);
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
  // Same dialog-scoping requirement as `settleAndScan`/`clickResilient`
  // above (Home layout整理 follow-up, PR #22 root cause) — expressed as a
  // locator instead of a `firstEnabledDialogButton(snapshotScreen(...))`
  // call so this loop keeps its own cheap, no-full-snapshot cost profile
  // (see the comment below): `dialogScope.getByRole('button', {name, exact:
  // true})` only ever matches a CLOSE label when it's actually nested under
  // a real `dialog`/`alertdialog` a11y node (Flutter's `Dialog`/
  // `AlertDialog`, both `aria-modal`), never a same-labeled, unrelated
  // control elsewhere on screen (e.g. `_HeroTaskCard`'s own "採用を見る").
  const dialogScope = page.locator('[role="dialog"], [role="alertdialog"]');
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
      const btn = dialogScope.getByRole('button', { name: label, exact: true });
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

/** Clicks whatever [locate] resolves to, but — unlike a bare `.click()` —
 * never trusts that a target present when the caller decided to click it is
 * still there by the time the click actually lands (CI run 32027667292,
 * HEAD 13800f5: `clickAndWaitForChange`'s bare click timed out the full 15s
 * waiting for "面接する" on mobile-chromium's retry; CI run 32040338628,
 * HEAD f07fa30: the candidate-list click resolved, then "element was
 * detached from the DOM, retrying", then timed out — the exact same "戻る
 * race" shape already root-caused and fixed in `ses-player.ts`'s
 * `clickDecisionResilient`, recurring at different, previously-unhardened
 * click sites in this file's own hire-attempt loop).
 *
 * Every user-driven click in this file now goes through this single
 * mechanism (§ PR #15 CI investigation's click-site audit) instead of each
 * failure spawning its own one-off retry patch. [locate] is a *factory*,
 * not a held `Locator` — every attempt calls it again, which is what makes
 * a retry re-resolve against the DOM/semantics tree as it actually is right
 * now rather than replaying the same (possibly gone-for-good) reference;
 * this covers both a fixed exact-name button (`byButton('採用する')`) and a
 * dynamic-label target like the candidate list (`getByRole('button', {
 * name: /未面接/ }).first()`, where "first()" itself needs to be
 * re-evaluated against the current list on every retry, not just re-clicked
 * by the same stale selector).
 *
 * On a timeout, dismisses any currently-stacked known dialog (the same
 * [CLOSE] list `settleAndScan`/`waitForTabBar` already use) and retries —
 * total budget unchanged (15s split into 3s attempts), never a longer
 * timeout. */
async function clickResilient(page: import('@playwright/test').Page, locate: () => import('@playwright/test').Locator, label: string): Promise<void> {
  const deadline = Date.now() + CLICK_RESILIENT_TOTAL_MS;
  while (true) {
    const remaining = deadline - Date.now();
    const attemptTimeout = Math.max(500, Math.min(CLICK_RESILIENT_ATTEMPT_MS, remaining));
    try {
      await locate().click({ timeout: attemptTimeout });
      return;
    } catch (err) {
      if (Date.now() >= deadline) throw err;
      const snap = await snapshotScreen(page);
      const close = firstEnabledDialogButton(snap, CLOSE.filter((name) => name !== label));
      if (close) {
        // `close` is known to be in a dialog from the fresh snapshot. Keep
        // that scope at click time rather than broadening it to the entire
        // rebuilding screen.
        await byDialogButton(page, close.name)().click({ timeout: CLICK_RESILIENT_ATTEMPT_MS }).catch(() => {});
      }
      // Otherwise just loop straight back to a fresh `locate()` call — the
      // target may simply need another beat to (re)appear, or to be
      // re-resolved against a list that has since changed.
    }
  }
}

/** Locator factories for `clickResilient`'s two common shapes — a fixed
 * exact-name button, and a bottom-nav tab — so every call site shares the
 * same "re-query fresh each attempt" behavior without repeating the
 * `getByRole` boilerplate. */
const byButton = (page: import('@playwright/test').Page, name: string) => () => page.getByRole('button', { name, exact: true }).first();
const byTab = (page: import('@playwright/test').Page, name: string) => () => page.getByRole('tab', { name, exact: true });
const byDialogButton = (page: import('@playwright/test').Page, name: string) => () =>
  page.locator('[role="dialog"], [role="alertdialog"]').getByRole('button', { name, exact: true }).first();

/** Select a bottom tab and prove the newly rendered tab is current before
 * taking another snapshot. Flutter can expose the old tab's semantics for a
 * frame after the click, particularly in WebKit. */
async function selectTab(page: import('@playwright/test').Page, name: string): Promise<ScreenSnapshot> {
  return selectCurrentTab(page, name);
}

/** Returns a fresh, currently actionable candidate only after dialog
 * transitions have drained. The snapshot is used to establish that no modal
 * remains; the candidate locator is then acquired again from the live tree,
 * never retained from the pre-transition list. */
async function actionableUninterviewedCandidate(
  page: import('@playwright/test').Page,
  textOffenders: string[],
): Promise<import('@playwright/test').Locator | null> {
  await settleAndScan(page, textOffenders);
  const candidate = page.getByRole('button', { name: /未面接/ }).first();
  if ((await candidate.count()) === 0) return null;
  if (!(await candidate.isVisible()) || !(await candidate.isEnabled())) return null;
  return candidate;
}

function unlockDiagnostic(snap: ScreenSnapshot): string {
  const week = [...snap.texts, ...snap.buttons.map((b) => b.name)].find((text) => /week\s*\d+/i.test(text)) ?? 'week unknown';
  return `${week}; buttons=${JSON.stringify(snap.buttons)}; texts=${JSON.stringify(snap.texts)}`;
}

/** Drives the real Home loop until recruitment renders its real listing CTA.
 * A locked recruitment tab is a valid intermediate state, never a failure. */
async function waitForRecruitmentUnlock(
  page: import('@playwright/test').Page,
  textOffenders: string[],
): Promise<void> {
  for (let advanced = 0; advanced < RECRUITMENT_UNLOCK_MAX_ADVANCES; advanced++) {
    await settleAndScan(page, textOffenders);
    let snap = await stableSnapshotScreen(page);
    const postListing = page.getByRole('button', { name: '掲載する', exact: true }).first();
    if (await postListing.count() && await postListing.isVisible() && await postListing.isEnabled()) return;

    const next = snap.buttons.find((b) => b.enabled && b.name.startsWith('次の週へ'));
    if (!next) {
      const home = page.getByRole('tab', { name: 'ホーム', exact: true });
      if (await home.count()) snap = await selectTab(page, 'ホーム');
    }
    const currentNext = snap.buttons.find((b) => b.enabled && b.name.startsWith('次の週へ'));
    if (!currentNext) throw new Error(`recruitment remained locked with no legal week advance: ${unlockDiagnostic(snap)}`);
    await clickResilient(page, byButton(page, currentNext.name), currentNext.name);
    await settleAndScan(page, textOffenders);
    const recruitment = page.getByRole('tab', { name: '採用', exact: true });
    const after = await recruitment.count() ? await selectTab(page, '採用') : await stableSnapshotScreen(page);
    const listing = page.getByRole('button', { name: '掲載する', exact: true }).first();
    if (await listing.count() && await listing.isVisible() && await listing.isEnabled()) return;
    // The unlocked/locked decision is based on the current rendered state;
    // never reuse the pre-advance snapshot or locator next iteration.
    if (advanced === RECRUITMENT_UNLOCK_MAX_ADVANCES - 1) {
      throw new Error(`recruitment did not unlock after ${RECRUITMENT_UNLOCK_MAX_ADVANCES} legal advances: ${unlockDiagnostic(after)}`);
    }
  }
}

type CandidateEntryState = 'candidateList' | 'applicantDetailInterviewable' | 'applicantDetailNotActionable';

/** Resolves the real recruitment entry state. If invoked on the candidate
 * list it performs the one list action, waits for that route to commit, and
 * returns only the resulting state — never a Locator from either screen. */
async function openActionableCandidate(
  page: import('@playwright/test').Page,
  textOffenders: string[],
): Promise<CandidateEntryState> {
  await settleAndScan(page, textOffenders);
  const detailInterview = page.getByRole('button', { name: /面接(?:を再開)?する/ }).first();
  if (await detailInterview.count() && await detailInterview.isVisible() && await detailInterview.isEnabled()) {
    return 'applicantDetailInterviewable';
  }
  const candidate = await actionableUninterviewedCandidate(page, textOffenders);
  if (!candidate) return 'candidateList';
  await clickResilient(page, () => page.getByRole('button', { name: /未面接/ }).first(), '未面接候補者');
  await expect.poll(async () => {
    const interview = page.getByRole('button', { name: /面接(?:を再開)?する/ }).first();
    const back = page.getByRole('button', { name: /^Back\b/i }).first();
    return (await interview.count()) > 0 || (await back.count()) > 0;
  }, { timeout: 15_000, message: 'candidate selection did not reach Applicant Detail' }).toBe(true);
  const currentInterview = page.getByRole('button', { name: /面接(?:を再開)?する/ }).first();
  return (await currentInterview.count()) > 0 && await currentInterview.isVisible() && await currentInterview.isEnabled()
    ? 'applicantDetailInterviewable'
    : 'applicantDetailNotActionable';
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

/** True once the screen has actually arrived at `RecruitmentInterviewScreen`
 * — never satisfied by merely "some enabled button exists" (§ root cause
 * below). Two independent, structural signals, both required:
 *   - the *origin* screen's own CTA (ApplicantDetailScreen's "面接する" or,
 *     for a resumed session, "面接を再開する" — see the hire-attempt loop's
 *     own doc comment) is no longer present/enabled — proves we left that
 *     screen;
 *   - the destination screen's own identity is present:
 *     `RecruitmentInterviewScreen`'s AppBar title is literally
 *     "${applicant.name}との面接" (`extractInterviewCandidateName`, already
 *     used by `ses-player.ts` for the same purpose), which only mounts on
 *     that screen.
 * Neither alone is reliable: the origin CTA disappearing doesn't prove the
 * destination is the interview screen and not some other transitional/
 * empty frame; the title alone could theoretically survive a stale read. */
function isInterviewScreenReady(snap: ScreenSnapshot): boolean {
  const stillOnApplicantDetail = snap.buttons.some((b) => b.enabled && (b.name === '面接する' || b.name === '面接を再開する'));
  if (stillOnApplicantDetail) return false;
  return extractInterviewCandidateName(snap) !== null;
}

/** Waits specifically for `RecruitmentInterviewScreen` to have actually
 * mounted after clicking "面接する" — root-caused from PR #15 CI run
 * 32029449859's mobile-webkit failure: the interview Q&A loop's very first
 * iteration re-clicked "面接する" itself (via `clickAndWaitForChange`,
 * called with `anyBtn.name === '面接する'`), because the *previous* wait
 * here was the generic `waitForAnyEnabledButton` — which is satisfied the
 * instant `snapshotScreen` sees *any* enabled button, and the pre-click
 * `ApplicantDetailScreen` already has one ("面接する" itself). That wait
 * never actually confirmed a screen change, so under contention it could
 * return on the still-stale pre-click frame, sending the Q&A loop straight
 * back into the same button it just clicked instead of the first real
 * interview question. `waitForAnyEnabledButton` itself is unchanged (and
 * still correct) for its other, screen-agnostic call site above (after the
 * candidate click, before it's known whether an interview even needs
 * starting) — this is a *replacement* only at the one call site where the
 * destination screen's identity is actually known in advance. */
async function waitForInterviewScreenTransition(page: import('@playwright/test').Page): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  // Same ~30s order of magnitude as `waitForTabBar`/`waitForAnyEnabledButton`
  // (see their own doc comments for the CPU-throttling reproduction this is
  // sized against) — a route transition is the same class of CPU-bound work.
  for (let i = 0; i < 40 && !isInterviewScreenReady(snap); i++) {
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
  await clickResilient(page, byButton(page, buttonName), buttonName);
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
  test(`Phase 3A: recruitment flow stays operable in real UI, no dead-end (seed ${seed})`, async ({ page }, testInfo) => {
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
    await clickResilient(page, byButton(page, '経営を始める'), '経営を始める').catch(() => {});
    await returnToHome(page);
    await settleAndScan(page, textOffenders);

    // The tab may legitimately be locked for the first two post-assignment
    // weeks. Advance from the current Home state until its real listing CTA
    // exists; every iteration re-reads the rendered UI after the week move.
    await waitForRecruitmentUnlock(page, textOffenders);
    await captureMilestone(page, testInfo, '01-recruitment-unlocked');

    // --- recruitmentTradeoffExplained -------------------------------
    // Post a second listing (Free Work, ¥0 — always affordable) — a real
    // post-founding *growth* decision, not the March founding hire itself.
    await clickResilient(page, byButton(page, '掲載する'), '掲載する');
    await page.waitForTimeout(600);
    const after = await snapshotScreen(page);
    // Confirms the click actually posted (not a silent no-op) before
    // trusting the milestone assertion below to mean anything.
    expect(after.buttons.some((b) => b.name.startsWith('掲載中')), 'second listing did not actually post').toBe(true);

    await selectTab(page, 'ホーム');
    const tradeoffDialog = await advanceWeekAndFind(page, textOffenders, (snap) => hasText(snap, '採用のトレードオフ'));
    expect(tradeoffDialog, `採用のトレードオフ dialog never appeared after posting a second listing (seed=${seed})`).not.toBeNull();
    expect(hasText(tradeoffDialog!, '固定支出')).toBe(true);
    await captureMilestone(page, testInfo, '02-recruitment-tradeoff-dialog');
    await settleAndScan(page, textOffenders);

    // --- recruitment flow operability (not a waiting-cost guarantee) ---
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
    // (`RecruitmentEngine.rollAcceptance` is a real per-seed roll) is never
    // read back or asserted on here at all (§ this file's own top-of-file
    // responsibility-split comment) — every assertion below the loop is
    // about the *flow itself* staying operable, regardless of any
    // individual roll's outcome.
    expect(await waitForTabBar(page, textOffenders, '採用'), '採用 tab never became visible before the first hire attempt').toBe(true);
    await selectTab(page, '採用');

    // A handful of candidates in a row is enough to prove the interview ->
    // decision -> back-to-recruitment-tab cycle is genuinely repeatable
    // under real timing, without needing enough independent attempts to
    // beat down the odds of a probabilistic outcome — this file no longer
    // has a probabilistic outcome to beat down (see the responsibility-
    // split comment above), so there is no statistical reason for this to
    // be large. Kept well below the old value (9, sized for RNG margin that
    // no longer applies here) to keep this real-UI integration check fast,
    // per the same investigation's "長時間E2Eの責務を縮小" follow-up.
    const HIRE_ATTEMPTS = 3;
    for (let attempt = 0; attempt < HIRE_ATTEMPTS; attempt++) {
      const entryState = await openActionableCandidate(page, textOffenders);
      if (entryState === 'candidateList') break;
      if (entryState === 'applicantDetailNotActionable') {
        expect(await waitForTabBar(page, textOffenders, '採用'), `採用 tab never became visible after non-actionable detail ${attempt} (seed=${seed})`).toBe(true);
        continue;
      }
      // CI run 32040338628, HEAD f07fa30: this exact locator resolved, then
      // "element was detached from the DOM, retrying", then timed out — the
      // candidate list re-rendering out from under a plain `.click()`.
      // The entry helper above has confirmed that the current route is
      // Applicant Detail. Reacquire only that route's interview CTA below;
      // never re-assume the old candidate-list button still exists.
      // `ApplicantDetailScreen` (lib/ui/recruitment/applicant_detail_screen.dart
      // `_LockedPersonalityCard`) renders its interview-entry CTA as "面接する"
      // when no session exists yet, but as "面接を再開する" once one has
      // already been *started but not completed* — a real, legitimate,
      // clickable action, not "nothing to click". The previous version of
      // this check only ever matched "面接する" exactly, so a resumed
      // interview was silently misclassified as the dead-end case below and
      // abandoned instead of continued — a real E2E-harness gap, verified
      // directly against the widget's own source, not inferred from the CI
      // failure alone.
      const snapAfterOpen = await waitForAnyEnabledButton(page);
      const interviewBtn = enabledButton(snapAfterOpen, '面接する') ?? enabledButton(snapAfterOpen, '面接を再開する');
      if (!interviewBtn) {
        // Genuinely nothing to interview here — the only other state
        // `ApplicantDetailScreen` can render is "already interviewed"
        // (session completed, decision already recorded elsewhere), which
        // shows a static "面接済み" card with **no button at all** — or the
        // applicant no longer exists in `state.applicants` at all (already
        // hired/rejected), in which case the screen pops *itself* via its
        // own `postFrameCallback` without any input from us.
        //
        // The previous version of this branch additionally fired a manual,
        // single-shot `/^Back\b/i` click here before calling
        // `waitForTabBar` — but `waitForTabBar` (below) already retries
        // that exact same click internally, every idle iteration, for its
        // entire ~30s budget (see its own doc comment). That manual click
        // added no capability the retry loop didn't already have, and
        // being a single unguarded attempt outside any retry, risked
        // racing whatever the screen was already doing on its own (e.g.
        // its own auto-pop) instead of helping it along — removed rather
        // than patched further, since the fix here is recognizing
        // `waitForTabBar` already owns this recovery, not adding a second,
        // less careful copy of it.
        expect(await waitForTabBar(page, textOffenders, '採用'), `採用 tab never became visible after skipping attempt ${attempt} (seed=${seed})`).toBe(true);
        continue;
      }
      await clickResilient(page, byButton(page, interviewBtn.name), interviewBtn.name);
      await waitForInterviewScreenTransition(page);

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
          await clickResilient(page, byButton(page, '採用する'), '採用する');
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

    // A few weeks of clean, dead-end-free advancement after the hire
    // attempts — proving "次の週へ" keeps working, whatever dialog it
    // legitimately produces gets handled, and nothing left over from the
    // interview loop wedges the game. Deliberately does *not* hunt for
    // `waitingCostExplained`'s dialog text (`stopWhen: () => false`, same
    // shape as the recruitment-unlock loop above): whether any of the
    // `HIRE_ATTEMPTS` offers was actually accepted is a real per-seed
    // `RecruitmentEngine.rollAcceptance` roll this file has no business
    // depending on (§ top-of-file responsibility-split comment) —
    // `test/game/beginner_mode_test.dart`'s Test E2 and
    // `test/ui/beginner_mode_widget_test.dart` already prove
    // deterministically, in seconds, that the milestone and its dialog both
    // fire correctly once the right GameState facts hold, so this long-
    // running E2E has no remaining reason to search for that specific text.
    await returnToHome(page);
    for (let i = 0; i < 3; i++) {
      await advanceWeekAndFind(page, textOffenders, () => false);
    }
    await settleAndScan(page, textOffenders);

    expect(errors.pageErrors, `uncaught page errors (seed=${seed})`).toEqual([]);
    expect(errors.crashed, `page crashed (seed=${seed})`).toBe(false);
    expect(errors.consoleErrors, `unallowlisted console.error (seed=${seed})`).toEqual([]);
    expect(textOffenders, `doubled-particle text observed (seed=${seed}): ${JSON.stringify(textOffenders)}`).toEqual([]);
  });
}
