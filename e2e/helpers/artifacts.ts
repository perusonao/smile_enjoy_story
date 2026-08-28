// Console/page-error capture + result-JSON / action-trace writers (§16-19).
import fs from 'fs';
import path from 'path';
import type { Page, TestInfo } from '@playwright/test';
import type { PlayResult } from './ses-player';

export interface ErrorWatcher {
  consoleErrors: string[];
  consoleWarnings: string[];
  pageErrors: string[];
  crashed: boolean;
}

/** Known-harmless console noise that isn't about fonts, allowlisted with a
 * reason (§19) — never silently widened; add an entry here only with a
 * one-line justification. Font-fetch noise is handled separately below
 * (Codex follow-up §9-11) because it needs a stricter, two-part check. */
const OTHER_ALLOWLIST: { pattern: RegExp; reason: string }[] = [
  {
    // Headless Chromium/CI has no GPU, so Skia/CanvasKit falls back to a
    // software rasterizer. Purely an environment notice from the browser
    // itself, not from S.E.S. — same fallback happens in every headless
    // Flutter Web CI run, real players on real devices never see it.
    pattern: /Automatic fallback to software WebGL/i,
    reason: 'headless/no-GPU CI environment notice, not app-caused',
  },
  {
    pattern: /GroupMarkerNotSet\(crbug\.com\/242999\)/i,
    reason: 'Chromium DevTools tracing marker noise, not app-caused',
  },
];

// --- Font-fetch allowlist (Codex follow-up §9-11, re-review §9-13) --------
//
// Flutter Web's CJK font fallback fetches Noto Sans SC/JP/HK glyph subsets
// from fonts.gstatic.com on demand; this sandbox's network policy blocks
// that, which only degrades glyph rendering for those code points — nothing
// in the Guided Founding flow depends on network access.
//
// Deliberately NOT one wide OR-regex (the original bug, per review): a bare
// `ERR_CONNECTION_RESET` says nothing about *which* host failed, and
// Chromium's "Failed to load resource: net::ERR_..." console text
// (`msg.text()`) never includes the URL at all — so text-matching alone
// can't prove it was fonts.gstatic.com and not, say, an app asset or an
// unrelated host. Three separate, named conditions instead:
//   1. isKnownFontHost         — a request's URL host is a known Google
//                                 Fonts CDN host.
//   2. isKnownNetworkFailureCode — the request failed with a network-level
//                                 (not app-level) error code.
//   3. isFontMessageWithHost   — for the two console message *shapes* that
//                                 already embed the host in their own text
//                                 ("Failed to load font ... at
//                                 https://fonts.gstatic.com/...", "Flutter
//                                 Web engine failed ... fetch
//                                 \"https://fonts.gstatic.com/...\"") — safe
//                                 to allowlist by text alone since the host
//                                 is verifiable right there.
//
// The URL-less "Failed to load resource: net::ERR_..." console message is
// the hard case: `msg.text()` alone can never prove which resource it was
// about. A first re-review fix used a single global `pendingKnownFont
// NetworkFailures` counter, incremented on a matching `requestfailed` and
// decremented by the *next* bare "Failed to load resource" console message
// — but that message shape is generic (Chromium emits the exact same text
// for *any* failed resource), so an unrelated resource's own bare console
// error arriving between the font's `requestfailed` and its own bare
// console message would consume the pending slot instead, silently
// swallowing the unrelated failure.
//
// Investigated directly (real Chromium, `requestfailed` + `console`
// listeners on a page with both a fonts.gstatic.com request and an
// unrelated-host request failing, interleaved): Playwright's
// `ConsoleMessage.location().url` — distinct from `msg.text()` — reliably
// carries the exact URL of the resource that failed, for this specific
// message shape, even though the message *text* never does. That gives a
// real per-resource identity to correlate against, instead of a blind
// count: `pendingKnownFontFailuresByUrl` below is keyed by the exact
// failing URL, so a bare console message only gets allowlisted if its own
// `location().url` matches a URL that independently satisfies (1) AND (2)
// above — an unrelated host's bare error can never consume a font
// failure's slot no matter how the events interleave, because the two
// URLs are never equal.
//
// Safe fallback (§12 of the review): if a browser doesn't populate
// `location().url` for this message shape, the message is simply left
// unallowlisted (recorded as a real consoleError) rather than falling back
// to any global/positional heuristic — a false negative (occasionally
// flagging real font noise as a failure) is strictly preferred over a false
// positive (hiding an unrelated resource's real failure).

