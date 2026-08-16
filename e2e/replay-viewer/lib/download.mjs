// Pure helpers backing the Replay Viewer's "MP4 Download" control — kept
// separate from app.js's DOM wiring so both the safety decision (reusing
// isSafeRelativePath, the same guard the Replay modal / Result / Action
// Trace fetches already rely on) and the suggested filename are directly
// unit-testable without a DOM. Never invents or reconstructs a video
// path — manifest.json's own `video` field is the only source, and it's
// only ever used as a download href once confirmed safe.
import { isSafeRelativePath } from './safe-path.mjs';

const UNSAFE_FILENAME_CHARS = /[^A-Za-z0-9._-]+/g;

/** Collapses anything outside [A-Za-z0-9._-] to "-", collapses runs of
 * "." (which could otherwise reconstruct "..") to "-", and trims leading/
 * trailing "-"/".". This only shapes the *suggested save-as name* shown
 * in the browser's download dialog — it is never used to build or
 * validate the actual fetch/href path (isSafeRelativePath does that,
 * against the manifest's own `video` value, unmodified). */
export function sanitizeFilenameSegment(value, fallback) {
  const s = value === null || value === undefined ? '' : String(value);
  const cleaned = s
    .replace(UNSAFE_FILENAME_CHARS, '-')
    .replace(/\.{2,}/g, '-')
    .replace(/^[-.]+|[-.]+$/g, '')
    .slice(0, 80);
  return cleaned.length > 0 ? cleaned : fallback;
}

/** `ses-{browser}-{scenario}-{seed}.mp4`, e.g.
 * "ses-mobile-chromium-founding-first-assignment-100001.mp4". */
export function buildVideoDownloadFilename({ browser, scenario, seed } = {}) {
  const browserSeg = sanitizeFilenameSegment(browser, 'browser');
  const scenarioSeg = sanitizeFilenameSegment(scenario, 'scenario');
  const seedSeg = seed === null || seed === undefined || seed === '' ? 'noseed' : sanitizeFilenameSegment(seed, 'noseed');
  return `ses-${browserSeg}-${scenarioSeg}-${seedSeg}.mp4`;
}

/** Whether a manifest test entry's video should render as a real download
 * link, and if so, its (already-safe) href and suggested filename.
 * `t.video` is rejected by isSafeRelativePath whenever it's missing,
 * empty, non-string, absolute, a `../` traversal, or carries any URL
 * scheme (http:, https:, javascript:, data:, ...) — the same check the
 * Replay/Result/Action Trace modals already apply before fetching. Never
 * falls back to guessing a path when the manifest's own value is
 * unusable; the caller must render the control as disabled/hidden. */
export function computeVideoDownload(t) {
  const video = t?.video;
  if (!isSafeRelativePath(video)) {
    return { available: false, href: null, filename: null };
  }
  return {
    available: true,
    href: video,
    filename: buildVideoDownloadFilename({ browser: t?.browser, scenario: t?.scenario, seed: t?.seed }),
  };
}
