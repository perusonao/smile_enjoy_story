# SES FIRST-FUN-YEAR P1: Employee Roster Management Data — Phase B-1 Result

Issue: #235
PR: https://github.com/perusonao/smile_enjoy_story/pull/236
Status: **Merge Ready — Codex Broad Review P2 resolved, reconciled with latest
`origin/main` (incl. merged PR #233/#234), CI green (`validate`/`replay-unit`/`smoke-e2e`/
`Public Demo only`/`Build Public Demo browser preview`, GitHub `mergeable_state: clean`),
review thread resolved. Not merged — this session stops at Merge Ready per instruction.**
Base at initial implementation: `origin/main` @
`160b78ab972b00d787dc827620c23e1335144728`
Base after reconcile: `origin/main` @ `d45e375d1be087a23fe041c1d21543f0833231ab`

## 0. Current status

Phase B-1 is implemented, reconciled with the latest `origin/main`, and pushed. The
社員一覧 (`_employeeRosterCard`, `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`)
shows, per employee, a compact compensation line — 経験年数 (experience) ・ 月給 (monthly
salary) ・ 単金 (unit price) — below the existing name/status-badge row, PR #233's own
sales-readiness reason caption, and the skill capability bar.

This report supersedes its own first version (written against the pre-reconcile base SHA
`160b78a`). Since that version, one Codex Broad Review P2 finding was fixed (単金 now shows
a real project rate when one is safely resolvable — see §3), and the branch was reconciled
with `origin/main` after PR #233 (Package B) and PR #234 (Monthly Report Phase A) both
merged ahead of this PR.

## 0.1 Next action

Human review and merge of PR #236. This session does not merge it. Phase B-2 (年齢/性別,
product decision required first) remains an independent, unstarted follow-up per the
issue's own §7 split.

## 0.2 Actual elapsed time / Revised ETA

- Actual elapsed time, this reconcile+fix session: a single continuous session — Fresh
  Authority Trace for the Codex finding, the fix itself, a `git merge origin/main` conflict
  resolution (two files), an expanded focused test file, full-suite re-verification, and
  this report/SSOT/PR-body update.
- Revised ETA: none — this reconcile+fix round is complete. Phase B-2 (年齢/性別) remains
  unestimated pending its own product decision, unchanged from Phase A's own estimate.

## 1. Base / Head

- Base at initial Phase B-1 implementation: `origin/main` @
  `160b78ab972b00d787dc827620c23e1335144728`.
- Base at this reconcile: `origin/main` @ `d45e375d1be087a23fe041c1d21543f0833231ab`
  (post PR #234 merge; confirmed via `git fetch origin` at the start of this round — no
  further commits had landed on `origin/main` beyond this SHA at reconcile time).
- Original PR #236 HEAD (pre-reconcile): `29055c6b7471f1957b6d6efa090e8b3174675e06`.
- Final HEAD: see the commit this report ships with (`git log -1 --format=%H` on
  `claude/ses-issue-235-phase-b1-upu7vj`) — a `git merge origin/main` merge commit plus the
  Codex P2 fix, test expansion, and this doc update, all as one push.

## 2. Reconcile result

`git merge origin/main` (not a rebase — this repo's own convention for reconciling a
feature branch with an updated base once other work has already merged ahead of it, per
prior branches in this history, e.g. "Merge origin/main (PR #233 Package B) into Phase A
branch"). Two conflicts, both resolved by keeping both sides' additions (never dropping
either PR's work):

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — `_employeeRosterCard()`:
  PR #233's not-ready reason-caption `Text` block (`if (e.stage == waiting &&
  !readyForFieldSales(e.id)) ...`) and this PR's compensation-line `Text` block both kept,
  in that order (reason caption directly under the skill bar, compensation line last).
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — Update history: this PR's own
  entry (revised in place, see §7 below) kept at the top, followed by the pre-existing
  entries for Issue #232 Phase A (PR #234) and Issue #231 Package B (PR #233) unchanged.

No other file conflicted. `mergeable_state` on the PR was `dirty` before this push (per the
task's own report) — expected to read `clean`/mergeable after this push.

## 3. Codex P2 resolution

**Finding**: "Use project-backed rates instead of always showing a dash"
(`https://github.com/perusonao/smile_enjoy_story/pull/236#discussion_r3980381437`,
`chatgpt-codex-connector`, thread `PRRT_kwDOT2htY86hH6dn`) — for an engineer genuinely
assigned through the Phase 5/6 matching flow, `PublicDemoAssignment.projectId` identifies
the real project and is resolvable via `PublicDemoSeededProjectGenerator.regenerate`; the
original Phase B-1 implementation rendered `単金 —` unconditionally, hiding that
authoritative rate.

