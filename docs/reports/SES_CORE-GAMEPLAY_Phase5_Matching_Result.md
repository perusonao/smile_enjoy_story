# SES CORE-GAMEPLAY Phase 5: Matching Decision Gameplay — Result

Status: **Implementation complete. Full suite 1918/1918 green (0 failures) on the final HEAD SHA. `flutter analyze` clean. `git diff --check` clean. One blocker found by the full-suite run and fixed — see "Blocker found and fixed" below.**

## BASE SHA / branch / HEAD

- BASE SHA (`origin/main` at session start): `dffbca883258871a57ae95edb908ec9429219b5c`
  ("Merge PR #210: CORE-GAMEPLAY Phase 4.5 Recruitment/SkillSheet authority")
  — matches the exact commit Issue #205 names as the start point.
- Branch: `claude/phase-5-matching-gameplay-2015zi` — this branch's prior tip
  (`f4ca78f`, "Phase 0A/0B: SES domain models and random generators") was a
  stale ancestor of `origin/main` with no open PR, so per the
  merged/stale-branch-reuse rule it was reset onto the BASE SHA above
  (`git reset --hard origin/main`) before any new work, mirroring Phase 4's
  own branch-reuse note.
- Final HEAD SHA: `c0a45957a7cbdc7ff4592b505d0cf865d2753f9f`
- PR: `<FILLED IN AFTER PR CREATION — see final chat message>`

## Scope discipline (Issue #205's own "do not" list)

- `MatchingEngine` scoring: **not modified** — `lib/game/engine/matching_engine.dart`
  was read only, never imported for editing, never touched.
- Project Interview gameplay: **not implemented**. The existing
  `beginSelling → introduceProject → partner/client interview → recordOrder`
  sales-pipeline stage machine (`public_demo_sales.dart`/
  `public_demo_workflow_state.dart`) is entirely unmodified — Phase 5 adds
  a separate, additive proposal record instead (see "Proposal handoff"
  below), never touching that pipeline's methods or preconditions.
- Finance, Month transition, balance, recruitment, HOME: **not changed** —
  confirmed by the diff stat below: zero lines touched in
  `public_demo_state.dart`, `public_demo_monthly_close.dart`, any
  `*_recruitment*` production file, or any HOME-only widget/screen file.
- No project/engineer value invented — every fact Phase 5 displays is read
  from an existing authoritative source (see "Reused authority/classes").
- No hidden/raw parameter exposed — see "Hidden information protection".
- This PR is Phase 5 only: 15 files changed (14 new + this report, plus 4
  production/test edits — see below), all under `docs/reports/`,
  `lib/game/public_demo/`, `lib/ui/public_demo/`, or `test/`; every edited
  production file only gained new, additive methods/fields (no existing
  method body changed).

## Changed files

```
docs/reports/SES_CORE-GAMEPLAY_Phase5_Matching_Result.md         (new, this file)
lib/game/public_demo/public_demo_aggregate.dart                  (+16, edit — new proposeMatching delegation)
lib/game/public_demo/public_demo_matching_profile.dart            (new)
lib/game/public_demo/public_demo_matching_proposal.dart           (new)
lib/game/public_demo/public_demo_workflow_state.dart              (+71, edit — new matchingProposals field/command)
lib/ui/public_demo/public_demo_01_placeholder_screen.dart         (+187, edit — Sales-tab entry point + handlers; see "Known constraints" for the hasAnyContent fix)
lib/ui/public_demo/public_demo_matching_decision_sheet.dart       (new)
lib/ui/public_demo/public_demo_matching_engineer_select_sheet.dart (new)
lib/ui/public_demo/public_demo_matching_project_card.dart         (new)
lib/ui/public_demo/public_demo_matching_project_list_sheet.dart   (new)
test/game/public_demo/public_demo_matching_profile_test.dart      (new)
test/game/public_demo/public_demo_matching_proposal_workflow_test.dart (new)
test/game/public_demo/public_demo_recovery_aggregate_test.dart    (+4, edit — additive matchingProposals key added to an exact-schema assertion; see "Blocker found and fixed")
test/ui/public_demo/public_demo_matching_decision_sheet_test.dart (new)
test/ui/public_demo/public_demo_matching_flow_test.dart           (new)
```

