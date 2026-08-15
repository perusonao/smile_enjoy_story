// Boundary coverage for the completion-vs-cap ordering fix (Codex review on
// PR #3, item 3): playFoundingToFirstAssignment() must observe the result
// of the very last permitted action (the 100th action, or the 12th
// week-advancing action, in production) before a maxActions/maxWeeks cap
// can fail the run — not check the cap first and never look at what that
// last action actually did.
//
// Drives a real Playwright `page` against a minimal plain-HTML fixture
// (not Flutter) so playFoundingToFirstAssignment's own loop, snapshot
// reads, and real button clicks are exercised end to end — only the
// screen content is faked. Each click on the single "次の週へ" button
// (matched by decideAction's real, unmodified rule 10 — the same button
// production 今週やる操作はありません screens use) advances an in-page step
// counter; once the counter reaches a configured `completeAt`, the next
// render shows a completion screen containing "初案件参画" (the exact
// substring playFoundingToFirstAssignment's own completion check already
// looks for), with no button.
import { test, expect } from '@playwright/test';
import { playFoundingToFirstAssignment } from '../helpers/ses-player';

const FIXTURE_HTML = `
  <flt-semantics style="display:none"></flt-semantics>
  <div id="app"></div>
  <script>
    window.__step = 0;
    window.__completeAt = 0;
    window.render = function () {
      const app = document.getElementById('app');
      if (window.__step >= window.__completeAt) {
        app.innerHTML = '<p>初案件参画おめでとうございます</p>';
      } else {
        app.innerHTML = '<p>Week ' + window.__step + '</p><button>次の週へ</button>';
        app.querySelector('button').addEventListener('click', function () {
          window.__step += 1;
          window.render();
        });
      }
    };
  </script>
`;

async function setUpFixture(page: import('@playwright/test').Page, completeAt: number): Promise<void> {
  await page.setContent(FIXTURE_HTML);
  await page.evaluate((n) => {
    (window as unknown as { __completeAt: number; __step: number; render: () => void }).__completeAt = n;
    (window as unknown as { __step: number }).__step = 0;
    (window as unknown as { render: () => void }).render();
  }, completeAt);
}

// Large enough to never trip on its own within these short, few-action
// runs — these tests are about the completion/cap ordering, not the
// same-fingerprint stall detector (which the fixture's identical
// screen+button-set-every-tick would otherwise trigger, since that
// detector's fingerprint deliberately ignores body text — see
// waitForSemanticsChange vs the loop's own `fingerprint` in ses-player.ts).
const GENEROUS_STALL_THRESHOLD = 1000;
const IDLE_TIMEOUT_MS = 10_000;

test.describe('completion-vs-cap ordering (re-review §3 regression)', () => {
  test('completion on the final allowed action (maxActions) -> PASS, not a cap failure', async ({ page }) => {
    await setUpFixture(page, /* completeAt */ 3);

    const result = await playFoundingToFirstAssignment(page, {
      maxWeeks: 999,
      maxActions: 3,
      idleTimeoutMs: IDLE_TIMEOUT_MS,
      stallRepeatThreshold: GENEROUS_STALL_THRESHOLD,
    });

    expect(result.stallDetected, `expected no stall, got: ${result.stallReason}`).toBe(false);
    expect(result.completed).toBe(true);
    expect(result.actions).toBe(3);
  });

  test('no completion after the final allowed action -> a real cap failure', async ({ page }) => {
    await setUpFixture(page, /* completeAt */ 4);

    const result = await playFoundingToFirstAssignment(page, {
      maxWeeks: 999,
      maxActions: 3,
      idleTimeoutMs: IDLE_TIMEOUT_MS,
      stallRepeatThreshold: GENEROUS_STALL_THRESHOLD,
    });

    expect(result.completed).toBe(false);
    expect(result.stallDetected).toBe(true);
    expect(result.stallReason).toContain('max actions');
  });

  test('completion well before the cap -> PASS (normal case not broken by the reordering)', async ({ page }) => {
    await setUpFixture(page, /* completeAt */ 3);

    const result = await playFoundingToFirstAssignment(page, {
      maxWeeks: 999,
      maxActions: 10,
      idleTimeoutMs: IDLE_TIMEOUT_MS,
      stallRepeatThreshold: GENEROUS_STALL_THRESHOLD,
    });

    expect(result.stallDetected, `expected no stall, got: ${result.stallReason}`).toBe(false);
    expect(result.completed).toBe(true);
    expect(result.actions).toBe(3);
  });

  test('completion on the final allowed week-advancing action (maxWeeks) -> PASS, not a cap failure', async ({ page }) => {
    // Every click in this fixture is a "次の週へ" action, which decideAction
    // marks advancesWeek: true — so this exercises the identical reordered
    // check for weekAdvances >= maxWeeks (production's "12th week" case).
    await setUpFixture(page, /* completeAt */ 3);

    const result = await playFoundingToFirstAssignment(page, {
      maxWeeks: 3,
      maxActions: 999,
      idleTimeoutMs: IDLE_TIMEOUT_MS,
      stallRepeatThreshold: GENEROUS_STALL_THRESHOLD,
    });

    expect(result.stallDetected, `expected no stall, got: ${result.stallReason}`).toBe(false);
    expect(result.completed).toBe(true);
  });
});
