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
//   - heading "中村 翔太との面接" [level=2]
// Playwright's ariaSnapshot() is the supported replacement for the removed
// `page.accessibility.snapshot()` API (Playwright >= ~1.50).
//
// The trailing-annotations group captures *any* number of `[...]` tags
// (`[level=2]`, `[checked]`, `[disabled]`, ...), not just `[disabled]` —
// an earlier version anchored the whole line to `[disabled]?` specifically,
// so any OTHER bracket annotation (most commonly a heading's `[level=N]`)
// made the regex fail to match at all, silently dropping that entire line
// from both `texts` and `buttons`. Found via the Codex follow-up's
// candidate-identity check turning up `null` for a screen whose heading
// visibly had the name.
//
// The trailing `:?` (Playable 0.4C.4 investigation) handles a named/quoted
// node that itself has children in the tree — e.g. a `group "..."` whose
// accessible name is a whole merged card of text with a `button` nested
// under it (exactly what Flutter Web produces for
// FirstContractCelebration's headline + breakdown + CTA, all merged into
// one semantics node). ariaSnapshot() prints that as `- group "...":`
// followed by indented children lines; without this, the trailing `:`
// left the line unmatched, so the whole line — including the "初案件参画"
// text used to detect Prologue completion — was silently dropped, the same
// failure mode the comment above already describes for `[level=N]`.
const ARIA_LINE = /^-\s*([a-zA-Z]+)(?::\s*(.*?)|\s+"((?:[^"\\]|\\.)*)")?\s*((?:\[[a-zA-Z]+(?:=[^\]]*)?\]\s*)*):?$/;

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

/** Pure line-parser for Playwright's `ariaSnapshot()` YAML-ish text output —
 * split out from {@link snapshotScreen} so this parsing logic (the actual
 * source of two real bugs found so far: the `[level=N]` annotation gap and
 * the trailing-`:`-on-a-parent-with-children gap) is unit-testable without
 * a real Page/browser (see `tests/game-state.ariaParsing.spec.ts`). */
export function parseAriaSnapshot(raw: string): ScreenSnapshot {
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
      buttons.push({ name, enabled: !/\[disabled\]/.test(m[4] ?? '') });
    } else {
      texts.push(name);
    }
  }
  return { texts, buttons };
}

/** Reads the full accessibility tree in one round-trip, via ariaSnapshot(). */
export async function snapshotScreen(page: Page): Promise<ScreenSnapshot> {
  const raw = await page.locator('body').ariaSnapshot();
  return parseAriaSnapshot(raw);
}

export function hasText(snap: ScreenSnapshot, needle: string): boolean {
  return snap.texts.some((t) => t.includes(needle)) || snap.buttons.some((b) => b.name.includes(needle));
}

/** A snapshot with no texts and no buttons at all — the shape Flutter Web's
 * semantics tree transiently produces mid-route-transition (observed on
 * WebKit; see `readStableSemantics` in helpers/ses-player.ts), never a
 * legitimate screen a real player would see. Distinct from "unknown": an
 * `unknown` classification can still carry real (non-empty) semantics the
 * classifier just doesn't recognize. */
export function isEmptySnapshot(snap: ScreenSnapshot): boolean {
  return snap.texts.length === 0 && snap.buttons.length === 0;
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
  'start-choice', // 【初心者モード】 vs 【自由モード】 — a real, legitimate choice, not a design flaw.
  'recruitment-media-select',
  'candidate-select',
  'recruitment-interview',
  'client-interview',
  // 会社を設立する (found immediately with the pre-filled random defaults)
  // vs 名前を再生成 (re-roll both fields first) — Playable 0.4C.2 §5, both
  // real and always legal on this screen, not a design flaw.
  'company-setup',
]);

// PrologueInterviewScreen's AppBar title is literally "${applicant.name}
// との面接" (lib/ui/prologue/prologue_interview_screen.dart) — exactly what
// a first-time player reads on screen, not an internal GameState value.
const INTERVIEW_TITLE = /^(.+?)との面接$/;

/** Best-effort extraction of the currently-interviewed candidate's name
 * from the recruitment-interview screen's own semantics text (§12 of the
 * Codex follow-up: Failure Recovery candidate identity). `null` when not
 * on that screen or the title isn't present in the a11y tree for any
 * reason — callers must treat that as "unknown", never guess. */
export function extractInterviewCandidateName(snap: ScreenSnapshot): string | null {
  for (const t of snap.texts) {
    const m = INTERVIEW_TITLE.exec(t);
    if (m) return m[1];
  }
  return null;
}

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
