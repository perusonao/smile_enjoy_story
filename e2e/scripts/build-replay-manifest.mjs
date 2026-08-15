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
//                        (default: test-results/playwright-report.json).
//                        Its directory is also the *only* filesystem root
//                        attachment paths are ever allowed to resolve
//                        into — see validateAttachmentPath below.
//   SES_REPLAY_OUT       output directory (default: replay-package)
//   SES_REPLAY_FFMPEG    ffmpeg binary (default: "ffmpeg" on PATH)
//   SES_REPLAY_FFPROBE   ffprobe binary for best-effort post-encode
//                        verification (default: "ffprobe" on PATH; both
//                        ship in the same OS package as ffmpeg on the
//                        GitHub Actions runner image — never a separate
//                        production/Flutter dependency)
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

/** Resolves `rawPath` to its real, symlink-free absolute path and verifies
 * it lies within `allowedRootRealPath` (itself already realpath-resolved).
 * playwright-report.json's attachment paths are trusted in the common
 * case — they're paths this very CI job's own Playwright run just wrote
 * under test-results/ — but this builder never assumes that: a
 * corrupted/hand-edited report, or an attachment that happens to be a
 * symlink pointing outside test-results/, must never result in this
 * script reading, ffmpeg-processing, or copying a file from anywhere
 * outside the one directory it's supposed to operate on.
 *
 * Uses realpath + path.relative — never a bare `startsWith` string check,
 * which would wrongly accept a sibling directory that merely shares the
 * root's name as a prefix (e.g. an attachment resolving into
 * `test-results-evil/` would pass a naive `startsWith('.../test-results')`
 * check even though it is a completely different directory). A relative
 * path starting with `..` (or already absolute, e.g. on a different
 * Windows drive) means "outside the root" on every platform. */
export function validateAttachmentPath(rawPath, allowedRootRealPath, { realpathSync = fs.realpathSync, statSync = fs.statSync } = {}) {
  if (typeof rawPath !== 'string' || rawPath.length === 0) {
    return { ok: false, error: 'no path' };
  }
  let real;
  try {
    real = realpathSync(rawPath);
  } catch (err) {
    return { ok: false, error: `cannot resolve path: ${err.message}` };
  }
  const rel = path.relative(allowedRootRealPath, real);
  if (rel === '') {
    return { ok: false, error: 'resolves to the test-results root itself, not a file inside it' };
  }
  if (rel.startsWith('..') || path.isAbsolute(rel)) {
    return { ok: false, error: `resolves outside the allowed test-results root (${real})` };
  }
  let stat;
  try {
    stat = statSync(real);
  } catch (err) {
    return { ok: false, error: `cannot stat resolved path: ${err.message}` };
  }
  if (!stat.isFile()) {
    return { ok: false, error: 'resolved path is not a regular file' };
  }
  return { ok: true, realPath: real };
}

