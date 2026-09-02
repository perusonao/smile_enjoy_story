# SES-CI-SPEED-1 — CI Speed Optimization (Fast CI / Heavy E2E split) — Implementation Result

## Objective

First Fun Year の開発速度を優先し、通常の main/PR デプロイが WebKit 全件や年間
E2E の完了待ちで数十分止まらないようにする。品質検証そのものは削除せず、
「毎回必要な高速CI」と「重い回帰E2E」をワークフロー単位で分離した。

Finance / Domain / Persistence / save schema / balance / gameplay 仕様には
一切触れていない。変更対象は CI/E2E ワークフロー構成のみ。

## Changed files

| File | Change |
|---|---|
| `.github/workflows/e2e.yml` | Rewritten as **Fast CI**. `validate` job unchanged. `e2e-chromium`/`e2e-webkit` jobs replaced by a single `smoke-e2e` job (mobile-chromium only, curated spec list). `replay-package`/`check-latest`/`build`/`deploy` updated to depend on `smoke-e2e` instead of `[e2e-chromium, e2e-webkit]`. No Flutter/game logic touched. |
| `.github/workflows/e2e-heavy.yml` | **New.** Runs the full Playwright suite (all specs, incl. WebKit全件・年間 April→March baseline・Recovery全パターン・複数viewport) on both `mobile-chromium` and `mobile-webkit`. Triggers: `workflow_dispatch` (optional seed override) + weekly `schedule` (Mon 03:00 JST). Never touches Pages/build/deploy — fully decoupled from the deploy pipeline. |
| `e2e/README.md` | "## CI" section rewritten to describe the two-workflow split (was describing the old single combined workflow, now stale). |
| `docs/ai-knowledge/decisions/SES-CI-001-browser-runner-isolation.md` | Updated "Related files"/"Regression protection" to reference the new job/file names (`smoke-e2e` in `e2e.yml`; `e2e-heavy-chromium`/`e2e-heavy-webkit` in `e2e-heavy.yml`) — the per-browser job isolation the decision documents is preserved across both files. |

No test files, Dart/Flutter source, or Playwright config (`playwright.config.ts`) were modified. No test was skipped, marked `fixme`, had its retries/timeouts changed, or had an assertion weakened.

## Old CI flow (single workflow, `e2e.yml`)

```
pull_request/push/workflow_dispatch
  └─ validate (flutter analyze/test/build, npm ci, replay unit tests)
       ├─ e2e-chromium  (ALL specs incl. annual route/Recovery/multi-viewport, 3-seed founding sample)
       └─ e2e-webkit    (ALL specs, same set, continue-on-error: true for known WebKit flake)
             └─ replay-package (push only, merges both browsers' results)
             └─ check-latest → build → deploy   (waited on BOTH e2e-chromium AND e2e-webkit to finish)
```

Every normal PR/main push paid for the full ~19-spec suite on **both**
browser engines — including the annual April→March baseline, the full
Recovery-Loop pattern set, and multi-viewport checks — before `deploy` could
even be considered. WebKit's own known infra flake didn't fail the run
(`continue-on-error`), but the job still had to *finish or time out* (up to
its 30-minute budget) before `check-latest`/`build` were unblocked.

## New CI flow (two independent workflows)

```
Fast CI (.github/workflows/e2e.yml) — every PR/push/dispatch
  └─ validate (unchanged: flutter analyze/test/build, npm ci, replay unit tests)
       └─ smoke-e2e (mobile-chromium ONLY — 9 curated spec files, 52 tests)
             ├─ founding-first-assignment.spec.ts   (app launch + core short progression, 3-seed sample)
             ├─ public-demo-fresh-start.spec.ts     (Public Demo entry + basic HOME display)
             └─ artifacts.*/game-state.ariaParsing/seeds/ses-player.*/portable-wheel-fallback
                (harness's own browser-free/fixture regression guards — negligible runtime)
             └─ replay-package (push only, chromium-only input now)
             └─ check-latest → build → deploy   (wait ONLY on smoke-e2e + validate)

Heavy E2E (.github/workflows/e2e-heavy.yml) — workflow_dispatch + weekly schedule ONLY
  └─ build-web (own flutter analyze/test/build — independent run, not shared with Fast CI)
       ├─ e2e-heavy-chromium (full suite, ALL ~19 spec files)
       └─ e2e-heavy-webkit   (full suite, ALL ~19 spec files, continue-on-error: true — same known-flake carve-out as before)
  (no build/deploy jobs at all — fully decoupled)
```

## What blocks a normal main deploy now (unchanged in kind, narrower in scope)

- `validate` failing (flutter analyze/test/build, replay unit tests) — **blocks**.
- `smoke-e2e` failing — a real core-flow failure in app launch, Public Demo
  entry/HOME, or the Founding→First Assignment progression — **blocks**.
