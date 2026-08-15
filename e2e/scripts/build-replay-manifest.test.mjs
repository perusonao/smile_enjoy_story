// Unit tests for build-replay-manifest.mjs — run with `node --test`.
// Deliberately hermetic: copyFile/convertVideo/fileExists/validatePath are
// injected fakes, so these never touch a real ffmpeg/ffprobe binary or
// leave files behind. validateAttachmentPath itself (the real boundary
// check) is exercised directly against a real temp directory + real
// fs.realpathSync/statSync further below, since that's exactly the
// filesystem behavior (symlink resolution, prefix collisions) it exists
// to get right.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  sanitizeSegment,
  collectTestEntries,
  mapStatus,
  buildFfmpegArgs,
  validateAttachmentPath,
  verifyMp4Output,
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

// Hermetic fakes for buildManifestEntries' injected collaborators.
// validatePath here deliberately bypasses the real boundary-resolution
// logic (any path present in `files` is treated as valid, resolving to
// itself) — validateAttachmentPath's actual traversal/symlink/prefix-
// collision behavior is covered on real fs further below, and the
// "rejected attachment" integration wiring is covered by its own test
// using an explicit reject list.
function fakeCollaborators({ files = {}, videoConvertsOk = true, rejectPaths = [] } = {}) {
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
    validatePath: (rawPath) => {
      if (rejectPaths.includes(rawPath)) return { ok: false, error: 'rejected (fake, outside allowed root)' };
      if (!Object.prototype.hasOwnProperty.call(files, rawPath)) return { ok: false, error: 'not found (fake)' };
      return { ok: true, realPath: rawPath };
    },
  };
}

// --- sanitizeSegment / path traversal (output-path sanitization) --------

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

// --- status mapping (Codex Major review, Minor 4) --------------------------

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

test('mapStatus: missing result status on an "unexpected" test is never treated as a pass', () => {
  assert.equal(mapStatus('unexpected', undefined), 'failed');
});

test('mapStatus: a partial report — attachments present, testStatus "expected", but NO final result status — is failed, not silently passed (Codex Minor 4)', () => {
  // This is the exact gap Codex flagged: the old implementation's final
  // fallback line returned 'passed' whenever testStatus wasn't literally
  // 'unexpected', even with a missing finalResultStatus. Policy adopted
  // here (documented on mapStatus itself and in e2e/README.md): any
  // missing/unknown final status maps to 'failed', never to a build error
  // and never to a silent pass.
  assert.equal(mapStatus('expected', undefined), 'failed');
  assert.equal(mapStatus('expected', null), 'failed');
  assert.equal(mapStatus(undefined, undefined), 'failed');
});

// --- ffmpeg args ---------------------------------------------------------

