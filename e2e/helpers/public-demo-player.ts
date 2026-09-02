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
 * the scroll loop waiting on a button a modal barrier is still covering.
 *
 * RECOVERY-LOOP-1: the month 7-14 waiting-engineer card section can put
 * several engineers' full sales-pipeline cards (plus each one's own
 * duplicate-looking but distinct training card) on screen at once — a
 * genuinely taller page than this helper's original single-founding-
 * engineer baseline, not flakiness — so the scroll budget below (60 ticks)
 * is real navigation distance, not a timeout. */
export async function scrollToButton(
  page: Page,
  name: string | RegExp,
  exact = true,
  root: Page | Locator = page,
): Promise<Locator> {
  const button = root.getByRole('button', { name, exact });
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  for (let step = 0; step < 60; step++) {
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
 * `確認` shape.
 *
 * [root] narrows which button is matched to one already-located region of
 * the page (e.g. one specific applicant's own card) instead of the whole
 * page — needed whenever two engineers/applicants can carry the exact same
 * button label at once (e.g. two un-reviewed May applicants both showing
 * `経歴書確認`), which a bare page-wide `getByRole` cannot disambiguate.
 * Defaults to `page` itself, so every existing caller is unaffected. */
export async function clickButton(
  page: Page,
  name: string | RegExp,
  exact = true,
  root: Page | Locator = page,
): Promise<void> {
  const button = await scrollToButton(page, name, exact, root);
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

/** Scrolls the page fully back to its top, bounded and event-driven (never
 * a fixed sleep) — matches `scrollToButton`'s own per-tick shape
 * (`mouse.wheel` + `waitForStableFrame`), just unconditionally upward.
 * Needed before searching for a target near the top of a long page
 * (`findMonthlyPrimaryCta`) after a prior action scrolled deep down:
 * `scrollToButton`'s own default search direction is downward, and it can
 * only reverse once it already sees the target's (negative) position —
 * which a virtualized `ListView` will not expose at all once scrolled far
 * enough away, so a search that starts already far past the target can
 * never recover on its own. Starting every such search from a known
 * top-of-page position instead makes it search-direction-agnostic. */
export async function scrollToTop(page: Page): Promise<void> {
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  for (let step = 0; step < 40; step++) {
    await page.mouse.wheel(0, -3000);
    await waitForStableFrame(page);
  }
}

/** Finds the canonical monthly-close CTA without needing its exact current
 * label. Always searches from the top of the page (see [scrollToTop]) —
 * the CTA renders near the very top of every month's content, above the
 * engineer/applicant/assignment cards below it, so a caller need not track
 * how deep an earlier action (e.g. a Recovery sales-pipeline step further
 * down the page) left the scroll position.
 *
 * The whole scroll-to-top-then-search cycle is itself retried (`toPass`):
 * with several Recovery-eligible engineers' cards on screen at once, one
 * single pass has been observed to occasionally land mid-layout (a heavier
 * relayout still settling) and come up empty even right after a full
 * top-scroll — a second attempt, giving Flutter one more full paint cycle,
 * reliably finds it. This re-does real navigation, not a bare timeout. */
export async function findMonthlyPrimaryCta(page: Page): Promise<Locator> {
  let cta: Locator | undefined;
  await expect(async () => {
    await scrollToTop(page);
    cta = await scrollToButton(page, MONTHLY_PRIMARY_CTA_PATTERN, false);
    expect(await cta.count()).toBeGreaterThan(0);
  }).toPass({ timeout: 60_000 });
  return cta!;
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

/** Interviews and offers app-01 (高橋 翔, the only May applicant whose
 * `interviewScore` (74) clears recruitment's own >=60 gate — app-02, 田中
 * 美咲, scores 58 and can never be offered at all) but deliberately stops
 * right after the offer — no pre-entry SkillSheet/selling/interview/order.
 * `closeMay`'s own join-eligibility set already includes `offerAccepted`
 * (`public_demo_workflow_state.dart`), so app-01 still joins in May's
 * close on the accepted offer alone, then enters June/July as a genuinely
 * economically-waiting engineer rather than one whose pre-entry sales
 * progress silently carried them straight to an assignment — see
 * RECOVERY-LOOP-1's E2E design ("canonical target: app-01 / 高橋 翔"). */
/** Locator for app-01's own card — whichever one is currently on screen
 * (the May applicant card, `ac(i)`, or the post-join engineer card,
 * `ec(i)`) — anchored at the start of its accessible name only (`^高橋 翔`)
 * since the rest (status badge, resume summary, sales-stage progress)
 * changes after every action. Exported so any caller can scope its own
 * card-level clicks to app-01 specifically whenever another engineer could
 * otherwise carry the exact same button label at the same time (May's
 * second applicant, app-02; eng-01 if left unsold and still `waiting`). */
export function appOneCard(page: Page): Locator {
  return page.getByRole('group', { name: /^高橋 翔/ });
}

/** Interviews, offers, and runs app-01 (高橋 翔) through the FULL pre-entry
 * sales pipeline (SkillSheet through the June order) — the same May shape
 * `public_demo_01_success_playthrough_test.dart` already exercises. app-01
 * reaches `juneOrdered` and is picked up by `assignOrderedForMay` at May's
 * close, same as any other June hire.
 *
 * This is deliberately NOT "join on the accepted offer alone, skip
 * pre-entry sales" (an earlier version of this helper did exactly that,
 * matching `closeMay`'s own join-eligibility set, which also includes
 * `offerAccepted`) — that construction was found, empirically, to leave
 * Flutter Web's accessibility semantics tree in a state Playwright/CDP
 * stops exposing new content into from the very next month onward (the
 * month-close CTA and everything below it silently vanish from every
 * locator and `ariaSnapshot()` alike, though the underlying Dart state —
 * confirmed via an equivalent `PublicDemoAggregate`-level and
 * `WidgetTester`-level reproduction — stays completely correct throughout,
 * and no console/page error is ever raised). That reproduces on Chromium
 * regardless of scroll position, wait duration, or an explicit resize
 * event, so it reads as a Flutter-Web-CanvasKit-semantics ↔
 * Playwright/CDP interaction quirk specific to that one applicant-stage
 * shape, not a Recovery defect — see the E2E result report's KNOWN ISSUES.
 * Running app-01 through the ordinary pre-entry pipeline instead sidesteps
 * it entirely while still reaching the same eventual "waiting entering
 * July" fact this suite needs (see [leaveJulyContinuationUndecidedFor]),
 * and additionally exercises `recoverLateYearAssignment`'s UPSERT path
 * (into app-01's own May-era assignment entry) rather than only its APPEND
 * path. */
export async function hireAndRunAppOnePreEntryPipeline(page: Page): Promise<void> {
  // May's applicant pool always has two candidates (`publicDemoMayApplicants`)
  // on screen together, so every one of app-01's own buttons must be scoped
  // to their own card (`ac(i)`'s per-applicant group) — app-02 carries the
  // exact same `経歴書確認`/`採用面談` labels on their own card at the same
  // time, and an unscoped `getByRole('button', ...)` cannot tell them apart.
  const card = appOneCard(page);
  await clickButton(page, '経歴書確認', true, card);
  await clickButton(page, '採用面談', true, card);
  await clickButton(page, '合格・給与提示', true, card);
  const dialog = page.getByRole('alertdialog');
  await expect(dialog).toBeVisible({ timeout: 15_000 });
  // app-01's own requested salary (¥320,000 — `public_demo_recruitment.dart`)
  // is always one of `PublicDemoSalaryOfferDialog`'s three offered choices.
  await dialog.getByRole('button', { name: '32万円', exact: true }).click();
  await waitForStableFrame(page);
  await clickButton(page, '入社前SkillSheet', true, card);
  await clickButton(page, '入社前営業', true, card);
  await clickButton(page, '案件紹介', true, card);
  await clickButton(page, '上位会社面談', true, card);
  await clickButton(page, '客先面談', true, card);
  await clickButton(page, '6月受注', true, card);
}

/** Decides eng-01's own July continuation (`confirmJulyContinuation`'s own
 * shape) while scoping every click to eng-01's assignment card
 * specifically — needed once app-01 (via
 * [hireAndRunAppOnePreEntryPipeline]) is ALSO an assignment on the same
 * June screen, carrying the exact same `7月分の発注を確認`/`受注する`
 * labels on their own card at the same time. app-01's own assignment is
 * deliberately left at `nextOrderStatus: undecided` — Public Demo's
 * `assignedEngineerIds` only counts an entry as assigned from July onward
 * once its order is `accepted` (or `replacementStage` is `ordered`), so an
 * undecided May-era assignment is exactly as economically-waiting entering
 * July as one that was never made at all. */
export async function confirmSatoJulyContinuationOnly(page: Page): Promise<void> {
  const satoCard = page.getByRole('group', { name: /^佐藤 健/ });
  await clickButton(page, '7月分の発注を確認', true, satoCard);
  await clickButton(page, '受注する', true, satoCard);
}

/** Runs one waiting engineer's post-`waiting` sales pipeline —
 * SkillSheet review through order acceptance — using the raw employee
 * card's own button labels (`ec(i)`'s `SkillSheet確認`/`営業開始`, never
 * HOME Recommended Action's differently-worded `SkillSheetを確認`/
 * `営業を開始`, which `sellFoundingEngineerInApril` above targets instead —
 * the two are genuinely different on-screen strings for the same two
 * underlying commands, not a typo). RECOVERY-LOOP-1 deliberately does not
 * wire the month 7-14 waiting-engineer card into HOME (see
 * `docs/reports/SES_RECOVERY-LOOP-1_Implementation_Result.md`'s PRODUCTION
 * CHANGES section), so this raw-card path is the only one a Recovery-
 * eligible engineer redoing this same chain in July or later can ever
 * reach. */
export async function runWaitingEngineerSalesPipelineToOrdered(
  page: Page,
  root: Page | Locator = page,
): Promise<void> {
  // [root] scopes every card-level click to one specific engineer — needed
  // whenever eng-01 (never Recovery-eligible itself, but ready for field
  // sales and still `waiting` if never sold) is on screen at the same time
  // as the Recovery target, since both would otherwise carry the exact same
  // `SkillSheet確認` label the instant both are still `waiting` together
  // (e.g. the CRITICAL ACCEPTANCE GATE scenario, which deliberately never
  // sells eng-01). `内容を確認` lives inside the SkillSheet dialog itself,
  // not the card, so it is always page-scoped regardless of [root].
  await clickButton(page, 'SkillSheet確認', true, root);
  await clickButton(page, '内容を確認', true);
  await clickButton(page, '営業開始', true, root);
  await clickButton(page, '案件紹介', true, root);
  await clickButton(page, '上位会社面談', true, root);
  await clickButton(page, '客先面談', true, root);
  await clickButton(page, '受注', true, root);
}

/** Commits a Recovery-eligible waiting engineer's late-year (internal month
 * 7-14) order back into an assignment via `PublicDemoAggregate
 * .recoverAssignment` — the "案件へ復帰" button that only renders once
 * `PublicDemoRecoveryEligibility.isEligible` already holds
 * (`public_demo_01_placeholder_screen.dart`'s `ec(i)`). */
export async function recoverAssignment(page: Page): Promise<void> {
  await clickButton(page, '案件へ復帰', true);
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

/** Reads whether Public Demo's financial status is currently `cashShortage`
 * (`PublicDemoFinancialStatus.cashShortage` / `state.isFinanciallyRestricted`)
 * — a non-terminal warning state distinct from [isFinanciallyTerminal]'s
 * bankruptcy check: the player can still act, just under
 * `PublicDemoCashShortageCard`'s own red warning banner
 * (`public_demo_01_placeholder_screen.dart`'s `PublicDemoCashShortageCard(state: s)`).
 * Matches that card's exact production string, never a looser "is anything
 * wrong" heuristic. SES-FIRST-FUN-YEAR-UI-PHASE-1 removed the finance
 * summary card's own duplicate warning banner (`_financeSummary`'s
 * `warning` field, which used to carry this same fact as a second,
 * differently-worded string) — this now reads the one surviving
 * authoritative card instead. */
export async function isCashShortage(page: Page): Promise<boolean> {
  const snap = await snapshot(page);
  return snap.includes('資金不足：次回決算が期限です');
}

/** Reads the finance-summary card's `現金残高` (current cash) line verbatim,
 * for a checkpoint assertion/log — never parsed into a number here, so a
 * future currency-formatting change fails loudly in the calling test
 * instead of silently miscomparing. */
export async function readCashSummaryLine(page: Page): Promise<string | undefined> {
  const snap = await snapshot(page);
  return snap.split('\n').find((line) => line.includes('現金残高'))?.trim();
}

/** Scrolls down (from wherever the page currently sits — call [scrollToTop]
 * first for a deterministic starting point) until [text] appears anywhere
 * in the accessibility snapshot, then returns that snapshot. Mirrors
 * [scrollToButton]'s own per-tick shape (dismiss-dialog, wheel, settle) for
 * plain text instead of a button role — needed for read-only content
 * (finance summary card, monthly cash-flow card) a virtualized `ListView`
 * will not expose at all until actually scrolled near, exactly like a
 * button [scrollToButton] searches for. Throws (via the final `expect`) if
 * [text] is never found within the scroll budget, so a caller gets a clear
 * failure instead of silently reading stale/absent content. */
export async function scrollToText(page: Page, text: string): Promise<string> {
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  let found: string | undefined;
  // Retried from the top (`toPass`), same rationale as
  // `findMonthlyPrimaryCta`/`readCompactKpiValue` — an occasional
  // mid-layout snapshot with several Recovery-eligible engineers' cards on
  // screen is given one more full paint cycle rather than failing outright.
  await expect(async () => {
    await scrollToTop(page);
    for (let step = 0; step < 60; step++) {
      await dismissDialogIfPresent(page);
      const snap = await snapshot(page);
      if (snap.includes(text)) {
        found = snap;
        return;
      }
      await page.mouse.wheel(0, 500);
      await waitForStableFrame(page);
    }
    expect(found, `text "${text}" must appear somewhere on the page`).toBeDefined();
  }).toPass({ timeout: 30_000 });
  return found!;
}

/** Reads one compact-KPI tile's value (`KpiSection.compact`,
 * `home-kpi-compact-*`) by its exact label — `現金`, `参画`, `待機`,
 * `営業残`, `社員`, `売上`, or `入金予定`. This tile row renders
 * immediately after the page heading in every month, so it is always
 * reachable from [scrollToTop] alone, unlike the finance summary/cash-flow
 * cards further down (see [scrollToText]). Currency tiles (`現金`/`売上`/
 * `入金予定`) render as `¥N万` (truncated to ¥10,000 units — see
 * `kpi_section.dart`'s own `_yen`), exact only for amounts already a
 * multiple of ¥10,000, which every Public Demo revenue/salary constant is.
 * Throws (via the internal `toPass` retry) if [label] is never found
 * within the retry budget — a genuinely absent tile is a caller bug (every
 * label above always renders), not a normal `undefined` case. */
export async function readCompactKpiValue(page: Page, label: string): Promise<string | undefined> {
  // No trailing `\b` in the pattern below: JavaScript regex word boundaries
  // are ASCII-`\w` only, so one never actually matches directly after a
  // Japanese character (neither side of the position is a "word"
  // character) — the numeric/unit prefix this already requires is
  // disambiguating enough on its own.
  const pattern = new RegExp(`(¥?[\\d,]+(?:万|名|回))\\s*${label}`);
  let value: string | undefined;
  // Retried (`toPass`), same as `findMonthlyPrimaryCta` — a single
  // scroll-to-top-then-snapshot pass has been observed to occasionally
  // land mid-layout with several Recovery-eligible engineers' cards on
  // screen; one more full paint cycle reliably resolves it.
  await expect(async () => {
    await scrollToTop(page);
    const snap = await snapshot(page);
    value = snap.match(pattern)?.[1];
    expect(value, `${label} KPI tile`).toBeDefined();
  }).toPass({ timeout: 15_000 });
  return value;
}