const KNOWN_FONT_HOSTS = ['fonts.gstatic.com'];

export function isKnownFontHost(url: string): boolean {
  try {
    const host = new URL(url).host;
    return KNOWN_FONT_HOSTS.some((h) => host === h || host.endsWith(`.${h}`));
  } catch {
    return false;
  }
}

const KNOWN_NETWORK_FAILURE_CODES = [
  'net::ERR_CONNECTION_RESET',
  'net::ERR_CONNECTION_REFUSED',
  'net::ERR_CONNECTION_CLOSED',
  'net::ERR_NAME_NOT_RESOLVED',
  'net::ERR_INTERNET_DISCONNECTED',
  'net::ERR_NETWORK_CHANGED',
  'net::ERR_FAILED',
  // Phase 3A (S.E.S. Development Plan §3.2) local validation environment:
  // outbound HTTPS goes through an allowlisting proxy that answers a
  // blocked CONNECT with a 403 (confirmed directly against the Playwright
  // WebKit CDN host during this same session) — Chromium's network stack
  // reports that as this code, same root cause (fonts.gstatic.com
  // unreachable for the small set of CJK glyphs the bundled Noto Sans JP
  // subset doesn't cover) as the other entries above, just a different
  // failure surface than the sandbox this list was originally tuned in.
  'net::ERR_TUNNEL_CONNECTION_FAILED',
];

export function isKnownNetworkFailureCode(errorText: string): boolean {
  return KNOWN_NETWORK_FAILURE_CODES.some((code) => errorText.includes(code));
}

const RESOURCE_LOAD_FAILURE_MESSAGE = /^\[error\] Failed to load resource: (net::[A-Z_]+)/;

// These two shapes embed the failing host directly in the console text, so
// a single text-level AND (shape + host substring) is sound on its own.
const FONT_FETCH_MESSAGE_SHAPES = [/Failed to load font\b/i, /Flutter Web engine failed to complete HTTP request to fetch\b/i];

export function isFontMessageWithHost(text: string): boolean {
  return FONT_FETCH_MESSAGE_SHAPES.some((p) => p.test(text)) && isKnownFontHost(extractFirstUrl(text) ?? '');
}

