// The "初見プレイヤー" (first-time player) simulator (§6 of the E2E brief).
//
// Each tick: read the screen (game-state.ts), then do whatever the Guided
// Founding UI is currently presenting as the thing to do — its Primary CTA,
// a pending interview/selection/offer step, or "次の週へ" when the screen is
// legitimately just waiting. Never taps blindly; every rule below maps to a
// concrete, currently-enabled button already rendered by production UI.
import type { Locator, Page } from '@playwright/test';
import {
  anyEnabledButton,
  classifyScreen,
  CLIENT_INTERVIEW_FOLLOWUP_LABELS,
  enabledButton,
  extractInterviewCandidateName,
  hasText,
  isEmptySnapshot,
  snapshotScreen,
  MULTI_CHOICE_SCREENS,
  type ScreenLabel,
  type ScreenSnapshot,
} from './game-state';

export interface ActionTraceEntry {
  action: number;
  elapsedMs: number;
  screen: ScreenLabel;
  primaryCTA: string | null;
  primaryCTACount: number;
  clicked: string;
  advancedWeek: boolean;
  /** Set only for a failed Company Setup submission (§6 of the Codex
   * follow-up) — diagnostic info an "input/controller synchronization
   * failure" report needs, without a production debug bridge. */
  diagnostic?: CompanySetupDiagnostic;
}

export interface CompanySetupDiagnostic {
  screen: 'company-setup';
  presidentNameVisibleValue: string;
  companyNameVisibleValue: string;
  presidentFieldConfirmed: boolean;
  companyFieldConfirmed: boolean;
  submitAttempt: number;
  transitionObserved: boolean;
}

export interface PrimaryCtaAuditEntry {
  action: number;
  screen: ScreenLabel;
  primaryCTA: string | null;
  primaryCTACount: number;
  warning: boolean;
}

export interface ClientInterviewTurn {
  step: 'upper-company' | 'client';
  question: string | null;
  employeeAnswer: string | null;
  playerFollowUp: string | null;
  result: 'passed' | 'failed' | 'pending';
}

export interface StageRegressionWarning {
  action: number;
  from: ScreenLabel;
  to: ScreenLabel;
}

export interface PlayOptions {
  /** Hard cap on simulated "次の週へ" / week-advancing actions (§13). */
  maxWeeks: number;
  /** Hard cap on total player actions (§13). */
  maxActions: number;
  /** No legal action found / no DOM change for this long -> fail (§13). */
  idleTimeoutMs: number;
  /** How many consecutive ticks with an identical fingerprint count as a stall (§13). */
  stallRepeatThreshold: number;
  /** Explicitly reject the first recruitment candidate once, to exercise
   * Selection Failure Recovery (§11) via a real, always-legal UI action
   * instead of hunting for an RNG-unlucky seed. */
  forceRejectFirstCandidate?: boolean;
  /** Fired once per tick, before the click happens, with the screen as the
   * player actually saw it — use this (not onAction, which fires after the
   * click already navigated away) for milestone screenshots (§15). */
  onScreen?: (screen: ScreenLabel, snap: ScreenSnapshot) => Promise<void> | void;
  /** Called right after every action, for the action trace log. */
  onAction?: (entry: ActionTraceEntry) => Promise<void> | void;
}

export interface PlayResult {
  completed: boolean;
  firstAssignmentWeek: number | null;
  actions: number;
  clientInterviewCount: number;
  selectionFailureCount: number;
  stallDetected: boolean;
  stallReason: string | null;
  actionTrace: ActionTraceEntry[];
  primaryCtaAudit: PrimaryCtaAuditEntry[];
  primaryCtaWarnings: PrimaryCtaAuditEntry[];
  clientInterviewHistory: ClientInterviewTurn[];
  stageRegressionWarnings: StageRegressionWarning[];
  /** §12 of the Codex follow-up (Failure Recovery candidate identity):
   * the recruitment candidate's name at the moment of an explicit 不採用,
   * and the name of whoever was eventually hired — read straight off the
   * recruitment-interview screen's own AppBar title
   * ("${name}との面接", PrologueInterviewScreen), never GameState. `null`
   * when that action never happened or the name wasn't recoverable from
   * the UI. */
  rejectedCandidateName: string | null;
  acceptedCandidateName: string | null;
}

const START_GAME = '【初心者モード】おすすめ';
const FOUND_COMPANY = '会社を設立する';
const INTRO_NEXT = ['次へ進む', '次へ'];
const MEDIA_POST = 'この方法で募集する';
const CANDIDATE_INTERVIEW = '面接する';
const NEXT_WEEK = '次の週へ';
const SKILLSHEET_CONFIRM = 'SkillSheetを確認しました';
const SALES_START = '営業を開始する';
const PROCEED_TO_INTERVIEW = '面談へ進む';
const CONTINUE = '続ける';
const REVEAL_CLIENT_RESULT = '結果を確認する';
const REJECT_CANDIDATE = '不採用';
const HIRE_CANDIDATE = '採用する';
const DIALOG_BACK = '戻る';
const BEGIN_MANAGEMENT = '経営を始める';

