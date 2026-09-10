# SES First Fun Year — Order→Assignment Fresh Audit (Issue #226)

## Audited SHA

`aa8fe3f84ce022ecaa57f108a9cce5aff00de5e8` (`origin/main`, fetched at task start; matches
the SHA already recorded in Issue #226 and in the Post-Balance Human Replay Fresh
Triage report — no drift since triage).

## Environment limitation (must read before "tests executed")

This session's container has **no Flutter/Dart SDK installed** (`flutter`, `dart` are
both absent from `PATH` and not found anywhere on disk). `flutter test`/`flutter
analyze` could not be executed. All reproduction below is therefore a **static trace**
through production source plus **citation of an already-existing, already-passing test
in the repository** (`test/ui/public_demo/public_demo_01_home_office_stage_test.dart`)
that independently pins the exact defect this audit found, with its own doc comments
explaining the same root cause reached here from the other direction (UI truthfulness)
rather than the finance/growth direction this audit started from. No test was written,
run, or modified. No production code was changed. This is the audit's single blocking
limitation; see "Recommended immediate follow-up" at the end.

## Goal / scope recap

Trace `SkillSheet → selling → 案件紹介/提案 → 上位会社面談 → 客先面談 → 発注/受注 →
月末 → 翌月参画` through production authority (not UI guesswork) and classify the
Human Replay finding "前月に受注したはずなのに翌月参画していない" as A/B/C/D. READ-ONLY;
no HOME/Employee/Finance redesign, no production fix applied.

## 1. What "受注" means today (Q1/Q2)

`受注` is a single, company-side action with no separate "client issues an order"
step: `PublicDemoWorkflowState.recordOrder(engineerId)`
(`lib/game/public_demo/public_demo_workflow_state.dart:764-769`) transitions
`PublicDemoEngineerSales.stage` from `clientInterviewPassed` → `ordered`, gated so it
is a no-op unless the engineer is currently exactly at `clientInterviewPassed`. The UI
button (`lib/ui/public_demo/public_demo_01_placeholder_screen.dart:1136`,
`_commitAggregate(_game.recordOrder(e.id))`) is the only production caller. There is no
separate "client-side order" vs. "company accepts" state — winning the client
interview and clicking 受注 *is* the whole transaction. The applicant/pre-entry
equivalent is `PublicDemoApplicantStage.juneOrdered`.

Critically, `recordOrder` **only flips `stage`**. It does **not** create a
`PublicDemoAssignment`. Assignment materialization is a separate, later step (§2-3),
and that gap between "stage says ordered" and "an assignment object actually exists"
is the root cause below.

## 2. State-transition trace (April order → May, authoritative facts at each step)

| Step | Month | Engineer stage | `PublicDemoMatchingProposal`/interview record | `workflow.assignments` entry? | `assignedEngineerIds(month)` | UI-visible wording |
|---|---|---|---|---|---|---|
| SkillSheet confirmed | 4 | `skillSheet`→`waiting` | — | no | not contained | "スキルシートを確認" |
| 営業開始 | 4 | `selling` | — | no | not contained | "営業を開始" |
| 案件紹介 (`introduceProject`) | 4 | `introduced` | `PublicDemoMatchingProposal(engineerId, projectId, decidedMonth)` written via `withMatchingProposal` | no | not contained | "案件を紹介" |
| 上位会社面談通過 | 4 | `partnerInterviewPassed` | + partner interview evaluation | no | not contained | "上位会社面談へ" |
| 客先面談通過 (`recordEngineerInterviewResult`) | 4 | `clientInterviewPassed` | + `PublicDemoEngineerInterviewRecord` (unforgeable, mints `hasGenuineInterviewRecord`) | no | not contained | "客先面談通過" |
| **受注 (`recordOrder`)** | 4 | **`ordered`** | unchanged | **still no** | **still not contained** | "案件を受注しました" |
| 4月close (`closeApril`→`advanceToMay`) | 4→5 | `ordered` (unchanged) | unchanged | **still no assignment created** | **still not contained for month 5** | HUD: `engineersAssigned` (int) = 1 — correct, see §4 |
| **All of May** | 5 | `ordered` (unchanged — `ordered` has no further stage transition) | unchanged | **empty** | **empty** | Office Stage / Employee tab: `翌月参画予定` ("scheduled to join next month") — **stale**: May *is* "next month" relative to the April order, yet the label still says "scheduled," never "参画中" |
| 5月close (`closeMay`→`assignOrderedForMay()`) | 5→6 | `ordered` (unchanged) | unchanged | **now created** (`PublicDemoAssignment.forOrderedEngineer(projectId: genuine Phase-6 id)`) | **now contains the engineer, for month 6** | Office Stage / Employee tab: `参画中` — first month this ever appears |

