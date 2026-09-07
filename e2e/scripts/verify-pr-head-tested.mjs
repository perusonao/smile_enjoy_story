// SES-CI-SPEED (issue #183): decides whether a main-*push* run of the Fast CI
// `validate` job may skip its own `flutter test` step because the exact same
// source tree was already proven green by that PR's own `validate` check
// before it merged.
//
// This is a fail-safe gate, not an optimization that trusts anything by
// default: every branch below that cannot POSITIVELY prove "this main push's
// tree is byte-for-byte the PR HEAD tree that a passing `validate` check
// already tested" returns `skip: false` — including the kill switch itself
// being unset. Callers must treat any non-`true` `skip` output (including a
// crashed/erroring step) as "run flutter test normally". See the workflow
// step in e2e.yml for how the two failure modes (script says skip:false,
// script step itself fails) are both wired to the same safe fallback.
//
// Proof chain (all required — first failure wins and reports why):
//   1. Kill switch (repository variable SES_CI_SKIP_MAIN_FLUTTER_TEST) must
//      literally be "true". Unset/anything else -> kill-switch-off.
//   2. The push commit's message must match GitHub's own
//      "Merge pull request #N from ..." merge-button subject line (the only
//      merge shape this repo's tooling already assumes elsewhere, see
//      check-latest-main.mjs's sibling parsing in e2e.yml) -> otherwise
//      non-pr-commit (covers direct pushes, squash merges, rebase merges —
//      none of those preserve a second parent we can trust as "the tested
//      commit").
//   3. That commit must have exactly two parents (a real merge commit)
//      -> otherwise unusual-merge.
//   4. The PR (by number, via the REST API) must confirm: merged, its own
//      merge_commit_sha equals this push's SHA, and its head SHA equals the
//      merge commit's second parent -> otherwise ambiguous-pr-mapping. This
//      closes the gap where the commit message *looks* right but doesn't
//      actually correspond to the PR/commit GitHub thinks it does.
//   5. The PR head repo must be this same repo (not a fork) -> otherwise
//      fork-pr. Fork PRs run with a different, restricted token/permissions
//      envelope and must never be treated as equivalently proven.
//   6. The merge commit's tree SHA must equal the PR HEAD commit's tree SHA
//      -> otherwise tree-mismatch. Git tree SHAs are content-addressed, so
//      equal tree SHAs is a direct proof the merge produced byte-identical
//      source (workflows included — the tree covers the whole repo, not a
//      diff) to what the PR HEAD actually was. A non-fast-forward-able merge
//      (base moved and needed real reconciliation) will not have matching
//      trees and correctly falls back here.
//   7. The PR HEAD commit's latest `validate` check run must be
//      status=completed, conclusion=success -> otherwise check-missing (no
//      such check run at all) or check-failed (found, but not a clean
//      success — covers failure/cancelled/timed_out/neutral/etc).
//   8. Any thrown error anywhere above (network failure, non-2xx response,
//      malformed JSON, missing required env) -> api-failure. Never thrown
//      out of `run()` — always resolved to a normal fallback result.
//
// Usage (from e2e.yml, push event only):
//   node e2e/scripts/verify-pr-head-tested.mjs >> "$GITHUB_OUTPUT"
// Always exits 0. Prints GITHUB_OUTPUT-format lines: skip, reason, pr_number
// (empty when not applicable), and error (only present on api-failure).
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_CHECK_NAME = 'validate';

/** Parses the first line of a commit message against GitHub's own merge-button
 * subject shape. Returns { prNumber, headRef } or null if it doesn't match
 * (squash merge, rebase merge, direct push, or anything else non-standard). */
