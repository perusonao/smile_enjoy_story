// Unit tests for build-replay-manifest.mjs — run with `node --test`.
// Deliberately hermetic: copyFile/convertVideo/fileExists are injected
// fakes, so these never touch a real ffmpeg binary or leave files behind.
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {
  sanitizeSegment,
  collectTestEntries,
  mapStatus,
  buildFfmpegArgs,
  buildManifestEntries,
  buildManifest,
  ReplayBuildError,
} from './build-replay-manifest.mjs';

function attachment(name, path_) {
  return { name, path: path_, contentType: 'application/octet-stream' };
}

function makeResult({ status = 'passed', retry = 0, duration = 1000, attachments = [] } = {}) {
  return { status, retry, duration, attachments, errors: [], stdout: [], stderr: [], startTime: '2026-08-15T00:00:00.000Z' };
}

function makeReport(tests) {
  return {
    suites: [
      {
        title: 'root',
        file: '',
        specs: [],
        suites: [
          {
            title: 'founding-first-assignment.spec.ts',
            file: 'founding-first-assignment.spec.ts',
            specs: tests.map((t, i) => ({
              title: t.specTitle ?? `spec ${i}`,
              file: 'founding-first-assignment.spec.ts',
              ok: true,
              tests: [
                {
                  projectName: t.browser ?? 'mobile-chromium',
                  status: t.testStatus ?? 'expected',
                  results: t.results ?? [makeResult()],
                },
              ],
            })),
          },
        ],
      },
    ],
  };
}

function fakeCollaborators({ files = {}, videoConvertsOk = true } = {}) {
  const copied = [];
  const converted = [];
  return {
    files,
    copied,
    converted,
    fileExists: (p) => Object.prototype.hasOwnProperty.call(files, p),
    readFile: (p) => {
      if (!Object.prototype.hasOwnProperty.call(files, p)) {
        const err = new Error(`ENOENT: no such fake file: ${p}`);
        err.code = 'ENOENT';
        throw err;
      }
      return files[p];
    },
    copyFile: (src, dest) => {
      copied.push({ src, dest });
    },
    convertVideo: (input, output) => {
      converted.push({ input, output });
      return videoConvertsOk ? { ok: true } : { ok: false, error: 'boom' };
    },
  };
}

// --- sanitizeSegment / path traversal --------------------------------

test('sanitizeSegment strips path traversal and separators', () => {
  assert.equal(sanitizeSegment('../../etc/passwd', 'fallback'), 'etc_passwd');
  assert.equal(sanitizeSegment('..\\..\\windows', 'fallback'), 'windows');
  assert.equal(sanitizeSegment('a/b/../../c', 'fallback'), 'a_b_c');
  assert.equal(sanitizeSegment('', 'fallback'), 'fallback');
  assert.equal(sanitizeSegment(null, 'fallback'), 'fallback');
  assert.equal(sanitizeSegment('founding-first-assignment', 'fallback'), 'founding-first-assignment');
});

test('sanitizeSegment caps length so a pathological title cannot blow up a path', () => {
  const long = 'a'.repeat(500);
  assert.ok(sanitizeSegment(long, 'fallback').length <= 80);
});

test('buildManifestEntries never writes outside outDir even with a hostile scenario/seed', () => {
  const outDir = path.resolve('/tmp/replay-out-test');
  const files = {
    '/src/result.json': JSON.stringify({ scenario: '../../../etc/passwd', seed: '1;rm -rf /', durationMs: 10 }),
    '/src/video.webm': 'x',
    '/src/action-trace.json': '[]',
  };
  const report = makeReport([
    {
      results: [
        makeResult({
          attachments: [attachment('result.json', '/src/result.json'), attachment('video', '/src/video.webm'), attachment('action-trace.json', '/src/action-trace.json')],
        }),
      ],
    },
  ]);
  const collab = fakeCollaborators({ files });
  const { manifestTests } = buildManifestEntries(report, { outDir, ...collab });
  const t = manifestTests[0];
  assert.equal(t.seed, null); // '1;rm -rf /' is not a finite number -> not trusted as a seed
  for (const rel of [t.video, t.result, t.actionTrace]) {
    const resolved = path.resolve(outDir, rel);
    assert.ok(resolved.startsWith(outDir + path.sep) || resolved === outDir, `escaped outDir: ${rel}`);
  }
  for (const c of [...collab.copied, ...collab.converted]) {
    const dest = path.resolve(c.dest ?? c.output);
    assert.ok(dest.startsWith(outDir + path.sep));
  }
});