This is reproduced verbatim by the existing pinned test group
`'POST-HOME-FREEZE Small-UX-Fix: truthful ordered-vs-assigned status'`
(`test/ui/public_demo/public_demo_01_home_office_stage_test.dart:407-487`):

- L415-434: after April's order + April's close, `workflow.assignedEngineerIds(month:
  currentState.month).contains(sato.id)` is asserted `isFalse` with the reason
  `"assignOrderedForMay has not run yet in April"`, and the Office Stage status is
  asserted to still read `翌月参画予定`.
- L437-486: after May's close too (`'5月を終了して6月へ'`), the test asserts
  `assignedEngineerIds(month: 5).contains(satoId)` is `isFalse` — reason: `"assignOrderedForMay
  has not run yet in May itself"` — i.e. **the whole of May, an engineer ordered in
  April is truthfully un-assigned everywhere `workflow.assignments` is read.** Only
  once June's month starts (i.e. May's own close ran `assignOrderedForMay()`) does the
  status finally become `参画中` (L468-486).

## 3. Where assignment is actually materialized, and why the May gap exists

- `PublicDemoAssignment` model: `lib/game/public_demo/public_demo_assignment.dart:14-214`.
- The **only** production writer that turns `stage == ordered` into a real
  `PublicDemoAssignment` for the primary pipeline is
  `PublicDemoWorkflowState.assignOrderedForMay()`
  (`lib/game/public_demo/public_demo_workflow_state.dart:963-1004`) — a full,
  from-scratch **rebuild** of `workflow.assignments` from every engineer currently at
  `stage == ordered` (+ `hasGenuineInterviewRecord`) and every applicant at
  `juneOrdered` (+ `hasJoined`).
- Its **only call site** is inside `PublicDemoAggregate.closeMay()`
  (`lib/game/public_demo/public_demo_aggregate.dart:1219-1285`, call at line 1257),
  which is guarded `if (state.month != 5 ...) return this;` — i.e. it only runs while
  **closing May** (the May→June transition).
- `PublicDemoAggregate.closeApril()` (`public_demo_aggregate.dart:1199-1210`, the
  April→May transition) does **not** call `assignOrderedForMay()` or any equivalent.
  It only calls `_closeGrowth(const {})` (empty set — correctly, nobody has an
  assignment during April itself) and `PublicDemoMonthlyClose.closeApril(...,
  orderedEngineers: workflow.orderedEngineerCount)`, which feeds
  `PublicDemoState.advanceToMay` (`public_demo_state.dart:464-486`) — that method sets
  `engineersAssigned = orderedEngineers.clamp(0, engineerCount)`, an **`int` headcount
  only**, never touching `workflow.assignments`.

So the design's own naming (`assignOrderedForMay` — "assign, for May") does not match
its actual wiring: the method that is supposed to produce May's assignment roster is
wired to run one month-close **too late**, at the close of May instead of the close of
April. This is a genuine, single-root-cause, reproducible one-month materialization lag
— not a mis-worded label sitting on top of otherwise-correct state, because the actual
domain object (`PublicDemoAssignment`) the rest of the codebase's own documented SSOT
depends on (see §4) really does not exist for a full month.

## 4. What this gap does and does not break (why it wasn't a financial/save bug)

`lib/game/public_demo/public_demo_workflow_state.dart:1220-1248` documents
`assignedEngineerIds(month)` (built from `workflow.assignments`) as **"the single SSOT
Revenue, Growth, and training eligibility must all agree on."** Tracing each of those
three claimed consumers against what actually happens in May:

