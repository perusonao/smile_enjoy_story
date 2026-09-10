# SES FIRST-FUN-YEAR P1: Order-Assignment Timing Fix — Result Report

Issue: #227
Base SHA: `aa8fe3f84ce022ecaa57f108a9cce5aff00de5e8` (issue-creation main, `origin/main`)
Head SHA: _filled in at commit time — see PR description_
Branch: `claude/issue-227-dst0k4`
Recommended/used AI: Claude Code Sonnet 5

## 1. Goal recap

Fresh Audit (#226, off #225's Human Replay) found a genuine P1 progression
defect: a real April order (`engineer.stage == ordered`, backed by a genuine
Phase 6 client-interview pass) stayed un-assigned — no `PublicDemoAssignment`
on `PublicDemoWorkflowState.assignments` — through the **whole of May**. The
assignment only materialized when May's own close ran
(`PublicDemoAggregate.closeMay` → `assignOrderedForMay()`), one month later
than the stated design ("受注した翌月に参画する" — order this month, assignment
next month). Revenue happened to stay correct (a separate `engineersAssigned`
counter drives it), but Employee/Office status, training eligibility, and the
参画中案件 card all read `workflow.assignments`/`assignedEngineerIds`, so the
player could genuinely observe "前月に受注したのに今月参画していない".

Required fix (minimal P1 slice): materialize the April order's assignment
during `closeApril()`, reusing the existing `assignOrderedForMay()` authority
— never a second assignment formula — while introducing no duplicate
assignment/revenue/growth/payroll side effects, preserving genuine
`engineerId`/`projectId`/interview authority, and verifying June+/ordinary-
month cadence and second-order (`nextOrderStatus`) timing are not disturbed.

## 2. Root cause

`PublicDemoWorkflowState.assignOrderedForMay()` — the sole domain-owned
roster builder, which rebuilds `assignments` from current
`ordered`/`hasGenuineInterviewRecord` (engineers) and
`juneOrdered`/`hasJoined` (applicants) stage facts — was called from exactly
one production site: `PublicDemoAggregate.closeMay()`, i.e. the May→June
transition. `PublicDemoAggregate.closeApril()` (April→May) never called it,
so nothing added a genuinely-ordered April engineer to `assignments` until
May itself closed.

A second, latent problem sat behind the obvious one: `assignOrderedForMay()`
always constructed a **brand new** `PublicDemoAssignment` for every
qualifying engineer/applicant on every call (`PublicDemoAssignment
.forOrderedEngineer(...)`, `monthsCredited` defaulting to `0`), never
consulting any assignment already on the roster. That was safe only because
the method ran exactly once per playthrough. Simply adding a second call site
in `closeApril()` — as the audit's own suggested fix does — would have made
`closeMay()`'s later call **wholesale-discard** whatever the April-created
entry had already accumulated (any `nextOrderStatus`/`replacementStage`/
`fieldEvaluation` change, and its `monthsCredited`), a real regression the
audit's literal instruction ("reuse `assignOrderedForMay()`") would have
silently introduced. Fixing the call-site alone was not sufficient; the
method itself had to become safe to call more than once.

## 3. Production changes

### 3.1 `lib/game/public_demo/public_demo_workflow_state.dart`

`assignOrderedForMay()` is now idempotent/upsert instead of a destructive
full rebuild:

- The **eligibility set** (which engineer/applicant ids belong on the
  roster) is still recomputed from current stage facts on every call,
  exactly as before — an entry whose engineer/applicant no longer qualifies
  is still dropped.
- For each qualifying id, an **existing** entry on `assignments` (built by
  an earlier call this same method made) is now reused byte-for-byte —
  `nextOrderStatus`, `replacementStage`, `fieldEvaluation`, `projectId`, and
  `monthsCredited` all carried forward untouched.
- Only an id with **no existing entry** gets a freshly-built one (the exact
  same construction logic as before, extracted into a new private helper,
  `_freshOrderedAssignment`, so it composes with the `??` reuse — the
  original `if (... case ...)` collection-element shape cannot itself sit on
  the right-hand side of `??`).
- The applicant (`juneOrdered`/`hasJoined`) branch gets the identical
  existing-entry-reuse treatment for symmetry, though in production it can
  only ever build fresh entries — applicants cannot reach `juneOrdered` +
  `hasJoined` before May's own join step runs.

No other method in this file changed. `_withAssignments` stays private;
there is still no way to inject an arbitrary roster from outside this file.

### 3.2 `lib/game/public_demo/public_demo_aggregate.dart`

`closeApril()` now ends with `workflow: grown.workflow.assignOrderedForMay()`
instead of `workflow: grown.workflow` — the one-line functional change. Every
other statement in `closeApril()` (the `state.month != 4 ||
state.isCloseBlocked` idempotency guard, `_closeGrowth(const {})`, the
`orderedEngineers: workflow.orderedEngineerCount` revenue projection) is
unchanged.

### 3.3 Test fixture update

`test/ui/public_demo/public_demo_01_home_office_stage_test.dart`: one
existing widget test explicitly pinned the pre-fix behavior ("assignOrderedForMay
has not run yet in May itself" / "...has now built the assignment, in June").
Updated to assert the corrected behavior — the engineer is truthfully
`参画中` (not `翌月参画予定`) from the moment April closes, and the assignment
survives May's own close untouched into June. No other test file needed a
behavior change; every other suite already exercised the *correct* target
behavior or was unaffected.

## 4. Before/after state-transition table

| Point in time | Before fix | After fix |
|---|---|---|
| April closes (month 4→5) | `workflow.assignments` unchanged (no entry) | `assignOrderedForMay()` runs; a genuine April order gets a fresh `PublicDemoAssignment` (`monthsCredited: 0`, real `projectId` when Phase 6 minted one) |
| During May (`assignedEngineerIds(month: 5)`) | Does **not** contain the April-ordered engineer | **Contains** the April-ordered engineer |
| May UI: Office Stage / Employee status | `翌月参画予定` (stale — no further stage transition ever occurs) | `参画中` (truthful) |
| May UI: internal training card for that engineer | Rendered (wrongly available) | Suppressed (`_currentlyAssignedEngineerIds` now excludes them) — no code change needed here; it already read `workflow.assignedEngineerIds` |
| May UI: 参画中案件 card | Absent | Present |
| May's own close (`closeMay`, month 5→6) | `assignOrderedForMay()` runs for the *first* time — builds a fresh entry, `monthsCredited: 0` | `assignOrderedForMay()` runs again — finds the April-built entry via `existingAssignmentFor` and **reuses it as-is** (no reset) |
| Growth credit at May's close | `creditAssignmentMonths` credits the just-built entry → `monthsCredited: 1` | `creditAssignmentMonths` credits the *same, reused* entry → `monthsCredited: 1` (identical end value — first genuine credit opportunity is May's close either way) |
| June onward | `参画中`, `monthsCredited` continuing from 1 | Identical — no behavior change from June onward |
| `projectId` (genuine Phase 6 project link) | Set once, at June-close time | Set once, at April-close time, then carried forward unchanged by every later `assignOrderedForMay()` call |

## 5. Second-order (next-order cadence) verification

Confirmed the earlier-materialized assignment does **not** pull the
continuation-decision UI ("7月分の発注を確認"/`decideOrder`) one month early:

- `assignmentCard(i)` — the only render site with the `nextOrderStatus ==
  undecided` → "7月分の発注を確認" button — is gated by `if (s.month == 6)`
  (`public_demo_01_placeholder_screen.dart`, `_salesProjectStatusCards`).
- `_addAssignmentCandidate` (HOME's Recommended Action mirror of the same
  branch) is likewise only invoked from inside `if (s.month == 6) { ... for
  (a in workflow.assignments) _addAssignmentCandidate(add, a); }`.

Both gates key off `s.month`, never off whether the `PublicDemoAssignment`
object exists — so an assignment now existing from May onward (instead of
June onward) does not change when either CTA becomes visible. The domain
*fact* `nextOrderStatus == undecided` does exist through May (as the audit
anticipated), but it was never otherwise surfaced or acted on before June, so
this is a non-issue — no cadence fix was required in this slice.

## 6. Ordinary-month timing (June→July, July+) — unaffected, verified

Order-to-assignment timing for June onward is governed by an entirely
separate, pre-existing mechanism this fix never touches: once an engineer's
first assignment exists (built by `assignOrderedForMay`, now in April or May
depending on when they first ordered), all later continuation/replacement
timing is a same-entry mutation, never a rebuild —
`withAssignmentUpdate`/`consumeSlotAndSetReplacementStage`
(nextOrderStatus/replacementStage progression) and
`recoverLateYearAssignment` (RECOVERY-LOOP-1's July–February upsert, whose
own doc already documents the append/upsert contract this fix's
`assignOrderedForMay` change now mirrors). `closeJune`/`closeJuly` never call
`assignOrderedForMay()` at all. Confirmed unaffected by running the full
recovery suite (`public_demo_recovery_regression_test.dart`,
`public_demo_recovery_aggregate_test.dart`) and the ordinary-month close
suite (`public_demo_monthly_close_ordinary_month_test.dart`) — all pass
unchanged.

## 7. Save/reload, idempotency, retry, projectId — verified

- **Idempotency of `assignOrderedForMay` itself**: the pre-existing test
  "calling assignOrderedForMay again never duplicates an assignment" still
  passes; it now holds more strongly than before (identical object reuse,
  not just structural/id-set equality).
- **April→May→June two-call path**: exercised end-to-end by the updated
  `public_demo_01_home_office_stage_test.dart` widget test, which plays
  through April, checks May, then June, in one continuous session.
- **Retry/double-tap on `closeApril`**: unchanged — the existing
  `state.month != 4 || state.isCloseBlocked` guard still makes a retried
  `closeApril()` call a complete no-op (the new `assignOrderedForMay()` call
  sits inside that same guarded branch, never outside it).
- **No duplicate assignment/revenue/growth/payroll**: `orderedEngineers:
  workflow.orderedEngineerCount` (the revenue-side count `advanceToMay`
  consumes) is unchanged — it already read the identical `ordered`-stage
  fact independent of whether an assignment object existed.
  `assignOrderedForMay()` itself never touches cash, `engineersAssigned`, or
  payroll. `_closeGrowth(const {})` in `closeApril` is unchanged (empty
  credited-id set), so no engineer gets an extra growth-credited month from
  this change.
- **Genuine `projectId` retention**: `_freshOrderedAssignment` still reads
  `engineer.genuineInterviewProjectId` exactly as before; once built (now in
  April), the entry is reused by identity on every later
  `assignOrderedForMay()` call, so `projectId` is never recomputed, dropped,
  or overwritten.
- **Save/reload**: no `PublicDemoAssignment`/`PublicDemoWorkflowState`
  schema change — `toJson`/`fromJson` untouched. Full save-codec suite
  (`public_demo_save_codec_test.dart`,
  `public_demo_assignment_lifecycle_save_codec_test.dart`) passes unchanged.

## 8. Test results

Flutter/Dart SDK was not present in this container by default (matching the
prior audit's own noted limitation) — Flutter 3.44.8 (the version pinned in
`.github/workflows/public-demo-validation.yml`) was installed locally for
this session to run real tests, not inferred from source reading alone.

- `flutter analyze` (whole project): **No issues found.**
- Focused suites directly exercising this change (workflow state, aggregate,
  monthly close, month-guard/persistence UI, save codec): **158/158 passed**
  (`public_demo_monthly_close_test.dart`,
  `public_demo_monthly_close_revenue_test.dart`,
  `public_demo_monthly_close_ordinary_month_test.dart`,
  `public_demo_workflow_state_test.dart`, `public_demo_aggregate_test.dart`,
  `public_demo_01_month_guard_april_may_june_test.dart`,
  `public_demo_01_month_guard_recommended_test.dart`,
  `public_demo_01_persistence_test.dart`, `public_demo_save_codec_test.dart`).
- Issue-mandated regression coverage (#220 project-interview reachability,
  #222 post-May join lifecycle, #224 seeded balance, recovery/replacement
  cycle, assignment lifecycle, founder follow-up, career-history writer,
  workflow snapshot): **153/153 passed**
  (`public_demo_project_interview_test.dart`,
  `public_demo_post_may_join_lifecycle_test.dart`,
  `public_demo_seeded_balance_regression_test.dart`,
  `public_demo_recovery_regression_test.dart`,
  `public_demo_recovery_aggregate_test.dart`,
  `public_demo_assignment_lifecycle_test.dart`,
  `public_demo_assignment_lifecycle_save_codec_test.dart`,
  `public_demo_career_history_writer_test.dart`,
  `public_demo_founder_follow_up_test.dart`,
  `public_demo_workflow_snapshot_test.dart`).
- The one test that pinned the pre-fix bug
  (`public_demo_01_home_office_stage_test.dart`) was updated to assert the
  correct behavior and now **passes (19/19 in that file)**.
- Full project `flutter test` (all files under `test/`): launched separately
  and takes materially longer than the targeted runs above (the full suite
  includes multi-month seeded-strategy-bot playthroughs). Every suite that
  actually exercises the changed files — `public_demo_workflow_state.dart`
  and `public_demo_aggregate.dart` — is already covered and green by the
  targeted runs listed above, which is the real regression surface for this
  change; this report will be amended with the full run's own pass/fail
  count once it finishes if anything beyond that surface turns up.

## 9. Unresolved items / severity

None found in this P1 slice's scope. The audit's `発注を受注する` wording
note is explicitly P2/non-blocking per the issue and was not touched.

## 10. Actual processing time

Approximately 70 minutes, including installing Flutter 3.44.8 locally (no
SDK was preinstalled in this session) and running the full targeted-suite
matrix above, within the issue's own 45–90 minute estimate.

## 11. PR

_[filled in once opened]_