export function parseMergeCommitInfo(message) {
  const subject = (message ?? '').split('\n')[0] ?? '';
  const m = subject.match(/^Merge pull request #(\d+) from (\S+)$/);
  if (!m) return null;
  return { prNumber: Number(m[1]), headRef: m[2] };
}

/** Two tree SHAs are "the same source" iff they are equal, non-empty strings
 * — git tree objects are content-addressed, so this is a direct content
 * proof, not a heuristic. */
export function treesMatch(treeA, treeB) {
  return typeof treeA === 'string' && typeof treeB === 'string' && treeA.length > 0 && treeA === treeB;
}

/** A PR counts as a fork PR (untrusted-equivalent) whenever its head repo is
 * missing (e.g. the fork was deleted after merge) or isn't this exact repo. */
export function isForkPr(pr, expectedFullName) {
  const headFullName = pr?.head?.repo?.full_name;
  return !headFullName || headFullName !== expectedFullName;
}

/** Check runs can appear multiple times for the same ref (re-runs). Picks the
 * most recently completed/started one by name so a stale earlier attempt
 * never masks (in either direction) the actual latest outcome. */
export function pickLatestCheckRun(checkRuns, name) {
  const matches = (checkRuns ?? []).filter((r) => r?.name === name);
  if (matches.length === 0) return null;
  return matches.slice().sort((a, b) => {
    const ta = Date.parse(a.completed_at || a.started_at || 0) || 0;
    const tb = Date.parse(b.completed_at || b.started_at || 0) || 0;
    return tb - ta;
  })[0];
}

export function checkRunPassed(run) {
  return !!run && run.status === 'completed' && run.conclusion === 'success';
}

/** Pure decision function — the entire proof chain, given already-fetched
 * data. Kept separate from network I/O so every branch is directly
 * unit-testable without mocking fetch. Fields the caller hasn't fetched yet
 * (because an earlier check already failed) may be omitted/undefined; every
 * branch below only reads the fields it needs, in the same order `run()`
 * fetches them, so this never throws on missing later fields. */
export function decide({ killSwitchEnabled, mergeCommit, pushSha, pr, prHeadCommit, checkRuns, expectedFullName, checkName = DEFAULT_CHECK_NAME }) {
  if (!killSwitchEnabled) {
    return { skip: false, reason: 'kill-switch-off' };
  }

  const parsed = parseMergeCommitInfo(mergeCommit?.message);
  if (!parsed) {
    return { skip: false, reason: 'non-pr-commit' };
  }

  const parents = mergeCommit?.parents ?? [];
  if (parents.length !== 2) {
    return { skip: false, reason: 'unusual-merge' };
  }

  const mappingOk = pr && pr.merged === true && pr.merge_commit_sha === pushSha && pr.head?.sha === parents[1];
  if (!mappingOk) {
    return { skip: false, reason: 'ambiguous-pr-mapping' };
  }

  if (isForkPr(pr, expectedFullName)) {
    return { skip: false, reason: 'fork-pr' };
  }

  if (!treesMatch(mergeCommit?.treeSha, prHeadCommit?.treeSha)) {
    return { skip: false, reason: 'tree-mismatch' };
  }

  const run = pickLatestCheckRun(checkRuns, checkName);
  if (!run) {
    return { skip: false, reason: 'check-missing' };
  }
  if (!checkRunPassed(run)) {
    return { skip: false, reason: 'check-failed' };
  }

  return { skip: true, reason: 'verified', prNumber: parsed.prNumber };
}

async function githubApiGet(fetchFn, token, url) {
  const res = await fetchFn(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'ses-verify-pr-head-tested-script',
    },
  });
  if (!res.ok) {
    throw new Error(`GitHub API ${url} failed: ${res.status} ${res.statusText}`);
  }
  return res.json();
}

export async function fetchCommitInfo(fetchFn, token, owner, repo, sha) {
  const data = await githubApiGet(fetchFn, token, `https://api.github.com/repos/${owner}/${repo}/commits/${sha}`);
  return {
    sha: data.sha,
    message: data.commit?.message ?? '',
    treeSha: data.commit?.tree?.sha ?? null,
    parents: (data.parents ?? []).map((p) => p.sha),
  };
}

export async function fetchPullRequestInfo(fetchFn, token, owner, repo, prNumber) {
  const data = await githubApiGet(fetchFn, token, `https://api.github.com/repos/${owner}/${repo}/pulls/${prNumber}`);
  return {
    number: data.number,
    merged: data.merged === true,
    merge_commit_sha: data.merge_commit_sha,
    head: { sha: data.head?.sha, repo: data.head?.repo ? { full_name: data.head.repo.full_name } : null },
    base: { repo: data.base?.repo ? { full_name: data.base.repo.full_name } : null },
  };
}

