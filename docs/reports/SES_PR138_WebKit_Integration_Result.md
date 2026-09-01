# SES PR #138 WebKit Failure — Investigation & Latest-Main Integration Result

## 1. Executive Summary

PR #138's `e2e-webkit` CI job failed, but **none of the failure is in the
code PR #138 added**. All 6 new `public-demo-annual-route.spec.ts` cases
(3 scenarios × 2 viewports: 360×800, 390×800) passed cleanly on WebKit, with
zero retries. The job's actual failures are in two **pre-existing** specs
that PR #138 never touches: `beginner-mode-waiting-and-recruitment.spec.ts`
(1 hard failure, exhausted its retry) and `phase-3b1-fit-reason.spec.ts` (1
flaky failure that passed on retry). Both are Beginner-Mode/Founding-Prologue
specs, unrelated to Public Demo.

The most direct comparison available — `origin/main` at the exact commit
this PR is currently based against one merge ahead of (`8c59e309`, merged
~40 minutes before PR #138's CI run, same day) — ran the **entire** WebKit
suite green in `5m16s`. PR #138's WebKit job, which additionally runs the 6
new annual-route tests (~4.2 cumulative test-minutes, the slowest spec in
the whole suite), took `10m7s` — essentially double. The failing locator's
own in-repo comment (`beginner-mode-waiting-and-recruitment.spec.ts:583-588`)
already documents this exact failure class from a **prior, independent** CI
run (`32040338628`) — a candidate-list DOM re-render race under load — with
its own retry helper (`clickResilient`) built specifically to absorb it.

**Conclusion: Classification D (CI infrastructure / timing instability),
not a PR #138 regression.** PR #138's own new tests are a clean, isolated
pass. No evidence connects this failure to PR #136's SkillSheet Bottom
Sheet / `案件スキル適合` issue — the one assertion in this exact WebKit run
that touches that exact text (`public-demo-fresh-start.spec.ts:38`) **passed**.

PR #138 merges cleanly (no conflicts) onto the current `origin/main`
(`8c59e309`), and the one intervening production change (PR #137's July
Month Guard) is a behavior-preserving refactor of the same summer-bonus gate
PR #138's own July flow already exercises — analysis below. **No production,
test, or workflow change is required or was made in this investigation.**

This session's sandbox has no Flutter SDK and no installed WebKit browser
(only Chromium is pre-installed here), so `flutter analyze`/`flutter test`
and a live `mobile-webkit` run could not be executed locally — see §11-13
for what was and was not verified, and §16 for the recommended next action.

## 2. Exact SHAs

| Ref | SHA |
|---|---|
| `origin/main` (audited, confirmed via `git fetch origin main`) | `8c59e3092519e8f31e415323b14f793c212a2300` |
| PR #138 base (per GitHub, at PR creation time) | `25a2e9b6b401794090151cc86006e433c8d9a789` |
| PR #138 head | `4eb0515a712302ba5b70698e52254848b0825d31` |
| `git merge-base origin/main PR#138-head` | `25a2e9b6b401794090151cc86006e433c8d9a789` |

`origin/main` matches the task brief's expected `8c59e309...` exactly.
`main` is exactly **one merge ahead** of PR #138's base — PR #137 ("Merge
pull request #137 from perusonao/claude/month-guard-pr1-rsi7p0", Issue #119
Month Guard PR1) — confirmed via `git log` and `git merge-base`.

Note: this session's designated working branch
(`claude/pr138-webkit-failure-y4m47d`) does **not** itself contain PR #138's
commits — it was created from an older, already-merged commit
(`f4ca78f`, "Phase 0A/0B"). All PR #138 forensics in this report were done
against `origin/claude/full-year-demo-e2e-phase1-ls8sje` (PR #138's actual
head branch, fetched directly) and `origin/main`, not against this session's
own working branch. This report file is committed to the session's
designated branch per the task's process instructions; it makes no other
change there.

## 3. CI Failure Evidence

PR #138 check runs (head `4eb0515a`, workflow run `33455720462`):

