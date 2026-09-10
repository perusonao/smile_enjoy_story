# SES First Fun Year — Monthly Management Report Phase A: Result Snapshot / Authority Adapter — Result Report

Status: **Implemented — Phase A only (Result Snapshot / authority adapter, no UI). Codex Broad Review P1 findings × 2 fixed; PR reconciled with latest `origin/main` (PR #233).**

## 0. Metadata

| item | value |
|---|---|
| Issue | [#232](https://github.com/perusonao/smile_enjoy_story/issues/232) — FIRST-FUN-YEAR P1: Monthly Management Report Phase A |
| PR | [#234](https://github.com/perusonao/smile_enjoy_story/pull/234) |
| Original base `origin/main` SHA | `160b78ab972b00d787dc827620c23e1335144728` (PR #234's original base, confirmed against Issue #232's own recorded SHA) |
| Latest `origin/main` SHA at this update | `2abbef854d54597139830869195acbb7064f1616` (PR #233 "Package B — Initial Employee/SkillSheet Gate Clarity" merged) |
| Branch | `claude/github-issue-232-phase-a-a45c49` — same branch as PR #234's initial submission, **not** a new PR. Merged forward to latest `origin/main` (`git merge`, no rebase/force-push) after re-fetching. Repository default branch was **not** used at any point. |
| Final HEAD SHA (this update) | `5e39fa23c5a6c21279afee006c39107f291213c4` |
| Scope (unchanged from initial submission) | Phase A only: Result Snapshot + `netIncome`-equivalent derived getter + focused domain tests. **No Dialog/UI**, no in-month delta, no Finance/Payroll/Recruitment/Assignment/monthly-close change, no save-schema change, no Phase B. |

## 1. Fresh authority trace

Both authorities named by Issue #232 were read before writing any code:

1. **Issue #232 body** (full text) — scope, required fields, explicit out-of-scope list, authority rules ("must not violate"), and the Definition of Done.
2. **`docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report_Fresh-Audit.md`** — not yet on `origin/main` at the time of this session (it lives on `claude/monthly-report-fresh-audit-7bt7ag`, still unmerged); fetched from that branch and read in full (all 22 sections) as the audit's own findings, per Issue #232's instruction to treat it as authority regardless of merge state. Key facts this implementation is built directly on:
   - §5.1/§8: `PublicDemoState.latestMonthlyCashFlow` (`PublicDemoMonthlyCashFlow`) is the single finance SSOT for a closed month; `openingCash`/`closingCash` already carry cash-before/after, no monthly-close re-run needed.
   - §5.2: "純損益" has no existing single field; `revenue - totalOutflow` is the recommended 1-line derived getter, named to match existing `netCashMovement` (this report calls it `netIncome`, exactly as Issue #232's own code sketch names it).
   - §4/§12: a no-op close (blocked month) leaves the *previous* month's `latestMonthlyCashFlow` in place — a snapshot must verify `latestMonthlyCashFlow.month` against the month it believes it's reporting, or it will misattribute a stale result.
   - §7.1: `PublicDemoWorkflowState.assignedEngineerIds({required int month})` is the sole participate/wait SSOT; `workflow.engineers` already contains every joined applicant (`withJoinedEngineers`), so filtering that list by `assignedEngineerIds` reproduces exactly what HOME's Office Stage / 社員タブ already show — no new classification invented.
   - §6.1/§6.2: "現在のパイプライン状態" (e.g. `stage == juneOrdered`, "受注済み・翌月入社予定") is safely delta-free and directly readable; "今月の応募/面談/受注 N件" is a genuine GAP (no "when did this happen" field exists) and is explicitly out of Phase A scope.
   - §14/§19: Phase A's predicted changed-files list (`public_demo_monthly_report_snapshot.dart` + `netIncome` getter + focused test) is what this PR implements, unchanged.

Also consulted per `AGENTS.md`'s required-reading rule: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` and `docs/DEVELOPMENT_PLAN.md` (current governing priority/plan) — no conflict found; First Fun Year Management Report is the active P1 focus, and this Phase A stays inside the "progression/financial correctness over presentation" priority (no presentation work at all in this phase).

## 2. Snapshot design

### `PublicDemoMonthlyCashFlow.netIncome` (`lib/game/public_demo/public_demo_monthly_cash_flow.dart`)

```dart
int get netIncome => revenue - totalOutflow;
```

One-line, read-only derived getter, same pattern as the existing `netCashMovement`/`totalOutflow` getters on the same class. Not a `copyWith` parameter, not in `toJson`/`fromJson` — no persisted field added, no save-schema change (verified by a dedicated test — see §5).

### `PublicDemoMonthlyReportSnapshot` (`lib/game/public_demo/public_demo_monthly_report_snapshot.dart`)

```dart
factory PublicDemoMonthlyReportSnapshot.fromAggregate(
  PublicDemoAggregate aggregate, {
  required int closedMonth,
})
```

- Input is exactly one already-closed `PublicDemoAggregate` (the same value a caller would hold immediately after `_commitAggregate(_game.closeX(...))`, per the Audit's own recommended call site) plus the `closedMonth` the caller believes it just closed.
- Reads only `aggregate.state.latestMonthlyCashFlow` and `aggregate.workflow.{engineers, applicants, assignedEngineerIds}` — **no** aggregate/state/workflow command is ever called from inside this factory, and nothing is mutated (defense-in-depth: `PublicDemoAggregate`/`PublicDemoState`/`PublicDemoWorkflowState` are themselves immutable value classes, so a mutation would be a Dart compile error, not just a runtime bug — the "no mutation" focused test documents this contract rather than trying to catch an impossible bug).
- `PublicDemoMonthlyReportStatus` enum: `ready` / `notYetRecorded` (`latestMonthlyCashFlow == null`) / `staleClosedMonth` (`latestMonthlyCashFlow.month != closedMonth`). Only `ready` populates `cashFlow`/`assignedEngineers`/`waitingEngineers`/`confirmedNextMonthJoinApplicantIds` — the other two statuses return an otherwise-empty snapshot rather than exposing a stale or absent flow under the wrong month's label. This directly encodes Fresh Audit §4/§12's stale-month warning as a type-level guard rather than a comment.
- Assigned/waiting split: `workflow.engineers` filtered by `workflow.assignedEngineerIds(month: aggregate.state.month)` — deliberately keyed by the aggregate's own **current** month (already advanced past `closedMonth` by the close that produced this aggregate, per Fresh Audit §3), matching exactly how HOME's `_officeStageDisplay`/`_currentEmployeeStatusLabel` already read this same authority. No new participate/wait judgment is introduced.
- `confirmedNextMonthJoinApplicantIds`: `workflow.applicants.where((a) => a.stage == PublicDemoApplicantStage.juneOrdered && !a.hasJoined)`. The `stage == juneOrdered` half is the exact single-enum-value filter the existing `may()` production handler already uses verbatim (`public_demo_01_placeholder_screen.dart`); the `!hasJoined` half was added in response to a Codex Broad Review P1 finding (§2.1 below) — `PublicDemoApplicant.join` mints a `PublicDemoJoinRecord` without ever clearing `stage`, so `juneOrdered` is a **permanent** "won this June order" identity that survives the join, not a pending-join flag. `hasJoined` is itself an existing, already-named authority (WORKFLOW-STATE-1AB FIX2 P1-4), reused verbatim — not a new judgment. The broader "内定済み・入社待ち" pre-entry grouping the Audit also mentions (§6.1) was **deliberately left out of Phase A** — reproducing it would mean duplicating a currently UI/aggregate-local `accepted(applicant)` stage-set closure as a *new* named authority, which Issue #232's own rule ("UI/adapter独自の gameplay threshold/判定を作らない") argues against. Recorded as a Known Limitation (§6 below), not silently dropped.

### 2.1 Codex Broad Review fixes (this update)

PR #234's Codex Broad Review (already completed before this update — no new Broad Review was requested) flagged 2 P1 findings, both fixed in this update:

1. **Exclude applicants who have already joined.** `confirmedNextMonthJoinApplicantIds` originally read `stage == juneOrdered` alone. Since `stage` never clears after a genuine join, an applicant who joined in May (say) would still show `stage == juneOrdered` in June, July, ... every later month — and the snapshot would keep reporting them as a "next month" join forever. Fixed by adding `&& !applicant.hasJoined`. See the updated bullet above and §5's new regression tests.
2. **Record Phase A completion in the governing plan.** `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` (the AGENTS.md-mandated governing SSOT) did not record Issue #232 Phase A's completion. Fixed by adding a new Update-history entry (dated 2026-09-10) that records: Phase A is implemented; it is explicitly the read-only Result Snapshot/authority adapter only; Phase B (Dialog/UI) is **not** implemented and the P1 "月次結果・経営フィードバック改善" backlog bucket therefore stays open (not marked 完了); and how this fits the current First Fun Year execution order (no change to it). Follows the exact same partial-completion recording pattern the doc already uses for the adjacent Issue #231/#229 entries.

Also corrected in this update (flagged directly by the user, not Codex): the PR body and this report previously said building Phase B's Dialog was "Phase B/Issue #231-dependent." That was wrong — Issue #232's own "Parallelism" section only asks that Phase B *start from* the latest `origin/main` once #231 merges (to minimize file conflicts in the large `public_demo_01_placeholder_screen.dart` both would eventually touch), which is a sequencing choice, not a functional dependency between the two features. Phase B remains a separate future Issue/task, not implemented here. See §6 below for the corrected wording.

## 3. Changed files

### Initial submission

| file | change |
|---|---|
| `lib/game/public_demo/public_demo_monthly_cash_flow.dart` | +1 getter (`netIncome`), doc comment only otherwise. No field, no `toJson`/`fromJson` change. |
| `lib/game/public_demo/public_demo_monthly_report_snapshot.dart` | **New.** `PublicDemoMonthlyReportSnapshot` + `PublicDemoMonthlyReportStatus`. |
| `test/game/public_demo/public_demo_monthly_cash_flow_test.dart` | +1 test group (`14. netIncome`), 3 tests. |
| `test/game/public_demo/public_demo_monthly_report_snapshot_test.dart` | **New.** 11 tests across 8 groups. |
| `docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report_PhaseA_Result.md` | **New** — this report. |

### This update (Codex P1 fixes + `origin/main` reconciliation)

| file | change |
|---|---|
| `lib/game/public_demo/public_demo_monthly_report_snapshot.dart` | P1-1 fix: `confirmedNextMonthJoinApplicantIds` now also requires `!applicant.hasJoined`. Doc comments updated to explain why. |
| `test/game/public_demo/public_demo_monthly_report_snapshot_test.dart` | +3 regression tests (already-joined excluded; later month does not re-announce; save/reload round-trip preserves the judgment before and after join) — group now 14 tests, file totals 17 tests. |
| `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` | P1-2 fix: new Update-history entry recording Phase A completion (see §2.1). |
| `docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report_PhaseA_Result.md` | This update (P1 fixes, reconciliation, corrected Phase B/#231 wording, refreshed test results). |
| *(merge commit only, no manual edits)* `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`, `docs/reports/SES_FIRST-FUN-YEAR_Initial-Employee-SkillSheet-Clarity_P1_Result.md`, `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, `lib/game/public_demo/public_demo_employee_visual.dart`, and 4 test files under `test/ui/public_demo/` | Brought in verbatim from `origin/main` by `git merge origin/main` (PR #233's own changes) — not authored or altered by this task. See §4.1. |

No Finance/Payroll/Recruitment/Assignment/monthly-close file, `PublicDemoSaveCodec`, or Dialog/UI file was touched by this task's own commits at any point.

### 3.1 Reconciliation with latest `origin/main` (PR #233)

PR #234 was originally opened against `origin/main` at `160b78a...` (pre-PR #233). Per this update's instructions, `git fetch origin` was re-run, confirming latest `origin/main` is `2abbef8...` (PR #233 "Package B — Initial Employee/SkillSheet Gate Clarity" merged). The branch was reconciled with `git merge origin/main` (a merge commit, not a rebase/force-push — this PR's own branch, no other collaborator had pushed to it, and a merge is the least disruptive way to pick up PR #233 without rewriting this PR's existing, already-reviewed commit history).

**Merge result: clean, zero conflicts.** `git diff --stat` confirms the merge brought in exactly PR #233's own 9 files (`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`, a new `docs/reports/SES_FIRST-FUN-YEAR_Initial-Employee-SkillSheet-Clarity_P1_Result.md`, `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, `lib/game/public_demo/public_demo_employee_visual.dart`, and 5 test files) verbatim, with no overlap against this PR's own 5 files (Phase A touches only `public_demo_monthly_cash_flow.dart`/`public_demo_monthly_report_snapshot.dart`/2 test files/this report — exactly as the "Parallelism" section of the original PR body predicted). PR #233's Initial Employee/SkillSheet Gate Clarity change is untouched by this task; the Public Demo test run in §5 (1398 tests, including every `public_demo_issue231_*`/`employee_ui_phase1`/`employee_visual_complete` test PR #233 added or touched) confirms it.

## 4. Mutation / persistence impact

- **Mutation**: none. `PublicDemoMonthlyReportSnapshot.fromAggregate` never calls an aggregate/state/workflow command; it only reads already-computed fields. A focused test (`8. no mutation of aggregate/state/workflow`) captures the aggregate's `state`/`workflow`/`cash`/engineer-id-list before two snapshot calls (including one with a deliberately mismatched month) and asserts every one of them is unchanged afterward (`identical()` on `state`/`workflow` plus value equality on `cash` and the engineer-id list).
- **Persistence**: no new persisted field. `netIncome` is absent from `PublicDemoMonthlyCashFlow.toJson()` (asserted directly by a test) and is recomputed identically after a `fromJson` round-trip. `PublicDemoMonthlyReportSnapshot` itself has no `toJson`/`fromJson` at all — it is a transient, presentation-adjacent read, never saved (matching Fresh Audit §13's "no schema change" recommendation; the Report-shown/not-shown question itself is explicitly Phase B/future scope, unaddressed here since there is no Dialog yet).
- **Save schema**: unchanged. No `PublicDemoSaveCodec` file touched.
- **Balance authority**: unchanged. No Finance/Payroll/Recruitment/Assignment/monthly-close file touched; `assignedEngineerIds` is read, never reimplemented.

## 5. Test results

Flutter 3.44.9 (stable) throughout — matching the version pinned in `.github/workflows` CI (`subosito/flutter-action@v2`, `flutter-version: "3.44.9"`). Both this update's rounds below were run **after** the `origin/main` merge (§3.1) and the P1-1 code fix, i.e. against the final tree being pushed.

### Focused (Monthly Report)

```
flutter test test/game/public_demo/public_demo_monthly_report_snapshot_test.dart \
              test/game/public_demo/public_demo_monthly_cash_flow_test.dart
```
→ **34/34 passed** (14 snapshot tests — 11 original + 3 new P1-1 regression tests — + 3 `netIncome` tests + 17 pre-existing `public_demo_monthly_cash_flow_test.dart` tests, all green).

Focused coverage against Issue #232's minimum test list, plus this update's new P1-1 regression requirements:

| Requirement | Test |
|---|---|
| April→May close後の snapshot | `1. April close -> May snapshot` |
| ordinary month close後の snapshot | `2. ordinary month close snapshot (June -> July -> August)` |
| openingCash / closingCash / netCashMovement 一致 | `3. finance fields agree field-for-field...` |
| revenue / payroll / expenses 一致 | `3. finance fields agree field-for-field...` |
| derived net income 一致 | `3. ...` + `public_demo_monthly_cash_flow_test.dart` group 14 (3 tests) |
| assigned/waiting が `assignedEngineerIds` と一致 | `4. assigned/waiting agree with assignedEngineerIds` (both sub-tests) |
| latestMonthlyCashFlow null | `6. latestMonthlyCashFlow null` |
| stale month mismatch を安全に扱う | `7. stale month mismatch is handled safely` |
| snapshot生成で aggregate/state/workflow mutationなし | `8. no mutation of aggregate/state/workflow` |
| 複数社員でも分類が安定 | `4. ...` sub-test `10. stays stable...` |
| juneOrdered + 未入社 → 含む | `5. ...` `an applicant who genuinely reached juneOrdered is reported` |
| juneOrdered + 入社済み → 含まない (P1-1) | `5. ...` `an applicant who has already joined is excluded...` (**new**) |
| 入社後の後続月 → 再告知しない (P1-1) | `5. ...` `a later month's snapshot does not re-announce a completed join` (**new**) |
| save/reload後も判定が変わらない (P1-1) | `5. ...` `save/reload does not change the judgment` (**new**) |
| staleClosedMonth / notYetRecorded の既存挙動を壊さない | `6.`/`7.` (unchanged, still green) |

### `flutter analyze`

```
Analyzing smile_enjoy_story...
No issues found! (ran in 5.2s)
```

### Public Demo test suite (`test/game/public_demo` + `test/ui/public_demo`)

```
flutter test test/game/public_demo test/ui/public_demo
...
12:27 +1398: All tests passed!
[exited with code 0]
```
→ **1398/1398 passed**, 0 failed — including every test PR #233 added/touched (`public_demo_issue231_employee_skillsheet_clarity_test.dart`, `public_demo_employee_ui_phase1_test.dart`, `public_demo_employee_visual_complete_test.dart`, `public_demo_01_home_consolidation_test.dart`, `public_demo_01_success_playthrough_test.dart`), confirming the merge did not regress PR #233's Initial Employee/SkillSheet Gate Clarity behavior.

(The prior round of this report separately ran the *entire* project `flutter test` — 2185/2185 green, pre-merge — and `flutter analyze` clean; not re-run project-wide this round since this update's own instruction scoped verification to Monthly Report focused tests + Public Demo-related tests, both re-run above against the final, merged, P1-fixed tree.)

### `git diff --check`

Exit code `0` (checked again after this update's commits) — no trailing-whitespace / conflict-marker issues.

### Incidental cleanup

Both this update's `flutter test` runs again regenerated the same 4 unrelated visual-regression PNGs under `docs/reports/screenshots/` (a pre-existing golden-image side effect of some other test, unrelated to Monthly Management Report). Reverted (`git checkout --`) before each commit, exactly as the initial submission did — this PR's diff never includes them.

Mobile 360x800/390x844 visual verification was **not** performed, per Issue #232's own instruction ("Phase A はUI変更なしなので...visual verification は不要") — there is no UI change in this phase.

## 6. Known Limitations (Phase A → Phase B / future)

1. **In-month deltas (今月の応募数・面談数・新規受注数) are not implemented**, per explicit instruction. Fresh Audit §6.2/§7.2 confirms this is a genuine authority gap (no "when did this happen" field on `PublicDemoApplicant`/`PublicDemoAssignment`), not a Phase A oversight — a correct implementation would need either a new domain fact or a non-persisted month-start snapshot, both explicitly deferred to a future phase/issue.
2. **Broader "内定済み・入社待ち" pre-entry-pipeline grouping is not exposed.** Only the single, already-canonical `juneOrdered` stage is read for "confirmed to join next month." Exposing the wider pre-entry set (offerAccepted + all preEntry* stages) would require duplicating a currently UI/aggregate-local `accepted(applicant)` closure as a new named authority — deliberately avoided this phase per Issue #232's "no new gameplay threshold/判定" rule. A future phase can promote that closure to a proper named domain authority if this data turns out to be needed for the UI.
3. **No Dialog/UI, no Report "seen/skipped" tracking.** Per Fresh Audit §13, Report-shown persistence is explicitly not recommended (no save-schema benefit). Building the Dialog itself is Phase B — a separate future Issue/task, not implemented here and not functionally dependent on Issue #231. (Issue #232's own §"Parallelism" only asked that Phase B *start from* the latest `origin/main` once #231 merges, to minimize file conflicts in the large `public_demo_01_placeholder_screen.dart` both would otherwise touch — that is a sequencing choice, not a dependency between the two features.)
4. **`PublicDemoMonthlyReportSnapshot` is not persisted and does not need to be** — it is a pure, on-demand read; nothing here changes reload/save behavior.

## 7. Actual elapsed time

- Initial submission (investigation/authority trace, design, implementation, focused+full verification including a from-scratch Flutter 3.44.9 SDK install in this container, Result Report, commit/push/PR): ~2 hours, within Issue #232's own 1.5–2.5h estimate (excluding CI wait).
- This update (re-fetch/reconcile with `origin/main`, 2× Codex P1 fixes + regression tests, governing-plan Update-history entry, Phase B/#231 wording correction, re-verification, review-thread replies/resolves, Result Report refresh): ~45 minutes (excluding CI wait).
- **Revised ETA for PR #234 reaching Merge Ready**: this update completes PR #234's outstanding work — no further ETA beyond CI running on the pushed commits.

## 8. PR / review status

- PR: https://github.com/perusonao/smile_enjoy_story/pull/234 (same branch, `claude/github-issue-232-phase-a-a45c49` — not a new PR)
- Codex Broad Review: already completed before this update; **not re-requested**, per instruction. Both of its P1 findings fixed and replied to on their own threads, then resolved via `resolve_review_thread`:
  - P1-1 "Exclude applicants who have already joined" — fixed (§2.1), replied, resolved.
  - P1-2 "Record Phase A completion in the governing plan" — fixed (§2.1), replied, resolved.
- No PR was merged by this task, as instructed — PR #234 is left open at Merge Ready for the repository owner to merge.

---

_Generated by [Claude Code](https://claude.ai/code)_