### Fresh Authority Trace (against `origin/main` @ `d45e375`)

Re-verified against the current `origin/main`, not assumed from the review comment alone:

- `PublicDemoAssignment.projectId` (`lib/game/public_demo/public_demo_assignment.dart`) —
  confirmed present, `String?`, "the real Phase 4/5/6 `Project` id this assignment actually
  represents ... when it was created from a genuine, project-bound Phase 6 project-interview
  pass ... `null` for every assignment created before this field existed, and for one still
  built from the generic, project-agnostic interview path."
- `PublicDemoSeededProjectGenerator.regenerate({required int runSeed, required String
  projectId})` (`lib/game/public_demo/public_demo_project_generator.dart`) — confirmed:
  "Recovers the exact candidate a given `projectId` ... represents, purely from `(runSeed,
  projectId)` — no save-data dependency ... Returns `null` for an id this generator did not
  mint." Already used for exactly this resolution shape by
  `PublicDemoAggregate._industryByEngineerId` (feeds Growth's per-engineer industry) and by
  `PublicDemoAggregate.endAssignment`'s `CareerHistoryEntry` writer — this is not a new
  resolution path, it is a third caller of an existing one.
- `PublicDemoProjectCandidate.monthlyRate` (`int get monthlyRate => project.monthlyRate;`,
  same file) — confirmed present and reads straight through to the real `Project`, not a
  second/derived figure.
- Cross-checked `PublicDemoSaveCodec._hasConsistentAuthorityFacts`
  (`lib/game/persistence/public_demo_save_codec.dart`) — confirmed it cross-checks every
  non-null `assignments[*].projectId` against the corresponding engineer's own
  `interviewRecord.projectId`, and migrates a pre-existing-field-less legacy save's
  `projectId` to an explicit `null` (never leaves a dangling/malformed string). This means:
  any non-null `projectId` that legitimately reaches the roster card via a real save is, by
  construction, resolvable — the "cannot resolve" branch is defensive-only, mirroring the
  identical pattern `_industryByEngineerId` already uses (see §5 unresolved-item note).

**Verdict: the finding is correct on current `origin/main`.** Fixed.

### Fix

- New private helper `_currentUnitPriceDisplayFor(String engineerId)` on the roster screen
  State, gated on three conditions, all of which must hold before any real rate is shown:
  1. `_currentlyAssignedEngineerIds.contains(engineerId)` — the exact same authoritative
     "currently assigned" fact the status badge/label already reads. Checked *before*
     looking at any assignment row, because `PublicDemoWorkflowState.endAssignment`'s own
     doc records that an ended assignment's row is sometimes deliberately left in place
     rather than removed — a bare `workflow.assignments` scan alone could otherwise show a
     stale project's rate for someone no longer actually earning it.
  2. `_assignmentForOrNull(engineerId)?.projectId` is non-null (the existing lookup already
     used by the SkillSheet sheet for the same engineer's "current assignment").
  3. `PublicDemoSeededProjectGenerator.regenerate(runSeed: s.runSeed, projectId: projectId)`
     resolves to a non-null candidate.
- Only when all three hold: `単金 ${candidate.monthlyRate ~/ 10000}万円`. Otherwise (waiting,
  generic/legacy assignment with no `projectId`, or an unresolvable id): `単金 —`.
- **Never** `PublicDemoRevenue.ratePerAssignedEngineer` (the flat ¥600,000/month
  per-headcount constant) is shown as an individual employee's rate, at any point.
- No new data model, no `PublicDemoAssignment`/save-schema field, no Finance/Revenue
  formula change — purely a new *read* of three pieces of authority that already existed
  and were already used elsewhere in this exact combination.

## 4. Unit-rate authority trace (summary table)

| Case | Authority read | Result |
|---|---|---|
| Genuinely assigned, real Phase 5/6 project-bound assignment | `PublicDemoAssignment.projectId` → `PublicDemoSeededProjectGenerator.regenerate` → `PublicDemoProjectCandidate.monthlyRate` | Real project rate (e.g. `単金 60万円`) |
| Waiting (not assigned) | `_currentlyAssignedEngineerIds` does not contain the id | `単金 —` |
| Genuinely assigned, generic/legacy assignment (`projectId == null`) — e.g. Recovery-assigned via the pre-Phase-5/6 sales pipeline | `PublicDemoAssignment.projectId` is `null` | `単金 —` |
| Genuinely assigned, `projectId` set but unresolvable (defensive-only; not reachable via any legitimate save — see §3's `_hasConsistentAuthorityFacts` note) | `PublicDemoSeededProjectGenerator.regenerate` returns `null` | `単金 —`, no crash |

## 5. Package B compatibility

PR #233 (Issue #231 Package B) merged into `origin/main` on 2026-09-10 23:23 JST (merge
commit `2abbef854d54597139830869195acbb7064f1616`) — **before** this reconcile, so the
"PR #233 not yet merged" note in this report's and the PR's original text is now stale and
has been corrected throughout (see §2's reconcile-conflict resolution and the SSOT update).

Verified by test (see §6) that, on the same roster row:

- 氏名, PR #233's own 参画状況 badge (営業可能/研修が必要/参画中/待機) and its not-ready
  reason caption (`営業には実力60以上が必要（現在52）` for eng-02 in the fresh-April
  fixture), スキル (capability bar), 経験年数, 月給, and 単金 all render together with no
  dropped text and no overflow, at 360x800/390x844 × TextScaler 1.0/1.3.
- `_currentEmployeeStatusLabel`, `_employeeStatusTone`, `readyForFieldSales`,
  `_fieldSalesActionReachableThisMonth`-gated Section 2 clarity (`営業準備OK` / the
  not-ready lock banner) are all read verbatim, unmodified by this reconcile or the Codex
  fix.

## 6. What changed (cumulative, vs. `origin/main` @ `160b78a`)

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — `_employeeRosterCard()`
  plus the new `_currentUnitPriceDisplayFor` helper. Adds:
  - 経験年数/月給 line items (unchanged from the original Phase B-1 implementation): read
    from `s.runtimeForOrNull(e.id)?.totalItExperienceMonths` /
    `PublicDemoSalary.currentMonthlySalaryFor`.
  - 単金 (this round's fix): real project rate when genuinely resolvable, `—` otherwise —
    see §3/§4.
  - No existing widget/key/section/eligibility check was touched; PR #233's own reason
    caption block is unmodified, just re-ordered to sit above the new compensation line.
- `test/ui/public_demo/public_demo_employee_roster_phase_b1_test.dart` — expanded from 12
  to 20 test cases (see §6.1 below).
- `docs/reports/SES_FIRST-FUN-YEAR_Employee-Roster-Management-Data_Fresh-Audit.md` —
  unchanged from the original Phase B-1 push (Phase A's audit, carried forward).
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — the Issue #235 Update history
  entry rewritten in place (see §7) to record the Codex P2 fix and the corrected PR #233
  merge status; no other entry's text changed (the merge brought in PR #233/#234's own
  entries verbatim).
- This Result Report — rewritten (see header) to reflect the reconcile and fix.

No file under `lib/game/public_demo/public_demo_revenue.dart`,
`public_demo_salary_finance.dart`, any Assignment/save-codec file, `lib/presentation/home/`,
or any Sales/Recruitment file was touched by this round. `schemaVersion` stays `1`. No new
gameplay threshold was introduced.

### 6.1 Focused test file — 20 cases, all green

- founding employee: compensation line reads existing authority (unchanged from original).
- recruited employee: applicant-sourced salary/experience (unchanged from original).
- **単金: waiting employee shows "—"** (new, explicit).
- **単金: legacy/generic assignment (`projectId == null`) shows "—"** (renamed/clarified
  from the original "waiting vs assigned" test; now explicitly asserts
  `assignment.projectId == null` as fixture sanity).
- **単金: project-backed assignment shows the real project rate** (new) — a genuine eng-01
  assignment built through the real Phase 5 matching (`proposeMatch`) → Phase 6 project
  interview (`startProjectInterview`/`chooseProjectInterviewFollowUp`/
  `concludeProjectInterview`) → `recordOrder` → April/May close flow (scanning a bounded
  seed range for a genuine client-interview pass, mirroring
  `public_demo_career_history_writer_test.dart`'s own `_genuineAssignedAggregate`
  technique), asserting the card shows the exact
  `PublicDemoSeededProjectGenerator.regenerate(...).monthlyRate`, and that this value is
  never the flat ¥600,000 constant.
- **単金: project-backed — save/reload** (new): the same genuine fixture, round-tripped
  through `PublicDemoSaveCodec`, shows the identical rate after reload.
- **単金: an unresolvable project id never crashes, always falls back to "—"** (new) — a
  direct-call test pinning `PublicDemoSeededProjectGenerator.regenerate` returning `null`
  (not throwing) for a malformed/unminted id — the exact guard
  `_currentUnitPriceDisplayFor` depends on. See §3's note on why a full UI-level round trip
  for this exact case cannot be constructed through the legitimate save codec.
- salary display / experience display / skill display (unchanged from original).
- **Package B (営業可能/研修が必要 caption) coexistence** (rewritten from the original
  "regression" test, which had noted PR #233 was unmerged — it now is) — asserts 営業可能
  (eng-01)/研修が必要 + reason caption (eng-02) render together with the compensation line
  on the same row, plus a new 360x800/390x844 × TextScaler 1.0/1.3 overflow sweep for this
  combined card content.
- save/reload (general, unchanged from original).
- 360x800/390x844 × TextScaler 1.0/1.3 overflow (unchanged from original).

## 7. Tests (full verification, this round)

Environment note: no Flutter SDK was preinstalled in this session's container (same as the
original Phase B-1 session); the same locally-installed Flutter 3.44.9 (stable, matching
this repo's CI `subosito/flutter-action` pin) was reused.

- `flutter analyze` (whole project, post-reconcile+fix): **No issues found.**
- New focused test file (expanded): **20/20 green.**
- Existing roster suites, unmodified, re-run against the merged tree:
  `public_demo_employee_ui_phase1_test.dart` + `public_demo_employee_visual_complete_test.dart`
  + `public_demo_issue231_employee_skillsheet_clarity_test.dart` (PR #233's own dedicated
  suite, now present after the merge): **42/42 green.**
- `test/ui/public_demo/` (full suite): **560/560 green** (up from 533 pre-reconcile,
  reflecting PR #233's own new test files brought in by the merge, plus this round's own
  8 additional focused cases).
- `test/game/public_demo/` (full domain suite, sanity check — no domain file touched):
  **858/858 green** (up from 842 pre-reconcile, reflecting PR #234's own new
  `public_demo_monthly_report_snapshot_test.dart` suite brought in by the merge).
- `git diff --check`: clean, no whitespace errors, after the merge-conflict resolution.

## 8. Visual verification

360x800/390x844 × TextScaler 1.0/1.3 verified via `tester.getRect()` bounds assertions
(never visual/screenshot inspection, consistent with the original Phase B-1 round) — this
round adds a dedicated sweep for the combined card (name + 営業可能/研修が必要 badge +
reason caption + skill bar + compensation line) in the "Package B coexistence" group (§6.1),
in addition to the pre-existing sweeps in the original compensation-line test group and in
`public_demo_employee_ui_phase1_test.dart`'s own suite (which also exercises TextScaler 2.0).

## 9. Known limitations / Unresolved items

1. **単金's "cannot resolve" branch is defensive-only, not reachable via any legitimate
   save.** `PublicDemoSaveCodec._hasConsistentAuthorityFacts` guarantees any non-null
   `projectId` reaching the roster card is consistent with a real matching
   proposal/interview record, so `PublicDemoSeededProjectGenerator.regenerate` returning
   `null` in production would require data this codec already refuses to load. The branch
   is kept anyway (mirroring `_industryByEngineerId`'s identical defensive pattern) and is
   tested directly at the function level (§6.1) rather than through an unconstructible
   UI-level round trip.
2. **年齡・性別 remain unimplemented**, per the issue's own instruction — unchanged from
   the original Phase B-1 round; Fresh Audit §5.1/§5.2 already recorded the minimal-extension
   proposals and the open product question for a future Phase B-2.
3. This PR is **not merged** — per this task's explicit instruction, the session stops at
   Merge Ready (green tests, resolved review thread, reconciled with latest `origin/main`)
   and does not merge.

## 10. Review thread resolution

Thread `PRRT_kwDOT2htY86hH6dn` (Codex P2 "Use project-backed rates instead of always
showing a dash") — replied with the fix summary and Fresh Authority Trace result
(`https://github.com/perusonao/smile_enjoy_story/pull/236#discussion_r3981228302`), then
marked resolved via the GitHub API. No new Broad Review was requested (per instruction). No
P0/P1 findings were surfaced by this round's own re-verification.

## 11. CI

All checks on the final head (`6dc3977`) completed successfully: `replay-unit`, `Build
Public Demo browser preview`, `Public Demo only`, `validate` (the full
`flutter analyze`/`flutter test`/web-build gate), `smoke-e2e`. GitHub reports
`mergeable_state: "clean"`.

## 12. PR

https://github.com/perusonao/smile_enjoy_story/pull/236 — **Merge Ready, not merged** (per
instruction, this session stops here).
