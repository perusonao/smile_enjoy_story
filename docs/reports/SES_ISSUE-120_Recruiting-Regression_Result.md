# SES Issue #120 — Recruiting Regression (PUBLIC-DEMO-RECRUIT-1A) Result

## Status

**Verified, not fixed — no production defect found.** The Public Demo
recruiting-media system already satisfies Issue #120's literal, testable
acceptance criteria on `origin/main`: `flutter analyze` clean, the new
dedicated regression suite (4/4) passes, and the full Public Demo suite
(`test/game/public_demo/` + `test/ui/public_demo/`, 735 tests) passes
unmodified. No `lib/` file was touched. One finding below needs a maintainer
decision before Issue #120 can be closed — see
[Issue #120 close readiness](#issue-120-close-readiness).

## Base SHA

`39d6f40e0d43561766f5cbf2c33a26ccbf9fd6f1` (`origin/main`, "Merge pull
request #161 from perusonao/claude/first-fun-year-cash-shortage-truth-4blgnw").

## Branch

`claude/issue-120-recruiting-regression-7jsr87`

## Scope Respected

Per the task's explicit boundaries (PR #164 is mid-flight on Public Demo
save/persistence/entry/routing):

* No file under Public Demo save/persistence (`public_demo_save_codec.dart`,
  `public_demo_save_service*`), app entry, or routing was read for editing
  or changed.
* No CI/E2E infrastructure file was changed.
* No balance/economy value (recruiting cost, applicant count, salary, growth
  rate) was changed.
* No applicant/interview/offer/join state-machine logic was changed.
* Zero `lib/` production files changed. Only one new test file was added.

## Investigation

### 1. Read Issue #120 and current `main`

Acceptance criteria: "No active recruiting => no recruiting-generated
applicant. Active recruiting follows existing configured rules. Existing
applicant/interview flows remain intact. Deterministic tests cover inactive
and active recruiting states. No unrelated balance change." Dependency
(PUBLIC-DEMO-MONTH-GUARD-1A / Issue #119) is already merged into `main`
(`docs/reports/SES_ISSUE-119_MONTH-GUARD_Implementation_Result.md`).

### 2. Traced every applicant-generation path in Public Demo 0.1

Searched all of `lib/` for every caller of the two APIs that can ever place
an entry into `PublicDemoWorkflowState.applicants` after game start:

* `PublicDemoWorkflowState.withGeneratedApplicants` — **exactly one caller**,
  `PublicDemoAggregate.recruit` (`public_demo_aggregate.dart:286`).
* `PublicDemoAggregate.recruit` — **exactly one caller**,
  `_openRecruitmentMedia` in `public_demo_01_placeholder_screen.dart:742`,
  itself only reachable from `_RecruitmentMediaCard`'s `onPressed`, gated
  behind a player-dismissible `showModalBottomSheet` (dismissing returns
  `null` and the method returns immediately — no side effect).

There is no other production code path anywhere under `lib/` that can add an
applicant to the authoritative workflow. `PublicDemoRecruitmentCalculation`
(the pure calculation `recruit()` commits) already gates on
`canUseRecruitmentMediaInMonth` (one recruit per month, months 4-8 only) and
`state.isFinanciallyRestricted` (checked before generation, per
FINANCE-FAILURE-1A+1B §13/15, for every medium including `free`) — both
already covered by extensive existing tests in
`test/game/public_demo/public_demo_recruitment_workflow_transaction_test.dart`.

### 3. Reproduced the literal symptom, then found it is pre-existing intentional content

`PublicDemoWorkflowState.initial()` seeds `applicants: publicDemoMayApplicants`
(two entries — `app-01`/高橋 翔, `app-02`/田中 美咲) directly, with **no**
recruiting action required, so a fresh game *does* show two applicants in
May before the player has ever pressed anything. Read narrowly, this
reproduces the literal symptom ("応募者が生成される" with zero recruiting
activity) and the Screen Verification Gate as written ("advance through the
relevant month without recruiting and confirm no unexplained applicant
appears") would fail against it.

However, tracing this pool's origin and every place it is exercised showed
it is not a code defect, but pre-existing, foundational, heavily-verified
game content, predating the recruiting-media system entirely:

* `PublicDemoWorkflowState.initial()`'s own doc comment: "Public Demo 0.1's
  starting workflow, **matching the founding team and established applicant
  pool that predate this class** (exactly the values
  `[PublicDemo01PlaceholderScreen]`'s own `State` fields used to default
  to)." `git log --follow -p` confirms this seed has been unchanged since
  the WORKFLOW-STATE-1 domain cutover, itself carried over from the
  original widget defaults (commit `0e359f3`, "add May recruitment model" —
  predates the recruitment-media feature, commit `372ec85`, entirely).
* `e2e/helpers/public-demo-player.ts`'s `interviewAndOfferAppOne` — a
  currently-used, currently-passing helper — documents interviewing and
  offering `app-01` (高橋 翔) via `経歴書確認` → `採用面談`, with **no**
  recruiting-media purchase, as *the* canonical May hiring route: "May's
  applicant pool always has two candidates (`publicDemoMayApplicants`)."
  Recruiting media is a **separate, additional** channel for more
  candidates, not the only channel — by the codebase's own existing,
  end-to-end-tested design.
* `PublicDemoAggregate`'s own class doc states test fixtures must reach any
  state "by chaining these same real commands from `initial`... never via a
  reconstruction shortcut" — and dozens of already-existing, deliberately
  security-hardened tests (`public_demo_aggregate_test.dart`'s
  WORKFLOW-STATE-1AB FIX1-FIX6 coverage, `public_demo_workflow_state_test.dart`,
  `public_demo_binding_offer_test.dart`, `public_demo_join_test.dart`,
  `public_demo_financial_status_test.dart`,
  `public_demo_balance_regression_test.dart`,
  `public_demo_recovery_aggregate_test.dart`, `public_demo_save_codec_test.dart`)
  all build their fixtures on the assumption that `PublicDemoAggregate.initial()`
  already carries these two applicants for free, and interview/offer/join
  them directly as the "genuine interview"/"genuine offer"/"genuine join"
  baseline case.

Removing or gating this seed — the only way to make the Screen Verification
Gate literally true — would necessarily rewrite core fixture assumptions in
that security-hardened aggregate-test suite (one concrete example: the
`completeInterview`/"budget of 4" test in `public_demo_aggregate_test.dart`
explicitly spends its whole 4-slot sales budget on "both real initial
engineers' partner interviews... plus both real initial applicants'
`completeInterview`", a scenario that requires exactly these two applicants
to exist without any prior `recruit()` call), would touch
`public_demo_save_codec_test.dart` (persistence — explicitly out of scope
for this task) and `e2e/helpers/public-demo-player.ts` (E2E infrastructure —
also explicitly out of scope), and would remove the currently-documented
primary May hiring route — directly conflicting with this same issue's own
"Existing applicant/interview flows remain intact" and "No unrelated
balance change" criteria, and with this task's explicit prohibition on
touching persistence/E2E-infrastructure. **No code change can satisfy every
stated constraint simultaneously**, which is exactly the "do not guess"
condition this task asks to stop on rather than force a fix through.

### 4. Confirmed the actually-configured recruiting contract is correct and already tested

What *is* fully attributable to "recruiting activity" — the paid/free
recruiting-media purchase — already behaves exactly as Issue #120's
acceptance criteria require:

* No `recruit()` call ever fires on its own; it is reachable from exactly
  one player-initiated, dismissible UI action.
* One recruit call adds exactly `medium.applicantCount` applicants
  (free: 1, engineer: 2) and charges exactly `medium.cost`, atomically with
  the cash change (`PublicDemoRecruitmentCalculation.execute`,
  `PublicDemoAggregate.recruit`).
* A second recruit attempt in the same month is rejected
  (`alreadyUsedThisMonth`) and changes nothing.
* This was already covered by
  `public_demo_recruitment_workflow_transaction_test.dart`, but no existing
  test asserted the "inactive vs. active" contract together, by name,
  against the unmodified `PublicDemoAggregate.initial()` production entry
  point in one place — the gap Issue #120 asks to close with "deterministic
  tests cover inactive and active recruiting states."

## Change Made

**Test-only.** Added
`test/game/public_demo/public_demo_recruiting_activity_regression_test.dart`,
a dedicated Issue #120 regression suite, four tests:

1. `PublicDemoAggregate.initial()` with zero `recruit()` calls: no applicant
   id matches the `recruitment-*` pattern `PublicDemoRecruitmentCalculation`
   mints, `recruitmentMediumUsedMonth` is `null`, and the applicant roster
   is exactly the established May pool (`publicDemoMayApplicants`'s ids, in
   order) — never more, never fewer.
2. Active recruiting, paid `engineer` medium: adds exactly
   `medium.applicantCount` new, `recruitment-`-prefixed ids, atomically with
   `medium.cost` cash and the per-month usage guard.
3. Active recruiting, `free` medium: adds exactly `medium.applicantCount`
   at zero cash cost.
4. A second same-month recruit attempt is rejected and adds nothing.

No production (`lib/`) file was changed.

## Tests

* `dart format test/game/public_demo/public_demo_recruiting_activity_regression_test.dart`
  — 1 file formatted, clean.
* `flutter analyze` (full project): **No issues found!**
* `flutter test test/game/public_demo/public_demo_recruiting_activity_regression_test.dart`:
  **4/4 passed**.
* `flutter test test/game/public_demo/ test/ui/public_demo/` (full Public
  Demo suite, domain + widget): **735/735 passed**, unmodified — confirms
  zero regression from adding the new file (expected, since no production
  code changed).
* Full-repo `flutter test` / Heavy E2E / WebKit: not run, per the task's own
  "必要最小限のPublic Demo tests, full E2E/WebKitは不要" instruction.

## Issue #120 Close Readiness

**Not recommended to close as-is.** Two things are true at once and the gap
between them is a design question, not a code defect this task can resolve
unilaterally:

* The *configured recruiting-media system* (the only mechanism this
  codebase calls "recruiting") already satisfies the issue's functional
  acceptance criteria, now with dedicated regression coverage.
* The issue's own Screen Verification Gate, read literally ("advance
  through the relevant month without recruiting and confirm no unexplained
  applicant appears"), does **not** currently pass, because
  `publicDemoMayApplicants` (`app-01`/`app-02`) are visible in May with zero
  player action — by long-standing, heavily end-to-end-tested design that
  predates recruiting media, not a regression.

Recommended next step: have the maintainer confirm intent before either
closing #120 as "working as designed — natural May applicants are not
'recruiting', only media purchases are" or filing a properly-scoped
follow-up to gate/relabel the natural May pool. That follow-up is
substantially larger than a "1A" fix — it touches the security-hardened
`PublicDemoAggregate`/`PublicDemoWorkflowState` fixture contract, Public
Demo persistence tests, and `e2e/helpers/public-demo-player.ts`'s canonical
hiring route — i.e. exactly the persistence/E2E-infrastructure surface this
task was told not to touch, so it should not be attempted inside this
task's boundaries regardless of the answer.

## Result Summary

* **RESULT: PASS**
* **Base SHA:** `39d6f40e0d43561766f5cbf2c33a26ccbf9fd6f1`
* **Root cause:** No code defect in the configured recruiting-media system;
  the only zero-action applicants (`app-01`/`app-02`) are pre-existing,
  intentional, end-to-end-tested May content that predates recruiting
  media, not something `PublicDemoAggregate.recruit` (the sole
  applicant-generation path) invents.
* **Production change:** NO
* **Tests:** `flutter analyze` clean; new suite 4/4; full Public Demo suite
  735/735 (unmodified, no regression)
* **Final SHA:** see this commit
* **PR number:** none opened yet — see note below
* **Issue #120 close readiness:** NOT YET — needs maintainer confirmation
  on the `app-01`/`app-02` baseline-pool design question above before
  closing or before scoping any further code change
* **Result report path:** `docs/reports/SES_ISSUE-120_Recruiting-Regression_Result.md`

Per the task's instructions, since production code was not changed, this
report is pushed to the designated branch, but no PR is opened purely for a
documentation-only, no-code-change branch pending the maintainer's answer
on close readiness — happy to open one on request.
