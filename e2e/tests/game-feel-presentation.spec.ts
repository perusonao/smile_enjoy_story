// Playable 0.4C.3 — Game Feel / Presentation: targeted checks for the new
// UI surfaces this release adds (persistent HUD, company-phase banner,
// recruitment-interview question cards, first-assignment celebration
// breakdown) on top of the existing Founding→First Assignment coverage.
//
// Deliberately light — `founding-first-assignment.spec.ts` already proves
// the full playthrough never dead-ends and throws no console errors; these
// tests assert the *specific new copy/structure* this release introduces.
// Flutter Web (CanvasKit) draws everything to a single <canvas> — there is
// no real DOM text to query, only the accessibility/semantics tree it
// projects (enabled via `?e2e=1`, see lib/main.dart) — so, like every other
// spec in this repo, these read the UI via `snapshotScreen()`'s
// ariaSnapshot(), never raw DOM text locators (see e2e/README.md "Why no
// debug API").
import { test, expect } from '@playwright/test';
import { playFoundingToFirstAssignment } from '../helpers/ses-player';
import { watchForErrors } from '../helpers/artifacts';
import { hasText, snapshotScreen } from '../helpers/game-state';

test.describe('Persistent management HUD (§2)', () => {
  test('HUD shows Week / cash / headcount / month-end forecast and survives a tab switch', async ({ page }) => {
    watchForErrors(page);
    await page.goto('/?e2e=1&seed=100001');

    // First real paint: headless/no-GPU Chromium falls back to software
    // rendering, so Flutter's semantics tree can take several seconds to
    // attach (observed ~5-15s locally, matching ses-player.ts's own note).
    await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });

    // '自由モード' skips straight to free management so the HUD's steady-
    // state (post-tutorial) content is what gets asserted here. `.click()`
    // auto-waits for the button itself to attach/be actionable.
    await page.getByRole('button', { name: '【自由モード】', exact: true }).click({ timeout: 45_000 });

    // The HUD (management_hud.dart) is one tappable region (opens the
    // finance detail sheet), so Flutter Web's semantics tree exposes its
    // whole row as a single button's accessible name, not separate `text:`
    // entries — hence checking substrings via `hasText` (texts OR button
    // names), the same helper every other spec in this repo uses, rather
    // than a strict `texts`-only regex.
    const assertHudPresent = async () => {
      await expect(async () => {
        const snap = await snapshotScreen(page);
        expect(hasText(snap, 'WEEK')).toBe(true);
        expect(hasText(snap, '月末予想')).toBe(true);
        const all = [...snap.texts, ...snap.buttons.map((b) => b.name)];
        expect(all.some((t) => /\d+人/.test(t))).toBe(true);
      }).toPass({ timeout: 15_000 });
    };

    await assertHudPresent();

    // Switch tabs — the HUD lives in MainShell, above the per-tab
    // IndexedStack, so it must still be there after navigating away from
    // Home (§2: "常時表示").
    await page.getByRole('button', { name: '社員' }).click();
    await assertHudPresent();
  });
});

test.describe('Founding First Assignment — new presentation surfaces (§5-6, §9-10)', () => {
  test('recruitment-interview cards and company-phase banner render during a real playthrough', async ({ page }, testInfo) => {
    test.setTimeout(180_000);
    const errors = watchForErrors(page);
    await page.goto('/?e2e=1&seed=100001');

    let sawQuestionCards = false;
    const result = await playFoundingToFirstAssignment(page, {
      maxWeeks: 12,
      maxActions: 100,
      idleTimeoutMs: 30_000,
      stallRepeatThreshold: 5,
      onScreen: async (_screen, snap) => {
        // §5-6: the question-selection screen (classified by ses-player.ts
        // via the same "質問 N / 3" text this release's card UI renders)
        // shows every category as a card with its info-type hint.
        if (sawQuestionCards) return;
        const hasCategoryCard = ['技術経験', '役割・経歴', '転職理由', 'チームワーク', '将来像', '働き方'].some((label) => hasText(snap, label));
        const infoHintPattern = /情報：(高|中|低)/;
        const hasInfoHint = snap.texts.some((t) => infoHintPattern.test(t)) || snap.buttons.some((b) => infoHintPattern.test(b.name));
        if (hasCategoryCard && hasInfoHint) sawQuestionCards = true;
      },
    });

    expect(result.stallDetected, `dead-end/stall: ${result.stallReason}`).toBe(false);
    expect(result.completed, 'did not reach first assignment').toBe(true);
    expect(errors.pageErrors).toEqual([]);
    expect(errors.crashed).toBe(false);
    expect(errors.consoleErrors).toEqual([]);
    expect(sawQuestionCards, 'never observed the recruitment-interview question cards + info hints').toBe(true);

    // §10: company-phase banner (company_phase_indicator.dart) reflects
    // company maturity. The driver stops the instant "初案件参画" is
    // observed anywhere (its own completion check), which lands on the
    // Prologue's own closing screen — advance past it via "経営を始める"
    // (which also finishes the guided founding, moving the phase banner's
    // bucket on to "会社経営スタート") before looking for the bottom-nav
    // Home tab.
    await page.getByRole('button', { name: '経営を始める', exact: true }).click({ timeout: 5_000 }).catch(() => {});
    await page.getByRole('button', { name: 'ホーム', exact: true }).click({ timeout: 5_000 }).catch(() => {});
    await expect(async () => {
      const snap = await snapshotScreen(page);
      expect(hasText(snap, '会社経営スタート') || hasText(snap, '初案件参画')).toBe(true);
    }).toPass({ timeout: 15_000 });

    await testInfo.attach('final-home', { body: await page.screenshot(), contentType: 'image/png' });
  });
});
