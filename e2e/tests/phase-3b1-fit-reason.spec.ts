// Phase 3B-1 (S.E.S. Development Plan §3.3, "案件を選ぶ"): real-UI E2E
// coverage for "Fitの理由を見る" — the FitReasonSheet PR #18 added to
// EngineerDetailScreen's 営業状況/参画オファー比較・回答 cards.
//
// Reuses the existing Founding/Beginner Mode drivers unchanged
// (helpers/ses-player.ts, helpers/beginner-mode-player.ts) through Week 13,
// then drives the *real* production UI by hand from there: opens the
// engineer's own detail screen, starts a second, parallel sales search for
// their already-assigned engineer (a real, always-legal "並行営業" action —
// GameEngine.startSales has no guard against an already-`assigned` engineer,
// only against one already `selling`/`interviewing`), waits for a real
// interview offer, accepts it, and opens the resulting FitBadge's "Fitの理由
// を見る" sheet — never a shortcut/debug API, exactly like every other
// driver in this harness (see README.md "Why no debug API").
//
// Determinism: every RNG draw this scenario touches
// (ProjectInterviewEngine.roll for the interview-offer roll, MatchingEngine
// itself) is a pure function of (state.seed, state.week, salt) — see
// project_interview_engine.dart's own doc comment — so under a fixed seed
// and this file's fixed action sequence, the same interview offer (same
// project, same Fit) appears at the same week every run. Verified directly
// against real Chromium during development, not assumed: seed 100001
// reaches a QA体制強化支援 offer exactly 2 week-advances after starting the
// second sales search at Week 13. `MAX_WEEKS_TO_WAIT_FOR_OFFER` below still
// gives real margin (5x) past that observed timing — a bounded, ordinary
// weekly-progression loop (same shape as every other spec's week-advance
// loop), not a retry-driven flakiness workaround.
//
// No RNG-dependent *outcome* is ever a pass/fail condition here (§ this
// PR's brief): whether the client interview this offer leads into ends up
// passing or failing is never inspected — this file only proves the FitBadge
// state is reachable, FitReasonSheet renders the right structure, and the
// game stays legally continuable once it's dismissed. `社員に任せる` (client-
// interview auto-resolve) is clicked once during the post-close continuation
// check purely to clear the pending action and prove "次の週へ" keeps
// working afterwards — its pass/fail result is never read or asserted on.
//
// The one production change this scenario needed (documented in
// engineer_detail_screen.dart's own `_FitReasonLink` doc comment): a real,
// pre-existing accessibility gap, not an E2E-only shortcut. A bare
// `InkWell` only carries a tap *action*, not the `isButton` flag a real
// `Button` widget sets, so Flutter's semantics compiler was merging
// "Fitの理由を見る" into the surrounding card's own combined text —
// invisible to screen readers *and* to role-based automation, for the
// exact same reason.
// `Semantics(container: true, button: true, label: ..., onTap: ...)` gives
// it its own accessibility node, matching how the card's real `面談をプレイ`/
// `社員に任せる` buttons already behave — zero visual or behavioral change,
// no FitReasonSheet content/spec touched, no MatchingEngine/game-logic
// touched.
import { test, expect } from '@playwright/test';
import { playFoundingToFirstAssignment } from '../helpers/ses-player';
import { playBeginnerModeThroughJune } from '../helpers/beginner-mode-player';
import { snapshotScreen, hasText, findDoubledParticles, firstEnabledDialogButton, type ScreenSnapshot } from '../helpers/game-state';
import { watchForErrors, captureMilestone, writeArtifacts, buildResultJson, drainWheelDiagnostics, assertScrollWasEffective } from '../helpers/artifacts';
import { parseSeeds } from '../helpers/seeds';
import fs from 'fs';
import path from 'path';

// Deterministic under a fixed seed (see the file-level doc comment above) —
// a single seed is enough to prove the real flow/UI structure; override with
// SES_E2E_FIT_REASON_SEEDS for a wider batch.
const DEFAULT_SEEDS = [100001];
const parsedSeeds = parseSeeds(process.env.SES_E2E_FIT_REASON_SEEDS, DEFAULT_SEEDS);

const FOUNDING_MAX_WEEKS = 12;
const FOUNDING_MAX_ACTIONS = 100;
const IDLE_TIMEOUT_MS = 30_000;
const STALL_REPEAT_THRESHOLD = 5;
const BEGINNER_TARGET_WEEK = 12;
const BEGINNER_MAX_ACTIONS = 200;

// Bounded ordinary week-advance loop, not a retry mechanism — see the
// file-level doc comment's determinism note (observed: 2 weeks for seed
// 100001, this gives 5x margin).
const MAX_WEEKS_TO_WAIT_FOR_OFFER = 10;

const EMPLOYEES_TAB = '社員';
const HOME_TAB = 'ホーム';
const START_SALES = '営業を開始する';
const CONFIRM_START_SALES = '営業開始';
const NEXT_WEEK_PREFIX = '次の週へ';
const PROCEED_TO_INTERVIEW = '面談へ進む';
const FIT_REASON_LINK = 'Fitの理由を見る';
const AUTO_RESOLVE_CLIENT_INTERVIEW = '社員に任せる';