15 files changed, 2230 insertions(+), 0 deletions(-) (`git diff --stat`
against BASE SHA).

## Reused authority / classes

**Never reimplemented; all imported/called as-is:**

- `MatchingEngine.computeFit(Engineer, Project)` (`lib/game/engine/matching_engine.dart`)
  — the sole Fit scoring call. Reached through
  `ProjectComparisonEngine.rowFor(engineer, project)` — the same
  established indirection `FitReasonSheet` (main game) already uses, so
  Phase 5 never calls `computeFit` a second, independent way.
- `FitBreakdown`, `FitDetailItem`, `FitDimension`, `PlayerVisibleFit`
  (`lib/game/models/fit_result.dart`) — read, never re-derived.
- `FitBadge` (`lib/ui/widgets/fit_badge.dart`) — reused verbatim (imported
  directly) for every ◎○△× badge in the engineer-select list and the
  decision sheet.
- The *structure* of `FitReasonSheet` (breakdown rows + 良い点/注意点-style
  bullet lists, `fitDetailLabel` from `lib/ui/widgets/labels.dart`) is
  mirrored in the new `PublicDemoMatchingDecisionSheet` — not imported
  directly, because `FitReasonSheet` renders `fit.total` as a raw number,
  which Issue #205 explicitly forbids ("do not show only a number").
  `PublicDemoMatchingDecisionSheet` reuses every other piece of that
  structure but never renders `fit.total` or any sub-score.
- `PublicDemoSeededProjectGenerator` / `PublicDemoProjectCandidate`
  (`lib/game/public_demo/public_demo_project_generator.dart`, Phase 4) —
  the only source of project candidates, via the pre-existing
  `PublicDemoAggregate.projectCandidatesForMonth(month)` query entry point
  (added in Phase 4 explicitly "for Phase 5"). No project data is
  regenerated or duplicated.
- `PublicDemoSkillSheetSheet` (`lib/ui/public_demo/public_demo_skill_sheet_sheet.dart`,
  Phase 4.5) — reused verbatim via the screen's existing
  `_viewEmployeeSkillSheet` method (its own doc comment already
  anticipated this exact Phase 5 reuse). No new SkillSheet widget or
  projection was written.
- `PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant`
  (`public_demo_recruitment_candidate_generator.dart`, Phase 3) and the
  legacy-fixture-seed technique from
  `PublicDemoRecruitmentInterview._legacyFixtureApplicant` — both reused
  (not duplicated logic, generalized to any engineer id) inside the new
  `PublicDemoMatchingProfile` adapter — see below.

## Why a new adapter (`PublicDemoMatchingProfile`) was needed

`MatchingEngine.computeFit` requires a full domain `Engineer` (→ `Applicant`
→ `PersonalityTraits`, `japaneseLevel`, `desiredWorkStyle`, ...).
`PublicDemoEngineerRuntime` (Public Demo's own ground-truth capability
model) deliberately carries none of these — its own class doc says it
"does not contain SkillSheet/sales values." Inventing neutral placeholder
personality traits for this purpose was rejected: it would let the player
see a ◎○△× rating for a trait that was never actually measured, i.e.
exactly the "do not invent" violation Issue #205 forbids.

Instead, `PublicDemoMatchingProfile.engineerForMatching` recovers the
**genuine** domain `Applicant` an engineer was originally generated from —
via `PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant`
(Phase 3's own sanctioned technique for the identical purpose: giving a
main-engine engine real personality/hidden data to read), with the same
legacy-fixture fallback `PublicDemoRecruitmentInterview` already
established for the two founding engineers. Two authoritative sources are
combined, never fabricated:

- Stable identity/personality facts the runtime never tracks at all
  (personality traits, Japanese level, desired work style, age,
  education, ...) come from that genuine original `Applicant`.
