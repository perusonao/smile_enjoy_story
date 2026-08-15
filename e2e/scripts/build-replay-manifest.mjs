// Builds a self-contained "replay package" (manifest.json + per-test
// MP4/result/action-trace files) from a completed Playwright run, for the
// E2E Replay Viewer (a dev/QA tool — see e2e/replay-viewer/). This is
// strictly a QA/CI utility: it never touches Flutter/lib code, never
// changes what Playwright ran or how it scored pass/fail, and reads only
// Playwright's own JSON reporter output (test-results/playwright-report.json,
// already produced by playwright.config.ts's `json` reporter) plus the
// result.json/action-trace.json/video attachments helpers/artifacts.ts
// already writes. Nothing here is invented — fields not present in those
// sources are simply omitted (never guessed).
//
// Usage: node build-replay-manifest.mjs
//
// Env (all optional):
//   SES_REPLAY_REPORT   path to playwright-report.json
//                        (default: test-results/playwright-report.json)
//   SES_REPLAY_OUT       output directory (default: replay-package)
//   SES_REPLAY_FFMPEG    ffmpeg binary (default: "ffmpeg" on PATH)
//   SES_REPLAY_RUN_ID / SES_REPLAY_RUN_URL / SES_REPLAY_COMMIT_SHA /
//   SES_REPLAY_WORKFLOW / SES_REPLAY_EVENT — run metadata for the
//     manifest header, taken from the GitHub Actions context by the
//     workflow step, never fabricated here.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

export class ReplayBuildError extends Error {}

/** Only filesystem-safe characters survive; everything else — including
 * `/`, `\`, `..`, control/Unicode chars — collapses to `_`. Applied to
 * every value (scenario, seed, browser) that ends up in an output path.
 * `scenario`/`seed` ultimately come from a JSON file (result.json) that
 * this builder treats as untrusted input for path-construction purposes,
 * even though in practice it's written by our own trusted E2E code —
 * defense in depth against path traversal, tested explicitly below. */
export function sanitizeSegment(value, fallback) {
  const s = String(value ?? '');
  const cleaned = s
    .replace(/[^A-Za-z0-9_-]+/g, '_')
    .replace(/^_+|_+$/g, '');
  const trimmed = cleaned.slice(0, 80);
  return trimmed.length > 0 ? trimmed : fallback;
}

/** Recursively flattens Playwright's JSON reporter suite tree
 * (suites -> specs -> tests -> results) into one entry per (spec, test),
 * keeping only the final (last-retry) result — the one that decided the
 * test's actual outcome and whose attachments are the ones worth
 * replaying. Throws on a structurally malformed report rather than
 * silently returning an empty list, so a broken/truncated
 * playwright-report.json is a loud build failure, not a quietly empty
 * replay package. */
export function collectTestEntries(report) {
  if (!report || typeof report !== 'object' || !Array.isArray(report.suites)) {
    throw new ReplayBuildError('playwright-report.json: missing or malformed "suites" array');
  }
  const entries = [];
  const walk = (suites) => {
    for (const suite of suites ?? []) {
      for (const spec of suite.specs ?? []) {
        for (const test of spec.tests ?? []) {
          const results = Array.isArray(test.results) ? test.results : [];
          const finalResult = results.length > 0 ? results[results.length - 1] : null;
          entries.push({
            specTitle: spec.title,
            browser: test.projectName,
            testStatus: test.status, // 'skipped' | 'expected' | 'unexpected' | 'flaky'
            finalResult,
          });
        }
      }
      if (Array.isArray(suite.suites)) walk(suite.suites);
    }
  };
  walk(report.suites);
  return entries;
}

function findAttachment(attachments, name) {
  if (!Array.isArray(attachments)) return null;
  const found = attachments.find((a) => a && a.name === name && typeof a.path === 'string');
  return found ? found.path : null;
}