function extractFirstUrl(text: string): string | null {
  const m = /https?:\/\/[^\s"]+/.exec(text);
  return m ? m[0] : null;
}

const MOBILE_WEBKIT_WHEEL_UNSUPPORTED = /Mouse wheel is not supported in mobile WebKit/i;
const PORTABLE_WHEEL_INSTALLED = Symbol('sesPortableWheelInstalled');
type PortableMouse = Page['mouse'] & { [PORTABLE_WHEEL_INSTALLED]?: boolean };

/**
 * PR #80 follow-up: Playwright intentionally rejects `page.mouse.wheel()`
 * when WebKit is running with the mobile/touch context. The recruitment
 * recovery helper uses that API only as a bounded viewport nudge to bring an
 * off-screen Flutter ListView child into the semantics tree. Keep Chromium's
 * native wheel path unchanged, but provide the equivalent browser-side wheel
 * event / DOM-scroll fallback only for that one explicit mobile-WebKit error.
 * Event-watcher unit tests deliberately use a minimal Page-shaped mock with
 * no mouse; those callers do not need scrolling, so preserve that supported
 * test seam by treating a missing mouse as a no-op here.
 */
/** One attempt at one scroll strategy, and whether it demonstrably moved
 * anything. Recorded even when it did not — an inert fallback must never
 * look like a successful one. */
export interface WheelStrategyAttempt {
  strategy: 'wheelEvent' | 'pointerDrag' | 'semanticsScroll' | 'genericScroll' | 'windowScroll';
  moved: boolean;
  detail?: string;
}

export interface WheelFallbackDiagnostic {
  /** The strategy that actually moved something, or null when every one of
   * them was inert — the signal that this invocation achieved nothing. */
  movedBy: WheelStrategyAttempt['strategy'] | null;
  attempts: WheelStrategyAttempt[];
  /** Total `flt-semantics` elements in the DOM at the time of the call. */
  fltSemanticsTotal: number;
  /** How many were *programmatically* scrollable (`scrollHeight >
   * clientHeight`), which is the property that actually matters — not the
   * computed `overflow-y`, which on mobile WebKit is `visible` for every
   * Flutter semantics node (measured: 20 visible + 1 hidden of 21). */
  fltSemanticsScrollable: number;
  /** Computed `overflow-y` histogram across all `flt-semantics` elements. */
  fltSemanticsOverflowY: Record<string, number>;
  windowScrollYBefore: number;
  windowScrollYAfter: number;
  /** True when any strategy moved something. */
  moved: boolean;
}

// SES_WEBKIT-SCROLL-1: one record per mobile-WebKit wheel-fallback
// invocation, so a CI *log* can answer "did the fallback actually move
// anything?" without downloading the 300 MB+ results artifact.
const MAX_WHEEL_DIAGNOSTICS = 400;
const wheelDiagnostics = new WeakMap<Page, WheelFallbackDiagnostic[]>();

/** Returns and clears the wheel-fallback diagnostics recorded for [page]
 * since the last drain. Empty on Chromium, which never enters the fallback. */
export function drainWheelDiagnostics(page: Page): WheelFallbackDiagnostic[] {
  const recorded = wheelDiagnostics.get(page) ?? [];
  wheelDiagnostics.set(page, []);
  return recorded;
}

/** What one bounded scroll loop observed about its own effect. */
export interface ScrollEffectEvidence {
  /** How many scroll steps were actually attempted. */
  steps: number;
  /** Whether the accessibility snapshot ever changed across those steps —
   * the only evidence that Flutter re-laid out and materialized anything. */
  fingerprintChanged: boolean;
  /** Wheel-fallback invocations recorded during the loop. Zero on Chromium,
   * whose native wheel path produces no measurements at all. */
  wheelInvocations: number;
  /** How many of those demonstrably moved something. */
  wheelMoved: number;
}

/** Fails loudly when a scroll loop is *provably* inert.
 *
 * SES_WEBKIT-SCROLL-1 exists because this condition went unreported: on
 * mobile WebKit the fallback ran 150 times, moved nothing on every single
 * one, and the spec then failed with the ordinary "CTA not found" assertion —
 * indistinguishable from the CTA legitimately not being there. A scroll
 * mechanism that achieves nothing is a harness defect and must say so.
 *
 * Deliberately conservative: it only throws where inertness can be *proven*.
 * A loop whose snapshot never changed because the screen genuinely had
 * nothing below the fold is not a defect, and Chromium's native wheel path
 * reports no movement measurements at all, so neither can trip this. */
export function assertScrollWasEffective(evidence: ScrollEffectEvidence, context: string): void {
  if (evidence.fingerprintChanged) return;
  if (evidence.steps === 0) return;
  if (evidence.wheelInvocations === 0) return; // no measurements — nothing proven
  if (evidence.wheelMoved > 0) return; // something moved; not provably inert
  throw new Error(
    `inert scroll while ${context}: ${evidence.steps} scroll steps and ` +
      `${evidence.wheelInvocations} wheel-fallback invocations moved nothing at all, and the ` +
      `accessibility snapshot never changed. The scroll mechanism is broken, so "not found" here ` +
      `proves nothing about whether the target exists. See SES_WEBKIT-SCROLL-1.`,
  );
}

function installPortableWheelFallback(page: Page): void {
  const mouse = (page as unknown as { mouse?: PortableMouse }).mouse;
  if (!mouse || mouse[PORTABLE_WHEEL_INSTALLED]) return;

  const nativeWheel = mouse.wheel.bind(mouse);
  mouse.wheel = async (deltaX: number, deltaY: number): Promise<void> => {
    try {
      await nativeWheel(deltaX, deltaY);
      return;
    } catch (err) {
      if (!MOBILE_WEBKIT_WHEEL_UNSUPPORTED.test(String(err))) throw err;
    }

    const diagnostic = await page.evaluate(
      async ({ x, y }) => {
        const centerX = window.innerWidth / 2;
        const centerY = window.innerHeight / 2;

        // Flutter Web paints into a canvas, so no DOM scrollbar moves when a
        // ListView scrolls. What *does* change is the semantics tree Flutter
        // rebuilds for the new viewport: node count, node geometry and label
        // lengths. That makes this signature the only honest "did anything
        // actually happen?" oracle available from inside the page — and the
        // one every strategy below is checked against.
        const signature = (): string => {
          const nodes = document.querySelectorAll<HTMLElement>('flt-semantics');
          const parts: string[] = [String(nodes.length), String(Math.round(window.scrollY))];
          nodes.forEach((n) => {
            const r = n.getBoundingClientRect();
            parts.push(`${Math.round(r.top)},${Math.round(r.height)},${(n.getAttribute('aria-label') ?? '').length},${n.scrollTop}`);
          });
          return parts.join('|');
        };
        // A frame barrier, not a timeout: Flutter applies a scroll and
        // republishes semantics on its next frame, so the oracle has to be
        // sampled one frame later or it would read the pre-scroll tree and
        // report every strategy inert.
        const frame = (): Promise<void> => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve())));

        const allSemantics = Array.from(document.querySelectorAll<HTMLElement>('flt-semantics'));
        const overflowHistogram: Record<string, number> = {};
        for (const el of allSemantics) {
          const value = getComputedStyle(el).overflowY || '(empty)';
          overflowHistogram[value] = (overflowHistogram[value] ?? 0) + 1;
        }
        const windowScrollYBefore = window.scrollY;
        const attempts: { strategy: string; moved: boolean; detail?: string }[] = [];
        let movedBy: string | null = null;
        let last = signature();

        const attempt = async (strategy: string, run: () => void | Promise<void>, detail?: string): Promise<void> => {
          if (movedBy) return; // a previous strategy already worked
          try {
            await run();
          } catch (err) {
            attempts.push({ strategy, moved: false, detail: `threw: ${String(err)}` });
            return;
          }
          await frame();
          const now = signature();
          const moved = now !== last;
          attempts.push({ strategy, moved, detail });
          last = now;
          if (moved) movedBy = strategy;
        };

        // Flutter's PointerBinding hit-tests a wheel signal by the event's
        // own client coordinates, never by its DOM target. The original
        // fallback built this WheelEvent with no clientX/clientY at all, so
        // every scroll it ever sent was aimed at (0, 0) — the AppBar, which
        // is not scrollable — no matter which element it was dispatched on.
        const viewRoot =
          document.querySelector<HTMLElement>('flutter-view') ??
          document.querySelector<HTMLElement>('flt-glass-pane') ??
          document.elementFromPoint(centerX, centerY) ??
          document.body;
        await attempt('wheelEvent', () => {
          viewRoot.dispatchEvent(
            new WheelEvent('wheel', {
              bubbles: true,
              cancelable: true,
              composed: true,
              deltaX: x,
              deltaY: y,
              deltaMode: WheelEvent.DOM_DELTA_PIXEL,
              clientX: centerX,
              clientY: centerY,
              screenX: centerX,
              screenY: centerY,
            }),
          );
        });

        // A real finger swipe, delivered through Flutter's ordinary gesture
        // pipeline. pointerType must be 'touch': Flutter's default
        // MaterialScrollBehavior.dragDevices excludes PointerDeviceKind.mouse,
        // so a mouse-typed drag is ignored by every Scrollable in the app.
        await attempt('pointerDrag', async () => {
          const dx = Math.max(-Math.round(window.innerWidth * 0.6), Math.min(Math.round(window.innerWidth * 0.6), -x));
          const dy = Math.max(-Math.round(window.innerHeight * 0.6), Math.min(Math.round(window.innerHeight * 0.6), -y));
          const startX = Math.min(window.innerWidth - 4, Math.max(4, centerX - dx / 2));
          const startY = Math.min(window.innerHeight - 4, Math.max(4, centerY - dy / 2));
          const pointerId = 20260828;
          const send = (type: string, cx: number, cy: number, buttons: number): void => {
            viewRoot.dispatchEvent(
              new PointerEvent(type, {
                bubbles: true,
                cancelable: true,
                composed: true,
                pointerId,
                pointerType: 'touch',
                isPrimary: true,
                button: buttons === 0 ? -1 : 0,
                buttons,
                clientX: cx,
                clientY: cy,
                screenX: cx,
                screenY: cy,
                width: 1,
                height: 1,
                pressure: buttons === 0 ? 0 : 0.5,
              }),
            );
          };
          send('pointerdown', startX, startY, 1);
          const steps = 12;
          for (let i = 1; i <= steps; i++) {
            send('pointermove', startX + (dx * i) / steps, startY + (dy * i) / steps, 1);
            await frame();
          }
          // Two stationary moves before release so the release velocity is
          // ~0. A fast release would start a fling whose final offset this
          // helper cannot predict, making the scroll non-deterministic.
          send('pointermove', startX + dx, startY + dy, 1);
          await frame();
          send('pointermove', startX + dx, startY + dy, 1);
          await frame();
          send('pointerup', startX + dx, startY + dy, 0);
        });

        // Flutter marks an accessibility-scrollable ListView with a
        // FLT-SEMANTICS node, but its computed overflow-y is NOT reliably
        // 'scroll'/'auto': measured on mobile WebKit it is 'visible' for 20
        // of 21 nodes and 'hidden' for the remaining one, so the previous
        // overflow-based filter matched zero elements on every one of 150
        // invocations. What matters is whether the node is *programmatically*
        // scrollable, and — since even that can be true for a node nothing
        // reacts to — whether scrolling it actually moved anything. So try
        // each candidate and keep the first that demonstrably works.
        const semanticsCandidates = allSemantics
          .filter((el) => el.scrollHeight > el.clientHeight + 1 || el.scrollWidth > el.clientWidth + 1)
          .sort((a, b) => (b.scrollHeight - b.clientHeight) - (a.scrollHeight - a.clientHeight));
        for (const el of semanticsCandidates) {
          await attempt('semanticsScroll', () => {
            el.scrollBy({ left: x, top: y, behavior: 'auto' });
            el.dispatchEvent(new Event('scroll', { bubbles: true }));
          }, el.getAttribute('id') ?? el.tagName);
        }

        const genericCandidates = Array.from(document.querySelectorAll<HTMLElement>('*'))
          .filter((el) => el.scrollHeight > el.clientHeight + 1)
          .sort((a, b) => (b.scrollHeight - b.clientHeight) - (a.scrollHeight - a.clientHeight))
          .slice(0, 5);
        for (const el of genericCandidates) {
          await attempt('genericScroll', () => {
            el.scrollBy({ left: x, top: y, behavior: 'auto' });
          }, el.tagName);
        }

        await attempt('windowScroll', () => {
          window.scrollBy(x, y);
        });

        return {
          movedBy: movedBy as WheelStrategyAttempt['strategy'] | null,
          attempts: attempts as WheelStrategyAttempt[],
          fltSemanticsTotal: allSemantics.length,
          fltSemanticsScrollable: semanticsCandidates.length,
          fltSemanticsOverflowY: overflowHistogram,
          windowScrollYBefore,
          windowScrollYAfter: window.scrollY,
          moved: movedBy !== null,
        };
      },
      { x: deltaX, y: deltaY },
    );

    const recorded = wheelDiagnostics.get(page) ?? [];
    if (recorded.length < MAX_WHEEL_DIAGNOSTICS) recorded.push(diagnostic);
    wheelDiagnostics.set(page, recorded);
  };
  mouse[PORTABLE_WHEEL_INSTALLED] = true;
}

