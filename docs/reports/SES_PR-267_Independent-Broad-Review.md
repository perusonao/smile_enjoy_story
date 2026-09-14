# SES PR #267 — Independent Broad Review / Merge Gate

Role: independent second reviewer, outside the PR's own authorship session.
(Codex review was requested once on this PR but did not execute due to a
Codex usage limit; this review was run instead, per instruction not to
retry Codex and not to recursively chain another broad review after this
one.)

## Verified identity

- Repo: `perusonao/smile_enjoy_story`, PR #267.
- `origin/main` (explicit fetch): `4efb4787b677ed75a5fdb3493c88ddf7f3555e3c`
  — matches the PR's own stated base exactly, no drift.
- PR #267 `head.sha` (fetched live via the GitHub API): `758467dbea652ca02aa86925c1868fb5f77f5cd2`
- **Expected reviewed HEAD** (task spec): `758467dbea652ca02aa86925c1868fb5f77f5cd2`
- **Match: exact.** Single-commit PR (`758467d "feat(public-demo): Mission
  Phase 3 — SkillSheet Understanding / Editing"`), so "the actual PR diff
  against latest main" is this one commit's diff against
  `4efb4787b677ed75a5fdb3493c88ddf7f3555e3c`, reviewed in full below.

## Reviewed HEAD

`758467dbea652ca02aa86925c1868fb5f77f5cd2`

## Final HEAD

**Unchanged** — `758467dbea652ca02aa86925c1868fb5f77f5cd2`. No fix was
required (see Findings), so per instruction production code was not
touched and nothing was pushed to the PR's own branch
(`claude/skillsheet-editing-phase3-4jxr6a`). This report is committed to
this review's own designated branch
(`claude/ses-pr-267-broad-review-9b088l`) only.

## Method

- Read `docs/reports/SES_FIRST-FUN-QUARTER_MISSION-PHASE3_Result.md` (the
  author's own Fresh Audit + self-review) in full.
- Fetched the PR head commit locally and diffed it against
  `origin/main` directly (`git diff origin/main <head> -- lib/` and
  `-- test/`), read every changed line in `lib/` (658 diff lines across 10
  files) and every changed/added test file (916 diff lines across 8
  files) — not a summary pass.
- Cross-checked every claim in the Result Report against the actual diff
  rather than trusting the report's prose (e.g. grepped for every
  production write site of `displayedExperienceMonths` and
  `salesProfileEditConfirmed` to independently confirm the "single
  authority" claims; confirmed `lib/ui/widgets/labels.dart` — the shared
  `techDomainLabels` file — has a genuinely empty diff).
- Checked the PR's live CI on the exact reviewed SHA: `flutter analyze`
  step (`Fast CI (S.E.S.)` → `validate` job) — **success**; that same
  job's whole-repo `flutter test` step (started after `analyze`, ran
  ~14.5 minutes, covers the full suite including the 276-test main-game
  regression slice) — **success**; the separate `Public Demo only` check
  (the `test/game/public_demo` + `test/ui/public_demo` suite this PR's own
  1877-test claim refers to) — **success**; `replay-unit` — **success**.
  All four are green on `758467dbea652ca02aa86925c1868fb5f77f5cd2`. This
  review's own sandbox has no `flutter` toolchain installed, so
  verification here is: (a) direct code reading, (b) the PR's own live
  GitHub Actions results for the exact reviewed SHA.

## Findings

**No P0 or P1 findings.** No fix was required; per instruction, production
code was left untouched.

### P2

