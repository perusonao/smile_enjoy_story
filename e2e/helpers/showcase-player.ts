// Driver helpers for the **video-showcase spec only**
// (tests-showcase/ui-showcase-video.spec.ts). Never imported by any spec
// under tests/ — a new file, not a change to any existing helper, so the
// normal E2E suite's behavior/timing is untouched.
//
// The click/dialog-dismiss/scroll primitives below are deliberately the
// same *shape* already proven out in this harness
// (helpers/beginner-mode-player.ts, tests/beginner-mode-waiting-and-
// recruitment.spec.ts, tests/phase-3b1-fit-reason.spec.ts) — a local copy
// rather than a shared export, matching those files' own precedent of
// keeping each driver's retry/dialog-scope details local to what it
// actually needs (see phase-3b1-fit-reason.spec.ts's own doc comment on
// this). This file only ever taps real, currently-enabled production
// buttons — no debug/state API, same principle as every other driver here.
import type { Locator, Page } from '@playwright/test';
import { extractInterviewCandidateName, firstEnabledDialogButton, hasText, snapshotScreen, type ScreenSnapshot } from './game-state';

export const HOME_TAB = 'ホーム';
export const EMPLOYEES_TAB = '社員';
export const RECRUITMENT_TAB = '採用';
export const PROJECTS_TAB = '案件';

export const NEXT_WEEK_PREFIX = '次の週へ';
export const START_SALES = '営業を開始する';
export const CONFIRM_START_SALES = '営業開始';
export const POST_LISTING = '掲載する';
export const VIEW_PROJECT_LIST = '案件一覧を見る';

// recruitment_interview_screen.dart's `_Questions` / game-feel-
// presentation.spec.ts's own identical list (the six
// `InterviewQuestionCategory.values` labels) — used to tell a real question
// card apart from the screen's own "過去の回答" ExpansionTile toggle (see
// hireFirstAvailableApplicant's own doc comment for why that distinction
// matters).
const QUESTION_CATEGORY_LABELS = ['技術経験', '役割・経歴', '転職理由', 'チームワーク', '将来像', '働き方'];

// Same dismiss-list shape as every other Phase 3A/3B driver in this harness
// (beginner-mode-player.ts's CLOSE_LABELS, beginner-mode-waiting-and-
// recruitment.spec.ts's CLOSE, phase-3b1-fit-reason.spec.ts's CLOSE) —
// duplicated locally on purpose (see this file's top-of-file doc comment).
export const DIALOG_CLOSE_LABELS = [
  '閉じる',
  'OK',
  '会社状況を見る',
  '面談依頼を見る',
  '採用を見る',
  '社員環境を見る',
  'それでも進む',
  '社員に任せて進む',
  '採用画面へ戻る',
];

const CLICK_RESILIENT_TOTAL_MS = 15_000;
const CLICK_RESILIENT_ATTEMPT_MS = 3_000;

export const byButton = (page: Page, name: string) => () => page.getByRole('button', { name, exact: true }).first();
export const byTab = (page: Page, name: string) => () => page.getByRole('tab', { name, exact: true });

/** Clicks whatever [locate] resolves to, re-resolving fresh on every retry
 * and dismissing a known dialog on timeout — same shape as
 * ses-player.ts's clickDecisionResilient / the other drivers' own
 * clickResilient (see this file's doc comment). */
export async function clickResilient(page: Page, locate: () => Locator, label: string): Promise<void> {
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
      const close = firstEnabledDialogButton(snap, DIALOG_CLOSE_LABELS.filter((name) => name !== label));
      if (close) {
        await page.getByRole('button', { name: close.name, exact: true }).click().catch(() => {});
        await page.waitForTimeout(300);
      }
    }
  }
}

/** Dismisses every dialog currently stacked on screen (bounded). Returns the
 * first snapshot with nothing left to dismiss. */
export async function settleDialogs(page: Page, maxIterations = 10): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  for (let i = 0; i < maxIterations; i++) {
    const close = firstEnabledDialogButton(snap, DIALOG_CLOSE_LABELS);
    if (!close) return snap;
    await clickResilient(page, byButton(page, close.name), close.name);
    await page.waitForTimeout(400);
    snap = await snapshotScreen(page);
  }
  return snap;
}

