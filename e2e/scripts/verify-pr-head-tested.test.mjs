// Unit tests for verify-pr-head-tested.mjs (SES-CI-SPEED, issue #183).
// Required scenarios (per the fail-safe design): verified success, tree
// mismatch, missing check, failed check, API failure, malformed/non-PR
// commit, fork PR, kill switch OFF. All network access is faked via an
// injected fetchFn — no real HTTP calls.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parseMergeCommitInfo,
  treesMatch,
  isForkPr,
  pickLatestCheckRun,
  checkRunPassed,
  decide,
  run,
} from './verify-pr-head-tested.mjs';

const OWNER = 'perusonao';
const REPO = 'smile_enjoy_story';
const EXPECTED_FULL_NAME = `${OWNER}/${REPO}`;
const PUSH_SHA = 'm'.repeat(40);
const PREV_MAIN_SHA = 'p'.repeat(40);
const PR_HEAD_SHA = 'h'.repeat(40);
const TREE_SHA = 't'.repeat(40);

function baseMergeCommit(overrides = {}) {
  return {
    sha: PUSH_SHA,
    message: 'Merge pull request #42 from perusonao/some-feature-branch',
    treeSha: TREE_SHA,
    parents: [PREV_MAIN_SHA, PR_HEAD_SHA],
    ...overrides,
  };
}

function basePr(overrides = {}) {
  return {
    number: 42,
    merged: true,
    merge_commit_sha: PUSH_SHA,
    head: { sha: PR_HEAD_SHA, repo: { full_name: EXPECTED_FULL_NAME } },
    base: { repo: { full_name: EXPECTED_FULL_NAME } },
    ...overrides,
  };
}

function basePrHeadCommit(overrides = {}) {
  return { sha: PR_HEAD_SHA, message: 'feat: some feature', treeSha: TREE_SHA, parents: [PREV_MAIN_SHA], ...overrides };
}

function passingCheckRuns(overrides = {}) {
  return [{ name: 'validate', status: 'completed', conclusion: 'success', started_at: '2026-01-01T00:00:00Z', completed_at: '2026-01-01T00:05:00Z', ...overrides }];
}

// --- pure helpers -----------------------------------------------------

test('parseMergeCommitInfo matches a standard GitHub merge-button subject', () => {
  const parsed = parseMergeCommitInfo('Merge pull request #42 from perusonao/some-feature-branch\n\nSome body');
  assert.deepEqual(parsed, { prNumber: 42, headRef: 'perusonao/some-feature-branch' });
});

test('parseMergeCommitInfo returns null for a squash-merge-shaped subject', () => {
  assert.equal(parseMergeCommitInfo('feat: some feature (#42)'), null);
});

test('parseMergeCommitInfo returns null for a direct-push commit', () => {
  assert.equal(parseMergeCommitInfo('fix typo directly on main'), null);
});

test('parseMergeCommitInfo returns null for empty/missing message', () => {
  assert.equal(parseMergeCommitInfo(''), null);
  assert.equal(parseMergeCommitInfo(undefined), null);
});

test('treesMatch requires equal, non-empty string SHAs', () => {
  assert.equal(treesMatch(TREE_SHA, TREE_SHA), true);
  assert.equal(treesMatch(TREE_SHA, 'x'.repeat(40)), false);
  assert.equal(treesMatch('', ''), false);
  assert.equal(treesMatch(null, TREE_SHA), false);
  assert.equal(treesMatch(TREE_SHA, undefined), false);
});

test('isForkPr is false for a same-repo PR head', () => {
  assert.equal(isForkPr(basePr(), EXPECTED_FULL_NAME), false);
});

test('isForkPr is true when head repo full_name differs (a fork)', () => {
  assert.equal(isForkPr(basePr({ head: { sha: PR_HEAD_SHA, repo: { full_name: 'someone-else/smile_enjoy_story' } } }), EXPECTED_FULL_NAME), true);
});