// Dialogs whose dismiss button is always safe to tap without losing
// anything under test — same list every other Phase 3A/3B E2E driver in
// this harness already uses (beginner-mode-player.ts,
// beginner-mode-waiting-and-recruitment.spec.ts).
//
// A bare name match against this list is *not* enough on its own (Home
// layout整理 follow-up, PR #22 root cause): "採用を見る" is also
// `_HeroTaskCard`'s real, non-dialog Home CTA text, and this exact list —
// matched against every enabled button on screen with no further scoping —
// is what clicked it, sending a real playthrough off to the 採用 tab mid
// week-advance loop instead of recognizing it had nothing to actually
// dismiss. Every lookup below goes through `firstEnabledDialogButton`,
// which additionally requires the match to be nested under a real
// `dialog`/`alertdialog` a11y node (see `dialogButtonNames` in
// game-state.ts) — never against `CLOSE` directly.
const CLOSE = ['閉じる', 'OK', '会社状況を見る', '面談依頼を見る', '採用を見る', '社員環境を見る', 'それでも進む', '技術者に任せて進む'];

// --- clickResilient + friends -------------------------------------------
// Deliberately the *same* implementation as
// beginner-mode-waiting-and-recruitment.spec.ts's own clickResilient (not a
// new invention) — kept as a local copy rather than an import for the same
// reason that file's own doc comment implies: this spec must not carry that
// file's own known-flaky-test follow-up work, and importing from a sibling
// *.spec.ts file would couple the two in a way neither this PR nor that
// one's own history calls for. helpers/ses-player.ts's
// clickDecisionResilient is the analogous primitive for the founding driver
// itself — this is that same "re-resolve fresh on every retry, dismiss a
// known dialog on timeout" shape, just for this file's own hand-driven
// steps once the founding/beginner drivers hand off.
const CLICK_RESILIENT_TOTAL_MS = 15_000;
const CLICK_RESILIENT_ATTEMPT_MS = 3_000;

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
        await page.getByRole('button', { name: close.name, exact: true }).click().catch(() => {});
        await page.waitForTimeout(300);
      }
    }
  }
}

const byButton = (page: import('@playwright/test').Page, name: string) => () => page.getByRole('button', { name, exact: true }).first();
const byTab = (page: import('@playwright/test').Page, name: string) => () => page.getByRole('tab', { name, exact: true });

/** Dismisses every dialog currently stacked on screen, recording each one's
 * text for the doubled-particle scan — same shape as
 * beginner-mode-waiting-and-recruitment.spec.ts's own settleAndScan. */
async function settleAndScan(page: import('@playwright/test').Page, textOffenders: string[], observed?: string[]): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  for (let i = 0; i < 10; i++) {
    textOffenders.push(...findDoubledParticles(snap));
    // SES_WEBKIT-SCROLL-1 Phase 1 (observation only, no control-flow
    // change): Home's own next-week handler lists *every* Critical task in
    // a 「重要事項が残っています」 dialog before it will advance
    // (home_screen.dart `_handleNextWeek`) — deliberately exhaustive, not
    // the top-N summary the hero card shows. That makes this the one place
    // a pending 面談依頼 can never be ranked out of view, so whatever this
    // dismisses is worth recording before it disappears.
    if (observed) observed.push(...snap.texts, ...snap.buttons.map((b) => b.name));
    const close = firstEnabledDialogButton(snap, CLOSE);
    if (!close) return snap;
    await clickResilient(page, byButton(page, close.name), close.name);
    await page.waitForTimeout(400);
    snap = await snapshotScreen(page);
  }
  return snap;
}

/** 社員画面 Phase 2 (レイアウト改修) added a top すべて/参画中/待機中 filter row
 * above the roster — each chip is itself a real, enabled a11y `button`
 * ("すべて N", "参画中 N", "待機中 N"), so it now sits ahead of the real
 * engineer card in a plain "first enabled button" scan. Excluded by prefix,
 * the same way `!b.name.startsWith('経営状況')` already excludes the
 * ManagementHud button below. */
const FILTER_CHIP_PREFIXES = ['すべて ', '参画中 ', '待機中 '];

/** The one (Beginner Mode never hires a second engineer by Week 13) real
 * engineer card on the 社員 tab — matched by "not the ManagementHud button
 * / not a filter chip" the same way every other driver in this harness
 * distinguishes it (its own label is a dynamic "${name} ${status} ¥{salary}
 * ... (残N週)" string that changes week to week, so it's never matched by a
 * fixed name). */
function findEngineerCard(snap: ScreenSnapshot) {
  return snap.buttons.find(
    (b) => b.enabled && !b.name.startsWith('経営状況') && !FILTER_CHIP_PREFIXES.some((p) => b.name.startsWith(p)),
  );
}

async function openEngineerDetail(page: import('@playwright/test').Page): Promise<ScreenSnapshot> {
  await clickResilient(page, byTab(page, EMPLOYEES_TAB), '社員タブ');
  await page.waitForTimeout(500);
  const snap = await snapshotScreen(page);
  const card = findEngineerCard(snap);
  expect(card, `no engineer card on 社員 tab`).toBeTruthy();
  await clickResilient(page, byButton(page, card!.name), card!.name);
  await page.waitForTimeout(500);
  return snapshotScreen(page);
}

// --- SES_WEBKIT-SCROLL-1 Phase 1 diagnostics ----------------------------
// Everything below is *observation only*: it adds no wait, no retry, no
// gameplay action and no assertion. Its whole job is to put the evidence a
// root-cause classification needs into the CI **job log**, so nobody has to
// download the 300 MB+ Playwright results artifact to answer "was the CTA
// there?". Every value printed is read from the same real-UI accessibility
// snapshot the test itself acts on — never from a debug/GameState bridge
// (see e2e/README.md "Why no debug API").