/** Wires console.error / pageerror / crash / requestfailed listeners
 * (§19). Call before `page.goto`. Fatal errors (uncaught page errors, a
 * page crash) should fail the test; an unallowlisted `console.error`
 * fails it too (Codex follow-up §7-8) — only the narrowly-scoped font
 * allowlist above (and the two other-noise entries) are recorded without
 * failing. */
export function watchForErrors(page: Page): ErrorWatcher {
  installPortableWheelFallback(page);
  const watcher: ErrorWatcher = { consoleErrors: [], consoleWarnings: [], pageErrors: [], crashed: false };

  // Keyed by the exact failing request URL, not a bare count: one entry per
  // pending "a known font host failed with a known network-level error",
  // consumed only by a bare "Failed to load resource" console message whose
  // own `location().url` matches that *same* URL. An unrelated request's
  // bare console error carries its own (different) URL, so it can never
  // consume a font failure's slot, however the events interleave — see the
  // investigation notes above `KNOWN_FONT_HOSTS`.
  const pendingKnownFontFailuresByUrl = new Map<string, number>();
  page.on('requestfailed', (request) => {
    const errorText = request.failure()?.errorText ?? '';
    if (isKnownFontHost(request.url()) && isKnownNetworkFailureCode(errorText)) {
      const url = request.url();
      pendingKnownFontFailuresByUrl.set(url, (pendingKnownFontFailuresByUrl.get(url) ?? 0) + 1);
    }
  });

  page.on('console', (msg) => {
    const text = `[${msg.type()}] ${msg.text()}`;
    if (OTHER_ALLOWLIST.some((e) => e.pattern.test(text))) return;
    if (isFontMessageWithHost(text)) return;
    if (RESOURCE_LOAD_FAILURE_MESSAGE.test(text)) {
      const locationUrl = msg.location().url;
      const pending = locationUrl ? pendingKnownFontFailuresByUrl.get(locationUrl) ?? 0 : 0;
      if (locationUrl && pending > 0) {
        pendingKnownFontFailuresByUrl.set(locationUrl, pending - 1);
        return;
      }
      // No location URL, or it doesn't match any known-font-failure's exact
      // URL: not certain enough to allowlist (safe fallback, §12) — falls
      // through to be recorded as a real error below.
    }
    if (msg.type() === 'error') watcher.consoleErrors.push(text);
    else if (msg.type() === 'warning') watcher.consoleWarnings.push(text);
  });
  page.on('pageerror', (err) => {
    watcher.pageErrors.push(err.stack || err.message);
  });
  page.on('crash', () => {
    watcher.crashed = true;
  });
  return watcher;
}

