# SES_CI-SPEED-3_Parallel-Gate_Result

## STATUS

Implemented — awaiting CI review.

## BASE / HEAD

- Base: `81ae23ae999d41ae78ad1285b6ce955ca0bcba49` (main when the branch was created)
- Implementation commits: `fcf79a58bcf404c9c13ac39cb6d21e0650db417f`, `27a08c3291f8efe060c40a8426be6eee0dfc0712`

## What changed

- Split the former sequential Fast CI `validate` job into independent required jobs:
  - `flutter-validate`: unchanged Flutter analyze, full Flutter test, and Pages-compatible Web build/artifact.
  - `replay-unit`: unchanged lockfile-based Replay Viewer unit test.
  - `smoke-e2e`: waits for both gates, then runs the existing Chromium smoke suite unchanged.
- Added `actions/setup-node` npm cache and cache-first locked installs (`npm ci --prefer-offline --no-audit --fund=false`) to Node-consuming Fast CI jobs.
- Preserved the existing same-workflow Pages SHA checks, least-privilege permissions, single-browser runner isolation, heavy-E2E separation, and all blocking semantics.
- Recorded the durable delivery-gate policy in the governing decision.

## Changed files

- `.github/workflows/e2e.yml`
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`
- `docs/reports/SES_CI-SPEED-3_Parallel-Gate_Result.md`

## Verification

- Workflow YAML reviewed for job dependencies and artifact flow.
- CI pending: this workflow-only change must be verified by its own Fast CI run.
- No application/game code or test selection was changed.

## Known issues

- The prior PR #161 Fast CI cancellations occurred during external `npm ci` dependency retrieval after Flutter validation completed. This change removes that serial budget collision and makes dependency retrieval cache-first; it does not mask a genuine npm/test failure.

## Merge readiness

Await Fast CI, Public Demo Validation, and Public Demo Preview. Do not merge until all required checks pass and review finds no regression.
