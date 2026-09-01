// Public Demo (`#/public-demo-01`)-specific Playwright helper — SES-FULL-YEAR-E2E-PHASE1.
//
// This is deliberately a SEPARATE helper from `ses-player.ts`. That file
// drives the Founding Prologue's `GameEngine`/`PrologueEngine` auto-player;
// this one drives `PublicDemo01PlaceholderScreen` / `PublicDemoAggregate`,
// an unrelated screen, state machine, and month model (internal months
// 4-15 = April-March; see `lib/game/public_demo/public_demo_month_label.dart`).
// The two stacks share no runtime state and must not be mixed: nothing
// here calls into `ses-player.ts`, and nothing there should call into this
// file.
//
// Every operation below is a real tap against real production UI — exactly
// like `ses-player.ts` — read from the actual rendered Flutter Web
// accessibility tree, never from a Dart debug/state API (there isn't one;
// see e2e/README.md's "Why no debug API").
//
// Scope: this only extracts what Phase 1's own tests need (open, fresh
// start, month assertions, the canonical monthly CTA, dialog handling,
// safe scrolling, stable-semantics waits, and the minimal April/June sales
// actions the smallest legitimate current annual route needs). It is not a
// general Public Demo automation framework — later lanes (Recovery,
// Persistence, ...) should extend this file with their own small, named
// helpers the same way, not a generic action-runner.
import { expect, type Page, type Locator } from '@playwright/test';

/** Public Demo's own hash route. `e2e=1` only force-enables Flutter Web's
 * accessibility/semantics tree (see `lib/main.dart`) — it changes no game
 * logic and is not specific to this screen. */
export const PUBLIC_DEMO_PATH = '/?e2e=1#/public-demo-01';

/** Opens the Public Demo route and waits for Flutter Web semantics to
 * attach. Mirrors every existing Public Demo spec's own opening lines
 * (`public-demo-fresh-start.spec.ts`, `public-demo-july-restart.spec.ts`,
 * `public-demo-single-month-cta.spec.ts`) so this is a pure extraction, not
 * a behavior change. */
export async function openPublicDemo(page: Page): Promise<void> {
  await page.goto(PUBLIC_DEMO_PATH);
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });
}

/** Reads the current, full-page ARIA snapshot. Every assertion in this
 * helper reads the browser's actual accessibility snapshot directly —
 * matching `public-demo-fresh-start.spec.ts`'s own rationale: the generic
 * `ses-player.ts`/`game-state.ts` semantics parser is normalized for that
 * other auto-player and must not be reused here (see this file's own
 * header doc). */
export async function snapshot(page: Page): Promise<string> {
  return page.locator('body').ariaSnapshot();
}

/** Fresh-start invariants any Public Demo test can assert after
 * `openPublicDemo` and before taking any action — a non-mutating read, safe
 * to call from any lane. Does not itself assert April; call
 * `assertCalendarMonth(page, 4)` for that. */
export async function assertFreshStartInvariants(page: Page): Promise<void> {
  await expect(async () => {
    const raw = await snapshot(page);
    expect(raw, 'Public Demo identity').toContain('S.E.S. Public Demo 0.1');
    expect(raw, 'fresh start must not already be terminal').not.toContain(
      'このプレイスルーは終了しました。',
    );
    expect(raw, 'fresh start must not already be bankrupt').not.toContain('倒産');
  }).toPass({ timeout: 15_000 });
}

/** Asserts the HOME header's current calendar-month label (`1年目 4月` for
 * April, etc. — see `publicDemoMonthLabel`, internal months 4-15 wrap
 * 13/14/15 back to 1/2/3). Polls via `toPass` because a just-completed
 * month-close can take a tick to settle (matches
 * `public-demo-july-restart.spec.ts`'s own `expectMonth`). */
export async function assertCalendarMonth(page: Page, calendarMonth: number): Promise<void> {
  await expect(async () => {
    const snap = await snapshot(page);
    expect(snap).toContain(`1年目 ${calendarMonth}月`);
  }).toPass({ timeout: 15_000 });
}