function readJsonFileSafe(filePath, readFile) {
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

/** A skipped test is 'skipped'. Every other case is judged strictly by
 * whether the final attempt's own Playwright status is exactly 'passed' —
 * failed/timedOut/interrupted all map to 'failed', and so does a MISSING
 * final status (an empty/partial or malformed report). This is a
 * deliberately conservative policy: a report that doesn't clearly say a
 * test passed is never treated as though it did — "unknown -> failed",
 * not "unknown -> manifest build error" (one test's partial result
 * shouldn't sink the whole replay package; see the per-test
 * warning/degradation policy in buildManifestEntries). */
export function mapStatus(testStatus, finalResultStatus) {
  if (testStatus === 'skipped') return 'skipped';
  return finalResultStatus === 'passed' ? 'passed' : 'failed';
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
    // problem, not a per-video quirk; never a CI/production `ffmpeg`
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

/** Runs after a successful ffmpeg exit: refuses to publish a missing or
 * 0-byte MP4 (a truncated/corrupt encode must never end up linked from
 * the manifest). Best-effort only beyond that: when ffprobe happens to be
 * on PATH (the same OS package as ffmpeg on the runner image — never
 * installed as a separate dependency here), it also confirms the encoded
 * stream is really H.264/yuv420p as requested. If ffprobe itself isn't
 * available, that extra check is simply skipped — an absent *verification*
 * tool is not grounds to reject an otherwise successfully-encoded,
 * non-empty file. */
export function verifyMp4Output(outputPath, { ffprobeBin = 'ffprobe', statSync = fs.statSync, spawnSyncFn = spawnSync } = {}) {
  let stat;
  try {
    stat = statSync(outputPath);
  } catch (err) {
    return { ok: false, error: `output file missing after ffmpeg: ${err.message}` };
  }
  if (!stat.isFile()) {
    return { ok: false, error: 'ffmpeg output path is not a regular file' };
  }
  if (stat.size <= 0) {
    return { ok: false, error: 'ffmpeg produced a 0-byte file' };
  }

  const probe = spawnSyncFn(ffprobeBin, ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,pix_fmt', '-of', 'csv=p=0', outputPath], {
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (probe.error) {
    // ffprobe not on PATH — best-effort codec verification skipped.
    return { ok: true };
  }
  if (probe.status !== 0) {
    return { ok: false, error: `ffprobe could not read the encoded output: ${(probe.stderr?.toString() || '').slice(-500)}` };
  }
  const [codec, pixFmt] = (probe.stdout?.toString() || '')
    .trim()
    .split(',')
    .map((s) => s.trim());
  if (codec !== 'h264' || pixFmt !== 'yuv420p') {
    return { ok: false, error: `unexpected encoded stream (codec=${codec ?? '?'} pix_fmt=${pixFmt ?? '?'}), expected h264/yuv420p` };
  }
  return { ok: true };
}

/** Default fs-backed collaborators for buildManifest's injectable
 * copy/convert/validate steps — swapped out in unit tests for hermetic
 * fakes that touch neither the filesystem nor a real ffmpeg/ffprobe
 * binary. `testResultsRootRealPath` must already be realpath-resolved
 * (see validateAttachmentPath / main() below). */
export function makeFsCollaborators({ ffmpegBin, ffprobeBin, testResultsRootRealPath }) {
  return {
    copyFile: (src, dest) => {
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.copyFileSync(src, dest);
    },
    convertVideo: (inputPath, outputPath) => {
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });
      const converted = runFfmpeg(ffmpegBin, inputPath, outputPath);
      if (!converted.ok) return converted;
      return verifyMp4Output(outputPath, { ffprobeBin });
    },
    fileExists: (p) => fs.existsSync(p),
    readFile: (p) => fs.readFileSync(p, 'utf-8'),
    validatePath: (rawPath) => validateAttachmentPath(rawPath, testResultsRootRealPath),
  };
}

function posixJoin(...parts) {
  return parts.join('/');
}

/** Builds the flat `tests` array + collects any non-fatal per-test
 * warnings (missing video, missing result.json, malformed JSON, a
 * rejected/out-of-bounds attachment path, a failed ffmpeg conversion,
 * ...). A per-test problem degrades that one entry — it never aborts the
 * whole build and it never silently disappears: it's recorded in that
 * entry's `warnings` and also returned in `buildWarnings` for the caller
 * to log. */
export function buildManifestEntries(report, { outDir, copyFile, convertVideo, fileExists, readFile, validatePath }) {
  const entries = collectTestEntries(report);
  const manifestTests = [];
  const buildWarnings = [];
  // Scoped by "browserSeg/baseName" — the actual filesystem collision
  // domain (video/result.json/trace.json all live under relDir/baseName.*)
  // — so two same-(browser, scenario, seed) entries always end up on two
  // different baseNames instead of one silently overwriting the other's
  // MP4/result/trace files on disk.
  const seenBaseNames = new Set();

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

    const warnings = [];

    // Every attachment path is boundary-validated before this builder ever
    // touches the filesystem for it (see validateAttachmentPath). A
    // rejected path is never read, never handed to ffmpeg, never copied —
    // only recorded as a warning.
    const resultCheck = resultPath ? validatePath(resultPath) : null;
    const traceCheck = tracePath ? validatePath(tracePath) : null;
    const videoCheck = videoPath ? validatePath(videoPath) : null;

    let resultRead;
    if (!resultPath) {
      resultRead = { ok: false, error: 'not attached' };
      warnings.push('result.json: not attached');
    } else if (!resultCheck.ok) {
      resultRead = { ok: false, error: resultCheck.error };
      warnings.push(`result.json: rejected (${resultCheck.error})`);
    } else {
      resultRead = readJsonFileSafe(resultCheck.realPath, readFile);
      if (!resultRead.ok) warnings.push(`result.json: ${resultRead.error}`);
    }

    const scenarioRaw = resultRead.ok ? resultRead.data?.scenario : null;
    const seedRaw = resultRead.ok ? resultRead.data?.seed : null;
    const scenario = sanitizeSegment(scenarioRaw, sanitizeSegment(specTitle, 'unknown-scenario'));
    const seedNum = Number(seedRaw);
    const seed = resultRead.ok && Number.isFinite(seedNum) ? Math.trunc(seedNum) : null;
    const browserSeg = sanitizeSegment(browser, 'unknown-browser');
    const seedSeg = seed === null ? 'noseed' : String(seed);
    const relDir = browserSeg;

    // baseName is disambiguated FIRST, then used as the single source of
    // truth for both the manifest id and every output filename below — a
    // guaranteed 1:1 mapping, so two entries can never share (and one
    // silently overwrite) the same video/result/trace file on disk.
    let baseName = `${scenario}-${seedSeg}`;
    const collisionKey = (name) => `${relDir}/${name}`;
    if (seenBaseNames.has(collisionKey(baseName))) {
      let n = 2;
      while (seenBaseNames.has(collisionKey(`${baseName}-${n}`))) n++;
      baseName = `${baseName}-${n}`;
    }
    seenBaseNames.add(collisionKey(baseName));
    const id = `${browserSeg}__${baseName}`;

    let videoRel = null;
    if (!videoPath) {
      warnings.push('video attachment missing');
    } else if (!videoCheck.ok) {
      warnings.push(`video: rejected (${videoCheck.error})`);
    } else {
      const mp4Rel = posixJoin(relDir, `${baseName}.mp4`);
      const mp4Abs = path.join(outDir, ...mp4Rel.split('/'));
      const converted = convertVideo(videoCheck.realPath, mp4Abs);
      if (converted.ok) {
        videoRel = mp4Rel;
      } else {
        warnings.push(`video conversion failed: ${converted.error}`);
      }
    }

    // Only copy/link result.json into the package once it's confirmed
    // boundary-valid AND valid JSON — never republished as if it were a
    // working Result Viewer payload otherwise.
    let resultRel = null;
    if (resultRead.ok) {
      const rel = posixJoin(relDir, `${baseName}.result.json`);
      copyFile(resultCheck.realPath, path.join(outDir, ...rel.split('/')));
      resultRel = rel;
    }

    let traceRel = null;
    if (!tracePath) {
      warnings.push('action-trace.json missing');
    } else if (!traceCheck.ok) {
      warnings.push(`action-trace.json: rejected (${traceCheck.error})`);
    } else {
      const rel = posixJoin(relDir, `${baseName}.trace.json`);
      copyFile(traceCheck.realPath, path.join(outDir, ...rel.split('/')));
      traceRel = rel;
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

export function buildManifest({ report, runMeta, outDir, copyFile, convertVideo, fileExists, readFile, validatePath }) {
  const { manifestTests, buildWarnings } = buildManifestEntries(report, { outDir, copyFile, convertVideo, fileExists, readFile, validatePath });
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
  const ffprobeBin = process.env.SES_REPLAY_FFPROBE || 'ffprobe';

  if (!fs.existsSync(reportPath)) {
    throw new ReplayBuildError(`playwright-report.json not found at ${reportPath} — did Playwright run?`);
  }
  let report;
  try {
    report = JSON.parse(fs.readFileSync(reportPath, 'utf-8'));
  } catch (err) {
    throw new ReplayBuildError(`playwright-report.json is not valid JSON: ${err.message}`);
  }

  const testResultsRoot = path.dirname(reportPath);
  let testResultsRootRealPath;
  try {
    testResultsRootRealPath = fs.realpathSync(testResultsRoot);
  } catch (err) {
    throw new ReplayBuildError(`cannot resolve the test-results root (${testResultsRoot}): ${err.message}`);
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
    ...makeFsCollaborators({ ffmpegBin, ffprobeBin, testResultsRootRealPath }),
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
    // unresolvable test-results root, ffmpeg unavailable) prints loudly
    // and fails the CI step.
    console.error(`[build-replay-manifest] FAILED: ${err instanceof Error ? err.message : String(err)}`);
    process.exitCode = 1;
  }
}
