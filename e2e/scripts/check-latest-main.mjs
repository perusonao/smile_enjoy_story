// Guards deploy.yml against a stale-run Pages rollback (Codex Major 1):
// a slower/earlier-queued workflow_run for an OLDER main commit must never
// call actions/deploy-pages *after* a newer commit's run already deployed,
// which would silently roll production back to the older commit.
//
// This is deliberately NOT expressed only via GitHub Actions `concurrency:`
// — a concurrency group only serializes *execution order of runs that are
// already queued*, it says nothing about which commit's E2E happened to
// finish first, so relying on it as a "latest wins" guarantee is exactly
// the bug this script exists to close. The actual guard is a direct value
// comparison, done as close to the real deploy-pages call as possible:
// "is the commit this run is about to deploy still origin/main's current
// tip, right now?" If not, the caller must skip the deploy — this script
// only ever reports true/false, it never deletes/mutates anything.
//
// Usage: node check-latest-main.mjs <targetSha> <remoteUrl> <branch>
// Prints GITHUB_OUTPUT-format lines to stdout:
//   target_sha=<targetSha>
//   current_sha=<the branch's actual current tip>
//   is_latest=true|false
// Always exits 0 (a "not latest" result is a normal, expected outcome for
// deploy.yml to act on — not a script failure). Only a genuine inability to
// determine the current tip (git itself failing, unparseable output) is a
// script failure (non-zero exit + a message on stderr).
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

/** Parses `git ls-remote <url> refs/heads/<branch>` stdout — a single
 * "<sha>\trefs/heads/<branch>" line (or empty, if the branch doesn't
 * exist) — into just the SHA, or null if it can't be found/parsed. */
export function parseLsRemoteHead(stdout) {
  const line = (stdout ?? '').split('\n').find((l) => l.trim().length > 0);
  if (!line) return null;
  const sha = line.split(/\s+/)[0];
  return /^[0-9a-f]{40}$/i.test(sha) ? sha.toLowerCase() : null;
}

/** Pure comparison — the actual "is this run still deployable" decision,
 * kept separate from the git plumbing so it's trivially unit-testable:
 * A != current main -> false (deploy forbidden), B == current main -> true
 * (deploy allowed). */
export function isLatestCommit(targetSha, currentSha) {
  return typeof targetSha === 'string' && typeof currentSha === 'string' && targetSha.trim().toLowerCase() === currentSha.trim().toLowerCase();
}

export function resolveCurrentMainSha(remoteUrl, branch, { spawnSyncFn = spawnSync } = {}) {
  const res = spawnSyncFn('git', ['ls-remote', remoteUrl, `refs/heads/${branch}`], { encoding: 'utf-8' });
  if (res.error) {
    throw new Error(`git ls-remote could not be launched: ${res.error.message}`);
  }
  if (res.status !== 0) {
    throw new Error(`git ls-remote failed (exit ${res.status}): ${(res.stderr || '').trim()}`);
  }
  const sha = parseLsRemoteHead(res.stdout);
  if (!sha) {
    throw new Error(`could not parse a commit SHA for refs/heads/${branch} from git ls-remote output: ${JSON.stringify(res.stdout)}`);
  }
  return sha;
}

function main() {
  const [targetSha, remoteUrl, branch] = process.argv.slice(2);
  if (!targetSha || !remoteUrl || !branch) {
    console.error('usage: node check-latest-main.mjs <targetSha> <remoteUrl> <branch>');
    process.exitCode = 1;
    return;
  }
  const currentSha = resolveCurrentMainSha(remoteUrl, branch);
  const latest = isLatestCommit(targetSha, currentSha);
  console.log(`target_sha=${targetSha}`);
  console.log(`current_sha=${currentSha}`);
  console.log(`is_latest=${latest}`);
}

const invokedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (invokedDirectly) {
  try {
    main();
  } catch (err) {
    console.error(`[check-latest-main] FAILED: ${err instanceof Error ? err.message : String(err)}`);
    process.exitCode = 1;
  }
}
