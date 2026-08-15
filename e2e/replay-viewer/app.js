// E2E Replay Viewer — a standalone dev/QA static page. Fetches
// ./manifest.json (built by e2e/scripts/build-replay-manifest.mjs) and
// renders it. No build step, no framework, no GitHub API calls, no
// tokens — everything it needs ships alongside it as static files.
import { escapeHtml } from './lib/escape-html.mjs';
import { isSafeRelativePath } from './lib/safe-path.mjs';
import { filterTests, distinctBrowsers } from './lib/filter-tests.mjs';
import { formatDurationMs, formatElapsed, browserLabel, statusLabel } from './lib/format.mjs';

const state = {
  manifest: null,
  browserFilter: 'all',
  statusFilter: 'all',
};

const el = {
  runSummary: document.getElementById('run-summary'),
  browserFilter: document.getElementById('browser-filter'),
  statusFilter: document.getElementById('status-filter'),
  cards: document.getElementById('cards'),
  modal: document.getElementById('modal'),
  modalBody: document.getElementById('modal-body'),
  modalClose: document.getElementById('modal-close'),
};

el.modalClose.addEventListener('click', closeModal);
el.modal.addEventListener('click', (e) => {
  if (e.target === el.modal) closeModal();
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeModal();
});

function openModal(html) {
  el.modalBody.innerHTML = html;
  el.modal.classList.remove('hidden');
  el.modal.setAttribute('aria-hidden', 'false');
}

function closeModal() {
  // Stop any playing video instead of leaving it running behind the modal.
  el.modalBody.querySelectorAll('video').forEach((v) => v.pause());
  el.modal.classList.add('hidden');
  el.modal.setAttribute('aria-hidden', 'true');
  el.modalBody.innerHTML = '';
}

async function loadManifest() {
  let res;
  try {
    res = await fetch('./manifest.json', { cache: 'no-store' });
  } catch (err) {
    renderLoadError(`manifest.json を取得できませんでした（ネットワークエラー）: ${err.message}`);
    return;
  }
  if (!res.ok) {
    renderLoadError(`manifest.json の取得に失敗しました（HTTP ${res.status}）。E2E replay package がまだ公開されていない可能性があります。`);
    return;
  }
  let manifest;
  try {
    manifest = await res.json();
  } catch (err) {
    renderLoadError(`manifest.json の内容が不正です（JSON parse error）: ${err.message}`);
    return;
  }
  if (!manifest || !Array.isArray(manifest.tests)) {
    renderLoadError('manifest.json の形式が想定と異なります（"tests" 配列がありません）。');
    return;
  }
  state.manifest = manifest;
  render();
}

function renderLoadError(message) {
  el.runSummary.innerHTML = `<p class="error-text">${escapeHtml(message)}</p>`;
  el.browserFilter.innerHTML = '';
  el.statusFilter.innerHTML = '';
  el.cards.innerHTML = '';
}

function render() {
  renderSummary();
  renderFilters();
  renderCards();
}

function renderSummary() {
  const m = state.manifest;
  const generated = m.generatedAt ? new Date(m.generatedAt).toLocaleString('ja-JP') : '—';
  const runLine = m.runUrl && isHttpUrl(m.runUrl) ? `<a href="${escapeHtml(m.runUrl)}" target="_blank" rel="noopener noreferrer">${escapeHtml(m.runId ?? m.runUrl)}</a>` : escapeHtml(m.runId ?? '—');
  el.runSummary.innerHTML = `
    <dl>
      <dt>Run</dt><dd>#${runLine}</dd>
      <dt>Commit</dt><dd>${escapeHtml(shortSha(m.commitSha))}</dd>
      <dt>Generated</dt><dd>${escapeHtml(generated)}</dd>
      <dt>Tests</dt><dd>${escapeHtml(m.stats?.passed ?? 0)} PASS / ${escapeHtml(m.stats?.failed ?? 0)} FAIL${m.stats?.skipped ? ` / ${escapeHtml(m.stats.skipped)} SKIP` : ''}</dd>
    </dl>
  `;
}

function isHttpUrl(value) {
  return typeof value === 'string' && /^https?:\/\//.test(value);
}

function shortSha(sha) {
  return typeof sha === 'string' && sha.length > 0 ? sha.slice(0, 7) : '—';
}