/** Waits for two consecutive animation frames — the same bounded,
 * event-driven "let Flutter finish this frame" wait every existing Public
 * Demo spec already uses (`public-demo-july-restart.spec.ts`,
 * `public-demo-single-month-cta.spec.ts`), never an arbitrary sleep. */
export async function waitForStableFrame(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
      ),
  );
}

/** Scrolls the page until an exact-named button is fully on screen, then
 * returns its locator (still requires the caller to `.click()` it).
 * Flutter Web's accessibility tree only exposes a scrollable child's
 * semantics once it is actually scrolled into view — confirmed against
 * this repo's own `clickScrollableButton`/`scrollToButton` helpers in
 * `public-demo-july-restart.spec.ts` and `public-demo-single-month-cta.spec.ts`,
 * which this consolidates. Also dismisses any open alert dialog on every
 * poll tick (`dismissDialogIfPresent`) so a result dialog that appears
 * asynchronously (interview results await an event-image precache before
 * `showDialog` — see `PublicDemo01PlaceholderScreen.ei()`) never strands
 * the scroll loop waiting on a button a modal barrier is still covering. */
export async function scrollToButton(
  page: Page,
  name: string | RegExp,
  exact = true,
): Promise<Locator> {
  const button = page.getByRole('button', { name, exact });
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  for (let step = 0; step < 30; step++) {
    await dismissDialogIfPresent(page);
    if ((await button.count()) > 0) {
      const box = await button.boundingBox();
      if (box && viewport && box.y >= 0 && box.y + box.height <= viewport.height) {
        return button;
      }
      if (box?.y != null && box.y < 0) {
        await page.mouse.wheel(0, -500);
        await waitForStableFrame(page);
        continue;
      }
    }
    await page.mouse.wheel(0, 500);
    await waitForStableFrame(page);
  }
  return button;
}

/** Scrolls to, then clicks, an exact-named button. This is the one write
 * path every Public Demo test action should go through — never a bare
 * `page.getByRole('button', ...).click()` — so scrolling/dialog-timing
 * fixes land in one place.
 *
 * Several actions (order acceptance, interview results, ...) open a
 * follow-up event dialog after the click resolves, sometimes only once an
 * awaited image precache finishes (`ei()`, `ci()`, the order-acceptance
 * flow in `PublicDemo01PlaceholderScreen`) — and Flutter's modal barrier
 * excludes the rest of the screen from the accessibility tree while that
 * dialog is open, so a caller reading the snapshot right after the click
 * would see only the dialog, not the state the click actually produced.
 * This absorbs exactly one such dialog (bounded poll, never a fixed sleep)
 * before returning, so every `clickButton` caller can read the snapshot
 * immediately afterward. A caller expecting a dialog that needs a
 * non-default confirm label (the July bonus picker, the restart confirm)
 * still handles it explicitly — this only auto-dismisses the common
 * `確認` shape. */
export async function clickButton(page: Page, name: string | RegExp, exact = true): Promise<void> {
  const button = await scrollToButton(page, name, exact);
  await expect(button, `button "${name}" must be reachable`).toBeVisible({ timeout: 15_000 });
  await button.click();
  await waitForStableFrame(page);
  await waitAndDismissDialog(page);
}

/** Dismisses one open `alertdialog` by clicking a button matching [label]
 * inside it, if a dialog is currently open. Single-shot, non-polling —
 * `clickButton`'s own scroll loop already calls this every tick, and
 * `closeMonthlyPrimaryCta` polls it across an async dialog appearance; call
 * this directly only when you know a dialog is (or might already be) open
 * right now. Returns whether a dialog was actually dismissed. */
export async function dismissDialogIfPresent(page: Page, label = '確認'): Promise<boolean> {
  try {
    const dialog = page.getByRole('alertdialog');
    if ((await dialog.count()) === 0) return false;
    const button = dialog.getByRole('button', { name: label, exact: true });
    if ((await button.count()) === 0) return false;
    await button.click({ timeout: 5_000 });
    await waitForStableFrame(page);
    return true;
  } catch {
    // A dialog that closed/transitioned between the presence check and the
    // click is not a failure here — the caller's own poll (or the next
    // scroll tick) will observe whatever state comes next.
    return false;
  }
}

