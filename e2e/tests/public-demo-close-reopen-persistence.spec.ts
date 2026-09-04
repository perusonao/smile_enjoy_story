// Issue #166 (PUBLIC-DEMO-PERSISTENCE-P0-1): a valid Public Demo save must
// restore reliably after the tab/browser context is closed and the player
// revisits the same origin, and PR #164's Development/Public Demo routing
// contract must not regress while doing so.
//
// Investigation finding (see docs/reports/SES_PUBLIC-DEMO-PERSISTENCE-P0-1_Result.md
// for the full audit): production persistence and routing are already
// correct. The PR #164 audit's earlier "new browser context" failure was a
// TEST-HARNESS artifact — `browser.newContext()` with no `storageState`
// creates an isolated storage partition equivalent to a different browser
// profile, not "the same browser, tab closed and reopened". A real browser
// persists `localStorage` to disk across a full restart within the same
// profile; Playwright's equivalent of that is `context.storageState()`
// captured before close and passed back into the next `browser.newContext()`
// — used below for the "close the whole browser, reopen later" case.
import { test, expect, type Page } from '@playwright/test';
import { openPublicDemo, assertCalendarMonth, scrollToButton } from '../helpers/public-demo-player';

const SAVE_KEY = 'flutter.ses_public_demo_01_aggregate_v1';

/** Opens the SkillSheet sheet and confirms it — the real production
 * mutation/save path (`_openSkillSheetReview` → `_startSkillSheetReview` →
 * `_commitAggregate` in `public_demo_01_placeholder_screen.dart`). Merely
 * opening the sheet does not commit or save anything. */
async function commitSkillSheetReview(page: Page): Promise<void> {
  const openBtn = await scrollToButton(page, 'SkillSheet確認');
  await openBtn.click();
  const confirmBtn = page.getByRole('button', { name: '内容を確認', exact: true });
  await confirmBtn.waitFor({ state: 'visible', timeout: 10_000 });
  await confirmBtn.click();
  await page.waitForTimeout(500);
}

/** True once the reviewed engineer's stage-gated button has flipped from
 * "SkillSheet確認"（`PublicDemoSalesStage.waiting`）to "営業開始"
 * （`PublicDemoSalesStage.skillSheet`) — the real stage transition
 * [commitSkillSheetReview] causes. A fresh, never-reviewed aggregate always
 * shows "SkillSheet確認"/"営業準備OK" instead, so — unlike asserting
 * `1年目 4月` alone, which a fresh aggregate satisfies too — this is what
 * actually distinguishes "genuinely restored" from "silently started a new
 * game". */
async function skillSheetReviewIsVisibleInUi(page: Page): Promise<boolean> {
  const snap = await page.locator('body').ariaSnapshot();
  return snap.includes('営業開始') && !snap.includes('SkillSheet確認');
}

test('a Public Demo save survives closing the tab and reopening the same origin', async ({ browser }) => {
  const context = await browser.newContext();
  const page1 = await context.newPage();
  await openPublicDemo(page1);
  await commitSkillSheetReview(page1);
  const rawBefore = await page1.evaluate((key) => localStorage.getItem(key), SAVE_KEY);
  expect(rawBefore, 'a real save must exist before the tab closes').not.toBeNull();
  await page1.close();

  const page2 = await context.newPage();
  await openPublicDemo(page2);
  const rawAfter = await page2.evaluate((key) => localStorage.getItem(key), SAVE_KEY);
  expect(rawAfter, 'localStorage in the same browser context must be untouched by closing a tab').toEqual(rawBefore);
  await assertCalendarMonth(page2, 4);
  expect(
    await skillSheetReviewIsVisibleInUi(page2),
    'the reopened tab must show the restored SkillSheet-reviewed state, not a fresh game',
  ).toBe(true);
  await context.close();
});

test('a Public Demo save survives a full browser restart', async ({ browser }) => {
  const contextA = await browser.newContext();
  const pageA = await contextA.newPage();
  await openPublicDemo(pageA);
  await commitSkillSheetReview(pageA);
  const rawBefore = await pageA.evaluate((key) => localStorage.getItem(key), SAVE_KEY);
  expect(rawBefore).not.toBeNull();

  // What a real OS-persisted browser profile gives for free across a full
  // quit/reopen — see this file's header doc for why a bare
  // `browser.newContext()` does not model the same thing.
  const storageState = await contextA.storageState();
  await contextA.close();

  const contextB = await browser.newContext({ storageState });
  const pageB = await contextB.newPage();
  await openPublicDemo(pageB);
  const rawAfter = await pageB.evaluate((key) => localStorage.getItem(key), SAVE_KEY);
  expect(rawAfter, 'localStorage transferred via storageState must still carry the save').toEqual(rawBefore);
  await assertCalendarMonth(pageB, 4);
  expect(
    await skillSheetReviewIsVisibleInUi(pageB),
    'the restarted browser must restore the SkillSheet-reviewed state via PublicDemoSaveService, not fall back to a new game',
  ).toBe(true);
  await contextB.close();
});

test('a same-tab reload resumes an active Public Demo session (PR #164 regression)', async ({ browser }) => {
  const context = await browser.newContext();
  const page = await context.newPage();
  await openPublicDemo(page);
  await commitSkillSheetReview(page);

  // A same-tab reload — Flutter Web's own router has already rewritten
  // `location.hash` away from `#/public-demo-01` by now (the documented
  // SES-FIRST-FUN-YEAR-RELOAD-1 root cause PR #164 fixed), so this
  // exercises `wasPublicDemoThisSession`'s sessionStorage marker path.
  await page.reload();
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });
  await assertCalendarMonth(page, 4);
  expect(
    await skillSheetReviewIsVisibleInUi(page),
    'a same-tab reload must resume the same Public Demo session',
  ).toBe(true);
  await context.close();
});

test('a genuine new tab at root stays on Development despite an existing Public Demo save (PR #164 regression)', async ({
  browser,
}) => {
  const context = await browser.newContext();
  const page1 = await context.newPage();
  await openPublicDemo(page1);
  await commitSkillSheetReview(page1);
  expect(await page1.evaluate((key) => localStorage.getItem(key), SAVE_KEY)).not.toBeNull();
  await page1.close();

  // A genuinely new tab (new top-level browsing context) in the SAME
  // browser context: localStorage (context-partitioned) still carries the
  // Public Demo save, but sessionStorage (tab-partitioned) does not carry
  // over from the closed tab, so this must resolve to Development — the
  // `resolveAppExperienceWithSaveFallback` contract PR #164 added must
  // never treat mere save presence as launch intent.
  const page2 = await context.newPage();
  await page2.goto('/?e2e=1');
  await page2.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });
  await page2.waitForTimeout(1000);
  const snap = await page2.locator('body').ariaSnapshot();
  expect(
    snap.includes('S.E.S. Public Demo 0.1'),
    'a genuine new-tab root entry must not be hijacked into Public Demo merely because a Public Demo save exists',
  ).toBe(false);
  await context.close();
});