/** True once [snap] is showing an image-backed FoundingEventDialog (画像付
 * きイベントモーダル Phase 1) rather than a plain-text one — detected the
 * same way a sighted player would recognize it: a short category label
 * (founding_dialogs.dart's own `category` field — e.g. "取引先からの連絡",
 * "採用・応募", "会社経営", "案件面談") sitting above a dialog's title/body,
 * which only ever renders when `imageAssetPath` is set. Never reads
 * GameState/asset paths directly (see e2e/README.md "Why no debug API").
 *
 * Substring match (`hasText`, not an exact `texts` entry): Flutter Web
 * merges this dialog's category+title+body into one combined semantics
 * text node (confirmed directly against a real run — the raw text reads
 * "取引先からの連絡 🎉 面談依頼が届きました！ ..." as a single array entry),
 * the same merging behavior documented throughout this harness (e.g.
 * game-state.ts's own `ARIA_LINE` doc comment) for adjacent Text widgets —
 * an exact-equality check against `snap.texts` never matches. */
const EVENT_MODAL_CATEGORY_LABELS = ['取引先からの連絡', '採用・応募', '会社経営', '案件面談'];

export function isImageEventModal(snap: ScreenSnapshot): boolean {
  return snap.dialogButtonNames.length > 0 && EVENT_MODAL_CATEGORY_LABELS.some((label) => hasText(snap, label));
}

/** Taps "次の週へ" (after clearing anything already pending), then drains
 * *every* dialog the advance produces, one at a time — not just the first.
 * `_showPendingFoundingEvents`/`_showPendingBeginnerEvents`
 * (home_screen.dart) can queue several one-time dialogs behind a single
 * week advance (confirmed directly: a real run's very first Home week-
 * advance showed a 面談依頼 celebration, and — after tapping through it,
 * which itself navigates to the employee's own detail screen — Beginner
 * Mode's own milestone dialogs kept appearing on top of *that* screen), so
 * a single "read the snapshot right after the click" would only ever see
 * the first one. [onDialog] is called with every dialog's snapshot, in
 * order, before it gets dismissed — the caller decides what (if anything)
 * to do with each one (e.g. pause on an image-backed one). Automatically
 * pops back to the bottom-nav tab shell afterward if a dialog's own
 * tap-through navigated to a pushed detail route (interviewOfferCelebration
 * does this). Returns the final settled snapshot, or `null` if no "次の週へ"
 * was available at all. */
export async function advanceOneWeek(page: Page, onDialog?: (snap: ScreenSnapshot) => Promise<void>): Promise<ScreenSnapshot | null> {
  await settleDialogs(page);
  await returnToTabShell(page);
  const snap = await snapshotScreen(page);
  const next = snap.buttons.find((b) => b.enabled && b.name.startsWith(NEXT_WEEK_PREFIX));
  if (!next) return null;
  await clickResilient(page, byButton(page, next.name), next.name);
  await page.waitForTimeout(700);

  let current = await snapshotScreen(page);
  const MAX_DIALOGS_PER_ADVANCE = 15;
  for (let i = 0; i < MAX_DIALOGS_PER_ADVANCE; i++) {
    const close = firstEnabledDialogButton(current, DIALOG_CLOSE_LABELS);
    if (!close) break;
    if (onDialog) await onDialog(current);
    await clickResilient(page, byButton(page, close.name), close.name);
    await page.waitForTimeout(500);
    current = await snapshotScreen(page);
  }
  await returnToTabShell(page);
  return snapshotScreen(page);
}

/** Pops back to the bottom-nav tab shell (until the "ホーム" tab is visible
 * again) if a dialog's own tap-through navigated to a pushed detail route
 * — `MainShell`'s bottom `NavigationBar` is only reachable from the tab
 * shell itself, never from a `Navigator.push`-ed full-screen route like
 * `EngineerDetailScreen` (which `interviewOfferCelebration`'s "面談依頼を見
 * る" tap-through opens). A no-op when already on the tab shell. */
export async function returnToTabShell(page: Page, maxSteps = 6): Promise<void> {
  const homeTab = page.getByRole('tab', { name: HOME_TAB, exact: true });
  for (let i = 0; i < maxSteps; i++) {
    if (await homeTab.count()) return;
    await page.getByRole('button', { name: /^Back\b/i }).first().click({ timeout: 1_500 }).catch(() => {});
    await page.waitForTimeout(350);
  }
}

// 社員タブ Phase 2's own filter-chip row ("すべて N" / "参画中 N" / "待機中
// N") plus ManagementHud's own tappable "経営状況..." button both render as
// real, enabled a11y buttons ahead of any engineer roster card — excluded by
// prefix, the same way phase-3b1-fit-reason.spec.ts's findEngineerCard
// already does.
const NON_CARD_BUTTON_PREFIXES = ['すべて ', '参画中 ', '待機中 ', '経営状況'];