function renderFilters() {
  const browsers = distinctBrowsers(state.manifest.tests);
  el.browserFilter.innerHTML = '';
  el.browserFilter.appendChild(makeFilterButton('all', 'All', state.browserFilter, (v) => setBrowserFilter(v)));
  for (const b of browsers) {
    el.browserFilter.appendChild(makeFilterButton(b, browserLabel(b), state.browserFilter, (v) => setBrowserFilter(v)));
  }

  el.statusFilter.innerHTML = '';
  el.statusFilter.appendChild(makeFilterButton('all', 'All', state.statusFilter, (v) => setStatusFilter(v)));
  el.statusFilter.appendChild(makeFilterButton('passed', 'PASS', state.statusFilter, (v) => setStatusFilter(v)));
  el.statusFilter.appendChild(makeFilterButton('failed', 'FAIL', state.statusFilter, (v) => setStatusFilter(v)));
}

function makeFilterButton(value, label, current, onSelect) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'filter-btn';
  btn.textContent = label;
  btn.setAttribute('aria-pressed', String(value === current));
  btn.addEventListener('click', () => onSelect(value));
  return btn;
}

function setBrowserFilter(v) {
  state.browserFilter = v;
  render();
}
function setStatusFilter(v) {
  state.statusFilter = v;
  render();
}

function renderCards() {
  const tests = filterTests(state.manifest.tests, { browser: state.browserFilter, status: state.statusFilter });
  if (tests.length === 0) {
    el.cards.innerHTML = '<p class="empty-state">条件に一致するテストがありません。</p>';
    return;
  }
  el.cards.innerHTML = '';
  for (const t of tests) {
    el.cards.appendChild(renderCard(t));
  }
}

function renderCard(t) {
  const card = document.createElement('article');
  card.className = 'card';

  const summary = t.resultSummary;
  // Plain, unescaped strings here — escaping happens exactly once, in the
  // `.map(escapeHtml)` at render time below. Escaping each value twice
  // (once here, once there) doesn't weaken XSS protection by itself, but
  // it's still wrong: any value that actually contained an HTML-special
  // character would render as a literal `&amp;` instead of `&`.
  const metaLines = [browserLabel(t.browser), `Seed: ${t.seed ?? '—'}`];
  if (summary?.firstAssignmentWeek != null) metaLines.push(`First assignment: week ${summary.firstAssignmentWeek}`);
  if (t.durationMs != null) metaLines.push(`Duration: ${formatDurationMs(t.durationMs)}`);

  card.innerHTML = `
    <div class="status ${escapeHtml(t.status)}">${escapeHtml(statusLabel(t.status))}</div>
    <div class="scenario">${escapeHtml(t.scenario)}</div>
    <div class="meta">${metaLines.map(escapeHtml).join(' · ')}</div>
    ${t.warnings?.length ? `<div class="warnings">⚠ ${escapeHtml(t.warnings.join(' / '))}</div>` : ''}
    <div class="actions">
      <button type="button" class="replay-btn" ${t.video ? '' : 'disabled'}>${t.video ? '▶ Replay' : '動画なし'}</button>
      <button type="button" class="trace-btn secondary" ${t.actionTrace ? '' : 'disabled'}>Action Trace</button>
      <button type="button" class="result-btn secondary" ${t.result ? '' : 'disabled'}>Result</button>
    </div>
  `;

  const replayBtn = card.querySelector('.replay-btn');
  if (t.video) replayBtn.addEventListener('click', () => openReplayModal(t));
  const traceBtn = card.querySelector('.trace-btn');
  if (t.actionTrace) traceBtn.addEventListener('click', () => openTraceModal(t));
  const resultBtn = card.querySelector('.result-btn');
  if (t.result) resultBtn.addEventListener('click', () => openResultModal(t));

  return card;
}

function openReplayModal(t) {
  if (!isSafeRelativePath(t.video)) {
    openModal(`<p class="error-text">動画パスが不正です。</p>`);
    return;
  }
  openModal(`
    <h2>${escapeHtml(t.scenario)} — ${escapeHtml(browserLabel(t.browser))} (seed ${escapeHtml(t.seed ?? '—')})</h2>
    <video controls playsinline preload="metadata" src="${escapeHtml(t.video)}"></video>
    <div class="playback-rates" role="group" aria-label="Playback speed"></div>
  `);
  const video = el.modalBody.querySelector('video');
  const rateGroup = el.modalBody.querySelector('.playback-rates');
  for (const rate of [0.5, 1, 1.5, 2]) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = `${rate}x`;
    btn.setAttribute('aria-pressed', String(rate === 1));
    btn.addEventListener('click', () => {
      video.playbackRate = rate;
      rateGroup.querySelectorAll('button').forEach((b) => b.setAttribute('aria-pressed', String(b === btn)));
    });
    rateGroup.appendChild(btn);
  }
  video.play().catch(() => {
    // Autoplay can be blocked (esp. iOS Safari) — controls are still
    // present, so the user can start playback manually.
  });
}

