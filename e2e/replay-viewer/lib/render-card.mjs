// Pure builder for a Replay card's action-button row (Replay / MP4
// Download / Action Trace / Result) — kept separate from app.js's DOM
// wiring (querySelector/addEventListener) so the exact generated markup
// (hrefs, download filenames, disabled states) is directly assertable in
// unit tests without a real DOM or browser. app.js hands this string
// straight to `card.innerHTML` and wires up click handlers against the
// class names below; nothing here changes that behavior.
import { escapeHtml } from './escape-html.mjs';
import { computeVideoDownload } from './download.mjs';

export function renderActionsHtml(t) {
  // A plain same-origin <a href> (not just a click-to-fetch button) so
  // that iOS Safari — where the `download` attribute is unreliable — can
  // still open/share/save the MP4 via its normal link handling even if
  // the attribute itself is ignored. No target="_blank": opening in the
  // same tab keeps that fallback path intact.
  const dl = computeVideoDownload(t);
  const downloadControl = dl.available
    ? `<a class="download-btn secondary" href="${escapeHtml(dl.href)}" download="${escapeHtml(dl.filename)}">⬇ MP4 Download</a>`
    : `<button type="button" class="download-btn secondary" disabled>⬇ MP4 Download</button>`;

  return `
    <button type="button" class="replay-btn" ${t.video ? '' : 'disabled'}>${t.video ? '▶ Replay' : '動画なし'}</button>
    ${downloadControl}
    <button type="button" class="trace-btn secondary" ${t.actionTrace ? '' : 'disabled'}>Action Trace</button>
    <button type="button" class="result-btn secondary" ${t.result ? '' : 'disabled'}>Result</button>
  `;
}
