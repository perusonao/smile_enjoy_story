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
import { snapshotScreen, hasText, findDoubledParticles, type ScreenSnapshot } from '../helpers/game-state';
import { watchForErrors, captureMilestone, writeArtifacts, buildResultJson } from '../helpers/artifacts';
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
const CLOSE = ['閉じる', 'OK', '会社状況を見る', '面談依頼を見る', '採用を見る', '社員環境を見る', 'それでも進む', '社員に任せて進む'];

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
      const close = snap.buttons.find((b) => b.enabled && CLOSE.includes(b.name) && b.name !== label);
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
async function settleAndScan(page: import('@playwright/test').Page, textOffenders: string[]): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  for (let i = 0; i < 10; i++) {
    textOffenders.push(...findDoubledParticles(snap));
    const close = snap.buttons.find((b) => b.enabled && CLOSE.includes(b.name));
    if (!close) return snap;
    await clickResilient(page, byButton(page, close.name), close.name);
    await page.waitForTimeout(400);
    snap = await snapshotScreen(page);
  }
  return snap;
}

/** The one (Beginner Mode never hires a second engineer by Week 13) real
 * engineer card on the 社員 tab — matched by "not the ManagementHud button"
 * the same way every other driver in this harness distinguishes it (its own
 * label is a dynamic "${name} ${status} ¥${salary} ... (残N週)" string that
 * changes week to week, so it's never matched by a fixed name). */
function findEngineerCard(snap: ScreenSnapshot) {
  return snap.buttons.find((b) => b.enabled && !b.name.startsWith('経営状況'));
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
async function scrollUntilButtonFound(page: import('@playwright/test').Page, buttonName: string, maxSteps = 15): Promise<ScreenSnapshot> {
  // `page.mouse.wheel` scrolls whatever is under the *current* virtual mouse
  // position — which, right after a `.click()` on the previous screen,
  // still sits wherever that click landed (a different route entirely).
  // Re-center it over this screen's own body first so the wheel events
  // reliably land on this screen's `ListView`, not wherever the last click
  // happened to be.
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  await page.waitForTimeout(200);
  let snap = await snapshotScreen(page);
  let everChanged = false;
  let stableStreak = 0;
  let lastFingerprint = JSON.stringify(snap.texts);
  for (let i = 0; i < maxSteps; i++) {
    if (snap.buttons.some((b) => b.enabled && b.name === buttonName)) return snap;
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(300);
    snap = await snapshotScreen(page);
    const fingerprint = JSON.stringify(snap.texts);
    if (fingerprint === lastFingerprint) {
      stableStreak++;
      // Never give up on the very first unchanged read (a transient
      // SnackBar dismissing, or the very first wheel event landing before
      // Flutter's Scrollable is fully ready to receive it, can both leave
      // an early read identical without the list actually being stuck) —
      // only once real scrolling has been observed at least once *and*
      // then stalls for a few reads in a row is this the bottom.
      if (everChanged && stableStreak >= 3) break;
    } else {
      everChanged = true;
      stableStreak = 0;
    }
    lastFingerprint = fingerprint;
  }
  return snap;
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
    for (; weeksWaited < MAX_WEEKS_TO_WAIT_FOR_OFFER && !offerAccepted; weeksWaited++) {
      await settleAndScan(page, textOffenders);
      snap = await snapshotScreen(page);
      const next = snap.buttons.find((b) => b.enabled && b.name.startsWith(NEXT_WEEK_PREFIX));
      if (next) {
        await clickResilient(page, byButton(page, next.name), next.name);
        await page.waitForTimeout(700);
      }
      await settleAndScan(page, textOffenders);

      snap = await openEngineerDetail(page);
      const proceed = snap.buttons.find((b) => b.enabled && b.name === PROCEED_TO_INTERVIEW);
      if (proceed) {
        await clickResilient(page, byButton(page, PROCEED_TO_INTERVIEW), PROCEED_TO_INTERVIEW);
        await page.waitForTimeout(700);
        offerAccepted = true;
        break;
      }
      // No offer yet this week — pop back off the engineer's detail screen
      // (a pushed route with no tab bar of its own) before the next
      // iteration's Home tab click can find anything.
      await clickResilient(page, () => page.getByRole('button', { name: /^Back/i }).first(), 'Back').catch(() => {});
      await page.waitForTimeout(400);
      await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ');
      await page.waitForTimeout(400);
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
    // actually render (bounded poll, not a fixed sleep).
    await clickResilient(page, byButton(page, FIT_REASON_LINK), FIT_REASON_LINK);
    let sheetSnap: ScreenSnapshot | null = null;
    for (let i = 0; i < 20; i++) {
      const candidate = await snapshotScreen(page);
      if (hasText(candidate, 'Fitの理由')) {
        sheetSnap = candidate;
        break;
      }
      await page.waitForTimeout(200);
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