const SCREEN_ORDER_INDEX: Partial<Record<ScreenLabel, number>> = {
  'start-choice': 0,
  'company-setup': 1,
  intro: 2,
  'recruitment-media-select': 3,
  'candidate-select': 4,
  'recruitment-interview': 5,
  'skill-sheet-confirm': 6,
  'sales-start': 7,
  'interview-request': 8,
  'upper-interview': 9,
  'client-interview': 10,
  contract: 11,
  complete: 12,
};

// Screens a normal playthrough legitimately revisits (candidate re-pick
// after a decline, a fresh interview request after a failed selection
// round) — never counted as a stage-regression warning.
const LEGITIMATE_REVISITS: ReadonlySet<ScreenLabel> = new Set(['candidate-select', 'recruitment-interview', 'interview-request', 'upper-interview']);

/** A definitive-failure placeholder for callers that need a `PlayResult` to
 * report even when `playFoundingToFirstAssignment` itself threw before
 * returning one (Codex follow-up §15: artifacts must still be written on
 * an early/unexpected exception, not just on a clean stall). */
export function emptyPlayResult(reason: string): PlayResult {
  return {
    completed: false,
    firstAssignmentWeek: null,
    actions: 0,
    clientInterviewCount: 0,
    selectionFailureCount: 0,
    stallDetected: true,
    stallReason: reason,
    actionTrace: [],
    primaryCtaAudit: [],
    primaryCtaWarnings: [],
    clientInterviewHistory: [],
    stageRegressionWarnings: [],
    rejectedCandidateName: null,
    acceptedCandidateName: null,
  };
}