test('isForkPr is true when head repo is missing (e.g. fork deleted post-merge)', () => {
  assert.equal(isForkPr(basePr({ head: { sha: PR_HEAD_SHA, repo: null } }), EXPECTED_FULL_NAME), true);
});

test('pickLatestCheckRun picks the most recently completed run by name', () => {
  const runs = [
    { name: 'validate', status: 'completed', conclusion: 'failure', completed_at: '2026-01-01T00:00:00Z' },
    { name: 'validate', status: 'completed', conclusion: 'success', completed_at: '2026-01-01T01:00:00Z' },
    { name: 'smoke-e2e', status: 'completed', conclusion: 'success', completed_at: '2026-01-01T02:00:00Z' },
  ];
  const latest = pickLatestCheckRun(runs, 'validate');
  assert.equal(latest.conclusion, 'success');
  assert.equal(latest.completed_at, '2026-01-01T01:00:00Z');
});

test('pickLatestCheckRun returns null when no run matches the name', () => {
  assert.equal(pickLatestCheckRun([{ name: 'smoke-e2e', status: 'completed', conclusion: 'success' }], 'validate'), null);
  assert.equal(pickLatestCheckRun([], 'validate'), null);
  assert.equal(pickLatestCheckRun(undefined, 'validate'), null);
});

test('checkRunPassed requires status=completed AND conclusion=success', () => {
  assert.equal(checkRunPassed({ status: 'completed', conclusion: 'success' }), true);
  assert.equal(checkRunPassed({ status: 'completed', conclusion: 'failure' }), false);
  assert.equal(checkRunPassed({ status: 'in_progress', conclusion: null }), false);
  assert.equal(checkRunPassed(null), false);
});

// --- decide(): the full proof chain, one required scenario each -------

test('decide: kill switch OFF short-circuits before looking at anything else', () => {
  const result = decide({ killSwitchEnabled: false });
  assert.deepEqual(result, { skip: false, reason: 'kill-switch-off' });
});

test('decide: malformed/non-PR commit (e.g. squash merge) falls back', () => {
  const result = decide({
    killSwitchEnabled: true,
    mergeCommit: baseMergeCommit({ message: 'feat: some feature (#42)' }),
    pushSha: PUSH_SHA,
    expectedFullName: EXPECTED_FULL_NAME,
  });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'non-pr-commit');
});

test('decide: unusual merge (not exactly two parents) falls back', () => {
  const result = decide({
    killSwitchEnabled: true,
    mergeCommit: baseMergeCommit({ parents: [PREV_MAIN_SHA] }),
    pushSha: PUSH_SHA,
    expectedFullName: EXPECTED_FULL_NAME,
  });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'unusual-merge');
});

test('decide: ambiguous PR mapping (merge_commit_sha does not match this push) falls back', () => {
  const result = decide({
    killSwitchEnabled: true,
    mergeCommit: baseMergeCommit(),
    pushSha: PUSH_SHA,
    pr: basePr({ merge_commit_sha: 'z'.repeat(40) }),
    expectedFullName: EXPECTED_FULL_NAME,
  });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'ambiguous-pr-mapping');
});

test('decide: fork PR falls back', () => {
  const result = decide({
    killSwitchEnabled: true,
    mergeCommit: baseMergeCommit(),
    pushSha: PUSH_SHA,
    pr: basePr({ head: { sha: PR_HEAD_SHA, repo: { full_name: 'someone-else/smile_enjoy_story' } } }),
    expectedFullName: EXPECTED_FULL_NAME,
  });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'fork-pr');
});

test('decide: tree mismatch falls back (merge tree differs from PR HEAD tree)', () => {
  const result = decide({
    killSwitchEnabled: true,
    mergeCommit: baseMergeCommit({ treeSha: TREE_SHA }),
    pushSha: PUSH_SHA,
    pr: basePr(),
    prHeadCommit: basePrHeadCommit({ treeSha: 'different-tree-sha'.padEnd(40, '0') }),
    expectedFullName: EXPECTED_FULL_NAME,
  });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'tree-mismatch');
});

