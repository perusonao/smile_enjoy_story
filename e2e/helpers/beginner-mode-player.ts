// Phase 3A driver (S.E.S. Development Plan §3.2): continues a Playwright
// playthrough from the Founding Prologue's completion screen through Home
// for April-June (fiscal weeks 1-12), understanding Beginner Mode's *own*
// semantics (its one-time teaching dialogs, the "重要事項"/"客先面談が残っ
// ています" confirmations, a celebration dialog that navigates to another
// tab) instead of falling back to "click anything enabled" once
// `playFoundingToFirstAssignment` (helpers/ses-player.ts) hands off.
//
// Same principles as ses-player.ts: never taps blindly, every rule maps to
// a concrete, currently-enabled, real production button; Failure Recovery
// (a rejected candidate, a declined offer, a quiet no-action week) must
// never look like a dead end.
import type { Page } from '@playwright/test';
import { firstEnabledDialogButton, hasText, snapshotScreen, type ScreenSnapshot } from './game-state';

export interface BeginnerModeMilestones {
  managementPhaseStarted: boolean;
  revenueVsCashExplained: boolean;
  waitingCostExplained: boolean;
  firstCollectionCelebrated: boolean;
  recruitmentTradeoffExplained: boolean;
}

export interface BeginnerModePlayResult {
  completed: boolean;
  finalWeek: number | null;
  actions: number;
  stallDetected: boolean;
  stallReason: string | null;
  milestones: BeginnerModeMilestones;
}

export interface BeginnerModePlayOptions {
  /** Stop once `state.week` reaches this value (12 = end of June). */
  targetWeek: number;
  maxActions: number;
  idleTimeoutMs: number;
  onScreen?: (snap: ScreenSnapshot, week: number | null) => Promise<void> | void;
}

const NEXT_WEEK = '次の週へ';
const BEGIN_MANAGEMENT = '経営を始める';
const HOME_TAB = 'ホーム';
const CLOSE_LABELS = ['閉じる', 'OK', '会社状況を見る', '面談依頼を見る', '採用を見る', '社員環境を見る'];
const PROCEED_DESPITE_CRITICAL = 'それでも進む';
const LET_EMPLOYEE_HANDLE = '技術者に任せて進む';
const DIALOG_BACK = '戻る';

// Case-insensitive: ManagementHud's own semantics label uses "WEEK N"
// (lib/ui/widgets/management_hud.dart), Home's AppBar uses "Week N / 48"
// (lib/ui/home/home_screen.dart) — both single-line, both worth matching.
const WEEK_RE = /week\s*(\d+)/i;

function currentWeek(snap: ScreenSnapshot): number | null {
  // ManagementHud renders its whole row as one semantics *button* (it's
  // tappable, opening the finance breakdown sheet) — the week number lives
  // in `buttons`, not `texts`, so both must be scanned.
  for (const t of [...snap.texts, ...snap.buttons.map((b) => b.name)]) {
    const m = WEEK_RE.exec(t);
    if (m) return Number(m[1]);
  }
  return null;
}

function enabled(snap: ScreenSnapshot, name: string) {
  return snap.buttons.find((b) => b.name === name && b.enabled);
}

/** Home's own Next Week button carries the week range in its own label
 * (e.g. "次の週へ (Week 1 → 2)", lib/ui/home/home_screen.dart) — unlike the
 * Prologue's plain "次の週へ", so this needs a prefix match instead of
 * `enabled()`'s exact one. */
function enabledNextWeek(snap: ScreenSnapshot) {
  return snap.buttons.find((b) => b.enabled && b.name.startsWith(NEXT_WEEK));
}

/** Reads the milestone dialogs/card this playthrough has already surfaced,
 * purely from on-screen text — never GameState (see e2e/README.md "Why no
 * debug API"). Best-effort: a milestone whose dialog was shown and
 * dismissed before this particular read won't retroactively appear here,
 * which is fine — callers OR this in as the run progresses. */
function observeMilestones(snap: ScreenSnapshot, acc: BeginnerModeMilestones): BeginnerModeMilestones {
  return {
    managementPhaseStarted: acc.managementPhaseStarted || hasText(snap, '初心者経営編') || hasText(snap, '初心者経営期間'),
    revenueVsCashExplained: acc.revenueVsCashExplained || hasText(snap, '売上が発生しました') || hasText(snap, '契約成立') || hasText(snap, '初案件参画'),
    waitingCostExplained: acc.waitingCostExplained || hasText(snap, '待機社員にも給与が発生しています'),
    firstCollectionCelebrated: acc.firstCollectionCelebrated || hasText(snap, '初入金'),
    recruitmentTradeoffExplained: acc.recruitmentTradeoffExplained || hasText(snap, '採用のトレードオフ'),
  };
}

/** Drives Home from right after the Founding Prologue completes (taps
 * "経営を始める" if it's still on screen) through week `targetWeek`,
 * handling Beginner Mode's own one-time dialogs and the existing "重要事項
 * が残っています" / "客先面談が残っています" confirmations along the way. */
