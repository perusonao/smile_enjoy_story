# SES First Fun Year — Employee Status Unified Display — Result

Status: **Implemented, tested, committed, and pushed. PR opened
(https://github.com/perusonao/smile_enjoy_story/pull/238), not merged.**

Base: `origin/main` @ `faee0ce100662aed405f34af68596dcd30e6f3e9` (fetched fresh at
session start; unchanged from the audit session's SHA — no drift, no conflicts to
reconcile).

This implements the READ-ONLY Fresh Audit's recommendation
(`docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Fresh-Audit.md`,
verdict: **A — one PR, one pure presentation-layer consolidation, 2–3h**) verbatim.

## 0. Current status / Next action

Current status: implementation complete, self-reviewed, fully tested, committed, pushed,
PR opened. Next action: human review and merge (this session does not merge).

## 0.1 Actual elapsed time / Revised ETA

Actual elapsed time: a single continuous session — Flutter SDK provisioning (not
pre-installed in this environment), resolver design/implementation, two new focused test
files, two full-suite runs (`test/game/public_demo`, `test/ui/public_demo`), one
self-review pass (which found and fixed one additional related P2 beyond the Fresh
Audit's own two confirmed findings), SSOT sync, this report, commit, push, PR. Within the
Fresh Audit's own 2–3h implementation-size estimate.

Revised ETA: none — this task is complete pending human review/merge.

## 1. Base / Head

- Base: `origin/main` @ `faee0ce100662aed405f34af68596dcd30e6f3e9`.
- The designated branch (`claude/employee-status-unified-audit-d848ed`) held only an
  unrelated, far-stale commit from a much earlier point in the repo's history (799 files
  of drift, no PR opened against it) — restarted from `origin/main` per this session's own
  "stale/unrelated branch" handling policy, keeping the same branch name. The untracked
  Fresh Audit report from the prior audit session survived this reset (it was never
  committed, so `git reset --hard` did not touch it) and is committed together with this
  implementation.
- Final HEAD (implementation commit, before this final-URL doc update):
  `0b00a53d7c5a029f5ed34be466b3887968b2b1c3`.
- PR: https://github.com/perusonao/smile_enjoy_story/pull/238 (open, not merged).

## 2. What changed

### 2.1 New pure resolver

`lib/ui/public_demo/public_demo_employee_status_resolver.dart` (new file) —
`PublicDemoEmployeeStatusResolver.resolve(...)` and `PublicDemoEmployeeStatusDisplay`
(label + tone, always produced together). A pure function: takes only
`stage`/`isCurrentlyAssigned`/`isReadyForFieldSales`/`fieldSalesActionReachableThisMonth`
— primitives/enums the caller already computes from existing authoritative state — and
never reads `PublicDemoAggregate`/`PublicDemoState` itself, mirroring the existing
convention documented at the top of `public_demo_employee_visual.dart`. **Post-review
revision (§9):** the first version also took a caller-supplied `rawStageLabel` as a
fallback for the sales-pipeline sub-stages and for an `ordered`-not-yet-assigned
engineer; the current version is an exhaustive `switch (stage)` with an explicit branch
for every `PublicDemoSalesStage` value and takes no raw-label fallback at all, per the
PR #238 review follow-up (§9).

### 2.2 Call sites unified

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`:
- New `_employeeStatusDisplayFor(engineer)` — the one place this screen calls the
  resolver, computing its inputs from existing helpers
  (`_currentlyAssignedEngineerIds`, `readyForFieldSales`,
  `_fieldSalesActionReachableThisMonth`, `engineerStatus`).
- Replaces the former `_currentEmployeeStatusLabel` + `_employeeStatusTone` (社員タブ
  roster badge) — both deleted, single call site in `_employeeRosterCard` now computes
  the display once and reads `.label`/`.tone`.
- Replaces raw `engineerStatus(engineer)` at both SkillSheet call sites
  (`_openSkillSheetReview`, `_viewEmployeeSkillSheet`) with
  `_employeeStatusDisplayFor(engineer).label`.
- No other file changed. No domain file (`lib/game/public_demo/**`) touched. No save
  schema change (`schemaVersion` untouched — this PR never touches persistence at all).

### 2.3 HOME Freeze decision

**HOME is unchanged.** HOME's own `_officeStageStatusFor` is deliberately **not** routed
through the shared resolver in this PR. Rationale (documented in code at
`_employeeStatusDisplayFor`'s own doc comment): every prior consolidation touching this
same status logic (#231 Employee UI Phase 1, #235/#236) explicitly left
`_officeStageStatusFor` byte-for-byte untouched rather than share even
logically-equivalent code with it, treating any diff inside HOME-owned code as HOME
Freeze risk regardless of behavior preservation. This PR follows that same established
precedent. HOME still reads the exact same underlying facts
(`stage == ordered && assignedEngineerIds` membership) independently, so it cannot
disagree with the roster/SkillSheet on the *fact* — it simply does not yet share this
file's *implementation*. Routing HOME through the resolver is a safe, architecturally
ready follow-up once HOME Freeze is lifted or a behavior-preserving internal refactor is
explicitly confirmed acceptable.

## 3. Fixed inconsistencies

Both inconsistencies the Fresh Audit confirmed by tracing the code (§3), plus one
related P2 found during this session's own implementation/self-review pass:

1. **SkillSheet stale 翌月参画予定 (Fresh Audit finding).** An already-`ordered` +
   currently-assigned engineer's SkillSheet kept showing '翌月参画予定' — both SkillSheet
   call sites passed raw `engineerStatus(engineer)` straight through, which has no
   assignment-membership override — while the roster/HOME already correctly said
   '参画中' for the same engineer. Fixed by routing both call sites through
   `_employeeStatusDisplayFor`, which applies the same `stage == ordered &&
   isCurrentlyAssigned` check the roster already used.
2. **Training-selection label/tone mismatch (Fresh Audit finding).** The former
   `_employeeStatusTone` treated `PublicDemoState.trainingSelections.containsKey(id)` as
   higher priority than the waiting/ready split, while the label never checked
   `trainingSelections` at all — so a field-sales-ready (or genuinely `selling`/
   `introduced`/etc.) engineer with this month's training also selected showed the
   correct text painted in the training (red) tone. Fixed structurally: the resolver has
   no parameter through which `trainingSelections` can reach it at all, so label and tone
   are always derived from the same stage/assignment/readiness facts and can never
   disagree over a training selection.
3. **(Found during this session, not by the original audit) 参画中 tone required only
   assignment membership, not also `stage == ordered`.** The former `_employeeStatusTone`
   checked `_currentlyAssignedEngineerIds.contains(e.id)` alone for the assigned/green
   tone, while the former `_currentEmployeeStatusLabel`'s '参画中' branch already required
   **both** `stage == ordered` **and** assignment membership. These two conditions can
   genuinely diverge: `PublicDemoWorkflowState.endAssignment`'s own documented pre-July
   behavior — the assignment row is deliberately *kept* (not removed) when doing so would
   change this month's already-earned revenue count, while the engineer's `stage` is reset
   to `waiting` via `releaseFromAssignment()` — produces exactly `stage == waiting` with
   `isCurrentlyAssigned == true` for the remainder of that month. Under the old code this
   engineer's label correctly read 研修が必要/営業可能 while the tone incorrectly painted
   it green (参画中/assigned). The resolver requires both conditions together for its one
   参画中 branch, closing this gap by construction — pinned by
   `public_demo_employee_status_resolver_test.dart`'s own "参画中 requires BOTH" test.

4. **Sales-pipeline sub-stages/ordered-unassigned not actually collapsed (PR #238 review
   follow-up — see §9 for the full fix).** The first version's resolver still fell back
   to the caller-supplied raw `engineerStatus` label for every non-`waiting`,
   non-currently-assigned-`ordered` stage — so the roster/SkillSheet kept showing the raw,
   un-collapsed per-sub-stage text (営業準備/案件紹介済/各面談通過・不合格) and the raw
   '翌月参画予定' for an `ordered`-not-yet-assigned engineer, rather than Fresh Audit §4's
   actual six-value taxonomy (営業中 for all six pipeline sub-stages, 参画予定 for
   ordered-not-assigned). Fixed by making the resolver an exhaustive switch with an
   explicit branch for every stage.

No other P1/P2 was found in self-review. One unrelated, environment-specific side effect
was caught and reverted before committing: running the full `test/ui/public_demo` suite
locally regenerates 4 screenshot PNGs under `docs/reports/screenshots/` (a pre-existing
test, `public_demo_seeded_recruitment_visual_test.dart`, writes debug screenshots as a
side effect of running) with different bytes than committed — almost certainly font
rendering differences between this sandbox and wherever they were originally captured.
These were `git restore`d back to their committed content before staging; nothing in this
PR touches `docs/reports/screenshots/`.

## 4. Compatibility

- **#233 (Initial Employee / SkillSheet Gate Clarity).** The 営業可能/研修が必要 split,
  the `fieldSalesCapabilityRequirement` threshold, and the reason caption
  (`実力$threshold以上が必要（現在$capability）`) are all unchanged — the resolver reuses
  the exact same `readyForFieldSales`/`_fieldSalesActionReachableThisMonth` inputs #233
  established, verbatim. `public_demo_issue231_employee_skillsheet_clarity_test.dart`
  passes unmodified.
- **#236 (Employee Roster Phase B-1).** The 経験年数/月給/単金 compensation line is
  untouched — only the status badge above it now comes from the resolver.
  `public_demo_employee_roster_phase_b1_test.dart` passes unmodified.
- **#237 (Monthly Management Report Phase B).** `PublicDemoMonthlyReportSnapshot` never
  called any of the replaced functions (it reads `assignedEngineerIds`/`hasJoined`
  directly, never a label function) — nothing to regress.
  `public_demo_01_monthly_report_test.dart`/`public_demo_monthly_report_display_data_test.dart`
  pass unmodified.
- Mobile density (360×800/390×844 × TextScaler 1.0/1.3): existing roster-card overflow
  tests pass unmodified; two new regression scenarios (ordered+assigned roster row) added
  at all four size/scale combinations.

## 5. Tests

New/updated (post-review counts — see §9 for what changed since the initial PR):
- `test/ui/public_demo/public_demo_employee_status_resolver_test.dart` (pure unit tests,
  no widget pump) — every resolver branch (研修が必要/営業可能/待機/参画予定/参画中, and
  all seven sales-pipeline sub-stages individually asserted as 営業中), status priority
  (参画中 must win over ready-for-sales; 参画中 requires both `stage == ordered` and
  assignment membership; 参画予定 vs 営業中 are never confused), and the
  training-selection non-interference guarantee (both for a ready-and-waiting engineer
  and for one genuinely on the 営業中 pipeline). **17 tests, all passing.**
- `test/ui/public_demo/public_demo_employee_status_unified_display_test.dart`
  (real-screen widget tests, fixtures built via the same real domain-command chaining
  technique `public_demo_employee_roster_phase_b1_test.dart` already uses — never a
  hand-built/UI-driven fixture) — SkillSheet now reads 参画中 for an ordered+assigned
  engineer (never 翌月参画予定); a field-sales-ready engineer with training selected
  stays 営業可能 in the roster; an engineer genuinely at `stage == selling` reads 営業中
  in both the roster and SkillSheet; an engineer genuinely `ordered`-not-yet-assigned
  reads 参画予定 in the roster; four mobile-density no-overflow checks. **8 tests, all
  passing.**
- `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` (pre-existing, updated):
  one assertion's expected text updated from the raw '翌月参画予定' to the unified
  '参画予定' for the same ordered-not-assigned scenario it already covered (§9) — still
  passing, now asserting the current, intended text.

Full-suite verification (this session, via a self-provisioned Flutter 3.44.8 — pinned to
the same version `.github/workflows/public-demo-validation.yml` uses — since this
environment does not ship Flutter), run twice: once for the initial implementation, once
more after the §9 review follow-up:
- `flutter analyze` (whole project): **No issues found** (both rounds).
- `flutter test test/game/public_demo`: **858 tests, all passing** (both rounds —
  unaffected, as expected, since no domain file changed).
- `flutter test test/ui/public_demo` (full suite): **607/607 passing** after the initial
  implementation; **611/611 passing** after the §9 review follow-up (586 pre-existing +
  17 resolver unit tests + 8 widget regression tests).
- Focused suite (11 files covering both fixed inconsistencies, the §9 follow-up,
  #233/#236/#237, HOME, SkillSheet, monthly report) re-run after §9: **140 tests, all
  passing**, including HOME's own pre-existing literal '翌月参画予定' assertions
  (`public_demo_01_home_office_stage_test.dart`), confirming HOME is genuinely untouched.
- `git diff --check`: clean, no whitespace errors (both rounds).
- One unrelated side effect caught on every full-suite run and reverted before staging:
  running `test/ui/public_demo` regenerates 4 screenshot PNGs under
  `docs/reports/screenshots/` (`public_demo_seeded_recruitment_visual_test.dart` writes
  them as a side effect) with different bytes than committed — environment font-rendering
  differences, not a real change. Reverted via `git restore` every time; nothing in this
  PR touches `docs/reports/screenshots/`.

## 6. Files changed

- `lib/ui/public_demo/public_demo_employee_status_resolver.dart` (new)
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (modified — see §2.2)
- `lib/ui/public_demo/public_demo_employee_visual.dart` (doc-comment only — stale function
  name reference updated after the rename)
- `test/ui/public_demo/public_demo_employee_status_resolver_test.dart` (new, revised in §9)
- `test/ui/public_demo/public_demo_employee_status_unified_display_test.dart` (new,
  extended in §9)
- `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` (pre-existing file,
  one assertion's expected text updated in §9)
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` (Update history entries, incl.
  §9 follow-up)
- `docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md` (item 4 marked done,
  revised in §9 to state the taxonomy precisely and name the HOME wording gap explicitly)
- `docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Fresh-Audit.md`
  (committed alongside — was untracked from the prior READ-ONLY audit session)
- `docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Result.md` (this file)

## 7. Known limitations / unresolved

- HOME's `_officeStageStatusFor` is not yet routed through the shared resolver (§2.3) —
  intentional, per established HOME Freeze precedent, not an oversight. Follow-up once
  HOME Freeze is lifted or a behavior-preserving internal refactor is explicitly
  confirmed acceptable.
- No new save-schema field, no domain enum change, no economic-balance change — none was
  needed or made.
- The Fresh Audit's own §16 "Known Limitations" (interview sub-stage granularity folded
  into 営業中 for the card-level badge; no domain 契約終了/退職 exit state; 年齢/性別 still
  absent from any authority) are unchanged by this implementation — none were in this
  Issue's scope.

## 8. SSOT updates made

- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`: new 2026-09-11 Update history
  entry recording completion, explicitly not changing Current execution order/Prioritized
  backlog table structure (same convention #231/#235/#236/#237 used).
- `docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`: item 4 ("Employee
  lifecycle status clarity") marked done with a summary and pointer to this report.

## 9. PR #238 review follow-up (same day, same PR, same branch)

PR #238 was opened, then reviewed (automated Codex review + the human owner's own P1
review comment) before merge. Both independently flagged the same real gap:

**Finding:** the Fresh Audit's own §4 taxonomy specifies that every sales-pipeline
sub-stage (`skillSheet`/`selling`/`introduced`/partner-and-client interview pass/fail)
collapses to one player-facing **営業中** bucket, and that an `ordered`-but-not-yet-
assigned engineer reads **参画予定** (not the raw pipeline's own `翌月参画予定` text). The
first implementation's resolver still fell back to the caller-supplied raw
`engineerStatus` label for exactly those cases, so the roster/SkillSheet kept showing the
un-collapsed per-sub-stage text and the raw ordered-unassigned wording instead of the
taxonomy the PR's own description claimed to ship.

**Fix (this same PR/branch, no new Broad Review, no new PR):**
- `PublicDemoEmployeeStatusResolver.resolve` rewritten as an exhaustive
  `switch (stage)` with an explicit branch for every `PublicDemoSalesStage` value — no
  more `rawStageLabel` fallback parameter. `ordered` splits into 参画中 (assigned) /
  参画予定 (not yet assigned); `waiting` keeps its existing 研修が必要/営業可能/待機 split
  unchanged; the remaining six stages all return 営業中. Because the switch is now
  exhaustive, a future `PublicDemoSalesStage` value added without updating this file
  fails to compile, rather than silently reusing an un-collapsed raw label.
- `_employeeStatusDisplayFor` (`public_demo_01_placeholder_screen.dart`) updated to stop
  passing `rawStageLabel: engineerStatus(engineer)` — its own doc comment updated to
  record this fix and to be explicit that HOME's un-integrated wording gap (待機 vs
  研修が必要/営業可能, and now also 翌月参画予定 vs 参画予定, and raw pipeline sub-stage
  text vs 営業中) is a known, tracked difference, not a new regression.
- **No domain authority, save schema, economy, or HOME Freeze change** — `engineerStatus`
  itself (the raw 9-stage switch), `PublicDemoSalesProgress`'s stepper, the Sales tab, and
  `_officeStageStatusFor` are all byte-for-byte unchanged.
- Tests updated/added:
  - `public_demo_employee_status_resolver_test.dart`: the 7-stage loop now asserts every
    sales-pipeline sub-stage collapses to 営業中/waiting tone (not a caller-supplied raw
    label); the ordered-not-assigned test now asserts 参画予定 literally; a new priority
    test pins that 参画予定 and 営業中 are never confused with each other.
  - `public_demo_employee_status_unified_display_test.dart`: two new real-screen widget
    tests — an engineer genuinely driven to `stage == selling` (via the real
    `startSkillSheetReview`→`beginSelling` commands) reads 営業中 in both the roster and
    SkillSheet; an engineer genuinely `ordered` but not yet assigned reads 参画予定 in the
    roster (never 翌月参画予定).
  - `public_demo_employee_ui_phase1_test.dart` (pre-existing #231-era test): the one
    assertion that hard-coded the old raw '翌月参画予定' text for this exact
    ordered-not-assigned roster scenario was updated to '参画予定' — a deliberate,
    reviewer-directed label change, not a silently-tolerated regression (same precedent
    as prior status-text changes in this repo's own history, e.g. #231's own update to a
    "待機 for everyone" assertion).
- Verification: `flutter analyze` (whole project) — No issues. Focused tests (11 files
  covering both fixed inconsistencies, #233/#236/#237, HOME, SkillSheet, monthly report) —
  140 tests, all passing, including HOME's own pre-existing '翌月参画予定'-literal
  assertions (`public_demo_01_home_office_stage_test.dart`), confirming HOME truly is
  untouched. Full `test/game/public_demo` — 858 tests, all passing (unaffected). Full
  `test/ui/public_demo` (including the updated/new tests) — see §5 for the final count.
  `git diff --check` — clean.
- Final HEAD after this follow-up: see the commit this report ships with, same
  `claude/employee-status-unified-audit-d848ed` branch, same PR #238 (pushed, not merged).

## 10. Merge readiness

Not merged (per instruction — this session stops at PR-opened/PR-updated). Implementation,
self-review, and full-suite verification are complete for both the initial PR and this
review follow-up; CI will re-run the same checks this session already ran locally
(`flutter analyze`, `flutter test test/game/public_demo`, plus the two focused UI test
files this workflow names explicitly) via `.github/workflows/public-demo-validation.yml`,
and this session's own broader `test/ui/public_demo` full-suite run gives additional
confidence beyond that workflow's own narrower test selection.