/** The first real engineer-roster card on the currently-filtered 社員 tab —
 * matched by "not a filter chip / not the HUD button" (its own accessible
 * name is a dynamic, per-engineer merged string, never a fixed label — see
 * phase-3b1-fit-reason.spec.ts's identical findEngineerCard for why a bare
 * InkWell-wrapped card still shows up as one enabled `button` node). `null`
 * when the currently-applied filter has no matching engineer. */
export function findFirstEngineerCard(snap: ScreenSnapshot) {
  return snap.buttons.find((b) => b.enabled && !NON_CARD_BUTTON_PREFIXES.some((p) => b.name.startsWith(p))) ?? null;
}

/** Reads 社員タブ Phase 2's own すべて/参画中/待機中 filter-chip counts —
 * caller must already be on the 社員 tab. Used by the enrichment driver to
 * tell "an interview/offer round happened" (helpers/game-state.ts has no
 * notion of this) apart from "a second engineer actually joined the roster"
 * — `RecruitmentEngine.rollAcceptance` (accept/decline) and
 * `joinDelayWeeks` (1-2 weeks after acceptance) both mean a real player
 * only sees the roster grow some time after the hire decision, never on the
 * same tick. `null` if the filter row isn't present for any reason. */
export async function readEmployeeCounts(page: Page): Promise<{ all: number; assigned: number; waiting: number } | null> {
  const snap = await snapshotScreen(page);
  const all = findChipTextByPrefix(snap, 'すべて ');
  const assigned = findChipTextByPrefix(snap, '参画中 ');
  const waiting = findChipTextByPrefix(snap, '待機中 ');
  if (!all || !assigned || !waiting) return null;
  const num = (label: string) => Number(label.split(' ').pop());
  return { all: num(all), assigned: num(assigned), waiting: num(waiting) };
}

/** Scrolls the current screen's list (bounded, polling for the target
 * rather than a fixed scroll amount) until [buttonName] is an enabled
 * button on screen, or the list stops changing — same technique as
 * phase-3b1-fit-reason.spec.ts's scrollUntilButtonFound (Flutter Web's
 * SliverList only materializes semantics for on/near-viewport children). */
export async function scrollUntilButtonFound(page: Page, buttonName: string, maxSteps = 15): Promise<ScreenSnapshot> {
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  await page.waitForTimeout(200);
  let snap = await snapshotScreen(page);
  let everChanged = false;
  let stableStreak = 0;
  let lastFingerprint = JSON.stringify(snap.texts);
  for (let i = 0; i < maxSteps; i++) {
    if (snap.buttons.some((b) => b.enabled && b.name === buttonName)) return snap;
    await page.mouse.wheel(0, 400);
    await page.waitForTimeout(300);
    snap = await snapshotScreen(page);
    const fingerprint = JSON.stringify(snap.texts);
    if (fingerprint === lastFingerprint) {
      stableStreak++;
      if (everChanged && stableStreak >= 3) break;
    } else {
      everChanged = true;
      stableStreak = 0;
    }
    lastFingerprint = fingerprint;
  }
  return snap;
}

/** Scrolls a screen back to its top the same event-driven way
 * [scrollUntilButtonFound] scrolls down — used purely for the video's own
 * presentation (returning to the top of a tab before switching away). */
export async function scrollToTop(page: Page, steps = 6): Promise<void> {
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  for (let i = 0; i < steps; i++) {
    await page.mouse.wheel(0, -600);
    await page.waitForTimeout(150);
  }
}

/** Locator for a `ChoiceChip` (社員タブ/案件タブ Phase 2's own filter rows,
 * e.g. "すべて 1", "営業中 0") by its exact current label. Confirmed
 * directly against a real run's raw `ariaSnapshot()` output: Flutter's
 * `ChoiceChip` renders with ARIA role `checkbox` (`[checked]`/unchecked),
 * *not* `button` — `helpers/game-state.ts`'s `parseAriaSnapshot` only ever
 * special-cases `role === 'button'` into `ScreenSnapshot.buttons`, so every
 * other role (checkbox included) lands in `.texts` as plain text with no
 * role information preserved. That's why a chip's label must be read from
 * `snap.texts` (via `findChipTextByPrefix`, below) rather than
 * `snap.buttons`, and why *clicking* it needs an explicit `checkbox`-role
 * locator rather than `byButton`'s `button`-role one. */
export const byChip = (page: Page, name: string) => () => page.getByRole('checkbox', { name, exact: true }).first();

/** The current label of the first `ChoiceChip` whose text starts with
 * [prefix] (e.g. "参画中 " -> "参画中 2") — see `byChip`'s doc comment for
 * why this reads `snap.texts`, not `snap.buttons`. `null` if no chip with
 * that prefix is present (never actually happens for this app's own
 * filter rows, which always render all of their chips, but defensive
 * rather than assumed). */