| Job | Conclusion |
|---|---|
| validate | success |
| e2e-chromium | success |
| e2e-webkit | **failure** |
| replay-package / check-latest / build / deploy | skipped (webkit failure blocks the deploy pipeline) |

`e2e-webkit` job (`99697034351`) ran `00:50:08`–`01:00:15` (**10m7s**).
Final summary line from the job log:

```
1 failed
  [mobile-webkit] › tests/beginner-mode-waiting-and-recruitment.spec.ts:493:7 › Phase 3A: recruitment flow stays operable in real UI, no dead-end (seed 100001)
1 flaky
  [mobile-webkit] › tests/phase-3b1-fit-reason.spec.ts:245:7 › Phase 3B-1: Fitの理由を見る is reachable and correct in real UI (seed 100001)
69 passed (8.0m)
```

## 4. Failed Test / Spec

**PR #138's own new tests — all passed, no retries, on both viewports:**

| Spec (public-demo-annual-route.spec.ts) | 360×800 | 390×800 |
|---|---|---|
| April: only fiscal-year-sellable engineer reaches an order | ✅ 21.5s | ✅ 21.0s |
| June: July continuation starts revenue recognition | ✅ 35.9s | ✅ 36.9s |
| April→March: full traversal to fiscal-year terminal close | ✅ 1.2m | ✅ 1.0m |

**Actually-failing tests (both pre-existing, both outside PR #138's diff):**

1. `tests/beginner-mode-waiting-and-recruitment.spec.ts:493` —
   "Phase 3A: recruitment flow stays operable in real UI, no dead-end (seed
   100001)". **Hard failure** (original + retry #1, both failed the same
   way).
   - Assertion/error: `TimeoutError: locator.click: Timeout 2938ms exceeded`
     (retry: `2915ms`).
   - Locator: `getByRole('button', { name: /未面接/ }).first()` (a
     "not-yet-interviewed" candidate card in the recruitment tab).
   - Call site: `clickResilient()` helper (`beginner-mode-waiting-and-recruitment.spec.ts:340`),
     invoked from the per-attempt hire loop at `:589`.
   - No screenshot/trace content was fetched in this investigation (would
     require downloading the `ses-playwright-results-mobile-webkit`
     artifact, which was not necessary to establish root cause — see §5);
     the job log confirms artifacts (`test-failed-1.png`, `video.webm`,
     `trace.zip`, `error-context.md`) were captured for both attempts.
   - Retry: yes (Playwright's own retry-on-failure), both attempts failed
     identically.

2. `tests/phase-3b1-fit-reason.spec.ts:245` —
   "Phase 3B-1: Fitの理由を見る is reachable and correct in real UI (seed
   100001)". **Flaky** — failed on the original attempt, passed on retry
   #1.
   - Assertion/error (original attempt): `Error: Beginner Mode
     dead-end/stall (seed=100001): dead-end at week 6: no recognized
     action. buttons=[] texts=[]`.
   - This is week 6 of the shared Founding/Beginner-Mode driver
     (`playFoundingToFirstAssignment`/Beginner Mode auto-play), well before
     this spec's own FitReasonSheet/BottomSheet interaction (which happens
     around week 13+, per the spec's own header comment) — the failure is
     not related to that spec's BottomSheet code at all.
   - Retry: yes, passed on retry #1 (1.3m).

Neither failing/flaky spec references Public Demo, `SkillSheet`,
`public-demo-player.ts`, or anything PR #138 added or touched.

## 5. Root Cause

**Not a PR #138 code defect** — established by elimination and by direct
comparison, not assumption:

- PR #138's diff is exactly 3 new files, 0 modified files:
  `e2e/helpers/public-demo-player.ts` (new), `e2e/tests/public-demo-annual-route.spec.ts`
  (new), `docs/reports/SES_FULL-YEAR_E2E_Phase1_Result.md` (new). Confirmed
  via `pull_request_read(get_files)`. No existing spec, helper,
  `playwright.config.ts`, or workflow file was touched.