- **Revenue: not affected.** `PublicDemoState.advanceToMay`'s `engineersAssigned` int
  (set directly from `orderedEngineerCount`, never from `workflow.assignments`) is what
  `PublicDemoRevenue`/`PublicDemoMonthlyClose.closeMay` actually book against. Confirmed
  by the existing test comment at `test/game/public_demo/public_demo_monthly_close_test.dart:157-162`:
  "REVENUE-4: mayState() carries engineersAssigned=1 from April's order into May, so
  this close's pre-transition snapshot books May's revenue (1 × 600,000)." **May's
  revenue for this engineer is correctly booked** even though no assignment object
  exists yet.
- **Growth: not affected, but for a fragile reason.** `PublicDemoAggregate.closeMay`'s
  own `_closeGrowth` call (`public_demo_aggregate.dart:1263-1269`) does **not** read
  `assignedEngineerIds`/`workflow.assignments` — it independently re-scans
  `nextWorkflow.engineers.where((e) => e.stage == PublicDemoSalesStage.ordered)`. So May's
  growth is correctly credited to the April-ordered engineer, but only because this one
  call site silently bypasses the very SSOT its neighboring code calls authoritative.
  **This is the first place a future refactor "simplifying" `closeMay` to use
  `assignedEngineerIds` like everything else would silently break May's growth.**
- **Training eligibility: genuinely wrong for the whole of May.** The training-button
  gate (`_trainingButtonFor`, `public_demo_01_placeholder_screen.dart:2489-2491`) reads
  `_currentlyAssignedEngineerIds` (= `workflow.assignedEngineerIds(month: s.month)`,
  `public_demo_01_placeholder_screen.dart:907-908`) and only hides the training button
  when that set contains the engineer. Since the April-ordered engineer is absent from
  it throughout May, **the internal-training button remains offered for an engineer who
  is simultaneously earning real client revenue that same month** — a real, if minor,
  game-logic inconsistency, not just a label problem.
- **Every other UI surface keyed off the same SSOT is wrong for the whole of May**:
  Office Stage status (`_officeStageStatusFor`, line 461-467), Employee-tab status
  (`_currentEmployeeStatusLabel`, line 2196-2202) and its 全員/待機中/参画中 filter
  bucketing (`_matchesEmployeeStatusFilter`, line 3808-3815) and status-tone coloring
  (`_employeeStatusTone`, line 3972-3978), and the Sales-tab "現在の営業・採用状況"
  overview tile's `案件 ${workflow.assignments.length}件` count
  (`_salesOverviewSection`, line 4320-4385) all under-report this engineer as not yet
  on a project for the entire month of May. HOME's cash-forecast advice filter is
  documented (line 449-451 comment in the pinned test) to read the same
  `assignedEngineerIds` SSOT too, so its advice text is also blind to this engineer's
  real May revenue.

Net effect: **the specific symptom the Human Replay reported — "an engineer I ordered
last month doesn't show as participating this month" — is not a misreading by the
player.** For an April order, it is production-accurate: on every screen that shows
"who is currently on a project" (Office Stage, Employee tab, Sales overview count),
that engineer genuinely, verifiably does not appear anywhere as assigned until June,
one month after the player would reasonably expect it and one month after the game is
already quietly billing the client for their work.

## 5. Other required-trace cases (checked by code reading; not independently executed — no SDK)

- **May/pre-entry order → June join+assignment**: `assignOrderedForMay()`'s applicant
  branch (`workflow_state.dart:991-1001`) requires `stage == juneOrdered &&
  hasJoined`; `hasJoined` only becomes true via the real May-close join transaction
  (`joinAndKeepOnly`), so this branch fires in the *same* close call that just joined
  them — **no extra one-month lag here**, unlike the engineer branch. This path is
  correct.