export interface SesResultJson {
  scenario: string;
  device: string;
  seed: number;
  completed: boolean;
  firstAssignmentWeek: number | null;
  actions: number;
  clientInterviewCount: number;
  selectionFailureCount: number;
  stallDetected: boolean;
  stallReason: string | null;
  primaryCtaWarnings: unknown[];
  stageRegressionWarnings: unknown[];
  clientInterviewHistory: unknown[];
  /** §12 of the Codex follow-up (Failure Recovery candidate identity). */
  rejectedCandidateName: string | null;
  acceptedCandidateName: string | null;
  consoleErrors: string[];
  consoleWarnings: string[];
  pageErrors: string[];
  durationMs: number;
}

export function buildResultJson(args: {
  scenario: string;
  device: string;
  seed: number;
  play: PlayResult;
  errors: ErrorWatcher;
  durationMs: number;
}): SesResultJson {
  return {
    scenario: args.scenario,
    device: args.device,
    seed: args.seed,
    completed: args.play.completed,
    firstAssignmentWeek: args.play.firstAssignmentWeek,
    actions: args.play.actions,
    clientInterviewCount: args.play.clientInterviewCount,
    selectionFailureCount: args.play.selectionFailureCount,
    stallDetected: args.play.stallDetected,
    stallReason: args.play.stallReason,
    primaryCtaWarnings: args.play.primaryCtaWarnings,
    stageRegressionWarnings: args.play.stageRegressionWarnings,
    clientInterviewHistory: args.play.clientInterviewHistory,
    rejectedCandidateName: args.play.rejectedCandidateName,
    acceptedCandidateName: args.play.acceptedCandidateName,
    consoleErrors: args.errors.consoleErrors,
    consoleWarnings: args.errors.consoleWarnings,
    pageErrors: args.errors.pageErrors,
    durationMs: args.durationMs,
  };
}

