import { test, expect, type Page } from '@playwright/test';
import { watchForErrors, drainWheelDiagnostics } from '../helpers/artifacts';

test('watchForErrors installs a portable wheel path that scrolls the page', async ({ page }) => {
  watchForErrors(page);
  await page.setContent('<div style="height:2000px">scroll</div>');
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(50);
  expect(await page.evaluate(() => window.scrollY)).toBeGreaterThan(0);
});

// SES_WEBKIT-SCROLL-1 Phase 4.1. The test above only ever proved the fallback
// can scroll a *plain* page via `window.scrollBy`. Its fixture contains no
// `flt-semantics` element at all, so it never entered the Flutter-specific
// branch and passed whether that branch worked or not — which is how a
// fallback that moved nothing on 150 consecutive real invocations stayed
// green in CI (run 33193672549, e2e-webkit).
//
// This fixture reproduces the shape actually measured there: the element that
// wins a naive "largest scrollHeight - clientHeight" search is not scrollable
// at all, while the element that really scrolls is a `flt-semantics` node
// whose computed overflow-y is `hidden` — not `scroll`/`auto`. Against that
// shape the previous implementation is inert: its overflow-based filter
// matched 0 of 21 nodes in CI and 0 of 2 here, and its generic branch picks
// the decoy and moves nothing.
//
// `overflow: visible` with tall content is the load-bearing detail: such an
// element reports scrollHeight > clientHeight yet ignores every scrollTop
// write, so a strategy that does not verify its own effect cannot tell
// success from failure here.
const FLUTTER_SHAPED_FIXTURE = `
  <style>
    /* The page itself must not be able to scroll, so this fixture cannot be
       satisfied by the generic window fallback — only by finding the real
       scroller. */
    html, body { margin: 0; height: 100%; overflow: hidden; }
    /* flt-semantics is an unknown element and therefore inline by default,
       which would leave it with no scroll box at all. Flutter's engine lays
       these out as positioned blocks; the fixture must do the same or it
       would not reproduce the real shape. */
    flt-semantics { display: block; }
    #decoy { height: 120px; overflow: visible; }
    #real { height: 120px; overflow-y: hidden; }
  </style>
  <flt-semantics id="decoy"><div style="height:4000px">not actually scrollable</div></flt-semantics>
  <flt-semantics id="real"><div style="height:900px">the real scroller</div></flt-semantics>
`;

/** Makes the native wheel raise the exact mobile-WebKit rejection the
 * fallback keys on, so the fallback runs on *both* projects. Without this
 * the branch under test would only ever execute on mobile-webkit and these
 * tests would have to be skipped on Chromium — and a skipped test is no
 * safer than the untested branch it replaces. */
async function forcePortableWheelPath(page: Page): Promise<void> {
  const mouse = page.mouse as unknown as { wheel: (x: number, y: number) => Promise<void> };
  mouse.wheel = async () => {
    throw new Error('Mouse wheel is not supported in mobile WebKit');
  };
  watchForErrors(page);
  await page.setContent(FLUTTER_SHAPED_FIXTURE);
  drainWheelDiagnostics(page);
}

const readScroll = (page: Page) =>
  page.evaluate(() => ({
    decoy: document.querySelector('#decoy')!.scrollTop,
    real: document.querySelector('#real')!.scrollTop,
    windowY: window.scrollY,
  }));

test('the portable wheel path scrolls a Flutter-shaped semantics scroller, not just a plain page', async ({ page }) => {
  await forcePortableWheelPath(page);

  await page.mouse.wheel(0, 300);
  await page.waitForTimeout(50);

  const scrolled = await readScroll(page);
  // The decoy can never move and the page itself cannot scroll, so the only
  // way to pass is to have found the real semantics scroller.
  expect(scrolled.real, `the real semantics scroller did not move: ${JSON.stringify(scrolled)}`).toBeGreaterThan(0);
  expect(scrolled.decoy, 'the non-scrollable decoy cannot move').toBe(0);
  expect(scrolled.windowY, 'this fixture must not be satisfiable by scrolling the page').toBe(0);
});

test('the portable wheel path reports honestly which strategy moved something', async ({ page }) => {
  await forcePortableWheelPath(page);

  await page.mouse.wheel(0, 300);
  await page.waitForTimeout(50);
  const diagnostics = drainWheelDiagnostics(page);

  expect(diagnostics, 'the fallback must record one diagnostic per invocation').toHaveLength(1);
  const record = diagnostics[0];
  expect(record.attempts.length, 'every strategy tried must be recorded').toBeGreaterThan(0);
  expect(record.moved, `fallback reported no movement on a scrollable fixture; attempts=${JSON.stringify(record.attempts)}`).toBe(true);
  expect(record.movedBy, 'a moving fallback must name the strategy that worked').not.toBeNull();
  expect(record.attempts.some((a) => a.strategy === record.movedBy && a.moved)).toBe(true);

  // The exact regression this task exists for: a strategy that ran and
  // achieved nothing must be recorded `moved: false`, never quietly treated
  // as success. The decoy is guaranteed to be one such attempt.
  expect(
    record.attempts.some((a) => !a.moved),
    `an ineffective attempt must be recorded as such; attempts=${JSON.stringify(record.attempts)}`,
  ).toBe(true);
});