export function findChipTextByPrefix(snap: ScreenSnapshot, prefix: string): string | null {
  return snap.texts.find((t) => t.startsWith(prefix)) ?? null;
}

/** Reads the current screen and taps the first `ChoiceChip` whose label
 * starts with [prefix], if any. Returns whether a match was found/clicked
 * — `false` (not a throw) when it legitimately isn't there right now. */
export async function clickChipByPrefix(page: Page, prefix: string): Promise<boolean> {
  const snap = await snapshotScreen(page);
  const label = findChipTextByPrefix(snap, prefix);
  if (!label) return false;
  await clickResilient(page, byChip(page, label), label);
  return true;
}

/** Repeatedly dismisses any known dialog until [tabName]'s bottom-nav tab is
 * actually present — same shape/reasoning as beginner-mode-waiting-and-
 * recruitment.spec.ts's own waitForTabBar (a hire/reject decision's result
 * dialog can chain into a further one-time tutorial dialog before
 * `Navigator.popUntil` actually runs and the tab bar reappears). */
export async function waitForTabPresence(page: Page, tabName: string, maxIterations = 40): Promise<boolean> {
  const tab = page.getByRole('tab', { name: tabName, exact: true });
  for (let i = 0; i < maxIterations; i++) {
    if (await tab.count()) return true;
    let dismissed = false;
    for (const label of DIALOG_CLOSE_LABELS) {
      const btn = page.locator('[role="dialog"], [role="alertdialog"]').getByRole('button', { name: label, exact: true });
      if (await btn.count()) {
        await btn.click().catch(() => {});
        dismissed = true;
        break;
      }
    }
    if (!dismissed) {
      await page.getByRole('button', { name: /^Back\b/i }).first().click({ timeout: 500 }).catch(() => {});
    }
    await page.waitForTimeout(300);
  }
  return (await tab.count()) > 0;
}

/** Polls (bounded) until at least one real, enabled action button is on
 * screen — a navigation can transiently render a bare loading state first.
 * Same shape as beginner-mode-waiting-and-recruitment.spec.ts's
 * waitForAnyEnabledButton. */
export async function waitForAnyEnabledButton(page: Page, maxIterations = 40): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  for (let i = 0; i < maxIterations && !snap.buttons.some((b) => b.enabled && b.name !== 'back'); i++) {
    await page.waitForTimeout(300);
    snap = await snapshotScreen(page);
  }
  return snap;
}

/** True once `RecruitmentInterviewScreen` has actually mounted — the origin
 * screen's own CTA ("面接する"/"面接を再開する") is gone *and* the
 * destination's own identity (its AppBar title, "${name}との面接") is
 * present. Same two-signal check as phase-3b1-fit-reason.spec.ts's sibling
 * file (beginner-mode-waiting-and-recruitment.spec.ts)'s
 * isInterviewScreenReady. */
function isInterviewScreenReady(snap: ScreenSnapshot): boolean {
  const stillOnApplicantDetail = snap.buttons.some((b) => b.enabled && (b.name === '面接する' || b.name === '面接を再開する'));
  if (stillOnApplicantDetail) return false;
  return extractInterviewCandidateName(snap) !== null;
}

async function waitForInterviewScreenTransition(page: Page, maxIterations = 40): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  for (let i = 0; i < maxIterations && !isInterviewScreenReady(snap); i++) {
    await page.waitForTimeout(300);
    snap = await snapshotScreen(page);
  }
  return snap;
}

export type HireAttemptOutcome =
  /** Reached "面接まとめ" and tapped "採用する" — a real hire *decision* was
   * made (still subject to `RecruitmentEngine.rollAcceptance` + a 1-2 week
   * `joinDelayWeeks` before the roster actually grows — never assume this
   * alone means the candidate joined). */
  | 'decided'
  /** No un-interviewed applicant was on screen right now. */
  | 'no-candidate'
  /** A candidate was opened/interviewed but the Q&A loop's bounded step
   * budget ran out before reaching "面接まとめ" — a real (rare) case worth
   * telling apart from `'decided'`, not silently folded into it. */
  | 'gave-up';

/** Interviews and hires the first not-yet-interviewed applicant currently
 * listed on the 採用 tab (must already be the active tab) — same flow a
 * real player follows: candidate card -> "面接する" -> answer every
 * question/reverse-question with the first enabled choice -> "採用する" at
 * "面接まとめ" -> drain the result dialog(s) back to the tab bar. Never
 * inspects/depends on `RecruitmentEngine.rollAcceptance`'s outcome — this
 * is enrichment for the showcase video, not a correctness assertion; see
 * `HireAttemptOutcome` for what the return value does and doesn't promise. */
