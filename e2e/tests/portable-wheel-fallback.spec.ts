import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';

test('watchForErrors leaves supported mouse wheel behavior intact', async ({ page }) => {
  watchForErrors(page);
  await page.setContent('<div style="height:2000px">scroll</div>');
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(50);
  expect(await page.evaluate(() => window.scrollY)).toBeGreaterThan(0);
});
