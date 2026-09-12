# SES Issue #183 — CI Speed: Conditional Main-Push `flutter test` Skip — Implementation Result

## Status: staged, safe rollout — kill switch OFF by default

This lands the proof machinery and its wiring into Fast CI, but **does not
change CI behavior today**. `SES_CI_SKIP_MAIN_FLUTTER_TEST` (repository
variable) is unset in this repository, so every main push still runs
`flutter test` exactly as before. Per the task's own guidance, this is *not*
being reported as "fully rolled out" — only the fallback path has been
exercised in real CI so far (see § 実CI結果 below). Turning the kill switch
on, watching one real skip on a real main push, and confirming the fallback
path once more on a deliberately-adversarial push are the remaining steps
before calling this complete.

## BASE SHA

`f04ae434cfb7150dad587778f71100bc8fa3844d` — `origin/main` at task start.
This matched the audit's stated BASE exactly (no main-branch drift to
reconcile). The designated working branch (`claude/ci-speed-main-test-skip-ie6ghg`)
was found pointing at a stale, unrelated ancestor commit (`f4ca78f`,
"Phase 0A/0B: SES domain models and random generators") with no unmerged
work of its own, so it was reset (`git checkout -B ... origin/main`) onto
this BASE before implementation, per this task's own branch-recovery rule.

Note: the audit document named in the task
(`docs/reports/SES_ISSUE-183_CI-Speed_Fresh-Recheck.md`) does not exist
anywhere in this repository's history (checked `git log --all` and a full
working-tree search) — no `docs/` directory existed at all before this
change. The task's own KEEP/DO NOT/IMPLEMENT/TEST specification was
detailed enough to implement directly from; this report documents that gap
rather than fabricating audit content.

## Final HEAD

Implementation commit: `23cd1d3` (script + tests + workflow wiring).
This report is committed on top of it; see the PR for the true final HEAD
SHA after push (reported separately, per the task's closing checklist).

## Changed files

- `e2e/scripts/verify-pr-head-tested.mjs` (new) — the independent proof
  algorithm, pure-function-first and unit-testable without any network
  access.
- `e2e/scripts/verify-pr-head-tested.test.mjs` (new) — 29 unit tests
  covering every fallback category plus the one success path.
- `.github/workflows/e2e.yml` (modified) — adds one push-only verify step
  and splits the existing `flutter test` step into a conditional
  run/skip pair, inside the existing `flutter-validate` job. Adds
  job-level `checks: read` + `pull-requests: read` permissions (with
  `contents: read` repeated, since a job-level `permissions:` block
  replaces rather than merges with the workflow-level default).
- `docs/reports/SES_ISSUE-183_CI-Speed_Implementation_Result.md` (new,
  this file).

No other file was touched. `flutter analyze`, `flutter build web`,
`smoke-e2e`, `replay-unit`, `replay-package`, `check-latest`, `build`,
`deploy`, the stale-SHA guards, and every required check are byte-identical
to before. Nothing under Sales/Accounting/HOME/Employee UI, gameplay, or
production Flutter code was touched.

## Proof algorithm

Implemented in `decide()` (pure) + `run()` (I/O orchestration) in
`e2e/scripts/verify-pr-head-tested.mjs`. Runs only when triggered from the
`flutter-validate` job's `push`-only step. All checks below are required —
first failure wins and is reported as the `reason` output:

1. **Kill switch.** Repository variable `SES_CI_SKIP_MAIN_FLUTTER_TEST`
   must be the literal string `true` (case-insensitive, trimmed). Anything
   else (unset, `false`, `1`, `yes`, ...) → `kill-switch-off`, and no
   network call is made at all.
2. **Merge-commit shape.** The push commit's message must match GitHub's
   own merge-button subject line, `^Merge pull request #(\d+) from
   (\S+)$` — the same shape this repo's own `flutter build web` step
   already parses for PR-number tagging. No match (squash merge, rebase
   merge, direct push) → `non-pr-commit`.
3. **Parent count.** The commit must have exactly two parents (a real merge
   commit). Otherwise → `unusual-merge`.
4. **PR mapping.** `GET /pulls/{n}` (n from step 2) must confirm: `merged
   === true`, `merge_commit_sha` equals this push's SHA, and `head.sha`
   equals the merge commit's second parent. Any mismatch → closes the gap
   where the commit message merely *looks* right but doesn't actually
   correspond to this PR/commit → `ambiguous-pr-mapping`.
5. **Not a fork.** The PR's `head.repo.full_name` must equal this exact
   repository (and must exist — a fork deleted post-merge also fails
   closed). Otherwise → `fork-pr`.
6. **Tree identity.** The merge commit's tree SHA (`GET /commits/{sha}`,
   `commit.tree.sha`) must equal the PR HEAD commit's tree SHA. Git tree
   SHAs are content-addressed, so equality here is a direct, algorithmic
   proof that the merge produced a byte-identical source tree — including
   the workflow files themselves, since the tree covers the whole repo,
   not a diff — to what the PR HEAD actually was. A "real" 3-way merge
   (base had moved and needed reconciliation) will not have matching
   trees and correctly falls back here. Otherwise → `tree-mismatch`.