function readJsonFileSafe(filePath, readFile) {
  if (!filePath) return { ok: false, error: 'not attached' };
  let text;
  try {
    text = readFile(filePath);
  } catch (err) {
    return { ok: false, error: `unreadable: ${err.message}` };
  }
  try {
    return { ok: true, data: JSON.parse(text) };
  } catch (err) {
    return { ok: false, error: `malformed JSON: ${err.message}` };
  }
}

/** A skipped test is 'skipped'; anything else is judged strictly by its
 * final attempt's own Playwright status — never by whether the earlier
 * attempts passed, and never softened to "passed" just because the test
 * eventually stopped retrying. A missing status (shouldn't normally
 * happen) is treated as failed, never as a silent pass. */
export function mapStatus(testStatus, finalResultStatus) {
  if (testStatus === 'skipped') return 'skipped';
  if (finalResultStatus === 'passed') return 'passed';
  if (finalResultStatus) return 'failed'; // failed / timedOut / interrupted
  return testStatus === 'unexpected' ? 'failed' : 'passed';
}

/** Pure — the exact ffmpeg argument vector, so the transcode policy
 * (H.264 / yuv420p / faststart, per the approved design) is unit-testable
 * without invoking a real binary. */
export function buildFfmpegArgs(inputPath, outputPath) {
  return ['-y', '-i', inputPath, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', outputPath];
}

function runFfmpeg(ffmpegBin, inputPath, outputPath) {
  const res = spawnSync(ffmpegBin, buildFfmpegArgs(inputPath, outputPath), { stdio: ['ignore', 'pipe', 'pipe'] });
  if (res.error) {
    // ffmpeg itself couldn't be launched (e.g. ENOENT) — a systemic
    // problem, not a per-video quirk; never CI/production `ffmpeg`
    // dependency, this is the OS binary already on the GitHub Actions
    // runner image.
    throw new ReplayBuildError(`ffmpeg could not be launched ("${ffmpegBin}"): ${res.error.message}`);
  }
  if (res.status !== 0) {
    const stderrTail = (res.stderr?.toString() || `ffmpeg exited with status ${res.status}`).slice(-2000);
    return { ok: false, error: stderrTail };
  }
  return { ok: true };
}

/** Default fs-backed collaborators for buildManifest's injectable
 * copy/convert steps — swapped out in unit tests for hermetic fakes that
 * touch neither the filesystem nor a real ffmpeg binary. */
export function makeFsCollaborators({ ffmpegBin }) {
  return {
    copyFile: (src, dest) => {
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.copyFileSync(src, dest);
    },
    convertVideo: (inputPath, outputPath) => {
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });
      return runFfmpeg(ffmpegBin, inputPath, outputPath);
    },
    fileExists: (p) => fs.existsSync(p),
    readFile: (p) => fs.readFileSync(p, 'utf-8'),
  };
}

/** Builds the flat `tests` array + collects any non-fatal per-test
 * warnings (missing video, missing result.json, malformed JSON, a failed
 * ffmpeg conversion, ...). A per-test problem degrades that one entry —
 * it never aborts the whole build and it never silently disappears: it's
 * recorded in that entry's `warnings` and also returned in
 * `buildWarnings` for the caller to log. */