/** Polls (bounded, event-driven — never a fixed sleep) for a dialog to
 * appear and dismisses every one it sees, up to [timeoutMs]. Several Public
 * Demo actions precache an event image before `showDialog` (`ei()`, `ci()`,
 * `april()`, ...), so the dialog can appear a tick or two after the
 * triggering click returns — this absorbs that gap. Returns whether any
 * dialog was dismissed.
 *
 * `clickButton` calls this after every click, and most clicks never open a
 * dialog at all — so this must not cost its full [timeoutMs] on the common
 * no-dialog path. It polls in short (~100ms) steps and gives up as soon as
 * an early check comes back empty, only continuing to poll past that if it
 * has *already* seen (and dismissed) a dialog this call, since a second one
 * chained immediately after the first is the one case actually worth
 * waiting the rest of the budget for. */
export async function waitAndDismissDialog(
  page: Page,
  label = '確認',
  timeoutMs = 1_500,
): Promise<boolean> {
  const stepMs = 100;
  const deadline = Date.now() + timeoutMs;
  let dismissedAny = false;
  let checks = 0;
  while (Date.now() < deadline) {
    if (await dismissDialogIfPresent(page, label)) {
      dismissedAny = true;
      checks = 0;
      continue; // a second dialog can immediately follow the first
    }
    checks += 1;
    // No dialog on the first several checks (~600ms) and none dismissed yet
    // this call: treat this click as one that simply never opens a dialog
    // rather than spending the rest of the budget polling for one.
    if (!dismissedAny && checks >= 6) break;
    if (dismissedAny) break;
    await page.waitForTimeout(stepMs);
  }
  return dismissedAny;
}

/** Matches every current canonical monthly-close CTA label
 * (`PublicDemo01PlaceholderScreen._monthlyPrimaryAction`,
 * `Key('public-demo-monthly-primary-cta')`): `４月を終了して５月へ`
 * (April-June, each naming next month), `７月を終了して８月へ` (July),
 * `Ｘ月を終了して翌月へ` (August-February), and `３月を終了して第１期を完了`
 * (March). One regex instead of one literal per month keeps this helper
 * correct without an edit every time a month's exact label wording changes,
 * while still only ever matching the single canonical CTA Issue #118
 * (`public-demo-single-month-cta.spec.ts`) guarantees is unique on screen —
 * never a removed legacy per-month button (those used a `終了→` dash-arrow
 * shape this pattern cannot match). */
export const MONTHLY_PRIMARY_CTA_PATTERN = /を終了して(翌月へ|\d+月へ|第1期を完了)$/;

/** Finds the canonical monthly-close CTA without needing its exact current
 * label. */
export async function findMonthlyPrimaryCta(page: Page): Promise<Locator> {
  return scrollToButton(page, MONTHLY_PRIMARY_CTA_PATTERN, false);
}

/** Clicks the canonical monthly-close CTA and absorbs whichever dialog (if
 * any) that specific month's close opens — April's new-applicant event
 * dialog, July's summer-bonus flow being a prerequisite rather than a
 * post-close dialog, etc. Does not itself assert the resulting month; call
 * `assertCalendarMonth` afterwards. */
export async function closeMonthlyPrimaryCta(page: Page): Promise<void> {
  const cta = await findMonthlyPrimaryCta(page);
  await expect(cta, 'canonical monthly-close CTA must be reachable').toBeVisible({
    timeout: 15_000,
  });
  await cta.click();
  await waitForStableFrame(page);
  // A larger budget than `clickButton`'s own default: April's month-close
  // specifically opens a new-applicant event dialog only after an awaited
  // image precache (`april()`), and this is called at most once per month
  // (12 times for a full year), so the worst case here is cheap.
  await waitAndDismissDialog(page, '確認', 4_000);
}

/** Restarts a Public Demo playthrough from whatever month it currently sits
 * at, via the always-available "テスト用操作" reset control
 * (`public-demo-july-restart.spec.ts`'s own flow) — confirms the
 * confirmation dialog. Leaves the caller to assert April afterwards. */
