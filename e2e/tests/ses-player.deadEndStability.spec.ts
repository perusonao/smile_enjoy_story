// Regression coverage for waitForActionableOrStableDeadEnd() (re-review
// §1-11): the generalized, content-agnostic bounded stability check that
// runs whenever decideAction() finds no legal action on a snapshot, before
// that's treated as a dead-end. Exercises it against a real Playwright
// `page` (plain HTML driven via page.evaluate(), not Flutter) so
// snapshotScreen()'s actual ariaSnapshot()-parsing path is exercised end to
// end, exactly like production — only the DOM content differs.
//
// The bug this guards: a real, *non-empty* transient screen (WebKit's
// "応募者が見つかりません" / buttons=[] frame right after a hire decision,
// before the next screen's semantics attach) was previously treated as an
// immediate dead-end on a single read. Deliberately does not special-case
// that string anywhere — every case here uses generic placeholder text to
// prove the fix is content-agnostic (§12 of the re-review).
import { test, expect } from '@playwright/test';
import { snapshotScreen } from '../helpers/game-state';
import { NO_ACTION_STABILITY_WINDOW_MS, waitForActionableOrStableDeadEnd, type DeadEndCheck } from '../helpers/ses-player';

const NO_ACTION_TEXT = '<p>状態Aです</p>';
const ACTIONABLE_HTML = '<button>次の週へ</button>';
const DECIDE_OPTS = { forceRejectFirstCandidate: false };

test.describe('waitForActionableOrStableDeadEnd() (re-review §11 regression cases)', () => {
  test('Case 1: a transient non-empty/no-action snapshot resolving to an actionable screen is NOT a dead-end', async ({ page }) => {
    await page.setContent(`<body>${NO_ACTION_TEXT}</body>`);
    const initial = await snapshotScreen(page);
    expect(initial.buttons).toEqual([]);

    const [check] = await Promise.all([
      waitForActionableOrStableDeadEnd(page, initial, DECIDE_OPTS),
      (async () => {
        await page.waitForTimeout(300);
        await page.evaluate((html) => {
          document.body.innerHTML = html;
        }, ACTIONABLE_HTML);
      })(),
    ]);

    expect(check.status).toBe('actionable');
    expect(check.decision?.name).toBe('次の週へ');
  });

  test('Case 2: a genuinely stable non-empty/no-action snapshot (never changes) is a real dead-end', async ({ page }) => {
    await page.setContent(`<body>${NO_ACTION_TEXT}</body>`);
    const initial = await snapshotScreen(page);

    // No mutation at all — the DOM never changes for the whole window.
    const check = await waitForActionableOrStableDeadEnd(page, initial, DECIDE_OPTS);

    expect(check.status).toBe('stable-dead-end');
    expect(check.decision).toBeNull();
  });

  test('Case 3: a fully-empty frame inside the window still recovers to actionable (existing empty-recovery preserved)', async ({ page }) => {
    await page.setContent(`<body>${NO_ACTION_TEXT}</body>`);
    const initial = await snapshotScreen(page);

    const [check] = await Promise.all([
      waitForActionableOrStableDeadEnd(page, initial, DECIDE_OPTS),
      (async () => {
        await page.waitForTimeout(200);
        await page.evaluate(() => {
          document.body.innerHTML = ''; // transient fully-empty frame
        });
        await page.waitForTimeout(200);
        await page.evaluate((html) => {
          document.body.innerHTML = html;
        }, ACTIONABLE_HTML);
      })(),
    ]);

    expect(check.status).toBe('actionable');
    expect(check.decision?.name).toBe('次の週へ');
  });

  test('Case 4: multiple distinct transitional non-action snapshots eventually resolve to actionable via repeated hops', async ({ page }) => {
    await page.setContent(`<body>${NO_ACTION_TEXT}</body>`);
    let snap = await snapshotScreen(page);

    // Hop 1: transitions to a *different* still-non-actionable state — must
    // report 'transitioning', not 'stable-dead-end', and must not itself
    // keep polling all the way to the eventual actionable screen (§10: no
    // nested nested-timeout accumulation inside one call).
    const [check1] = await Promise.all([
      waitForActionableOrStableDeadEnd(page, snap, DECIDE_OPTS),
      (async () => {
        await page.waitForTimeout(250);
        await page.evaluate(() => {
          document.body.innerHTML = '<p>状態Bです</p>';
        });
      })(),
    ]);
    expect(check1.status).toBe('transitioning');
    snap = check1.snapshot;

    // Hop 2: the caller (here, the test, mirroring the real outer loop's
    // `continue` + fresh decideAction/waitForActionableOrStableDeadEnd
    // call) re-invokes with the new baseline and this time it lands on an
    // actionable screen.
    const [check2] = await Promise.all([
      waitForActionableOrStableDeadEnd(page, snap, DECIDE_OPTS),
      (async () => {
        await page.waitForTimeout(250);
        await page.evaluate((html) => {
          document.body.innerHTML = html;
        }, ACTIONABLE_HTML);
      })(),
    ]);
    expect(check2.status).toBe('actionable');
    expect(check2.decision?.name).toBe('次の週へ');
  });

  test('sanity: the stable-dead-end window is the documented NO_ACTION_STABILITY_WINDOW_MS', async ({ page }) => {
    await page.setContent(`<body>${NO_ACTION_TEXT}</body>`);
    const initial = await snapshotScreen(page);

    const startedAt = Date.now();
    const check: DeadEndCheck = await waitForActionableOrStableDeadEnd(page, initial, DECIDE_OPTS);
    const elapsed = Date.now() - startedAt;

    expect(check.status).toBe('stable-dead-end');
    expect(elapsed).toBeGreaterThanOrEqual(NO_ACTION_STABILITY_WINDOW_MS);
    // Generous upper bound — bounded, not open-ended (§6 of the re-review).
    expect(elapsed).toBeLessThan(NO_ACTION_STABILITY_WINDOW_MS + 2_000);
  });
});
