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
      // HOME UI Phase 1 deleted the standalone `社員ステージ` summary card
      // (and its "営業準備前" status vocabulary with it) as a duplicate of
      // the Office Stage employee summary already on HOME — the initial
      // employee is still asserted below via the Office Stage's own name
      // label and the reachable SkillSheet action.
      expect(raw, 'initial employee').toContain('佐藤 健');
      expect(raw, 'initial real action').toContain('SkillSheetを確認');
      expect(raw, 'fresh start must not already be terminal').not.toContain('このプレイスルーは終了しました。');
      expect(raw, 'fresh start must not already be bankrupt').not.toContain('倒産');
    }).toPass({ timeout: 15_000 });

    // The production HOME action now opens inspectable SkillSheet content
    // first. Merely opening it must not silently advance the sales stage.
    await page.getByRole('button', { name: 'SkillSheetを確認', exact: true }).click();
    await expect(page.getByText('営業用SkillSheet', { exact: false })).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('Java / SQL・開発経験3年', { exact: true })).toBeVisible();
    await expect(page.getByText('案件スキル適合', { exact: true })).toBeVisible();
    await expect(page.getByText('ヒューマンスキル', { exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: '営業を開始', exact: true })).toHaveCount(0);

    // Back/cancel is a no-op. The same SkillSheet action remains available
    // and sales start is still unavailable.
    await page.getByRole('button', { name: '戻る', exact: true }).click();
    await expect(page.getByRole('button', { name: 'SkillSheetを確認', exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: '営業を開始', exact: true })).toHaveCount(0);

    // Only explicit confirmation advances to the existing sales-start step.
    await page.getByRole('button', { name: 'SkillSheetを確認', exact: true }).click();
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