export async function playFoundingToFirstAssignment(page: Page, options: PlayOptions): Promise<PlayResult> {
  const start = Date.now();

  // First real paint: headless/no-GPU Chromium falls back to software
  // rendering, so Flutter's semantics tree can take several seconds to
  // attach (observed ~5-15s locally). Wait for it explicitly instead of
  // burning the idle-timeout budget below on "app hasn't finished loading
  // yet" — that's a startup cost, not a stall.
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });
  const trace: ActionTraceEntry[] = [];
  const primaryCtaAudit: PrimaryCtaAuditEntry[] = [];
  const clientInterviewHistory: ClientInterviewTurn[] = [];
  const stageRegressionWarnings: StageRegressionWarning[] = [];

  let actionCount = 0;
  let weekAdvances = 0;
  let selectionFailureCount = 0;
  let clientInterviewCount = 0;
  let rejectedOnce = false;
  let rejectedCandidateName: string | null = null;
  let acceptedCandidateName: string | null = null;
  let previousClickedName: string | null = null;
  let lastFingerprint = '';
  let sameFingerprintStreak = 0;
  let highestSeenStage = -1;
  let lastActivityAt = Date.now();

  let completed = false;
  let stallDetected = false;
  let stallReason: string | null = null;

  while (true) {
    // Read the current snapshot and check for completion FIRST, always —
    // before any cap/timeout can fail the run (Codex review on PR #3, item
    // 3). The bug this fixes: when the very last permitted action (the
    // 100th action, or the 12th week-advancing action) is the one that
    // actually reaches first assignment, the *previous* ordering checked
    // `actionCount >= maxActions` / `weekAdvances >= maxWeeks` before ever
    // reading the resulting screen, so a genuine completion on the final
    // allowed action was reported as a cap failure instead of a success.
    // Observing the result of the last legal action before judging the cap
    // it landed on is the fix — not raising the caps, which would only
    // move the same boundary bug one action/week later.
    let snap = await readStableSemantics(page);
    let screen = classifyScreen(snap);

    if (options.onScreen) await options.onScreen(screen, snap);

    if (screen === 'complete' || hasText(snap, '初案件参画')) {
      completed = true;
      trace.push({ action: actionCount + 1, elapsedMs: Date.now() - start, screen, primaryCTA: null, primaryCTACount: 0, clicked: '(observed completion)', advancedWeek: false });
      if (options.onAction) await options.onAction(trace[trace.length - 1]);
      break;
    }

    // Only once this snapshot is confirmed *not* a completion do the caps
    // apply — they bound the next action about to be considered, not the
    // observation of one that already happened.
    if (actionCount >= options.maxActions) {
      stallDetected = true;
      stallReason = `max actions (${options.maxActions}) exceeded without reaching first assignment`;
      break;
    }
    if (weekAdvances >= options.maxWeeks) {
      // >= , not > : options.maxWeeks is "at most this many week-advancing
      // actions total" (Codex follow-up §14 — the previous `>` let a
      // maxWeeks=12 run attempt a 13th advance before stopping).
      stallDetected = true;
      stallReason = `max weeks (${options.maxWeeks}) exceeded without reaching first assignment`;
      break;
    }
    if (Date.now() - lastActivityAt > options.idleTimeoutMs) {
      stallDetected = true;
      stallReason = `no legal action found for ${options.idleTimeoutMs}ms (dead-end)`;
      break;
    }

    const stageIndex = SCREEN_ORDER_INDEX[screen] ?? -1;
    if (stageIndex >= 0) {
      if (stageIndex > highestSeenStage) {
        highestSeenStage = stageIndex;
      } else if (stageIndex < highestSeenStage && !LEGITIMATE_REVISITS.has(screen)) {
        stageRegressionWarnings.push({ action: actionCount + 1, from: `stage#${highestSeenStage}` as ScreenLabel, to: screen });
      }
    }

    const decideOpts = { forceRejectFirstCandidate: !!options.forceRejectFirstCandidate && !rejectedOnce };
    let decision = decideAction(snap, decideOpts);

    if (!decision) {
      // No legal action on this read — but before treating that as a
      // dead-end, confirm it's not just a transient no-action frame mid
      // route-transition (§1-9 of the re-review: WebKit can render a real,
      // *non-empty* "応募者が見つかりません"/buttons=[] intermediate screen
      // for a tick or two right after a hire decision, before the actual
      // next screen's semantics attach — readStableSemantics only guards
      // against a fully *empty* tree, not this). Bounded, content-agnostic:
      // never special-cases any particular screen or string.
      const check = await waitForActionableOrStableDeadEnd(page, snap, decideOpts);
      if (check.status === 'transitioning') {
        // The tree moved on to some other still-non-actionable state rather
        // than settling — not evidence either way yet. Re-enter the outer
        // loop fresh: the idle-timeout watchdog above (lastActivityAt is
        // deliberately not touched here) still catches a genuinely stuck
        // sequence of repeated transitioning ticks.
        continue;
      }
      snap = check.snapshot;
      screen = check.screen;
      decision = check.decision;
    }

    // Primary-CTA audit (§7): count currently-enabled buttons that look like
    // "the thing to do" (excludes the AppBar restart icon, which never
    // reports as a distinct name collision here since it isn't in `buttons`
    // under the label we match on).
    const enabledCount = snap.buttons.filter((b) => b.enabled).length;
    const auditEntry: PrimaryCtaAuditEntry = {
      action: actionCount + 1,
      screen,
      primaryCTA: decision?.name ?? null,
      primaryCTACount: enabledCount,
      warning: enabledCount > 1 && !MULTI_CHOICE_SCREENS.has(screen),
    };
    primaryCtaAudit.push(auditEntry);

    if (!decision) {
      stallDetected = true;
      stallReason = `dead-end at screen="${screen}": no Primary CTA, no pending event, and no "次の週へ" available (confirmed stable for ${NO_ACTION_STABILITY_WINDOW_MS}ms, not a transient mid-transition frame). Visible buttons: [${snap.buttons.map((b) => `${b.name}${b.enabled ? '' : '(disabled)'}`).join(', ')}]. Visible text: ${JSON.stringify(snap.texts)}`;
      break;
    }

    const fingerprint = `${screen}|${decision.name}|${snap.buttons.map((b) => `${b.name}:${b.enabled}`).sort().join(',')}`;
    if (fingerprint === lastFingerprint) {
      sameFingerprintStreak++;
    } else {
      sameFingerprintStreak = 0;
      lastFingerprint = fingerprint;
    }
    if (sameFingerprintStreak >= options.stallRepeatThreshold) {
      stallDetected = true;
      stallReason = `identical (screen, primaryCTA, buttons) observed ${sameFingerprintStreak + 1}x in a row at screen="${screen}" — Next Week / action likely not changing GameState`;
      break;
    }

    // Company Setup is handled entirely by its own dedicated, self-verifying
    // submission routine (Codex follow-up §2-6) — it does its own fill,
    // confirm, blur, submit, and transition-wait, with exactly one bounded
    // retry of its own, and never falls through to the generic "click
    // decision.name" path below (which would just be the same silently-
    // retried submit the review flagged). A definitive outcome either way
    // ends this tick.
    if (decision.kind === 'fill-company-setup') {
      const result = await submitCompanySetup(page);
      actionCount++;
      lastActivityAt = Date.now();
      const entry: ActionTraceEntry = {
        action: actionCount,
        elapsedMs: Date.now() - start,
        screen,
        primaryCTA: decision.name,
        primaryCTACount: enabledCount,
        clicked: decision.name,
        advancedWeek: false,
        ...(result.ok ? {} : { diagnostic: result.diagnostic }),
      };
      trace.push(entry);
      if (options.onAction) await options.onAction(entry);
      if (result.ok) {
        previousClickedName = decision.name;
        continue;
      }
      stallDetected = true;
      stallReason = `Company Setup submission failed after ${result.diagnostic.submitAttempt} attempt(s) — input/controller synchronization failure: ${JSON.stringify(result.diagnostic)}`;
      break;
    }

    if (decision.turn) clientInterviewHistory.push(decision.turn);
    if (decision.countsAsClientInterview) clientInterviewCount++;
    if (decision.countsAsSelectionFailure) selectionFailureCount++;
    if (decision.kind === 'reject-candidate') {
      rejectedOnce = true;
      if (decision.candidateName) rejectedCandidateName = decision.candidateName;
    }
    if (decision.kind === 'hire-candidate' && decision.candidateName) {
      acceptedCandidateName = decision.candidateName;
    }

    if (decision.name === previousClickedName) {
      // Same button label as the immediately-preceding action (e.g. "面談へ
      // 進む" both accepting an Interview Request and then, on the very next
      // screen, entering the Upper Company Interview) — legitimately two
      // different screens/widgets, but close enough together that a
      // same-labeled semantics node from the *new* screen can be bound to a
      // BuildContext Flutter hasn't fully settled yet under headless
      // software rendering. A bit of extra breathing room here avoids
      // acting on it mid-settle.
      await page.waitForTimeout(500);
    }
    previousClickedName = decision.name;

    await page.getByRole('button', { name: decision.name, exact: true }).first().click();
    actionCount++;
    lastActivityAt = Date.now();
    if (decision.advancesWeek) weekAdvances++;

    // Wait for the click to actually take effect before reading again —
    // don't just sleep a fixed interval. Headless/software-rendered
    // Chromium can lag well behind real time producing Flutter's next
    // semantics frame; sampling (or worse, clicking again) before that
    // frame lands risks acting on an already-disposed node.
    await waitForSemanticsChange(page, snap);

    const entry: ActionTraceEntry = {
      action: actionCount,
      elapsedMs: Date.now() - start,
      screen,
      primaryCTA: decision.name,
      primaryCTACount: enabledCount,
      clicked: decision.name,
      advancedWeek: decision.advancesWeek,
    };
    trace.push(entry);
    if (options.onAction) await options.onAction(entry);
  }

  return {
    completed,
    firstAssignmentWeek: completed ? weekAdvances + 1 : null,
    actions: actionCount,
    clientInterviewCount,
    selectionFailureCount,
    stallDetected,
    stallReason,
    actionTrace: trace,
    primaryCtaAudit,
    primaryCtaWarnings: primaryCtaAudit.filter((a) => a.warning),
    clientInterviewHistory,
    stageRegressionWarnings,
    rejectedCandidateName,
    acceptedCandidateName,
  };
}