7. **PR HEAD was actually tested.** `GET
   /commits/{prHeadSha}/check-runs`, filtered to the check named
   `validate` (the `flutter-validate` job's own check-run name — unique
   across this repo's workflows; `e2e-heavy.yml`'s jobs are named
   differently). The most recently completed run of that name must be
   `status: completed`, `conclusion: success`. No such run → `check-missing`;
   found but not a clean success → `check-failed`.
8. **Any thrown error** anywhere above (network failure, non-2xx HTTP
   response, malformed JSON, missing required environment) is caught and
   resolved to `api-failure` — `run()` never throws.

Only when all eight hold does the script emit `skip=true`,
`reason=verified`, `pr_number=<n>`.

## Fail-safe list (every path that keeps `flutter test` running)

1. Kill switch unset or not exactly `true` → `kill-switch-off` (default
   state today).
2. Non-merge-commit push (direct push, squash, rebase) → `non-pr-commit`.
3. Merge commit without exactly two parents → `unusual-merge`.
4. PR metadata doesn't match the merge commit (wrong/ambiguous PR) →
   `ambiguous-pr-mapping`.
5. PR head is a fork (or the fork was deleted) → `fork-pr`.
6. Merge tree SHA ≠ PR HEAD tree SHA (real 3-way merge, base had moved) →
   `tree-mismatch`.
7. PR HEAD has no `validate` check run at all → `check-missing`.
8. PR HEAD's `validate` check run exists but isn't a clean success →
   `check-failed`.
9. Any GitHub API failure (network, non-2xx, malformed JSON, missing
   env/token) → `api-failure`. `run()` catches this internally and never
   throws.
10. Any unexpected crash reaching `main()` regardless → caught a second
    time, reported as `script-crash`, and the process still exits `0`.
11. Workflow-level second net: the verify step itself carries
    `continue-on-error: true`. If it fails outright (exits non-zero
    despite the two internal catches, e.g. `node` unavailable on the
    runner), `steps.verify_pr_head_tested.outcome` becomes `failure`, and
    both downstream `if:` conditions treat that identically to
    `skip=false` — `flutter test` still runs.
12. PR runs are entirely unaffected — the verify step's `if:` is
    `github.event_name == 'push'` only; pull_request and workflow_dispatch
    runs are byte-identical to before this change.

Any one of the above is sufficient on its own to guarantee normal
`flutter test` execution; none of them is bypassable by the others.

## Kill switch

- Name: **`SES_CI_SKIP_MAIN_FLUTTER_TEST`** (GitHub Actions *repository
  variable*, read via `${{ vars.SES_CI_SKIP_MAIN_FLUTTER_TEST }}`, not a
  secret — it carries no sensitive value).
- Accepted "on" value: the literal string `true` (case-insensitive,
  whitespace-trimmed). Any other value, including unset, is "off."
- **Current state in this repository: unset (OFF).** This PR does not
  create or set the variable — enabling it is a deliberate, separate,
  reversible action for whoever administers repository settings, after
  reviewing this PR's own CI run.
- Turning it off at any time (or simply never turning it on) is a complete,
  immediate rollback of this feature's *effect* with zero code changes —
  see § Rollback.

## Tests

`node --test scripts/*.test.mjs replay-viewer/lib/*.test.mjs`
(`npm run test:replay-unit`, unchanged command — the new test file is
picked up automatically by the existing glob):

- **Full suite: 141 passed, 0 failed** (112 pre-existing + 29 new).
- New file `verify-pr-head-tested.test.mjs` (29 tests) covers, per the
  task's required list, each as its own isolated test with fabricated
  (non-network) data:
  - **verified success** — `decide()` and an end-to-end `run()` wiring
    test, both asserting `skip: true, reason: 'verified'`.
  - **tree mismatch** — matching PR/check-run data but a differing tree
    SHA.
  - **missing check** — check-runs list present but with no `validate`
    entry.
  - **failed check** — a `validate` run present with `conclusion:
    'failure'`, both at the `decide()` level and through the full `run()`
    fetch wiring.
  - **API failure** — both a non-2xx HTTP response and a thrown network
    error, each asserted to resolve to `reason: 'api-failure'` rather than
    rejecting/throwing.
  - **malformed/non-PR commit** — a squash-merge-shaped subject line,
    plus a `run()` test proving the PR is never even fetched in this case.
  - **fork PR** — head repo `full_name` differs from the target repo, plus
    a `run()` test proving PR-HEAD-commit/check-runs are never fetched
    once a fork is detected.
  - **kill switch OFF** — asserted to short-circuit before any `fetchFn`
    call at all (a spy proves zero calls), and a case-sensitivity/typo
    test (`'yes'`, `'TRUE'`) confirming only the exact string `true`
    enables it.
  - Additional coverage beyond the required list: `unusual-merge` (wrong
    parent count) and `ambiguous-pr-mapping` (PR metadata not matching the
    commit), plus focused unit tests for every pure helper
    (`parseMergeCommitInfo`, `treesMatch`, `isForkPr`,
    `pickLatestCheckRun`, `checkRunPassed`).
