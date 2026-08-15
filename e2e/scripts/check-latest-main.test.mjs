// Unit tests for check-latest-main.mjs (Codex Major 1 — Pages rollback
// race). Requirement: A != current main -> deploy forbidden, B == current
// main -> deploy possible. git itself is faked via an injected spawnSyncFn
// — no network/real git calls.
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseLsRemoteHead, isLatestCommit, resolveCurrentMainSha } from './check-latest-main.mjs';

const SHA_A = 'a'.repeat(40);
const SHA_B = 'b'.repeat(40);

test('parseLsRemoteHead extracts the SHA from a normal ls-remote line', () => {
  assert.equal(parseLsRemoteHead(`${SHA_B}\trefs/heads/main\n`), SHA_B);
});

test('parseLsRemoteHead is case-insensitive and normalizes to lowercase', () => {
  assert.equal(parseLsRemoteHead(`${SHA_B.toUpperCase()}\trefs/heads/main\n`), SHA_B);
});

test('parseLsRemoteHead returns null for empty/unparseable output (branch not found, garbage)', () => {
  assert.equal(parseLsRemoteHead(''), null);
  assert.equal(parseLsRemoteHead('\n\n'), null);
  assert.equal(parseLsRemoteHead('not-a-sha\trefs/heads/main\n'), null);
});

test('isLatestCommit: A != current main -> deploy forbidden', () => {
  assert.equal(isLatestCommit(SHA_A, SHA_B), false);
});

test('isLatestCommit: B == current main -> deploy possible', () => {
  assert.equal(isLatestCommit(SHA_B, SHA_B), true);
});

test('isLatestCommit is case-insensitive (git SHAs are case-insensitive in practice)', () => {
  assert.equal(isLatestCommit(SHA_B.toUpperCase(), SHA_B), true);
});

test('isLatestCommit rejects non-string inputs rather than throwing', () => {
  assert.equal(isLatestCommit(null, SHA_B), false);
  assert.equal(isLatestCommit(undefined, undefined), false);
});

test('resolveCurrentMainSha parses a successful git ls-remote', () => {
  const sha = resolveCurrentMainSha('https://example.invalid/repo.git', 'main', {
    spawnSyncFn: () => ({ status: 0, stdout: `${SHA_B}\trefs/heads/main\n`, stderr: '' }),
  });
  assert.equal(sha, SHA_B);
});

test('resolveCurrentMainSha throws (does not silently return a fake value) when git exits non-zero', () => {
  assert.throws(
    () => resolveCurrentMainSha('https://example.invalid/repo.git', 'main', { spawnSyncFn: () => ({ status: 128, stdout: '', stderr: 'fatal: repository not found' }) }),
    /git ls-remote failed/,
  );
});

test('resolveCurrentMainSha throws when git itself cannot be launched', () => {
  assert.throws(
    () => resolveCurrentMainSha('https://example.invalid/repo.git', 'main', { spawnSyncFn: () => ({ error: new Error('ENOENT') }) }),
    /could not be launched/,
  );
});

test('resolveCurrentMainSha throws on unparseable output rather than returning null/undefined silently', () => {
  assert.throws(
    () => resolveCurrentMainSha('https://example.invalid/repo.git', 'main', { spawnSyncFn: () => ({ status: 0, stdout: '', stderr: '' }) }),
    /could not parse/,
  );
});

// --- end-to-end scenario matching the exact Codex requirement --------------

test('scenario: an older run (A) for a commit that is no longer main tip must never be reported as deployable', () => {
  const currentSha = resolveCurrentMainSha('https://example.invalid/repo.git', 'main', {
    spawnSyncFn: () => ({ status: 0, stdout: `${SHA_B}\trefs/heads/main\n`, stderr: '' }),
  });
  assert.equal(isLatestCommit(SHA_A, currentSha), false, 'stale commit A must be refused');
});

test('scenario: the run for the actual current main tip (B) is deployable', () => {
  const currentSha = resolveCurrentMainSha('https://example.invalid/repo.git', 'main', {
    spawnSyncFn: () => ({ status: 0, stdout: `${SHA_B}\trefs/heads/main\n`, stderr: '' }),
  });
  assert.equal(isLatestCommit(SHA_B, currentSha), true, 'current commit B must be allowed');
});