// ---------------------------------------------------------------------
// Company Setup (Codex follow-up §2-6): a dedicated, self-verifying
// submission routine instead of a bare fill()+click() the outer per-tick
// loop would otherwise retry blindly.
//
// Root cause (verified by reproduction, not guessed — see e2e/README.md
// "Findings"): Playwright's `fill()` does a bulk DOM value assignment plus
// one synthetic `input` event. Under slow/resource-constrained conditions
// this can race Flutter Web's TextInputConnection/EditableText sync — the
// DOM `<input>` (and even `inputValue()` right after) can end up *not*
// reflecting what was requested, and even when it does, that alone never
// proves Flutter's own TextEditingController received it (PrologueScreen's
// `_submit()` reads the latter, not the DOM). Reproduced locally via CPU
// throttling: bare `fill()` succeeded as low as 2/10 under 6x throttling;
// real per-character keystrokes (`pressSequentially`) + an explicit blur
// succeeded 10/10 under the identical throttling. This function uses the
// latter.
// ---------------------------------------------------------------------

/** Fills one Company Setup field via real keystrokes and confirms the DOM
 * value landed, retrying up to `maxAttempts` times. Never assumes a single
 * `pressSequentially` call succeeded just because it didn't throw. */
async function fillCompanySetupField(field: Locator, value: string, maxAttempts = 3): Promise<boolean> {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    await field.click();
    // Clear any existing content via select-all + delete — keystroke-based,
    // like the fill itself, rather than fill('') racing the same way.
    await field.press('Control+A').catch(() => {});
    await field.press('Backspace').catch(() => {});
    await field.pressSequentially(value, { delay: 12 });
    const domValue = await field.inputValue().catch(() => null);
    if (domValue === value) return true;
  }
  return false;
}