export function buildManifestEntries(report, { outDir, copyFile, convertVideo, fileExists, readFile }) {
  const entries = collectTestEntries(report);
  const manifestTests = [];
  const buildWarnings = [];
  const seenIds = new Set();

  for (const entry of entries) {
    const { browser, finalResult, testStatus, specTitle } = entry;
    const status = mapStatus(testStatus, finalResult?.status);
    const attachments = finalResult?.attachments ?? [];

    const resultPath = findAttachment(attachments, 'result.json');
    const tracePath = findAttachment(attachments, 'action-trace.json');
    const videoPath = findAttachment(attachments, 'video');

    // Not every Playwright test in this suite is a scenario playthrough —
    // e2e/tests/ also has plain unit-test specs (artifacts.allowlist.spec.ts,
    // seeds.spec.ts, ses-player.completionCapOrdering.spec.ts, ...) that
    // never call writeArtifacts(). The presence of a `video` attachment
    // alone doesn't mean much either: SES_E2E_VIDEO=on makes Playwright
    // auto-record a video for every test's browser context project-wide,
    // scenario or not. result.json/action-trace.json only ever exist for a
    // test that actually called writeArtifacts() (helpers/artifacts.ts) —
    // that's the one reliable "this is a real scenario replay" signal.
    // Skipping anything without either keeps the Viewer's card list to
    // actual playthroughs instead of dozens of "no data" noise cards; a
    // scenario test that's merely missing *one* of the three attachments
    // still gets a full entry (with a warning) below.
    if (!resultPath && !tracePath) continue;

    const resultRead = readJsonFileSafe(resultPath, readFile);
    const warnings = [];
    if (!resultRead.ok) warnings.push(`result.json: ${resultRead.error}`);

    const scenarioRaw = resultRead.ok ? resultRead.data?.scenario : null;
    const seedRaw = resultRead.ok ? resultRead.data?.seed : null;
    const scenario = sanitizeSegment(scenarioRaw, sanitizeSegment(specTitle, 'unknown-scenario'));
    const seedNum = Number(seedRaw);
    const seed = resultRead.ok && Number.isFinite(seedNum) ? Math.trunc(seedNum) : null;
    const browserSeg = sanitizeSegment(browser, 'unknown-browser');
    const seedSeg = seed === null ? 'noseed' : String(seed);

    let id = `${browserSeg}__${scenario}__${seedSeg}`;
    if (seenIds.has(id)) {
      let n = 2;
      while (seenIds.has(`${id}-${n}`)) n++;
      id = `${id}-${n}`;
    }
    seenIds.add(id);

    const baseName = `${scenario}-${seedSeg}`;
    const relDir = browserSeg;

    let videoRel = null;
    if (videoPath && fileExists(videoPath)) {
      const mp4Rel = posixJoin(relDir, `${baseName}.mp4`);
      const mp4Abs = path.join(outDir, ...mp4Rel.split('/'));
      const converted = convertVideo(videoPath, mp4Abs);
      if (converted.ok) {
        videoRel = mp4Rel;
      } else {
        warnings.push(`video conversion failed: ${converted.error}`);
      }
    } else {
      warnings.push('video attachment missing');
    }

    // Only copy/link result.json into the package once it's confirmed valid
    // JSON — a malformed file is recorded as a warning above, not
    // republished as if it were a working Result Viewer payload.
    let resultRel = null;
    if (resultPath && resultRead.ok) {
      const rel = posixJoin(relDir, `${baseName}.result.json`);
      copyFile(resultPath, path.join(outDir, ...rel.split('/')));
      resultRel = rel;
    }

    let traceRel = null;
    if (tracePath && fileExists(tracePath)) {
      const rel = posixJoin(relDir, `${baseName}.trace.json`);
      copyFile(tracePath, path.join(outDir, ...rel.split('/')));
      traceRel = rel;
    } else {
      warnings.push('action-trace.json missing');
    }

    const r = resultRead.ok && resultRead.data && typeof resultRead.data === 'object' ? resultRead.data : {};
    manifestTests.push({
      id,
      browser,
      scenario,
      seed,
      status,
      retry: typeof finalResult?.retry === 'number' ? finalResult.retry : 0,
      durationMs: typeof r.durationMs === 'number' ? r.durationMs : (typeof finalResult?.duration === 'number' ? finalResult.duration : null),
      video: videoRel,
      videoFormat: videoRel ? 'mp4' : null,
      result: resultRel,
      actionTrace: traceRel,
      resultSummary: resultRead.ok
        ? {
            completed: r.completed ?? null,
            firstAssignmentWeek: r.firstAssignmentWeek ?? null,
            actions: r.actions ?? null,
            stallDetected: r.stallDetected ?? null,
            stallReason: r.stallReason ?? null,
            rejectedCandidateName: r.rejectedCandidateName ?? null,
            acceptedCandidateName: r.acceptedCandidateName ?? null,
            consoleErrorCount: Array.isArray(r.consoleErrors) ? r.consoleErrors.length : null,
            pageErrorCount: Array.isArray(r.pageErrors) ? r.pageErrors.length : null,
          }
        : null,
      warnings,
    });
    buildWarnings.push(...warnings.map((w) => `${id}: ${w}`));
  }

  return { manifestTests, buildWarnings };
}

