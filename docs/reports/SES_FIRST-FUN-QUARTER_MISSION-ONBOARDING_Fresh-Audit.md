# SES First Fun Quarter — Mission System / Beginner Onboarding — Fresh Audit

**Status: READ-ONLY audit. No production code, tests, or workflow files were modified. Nothing in this session was committed or pushed.**

Audited `origin/main` SHA: `dfb272619b92219853203a2f72eba4c785c0f66f`
(confirmed via `git fetch origin main && git rev-parse origin/main` at session start — matched the SHA the task supplied; `origin/main` had not advanced further during this session)

Audit method: the session branch (`claude/ses-first-fun-quarter-audit-n7gk4p`) contained no commits of its own beyond `origin/main` (`git log HEAD --not origin/main` = 0), so the working tree was reset to `origin/main` (`git reset --hard origin/main`, no history rewritten, nothing pushed) for accurate read-only inspection with normal file tools. All paths below are repo-relative and valid at this SHA.

---

## 0. Final Verdict (short form — see §15 for full verdict)

**GO for a phased Mission System, with one structural correction to the task's own premise: several of the 24 candidate missions are not independent player actions in the current domain — they are the *same* authoritative fact viewed twice, or a fact with no domain-level "player did this" signal at all.** Sections §2–§3 identify exactly which, with a recommended fix (merge, rename, or explicitly scope out) rather than a silent deletion, per the task's own instruction. The Mission System itself (progress tracking, unlock sequencing, Hiyori narration) is a **new, additive presentation-plus-thin-persistence layer** — no existing domain authority needs to change, and (with one exception, training completion — §3, Mission 9) every mission's completion signal can be **derived** from state the game already persists, which is the safest possible save-compatibility posture (§10).

---

## 1. Current Behavior — What Exists Today

### 1.1 Two separate onboarding surfaces already exist, neither is a "Mission System"

Public Demo does **not** use the main game's `BeginnerModeEngine`/`BeginnerModeState` (`lib/game/engine/beginner_mode_engine.dart`, `lib/game/models/beginner_mode_state.dart`) — a repo-wide search for `BeginnerMode` under `lib/game/public_demo/` and `lib/ui/public_demo/` returns zero matches. Public Demo's onboarding is its own, independent, additive mechanism:

1. **`PublicDemoOpeningContextScreen`** (`lib/ui/public_demo/public_demo_opening_context_screen.dart`) — shown once per browser (tracked by `PublicDemoOpeningMarker`, a `SharedPreferences` key **completely independent of save schema** — see §10.4), before the player's first April. It is a **single scrollable list** (目的 → 初期資金 → 毎月の固定費 → 注意/倒産リスク → 創業メンバー紹介 → 最初にすること), followed by two buttons: "まずSkillSheetで2人を確認する" (opens 社員タブ) or "4月の経営を始める" (opens HOME). This is exactly the "列挙式" the task asks to convert to a conversational format — see §6.
2. **The SkillSheet confirmation hard gate** (`waiting → skillSheet → selling`, `PublicDemoEngineerSales.stage`) — a genuine one-click state transition every engineer must pass through before selling can start. Multiple prior audits (§8 below) have already examined and **deliberately kept** this gate; see §3, Mission 1.

There is **no persisted milestone/achievement system of any kind** in Public Demo today — a search for `Milestone`/`Achievement`/`firstRevenue`/`firstAssignment` under `lib/game/public_demo/` returns zero matches. The Mission System is a genuinely new layer, not a consolidation of an existing one.

### 1.2 Domain authority is unusually well-hardened — read this before designing Mission completion checks

Public Demo's domain layer (`lib/game/public_demo/`) has been through repeated security/anti-forgery hardening passes (WORKFLOW-STATE-1AB FIX1–FIX7, PR #214/#215/#216 and later). The pattern that recurs everywhere and that the Mission System **must** follow:

- A "stage" enum field (`PublicDemoSalesStage`, `PublicDemoApplicantStage`) is **not, by itself,** trusted proof that an action really happened — every place that matters also checks an **unforgeable record** (`PublicDemoEngineerInterviewRecord`, `PublicDemoJoinRecord`, `PublicDemoInterviewRecord`), whose constructor is private to its own file and can only be minted by the one sanctioned domain method for that transition.
- **The Mission System must read the same unforgeable records / derived booleans the game's own eligibility logic already reads — never re-derive "did this happen" from a raw stage field alone.** Doing otherwise would silently reopen a forgery class the domain team already spent multiple PRs closing (e.g., a save edited to show `stage: ordered` without ever having a genuine interview record). §3's authority column always cites the record-backed fact, not the bare stage.