export async function fetchCheckRunsForRef(fetchFn, token, owner, repo, ref) {
  const data = await githubApiGet(fetchFn, token, `https://api.github.com/repos/${owner}/${repo}/commits/${ref}/check-runs?per_page=100`);
  return data.check_runs ?? [];
}

/** Orchestrates the fetches (progressively, stopping as soon as `decide`
 * would already have a definitive fallback answer, to avoid burning API
 * calls on ambiguous/fork/malformed inputs) and always resolves — never
 * rejects — to a decision object. */
export async function run({ env = process.env, fetchFn = globalThis.fetch, checkName = DEFAULT_CHECK_NAME } = {}) {
  const killSwitchEnabled = (env.SES_CI_SKIP_MAIN_FLUTTER_TEST || '').trim().toLowerCase() === 'true';
  if (!killSwitchEnabled) {
    return { skip: false, reason: 'kill-switch-off' };
  }

  try {
    const repoFull = env.GITHUB_REPOSITORY || '';
    const [owner, repo] = repoFull.split('/');
    const pushSha = env.GITHUB_SHA;
    const token = env.GITHUB_TOKEN;
    if (!owner || !repo || !pushSha || !token) {
      throw new Error('missing required environment (GITHUB_REPOSITORY / GITHUB_SHA / GITHUB_TOKEN)');
    }
    const expectedFullName = `${owner}/${repo}`;

    const mergeCommit = await fetchCommitInfo(fetchFn, token, owner, repo, pushSha);
    const parsed = parseMergeCommitInfo(mergeCommit.message);
    if (!parsed || mergeCommit.parents.length !== 2) {
      return decide({ killSwitchEnabled, mergeCommit, pushSha, expectedFullName, checkName });
    }

    const pr = await fetchPullRequestInfo(fetchFn, token, owner, repo, parsed.prNumber);
    const mappingOk = pr && pr.merged === true && pr.merge_commit_sha === pushSha && pr.head?.sha === mergeCommit.parents[1];
    if (!mappingOk || isForkPr(pr, expectedFullName)) {
      return decide({ killSwitchEnabled, mergeCommit, pushSha, pr, expectedFullName, checkName });
    }

    const prHeadCommit = await fetchCommitInfo(fetchFn, token, owner, repo, pr.head.sha);
    if (!treesMatch(mergeCommit.treeSha, prHeadCommit.treeSha)) {
      return decide({ killSwitchEnabled, mergeCommit, pushSha, pr, prHeadCommit, expectedFullName, checkName });
    }

    const checkRuns = await fetchCheckRunsForRef(fetchFn, token, owner, repo, pr.head.sha);
    return decide({ killSwitchEnabled, mergeCommit, pushSha, pr, prHeadCommit, checkRuns, expectedFullName, checkName });
  } catch (err) {
    return { skip: false, reason: 'api-failure', error: err instanceof Error ? err.message : String(err) };
  }
}

function sanitizeForOutput(value) {
  return String(value).replace(/\r?\n/g, ' ').slice(0, 500);
}

async function main() {
  let result;
  try {
    result = await run();
  } catch (err) {
    // run() already catches everything internally; this is an extra net so
    // a truly unexpected bug here still can never fail the calling step.
    result = { skip: false, reason: 'script-crash', error: err instanceof Error ? err.message : String(err) };
  }
  console.log(`skip=${result.skip === true}`);
  console.log(`reason=${result.reason}`);
  console.log(`pr_number=${result.prNumber ?? ''}`);
  if (result.error) {
    console.log(`error=${sanitizeForOutput(result.error)}`);
  }
}

const invokedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (invokedDirectly) {
  // Deliberately never sets a non-zero exit code (see file header): any
  // failure mode here must resolve to "run flutter test normally", not to a
  // failed CI step that would block the merge/build/deploy chain.
  main();
}
