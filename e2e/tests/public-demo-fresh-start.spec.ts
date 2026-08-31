// PUBLIC-DEMO-E2E-1A — the smallest real-browser check that the separately
// routed Public Demo is reachable as a playable fresh start. This does not
// drive month progression or inject state: it only follows the first action
// a player can take on the actual Public Demo HOME surface.
import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';
import { hasText, snapshotScreen } from '../helpers/game-state';

test.describe('Public Demo fresh start', () => {
  test('Public Demo route opens in April with a reachable initial employee action', async ({ page }) => {
    const errors = watchForErrors(page);

    // The hash route is the static-host-safe public entry point. `e2e=1`
    // only enables Flutter Web semantics; it does not seed or alter gameplay.
    await page.goto('/?e2e=1#/public-demo-01');
    await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });

    await expect(async () => {
      const snap = await snapshotScreen(page);
      expect(hasText(snap, 'S.E.S. Public Demo 0.1')).toBe(true);
      expect(hasText(snap, '4月')).toBe(true);
      expect(hasText(snap, '社員ステージ')).toBe(true);
      expect(hasText(snap, '佐藤 健')).toBe(true);
      expect(hasText(snap, '営業準備前')).toBe(true);
      expect(hasText(snap, 'SkillSheetを確認')).toBe(true);
      expect(hasText(snap, 'このプレイスルーは終了しました。')).toBe(false);
      expect(hasText(snap, '倒産')).toBe(false);
    }).toPass({ timeout: 15_000 });

    // This is the production HOME button for the initial employee. It uses
    // the real workflow command and demonstrates that the SkillSheet step is
    // browser-reachable without a test fixture or internal state mutation.
    await page.getByRole('button', { name: 'SkillSheetを確認', exact: true }).click();

    await expect(async () => {
      const snap = await snapshotScreen(page);
      expect(hasText(snap, '営業を開始')).toBe(true);
      expect(hasText(snap, 'このプレイスルーは終了しました。')).toBe(false);
    }).toPass({ timeout: 15_000 });

    expect(errors.pageErrors, 'uncaught page errors on Public Demo fresh start').toEqual([]);
    expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    expect(errors.consoleErrors, 'unallowlisted console.error on Public Demo fresh start').toEqual([]);
  });
});