// Converts the video-showcase spec's Playwright-recorded .webm (VP8/VP9 in
// a WebM container) into an H.264/yuv420p/faststart .mp4 — the format the
// task brief asks the final deliverable be in, since a raw .webm doesn't
// play natively everywhere a human might want to watch it (some Slack/Teams
// embeds, some phones' default players, some presentation software).
//
// Dependency-free beyond `ffmpeg` itself (same "no extra npm download"
// principle as scripts/static-server.js) — shells out via child_process,
// never a video-processing npm package.
//
// Usage:
//   node scripts/convert-showcase-video.mjs [input.webm] [output.mp4]
// With no args, finds the single video.webm Playwright wrote under
// ./test-results-showcase/** (the video-showcase spec always records
// exactly one, per playwright.showcase.config.ts's `workers: 1`) and writes
// alongside it as showcase-video.mp4.
'use strict';

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const e2eRoot = path.resolve(__dirname, '..');

function findFirstWebm(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const found = findFirstWebm(full);
      if (found) return found;
    } else if (entry.isFile() && entry.name.toLowerCase().endsWith('.webm')) {
      return full;
    }
  }
  return null;
}

function main() {
  const [, , inputArg, outputArg] = process.argv;

  const input = inputArg
    ? path.resolve(inputArg)
    : findFirstWebm(path.join(e2eRoot, 'test-results-showcase'));

  if (!input || !fs.existsSync(input)) {
    console.error(
      '[convert-showcase-video] no input .webm found — run `npm run showcase:video` first, ' +
        'or pass an explicit path: node scripts/convert-showcase-video.mjs <input.webm> [output.mp4]',
    );
    process.exit(1);
  }

  const output = outputArg ? path.resolve(outputArg) : path.join(path.dirname(input), 'showcase-video.mp4');

  const ffmpegCheck = spawnSync('ffmpeg', ['-version'], { stdio: 'ignore' });
  if (ffmpegCheck.error) {
    console.error('[convert-showcase-video] ffmpeg not found on PATH — install it first (e.g. `apt-get install ffmpeg`).');
    process.exit(1);
  }

  console.log(`[convert-showcase-video] input:  ${input}`);
  console.log(`[convert-showcase-video] output: ${output}`);

  // -c:v libx264 + -pix_fmt yuv420p: H.264/yuv420p, the single most widely
  // compatible combination (yuv420p specifically because some players/
  // embeds reject yuv444p/yuv422p H.264). -movflags +faststart moves the
  // moov atom to the front of the file so playback (and web-embedded
  // preview players) can start before the whole file has downloaded. No
  // audio track exists in the source (Playwright's recordVideo captures
  // video only), so no -c:a flag is needed.
  const result = spawnSync(
    'ffmpeg',
    ['-y', '-i', input, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', output],
    { stdio: 'inherit' },
  );

  if (result.status !== 0) {
    console.error(`[convert-showcase-video] ffmpeg exited with code ${result.status}`);
    process.exit(result.status ?? 1);
  }

  console.log('[convert-showcase-video] done.');
}

main();
