// Reads the *rendered UI* of the Founding Prologue (Guided Founding) and
// turns it into a decision the auto-player can act on.
//
// Deliberately does not read any internal Dart/GameState value — S.E.S.
// exposes no debug bridge on purpose (see e2e/README.md "Why no debug
// API"), so everything here is inferred from what a first-time player would
// actually see: button labels and on-screen text, read through Flutter Web's
// accessibility/semantics tree (enabled via `?e2e=1`, see lib/main.dart).
import type { Page } from '@playwright/test';

export interface ButtonInfo {
  name: string;
  enabled: boolean;
}

export interface ScreenSnapshot {
  /** All texts (buttons, headings, body copy) currently in the a11y tree. */
  texts: string[];
  buttons: ButtonInfo[];
}

// Matches one ariaSnapshot() line, e.g.:
//   - button "この方法で募集する"
//   - button "面接する" [disabled]
//   - text: 応募者が2名届きました。
// Playwright's ariaSnapshot() is the supported replacement for the removed
// `page.accessibility.snapshot()` API (Playwright >= ~1.50).
const ARIA_LINE = /^-\s*([a-zA-Z]+)(?::\s*(.*)|\s+"((?:[^"\\]|\\.)*)")?\s*(\[disabled\])?\s*$/;

// Two always-there pieces of chrome, excluded at the source so no decision
// rule can ever pick them by accident and so they don't inflate the
// Primary-CTA audit's enabled-button count on every single screen:
//  - Flutter Web's auto-inserted AppBar back arrow (present on every pushed
//    route: PrologueInterviewScreen, ClientInterviewScreen) — popping the
//    route is never the right Guided Founding action.
//  - PrologueScreen's own AppBar "最初からやり直す" reset icon — always
//    present, on purpose (Playable 0.5A.1 §7), on every single Prologue
//    screen; a real Primary-CTA-count audit needs to look past it, not
//    flag every screen in the game as "too many choices".
const CHROME_BUTTON_NAME = /^((back\s*)+|最初からやり直す)$/i;

/** Reads the full accessibility tree in one round-trip, via ariaSnapshot(). */
export async function snapshotScreen(page: Page): Promise<ScreenSnapshot> {
  const raw = await page.locator('body').ariaSnapshot();
  const texts: string[] = [];
  const buttons: ButtonInfo[] = [];
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('-')) continue;
    const m = ARIA_LINE.exec(trimmed);
    if (!m) continue;
    const role = m[1];
    const name = (m[3] ?? m[2] ?? '').replace(/\\"/g, '"').trim();
    if (!name || CHROME_BUTTON_NAME.test(name)) continue;
    if (role === 'button') {
      buttons.push({ name, enabled: !m[4] });
    } else {
      texts.push(name);
    }
  }
  return { texts, buttons };
}

export function hasText(snap: ScreenSnapshot, needle: string): boolean {
  return snap.texts.some((t) => t.includes(needle)) || snap.buttons.some((b) => b.name.includes(needle));
}

export function enabledButton(snap: ScreenSnapshot, name: string): ButtonInfo | undefined {
  return snap.buttons.find((b) => b.name === name && b.enabled);
}

export function anyEnabledButton(snap: ScreenSnapshot, names: string[]): ButtonInfo | undefined {
  for (const name of names) {
    const b = enabledButton(snap, name);
    if (b) return b;
  }
  return undefined;
}

/** Known Client-Interview follow-up choices (labels straight from
 * lib/game/engine/client_interview_content.dart's clientInterviewFollowUpLabels
 * — kept here only for *label matching*, not for re-implementing any of the
 * engine's own evaluation logic). */
export const CLIENT_INTERVIEW_FOLLOWUP_LABELS = [
  '本人の回答に任せる',
  '技術面の担当範囲を補足する',
  '業界知識を補足する',
  '顧客との調整経験を補足する',
  'リーダー経験を補足する',
  '主担当ではないと期待値を調整する',
];

/** Approximate "ideal" Guided-Founding screen order, used only for the
 * best-effort Tutorial/GameState consistency check (§12 of the E2E brief):
 * if a later-stage screen was already seen and then an *earlier* one
 * reappears (other than the legitimate retry loops the engine itself
 * documents — candidate re-selection, interview-request retry), that is
 * reported as a `stageRegressionWarnings` entry, never a hard failure. */
export const SCREEN_ORDER = [
  'start-choice',
  'company-setup',
  'intro',
  'recruitment-media-select',
  'candidate-select',
  'recruitment-interview',
  'skill-sheet-confirm',
  'sales-start',
  'interview-request',
  'upper-interview',
  'client-interview',
  'contract',
  'complete',
] as const;
export type ScreenLabel = (typeof SCREEN_ORDER)[number] | 'unknown';

/** Screens where more than one enabled action is legitimate by design
 * (§7 — "仕様上正当な複数選択肢") so a Primary-CTA-count > 1 there is
 * expected, not a warning. */
export const MULTI_CHOICE_SCREENS: ReadonlySet<ScreenLabel> = new Set([
  'recruitment-media-select',
  'candidate-select',
  'recruitment-interview',
  'client-interview',
]);

export function classifyScreen(snap: ScreenSnapshot): ScreenLabel {
  if (hasText(snap, '初案件参画')) return 'complete';
  if (hasText(snap, '契約成立')) return 'contract';
  // The auto-resolved final Client Interview (_ClientInterviewAuto) always
  // carries a "客先面談" prefix in its NavigatorCard copy — checked before
  // the generic pass/fail check below so it isn't misread as the Upper
  // Company Interview's own result page.
  if (hasText(snap, '客先面談')) return 'client-interview';
  // ClientInterviewScreen (Upper Company Interview): its question card
  // ("面接官") or result page. The result page's AppBar title
  // ("上位会社面談結果") isn't reliably captured as separate a11y-tree text
  // (Flutter Web merges adjacent Text widgets into one semantics node), so
  // a bare pass/fail word is the fallback signal — safe here since the
  // "客先面談" case above is already excluded.
  if (hasText(snap, '面接官') || hasText(snap, '合格') || hasText(snap, '不合格')) return 'upper-interview';
  if (hasText(snap, '面談へ進む') && hasText(snap, '上位会社')) return 'upper-interview';
  if (hasText(snap, '面談依頼が届きました')) return 'interview-request';
  if (hasText(snap, '営業を開始する')) return 'sales-start';
  if (hasText(snap, 'SkillSheetを確認しました') || hasText(snap, 'SkillSheet(営業用経歴)')) return 'skill-sheet-confirm';
  if (hasText(snap, '面接まとめ') || hasText(snap, '応募者からの質問') || /質問\s*\d+\s*\/\s*3/.test(snap.texts.join(' '))) return 'recruitment-interview';
  if (hasText(snap, '面接する') || hasText(snap, '応募者が')) return 'candidate-select';
  if (hasText(snap, 'この方法で募集する') || hasText(snap, '無料求人')) return 'recruitment-media-select';
  if (hasText(snap, '会社を設立する')) return 'company-setup';
  if (hasText(snap, '【初心者モード】')) return 'start-choice';
  if (hasText(snap, '次へ') || hasText(snap, '次へ進む')) return 'intro';
  return 'unknown';
}
