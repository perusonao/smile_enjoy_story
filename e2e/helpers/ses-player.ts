// The "初見プレイヤー" (first-time player) simulator (§6 of the E2E brief).
//
// Each tick: read the screen (game-state.ts), then do whatever the Guided
// Founding UI is currently presenting as the thing to do — its Primary CTA,
// a pending interview/selection/offer step, or "次の週へ" when the screen is
// legitimately just waiting. Never taps blindly; every rule below maps to a
// concrete, currently-enabled button already rendered by production UI.
import type { Page } from '@playwright/test';
import {
  anyEnabledButton,
  classifyScreen,
  CLIENT_INTERVIEW_FOLLOWUP_LABELS,
  enabledButton,
  hasText,
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
  let previousClickedName: string | null = null;
  let lastFingerprint = '';
  let sameFingerprintStreak = 0;
  let highestSeenStage = -1;
  let lastActivityAt = Date.now();

  let completed = false;
  let stallDetected = false;
  let stallReason: string | null = null;

  while (true) {
    if (completed) break;
    if (actionCount >= options.maxActions) {
      stallDetected = true;
      stallReason = `max actions (${options.maxActions}) exceeded without reaching first assignment`;
      break;
    }
    if (weekAdvances > options.maxWeeks) {
      stallDetected = true;
      stallReason = `max weeks (${options.maxWeeks}) exceeded without reaching first assignment`;
      break;
    }
    if (Date.now() - lastActivityAt > options.idleTimeoutMs) {
      stallDetected = true;
      stallReason = `no legal action found for ${options.idleTimeoutMs}ms (dead-end)`;
      break;
    }

    const snap = await snapshotScreen(page);
    const screen = classifyScreen(snap);

    if (options.onScreen) await options.onScreen(screen, snap);

    if (screen === 'complete' || hasText(snap, '初案件参画')) {
      completed = true;
      trace.push({ action: actionCount + 1, elapsedMs: Date.now() - start, screen, primaryCTA: null, primaryCTACount: 0, clicked: '(observed completion)', advancedWeek: false });
      if (options.onAction) await options.onAction(trace[trace.length - 1]);
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

    const decision = decideAction(snap, {
      forceRejectFirstCandidate: !!options.forceRejectFirstCandidate && !rejectedOnce,
    });

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
      stallReason = `dead-end at screen="${screen}": no Primary CTA, no pending event, and no "次の週へ" available. Visible buttons: [${snap.buttons.map((b) => `${b.name}${b.enabled ? '' : '(disabled)'}`).join(', ')}]. Visible text: ${JSON.stringify(snap.texts)}`;
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

    if (decision.kind === 'fill-company-setup') {
      // getByRole('textbox', ...), not getByLabel — the surrounding
      // NavigatorCard's own semantics group repeats these field labels in
      // its message text, so getByLabel's substring match resolves to both
      // the group and the input.
      //
      // Verified, not fire-and-forget: _submit() silently no-ops if either
      // field reads empty, and an occasional fill() not landing before the
      // very first click (observed under this sandbox's flaky font-fetch
      // network conditions) would otherwise look identical to a genuine
      // dead-end — retry a few times rather than misreport one as the other.
      const president = page.getByRole('textbox', { name: '社長のお名前' });
      const company = page.getByRole('textbox', { name: '会社名' });
      for (let attempt = 0; attempt < 3; attempt++) {
        await president.fill('E2Eテスト社長');
        await company.fill('E2Eテスト株式会社');
        const [presidentValue, companyValue] = await Promise.all([president.inputValue(), company.inputValue()]);
        if (presidentValue === 'E2Eテスト社長' && companyValue === 'E2Eテスト株式会社') break;
      }
    }
    if (decision.turn) clientInterviewHistory.push(decision.turn);
    if (decision.countsAsClientInterview) clientInterviewCount++;
    if (decision.countsAsSelectionFailure) selectionFailureCount++;
    if (decision.kind === 'reject-candidate') rejectedOnce = true;

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
  };
}

function fingerprintOf(snap: ScreenSnapshot): string {
  return JSON.stringify([snap.texts.slice().sort(), snap.buttons.slice().sort((a, b) => a.name.localeCompare(b.name))]);
}

/** Polls until the accessibility tree actually differs from just before the
 * click — i.e. Flutter produced a new semantics frame reacting to it —
 * instead of sleeping a fixed interval that either wastes time or (worse,
 * under headless software rendering's occasional multi-hundred-ms frame
 * lag) samples/re-clicks a still-stale, about-to-be-disposed node. Gives up
 * silently after `maxWaitMs` (a screen that legitimately looks identical
 * before and after — e.g. a blocked "次の週へ" retry — must not hang here;
 * the caller's own same-fingerprint stall detection handles that case). */
async function waitForSemanticsChange(page: Page, before: ScreenSnapshot, maxWaitMs = 5_000): Promise<void> {
  const start = Date.now();
  const beforeFingerprint = fingerprintOf(before);
  while (Date.now() - start < maxWaitMs) {
    await page.waitForTimeout(150);
    const now = await snapshotScreen(page);
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

interface Decision {
  name: string;
  kind: 'click' | 'fill-company-setup' | 'reject-candidate';
  advancesWeek: boolean;
  /** Recorded into clientInterviewHistory verbatim when set. */
  turn?: ClientInterviewTurn;
  /** Counts this action as one Client-Interview round (§10/§18: clientInterviewCount). */
  countsAsClientInterview?: boolean;
  /** Counts this action as one Selection failure (§18: selectionFailureCount). */
  countsAsSelectionFailure?: boolean;
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
    if (btn) return { name, kind: wantsReject ? 'reject-candidate' : 'click', advancesWeek: false };
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