function posixJoin(...parts) {
  return parts.join('/');
}

export function buildManifest({ report, runMeta, outDir, copyFile, convertVideo, fileExists, readFile }) {
  const { manifestTests, buildWarnings } = buildManifestEntries(report, { outDir, copyFile, convertVideo, fileExists, readFile });
  const stats = manifestTests.reduce(
    (acc, t) => {
      acc.total += 1;
      acc[t.status] = (acc[t.status] ?? 0) + 1;
      return acc;
    },
    { total: 0, passed: 0, failed: 0, skipped: 0 },
  );
  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    runId: runMeta?.runId ?? null,
    runUrl: runMeta?.runUrl ?? null,
    commitSha: runMeta?.commitSha ?? null,
    workflow: runMeta?.workflow ?? null,
    eventName: runMeta?.eventName ?? null,
    stats,
    tests: manifestTests,
    buildWarnings,
  };
}

// ---------------------------------------------------------------- CLI ---

function main() {
  const reportPath = path.resolve(process.env.SES_REPLAY_REPORT || 'test-results/playwright-report.json');
  const outDir = path.resolve(process.env.SES_REPLAY_OUT || 'replay-package');
  const ffmpegBin = process.env.SES_REPLAY_FFMPEG || 'ffmpeg';

  if (!fs.existsSync(reportPath)) {
    throw new ReplayBuildError(`playwright-report.json not found at ${reportPath} — did Playwright run?`);
  }
  let report;
  try {
    report = JSON.parse(fs.readFileSync(reportPath, 'utf-8'));
  } catch (err) {
    throw new ReplayBuildError(`playwright-report.json is not valid JSON: ${err.message}`);
  }

  fs.rmSync(outDir, { recursive: true, force: true });
  fs.mkdirSync(outDir, { recursive: true });

  const manifest = buildManifest({
    report,
    runMeta: {
      runId: process.env.SES_REPLAY_RUN_ID || null,
      runUrl: process.env.SES_REPLAY_RUN_URL || null,
      commitSha: process.env.SES_REPLAY_COMMIT_SHA || null,
      workflow: process.env.SES_REPLAY_WORKFLOW || null,
      eventName: process.env.SES_REPLAY_EVENT || null,
    },
    outDir,
    ...makeFsCollaborators({ ffmpegBin }),
  });

  fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2), 'utf-8');

  console.log(
    `[build-replay-manifest] wrote ${manifest.tests.length} test entries ` +
      `(passed=${manifest.stats.passed} failed=${manifest.stats.failed} skipped=${manifest.stats.skipped}) to ${outDir}`,
  );
  for (const w of manifest.buildWarnings) console.warn(`[build-replay-manifest] WARNING: ${w}`);
  if (manifest.tests.length === 0) {
    console.warn('[build-replay-manifest] no tests found in playwright-report.json — empty run, not an error by itself');
  }
}

const invokedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (invokedDirectly) {
  try {
    main();
  } catch (err) {
    // Never a silent success: any hard error (missing/malformed report,
    // ffmpeg unavailable) prints loudly and fails the CI step.
    console.error(`[build-replay-manifest] FAILED: ${err instanceof Error ? err.message : String(err)}`);
    process.exitCode = 1;
  }
}