async function openTraceModal(t) {
  if (!isSafeRelativePath(t.actionTrace)) {
    openModal(`<p class="error-text">action-trace のパスが不正です。</p>`);
    return;
  }
  openModal('<p>読み込み中…</p>');
  let trace;
  try {
    const res = await fetch(t.actionTrace, { cache: 'no-store' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    trace = await res.json();
  } catch (err) {
    openModal(`<p class="error-text">action-trace.json を読み込めませんでした: ${escapeHtml(err.message)}</p>`);
    return;
  }
  if (!Array.isArray(trace)) {
    openModal('<p class="error-text">action-trace.json の形式が想定と異なります（配列ではありません）。</p>');
    return;
  }
  if (trace.length === 0) {
    openModal(`<h2>Action Trace</h2><p class="empty-state">記録されたアクションがありません。</p>`);
    return;
  }
  // No per-action week display: ActionTraceEntry has no raw `week` field
  // (only `advancedWeek: boolean`), and a count-of-advancedWeek-so-far
  // derived value is too easy to misread as GameState's actual week
  // number — dropped rather than risk that (Codex Minor 5).
  const items = trace
    .map((entry, i) => {
      const hasElapsed = typeof entry?.elapsedMs === 'number';
      const seq = typeof entry?.action === 'number' ? entry.action : i + 1;
      const timeLabel = hasElapsed ? formatElapsed(entry.elapsedMs) : null;
      const line = `#${escapeHtml(seq)}${timeLabel ? ` [${escapeHtml(timeLabel)}]` : ''} ${escapeHtml(entry?.screen ?? '?')} → <span class="trace-clicked">${escapeHtml(entry?.clicked ?? '?')}</span>`;
      return `<li>${line}</li>`;
    })
    .join('');
  openModal(`<h2>Action Trace — ${escapeHtml(t.scenario)}</h2><ul class="trace-list">${items}</ul>`);
}

async function openResultModal(t) {
  if (!isSafeRelativePath(t.result)) {
    openModal(`<p class="error-text">result.json のパスが不正です。</p>`);
    return;
  }
  openModal('<p>読み込み中…</p>');
  let data;
  try {
    const res = await fetch(t.result, { cache: 'no-store' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    data = await res.json();
  } catch (err) {
    openModal(`<p class="error-text">result.json を読み込めませんでした: ${escapeHtml(err.message)}</p>`);
    return;
  }
  const rows = [
    ['completed', data?.completed],
    ['seed', data?.seed],
    ['browser (device)', data?.device],
    ['firstAssignmentWeek', data?.firstAssignmentWeek],
    ['actions', data?.actions],
    ['stallDetected', data?.stallDetected],
    ['stallReason', data?.stallReason],
    ['rejectedCandidateName', data?.rejectedCandidateName],
    ['acceptedCandidateName', data?.acceptedCandidateName],
    ['consoleErrors', Array.isArray(data?.consoleErrors) ? data.consoleErrors.length : null],
    ['pageErrors', Array.isArray(data?.pageErrors) ? data.pageErrors.length : null],
    ['durationMs', data?.durationMs],
  ].filter(([, v]) => v !== undefined);
  const rowsHtml = rows.map(([k, v]) => `<dt>${escapeHtml(k)}</dt><dd>${escapeHtml(formatValue(v))}</dd>`).join('');
  const errorLines = Array.isArray(data?.consoleErrors) && data.consoleErrors.length > 0 ? `<h3>consoleErrors</h3><ul class="trace-list">${data.consoleErrors.map((e) => `<li>${escapeHtml(e)}</li>`).join('')}</ul>` : '';
  openModal(`<h2>Result — ${escapeHtml(t.scenario)}</h2><dl class="panel">${rowsHtml}</dl>${errorLines}`);
}

function formatValue(v) {
  if (v === null || v === undefined) return '—';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  return v;
}

loadManifest();