### 1.3 The screen doing all of this is a single 6,721-line file

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart` is 6,721 lines and is the single call site for essentially all Public Demo UI wiring — the 5-tab `NavigationBar` (§7), every tab body, every dialog launch, every stage-transition button, the Opening Context screen's caller, and the SkillSheet sheet's caller. **This is a genuine implementation-risk finding, not a style note**: any Mission System touching "what happens after action X" (i.e., every mission) means touching this file, and the file's own governing plan (`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`) already records a HOME Freeze specifically because past changes here have had cross-cutting regressions. See §12 (risks) and §13 (Phase 1 batch) for how this shapes the recommended implementation split.

### 1.4 HOME Freeze is still in effect

The governing SSOT's "Current execution order" (as of the 2026-09-13 entry) still lists HOME Freeze as active: "HOMEの追加レイアウト変更は禁止." `_officeStageStatusFor` (HOME's own status-label function) is explicitly **not** yet routed through the shared `PublicDemoEmployeeStatusResolver` for exactly this reason (§3 of the Employee-Status-Unified-Display Fresh Audit, `docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Fresh-Audit.md`). **Any Mission System design that assumes it can freely add a HOME card is contradicted by current policy** — see §7 (navigation) for how this changes the recommendation.

---

## 2. Mission Candidates — Review Against Current Implementation

The task asked for the 24-item list to be checked against real code, and for duplicates/unnatural naming/SES-industry-inaccuracies to be **flagged with a reason and a proposed fix, not silently deleted.** Findings:

### 2.1 Confirmed duplicate: Missions 15 and 16 are the *same domain action*

> 15. 採用候補者に給与条件を提示する
> 16. 内定を出す

Traced call path: the UI's **only** offer-related button opens `PublicDemoSalaryOfferDialog`, whose confirm action calls `PublicDemoAggregate.acceptOffer(applicantId, offer, fiscalCloseId)` **directly** — a single command that (a) computes the offer via `PublicDemoSalaryOfferEvaluator.evaluate` (salary vs. `acceptanceScore`), (b) immediately decides accept/decline, and (c) if accepted, mints the `PublicDemoBindingOffer` in the same call. **There is no separate "extend an offer, then the candidate decides" two-step in the current domain** — presenting salary conditions *is* extending the offer, in one atomic transaction. `PublicDemoApplicantStage.offerAccepted` (displayed "内定承諾") is the resulting stage; there is no distinct stage for "an offer was extended but not yet decided."

**Recommendation:** merge Missions 15/16 into one: **"給与条件を提示し、内定を出す"** (single completion event = `acceptOffer` resulting in `offerAccepted`). Do not implement them as two separately-trackable missions — a player cannot complete them as separate actions, and a two-step mission UI would imply a game mechanic that does not exist (the task's own §Mission候補 instruction against inventing hidden mechanics applies here in reverse: do not invent a *player-visible two-step* where the domain has one atomic step).

### 2.2 Likely-duplicate / no distinct authority: Mission 17

> 17. 応募者を採用する

No domain method named anything like "hire"/"採用する" exists distinct from (a) `acceptOffer` (§2.1, "内定を出す") or (b) `PublicDemoJoinTransaction.join`/`PublicDemoApplicant.join` (Mission 20, "入社する"). "採用する" as commonly understood in SES business language ("this candidate is now our employee") is genuinely satisfied only by **join**, not by offer acceptance (an `offerAccepted` candidate is not yet payroll/headcount — see `hasJoined`, §1.6 of the Employee-Status-Unified-Display audit, quoted in §3 below). Two readings are possible and the task's list does not disambiguate them:

- If "採用する" means "decide to hire" → this is Mission 16/15 (§2.1), already covered.
- If "採用する" means "the person is now actually an employee" → this is Mission 20 (入社する) verbatim.

**Recommendation:** drop Mission 17 as written, or rename it to make the distinction explicit if the design intends a third, currently-nonexistent checkpoint (e.g., an explicit "採用確定" HR paperwork step separate from both offer and join) — that would be a **Category C** (new domain concept), not a UI-only mission wiring, and should not be assumed to exist without a product decision. This audit recommends the former (drop/merge into 20) since inventing a new domain step this late in the current SSOT's priority order is out of scope for First Fun Quarter.

### 2.3 Confirmed duplicate: Mission 22 largely restates Mission 8

> 8. 技術者を案件に参画させる
> 22. 売上を発生させる

`PublicDemoRevenue.monthlyRevenueForAssignedCount` computes revenue **directly and only** from `PublicDemoState.engineersAssigned` (itself `assignedEngineerIds(month:).length`) — i.e., revenue is not a separate action a player takes; it is the **automatic, immediate consequence** of Mission 8 succeeding. There is no distinct "generate revenue" command a player invokes.

**Recommendation:** do not implement Mission 22 as a separate mission with its own CTA — that would teach the player a false mental model ("participation" and "revenue" are two things to do) when the domain has one. Instead, fold the revenue fact into **Mission 8's own completion narration** ("技術者が案件に参画しました。これで来月から売上が計上されます。") — this is exactly the kind of cause→effect explanation the task's Mission System design (目的→操作→結果→説明→次Mission) already calls for, applied to a single mission rather than two.

### 2.4 Mission 23 has no domain-level "confirm" action — needs explicit redefinition

> 23. 入金を確認する

`PublicDemoRevenuePayment.apply` settles `pendingRevenue` into `cash` **automatically at month-end close** — there is no player command called "confirm receipt," and no boolean anywhere recording "the player looked at this." The Monthly Management Report (`PublicDemoMonthlyReportDialog`, §2032 SSOT entry) already displays the 現金/売上/入金/売掛金 breakdown after every month-end close, and the Accounting tab's own forecast section (`_accountingForecastSection`) shows it persistently.

**Recommendation:** redefine Mission 23's completion condition explicitly as a **presentation-layer event**, not a domain transaction: "the player has seen a Monthly Management Report (or opened 会計タブ) *after* a month in which `revenueReceived > 0`." This requires a small, new, additive UI-only signal (§3, Category B) — it is not a fabricated gameplay mechanic, but it is also not free from existing authority the way Missions 1–8 are.

### 2.5 Mission naming vs. real SES industry terms — spot checks

- 「上位会社面談」/「客先面談」 (Missions 5–6) — both terms are already the exact in-game/industry-standard terms (`selectionStepLabels` in `lib/ui/widgets/labels.dart`: `upperCompanyInterview` → 上位会社面談, `clientInterview` → 客先面談). No change needed.
- 「案件を受注する」(Mission 7) — already the term used everywhere in-game (`recordOrder`, UI button "受注する"). No change needed.
- 「内定者が入社前に営業を開始する」/「…受注する」(Missions 18–19) — matches the existing `preEntrySelling`/`preEntryClientPassed` pipeline verbatim; this is a real, already-implemented SES practice (multiple SES firms do sell not-yet-joined hires) and the domain already models it distinctly from post-join selling. No change needed, but flag for the Mission copy: this is a genuinely advanced/non-obvious mechanic for a First Fun Quarter beginner and should be sequenced late (§9).
- 「賞与を支給する」(Mission 24) — matches `PublicDemoSummerBonusPlan`/`PublicDemoSummerBonusPayment` exactly; July-only in Public Demo (main game's two-installment plan is explicitly excluded per that file's own doc comment). No change needed.

No missions were found to be factually wrong about SES business practice; the issues found are all **domain-granularity mismatches** (§2.1–§2.4), not incorrect terminology.

---

## 3. Mission Fresh Audit — Full A/B/C Classification (Revised List)

Per §2's findings, Missions 15/16 are presented merged, 17 is flagged for removal, and 22/23 are redefined. The table below tracks all **24 original numbers** so nothing is silently dropped, with the merge/redefinition noted inline.

Legend — **A**: existing state/event alone gives an accurate, unforgeable completion signal. **B**: existing feature exists, but Mission tracking needs a small additive state/event. **C**: the underlying game feature itself does not exist yet, or needs a large addition.

| # | Mission | Class | Existing feature? | Authority (model/state) | Completion signal | Save/reload survives? | Duplicate-reward risk | Month-transition risk | Size | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 技術者のSkillSheetを確認する | **A** | Yes — `_openSkillSheetReview` gate | `PublicDemoEngineerSales.stage != waiting` (i.e., has reached ≥`skillSheet`) | `stage` transitioned past `waiting` via the sanctioned gate call | Yes — `stage` is persisted, monotonic (never reverts to `waiting` except via `endAssignment`, which is itself a real re-entry, not a "un-view") | None — a monotonic stage transition is naturally idempotent | None — no month gate on viewing | XS | 1 |
| 2 | 技術者のSkillSheetを編集する | **C** | **No.** Confirmed absent: `public_demo_skill_sheet_sheet.dart`/`_sections.dart`/`_display_projection.dart` contain no write path — every widget is `StatelessWidget` rendering `PublicDemoSkillSheetDisplayData` verbatim, and the class's own doc states "This is presentation-only... nothing produced here is ever written back into `PublicDemoAggregate`." No `editSkillSheet`/similar method exists anywhere in `lib/game/public_demo/`. | N/A | N/A — depends on §6's design decision on *what* becomes editable | N/A | N/A | N/A | M–L (domain: new editable field(s) + persistence; UI: new edit form) | 3 |
| 3 | 技術者の営業を行う | **A** | Yes — "営業開始" button | `PublicDemoEngineerSales.stage == selling` (or beyond) | Stage reached `selling` | Yes | Monotonic stage — none | None (reachable April, June for new joins, July–Feb via RECOVERY-LOOP-1; **not reachable May/March** — `_fieldSalesActionReachableThisMonth`) — Mission copy must not promise a CTA in a month it will not appear | XS | 1 |
| 4 | 技術者を案件に提案する | **A** | Yes — "案件紹介" (`_introduceProject`) | `stage == introduced`, backed by a genuine `PublicDemoMatchingProposal` (`matchingProposalFor(engineerId) != null`) | Stage reached `introduced` AND a genuine proposal exists (do not trust stage alone — a proposal-less `introduced` should not happen in normal play per `_bestFitProjectIdFor`'s own doc, but the unforgeable check costs nothing) | Yes | Monotonic — none | None | XS | 1 |
| 5 | 上位会社面談を通過する | **A** | Yes — `_startPartnerInterview` | `stage == partnerInterviewPassed`, or (post-June, replacement path) `PublicDemoAssignment.replacementStage == partnerPassed` | Stage transition via `evaluateInterview`/`applyProjectInterviewResult` | Yes | Monotonic (re-attempts after a *fail* are a real, separate re-entry the domain already models — RECOVERY-LOOP-1 — do not double-reward each retry; key the mission off "ever reached `partnerInterviewPassed` at least once," not "currently in that stage," since a later stage supersedes it) | Interview-flow condition itself is **not random** — see §4 | XS | 1 |
| 6 | 客先面談を通過する | **A** | Yes — `_startClientInterview` | `stage == clientInterviewPassed`, backed by unforgeable `PublicDemoEngineerInterviewRecord` (`hasGenuineInterviewRecord`) — **this is the one place the domain itself already refuses to trust the bare stage**, so the Mission System must check the same record, not `stage` alone | Genuine interview record exists | Yes (`_hasConsistentAuthorityFacts` in the save codec already rejects an internally-inconsistent save at load time — see §10) | None (unforgeable record) | Same as #5 — see §4 | XS | 1 |
| 7 | 案件を受注する | **A** | Yes — `recordOrder`/`recordOfferCandidateOrder` | `stage == ordered` | Stage reached `ordered` | Yes | Monotonic | Ordered-but-not-yet-assigned is a real, distinct, one-month-wide intermediate state (参画予定) — do not conflate with Mission 8 | XS | 1 |
| 8 | 技術者を案件に参画させる | **A** | Yes — automatic at month-close via `assignOrderedForMay`/monthly close | `workflow.assignedEngineerIds(month:).contains(engineerId)` — **the single SSOT** every other system (Revenue, roster, HOME, SkillSheet) already agrees on (§1.4 of the Employee-Status-Unified-Display audit) | Engineer id present in `assignedEngineerIds` for the current month | Yes — this is the most heavily-guarded fact in the whole domain (WORKFLOW-STATE-1-FIX1 unforgeable-record chain culminates here) | None — membership check, naturally idempotent; **do not** key off "row exists in `assignments`" (a released assignment can leave an inert row before month 7 — use `assignedEngineerIds` membership only, exactly as the roster/HOME/Revenue already do) | Meaning of `assignedEngineerIds` itself changes by month (all rows through June; only `nextOrderStatus==accepted`/`replacementStage==ordered` from July) — this is already handled correctly by the one shared accessor; **the Mission System must call the same accessor with the current month, never a cached/stale month** | XS | 1 — **this is the April headline mission (§5)** |
| 9 | 技術者1名が研修を受講する | **B** | Yes — `selectInternalTraining`/`selectExternalTraining` exist and are real cash transactions | **Gap found**: `PublicDemoState.trainingSelections` is a **per-month, transient** map — `applyMonthlyGrowth` (month-close) explicitly resets it to `trainingSelections: const {}` after applying the growth for that month (`public_demo_state.dart:792`). **There is no persisted "this engineer has ever completed training" fact anywhere** — the selection is consumed and erased every month. A save loaded mid-month can see the *current* selection, but a mission checked after month close (the normal case) has nothing to read. | **None exists today** — needs a new field | N/A until added | N/A until added | The training-selection UI itself is only reachable May–March (`s.month >= 5`) — April has no training CTA at all; a Mission unlocked in April pointing at this action would be a dead end for one month | S (one new persisted counter/flag, e.g. `PublicDemoState.trainingCompletionCount` or a per-engineer flag threaded through `applyMonthlyGrowth`, before it clears the map) | 1 (data only) / 4 (UI) — see §10.2 |
| 10 | 未経験者を案件に参画させる | **A**, with one verify-before-ship caveat | Yes — `isInexperienced` (`PublicDemoApplicant.experienceMonths == 0`) is a **permanent** field on the applicant record, and `PublicDemoEngineerSales.fromApplicant(applicant).id == applicant.id` (`withJoinedEngineers`) means the original applicant id survives as the engineer id after joining | `workflow.applicants.any((a) => a.id == engineerId && a.isInexperienced)` **AND** `engineerId ∈ assignedEngineerIds(month)` | Both facts true simultaneously | Yes, **provided** `workflow.applicants` never drops a joined applicant's record — traced as true in every code path read this session (joined applicants are re-categorized for display, never removed from the list), but this audit did not exhaustively grep every mutation site of `applicants`; **implementation should add one focused unit test asserting this before relying on it**, rather than trusting the audit's trace alone | None (pure conjunction of two existing facts) | None beyond #8's own | S (verification + a pure derived-boolean helper; no new persisted field if the caveat holds) | 4 |
| 11 | 求人媒体で募集する | **A** | Yes — `purchaseRecruitmentMedium`/`recruit` | A `PublicDemoRecruitmentMedium` purchase transaction succeeded this game (cash was actually spent for `engineer` medium, or the `free` medium was used) | Transaction success result, not merely "button visible" | Yes if keyed off a persisted usage counter (`GameStats`-style — confirm main-game precedent, `recruitmentTradeoffExplained`'s own bug fix in §3.9 of `DEVELOPMENT_PLAN.md` is a direct cautionary tale: **do not** key a Mission off "current listings" the way that bug did, since weekly/monthly pruning silently un-satisfies a naive "is there an active listing" check — key off a monotonic *count of successful purchases*, not current listing presence) | None if counter-based | None | XS–S (confirm/add a monotonic purchase counter if one does not already exist in Public Demo — main game's `GameStats.recruitmentListingsPosted` is the cited precedent pattern, not a reusable field, since Public Demo does not share `GameStats`) | 4 |
| 12 | 応募者のSkillSheetを確認する | **A** | Yes — `PublicDemoCandidateSkillSheetSheet.show` | A UI-only "was this sheet opened for this applicant" fact — **no domain field records this today** (the sheet is `StatelessWidget`, read-only, no callback other than "close") | Needs a lightweight, presentation-layer "viewed" signal, same class as Mission 23 (§2.4) — **not** a domain mutation | Depends on where the "viewed" flag lives (§10.2 recommends: do **not** add a persisted field for a pure viewing act; treat as a session-scoped Mission System UI event that also completes retroactively via a stronger fact — see below) | If tracked at all, must not double-count re-opens | None | XS (treat "viewed" as satisfied retroactively by `resumeReviewed` — §13, this is the one place this audit recommends *widening* the completion condition rather than adding tracking: an applicant already reached `resumeReviewed` cannot have gotten there without the player having had the SkillSheet reachable, and 書類選考 itself is a stronger, already-tracked signal one step later) | 4 |
| 13 | 応募者を書類選考する | **A** | Yes — `reviewResume` | `applicant.stage` reached `resumeReviewed` (or beyond) | Stage transition | Yes | Monotonic | None | XS | 4 |
| 14 | 応募者の採用面談を行う | **A** | Yes — full interactive Q&A system (`RecruitmentInterviewEngine`/`PublicDemoRecruitmentInterview`, landed 2026-09-13, PR #264) | `applicant.hasBeenInterviewed` (unforgeable `PublicDemoInterviewRecord`) **or**, if "行う" is read as "completed the interactive session" rather than "paid for the paperwork step," `workflow.interviewSessions[...].completed == true` | Either fact, depending on Mission copy's intended granularity — recommend the stronger one (`session.completed`) since it is what the task's own SES-narrative goal ("面談") implies, not the sales-slot-paperwork step alone | Yes | Session-completion is a one-shot event per applicant; not naturally re-triggerable | None | XS | 4 |
| 15+16 | 採用候補者に給与条件を提示する／内定を出す | **A**, merged per §2.1 | Yes — `acceptOffer` | `applicant.stage == offerAccepted` (backed by `applicant.hasBindingOffer`) | Stage + binding offer present | Yes | Monotonic | None | XS | 4 |
| 17 | 応募者を採用する | **flag for removal**, per §2.2 | — | — | — | — | — | — | — | — |
| 18 | 内定者が入社前に営業を開始する | **A** | Yes — `preEntrySelling` pipeline | `applicant.stage == preEntrySelling` (or beyond in the pre-entry chain) | Stage transition | Yes | Monotonic | Pre-entry pipeline is only reachable for a non-`isInexperienced` (`canEnterPreJoinSales`) applicant who already has `offerAccepted` — Mission copy/unlock must gate on this, or it will appear as a dead-end for inexperienced hires (this is domain-correct behavior, not a bug — inexperienced hires intentionally skip pre-entry sales) | XS | 4 (sequence late — this is an advanced mechanic, see §2.5/§9) |
| 19 | 内定者が入社前に案件を受注する | **A** | Yes — `preEntryClientPassed`→`juneOrdered` | `applicant.stage == juneOrdered` | Stage transition | Yes | Monotonic | `juneOrdered` is permanent even after join — do not use `stage` alone once `hasJoined` may also be true; check `stage == juneOrdered` regardless of `hasJoined` for "was this mission ever completed," since the stage is never cleared by joining (confirmed, §1.6 of the Employee-Status-Unified-Display audit) | XS | 4 |
| 20 | 内定者が入社する | **A** | Yes — `PublicDemoJoinTransaction.join` | `applicant.hasJoined` (unforgeable `PublicDemoJoinRecord`) | Record present | Yes | None (unforgeable, one-shot) | Joins happen at the month-end boundary the applicant's binding offer targets — no special Mission-side handling needed, the record itself is the truth | XS | 4 |
| 21 | 新入社員を案件に参画させる | **A** | Yes — same authority as #8, post-join | Newly-joined engineer id present in `assignedEngineerIds(month)` | Same check as #8, scoped to an engineer whose `applicant.hasJoined` became true this playthrough (to distinguish "a *new* hire" from "any" participation, if the Mission's intent is specifically about a recruited hire rather than a founder) | Yes | Same as #8 | Same as #8 | XS | 4 |
| 22 | 売上を発生させる | **merged into #8**, per §2.3 | — | — | — | — | — | — | — | — |
| 23 | 入金を確認する | **B**, redefined per §2.4 | Partial — the underlying fact (`revenueReceived > 0` this month) is fully authoritative (`PublicDemoRevenuePaymentResult.revenueReceived`), but "confirm" as a player action does not exist | Needs a new, additive, UI-only "viewed monthly report / accounting tab after a month with `revenueReceived > 0`" signal | See above | If tracked, must be re-derivable or explicitly stored; recommend NOT persisting a new save field for this either (§10.2) — treat as auto-satisfied by "the player has closed at least one month whose `PublicDemoMonthlyReportSnapshot.revenueReceived > 0`," which needs no new persisted field beyond what Monthly Report Phase A/B already computes on demand | None | None | XS (derive from existing `PublicDemoMonthlyReportSnapshot`, no new field) | 1 |
| 24 | 賞与を支給する | **A** | Yes — `PublicDemoSummerBonusPlan`/`PublicDemoSummerBonusPayment` | A plan other than `none` was actually paid | Payment transaction result | Yes | Monotonic (July-only, one-shot per fiscal year) | July-only — Mission unlock must gate to July, or it will sit permanently "not yet available" for 11 months, which is confusing without an explanation | XS | 4 |

**Summary counts (of the 22 missions retained after §2's merges):** 18 Category A, 3 Category B (9, 12/23 treated as a UI-viewing-event class, 2 is separate/major), 1 Category C (Mission 2, SkillSheet editing). This is a substantially safer distribution than a naive reading of the original 24-item list would suggest — most of the apparent "B/C" risk in the original list was actually §2's naming/granularity mismatches, not missing domain features.

---

## 4. Interview-Flow Audit — Why the Mini-Game Sometimes Does/Doesn't Appear

Traced call path (`lib/ui/public_demo/public_demo_01_placeholder_screen.dart:1943-1969`, doc comments at `:1934-1961`):

```
_startPartnerInterview(i) / _startClientInterview(i)
  → if _game.projectInterviewCandidateFor(engineer.id) != null:
        opens PublicDemoProjectInterviewDialog   (interactive mini-game)
    else:
        falls back to ei(i, type)                (automatic evaluate+result dialog)
