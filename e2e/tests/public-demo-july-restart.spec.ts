import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';

async function expectMonth(page: import('@playwright/test').Page, month: number) {
  await expect(async () => {
    const snapshot = await page.locator('body').ariaSnapshot();
    expect(snapshot).toContain(`1年目 ${month}月`);
  }).toPass();
}

async function waitForRenderedFrames(page: import('@playwright/test').Page) {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
      ),
  );
}

async function clickScrollableButton(
  page: import('@playwright/test').Page,
  name: string,
) {
  const button = page.getByRole('button', { name, exact: true });
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  for (let step = 0; step < 20; step++) {
    if ((await button.count()) > 0) {
      const box = await button.boundingBox();
      if (
        box &&
        viewport &&
        box.y >= 0 &&
        box.y + box.height <= viewport.height
      ) {
        await button.click();
        return;
      }
      if (box?.y != null && box.y < 0) {
        await page.mouse.wheel(0, -500);
        await waitForRenderedFrames(page);
        continue;
      }
    }
    await page.mouse.wheel(0, 500);
    await waitForRenderedFrames(page);
  }
  await expect(button).toBeVisible();
  await button.click();
}

test.describe('Public Demo July close and April restart', () => {
  test('none closes July into August and the test restart is confirmable', async ({ page }) => {
    const errors = watchForErrors(page);

    await page.goto('/?e2e=1#/public-demo-01');
    await page.locator('flt-semantics').first().waitFor({ state: 'attached' });
    await expectMonth(page, 4);

    await clickScrollableButton(page, '4月を終了して5月へ');
    const applicationDialog = page.getByRole('alertdialog');
    await expect(applicationDialog).toBeVisible();
    expect(await applicationDialog.ariaSnapshot()).toContain('新しい応募が届きました');
    await applicationDialog.getByRole('button', { name: '確認', exact: true }).click();
    await expectMonth(page, 5);

    await clickScrollableButton(page, '5月を終了して6月へ');
    await expectMonth(page, 6);
    await clickScrollableButton(page, '6月を終了して7月へ');
    await expectMonth(page, 7);

    await clickScrollableButton(page, '夏季賞与を決める');
    const bonusDialog = page.getByRole('alertdialog');
    const none = bonusDialog.getByRole('button', { name: /^なし/ });
    await expect(none).toBeEnabled();
    await none.click();
    await clickScrollableButton(page, '7月を終了して8月へ');

    await expectMonth(page, 8);

    await clickScrollableButton(page, '4月からやり直す');
    const restartDialog = page.getByRole('alertdialog');
    await expect(restartDialog).toBeVisible();
    expect(await restartDialog.ariaSnapshot()).toContain('Public Demoを4月からやり直しますか？');

    await restartDialog.getByRole('button', { name: 'キャンセル', exact: true }).click();
    await expectMonth(page, 8);

    await clickScrollableButton(page, '4月からやり直す');
    await page
      .getByRole('alertdialog')
      .getByRole('button', { name: '4月からやり直す', exact: true })
      .click();

    await expectMonth(page, 4);
    expect(await page.locator('body').ariaSnapshot()).toContain('佐藤 健');
    await expect(page.getByRole('button', { name: 'SkillSheetを確認', exact: true })).toBeVisible();

    expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
    expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);
  });
});
