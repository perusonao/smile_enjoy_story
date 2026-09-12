# SES FIRST-FUN-YEAR — Applicant→Engineer Data Preservation / SkillSheet Expansion — Result Report

Status: **Implemented, self-hardened, Codex broad review P1s addressed, tests green**

Issue: [#248](https://github.com/perusonao/smile_enjoy_story/issues/248)
PR: [#249](https://github.com/perusonao/smile_enjoy_story/pull/249)

## Audited explicit main SHA

`0b90d556b74746c2f82ac0e9111a95e93bd564b6` (`origin/main`, confirmed via
`git fetch origin && git rev-parse origin/main` before any branch work).

The working branch (`claude/ses-248-applicant-engineer-preservation-rlchfl`)
pre-existed with stale content from an earlier session (a commit already an
ancestor of `origin/main`, 834 commits behind, zero commits ahead). Per the
task's explicit instruction to build only from the latest `origin/main`, and
to not incorporate PR #247's branch/changes, it was reset with
`git checkout -B claude/ses-248-applicant-engineer-preservation-rlchfl
origin/main` before any new work — a safe reset since the branch carried no
unique commits. PR #247 was never fetched, merged, or referenced.

`docs/reports/SES_DATA-ASSET_FULL-INVENTORY_2026-09-12.md` (the "Source
audit" the issue names) **does not exist anywhere in this repository** —
checked on `origin/main` and searched across every remote branch. Per the
issue's own instruction ("過去レポートより現在のコードをauthorityとして優先"),
Phase 0 below is a fresh, direct code audit, not a review of that
non-existent document.

## Final branch / PR / HEAD

- Branch: `claude/ses-248-applicant-engineer-preservation-rlchfl`
- Base: `main` (`0b90d556b74746c2f82ac0e9111a95e93bd564b6`)
- PR: https://github.com/perusonao/smile_enjoy_story/pull/249
- PR HEAD before this Codex-review-response round: `b18bf4c32849e756d409501c50403caa5e5d979e`
- Final HEAD SHA (after this round — Codex broad review P1 fixes): *(see
  chat's final report for the exact value confirmed via `pull_request_read`
  after push)*

## Codex broad review response (this round)

PR #249's one broad Codex review (already run once, per the issue's review
policy — **not re-run in this round**) raised two P1 findings, both fixed
here in the same PR:

1. **[Review thread `PRRT_kwDOT2htY86hrzq4`](https://github.com/perusonao/smile_enjoy_story/pull/249#discussion_r3994580195)
   — an id shape alone is not proof of provenance.** A save created before
   CORE-GAMEPLAY Phase 2 (seeded recruitment) can still carry a *pending*
   applicant whose id is already shaped like
   `recruitment-<month>-<medium>-<slot>` — the pre-Phase-2 fixed/cyclic
   template pool (`PublicDemoRecruitmentCalculation`'s old default) used the
   exact same id scheme. Blindly trusting `regenerateDomainApplicant` for
   such an id would attach today's seed-generated candidate's language/
   skill/tech to a completely unrelated stored applicant. See "Phase 1
   fix, round 2" below for the resolution.
2. **[Review thread `PRRT_kwDOT2htY86hrzq9`](https://github.com/perusonao/smile_enjoy_story/pull/249#discussion_r3994580200)
   — governing plan not synced.** `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`
   did not record Issue #248/PR #249's completion. Fixed by adding a
   2026-09-12 Update history entry (First Fun Year priority, Current
   execution order, and Prioritized backlog table structure all left
   unchanged, per that document's own plan-maintenance rule and per this
   task's explicit instruction).

## Phase 0 — Fresh Audit (traced against current code, not the missing report)

Traced the full path: `ApplicantGenerator` → `PublicDemoSeededRecruitmentGenerator`
(`PublicDemoApplicant` projection) → Recruitment Interview → Offer → Join →
`PublicDemoEngineerRuntime.fromApplicant` (Engineer materialization) →
Employee roster / SkillSheet → Sales/Matching (`PublicDemoEngineerProjectFit`).

### 1. Fields that exist at generation but never reach `PublicDemoApplicant`

`PublicDemoSeededRecruitmentGenerator._project()`
(`lib/game/public_demo/public_demo_recruitment_candidate_generator.dart`)
generates a full domain `Applicant` (age, `ApplicantType`, `mainLanguage`,
full `languageSkills` map, `subLanguages`, `techSkills`, `PersonalityTraits`,
`HiddenParameters`, education/major/workStyle/qualifications) but only
projects `name`, a derived `resumeSummary` string, `interviewScore`,
`acceptanceScore`, `salesSkillFit` (= main-language `actualSkill`),
`experienceMonths` (= aggregate total), and a rescaled
`requestedMonthlySalary` onto `PublicDemoApplicant`.

**This is not actually data loss.** `PublicDemoSeededRecruitmentGenerator
.regenerateDomainApplicant({runSeed, applicantId})` (already existing,
already used by the interview step) recovers the *exact* full domain
`Applicant` purely from `(runSeed, id)` for every id this generator produced
(`recruitment-<month>-<medium>-<slot>`). Nothing generation-time is
irrecoverable for the applicant population every current playthrough
actually produces.

### 2. Fields present on `PublicDemoApplicant` that are dropped at Engineer materialization — **the core defect this issue targets**

`PublicDemoEngineerRuntime.fromApplicant` (pre-fix,
`lib/game/public_demo/public_demo_engineer_runtime.dart`) **unconditionally
hard-coded `primaryLanguage: ProgrammingLanguage.java` and `techSkills: const
TechSkillLevels.zero()` for every experienced hire**, regardless of which
language/tech profile `ApplicantGenerator` actually produced them with, and
never added the language to `confirmedLanguages` (left empty).

This one gap silently replaced every hired person's real technology identity
with a generic placeholder, and it was **already visibly wrong in the running
app**, not merely a latent inconsistency:

- The employee roster's own skill bar
  (`_primarySkillDisplayFor` → `languageLabels[runtime.primaryLanguage]`,
  `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`) showed **every
  single joined engineer as "Java"**, no matter what language they were
  hired for.
- `PublicDemoSkillSheetDisplayFactory.create`'s `primaryLanguageLabel` and
  `experienceComparisons` are gated on `confirmedLanguages.contains(...)` —
  with `confirmedLanguages` always empty for an experienced hire, **every
  employee's SkillSheet showed no primary-language chip and no "実経験 vs
  SkillSheet記載" row at all**, and `techSkillChips` (gated on
  `techSkills.>0`) was **always empty**.
- `PublicDemoEngineerProjectFit._placeholderEngineerFor` filters
  `languageSkills` down to only `confirmedLanguages` entries before calling
  the shared `MatchingEngine.computeFit` — so **every experienced hire's
  language-fit dimension in Matching was scored against zero confirmed
  language experience**, and `techSkills` was always the zero object,
  independent of the actual hire's technology profile.

Salary and aggregate experience were **not** affected: `applicant
.acceptedMonthlySalary`/`salaryForMonth` (`PublicDemoSalary
.currentMonthlySalaryFor`) and `PublicDemoEngineerRuntime
.totalItExperienceMonths` (already fixed for a related concern in PR #212)
both already carry the real, single-authority value through join and
materialization unchanged.

### 3. What Engineer/SkillSheet can currently hold (no schema gap)

`PublicDemoEngineerRuntime` already models `primaryLanguage`,
`languageSkills` (full `LanguageSkill` including `actualExperienceMonths`/
`displayedExperienceMonths`/`actualSkill`), `techSkills`
(`TechSkillLevels`), `confirmedLanguages`, and `totalItExperienceMonths`.
Every field #2 needed to fix was already present in the save schema; the
defect was purely that `fromApplicant` never populated it from the data that
was already available.

### 4. Save/reload

`PublicDemoEngineerRuntime.toJson`/`fromJson` were already correct and
already round-trip every field above. No change was needed or made to
either method.

### 5. Authority conflicts

None found. Single authorities confirmed:

- **Salary**: `PublicDemoApplicant.acceptedMonthlySalary`/`salaryForMonth`
  via `PublicDemoSalary.currentMonthlySalaryFor` — the only salary source
  read anywhere (roster, SkillSheet, payroll).
- **Experience**: `PublicDemoApplicant.experienceMonths` at hire time →
  `PublicDemoEngineerRuntime.totalItExperienceMonths` (carried once, at
  materialization, never re-derived elsewhere).
- **Skill**: `PublicDemoApplicant.salesSkillFit` → `LanguageSkill
  .actualSkill` under `primaryLanguage` → `runtime.actualCapability`. This
  fix does not touch this number, only which language it is attributed to.
- **Language**: previously **no single authority reached the runtime at
  all** for an experienced hire (hard-coded placeholder). This fix makes
  the domain `Applicant.mainLanguage` (recoverable via
  `regenerateDomainApplicant`) the authority, consistent with how the
  interview step already treats it.

### 6. Maximum safe range without a schema change

Everything in Phase 1/2 below. **No save-schema change was made or is
needed.** `PublicDemoEngineerRuntime`'s JSON shape is byte-for-byte
unchanged (verified by a new round-trip test asserting the exact key set).

## Phase 1 — Data Preservation (implemented)

`lib/game/public_demo/public_demo_engineer_runtime.dart`:
`PublicDemoEngineerRuntime.fromApplicant` gained one new **optional**
parameter, `Applicant? sourceApplicant` — the full domain `Applicant` this
hire was actually generated from, recovered the exact same way the
interview step already does
(`PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant({runSeed,
applicantId})`, no new save data, purely re-derived on demand).

- **Experienced hire, `sourceApplicant` available** (every hire the
  seeded generator produces — the only generator normal play uses):
  `primaryLanguage` = `sourceApplicant.mainLanguage`, `languageSkills` =
  `{mainLanguage: sourceApplicant.skillFor(mainLanguage)}` (the real
  generated `LanguageSkill`, whose `actualSkill` is, by construction,
  identical to `applicant.salesSkillFit`), `confirmedLanguages` =
  `{mainLanguage}` (now truthful, since the language itself is now real —
  the pre-existing "never fabricate a confirmed language" concern
  documented on `confirmedLanguages` specifically named the *hard-coded
  Java* case as the risk, which no longer applies), `techSkills` =
  `sourceApplicant.techSkills` (the real generated tech-domain profile).
- **Experienced hire, `sourceApplicant` unavailable** (the hand-authored
  legacy pool `app-01`/`app-02`/`free-template-*`, which predates
  `PublicDemoSeededRecruitmentGenerator` and cannot be regenerated by id):
  **byte-for-byte the exact pre-existing behavior** — hard-coded Java,
  empty `confirmedLanguages`, zero `techSkills`. Verified directly by test.
- **Inexperienced hire**: **unchanged regardless of `sourceApplicant`** —
  their résumé genuinely names no language at all
  ("ITスクール修了・実務未経験"), so assigning them the flavor applicant's
  incidental main language would itself be a fabrication, not a fix.
- `hidden` (personality/growth parameters) and `totalItExperienceMonths`
  are **deliberately left untouched** — see "Intentionally not preserved"
  below.

Call sites updated (`lib/game/public_demo/public_demo_aggregate.dart`,
the only two production call sites of `fromApplicant`): both now pass
`sourceApplicant: PublicDemoSeededRecruitmentGenerator
.verifiedSourceApplicantFor(runSeed: state.runSeed, applicant: applicant)`.
`state.runSeed` is invariant for the whole playthrough (existing
guarantee), so this is deterministic and safe to call at any point join
can occur (May, June, or a later recovery-loop join).

### Phase 1 fix, round 2 (Codex P1): provenance verification, not id-only trust

The initial implementation called `regenerateDomainApplicant` directly,
trusting the id shape alone. Codex's broad review correctly identified that
this is unsafe for a save created before CORE-GAMEPLAY Phase 2: the
pre-Phase-2 fixed/cyclic template pool used the exact same
`recruitment-<month>-<medium>-<slot>` id scheme, so a *pending* applicant
from such a save could have an id today's generator would happily
regenerate a candidate for — a candidate that is, by construction, an
unrelated person.

`lib/game/public_demo/public_demo_recruitment_candidate_generator.dart`
gained two new methods on `PublicDemoSeededRecruitmentGenerator`:

- `regenerateProjectedApplicant({runSeed, applicantId})` — reconstructs the
  exact `PublicDemoApplicant` `generate()` would have produced for this
  id's own slot, purely from `(runSeed, id)`. Implemented by extracting the
  same per-slot branch `generate()` already uses (same `_rollsInexperienced`/
  `_pickApplicant`/`_project`/`_inexperiencedCandidate` calls) — no new
  generation formula.
- `verifiedSourceApplicantFor({runSeed, applicant})` — calls the above and
  compares every résumé-visible field (`name`, `resumeSummary`,
  `experienceMonths`, `salesSkillFit`, `interviewScore`, `acceptanceScore`,
  `requestedMonthlySalary`) against what is *actually stored* on
  `applicant`. Only when **every** field matches does it return the
  verified domain `Applicant` (via `regenerateDomainApplicant`); otherwise
  it returns `null`, and the caller falls back to the exact pre-existing
  placeholder behavior — identical to the "no `sourceApplicant`" path
  already described above.

No new save-schema/provenance field was added — this is a pure,
re-derived-on-demand check, matching the existing `regenerateDomainApplicant`
design (nothing about it is persisted). A genuinely fresh, seed-generated
applicant always verifies (its stored fields are exactly what `_project()`
derived from the same seed in the first place), so the happy path this
issue exists for is unaffected; only an id-shape coincidence with
mismatched stored data now safely falls back.

**This one change automatically fixes the roster skill bar, the
SkillSheet's primary-language chip / experience comparison / tech-skill
chips, and Matching's language and tech-domain fit dimensions — none of
those UI/Matching call sites needed any change themselves, since they were
already correctly wired to read `confirmedLanguages`/`languageSkills`/
`techSkills`; they were just never being fed real data.**

### Continuity verified: 応募者A → 採用 → 社員A → SkillSheet → 営業 → 案件Matching

New test
`test/game/public_demo/public_demo_issue248_applicant_engineer_continuity_test.dart`
drives the exact production path (`recruit` → `completeInterview` →
`acceptOffer` → pre-entry sales chain → `closeApril`/`closeMay`) for a
seeded engineer-medium hire and asserts the resulting
`PublicDemoEngineerRuntime` (read from `state.runtimeFor(id)` after the real
join) has the same `primaryLanguage`/`techSkills` as the independently
regenerated domain `Applicant`, and that `actualCapability` still equals the
original `applicant.salesSkillFit` — i.e. the same person's technology and
skill survive the entire pipeline, not a generic replacement.

## Phase 2 — SkillSheet / Recruitment UX (implemented)

**Employee/SkillSheet side**: no new UI code was needed. Phase 1 alone
makes `PublicDemoSkillSheetDisplayFactory` and the employee roster's skill
bar show the real primary language, tech-skill chips, and experience
comparison for every future hire — capability that already existed in the
UI layer and was simply never fed real data before. `_employeeRosterCard`
already shows 経験/月給/単金 (Issue #235, prior work) and is unchanged here.

**Recruitment side** (`ac(i)` in
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`): before this
change, an applicant card showed only name/résumé text/status until *after*
the player spent an interview action — `requestedMonthlySalary` only
appeared once `stage == interviewed`, even though it is explicitly
documented (`docs/reports/SES_CORE-GAMEPLAY_Phase2_Random-Recruitment_Result.md`,
"Visible vs. interview-hidden fields") as a non-hidden, résumé-level fact
available "at application time" — only `interviewScore`/`acceptanceScore`/
`salesSkillFit` genuinely require the interview. This was a presentation
gap, not a deliberate gate.

Added one row, shown from the applicant's very first card render (`applied`
stage onward): `経験 <formatExperience> ｜ 希望給与/確定給与 <salary>万円` —
both values read verbatim from existing `PublicDemoApplicant` fields, no new
field, no schema change. The now-redundant salary line at the `interviewed`
stage was removed (the fact is shown exactly once). This lets the player
compare experience and salary across multiple candidates *before* spending
an interview action on any of them, directly serving "応募者を比較して採用し".

No hidden score, no new stat, no Finance/Payroll/Matching formula change,
no HOME change, no 5-tab structure change.

## Guardrail compliance

- No new capability/stat invented — only real, already-generated values
  (`mainLanguage`, `techSkills`, `experienceMonths`, `requestedMonthlySalary`)
  are wired through.
- No hidden score displayed — `interviewScore`/`acceptanceScore`/
  `salesSkillFit` remain gated behind the interview exactly as before.
- Finance/Payroll calculation authority unchanged.
- Matching outcome formula (`MatchingEngine.computeFit`) unchanged — only
  its *input* (`confirmedLanguages`/`languageSkills`/`techSkills`) is now
  truthful instead of a placeholder.
- `ordered != assigned` unchanged.
- No Main Game/Public Demo full unification, no Parallel Sales, no Trade
  Flow, no late-game economy change, no unrelated HOME/5-tab redesign.

## Intentionally not preserved (and why)

- **`hidden` (`HiddenParameters`: `growthPotential`/`stressTolerance`/
  `retention`/`projectInterviewSkill`/`turnoverIntent`)** — left at the
  existing fixed defaults for every hire, even though a real generated
  value is recoverable via `sourceApplicant.hidden`. `growthPotential`
  directly drives EG-2's monthly growth curve; wiring in a real,
  per-hire-varying value would be a substantive, unreviewed **balance**
  change (every future hire's long-term growth trajectory would shift),
  not a data-preservation fix, and is outside this issue's explicit P1
  list (experience/language/skill/salary). Recommended as its own,
  separately-reviewed follow-up if wanted.
- **`resumeSummary` structural fields (age/`ApplicantType`/`subLanguages`)**
  — already visible to the player as free text on the résumé; not
  restructured into new UI fields, per "情報を増やすこと自体が目的ではない"
  and to avoid touching more surface than the issue's priority list
  requires.
- **Career history entries prior to join** — `PublicDemoEngineerRuntime
  .careerHistory` has no pre-join equivalent on `PublicDemoApplicant`
  (nothing to carry forward; not a loss).

## Schema impact

**None.** `PublicDemoEngineerRuntime.toJson()`'s key set is unchanged
(verified by test) and `fromJson` is unchanged. `PublicDemoApplicant`'s
schema is unchanged. `schemaVersion` remains `1`.

## Legacy save behavior

Unaffected. `fromApplicant` is only ever invoked at the moment of a *new*
join — never at load time — so an already-materialized `PublicDemoEngineerRuntime`
in an existing save reloads exactly as before via the unchanged `fromJson`.
For a legacy save still mid-game with an unjoined `app-01`/`app-02`/
`free-template-*` applicant, `regenerateDomainApplicant`/
`regenerateProjectedApplicant` return `null` for those ids (unparseable —
verified by test), so any future join for them reproduces the exact
pre-existing hard-coded-Java behavior — zero behavior change.

**Round 2 addition**: a legacy save whose pending applicant's id *does*
parse as `recruitment-<month>-<medium>-<slot>` (the pre-Phase-2 template
pool used this same scheme) is now also safe: `verifiedSourceApplicantFor`
rejects the regenerated candidate unless its projected profile matches the
actually-stored applicant field-for-field, so such an applicant still joins
with their own real salary/experience and the same safe Java/zero-tech
placeholder every pre-this-issue save already used — never an unrelated
regenerated identity. Verified end-to-end by test, including a
save→reload immediately after join and a duplicate/retry `closeMay` call.

## UI changes

- `ac(i)` (recruitment/sales tab applicant card): new "経験 ｜ 希望/確定給与"
  row from the first render onward; removed the now-redundant duplicate
  salary line at the `interviewed` stage.
- No change to the 5-tab/HOME structure, navigation, or any other screen.
- `docs/reports/screenshots/ses-core-gameplay-phase2-recruitment-seed{A,B}-{360x800,390x844}.png`
  were regenerated by the pre-existing `public_demo_seeded_recruitment_visual_test.dart`
  (which writes these files as a side effect of running) and now show the
  new row; no other screenshots changed.

## Tests

- `flutter analyze` (project-wide): **No issues found.**
- `test/game/public_demo/public_demo_issue248_applicant_engineer_continuity_test.dart`
  (**11 tests**, +4 in this round) — factory-level language/techSkills/
  confirmedLanguages continuity, legacy-fixture no-op, inexperienced-hire
  no-fabrication, toJson key-set/round-trip regression, SkillSheet-projection
  surfacing, Matching-input surfacing, a full production
  recruit→interview→offer→pre-entry-sales→closeApril/closeMay→reload
  end-to-end check, and (round 2, Codex P1) four regression tests: a
  genuinely fresh seed-generated applicant still verifies and uses its real
  source (happy path unaffected); an id-only match with a mismatched
  stored profile is rejected by `verifiedSourceApplicantFor`;
  `fromApplicant` falls back to the exact pre-existing placeholder for such
  a mismatched legacy-style applicant; and a full production join pipeline
  test for that same legacy-style applicant, including save→reload and a
  duplicate/retry `closeMay` call, confirming salary/experience authority
  stays theirs while the placeholder technology profile is preserved.
- `test/ui/public_demo/public_demo_issue248_recruitment_comparison_display_test.dart`
  (5 tests, unchanged this round) — the new row is present pre-interview at
  360×800/390×844 × TextScaler 1.0/1.3 with no overflow, and the fact is
  shown exactly once (not duplicated) once interviewed.
- `flutter test test/game/public_demo`: **872 passed**, 0 failed (861 +
  11 new, after the round-2 provenance fix).
- `flutter test test/ui/public_demo`: full suite re-run after the round-2
  fix — *(see chat's final report for the exact count; the fix only
  touches `lib/game/public_demo/`, no UI file, so no change to Phase 2's
  own UI test results was expected or found)*.
- `git diff --check`: clean.

## Unresolved issues / follow-ups

- `HiddenParameters` continuity (growth-affecting) intentionally deferred —
  see "Intentionally not preserved" above. Recommend a separate,
  explicitly-scoped balance-review task if the team wants per-hire growth
  variance instead of the current uniform default.
- The missing `SES_DATA-ASSET_FULL-INVENTORY_2026-09-12.md` report the
  issue names as its source audit does not exist in the repository at all
  (checked on `origin/main` and every remote branch) — flagged here rather
  than silently working around it.
- Both Codex broad review P1 findings on PR #249 are resolved as of this
  round (provenance verification; governing plan sync) — no other P0/P1/P2
  is outstanding on this PR. Per the review policy, the broad review is not
  re-run in this round.

## Recommended next phase

Per `docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`'s
existing execution order, continue with the already-queued P1 items
(project/order/assignment continuity, recruitment lifecycle clarity,
month-start recommended action) rather than opening new scope here. If the
team wants employee growth to also vary per-hire based on real generated
`HiddenParameters`, scope that as its own reviewed balance task.
