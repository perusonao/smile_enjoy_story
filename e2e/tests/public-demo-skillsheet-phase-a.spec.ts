// SKILLSHEET-UX-2A Phase A verification — the mobile-first SkillSheet sheet
// redesign (see docs/reports/SES_ISSUE-132_Phase-A_Implementation_Result.md).
//
// This does not re-verify game logic or #117's own semantics in depth —
// public-demo-fresh-start.spec.ts already owns that smoke test and is left
// untouched. This spec instead proves, at both 360px and 390px viewports:
//   * no horizontal overflow/clipping while the sheet is open
//   * the sheet's content is real domain data (佐藤健's own summary/skill
//     numbers), not placeholder text
//   * accordion sections are tappable
//   * Back does not advance HOME's progress and the sheet can be reopened
//   * explicit confirm is the only thing that advances, then HOME/sales
//     start remain reachable — the same #117 contract, at each width
import { test, expect } from '@playwright/test';
import { watchForErrors, captureMilestone } from '../helpers/artifacts';

const VIEWPORTS = [
  { label: '360x800', width: 360, height: 800 },
  { label: '390x800', width: 390, height: 800 },
];

async function hasNoHorizontalOverflow(page: import('@playwright/test').Page): Promise<boolean> {
  return page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
}

for (const viewport of VIEWPORTS) {
  test.describe(`SkillSheet Phase A @ ${viewport.label}`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test(`fresh start -> SkillSheet -> back -> reopen -> confirm -> sales start (${viewport.label})`, async ({
      page,
    }, testInfo) => {
      const errors = watchForErrors(page);

      await page.goto('/?e2e=1#/public-demo-01');
      await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });

      await expect(async () => {
        const raw = await page.locator('body').ariaSnapshot();
        expect(raw, 'Public Demo identity').toContain('S.E.S. Public Demo 0.1');
        expect(raw, 'initial employee').toContain('佐藤 健');
      }).toPass({ timeout: 15_000 });

      expect(await hasNoHorizontalOverflow(page), `HOME must not overflow at ${viewport.label}`).toBe(true);
      await captureMilestone(page, testInfo, `${viewport.label}-01-home`);

      // ---- HOME -> Sato SkillSheet -----------------------------------
      await page.getByRole('button', { name: 'SkillSheetを確認', exact: true }).click();
      await expect(page.getByText('営業用SkillSheet', { exact: false })).toBeVisible({ timeout: 15_000 });

      // ---- content is real domain data, not placeholder text --------
      await expect(page.getByText('Java / SQL・開発経験3年', { exact: true })).toBeVisible();
      await expect(page.getByText('案件スキル適合', { exact: true })).toBeVisible();
      await expect(page.getByText('ヒューマンスキル', { exact: true })).toBeVisible();
      await expect(page.getByText('モチベーション', { exact: true })).toBeVisible();
      await expect(page.getByText('取引先からの信頼', { exact: true })).toBeVisible();
      await expect(page.getByText('78', { exact: true })).toBeVisible(); // Sato's actual skillFit

      expect(await hasNoHorizontalOverflow(page), `SkillSheet sheet must not overflow at ${viewport.label}`).toBe(
        true,
      );
      await captureMilestone(page, testInfo, `${viewport.label}-02-skillsheet-open`);

      // ---- accordion sections are tappable ---------------------------
      await page.getByText('技術スキル', { exact: true }).click();
      await expect(page.getByText('Backend Lv.3', { exact: true })).toBeVisible({ timeout: 10_000 });
      expect(await hasNoHorizontalOverflow(page), `expanded 技術スキル must not overflow at ${viewport.label}`).toBe(
        true,
      );

      await page.getByText('経験', { exact: true }).click();
      await expect(page.getByText(/実経験/, { exact: false })).toBeVisible({ timeout: 10_000 });
      await expect(page.getByText(/SkillSheet記載/, { exact: false })).toBeVisible();
      expect(await hasNoHorizontalOverflow(page), `expanded 経験 must not overflow at ${viewport.label}`).toBe(true);
      await captureMilestone(page, testInfo, `${viewport.label}-03-accordion-expanded`);

      await expect(page.getByRole('button', { name: '営業開始', exact: true })).toHaveCount(0);

      // ---- Back does not advance progress; CTA remains reachable -----
      await page.getByRole('button', { name: '戻る', exact: true }).click();
      await expect(page.getByRole('button', { name: 'SkillSheetを確認', exact: true })).toBeVisible();
      await expect(page.getByRole('button', { name: '営業開始', exact: true })).toHaveCount(0);
      expect(await hasNoHorizontalOverflow(page), `HOME after Back must not overflow at ${viewport.label}`).toBe(
        true,
      );

      // ---- reopen is possible -----------------------------------------
      await page.getByRole('button', { name: 'SkillSheetを確認', exact: true }).click();
      await expect(page.getByText('営業用SkillSheet', { exact: false })).toBeVisible();

      // ---- explicit confirm is the only thing that advances -----------
      const confirmButton = page.getByRole('button', { name: '内容を確認', exact: true });
      await expect(confirmButton).toBeVisible();
      expect(await hasNoHorizontalOverflow(page), `sticky CTA row must not overflow at ${viewport.label}`).toBe(true);
      await confirmButton.click();
      await expect(page.getByRole('button', { name: '営業を開始', exact: true })).toBeVisible({ timeout: 15_000 });
      await captureMilestone(page, testInfo, `${viewport.label}-04-confirmed-home`);

      const afterConfirm = await page.locator('body').ariaSnapshot();
      expect(afterConfirm, 'playthrough must remain non-terminal after confirming SkillSheet').not.toContain(
        'このプレイスルーは終了しました。',
      );
      expect(await hasNoHorizontalOverflow(page), `HOME after confirm must not overflow at ${viewport.label}`).toBe(
        true,
      );

      // ---- sales start is reachable from HOME --------------------------
      await page.getByRole('button', { name: '営業を開始', exact: true }).click();
      await expect(page.getByRole('button', { name: '営業を開始', exact: true })).toHaveCount(0, { timeout: 15_000 });
      await captureMilestone(page, testInfo, `${viewport.label}-05-sales-started`);
      expect(await hasNoHorizontalOverflow(page), `HOME after sales start must not overflow at ${viewport.label}`).toBe(
        true,
      );

      expect(errors.pageErrors, `uncaught page errors at ${viewport.label}`).toEqual([]);
      expect(errors.crashed, `page crashed at ${viewport.label}`).toBe(false);
      expect(errors.consoleErrors, `unallowlisted console.error at ${viewport.label}`).toEqual([]);
    });
  });
}
