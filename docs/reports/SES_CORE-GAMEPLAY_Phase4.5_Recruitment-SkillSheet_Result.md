# SES CORE-GAMEPLAY Phase 4.5: Recruitment / SkillSheet Authority Fix — Result

Status: **Merge-blocker follow-up complete (second pass) — full
`test/game/public_demo/` (588 tests) and `test/ui/public_demo/` (508 tests,
+1 new regression test) directories green, `flutter analyze` clean, `git
diff --check` clean. See "Merge Blocker Follow-up (second pass)" below for
what changed after PR #210's review comment.**

## BASE SHA / branch / HEAD

- BASE SHA (origin/main at session start): `79c618c609c4444fd9c844bdbc9f4d523bbf90c9` —
  matched the task's own expected BASE exactly.
- Branch: `claude/recruitment-skillsheet-authority-e7v65x` — this branch's own
  prior tip (`f4ca78f`) was an ancestor of `origin/main` with no unmerged
  commits, so it was fast-forwarded onto the BASE SHA above at session start
  (`git merge --ff-only origin/main`), per the merged-branch-reuse rule.
- HEAD after this work: recorded in the commit that accompanies this report
  (see FINISH section).

## Scope

Phase 4.5 is a minimal, necessary fix ahead of Phase 5 (Matching), addressing
four confirmed Recruitment/SkillSheet authority and wording problems without
touching Finance/Month authority, Balance, Month transition, or HOME layout.

## 1. 5月応募の旧原因と修正後authority