test('decide: missing check falls back (no validate check run at all)', () => {
  const result = decide({
    killSwitchEnabled: true,
    mergeCommit: baseMergeCommit(),
    pushSha: PUSH_SHA,
    pr: basePr(),
    prHeadCommit: basePrHeadCommit(),
    checkRuns: [{ name: 'smoke-e2e', status: 'completed', conclusion: 'success' }],
    expectedFullName: EXPECTED_FULL_NAME,
  });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'check-missing');
});

test('decide: failed check falls back (validate check run found but not success)', () => {
  const result = decide({
    killSwitchEnabled: true,
    mergeCommit: baseMergeCommit(),
    pushSha: PUSH_SHA,
    pr: basePr(),
    prHeadCommit: basePrHeadCommit(),
    checkRuns: passingCheckRuns({ conclusion: 'failure' }),
    expectedFullName: EXPECTED_FULL_NAME,
  });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'check-failed');
});

test('decide: verified success — the one and only path that allows skip:true', () => {
  const result = decide({
    killSwitchEnabled: true,
    mergeCommit: baseMergeCommit(),
    pushSha: PUSH_SHA,
    pr: basePr(),
    prHeadCommit: basePrHeadCommit(),
    checkRuns: passingCheckRuns(),
    expectedFullName: EXPECTED_FULL_NAME,
  });
  assert.deepEqual(result, { skip: true, reason: 'verified', prNumber: 42 });
});

// --- run(): wiring + API-failure handling ------------------------------

function makeFetch(routes) {
  return async (url) => {
    for (const [matcher, handler] of routes) {
      if (matcher.test(url)) return handler(url);
    }
    throw new Error(`unexpected URL in test fetch stub: ${url}`);
  };
}

function jsonResponse(body, { ok = true, status = 200, statusText = 'OK' } = {}) {
  return { ok, status, statusText, json: async () => body };
}

function fullHappyPathRoutes({ checkConclusion = 'success' } = {}) {
  return [
    [
      new RegExp(`/repos/${OWNER}/${REPO}/commits/${PUSH_SHA}$`),
      () =>
        jsonResponse({
          sha: PUSH_SHA,
          commit: { message: 'Merge pull request #42 from perusonao/some-feature-branch', tree: { sha: TREE_SHA } },
          parents: [{ sha: PREV_MAIN_SHA }, { sha: PR_HEAD_SHA }],
        }),
    ],
    [
      new RegExp(`/repos/${OWNER}/${REPO}/pulls/42$`),
      () =>
        jsonResponse({
          number: 42,
          merged: true,
          merge_commit_sha: PUSH_SHA,
          head: { sha: PR_HEAD_SHA, repo: { full_name: EXPECTED_FULL_NAME } },
          base: { repo: { full_name: EXPECTED_FULL_NAME } },
        }),
    ],
    [
      new RegExp(`/repos/${OWNER}/${REPO}/commits/${PR_HEAD_SHA}$`),
      () => jsonResponse({ sha: PR_HEAD_SHA, commit: { message: 'feat: some feature', tree: { sha: TREE_SHA } }, parents: [{ sha: PREV_MAIN_SHA }] }),
    ],
    [
      new RegExp(`/repos/${OWNER}/${REPO}/commits/${PR_HEAD_SHA}/check-runs`),
      () => jsonResponse({ check_runs: [{ name: 'validate', status: 'completed', conclusion: checkConclusion, completed_at: '2026-01-01T00:05:00Z' }] }),
    ],
  ];
}

function baseEnv(overrides = {}) {
  return {
    SES_CI_SKIP_MAIN_FLUTTER_TEST: 'true',
    GITHUB_REPOSITORY: EXPECTED_FULL_NAME,
    GITHUB_SHA: PUSH_SHA,
    GITHUB_TOKEN: 'fake-token',
    ...overrides,
  };
}

test('run: kill switch OFF never calls fetch at all', async () => {
  let called = false;
  const result = await run({ env: baseEnv({ SES_CI_SKIP_MAIN_FLUTTER_TEST: '' }), fetchFn: async () => { called = true; } });
  assert.deepEqual(result, { skip: false, reason: 'kill-switch-off' });
  assert.equal(called, false);
});

