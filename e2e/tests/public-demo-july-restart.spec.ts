import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';
import {
  openPublicDemo,
  assertCalendarMonth,
  dismissMonthGuardIfPresent,
  scrollToButton,
  scrollToTop,
} from '../helpers/public-demo-player';

// This test needs to inspect two dialogs' own content (the April
// new-applicant event, the summer-bonus picker) before choosing which of
// their buttons to click — unlike every other Public Demo spec's write
// path, it deliberately does not go through `clickButton` (which would
// auto-dismiss a `確認`-labelled dialog before this test gets to assert on
// it). It still reuses `scrollToButton` — the same robust, dialog-aware
// scroll loop `clickButton` itself is built on — rather than a second,
// weaker scroll implementation of its own.
//
// Scrolls to the top first, same as `findMonthlyPrimaryCta`: this test's
// own targets (the monthly-close CTA, the summer-bonus/restart controls)
// all render near the top of the page, and `scrollToButton`'s own search
// only ever goes downward until it has already seen the target (so a
// caller left scrolled deep past it — e.g. after the previous action's own
// card interaction — could never recover on its own).
async function clickScrollableButton(
  page: import('@playwright/test').Page,
  name: string,
) {
  await scrollToTop(page);
  const button = await scrollToButton(page, name, true);
  await expect(button).toBeVisible();
  await button.click();
}

test.describe('Public Demo July close and April restart', () => {
  test('none closes July into August and the test restart is confirmable', async ({ page }) => {
    const errors = watchForErrors(page);

    await openPublicDemo(page);
    await assertCalendarMonth(page, 4);

    await clickScrollableButton(page, '4月を終了して5月へ');
    // Issue #168 (FIRST-FUN-YEAR-ONBOARDING-1): April's close now runs the
    // Month Guard before its own new-applicant event dialog — a fresh
    // playthrough's untouched 佐藤 健 SkillSheet確認 is a genuinely
    // outstanding recommended-level action, so the guard's warning shows
    // first. Proceed through it exactly as a player choosing "このまま月末
    // 処理を進める" would, then the applicant dialog this test actually
    // means to assert on follows.
    await dismissMonthGuardIfPresent(page);
    const applicationDialog = page.getByRole('alertdialog');
    await expect(applicationDialog).toBeVisible();
    expect(await applicationDialog.ariaSnapshot()).toContain('採用候補者の情報を確認できます');
    await applicationDialog.getByRole('button', { name: '確認', exact: true }).click();
    await assertCalendarMonth(page, 5);

    await clickScrollableButton(page, '5月を終了して6月へ');
    // Same Issue #168 wiring as April, on May's own close: the two
    // pre-seeded applicants are still unreviewed and recruitment media
    // unused at this point in the playthrough, a genuinely outstanding
    // recommended-level action, so the guard can warn here too. May's
    // close has no event dialog of its own, so this is the only dialog to
    // proceed through before the month advances.
    await dismissMonthGuardIfPresent(page);
    await assertCalendarMonth(page, 6);
    await clickScrollableButton(page, '6月を終了して7月へ');
    // Same Issue #168 wiring on June's own close: this playthrough never
    // actually performed the recommended April/May actions (this test's
    // subject is July's own Month Guard, not the earlier months'), so June
    // may still see outstanding items and warn.
    await dismissMonthGuardIfPresent(page);
    await assertCalendarMonth(page, 7);

    await clickScrollableButton(page, '夏季賞与を決める');
    const bonusDialog = page.getByRole('alertdialog');
    const none = bonusDialog.getByRole('button', { name: /^なし/ });
    await expect(none).toBeEnabled();
    await none.click();
    await clickScrollableButton(page, '7月を終了して8月へ');

    await assertCalendarMonth(page, 8);

    // SES-FIRST-FUN-YEAR-UI-PHASE-2: the test-only restart control moved
    // out of the normal monthly flow into a bottom "開発・テストメニュー" fold,
    // closed by default so a normal player never mistakes it for part of
    // ordinary play. Opening that fold once is the one new step here — it
    // stays open across the cancel-and-retry below, and the restart
    // button itself, its key, and its confirmation dialog are unchanged.
    await clickScrollableButton(page, '開発・テストメニュー');
    await clickScrollableButton(page, '4月からやり直す');
    const restartDialog = page.getByRole('alertdialog');
    await expect(restartDialog).toBeVisible();
    expect(await restartDialog.ariaSnapshot()).toContain('Public Demoを4月からやり直しますか？');

    await restartDialog.getByRole('button', { name: 'キャンセル', exact: true }).click();
    await assertCalendarMonth(page, 8);

    await clickScrollableButton(page, '4月からやり直す');
    await page
      .getByRole('alertdialog')
      .getByRole('button', { name: '4月からやり直す', exact: true })
      .click();

    await assertCalendarMonth(page, 4);
    expect(await page.locator('body').ariaSnapshot()).toContain('佐藤 健');
    await expect(page.getByRole('button', { name: 'SkillSheetを確認', exact: true })).toBeVisible();

    expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
    expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);
  });
});