// --- status mapping ----------------------------------------------------

test('mapStatus: skipped test is skipped regardless of result status', () => {
  assert.equal(mapStatus('skipped', 'passed'), 'skipped');
});

test('mapStatus: unexpected/failed final result is failed, never silently passed', () => {
  assert.equal(mapStatus('unexpected', 'failed'), 'failed');
  assert.equal(mapStatus('unexpected', 'timedOut'), 'failed');
});

test('mapStatus: flaky (eventually passed after retry) reports the final attempt as passed', () => {
  assert.equal(mapStatus('flaky', 'passed'), 'passed');
});

test('mapStatus: missing result status is never treated as a pass', () => {
  assert.equal(mapStatus('unexpected', undefined), 'failed');
});

// --- ffmpeg args ---------------------------------------------------------

test('buildFfmpegArgs uses H.264 / yuv420p / faststart, no audio track', () => {
  const args = buildFfmpegArgs('/in/video.webm', '/out/video.mp4');
  assert.deepEqual(args, ['-y', '-i', '/in/video.webm', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', '/out/video.mp4']);
});

// --- Chromium/WebKit + scenario/seed mapping -----------------------------

test('maps browser project name, scenario and seed straight from result.json', () => {
  const outDir = '/tmp/replay-out';
  const files = {
    '/c/result.json': JSON.stringify({ scenario: 'founding-first-assignment', seed: 100001, durationMs: 5000 }),
    '/c/video.webm': 'x',
    '/w/result.json': JSON.stringify({ scenario: 'founding-first-assignment', seed: 100001, durationMs: 6000 }),
    '/w/video.webm': 'x',
  };
  const report = makeReport([
    { browser: 'mobile-chromium', results: [makeResult({ attachments: [attachment('result.json', '/c/result.json'), attachment('video', '/c/video.webm')] })] },
    { browser: 'mobile-webkit', results: [makeResult({ attachments: [attachment('result.json', '/w/result.json'), attachment('video', '/w/video.webm')] })] },
  ]);
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  assert.equal(manifestTests.length, 2);
  assert.deepEqual(
    manifestTests.map((t) => [t.browser, t.scenario, t.seed]).sort(),
    [
      ['mobile-chromium', 'founding-first-assignment', 100001],
      ['mobile-webkit', 'founding-first-assignment', 100001],
    ].sort(),
  );
});

// --- result.json / action-trace mapping -----------------------------------

test('resultSummary is populated only from real result.json fields', () => {
  const outDir = '/tmp/replay-out';
  const files = {
    '/r/result.json': JSON.stringify({
      scenario: 'failure-recovery-recruitment-reject',
      seed: 900001,
      completed: true,
      firstAssignmentWeek: 4,
      actions: 30,
      stallDetected: false,
      stallReason: null,
      rejectedCandidateName: '田中花子',
      acceptedCandidateName: '山田太郎',
      consoleErrors: ['x'],
      pageErrors: [],
      durationMs: 9000,
    }),
  };
  const report = makeReport([{ results: [makeResult({ attachments: [attachment('result.json', '/r/result.json')] })] }]);
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  const summary = manifestTests[0].resultSummary;
  assert.equal(summary.acceptedCandidateName, '山田太郎');
  assert.equal(summary.rejectedCandidateName, '田中花子');
  assert.equal(summary.consoleErrorCount, 1);
  assert.equal(summary.pageErrorCount, 0);
  assert.equal('notAField' in summary, false);
});

test('action-trace.json is copied and referenced when present', () => {
  const outDir = '/tmp/replay-out';
  const files = {
    '/r/result.json': JSON.stringify({ scenario: 's', seed: 1 }),
    '/r/action-trace.json': JSON.stringify([{ action: 1, screen: 'start-choice', clicked: '始める' }]),
  };
  const report = makeReport([{ results: [makeResult({ attachments: [attachment('result.json', '/r/result.json'), attachment('action-trace.json', '/r/action-trace.json')] })] }]);
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  assert.equal(manifestTests[0].actionTrace, 'mobile-chromium/s-1.trace.json');
  assert.equal(manifestTests[0].warnings.includes('action-trace.json missing'), false);
});

// --- missing artifacts --------------------------------------------------

test('missing video attachment: entry still built, video is null, warning recorded', () => {
  const outDir = '/tmp/replay-out';
  const files = { '/r/result.json': JSON.stringify({ scenario: 's', seed: 1 }) };
  const report = makeReport([{ results: [makeResult({ attachments: [attachment('result.json', '/r/result.json')] })] }]);
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  const t = manifestTests[0];
  assert.equal(t.video, null);
  assert.equal(t.videoFormat, null);
  assert.ok(t.warnings.some((w) => w.includes('video attachment missing')));
});

test('missing result.json (video/trace present): entry still built with null result/resultSummary, scenario falls back to spec title', () => {
  const outDir = '/tmp/replay-out';
  const files = { '/r/video.webm': 'x', '/r/action-trace.json': '[]' };
  const report = makeReport([
    {
      specTitle: 'Founding First Assignment (seed 100001)',
      results: [makeResult({ attachments: [attachment('video', '/r/video.webm'), attachment('action-trace.json', '/r/action-trace.json')] })],
    },
  ]);
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  const t = manifestTests[0];
  assert.equal(t.result, null);
  assert.equal(t.resultSummary, null);
  assert.equal(t.seed, null);
  assert.ok(t.scenario.length > 0); // derived from the real spec title, never invented
  assert.ok(t.warnings.some((w) => w.startsWith('result.json:')));
});

test('a plain unit-test spec with zero replay attachments (e.g. artifacts.allowlist.spec.ts) is excluded entirely, not shown as a noise card', () => {
  const outDir = '/tmp/replay-out';
  const report = makeReport([
    { specTitle: 'isKnownFontHost: fonts.gstatic.com is known', results: [makeResult({ attachments: [] })] },
    { specTitle: 'Founding First Assignment (seed 100001)', results: [makeResult({ attachments: [attachment('result.json', '/r/result.json')] })] },
  ]);
  const files = { '/r/result.json': JSON.stringify({ scenario: 'founding-first-assignment', seed: 1 }) };
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  assert.equal(manifestTests.length, 1);
  assert.equal(manifestTests[0].scenario, 'founding-first-assignment');
});

test('a unit-test spec with only Playwright\'s own auto-recorded video (SES_E2E_VIDEO=on applies project-wide) and no result.json/action-trace.json is excluded too', () => {
  const outDir = '/tmp/replay-out';
  const files = { '/r/video.webm': 'x' };
  const report = makeReport([
    { specTitle: 'sanity: the stable-dead-end window is the documented constant', results: [makeResult({ attachments: [attachment('video', '/r/video.webm')] })] },
    { specTitle: 'Founding First Assignment (seed 100001)', results: [makeResult({ attachments: [attachment('result.json', '/s/result.json')] })] },
  ]);
  files['/s/result.json'] = JSON.stringify({ scenario: 'founding-first-assignment', seed: 1 });
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  assert.equal(manifestTests.length, 1);
  assert.equal(manifestTests[0].scenario, 'founding-first-assignment');
});

// --- failed test replay --------------------------------------------------

test('a failed test is still included with status "failed" and its video/trace intact', () => {
  const outDir = '/tmp/replay-out';
  const files = {
    '/r/result.json': JSON.stringify({ scenario: 'founding-first-assignment', seed: 100003, completed: false, stallDetected: true, stallReason: 'idle timeout' }),
    '/r/video.webm': 'x',
    '/r/action-trace.json': '[]',
  };
  const report = makeReport([
    {
      testStatus: 'unexpected',
      results: [makeResult({ status: 'failed', attachments: [attachment('result.json', '/r/result.json'), attachment('video', '/r/video.webm'), attachment('action-trace.json', '/r/action-trace.json')] })],
    },
  ]);
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  const t = manifestTests[0];
  assert.equal(t.status, 'failed');
  assert.ok(t.video);
  assert.equal(t.resultSummary.stallDetected, true);
});

// --- malformed JSON --------------------------------------------------------

test('malformed result.json: does not throw, records a warning, other fields still present', () => {
  const outDir = '/tmp/replay-out';
  const files = { '/r/result.json': '{ not valid json' };
  const report = makeReport([{ results: [makeResult({ attachments: [attachment('result.json', '/r/result.json')] })] }]);
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  const t = manifestTests[0];
  assert.equal(t.result, null);
  assert.ok(t.warnings.some((w) => w.includes('malformed JSON')));
});

test('collectTestEntries throws ReplayBuildError on a structurally malformed report (not silent)', () => {
  assert.throws(() => collectTestEntries({}), ReplayBuildError);
  assert.throws(() => collectTestEntries(null), ReplayBuildError);
  assert.throws(() => collectTestEntries({ suites: 'nope' }), ReplayBuildError);
});

// --- video conversion failure ---------------------------------------------

test('a failed ffmpeg conversion degrades that entry (video=null + warning) without failing the whole build', () => {
  const outDir = '/tmp/replay-out';
  const files = { '/r/result.json': JSON.stringify({ scenario: 's', seed: 1 }), '/r/video.webm': 'x' };
  const report = makeReport([{ results: [makeResult({ attachments: [attachment('result.json', '/r/result.json'), attachment('video', '/r/video.webm')] })] }]);
  const { manifestTests, buildWarnings } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files, videoConvertsOk: false }) });
  assert.equal(manifestTests[0].video, null);
  assert.ok(buildWarnings.some((w) => w.includes('video conversion failed')));
});