None that affect save/progression/authority/data integrity or the Phase 3
product requirement. See P3 below for the two items worth naming, both
already correctly self-identified and documented by the author's own
Result Report — independently re-verified here, not fixed (per the
"low-impact P2/P3 may remain documented" instruction and the "no fix
needed → do not touch production code" instruction).

### P3 (documented, no fix required)

1. **`LanguageSkill.displayedExperienceMonths >= 0` is a debug-only
   `assert`.** In a release build (asserts stripped), a hand-corrupted
   save with a negative legacy `displayedExperienceMonths` would load
   without being rejected — verified by reading
   `domain/models/language_skill.dart`: the non-negativity check is only
   the constructor's `assert`, not a `fromJson`-level clamp/throw. In this
   repo's actual test environment (asserts enabled, `flutter test`
   default), the existing test
   (`public_demo_skill_sheet_edit_test.dart`, "a malformed legacy
   displayedExperienceMonths … is rejected by decode() as a whole")
   correctly observes the whole save being discarded — that is
   assert-triggered `decode()` failure, not an explicit validation path,
   and the test's own name is accurate about what it's actually
   exercising. Pre-existing in a **shared** domain model used by both the
   main game and Public Demo, not introduced by this PR; this PR's own new
   write path (`PublicDemoState.updateDisplayedExperience`) always clamps
   to `[0, ceiling]` before writing, so it cannot itself produce this
   state. Fixing it means hardening `LanguageSkill.fromJson` to clamp
   instead of assert — a genuinely shared file, outside this PR's declared
   SkillSheet-editing scope. Sizing that is a fine candidate for its own
   small follow-up PR; not a reason to hold this one.
2. **Shared `techDomainLabels`/`fitDetailLabel` main-game labels remain
   English.** Independently confirmed: `lib/ui/widgets/labels.dart` has a
   literally empty diff against `origin/main` in this PR — the localization
   in this PR is entirely confined to the new private
   `_techSkillDomainLabels` map in
   `public_demo_skill_sheet_display_projection.dart`. This is a
   deliberate, explicitly documented scope boundary (Result Report Design
   Decision #1), not an oversight — the shared map's real footprint (4
   main-game detail/list screens plus Public Demo's own Matching
   Fit-reason line) is legitimately out of this PR's "SkillSheet only"
   scope. Correctly named as a candidate for a future, separately-scoped
   localization pass.

No other findings survived verification — see the point-by-point checklist
below for what was specifically checked and cleared.

## Review-priority checklist (all 19 items)

1. **Save/legacy compatibility** — `salesProfileEditConfirmed` is additive
   (`json['salesProfileEditConfirmed'] as bool? ?? false`), no
   `schemaVersion` bump; a legacy-JSON test that strips the key entirely
   confirms a clean `false` fallback. `displayedExperienceMonths` reuses
   the pre-existing `LanguageSkill` field/round-trip — no schema work
   needed for it. Cleared.
2. **`displayedExperienceMonths` authority** — grepped every production
   write site: seed/generation code (`public_demo_engineer_runtime.dart`'s
   own seed constants, `public_demo_growth_engine.dart`,
   `prologue_engine.dart`, `applicant_generator.dart`, `applicant.dart`)
   only ever construct *initial* values; the **only** place an existing
   hired engineer's displayed experience is ever mutated post-hire is
   `PublicDemoState.updateDisplayedExperience`, called only from
   `PublicDemoAggregate.confirmSkillSheetEdit`, called only from
   `_openSkillSheetEdit` in the placeholder screen on a non-null (Save)
   result. Single, traceable authority chain confirmed by direct grep, not
   just by reading the doc comment. Cleared.
3. **`salesProfileEditConfirmed` persistence** — additive `bool`, default
   `false`, wired through `copyWith`/`toJson`/`fromJson`; round-trip test
   (`public_demo_skill_sheet_edit_test.dart`) confirms it survives a real
   `PublicDemoSaveCodec.encode`/`decode` cycle. Cleared.
4. **Cancel must NOT complete Mission** — `PublicDemoSkillSheetEditSheet`'s
   Cancel button calls bare `Navigator.pop(context)` (no value); `show()`
   returns `Future<int?>`; `_openSkillSheetEdit` only calls
   `confirmSkillSheetEdit` when `result != null`. Verified at both domain
   (`public_demo_mission_resolver_test.dart`: "cancelling the edit sheet
   (no confirmSkillSheetEdit call) never completes editSkillSheet") and
   widget/integration level
   (`public_demo_01_skill_sheet_flow_test.dart`: cancel leaves
   `salesProfileEditConfirmed` false). Cleared.
5. **Same-value confirmed save behavior** — `confirmSkillSheetEdit` always
   sets `salesProfileEditConfirmed: true` on a genuine save regardless of
   whether the clamped value equals the pre-edit value (it is not a diff
   against a baseline); a dedicated test saves the unchanged value and
   asserts the mission still completes. This is a deliberate, well-reasoned
   design choice (Result Report: deriving "was this edited" from a value
   diff would itself require persisting a pre-edit baseline, and would
   misreport a genuine re-confirm as "not edited"). Cleared.
6. **Actual experience must remain unchanged** —
   `updateDisplayedExperience` only ever calls
   `currentSkill.copyWith(displayedExperienceMonths: clamped)`, never
   touching `actualExperienceMonths`/`actualSkill` on that same
   `LanguageSkill`. Domain test asserts `actualExperienceMonths`/
   `actualSkill` bit-for-bit unchanged after an edit; widget/integration
   test asserts the interview profile and stage are untouched too.
   Cleared.
7. **Actual capability must remain unchanged** — `actualCapability` is a
   getter over `actualSkill`, never written by this feature; domain test
   explicitly asserts `afterRuntime.actualCapability ==
   beforeRuntime.actualCapability`. Cleared.
8. **Fit/matching must remain unchanged** — read `MatchingEngine.computeFit`
   directly (not just trusted the doc comment): the experience dimension
   reads `profile.totalItExperienceMonths` and the skill dimension reads
   `profile.skillFor(language).actualSkill` — `displayedExperienceMonths`
   is not an input to Fit at all, so editing it is inert to Fit/Matching by
   construction. `techSkills`, `totalItExperienceMonths` are asserted
   unchanged by the domain test. Cleared.
9. **Engineer A/B isolation** — `updateDisplayedExperience`'s
   `engineerRuntimes` rebuild only replaces the list entry whose
   `engineerId` matches; `_withEngineer` (workflow side) does the same by
   id. Dedicated test edits eng-01 and asserts eng-02's
   `displayedExperienceMonths` and `salesProfileEditConfirmed` are both
   untouched. Cleared.
10. **Malformed/legacy save** — legacy save (key absent) → clean `false`
    default, tested. Malformed save (hand-corrupted negative
    `displayedExperienceMonths` inside an otherwise-valid save) → whole
    `decode()` rejected (`null`), tested — matches this repo's existing
    "reject the whole save on any invariant violation" convention, not a
    crash. The one caveat here (assert stripped in release builds) is P3
    #1 above — pre-existing, shared, out of scope, correctly documented
    rather than silently missed. Cleared as "no regression introduced";
    P3 limitation carried forward as documented.
11. **Mission chain**: view SkillSheet → **edit SkillSheet** → begin
    selling → proposal → partner interview → client interview → order →
    assignment — confirmed directly in
    `publicDemoAprilMissionChain` (now 8 entries, `editSkillSheet` inserted
    between `viewSkillSheet` and `beginSelling`) and in
    `publicDemoAdvanceEngineerToOrdered`'s updated command chain used by
    every "full chain complete" test helper. Cleared.
12. **False Mission completion** — `editSkillSheet`'s completion predicate
    (`anyEngineer((e) => e.salesProfileEditConfirmed)`) reads only the one
    field set exclusively by `confirmSkillSheetEdit`'s workflow half; no
    other command in the diff sets it (grepped every
    `salesProfileEditConfirmed:` write site — only the one real write in
    `public_demo_workflow_state.dart`, plus `copyWith`/`fromJson` plumbing
    in `public_demo_sales.dart`). A dedicated test also confirms
    `beginSelling` alone (without ever calling `confirmSkillSheetEdit`)
    does not flip it. Cleared.
13. **36-month clamp correctness** —
    `ceiling = currentSkill.actualExperienceMonths +
    PublicDemoEngineerRuntime.maxDisplayedExperienceInflationMonths` (36,
    verbatim copy of the main game's own
    `SkillSheet.maxExperienceInflationMonths` value); `clamped` floors at
    0 and ceilings at that value. Tests cover both bounds (`999999` →
    clamped to ceiling; `-50` → clamped to `0`). The UI's own year-stepper
    additionally floor-divides the ceiling by 12 for its whole-year
    granularity (so a non-multiple-of-12 ceiling is slightly
    under-selectable in the UI, e.g. a 66-month ceiling caps the stepper
    at 5 years/60 months rather than 66) — this is a deliberate, harmless
    UX simplification consistent with the main game's own year-stepper
    convention (documented in the widget's own class doc), not a clamp
    bug: the domain-level clamp itself (the actual authority) is exactly
    right. Cleared.
14. **Applicant SkillSheet regression** — `PublicDemoCandidateSkillSheetSheet`/
    `…DisplayFactory` (pre-hire) are structurally separate classes/files
    from the employee `PublicDemoSkillSheetSheet`/`…DisplayFactory`
    touched by this PR; `PublicDemoApplicant` has no
    `displayedExperienceMonths` concept at all. Confirmed zero overlap by
    reading the diff's file list — no applicant/candidate file appears in
    it at all. Cleared.
15. **Public Demo label localization scope** — `_techSkillDomainLabels` is
    `private to public_demo_skill_sheet_display_projection.dart`; the
    shared `lib/ui/widgets/labels.dart` (`techDomainLabels`) has a literally
    empty diff (independently verified via `git diff`, not just the
    author's own claim). Cleared — see P3 #2 for the (correctly
    documented, out-of-scope) residual English labels on the main-game
    side.
16. **Main Game shared-helper regression** — the one genuinely shared
    symbol this PR touches is a **value**, not a shared symbol:
    `PublicDemoEngineerRuntime.maxDisplayedExperienceInflationMonths` is a
    new, Public-Demo-local constant that copies the main game's
    `SkillSheet.maxExperienceInflationMonths` numeric value (36) with no
    import coupling. No main-game file appears anywhere in the diff's file
    list (`lib/game/public_demo/` and `lib/ui/public_demo/` only, plus
    docs). Cleared.
17. **UI overflow/TextScaler** — the new edit sheet is covered by a
    360×800/390×844 × TextScaler-1.0/1.3 matrix
    (`public_demo_skill_sheet_edit_sheet_test.dart`) asserting
    `tester.takeException()` is `null` at every combination; the existing
    Mission-screen overflow matrix already covers the now-8-step chain.
    The sheet itself uses `Flexible`/`SingleChildScrollView`/`SafeArea` and
    a `maxHeight` constraint derived from `MediaQuery.sizeOf`, consistent
    with this codebase's existing sheet patterns. Cleared.
18. **HOME Freeze/Bottom Nav regression** — no HOME or bottom-navigation
    file appears anywhere in the diff (`git diff --stat` file list
    contains only `lib/game/public_demo/*`, `lib/ui/public_demo/*`, and
    docs — no `home`/`bottom_nav`/`app_shell` file). Cleared by absence.
19. **Atomicity/duplicate action/reload edge cases** —
    `PublicDemoAggregate.confirmSkillSheetEdit` is a single `_copyWith`
    call constructing one new immutable `PublicDemoAggregate` from both the
    new `state` and new `workflow` together — the same atomic-replacement
    pattern every other command in this class uses; there is no
    intermediate state where one half is updated and the other is not.
    Reload/persistence is covered by the round-trip test in finding #3.
    One minor, non-production-facing observation (not raised to a finding
    because the only real call site already prevents it): the state-half
    (`updateDisplayedExperience`) and workflow-half
    (`confirmSkillSheetEdit`) of the combined command each independently
    no-op for an unrecognized id on their own side, so a hypothetical
    caller passing an id known to the workflow's engineer list but absent
    from the state's runtime list (or vice versa) could set
    `salesProfileEditConfirmed: true` without a matching displayed-months
    write. This is unreachable via the only production caller
    (`_openSkillSheetEdit`, which pre-checks both `runtime` and its
    primary-language `LanguageSkill` entry before ever opening the sheet)
    and the two lists are always constructed together from the same
    engineer roster elsewhere in this codebase — recorded here as a
    documented limitation, not a fix-required finding, since it does not
    correspond to any reachable production path.

## Fixes

None. No P0/P1 or fix-required P2 finding was identified, so per
instruction no production code was modified in this review.

## Tests

No new tests were written or existing tests modified by this review (no
fix required). Verification performed:

- Full manual read of the PR's own diff (`lib/`: 658 diff lines / 10
  files; `test/`: 916 diff lines / 8 files) against `origin/main` at
  `4efb4787b677ed75a5fdb3493c88ddf7f3555e3c`.
- Direct reads of `MatchingEngine.computeFit`,
  `PublicDemoWorkflowState._withEngineer`/`beginSelling`, and
  `LanguageSkill`'s constructor to independently verify claims rather than
  trust the Result Report's prose.
- Grep-based cross-checks for single-writer claims on
  `displayedExperienceMonths` and `salesProfileEditConfirmed`, and for the
  shared-label-file diff being empty.
- PR's own live CI on the exact reviewed SHA
  (`758467dbea652ca02aa86925c1868fb5f77f5cd2`), all green: `flutter
  analyze` — **success**; `validate` job's whole-repo `flutter test` step
  (includes the 276-test main-game regression slice) — **success**;
  `Public Demo only` (the `test/game/public_demo` + `test/ui/public_demo`
  suite, i.e. this PR's own claimed 1877-test run) — **success**;
  `replay-unit` — **success**.
- `flutter` is not installed in this review's own sandbox, so no local
  `flutter analyze`/`flutter test`/`git diff --check` run was performed
  here; verification instead relied on direct code reading plus the PR's
  own live CI for the exact reviewed SHA, per the instruction not to
  rerun the full suite when no fix changes broad behavior.

## Known limitations

- This review's sandbox has no Flutter SDK; all "does this actually pass"
  confirmation for test claims comes from the PR's own live GitHub Actions
  runs against the reviewed SHA (`Fast CI (S.E.S.)`, run `34861084226`),
  not a local re-run. All four relevant checks on that run — `flutter
  analyze`, the `validate` job's whole-repo `flutter test`, `Public Demo
  only`, and `replay-unit` — finished **success** before this report was
  finalized.
- The two P3 items above are carried forward as documented limitations,
  not fixed, per the task's own "low-impact P2/P3 may remain documented"
  and "no fix needed → do not touch production code" instructions.

## FINAL VERDICT: **GO**

No P0/P1 findings. Every reviewed checklist item traces to a real,
independently-verified authority chain (single writer, atomic combined
command, correct clamp math, correct additive-persistence default,
cancel-safe, same-value-safe, A/B-isolated, Fit/Matching-inert by
construction, no shared main-game or HOME/bottom-nav file touched). The
two P3 items are pre-existing/out-of-scope and already correctly
self-documented by the PR's own Result Report; neither affects
save/progression/authority/data integrity or the Phase 3 product
requirement. All CI on the reviewed SHA is green (`flutter analyze`,
whole-repo `flutter test`, `Public Demo only`, `replay-unit`). Recommend
merge.
