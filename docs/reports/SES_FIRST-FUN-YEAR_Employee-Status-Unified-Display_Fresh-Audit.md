# SES First Fun Year — Employee Status Unified Display — Fresh Audit

**Status: READ-ONLY audit. No production code, tests, or workflow files were modified. Nothing in this session was committed or pushed.**

Audited origin/main SHA: `faee0ce100662aed405f34af68596dcd30e6f3e9`
(confirmed via `git fetch origin main && git rev-parse origin/main` at audit start — matched the SHA given in the task; origin/main had not advanced further at audit time)

This SHA is the post-merge state of #233 (Initial Employee / SkillSheet Gate Clarity), #234 (Monthly Management Report Phase A), #236 (Employee Roster Phase B-1), #237 (Monthly Management Report Phase B).

Audit method: read-only inspection of `origin/main` checked out into a detached worktree (`/tmp/audit-main`), no edits. All file paths below are repo-relative and valid on this SHA.

---

## 0. Final Verdict

**Verdict: GO, with existing prior art — this is a consolidation task, not new authority design.**

The domain authorities this task needs already exist, are already correct, and are already reused consistently by every real gameplay decision (Cash Advisor, HOME Recommended Action, Sales, Monthly Report). The problem is **not missing or wrong authority** — it is that **the presentation layer computes "what to show" in four independent, hand-duplicated places** that happen to agree today only because each one was patched by hand, one Issue at a time (#231, then #233, then #235/#236), with doc comments explicitly noting "this mirrors X, but is a separate method". This audit found one concrete case (§6) where two of those four places already **disagree** for a specific, reachable state.

Recommended implementation size: **A — one PR, one pure presentation-layer consolidation, 2–3h.** No domain authority change, no save-schema change. See §14.

---

## 1. Current Domain Authorities

All of these live under `lib/game/public_demo/` and are read, never re-derived, by every screen. None of this is UI-string based.

### 1.1 `PublicDemoEngineerSales` (`public_demo_sales.dart`)
The **sales-pipeline stage** — the single most important authority for "what is this employee doing right now, before they're staffed".

```dart
enum PublicDemoSalesStage {
  waiting, skillSheet, selling, introduced,
  partnerInterviewFailed, partnerInterviewPassed,
  clientInterviewFailed, clientInterviewPassed,
  ordered,
}
```
- `stage` transitions only through sanctioned domain methods (`evaluateInterview`, `applyProjectInterviewResult`, `releaseFromAssignment`) — never a bare field set in production code outside `copyWith`.
- `hasGenuineInterviewRecord` / `PublicDemoEngineerInterviewRecord` — **unforgeable proof** a client interview was actually passed (constructor is file-private). `stage == ordered` alone is *not* trusted anywhere that matters (`assignOrderedForMay` corroborates it).
- `genuineInterviewProjectId` — the real project id a genuine pass is bound to (`null` for the legacy/generic path).

### 1.2 `PublicDemoEngineerRuntime` (`public_demo_engineer_runtime.dart`)
Ground-truth **capability**, independent of sales/assignment state.

- `actualCapability` — derived getter, `languageSkills[primaryLanguage].actualSkill`.
- `fieldSalesCapabilityRequirement = 60` — the single sanctioned threshold constant.
- `isReadyForFieldSales` — `actualCapability >= fieldSalesCapabilityRequirement`, **derived, never persisted**.
- `totalItExperienceMonths`, `confirmedLanguages` — feed the roster's 経験年数/skill-bar display (#235/#236); deliberately do **not** feed sales stage.

### 1.3 `PublicDemoAssignment` (`public_demo_assignment.dart`)
The **staffing record** — created only by `assignOrderedForMay`.

- `engineerId`, `projectName`, `projectId` (nullable — `null` for any legacy/generic assignment with no real Phase 6 project behind it), `nextOrderStatus` (`undecided|offered|accepted|notOffered`), `replacementStage` (`none|selling|introduced|partnerPassed|partnerFailed|clientPassed|clientFailed|ordered`), `monthsCredited`.

### 1.4 `PublicDemoWorkflowState.assignedEngineerIds({required int month})` (`public_demo_workflow_state.dart:1271`)
**The single SSOT for "is this employee currently staffed/revenue-generating"**, explicitly documented as the one fact Revenue, Growth, and training eligibility must all agree on (12MONTH-3-FIX1 P1-1). Its meaning changes by month, on purpose:
- Through June: every row in `assignments` counts (`assignedEngineerIdsUnfiltered`) — June's own renewal decision is about *next* month, not this month's already-earned revenue.
- From July on: only rows where `nextOrderStatus == accepted` or `replacementStage == ordered` count — the roster the player's June decision actually confirmed, carried forward for the rest of the fiscal year (P1-1 design decision: once a real assignment starts, the employee stays on the same project through fiscal-year end).

### 1.5 `PublicDemoWorkflowState.endAssignment` / `assignOrderedForMay` / `creditAssignmentMonths`
The full staffing lifecycle mutators. `endAssignment` is carefully idempotent and month-aware (it will not shrink this month's already-earned revenue count even while resetting the engineer's sales stage back to `waiting`).

### 1.6 `PublicDemoApplicant` / `PublicDemoApplicantStage` (`public_demo_recruitment.dart`)
The **pre-join mirror** of §1.1 for a not-yet-joined recruit:
```dart
enum PublicDemoApplicantStage {
  applied, resumeReviewed, interviewed, rejected,
  offerAccepted, offerDeclined,
  preEntrySkillSheet, preEntrySelling, preEntryIntroduced,
  preEntryPartnerPassed, preEntryPartnerFailed,
  preEntryClientPassed, preEntryClientFailed,
  juneOrdered,
}
```
- `hasJoined` — backed by unforgeable `PublicDemoJoinRecord`, minted only by `PublicDemoJoinTransaction.join`. Critically, `stage == juneOrdered` is a **permanent** "won this June order" identity and is never cleared by joining — so `hasJoined`, not `stage`, is the fact that tells you whether a `juneOrdered` applicant is still "joining next month" or has already joined (Monthly Report Phase B relies on exactly this — §10).

### 1.7 `PublicDemoJoinStatus`, `PublicDemoInterviewCompletionStatus`, `PublicDemoRecruitmentTransactionStatus`
Transaction-result enums (not employee state) — outcomes of one-shot commands, not a display authority.

### 1.8 `PublicDemoState.trainingSelections: Map<String, PublicDemoGrowthSource>`
This month's **training selection** — independent of sales stage or assignment. `selectInternalTraining`/`selectExternalTraining` have **no stage or readiness gate** at the domain level (`public_demo_state.dart:363-382`) — any engineer id can be selected, whether or not they are field-sales-ready. The UI's own `internalTrainingCard` (`public_demo_01_placeholder_screen.dart:2646`) only excludes a *currently assigned* engineer — this is load-bearing for §6.

### 1.9 `PublicDemoState.engineersWaiting` / `engineersAssigned` / `adminCount` / `engineerCount`
The HOME KPI's own aggregate counts — `engineersWaiting`/`engineersAssigned` partition `workflow.engineers` by `assignedEngineerIds(month:)` membership (same authority as §1.4). `adminCount` is the one 総務/general-affairs employee every save starts with — **outside** the engineer roster entirely; the unified status taxonomy in this report does not apply to them (see §12).

None of the above is a UI string. Every "研修が必要"/"営業可能"/"参画中"/etc. label seen anywhere in the app is derived from these facts at render time (§4).

---

## 2. Employee Lifecycle Map

Traced from `PublicDemoWorkflowState`/`PublicDemoAggregate`/`public_demo_01_placeholder_screen.dart` production call paths only — no assumed ordering. **`ordered` does not mean "assigned"** — this single distinction is the root of most of the cross-screen naming this audit exists to fix.

| # | Domain state | UI label(s) actually shown | Player action available | Revenue | Salary | Next action |
|---|---|---|---|---|---|---|
| 1 | New engineer, `stage=waiting`, `isReadyForFieldSales=false` | `_currentEmployeeStatusLabel`: **研修が必要**; `engineerStatus`/HOME/SkillSheet: **待機** | 研修 (internal/external training card, from month≥5) | No | Yes (月給) | Train until capability ≥60 |
| 2 | `stage=waiting`, `isReadyForFieldSales=true` | Roster: **営業可能** (only if `_fieldSalesActionReachableThisMonth` — see §6); HOME/SkillSheet: **待機** | スキルシート確認 → 営業開始 | No | Yes | Start sales flow |
| 3 | `stage=skillSheet` | **営業準備** (everywhere) | 営業開始 | No | Yes | Begin selling |
| 4 | `stage=selling` | **営業中** | (wait for next stage — no player command shown at this stage itself) | No | Yes | — |
| 5 | `stage=introduced` | **案件紹介済** | Partner interview | No | Yes | Take partner interview |
| 6 | `stage=partnerInterviewPassed` | **上位面談通過** | Client interview | No | Yes | Take client interview |
| 7 | `stage=partnerInterviewFailed` / `clientInterviewFailed` | **上位面談不合格** / **客先面談不合格** | Re-enter sales (`RECOVERY-LOOP-1`, July–Feb) | No | Yes | Retry sales flow |
| 8 | `stage=clientInterviewPassed` | **客先面談通過** | Order recorded by domain (`recordOrder`) | No | Yes | — |
| 9 | `stage=ordered`, **not yet in `assignedEngineerIds(month)`** | Roster/HOME: **翌月参画予定** (`engineerStatus`); SkillSheet: same | none — waiting for month close | No (not yet) | Yes | Wait for month close |
| 10 | `stage=ordered`, **already in `assignedEngineerIds(month)`** | Roster/HOME (patched): **参画中**; **SkillSheet: still shows 翌月参画予定** (stale — see §4) | none (assignment maintained) | **Yes** | Yes | Maintain (renewal decision comes in June/monthly) |
| 11 | Assignment continues, June renewal decided (`nextOrderStatus=accepted` or `replacementStage=ordered`) | **参画中** (all surfaces agree from here) | none by default | Yes | Yes | Maintain |
| 12 | `endAssignment` called (`nextOrderStatus=notOffered`, no replacement secured) | `releaseFromAssignment()` resets `stage → waiting`, clears `interviewRecord` | Re-enter sales pipeline | No | Yes | Restart sales flow (back to state 1/2) |
| 13 | Recruited applicant, `stage=juneOrdered`, `hasJoined=false` | Monthly Report: "翌月入社予定"; applicantStatus: **入社・参画予定** | Wait for June join | No | No (not yet employee) | Wait for join |
| 14 | Recruited applicant joined (`PublicDemoJoinRecord` minted) | Becomes a `PublicDemoEngineerSales` via `withJoinedEngineers`, enters this table at whichever stage the join produced | — | per stage above | Yes | per stage above |

There is **no explicit "契約終了"/"退職" state** in the traced authorities — Public Demo 0.1 has no employee-exit domain path other than `endAssignment` (which returns the engineer to `waiting`, not out of the company). This is a genuine absence, not an oversight to paper over: do not invent a "退職" status.

---

## 3. Cross-Screen Audit

Four independent string-producing functions exist for the *same* underlying fact set (`engineer.stage` + `assignedEngineerIds` membership), each documented as deliberately **not** touching the others:

| Screen / call site | Function | File:line | Behavior |
|---|---|---|---|
| HOME Office Stage | `_officeStageStatusFor` | `public_demo_01_placeholder_screen.dart:558` | `engineerStatus(e)`, except `ordered`+currently-assigned → **参画中** override |
| 社員タブ roster (Section 1) | `_currentEmployeeStatusLabel` | `public_demo_01_placeholder_screen.dart:2327` | Same `ordered`+assigned override, **plus** `waiting` → 研修が必要/営業可能 split (gated by `_fieldSalesActionReachableThisMonth`) |
| SkillSheet modal (社員タブ icon **and** the one-time gate flow) | raw `engineerStatus(e)` passed verbatim | `public_demo_01_placeholder_screen.dart:1044`, `:1068` | **No override at all** — an `ordered`+assigned engineer's SkillSheet still reads **翌月参画予定**, contradicting the roster/HOME "参画中" the player just saw for the same person |
| Raw pipeline label (shared helper) | `engineerStatus` | `public_demo_01_placeholder_screen.dart:2280` | The 9-way switch on `PublicDemoSalesStage` verbatim — this is what all three above ultimately fall back to |
| 社員タブ badge *color* | `_employeeStatusTone` | `public_demo_01_placeholder_screen.dart:4240` | A **fifth**, semantically distinct axis: assigned > this-month-training-selected > waiting-detail > default waiting |
| Cash Advisor | `PublicDemoCashAdviceSelector` | `public_demo_cash_advice_selector.dart` | Reads `stage==waiting` + `isReadyForFieldSales` directly (no shared label function — consistent with the fact, but a fourth independent read site) |
| HOME Recommended Action | the `switch (e.stage)` emit block | `public_demo_01_placeholder_screen.dart:3006-3022` | Reads `stage` + `readyForFieldSales` directly too |
| Monthly Management Report | `PublicDemoMonthlyReportSnapshot` | `public_demo_monthly_report_snapshot.dart` | Reads `assignedEngineerIds`/`hasJoined` directly (no employee-status *label*, only counts — see §10) |

**Findings:**

1. **Confirmed inconsistency (not hypothetical):** an `ordered` engineer who is already inside `assignedEngineerIds(month)` shows **参画中** on HOME and the 社員タブ roster, but **翌月参画予定** in their own SkillSheet (`statusLabel: engineerStatus(engineer)` is passed unconditionally at both SkillSheet call sites). This is the exact class of confusion this Issue exists to remove: a player who taps into the SkillSheet of someone the roster just told them is currently participating sees a contradicting, month-stale claim.
2. **Confirmed label/tone mismatch (traced, not simulated):** `_employeeStatusTone` treats "this month's training is selected" (`s.trainingSelections.containsKey(e.id)`) as **higher priority than the waiting/ready split**, but `_currentEmployeeStatusLabel`'s *text* never looks at `trainingSelections` at all. Since `internalTrainingCard` (`:2646`) allows training selection for **any non-currently-assigned engineer regardless of stage or readiness** (there is no `stage==waiting`/`isReadyForFieldSales` gate on it), a player can select training for e.g. an already-ready-for-sales or even a `selling`/`introduced`-stage engineer. In that reachable state the roster row shows the text **営業可能** (or **営業中**, **案件紹介済**, …) painted in the **研修 (training)** tone color — text and color visibly disagree for the same card.
3. **No fifth, silently-diverging authority found beyond this** — every other read site (Cash Advisor, Recommended Action, Sales tab's own `PublicDemoSalesStatusTone`, Monthly Report) reads `stage`/`assignedEngineerIds`/`readyForFieldSales` directly rather than through a label function, so they cannot disagree on the underlying *fact*, only (as above) on how it's *worded*.
4. **Not a bug, but worth naming:** `PublicDemoSalesStatusTone` (positive/caution/negative/inProgress — for applicant/order *outcomes* in the Sales tab) is a **separate taxonomy** from `PublicDemoEmployeeStatusTone` (assigned/training/readyForSales/waiting — for employee *identity* status). They must not be merged; they answer different questions (§5 keeps this separation explicit).

---

## 4. Recommended Player-Facing Status Taxonomy

Minimal, matching what already exists in code (`_currentEmployeeStatusLabel`'s vocabulary is already close to correct — this is consolidation, not invention):

| Player-facing status | Domain condition (all read-only) | Notes |
|---|---|---|
| **研修が必要** | `stage == waiting && !runtime.isReadyForFieldSales` | Existing label (#231/#233), keep verbatim |
| **営業可能** | `stage == waiting && runtime.isReadyForFieldSales` | Existing label; keep the existing `_fieldSalesActionReachableThisMonth` month-gate so this is never shown with no reachable control (#233 P2 fix — must be preserved) |
| **営業中** | `stage ∈ {skillSheet, selling, introduced, partnerInterviewPassed/Failed, clientInterviewPassed/Failed}` | Collapses the raw pipeline's 6 sub-stages into one player-facing bucket — see mapping rationale below |
| **参画予定** | `stage == ordered && !assignedEngineerIds(month).contains(id)` | The one genuinely "waiting for next month" case |
| **参画中** | `stage == ordered && assignedEngineerIds(month).contains(id)`, **or** any later month where `assignedEngineerIds` still contains them | Must be the SAME check everywhere — see §7 architecture |
| **待機** | Fallback: `stage == waiting` handled above; this bucket effectively never fires standalone once 研修が必要/営業可能 exist, but keep it as the literal fallback for a future stage this switch doesn't yet know about (defensive, §11) |

**Mapping rationale for 営業中 (collapsing 6 raw stages into 1):** the raw pipeline (`skillSheet→selling→introduced→partnerInterviewPassed/Failed→clientInterviewPassed/Failed`) is real and must stay visible **somewhere** (the existing `PublicDemoSalesProgress(currentStep: engineerStep(e))` stepper already does this, and the SkillSheet/roster detail already shows the raw label too) — but for the *card-level, at-a-glance* status this Issue is about, six near-identical "still in the sales funnel, not yet earning" sub-states collapse to one truthful bucket: **not generating revenue yet, still in motion**. This mirrors what `_employeeStatusTone`'s own `waiting` bucket already does implicitly ("anything else on the waiting/selling/interviewing path" — its own doc comment, `public_demo_employee_visual.dart:44`). A failed interview (`partnerInterviewFailed`/`clientInterviewFailed`) is not given its own player-facing bucket because RECOVERY-LOOP-1 already re-enters the same 営業中 flow next month; do not invent a distinct "面談不合格" top-level status — it would be a dead-end label with no different next action from 営業中 itself.

**Do not introduce:** a distinct "面談中" top-level bucket was in the task's own example vocabulary, but tracing the actual pipeline shows interviews are single-turn transactions (`evaluateInterview`), not a state an employee visibly sits "in" between renders — collapsing it into 営業中 is honest; inventing a standalone "面談中" would imply a waiting room state that does not exist in the domain.

**Domain state vs. player-facing status — explicit separation:**
- Domain state = `PublicDemoSalesStage` (9 values) + `assignedEngineerIds` membership + `trainingSelections` membership. This is what persists, what tests assert against, what `PublicDemoAggregate` transitions.
- Player-facing status = the 6-value table above. It is a pure function of domain state, computed at render time, never persisted, never a `copyWith` parameter anywhere.

---

## 5. Status Priority

Ordered, most-important-first, derived from tracing what already governs `_employeeStatusTone` plus the one gap found in §3.2:

1. **参画中** (`assignedEngineerIds` membership) — always wins. An `isReadyForFieldSales==true` engineer who is currently assigned must never show 営業可能 — confirmed already correctly handled (`_currentEmployeeStatusLabel`'s `ordered && assigned` branch is checked first, before the `waiting` branch is even reachable).
2. **参画予定** (`ordered`, not yet assigned) — second priority; this is the one case worth keeping visible rather than folding into 営業中, because the next action ("wait for month close") is genuinely different from every other 営業中 sub-state ("act now").
3. **研修が必要 / 営業可能** (`waiting`, split by `isReadyForFieldSales`) — third priority, only reachable once 1–2 are excluded.
4. **営業中** (every other non-`waiting`, non-`ordered` stage) — fourth.
5. **待機** — literal fallback.

**On training selection (the §3.2 finding):** this audit recommends training-selected-this-month be demoted to a **secondary indicator** (e.g. a small "研修選択中" sub-line or icon), never the primary status color/text, for any employee whose primary status is not itself training-related (営業可能/研修が必要 while unready already reads as training-relevant; 営業中/参画中 does not). Concretely: keep `_currentEmployeeStatusLabel`'s current behavior (never checks `trainingSelections`) as the SSOT for the *label*, and stop `_employeeStatusTone` from overriding tone with `training` when the label is not itself 研修が必要 — this removes the confirmed mismatch without touching any gameplay eligibility.

**面談中 vs. 営業中 hiding it:** since interviews are single-command transactions with no idle "in interview" render state, there is nothing to hide — the raw stage (`introduced`/`partnerInterviewPassed` etc.) is still fully visible in the roster's detail row (`engineerStep`/`PublicDemoSalesProgress`) and in the SkillSheet; only the *card-level bucket* collapses it.

**受注済み・翌月参画予定 priority:** per the lifecycle table (§2, row 9), this must show **参画予定**, not a generic 営業中/待機 — it is the one state where the player has already won the deal and the only remaining next action is "wait", which is materially different guidance from every 営業中 sub-state ("keep working the pipeline").

---

## 6. Revenue / Cost Meaning

Traced against `PublicDemoRevenue`/`PublicDemoSalary`/`PublicDemoInternalTrainingTransaction` call sites reached from the roster/HOME:

| Status | 単金 (unit rate) shown | Revenue this month? | Salary this month? |
|---|---|---|---|
| 研修が必要 / 営業可能 / 営業中 / 参画予定 | **`—`** (dash) — `_currentUnitPriceDisplayFor` returns `null` for anyone not in `_currentlyAssignedEngineerIds` (`:4225`) | **No** | Yes (月給 always shown via `PublicDemoSalary.currentMonthlySalaryFor`) |
| 参画中 | Real per-project rate **only if** `PublicDemoAssignment.projectId != null` and `PublicDemoSeededProjectGenerator.regenerate` resolves it; otherwise `—` (a legacy/generic assignment never fabricates a rate — PR #236 Codex fix, explicitly never falls back to `PublicDemoRevenue.ratePerAssignedEngineer`'s flat constant) | **Yes, this month's assignment is counted in `assignedEngineerIds`, which is what `PublicDemoRevenue` sums** | Yes |

**Important correction to the task's own illustrative example:** "参画中 = 必ず当月入金" must **not** be stated as fact in the unified display copy. Revenue *recognition* (this employee counted in this month's `assignedEngineerIds`, feeding `PublicDemoRevenue`) and *cash receipt* (a 30-day-sight client payment, tracked separately by `PublicDemoMonthlyCashFlow`/accounts-receivable authority) are **different facts** already kept separate in the codebase (Monthly Report's own cash-flow section shows 現金 vs 売上 vs 売掛金 as distinct lines — `docs/decisions/…2026-09-02.md`'s Update history for #232 Phase B explicitly lists "売上・入金・売掛金" as three separate figures). The unified status display must say "参画中 = 売上計上対象" (counted toward revenue), never "入金済み" or "必ず当月入金".

**研修中/研修必要 cost:** `PublicDemoInternalTrainingTransaction.cost` is a real, separate one-time cost from 月給 — do not conflate "研修が必要" (a *status*, no transaction yet) with "研修を選択した" (a transaction, `trainingSelections` membership, real cash cost). The unified taxonomy's 研修が必要 bucket is a recommendation state, not proof a cost has been incurred.

---

## 7. Next-Action Mapping

Every action below is an action that already exists and is reachable in the traced production UI — nothing invented:

| Status | Next action (existing control) | Month availability (traced) |
|---|---|---|
| 研修が必要 | 研修 (`internalTrainingCard`, `_selectInternalTraining`) | Month ≥ 5 only (`_employeeGrowthSection`'s `s.month >= 5` gate, `:4420`) — **absent in April**, a real, existing gap this display must not paper over |
| 営業可能 | スキルシート確認 → 営業開始 (`_openSkillSheetReview`/`_beginSelling`) | April (always), June (only a joined-applicant-turned-engineer — `s.joinedApplicantIds`), July–Feb (RECOVERY-LOOP-1); **not reachable in May or March** — `_fieldSalesActionReachableThisMonth` (`:2361`) already encodes exactly this, and the label itself already falls back to the raw `engineerStatus` text in May/March rather than promising a dead-end action (#233 P2 fix — must be preserved verbatim) |
| 営業中 | Depends on exact sub-stage (partner/client interview button, or none at the plain `selling` stage) — the existing per-stage buttons in `_employeeNextActionsSection`, unchanged | Varies by sub-stage; do not generalize a single CTA label across all six sub-stages |
| 参画予定 | None — "翌月の月次決算を待つ" (a passive wait), never a fabricated button | N/A |
| 参画中 | None by default; June renewal decision (`decideOrder`/`replacementPartner`/`replacementClient`) is the one month a real action exists | June-specific |

Do not invent a generic "営業を進める" CTA that isn't wired to a real per-sub-stage control — the existing `_employeeNextActionsSection` cards are already the single source of truth for what's actionable this month; the unified status display should **link to/mirror** those cards' presence, never assert an action independently.

---

## 8. #233 Compatibility

#233 (Initial Employee / SkillSheet Gate Clarity) introduced exactly the 営業可能/研修が必要 split plus the reason caption (`実力$threshold以上が必要（現在$capability）`, `:4153`) and the `_fieldSalesActionReachableThisMonth` month-gate. **This audit's recommended taxonomy (§4) reuses #233's labels and gate verbatim** — it does not redefine the 60-point threshold, does not change `fieldSalesCapabilityRequirement`, and keeps the reason caption. The SkillSheet hard gate (`waiting→skillSheet→selling`) that #231 Package B explicitly chose to **keep** (embedded in HOME Recommended Action + Cash Advisor) is unaffected by this Issue's scope; it must stay.

## 9. #236 Compatibility

#236 (Employee Roster Phase B-1) added 経験年数/月給/単金 to the roster card and the project-backed 単金 resolution (`_currentUnitPriceDisplayFor`). This audit's recommendation is to **keep this line exactly as-is** and attach the unified status badge above it in the same card, not replace it. 年齢/性別 remain genuinely absent from any authority (per #236's own Fresh Audit finding, `docs/reports/SES_FIRST-FUN-YEAR_Employee-Roster-Management-Data_Fresh-Audit.md`) — do not add them as part of this Issue.

## 10. #237 Compatibility

Monthly Management Report Phase B (`PublicDemoMonthlyReportSnapshot`/`PublicDemoMonthlyReportDisplayData`) reads **the exact same `workflow.assignedEngineerIds(month:)` fact** the roster/HOME already use (`public_demo_monthly_report_snapshot.dart:93-100`), and its own doc explicitly cites this as "read exactly as HOME's own Office Stage / 社員タブ already do". There is therefore **no risk of the "Monthly Report says 待機1名 but nobody in the roster looks waiting" contradiction** the task warns about — both already share one authority. The only thing this Issue's consolidation needs to preserve is that a future refactor of the roster's status function does not accidentally stop reading `assignedEngineerIds` in favor of some other per-employee flag; §11's architecture keeps this explicit.

---

## 11. Recommended Architecture

**Recommendation: pure presentation-layer consolidation. No domain model change, no new enum on `PublicDemoEngineerSales`/`PublicDemoEngineerRuntime`, no save-schema change.**

```
Domain authorities (unchanged)
  PublicDemoEngineerSales.stage
  PublicDemoWorkflowState.assignedEngineerIds(month:)
  PublicDemoEngineerRuntime.isReadyForFieldSales
  PublicDemoState.trainingSelections
        │
        ▼
NEW: PublicDemoEmployeeStatusPresenter (pure function, no widget/BuildContext)
  EmployeeStatusDisplay resolve({
    required PublicDemoEngineerSales engineer,
    required bool isCurrentlyAssigned,          // assignedEngineerIds membership
    required bool? isReadyForFieldSales,        // runtime.isReadyForFieldSales, nullable if no runtime
    required bool fieldSalesActionReachableThisMonth,
    required bool hasTrainingSelectedThisMonth,
  }) => EmployeeStatusDisplay(label: ..., tone: ...)
        │
        ├── 社員タブ roster card  (replaces _currentEmployeeStatusLabel + _employeeStatusTone)
        ├── HOME Office Stage     (replaces _officeStageStatusFor)
        └── SkillSheet modal      (replaces raw engineerStatus(engineer) passed as statusLabel — fixes §3 finding #1)
```

- A pure `EmployeeStatusDisplay resolve(...)` function/class, taking only primitives/enums already computed by the caller (never reading `PublicDemoAggregate`/`PublicDemoState` itself) — mirrors the existing convention already documented at the top of `public_demo_employee_visual.dart` ("Every widget here is presentation-only... never reads PublicDemoAggregate/PublicDemoState itself").
- This resolves §3 finding #1 (SkillSheet staleness) for free: SkillSheet's two call sites (`:1044`, `:1068`) pass the resolver's output instead of raw `engineerStatus(engineer)`.
- This resolves §3 finding #2 (label/tone mismatch) by construction: label and tone come from the same function call, so they cannot diverge.
- **Deliberately not a new domain enum**: a `PlayerFacingEmployeeStatus` UI enum belongs in `lib/ui/public_demo/` (or a new small file next to `public_demo_employee_visual.dart`), never in `lib/game/public_demo/`. Putting it in the domain would let it drift into being (mis)trusted as a gameplay eligibility check, exactly the anti-pattern `PublicDemoEmployeeStatusTone`'s own doc comment already warns against ("no new status vocabulary is introduced here").
- HOME Freeze compliance: HOME's Office Stage currently calls its own private `_officeStageStatusFor`. Routing it through the shared resolver is a **behavior-preserving refactor** (identical output for every existing test fixture) — this satisfies "HOME's layout/behavior does not change" even though the *implementation* of `_officeStageStatusFor` is now one line calling the shared resolver. If the team's HOME Freeze policy requires literally zero diff inside HOME-owned files, an equally valid Phase-1-safe alternative is to leave `_officeStageStatusFor` untouched and only consolidate the 社員タブ + SkillSheet paths (which are not HOME-owned) — recommend confirming this interpretation before implementation (see P1 blocker in §18).

---

## 12. Edge Cases

Traced against `PublicDemoSaveCodec`, `PublicDemoRecovery`, `public_demo_engineer_runtime.dart` fallback constructors:

| Edge case | Traced behavior | Unified display implication |
|---|---|---|
| Founding employee (`eng-01`/`eng-02`) | Ground-truth constants in `publicDemoInitialEngineerRuntimes`/`publicDemoInitialEngineers` | No special-casing needed — same resolver path |
| Recruited employee | Enters via `withJoinedEngineers` after `PublicDemoJoinRecord` mint | Same resolver path once `PublicDemoEngineerSales` exists |
| SkillSheet未確認 | `stage == waiting`, no `skillSheet` transition yet | 研修が必要/営業可能 bucket, unchanged |
| Selling/interview/ordered-but-unassigned | Covered in §2 table | Covered |
| Legacy/null-project assignment | `PublicDemoAssignment.projectId == null` | 単金 shows `—`, never fabricated (§6) — status label still shows 参画中 correctly (status ≠ rate) |
| Month transition | `assignedEngineerIds(month:)` is itself month-parameterized; the resolver must always be called with the **current** `s.month`, never a captured/stale month | Architecture note added to §11 |
| Assignment end exists | `endAssignment` — idempotent, resets stage to `waiting`, may leave an inert row in `assignments` before month 7 (documented, deliberate) | Resolver must key off `assignedEngineerIds` membership, **not** "row exists in `assignments`" — this is already how `_currentUnitPriceDisplayFor` and `_currentlyAssignedEngineerIds` work; do not regress to a naive "assignment row present" check |
| Bankruptcy / year-end | `fiscalYearCompleted`/`isFinanciallyTerminal` make the whole state read-only; no employee-status-specific terminal state exists | Resolver keeps producing whatever label the frozen state implies — no special "終了" status needed |
| Save/reload | `PublicDemoSaveCodec._hasConsistentAuthorityFacts` rejects an internally-inconsistent save **at load time**, wholesale (returns `null` → falls back to a fresh/prior valid state) rather than letting a malformed per-employee state reach the UI | The resolver does not need its own crash-fallback for a genuinely malformed `stage`/assignment combination — that class of corruption is already filtered out before any screen renders. It **should** still null-coalesce a missing/`null` `runtime` (`isReadyForFieldSales: null` → treat as "unknown, not yet measured" rather than crashing), matching `s.runtimeForOrNull` callers' existing `?? false` convention (`readyForFieldSales`, `:996`) |
| ID mismatch / missing reference | `PublicDemoEngineerInterviewRecord`/`PublicDemoJoinRecord` check identity (`engineerId == id`) before trusting a record — a copyWith-reused record for the wrong id is already rejected at the domain layer | No UI-level fallback needed; domain already refuses to produce this state |
| Malformed/legacy state | Same save-codec rejection as above | Same |
| 総務/general-affairs employee | Not a `PublicDemoEngineerSales` at all — outside `workflow.engineers` | This taxonomy does not apply to them; do not attempt to give them a sales-pipeline status |

**Fallback rule for the resolver:** if a future `PublicDemoSalesStage` value is added and the switch is not updated, prefer a Dart exhaustive `switch` (compile-time error on a missing case) over a runtime default — this is stronger than a defensive fallback and matches the existing `engineerStatus`/`engineerStep` style (both are already exhaustive switches with no `default:`).

---

## 13. Mobile Design (360×800, 390×844, TextScaler 1.0/1.3)

Current card (`_employeeRosterCard`, `:4082`) already fits this budget at 3 lines: name+badge row, skill bar (conditional), compensation line (conditional reason caption). Recommended information hierarchy for the unified card, unchanged in row count:

1. **Primary status** — the unified badge (name row, unchanged position/size).
2. **Secondary reason** — existing conditional caption (`営業には実力60以上が必要（現在52）`) — keep gated to only the one case it currently covers (waiting + not ready); do not add a caption for every status (would bloat the card).
3. **Skill / experience** — existing skill bar + `経験 X年` (unchanged).
4. **Salary / rate** — existing 月給/単金 line (unchanged).
5. **Next action** — do **not** add a fifth line/button to this card; the existing `_employeeNextActionsSection` (Section 2) remains the single place actions live, per the existing Employee UI Phase 1 four-stage information architecture (`社員一覧・現在状態 → 今やるべき社員アクション → 参画中案件 → 成長・SkillSheet・研修`) already established in the governing plan. Adding a duplicate CTA into the roster card would reopen the exact "重複情報を減らす" regression the team already fixed once (2026-09-06 Employee UI Phase 1 entry, `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`, removing `ec(i)`'s own duplicate badge).

Existing widget tests already assert ≥48dp tap targets and no-overflow at 360×800/390×844×TextScaler 1.0/1.3 for this exact card family (`public_demo_employee_roster_phase_b1_test.dart`) — the consolidation must keep passing those, not re-derive the constraint.

---

## 14. Implementation Scope

**A — 1 PR / 2–3h.**

Rationale: no domain authority change (§1 is already correct and already shared correctly by #233/#236/#237), no save-schema change, and the fix is narrowly a presentation-layer consolidation of four existing functions into one, applied at three call sites (社員タブ roster, HOME Office Stage, SkillSheet modal). This is the same size class as #231/#233/#235/#236 individually were. Do not combine this with any Visual Complete or Sales/Accounting tab work (per the governing plan's own "one implementation phase ≒ one PR" execution policy, `SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`).

If HOME Freeze is interpreted strictly (zero diff inside HOME-owned files, not even a behavior-preserving one-line refactor), split into:
- **Phase 1 (this PR):** 社員タブ + SkillSheet consolidation only (fixes the confirmed inconsistency in §3).
- **Phase 2 (separate, small):** route HOME's `_officeStageStatusFor` through the same resolver, timed with whatever HOME Freeze review already exists — this does not block Phase 1.

---

## 15. Test Plan

**New/changed assertions needed:**
- 研修が必要 / 営業可能 / 営業中 / 参画予定 / 参画中 / 待機 — one resolver unit test per bucket, covering the boundary between `waiting`+ready/not-ready and `ordered`+assigned/not-assigned.
- Status priority: an `ordered`+assigned engineer must never show 営業可能 even if `isReadyForFieldSales==true` (regression-pin the existing correct precedence).
- The confirmed §3.2 label/tone (training-selected) fix: an already-ready-for-sales `waiting` engineer with `trainingSelections` containing them shows 営業可能 in **both** label and tone (no training-tone override) — this is a genuine new regression test, not a duplicate of anything existing.
- SkillSheet now shows 参画中 (not stale 翌月参画予定) for an `ordered`+assigned engineer — new, since no such assertion exists today (confirmed absent: `public_demo_skill_sheet_display_projection_test.dart`/`public_demo_01_skill_sheet_flow_test.dart` were not found to assert this case in the file list reviewed).
- project-backed rate / waiting dash — **already covered**, do not duplicate (`public_demo_employee_roster_phase_b1_test.dart`).
- save/reload — **already covered** at the save-codec level (`public_demo_assignment_lifecycle_save_codec_test.dart`, `public_demo_save_codec_test.dart`) — the resolver itself needs no new save/reload test since it never persists.
- month boundary (June→July filtered `assignedEngineerIds`) — **already covered** (`public_demo_assignment_lifecycle_test.dart`, `public_demo_post_may_join_lifecycle_test.dart`).
- founding/recruited employee — **already covered** implicitly by every roster test using both `eng-01`/`eng-02` and a joined applicant fixture.
- Monthly Report waiting/assigned consistency — **already covered** (`public_demo_monthly_report_display_data_test.dart`, `public_demo_01_monthly_report_test.dart`) — no new test needed, only confirm the consolidation does not change `assignedEngineerIds` call sites.
- 360×800/390×844 × TextScaler 1.0/1.3 — **already covered** for the current card shape (`public_demo_employee_roster_phase_b1_test.dart`); re-run, do not re-author, unless the badge itself changes size.
- #233 regression — `public_demo_issue231_employee_skillsheet_clarity_test.dart` — re-run as the primary regression guard for the reason-caption/threshold behavior.
- #236 regression — `public_demo_employee_roster_phase_b1_test.dart` — re-run for the compensation line.
- #237 regression — `public_demo_01_monthly_report_test.dart`, `public_demo_monthly_report_display_data_test.dart` — re-run; expect no change since Monthly Report never called the label functions being consolidated.

**Explicitly do not re-test:** anything about `PublicDemoSalesStage` transition rules themselves (`public_demo_assignment_test.dart`, `public_demo_join_test.dart`, the `public_demo_recovery_*` suite) — none of that changes.

---

## 16. Known Limitations

- The SkillSheet fix (§3 finding #1) has been *identified*, not implemented — this is a READ-ONLY audit.
- The training-selection tone mismatch (§3 finding #2) was traced through code, not exercised via a running app/widget test in this session (no code changes were made, per the READ-ONLY constraint) — treat it as **code-confirmed, not runtime-screenshot-confirmed**.
- Interview sub-stage granularity (partner/client passed/failed) is deliberately folded into 営業中 for the card-level badge; if a future Human Replay finds this too coarse, the existing `PublicDemoSalesProgress` stepper is the already-existing place to add detail back, not the badge.
- 年齢/性別 remain out of scope (confirmed absent authority, per #236's own Fresh Audit — not re-litigated here).
- HOME Freeze interpretation ambiguity for the resolver refactor (§11/§14) is flagged as a P1 blocker for implementation, not resolved by this audit.

---

## 17. SSOT Update Required

`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — **not updated by this audit (per instructions).** For the implementation phase, the following updates will be needed:
- Add an Update History entry recording this Issue's completion, in the same style as the #231/#235/#236/#237 entries (each explicitly states "本エントリはCurrent execution order・Prioritized backlog tableの構成自体は変更しない" for exactly this class of task) — this Issue belongs in the same P3 "Public Demo UX仕上げ" / employee-status-clarity lineage as #231, not a new top-level priority line.
- `docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md` item 4, "Employee lifecycle status clarity" (P1, 2–3h est.), should be marked addressed by whichever PR implements this audit's recommendation — it is the same task this addendum already named, now formally audited.

---

## 18. Estimated Implementation Size

**A — 1 PR, 2–3h**, per §14. Recommended PR count: **1** (or 2 only if HOME Freeze is read strictly per §14's fallback plan).

---

## Appendix: Files Read (this audit)

`lib/game/public_demo/public_demo_engineer_runtime.dart`, `public_demo_assignment.dart`, `public_demo_sales.dart`, `public_demo_join.dart`, `public_demo_recruitment.dart` (partial), `public_demo_workflow_state.dart` (partial, targeted), `public_demo_state.dart` (partial, targeted), `public_demo_monthly_report_snapshot.dart`, `public_demo_save_codec.dart` (targeted); `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (targeted, ~400 lines across multiple sections), `public_demo_employee_visual.dart`, `public_demo_skill_sheet_display_projection.dart`/`_sheet.dart`/`_sections.dart` (targeted); `lib/presentation/home/models/home_dashboard_display_data.dart` (targeted); `lib/app/app_entry.dart`; `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`, `docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`; test directory listings under `test/ui/public_demo/`, `test/game/public_demo/` (names only, not full contents).
