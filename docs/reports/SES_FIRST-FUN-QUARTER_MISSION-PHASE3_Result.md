# SES First Fun Quarter — Mission Phase 3 (SkillSheet Understanding / Editing) — Result Report

Status: **COMPLETE**

Governing docs: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` (Update
history, 2026-09-14 Phase 3 entry) / `docs/design/
SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md` §6.

## Base main SHA

- Task-specified expected SHA: `4efb4787b677ed75a5fdb3493c88ddf7f3555e3c`
- `git fetch origin main` at session start resolved `origin/main` to exactly
  `4efb4787b677ed75a5fdb3493c88ddf7f3555e3c` — **exact match, no drift.**
  This is PR #266's merge commit (Mission System Phase 2 — Progressive
  Onboarding).
- `main` Fast CI run #703 (workflow run id `34842704246`, head SHA
  `4efb478...`) was **in_progress** at Fresh Audit start, per task
  instruction ("Fast CI実行中ならFresh Auditは進めてよい"). Re-checked before
  starting production implementation: run #703 completed with
  `conclusion: success`. No unrelated failure to triage.
- Working branch `claude/skillsheet-editing-phase3-4jxr6a` created fresh from
  `origin/main` at that SHA.

## Fresh Audit findings (before implementation)

Ordered per the task's own 12-point checklist:

1. **Public Demo SkillSheet display fields** — `PublicDemoSkillSheetSheet` /
   `PublicDemoSkillSheetBody` (`public_demo_skill_sheet_sheet.dart`,
   `_sections.dart`) render: name/primary-language/status header, summary
   band, 基本プロフィール (ability chips), 技術スキル (tech-skill chips,
   English-labeled before this phase), 経験 (actual-vs-displayed experience
   comparison + industry experience + career history), 案件/参画情報, and
   営業・面談プロフィール (unchanged #117 shape). All purely derived from
   `PublicDemoEngineerSales`/`PublicDemoEngineerRuntime`/`PublicDemoAssignment`
   — no field invented for display.
2. **English labels, all locations found in Public Demo**:
   - `_techSkillDomainLabels` (`public_demo_skill_sheet_display_projection
     .dart`) — Frontend/Backend/Leader/Manager/Network/Infra — **private to
     this file**, exactly the target the task's example list names. Fixed
     in this phase.
   - The **shared** `techDomainLabels` (`lib/ui/widgets/labels.dart`) — read
     by 4+ main-game screens (`project_detail_screen.dart`,
     `engineer_detail_screen.dart`, `engineer_list_screen.dart`,
     `applicant_detail_screen.dart`) AND, via `fitDetailLabel`, by Public
     Demo's own Matching-screen Fit-reason line
     (`public_demo_matching_screen.dart`'s `_ReasonLine`). **Not changed** —
     see Design Decision #1 below.
   - `PublicDemoAggregate._technologiesFor` (career-history "technologies"
     list, English) — verified **never rendered anywhere in the UI**
     (`grep -rn '\.technologies\b'` finds only the model field, no reader).
     Not a visible label; left alone.
3. **`displayedExperienceMonths`** — lives on `LanguageSkill`
   (`domain/models/language_skill.dart`), already asserted `>= 0`, already
   serialized inside `PublicDemoEngineerRuntime.languageSkills` →
   `PublicDemoState.engineerRuntimes` → the existing save codec. **Already
   fully persisted before this phase** — no schema work needed to make the
   value itself durable.
4. **`actualExperience`/`actualCapability`** — `actualCapability` is a getter
   (`languageSkills[primaryLanguage]?.actualSkill ?? 0`), gates
   `isReadyForFieldSales`/field-sales entry. Verified via
   `PublicDemoGrowthEngine.calculate`'s own comment
   ("SkillSheet-facing displayed experience intentionally remains intact")
   that growth already keeps actual/displayed independent — this phase's
   editor preserves that same separation for player-driven edits.
5. **Fit calculation** — `PublicDemoEngineerProjectFit.compute` →
   `MatchingEngine.computeFit`. Confirmed by reading the engine directly:
   the experience dimension reads `profile.totalItExperienceMonths`
   (ground truth), the skill dimension reads `profile.skillFor(language)
   .actualSkill` — **`displayedExperienceMonths` is never read by Fit**.
   Editing it is therefore inert to Fit/Matching by construction, not just
   by convention.
6. **sales/proposal/interview values** — grepped every
   `displayedExperienceMonths` call site outside Public Demo's own SkillSheet
   display code: all are either main-game-only (`prologue_screen.dart`,
   `recruitment_engine.dart`, `recommendation_engine.dart`,
   `applicant_generator.dart` — unrelated pipeline, not touched) or Public
   Demo's own candidate-generation display text
   (`public_demo_recruitment_candidate_generator.dart`, pre-hire résumé
   card). None of Public Demo's sales/proposal/interview evaluation code
   (`PublicDemoEngineerSales.evaluateInterview`,
   `PublicDemoInterviewEvaluator`, `PublicDemoProjectInterview`) reads
   `displayedExperienceMonths` — confirmed by reading those files; they key
   off `actualCapability`/`interviewProfile` only.
7. **Save codec** — `PublicDemoSaveCodec` (`schemaVersion == 1`, unchanged by
   this or the prior two Mission phases). Every prior field this phase
   depends on or adds follows the same additive-with-legacy-default
   convention already established (`confirmedLanguages`,
   `totalItExperienceMonths`, `founderFollowUpMonth`,
   `interviewRecordProjectId`, …) — no precedent for a schema bump exists
   in this file's own history for an additive scalar/bool.
8. **Applicant SkillSheet sharing** — `PublicDemoCandidateSkillSheetSheet` /
   `...DisplayFactory` (pre-hire) are structurally separate classes/files
   from the employee `PublicDemoSkillSheetSheet` /
   `...DisplayFactory`, sharing only `SkillSheetMetricRow` (a stateless
   label/value row primitive) and `formatExperience` — neither of which this
   phase's edit changed. **Zero overlap** with the new edit surface; the
   applicant sheet has no `displayedExperienceMonths` concept at all
   (`PublicDemoApplicant` only carries one flat `experienceMonths` scalar,
   per that factory's own class doc on why per-language breakdown is
   deliberately absent pre-hire).
9. **Main Game shared label/helper** — see finding #2. The one genuine
   shared surface this phase touches at all is `PublicDemoEngineerRuntime
   .maxDisplayedExperienceInflationMonths`, which is a **new, Public-Demo-
   only constant that copies the main game's existing
   `SkillSheet.maxExperienceInflationMonths` VALUE (36)**, not a shared
   symbol — no import coupling between the two files.
10. **Mission resolver connection** — `PublicDemoMissionResolver.resolve`
    reads only `PublicDemoWorkflowState`/`PublicDemoState` (already
    documented as the System's "only authority-reading surface"). Confirmed
    its own stated discipline ("`locked` never gates a real domain action")
    before deciding how to slot in the new mission — see Design Decision #2.
11. **SkillSheet confirmation authority** — `PublicDemoWorkflowState
    .startSkillSheetReview` (`waiting` → `skillSheet`, called from
    `_openSkillSheetReview`'s explicit confirm button only). Completely
    unchanged by this phase; the new edit command is a parallel, independent
    authority that never reads or writes `stage`.
12. **Currently editable fields (pre-Phase-3)** — none, in Public Demo. The
    main game (`engineer_detail_screen.dart`'s `_editSkillSheet`) already has
    a full SkillSheet editor (language experience + Backend/Leader levels)
    with an attached trust/risk system (`SalesEngine.riskFor`, `SkillSheetRisk
    {honest, moderate, aggressive, extreme}`, `inflationDetails`,
    `employeeReaction`) that Public Demo has never had any equivalent of.
    This is important prior art (see Design Decisions #3/#4) but its
    risk/penalty mechanic is explicitly **not** ported in this phase — see
    Safety section.

## Design decisions

1. **Label localization scope: Public-Demo-local map only, shared
   `techDomainLabels` untouched.** The Implementation Plan's own §6.1 assumed
   editing both maps was safe; the Fresh Audit found the shared map's real
   main-game footprint (4 screens + Public Demo's own Matching Fit-reason
   line) too wide for this task's explicit "SkillSheet only" scope. Per
   this task's own "コードを正として計画を修正する" instruction, only
   `_techSkillDomainLabels` (private to
   `public_demo_skill_sheet_display_projection.dart`) was translated.
   `DB` was kept as-is (already common even in Japanese SES usage, matches
   how the plan itself flagged it as "conventionally kept"). The shared map
   and its main-game/Matching-screen readers are a documented candidate for
   a future, separately-scoped localization pass.
2. **Mission chain placement: `editSkillSheet` inserted between
   `viewSkillSheet` and `beginSelling` in `publicDemoAprilMissionChain`
   (April chain is now 8 steps).** This changes the **presentational**
   locked/available status shown for `beginSelling` immediately after only
   confirming the SkillSheet (it now shows `locked` until the edit is
   genuinely saved, instead of `available`) — a deliberate, documented
   change to one existing Phase-1 unit-test's assertions (see Tests below).
   This does **not** change any real domain permission: the resolver's own
   pre-existing rule ("`locked` never disables a real domain action") is
   unchanged, and `beginSelling`'s own precondition
   (`PublicDemoWorkflowState.beginSelling`'s stage-set check) was not
   touched — a player can still press "営業開始" without ever opening the
   edit sheet; the Mission tile simply keeps showing `beginSelling` as
   completed the instant `stage` reaches `selling`, exactly like the
   existing "authority regression pin" test already demonstrates for
   `winOrder`/`assignToProject` completing simultaneously out of the naive
   chain order.
3. **Editable scope: primary language only, whole-year steps.** The
   Implementation Plan's own §6.2 sketched a per-language editor; the Fresh
   Audit found Public Demo's SkillSheet only ever surfaces one confirmed
   language's experience comparison per employee in practice
   (`PublicDemoSkillSheetDisplayFactory`'s own "only a confirmed language"
   rule), so a multi-language UI would have no second real target to point
   at. The editor also mirrors the main game's own `_editSkillSheet`
   dialog's year-stepper shape (`adjust(...)`, `v * 12` on save) rather than
   inventing a second interaction convention for the same concept.
4. **Clamp bound: reuse, not invent.** §6.2 left the inflation ceiling as an
   open product question. Resolved by reusing the main game's existing
   `SkillSheet.maxExperienceInflationMonths` (36 months) **value**, exposed
   as the new, Public-Demo-only
   `PublicDemoEngineerRuntime.maxDisplayedExperienceInflationMonths`
   constant — never a second, independently-tuned balance number.
5. **UX naming: "スキルシートを編集" / "営業用プロフィール".** Chosen from the
   task's own candidate list. Copy states plainly what changes (表示経験/
   営業用プロフィール) and what does not (実際の実務経験や実力), matching the
   task's "経歴詐称を無条件に推奨する表現は禁止" constraint — no wording
   frames inflating the number as advantageous or risk-free.
6. **"実力" naming: left unchanged, no supplementary label added.** The
   Fresh Audit confirmed `actualCapability` ("実力") and the interview
   profile's `skillFit` ("案件スキル適合") are already two distinctly-worded,
   separately-displayed numbers in the existing UI (e.g. the field-sales
   lock banner: "営業開始には実力 60 以上が必要です（現在 52）。" vs. the
   SkillSheet's own "案件スキル適合" row) — no observed confusion between
   them in the existing copy, so the task's own "必要なら" (optional)
   supplementary label was judged unnecessary. No capability-model change of
   any kind was made.

## Persistence authority

- **`displayedExperienceMonths`**: reused the existing `LanguageSkill` field
  and its existing round-trip through `PublicDemoEngineerRuntime`/
  `PublicDemoState`. No schema bump.
- **`PublicDemoEngineerSales.salesProfileEditConfirmed`** (new, additive
  `bool`, default `false`): the one new persisted field this phase adds.
  **Why a dedicated field, not a pure derivation**: the task's own
  same-value edge case forced the decision — deriving "was this SkillSheet
  ever edited" from a diff against the pre-edit value would itself require
  persisting a pre-edit baseline (no less a new field than this flag), and
  would incorrectly read a genuine "I reviewed this and re-saved the exact
  same number" action as *not* having happened. A plain confirmation flag
  is the more honest domain fact: "the player explicitly saved this
  SkillSheet's sales-facing profile at least once," independent of whether
  the number moved. It is not "Mission-only" plumbing — it is a real,
  player-visible fact about this engineer's SkillSheet (a future phase
  could, for instance, show a "編集済み" badge from the same field).
  `fromJson` defaults it to `false` when absent, matching every other
  additive field's own convention on this class (`founderFollowUpMonth`,
  `confirmedLanguages`, `interviewRecordProjectId`, …) — no schemaVersion
  bump, verified by a dedicated legacy-JSON test that strips the key
  entirely and confirms a clean `false` fallback with no crash.

## Mission authority

- `PublicDemoMissionId.editSkillSheet` (new), inserted into
  `publicDemoAprilMissionChain` between `viewSkillSheet` and `beginSelling`
  (chain is now 8 steps).
- Completion: `anyEngineer((e) => e.salesProfileEditConfirmed)` — company-
  level, mirroring every other mission in this resolver.
- Never derived from the raw stage or from opening the edit sheet — only
  from a genuine `PublicDemoAggregate.confirmSkillSheetEdit` call actually
  having run (Save button only; Back/barrier-dismiss on the edit sheet
  resolves to `null` and the caller no-ops on `null`).
- Phase 1's existing authority discipline is unchanged: no `.index`
  comparisons were touched, `passClientInterview` still reads
  `hasGenuineInterviewRecord`, `assignToProject` still reads the current
  month's `assignedEngineerIds` — this phase only *adds* one new map entry
  and one new chain slot, it does not rewrite any existing branch.

## Changed files

**Domain / game layer** (all under `lib/game/public_demo/`, no shared
main-game file touched):
- `public_demo_engineer_runtime.dart` — new
  `maxDisplayedExperienceInflationMonths` constant.
- `public_demo_state.dart` — new `updateDisplayedExperience(...)`.
- `public_demo_sales.dart` — new `salesProfileEditConfirmed` field
  (+ copyWith/toJson/fromJson).
- `public_demo_workflow_state.dart` — new `confirmSkillSheetEdit(...)`.
- `public_demo_aggregate.dart` — new `confirmSkillSheetEdit(...)` (the one
  production entry point, wires state + workflow atomically).
- `public_demo_mission_resolver.dart` — new `editSkillSheet` mission id +
  chain slot + completion rule.

**UI layer:**
- `public_demo_skill_sheet_edit_sheet.dart` (new) —
  `PublicDemoSkillSheetEditSheet`.
- `public_demo_01_placeholder_screen.dart` — new `_openSkillSheetEdit`
  method; new "スキルシートを編集" roster button
  (`stage != waiting`, independent of the field-sales capability gate).
- `public_demo_mission_screen.dart` — new `PublicDemoMissionCopy` entry for
  `editSkillSheet`.
- `public_demo_skill_sheet_display_projection.dart` — `_techSkillDomainLabels`
  localized to Japanese (Frontend/Backend/Leader/Manager/Network/Infra;
  `DB` kept).

**Docs:**
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — Update history
  entry.
- `docs/design/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md`
  — §6 status + two "superseded at implementation time" notes.

**Tests** (all under `test/game/public_demo/` and `test/ui/public_demo/`):
- `public_demo_skill_sheet_edit_test.dart` (new, domain) — save authority,
  clamping (ceiling + floor), engineer A/B independence, unknown-id no-op,
  `salesProfileEditConfirmed` semantics (default/same-value/never-set-by-
  other-commands), save/reload round trip, legacy-missing-key default,
  malformed-negative-value rejection.
- `public_demo_skill_sheet_edit_sheet_test.dart` (new, widget) — initial
  values, stepper clamp at both bounds, save/cancel return values, 360×800/
  390×844 × TextScaler 1.0/1.3 overflow matrix.
- `public_demo_mission_resolver_test.dart` — 1 existing test updated (chain
  reorder), 3 new tests (edit completes the mission / same-value counts /
  cancel does not count).
- `public_demo_01_skill_sheet_flow_test.dart` — 3 new integration tests
  (entry-point gating, save leaves stage/interview-profile untouched +
  cancel leaves everything untouched, Mission-screen tile reflects
  confirm/cancel).
- `public_demo_skill_sheet_display_projection_test.dart` — 1 new regression
  test pinning the localized labels.
- `public_demo_mission_screen_test.dart` /
  `public_demo_mission_appbar_entry_test.dart` — progress-count strings
  updated 7→8 for the new chain length; one comment corrected for the new
  front-index meaning.
- `test_support/public_demo_recovery_test_helpers.dart` —
  `publicDemoAdvanceEngineerToOrdered` now also calls
  `confirmSkillSheetEdit` so every existing "full chain complete" pin across
  the suite keeps passing without per-test changes.

## Tests

- `flutter analyze` (whole project): **No issues found.**
- `flutter test test/game/public_demo` **and**
  `flutter test test/ui/public_demo` (run together, full suite): **1877
  tests, all passed.** No regressions in any pre-existing Mission Phase 1/2,
  Recovery, Offer/Candidate, Growth, or roster test.
- Main-game regression (no shared file was touched, but verified anyway):
  `flutter test test/ui/fit_reason_widget_test.dart test/game/matching_test
  .dart test/presentation test/domain` — **276 tests, all passed**
  (includes the exact `techDomainLabels`/`fitDetailLabel` consumer this
  phase deliberately left unchanged).
- `git diff --check`: clean (no trailing whitespace / conflict markers).
- 390×844 / 360×800 × TextScaler 1.0/1.3 overflow matrices: covered for the
  new edit sheet and for the now-8-step Mission screen (both green).

## Self-hardening (Claude Broad Self Review, 1 pass)

Reviewed the full diff against the requested checklist:

- **Save authority**: `confirmSkillSheetEdit` is the sole production writer
  of both new/touched fields; verified no second code path calls
  `copyWith(salesProfileEditConfirmed: true)` or mutates
  `displayedExperienceMonths` anywhere else in the diff.
- **Actual/displayed confusion**: dedicated test asserts
  `actualExperienceMonths`/`actualSkill`/`techSkills`/
  `totalItExperienceMonths`/`interviewProfile`/`stage` are all bit-for-bit
  unchanged after an edit.
- **Mission false-positive**: `salesProfileEditConfirmed` has exactly one
  writer; a bare-bool-in-a-legacy-save forgery risk exists but is judged
  acceptable — this mission gates no economic/authority consequence, unlike
  `passClientInterview`/`winOrder`, which is why those two alone need
  unforgeable-record-level proof (Fresh Audit §3 precedent).
- **Cancel does not complete Mission**: verified at both the domain level
  (no `confirmSkillSheetEdit` call on `null`) and the widget level (Cancel
  button's `Navigator.pop(context)` carries no value).
- **Same-value save**: explicit test — confirms the mission completes even
  when the saved value equals the pre-edit value.
- **Engineer A/B**: explicit test — editing eng-01 never touches eng-02's
  displayed experience or confirmation flag.
- **Legacy save**: explicit test — a `salesProfileEditConfirmed`-free
  engineer JSON decodes to `false`, not a crash.
- **Malformed value**: explicit test — a hand-corrupted negative
  `displayedExperienceMonths` in a legacy-shaped save is rejected by
  `decode()` as a whole (existing `LanguageSkill` invariant/try-catch
  behavior, not new to this phase — see Unresolved below).
- **Shared label regression**: the shared `techDomainLabels`/`fitDetailLabel`
  path was left untouched by design; confirmed via the Main Game regression
  run above.
- **Overflow**: covered by the two new overflow matrices plus the updated
  existing Mission screen matrix (now 8-step).

No P0/P1 findings from this pass. One P2-adjacent observation is recorded
under Unresolved rather than fixed, per scope discipline (see below).

## Unresolved / known issues

- **`LanguageSkill`'s own `assert(displayedExperienceMonths >= 0)` is a
  debug-only guard.** In a release build (asserts stripped), a hand-
  corrupted save with a negative legacy `displayedExperienceMonths` would
  load without being rejected, unlike in this repo's own test environment
  (asserts enabled) where `decode()` safely discards the whole save. This is
  **pre-existing behavior in a shared domain model** (`domain/models/
  language_skill.dart`, used by both the main game and Public Demo), not
  something this phase introduced, and this phase's own new write path
  (`PublicDemoState.updateDisplayedExperience`) already clamps every value
  it produces to `[0, ceiling]`, so it cannot itself create this state.
  Hardening `LanguageSkill.fromJson` to clamp instead of assert would touch
  a genuinely shared file outside this phase's declared scope — flagged
  here rather than fixed, for a future audit to size independently.
- **Shared `techDomainLabels`/`fitDetailLabel` main-game labels remain
  English** — a deliberate, documented Phase 3 scope boundary (Design
  Decision #1), not an oversight. Left as a named candidate for a future,
  separately-scoped localization phase that can budget for the main-game
  screen verification the Implementation Plan's own §6.1 originally called
  for.

## Future trust/risk proposal (not implemented this phase, by design)

Per the task's explicit Safety/game-design constraint, no penalty mechanic
was added this phase. The main game's own existing `SalesEngine`
(`SkillSheetRisk {honest, moderate, aggressive, extreme}`,
`inflationDetails`, `employeeReaction`) is real prior art already in this
codebase and is the natural shape for a future Public Demo phase to port:
Company Trust impact scaled by inflation size, an interview-outcome
penalty when a client discovers the gap, and/or an employee-trust reaction
mirroring the main game's own `employeeReaction` copy. Recommended as its
own scoped phase, gated on this Phase 3 editor having shipped and been
played first.

## FINAL VERDICT

**Phase 3 implemented, tested, and merged into the working branch as
planned.** Fresh Audit surfaced two legitimate deviations from the prior
Implementation Plan §6 text (shared-label scope, per-language editor scope)
and both were resolved with the code kept as authority, documented above and
in the Implementation Plan itself. No existing Mission Phase 1/2 authority,
HOME content, bottom navigation, or main-game screen was altered. All
requested focused test commands pass; the full `public_demo` suite (1877
tests) and a targeted main-game regression pass (276 tests) are green;
`flutter analyze` and `git diff --check` are clean.