/** Waits for the Company Setup screen's own marker (its submit button) to
 * actually disappear — a real, screen-specific transition signal, not the
 * generic "any semantics change" `waitForSemanticsChange` uses elsewhere,
 * which a transient focus/animation frame could satisfy without the submit
 * having done anything. */
async function waitForCompanySetupExit(page: Page, maxWaitMs: number): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < maxWaitMs) {
    // readStableSemantics, not a bare snapshotScreen: the same transient-
    // empty-mid-transition frame this fix addresses elsewhere (§3 of the
    // review) could otherwise make a still-in-progress submission look like
    // it already exited, the moment the marker briefly reads as "gone"
    // during an empty frame rather than because the screen actually changed.
    const snap = await readStableSemantics(page, 800);
    if (!isEmptySnapshot(snap) && !hasText(snap, FOUND_COMPANY)) return true;
    await page.waitForTimeout(200);
  }
  return false;
}

async function submitCompanySetup(page: Page): Promise<{ ok: true } | { ok: false; diagnostic: CompanySetupDiagnostic }> {
  const president = page.getByRole('textbox', { name: '社長のお名前' });
  const company = page.getByRole('textbox', { name: '会社名' });
  const submit = page.getByRole('button', { name: FOUND_COMPANY, exact: true }).first();
  const PRESIDENT_NAME = 'E2Eテスト社長';
  const COMPANY_NAME = 'E2Eテスト株式会社';

  let lastDiagnostic: CompanySetupDiagnostic | null = null;

  // Exactly one retry of the *whole* sequence (§5: no unbounded retry of
  // the same submit) — two well-defined, individually-diagnosable attempts.
  for (let submitAttempt = 1; submitAttempt <= 2; submitAttempt++) {
    const presidentFieldConfirmed = await fillCompanySetupField(president, PRESIDENT_NAME);
    const companyFieldConfirmed = await fillCompanySetupField(company, COMPANY_NAME);
    // Commit: Tab off the last field so Flutter's EditableText finalizes
    // the pending TextEditingValue instead of leaving it mid-composition,
    // then give the TextInputConnection round-trip a brief, bounded moment
    // to land before we act on it.
    await company.press('Tab').catch(() => {});
    await page.waitForTimeout(200);

    const presidentNameVisibleValue = (await president.inputValue().catch(() => '')) ?? '';
    const companyNameVisibleValue = (await company.inputValue().catch(() => '')) ?? '';

    let transitionObserved = false;
    if (presidentFieldConfirmed && companyFieldConfirmed) {
      await submit.click();
      transitionObserved = await waitForCompanySetupExit(page, 6_000);
      if (transitionObserved) return { ok: true };
    }

    lastDiagnostic = {
      screen: 'company-setup',
      presidentNameVisibleValue,
      companyNameVisibleValue,
      presidentFieldConfirmed,
      companyFieldConfirmed,
      submitAttempt,
      transitionObserved,
    };
  }

  return { ok: false, diagnostic: lastDiagnostic! };
}

function fingerprintOf(snap: ScreenSnapshot): string {
  return JSON.stringify([snap.texts.slice().sort(), snap.buttons.slice().sort((a, b) => a.name.localeCompare(b.name))]);
}

// How long a *transiently* empty semantics tree gets to recover before it's
// treated as a real, stable state (either a genuine dead-end or — via the
// normal decideAction() fallthrough — an unrecognized-but-populated screen,
// see isEmptySnapshot in helpers/game-state.ts for the distinction this
// exists to draw). Deliberately the same poll cadence
// `waitForSemanticsChange` already used before this fix, just applied to a
// state condition (non-empty reappeared) instead of a fixed sleep.
const SEMANTICS_POLL_INTERVAL_MS = 150;
const EMPTY_SEMANTICS_RECOVERY_MS = 2_000;

/** Reads the accessibility tree, but does not trust a momentarily *empty*
 * result (no texts, no buttons at all) as the screen itself. Reproducibly on
 * WebKit, Flutter Web's semantics tree goes through a completely empty frame
 * mid-route-transition (observed around the recruitment-interview questions
 * / reverse-question screens) before the next real screen's semantics
 * attach — reading during that gap previously got misclassified as
 * `screen="unknown"` with no buttons/text and treated as an immediate
 * dead-end.
 *
 * Bounded polling, not a fixed sleep: returns the instant a non-empty read
 * shows up, and only returns the (still empty) snapshot once
 * `maxWaitMs` has actually elapsed with no recovery — which the caller then
 * legitimately treats as a stable-empty dead-end/unknown candidate. Never
 * retried again beyond this one bounded window (§13 of the review: a truly
 * broken screen must still surface as a failure, not be hidden behind
 * unbounded retry). */