export async function hireFirstAvailableApplicant(page: Page): Promise<HireAttemptOutcome> {
  // `getByRole` directly, not snapshotScreen: ApplicantDetailScreen's list
  // can render an over-long/truncated aria-label on its outer group that
  // ariaSnapshot()-based parsing misses, even though each card is
  // individually a well-labelled button (documented in
  // beginner-mode-waiting-and-recruitment.spec.ts).
  const candidate = page.getByRole('button', { name: /未面接/ }).first();
  if ((await candidate.count()) === 0) return 'no-candidate';
  await clickResilient(page, () => page.getByRole('button', { name: /未面接/ }).first(), '未面接候補者');

  const afterOpen = await waitForAnyEnabledButton(page);
  const interviewBtn = afterOpen.buttons.find((b) => b.enabled && (b.name === '面接する' || b.name === '面接を再開する'));
  if (!interviewBtn) {
    // Already interviewed/hired/rejected elsewhere — nothing to do here.
    await waitForTabPresence(page, RECRUITMENT_TAB);
    return 'no-candidate';
  }
  await clickResilient(page, byButton(page, interviewBtn.name), interviewBtn.name);
  let snap = await waitForInterviewScreenTransition(page);

  let decided = false;
  for (let step = 0; step < 12; step++) {
    if (hasText(snap, '面接まとめ')) {
      await clickResilient(page, byButton(page, '採用する'), '採用する');
      decided = true;
      break;
    }
    // recruitment_interview_screen.dart's `_Questions` renders its "過去の
    // 回答 (N)" ExpansionTile *before* the six question-category cards in
    // the widget tree, once a second question has been asked — a plain
    // "first enabled button" scan (which found this loop, verified by a
    // real run's own diagnostic: every attempt gave up without ever
    // reaching "面接まとめ") picks that toggle over a real remaining
    // question every time from then on. Toggling it does change the
    // screen's visible text (past answers show/hide), so clickAndWaitFor
    // Change's own "did it change" check alone can't tell the two apart —
    // a real question category is preferred explicitly whenever one is
    // still available; only the reverse-question screen's FilledButton.tonal
    // choices (which match none of these category labels) fall through to
    // the generic "any enabled button" pick below.
    const questionBtn = snap.buttons.find((b) => b.enabled && QUESTION_CATEGORY_LABELS.some((c) => b.name.includes(c)));
    const anyBtn = questionBtn ?? snap.buttons.find((b) => b.enabled && b.name !== 'back' && !b.name.includes('過去の回答'));
    if (!anyBtn) break;
    // Waits for the screen's own text content to actually change before the
    // next read — a fixed sleep here risks reading a still-stale question
    // and either double-clicking the same choice or exiting this loop
    // without ever reaching "面接まとめ" (beginner-mode-waiting-and-
    // recruitment.spec.ts's own clickAndWaitForChange doc comment: reproduced
    // directly via CPU throttling — the gap between one interview-question
    // click and the next question actually rendering measured seconds, not
    // hundreds of ms, under real contention).
    snap = await clickAndWaitForChange(page, anyBtn.name, snap);
  }

  await waitForTabPresence(page, RECRUITMENT_TAB);
  return decided ? 'decided' : 'gave-up';
}

/** Clicks [buttonName] and polls (bounded) until the screen's own text
 * content actually differs from [beforeSnap] — same shape as beginner-
 * mode-waiting-and-recruitment.spec.ts's own clickAndWaitForChange (see its
 * doc comment for the CPU-throttling reproduction this timing is sized
 * against). */
async function clickAndWaitForChange(page: Page, buttonName: string, beforeSnap: ScreenSnapshot): Promise<ScreenSnapshot> {
  await clickResilient(page, byButton(page, buttonName), buttonName);
  const beforeKey = JSON.stringify(beforeSnap.texts);
  for (let i = 0; i < 40; i++) {
    await page.waitForTimeout(300);
    const snap = await snapshotScreen(page);
    if (JSON.stringify(snap.texts) !== beforeKey) return snap;
  }
  return snapshotScreen(page);
}

/** A short, human-watchable pause on the current screen — this spec's whole
 * point is a video a person can actually watch, not raw speed (§ task
 * brief: "各主要画面を人間が確認できる程度の短い表示時間"). Never used by,
 * or copied into, any spec under tests/ — those keep their existing
 * timing untouched. */
export async function pauseForViewing(page: Page, ms: number): Promise<void> {
  await page.waitForTimeout(ms);
}
