import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';
import {
  openPublicDemo,
  assertCalendarMonth,
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
    const applicationDialog = page.getByRole('alertdialog');
    await expect(applicationDialog).toBeVisible();
    expect(await applicationDialog.ariaSnapshot()).toContain('新しい応募が届きました');
    await applicationDialog.getByRole('button', { name: '確認', exact: true }).click();
    await assertCalendarMonth(page, 5);

    await clickScrollableButton(page, '5月を終了して6月へ');
    await assertCalendarMonth(page, 6);
    await clickScrollableButton(page, '6月を終了して7月へ');
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