test('run: kill switch is case/whitespace tolerant only for the literal "true" value', async () => {
  const result = await run({ env: baseEnv({ SES_CI_SKIP_MAIN_FLUTTER_TEST: 'TRUE' }), fetchFn: makeFetch(fullHappyPathRoutes()) });
  assert.equal(result.skip, true);

  let called = false;
  const offResult = await run({ env: baseEnv({ SES_CI_SKIP_MAIN_FLUTTER_TEST: 'yes' }), fetchFn: async () => { called = true; } });
  assert.equal(offResult.reason, 'kill-switch-off');
  assert.equal(called, false);
});

test('run: verified success end-to-end through the real fetch wiring', async () => {
  const result = await run({ env: baseEnv(), fetchFn: makeFetch(fullHappyPathRoutes()) });
  assert.deepEqual(result, { skip: true, reason: 'verified', prNumber: 42 });
});

test('run: failed check end-to-end (validate check run exists but failed)', async () => {
  const result = await run({ env: baseEnv(), fetchFn: makeFetch(fullHappyPathRoutes({ checkConclusion: 'failure' })) });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'check-failed');
});

test('run: malformed/non-PR commit short-circuits before fetching the PR', async () => {
  let prFetched = false;
  const routes = [
    [
      new RegExp(`/repos/${OWNER}/${REPO}/commits/${PUSH_SHA}$`),
      () => jsonResponse({ sha: PUSH_SHA, commit: { message: 'chore: direct push to main', tree: { sha: TREE_SHA } }, parents: [{ sha: PREV_MAIN_SHA }] }),
    ],
    [/\/pulls\//, () => { prFetched = true; return jsonResponse({}); }],
  ];
  const result = await run({ env: baseEnv(), fetchFn: makeFetch(routes) });
  assert.equal(result.reason, 'non-pr-commit');
  assert.equal(prFetched, false);
});

test('run: fork PR short-circuits before fetching PR HEAD commit / check-runs', async () => {
  let prHeadFetched = false;
  const routes = [
    fullHappyPathRoutes()[0],
    [
      new RegExp(`/repos/${OWNER}/${REPO}/pulls/42$`),
      () =>
        jsonResponse({
          number: 42,
          merged: true,
          merge_commit_sha: PUSH_SHA,
          head: { sha: PR_HEAD_SHA, repo: { full_name: 'someone-else/smile_enjoy_story' } },
          base: { repo: { full_name: EXPECTED_FULL_NAME } },
        }),
    ],
    [new RegExp(`/repos/${OWNER}/${REPO}/commits/${PR_HEAD_SHA}`), () => { prHeadFetched = true; return jsonResponse({}); }],
  ];
  const result = await run({ env: baseEnv(), fetchFn: makeFetch(routes) });
  assert.equal(result.reason, 'fork-pr');
  assert.equal(prHeadFetched, false);
});

test('run: API failure (non-2xx response) resolves to a normal fallback, never throws', async () => {
  const result = await run({
    env: baseEnv(),
    fetchFn: async () => jsonResponse({}, { ok: false, status: 500, statusText: 'Internal Server Error' }),
  });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'api-failure');
  assert.match(result.error, /500/);
});

test('run: API failure (network error thrown by fetch) resolves to a normal fallback, never throws', async () => {
  const result = await run({
    env: baseEnv(),
    fetchFn: async () => { throw new Error('getaddrinfo ENOTFOUND api.github.com'); },
  });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'api-failure');
  assert.match(result.error, /ENOTFOUND/);
});

test('run: missing required environment (e.g. no token) is treated as api-failure, not a crash', async () => {
  const result = await run({ env: baseEnv({ GITHUB_TOKEN: '' }), fetchFn: async () => jsonResponse({}) });
  assert.equal(result.skip, false);
  assert.equal(result.reason, 'api-failure');
});