**旧原因**: `PublicDemoWorkflowState.initial()`
(`lib/game/public_demo/public_demo_workflow_state.dart`) unconditionally
seeded `applicants: publicDemoMayApplicants` (`app-01`/`app-02`, hand-authored
constants in `lib/game/public_demo/public_demo_recruitment.dart`) — present in
the authoritative `workflow.applicants` list from month 4 (April) at game
start, **before any recruiting action**. The Sales tab's own applicant funnel
(`_salesApplicantProgressCards`) and its overview count
(`_salesOverviewSection`'s `候補者` tile) were separately gated to
`s.month >= 5`, so the two pre-seeded applicants existed internally for the
whole of April but were invisible until May — reading, to the player, as
"応募者が5月に突然現れる" even though nothing they did in April caused it.
This was already self-documented in the pre-fix code's own comments
(`_salesOverviewSection`'s doc explicitly named the "dormant pre-May pool").

**修正後authority**: `PublicDemoWorkflowState.initial()` now seeds
`applicants: const []`. The **sole** production source of any applicant, from
this fix forward, is `PublicDemoAggregate.recruit(medium)`
(`lib/game/public_demo/public_demo_aggregate.dart`), which delegates to
`PublicDemoRecruitmentCalculation` → `PublicDemoSeededRecruitmentGenerator`
(CORE-GAMEPLAY Phase 2, unmodified) — a real player action ("求人媒体を使う"
on the 営業 tab), gated to once per month
(`PublicDemoState.canUseRecruitmentMediaInMonth`, months 4-8, unmodified) and
costing real cash for the `engineer` medium. A bare month transition
(`closeApril`/`closeMay`/`closeOrdinaryMonth`, all unmodified) never adds an
applicant on its own — verified directly by a new domain test and by the
existing recruitment-transaction suite's own delta-based assertions (which
were already agnostic to the starting count and needed no change).

The April month-close event dialog
(`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, `april()`)
previously told the player "採用候補者の情報を確認できます" — accurate under
Issue #168's own prior truthfulness fix (it no longer claimed a "new"
application had just arrived), but its premise (an existing candidate pool
ready to review) is now false with zero pre-seeded applicants. It now reads
"採用は求人媒体から始まります" / "採用候補者は求人媒体を使うと集まります。" /
"営業タブから求人媒体を使いましょう。" — the one fact that stays true on every
playthrough regardless of what the player did in April.

## 2. legacy app-01/app-02の扱い

`publicDemoMayApplicants`/`publicDemoFreeApplicants`
(`public_demo_recruitment.dart`) are **unchanged as constants** but are no
longer read by `PublicDemoWorkflowState.initial()`. They remain solely for:

- **Legacy save compatibility**: a save persisted before this fix may still
  contain `app-01`/`app-02` (or the `free-template-*` ids) inside
  `workflow.applicants`' JSON. `PublicDemoWorkflowState.fromJson` round-trips
  any applicant list verbatim regardless of origin — untouched by this fix —
  so such a save still loads and plays exactly as before.
- **`PublicDemoRecruitmentInterview`'s existing id-only fallback**
  (CORE-GAMEPLAY Phase 3, unmodified): `regenerateDomainApplicant` already
  returned `null` for these hand-authored ids (never produced by
  `PublicDemoSeededRecruitmentGenerator`), and the interview adapter's
  existing fallback path (a synthetic flavor `Applicant` seeded from the
  applicant's id alone) still resolves them for a legacy save's own
  interview-in-progress state.

A new shared test helper,
`test/game/public_demo/test_support/public_demo_legacy_applicant_test_helpers.dart`
(`withLegacyFoundingApplicants`), reconstructs exactly this "save created
before Phase 4.5" scenario through the same `PublicDemoAggregate.fromJson`
path a real save load uses — splicing the legacy fixtures into the JSON
envelope — for the handful of existing tests whose whole point is these two
specific, named applicants (their exact scores keep several pre-existing
adversarial/regression tests meaningful without inventing a new scenario).

## 3. SkillSheetのauthoritative data source

Two distinct, already-existing data sources, unchanged by this phase, each
now paired with a display-side component:

- **Employee (post-hire)**: `PublicDemoEngineerRuntime` +
  `PublicDemoEngineerSales` + `PublicDemoAssignment` (when currently
  assigned) → `PublicDemoSkillSheetDisplayFactory.create(...)` (pre-existing,
  unmodified) → `PublicDemoSkillSheetSheet` (pre-existing, unmodified).
- **Candidate (pre-hire)**: `PublicDemoApplicant`'s own flat, résumé-level
  scalars (name, resumeSummary, experienceMonths, requestedMonthlySalary) →
  new `PublicDemoCandidateSkillSheetDisplayFactory.create(...)`
  (`lib/ui/public_demo/public_demo_candidate_skill_sheet_display_projection.dart`)
  → new `PublicDemoCandidateSkillSheetSheet`
  (`lib/ui/public_demo/public_demo_candidate_skill_sheet_sheet.dart`). No new
  domain field, no fabricated data — every value is read verbatim from the
  same authoritative `PublicDemoApplicant` the screen already holds.

## 4. candidate/employeeで表示する項目 と hidden情報との境界

| | Candidate (pre-hire) | Employee (post-hire) |
|---|---|---|
| Shown | name, résumé text (`resumeSummary`), experience (`experienceMonths`, formatted), requested monthly salary | name, primary language, status, ability chips, tech-skill chips, actual-vs-displayed experience per confirmed language, industry experience, career history, current assignment (project/deliveryPressure/budgetHealth) |
| Excluded (hidden/interview-only) | `interviewScore`, `acceptanceScore`, `salesSkillFit` | *(none excluded — these are all already-confirmed, post-hire facts)* |

`interviewScore`/`acceptanceScore` are only ever revealed by actually running
the 採用面談 step (already shown as `評価 {score}` on the applicant card once
interviewed — unchanged, outside the SkillSheet sheet itself).
`salesSkillFit` is only ever revealed by the 上位会社面談/客先面談 pre-entry
steps (`PublicDemoInterviewResultDialog`'s own `score` display — unchanged).
The new candidate SkillSheet sheet deliberately never reads any of these
three fields, so a player can never see, through the SkillSheet button, a
fact that step exists specifically to reveal.

### Button-to-content match (item 3)

Both candidate-facing buttons previously either did nothing visible
("経歴書確認": a bare stage transition, `applied → resumeReviewed`, no
dialog at all) or opened nothing real ("入社前SkillSheet": same pattern,
`offerAccepted → preEntrySkillSheet`). Both now open
`PublicDemoCandidateSkillSheetSheet` (in addition to committing the exact
same, unchanged stage transition) and are labeled in Japanese only:
"スキルシート確認" (applied stage) and "入社前スキルシートを確認"
(offerAccepted stage). "スキルシート確認" (not "…を確認") was chosen
specifically to stay byte-distinct from HOME's own pre-existing
`employeeSkillSheetReview` recommended-action CTA label
("スキルシートを確認") — `home_recommended_action_test.dart`'s own
"no CTA label is byte-identical to a legacy Public Demo control" rule
requires a HOME shortcut and the screen control it triggers to read as
visibly different text; this is a pre-existing repo-wide invariant, not new.

### Terminology unification (item 2)

Every user-facing "SkillSheet"/"経歴書" mix was unified to "スキルシート":
the employee-tab gating button, section header ("成長・スキルシート・研修"),
the pre-join sales-progress copy, the sales-progress dialog copy, and the
`PublicDemoSkillSheetSheet`'s own header/experience-comparison text
("営業用スキルシート" / "スキルシート記載"). Domain/internal identifiers
(`PublicDemoSkillSheet*` class names, `SkillSheet` in
`lib/domain/models/sales_profile.dart`) were left untouched, per the task's
own instruction not to rename internal identifiers.

### Employee SkillSheet always reachable (item 4)

Before this phase, an employee's SkillSheet was only ever reachable through
the one-time `waiting`-stage gating action (`ec(i)`'s own
"スキルシート確認" button) — once an employee moved past that stage, there
was no way to view it again. A new pure-view method,
`_viewEmployeeSkillSheet(engineer)`, opens the exact same
`PublicDemoSkillSheetSheet`/`PublicDemoSkillSheetDisplayFactory` **without**
committing `_startSkillSheetReview`, so it is safe at any
`PublicDemoSalesStage`. It is wired to:

- a small icon button on every row of the Employee tab's roster section
  (`_employeeRosterCard`, all employees, any status), and
- a small icon button on the Sales tab's June assignment card
  (`assignmentCard(i)`), resolving the assignment's `engineerId` back to a
  `PublicDemoEngineerSales` via the existing `_engineerById` helper.

Both call sites use the identical underlying method on the same screen
`State` class — proving the display is genuinely reusable across tabs today,
and the concrete hook point a future Phase 5 (Matching) surface should
follow (see below), not merely a theoretical possibility.

## Phase 5 (Matching) handoff

- **Employee SkillSheet**: call `PublicDemoSkillSheetSheet.show(context,
  engineer:, statusLabel:, runtime:, currentAssignment:)` directly — the same
  call `_viewEmployeeSkillSheet`/`_openSkillSheetReview` already make. No new
  authority needed; `runtime`/`currentAssignment` are already nullable and
  resolve to an explicit empty state.
- **Candidate SkillSheet** (for any future "compare candidates" Matching UI):
  call `PublicDemoCandidateSkillSheetSheet.show(context, applicant:)` —
  purely a function of the `PublicDemoApplicant` already on the workflow, no
  new authority.
- **Project side**: `PublicDemoAggregate.projectCandidatesForMonth` (Phase 4)
  remains the query entry point for seeded project candidates, per its own
  doc — unrelated to and unaffected by this phase.
- Neither sheet was changed to accept a "compare" mode or list rendering —
  that UI shape is Phase 5's own decision to make; this phase only ensures
  the display primitives it will need already exist, are truthful, and are
  proven reusable.

## Changed files

**Production**:
- `lib/game/public_demo/public_demo_workflow_state.dart` —
  `PublicDemoWorkflowState.initial()` no longer pre-seeds applicants.
- `lib/game/public_demo/public_demo_recruitment.dart` — doc comment on
  `publicDemoMayApplicants` clarifies legacy-only status; no field/logic
  change.
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — April event
  dialog copy; two new async handlers
  (`_reviewResumeAndOpenSkillSheet`/`_beginPreEntrySkillSheetAndOpen`) wiring
  the candidate SkillSheet sheet into the existing `ac(i)` buttons and their
  HOME recommended-action mirrors; new `_viewEmployeeSkillSheet`; new
  IconButton on `_employeeRosterCard` and `assignmentCard(i)`; button-label/
  section-header terminology unification (see above).
- `lib/ui/public_demo/public_demo_skill_sheet_sections.dart` — two
  user-facing string literals unified to "スキルシート".
- `lib/ui/public_demo/public_demo_candidate_skill_sheet_display_projection.dart`
  (new) — `PublicDemoCandidateSkillSheetDisplayFactory`.
- `lib/ui/public_demo/public_demo_candidate_skill_sheet_sheet.dart` (new) —
  `PublicDemoCandidateSkillSheetSheet`.

**Tests** (game-level fixtures updated to recruit via the same real
`PublicDemoAggregate.recruit` command production code uses, in place of the
removed pre-seeded pool; UI-level button-text renames; two fixtures pinned
to a specific `runSeed` where determinism or a threshold — offer-acceptance,
pre-entry interview pass — genuinely matters):
- `test/game/public_demo/test_support/public_demo_legacy_applicant_test_helpers.dart`
  (new) — `withLegacyFoundingApplicants`.
- `test/game/public_demo/public_demo_aggregate_test.dart`,
  `public_demo_balance_regression_test.dart`,
  `public_demo_financial_status_test.dart`,
  `public_demo_recovery_aggregate_test.dart`,
  `public_demo_recruitment_interview_test.dart`,
  `public_demo_save_codec_test.dart`, `public_demo_workflow_state_test.dart`.
- `test/presentation/home/home_recommended_action_test.dart` — one legacy
  control string updated (`SkillSheet確認` → `スキルシート確認`).
- 27 files under `test/ui/public_demo/` — button text renames
  (`SkillSheet確認`→`スキルシート確認`, `経歴書確認`/`入社前SkillSheet`→
  unified text), April-dialog text, and (for the files whose own fixtures
  needed a real applicant) a `recruit()` step in place of relying on the
  removed pre-seeded pool. See `git diff --stat` for the exact list.
- `e2e/helpers/public-demo-player.ts`,
  `e2e/tests/public-demo-july-restart.spec.ts`,
  `e2e/tests/public-demo-single-month-cta.spec.ts`,
  `e2e/tests/public-demo-close-reopen-persistence.spec.ts`,
  `e2e/tests/public-demo-month-guard.spec.ts` — mechanical button-text/
  dialog-text renames only (see Known limitations — the deeper
  `app-01`-dependent E2E flows are not restructured in this session).

## Tests / analyze

Environment: Flutter 3.44.9 (stable), downloaded to `/opt/flutter` (no SDK
preinstalled this session).

- `flutter analyze` (whole project): **No issues found.**
- `git diff --check`: clean.
- `flutter test test/game/public_demo/` (full directory, 588 tests): an
  earlier pass surfaced 1 failure introduced by this phase itself —
  `public_demo_aggregate_test.dart`'s "P1-1: … genuine interview then offer
  acceptance succeeds end-to-end" called `PublicDemoAggregate.initial()`
  with no `runSeed` after this phase's own edit added a `recruit()` call in
  its place; the generated candidate's `acceptanceScore` is seed-dependent,
  so the offer (at zero salary delta) sometimes failed the real evaluator's
  threshold non-deterministically. Fixed by pinning `runSeed: 1` (already
  known, from this same file's TEST C/E, to clear the acceptance threshold).
  Re-ran the full directory twice after the fix: **588/588 passed** both
  times. Separately, `public_demo_financial_status_test.dart`'s own
  pre-existing test "P: shortage blocks new offer acceptance" uses a shared
  fixture (`_reachShortageAggregate`, already written against
  `PublicDemoAggregate.recruit(free)` since CORE-GAMEPLAY Phase 2 — not
  touched by this phase, and not re-observed failing in the two clean
  reruns above) with **no pinned `runSeed`**; documented as pre-existing,
  seed-dependent flakiness this phase did not introduce — see Known
  limitations.
- `flutter test test/ui/public_demo/public_demo_01_success_playthrough_test.dart` — the
  full April→July golden path, rewritten to recruit via 求人媒体 (seed 9)
  instead of the removed pre-seeded pool: **pass**.
- Every other individually-identified affected file (see Changed files) run
  and green after its fix: `public_demo_01_playthrough_test.dart`,
  `public_demo_01_recovery_ui_test.dart`,
  `public_demo_01_suzuki_sales_yearend_boundary_test.dart`,
  `public_demo_01_home_recommended_action_test.dart` (27 tests),
  `public_demo_01_home_runtime_read_test.dart`,
  `public_demo_sales_ui_phase1_test.dart`,
  `public_demo_sales_visual_complete_test.dart`,
  `public_demo_employee_ui_phase1_test.dart`,
  `public_demo_employee_visual_complete_test.dart`,
  `public_demo_01_home_cash_forecast_advice_test.dart`,
  `public_demo_recruitment_interview_visual_test.dart`,
  `public_demo_01_skill_sheet_flow_test.dart`, and the batch of 15 remaining
  affected UI files (131 tests, all green after the button-text fix).
- A final broad regression pass, `flutter test test/ui/public_demo/
  --concurrency=6` (the whole directory, ~500 tests), surfaced exactly one
  additional failure beyond the individually-verified files above:
  `public_demo_seeded_recruitment_visual_test.dart`'s own sanity test
  (CORE-GAMEPLAY Phase 2, pre-existing) asserted candidate identity via
  `.skip(2)` — skipping what it assumed was still the fixed 高橋・田中
  founding pair ahead of the seeded candidates in `workflow.applicants`.
  With that pair removed by this fix, the skip silently dropped real seeded
  applicants instead. Fixed by removing the now-obsolete `.skip(2)` (and its
  matching comment/test-description text referencing the founding pair) so
  the assertion operates on the two seeded candidates directly. Re-ran the
  full `test/ui/public_demo/` directory afterward: **all 498 tests pass.**
- New game applicants == 0: verified directly (`public_demo_workflow_state_test.dart`'s
  own "engineers/assignments start from the established pools; applicants
  start empty").
- Month transition alone never adds an applicant: verified by the unmodified
  delta-based assertions across the whole recruitment-transaction/aggregate
  suites (none needed a starting-count change) and directly by the new
  empty-start assertion above.
- recruit() only ever generates applicants after being called: unchanged
  authority (`PublicDemoSeededRecruitmentGenerator`, CORE-GAMEPLAY Phase 2),
  reverified by the full recruitment-transaction suite passing unmodified.
- Same-seed reproducibility: unchanged authority
  (`PublicDemoRng`/`PublicDemoSeededRecruitmentGenerator`, Phase 1/2),
  reverified by the full seeded-recruitment-generator suite passing
  unmodified; this phase's own new golden-path/fixture tests additionally
  pin `debugSeed`/`runSeed` explicitly for reproducibility.
- Legacy save compatibility: verified by `withLegacyFoundingApplicants`-based
  tests (a real `fromJson` round-trip splicing in the legacy fixtures) all
  passing, and by `public_demo_save_codec_test.dart`'s own unmodified
  round-trip suite passing.
- 採用面談 Phase 3 regression: `public_demo_recruitment_interview_test.dart`
  passes in full, including its own legacy-fixture-fallback test (now
  reconstructed via `withLegacyFoundingApplicants` instead of relying on the
  removed pre-seed).
- candidate SkillSheetのhidden情報非表示: by construction —
  `PublicDemoCandidateSkillSheetDisplayFactory` never reads
  `interviewScore`/`acceptanceScore`/`salesSkillFit` (see section 4 above).
  No dedicated forbidden-field-name test was added this session (see Known
  limitations).
- employee SkillSheet表示 / Sales・将来Matichingから再利用可能: verified
  structurally (same call reused from two tabs, see section 4) and by the
  existing `public_demo_skill_sheet_display_projection_test.dart` suite
  passing unmodified (the underlying factory/data model is untouched).
- 360x800 / 390x844でoverflowなし: verified by
  `public_demo_sales_visual_complete_test.dart` and
  `public_demo_employee_visual_complete_test.dart`'s own existing overflow
  suites (both exercise the exact rows this phase added an IconButton to —
  the Sales June assignment card and the Employee roster row — at both
  viewports and TextScaler 1.0/1.3/2.0) passing unmodified.

## Known limitations (original pass — see Merge Blocker Follow-up below for what changed)

- ~~Pre-existing test flakiness, unrelated to this fix~~ — **fixed in the
  second follow-up pass below** (`_reachShortageAggregate` now pins
  `runSeed: 1`).
- ~~No dedicated automated test that the candidate SkillSheet sheet never
  renders `interviewScore`/`acceptanceScore`/`salesSkillFit`~~ — **fixed in
  the second follow-up pass below** (new
  `public_demo_candidate_skill_sheet_hidden_fields_test.dart`).
- ~~E2E (Playwright) specs were not restructured to recruit an applicant~~ —
  **fixed in the first follow-up pass** (commit `7408961` and the three
  E2E-repair commits after it — see below); the remaining stale
  `SkillSheetを確認`/`営業用SkillSheet` wording in
  `public-demo-skillsheet-phase-a.spec.ts`/`public-demo-july-restart.spec.ts`
  was fixed in the second follow-up pass.
- **Sales-tab reuse is currently a single, minimal hook** (one IconButton on
  the June assignment card) — sufficient to prove the display is genuinely
  reusable today, but Phase 5's own Matching UI will likely want a richer
  entry point (e.g. from a candidate-comparison list) that this phase
  deliberately does not build (out of scope: "Matching実装"). Still true —
  not touched by either follow-up pass.
- ~~`求人媒体` Sales-tab card visibility remains gated to `s.month == 5`~~ —
  **fixed in the first follow-up pass**, then **deliberately re-scoped (not
  reverted) in the second** to May-August rather than the domain's full
  April-August window — see the Merge Blocker Follow-up section below for
  why April specifically stays excluded.

## Merge Blocker Follow-up (second pass)

PR #210's review left a comment
(https://github.com/perusonao/smile_enjoy_story/pull/210#issuecomment-5584946130)
after a first follow-up pass (commits `7408961`..`70480a7`, same branch) had
already fixed the P1 recruiting dead-end, retired the E2E suite's `app-01`
assumption, and fixed the Fast CI smoke's stale `営業用SkillSheet` wording in
`public-demo-fresh-start.spec.ts`. The **Public Demo only** required CI check
was still red on that HEAD. This section documents the second pass that
fixes it.

### What was actually still broken

The first pass's P1 fix widened `_RecruitmentMediaCard`'s (and its HOME
Recommended Action mirror's) render gate from a fixed `s.month == 5` branch
to `PublicDemoState.canUseRecruitmentMediaInMonth(s.month)` — the domain's
real April-August recruiting window. Two independent problems fell out of
that:

1. **The card gate reused the wrong predicate.** `canUseRecruitmentMediaInMonth`
   folds in *this month's own usage* as well as the window — so gating the
   card's *visibility* on it made the whole card (including its
   always-informational 現預金 line) disappear the instant the player
   recruited this month, instead of staying visible with its button
   disabled ("今月は利用済み") the way the old `month == 5` gate displayed it
   for the rest of May regardless of use. `test/ui/public_demo/
   public_demo_01_playthrough_test.dart`'s "recruitment media adds
   applicants through the existing flow" caught this directly (CI: `Found 0
   widgets with text "現預金 ¥3100000"`).
2. **Widening the window all the way to April changed HOME's initial view.**
   `HomeRecommendedActionKind.recruitmentMedia` is a real P3 Recommended
   Action candidate whenever the card is visible and unused — so April, a
   month that (before this fix) never had *any* eligible Recommended Action
   candidate, now legitimately gets one. That is a real HOME layout change:
   `public_demo_01_home_one_screen_final_fit_test.dart`'s own hard-won "the
   initial April view needs zero scrolling" contract broke
   (`maxScrollExtent` went from `0` to `27.0`/`44.0` at both target
   viewports). The top-level merge-blocker instructions explicitly rule out
   HOME layout changes in this fix, so this was never an acceptable side
   effect to accept or paper over.

Fixing only (1) and leaving April in the window still left the "Public Demo
only" job red (`public_demo_01_playthrough_test.dart`'s June assertion,
`翌月の発注を確認` — which the widened window also legitimately preempts with
`求人媒体で候補者を追加` now, unrelated to April), and fixing that surfaced (2)
across four more test files once the suite ran past that point. 18 tests
failed the first time the *entire* `test/ui/public_demo/` directory was run
against the first-pass HEAD (never run in full before this pass — the
"Public Demo only" required check only runs two individual UI test files,
not the whole directory) — all 18 traced back to the same two root causes
above, none to a new, unrelated regression.

### The fix

- `lib/game/public_demo/public_demo_state.dart`: added
  `isRecruitmentMediaWindowMonth(int month)` — the domain's April-August
  window with no usage check folded in (unlike `canUseRecruitmentMediaInMonth`).
  Pure addition; `canUseRecruitmentMediaInMonth` and every other domain
  predicate/authority are byte-for-byte unchanged (no recruitment cost,
  count, or seed authority touched, per the review's own instruction).
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`: two new
  getters replace the single reused predicate —
  `_recruitmentMediaCardVisible` (May-August — deliberately narrower than
  the domain's own April-August window, specifically to keep HOME's
  existing April layout budget untouched; see the getter's own doc for the
  full rationale) and `_recruitmentMediaCandidateEligible` (`_recruitmentMediaCardVisible`
  AND not yet used this month — the Recommended Action's own eligibility,
  never recommending a hidden or disabled CTA). `_salesNextActionCards` and
  `_addRecruitmentMediaCandidate` now read these instead of either domain
  predicate directly.
- `lib/presentation/home/models/home_recommended_action.dart` and
  `home_dashboard_display_data.dart`: doc-comment corrections only (no
  behavior change) — the "July's 求人媒体 is never recommended" absence and
  "Recruitment media's own UI never re-appears after May" claim were both
  already stale after the first pass's own May-August widening; updated to
  describe what the code actually does now.
- Ten test files updated to match the corrected (May-August, not
  April-August) window — each traced to one of the two root causes above,
  not a new behavior: `public_demo_01_playthrough_test.dart`,
  `public_demo_01_home_recommended_action_test.dart`,
  `public_demo_01_home_consolidation_test.dart`,
  `public_demo_01_fiscal_year_progression_test.dart`,
  `public_demo_01_home_ui_3c_density_test.dart`,
  `public_demo_sales_ui_phase1_test.dart` (August now shows the card —
  unused window; a new September case covers the genuine post-window empty
  state the August case used to).
- **Item 4 (candidate SkillSheet hidden-data regression)**: new
  `test/ui/public_demo/public_demo_candidate_skill_sheet_hidden_fields_test.dart`
  — pumps `PublicDemoCandidateSkillSheetSheet` directly with a fixture
  applicant carrying distinctive `interviewScore`/`acceptanceScore`/
  `salesSkillFit` values and asserts none of the three appears anywhere in
  the rendered widget tree (exact match, substring match, and a full-tree
  text walk). Verified to actually catch a regression: temporarily adding
  one `SkillSheetMetricRow('面接スコア', '${applicant.interviewScore}')` to the
  sheet made this new test fail as expected, then the change was reverted.
- **Item 3 residual**: `public-demo-fresh-start.spec.ts` (the Fast CI smoke
  spec) already had the correct `営業用スキルシート`/`スキルシートを確認`
  wording from the first pass. Two Heavy-E2E-only specs the first pass
  missed — `public-demo-skillsheet-phase-a.spec.ts` and
  `public-demo-july-restart.spec.ts` — still asserted the stale English
  `SkillSheetを確認`/`営業用SkillSheet`/`SkillSheet記載` text; fixed to match
  current production wording.
- **Pre-existing flaky test** (already disclosed in Known limitations
  above): `public_demo_financial_status_test.dart`'s `_reachShortageAggregate`
  now pins `runSeed: 1` (same pin the neighbouring `public_demo_aggregate_test
  .dart` TEST C/E fixtures already use), clearing test P's
  would-be-accepted-offer assertion deterministically. Confirmed flaky
  in isolation before the fix (failed 1 of 3 solo reruns) and stable across
  5 solo reruns after.

### Verification (this pass)

- `flutter analyze` (whole project): **No issues found.**
- `git diff --check`: clean.
- `flutter test test/game/public_demo/` (588 tests): **588/588 passed**,
  confirmed across two full runs plus 5 isolated reruns of the previously-
  flaky file.
- `flutter test test/ui/public_demo/` (508 tests — 507 pre-existing + 1 new):
  **508/508 passed**, confirmed across two full runs (`--concurrency=6`).
- `flutter test test/game/public_demo/ test/ui/public_demo/` together in one
  run: **1096/1096 passed.**
- E2E (Playwright): not executed this pass — no browser/dev-server available
  in this session either, same limitation the first pass disclosed. The two
  wording fixes were verified by direct text search against current
  production source (`grep` for the exact rendered strings), not by running
  the specs.

## FINISH

First follow-up pass: committed and pushed to
`claude/recruitment-skillsheet-authority-e7v65x` (commits `7408961`
through `70480a7`). Second follow-up pass (this update): committed and
pushed to the same branch/PR (#210) as `e7caccbe6d3fda02da8686271af10dec369ce177`.

## Final verdict

**PASS** — both follow-up passes' known limitations are resolved or
explicitly disclosed above; none hidden.
