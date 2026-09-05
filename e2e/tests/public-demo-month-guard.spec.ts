// Issue #119 PR1 (Month Guard): the canonical monthly CTA
// (`Key('public-demo-monthly-primary-cta')`) is the single entry point for
// both "open the required July summer-bonus decision" and "close the
// month" — there must never be a second close control, tapping the CTA
// before the decision is acknowledged must open the decision UI without
// advancing the month, and once the decision is acknowledged (including the
// valid "none" route from #133) the same CTA must close July into August.
import { test, expect } from '@playwright/test';
import { watchForErrors } from '../helpers/artifacts';
import { dismissMonthGuardIfPresent } from '../helpers/public-demo-player';

const viewports = [
  { label: '360px', width: 360, height: 800 },
  { label: '390px', width: 390, height: 800 },
];

const canonicalAprilLabel = '4月を終了して5月へ';
const canonicalMayLabel = '5月を終了して6月へ';
const canonicalJuneLabel = '6月を終了して7月へ';
const canonicalJulyLabel = '7月を終了して8月へ';

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

async function clickScrollableButton(
  page: import('@playwright/test').Page,
  name: string,
) {
  const button = await scrollToButton(page, name);
  await expect(button).toBeVisible({ timeout: 15_000 });
  await button.click();
}

async function expectNoHorizontalOverflow(page: import('@playwright/test').Page) {
  const viewport = page.viewportSize();
  expect(viewport, 'viewport must be set for this check').not.toBeNull();
  const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
  expect(
    scrollWidth,
    `document.documentElement.scrollWidth (${scrollWidth}) must not exceed the viewport width`,
  ).toBeLessThanOrEqual(viewport!.width + 1);
}

for (const viewport of viewports) {
  test.describe(`Public Demo July Month Guard at ${viewport.label}`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test(`July CTA before decision opens the summer-bonus decision without advancing the month, and "none" then reaches August via the same CTA (${viewport.label})`, async ({ page }) => {
      const errors = watchForErrors(page);

      await page.goto('/?e2e=1#/public-demo-01');
      await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });
      await expectMonth(page, 4);
      await expectNoHorizontalOverflow(page);

      await clickScrollableButton(page, canonicalAprilLabel);
      // Issue #168 (FIRST-FUN-YEAR-ONBOARDING-1): April's close now runs
      // the Month Guard before its own new-applicant event dialog — a
      // fresh playthrough's untouched 佐藤 健 SkillSheet確認 is a genuinely
      // outstanding recommended-level action, so the guard's warning shows
      // first. Proceed through it exactly as a player choosing "このまま
      // 月末処理を進める" would; this suite's own subject is the July Month
      // Guard below, not April's dialogs.
      await dismissMonthGuardIfPresent(page);
      const applicationDialog = page.getByRole('alertdialog');
      await expect(applicationDialog).toBeVisible();
      await applicationDialog.getByRole('button', { name: '確認', exact: true }).click();
      await expectMonth(page, 5);

      await clickScrollableButton(page, canonicalMayLabel);
      // Same Issue #168 wiring as April, on May's own close: the two
      // pre-seeded applicants are still unreviewed and recruitment media
      // unused at this point, a genuinely outstanding recommended-level
      // action, so the guard can warn here too. May's close has no event
      // dialog of its own, so this is the only dialog to proceed through
      // before the month advances.
      await dismissMonthGuardIfPresent(page);
      await expectMonth(page, 6);
      await clickScrollableButton(page, canonicalJuneLabel);
      // Same Issue #168 wiring on June's own close: this playthrough never
      // performed the recommended April/May actions (this suite's own
      // subject is July's Month Guard, not the earlier months'), so June
      // may still see outstanding items and warn.
      await dismissMonthGuardIfPresent(page);
      await expectMonth(page, 7);
      await expectNoHorizontalOverflow(page);

      // Exactly one canonical CTA is on screen — never a second close
      // control alongside it. (Flutter Web only attaches a scrollable
      // child's semantics once it is actually scrolled into view, so scroll
      // to it first, same as every other check in this suite.)
      const julyCta = await scrollToButton(page, canonicalJulyLabel);
      await expect(julyCta).toBeVisible({ timeout: 15_000 });
      await expect(page.getByRole('button', { name: canonicalJulyLabel, exact: true })).toHaveCount(1);

      // Tapping the canonical CTA before the decision is acknowledged must
      // open the decision UI, not silently close July.
      await julyCta.click();
      const bonusDialog = page.getByRole('alertdialog');
      await expect(bonusDialog).toBeVisible();
      expect(await bonusDialog.ariaSnapshot()).toContain('夏季賞与');

      // Dismiss without deciding (Escape closes Flutter's barrier-
      // dismissible AlertDialog) and confirm the month did not silently
      // advance while the decision UI was open (a modal alertdialog hides
      // the rest of the a11y tree, so the month check has to happen with it
      // closed).
      await page.keyboard.press('Escape');
      await expect(bonusDialog).toBeHidden();
      await expectMonth(page, 7);

      // Re-open via the same canonical CTA and actually decide this time.
      await julyCta.click();
      await expect(bonusDialog).toBeVisible();

      // #133: choosing "none" is a valid, mandatory-closable route.
      const none = bonusDialog.getByRole('button', { name: /^なし/ });
      await expect(none).toBeEnabled();
      await none.click();
      await expectMonth(page, 7);

      // The same canonical CTA (never a second control) now closes July.
      const julyCtaAfterDecision = await scrollToButton(page, canonicalJulyLabel);
      await expect(julyCtaAfterDecision).toBeVisible({ timeout: 15_000 });
      await expect(page.getByRole('button', { name: canonicalJulyLabel, exact: true })).toHaveCount(1);
      await julyCtaAfterDecision.click();
      await expectMonth(page, 8);
      await expectNoHorizontalOverflow(page);

      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'Public Demo page crashed').toBe(false);
    });
  });
}