/** Anything a pending 面談依頼 puts on screen. `TaskEngine.generateTasks`
 * adds a *critical* Home task titled "{name}さんに面談依頼があります" for every
 * `InterviewOfferStatus.pending` offer, ungated by the employee's workflow
 * state (lib/game/engine/task_engine.dart) — so Home tells us whether the
 * offer exists in game state even while the employee reads as 参画中 and the
 * engineer-detail 面談依頼 card sits below the fold. That difference is
 * exactly what separates "generated but not materialized into semantics"
 * from "never generated". */
const OFFER_MARKER_RE = /面談依頼/;

interface ScrollDiagnostics {
  steps: number;
  everChanged: boolean;
  fingerprintChanges: number;
  foundAtStep: number | null;
  exitReason: 'found' | 'stable' | 'maxSteps';
  wheelInvocations: number;
  wheelMoved: number;
  wheelStrategies: Record<string, number>;
  fltSemanticsTotal: number | null;
  fltSemanticsScrollable: number | null;
  fltSemanticsOverflowY: Record<string, number> | null;
}

interface WeekDiagnostics {
  iteration: number;
  weekOnHome: number | null;
  nextWeekButton: string | null;
  homeOfferMarkers: string[];
  /** Offer markers seen by `settleAndScan` while dismissing whatever the
   * week advance put on screen — including Home's exhaustive Critical-task
   * dialog. Independent of how the hero card ranks tasks. */
  settleOfferMarkers: string[];
  detailOfferMarkersBeforeScroll: string[];
  detailCtaBeforeScroll: boolean;
  detailButtonsBeforeScroll: number;
  detailTextsBeforeScroll: number;
  detailOfferMarkersAfterScroll: string[];
  detailCtaAfterScroll: boolean;
  detailButtonsAfterScroll: number;
  detailTextsAfterScroll: number;
  scroll: ScrollDiagnostics;
}

const WEEK_RE = /week\s*(\d+)/i;

/** ManagementHud renders its whole row as one semantics *button*, so the
 * week number can live in `buttons` as well as `texts` — same scan
 * beginner-mode-player.ts's own `currentWeek` already uses. */
function readWeek(snap: ScreenSnapshot): number | null {
  for (const t of [...snap.texts, ...snap.buttons.map((b) => b.name)]) {
    const m = WEEK_RE.exec(t);
    if (m) return Number(m[1]);
  }
  return null;
}

function offerMarkers(snap: ScreenSnapshot): string[] {
  return [...snap.texts, ...snap.buttons.map((b) => b.name)].filter((t) => OFFER_MARKER_RE.test(t));
}

function hasCta(snap: ScreenSnapshot): boolean {
  return snap.buttons.some((b) => b.enabled && b.name === PROCEED_TO_INTERVIEW);
}

/** The harness's complete view of one screen — exactly what every locator,
 * `expect` and actionability check in this file can see. Printed verbatim
 * (bounded) so the log alone shows whether a widget was materialized. */
function dumpSnapshot(label: string, snap: ScreenSnapshot): void {
  console.log(`[SES-DIAG] ---- ${label}: ${snap.texts.length} texts, ${snap.buttons.length} buttons ----`);
  for (const t of snap.texts) console.log(`[SES-DIAG]   text   | ${t.replace(/\n/g, ' \\n ')}`);
  for (const b of snap.buttons) console.log(`[SES-DIAG]   button | ${b.enabled ? 'enabled ' : 'disabled'} | ${b.name.replace(/\n/g, ' \\n ')}`);
  console.log(`[SES-DIAG] ---- end ${label} ----`);
}

/** Scrolls the current screen's `ListView` down (bounded, polling for the
 * target rather than a fixed scroll amount) until [buttonName] shows up
 * among the enabled buttons, or the list stops changing (genuinely not
 * there / already at the bottom). EngineerDetailScreen renders 営業状況
 * (and its "Fitの理由を見る") well below the fold — Flutter Web's
 * `SliverList` only materializes semantics for children within/near the
 * current viewport, so a fresh route mount never has it in the
 * accessibility tree until scrolled into view, confirmed directly against
 * the real ariaSnapshot() output during development (the section was
 * completely absent, not just unscrolled-to, until this). Mouse wheel
 * events, not a Playwright `scrollIntoView` call — there's no DOM element
 * to target one at until this scroll makes it exist. */