- The stale-SHA guard (`check-latest`/`deploy`'s re-check) — **blocks** (unchanged from before).

## What moved to non-blocking (Heavy E2E, separate workflow)

- WebKit — **all** specs, not just the previous `e2e-webkit` job's scope.
- `public-demo-annual-route.spec.ts` (April→March annual baseline).
- `public-demo-recovery.spec.ts` (Recovery Loop, all patterns).
- `public-demo-single-month-cta.spec.ts` (360px/390px multi-viewport) and
  `public-demo-recovery.spec.ts`'s own multi-viewport cases.
- Every other gameplay-flow spec not in the smoke list: `beginner-mode-april-june`,
  `beginner-mode-waiting-and-recruitment`, `failure-recovery`,
  `game-feel-presentation`, `phase-3b1-fit-reason`, `public-demo-july-restart`,
  `public-demo-month-guard`, `text-quality`.
- The full 10-seed `founding-first-assignment.spec.ts` validation batch (Fast
  CI still runs its existing 3-seed default sample; the 10-seed batch is now
  reached via Heavy E2E's `workflow_dispatch` seed input, same as before).

None of this was deleted, skipped, or weakened — it still runs, just on its
own schedule/dispatch instead of gating every push.

## Test results

- **YAML syntax**: both workflow files parsed successfully with `yaml.safe_load` (Python `PyYAML`). No `actionlint` binary was available in this sandbox to run a full GitHub Actions schema/expression lint; the YAML itself is otherwise a structural edit of an already-valid file plus a new file following the same job/step shapes.
- **Flutter analyze/test/build**: **not runnable in this sandbox** — no Flutter SDK is installed here and none could be installed (no cached SDK on disk, and downloading one was out of scope for a CI-file-only change). This is a known gap — see "Known issues" below.
- **Replay Viewer unit tests** (`npm run test:replay-unit`, unaffected by this change but re-run as a sanity check): **112/112 passed**.
- **Smoke E2E — spec-file list validity**: `npx playwright test --project=mobile-chromium --list <the 9 smoke files>` resolved cleanly to **52 tests across 9 files**, confirming the new `smoke-e2e` job's exact command (as written in `e2e.yml`) is syntactically valid and picks up the intended tests, including `founding-first-assignment.spec.ts`'s existing 3-seed default (100001–100003, unchanged).
- **Smoke E2E — actual execution**: of those 9 files, the 7 that don't require the built Flutter web app (`artifacts.allowlist`, `artifacts.watchForErrors`, `game-state.ariaParsing`, `seeds`, `ses-player.completionCapOrdering`, `ses-player.deadEndStability`, `portable-wheel-fallback`) were run for real against a pre-installed Chromium binary (`/opt/pw-browsers`, via the config's existing `SES_E2E_CHROMIUM_PATH` escape hatch) — **48/48 passed** in 15.4s. `founding-first-assignment.spec.ts` and `public-demo-fresh-start.spec.ts` need the actual built Flutter web app under `build/web`, which this sandbox cannot produce (no Flutter SDK) — these two are unchanged from the pre-existing, already-passing `e2e-chromium` job, so their content/logic carries no new risk from this change; only their *invocation* (which job runs them, and with which sibling files) changed.

## Known issues / follow-ups

1. **Flutter analyze/test/build could not be executed in this sandbox** (no Flutter SDK available). The `validate` and `build-web`/heavy `build-web` job bodies are unchanged copy-paste of the previously-working `validate`/`build` steps from the original `e2e.yml`, so risk is low, but this should be confirmed once this branch runs in real GitHub Actions.
2. **Branch protection / required status checks**: if the repository's branch protection rules require a status check literally named `e2e-chromium` and/or `e2e-webkit`, those checks will no longer appear on PRs (renamed to `validate` + `smoke-e2e`, both already existed as check names before). A repo admin should update the required-checks list in GitHub branch protection settings to `validate` and `smoke-e2e` if it currently pins the old names.
3. `public-demo-fresh-start.spec.ts` and `founding-first-assignment.spec.ts` could not be run end-to-end against a real Flutter build in this sandbox (see above) — recommend confirming a green `smoke-e2e` run on the actual PR before merge.
4. Heavy E2E's weekly schedule (Mon 03:00 JST) is a starting default; adjust the cron in `e2e-heavy.yml` if a different cadence is preferred.

## Estimated critical-path impact (structural, not a measured GitHub Actions benchmark)

This sandbox has no access to this repository's historical Actions run logs, so the numbers below are structural estimates from the spec files' own size/scope, not measured wall-clock times.

- **Before**: `validate` → wait for **both** `e2e-chromium` and `e2e-webkit`, each running the full ~19-spec suite (including the annual/Recovery/multi-viewport specs) before `check-latest`/`build`/`deploy` could proceed. Each browser job carried a 30-minute timeout; a normal run plus WebKit's documented flake risk routinely pushed the practical critical path into the "tens of minutes" range the task description names.
- **After**: `validate` → wait for **one** `smoke-e2e` job covering 9 files/52 tests, dominated by 3 short founding playthroughs and one fresh-start check (the harness-unit specs measured at 15s total above). The remaining ~10 heavy spec files and the WebKit engine entirely leave the deploy-blocking path. Expected result: the blocking portion of CI drops from a multi-ten-minute WebKit/full-suite wait to a small-minutes smoke run, with `validate`'s own `flutter analyze/test/build` remaining the dominant blocking cost (unchanged by this work).

## Commit SHA

`a5c927c44a3ba3c699c97333c0fdd650c0ef557a` — pushed to
`claude/ses-ci-speed-optimization-6w4hl0`.

## PR readiness

- Base branch: restarted from the current `main` tip (this branch previously carried only an already-merged commit, so it was reset onto `origin/main` per the session's branch-restart rule rather than stacking on stale history).
- Change is scoped entirely to `.github/workflows/*.yml`, `e2e/README.md`, and one `docs/ai-knowledge/decisions/*.md` file — no gameplay/domain/persistence code touched.
- Not merged to `main`; pushed to `claude/ses-ci-speed-optimization-6w4hl0` for review. A PR can be opened from this branch once a maintainer confirms a green `smoke-e2e` run against the real Flutter build in GitHub Actions (this sandbox could not build/run Flutter itself — see "Known issues" #1 and #3).