async function readStableSemantics(page: Page, maxWaitMs = EMPTY_SEMANTICS_RECOVERY_MS): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  if (!isEmptySnapshot(snap)) return snap;
  const start = Date.now();
  while (Date.now() - start < maxWaitMs) {
    await page.waitForTimeout(SEMANTICS_POLL_INTERVAL_MS);
    snap = await snapshotScreen(page);
    if (!isEmptySnapshot(snap)) return snap;
  }
  return snap;
}

/** Polls until the accessibility tree actually differs from just before the
 * click — i.e. Flutter produced a new *meaningful* semantics frame reacting
 * to it — instead of sleeping a fixed interval that either wastes time or
 * (worse, under headless software rendering's occasional multi-hundred-ms
 * frame lag) samples/re-clicks a still-stale, about-to-be-disposed node.
 *
 * A transiently empty read is explicitly not accepted as "the transition
 * completed" (§3/§5 of the review — WebKit's non-empty -> empty ->
 * next-screen sequence during route transitions must not be mistaken for
 * "screen changed" the moment it goes empty): it's skipped and polling
 * continues within the same bounded budget, so a recovered non-empty frame
 * later in that same window still gets picked up here rather than only on
 * the caller's *next* tick. Gives up silently after `maxWaitMs` (a screen
 * that legitimately looks identical before and after — e.g. a blocked "次の
 * 週へ" retry, or semantics still stuck empty — must not hang here; the
 * caller's own readStableSemantics + same-fingerprint stall detection
 * handle those cases on the next tick). */
async function waitForSemanticsChange(page: Page, before: ScreenSnapshot, maxWaitMs = 5_000): Promise<void> {
  const start = Date.now();
  const beforeFingerprint = fingerprintOf(before);
  while (Date.now() - start < maxWaitMs) {
    await page.waitForTimeout(150);
    const now = await snapshotScreen(page);
    if (isEmptySnapshot(now)) continue;
    if (fingerprintOf(now) !== beforeFingerprint) {
      // Grace period after the *visible* semantics update: Flutter Web's
      // engine-side pointer/click-listener teardown for the just-disposed
      // route can trail a frame or two behind what the a11y tree already
      // shows, especially under headless software rendering. Clicking again
      // immediately risks hitting that listener mid-teardown.
      await page.waitForTimeout(350);
      return;
    }
  }
}

// How long a genuinely *non-empty* but no-legal-action snapshot gets to
// either become actionable or keep changing before it's treated as a real,
// stable dead-end. Same order of magnitude as EMPTY_SEMANTICS_RECOVERY_MS
// above (§6 of the re-review: keep new timing consistent with what's
// already proven out in this harness) — this is the non-empty counterpart:
// readStableSemantics only ever protects against a *fully empty* tree, not
// a real, populated-but-not-yet-actionable one (e.g. WebKit's genuine
// "応募者が見つかりません" / buttons=[] frame right after a hire decision).
export const NO_ACTION_POLL_INTERVAL_MS = 150;
export const NO_ACTION_STABILITY_WINDOW_MS = 2_000;

export type DeadEndCheck =
  | { status: 'actionable'; snapshot: ScreenSnapshot; screen: ScreenLabel; decision: Decision }
  | { status: 'transitioning'; snapshot: ScreenSnapshot; screen: ScreenLabel; decision: null }
  | { status: 'stable-dead-end'; snapshot: ScreenSnapshot; screen: ScreenLabel; decision: null };

/** Called only once decideAction() has already found no legal action on the
 * current snapshot. Rather than failing on that single read, polls
 * (bounded, driven by the accessibility tree actually changing — never a
 * fixed sleep, never a check on any particular screen or string) for one of
 * three outcomes:
 *
 * - a later read becomes actionable -> `{ status: 'actionable', ... }`,
 *   handing back that snapshot/decision for the caller to act on as normal;
 * - the tree changes to some *other* non-actionable state ->
 *   `{ status: 'transitioning', ... }` — the caller re-enters its own
 *   top-of-loop bookkeeping (idle timeout, same-fingerprint stall
 *   detection, a fresh readStableSemantics) fresh next tick, rather than
 *   this helper accumulating its own unbounded nested wait across however
 *   many further transitions follow (§10 of the re-review: no nested-
 *   timeout complexity — this helper never calls itself or restarts its
 *   own window);
 * - the snapshot stays byte-identical to the one decideAction already
 *   failed on for the *entire* bounded window -> `{ status:
 *   'stable-dead-end', ... }` — a real, confirmed-stable dead-end
 *   candidate, not hidden behind further retry. */