/** Writes result.json + action-trace.json into the current test's
 * Playwright output directory (test-results/<test-name>/...) so they're
 * always attached alongside video/screenshots, and additionally attaches
 * them to the HTML report (§16-18, §21). */
export async function writeArtifacts(testInfo: TestInfo, result: SesResultJson, actionTrace: unknown[]): Promise<void> {
  const dir = testInfo.outputDir;
  fs.mkdirSync(dir, { recursive: true });

  const resultPath = path.join(dir, 'result.json');
  fs.writeFileSync(resultPath, JSON.stringify(result, null, 2), 'utf-8');
  await testInfo.attach('result.json', { path: resultPath, contentType: 'application/json' });

  const tracePath = path.join(dir, 'action-trace.json');
  fs.writeFileSync(tracePath, JSON.stringify(actionTrace, null, 2), 'utf-8');
  await testInfo.attach('action-trace.json', { path: tracePath, contentType: 'application/json' });
}

/** §15: milestone screenshots on success, always-on-failure screenshot
 * (Playwright's `screenshot: 'only-on-failure'` project setting already
 * covers the failure case; this is for the named success-path milestones). */
export async function captureMilestone(page: Page, testInfo: TestInfo, name: string): Promise<void> {
  const dir = testInfo.outputDir;
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `milestone-${name}.png`);
  await page.screenshot({ path: file });
  await testInfo.attach(`milestone-${name}`, { path: file, contentType: 'image/png' });
}