async function scrollUntilButtonFound(page: import('@playwright/test').Page, buttonName: string, maxSteps = 15, diag?: ScrollDiagnostics): Promise<ScreenSnapshot> {
  // `page.mouse.wheel` scrolls whatever is under the *current* virtual mouse
  // position — which, right after a `.click()` on the previous screen,
  // still sits wherever that click landed (a different route entirely).
  // Re-center it over this screen's own body first so the wheel events
  // reliably land on this screen's `ListView`, not wherever the last click
  // happened to be.
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  await page.waitForTimeout(200);
  // Phase 1 diagnosis: isolate this call's wheel records from any earlier
  // ones. Draining is a no-op on Chromium, which never enters the fallback.
  if (diag) drainWheelDiagnostics(page);
  let snap = await snapshotScreen(page);
  let everChanged = false;
  let stableStreak = 0;
  let lastFingerprint = JSON.stringify(snap.texts);
  for (let i = 0; i < maxSteps; i++) {
    if (snap.buttons.some((b) => b.enabled && b.name === buttonName)) {
      if (diag) {
        diag.steps = i;
        diag.foundAtStep = i;
        diag.exitReason = 'found';
      }
      return snap;
    }
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(300);
    snap = await snapshotScreen(page);
    if (diag) diag.steps = i + 1;
    const fingerprint = JSON.stringify(snap.texts);
    if (fingerprint === lastFingerprint) {
      stableStreak++;
      // Never give up on the very first unchanged read (a transient
      // SnackBar dismissing, or the very first wheel event landing before
      // Flutter's Scrollable is fully ready to receive it, can both leave
      // an early read identical without the list actually being stuck) —
      // only once real scrolling has been observed at least once *and*
      // then stalls for a few reads in a row is this the bottom.
      if (everChanged && stableStreak >= 3) {
        if (diag) diag.exitReason = 'stable';
        break;
      }
    } else {
      everChanged = true;
      stableStreak = 0;
      if (diag) diag.fingerprintChanges++;
    }
    lastFingerprint = fingerprint;
  }
  if (diag) {
    diag.everChanged = everChanged;
    const wheel = drainWheelDiagnostics(page);
    diag.wheelInvocations = wheel.length;
    diag.wheelMoved = wheel.filter((w) => w.moved).length;
    for (const w of wheel) {
      const key = w.movedBy ?? 'none';
      diag.wheelStrategies[key] = (diag.wheelStrategies[key] ?? 0) + 1;
    }
    const last = wheel[wheel.length - 1];
    if (last) {
      diag.fltSemanticsTotal = last.fltSemanticsTotal;
      diag.fltSemanticsScrollable = last.fltSemanticsScrollable;
      diag.fltSemanticsOverflowY = last.fltSemanticsOverflowY;
    }
    // A scroll that provably moved nothing must never be reported as "the
    // button isn't there" — that conflation is what hid this defect for two
    // PRs. Strengthens the failure, never weakens one: it can only turn a
    // misleading pass/failure message into an accurate one.
    assertScrollWasEffective(
      { steps: diag.steps, fingerprintChanged: everChanged, wheelInvocations: diag.wheelInvocations, wheelMoved: diag.wheelMoved },
      `scrolling to "${buttonName}"`,
    );
  }
  return snap;
}

function newScrollDiagnostics(): ScrollDiagnostics {
  return {
    steps: 0,
    everChanged: false,
    fingerprintChanges: 0,
    foundAtStep: null,
    exitReason: 'maxSteps',
    wheelInvocations: 0,
    wheelMoved: 0,
    wheelStrategies: {},
    fltSemanticsTotal: null,
    fltSemanticsScrollable: null,
    fltSemanticsOverflowY: null,
  };
}

const FIT_SYMBOL = '[◎○△×]';
const OVERALL_FIT_RE = new RegExp(`総合Fit\\s*(${FIT_SYMBOL})\\s*(かなり有力|有力|微妙|厳しい)`);
const BREAKDOWN_RE = (label: string) => new RegExp(`${label}\\s*(${FIT_SYMBOL})\\s*(かなり有力|有力|微妙|厳しい)`);
const BULLET_RE = /・[^・]+?:\s*[◎○△×]\s*(?:かなり有力|有力|微妙|厳しい)/g;

