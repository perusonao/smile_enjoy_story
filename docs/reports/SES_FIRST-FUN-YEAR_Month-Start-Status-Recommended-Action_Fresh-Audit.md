# SES FIRST-FUN-YEAR — Month-start Status / Recommended Action — Fresh Audit (READ-ONLY)

Source prompt: `docs/issues/SES_FIRST-FUN-YEAR_Month-Start-Status-Recommended-Action_Fresh-Audit_Prompt.md`

## 0. Metadata

| item | value |
|---|---|
| Audited `origin/main` SHA (fetched explicitly, `git fetch origin main`) | `8e64a1c8dda86f5848a3257dcffc3938323992ed` |
| Issue #241 / PR #242 merge commit named by the prompt | `245a4d430901fc93245c1d95c8e858e3dcfda5c3` — confirmed an ancestor of the audited SHA (`docs: add month-start status recommended action fresh audit prompt` is the one commit on top of it) |
| Branch | `claude/fresh-audit-result-report-1riple`, reset onto `origin/main` before this audit (the branch previously carried only unrelated pre-#227-era content with no open PR, per the session's own branch-handling instructions) |
| Scope | READ-ONLY. No production file under `lib/` was modified by this task. |
| Fast CI #642 | Reported by the task as running post-merge at task creation; this audit does not depend on its result (read-only, no build/test run against a moving head) — a production implementation session must re-fetch/re-check before starting. |

## 1. Goal recap

First Fun Year's next P1: make the state a player lands in immediately after
a month change legible in a few seconds — this month's company state, what
changed from last month, what to do first, who to train/sell/progress, and
(when cash or a waiting employee is a risk) which action actually recovers
it — reusing existing Finance/Payroll/Assignment/Employee Status/Project
Context/Recruitment/Monthly Management Report/HOME Recommended Action
authority. No new system, no new authority.

## 2. Authority trace (§1–§13 of the prompt)

### §1 — Month-end close → next-month HOME transition order

Traced directly in all five close handlers (`april()`, `may()`, `june()`,
`july()`, `closeOrdinaryMonth()` — `public_demo_01_placeholder_screen.dart`).
The order is identical in every one of the five:

```
_confirmMonthCloseIfRecommendedOutstanding()   (Month Guard: required blocks,
                                                 recommended warns-and-allows)
  → [April/May only] existing PublicDemoEventDialog
  → closeX(...)                                 (domain command)
  → _commitAggregate(result)                     (setState + async save)
  → _maybeShowMonthlyReport(closedMonth)          (read-only dialog)
  → _resetMonthScroll()
  → normal build() renders next month's HOME
```

This matches PR #237's own documented flow diagram verbatim and is
unchanged since. Every handler captures `final closedMonth = s.month;`
**before** `_commitAggregate`, so the Monthly Report is asked about the
month that was just closed, not the (already-advanced) current month.

### §2 — What the Monthly Management Report hands to HOME on dismiss

**Nothing.** `_maybeShowMonthlyReport` is called *after* `_commitAggregate`
has already replaced `_game` — the month is already advanced, revenue/cash
already booked, before the dialog ever appears. The dialog
(`PublicDemoMonthlyReportDialog`) is a `StatelessWidget` reading a
`PublicDemoMonthlyReportDisplayData` snapshot; its only action is
`Navigator.of(context).pop()`. Dismissing it does not call any command —
the screen's `build()` simply re-runs against the state that was already
committed one step earlier, so every HOME getter (`_homeDashboardData`,
`_recommendedActionSlot`, `_officeStageDisplay`, `_importantTasks`) is
freshly recomputed. There is no "seen"/"report shown" flag anywhere in the
save schema (confirmed: no `toJson`/`fromJson` on either the Report's
snapshot or its display data), so a reload mid-Report only ever loses the
just-shown dialog, never a real state transition — this is Phase B's own
documented Known Limitation, verified still true.

### §3 — HOME's current authority for company status / KPI / cash warning / 総務 / Recommended Action

The **only** screen actually wired into the app is
`PublicDemo01PlaceholderScreen` (`lib/main.dart:206`). `_buildHomeTab`
composes, top to bottom:

1. `PublicDemoCashShortageCard(state: s, nextClose: _nextCloseForecastEntry)` — gated on `s.financialStatus == cashShortage`, reads `PublicDemoCashForecast` for whether the *next* close actually recovers.
2. `_bankruptcyTerminalCard()` — gated on `s.isFinanciallyTerminal`.
3. `PublicDemoHomeDashboardSection(data: _homeDashboardData, recommendedAction: _recommendedActionSlot, navigatorAdvice: navigatorAdviceFor(_recommendedActionSlot), cashAdvice: _cashForecastAdvice)`, itself composing `MonthHeaderBar` + `KpiSection.compact` + `HomeNavigatorSection` (one "何をすべきか" line — see §3.1 below).
4. `PublicDemoMonthlyPrimaryCtaSection` — the bound month-close CTA, when one exists this month.
5. `HomeOfficeStageSection(display: _officeStageDisplay)` — the 総務/roster-status card (每 engineer's name + `_officeStageStatusFor`, plus the one 総務 employee).
6. `PublicDemoImportantTasksSection(items: _importantTasks)` — up to 3 truthful category chips (営業/採用/資金), each gated on `homeImportantTaskHasEligibleAction` against the *same* `_recommendedActionCandidates` list.

All six read from getters evaluated fresh on every `build()` — none is a
`State` field, so none can go stale independently of the others (confirmed
by direct reading of each getter's own doc + implementation).

**Dead-code note (not a functional bug, but a genuine trap for a future
audit):** `lib/presentation/home/home_shell_page.dart` and 7 of its 11
sibling widgets (`brand_header.dart`, `company_status_section.dart`,
`dashboard_section_card.dart`, `home_bottom_nav.dart`,
`key_events_section.dart`, `month_end_cta_section.dart`,
`office_stage_section.dart`, `recommended_action_section.dart`) are **not
imported by any production file** — `lib/main.dart` never references
`HomeShellPage`, and grep confirms each of those 7 widgets is referenced
only by `home_shell_page.dart` itself and its own tests. Only 4 files under
`lib/presentation/home/` are genuinely live in production:
`models/home_dashboard_display_data.dart`,
`models/home_office_stage_display.dart`,
`models/home_navigator_display.dart`, `models/home_recommended_action.dart`,
plus 3 widgets consumed by `public_demo_home_dashboard_section.dart`/
`public_demo_01_placeholder_screen.dart`: `widgets/kpi_section.dart`,
`widgets/month_header_bar.dart`, `widgets/home_navigator_section.dart`,
`widgets/home_office_stage_section.dart`. A reader who opens
`home_shell_page.dart` first (as this Fresh Audit initially did) can easily
mistake an abandoned Phase 1A shell for the live HOME architecture. No fix
proposed here (out of scope for a READ-ONLY audit and not requested), but
flagged as a comprehension hazard worth a follow-up cleanup issue.

#### §3.1 — Company status + "next action" presentation: already substantially one resolver

Audit Question B asked whether "company state" and "next move" can be
collapsed into one presentation resolver. They largely already are:
`PublicDemoHomeDashboardSection._effectiveAdvice` is exactly that resolver —

```
cashAdvice ?? _baseAdvice
```

where `cashAdvice` (`_cashForecastAdvice`, a **forecasted, not-yet-realized**
shortage) outranks `_baseAdvice`, which is
`navigatorAdviceFor(recommendedAction)` with the month-goal text substituted
in for the generic neutral line when nothing is eligible
(`HomeRecommendedActionNone`). `navigatorAdviceFor`
(`home_navigator_display.dart`) is a pure, total, `switch`-based translator
from `HomeRecommendedActionSlot` to display copy — it cannot read game
state, cannot rank, and cannot invent a candidate. So HOME already has
exactly one "what to do next" line, resolved through one call chain, not
two competing cards. What is **not** unified into that same object is
"company state" (KPI/cash/office roster) — those stay separate, deliberately
narrower projections (`HomeDashboardDisplayData`, `HomeOfficeStageDisplay`)
specifically so HOME structurally cannot render a financial verdict
(`financialStatus`/`fiscalYearCompleted` are never projected — confirmed by
reading both classes' field lists). This narrowness is load-bearing, not
an oversight — see §7 Question B below.

### §4 — Recommended Action candidate generation / priority / CTA target

`_recommendedActionCandidates` (getter, `public_demo_01_placeholder_screen.dart:2915`)
is the single source. It never reconstructs a predicate independently: each
`_add*Candidate` helper mirrors the *exact* branch/condition of the
corresponding already-rendered button (`ec(i)` for engineers, `ac(i)` for
applicants, `assignmentCard(i)` for assignments), calling the *same* bound
handler. `selectHomeRecommendedAction` (`home_recommended_action.dart`) is a
pure, stable, single-pass scan: lowest `presentationPriority` wins, ties
broken by emission order (`workflow.engineers`/`.applicants`/`.assignments`
order) — never by an unstable comparator. `HomeRecommendedActionSlot` is
tri-state (`Available`/`None`/`Suppressed`), decided once, at the top of
`_recommendedActionSlot`, by `s.isCloseBlocked` (the same authority name
covering bankruptcy, March cash-shortage failure, and fiscal-year
completion — HOME never restates the three cases individually). CTA
targets are never resolved by id lookup downstream: `HomeRecommendedActionCandidate.invoke`
carries the *already-bound* closure from the exact call site that would
have fired the corresponding on-screen button, so a candidate cannot exist
for a button that is not itself rendered and enabled — see §6 for the one
place this invariant was found to have a scope gap (not a violation).

### §5 — Employee Status connection

`PublicDemoEmployeeStatusResolver.resolve` (Issue #238, PR history above) is
the single, pure, six-value taxonomy (研修が必要/営業可能/営業中/参画予定/参画中/待機)
shared by the roster card and SkillSheet. It takes only
`stage`/`isCurrentlyAssigned`/`isReadyForFieldSales`/
`fieldSalesActionReachableThisMonth` — all facts the caller already
computed from `PublicDemoWorkflowState`/`PublicDemoEngineerRuntime` — and
never re-derives cash, payroll, or assignment membership itself. It is
deliberately coarser than the raw 9-stage `engineerStatus`/
`PublicDemoSalesProgress` stepper, which remains the SSOT for pipeline
*detail* views. `trainingSelections` never overrides this resolver's output
(a documented, already-fixed label/tone disagreement — see the class doc).
This resolver is correct and unchanged by anything this audit found.

### §6 — Project / Order / Assignment Context connection

`PublicDemoProjectContextResolver` (Issue #239, PR #240, two Codex Broad
Review fixes already applied and verified by tests) resolves, per engineer,
which of three existing project-id sources is authoritative right now
(assigned → `PublicDemoAssignment.projectId`; ordered-not-assigned →
`genuineInterviewProjectId` then a leftover assignment row; earlier
pipeline stages → `genuineInterviewProjectId` then the still-open
`PublicDemoMatchingProposal.projectId`), and never surfaces a project for a
failed interview or the OLD project once a July+ replacement has been
secured (`replacementStage == ordered`). `ordered != assigned` is preserved
throughout — confirmed unchanged in the audited SHA. This connection is
correct and unchanged by anything this audit found.

### §7 — Recruitment / confirmed-next-month-join / joined-applicant connection

Traced end to end via Issue #221/#232/#234/#241's own already-committed
work: applicants are generated **only** by a real `recruit()` call
(`PublicDemoSeededRecruitmentGenerator.generate`, a pure
`(runSeed, month, medium, slot)` function) — `PublicDemoWorkflowState.initial()`
seeds zero applicants, and no monthly close ever generates one. Join
happens only at the close of the month in which an accepted offer's
`fiscalCloseId` matches (`_joinAcceptedApplicants`, generalized to every
close by #221/#222) — never same-day. `PublicDemoApplicant.stage` is
deliberately never rewritten by `join()` (by design — it is the applicant's
permanent pipeline identity), so every caller that needs "has this person
actually joined yet" must check `hasJoined`, not `stage`, separately.
Issue #241's Fresh Audit (already in this repo) found and fixed the two
places this had been missed — the Sales-tab applicant funnel and HOME's own
`_addApplicantStageCandidate` scan — **and**, as self-hardening, closed the
same hole at the domain layer (`!applicant.hasJoined` added as a
precondition on all six pre-entry-pipeline transition methods in
`PublicDemoWorkflowState`, plus one PR #242 review fix at the
`PublicDemoAggregate` boundary for atomicity). Re-verified directly in the
audited SHA: `for (final a in workflow.applicants.where((a) => !a.hasJoined))`
is exactly the loop guard `_recommendedActionCandidates` uses today
(`public_demo_01_placeholder_screen.dart:2977`). No regression found.

### §8 — Cash shortage / waiting-employee / assignment-shortage recovery routes

Three distinct, non-overlapping mechanisms, confirmed never to double up on
the same screen space:

1. **Already-realized shortage** (`s.financialStatus == cashShortage`) → `PublicDemoCashShortageCard` (HOME, above everything) + the `cashShortageResponse` Recommended Action candidate (informational only — `isInformational == true` — it never mutates state, matching `PublicDemoMonthGuard`'s own contract that an informational item never blocks a close).
2. **Forecasted, not-yet-realized shortage** (`financialStatus == normal` but `PublicDemoCashForecast` projects a future shortage) → `_cashForecastAdvice`, which **outranks** the normal Navigator line (`_effectiveAdvice = cashAdvice ?? _baseAdvice`) and resolves a genuinely actionable next step via `PublicDemoCashAdviceSelector` (confirm SkillSheet / start internal training / begin selling) against a pool that deliberately excludes currently-assigned engineers (a Codex PR #159 P2 fix, re-verified present) — falling back to a "confirm the finance plan" CTA only when no valid engineer-level action exists, never a fabricated command.
3. **A genuinely waiting, already-`ordered`, sales-pipeline-complete engineer, July–February** → `PublicDemoRecoveryEligibility.isEligible` (RECOVERY-LOOP-1) → the `recoveryAssignment` candidate, which is the **one** kind ranked *above* `cashShortageResponse` (`presentationPriority: -1`) specifically so an informational cash card can never permanently crowd out a real, mutating recovery step that is sitting right there and legal.

This three-way structure is sound and internally consistent. §9 below is
where the audit found the actual month-boundary gap in *how far this
window reaches back*.

### §9 — April opening vs. May-onward month-start experience

April is genuinely distinct: it is the only month gated by the persisted
Opening Context marker (Issue #229, `PublicDemoOpeningMarker`) — shown only
for a brand-new playthrough with no restored save, dismissed once and never
again for that browser. April is also the only month where `ec(i)`
(engineer sales-pipeline card) renders unconditionally for **every**
engineer, and HOME's Recommended Action mirrors that
(`if (s.month == 4) { for (final e in workflow.engineers) ... }`).
`_monthGoalTextFor` (the HOME fallback "what to watch" line) is a fixed
per-month table (4–15, plus an `_` default) that never repeats an action
already covered by a live Recommended Action candidate (documented,
verified against the switch's own doc). This is all correct.

**What is not correct, and is this audit's primary new finding, is what
happens to a founding engineer who does not finish the sales pipeline
within April** — see §12 Finding 1.

### §10 — July bonus / year-end / bankruptcy boundaries

- **July**: `s.month == 7 && !s.summerBonusDecisionConfirmed` is the one
  `required`-level Month Guard rule (cannot be bypassed) and is also
  `HomeRecommendedActionKind.summerBonusDecision` (P1 band,
  `presentationPriority: 10`). Confirmed both read the exact same
  `confirmed` flag — cannot disagree.
- **March (month 15) / fiscal-year completion**: `closeOrdinaryMonth()`
  handles March too (no month-15-specific handler); once
  `s.fiscalYearCompleted` is set, `s.isCloseBlocked` becomes true, so
  `_recommendedActionSlot` returns `HomeRecommendedActionSuppressed()` —
  HOME structurally shows no next action, and `PublicDemoYearEndResultCard`
  (Accounting tab) takes over. The Monthly Management Report dialog itself
  already special-cases this month (PR #237 Codex P2 fixes, re-verified
  present): the dismiss CTA reads "年度結果を見る" only when
  `closedMonth == 15`, and its Hiyori comment checks
  `isFiscalYearCompleted`/`isFinanciallyTerminal` **before** the
  waiting/assigned branches, so it never tells a player to use a Sales tab
  action that no longer exists.
- **Bankruptcy** (`s.isFinanciallyTerminal`): same suppression path via
  `isCloseBlocked`; `_bankruptcyTerminalCard()` renders above the (now
  suppressed) HOME dashboard section, never duplicated by the Report.

All three boundaries are internally consistent and already correctly
special-cased where copy could otherwise mislead. No new gap found here.

### §11 — Save/reload truthfulness

`_restoreAggregate()` (`initState` → `unawaited(_restoreAggregate())`)
loads one complete, already-validated `PublicDemoAggregate` (state +
workflow together, one JSON tree, one 1200ms timeout budget) or falls back
atomically to a fresh `PublicDemoAggregate.initial(...)` — there is no
partial-restore path and no separate "restore state" vs. "restore
workflow" step that could desync. Every HOME/Recommended-Action/Office-
Stage/Important-Tasks getter reads only `_game`/`s`/`workflow`, evaluated
fresh on the very first `build()` after restore — none is computed once at
close time and cached forward. The Monthly Report dialog is the one thing
genuinely lost on a reload mid-dialog (by design, already documented as a
Known Limitation in Phase B — it is not authoritative and re-showing it is
neither possible nor necessary, since the state it describes was already
committed before it ever appeared). No truthfulness gap found for §11.

### §12 — Stale / duplicate / impossible CTA conditions

**Already found and fixed, re-verified present in the audited SHA (no
regression):**
- Issue #238 P1: raw un-collapsed per-substage employee status labels; a
  training-selection tone silently overriding the waiting/ready split; a
  participation-tone/label disagreement after a mid-month `endAssignment`.
- Issue #239/PR #240 P1+P2: a failed interview stage showing "提案中の案件"
  for an already-concluded interview; the July+ replacement mini-cycle
  showing the OLD (ending) project's real title under a "新案件参画予定"
  banner.
- Issue #241/PR #242: an already-joined applicant remaining visible (and
  actionable, via a real domain command) in the Sales-tab funnel and HOME's
  Recommended Action, plus the underlying domain-layer gap that let a
  mid-pipeline pre-entry transition silently complete against an
  already-joined person.

**Newly found by this audit — see §12 Finding 1 below (root cause / gap).**
No other stale/duplicate/impossible-CTA condition was found in this pass:
every remaining `_add*Candidate` branch was cross-checked against its
mirrored render site's own enable condition (`salesRemaining > 0` guards,
`readyForFieldSales` guards, `PublicDemoRecoveryEligibility.isMonthEligible`)
and found consistent.

### §13 — 360×800 / 390×844 room to add information without breaking One-Screen HOME

Not independently re-measured pixel-by-pixel in this READ-ONLY pass (that
verification belongs to an implementation phase, per every prior HOME
Result Report's own convention — HOME-COMPACT/ONE-SCREEN-FINAL-FIT/
FINAL-DENSITY already spent significant, documented effort tuning this
exact budget). What this audit *can* state from the code: the one concrete
fix this audit recommends (§14 Finding 1) adds **zero** new information to
HOME's own layout — it only widens an *existing* Recommended Action
candidate's eligibility window by two months and revives an *already-built*
`ec(i)` card on the separate 社員 tab for two more months. HOME's
`_recommendedActionSlot` still renders exactly one card in exactly the same
position; the 社員 tab is not subject to HOME's One-Screen budget at all
(it already scrolls). So the proposed fix carries no known mobile-layout
risk, but the implementation phase must still re-run the existing
360×800/390×844 × TextScaler regression suite (§15) rather than assume this.

## 3. Required state matrix

| State | Displayed status (HOME/roster) | Recommended Action | CTA target | Authority |
|---|---|---|---|---|
| Fresh April | 待機/研修が必要 badges per `_officeStageStatusFor`; KPI shows opening cash/headcount | `ec(i)` mirror for every engineer at `waiting`(ready)/`skillSheet` | SkillSheet review / 営業開始 (bound to `_openSkillSheetReview`/`_beginSelling`) | `_addEngineerStageCandidate`, month==4 block |
| May after no recruitment | 待機 (or 研修が必要); recruitment media candidate only | `recruitmentMedia` (P3) if window open, else `HomeRecommendedActionNone` → month-goal fallback | 求人媒体を開く | `_addRecruitmentMediaCandidate` / `canUseRecruitmentMediaInMonth` |
| waiting employee + sales-ready | 営業可能 (only if `fieldSalesActionReachableThisMonth`, else falls back to 待機 label) | `employeeSkillSheetReview`/`employeeBeginSelling` **only in months 4, 6(joined-only), 7–14** — **none in May/June for a founding engineer** (Finding 1) | スキルシートを確認/営業を開始 | `PublicDemoEmployeeStatusResolver` + `_addEngineerStageCandidate` |
| waiting employee + training-required | 研修が必要 | none (training is deliberately never recommended — see `HomeRecommendedActionKind`'s own doc) — reachable via `_employeeGrowthSection`'s always-on training card, month≥5 | 研修する (`_selectInternalTraining`) | `internalTrainingCard`, `PublicDemoEngineerRuntime.isReadyForFieldSales` |
| active sales pipeline (selling/introduced/interview stages) | 営業中 | stage-specific (`employeeIntroduceProject`/`employeePartnerInterview`/`employeeClientInterview`/`employeeAcceptOrder`/`employeeResumeSelling`) — **same May/June gap for founding engineers** | 案件を紹介/上位会社面談へ/客先面談へ/案件を受注/再営業する | `_addEngineerStageCandidate` |
| ordered but not assigned | 参画予定 | none (correct — "wait for month close" has no action) | — | `PublicDemoEmployeeStatusResolver.resolve` case `ordered && !isCurrentlyAssigned` |
| assigned engineer | 参画中 | none in months 4–6; `founderFollowUp` in months 8–14 if eligible; June's `assignmentConfirmNextOrder`/replacement chain | 発注を確認する / 客先面談へ / etc. | `_addAssignmentCandidate`, `PublicDemoFounderFollowUp.isEligible` |
| recruitment applicant pending (applied→interviewed) | 応募/書類確認済/採用面談済 | `applicantReviewResume`/`applicantInterview`/`applicantContinueInterview`/`applicantSalaryOffer` | 経歴書を確認/採用面談へ/面談へ/給与提示へ | `_addApplicantStageCandidate` |
| confirmed next-month join (`juneOrdered`, `!hasJoined`) | 入社・参画予定 | none (correct — nothing to do but wait) | — | `applicantStatus`, `PublicDemoMonthlyReportSnapshot.confirmedNextMonthJoinApplicantIds` |
| newly joined employee | 待機 or 研修が必要 (now in `workflow.engineers`, sales-pipeline reset) | Sales-tab funnel and HOME candidate both correctly stop showing them once `hasJoined` (Issue #241) | — | `withJoinedEngineers`, `PublicDemoApplicant.hasJoined` |
| cash warning / recovery-needed | `PublicDemoCashShortageCard` (realized) or `_cashForecastAdvice` (forecasted) | `cashShortageResponse` (informational, P0) or forecast-driven engineer action, or `recoveryAssignment` (P-1, outranks P0) | 資金不足を確認 / 資金計画を確認する / スキルシートを確認・研修する・営業を開始 / 案件へ復帰 | `PublicDemoCashForecast`, `PublicDemoCashAdviceSelector`, `PublicDemoRecoveryEligibility` |
| July bonus boundary | Month Guard `required` block until decided | `summerBonusDecision` (P1) | 夏季賞与を決定 | `s.summerBonusDecisionConfirmed`, `PublicDemoMonthGuard` |
| March / year-end | HOME Recommended Action suppressed (`isCloseBlocked`); `PublicDemoYearEndResultCard` on Accounting tab; Report dismiss CTA reads "年度結果を見る" | none (correctly suppressed, not merely absent) | — | `s.fiscalYearCompleted`, `HomeRecommendedActionSuppressed` |
| bankruptcy/terminal | `_bankruptcyTerminalCard()`; HOME Recommended Action suppressed; Report Hiyori comment avoids Sales-tab wording | none (correctly suppressed) | — | `s.isFinanciallyTerminal`, `HomeRecommendedActionSuppressed` |
| reload immediately after month transition | Identical to a live rebuild — every getter recomputed fresh from the restored aggregate | Identical to a live rebuild | Identical to a live rebuild | `_restoreAggregate` (atomic full-aggregate load) |

## 4. Audit questions

**A. Is a new month-start-only persistent state genuinely needed, or is
everything read-only-derivable from existing aggregates?**
Everything traced in §2/§3 is already read-only-derivable from the existing
`PublicDemoAggregate` at build time. No candidate for a new persisted field
was found. The one real gap (§5 Finding 1) is a **presentation eligibility
window**, not a missing fact — every fact it needs (`stage`,
`isCurrentlyAssigned`, `isReadyForFieldSales`) already exists and is already
read by the exact same helper (`_addEngineerStageCandidate`) that already
handles the July–February case.

**B. Can "company state" and "next move" collapse into one presentation
resolver?**
Largely already done for "next move" (`_effectiveAdvice` →
`navigatorAdviceFor`, §3.1) — one line, one CTA, one call chain, pure and
total. "Company state" (KPI/cash/roster) is deliberately kept as separate,
*narrower* projections so HOME structurally cannot render a financial
verdict on its own (`financialStatus`/`fiscalYearCompleted` are never
projected into `HomeDashboardDisplayData`). Merging the two into a single
object would either widen that projection (reintroducing the exact coupling
2A/2C were built to avoid) or duplicate data already shown by the KPI/Office
Stage sections. Recommendation: **do not merge them further** — the current
split (one resolver for "what to do", separate narrow projections for
"what is true") is the correct shape and should be preserved by any
implementation.

**C. Does the existing Recommended Action set have stale/impossible/
info-confirmation-prioritized problems?**
`cashShortageResponse` is informational and P0, but is explicitly
*outranked* by the one truly mutating recovery step
(`recoveryAssignment`, P-1) precisely to prevent an info-only card from
permanently starving a real action — confirmed this exception is narrow and
documented, not a general pattern. No stale or impossible candidate was
found (§12); the only defect found is an **absence**, not a wrong-priority
presence (§5 Finding 1).

**D. Can the "last month's result → this month's action" comprehension
loop be closed using only the Monthly Report + HOME's existing
information?**
Yes, for what already exists: the Monthly Report states 現金/売上/支出/参画・
待機人数/翌月入社予定 for the month just closed, and HOME's own KPI restates
the *current* cash/headcount the moment the report is dismissed — a player
who reads both can already connect "what changed" to "what's true now"
without any new field. What it cannot yet close, because the underlying
Recommended Action authority itself has the gap in §5 Finding 1, is
"why does nobody need my attention this month" when the true answer is "an
engineer is stuck and nothing on screen currently says so."

**E. Minimum scope before Human Replay #225 can resume?**
See §7 below.

## 5. Root causes / gaps

### Finding 1 (P1) — A founding engineer left mid-sales-pipeline at the end of April has no recommendable action and no on-screen control for two full months (May, June)

**Evidence (already-committed production code, not proposed):**

- `_employeeNextActionsSection`'s own doc (`public_demo_01_placeholder_screen.dart:2406-2413`)
  states explicitly: `ec(i)` — the only card offering
  スキルシート確認/営業開始/案件紹介/面談/受注 — renders in April (every engineer),
  in June (**only** engineers in `s.joinedApplicantIds`, i.e. a later-recruited
  hire — never a founding engineer), and in July–February (RECOVERY-LOOP-1,
  every economically-waiting engineer). **May renders it for nobody.**
- `_recommendedActionCandidates` mirrors this exactly:
  `if (s.month == 4) { ...all engineers... }`,
  `if (s.month == 6) { ...only s.joinedApplicantIds.contains(e.id)... }`,
  `if (s.month >= 7 && s.month <= 14) { ...all engineers not currently assigned... }`.
  There is no `s.month == 5` branch, and the `s.month == 6` branch explicitly
  excludes founding engineers.
- `PublicDemoAggregate.closeApril` (`lib/game/public_demo/public_demo_aggregate.dart`)
  performs growth, the financial close, and `assignOrderedForMay()` (which
  only materializes an assignment for an engineer **already** at `ordered`)
  — it does not advance or reset any engineer's `PublicDemoSalesStage`.
  `PublicDemoWorkflowState`'s sales-pipeline transition methods
  (`beginSelling`/`introduceProject`/interview recorders) are themselves
  never month-gated (confirmed by `PublicDemoRecoveryEligibility`'s own
  class doc, which relies on exactly this fact for July+).
- `_employeeGrowthSection`'s own doc is explicit that its `s.month >= 5`
  training card is the *only* thing reachable in May/June for a
  non-`ordered` founding engineer, and training addresses field-sales
  *readiness*, never the sales-pipeline steps themselves.

**Consequence:** a genuinely plausible first-month outcome — a new player
who does not fully walk both founding engineers through
待機→スキルシート→営業開始→案件紹介→上位会社面談→客先面談→受注 inside April
alone — leaves that engineer with **zero interactive control anywhere on
screen** and **zero HOME/Month-Guard signal that anything is outstanding**
for the entirety of May and June, resurfacing only when July's
RECOVERY-LOOP-1 window opens. This directly undercuts the audit's own Goal
("誰を営業…すべきか") for exactly the population (founding engineers) the
Public Demo's first two months are built around, and is a stronger,
previously-undocumented instance of the same defect class the Post-Balance
Human Replay Fresh Triage (Issue #225, §2) already flagged around
order/assignment comprehension.

**Why this is not a duplicate of RECOVERY-LOOP-1's own scope:**
RECOVERY-LOOP-1 (Issue #119) was deliberately scoped to July–February for a
different, narrower population — engineers who are economically *waiting*
after having *already* reached `ordered` once. Finding 1's population is
broader (any founding engineer not yet at `ordered`) and the window it
falls into a gap for (May–June) is *earlier* than RECOVERY-LOOP-1's own
start month. Extending RECOVERY-LOOP-1 backward by two months would also be
wrong: its own July start is tied to `PublicDemoRecoveryEligibility
.firstEligibleMonth`, which several other authorities (Month Guard
messaging, HOME copy) already assume. The correct fix is a **new, narrow**
month-5/6 render-site + candidate-emission extension for founding engineers
specifically, mirroring the *shape* of the existing month-6/July branches
without touching their own conditions.

### Finding 2 (P3, informational only) — Dead HOME-shell code is a comprehension trap, not a functional bug

See §3's dead-code note. No behavioral impact (nothing renders it), but a
future auditor or contributor who edits `lib/presentation/home/home_shell_page.dart`
or its 7 orphaned widgets expecting a production effect would silently
waste effort. Recommended as a follow-up cleanup issue (delete or clearly
mark `@Deprecated`/superseded), not part of this audit's scope to fix.

## 6. Verdict

**GO WITH MINOR DESIGN CHANGES.**

No new economic threshold, no new persisted state, no save-schema change,
and no HOME redesign are needed. The single functional gap found (Finding
1) is fixable by widening two existing, already-precedented conditionals
(`_employeeNextActionsSection`'s `ec(i)` render gate, and
`_recommendedActionCandidates`'s matching emission gate) to cover May and
June for a founding engineer not yet `ordered` and not currently assigned —
the same shape as the existing month-6 (joined-applicant) and month 7–14
(RECOVERY-LOOP-1) branches, reusing the exact same `_addEngineerStageCandidate`/`ec(i)`
call already used elsewhere. This is exactly the class of "smallest safe
implementation slice" this codebase's own prior Fresh Audits (RECOVERY-LOOP-1,
PR #210's recruitment-media window widening) have already used successfully.

## 7. Proposed minimal presentation architecture

No new architecture. Concretely:

1. **`_employeeNextActionsSection`** (`public_demo_01_placeholder_screen.dart`):
   add one branch — `if (s.month == 5 || s.month == 6)` — that renders
   `ec(i)` for every engineer where `e.stage != PublicDemoSalesStage.ordered`
   and the engineer is not in `s.joinedApplicantIds` (to avoid double-
   rendering the existing month-6 joined-applicant loop) and is not
   currently assigned. Concretely this **replaces** the existing
   `if (s.month == 6) { ...joinedApplicantIds-only... }` engineer loop with
   a combined `if (s.month == 5 || s.month == 6)` loop covering **both**
   populations (founding-not-yet-ordered, and joined-applicant-not-yet-
   ordered) under one condition, to avoid two near-duplicate loops.
2. **`_recommendedActionCandidates`**: same shape, mirrored — extend the
   existing month==6 engineer-loop condition to also run for month==5, and
   drop its `joinedApplicantIds`-only restriction in favor of "not yet
   ordered, not currently assigned" (matching the July–February loop's own
   filter exactly, just two months earlier for this specific population).
3. **`_fieldSalesActionReachableThisMonth`** (used by `PublicDemoEmployeeStatusResolver`'s
   caller to decide whether 営業可能 is a truthful label): update its
   `switch`/`if` to also return `true` for month 5 (currently `false`),
   keeping every other branch unchanged — otherwise Finding 1's fix would
   make a card newly reachable in May while the roster's own status label
   still (truthfully, per the *old* rule) said 待機 with no reachable
   action, reopening exactly the PR #233 P2 class of bug this function
   exists to prevent.

No new class, no new enum value, no new field on any display-data object.
`HomeRecommendedActionKind` needs no new value — the emitted candidates
(`employeeSkillSheetReview`/`employeeBeginSelling`/`employeeIntroduceProject`/
etc.) already exist and already have correct presentation priorities.

## 8. Changed-file candidates (not yet changed — READ-ONLY audit)

| file | expected change |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_employeeNextActionsSection` (widen the month-6 engineer loop to month 5+6, drop the joined-applicant-only filter in favor of not-yet-ordered/not-assigned); `_recommendedActionCandidates` (same shape); `_fieldSalesActionReachableThisMonth` (return `true` for month 5 too) |
| `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart` (or a new focused test file) | new cases: a founding engineer at `waiting`(ready)/`skillSheet`/`selling`/etc. in May and June now yields a Recommended Action candidate and Month Guard "recommended" warning; existing month-4/6-joined-applicant/July–February cases unchanged |
| `test/ui/public_demo/public_demo_01_employee_ui_*_test.dart` (existing Employee UI test files) | new cases: `ec(i)` now renders for a founding, not-yet-ordered engineer in May/June; existing April/June-joined-only/July+ cases unchanged |
| `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` or equivalent | regression: 営業可能 label only appears in May now for an engineer with a genuinely reachable card (the `_fieldSalesActionReachableThisMonth` update keeps label truthful) |

No `lib/game/**` file, no `PublicDemoSaveCodec` file, and no HOME layout
file is expected to change.

## 9. Test matrix (for the implementation phase)

- Fresh April: unaffected (regression only).
- May, founding engineer stuck at `waiting`(ready): now yields
  `employeeSkillSheetReview` candidate + Month Guard "recommended" warning;
  roster status now correctly reads 営業可能 (not 待機).
- May, founding engineer stuck at `selling`/`introduced`/interview-pass-or-fail:
  now yields the matching stage candidate; 営業中 label unaffected (label was
  already correct — only the *action* was missing).
- June, founding engineer still not `ordered` (same stuck states): same as
  May, now consistent with the already-existing joined-applicant case.
- June, joined-applicant not yet `ordered`: unchanged (regression only,
  same candidates as before, now emitted by the combined loop).
- July onward: unchanged (RECOVERY-LOOP-1 loop already covers this
  population; the May/June fix must not double-emit once month ≥ 7).
- An engineer who reaches `ordered` inside May/June via this new control:
  unaffected downstream — `assignOrderedForMay`/June's own assignment
  materialization already handle an `ordered` engineer regardless of which
  month they reached it in.
- Month Guard: April/May/June recommended-level warning list now includes
  this newly-eligible population where applicable; required-level (July
  bonus) unaffected.
- 360×800/390×844 × TextScaler 1.0/1.3: re-run the existing Employee-tab and
  HOME regression suites (no new information is added to HOME itself — see
  §2 §13 — but the 社員 tab gains cards in two more months and must be
  re-verified for overflow there).
- Full regression: `test/game/public_demo/` (unaffected — no domain file
  changes) and `test/ui/public_demo/` (must stay green).

## 10. Persistence / schema impact

**None.** No new field, no new enum value, no `toJson`/`fromJson` change.
The proposed fix reads only already-persisted, already-validated facts
(`PublicDemoSalesStage`, `assignedEngineerIds`, `joinedApplicantIds`) that
every other branch of the same two methods already reads.

## 11. Known limitations (carried over, still accurate)

- Monthly Report is not persisted (Phase B's own documented limitation) —
  a reload mid-Report loses only the dialog, never state.
- No month-over-month ("前月比") comparison exists in the Monthly Report —
  out of scope for this audit, unchanged.
- No truthful "入社予定月（◯月）" figure is shown for a confirmed-next-month
  join beyond "入社・参画予定" (Issue #241's own documented limitation) —
  unchanged, out of scope here.
- 求人媒体/採用 comprehension gaps flagged by the Human Replay (timing
  perception, interview-question appropriateness) are unaddressed by this
  audit — they are UI/copy questions distinct from the state-authority
  question this audit was scoped to.

## 12. Human Replay #225 resumption condition

The Post-Balance Human Replay Fresh Triage (2026-09-10) paused full
April→March sign-off pending "P0/P1 focused reproduction: order →
next-month assignment and proposal/result persistence" (§8 item 1 of that
report). Issue #239/PR #240 has since **closed that item** — project
identity now stays truthful and consistent across the sales-pipeline card,
roster, `activeProjectStatusCard`, and June's assignment card, with two
Codex-reviewed follow-up fixes already merged and verified. Issue #241/PR
#242 has since closed a second, adjacent progression defect (a joined
applicant remaining actionable in a pre-entry funnel that should have
already ended for them).

This audit's own Finding 1 is a **new** item that was not part of Issue
#225's original findings and is not, on its own, a blocker for resuming
Human Replay from April: it is a comprehension/progression gap for a
*specific* population (a founding engineer who does not finish selling
within April) rather than a general order→assignment defect, and a replay
that fully sells both founding engineers in April (matching the intended
happy path this Public Demo's April tutorial-adjacent event dialogs are
built around) will not encounter it at all.

**Recommended condition to resume Human Replay #225:** implement Finding 1
first (small, 2–3 hour, no schema/domain risk — see §13), *then* resume
April→March replay. This closes the last known state-authority gap the
Post-Balance Triage's own §8 priority order names before the Triage's
remaining items (§2 core-loop comprehension copy, §3 SkillSheet/training
copy, §5 recruitment timing/copy) — none of which are state-authority
defects and can be triaged in parallel with, or after, a fresh replay.

## 13. Implementation plan (GO — 2–3 hour Claude Code units, not yet started)

1. **Unit 1 (~1.5–2h): Finding 1 fix + focused tests.**
   `_employeeNextActionsSection` + `_recommendedActionCandidates` +
   `_fieldSalesActionReachableThisMonth` changes from §7/§8, plus the new
   focused test cases from §9 (Recommended Action candidate emission,
   Month Guard recommended-level warning, roster label truthfulness,
   `ec(i)` render-site coverage). Self-hardening pass against: double-
   emission once month ≥ 7, double-emission for an already-`ordered`
   engineer, and the existing month-6 joined-applicant case staying
   unchanged.
2. **Unit 2 (~30–45 min): full regression + mobile verification.**
   `flutter test test/game/public_demo` (expect unchanged, zero-diff
   domain), `flutter test test/ui/public_demo` (full suite green),
   360×800/390×844 × TextScaler 1.0/1.3 on the 社員 tab for May/June with
   a stuck founding engineer.
3. **Unit 3 (~20–30 min): Result Report + Codex Broad Review (once, per
   the standing review policy) + P0/P1/First-Fun-Year-relevant-P2 fix pass
   if any findings surface.**

Finding 2 (dead-code cleanup) is explicitly **not** part of this
implementation plan — it is a separate, lower-priority follow-up the
repository owner can file as its own issue.

---

_Generated by [Claude Code](https://claude.ai/code)_