- Facts Public Demo tracks as CURRENT, growth-updated ground truth
  (`PublicDemoEngineerRuntime.techSkills`, `.hidden`, and the tracked
  language's growth-adjusted experience/skill) are read from the runtime
  instead, since growth/training can make these differ from the
  application-time snapshot.
- Sub-language proficiency is left empty (`subLanguages: const []`):
  Public Demo tracks no CURRENT sub-language signal for a hired engineer
  (only the primary language's own growth) — mirrors
  `PublicDemoEngineerRuntime.confirmedLanguages` already limiting the
  SkillSheet the same way, for the same reason.

This file is the sole place Public Demo code constructs a full domain
`Engineer` for Matching — mirroring how `PublicDemoRecruitmentInterview`
is the sole gateway onto the recruitment-interview engine.

## Matching 表示内容 (what the player sees)

Required flow implemented exactly as specified:
`案件を見る → 社員を選ぶ → スキルシートを見る → 強み/不足を見る → 提案する/見送る → (Phase 6 handoff)`

1. **営業タブ → 「案件マッチング」→「案件を見る」** — opens
   `PublicDemoMatchingProjectListSheet`, a bottom sheet listing this
   month's real Phase 4 project candidates as `PublicDemoMatchingProjectCard`s:
   project name, monthly rate (万円), required languages/technology domains,
   required experience (`formatExperience`), difficulty/rank, payment
   term (days), and client tendency (`clientSpecialtyLabels`) — every
   field the Issue's "Project card" section requires, each a straight read
   of `PublicDemoProjectCandidate`/`Project`/`Client`.
2. **社員を選ぶ** — tapping a project opens
   `PublicDemoMatchingEngineerSelectSheet`: every available engineer (not
   currently on an active assignment — the same `_currentlyAssignedEngineerIds`
   signal every other on-screen assignment check already reads), each row
   showing only a bucketed `FitBadge` (◎○△×), never a number.
3. **スキルシートを見る / 強み/不足を見る** — tapping an engineer opens
   `PublicDemoMatchingDecisionSheet`: the full qualitative `FitBreakdown`
   (技術/経験/人物・相性/条件, each ◎○△×), a 強み/不足 bullet list built
   from `FitDetailItem`s (dimension label + rating symbol/label, e.g.
   "・Java: ◎ かなり有力"), an overall `FitBadge`, and a coarse
   "面接通過見込み: 高/中/低" tier — `PlayerVisibleFit.fromScore(fit.total)`
   bucketed into 3 labels, the number itself never rendered. A
   "スキルシートを見る" button opens the reused `PublicDemoSkillSheetSheet`
   on top.
4. **提案する / 見送る** — the sheet's own two buttons pop `true`/`false`;
   `true` commits `PublicDemoAggregate.proposeMatching`.

## Hidden情報保護

- `HiddenParameters` (growthPotential/stressTolerance/retention/
  projectInterviewSkill/turnoverIntent) is never read directly by any new
  UI file — only `MatchingEngine.computeFit` reads `hidden
  .projectInterviewSkill` internally, folded into the aggregate
  personality sub-score, itself only ever shown as a bucketed ◎○△×
  (`_BreakdownRow`), exactly like the main game's own `FitReasonSheet`
  already does — same audited pattern, not a new leak surface.
- `fit.total` and every raw sub-score (`techScore`/`experienceScore`/
  `personalityScore`/`conditionScore`) are never rendered — enforced by a
  dedicated regression test (`public_demo_matching_decision_sheet_test.dart`)
  that walks every painted `Text` widget and asserts none of five
  distinctive fixture numbers (including the total) appears anywhere,
  mirroring the technique
  `public_demo_candidate_skill_sheet_hidden_fields_test.dart` established
  for Phase 4.5's own hidden-field guard. No raw `%` figure is rendered
  either.

## SkillSheet連携

`_viewEmployeeSkillSheet` (Phase 4.5, unmodified) is called verbatim from
the decision sheet's "スキルシートを見る" button — same
`PublicDemoSkillSheetSheet`/`PublicDemoSkillSheetDisplayFactory`, same
authoritative data, same widget instance the Sales/Employee tabs already
use. Verified end-to-end in `public_demo_matching_flow_test.dart` (opens
`public-demo-skill-sheet-eng-01`, closes via its own cancel button, returns
to the still-open decision sheet with no state change).

## Proposal handoff (Phase 6)

`PublicDemoMatchingProposal { engineerId, projectId, decidedMonth }`
(`public_demo_matching_proposal.dart`) — a minimal, additive record stored
in a new `PublicDemoWorkflowState.matchingProposals` map (keyed by
engineerId, at most one entry per engineer — a later proposal for the same
engineer overwrites the earlier one). Committed only via
`PublicDemoAggregate.proposeMatching(engineerId, projectId)`, which stamps
the current `state.month`.

**Deliberately does not touch** `PublicDemoEngineerSales.stage` or any of
the existing `beginSelling`/`introduceProject`/interview-evaluation
methods — those remain entirely independent, unmodified authority. Phase 6
(Project Interview) is expected to read `matchingProposals` to know which
real project a given engineer was proposed for; nothing in this phase acts
on the record beyond storing/overwriting/reading it. Persisted (additive
JSON field, backward-compatible — a save written before this phase
restores to an empty map, not a rejected save) so the decision survives
save/reload.

## Deterministic matching

- Same `(runSeed, runtime)` → byte-identical `Engineer.profile` on every
  call (`public_demo_matching_profile_test.dart`).
- Same `Engineer` × `Project` → identical `FitBreakdown` (total and every
  sub-score) across repeated `ProjectComparisonEngine.rowFor` calls — no
  hidden RNG draw inside the adapter or Matching itself.
- A founding engineer's personality facts are stable across different
  `runSeed`s (their identity predates any playthrough seed — same
  legacy-fixture-seed technique Phase 3 already relies on).
- End-to-end: reopening "案件を見る" for the same save renders the same
  project-card content both times (`public_demo_matching_flow_test.dart`).

## Tests

New suites (34 tests, all green):

- `test/game/public_demo/public_demo_matching_profile_test.dart` (5) —
  adapter determinism, current-runtime override behavior, no fabricated
  sub-language signal, Fit total sums correctly.
- `test/game/public_demo/public_demo_matching_proposal_workflow_test.dart` (9)
  — record/no-op/overwrite/independence, stage untouched, aggregate
  month-stamping, JSON round-trip, backward-compatible legacy-save
  default.
- `test/ui/public_demo/public_demo_matching_decision_sheet_test.dart` (11)
  — hidden/raw-score non-exposure (the belt-and-suspenders full-tree walk),
  qualitative 強み/不足 rendering, propose/skip pop values, SkillSheet
  button callback, and 360×800/390×844 × TextScaler 1.0/1.3/2.0 overflow
  checks (6 cases).
- `test/ui/public_demo/public_demo_matching_flow_test.dart` (9) — full
  required player flow end-to-end (including SkillSheet open/close and
  the resulting `matchingProposals` entry), skip leaves no proposal,
  deterministic reopen, and the same 6-case viewport/TextScaler matrix
  driven through the real Sales-tab entry point.

Focused-suite result: `flutter test <the 4 files above>` — **34/34 passed**
(re-confirmed on the final HEAD SHA above, after the fixes in "Blocker
found and fixed" below).

Full-suite result: `flutter test` (all 198 files, 1918 individual tests)
on the final HEAD SHA — **1918/1918 passed, 0 failures**, exit code 0.
Existing recruitment/Finance/Month/assignment/HOME regressions are green.

## Blocker found and fixed (reported per Issue #205's own request)

The **first** full-suite run (on commit `81c6b48`, before the fix below)
reported **16 failing tests** — genuinely caused by this Phase 5 diff, not
pre-existing flakiness. Both root causes were identified, fixed, and
re-verified before any commit was described as "ready":

1. **Sales-tab empty state silently deleted (≈15 failures).**
   `_buildSalesTab`'s `hasAnyContent` check originally included the new
   `matchingCards` (`案件を見る`) list. Since that list is *always*
   non-empty (real project candidates exist for every month), this made
   `hasAnyContent` permanently `true`, so Issue #173's truthful "no current
   action" empty-state card could never render again — breaking
   `public_demo_01_home_ui_3c_density_test.dart`,
   `public_demo_sales_ui_phase1_test.dart`, and `sales_overview_screen_test.dart`
   assertions that depend on it. **Fix:** `matchingCards` was removed from
   `hasAnyContent`'s computation (with a doc comment explaining why): the
   permanently-available "案件を見る" entry point and the truthful "nothing
   else to do this month" message are not mutually exclusive and now both
   render when applicable.
2. **Exact-schema-key test broken by an intentional additive field (1
   failure).** `public_demo_recovery_aggregate_test.dart` asserted the
   workflow JSON's key set exactly — before this phase's own
   `matchingProposals` key existed. **Fix:** the expected key set was
   updated to include `'matchingProposals'`, mirroring the same test's own
   precedent comment for Phase 3's `interviewSessions` addition (both are
   "additive, unrelated to Recovery, present on every workflow JSON since
   that phase").
3. **A test-only side effect of fix #1:** the new
   `public_demo_matching_flow_test.dart`'s 360×800/textScale 2.0 viewport
   case started failing to tap the (now correctly-coexisting) empty-state
   + matching card at that combination, because the tap point had shifted
   off-screen and the test did not scroll first. **Fix:** added
   `tester.ensureVisible(...)` before the tap, matching the convention
   `public_demo_01_skill_sheet_flow_test.dart`'s `tapVisible` helper
   already established elsewhere in this suite.

All three fixes are isolated to `public_demo_01_placeholder_screen.dart`
(the `hasAnyContent` computation only), the one pre-existing test's
expected-key-set literal, and this phase's own new test file — nothing
about `MatchingEngine`, Finance, Month transition, or HOME was touched by
the fix. Re-verified: the specific previously-failing test files, then the
full 1918-test suite, both green on the final HEAD SHA (see above).

## `flutter analyze`

**No issues found.** (Run repeatedly across the session — after the
production diff, after the test diff, and again on the final HEAD SHA
after the blocker fix — clean every time.)

## `git diff --check`

**Clean** — no whitespace errors.

## Known constraints / limitations

- **Engineer availability** uses the same "not currently on an active
  assignment" (`assignedEngineerIds`) signal every other on-screen check
  already reads. It does not additionally exclude an engineer already at
  a later sales-pipeline stage (e.g. `introduced`) from being proposed for
  a *different* project — Issue #205 scoped "preserve existing workflow
  authority" as "do not change it," not "invent a new cross-pipeline
  exclusivity rule," so this was left as the minimal, additive behavior;
  Phase 6 can tighten this once Project Interview defines what "already
  spoken for" should mean.
- **No `monthlyProfit`/salary figure is shown** on the project card or
  decision sheet. `MatchingEngine.monthlyProfit` needs `Engineer.salary`,
  which `PublicDemoMatchingProfile` deliberately sets to a structural `0`
  placeholder (documented in that file) rather than sourcing a real salary
  fact not required by this Issue's field list — showing a profit figure
  built from that placeholder would misrepresent it as real, so it is
  simply not shown, consistent with the "not shown rather than invented"
  precedent Phase 4.5's SkillSheet projection already established.
- Sub-language Fit contribution is intentionally omitted (see "Why a new
  adapter" above) — an engineer's Fit here reflects only their primary
  tracked language, matching what the SkillSheet already discloses about
  them.
- The "面接通過見込み" 3-tier label is a coarse re-bucketing of the
  existing 4-tier `PlayerVisibleFit.fromScore` thresholds (excellent/good
  → 高, fair → 中, poor → 低) — not a new probability model, per Issue
  #205's explicit "Phase 5 may show only a coarse qualitative prospect ...
  without a new probability formula."

## Phase 6 handoff

- Read `PublicDemoWorkflowState.matchingProposals[engineerId]` (a
  `PublicDemoMatchingProposal?`) to find which real
  `PublicDemoProjectCandidate.id` (re-derivable via
  `PublicDemoSeededProjectGenerator.regenerate(runSeed:, projectId:)`) the
  player most recently proposed this engineer for, and in which month.
- The existing `beginSelling → introduceProject → partner/client interview
  → recordOrder` pipeline (`public_demo_sales.dart`) remains exactly as
  it was before this phase — Phase 6 is free to wire a real project
  interview onto it, or to design a new flow that reads
  `matchingProposals` directly; this phase does not presuppose which.
- `PublicDemoMatchingProfile.engineerForMatching` is available for Phase
  6 to reuse if it also needs a full domain `Engineer` for the same
  engineer/project pairing (e.g. to reuse `MatchingEngine.computeFit`
  again for interview-difficulty flavor) — no need to re-derive the same
  adapter a second time.