export async function restartFromApril(page: Page): Promise<void> {
  await clickButton(page, '4月からやり直す', true);
  const dialog = page.getByRole('alertdialog');
  await expect(dialog).toBeVisible({ timeout: 15_000 });
  await dialog.getByRole('button', { name: '4月からやり直す', exact: true }).click();
  await waitForStableFrame(page);
}

// ---------------------------------------------------------------------
// Minimal April/June sales-pipeline actions (CURRENT-behavior baseline).
//
// eng-01 (佐藤 健, actualCapability 78) is the ONLY founding engineer whose
// April capability already clears `fieldSalesCapabilityRequirement` (60) —
// see `public_demo_engineer_runtime.dart`. eng-02 (鈴木 葵, capability 52)
// cannot begin field sales this fiscal year: the founding engineers' sales
// stage buttons render only in their April join month, and the production
// code's own comment on this (`public_demo_01_placeholder_screen.dart`,
// `readyForFieldSales`/`fieldSalesLock` card) is explicit that no later
// month reopens this action no matter how much later training raises
// capability. That is CURRENT, deliberate behavior, not a bug this Phase 1
// harness works around — see the Phase 1 result report's "Current Annual
// Route" section for the full accounting.
// ---------------------------------------------------------------------

/** Runs eng-01 (佐藤 健)'s full April sales pipeline — SkillSheet review
 * through order acceptance — the only founding engineer capable of it this
 * fiscal year. Each label is the exact, current production button text
 * (`public_demo_01_placeholder_screen.dart`'s `ec(i)`/HOME recommended
 * action cards); a wording change here is a real product change this
 * helper should surface as a failing assertion, not silently paper over. */
export async function sellFoundingEngineerInApril(page: Page): Promise<void> {
  await clickButton(page, 'SkillSheetを確認', true);
  await clickButton(page, '内容を確認', true);
  await clickButton(page, '営業を開始', true);
  await clickButton(page, '案件紹介', true);
  await clickButton(page, '上位会社面談', true);
  await clickButton(page, '客先面談', true);
  await clickButton(page, '受注', true);
}

/** Decides and accepts eng-01's July contract continuation during June —
 * the one-time decision `assignedEngineerIds(month)` requires from July
 * onward (`PublicDemoWorkflowState.assignedEngineerIds`: July-March only
 * counts an assignment whose `nextOrderStatus` is `accepted`). Skipping
 * this in June is itself a legitimate current route (no revenue the rest
 * of the fiscal year) — Phase 1's own annual-reachability route always
 * calls this so the smallest currently-solvent-as-possible baseline is the
 * one recorded. */
export async function confirmJulyContinuation(page: Page): Promise<void> {
  await clickButton(page, '7月分の発注を確認', true);
  await clickButton(page, '受注する', true);
}

/** Decides the July summer bonus as "none" (`なし`) — the same choice
 * `public-demo-july-restart.spec.ts` already exercises — and leaves the
 * month ready to close. Does not click the monthly CTA itself. */
export async function decideNoSummerBonus(page: Page): Promise<void> {
  await clickButton(page, '夏季賞与を決める', true);
  const dialog = page.getByRole('alertdialog');
  await expect(dialog).toBeVisible({ timeout: 15_000 });
  const none = dialog.getByRole('button', { name: /^なし/ });
  await expect(none).toBeEnabled();
  await none.click();
  await waitForStableFrame(page);
}

/** Reads whether the bankruptcy/March-cash-shortage terminal card
 * (`Key('public-demo-bankruptcy-card')`) is present, without asserting
 * either way — callers decide what a terminal state should mean for their
 * own scenario. */
export async function isFinanciallyTerminal(page: Page): Promise<boolean> {
  const snap = await snapshot(page);
  return snap.includes('このプレイスルーは終了しました。');
}

/** Reads the finance-summary card's `現金残高` (current cash) line verbatim,
 * for a checkpoint assertion/log — never parsed into a number here, so a
 * future currency-formatting change fails loudly in the calling test
 * instead of silently miscomparing. */
export async function readCashSummaryLine(page: Page): Promise<string | undefined> {
  const snap = await snapshot(page);
  return snap.split('\n').find((line) => line.includes('現金残高'))?.trim();
}