for (const seed of parsedSeeds.error ? [] : parsedSeeds.seeds) {
  test(`Phase 3B-1: Fitの理由を見る is reachable and correct in real UI (seed ${seed})`, async ({ page }, testInfo) => {
    test.setTimeout(7 * 60 * 1000);
    const errors = watchForErrors(page);
    const startedAt = Date.now();
    const textOffenders: string[] = [];
    const seenMilestones = new Set<string>();
    const capture = async (name: string) => {
      if (seenMilestones.has(name)) return;
      seenMilestones.add(name);
      await captureMilestone(page, testInfo, name);
    };

    await page.goto(`/?e2e=1&seed=${seed}`);

    // Phase 1: 会社設立 -> 採用 -> 初案件参画 -> 4月-6月 (Week 13). Reuses the
    // same, already-validated drivers every other Phase 3A/3B spec uses —
    // this file never reimplements Founding/Beginner Mode navigation.
    const founding = await playFoundingToFirstAssignment(page, {
      maxWeeks: FOUNDING_MAX_WEEKS,
      maxActions: FOUNDING_MAX_ACTIONS,
      idleTimeoutMs: IDLE_TIMEOUT_MS,
      stallRepeatThreshold: STALL_REPEAT_THRESHOLD,
    });
    await capture('01-first-assignment');
    expect(founding.stallDetected, `founding dead-end/stall (seed=${seed}): ${founding.stallReason}`).toBe(false);
    expect(founding.completed, `did not reach first assignment (seed=${seed})`).toBe(true);

    const beginner = await playBeginnerModeThroughJune(page, {
      targetWeek: BEGINNER_TARGET_WEEK,
      maxActions: BEGINNER_MAX_ACTIONS,
      idleTimeoutMs: IDLE_TIMEOUT_MS,
    });
    await capture('02-week13');
    expect(beginner.stallDetected, `Beginner Mode dead-end/stall (seed=${seed}): ${beginner.stallReason}`).toBe(false);
    expect(beginner.completed, `did not reach Week ${BEGINNER_TARGET_WEEK} (seed=${seed})`).toBe(true);

    // Phase 2: real UI from here — open the engineer's own detail screen
    // (実際に到達可能な導線: 社員 tab -> the one engineer's card) and start a
    // second, parallel sales search (並行営業, engineer_detail_screen.dart's
    // own "並行営業 N / 3" label) for their next project. A real, always-
    // legal player action while already assigned — GameEngine.startSales
    // only refuses an engineer already `selling`/`interviewing`.
    let snap = await openEngineerDetail(page);
    await capture('03-engineer-detail-before-sales');
    const startSalesBtn = snap.buttons.find((b) => b.enabled && b.name === START_SALES);
    expect(startSalesBtn, `${START_SALES} not available on the engineer's detail screen (seed=${seed})`).toBeTruthy();
    await clickResilient(page, byButton(page, START_SALES), START_SALES);
    await page.waitForTimeout(400);
    await clickResilient(page, byButton(page, CONFIRM_START_SALES), CONFIRM_START_SALES);
    await page.waitForTimeout(400);

    // Back to the tab bar, then Home to advance weeks — mirrors every other
    // driver's own "面談を待ちましょう。次の週へ進めると..." rhythm.
    await clickResilient(page, () => page.getByRole('button', { name: /^Back/i }).first(), 'Back').catch(() => {});
    await page.waitForTimeout(400);
    await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ');
    await page.waitForTimeout(400);

    // Wait (bounded, ordinary weekly progression — see file-level doc
    // comment) for the interview offer this parallel sales search produces,
    // then accept it via the engineer's own 面談依頼 card — never a debug
    // shortcut, the same "断る"/"面談へ進む" card a real player sees.
    let offerAccepted = false;
    let weeksWaited = 0;
    // Phase 1 diagnosis only — collected, printed, never asserted on.
    const weekDiagnostics: WeekDiagnostics[] = [];
    let loopExitReason = 'maxWeeks';
    let offerEvidenceDumped = false;
    // A `for (...; weeksWaited++)` here undercounts by one: `break` on the
    // iteration that finds the offer skips the increment clause entirely,
    // so a genuine 2-week wait was reported as 1 (and an offer found on the
    // very first advance as 0) in fit-reason-result.json. Incrementing
    // explicitly right after the week actually advances — independent of
    // whether *this same* iteration goes on to find the offer — keeps the
    // reported count accurate regardless of where the loop breaks.
    while (weeksWaited < MAX_WEEKS_TO_WAIT_FOR_OFFER && !offerAccepted) {
      await settleAndScan(page, textOffenders);
      snap = await snapshotScreen(page);
      const next = snap.buttons.find((b) => b.enabled && b.name.startsWith(NEXT_WEEK_PREFIX));
      // Home, before this iteration's week advance: `TaskEngine`'s critical
      // 面談依頼 task shows up here whenever the offer exists in GameState.
      const homeSnap = snap;
      const settleObserved: string[] = [];
      if (next) {
        await clickResilient(page, byButton(page, next.name), next.name);
        await page.waitForTimeout(700);
        weeksWaited++;
      }
      await settleAndScan(page, textOffenders, settleObserved);

      snap = await openEngineerDetail(page);
      const beforeScroll = snap;
      const scrollDiag = newScrollDiagnostics();
      snap = await scrollUntilButtonFound(page, PROCEED_TO_INTERVIEW, 15, scrollDiag);
      const week: WeekDiagnostics = {
        iteration: weekDiagnostics.length + 1,
        weekOnHome: readWeek(homeSnap),
        nextWeekButton: next?.name ?? null,
        homeOfferMarkers: offerMarkers(homeSnap),
        settleOfferMarkers: [...new Set(settleObserved.filter((t) => OFFER_MARKER_RE.test(t)))],
        detailOfferMarkersBeforeScroll: offerMarkers(beforeScroll),
        detailCtaBeforeScroll: hasCta(beforeScroll),
        detailButtonsBeforeScroll: beforeScroll.buttons.length,
        detailTextsBeforeScroll: beforeScroll.texts.length,
        detailOfferMarkersAfterScroll: offerMarkers(snap),
        detailCtaAfterScroll: hasCta(snap),
        detailButtonsAfterScroll: snap.buttons.length,
        detailTextsAfterScroll: snap.texts.length,
        scroll: scrollDiag,
      };
      weekDiagnostics.push(week);
      console.log(`[SES-DIAG] week#${week.iteration} homeWeek=${week.weekOnHome} weeksWaited=${weeksWaited} ` +
        `homeOffer=${week.homeOfferMarkers.length > 0} settleOffer=${week.settleOfferMarkers.length > 0} ` +
        `detailOfferText=${week.detailOfferMarkersBeforeScroll.length > 0} ` +
        `cta(before/after)=${week.detailCtaBeforeScroll}/${week.detailCtaAfterScroll} ` +
        `detailButtons=${week.detailButtonsBeforeScroll}->${week.detailButtonsAfterScroll} ` +
        `scroll{steps=${scrollDiag.steps} everChanged=${scrollDiag.everChanged} changes=${scrollDiag.fingerprintChanges} ` +
        `exit=${scrollDiag.exitReason} wheel=${scrollDiag.wheelInvocations} wheelMoved=${scrollDiag.wheelMoved} ` +
        `strategies=${JSON.stringify(scrollDiag.wheelStrategies)} fltSemantics=${scrollDiag.fltSemanticsTotal}` +
        `/${scrollDiag.fltSemanticsScrollable} overflowY=${JSON.stringify(scrollDiag.fltSemanticsOverflowY)}}`);
      // The decisive dump, emitted at most once: the first week Home says an
      // offer exists. Home and the engineer detail screen side by side is
      // what separates "exists but unmaterialized" from "never generated".
      if (!offerEvidenceDumped && (week.homeOfferMarkers.length > 0 || week.settleOfferMarkers.length > 0)) {
        offerEvidenceDumped = true;
        console.log(`[SES-DIAG] === OFFER EVIDENCE (week#${week.iteration}, homeWeek=${week.weekOnHome}) ===`);
        console.log(`[SES-DIAG] settleOfferMarkers=${JSON.stringify(week.settleOfferMarkers)}`);
        dumpSnapshot('home (offer task present)', homeSnap);
        dumpSnapshot('engineer detail BEFORE scroll', beforeScroll);
        dumpSnapshot('engineer detail AFTER scroll', snap);
      }
      const proceed = snap.buttons.find((b) => b.enabled && b.name === PROCEED_TO_INTERVIEW);
      if (proceed) {
        await clickResilient(page, byButton(page, PROCEED_TO_INTERVIEW), PROCEED_TO_INTERVIEW);
        await page.waitForTimeout(700);
        offerAccepted = true;
        loopExitReason = 'offerAccepted';
        break;
      }
      // No offer yet this week — pop back off the engineer's detail screen
      // (a pushed route with no tab bar of its own) before the next
      // iteration's Home tab click can find anything.
      await clickResilient(page, () => page.getByRole('button', { name: /^Back/i }).first(), 'Back').catch(() => {});
      await page.waitForTimeout(400);
      await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ');
      await page.waitForTimeout(400);
      if (!next) {
        loopExitReason = 'noNextWeekButton';
        break; // no next-week button and no offer — genuinely stuck, don't loop forever
      }
    }
    // Phase 1 diagnosis: the whole classification input, in the job log, in
    // one place — no artifact download required. Printed unconditionally so
    // the passing Chromium run is directly comparable to the WebKit one.
    const lastWeek = weekDiagnostics[weekDiagnostics.length - 1];
    console.log(`[SES-DIAG] === SUMMARY seed=${seed} ===`);
    console.log(`[SES-DIAG] offerAccepted=${offerAccepted} weeksWaited=${weeksWaited} ` +
      `iterations=${weekDiagnostics.length} exit=${loopExitReason} ` +
      `homeOfferEverSeen=${weekDiagnostics.some((w) => w.homeOfferMarkers.length > 0)} ` +
      `settleOfferEverSeen=${weekDiagnostics.some((w) => w.settleOfferMarkers.length > 0)} ` +
      `detailOfferTextEverSeen=${weekDiagnostics.some((w) => w.detailOfferMarkersBeforeScroll.length > 0 || w.detailOfferMarkersAfterScroll.length > 0)} ` +
      `ctaEverSeen=${weekDiagnostics.some((w) => w.detailCtaBeforeScroll || w.detailCtaAfterScroll)} ` +
      `anyScrollEverChanged=${weekDiagnostics.some((w) => w.scroll.everChanged)} ` +
      `totalWheelInvocations=${weekDiagnostics.reduce((n, w) => n + w.scroll.wheelInvocations, 0)} ` +
      `totalWheelMoved=${weekDiagnostics.reduce((n, w) => n + w.scroll.wheelMoved, 0)}`);
    for (const w of weekDiagnostics) {
      if (w.homeOfferMarkers.length > 0) console.log(`[SES-DIAG] week#${w.iteration} homeOfferMarkers=${JSON.stringify(w.homeOfferMarkers)}`);
      if (w.settleOfferMarkers.length > 0) console.log(`[SES-DIAG] week#${w.iteration} settleOfferMarkers=${JSON.stringify(w.settleOfferMarkers)}`);
      if (w.detailOfferMarkersBeforeScroll.length > 0) console.log(`[SES-DIAG] week#${w.iteration} detailOfferMarkersBefore=${JSON.stringify(w.detailOfferMarkersBeforeScroll)}`);
      if (w.detailOfferMarkersAfterScroll.length > 0) console.log(`[SES-DIAG] week#${w.iteration} detailOfferMarkersAfter=${JSON.stringify(w.detailOfferMarkersAfterScroll)}`);
    }
    if (!offerAccepted && lastWeek) {
      // Nothing above proved the offer exists — dump the final state in full
      // so the "never generated" reading can be checked against real output
      // rather than assumed.
      console.log('[SES-DIAG] === FINAL STATE (no offer accepted) ===');
      console.log(`[SES-DIAG] lastWeek#${lastWeek.iteration} homeWeek=${lastWeek.weekOnHome} nextWeekButton=${lastWeek.nextWeekButton}`);
      dumpSnapshot('engineer detail, final iteration AFTER scroll', snap);
      console.log(`[SES-DIAG] raw aria snapshot follows (${'engineer detail, final'})`);
      for (const line of (await page.locator('body').ariaSnapshot()).split('\n')) console.log(`[SES-DIAG] raw | ${line}`);
    }
    expect(offerAccepted, `no 面談依頼/${PROCEED_TO_INTERVIEW} appeared within ${MAX_WEEKS_TO_WAIT_FOR_OFFER} weeks (seed=${seed}) — not a stall/timeout tuning issue, see this file's determinism note`).toBe(true);

    // Phase 3: the accepted application is now `active` — the exact real
    // GameState transition `_ApplicationRow`'s FitBadge/`Fitの理由を見る`
    // read from (project_proposal.dart: `status` defaults to `active`) —
    // so 営業状況 now shows it, no client-interview resolution needed first.
    // The engineer's detail screen right after accepting still shows the
    // "営業状況" card mid-rebuild (its own group briefly renders with no
    // name at all — verified directly, not a timing guess: acceptance is a
    // real GameState mutation via a real `showModalBottomSheet`-adjacent
    // Navigator/SnackBar transition, and this screen's own ListView needs a
    // fresh route mount to settle), so this pops back to the tab bar and
    // re-enters via 社員 -> the same card for a clean rebuild, exactly like
    // a real player switching tabs and back would see.
    await clickResilient(page, () => page.getByRole('button', { name: /^Back/i }).first(), 'Back').catch(() => {});
    await page.waitForTimeout(400);
    await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ');
    await page.waitForTimeout(400);
    snap = await openEngineerDetail(page);
    snap = await scrollUntilButtonFound(page, FIT_REASON_LINK);
    const fitLink = snap.buttons.find((b) => b.enabled && b.name === FIT_REASON_LINK);
    expect(fitLink, `${FIT_REASON_LINK} not visible after accepting the interview offer (seed=${seed})`).toBeTruthy();
    await capture('04-fitbadge-visible');

    // Click "Fitの理由を見る" and wait for FitReasonSheet's own content to
    // actually render (bounded poll, not a fixed sleep). Checks "Fit内訳"
    // specifically — never "Fitの理由", which is also a substring of the
    // "Fitの理由を見る" link itself, still sitting on the *background*
    // EngineerDetailScreen underneath the not-yet-rendered sheet. A CI
    // failure (PR #19, run 32101366921) traced to exactly that false
    // positive: `hasText(candidate, 'Fitの理由')` matched the still-present
    // link on the very first poll, before the sheet had opened at all —
    // grabbing the background screen's own semantics (visible in the CI
    // log's own `sheetText`: skill sheet / personality / basic info, zero
    // Fit content) as `sheetSnap`, not the sheet's. Passed 5/5 locally only
    // because local rendering happened to finish before that first poll;
    // CI's documented slower/contended rendering (see e2e/README.md's own
    // CPU-throttling findings) exposed the race. Also widened from 20×200ms
    // (4s) to 40×300ms (12s) — the same order of magnitude this harness's
    // other real transition-waits already use under CI contention
    // (`waitForAnyEnabledButton`/`waitForInterviewScreenTransition` in
    // beginner-mode-waiting-and-recruitment.spec.ts), not an arbitrary bump.
    await clickResilient(page, byButton(page, FIT_REASON_LINK), FIT_REASON_LINK);
    let sheetSnap: ScreenSnapshot | null = null;
    for (let i = 0; i < 40; i++) {
      const candidate = await snapshotScreen(page);
      if (hasText(candidate, 'Fit内訳')) {
        sheetSnap = candidate;
        break;
      }
      await page.waitForTimeout(300);
    }
    expect(sheetSnap, `FitReasonSheet never rendered after tapping ${FIT_REASON_LINK} (seed=${seed})`).not.toBeNull();
    await capture('05-fit-reason-sheet-open');

    const sheetText = sheetSnap!.texts.join(' ');
    textOffenders.push(...findDoubledParticles(sheetSnap!));

    // §8 of the brief — every required assertion, read straight from the
    // real rendered sheet, never re-derived from GameState:
    const overallMatch = OVERALL_FIT_RE.exec(sheetText);
    expect(overallMatch, `総合Fit not found in FitReasonSheet (seed=${seed}): ${sheetText}`).not.toBeNull();

    for (const label of ['技術', '経験', '人物・相性', '条件']) {
      expect(BREAKDOWN_RE(label).test(sheetText), `Fit内訳 "${label}" row missing/malformed (seed=${seed}): ${sheetText}`).toBe(true);
    }

    expect(hasText(sheetSnap!, '良い点'), `良い点 heading missing (seed=${seed}): ${sheetText}`).toBe(true);
    const cautionHeadingIndex = sheetText.indexOf('注意点');
    // Bounded to the "良い点" section alone — this sheet's own layout
    // always puts "注意点" (if present) directly after it, so an unbounded
    // slice-to-end would also count any caution bullets as positives.
    const positiveSection = sheetText.slice(sheetText.indexOf('良い点'), cautionHeadingIndex === -1 ? undefined : cautionHeadingIndex);
    const positiveBullets = positiveSection.match(BULLET_RE) ?? [];
    expect(positiveBullets.length, `良い点 has no bullet lines (seed=${seed}): ${sheetText}`).toBeGreaterThan(0);

    // 注意点 only when the sheet actually shows it (§8: "該当する場合のみ") —
    // never asserted as required, but validated when present.
    let cautionBullets: string[] = [];
    if (hasText(sheetSnap!, '注意点')) {
      cautionBullets = sheetText.slice(cautionHeadingIndex).match(BULLET_RE) ?? [];
      expect(cautionBullets.length, `注意点 heading present but no bullet lines (seed=${seed}): ${sheetText}`).toBeGreaterThan(0);
    }

    // Phase 4: close the BottomSheet — tap the dimmed area *above* the sheet
    // (the "Scrim" semantics node's own bounding box centers on the sheet
    // content itself, which visually intercepts a role-based click there;
    // a real player taps the visible dim strip instead) — then confirm the
    // game keeps going: back to the tab bar, a couple of ordinary week
    // advances, clearing the still-pending client interview via its own
    // always-legal "社員に任せる" action along the way. Never asserts on
    // that auto-resolve's pass/fail RNG outcome — only that the app keeps
    // presenting a legal next action, the actual "no dead-end" check (§9).
    // y=100 (CSS px), not right at the very top: EngineerDetailScreen's own
    // AppBar (~56px tall) sits underneath the barrier there too, and tapping
    // *on* the AppBar's own hit-testable area did not dismiss the sheet
    // (verified directly) — just below it, still well above where the sheet
    // itself starts, reliably lands on the barrier alone.
    const viewport = page.viewportSize();
    expect(viewport, 'no viewport size available to tap the sheet scrim').toBeTruthy();
    await page.mouse.click(viewport!.width / 2, 100);
    // Bounded poll for the close animation to actually finish (Material's
    // default bottom-sheet close transition), not a fixed sleep — a single
    // 500ms read here caught the sheet's content mid-animation, still
    // present in the semantics tree, before its own dispose ran. Checks
    // "Fit内訳" specifically (not "Fitの理由", which is also a substring of
    // the still-legitimately-present "Fitの理由を見る" link once back on
    // the detail screen) so this can't false-positive on that link.
    let afterClose = await snapshotScreen(page);
    for (let i = 0; i < 15 && hasText(afterClose, 'Fit内訳'); i++) {
      await page.waitForTimeout(200);
      afterClose = await snapshotScreen(page);
    }
    expect(hasText(afterClose, 'Fit内訳'), `FitReasonSheet still open after tapping its scrim (seed=${seed})`).toBe(false);
    await capture('06-sheet-closed-continuing');

    await clickResilient(page, () => page.getByRole('button', { name: /^Back/i }).first(), 'Back').catch(() => {});
    await page.waitForTimeout(400);
    await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ');
    await page.waitForTimeout(400);

    let continuedWeeks = 0;
    for (let i = 0; i < 3; i++) {
      await settleAndScan(page, textOffenders);
      snap = await snapshotScreen(page);
      const autoResolve = snap.buttons.find((b) => b.enabled && b.name === AUTO_RESOLVE_CLIENT_INTERVIEW);
      if (autoResolve) {
        await clickResilient(page, byButton(page, AUTO_RESOLVE_CLIENT_INTERVIEW), AUTO_RESOLVE_CLIENT_INTERVIEW);
        await page.waitForTimeout(500);
        await settleAndScan(page, textOffenders);
        await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ').catch(() => {});
        await page.waitForTimeout(400);
      }
      snap = await snapshotScreen(page);
      const next = snap.buttons.find((b) => b.enabled && b.name.startsWith(NEXT_WEEK_PREFIX));
      expect(next, `no legal action / 次の週へ after closing FitReasonSheet — dead-end (seed=${seed}, iter=${i}): buttons=${JSON.stringify(snap.buttons)}`).toBeTruthy();
      await clickResilient(page, byButton(page, next!.name), next!.name);
      await page.waitForTimeout(700);
      continuedWeeks++;
    }

    const durationMs = Date.now() - startedAt;
    const resultJson = buildResultJson({
      scenario: 'phase-3b1-fit-reason',
      device: testInfo.project.name,
      seed,
      play: founding,
      errors,
      durationMs,
    });
    await writeArtifacts(testInfo, resultJson, founding.actionTrace);

    const fitReasonResult = {
      seed,
      device: testInfo.project.name,
      reachedWeek13: beginner.completed,
      weeksWaitedForOffer: weeksWaited,
      offerAccepted,
      fitReasonSheetOpened: sheetSnap !== null,
      overallFit: overallMatch ? { symbol: overallMatch[1], label: overallMatch[2] } : null,
      positiveBulletCount: positiveBullets.length,
      cautionSectionPresent: hasText(sheetSnap!, '注意点'),
      cautionBulletCount: cautionBullets.length,
      continuedWeeksAfterClose: continuedWeeks,
      durationMs,
    };
    const fitReasonPath = path.join(testInfo.outputDir, 'fit-reason-result.json');
    fs.mkdirSync(testInfo.outputDir, { recursive: true });
    fs.writeFileSync(fitReasonPath, JSON.stringify(fitReasonResult, null, 2), 'utf-8');
    await testInfo.attach('fit-reason-result.json', { path: fitReasonPath, contentType: 'application/json' });

    if (errors.pageErrors.length > 0 || errors.consoleErrors.length > 0) {
      // eslint-disable-next-line no-console
      console.log(`[SES E2E Phase 3B-1] seed=${seed} device=${testInfo.project.name} FAILED — reproduce with ?e2e=1&seed=${seed}`, JSON.stringify(fitReasonResult, null, 2));
    }

    expect(errors.pageErrors, `uncaught page errors (seed=${seed})`).toEqual([]);
    expect(errors.crashed, `page crashed (seed=${seed})`).toBe(false);
    expect(errors.consoleErrors, `unallowlisted console.error (seed=${seed})`).toEqual([]);
    expect(textOffenders, `doubled-particle text observed (seed=${seed}): ${JSON.stringify(textOffenders)}`).toEqual([]);
  });
}

if (parsedSeeds.error) {
  test('SES_E2E_FIT_REASON_SEEDS is invalid', () => {
    throw new Error(parsedSeeds.error!);
  });
}
