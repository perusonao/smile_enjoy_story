# SES FIRST-FUN-YEAR Human Replay UX Findings — Fresh Audit

**Issue:** #245
**Type:** READ-ONLY Fresh Audit + design (no production implementation in this pass)
**Audited explicit main SHA:** `0ba21f2021c0963d8acfad28c2c99de096b776a9` (matches Issue #245's own "Issue作成時 explicit main" — no drift between `git fetch origin` and Issue creation)
**Branch:** `claude/issue-245-fresh-audit-3600u9` (created from `origin/main` at the SHA above)

## 0. Method

- `git fetch origin` performed first; `origin/main` used explicitly (not repository `default_branch`).
- Issue #245 body read in full as SSOT for all 13 findings.
- Issues #148, #205, #219, #225, #239 read in full for overlap/authority reuse.
- Every finding below is graded by evidence strength:
  - **Code-verified** — traced to specific authority classes/files/lines on the audited SHA, behavior confirmed by reading the actual logic (not just naming).
  - **Authority-inspected** — the relevant data/model exists and was located, but the exact UI rendering path was not read line-by-line; safe to act on, worth a quick re-confirm at implementation time.
- No production code was changed. No new score/state was introduced. No hidden parameter is disclosed anywhere in this report.

---

## 1. Finding #9 first — state integrity re-check (as Issue #245 requires)

**Hypothesis under test:** "面談モーダルを閉じる (dismiss/back/outside-tap) だけで面談済stateへ遷移していないか。"

### 1a. Phase 6 Project Interview dialog (`客先面談` when a real Matching proposal exists)

File: `lib/ui/public_demo/public_demo_project_interview_dialog.dart`
Authority: `PublicDemoProjectInterview` / `PublicDemoWorkflowState.startProjectInterviewSession` / `.concludeProjectInterview` (`lib/game/public_demo/public_demo_project_interview.dart`, `public_demo_workflow_state.dart:1396-1571`)

- `initState()` commits `startProjectInterview` — this only **creates/resumes a session** (`projectInterviewSessions`), it never sets `stage` to a passed/failed value.
- The close (X) button and the system back gesture both resolve to a bare `Navigator.of(context).pop()` (`public_demo_project_interview_dialog.dart:139`, `:150`) — **no state commit is attached to closing**, in either path.
- The only call that produces a pass/fail outcome is `_conclude()` → `concludeProjectInterview`, and `concludeProjectInterview` is a **hard no-op** unless: the engineer is at `partnerInterviewPassed`, a genuine session exists for the exact `project.id` and exact `currentMonth`, and — critically — `PublicDemoProjectInterview.isReadyToConclude(session)`, i.e. `session.playerFollowUps.length >= session.questions.length` (`public_demo_workflow_state.dart:1519-1571`). Every question must have received a player-chosen follow-up before this can ever fire.
- Reopening after a partial close resumes the same session (keyed by `employeeId` + `projectId` + `startedWeek`; a stale mismatched session is discarded, never silently concluded — `public_demo_workflow_state.dart:1406-1464`).

**Verdict for 1a: NOT REPRODUCIBLE.** Dismissing this dialog by any route (X, back, barrier) at any point before all follow-ups are answered leaves the engineer's `stage` unchanged and the session resumable. This is intentionally documented in the file's own header comment ("closing and reopening this dialog resumes exactly where the player left off").

### 1b. Recruitment Interview dialog (入社面談)

File: `lib/ui/public_demo/public_demo_recruitment_interview_dialog.dart`
Authority: `PublicDemoAggregate.startInterviewSession` / `.concludeInterviewSession`

- Same shape: `initState` only starts/resumes a session; the outcome (`concludeInterviewSession`) is committed **only** from the explicit `_DecisionBar` buttons ("採用候補として進める" / "見送る") at `_decide()` (`recruitment_interview_dialog.dart:88-101`), never from the close button (`:132`, tooltip literally reads "中断して閉じる" — "interrupt and close").

**Verdict for 1b: NOT REPRODUCIBLE**, same guarantee as 1a.

### 1c. The actual state-integrity-adjacent issue: the pre-Phase-6 `ei()` path

File: `lib/ui/public_demo/public_demo_01_placeholder_screen.dart:1633-1669` (`ei()`), wired from:
- `上位会社面談` button — **always** this path (`:3704`, `stage == introduced`) — Partner Interview has no interactive dialog at all in current production.
- `客先面談` — this path only as a *fallback* when the engineer has no real Phase 5 Matching proposal (`_startClientInterview`, `:1680-1687`); otherwise it routes into 1a.

`ei()`'s actual sequence is:

```dart
_commitAggregate(_game.recordEngineerInterviewResult(engineerId: e.id, type: t));  // ① state committed HERE
...
await showDialog<void>(...)   // ② modal shown only AFTER commit
```

**The state transition happens at button-press time, before the result dialog is even built.** The dialog (`PublicDemoInterviewResultDialog`) is a pure announcement screen (title/points/next action + a "確認" button that just pops) with **no decision to make and no undo** — closing it by any route changes nothing further, because there is nothing left to change.

**Verdict for 1c:** Issue #245's literal hypothesis ("closing the modal commits the result") does not reproduce for this path either — but the underlying player-facing symptom it is almost certainly describing does exist, just one step earlier: **一回のボタンタップで「面談を開始する」も「面談の結果を確定する」も同時に起きている**, with zero interactive content in between. A player who taps "上位会社面談" expecting to *open* something (per Finding #3's own framing — "面談ミニゲーム") is, in current production, already committed to a pass/fail outcome before any modal appears; the modal is easy to perceive as "the interview," and closing it is the last thing the player does before noticing 面談済 — which is consistent with how a player would describe this as "closing = 面談済."

**Conclusion:** No literal dismiss-writes-state bug exists (both interactive dialogs are correctly gated; recommend keeping this guarantee explicit in any future PR's regression matrix). But **Finding #9 and Finding #3 are the same root cause**: 上位会社面談 (and 客先面談 without a Matching proposal) has no mini-game at all — it is an instant, non-interactive, irreversible single-tap resolution disguised as a modal-driven interview. This should be tracked as one state-integrity/comprehension item, not closed as "not a bug."

---

## 2. All 13 findings

| # | Human Replay symptom | Current production behavior (evidence) | Authority | Related Issue/PR | Severity | Presentation-only? | Schema/domain impact | Recommended UX | Size |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 初期社員とSkillSheetを見る動機が弱い | **Code-verified.** `PublicDemoOpeningContextScreen` (`lib/ui/public_demo/public_demo_opening_context_screen.dart:58-101`) already covers 目的/初期資金/固定費/注意/最初にすることだが、**初期社員そのものへの言及が一切ない** — who they are, why they're there, how the two differ is not shown anywhere before April starts. | `PublicDemoWorkflowState.initial()` (founding roster), `PublicDemoOpeningContextScreen` | New (no direct existing Issue); adjacent to #148's "常時表示は短くし" principle | P1 | Yes | None — founding engineer names/roles already exist in `PublicDemoWorkflowState.initial()`; only new copy/section needed | Add one more `_OpeningSection` (or a short founding-roster card) naming the 2 founders and their one differentiator (例: すぐ営業可能 / 研修が必要), with a CTA into SkillSheet | S |
| 2 | 「営業開始」の結果が分かりにくい | **Code-verified.** `_beginSelling` (`:1126-1127`) is a bare `_commitAggregate(_game.beginSelling(engineerId))` — **no dialog, no snackbar, nothing renders.** `_introduceProject` (`:1164-1176`) — which now genuinely resolves a real Phase 4 project since the #219 fix — **also** just calls `_commitAggregate`, no modal. Only the stage badge text changes. | `PublicDemoAggregate.beginSelling` / `.introduceProject`, `PublicDemoSeededProjectGenerator` | #219 (already made 案件紹介 resolve a *real* project — the data is genuine, just not surfaced) | P1 | Yes | None — real project data already resolves at `introduceProject` time post-#219 | Add a lightweight `案件紹介` result card/modal (reuse `PublicDemoEventDialog` shape) showing the real candidate's name/client/rate the moment 案件紹介 fires | S–M |
| 3 | 上位会社面談ミニゲーム/面談の意味・成功理由が分からない | **Code-verified.** 上位会社面談 has **no interactive content ever** — `ei()` computes+commits `PublicDemoInterviewEvaluator.evaluate` synchronously off existing hidden `interviewProfile`, then shows a result-only dialog with a raw `$score点` (`public_demo_interview_result_dialog.dart:67-72`) against a bare "基準点60点" line. 客先面談 *does* have a genuine interactive mini-game (Phase 6, `PublicDemoProjectInterviewDialog`) — but only when a Matching proposal exists first. Two different fidelity levels are both labeled "面談." | `PublicDemoInterviewEvaluator` (legacy), `ClientInterviewEngine`/`PublicDemoProjectInterview` (Phase 6) | #219 (client-interview reachability, largely fixed), #148 (面談選択肢の意味) | P1 | Partially — labeling/explanation is presentation-only; giving Partner Interview real interactivity is not | Legacy `ei()` reuses `PublicDemoInterviewEvaluator`, a different formula from `ClientInterviewEngine`/`MatchingEngine` — no schema change to relabel, but building a real Partner Interview mini-game means either reusing `ClientInterviewEngine` for it too or a new small engine | Short term: stop showing the raw `score`/`基準点60点` line (HIDDEN-PARAMS-1-style — this is the same "never surface a raw rate" rule Phase 6 already documents for itself); explain pass/fail via qualitative reasons like Phase 6's `failureReasons`. Medium term: give 上位会社面談 the same interactive shape as Phase 6 (reuse `ClientInterviewEngine`, not a new formula) | S (relabel) / M–L (real mini-game) |
| 4 | 並行営業で複数案件を面談・比較し受注/辞退したい | **Code-verified.** `matchingProposalFor` returns the *first* match by `engineerId` (`public_demo_workflow_state.dart:1331-1334`); `startProjectInterviewSession` explicitly replaces (never keeps two) sessions for the same `employeeId` (`:1446-1464`). **One engineer can hold at most one active proposal/session at a time** — the schema has no concept of "N pending offers, compare, pick one." | `PublicDemoMatchingProposal`, `PublicDemoWorkflowState.projectInterviewSessions`, `PublicDemoEngineerSales.stage` (single-value) | None existing — genuinely new scope; Issue #245 itself already flags this as a "Separate design candidate" | P2 (real gameplay depth, not blocking First Fun Year completion) | No | **Yes — real schema change.** Needs an `engineerId → List<Proposal/Session>` shape, a "compare offers" UI, and an explicit accept-one/decline-rest command; interacts with `salesRemaining`/`salesCapacity`, `ordered` uniqueness, and assignment materialization | Multi-project holding state + comparison screen + accept/decline-rest command, new tests across save/reload and month-boundary | L — own Phase, not foldable into presentation work |
| 5 | 案件受注モーダルに画像がない | **Code-verified — ALREADY FIXED on current main.** `_recordEngineerOrder`/`_recordApplicantJuneOrder` (`:1244-1278`) already pass `imageAsset: AssetPaths.eventOrderDecision` into `PublicDemoEventDialog`, with a dedicated `Key('public-demo-order-decision-image')`. | `PublicDemoEventDialog`, `AssetPaths.eventOrderDecision` | None | **N/A — does not reproduce** | — | — | None — confirm only; if the Human Replay video predates this, note that the symptom is stale | — |
| 6 | 月終了/月次経営レポートが弱い（固定費内訳・ひより画像・スクロール・具体性） | **Authority-inspected.** `PublicDemoMonthlyReportSnapshot`/`PublicDemoMonthlyReportDisplayData` (`lib/ui/public_demo/public_demo_monthly_report_display_data.dart`, 223 lines) already carries `fixedCostsPaid` as a distinct field (`:44,76,147`) and already produces waiting-count-targeted advice text (`:216`, "待機中のメンバーが${data.waitingCount}名います。営業タブから案件参画を進めましょう。") — i.e. the "誰に何を" connective tissue #148 asks for partially exists already for this one case. Full breakdown of *which* fixed-cost line items make up `fixedCostsPaid`, whether the dialog fits one screen at 390×844/360×800, and whether a ひより portrait renders were not traced line-by-line in this pass. | `PublicDemoMonthlyReportSnapshot.fromAggregate`, `PublicDemoMonthlyReportDialog` | #148 Phase 1 (資金危機予告・具体的CTA) — directly reusable authority; #237 (referenced by #239 as "Monthly Management Reportのread-only authority") | P1/P2 (mix — the "赤字原因→対象社員→次の具体行動" connective piece is P1 per #148; visual/image polish is P2) | Yes for compression/labeling/advice wording; the underlying numbers are already real | None expected — `fixedCostsPaid` and friends already exist; a breakdown is a display slice of already-summed data (verify no per-category breakdown is silently absent before promising a "内訳" that doesn't exist in the domain yet) | Compress to one 390×844/360×800 screen without scroll for the KPI block; render `fixedCostsPaid`'s components if the domain actually has them (verify first — do not fabricate a breakdown); attach a ひより portrait + 1-2 line state-dependent comment; keep #148's "対象社員→具体行動" CTA pattern | M |
| 7 | 紹介会社/商流が分からない | **Code-verified — no authority exists.** `PublicDemoProjectCandidate` exposes `clientName` (via `client.name`, `public_demo_project_generator.dart:29`) but grep across the project generator found **no introducer/agent/trade-tier field at all** (no 一次/二次/多重下請けconcept). | `PublicDemoProjectCandidate`/`Project`/`client` | None | P3 | N/A — nothing to relabel | **Yes if built** — this is new data model surface, not a display fix | Per Issue #245's own guardrail: **do not fabricate this in UI.** Either (a) leave it out until a real data model is designed, or (b) scope a minimal `introducerTier`/`agencyName` field addition as its own small design item, explicitly separate from this Phase set | — (design-only until scoped) |
| 8 | 採用候補の「評価」の意味が分からない | **Code-verified.** `Text('評価 ${a.interviewScore}')` (`:3833`) shows the **raw** `PublicDemoApplicant.interviewScore` int directly, with a bare `>= 60` gate on the offer button (`:3199`,`:3837`) and no explanation anywhere of what composes the number or why 60 is the bar. `interviewScore` is derived once at generation time from `_interviewScore(a.personality)` (`public_demo_recruitment_candidate_generator.dart:206,239`) — i.e. it is generation-time-fixed, not something the player's own interview choices move (Public Demo's recruitment interview mini-game — Phase 3 — asks questions/observations but the accept/reject decision is the player's, not scored). | `PublicDemoApplicant.interviewScore`, `PublicDemoRecruitmentCandidateGenerator._interviewScore` | None existing | P1 | Yes | None — the number already exists and is already shown; this is a labeling/explanation gap, not a new score | Stop presenting a bare number as "評価"; replace with the same qualitative pattern Phase 5 Matching already established (◎○△×/tiered text) or, at minimum, label it truthfully ("書類上の評価" + a short "何を見ているか" line) and make the 60-point bar textual ("合格ライン") instead of implicit | S |
| 9 | 面談モーダルを閉じると面談済になる疑い | See §1 above — **does not reproduce as stated** for either interactive dialog; root cause is the same as Finding #3 (legacy `ei()` path commits on tap, before any modal renders) | See §1 | None existing | P1 (comprehension/trust issue even though not a literal integrity bug) | Partially — see Finding #3's split | None for the guard itself (already correct); building real interactivity for Partner Interview is a schema/UX addition, not a fix to a bug | Document/ regression-lock the "close never commits" guarantee for both interactive dialogs explicitly (add a dismiss/reopen test naming Issue #245 if not already covered); resolve the real complaint via Finding #3's plan | S (regression test) tied to Finding #3's M–L |
| 10 | 面談モーダルをスクロールしたくない | **Code-verified for Phase 6/Phase 3 dialogs** — both already use `SingleChildScrollView`/`ListView` specifically so a large `TextScaler` grows content *downward* rather than overflowing (explicit doc comment, `public_demo_project_interview_dialog.dart:268-272`); i.e. these dialogs are technically safe at 360×800/TextScaler 1.3, but by design they **do** scroll once content exceeds viewport — the finding is about information density/one-screen comprehension, not a bug. Not independently re-measured pixel-for-pixel in this pass. | `_QuestionPhase`/`_ResultPhase` (Phase 6), `_QuestionsPhase`/`_ReversePhase`/`_SummaryPhase` (Phase 3) | None existing | P2 | Yes | None | Trim the question card / info card heights, collapse secondary detail behind a "詳細" expansion, keep primary question+choices+CTA in the always-visible band; verify at 360×800 + TextScaler 1.3 with real content lengths (do this empirically before committing to a design, since claims of "先頭に収まる" are easy to get wrong) | S–M |
| 11 | 営業タブ右上の「案件数」の意味が分からない | **Code-verified.** `現在の営業・採用状況` section (`:4856-4895`) shows `'案件 ${workflow.assignments.length}件'`, i.e. **assignment records** (受注済み・参画中/検討中), not "紹介された案件数" or "候補案件数" as a player might reasonably guess. A secondary line ("うち検討中 N件") exists when `pendingAssignmentCount > 0`, using the same `assignments` collection. | `workflow.assignments` (`PublicDemoAssignment`) | None existing; adjacent to #239 (project/order/assignment continuous visibility — directly reusable resolver work) | P2 | Yes | None — same underlying count, just mislabeled | Relabel to something unambiguous, e.g. "受注案件 N件" (+"うち検討中 N件"), or add a tooltip/subtext clarifying it counts assignment records, not leads. #239's presentation-resolver work is the natural home for this fix | S |
| 12 | 入社面談後の応募者がどうなったか分からない | **Authority-inspected.** `PublicDemoApplicantStage` (`public_demo_recruitment.dart:63-78`) is a rich, explicit lifecycle enum (`applied → resumeReviewed → interviewed → rejected/offerAccepted/offerDeclined → preEntry* → juneOrdered`), and per-stage Japanese labels already exist (`:2428-2470` in the placeholder screen, e.g. `不採用`/`内定辞退`/`案件紹介済`/`上位面談通過`…). The backend data to answer "where is this applicant now" is present; whether the *player-facing surface* groups/filters by these stages clearly, and what a declined/rejected applicant's card looks like (dimmed vs. removed), was not independently re-verified pixel-for-pixel in this pass. Issue #245 itself notes #241 already fixed the "joined applicant stale CTA" sub-case. | `PublicDemoApplicantStage`, stage-label mapping in `public_demo_01_placeholder_screen.dart` | #241 (already merged — stale CTA fixed), #239 (lifecycle visibility pattern directly reusable) | P1 | Likely yes | None expected — stage data already exists | Reuse #239's "continuous visibility" resolver pattern for applicants too: a compact lifecycle strip per applicant card using the labels that already exist; confirm at implementation time whether declined/rejected applicants are dimmed, filtered into a separate section, or removed, and make that an explicit, intentional choice rather than incidental | S–M |
| 13 | 応募者がどこにいるか分かりにくい（一覧の所在） | **Authority-inspected**, same backend as #12. Existing rich stage enum + labels suggest grouping/sectioning by stage is achievable without new state. Actual current tab/section layout for the applicant list was not read screen-by-screen in this pass. | Same as #12 | #239 (reuse its per-surface grouping approach rather than inventing a new one) | P2 | Yes | None | Group existing 営業タブ applicant cards by stage bucket (応募中/選考中/結果待ち/辞退/入社予定) using the stage enum that already exists, with counts per bucket; do not add a new screen (issue explicitly asks to prefer existing surface) | S–M |

---

## 3. Existing Issue overlap map

| Issue | Status (audited SHA) | Overlap with #245 |
|---|---|---|
| **#148** (資金危機予告/具体的アドバイス) | Open, `closed_by_pull_requests: 0` | Direct authority reuse for **Finding #6** ("赤字原因→対象社員→次の具体行動" pattern) and adjacent to **Finding #3**'s "面談選択肢の意味" ask. #148 Phase 2 specifically asks for interview-choice-intent labels and post-fail differential feedback — same shape as this audit's Finding #3 recommendation. Do not duplicate; #148 should be treated as the authority owner for the Monthly Report CTA pattern. |
| **#205** (Matching Decision Gameplay) | Open, `closed_by_pull_requests: 0` | Establishes the ◎○△× qualitative-tier display convention (`PublicDemoEngineerProjectFit`/`FitBreakdown`) this audit recommends reusing for **Finding #8**'s "評価" relabel and partially for **Finding #3**'s Partner Interview explanation. No overlap in scope — #205 is Matching, not Interview or Recruitment evaluation, but its no-raw-score convention is the right template. |
| **#219** (Project Interview Reachability) | Open, `closed_by_pull_requests: 0`, but **substantial fixes already landed on main** (evidenced by doc comments at `_introduceProject`, `_startClientInterview`, and the existence of the fully-built `PublicDemoProjectInterviewDialog`/Phase 6 pipeline) | Directly explains why **客先面談** (with a proposal) is already a real interactive mini-game while **上位会社面談** never received equivalent treatment — this is the precise gap behind Finding #3/#9. #219 should likely be closed or re-scoped once its remaining "also inspect" bullets (営業残4回の意味, 案件0件の説明) are folded into this audit's Phase plan, to avoid two open Issues tracking the same reachability territory. |
| **#225** (Post-Balance Human Replay) | Open, 2 comments, `closed_by_pull_requests: 0` | **This is the direct parent of #245** — #245's own body states it is the Fresh Audit follow-up to #225's Human Replay findings. No independent new scope; #225 should stay open only as the human-replay record, with #245 (and its Phase split below) as the actioning Issue. |
| **#239** (Project/Order/Assignment Continuous Visibility) | Open, `closed_by_pull_requests: 0` | **Highest-value reusable authority in this audit.** Its "same presentation resolver, reused across Sales/Employee surfaces" approach is the correct implementation home for **Finding #11** (案件数ラベル) and directly extensible to **Finding #12/#13** (applicant lifecycle visibility) and **Finding #2** (営業開始/案件紹介 feedback) — all are "show existing truthful state more clearly," #239's exact mandate. Strongly recommend folding Findings #2, #11, #12, #13 into #239's scope or its immediate successor Phase, rather than opening a fourth parallel comprehension Issue. |

**Net read:** none of the five issues are stale/superseded as a whole, but #219's core reachability complaint is **already resolved for 客先面談** on current main (its remaining scope is narrower than its own title suggests), and #239's resolver pattern is the right home for roughly half of this audit's P1/P2 presentation findings.

---

## 4. Proposed Phase split

**Phase A — Comprehension & feedback fixes (presentation-only, no schema change)**
Findings: #1 (初期社員紹介), #2 (営業開始/案件紹介フィードバック), #8 (評価の説明), #9 (regression lock only), #11 (案件数ラベル)
- All confirmed presentation-only. Smallest, most isolated changes. No conflict with #239/#148's own in-flight scope if sequenced first or explicitly coordinated.
- Est. size: S–M each, cohesive as one PR.

**Phase B — Interview truthfulness & explanation (上位会社面談 + Recruitment)**
Findings: #3 (上位会社面談 explanation, stop showing raw score/基準点), #10 (interview dialog information density)
- Relabeling/score-hiding is presentation-only; giving Partner Interview real interactivity (reusing `ClientInterviewEngine`, not a new formula) is the one item here with meaningful size — recommend splitting Phase B into B1 (truthful labeling, no raw score, S) and a separately-scoped B2 (real Partner Interview mini-game, M–L) so B1 can ship without waiting on B2's design.

**Phase C — Lifecycle visibility (reuse #239's resolver)**
Findings: #6 (Monthly Report clarity/CTA, reusing #148), #12 (applicant lifecycle visibility), #13 (applicant list grouping)
- Explicitly coordinate with/extend #239 rather than forking a new resolver. #6 additionally reuses #148 Phase 1's CTA pattern.

**Phase D — Design-only, not implemented without further scoping**
Findings: #4 (parallel sales — real schema change, own Issue), #7 (紹介会社/商流 — no authority, do not fabricate; scope a data-model addition first if desired)
- Per Issue #245's own guardrail, these must not be folded into a "just implement it" phase. Recommend Phase D produce a short design doc/Issue for #4 before any implementation, and treat #7 as backlog until product need is confirmed.

## 5. Test strategy (for future implementation phases)

Reuse Issue #245's own Verification requirements verbatim as the regression floor for every Phase:
fresh/reset April; modal dismiss/back/reopen (explicitly re-assert §1's guarantee for both interactive dialogs); save/reload; duplicate/double-tap; month boundary; applicant joined/declined/pending; project proposal/interview/pass/fail/order/assignment; 360×800/390×844; TextScaler 1.0/1.3; focused tests; `flutter analyze`; `flutter test test/game/public_demo`; `flutter test test/ui/public_demo`; `git diff --check`. Phase B2 (real Partner Interview mini-game) additionally needs the same session-resume/duplicate-submission test shape already proven for Phase 6 Project Interview (`public_demo_project_interview_dialog.dart`'s own Codex P1/P2 regression tests) if it reuses that engine.

## 6. Implementation size summary

| Phase | Findings | Size | Schema/domain change |
|---|---|---|---|
| A | 1, 2, 8, 9(reg-test), 11 | S–M combined | None |
| B1 | 3 (labeling only) | S | None |
| B2 | 3 (real mini-game), 10 | M–L | Possibly none (reuse `ClientInterviewEngine`) — confirm at design time |
| C | 6, 12, 13 | M | None (reuse #239 resolver) |
| D | 4, 7 | Design-only this round | #4: yes, real schema change. #7: yes if ever built |

## 7. Non-goals honored

No production code changed. No new score/state introduced. No hidden parameter disclosed (Finding #3/#8 recommendations explicitly remove/avoid raw-score display rather than adding one). No project/company/trade-flow data fabricated for Finding #7. Finance/Payroll/Matching/Interview outcome formulas untouched. `ordered != assigned` and `revenue != cash receipt` distinctions unaffected by any recommendation above. HOME redesign / Visual Complete 2 / 1ターン1週化 not touched.

## 8. Final recommendation

**Proceed to Phase A first** (5 presentation-only findings, no schema risk, high comprehension payoff, directly addresses the two items Issue #245 flagged as needing first attention: Finding #9's state-integrity concern is resolved by evidence rather than a code fix, and Finding #1/#2's "why is nothing happening" gap is the most visible early-game friction from the Human Replay). Sequence Phase B1 next (same session, cheap). Coordinate Phase C explicitly with #239 rather than forking a new resolver. Treat Phase D (#4, #7) as backlog design work, not implementation, until scoped separately.

## Next 3 tasks

1. **Phase A implementation PR** — Findings #1, #2, #8, #11 (presentation-only) + an explicit Finding #9 regression test locking "dismiss never commits" for both interactive interview dialogs.
2. **Phase B1 implementation PR** — Finding #3's truthful relabel (stop showing raw `score`/`基準点60点` in `PublicDemoInterviewResultDialog`; qualitative reasons instead), scoped separately from the larger Partner Interview mini-game redesign (B2).
3. **Coordinate with #239** — either fold Findings #6/#11/#12/#13 into #239's own implementation scope, or open a explicitly-dependent follow-up Issue that reuses #239's resolver once #239 lands, to avoid two parallel "make existing state visible" efforts.
