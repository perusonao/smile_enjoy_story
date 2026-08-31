// Issue #118 (PUBLIC-DEMO-NAV-1A) — Screen Verification Gate: at 360px and
// 390px viewport widths, the Public Demo HOME must expose exactly one
// obvious next-month control (the canonical
// `Key('public-demo-monthly-primary-cta')` CTA), never a second legacy
// month-advance button reachable through the same screen state.
//
// The canonical CTA sits below the fold on a phone-height viewport.
// Flutter Web's accessibility tree only exposes nodes once their content is
// actually scrolled into view (confirmed against this repo's own
// `public-demo-july-restart.spec.ts`, whose `clickScrollableButton` helper
// exists for exactly this reason) — so every check below scrolls first,
// the same way a real player would, instead of asserting against an
// unscrolled snapshot.
import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';

const viewports = [
  { label: '360px', width: 360, height: 800 },
  { label: '390px', width: 390, height: 844 },
];

// The canonical CTA's own labels (see PublicDemo01PlaceholderScreen's
// `_monthlyPrimaryAction`). None of these ever contain the old dash-arrow
// format the removed legacy per-month buttons used.
const canonicalAprilLabel = '4月を終了して5月へ';
const canonicalMayLabel = '5月を終了して6月へ';

async function waitForRenderedFrames(page: import('@playwright/test').Page) {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
      ),
  );
}

/// Scrolls the page until an exact-named button is on screen, then returns
/// its locator. Mirrors `clickScrollableButton` in
/// `public-demo-july-restart.spec.ts` (same reason: Flutter Web only
/// attaches a scrollable child's semantics once it is actually scrolled
/// into view).
async function scrollToButton(
  page: import('@playwright/test').Page,
  name: string,
) {
  const button = page.getByRole('button', { name, exact: true });
  const viewport = page.viewportSize();
  if (viewport) await page.mouse.move(viewport.width / 2, viewport.height / 2);
  for (let step = 0; step < 30; step++) {
    if ((await button.count()) > 0) {
      const box = await button.boundingBox();
      if (
        box &&
        viewport &&
        box.y >= 0 &&
        box.y + box.height <= viewport.height
      ) {
        return button;
      }
    }
    await page.mouse.wheel(0, 500);
    await waitForRenderedFrames(page);
  }
  return button;
}

async function expectNoLegacyArrowLabel(page: import('@playwright/test').Page) {
  const snapshot = await page.locator('body').ariaSnapshot();
  // Any occurrence of the old dash-arrow label shape would mean a legacy
  // control resurfaced alongside the canonical one.
  expect(snapshot, 'no legacy dash-arrow month-advance label may appear').not.toMatch(/終了→/);
}

for (const viewport of viewports) {
  test.describe(`Public Demo single month-advance CTA at ${viewport.label}`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test(`April HOME exposes exactly one month-advance CTA at ${viewport.label}`, async ({ page }) => {
      const errors = watchForErrors(page);

      await page.goto('/?e2e=1#/public-demo-01');
      await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });

      const aprilCta = await scrollToButton(page, canonicalAprilLabel);
      await expect(aprilCta).toBeVisible({ timeout: 15_000 });
      await expect(
        page.getByRole('button', { name: canonicalAprilLabel, exact: true }),
      ).toHaveCount(1);
      await expectNoLegacyArrowLabel(page);

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    });

    test(`May HOME still exposes exactly one month-advance CTA at ${viewport.label}`, async ({ page }) => {
      const errors = watchForErrors(page);

      await page.goto('/?e2e=1#/public-demo-01');
      await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });

      const aprilCta = await scrollToButton(page, canonicalAprilLabel);
      await expect(aprilCta).toBeVisible({ timeout: 15_000 });
      await aprilCta.click();

      const applicationDialog = page.getByRole('alertdialog');
      await expect(applicationDialog).toBeVisible();
      await applicationDialog.getByRole('button', { name: '確認', exact: true }).click();

      const mayCta = await scrollToButton(page, canonicalMayLabel);
      await expect(mayCta).toBeVisible({ timeout: 15_000 });
      await expect(
        page.getByRole('button', { name: canonicalMayLabel, exact: true }),
      ).toHaveCount(1);
      await expectNoLegacyArrowLabel(page);

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    });
  });
}
