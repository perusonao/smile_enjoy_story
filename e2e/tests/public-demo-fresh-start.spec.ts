// PUBLIC-DEMO-E2E-1A — the smallest real-browser check that the separately
// routed Public Demo is reachable as a playable fresh start. This does not
// drive month progression or inject state: it only follows the first action
// a player can take on the actual Public Demo HOME surface.
import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';

test.describe('Public Demo fresh start', () => {
  test('Public Demo route opens in April with a reachable initial employee action', async ({ page }) => {
    const errors = watchForErrors(page);

    // The hash route is the static-host-safe public entry point. `e2e=1`
    // only enables Flutter Web semantics; it does not seed or alter gameplay.
    await page.goto('/?e2e=1#/public-demo-01');
    await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });

    // Read the browser's actual accessibility snapshot directly here. The
    // generic game-state parser intentionally normalizes semantics for the
    // auto-player, but this smoke test needs to prove the Public Demo HOME
    // identity/presentation itself, including merged Flutter semantics nodes.
    await expect(async () => {
      const raw = await page.locator('body').ariaSnapshot();
      expect(raw, 'Public Demo identity').toContain('S.E.S. Public Demo 0.1');
      expect(raw, 'fresh-start month').toContain('4月');
      expect(raw, 'employee stage').toContain('社員ステージ');
      expect(raw, 'initial employee').toContain('佐藤 健');
      expect(raw, 'initial sales state').toContain('営業準備前');
      expect(raw, 'initial real action').toContain('SkillSheetを確認');
      expect(raw, 'fresh start must not already be terminal').not.toContain('このプレイスルーは終了しました。');
      expect(raw, 'fresh start must not already be bankrupt').not.toContain('倒産');
    }).toPass({ timeout: 15_000 });

    // This is the production HOME button for the initial employee. It uses
    // the real workflow command and demonstrates that the SkillSheet step is
    // browser-reachable without a test fixture or internal state mutation.
    await page.getByRole('button', { name: 'SkillSheetを確認', exact: true }).click();

    await expect(page.getByRole('button', { name: '営業を開始', exact: true })).toBeVisible({ timeout: 15_000 });
    const afterSkillSheet = await page.locator('body').ariaSnapshot();
    expect(afterSkillSheet, 'playthrough must remain non-terminal after opening SkillSheet').not.toContain(
      'このプレイスルーは終了しました。',
    );

    expect(errors.pageErrors, 'uncaught page errors on Public Demo fresh start').toEqual([]);
    expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    expect(errors.consoleErrors, 'unallowlisted console.error on Public Demo fresh start').toEqual([]);
  });
});