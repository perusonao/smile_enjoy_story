// PUBLIC-DEMO-E2E-1A — the smallest real-browser check that the separately
// routed Public Demo is reachable as a playable fresh start. This does not
// drive month progression or inject state: it only follows the first action
// a player can take on the actual Public Demo HOME surface.
import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';

async function waitForRenderedFrames(page: import('@playwright/test').Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
      ),
  );
}

/** Scrolls the open SkillSheet's own scrollable body (bounded, polling for
 * the target rather than a fixed scroll amount) until [locator] is on
 * screen. Mirrors `clickScrollableButton` in
 * public-demo-july-restart.spec.ts / `scrollToButton` in
 * public-demo-single-month-cta.spec.ts: Flutter Web's accessibility tree
 * only attaches a scrollable child's semantics once it is actually scrolled
 * into view. `PublicDemoSkillSheetSheet` wraps every section — including
 * 営業・面談プロフィール, the last one, holding 案件スキル適合 /
 * ヒューマンスキル — in one `SingleChildScrollView`, and that section sits
 * below the fold on a phone-height viewport until scrolled to, confirmed
 * against the real mobile-webkit CI failure (run 33450496884) this helper
 * responds to. */
async function scrollSheetUntilVisible(
  page: import('@playwright/test').Page,
  locator: import('@playwright/test').Locator,
  maxSteps = 20,
): Promise<void> {
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  for (let step = 0; step < maxSteps; step++) {
    if ((await locator.count()) > 0) {
      const box = await locator.first().boundingBox();
      if (box && viewport) {
        if (box.y >= 0 && box.y + box.height <= viewport.height) return;
        // Target is above the current viewport (an earlier assertion in
        // this same test scrolled the sheet further down already) — scroll
        // back up towards it instead of only ever scrolling down.
        if (box.y < 0) {
          await page.mouse.wheel(0, -500);
          await waitForRenderedFrames(page);
          continue;
        }
      }
    }
    await page.mouse.wheel(0, 500);
    await waitForRenderedFrames(page);
  }
}

test.describe('Public Demo fresh start', () => {
  test('Public Demo route opens in April with a reachable initial employee action', async ({ page }) => {
    const errors = watchForErrors(page);

    // The hash route is the static-host-safe public entry point. `e2e=1`
    // only enables Flutter Web semantics; it does not seed or alter gameplay.
    await page.goto('/?e2e=1#/public-demo-01');
    await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });

    // Smoke-test the stable gameplay contract rather than presentation copy.
    // HOME labels/status wording may change during UI polish without changing
    // whether a fresh Public Demo is playable.
    await expect(async () => {
      const raw = await page.locator('body').ariaSnapshot();
      expect(raw, 'Public Demo identity').toContain('S.E.S. Public Demo 0.1');
      expect(raw, 'fresh-start month').toContain('4月');
      expect(raw, 'initial employee').toContain('佐藤 健');
      expect(raw, 'initial real action').toContain('スキルシートを確認');
      expect(raw, 'fresh start must not already be terminal').not.toContain('このプレイスルーは終了しました。');
      expect(raw, 'fresh start must not already be bankrupt').not.toContain('倒産');
    }).toPass({ timeout: 15_000 });

    // The production HOME action now opens inspectable SkillSheet content
    // first. Merely opening it must not silently advance the sales stage.
    await page.getByRole('button', { name: 'スキルシートを確認', exact: true }).click();
    await expect(page.getByText('営業用SkillSheet', { exact: false })).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('Java / SQL・開発経験3年', { exact: true })).toBeVisible();

    // 案件スキル適合/ヒューマンスキル live in 営業・面談プロフィール, the
    // SkillSheet's last (already-expanded) section — scroll the sheet's own
    // content to bring it on screen before asserting, the same way a real
    // player would, rather than asserting against an unscrolled viewport.
    await scrollSheetUntilVisible(page, page.getByText('案件スキル適合', { exact: true }));
    await expect(page.getByText('案件スキル適合', { exact: true })).toBeVisible();
    await expect(page.getByText('ヒューマンスキル', { exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: '営業を開始', exact: true })).toHaveCount(0);

    // Back/cancel is a no-op. The same SkillSheet action remains available
    // and sales start is still unavailable.
    await page.getByRole('button', { name: '戻る', exact: true }).click();
    await expect(page.getByRole('button', { name: 'スキルシートを確認', exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: '営業を開始', exact: true })).toHaveCount(0);

    // Only explicit confirmation advances to the existing sales-start step.
    await page.getByRole('button', { name: 'スキルシートを確認', exact: true }).click();
    await expect(page.getByText('営業用SkillSheet', { exact: false })).toBeVisible();
    await page.getByRole('button', { name: '内容を確認', exact: true }).click();
    await expect(page.getByRole('button', { name: '営業を開始', exact: true })).toBeVisible({ timeout: 15_000 });

    const afterSkillSheet = await page.locator('body').ariaSnapshot();
    expect(afterSkillSheet, 'playthrough must remain non-terminal after confirming SkillSheet').not.toContain(
      'このプレイスルーは終了しました。',
    );

    expect(errors.pageErrors, 'uncaught page errors on Public Demo fresh start').toEqual([]);
    expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    expect(errors.consoleErrors, 'unallowlisted console.error on Public Demo fresh start').toEqual([]);
  });
});
