# SES First Fun Year — Issue #168 Finding B — Result

## STATUS

IMPLEMENTATION COMPLETE (production fix + focused tests + full regression
run). Commit pushed to the designated branch; PR to be opened per task
instructions.

## SCOPE

Issue #168 (`FIRST-FUN-YEAR-ONBOARDING-1`) Finding B, as scoped by the
issue's own design-direction comment
(https://github.com/perusonao/smile_enjoy_story/issues/168#issuecomment-5549281040):
close the one gap that kept 鈴木葵 (Suzuki, eng-02, founding-engineer
`actualSkill` 52) from ever completing the game's own advertised
"研修 → 実力60到達 → 営業再開" loop, **without** changing the
`>= 60` sales threshold, the training growth rate, or adding any
Suzuki-only branch.

## AUDITED origin/main

```
git fetch origin main
git checkout -B claude/issue-168-finding-b-6rvhvy origin/main
git rev-parse origin/main -> 63d79bec203acdd46d01405454faa17a4e3b30bd
```

This SHA is PR #176's merge commit (Issue #168 Onboarding-1 Slice A+C+D).
The branch `claude/issue-168-finding-b-6rvhvy` existed locally but pointed
at a stale ancestor commit (`f4ca78f`, no unmerged work of its own) — reset
to `origin/main` before starting, per the "already-merged branch" restart
rule (nothing unmerged to preserve).

## ROOT CAUSE (confirmed against current code, not the pre-implementation
audit's summary alone)

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`'s
`_buildEmployeesTab()` already re-renders every still-`waiting`/`skillSheet`,
unassigned engineer's full sales-flow card
(`ec(i, showTrainingCard: false)`) every month from July through February
— this is RECOVERY-LOOP-1's own window, unrelated to Finding B, added for a
different reason (project-recovery). Because that loop keys off
`readyForFieldSales`/`isReadyForFieldSales` (`actualCapability >= 60`) with
no month-of-training special-casing, an engineer who reaches the threshold
through repeated training **does** get `SkillSheet確認` back — the rule the
old lock-banner copy said flatly could never happen was already partially
true before this change.

What was actually broken:

1. **May was the one gap in the training loop.** April's `ec(i)` embeds its
   own training card (`showTrainingCard` defaults `true`), and the
   unconditional `internalTrainingCard` block previously started at
   `s.month >= 6`. Nothing rendered a training card in May at all, costing
   every founding engineer a full month of `PublicDemoGrowthEngine`'s
   `internalTraining` growth (+1/month for Suzuki — see CALCULATION below)
   on the way to `fieldSalesCapabilityRequirement`, for no domain reason —
   `PublicDemoInternalTrainingTransaction` was never month-gated to begin
   with.
2. **The lock banner's own comment/copy overclaimed permanence.** It stated
   "no later month offers this action again, no matter how much further
   capability training raises" — false given the July-February window
   above; nobody had ever driven a fixture far enough (repeated training,
   many months) to notice. The copy itself didn't name a specific month,
   but the surrounding engineering comment asserted an absolute negative
   that wasn't true, and the copy read as a dead end rather than an
   open (if slow) path forward.

## CALCULATION (why this is closeable within Year 1, unassisted)

`PublicDemoGrowthEngine._capabilityDelta` for Suzuki's `internalTraining`
source: `sourceBase 1.2 * potentialMultiplier (0.70 + growthPotential(4) *
0.15 = 1.30) * fastLearnerMultiplier (1.0, no ability) * moraleMultiplier
(1.0, morale 64 is inside (30,75]) * diminishingMultiplier (1.0, skill <
70)`, floored: `floor(1.2 * 1.30) = 1` per month trained. From 52, eight
consecutive monthly trainings (April, May, June, July, August, September,
October, November) reach exactly 60 at November's close — verified
empirically by the new regression test, not just by this arithmetic.

## IMPLEMENTATION

**Production (1 file):**

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
  1. `_buildEmployeesTab()`'s unconditional `internalTrainingCard` loop
     changed from `if (s.month >= 6)` to `if (s.month >= 5)` — May now
     renders the same training card every other waiting month does. No
     other condition on that block changed (still self-guards on
     `assigned`, still the identical `research する` command/key).
  2. The field-sales-lock banner (`ec(i)`'s
     `public-demo-field-sales-lock-<id>` container) gained a third line:
     `実力が基準に達すれば、その月以降に営業を再開できます。` — states the
     causal fact the July-February window already provides, without naming
     a specific month (which this build cannot promise; it depends on how
     many months of training the player buys). The prior line
     (`まだ営業を始められません。`) is unchanged and still true whenever the
     banner renders at all.
  3. Updated the stale engineering comments next to both of the above (the
     lock banner's own comment, and `internalTrainingCard`'s Finding-D
     comment) to state the corrected, verified facts instead of the old
     "never again" claim.

**No changes to:** the `>= 60` threshold
(`PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement`), any growth
rate/multiplier in `PublicDemoGrowthEngine`, any Suzuki-specific
(`eng-02`-keyed) branch, Finance/save schema/game-balance files, or any CI
workflow.

**Tests (2 files changed, 1 file added):**

- `test/ui/public_demo/public_demo_01_suzuki_sales_reentry_test.dart`
  (NEW) — the item-3 regression: trains Suzuki every month from April
  through November through the real production UI (April via `ec(i)`'s
  embedded card, May via the newly-added standalone card, June onward via
  the pre-existing standalone card), sells and carries Sato's assignment
  forward for Revenue (mirrors
  `public_demo_01_assignment_carryforward_test.dart`'s own contract so the
  playthrough stays solvent — cash shortage in that fixture's baseline
  trajectory doesn't hit until February), and asserts:
  - the May training card now exists (Finding B's own fix);
  - `actualCapability` increases by exactly +1 at each month-end close
    (52 → 53 → 54 → … → 60 by November's close);
  - the lock banner and `SkillSheet確認`'s absence hold every month she is
    still below the threshold;
  - by December, the lock banner is gone and `SkillSheet確認` is back —
    with **zero** production code keyed to Suzuki, the threshold, or the
    growth rate having been touched to make this happen.
- `test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart`
  (UPDATED) — kept as the "one month of training is not enough" regression
  (its own fixture never trains her past April), but:
  - retitled away from the now-false "never offers the SkillSheet route …
    no matter how much later training raises her capability" claim;
  - the lock-banner text assertion now expects the corrected three-line
    banner (see IMPLEMENTATION §2);
  - added an assertion that May's training card exists (previously
    untested, now Finding B's own fix);
  - corrected the month-6/month-7 comments that echoed the old "never
    again" claim to instead point at
    `public_demo_01_suzuki_sales_reentry_test.dart` for the full path.
- `test/ui/public_demo/public_demo_01_recovery_ui_test.dart` (UPDATED,
  comments only) — the file's class doc and one assertion `reason:` string
  called Suzuki "permanently locked out of field sales for the whole
  fiscal year"; corrected to state she starts below threshold and stays
  locked only for as long as that suite's own fixture leaves her
  untrained, cross-referencing the new reentry test. No assertions or
  fixture behavior in this file changed — it still never trains eng-02, so
  every existing assertion in it holds unchanged.

## TESTS RUN

Focused (during implementation, per the "no full-suite reruns mid-work"
policy):

```
flutter analyze lib/ui/public_demo/public_demo_01_placeholder_screen.dart \
  test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart \
  test/ui/public_demo/public_demo_01_suzuki_sales_reentry_test.dart \
  test/ui/public_demo/public_demo_01_recovery_ui_test.dart
-> No issues found!

flutter test test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart
-> All tests passed! (1/1)

flutter test test/ui/public_demo/public_demo_01_suzuki_sales_reentry_test.dart
-> All tests passed! (1/1)

flutter test \
  test/ui/public_demo/public_demo_01_recovery_ui_test.dart \
  test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart \
  test/ui/public_demo/public_demo_01_internal_training_explanation_test.dart \
  test/ui/public_demo/public_demo_01_assignment_carryforward_test.dart \
  test/ui/public_demo/public_demo_01_fiscal_year_progression_test.dart \
  test/ui/public_demo/public_demo_01_success_playthrough_test.dart
-> All tests passed! (8/8)

flutter test \
  test/ui/public_demo/public_demo_01_home_consolidation_test.dart \
  test/ui/public_demo/public_demo_skill_sheet_display_projection_test.dart \
  test/ui/public_demo/public_demo_01_month_guard_april_may_june_test.dart \
  test/ui/public_demo/public_demo_01_month_guard_recommended_test.dart \
  test/ui/public_demo/public_demo_01_home_recommended_action_test.dart
-> All tests passed! (75/75)
```

Full regression (run once, at PR completion, per instructions):

```
flutter test
-> 00:00 ... 11:09 +1539: All tests passed!
   (exit code 0, ~11 minutes wall clock)
```

All 1539 tests pass, including the new/updated files above.

## GAMEPLAY / DOMAIN IMPACT

Founding engineers who start below the field-sales threshold (currently
only Suzuki, at 52) get one additional legal training opportunity (May)
per fiscal year, and the lock banner now truthfully states that reaching
the threshold reopens sales — a fact the existing July-February window
already made true, just previously unverified and undocumented. No other
engineer/applicant, stage, threshold, or growth-rate behavior changed.

## SAVE SCHEMA IMPACT

None. No new fields, no changed serialization — `trainingSelections` and
`engineerRuntimes` already round-trip through the existing schema
unchanged.

## SCREEN VERIFICATION

`public_demo_01_suzuki_sales_lock_test.dart` continues to assert the lock
banner fits inside 360px with no overflow (`lockRect.left >= 0`,
`lockRect.right <= 360`) with its now-three-line copy; the new reentry test
runs the full playthrough at the suite's default test size. Both pass.

## KNOWN GAPS / FOLLOW-UPS (out of this slice's scope, not required by
Issue #168 Finding B)

- June's founding-engineer sales card is scoped to `joinedApplicantIds`
  (newly-joined hires), which by design excludes founding engineers —
  Suzuki has no June `SkillSheet確認` opportunity even if she crossed the
  threshold mid-May. This is unaffected by this change (July onward already
  covers it) and was intentionally left alone to avoid widening this
  slice's scope beyond Finding B's own acceptance direction (no rule
  change beyond the training-card gap and the lock-banner copy).
- Reaching the threshold still takes real, repeated play (8 consecutive
  months for Suzuki's specific `growthPotential`) — this is the existing,
  unmodified growth rate, left untouched per the task's explicit
  prohibition on changing it.

## COMMIT / BRANCH / PR

- Branch: `claude/issue-168-finding-b-6rvhvy` (reset onto `origin/main`
  63d79bec203acdd46d01405454faa17a4e3b30bd before this work)
- Commit SHA: `1c5391f` (branch `claude/issue-168-finding-b-6rvhvy`, pushed)
- PR: https://github.com/perusonao/smile_enjoy_story/pull/177

## MERGE READINESS

Ready for review pending the full-suite result above. No CI workflow was
touched; the repository's `flutter-validate` gate (`flutter analyze` +
`flutter test` + web build) is expected to pass unchanged given the
focused results above.