export async function waitForActionableOrStableDeadEnd(
  page: Page,
  initialSnapshot: ScreenSnapshot,
  decideOpts: { forceRejectFirstCandidate: boolean },
  maxWaitMs = NO_ACTION_STABILITY_WINDOW_MS,
): Promise<DeadEndCheck> {
  const initialFingerprint = fingerprintOf(initialSnapshot);
  const start = Date.now();
  while (Date.now() - start < maxWaitMs) {
    await page.waitForTimeout(NO_ACTION_POLL_INTERVAL_MS);
    const snap = await readStableSemantics(page);
    const decision = decideAction(snap, decideOpts);
    if (decision) {
      return { status: 'actionable', snapshot: snap, screen: classifyScreen(snap), decision };
    }
    if (fingerprintOf(snap) !== initialFingerprint) {
      // Still transitioning (into some other non-actionable state) rather
      // than stuck — bail out to the caller's own per-tick loop instead of
      // restarting this same bounded window over again here.
      return { status: 'transitioning', snapshot: snap, screen: classifyScreen(snap), decision: null };
    }
  }
  return { status: 'stable-dead-end', snapshot: initialSnapshot, screen: classifyScreen(initialSnapshot), decision: null };
}

interface Decision {
  name: string;
  kind: 'click' | 'fill-company-setup' | 'reject-candidate' | 'hire-candidate';
  advancesWeek: boolean;
  /** Recorded into clientInterviewHistory verbatim when set. */
  turn?: ClientInterviewTurn;
  /** Counts this action as one Client-Interview round (§10/§18: clientInterviewCount). */
  countsAsClientInterview?: boolean;
  /** Counts this action as one Selection failure (§18: selectionFailureCount). */
  countsAsSelectionFailure?: boolean;
  /** Set on reject-candidate/hire-candidate decisions (§12 of the Codex
   * follow-up) — the candidate's name as read off-screen at that moment. */
  candidateName?: string | null;
}