test('buildFfmpegArgs uses H.264 / yuv420p / faststart, no audio track', () => {
  const args = buildFfmpegArgs('/in/video.webm', '/out/video.mp4');
  assert.deepEqual(args, ['-y', '-i', '/in/video.webm', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', '/out/video.mp4']);
});

// --- MP4 robustness: zero-byte + best-effort ffprobe verification --------

test('verifyMp4Output rejects a 0-byte output file', () => {
  const result = verifyMp4Output('/out/video.mp4', {
    statSync: () => ({ isFile: () => true, size: 0 }),
    spawnSyncFn: () => ({ status: 0, stdout: 'h264,yuv420p' }),
  });
  assert.equal(result.ok, false);
  assert.match(result.error, /0-byte/);
});

test('verifyMp4Output rejects a missing output file (stat throws)', () => {
  const result = verifyMp4Output('/out/video.mp4', {
    statSync: () => {
      throw new Error('ENOENT');
    },
  });
  assert.equal(result.ok, false);
  assert.match(result.error, /missing after ffmpeg/);
});

test('verifyMp4Output rejects a non-regular-file output path', () => {
  const result = verifyMp4Output('/out/video.mp4', {
    statSync: () => ({ isFile: () => false, size: 100 }),
  });
  assert.equal(result.ok, false);
  assert.match(result.error, /not a regular file/);
});

test('verifyMp4Output accepts a non-empty file and confirms h264/yuv420p via ffprobe when available', () => {
  const result = verifyMp4Output('/out/video.mp4', {
    statSync: () => ({ isFile: () => true, size: 12345 }),
    spawnSyncFn: () => ({ status: 0, stdout: 'h264,yuv420p\n', stderr: '' }),
  });
  assert.equal(result.ok, true);
});

test('verifyMp4Output rejects an encode whose ffprobe-reported codec/pix_fmt is not h264/yuv420p', () => {
  const result = verifyMp4Output('/out/video.mp4', {
    statSync: () => ({ isFile: () => true, size: 12345 }),
    spawnSyncFn: () => ({ status: 0, stdout: 'vp9,yuv420p\n', stderr: '' }),
  });
  assert.equal(result.ok, false);
  assert.match(result.error, /unexpected encoded stream/);
});

test('verifyMp4Output does not fail the build when ffprobe itself is unavailable (best-effort only)', () => {
  const result = verifyMp4Output('/out/video.mp4', {
    statSync: () => ({ isFile: () => true, size: 12345 }),
    spawnSyncFn: () => ({ error: Object.assign(new Error('ENOENT'), { code: 'ENOENT' }) }),
  });
  assert.equal(result.ok, true);
});

test('verifyMp4Output rejects when ffprobe runs but exits non-zero (corrupt/unreadable encode)', () => {
  const result = verifyMp4Output('/out/video.mp4', {
    statSync: () => ({ isFile: () => true, size: 12345 }),
    spawnSyncFn: () => ({ status: 1, stdout: '', stderr: 'Invalid data found' }),
  });
  assert.equal(result.ok, false);
  assert.match(result.error, /ffprobe could not read/);
});

// --- Attachment source boundary (Codex Major 3) ---------------------------
// validateAttachmentPath exercised against a REAL temp directory tree —
// this is exactly the filesystem behavior (realpath resolution through
// symlinks, prefix collisions) that matters here.

test('validateAttachmentPath: 5 boundary cases on real fs', async (t) => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'ses-replay-boundary-'));
  try {
    const root = path.join(tmp, 'test-results');
    fs.mkdirSync(root, { recursive: true });
    const rootReal = fs.realpathSync(root);

    await t.test('1. valid root-internal attachment -> accepted', () => {
      const inner = path.join(root, 'some-test', 'result.json');
      fs.mkdirSync(path.dirname(inner), { recursive: true });
      fs.writeFileSync(inner, '{}');
      const res = validateAttachmentPath(inner, rootReal);
      assert.equal(res.ok, true);
      assert.equal(res.realPath, fs.realpathSync(inner));
    });

    await t.test('2. ../ traversal -> rejected', () => {
      const outsideFile = path.join(tmp, 'secret.json');
      fs.writeFileSync(outsideFile, '{}');
      const traversal = path.join(root, '..', 'secret.json');
      const res = validateAttachmentPath(traversal, rootReal);
      assert.equal(res.ok, false);
      assert.match(res.error, /outside the allowed test-results root/);
    });

    await t.test('3. absolute path entirely outside root -> rejected', () => {
      const outsideFile = path.join(tmp, 'elsewhere', 'result.json');
      fs.mkdirSync(path.dirname(outsideFile), { recursive: true });
      fs.writeFileSync(outsideFile, '{}');
      const res = validateAttachmentPath(outsideFile, rootReal);
      assert.equal(res.ok, false);
      assert.match(res.error, /outside the allowed test-results root/);
    });

    await t.test('4. symlink inside root pointing outside root -> rejected', () => {
      const secretFile = path.join(tmp, 'symlink-target.json');
      fs.writeFileSync(secretFile, '{"secret":true}');
      const linkPath = path.join(root, 'evil-link.json');
      fs.symlinkSync(secretFile, linkPath);
      const res = validateAttachmentPath(linkPath, rootReal);
      assert.equal(res.ok, false);
      assert.match(res.error, /outside the allowed test-results root/);
    });

    await t.test('5. sibling directory sharing the root name as a string prefix ("test-results-evil") -> rejected, not allowed by a naive startsWith', () => {
      const evilRoot = path.join(tmp, 'test-results-evil');
      const evilFile = path.join(evilRoot, 'result.json');
      fs.mkdirSync(evilRoot, { recursive: true });
      fs.writeFileSync(evilFile, '{}');
      const res = validateAttachmentPath(evilFile, rootReal);
      assert.equal(res.ok, false);
      assert.match(res.error, /outside the allowed test-results root/);
    });

    await t.test('rejects a directory (not a regular file)', () => {
      const dir = path.join(root, 'a-directory');
      fs.mkdirSync(dir, { recursive: true });
      const res = validateAttachmentPath(dir, rootReal);
      assert.equal(res.ok, false);
      assert.match(res.error, /not a regular file/);
    });

    await t.test('rejects a nonexistent path without throwing', () => {
      const res = validateAttachmentPath(path.join(root, 'does-not-exist.json'), rootReal);
      assert.equal(res.ok, false);
      assert.match(res.error, /cannot resolve path/);
    });
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('buildManifestEntries: a rejected (boundary-violating) attachment is never read/copied/converted, just warned — not a silent success', () => {
  const outDir = '/tmp/replay-out';
  const files = {
    '/root/test-results/some-test/result.json': JSON.stringify({ scenario: 'founding-first-assignment', seed: 100001 }),
    '/etc/passwd': 'root:x:0:0::/root:/bin/bash', // simulates a traversal/symlink-escape target
  };
  const report = makeReport([
    {
      results: [
        makeResult({
          attachments: [
            attachment('result.json', '/root/test-results/some-test/result.json'),
            attachment('video', '/etc/passwd'),
            attachment('action-trace.json', '/etc/passwd'),
          ],
        }),
      ],
    },
  ]);
  const collab = fakeCollaborators({ files, rejectPaths: ['/etc/passwd'] });
  const { manifestTests } = buildManifestEntries(report, { outDir, ...collab });
  const t = manifestTests[0];
  assert.equal(t.video, null);
  assert.equal(t.actionTrace, null);
  assert.ok(t.warnings.some((w) => w.includes('video: rejected')));
  assert.ok(t.warnings.some((w) => w.includes('action-trace.json: rejected')));
  // Never touched: no copyFile/convertVideo call was ever made with the
  // rejected path.
  assert.equal(collab.copied.some((c) => c.src === '/etc/passwd'), false);
  assert.equal(collab.converted.some((c) => c.input === '/etc/passwd'), false);
  // result.json (not rejected) still resolved normally.
  assert.equal(t.scenario, 'founding-first-assignment');
});

test('buildManifestEntries: a rejected result.json is never parsed as JSON — scenario/seed fall back, not fabricated from the rejected file', () => {
  const outDir = '/tmp/replay-out';
  const files = {
    '/evil/result.json': JSON.stringify({ scenario: 'should-never-be-used', seed: 999999 }),
  };
  const report = makeReport([
    { specTitle: 'Founding First Assignment (seed 100001)', results: [makeResult({ attachments: [attachment('result.json', '/evil/result.json')] })] },
  ]);
  const collab = fakeCollaborators({ files, rejectPaths: ['/evil/result.json'] });
  const { manifestTests } = buildManifestEntries(report, { outDir, ...collab });
  const t = manifestTests[0];
  assert.equal(t.result, null);
  assert.equal(t.resultSummary, null);
  assert.notEqual(t.scenario, 'should-never-be-used');
  assert.ok(t.warnings.some((w) => w.includes('result.json: rejected')));
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

// --- duplicate (browser, scenario, seed) — Codex Major 2 --------------------

test('duplicate (browser, scenario, seed): manifest IDs, video/result/trace paths, AND file contents are all distinct — no output overwrite', () => {
  const outDir = '/tmp/replay-out';
  const files = {
    '/a/result.json': JSON.stringify({ scenario: 's', seed: 1, actions: 11 }),
    '/a/video.webm': 'VIDEO-CONTENT-A',
    '/a/action-trace.json': JSON.stringify([{ action: 1, clicked: 'first-run' }]),
    '/b/result.json': JSON.stringify({ scenario: 's', seed: 1, actions: 22 }),
    '/b/video.webm': 'VIDEO-CONTENT-B',
    '/b/action-trace.json': JSON.stringify([{ action: 1, clicked: 'second-run' }]),
    '/c/result.json': JSON.stringify({ scenario: 's', seed: 1, actions: 33 }),
    '/c/video.webm': 'VIDEO-CONTENT-C',
    '/c/action-trace.json': JSON.stringify([{ action: 1, clicked: 'third-run' }]),
  };
  const report = makeReport([
    {
      results: [
        makeResult({ attachments: [attachment('result.json', '/a/result.json'), attachment('video', '/a/video.webm'), attachment('action-trace.json', '/a/action-trace.json')] }),
      ],
    },
    {
      results: [
        makeResult({ attachments: [attachment('result.json', '/b/result.json'), attachment('video', '/b/video.webm'), attachment('action-trace.json', '/b/action-trace.json')] }),
      ],
    },
    {
      results: [
        makeResult({ attachments: [attachment('result.json', '/c/result.json'), attachment('video', '/c/video.webm'), attachment('action-trace.json', '/c/action-trace.json')] }),
      ],
    },
  ]);
  const collab = fakeCollaborators({ files });
  const { manifestTests } = buildManifestEntries(report, { outDir, ...collab });

  assert.equal(manifestTests.length, 3);

  const ids = manifestTests.map((t) => t.id);
  assert.equal(new Set(ids).size, 3, 'all 3 manifest IDs must be distinct');

  const videoPaths = manifestTests.map((t) => t.video);
  const resultPaths = manifestTests.map((t) => t.result);
  const tracePaths = manifestTests.map((t) => t.actionTrace);
  assert.equal(new Set(videoPaths).size, 3, 'all 3 video paths must be distinct');
  assert.equal(new Set(resultPaths).size, 3, 'all 3 result paths must be distinct');
  assert.equal(new Set(tracePaths).size, 3, 'all 3 actionTrace paths must be distinct');

  // ID <-> filename 1:1 correspondence, per the requested example shape:
  // founding-first-assignment-100001 / -100001-2 / -100001-3, and the SAME
  // disambiguated basename used for every one of that entry's 3 files.
  assert.deepEqual(
    ids,
    ['mobile-chromium__s-1', 'mobile-chromium__s-1-2', 'mobile-chromium__s-1-3'],
  );
  assert.deepEqual(videoPaths, ['mobile-chromium/s-1.mp4', 'mobile-chromium/s-1-2.mp4', 'mobile-chromium/s-1-3.mp4']);
  assert.deepEqual(resultPaths, ['mobile-chromium/s-1.result.json', 'mobile-chromium/s-1-2.result.json', 'mobile-chromium/s-1-3.result.json']);
  assert.deepEqual(tracePaths, ['mobile-chromium/s-1.trace.json', 'mobile-chromium/s-1-2.trace.json', 'mobile-chromium/s-1-3.trace.json']);

  // Never a card-A-references-card-B mixup: each entry's own resultSummary
  // (sourced from its own distinct result.json) matches its own source
  // file's content, not a neighbor's.
  assert.deepEqual(
    manifestTests.map((t) => t.resultSummary.actions),
    [11, 22, 33],
  );

  // The actual copy/convert calls used 3 distinct destinations too — this
  // is what "no overwrite" means at the filesystem level, not just in the
  // manifest's own bookkeeping.
  const videoDestinations = collab.converted.map((c) => c.output);
  const resultDestinations = collab.copied.filter((c) => c.dest.endsWith('.result.json')).map((c) => c.dest);
  const traceDestinations = collab.copied.filter((c) => c.dest.endsWith('.trace.json')).map((c) => c.dest);
  assert.equal(new Set(videoDestinations).size, 3);
  assert.equal(new Set(resultDestinations).size, 3);
  assert.equal(new Set(traceDestinations).size, 3);
});
