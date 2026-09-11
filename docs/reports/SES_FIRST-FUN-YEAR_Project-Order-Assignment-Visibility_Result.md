# SES FIRST-FUN-YEAR P1: Project / Order / Assignment Continuous Visibility — Result Report

GitHub Issue #239.

## Base / final HEAD SHA

- Base (`origin/main`, fetched explicitly at session start): `4a19b27daa93f53b7888e721b7c8e9486d5b95c1` — matches the SHA the Issue names; post-merge Fast CI #632 on this SHA is SUCCESS.
- Final HEAD (this branch, `claude/github-issue-239-nai2ql`): the commit titled "Issue #239 PR #240 review fix: never show 提案中 for a failed interview stage" (this report's own commit cannot name its own SHA without changing it — the exact hash is reported in this session's chat response and visible on PR #240) — supersedes `0b62ac6ed074252cd3d5bd2e922755e33a15e8cb`, the HEAD at PR #240's initial creation.
- The branch existed before this session with unrelated, un-PR'd, pre-#227-era content (`f4ca78f`, "Phase 0A/0B: SES domain models") — no open PR referenced it, so it was reset to `origin/main` and this Issue's work built fresh on top, per this session's own branch-handling instructions.

## Post-review fix (PR #240 Codex Broad Review, P1)

**Finding:** `PublicDemoProjectContextResolver.projectIdFor` resolved a project id for `partnerInterviewFailed`/`clientInterviewFailed` too (falling back to the still-recorded `PublicDemoMatchingProposal.projectId`), and `labelFor` then labeled it **提案中の案件** ("currently proposing") — misstating an interview that had already concluded in failure as still actively in progress. This also meant the original Verification matrix's own "Failed interview returns safely, no stale project context" line did not match the actual implementation or its unit tests, which the review also flagged.

**Fix (presentation-resolver only, no domain/save/economy/HOME change):**
- `projectIdFor` now returns `null` unconditionally for `partnerInterviewFailed`/`clientInterviewFailed` — removed from the shared "genuineInterviewProjectId, else matchingProposalProjectId" branch and grouped with the null-returning stages instead. A failed interview's own proposal is no longer surfaced as if still open.
- `labelFor` was rewritten from an `if`/catch-all into an exhaustive `switch` mirroring `projectIdFor`'s own case split, so a failed (or pre-introduction) stage can never read **提案中の案件** even if a future caller invoked `labelFor` in isolation, independently of `resolve`'s own short-circuit.
- No change to `beginSelling`/`再営業` (the existing recovery path back to `selling`), to `PublicDemoEngineerSales.evaluateInterview`'s pass/fail derivation, or to any other domain authority — `PublicDemoSalesProgress`'s raw stepper still shows the failed step exactly as before; only the new project-context line's own visibility for these two stages changed.
- Updated `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`'s doc comments (on the `ec(i)` insertion and on `_projectContextFor`) to state this exclusion explicitly.

**New/updated tests** (`test/ui/public_demo/public_demo_project_context_resolver_test.dart`, resolver unit suite grew from 18 → 24):
- `projectIdFor`: `partnerInterviewFailed`/`clientInterviewFailed` removed from the shared pass/fail-mixed loop; a new dedicated group pins `null` even when a `matchingProposalProjectId` (the just-failed project) and/or a `genuineInterviewProjectId` is supplied.
- `labelFor`: a new group pins that both failed stages never return `提案中の案件`.
- `resolve`: a new end-to-end group pins that both failed stages return `null` and never invoke `resolveCandidate` at all, even with a `matchingProposalProjectId` present — the Sales-pipeline card renders no project-context line for a failed stage.

**Verification:** `flutter analyze` (changed files) — no issues. `git diff --check` — no whitespace errors. Focused regression re-run after the fix: `public_demo_project_context_resolver_test.dart` (24), `public_demo_project_visibility_test.dart` (13), `public_demo_employee_roster_phase_b1_test.dart` + `public_demo_active_project_visibility_test.dart` + `public_demo_employee_ui_phase1_test.dart` + `public_demo_employee_visual_complete_test.dart` (63) — **100/100 passed, 0 failures.**

## Fresh Audit

Full read-only audit: `docs/reports/SES_FIRST-FUN-YEAR_Project-Order-Assignment-Visibility_Fresh-Audit.md` (committed alongside this report). Verdict: **GO**.

### Lifecycle authority map (summary — full table in the Fresh Audit)

`Project Candidate` (`PublicDemoSeededProjectGenerator`) → `Matching proposal` (`PublicDemoMatchingProposal`) → `Partner/Client interview` (`PublicDemoEngineerSales.stage` + `PublicDemoEngineerInterviewRecord`) → `Ordered` (`recordOrder`) → `Assignment materialization` (`assignOrderedForMay`/`recoverLateYearAssignment`/`appendPreEntryOrderAssignments`) → `Active` (`assignedEngineerIds(month:)`) → `End/renewal` (`endAssignment`/`replacementStage`). All unchanged by this Issue — every authority rule in the Issue's "MUST NOT VIOLATE" list is preserved verbatim (verified in the Fresh Audit and re-verified against the final diff below).

### Before/after visibility map

| Surface | Before | After |
|---|---|---|
| Sales-pipeline card (`ec(i)`) | Raw stage stepper only, no project identity at any stage | New line: `提案中の案件`/`受注案件：{real title}（{real client}・月額{real rate}万円）`, for `introduced`/`partnerInterviewPassed`/`clientInterviewPassed`/`ordered` — **not** `partnerInterviewFailed`/`clientInterviewFailed` (post-review fix, see below): an already-concluded failed interview shows no project-context line, never a stale "提案中" |
| Roster row (`_employeeRosterCard`) | Status badge + 経験/月給/単金 (単金 real-project-backed for 参画中 only) | + minimal `案件 {real title}` for `ordered` (参画予定 also gets the rate, since 単金 stays `—` there) |
| `activeProjectStatusCard` (Section 3, 参画中案件) | `PublicDemoAssignment.projectName` verbatim (generic placeholder even for a genuine project) | Real `Project.title` when a genuine `projectId` is attached, else unchanged fallback |
| June `assignmentCard` (営業タブ, 案件・参画/継続状況) | Same generic-placeholder issue | Same real-title fix |
| SkillSheet | Unchanged | Unchanged — no comprehension gap forced a change here (see Known Limitations) |
| Monthly Report / HOME | Unchanged | Unchanged (HOME Freeze) |

## Implementation decisions

1. **One new pure resolver, mirroring an existing convention.** `PublicDemoProjectContextResolver` (`lib/ui/public_demo/public_demo_project_context_resolver.dart`) follows `PublicDemoEmployeeStatusResolver`'s exact shape: static, stateless, takes only primitives/enums (plus an injected `resolveCandidate` callback so it never itself depends on `PublicDemoAggregate`/`PublicDemoState`), returns a small paired value object (`PublicDemoProjectContext`: label + title + clientName + monthlyRate) so label and content can never disagree.
2. **Priority order for "which project id is authoritative right now"**, in `projectIdFor`:
   - Currently assigned → `PublicDemoAssignment.projectId` only (the frozen identity once participation is real — never a possibly-stale interview/proposal id).
   - `ordered`, not yet assigned (受注済み・参画前) → `PublicDemoEngineerSales.genuineInterviewProjectId` first (the fresh Phase 6 pass), falling back to a pre-existing assignment row's `projectId` only for the rare case of a leftover prior-cycle entry.
   - Any pre-order pipeline stage (`introduced` through the client-interview pass/fail stages) → `genuineInterviewProjectId` once a pass exists, else the still-open `PublicDemoMatchingProposal.projectId`.
   - `waiting`/`skillSheet`/`selling` → always `null` (nothing has been introduced yet — `案件紹介` is the introduction event itself).
   This ordering is deliberate, not arbitrary: it is what correctly handles a real re-order (an engineer who ends an assignment, redoes the pipeline, and reaches `ordered` again before `assignOrderedForMay` next runs) without ever showing the previous cycle's stale project — verified by `_genuineInterviewPassFixture`'s own re-order-shaped test coverage.
3. **Reused, not reinvented, the real-title resolution.** `_realProjectNameFor` in the screen file is the identical `project?.title ?? assignment.projectName` pattern `PublicDemoAggregate._careerHistoryEntryFor` (Phase 7B) already established for the same `projectId → Project` lookup — found during the Fresh Audit, applied to `activeProjectStatusCard` and June's `assignmentCard`, which had never read it before (both always showed the raw, generic `PublicDemoAssignment.projectName` field, even when a genuine project was attached).
4. **Minimal roster addition, not a rewrite.** The roster row (`_employeeRosterCard`) only gains a segment for `ordered` (参画予定/参画中) — the Issue's own "最小追加" direction — and deliberately never repeats the rate: 単金 already shows it once assigned, so the new `案件` segment shows only the title there; the rate is added only for 参画予定, where 単金 is still `—`.
5. **No change to `ec(i)`'s render-site gating, eligibility, or button logic.** The new project-context line is purely additive inside the existing `Column`; every stage-branch button (`スキルシート確認`/`営業開始`/`案件紹介`/`上位会社面談`/`客先面談`/`受注`/`案件へ復帰`/`再営業`) is untouched.
6. **HOME untouched.** No HOME-owned file was opened for editing; `_officeStageStatusFor` and every other HOME source stay byte-for-byte as they were (verified: `git diff` touches only the four files listed below).

## Changed files

- New: `lib/ui/public_demo/public_demo_project_context.dart` — display value object.
- New: `lib/ui/public_demo/public_demo_project_context_resolver.dart` — pure resolver.
- New: `test/ui/public_demo/public_demo_project_context_resolver_test.dart` — 24 pure unit tests (18 at initial PR creation, +6 in the post-review fix below).
- New: `test/ui/public_demo/public_demo_project_visibility_test.dart` — 13 end-to-end widget tests across the real lifecycle.
- Modified: `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — four render sites (`ec(i)`, `_employeeRosterCard`, `activeProjectStatusCard`, `assignmentCard`) + three small helpers (`_projectContextFor`, `_orderedProjectRosterSegment`, `_realProjectNameFor`).
- New: `docs/reports/SES_FIRST-FUN-YEAR_Project-Order-Assignment-Visibility_Fresh-Audit.md`.
- New (this file): `docs/reports/SES_FIRST-FUN-YEAR_Project-Order-Assignment-Visibility_Result.md`.

No file under `lib/game/`, `lib/domain/`, or any HOME-prefixed presentation file was touched.

## Domain / save / economy impact

**None.** Every field read (`PublicDemoAssignment.projectId`, `PublicDemoEngineerSales.genuineInterviewProjectId`, `PublicDemoMatchingProposal.projectId`) was already persisted and already validated by `PublicDemoSaveCodec` before this change. No new domain field, enum, method signature, or save key. No eligibility/materialization rule changed — `ordered != assigned`, `revenue != cash receipt`, and every regression-protected authority (#227, #238, #236, #237, #219/#206, #207/#208) are read, never altered.

## Test results

All commands run against Flutter 3.35.5 / Dart 3.9.2 (this session's own SDK checkout; `pubspec.lock` left untouched — no dependency-version drift committed).

| Suite | Count | Result |
|---|---|---|
| `flutter analyze` (changed + new files, then the whole project) | — | No issues found |
| `test/game/public_demo/` (full domain suite) | 858 | All passed |
| `public_demo_employee_roster_phase_b1_test.dart`, `public_demo_active_project_visibility_test.dart`, `public_demo_employee_ui_phase1_test.dart`, `public_demo_employee_visual_complete_test.dart` (directly touched by this change) | 63 | All passed |
| `public_demo_project_context_resolver_test.dart` (pure-resolver unit tests; 18 at initial PR, +6 in the post-review fix) | 24 | All passed |
| Curated Order/Assignment/Matching/Recovery/Persistence UI suite: `public_demo_01_success_playthrough_test.dart`, `public_demo_01_recovery_ui_test.dart`, `public_demo_01_assignment_carryforward_test.dart`, `public_demo_01_suzuki_sales_reentry_test.dart`, `public_demo_01_suzuki_sales_yearend_boundary_test.dart`, `public_demo_01_persistence_test.dart`, `public_demo_matching_screen_test.dart`, `public_demo_project_interview_dialog_test.dart`, `public_demo_sales_ui_phase1_test.dart`, `public_demo_01_year_end_result_test.dart`, `public_demo_employee_status_unified_display_test.dart`, `public_demo_sales_visual_complete_test.dart` | 102 | All passed |
| `public_demo_project_visibility_test.dart` (end-to-end coverage for this Issue) | 13 | All passed |
| **Total newly-run/verified** | **1060** | **0 failures** |

(The 63/102/24/13 counts above were re-measured directly from this session's own test-runner output when preparing the post-review fix, correcting the initial PR's own Result Report, which had misstated the first row as 81.)

Full `test/ui/public_demo/` (67 files) was not run start-to-finish in this session: this environment's available CPU makes the complete directory take well beyond an hour per attempt (observed: two full attempts each exceeded 70+ minutes before being interrupted, with zero failures logged up to the point of interruption). Per the Issue's own instruction ("Full regressionはfocused修正ループごとに繰り返さず、PR最終段階/CIへ寄せる"), the full suite is left to CI, which runs on GitHub's own runners; the curated 102+13 UI tests above were chosen specifically to cover every card this change touches (roster, Sales-pipeline card, active-project card, June's assignment card) plus the surrounding lifecycle flows (playthrough, recovery, carryforward, re-entry, persistence, matching, project-interview dialog) most likely to interact with it.

### Verification matrix (Issue's own required matrix)

- Fresh April project → proposal → interviews → ordered: covered (`public_demo_project_visibility_test.dart`, "Sales-pipeline card" group).
- Ordered but not assigned = 参画予定 + correct project context: covered.
- Next-month assigned = 参画中 + same project identity/context: covered ("assigned (参画中)" group, identity checked via the exact same `projectId`/`Project.title` across ordered → assigned).
- Failed interview returns safely, no stale project context: **fixed post-review** (PR #240 Codex Broad Review P1 — see "Post-review fix" above); `projectIdFor`/`labelFor`/`resolve` are now all directly pinned, per-stage, to return `null`/never `提案中の案件` for `partnerInterviewFailed`/`clientInterviewFailed`, even with a still-recorded proposal for the just-failed project. `beginSelling`'s existing recovery path is unchanged.
- Assignment end/renewal/available: no authority touched; existing suites (`public_demo_01_assignment_carryforward_test.dart`, `public_demo_01_suzuki_sales_reentry_test.dart`, `public_demo_01_suzuki_sales_yearend_boundary_test.dart`) all still pass.
- Founding engineer + recruited engineer: this change reads engineer-generic fields only (no founding-vs-recruited branching); `public_demo_employee_roster_phase_b1_test.dart`'s own recruited-employee fixture already covers the roster row.
- Save/reload at proposal/interview/ordered/assigned boundary: covered directly (save/reload test in the new file) plus `public_demo_01_persistence_test.dart`.
- Duplicate/retry/ID-mismatch/malformed/legacy-state defenses: untouched — this change adds no new persisted field, so `PublicDemoSaveCodec`'s existing validation is unaffected; the legacy/generic (`projectId == null`) path is explicitly covered ("legacy/generic path" group) and falls back to the pre-existing generic text, never a crash or a fabricated project.
- Project-backed rate remains correct; waiting/unresolvable project stays dash/safe fallback: `_currentUnitPriceDisplayFor` is untouched; the new segments never duplicate or override it.
- 360×800 / 390×844, TextScaler 1.0/1.3, no overflow: covered directly (4 new tests) plus the pre-existing roster overflow suite, unaffected.

## 360 / 390 verification

Explicit `tester.takeException()` checks at `360×800` and `390×844`, `TextScaler` `1.0` and `1.3`, with a project-context line genuinely rendered (a real Phase 5 proposal fixture) — 4/4 pass, no overflow exception.

## Unresolved / Known Limitations

- **Pre-entry (applicant) sales pipeline has no real project identity.** `preEntrySkillSheet` → `preEntryClientPassed` → `juneOrdered` never attaches a `PublicDemoMatchingProposal`/interview-record equivalent — this is a pre-existing authority gap, not something this Issue's slice can (or should) fabricate a project for. `ac(i)`'s own stepper is unchanged.
- **SkillSheet's current-project line was scoped out.** The Issue's own "候補例" listed it as optional ("必要なら"); the roster row, Sales-pipeline card, and active-project card already give continuous visibility without it, so it was left as a real, ready-to-do follow-up rather than expanding this slice's surface area.
- **July+ replacement mini-cycle (`assignmentCard`'s own `replacementStage` continuation search) is a separate, generic state machine with no real project attached to its own replacement target.** During that specific window, `ec(i)`'s project-context line (when it renders at all for that engineer) still shows the *original* genuine interview project, since a replacement search has no real Phase 4/5/6 project of its own to show — this is a true fact (never fabricated), just potentially less crisp in this one rare corner. No existing test exercises `ec(i)` simultaneously with an in-progress replacement search, and this change does not alter that interaction's existing button/eligibility logic.
- Full `test/ui/public_demo/` regression was not completed end-to-end locally (see Test Results) — deferred to CI per the Issue's own guidance.

## Actual elapsed time

Initial PR: approximately 3 hours (Fresh Audit ~45 min; implementation ~40 min; self-hardening + format/import cleanup ~20 min; focused verification, including two interrupted full-suite attempts and the curated/targeted runs ~75 min; Result Report + commit/push/PR ~20 min) — within the Issue's own 2–3 hour target (excluding CI wait).

Post-review fix (PR #240 Codex Broad Review P1): approximately 35 minutes (fetch/confirm PR HEAD ~2 min; resolver + doc-comment fix ~10 min; unit test additions ~10 min; `flutter analyze`/`git diff --check`/focused regression re-run ~8 min; Result Report correction + commit/push ~5 min).

## PR URL

See the pull request opened from this branch (`claude/github-issue-239-nai2ql` → `main`), linked in this session's final response.