function decideAction(snap: ScreenSnapshot, opts: { forceRejectFirstCandidate: boolean }): Decision | null {
  // 1. A blocking AlertDialog always wins — nothing else on screen is
  //    interactable while it's open (Playable 0.5A.1's post-decision
  //    dialog: "内定承諾！" / "内定辞退" / "不採用").
  const dialogBack = enabledButton(snap, DIALOG_BACK);
  if (dialogBack) return { name: DIALOG_BACK, kind: 'click', advancesWeek: false };

  // 2. New-game entry point.
  const start = enabledButton(snap, START_GAME);
  if (start) return { name: START_GAME, kind: 'click', advancesWeek: false };

  // 3. President/company naming.
  if (hasText(snap, FOUND_COMPANY)) {
    const found = enabledButton(snap, FOUND_COMPANY);
    if (found) return { name: FOUND_COMPANY, kind: 'fill-company-setup', advancesWeek: false };
  }

  // 4. Founding intro carousel — "次へ" only ever appears here, never
  //    alongside a further-along stage's own buttons, so a bare presence
  //    check is unambiguous.
  const introNext = anyEnabledButton(snap, INTRO_NEXT);
  if (introNext) return { name: introNext.name, kind: 'click', advancesWeek: false };

  // 5. March Week 1: recruitment medium (multi-choice by design).
  const media = enabledButton(snap, MEDIA_POST);
  if (media) return { name: MEDIA_POST, kind: 'click', advancesWeek: false };

  // 6. March Week 2: candidate interview pick, "1 per week" gate respected —
  //    falls through to "次の週へ" below when both candidates are blocked.
  const interview = enabledButton(snap, CANDIDATE_INTERVIEW);
  if (interview) return { name: CANDIDATE_INTERVIEW, kind: 'click', advancesWeek: false };

  // 7. Recruitment-interview questions (3 of 6 categories) / reverse
  //    question / decision summary — all live inside PrologueInterviewScreen.
  if (hasText(snap, '面接まとめ')) {
    const wantsReject = opts.forceRejectFirstCandidate;
    const name = wantsReject ? REJECT_CANDIDATE : HIRE_CANDIDATE;
    const btn = enabledButton(snap, name);
    const candidateName = extractInterviewCandidateName(snap);
    if (btn) return { name, kind: wantsReject ? 'reject-candidate' : 'hire-candidate', advancesWeek: false, candidateName };
  }
  if (hasText(snap, '応募者からの質問')) {
    // Reverse question: any of the FilledButton.tonal answer choices is a
    // legal, always-available response — first one, deterministically.
    const choice = snap.buttons.find((b) => b.enabled && b.name !== DIALOG_BACK);
    if (choice) return { name: choice.name, kind: 'click', advancesWeek: false };
  }
  if (/質問\s*\d+\s*\/\s*3/.test(snap.texts.join(' '))) {
    const choice = snap.buttons.find((b) => b.enabled);
    if (choice) return { name: choice.name, kind: 'click', advancesWeek: false };
  }

  // 8. March Week 3: SkillSheet confirmation, then pre-joining sales.
  const skillSheet = enabledButton(snap, SKILLSHEET_CONFIRM);
  if (skillSheet) return { name: SKILLSHEET_CONFIRM, kind: 'click', advancesWeek: false };
  const sales = enabledButton(snap, SALES_START);
  if (sales) return { name: SALES_START, kind: 'click', advancesWeek: false };

  // 9. March Week 4: interview request -> upper company interview (manual,
  //    player-attended, §10 of the E2E brief) -> client interview
  //    (auto-resolved by design — the president isn't present, per the
  //    NavigatorCard copy) -> contract.
  const proceed = enabledButton(snap, PROCEED_TO_INTERVIEW);
  if (proceed) return { name: PROCEED_TO_INTERVIEW, kind: 'click', advancesWeek: false };

  // Upper Company Interview question card (ClientInterviewScreen) — the one
  // manual, player-attended selection step in the Prologue (§10 of the E2E
  // brief). Fixed rule: always let the employee's own answer stand ("本人の
  //回答に任せる") when offered, otherwise the first legal follow-up choice.
  const followUp =
    enabledButton(snap, '本人の回答に任せる') ?? CLIENT_INTERVIEW_FOLLOWUP_LABELS.map((label) => enabledButton(snap, label)).find(Boolean);
  if (followUp && hasText(snap, '面接官')) {
    const question = snap.texts.find((t) => t.startsWith('「')) ?? null;
    const turn: ClientInterviewTurn = { step: 'upper-company', question, employeeAnswer: null, playerFollowUp: followUp.name, result: 'pending' };
    return { name: followUp.name, kind: 'click', advancesWeek: false, turn, countsAsClientInterview: true };
  }

  // Upper Company Interview result page (ClientInterviewScreen's _Result —
  // AppBar title "上位会社面談結果", but Flutter Web merges adjacent Text
  // widgets into one semantics node, so the body's "合格"/"不合格" text and
  // the AppBar title don't reliably land in the same a11y-tree entry;
  // detected instead by "続ける" + a pass/fail word present *without* the
  // auto client-interview reveal's distinctive "客先面談" prefix, which is
  // checked first below). Its "続ける" only pops back into the scripted flow
  // (Navigator.pop) — it does NOT call PrologueEngine.advanceWeek. A failed
  // round recovers later via the ordinary "次の週へ" fallback (rule 10) once
  // PrologueScreen re-derives week4AwaitingRequest, exactly like a real
  // player would experience it.
  if (!hasText(snap, '客先面談') && (hasText(snap, '合格') || hasText(snap, '不合格'))) {
    const cont = enabledButton(snap, CONTINUE);
    if (cont) {
      const passed = hasText(snap, '合格') && !hasText(snap, '不合格');
      const turn: ClientInterviewTurn = { step: 'upper-company', question: null, employeeAnswer: null, playerFollowUp: null, result: passed ? 'passed' : 'failed' };
      return { name: CONTINUE, kind: 'click', advancesWeek: false, turn, countsAsSelectionFailure: !passed };
    }
  }

  const revealClient = enabledButton(snap, REVEAL_CLIENT_RESULT);
  if (revealClient) return { name: REVEAL_CLIENT_RESULT, kind: 'click', advancesWeek: false };
  if (hasText(snap, '客先面談') && (hasText(snap, '合格') || hasText(snap, '不合格'))) {
    const cont = enabledButton(snap, CONTINUE);
    if (cont) {
      const passed = hasText(snap, '合格') && !hasText(snap, '不合格');
      const turn: ClientInterviewTurn = { step: 'client', question: null, employeeAnswer: null, playerFollowUp: null, result: passed ? 'passed' : 'failed' };
      return { name: CONTINUE, kind: 'click', advancesWeek: true, turn, countsAsSelectionFailure: !passed };
    }
  }

  // 10. Generic waiting-state fallback ("今週やる操作はありません" — §9):
  //     always legal whenever it's on screen, never a dead-end by itself.
  const nextWeek = enabledButton(snap, NEXT_WEEK);
  if (nextWeek) return { name: NEXT_WEEK, kind: 'click', advancesWeek: true };

  // 11. End of the scripted flow.
  const begin = enabledButton(snap, BEGIN_MANAGEMENT);
  if (begin) return { name: BEGIN_MANAGEMENT, kind: 'click', advancesWeek: false };

  return null;
}