// --- empty run -------------------------------------------------------------

test('empty run: zero tests produces a valid manifest with tests: [] and zero stats, not an error', () => {
  const outDir = '/tmp/replay-out';
  const report = { suites: [] };
  const manifest = buildManifest({ report, runMeta: { runId: '1' }, outDir, ...fakeCollaborators({}) });
  assert.deepEqual(manifest.tests, []);
  assert.deepEqual(manifest.stats, { total: 0, passed: 0, failed: 0, skipped: 0 });
});

// --- full manifest / stats --------------------------------------------------

test('buildManifest aggregates pass/fail/skipped stats accurately and carries run metadata through unchanged', () => {
  const outDir = '/tmp/replay-out';
  const files = {
    '/a/result.json': JSON.stringify({ scenario: 'a', seed: 1 }),
    '/b/result.json': JSON.stringify({ scenario: 'b', seed: 2 }),
    '/c/result.json': JSON.stringify({ scenario: 'c', seed: 3 }),
  };
  const report = makeReport([
    { results: [makeResult({ status: 'passed', attachments: [attachment('result.json', '/a/result.json')] })] },
    { testStatus: 'unexpected', results: [makeResult({ status: 'failed', attachments: [attachment('result.json', '/b/result.json')] })] },
    // A skipped test wouldn't normally have written a result.json (it never
    // ran) — this one carries an attachment anyway purely to exercise the
    // skipped-stats bucket; see the dedicated "plain unit-test spec" test
    // above for the realistic zero-attachment skipped/non-scenario case.
    { testStatus: 'skipped', results: [makeResult({ status: 'skipped', attachments: [attachment('result.json', '/c/result.json')] })] },
  ]);
  const manifest = buildManifest({
    report,
    runMeta: { runId: '42', runUrl: 'https://example.invalid/run/42', commitSha: 'deadbeef', workflow: 'Playwright E2E (S.E.S.)', eventName: 'push' },
    outDir,
    ...fakeCollaborators({ files }),
  });
  assert.deepEqual(manifest.stats, { total: 3, passed: 1, failed: 1, skipped: 1 });
  assert.equal(manifest.runId, '42');
  assert.equal(manifest.commitSha, 'deadbeef');
  assert.equal(manifest.eventName, 'push');
  assert.equal(manifest.schemaVersion, 1);
});

test('duplicate (browser, scenario, seed) ids are disambiguated instead of overwriting each other', () => {
  const outDir = '/tmp/replay-out';
  const files = {
    '/a/result.json': JSON.stringify({ scenario: 's', seed: 1 }),
    '/b/result.json': JSON.stringify({ scenario: 's', seed: 1 }),
  };
  const report = makeReport([
    { results: [makeResult({ attachments: [attachment('result.json', '/a/result.json')] })] },
    { results: [makeResult({ attachments: [attachment('result.json', '/b/result.json')] })] },
  ]);
  const { manifestTests } = buildManifestEntries(report, { outDir, ...fakeCollaborators({ files }) });
  const ids = manifestTests.map((t) => t.id);
  assert.equal(new Set(ids).size, 2);
});
