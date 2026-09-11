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
`stage`/`isCurrentlyAssigned`/`isReadyForFieldSales`/`fieldSalesActionReachableThisMonth`/
`rawStageLabel` — primitives/enums the caller already computes from existing
authoritative state — and never reads `PublicDemoAggregate`/`PublicDemoState` itself,
mirroring the existing convention documented at the top of
`public_demo_employee_visual.dart`. Never re-derives the raw 9-stage label switch that
already lives in `engineerStatus` — that remains the single place that literal switch is
written; the resolver takes it as an input (`rawStageLabel`) instead.

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

New:
- `test/ui/public_demo/public_demo_employee_status_resolver_test.dart` (pure unit tests,
  no widget pump) — every resolver branch (研修が必要/営業可能/営業中 sub-stages/
  参画予定/参画中/待機 fallback), status priority (参画中 must win over ready-for-sales;
  参画中 requires both `stage == ordered` and assignment membership), and the
  training-selection non-interference guarantee. 15 tests, all passing.
- `test/ui/public_demo/public_demo_employee_status_unified_display_test.dart`
  (real-screen widget tests, fixtures built via the same real domain-command chaining
  technique `public_demo_employee_roster_phase_b1_test.dart` already uses — never a
  hand-built/UI-driven fixture) — SkillSheet now reads 参画中 for an ordered+assigned
  engineer (never 翌月参画予定); a field-sales-ready engineer with training selected
  stays 営業可能 in the roster; four mobile-density no-overflow checks. 6 tests, all
  passing.

Full-suite verification (this session, via a self-provisioned Flutter 3.44.8 — pinned to
the same version `.github/workflows/public-demo-validation.yml` uses — since this
environment does not ship Flutter):
- `flutter analyze` (whole project): **No issues found.**
- `flutter test test/game/public_demo`: **858 tests, all passing** (unaffected, as
  expected — no domain file changed).
- `flutter test test/ui/public_demo` (full suite, including both new files): **607
  tests, all passing** (baseline 586 + 15 new resolver unit tests + 6 new widget
  regression tests).
- `git diff --check`: clean, no whitespace errors.
- One unrelated side effect caught on both full-suite runs and reverted before staging:
  running `test/ui/public_demo` regenerates 4 screenshot PNGs under
  `docs/reports/screenshots/` (`public_demo_seeded_recruitment_visual_test.dart` writes
  them as a side effect) with different bytes than committed — environment font-rendering
  differences, not a real change. Reverted via `git restore` both times; nothing in this
  PR touches `docs/reports/screenshots/`.

## 6. Files changed

- `lib/ui/public_demo/public_demo_employee_status_resolver.dart` (new)
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (modified — see §2.2)
- `lib/ui/public_demo/public_demo_employee_visual.dart` (doc-comment only — stale function
  name reference updated after the rename)
- `test/ui/public_demo/public_demo_employee_status_resolver_test.dart` (new)
- `test/ui/public_demo/public_demo_employee_status_unified_display_test.dart` (new)
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` (Update history entry)
- `docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md` (item 4 marked done)
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

## 9. Merge readiness

Not merged (per instruction — this session stops at PR-opened). Implementation,
self-review, and full-suite verification are complete; CI will re-run the same checks
this session already ran locally (`flutter analyze`, `flutter test test/game/public_demo`,
plus the two focused UI test files this workflow names explicitly) via
`.github/workflows/public-demo-validation.yml`, and this session's own broader
`test/ui/public_demo` full-suite run gives additional confidence beyond that workflow's
own narrower test selection.