- `git diff --check`: clean, no whitespace errors.
- Workflow syntax: `.github/workflows/e2e.yml` parses successfully under
  `yaml.safe_load` (Python), including the new/modified `flutter-validate`
  job block; `actionlint` was not available in this environment to run
  additionally.

## 実CI結果 (real CI results)

**Not yet confirmed as of this report.** No real Actions run has executed
this code yet — it ships in the PR this report accompanies. Concretely:

- The **fallback path** will be exercised automatically on every run of
  this very PR (kill switch is OFF by default, so the verify step reports
  `kill-switch-off` and `flutter test` runs normally) — this is the CI run
  attached to the PR named in this task's final report.
- The **skip-success path** cannot be exercised until (a) this PR merges
  to main by a plain two-parent merge, (b) the repository variable is
  turned on, and (c) a subsequent main push re-runs this same commit's
  proof chain against a merge that satisfies all eight conditions above.
  That is deliberately a separate, later, human-gated step — this PR does
  not flip the switch itself.

Per the task's own instruction, this is explicitly **not** being reported
as "完全導入済み" (fully rolled out) — only the fallback path is provable
before merge. Recommended staged rollout after this PR merges:
1. Confirm the merged commit's own `flutter-validate` run reports
   `kill-switch-off` (expected, switch still off).
2. Set `SES_CI_SKIP_MAIN_FLUTTER_TEST=true` as a repository variable.
3. Land one more ordinary PR/merge and confirm its main-push run reports
   `reason=verified`, `skip=true`, and the "flutter test — skipped" step's
   `::notice::` names the correct PR number.
4. Separately, confirm a deliberately non-matching case (e.g. any
   workflow_dispatch push, or the next push whose PR happens to have been
   squash-merged, if any) still correctly falls back.
5. Only after both a real skip and a real fallback have been observed
   should this be considered fully validated.

## Expected time saving

`flutter test` currently runs once inside `flutter-validate` on every
`push` to `main`, in addition to already having run on the merged PR's own
`validate` check. Based on this workflow's own `timeout-minutes: 15` budget
for the whole `flutter-validate` job (analyze + test + build combined) and
this project's existing test suite size, `flutter test` is a meaningful
fraction of that job's wall time — skipping it on main pushes (while
keeping `flutter analyze` and `flutter build web`, both still required to
produce the deploy artifact and to catch static errors) removes one full
redundant Flutter VM test-runner invocation per ordinary merge, on the
critical path that gates `smoke-e2e` → `build` → `deploy`. This repo has no
committed historical CI-duration metrics to cite a precise number from, so
this report does not assert a specific minute figure — the real saving
should be read directly off the first real skip run's job duration
compared to the immediately preceding non-skip run for the same commit
shape (recommended as part of step 3 in the rollout above).

## Rollback

Three independent, none requiring a revert:

1. **Instant, config-only:** unset (or set to anything other than `true`)
   the `SES_CI_SKIP_MAIN_FLUTTER_TEST` repository variable. Every
   subsequent push immediately resumes running `flutter test` on every
   main push — no code change, no redeploy, effective on the very next
   push.
2. **Code-level, reversible commit:** revert this PR's commit(s) entirely;
   `flutter-validate` returns to its exact prior form (a single
   unconditional `flutter test` step, default job-level permissions).
3. **Mid-severity:** leave the script and permissions in place but remove
   only the two conditional steps in `e2e.yml`, restoring the single
   unconditional `flutter test` step, if the verify step's presence itself
   (e.g. its extra API calls) is ever undesirable independent of the kill
   switch.

## Merge readiness

- Full existing + new unit test suite passes (141/141).
- `git diff --check` clean; YAML parses.
- No required check, gameplay code, production Flutter code, or
  Sales/Accounting/HOME/Employee UI file touched.
- Kill switch defaults OFF — this PR is behavior-neutral for CI until a
  human explicitly turns it on.
- **Not yet merge-blocking-verified in real CI** (see § 実CI結果) — this
  PR's own CI run is the first real confirmation of the fallback path;
  reviewers should wait for that run to go green before merging, per this
  task's own "AUTO-MERGE禁止" instruction (no auto-merge was configured or
  requested).