```

**This is authority-based, never random.** `projectInterviewCandidateFor` resolves whenever a genuine `PublicDemoMatchingProposal` exists for the engineer. Tracing backward: `_introduceProject` (Mission 4, 案件紹介) **always** attempts to create one via `_bestFitProjectIdFor`, which in turn always succeeds as long as `PublicDemoSeededProjectGenerator` offers any candidate for the current month — and per that generator's own contract, it "always offers a full slate from April on" (doc comment, `public_demo_01_placeholder_screen.dart:1270`). Consequently:

- **In normal play, the interactive mini-game is not a coin-flip — it is the default, expected outcome every time**, because 案件紹介 (Mission 4) always creates the proposal the interview step needs.
- The automatic/no-mini-game fallback exists **only** for edge cases the code's own comments describe as "should not happen in normal play": a legacy pre-Phase-6 save, or (in principle) a month with zero project candidates, which the generator's contract says cannot occur from April on.
- Both partner (Mission 5) and client (Mission 6) interviews follow the identical pattern (`_startPartnerInterview` mirrors `_startClientInterview` "one pipeline stage earlier," per its own doc comment) — this was completed by Issue #245 Phase B2, **after** the earlier Human Replay finding (2026-09-10 Post-Balance triage, §5 audited below) that specifically complained partner interview was "an automatic result rather than an interactive mini-game." **That finding is now stale** — as of the audited SHA, partner interview is interactive whenever a proposal exists, which is always in normal play.

**Recommendation for player-facing clarity (design, not implementation):** since the trigger is deterministic and always-on in practice, the Mission System / 案件 UI does **not** need to warn the player "this is random" (it is not). What it should do, per the task's own request, is make the **selection flow sequence itself visible before the player starts it** — 書類 → 上位会社面談 → 客先面談 → 受注 → 参画 — since the *sequence* is fixed even though *whether a mini-game opens* is not really in question. A short, static "選考の流れ" strip (reusing the existing `selectionStepLabels`/`PublicDemoSalesProgress` stepper component, which already exists and is already shown post-hoc) shown proactively — e.g., inside the SkillSheet sheet or the 案件紹介 confirmation — would resolve the comprehension gap the task describes without inventing new copy about randomness that would not be true.

---

## 5. April Main Mission — Specification

**Candidate confirmed correct: "技術者1名を案件に参画させる" (Mission 8).**

Rationale, cross-checked against the domain:

- It is the one mission in the table with the strongest, most heavily-guarded authority in the entire codebase (§3, row 8) — safe to gate a headline UI element on.
- It is reachable in April in normal play: a founding engineer (佐藤健, `readyForFieldSales=true` — 78 capability, per Opening Context/Issue #231's own audited fixture) can complete Missions 1→3→4→5→6→7 within April, with Mission 8 itself completing automatically at April's month-close (`closeApril` → `assignOrderedForMay`).
- It matches the Opening Context screen's existing copy verbatim ("まずは4月、社員の状況を確認しながら、案件への参画や営業を進めていきましょう") — no new narrative needs to be invented, only formalized into a trackable mission chain.

**Recommended April mission chain (sub-missions, all Category A, all already reachable in April):**

1. 技術者のSkillSheetを確認する (Mission 1)
2. 技術者の営業を行う (Mission 3)
3. 技術者を案件に提案する (Mission 4)
4. 上位会社面談を通過する (Mission 5)
5. 客先面談を通過する (Mission 6)
6. 案件を受注する (Mission 7)
7. **技術者を案件に参画させる (Mission 8) — headline/final, completes at April month-close**

This chain deliberately **does not** force SkillSheet-before-selling as a *new* gate — the existing hard gate (§1.1) already enforces the ordering; the Mission System should present this chain as narration/progress on top of the existing gate, not a second, competing gate. §2.3's finding (revenue is Mission 8's automatic consequence) should be folded into the completion narration for this final sub-mission, not a separate step.

---

## 6. Progressive (Conversational) Onboarding — Design

### 6.1 What exists today vs. what is asked

`PublicDemoOpeningContextScreen` (§1.1) already has a Hiyori portrait + greeting at the top, but the **body is one scrollable list of six fixed sections**, not a turn-by-turn "次へ" flow, and it front-loads information the task explicitly wants deferred (SkillSheet, sales, recruitment, deposits are not mentioned in the current copy, so this specific over-explaining complaint does not currently apply to the *Opening* screen itself — but it does apply to the general shape the task is worried about, and to future Mission unlocks if they are implemented as list dumps rather than one-at-a-time reveals).

### 6.2 Recommended redesign shape

Convert `PublicDemoOpeningContextScreen`'s existing six `_OpeningSection` widgets into a **paged/stepper flow** (a `PageView` or simple index-based "次へ" button cycling through the same six `_OpeningSection` content, unchanged in *wording*) ending in the same two CTAs it has today. This is a **presentation-only refactor of an existing, working screen** — no new copy needs to be written, no new domain read added; `startingCash`/`monthlyFixedCost`/`founders` continue to come from the same callers, unchanged. Recommended stopping point for the *initial* conversation, per the task's explicit instruction not to explain everything up front:

1. 会社設立 (existing intro + goal section, condensed)
2. 総務ひよりがサポートします (existing navigator intro, already present)
3. 4月の目標: 「技術者1名を案件に参画させよう」 (new framing — reuses §5's mission, no new fact)
4. → 4月の経営を始める

Cash/fixed-cost/risk detail (currently sections 2–4 of the existing list) should **not** be deleted — Issue #229's own audit (`docs/reports/SES_FIRST-FUN-YEAR_Opening-Context_P1_Result.md`) established these numbers matter for comprehension — but should move to being explained **at first relevance** (event-driven), matching `docs/DEVELOPMENT_PLAN.md`'s own Phase 3 design rule #1 ("Event-driven teaching over calendar-only teaching"), already proven out for the main game's Beginner Mode and directly reusable as a *pattern* (not code — Public Demo does not share `BeginnerModeEngine`, §1.1) for Public Demo's Mission System:

| Trigger | Explain | Existing authority to key off |
|---|---|---|
| Player opens 社員タブ for the first time (or Mission 1 unlocks) | Why SkillSheet matters (§6.3) | `stage == waiting` engineers present |
| Player reaches `resumeReviewed`/opens Recruitment for the first time (Mission 11–13 unlock) | 求人媒体/書類選考 flow | `applicants.isNotEmpty` |
| First month-close with `revenueReceived > 0` (Mission 23's own trigger, §2.4/§3) | 入金 vs 売上 distinction, reusing Monthly Report's existing wording | `PublicDemoMonthlyReportSnapshot` |
| July (Mission 24 unlock) | 賞与制度 | `s.month == 7` |

### 6.3 SkillSheet's "why" — closing the specific gap the task calls out

> SkillSheetは「チュートリアルで読まされるもの」ではなく、「参画させるために必要なので自分で確認するもの」にする。

Current SkillSheet gate copy (§1.1, §3 row 1) does not yet state *why* — it is a click gate with no explanatory text found at either SkillSheet call site (`public_demo_skill_sheet_sheet.dart` has no framing text beyond the existing "取引先へ提示する営業用プロフィールです。内容を確認してから営業開始へ進みます。" line, which explains *what* the sheet is but not *why the player specifically needs to check it*, e.g. to judge project fit). **Recommendation**: extend that existing subtitle line (already present, already correctly scoped — one line, not a popup) with one added clause connecting it to the player's actual next decision, e.g. "...営業を開始する前に、案件との相性を自分で判断するために確認しましょう。" — a one-line copy change, Category A/XS, not a new mechanic.

---

## 7. SkillSheet Audit

### 7.1 English labels actually shown to the player — full enumeration

Every SkillSheet-reachable label was traced to its source map. Findings, split by whether the label is Japanese, industry-standard English (kept as-is by convention even in Japanese business/SES contexts), or genuinely untranslated English:

| Source | Label set | Status |
|---|---|---|
| `languageLabels` (`lib/ui/widgets/labels.dart:6`) — programming languages | Java, C#, PHP, Python, JavaScript, TypeScript | **Keep as-is.** Programming language names are conventionally written in Latin script even in fully Japanese SES/IT business contexts (a real 履歴書/スキルシート in Japan writes "Java", not "ジャバ"). Not a defect. |
| `_techSkillDomainLabels` (`public_demo_skill_sheet_display_projection.dart:131-139`) and its **exact duplicate** `techDomainLabels` (`lib/ui/widgets/labels.dart:159-167`) — technical skill chip labels shown as e.g. "Frontend Lv.3" | `database → 'DB'`, `network → 'Network'`, `infrastructure → 'Infra'`, `frontend → 'Frontend'`, `backend → 'Backend'`, `leader → 'Leader'`, `manager → 'Manager'` | **Genuine defect — this is the finding the task's實機 complaint refers to.** Only `database → 'DB'` is a conventionally-kept abbreviation (like the programming languages above). The other six (`Network`, `Infra`, `Frontend`, `Backend`, `Leader`, `Manager`) are plain English words with no abbreviation convention, shown as literal English inside an otherwise fully-Japanese SkillSheet sentence/chip row (e.g. "Leader Lv.1" next to "経験 3 年"). |
| `_industryLabels` (`public_demo_skill_sheet_display_projection.dart:109-118`) | 金融/製造/物流/公共/通信/EC/医療/その他 | Fully Japanese except "EC" (conventional abbreviation for e-commerce, kept). No defect. |
| `_abilityLabels` (`public_demo_skill_sheet_display_projection.dart:120-129`) | 面談巧者/現場営業向き/成長が早い/etc. | Fully Japanese. No defect. |
| `PublicDemoInterviewProfile` rows (`案件スキル適合`/`ヒューマンスキル`/`モチベーション`/`取引先からの信頼`) | Fully Japanese | No defect. |
| Candidate (pre-hire) SkillSheet (`public_demo_candidate_skill_sheet_sheet.dart`) | 経験/希望給与, fully Japanese | No defect. |

**This `_techSkillDomainLabels`/`techDomainLabels` map is duplicated verbatim in two files** (`lib/ui/public_demo/public_demo_skill_sheet_display_projection.dart` and the shared `lib/ui/widgets/labels.dart`, the latter also used by the **main game's** Project/Fit screens, not just Public Demo). Fixing this is therefore **not Public-Demo-local** — `techDomainLabels` also drives `topRequiredSkillLabel` (project "主要求スキル" summaries) elsewhere in the main game. Any localization fix must update both maps (or de-duplicate them into one shared source, which would also close a latent-drift risk: today nothing keeps the two identical if only one is edited) and must be verified against main-game screens too, not just Public Demo's SkillSheet — this pushes the effort estimate from "one map edit" to "one shared map edit + a main-game regression check," but does **not** require any main-game domain change (both are pure label maps, not gameplay authority).

**UI-only localization is fully safe**: both maps are presentation-layer `const Map<..., String>` lookups with zero persistence and zero gameplay-affecting logic — changing the string values changes nothing about matching/fit/eligibility calculations, which read the underlying `TechDomain` enum values, never these display strings.

### 7.2 「実力」— authority and calculation basis

Confirmed, `public_demo_engineer_runtime.dart` (per the Employee-Status-Unified-Display Fresh Audit, §1.2, re-verified against the live enum this session): 「実力」is the player-facing term for `PublicDemoEngineerRuntime.actualCapability`, a **derived getter** = `languageSkills[primaryLanguage].actualSkill` — i.e., it is **not** a composite of multiple factors; it is a single number, the engineer's actual skill level in their one confirmed primary language. The two prior audits that examined this (`SES_FIRST-FUN-YEAR_Post-Balance_Human-Replay_Fresh-Triage.md` §3, and `SES_FIRST-FUN-YEAR_Initial-Employee-SkillSheet-Clarity_P1_Result.md` line 125) both independently concluded: the term is used **consistently**, always paired with the concrete threshold/current numbers (never shown bare), and is **not** duplicated elsewhere with a different meaning.

**On the task's suggestion to rename to 「技術力」**: since `actualCapability` is provably single-factor (primary-language skill only, not an aggregate of tech skills + experience + interview aptitude), a rename to 「技術力」 would be **more misleading, not less** — "技術力" implies a broader composite than what is actually measured. The 2026-09-10 Post-Balance audit's own conclusion ("Do not rename 実力 to 技術力 until the underlying capability formula is audited... a narrower label would be misleading") is **correct and reconfirmed by this session's independent trace** of `actualCapability`. **Recommendation: keep 「実力」, do not rename.** If the comprehension gap persists in future human replay, the fix is a **clarifying subtitle** ("主要言語の実務スキルレベル"), not a rename — a small, safe copy addition, not a terminology change that would need re-auditing every existing usage site.

### 7.3 SkillSheet editing — feasibility and design

**Confirmed not implemented** (§3 row 2). Design questions for the implementation phase, informed by what the domain already models:

1. **What should be editable?** The domain already distinguishes **actual capability** (`PublicDemoEngineerRuntime.actualSkill`/`actualExperienceMonths`, ground truth) from **displayed/sales-facing values** (`displayedExperienceMonths`, already rendered today as "実経験 X → スキルシート記載 Y" — §7.2's `_ExperienceSection`). This is precisely the "actual history vs. sales SkillSheet" distinction `docs/DEVELOPMENT_PLAN.md` §7.2 already calls for as a long-term direction, and Public Demo has **already built half of it** (the display-comparison UI exists; only the *edit* side is missing). The safest, most authority-consistent scope for "editing": let the player adjust **`displayedExperienceMonths`** (the sales-facing exaggeration/understatement) within some bound, leaving `actualExperienceMonths`/`actualCapability` (ground truth, feeds Fit/Matching) untouched — this reuses an already-existing field pair rather than inventing a new one.
2. **Should editing affect Fit/Trust/interview risk?** `docs/DEVELOPMENT_PLAN.md` §7.2 explicitly anticipates this ("Company Trust / interview risk reacts to the gap") as a **future** consequence, not a Phase 3 requirement — this audit recommends **not** wiring editing to Fit/Trust in the first implementation (Category C, large, cross-cutting — would touch Matching's `PublicDemoEngineerProjectFit.compute` and the interview evaluators, both currently pure functions of ground-truth fields only). Ship editing as a **display-only** feature first (edit what the client sees, no gameplay consequence yet), then treat "exaggeration risk" as an explicit, separately-scoped follow-up once a human replay confirms it is worth the added complexity — this matches the task's own Phase-splitting instruction (small, safe, reviewable increments).
3. **Persistence**: `displayedExperienceMonths` is already a per-language, per-engineer field inside `LanguageSkill` (part of `PublicDemoEngineerRuntime.languageSkills`), which is already fully serialized in the save codec — editing it in place needs **no new save-schema field**, only a new domain method (`PublicDemoAggregate.editSkillSheetDisplayedExperience(engineerId, language, months)`, bounded/validated) and a UI edit form. This keeps Mission 2 at **Category C but the smaller end of C** — a real new player-facing capability, but one reusing 100% existing schema.

---

## 8. Other Real-Machine Findings — Backlog Triage

| Finding | Traced cause | Phase-1-relevant or Visual/Data Polish? |
|---|---|---|
| 応募者を書類選考で不採用にしたい | **Confirmed real gap.** `PublicDemoWorkflowState.rejectApplicant`/`PublicDemoApplicantStage.rejected` already exist and are fully wired — but **only** from the post-interview `concludeInterviewSession(outcome: InterviewOutcome.rejected)` path (`public_demo_aggregate.dart:728-750`). There is no call site that rejects at `resumeReviewed` (書類選考) time, before a sales slot is spent on the interview. | **Phase-1-relevant** (small, reuses existing domain method — add one UI button calling the already-public `rejectApplicant` from the 書類選考 card; Category B, not C) |
| イベント画像が荒い | Confirmed: only 8 generic character images exist repo-wide (`assets/images/characters/`: `applicant_engineer`, `client_contact_person`, `engineer_junior/midlevel/veteran`, `recruiter`, `sales_female/male`) — event scenes reuse these generic crops, not purpose-built event art. Resolution/quality was not separately measured this session (binary assets, not read as text) — treat the report's "荒い" as a real complaint pending a visual re-export at higher resolution, not a code defect. | **Visual/Data Polish** (Phase 5) |
| 経営結果のひより画像が小さい | Layout-sizing issue in the Year-End/monthly-result card area (`PublicDemoYearEndResultCard`/monthly report), not an asset problem — the same portrait asset used elsewhere (Opening Context, HOME) is displayed larger there (64×64 minimum, §1's `_NavigatorIntro`). A sizing-parity fix, no new asset needed. | **Visual/Data Polish** (Phase 5) — small, but touches result-card layout, which is adjacent to HOME-Freeze-sensitive surfaces; verify which file owns the result card before scoping |
| 社員画像が性別/年齢とリンクしていない | **Structurally cannot be fixed without a domain change**: confirmed (re-verified this session, consistent with `docs/DEVELOPMENT_PLAN.md` §7.1 and the Employee-Roster-Management-Data Fresh Audit's own finding) that **age and gender do not exist anywhere in the current domain** — `prologue_engine.dart`'s own doc comment states the design is deliberately gender-blind. Linking portraits to demographics that do not exist is impossible today; the *only* available character images are role-based (junior/midlevel/veteran engineer), not identity-based. | **Not Phase 1.** This is Phase 7.1 of `docs/DEVELOPMENT_PLAN.md` (a deliberately deferred, larger product decision — see that doc's own "Gameplay principle" guardrails on not turning demographics into ability modifiers) — do not schedule this as Visual Polish; it requires a product-level decision before any implementation. |
| 社員一覧に人物画像が表示されない | Confirmed: `_employeeRosterCard` (the roster's own primary card, §Employee UI Phase 1) contains no `Image.asset`/portrait widget at all — the file's one portrait reference (`Image.asset` at line 1868) is for the interview-scene dialog only, not the roster. Wiring the existing 8 role-based images (junior/midlevel/veteran, keyed by e.g. capability tier) into the roster card is feasible **today**, without waiting on age/gender — but would be a **generic role icon, not an individual portrait**, and should be labeled as such in any design doc so it is not mistaken for solving the row above. | **Visual/Data Polish** (Phase 5) — genuinely small (existing assets, existing card), but explicitly decouple from the age/gender item above |
| 営業候補者カードが縦に大きい | Not independently re-measured pixel-by-pixel this session (would need a rendered screenshot, out of scope for a read-only code audit) — flagged for the implementation phase to verify against the existing 360×800/390×844 test fixtures already covering this card family (`public_demo_employee_roster_phase_b1_test.dart` and siblings) before committing to a specific fix. | **Visual/Data Polish** (Phase 5) |

**New asset requirements (not placeholders — per the task's explicit instruction):**

- If Employee Visual Complete work eventually pursues gender/age-linked portraits (post product decision, out of this Fresh Audit's scope): a portrait set needs, at minimum, distinct crops per (role tier × a to-be-decided demographic axis), sized consistently with the existing `assets/images/characters/` crops (traced dimensions were not read this session — binary — verify against the existing files' actual pixel dimensions before commissioning new art, so new assets match).
- For the roster-portrait item (role-based, no product decision needed): **no new assets required** — the existing 8 role-based crops are sufficient; this is a wiring task, not an asset-creation task.
- For "イベント画像が荒い": a higher-resolution re-export of the existing event scene crops (same subjects/compositions, higher source resolution) — not new subjects, so no new art direction is needed, only a re-export/re-crop pass.

---

## 9. Navigation — 6-Tab vs. Alternatives

Current state (confirmed, `public_demo_01_placeholder_screen.dart:6513-6556`): `NavigationBar` with exactly 5 `NavigationDestination`s — ホーム / 社員 / 営業 / 会計 / メニュー, Material 3 `NavigationBar` (not the older `BottomNavigationBar`), each with an outline/filled icon pair.

| Option | Assessment at 390px |
|---|---|
| **A. Bottom Navigation 6タブ化** | Material 3 `NavigationBar` computes each destination's width as `available / count`; going from 5→6 shrinks each tab from 78px to 65px at 390px width. Each destination already carries a 2-character label ("ホーム"/"社員"/"営業"/"会計"/"メニュー") plus icon — a 6th ("ミッション", 5 characters) would either wrap or force label truncation, and 65px is close to (but not clearly under) Material's ~48dp minimum tap-target guidance once padding is subtracted. **Risk, not a hard blocker**, but the file's own existing test suite (`public_demo_01_persistence_test.dart` and the 360×800/390×844×TextScaler fixtures used throughout) would all need re-verification at 6 tabs, and HOME Freeze policy (§1.4) makes any bottom-nav change a cross-cutting, high-scrutiny change even though the `NavigationBar` widget itself lives in the Scaffold, not "inside" HOME's content area — worth flagging as ambiguous under a strict reading of Freeze. |
| **B. HOME内Mission入口** | Contradicts HOME Freeze directly — "HOMEの追加レイアウト変更は禁止" (§1.4) is unambiguous about adding a new card/section to HOME's own content. **Not recommended while Freeze holds.** |
| **C. メニュー内Mission入口** | Zero navigation-shape risk (メニュー tab already exists, already a list-of-entries screen per its own Visual Complete work in the SSOT history) but **buries the single most important beginner on-ramp inside the tab explicitly reserved for lowest-priority/settings-like content** ("開発・テストメニュー" lives here today) — contradicts the task's own framing that Missions are meant to be the primary initial-comprehension driver, not an auxiliary feature. |
| **D. HOMEのMission card + 専用Mission screen** | The task's own phrasing anticipates this option, but as written it still requires *some* HOME-side card, which is the same Freeze conflict as B for the "card" half. |
| **E variant (recommended): a dedicated Mission screen reachable via a HOME-independent, non-bottom-nav entry point** — specifically, an icon added to the existing `AppBar.actions` row (next to the existing 🔔 notifications icon, `public_demo_01_placeholder_screen.dart:6504-6511`), opening a full Mission screen via `Navigator.push` (not a tab, not a HOME card) | **Zero HOME Freeze conflict** (the `AppBar` is Scaffold-level chrome, same category as the existing bottom nav, not "HOME's content"), **zero 6-tab-width risk** (no new bottom-nav destination), and **discoverable from launch** (an `AppBar` icon is visible on every tab, not buried in メニュー). A small unread-mission-count badge on the icon (reusing the existing notification-badge pattern already established for 🔔, if one exists — not independently confirmed this session, verify at implementation time) would give it the same at-a-glance visibility Option A was trying to achieve, without any of A's width/Freeze risk. |

**Recommendation: Option E (AppBar entry point + dedicated Mission screen), not a 6th bottom-nav tab.** This is the one navigation design in the comparison that is simultaneously (a) fully compliant with the current HOME Freeze policy, (b) zero-risk to the existing 5-tab width/test-fixture contract, and (c) still gives Missions first-class, always-visible discoverability — which the task's own framing ("Missionが初心者の主要導線になることを踏まえ") requires. If a future HOME Freeze lift makes Option D's HOME card viable, it can be added **later** as a pure addition (a card linking to the same Mission screen) without needing to re-litigate the screen itself.

---

## 10. Save Compatibility Design

### 10.1 The existing migration convention (must be followed, not reinvented)

`PublicDemoSaveCodec` (`lib/game/persistence/public_demo_save_codec.dart`) has a static `schemaVersion = 1` that has **never been bumped** despite many additive fields landing since (`offerCandidates`, `qaEvaluationApplies`, etc. — all confirmed via the SSOT Update History, §2026-09-12/09-13 entries). The established, repeatedly-used pattern: **`schemaVersion` gates whole-envelope compatibility (a hard reject); every individual additive field gets its own per-field splice/migration inside `fromJson`, with a safe default for a save written before that field existed.** (Precedent: `_withMigratedOfferCandidates` for `offerCandidates`; `qaEvaluationApplies` defaulting to `false` for any pre-existing save, §2026-09-13 SSOT entry, reproduced in `public_demo_recruitment.dart:305-308` read this session.)

**The Mission System must follow this exact convention**: whatever new fields it needs (§10.2) are additive, `schemaVersion` stays `1`, each new field gets a safe default matching "this save predates the field," and the codec's own round-trip/consistency check (`_hasConsistentAuthorityFacts`) — which already rejects internally-inconsistent saves wholesale at load time rather than letting malformed per-field state reach the UI (§12 of the Employee-Status-Unified-Display audit) — becomes the safety net for any Mission-tracking field the implementation adds, exactly as it already is for every other additive field.

### 10.2 Prefer derived-from-existing-authority over new persisted fields — and where that is/isn't possible

Per §3's table, **18 of 22 retained missions need zero new persisted state** — their completion is a pure function of state the codec already serializes (stage enums, unforgeable records, `assignedEngineerIds`). This is the strongly preferred design, per the task's own instruction, and this audit confirms it is achievable for the large majority of missions.

The exceptions, and their specific save-compat handling:

- **Mission 9 (研修受講)** — genuinely needs a **new, small, additive field** (§3 row 9: a persisted counter or per-engineer flag, since `trainingSelections` is deliberately transient). Design: add it at the point `applyMonthlyGrowth` currently clears `trainingSelections` — increment/set the new field **before** clearing, so the persisted fact survives the same month-close boundary that erases the transient one. **Legacy save**: defaults to `0`/empty — a legacy save mid-playthrough will read as "never trained," which is truthful (there is genuinely no way to know whether an old save's engineer was ever trained, since the old code never recorded it) — this is the correct, honest default, not a data-loss bug.
- **Mission 23 (入金確認) / Mission 12 (応募者SkillSheet確認)** — per §2.4/§3, recommend **not** adding a persisted field at all; both are satisfiable by widening the completion check to an already-tracked, stronger downstream fact (§3's own recommendation: Mission 23 via "closed at least one month with `revenueReceived > 0`," derivable on demand from existing `PublicDemoMonthlyReportSnapshot`/`PublicDemoMonthlyCashFlow` history rather than a new boolean; Mission 12 via "reached `resumeReviewed`," which cannot happen without the SkillSheet having been reachable first). This avoids new schema entirely for these two.
- **Mission 2 (SkillSheet編集)** — per §7.3, the recommended scope (editing `displayedExperienceMonths`) uses an **already-serialized** field; no new schema.

### 10.3 Overall Mission-progress persistence shape

Even though individual mission *completion* is derived (§10.2), the Mission System likely still wants to persist **presentation state** — which missions the player has already been shown/acknowledged, so a completed-but-unread mission doesn't re-announce itself every session. Recommend a **single new, additive, purely-presentational map** (e.g. `PublicDemoState.missionAcknowledgements: Map<String, bool>` or a `Set<String>` of acknowledged mission ids), following the exact same additive-field convention as `trainingSelections`/`offerCandidates` before it. This field:

- **Never gates eligibility** — it only suppresses a repeat notification; the underlying derived-completion check (§3) remains the sole authority for "is this mission actually done."
- **Defaults to empty** for any legacy save — every mission the game can already prove was completed (via §3's derived checks) will correctly show as "done, not yet acknowledged" on first load of an old save, which is the intended, honest behavior for **retroactive detection** (§10.5) rather than a bug.
- **Duplicate-reward risk**: none, since nothing described here grants cash/items — Missions are informational/narrative only per the task's own framing (this audit found no request for Missions to grant rewards, and recommends against adding any without an explicit product decision, to avoid opening a new save-integrity attack surface the domain has spent significant effort closing elsewhere, §1.2).

### 10.4 Interaction with `PublicDemoOpeningMarker`

The existing Opening Context "seen" flag is `SharedPreferences`-backed, **explicitly outside save schema** (§1.1, by design — "existing ~80 widget tests and Playwright suite" compatibility). If the redesigned conversational Opening Context (§6.2) needs its own step-position state (e.g., "player is on page 3 of 4"), follow this same precedent — **do not** put transient UI navigation state into the save schema; `SharedPreferences` (or in-memory-only, reset on screen re-entry) is the correct tier for it, consistent with how the existing screen already handles its own one-shot "seen" flag.

### 10.5 Retroactive detection — explicit design statement

Because §3's completion checks are (almost entirely) derived from durable, already-persisted domain facts rather than "the player clicked a Mission-System-aware button," **a save from before the Mission System existed will correctly show already-completed missions as complete the moment it is loaded into a Mission-System-aware build** — this is the single biggest save-compatibility win of the derived-authority design and should be explicitly tested (§14's acceptance criteria) rather than assumed.

### 10.6 Duplicate-reward / re-entry / month-transition — consolidated statement

Every Category-A mission in §3 is keyed off either a **monotonic stage enum** (never regresses except through a real, separately-modeled re-entry like RECOVERY-LOOP-1 or `endAssignment`) or an **unforgeable one-shot record** — both patterns are naturally idempotent and immune to duplicate-reward risk **as long as the Mission System does not itself add a reward** (§10.3's recommendation against rewards removes this risk class entirely for v1). Month-transition risk is fully enumerated per-row in §3's own "Month-transition risk" column; the one cross-cutting rule to encode once, centrally, rather than per-mission: **any mission check reading `assignedEngineerIds` must always pass the aggregate's *current* month, never a value captured earlier in the same render pass** — this is the exact discipline the existing `_currentUnitPriceDisplayFor`/roster code already follows (§1.4 of the Employee-Status-Unified-Display audit), and the Mission resolver should be built as a sibling to, not a fork of, that existing pattern.

---

## 11. Risks

1. **`public_demo_01_placeholder_screen.dart` is 6,721 lines and is the call site for every single mission's trigger point.** Every Phase-1 change touches this file. Recommend the Mission resolver/state itself live in a **new, separate file** (mirroring `PublicDemoEmployeeStatusResolver`'s own precedent — a pure function file next to, not inside, the placeholder screen), with the placeholder screen changed only at the minimal set of call sites needed to invoke it — this is the same discipline the Employee-Status-Unified-Display audit already recommended and is a proven, low-risk pattern in this codebase.
2. **HOME Freeze ambiguity for the AppBar entry point (§9).** This audit's reading is that the `AppBar` is Scaffold-level chrome, not "HOME," and therefore outside Freeze — but this is an interpretation, not a policy the SSOT states explicitly for the `AppBar` specifically (it is explicit about bottom-nav-adjacent HOME *content*). Recommend confirming this reading with whoever owns HOME Freeze policy before Phase 1 lands, exactly as the Employee-Status-Unified-Display audit flagged its own HOME-Freeze ambiguity as a P1 blocker rather than guessing (§18 of that audit).
3. **Mission 9's new persisted field is the one place this design is not purely derived** — get its shape right in Phase 1 (or explicitly stage it into a later phase, §12) since every save written before it exists is permanently "never trained," which is correct but should be a **conscious, documented** decision, not a surprise found during a later save-compat review.
4. **§7.1's label-map duplication is shared with the main game.** A SkillSheet-localization PR that edits only `public_demo_skill_sheet_display_projection.dart`'s copy and misses `lib/ui/widgets/labels.dart` (or vice versa) will re-introduce drift between Public Demo and the main game's own Project/Fit screens. Any Phase 3 (§7.3-adjacent) work must touch both, and ideally de-duplicates them into one source rather than editing two copies again.
5. **Mission copy for Missions 18/19 (pre-entry sales) risks confusing a beginner if sequenced too early** — this is a genuinely advanced, non-obvious SES mechanic (§2.5); §12/§13 sequence it into a later phase deliberately, not April.
6. **No existing reward/economy interaction was found for Missions** — this audit explicitly recommends keeping it that way (§10.3) to avoid reopening the save-integrity attack surface the domain has spent significant engineering effort closing; a future product decision to add mission rewards should be treated as its own, separately-reviewed change, not folded into Phase 1–5.

---

## 12. Phase Split, Dependencies, and Time Estimates

Per the task's own instruction, sized to 2–3h Claude Code batches; the candidate 5-phase split from the task prompt was checked against this audit's findings and is **retained with one addition (Phase 1b) and minor scope shifts** based on what §2/§3 actually found:

| Phase | Scope | Depends on | Est. (Claude Code) |
|---|---|---|---|
| **1** | Mission System foundation: new resolver file (pure functions, §3's Category-A checks for the April chain only, §5), new Mission screen (empty/basic layout), AppBar entry point (§9 Option E), April main mission chain wired end-to-end, Missions 22/23 folded per §2.3/§2.4 (no new persistence) | None (foundation) | 2.5–3h |
| **1b** *(new, recommended split of the original Phase 1 given §3's findings)* | Mission 9's new persisted field + save-codec splice + migration test (§10.2, the one non-derived April/early mechanic — training is reachable from May, so this can trail Phase 1 slightly without leaving April incomplete) | Phase 1 (reuses the same resolver shape) | 1.5–2h |
| **2** | Progressive onboarding: convert `PublicDemoOpeningContextScreen` to the paged flow (§6.2), event-driven explanation triggers table (§6.2's table) | Phase 1 (reuses Mission unlock signals as triggers) | 2–2.5h |
| **3** | SkillSheet comprehension + editing: §7.1's label-map fix (both files, §11 risk 4), §6.3's SkillSheet-gate copy addition, §7.3's editing feature (`displayedExperienceMonths`, display-only scope) | None strictly, but logically follows Phase 2's onboarding-copy pass | 3h (label fix + copy: 1h; editing feature: 2h — consider splitting further if a single session runs long, per the task's own 2–3h guidance) |
| **4** | Recruitment missions (11–21 minus the merges/removal from §2): wires Missions 11–14, 15+16(merged), 18–21 into the Mission screen; includes §8's "書類選考不採用" button (small, reuses `rejectApplicant`) since it shares the same recruitment-card surface | Phase 1 (resolver pattern) | 2.5–3h |
| **5** | Visual/Data Polish: §8's roster-portrait wiring (existing assets), Hiyori result-image sizing, sales-candidate-card height re-measurement, event-image re-export coordination (asset work, not code) | None | 2–2.5h, **excluding** external asset re-export lead time and excluding the age/gender item (explicitly out of scope, §8) |

**Dependency graph**: 1 → 1b (parallel-safe after 1's resolver lands) → 2 → 3 → 4 → 5, with 4 and 5 reorderable relative to each other (5 has no functional dependency on 4). 1 is the only hard blocker for everything else.

---

## 13. Recommended First Implementation Batch (hand-off summary — full spec in the companion Implementation Plan)

**Phase 1 exactly as scoped above**: new pure-function Mission resolver file (April chain only: Missions 1, 3, 4, 5, 6, 7, 8 per §3/§5, with 22 folded into 8's narration per §2.3), a new minimal Mission screen, an `AppBar` entry point (§9 Option E), and the §2.3 revenue-narration addition to Mission 8's completion copy. Explicitly **excludes** Mission 9's new field (→ Phase 1b), the onboarding screen redesign (→ Phase 2), and every recruitment/accounting/visual mission (→ Phase 4/5). This keeps Phase 1 to the **18 fully-derived, zero-schema-change Category-A April missions**, which is the safest possible first slice: no save migration to design, no new domain method beyond what already exists, and a single new file plus minimal `AppBar`/screen wiring as the only touch to the 6,721-line placeholder screen.

---

## 14. Acceptance Criteria

1. A fresh April playthrough completing Missions 1→3→4→5→6→7→8 (§5's chain) shows each step's Mission-screen status flip to complete **without any new save field being written** (verify via a save-diff before/after each step against a pre-Phase-1 save format).
2. Loading a **pre-Mission-System save** that already has an engineer at `stage == ordered` and `assignedEngineerIds` membership immediately shows Mission 8 (and its prerequisite chain) as already complete on first load — no re-play required (§10.5).
3. Reloading mid-chain (e.g., after Mission 5 but before Mission 6) preserves exactly that completion state — no missions regress, none are prematurely marked complete.
4. No Mission completion check ever reads a captured/stale `month` value (§10.6) — verified by a test that advances the month between two mission-relevant actions and confirms the resolver output updates.
5. The AppBar Mission entry point is reachable and renders correctly at 360×800 and 390×844, TextScaler 1.0 and 1.3 (matching every other Public Demo screen's existing test convention).
6. `flutter analyze` clean, full `test/game/public_demo` + `test/ui/public_demo` suites green, plus new focused tests for the resolver (one per Mission-1 mission, boundary cases per §3's "duplicate-reward risk"/"month-transition risk" columns) and for save/reload (criteria 2–3 above).
7. HOME's own files (`_officeStageStatusFor` and everything else HOME-owned) have **zero diff** — Phase 1 must not touch HOME under any reading of Freeze, since §9's Option E was specifically chosen to make this possible.

---

## 15. FINAL VERDICT

**GO.** The Mission System is implementable as a phased, low-risk, additive feature on top of Public Demo's existing (unusually well-hardened) domain authority. The task's own 24-item mission list needed correction, not wholesale redesign: three pairs/items (15+16, 17, 22) collapse into existing single actions or should be dropped/redefined (§2), and only one mission (SkillSheet editing, #2) is a genuine new feature requiring new domain surface — every other retained mission (18 of 22) needs **zero new persisted state**, which is the best-case outcome for the save-compatibility requirement the task calls "非常に重要." The interview-flow "sometimes random" concern (§4) turned out to be a stale finding from an earlier build — the current mini-game trigger is deterministic and effectively always-on in normal play, which simplifies rather than complicates the Mission/selection-flow UI design. The one policy question this audit could not resolve unilaterally is whether the recommended `AppBar`-based navigation entry point (§9) is compliant with HOME Freeze under a strict reading — this should be confirmed before Phase 1 begins, exactly as flagged in §11 risk 2 and §16 of the companion Implementation Plan.

---

## Appendix: Files Read (this session)

`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` (full, both halves), `docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md` (full), `docs/DEVELOPMENT_PLAN.md` (full), `docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Fresh-Audit.md` (full), `docs/reports/SES_FIRST-FUN-YEAR_Post-Balance_Human-Replay_Fresh-Triage.md` (partial, targeted); `lib/game/public_demo/public_demo_sales.dart`, `public_demo_recruitment.dart` (full), `public_demo_recruitment_medium.dart` (full), `public_demo_revenue.dart` (full), `public_demo_revenue_payment.dart` (full), `public_demo_internal_training_transaction.dart` (full), `public_demo_summer_bonus_plan.dart` (partial), `public_demo_state.dart` (targeted: training selections, growth), `public_demo_aggregate.dart` (targeted: interview session commands, offer/accept, reject), `public_demo_workflow_state.dart` (targeted: withJoinedEngineers, reviewResume, rejectApplicant); `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (targeted, ~600 lines across multiple sections: nav bar, interview entry points, applicant labels/grouping, project introduction); `public_demo_opening_context_screen.dart` (full), `public_demo_skill_sheet_sections.dart` (full), `public_demo_skill_sheet_display_projection.dart` (full), `public_demo_candidate_skill_sheet_display_projection.dart` (full), `public_demo_candidate_skill_sheet_sheet.dart` (full); `lib/ui/widgets/labels.dart` (full); `lib/game/persistence/public_demo_save_codec.dart` (targeted: schemaVersion); `pubspec.yaml` (assets section); repo file listings (`git ls-tree`) for `lib/`, `docs/`, `assets/images/characters/`, `test/game/public_demo/`, `test/ui/public_demo/`.