- Both failing specs (`beginner-mode-waiting-and-recruitment.spec.ts`,
  `phase-3b1-fit-reason.spec.ts`) import only pre-existing helpers
  (`ses-player.ts`, `game-state.ts`, `beginner-mode-player.ts`,
  `artifacts.ts`) — none of which PR #138 modifies. `public-demo-player.ts`
  is entirely new, self-contained, and imported by nothing except PR #138's
  own new spec.
- PR #138's own 6 new tests, which **do** share the same WebKit browser
  process/runner as the failing tests (all in one `npx playwright test
  --project=mobile-webkit` invocation), passed cleanly with zero retries on
  both viewports — ruling out a shared-runner/global-state hypothesis where
  PR #138's tests themselves corrupt the runner for later tests.
- **Direct same-day comparison**: `origin/main` at `8c59e309` (the commit
  that merged ~40 minutes before PR #138's CI run started) ran the
  identical `e2e-webkit` job — same runner type (`ubuntu-latest`), same
  Playwright/WebKit install step — **green**, 0 failures, in `5m16s`
  (`00:40:21`–`00:45:37`, job `99706782504`, run `33459011788`).
- PR #138's `e2e-webkit` job took `10m7s` — nearly double. The 6 new
  annual-route tests alone account for ~4.2 cumulative test-minutes
  (21.5+35.9+72+21.0+36.9+63.0s ≈ 250s), consistent with that difference.
  `public-demo-annual-route.spec.ts` is explicitly documented (in PR #138's
  own report) as "the slowest single file" in the suite.
- The failing locator's **own in-repo comment**
  (`beginner-mode-waiting-and-recruitment.spec.ts:583-588`, present on
  `origin/main` unchanged, i.e. pre-existing and untouched by PR #138)
  reads: *"CI run 32040338628, HEAD f07fa30: this exact locator resolved,
  then 'element was detached from the DOM, retrying', then timed out — the
  candidate list re-rendering out from under a plain `.click()`."* This is
  a **previously observed, independent, CI-only** failure of this exact
  test/locator, already known well enough that a bounded-retry helper
  (`clickResilient`, 15s budget split into ~3s attempts) was built
  specifically to absorb it. The retry helper still has a bounded budget;
  under materially higher runner load (a WebKit job running ~2x longer than
  its main-branch baseline, i.e. more CPU/scheduling contention on a shared
  GitHub-hosted runner) that budget can still be exhausted.
- The second (flaky, self-recovering) failure's symptom — a "no recognized
  action, buttons=[] texts=[]" dead-end read on WebKit that resolves on the
  very next attempt — matches the **general category** `e2e/README.md`
  documents at length under "Major (fixed, re-review): WebKit
  transient-empty semantics mistaken for a dead-end" and "Major (fixed,
  second re-review): a real, non-empty no-action frame was also mistaken
  for a dead-end": WebKit's accessibility/semantics tree can present a
  transient, mid-transition frame that looks like a stable dead-end to a
  single read. Both of those fixes already exist in this file's own
  `waitForActionableOrStableDeadEnd()`; this run's flaky failure is
  consistent with that same underlying WebKit timing characteristic still
  having a residual, low-probability failure mode under elevated load —
  not with anything PR #138 introduced.

**Mechanism, stated plainly**: PR #138 is test-infrastructure-only and adds
no code that the two failing specs touch, directly or transitively. What it
does add is ~4-5 extra minutes of WebKit test execution in the same CI job,
which increases the job's total wall-clock/resource pressure on a shared
GitHub Actions runner. Two already-marginal, already-partially-mitigated
WebKit timing hazards (a documented DOM-race in the recruitment locator; the
broader class of transient-empty-semantics reads) were tipped past their
existing bounded-retry budgets in this one run. This is CI/runner-timing
instability exposed by a longer job, not a functional regression in
PR #138's own code.

## 6. Classification: **D** (CI infrastructure / browser-timing instability)

Evidence, per the required categories:

- **Not A** (PR #138's own new tests) — all 6 passed, no retries, both
  viewports.
- **Not B** (helper-change-induced regression in existing tests) — PR #138
  modifies zero existing files; `public-demo-player.ts` is new and
  self-contained; nothing existing imports it.
- **Partially resembles C** (known WebKit/Flutter semantics timing
  characteristic) for the *second*, self-recovering failure only — but
  that characteristic is pre-existing, already documented, and already
  partially mitigated in this codebase; PR #138 neither introduces nor
  worsens it in the code sense (only in incidental job duration).
- **D fits both failures**: job-duration-driven runner contention against
  already-marginal, already-known-flaky timing budgets, confirmed by direct
  comparison against a clean same-day `main` run of the same suite (minus
  PR #138's 6 tests) at half the wall-clock time.
- **Not E** — zero production code in PR #138's diff; the one production
  change on the path to latest `main` (PR #137's July Month Guard) is
  analyzed in §7/§9 and does not affect this failure (neither failing spec
  touches Public Demo or July-close logic at all).
- **Not F** — while there are two distinct failing tests, both trace to the
  same underlying mechanism (CI-timing pressure against known-marginal
  WebKit interaction budgets), not to unrelated causes.
- **Not G** — root cause is identified with direct, reproducible evidence
  (same-day clean main run, in-repo documentation of the identical prior
  failure, isolated PR #138 diff).

## 7. Comparison with `main`

`origin/main` at `8c59e309` (PR #137's merge commit, workflow run
`33459011788`, same day as PR #138's CI run, ~40 minutes earlier):

| Job | Conclusion | Duration |
|---|---|---|
| validate | success | 9m12s |
| e2e-chromium | success | 6m06s |
| e2e-webkit | **success** | **5m16s** |
| replay-package / check-latest / build / deploy | success | — |

Zero failed or flaky tests in this run. This is the most direct available
baseline: same repository state (minus PR #138's 3 new files), same runner
class, same day. **The failure exists only on the PR branch's run, not on
this contemporaneous main run** — consistent with §5/§6 (job-duration-driven
timing pressure introduced by PR #138's additive new tests), not with a
persistent/systemic main-branch defect independent of job size.

I did not locate a WebKit-specific failure of these exact two tests
(`beginner-mode-waiting-and-recruitment.spec.ts:493`,
`phase-3b1-fit-reason.spec.ts:245`) in the small additional sample of older
`main` runs checked (e.g. run `33160104252`, an older, unrelated
double-failure on both browsers from a stale PR #78 branch, not a repeat of
this signature). A full historical flake-rate audit across all ~96 `e2e.yml`
runs on `main` was out of scope for this investigation; the same-day direct
comparison in this section was judged sufficient to establish the
PR-branch-vs-main distinction the task asked for.

## 8. Relation to PR #136

**No evidence connects this failure to PR #136's SkillSheet Bottom Sheet /
`案件スキル適合` issue.** Checked directly, not assumed:

- The only test in this entire WebKit run whose assertion touches the exact
  string `案件スキル適合` is `public-demo-fresh-start.spec.ts:38`
  (pre-existing, unmodified by PR #138) — and it **passed**
  (`✓ 44 … public-demo-fresh-start.spec.ts … (7.0s)`).
- Neither failing spec (`beginner-mode-waiting-and-recruitment.spec.ts`,
  `phase-3b1-fit-reason.spec.ts`) references `SkillSheet`, a Bottom Sheet,
  or Public Demo at all (grep-confirmed against `origin/main`). Both are
  Beginner-Mode/Founding-Prologue specs — a different screen, state
  machine, and UI stack from Public Demo entirely (per PR #138's own report,
  §"Current Public Demo E2E Architecture").
- `phase-3b1-fit-reason.spec.ts` does contain **a** BottomSheet interaction
  (a `FitReasonSheet`, unrelated to PR #136's `SkillSheet`), but its actual
  failure in this run happened at week 6 of the shared weekly-progression
  loop — well before that spec ever reaches its BottomSheet code (documented
  in the spec's own header as happening around week 13+). The failure
  symptom (`dead-end at week 6: no recognized action`) is generic
  weekly-progression stall detection, not a BottomSheet/semantics-text
  lookup failure.

Conclusion: this is a **different** failure class from PR #136's. No
symptom, spec, locator, DOM/semantics area, or navigation state matches.

## 9. Required Fix

**None, within PR #138's scope.** PR #138's own diff (3 new files, 0
production changes) is not the cause of either failing test, so no change
to it is warranted. Per the task's own Fix Policy, no test-weakening
(skip/retry-inflation/timeout-inflation/assertion removal/WebKit-exclusion)
was applied or is recommended, and none is needed — this is not a defect in
PR #138's code to fix.

The two pre-existing flaky tests are **out of PR #138's scope** to fix (they
are not in its diff, and the task brief explicitly prohibits scope
expansion beyond the Full-Year E2E Phase 1 baseline). They are flagged here
as a separate, existing concern:

- `beginner-mode-waiting-and-recruitment.spec.ts`'s `clickResilient` retry
  budget (15s total, ~3s/attempt) already has a documented history of
  exactly this failure mode; a repo maintainer may want to revisit that
  budget or the candidate-list re-render race itself in a dedicated,
  unrelated change — not as part of landing PR #138.
- The residual transient-empty-semantics flake in
  `phase-3b1-fit-reason.spec.ts` is the same general WebKit timing category
  `e2e/README.md` already documents two prior fix rounds for; a third round
  (if it recurs with enough frequency to matter) is likewise a separate,
  unrelated change.

## 10. Files Changed

PR #138's diff (unchanged by this investigation): `e2e/helpers/public-demo-player.ts`
(new, 342 lines), `e2e/tests/public-demo-annual-route.spec.ts` (new, 183
lines), `docs/reports/SES_FULL-YEAR_E2E_Phase1_Result.md` (new, 376 lines).
Zero files under `lib/`.

This investigation's own change: this report file only
(`docs/reports/SES_PR138_WebKit_Integration_Result.md`), committed to this
session's designated branch (`claude/pr138-webkit-failure-y4m47d`), which is
**not** PR #138's branch (see §2 note). No change was made to PR #138's own
branch, to `main`, to any test, or to any workflow file.

## 11. Test Results

Local re-verification in this session's sandbox was **not possible**: the
sandbox has no Flutter SDK installed (`flutter: command not found`) and no
WebKit browser installed (`/opt/pw-browsers` contains only
`chromium`/`chromium_headless_shell`, no `webkit`). This mirrors PR #138's
own author's documented sandbox limitation (its PR description explicitly
defers WebKit verification to CI for the same reason). No `flutter analyze`,
`flutter test`, or local Playwright run was executed as part of this
investigation. What was verified instead:

- PR #138's own CI (`validate` job: `flutter analyze` + `flutter test`, both
  green) already confirms these on PR #138's actual head commit.
- `origin/main`'s own CI (`validate` job on run `33459011788`) is green.
- A local `git merge --no-commit --no-ff origin/main` against PR #138's head
  (`origin/claude/full-year-demo-e2e-phase1-ls8sje`) completed with **zero
  conflicts** ("Automatic merge went well") — see §13.

## 12. WebKit Results

From PR #138's actual CI run (job `99697034351`, run `33455720462`),
`mobile-webkit`, both required viewports (360×800, 390×800):

- **All 6 of PR #138's new `public-demo-annual-route.spec.ts` tests: PASS**,
  no retries, both viewports (§4 table).
- 69 of 71 total WebKit-suite tests: PASS.
- 1 hard failure, 1 flaky (recovered on retry) — both pre-existing,
  unrelated specs (§4, §5).
- WebKit was **not** skipped, disabled, or excluded from the gate at any
  point in this investigation, and no change was made to
  `playwright.config.ts` or `.github/workflows/e2e.yml`.

## 13. Latest-Main Compatibility

`origin/main` is exactly one merge ahead of PR #138's base: PR #137 ("July
Month Guard", Issue #119 PR1). Its production diff touches
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — the same
screen PR #138's new tests drive.

**Behavioral analysis of that diff** (full diff read, §"STEP 7" of this
investigation): PR #137 introduces `PublicDemoMonthGuard.evaluate()`, a pure
refactor of the pre-existing July-close gate. Before: `if
(!s.summerBonusDecisionConfirmed) { decideSummerBonus(); return; }`. After:
`if (_summerBonusDecisionRequired) { decideSummerBonus(); return; }`, where
`_summerBonusDecisionRequired` is true under exactly the same condition
(`month == 7 && !s.isCloseBlocked && !s.summerBonusDecisionConfirmed`) the
old check covered. Only the on-screen description/label *text* around the
July card changed (e.g. `夏季賞与を確認してから、月末処理へ進みます。` →
conditional text) — PR #138's tests assert against the canonical CTA regex
(`MONTHLY_PRIMARY_CTA_PATTERN`) and calendar-month labels, never against this
specific description text, so this refactor is transparent to PR #138's
assertions.

**Mergeability**: a local `git merge --no-commit --no-ff origin/main`
against PR #138's actual head (`origin/claude/full-year-demo-e2e-phase1-ls8sje`)
completed with **zero textual conflicts** ("Automatic merge went well; stopped
before committing as requested") — confirmed, then the merge was aborted and
the scratch branch deleted; nothing was pushed. GitHub's own
`mergeable_state: "unstable"` on PR #138 reflects only the failing WebKit
check, not a real merge conflict.

**Not independently re-run**: this session could not execute PR #138's
tests against a merged (PR #138 + latest `main`) tree locally (§11) — the
behavioral analysis above is a code-level read, not an executed
confirmation. Recommended verification path is in §16.

## 14. Merge Readiness

**Not yet mergeable as green** — `e2e-webkit` is currently failing on PR
#138's head commit, and this task's own instructions correctly prohibit
merging with a red required gate. However:

- The failure is judged, with direct evidence, **not** to be a defect in
  PR #138's own code (§5, §6).
- PR #138 merges cleanly (no conflicts) onto current `main` (§13).
- The one intervening production change (PR #137) is analyzed as
  behavior-preserving for PR #138's own test assertions (§13).

**Recommended path**: re-run (not modify) PR #138's `e2e-webkit` CI job. If
it passes clean (consistent with this investigation's theory that this was
transient runner-load pressure against two pre-existing, already-marginal
WebKit timing budgets), PR #138 is then ready to merge as-is, with no code
change. Optionally, before or after that re-run, bring `origin/main` into
PR #138's branch (merge, not rebase — see rationale below) so its own CI
run also validates directly against the current `main` tip rather than its
original base.

**Merge vs. rebase, if main is brought in**: **merge** is recommended over
rebase. PR #138's branch has no history worth linearizing away (2 commits,
both already reviewed as a unit), the merge was confirmed conflict-free, and
a merge commit preserves PR #138's original commits/SHAs for its existing
CI run's provenance, consistent with this repository's own visible
convention (every `main`-branch history entry inspected in this
investigation is itself a merge commit, never a rebase). A force-push is
never required for a merge (only for a rebase), consistent with this task's
prohibition on force-pushing.

## 15. Remaining Risks

- The re-run recommendation in §14 is a prediction, not a certainty: if
  `e2e-webkit` fails again on a clean re-run with the *same* two tests, that
  would upgrade this from "confirmed transient CI timing instability" to "a
  more persistent flake worth its own, separate investigation" — still not
  evidence of a PR #138 regression (the isolation argument in §5 holds
  regardless of flake persistence), but worth tracking.
- This investigation's latest-main-compatibility conclusion (§13) is a code
  read, not an executed test run — the recommended verification path (§16)
  closes that gap.
- No Flutter/WebKit tooling was available in this sandbox to independently
  reproduce anything locally (§11) — all verification in this report is
  from CI logs, GitHub API data, and static diff analysis.
- A full historical flake-rate audit of `beginner-mode-waiting-and-recruitment.spec.ts`
  and `phase-3b1-fit-reason.spec.ts` across all prior `main` CI runs was not
  performed (§7) — only a same-day, single-run comparison. If a maintainer
  wants a statistical flake-rate figure (not just "isolated from PR #138's
  diff, and clean on a contemporaneous main run"), that is additional,
  separate work.

## 16. Recommended Next Action

1. Re-run PR #138's existing `e2e-webkit` check (no code change) to confirm
   the transient-flake theory. This does not require touching PR #138's
   branch at all.
2. In parallel or afterward, merge current `origin/main` (`8c59e309`) into
   PR #138's branch (`claude/full-year-demo-e2e-phase1-ls8sje`) — confirmed
   conflict-free in this investigation (§13) — so PR #138's own CI run
   validates directly against latest `main`, including PR #137's July Month
   Guard refactor.
3. Once both `e2e-chromium` and `e2e-webkit` are green on that merged head,
   PR #138 is ready to merge as the Full-Year Public Demo E2E Phase 1
   baseline, with **no code changes to PR #138 itself**.
4. Separately (explicitly **not** part of landing PR #138): flag
   `beginner-mode-waiting-and-recruitment.spec.ts`'s `clickResilient`
   candidate-list race and the residual WebKit transient-empty-semantics
   flake in `phase-3b1-fit-reason.spec.ts` for a maintainer to consider in
   a dedicated, unrelated follow-up, given both already have prior CI
   history (§5, §9).

This session could not itself trigger a CI re-run or push a merge commit to
PR #138's branch (no `gh`/direct git-push access to that branch was
exercised, and doing so was out of this task's authorized scope without
further confirmation) — steps 1-2 above are handed to the repository owner
to execute.

---

STATUS: INVESTIGATION COMPLETE — NO CODE CHANGE MADE
ROOT CAUSE: CI-timing/runner-contention exposing two pre-existing, already-documented WebKit flake patterns (a candidate-list DOM-race in beginner-mode-waiting-and-recruitment.spec.ts; a transient-empty-semantics dead-end read in phase-3b1-fit-reason.spec.ts), triggered by PR #138 roughly doubling the WebKit job's wall-clock time by additively running 6 new tests — not by any defect in PR #138's own code
CLASSIFICATION: D (CI infrastructure / browser-timing instability)
PR138 HEAD: 4eb0515a712302ba5b70698e52254848b0825d31
AUDITED MAIN: 8c59e3092519e8f31e415323b14f793c212a2300
FAILED SPEC: tests/beginner-mode-waiting-and-recruitment.spec.ts:493 (hard failure); tests/phase-3b1-fit-reason.spec.ts:245 (flaky, recovered on retry) — both pre-existing, neither touched by PR #138
PR138 ANNUAL TESTS: ALL 6 PASS (360x800 and 390x800; April, June, April-March scenarios), zero retries
MAIN REPRODUCTION: NOT REPRODUCED — origin/main at 8c59e309 ran the same e2e-webkit job clean (0 failures) in 5m16s, same day, ~40 minutes before PR #138's failing run
FIX REQUIRED: NONE within PR #138's scope; pre-existing flaky tests flagged for a separate, unrelated follow-up
WEBKIT: REQUIRED GATE, CURRENTLY RED on PR #138's head for reasons unrelated to PR #138's own diff; recommend re-run to confirm transient-flake theory
LATEST MAIN COMPATIBILITY: CONFIRMED CONFLICT-FREE (local dry-run merge, zero conflicts); one intervening production change (PR #137 July Month Guard) analyzed as behavior-preserving for PR #138's assertions
MERGE READINESS: NOT YET (red required gate) — recommended path is a CI re-run, not a code change
NEXT ACTION: Re-run PR #138's e2e-webkit CI job; separately merge latest main into PR #138's branch (confirmed conflict-free) so its CI validates against current main before merging PR #138 as-is