export async function playBeginnerModeThroughJune(page: Page, options: BeginnerModePlayOptions): Promise<BeginnerModePlayResult> {
  let actions = 0;
  let milestones: BeginnerModeMilestones = {
    managementPhaseStarted: false,
    revenueVsCashExplained: false,
    waitingCostExplained: false,
    firstCollectionCelebrated: false,
    recruitmentTradeoffExplained: false,
  };
  let lastActivityAt = Date.now();
  let lastFingerprint = '';
  let sameFingerprintStreak = 0;
  let week: number | null = null;

  while (true) {
    const snap = await snapshotScreen(page);
    milestones = observeMilestones(snap, milestones);
    const w = currentWeek(snap);
    if (w !== null) week = w;
    if (options.onScreen) await options.onScreen(snap, week);

    // Strictly *past* targetWeek, not merely reaching it: the target
    // week's own month-end close (salary/rent payment, and any AR whose
    // payment site lands exactly on it — e.g. a 60-day term generated in
    // April is due at June's close) only actually runs on the click that
    // advances *out* of that week. Stopping the instant `week` first reads
    // 12 would skip observing June's own close entirely.
    if (week !== null && week > options.targetWeek) {
      return { completed: true, finalWeek: week, actions, stallDetected: false, stallReason: null, milestones };
    }
    if (actions >= options.maxActions) {
      return { completed: false, finalWeek: week, actions, stallDetected: true, stallReason: `max actions (${options.maxActions}) exceeded before reaching week ${options.targetWeek}`, milestones };
    }
    if (Date.now() - lastActivityAt > options.idleTimeoutMs) {
      return {
        completed: false,
        finalWeek: week,
        actions,
        stallDetected: true,
        stallReason: `no legal action found for ${options.idleTimeoutMs}ms at week ${week} — buttons: [${snap.buttons.map((b) => `${b.name}${b.enabled ? '' : '(disabled)'}`).join(', ')}]`,
        milestones,
      };
    }

    let clicked: string | null = null;
    let usesRoleTab = false;

    // 1. A blocking dialog wins first, same ordering as ses-player.ts.
    const begin = enabled(snap, BEGIN_MANAGEMENT);
    const proceedCritical = enabled(snap, PROCEED_DESPITE_CRITICAL);
    const letEmployeeHandle = enabled(snap, LET_EMPLOYEE_HANDLE);
    // dialog-scoped only (Home layout整理 follow-up, PR #22 root cause):
    // CLOSE_LABELS's own strings ("採用を見る" in particular) can now also
    // be a real, non-dialog Home CTA's exact button text (`_HeroTaskCard`),
    // so a bare name match against `snap.buttons` is no longer sufficient
    // to say "this is a dialog's dismiss button" — `firstEnabledDialogButton`
    // additionally requires the match to be nested under an actual
    // `dialog`/`alertdialog` a11y node (see `dialogButtonNames`'s own doc
    // comment in game-state.ts).
    const closeLabel = firstEnabledDialogButton(snap, CLOSE_LABELS)?.name;
    const back = enabled(snap, DIALOG_BACK);
    const next = enabledNextWeek(snap);

    if (begin) {
      clicked = BEGIN_MANAGEMENT;
    } else if (proceedCritical) {
      // "重要事項が残っています" confirm — Beginner Mode still lets the
      // player see everything critical first (Home's own Critical section);
      // the driver proceeds so a genuine multi-week playthrough isn't
      // blocked by, e.g., a still-pending Offer deadline notice.
      clicked = PROCEED_DESPITE_CRITICAL;
    } else if (letEmployeeHandle) {
      clicked = LET_EMPLOYEE_HANDLE;
    } else if (closeLabel && !next) {
      // `closeLabel` is already dialog-scoped (above) — this `!next` check
      // is now a second, redundant-by-design safety net, not the only line
      // of defense: even if a background route's semantics ever leaked
      // "次の週へ" into the same snapshot as an open dialog, an *unscoped*
      // name match could never reach here as `closeLabel` in the first
      // place.
      clicked = closeLabel;
    } else if (next) {
      clicked = next.name;
    } else if (back) {
      clicked = DIALOG_BACK;
    } else {
      // Got navigated off Home by a celebration dialog's tap-through
      // (interviewOfferCelebration/recruitmentUnlockCelebration/
      // welfareUnlockCelebration all do this) — return to Home instead of
      // wandering another tab's screen looking for "次の週へ".
      const homeTab = page.getByRole('tab', { name: HOME_TAB, exact: true });
      if (await homeTab.count()) {
        clicked = HOME_TAB;
        usesRoleTab = true;
      }
    }

    if (!clicked) {
      return {
        completed: false,
        finalWeek: week,
        actions,
        stallDetected: true,
        stallReason: `dead-end at week ${week}: no recognized action. buttons=[${snap.buttons.map((b) => `${b.name}${b.enabled ? '' : '(disabled)'}`).join(', ')}] texts=${JSON.stringify(snap.texts).slice(0, 400)}`,
        milestones,
      };
    }

    const fingerprint = `${week}|${clicked}|${snap.buttons.map((b) => `${b.name}:${b.enabled}`).sort().join(',')}`;
    if (fingerprint === lastFingerprint) {
      sameFingerprintStreak++;
    } else {
      sameFingerprintStreak = 0;
      lastFingerprint = fingerprint;
    }
    if (sameFingerprintStreak >= 6) {
      return { completed: false, finalWeek: week, actions, stallDetected: true, stallReason: `identical (week, action, buttons) observed ${sameFingerprintStreak + 1}x at week ${week} — Next Week likely not changing GameState`, milestones };
    }

    if (usesRoleTab) {
      await page.getByRole('tab', { name: HOME_TAB, exact: true }).click();
    } else {
      await page.getByRole('button', { name: clicked, exact: true }).first().click();
    }
    actions++;
    lastActivityAt = Date.now();
    await page.waitForTimeout(250);
    // Bounded settle-wait for the click's effect (a week advance can pop a
    // monthly-closing dialog, then a week-summary dialog, then a Beginner
    // Mode milestone dialog, in sequence) — polls instead of one fixed
    // sleep, same spirit as ses-player.ts's waitForSemanticsChange.
    const before = JSON.stringify(snap);
    for (let i = 0; i < 20; i++) {
      const now = await snapshotScreen(page);
      if (JSON.stringify(now) !== before) break;
      await page.waitForTimeout(200);
    }
  }
}
