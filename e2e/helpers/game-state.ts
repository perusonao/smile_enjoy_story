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
  /** Names of buttons that are nested under a `dialog`/`alertdialog` node
   * (Flutter's `Dialog`/`AlertDialog` — both `showDialog`-based, both set
   * `aria-modal` — see `engine/.../semantics/route.dart`'s `SemanticDialog`/
   * `SemanticAlertDialog`). A button whose *label text* happens to match a
   * real dialog's own dismiss button can still appear elsewhere on the same
   * screen as an entirely unrelated, non-dialog control (Home layout整理
   * follow-up, PR #22: `_HeroTaskCard`'s CTA can read exactly "採用を見る",
   * the same text `beginner-mode-player.ts`'s `CLOSE_LABELS` already used
   * for a *dialog's* "採用を見る" button) — `dialogButtonNames` is what lets
   * callers tell those two apart instead of matching on name alone. */
  dialogButtonNames: string[];
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
 * a real Page/browser (see `tests/game-state.ariaParsing.spec.ts`).
 *
 * Also tracks dialog scope (Home layout整理 follow-up, PR #22): `dialog`/
 * `alertdialog` role lines open a scope for every more-deeply-indented line
 * that follows, closed the moment a line's own indentation drops back to
 * (or below) the dialog line's — ariaSnapshot()'s YAML-ish output nests
 * children two spaces deeper than their parent, consistently, so indentation
 * alone is enough; no real DOM tree walk needed. */
export function parseAriaSnapshot(raw: string): ScreenSnapshot {
  const texts: string[] = [];
  const buttons: ButtonInfo[] = [];
  const dialogButtonNames: string[] = [];
  // Indentation (in raw, untrimmed columns) of the currently-open dialog/
  // alertdialog node, or null when no dialog scope is open. A line is
  // "inside" that dialog for as long as its own indentation is strictly
  // greater than this value.
  let dialogIndent: number | null = null;
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('-')) continue;
    const indent = line.length - line.trimStart().length;
    if (dialogIndent !== null && indent <= dialogIndent) dialogIndent = null;
    const m = ARIA_LINE.exec(trimmed);
    if (!m) continue;
    const role = m[1];
    if (role === 'dialog' || role === 'alertdialog') dialogIndent = indent;
    const name = (m[3] ?? m[2] ?? '').replace(/\\"/g, '"').trim();
    if (!name || CHROME_BUTTON_NAME.test(name)) continue;
    if (role === 'button') {
      buttons.push({ name, enabled: !/\[disabled\]/.test(m[4] ?? '') });
      if (dialogIndent !== null) dialogButtonNames.push(name);
    } else {
      texts.push(name);
    }
  }
  return { texts, buttons, dialogButtonNames };
}

/** Reads the full accessibility tree in one round-trip, via ariaSnapshot(). */
export async function snapshotScreen(page: Page): Promise<ScreenSnapshot> {
  const raw = await page.locator('body').ariaSnapshot();
  return parseAriaSnapshot(raw);
}

export function hasText(snap: ScreenSnapshot, needle: string): boolean {
  return snap.texts.some((t) => t.includes(needle)) || snap.buttons.some((b) => b.name.includes(needle));
}

/** True only when [name] is both an enabled button *and* inside a real
 * dialog scope (`dialogButtonNames` — see its own doc comment). The one
 * safe way for a driver to treat a same-labeled button as "dismiss this
 * dialog": a plain name match against `snap.buttons` alone can't tell a
 * dialog's own dismiss button apart from an unrelated, non-dialog control
 * elsewhere on the same screen that happens to carry identical text (PR
 * #22 follow-up — `_HeroTaskCard`'s "採用を見る" CTA vs.
 * `founding_dialogs.dart`'s own "採用を見る" dialog button). */
export function enabledDialogButton(snap: ScreenSnapshot, name: string): ButtonInfo | undefined {
  return snap.buttons.find((b) => b.name === name && b.enabled && snap.dialogButtonNames.includes(name));
}

/** First of [names] (checked in the given order) that is both enabled and
 * dialog-scoped — the "which known dialog-dismiss button, if any, is
 * actually open right now" query every CLOSE-list-driven E2E driver in this
 * harness needs (`helpers/beginner-mode-player.ts`,
 * `tests/phase-3b1-fit-reason.spec.ts`,
 * `tests/beginner-mode-waiting-and-recruitment.spec.ts` each keep their own
 * CLOSE/CLOSE_LABELS list — on purpose, since each file's own dismiss loop
 * needs different surrounding behavior (e.g. inspecting a dialog's text
 * before dismissing it) — but all three should resolve "is this really a
 * dialog" the same, single way rather than drifting into 3 independent
 * definitions of it (PR #22 root cause). */
export function firstEnabledDialogButton(snap: ScreenSnapshot, names: readonly string[]): ButtonInfo | undefined {
  for (const name of names) {
    const button = enabledDialogButton(snap, name);
    if (button) return button;
  }
  return undefined;
}

// Phase 3A UX review (P1-3): a dynamically-built Japanese sentence can
// accidentally double a particle when two independently-templated segments
// meet (e.g. a label that already ends in "が" concatenated with prose that
// also starts with "が"). "までで" (でで) is legitimate Japanese ("これまでで"
// = "the most ... so far") and must never be flagged. "やや" (slightly/
// somewhat — e.g. RecruitmentInterviewScreen's info-gauge copy "やや把握")
// is a single ordinary word, found via this file's own waiting-cost/
// recruitment-tradeoff E2E driving real recruitment-interview summary
// screens for the first time — no unit/widget test had ever rendered that
// copy through this scanner before.
const DOUBLED_PARTICLE = /(が|を|は|の|に|で|も|と|へ|や)\1/g;
const LEGITIMATE_DOUBLED_PARTICLE_CONTEXTS = [/までで/, /やや/];

/** Scans every text/button label in [snap] for an immediately-repeated
 * single-character Japanese particle (e.g. "がが", " をを") — almost always
 * a sign that two separately-built string segments were concatenated
 * without checking whether either already supplied the particle. Returns
 * each offending string once, in encounter order; empty when nothing looks
 * wrong. Never a golden/screenshot comparison — pure text-content
 * regression coverage that survives incidental layout/copy changes. */
export function findDoubledParticles(snap: ScreenSnapshot): string[] {
  const offenders: string[] = [];
  for (const t of [...snap.texts, ...snap.buttons.map((b) => b.name)]) {
    DOUBLED_PARTICLE.lastIndex = 0;
    let m: RegExpExecArray | null;
    while ((m = DOUBLED_PARTICLE.exec(t))) {
      const context = t.slice(Math.max(0, m.index - 2), m.index + 3);
      if (LEGITIMATE_DOUBLED_PARTICLE_CONTEXTS.some((p) => p.test(context))) continue;
      offenders.push(t);
      break;
    }
  }
  return offenders;
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
