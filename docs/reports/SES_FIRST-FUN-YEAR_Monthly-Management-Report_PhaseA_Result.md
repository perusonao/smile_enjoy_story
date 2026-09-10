# SES First Fun Year — Monthly Management Report Phase A: Result Snapshot / Authority Adapter — Result Report

Status: **Implemented — Phase A only (Result Snapshot / authority adapter, no UI)**

## 0. Metadata

| item | value |
|---|---|
| Issue | [#232](https://github.com/perusonao/smile_enjoy_story/issues/232) — FIRST-FUN-YEAR P1: Monthly Management Report Phase A |
| Base `origin/main` SHA | `160b78ab972b00d787dc827620c23e1335144728` (fetched fresh at session start; matches the SHA Issue #232 itself records as confirmed at creation time) |
| Branch | `claude/github-issue-232-phase-a-a45c49`, reset from `origin/main` (repository default branch `claude/ses-game-core-phase-0-h7e8om` was **not** used, per Issue #232's explicit instruction) |
| Final HEAD SHA (this commit) | `22c90682b4236a89f2156b3326d991b952ddb0e6` |
| Scope | Phase A only: Result Snapshot + `netIncome`-equivalent derived getter + focused domain tests. **No Dialog/UI**, no in-month delta, no Finance/Payroll/Recruitment/Assignment/monthly-close change, no save-schema change. |

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
- `confirmedNextMonthJoinApplicantIds`: `workflow.applicants.where((a) => a.stage == PublicDemoApplicantStage.juneOrdered)`, the exact single-enum-value filter the existing `may()` production handler already uses verbatim (`public_demo_01_placeholder_screen.dart`). The broader "内定済み・入社待ち" pre-entry grouping the Audit also mentions (§6.1) was **deliberately left out of Phase A** — reproducing it would mean duplicating a currently UI/aggregate-local `accepted(applicant)` stage-set closure as a *new* named authority, which Issue #232's own rule ("UI/adapter独自の gameplay threshold/判定を作らない") argues against. Recorded as a Known Limitation (§6 below), not silently dropped.

## 3. Changed files

| file | change |
|---|---|
| `lib/game/public_demo/public_demo_monthly_cash_flow.dart` | +1 getter (`netIncome`), doc comment only otherwise. No field, no `toJson`/`fromJson` change. |
| `lib/game/public_demo/public_demo_monthly_report_snapshot.dart` | **New.** `PublicDemoMonthlyReportSnapshot` + `PublicDemoMonthlyReportStatus`. |
| `test/game/public_demo/public_demo_monthly_cash_flow_test.dart` | +1 test group (`14. netIncome`), 3 tests. |
| `test/game/public_demo/public_demo_monthly_report_snapshot_test.dart` | **New.** 11 tests across 8 groups. |

No other file touched. In particular, **not touched**: `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, any Finance/Payroll/Recruitment/Assignment/monthly-close file, `PublicDemoSaveCodec`, or any Employee/SkillSheet file (Issue #231's territory).

## 4. Mutation / persistence impact

- **Mutation**: none. `PublicDemoMonthlyReportSnapshot.fromAggregate` never calls an aggregate/state/workflow command; it only reads already-computed fields. A focused test (`8. no mutation of aggregate/state/workflow`) captures the aggregate's `state`/`workflow`/`cash`/engineer-id-list before two snapshot calls (including one with a deliberately mismatched month) and asserts every one of them is unchanged afterward (`identical()` on `state`/`workflow` plus value equality on `cash` and the engineer-id list).
- **Persistence**: no new persisted field. `netIncome` is absent from `PublicDemoMonthlyCashFlow.toJson()` (asserted directly by a test) and is recomputed identically after a `fromJson` round-trip. `PublicDemoMonthlyReportSnapshot` itself has no `toJson`/`fromJson` at all — it is a transient, presentation-adjacent read, never saved (matching Fresh Audit §13's "no schema change" recommendation; the Report-shown/not-shown question itself is explicitly Phase B/future scope, unaddressed here since there is no Dialog yet).
- **Save schema**: unchanged. No `PublicDemoSaveCodec` file touched.
- **Balance authority**: unchanged. No Finance/Payroll/Recruitment/Assignment/monthly-close file touched; `assignedEngineerIds` is read, never reimplemented.

## 5. Test results

All commands run from this branch's HEAD (`22c90682b4236a89f2156b3326d991b952ddb0e6`), Flutter 3.44.9 (stable) — matching the version pinned in `.github/workflows` CI (`subosito/flutter-action@v2`, `flutter-version: "3.44.9"`).

### Focused

```
flutter test test/game/public_demo/public_demo_monthly_report_snapshot_test.dart \
              test/game/public_demo/public_demo_monthly_cash_flow_test.dart
```
→ **31/31 passed** (11 new snapshot tests + 3 new `netIncome` tests + 17 pre-existing `public_demo_monthly_cash_flow_test.dart` tests, all still green).

Focused coverage against Issue #232's minimum test list:

| Issue #232 requirement | Test |
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
| 複数社員でも分類が安定 | `4. ...` sub-test `10. stays stable and consistent across repeated reads with multiple engineers` |
| (bonus, not in the minimum list but in scope) confirmed next-month joins | `5. confirmed next-month joins (juneOrdered)` (both sub-tests) |

### `flutter analyze`

```
Analyzing smile_enjoy_story...
No issues found! (ran in 16.5s)
```

### Full `flutter test`

```
00:00 +0: loading ...
...
13:19 +2185: All tests passed!
[exited with code 0]
```
→ **2185/2185 passed**, 0 failed. (One test name contains the substring "interviewFailed" as an enum-value name — not a failure; verified by inspection.)

### `git diff --check`

Exit code `0` — no trailing-whitespace / conflict-marker issues in the diff.

### Incidental cleanup

Running the full suite regenerated 4 unrelated visual-regression PNGs under `docs/reports/screenshots/` (pre-existing golden images unrelated to this change, touched by some other test's snapshot-writing side effect). These were reverted (`git checkout --`) before committing — this PR's diff is exactly the 4 files in §3, nothing else.

Mobile 360x800/390x844 visual verification was **not** performed, per Issue #232's own instruction ("Phase A はUI変更なしなので...visual verification は不要") — there is no UI change in this phase.

## 6. Known Limitations (Phase A → Phase B / future)

1. **In-month deltas (今月の応募数・面談数・新規受注数) are not implemented**, per explicit instruction. Fresh Audit §6.2/§7.2 confirms this is a genuine authority gap (no "when did this happen" field on `PublicDemoApplicant`/`PublicDemoAssignment`), not a Phase A oversight — a correct implementation would need either a new domain fact or a non-persisted month-start snapshot, both explicitly deferred to a future phase/issue.
2. **Broader "内定済み・入社待ち" pre-entry-pipeline grouping is not exposed.** Only the single, already-canonical `juneOrdered` stage is read for "confirmed to join next month." Exposing the wider pre-entry set (offerAccepted + all preEntry* stages) would require duplicating a currently UI/aggregate-local `accepted(applicant)` closure as a new named authority — deliberately avoided this phase per Issue #232's "no new gameplay threshold/判定" rule. A future phase can promote that closure to a proper named domain authority if this data turns out to be needed for the UI.
3. **No Dialog/UI, no Report "seen/skipped" tracking.** Per Fresh Audit §13, Report-shown persistence is explicitly not recommended (no save-schema benefit), and building the Dialog itself is Phase B/Issue #231-dependent — untouched here.
4. **`PublicDemoMonthlyReportSnapshot` is not persisted and does not need to be** — it is a pure, on-demand read; nothing here changes reload/save behavior.

## 7. Actual elapsed time

Approximately 2 hours of active session time (investigation/authority trace, design, implementation, focused+full verification including a from-scratch Flutter 3.44.9 SDK install in this container, Result Report, commit/push/PR), within Issue #232's own 1.5–2.5h estimate (excluding CI wait).

## 8. PR

https://github.com/perusonao/smile_enjoy_story/pull/234

---

_Generated by [Claude Code](https://claude.ai/code)_