- **Ordinary-month order → following-month assignment (June–Feb)**: there is **no**
  bulk sweep in `closeJune`/`closeJuly`/ordinary-month close paths analogous to
  `assignOrderedForMay()`. A new order reached via the primary Sales pipeline in June
  has no path to an assignment in June itself; `PublicDemoRecoveryEligibility` only
  opens at internal month 7 (July) (`public_demo_recovery.dart:27-37`), and once open,
  it is **same-month**, not "following-month" (no wait beyond "it's currently July or
  later and you're genuinely ordered and not yet assigned"). This means a June order
  effectively waits until July (matching "following month" for June specifically, but
  for the same structural reason as the April/May gap — no June-close sweep — rather
  than deliberate design), while a July-or-later order is assigned the same month it is
  won. **This inconsistency was not independently reproduced with a test run in this
  session** (no SDK); it is flagged here as an open question for the focused
  implementation to confirm, not asserted as a second proven defect.
- **Save/reload before/after close, retry/double-tap idempotency, no double
  assignment/revenue, genuine projectId retention**: all have dedicated existing
  coverage — `test/game/public_demo/public_demo_assignment_lifecycle_test.dart`
  (idempotent-ending group at L293, June-deferred-row-never-double-counted group at
  L601), `test/game/public_demo/public_demo_assignment_lifecycle_save_codec_test.dart`
  (`'genuine real-project-identity round trip'` group, L84-143), and
  `PublicDemoAggregate.closeApril/closeMay`'s own `state.month != N` no-op guards
  (`public_demo_aggregate.dart:1199-1200`, `:1223`). Static reading of these did not
  surface a second defect, but — per the environment limitation above — **none of this
  was executed in this session**; treat this paragraph as "no contradicting evidence
  found," not "independently verified."

## 6. Verdict

**A — REAL P0/P1 PROGRESSION DEFECT**, specifically **P1** (not P0):

- It is a genuine progression-state gap, not a wording/label problem sitting on
  correct state: the `PublicDemoAssignment` object the codebase's own documentation
  calls the SSOT for "currently on a project" does not exist for a full month after a
  genuine April order, contradicting the exact "April order → May assignment"
  expectation this issue's own required-trace list states.
- P1 rather than P0 because the two things that would make it P0 — **cash/revenue
  correctness and playability** — are unaffected: `engineersAssigned`/revenue booking
  uses a separate, correctly-wired `int` counter, and Growth also happens to be
  correct by bypassing the broken SSOT. Nothing crashes, no progress is lost, and the
  gap silently self-heals at the next month's close.
- Training-button mis-gating for an already-billing engineer during May is a P2
  side-effect of the same root cause, not a separate defect.
- 「発注を受注する」terminology (`home_recommended_action.dart:208-209`) is a genuine,
  separate P2 wording confusion (an *offer* to continue, described with the verb for
  *winning new business*), but is orthogonal to this defect and does not itself explain
  the reported symptom.

This is **not** C (route/authority mismatch): every projectId, interview record, and
matching proposal traced through is genuine production authority end to end — Phase 6's
real `genuineInterviewProjectId` is correctly threaded into the eventual assignment once
it is finally created.

## 7. Minimal fix plan (not implemented — audit scope only)

**Do not implement in this session** (scope: READ-ONLY audit, per Issue #226).

Proposed minimal change for the focused-implementation follow-up:

1. In `PublicDemoAggregate.closeApril()` (`public_demo_aggregate.dart:1199-1210`), call
   `.assignOrderedForMay()` on `grown.workflow` before returning, exactly mirroring
   what `closeMay()` already does with its own post-growth workflow. Since
   `assignOrderedForMay()` is a pure, idempotent full-rebuild from `engineer.stage`/
   `applicant.stage` facts (not an append), calling it again — unchanged — inside
   `closeMay()` the following month remains safe and produces no duplicate entries.
2. **Before merging**, confirm two second-order effects this deliberately surfaces
   one month earlier than today:
   - `assignmentConfirmNextOrder`/`assignmentAcceptNextOrder` CTAs
     (`home_recommended_action.dart:206-209, 302-305`) become reachable in May instead
     of first appearing in June, because a genuine `PublicDemoAssignment` with
     `nextOrderStatus: undecided` now exists a month earlier. Confirm this is the
     intended cadence (decide in month N whether month N+1 continues) rather than a
     newly-introduced early decision point.
   - The training-button gate (`_trainingButtonFor`) will correctly start hiding this
     engineer a month earlier — a behavior change, not a regression, but worth a
     dedicated assertion.
3. Update the one test that currently pins the buggy timing as intentional:
   `test/ui/public_demo/public_demo_01_home_office_stage_test.dart:407-487`
   (`'POST-HOME-FREEZE Small-UX-Fix: truthful ordered-vs-assigned status'` group) —
   its April/May assertions (`isFalse`/`翌月参画予定`) would need to flip to reflect the
   corrected timing; its June assertion (`参画中`) stays true, just reached a month
   earlier.
4. Separately (P2, can be split into its own follow-up): rename
   `assignmentAcceptNextOrder`'s CTA label away from 「発注を受注する」 to remove the
   同語反復 the Human Replay flagged (e.g., 「継続を確定する」/「発注に回答する」), without
   touching `PublicDemoNextOrderStatus`/`PublicDemoReplacementStage` state.
5. Out of scope for this fix, flagged for a dedicated look: the June-order /
   July-Recovery-eligibility gap in §5 — confirm with an actual test run (this session
   had no SDK) whether a June-only order is really stranded until July, and if so
   whether that is intended or the same class of bug.

Estimated implementation size: small (1-2 files touched for the core fix, 1 test file
updated), roughly 1-2 hours including the second-order-effect verification and the
existing test-suite run this session could not perform.

## 8. Progress reporting (per Issue #226 required cadence)

1. **latest-main/root-cause trace complete** — Current status: root cause identified
   (assignOrderedForMay wired to closeMay instead of closeApril) and independently
   corroborated by an existing pinned test. Next action: reproduction via
   production-authority trace. Actual elapsed: ~30 min. Revised ETA: +20 min.
2. **reproduction complete** — Current status: reproduced via static trace + the
   existing `public_demo_01_home_office_stage_test.dart` pinned assertions (no SDK to
   run tests live in this session). Next action: boundary/idempotency check by code
   reading. Actual elapsed: ~50 min. Revised ETA: +15 min.
3. **save/reload + boundary verification complete** — Current status: covered by
   citing existing dedicated test files (save-codec round trip, idempotent-ending,
   double-count guard); not independently executed. Next action: write final report.
   Actual elapsed: ~60 min. Revised ETA: +15 min.
4. **final verdict/report complete** — Verdict A (P1). Report written, committing and
   pushing now. Actual elapsed: ~75 min total (vs. 20-40 min estimate; exceeded because
   this environment has no Flutter/Dart SDK, forcing full static cross-file tracing in
   place of running the existing test suite).

## Human Replay questions, answered directly

1. 「受注」= a single company-side action (`recordOrder`), gated on a genuine client-interview
   pass; no separate client-issues-order vs. company-accepts split exists.
2. See (1) — they are the same action/state; there is no dual state.
3. 参画 (assignment materialization) should start the month after the order per this
   issue's own required trace, but in production for the *first* (April) order it
   actually starts **two** months after (May order stage, June assignment object) — see
   §3-4. For May/June+ orders the lag is the intended one month (or same-month for
   July+ Recovery).
4. April→May close: nothing materializes it. May→June close
   (`assignOrderedForMay()` inside `closeMay`): this is the only bulk close-time
   materialization point in the whole fiscal year. June–Feb: no bulk sweep; only the
   player-triggered Recovery CTA (from July) upserts one engineer at a time.
5. Not exactly-once in the sense of "created once, at the right time" — it is
   correctly non-duplicating (idempotent rebuild / upsert-with-guard), but for an April
   order it is created one month later than the design intends.
6. No route/authority mismatch was found: every case traced kept a genuine `projectId`
   end to end (Phase 6 → `genuineInterviewProjectId` → `PublicDemoAssignment.projectId`).
7. Previous month's proposal/interview/order result is **not surfaced anywhere** once
   the month turns, beyond the (stale, for April orders) `翌月参画予定` badge on the
   Employee/Office Stage screens — there is no "先月の商談結果" summary card. This is a
   real, separate P1/P2 comprehension gap the Human Replay also raised, distinct from
   the assignment-timing defect above; not fixed or scoped further in this audit.
8. `案件紹介` → `案件へ提案` are two different actions in code (`introduceProject` writes
   `stage: introduced`; the "提案" language belongs to `PublicDemoMatchingProposal`
   created at the same step) but read as near-synonyms to the player. `発注/受注` are
   collapsed into one action as noted in (1)-(2) — the 「発注を受注する」 CTA label
   (§6, P2) is the sharpest instance of this ambiguity. `参画` is the one term whose
   underlying object (`PublicDemoAssignment`) is genuinely delayed, per this report's
   main finding.
