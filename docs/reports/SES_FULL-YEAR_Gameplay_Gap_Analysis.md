# SES Full-Year Gameplay Gap Analysis

## STATUS

Investigation only. No production code, test code, or workflow file was modified. No commit/push was made to `main`. No pull request was created. This report is the sole deliverable, committed to the designated read-only-audit branch `claude/ses-full-year-gameplay-audit-9h4ojx`.

A separate task is running CI/Deploy verification for PR #135 on `main`; this audit treated `main` as read-only throughout (all code inspection was done in a detached, throwaway git worktree checked out at the SHA below; the working branch itself only ever touches this one report file).

## AUDITED MAIN SHA

```
25a2e9b6b401794090151cc86006e433c8d9a789
```
("Merge pull request #135 from perusonao/claude/issue-118-single-monthly-cta-f3trqr", 2026-09-01T01:51:47+09:00). `git fetch origin main` was re-run immediately before writing this report; this was still `origin/main`'s tip at that time.

## EXECUTIVE SUMMARY

S.E.S. Public Demo is architecturally solid: the April→March progression is guarded by a single, well-tested `isCloseBlocked`/`PublicDemoFinancialStatus` state machine, and the three previously-known deadlocks (July summer-bonus close, duplicate month-advance CTA, premature SkillSheet stage transition) are already fixed and regression-tested on `main` (Issues #133, #118, #117). **No BLOCKER-severity deadlock was found in a normal playthrough at the audited SHA.**

The real gap is not "can the player finish the year" — they can, reliably, in both a success and a bankruptcy trajectory (`public_demo_balance_regression_test.dart`, `public_demo_01_bankruptcy_ux_test.dart`). The gap is **content**: recruitment is only ever exposed to the player in May, engineer sales-pipeline UI (the ability to sell/re-sell an engineer) exists only in April and June, and project assignment is frozen for the rest of the fiscal year once June's order/replacement decision is made. From **August through February — 7 of the 12 months** — the game has no month-specific mechanic at all; `PublicDemoMonthlyClose.closeOrdinaryMonth` is one generic path with, by the domain code's own comment, "no month-specific rule the way July's bonus does." This is not a hidden finding — it is the exact subject of open Issue #125 ("late-year months collapse into a generic fallback message"), though that issue is scoped to copy/presentation only, not new mechanics.

The single biggest lever for "1年間通してプレイできて面白い" is therefore **not** more deadlock-proofing (that work is essentially done) and **not** a minigame (Issues #128/#129) — it is giving September–February at least one real, repeating, consequential decision each, and giving March a year-end report that reflects more than one number (final cash).

## APRIL–MARCH TRACE

All facts below are drawn from the audited SHA's `lib/game/public_demo/*.dart` and `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, cross-checked against tests. Internal month numbering is April=4 … March=15; `closeApril/closeMay/closeJune/closeJuly` are dedicated per-month commands, `closeOrdinaryMonth` is one shared path for months 8–15.

| Month | Start state | Available actions | Required action | Optional actions | Player decision | Events | Employee change | Project/sales change | Cash/finance change | Month close condition | Next-month transition | Failure/recovery | Gameplay feedback |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **April (4)** | 2 engineers, ¥4,000,000 cash, `salesCapacity` 4 | SkillSheet review (read-only confirm) → begin selling → interview partner/client for each engineer | Advance-month CTA (always closable; no guard blocks April) | Retry a failed interview while sales slots remain | Real: SkillSheet confirm, when to push each engineer through the sales pipeline | New-applicant-arrival dialog (deterministic) | Sales stage advances per engineer; possible interview failure/retry | 0 assigned until an interview chain completes | `cash -= 600,000` (baseline salary+fixed cost) at close | `state.month == 4 && !isCloseBlocked` | `closeApril → advanceToMay` (overwrites assigned/waiting from ordered engineers) | Interview failure loops back to `selling`, retryable same month | Growth-result card only if any engineer actually grew |
| **May (5)** | Whatever April produced | Recruitment media (free vs. ¥100,000 "engineer" medium — **only month this card renders in the shipped UI**), applicant resume/interview/offer chain, salary-offer tier choice, continue any unsold engineer's sales pipeline | Advance-month CTA | Choose which/how many applicants to advance; which salary tier to offer | Real and consequential: free(1 applicant) vs. paid(2 applicants, ¥100k) recruiting; salary-offer tier changes acceptance odds and morale/trust deltas | First-join event dialog | New hires join via `PublicDemoBindingOffer`→`PublicDemoJoinTransaction`; payroll grows | Additional engineers/applicants can reach `ordered` | Cash: recruitment cost mid-month + baseline close deduction | `state.month == 5 && !isCloseBlocked` | `closeMay → advanceToJune` (additive assignment) | Rejected offer/failed interview: applicant drops out, no state corruption | Growth cards; new hire visible in roster |
| **June (6)** | Engineers/hires from April–May | Assignment decision per engineer: accept continuation (`decideOrder`/`acceptOrder`) or run a full replacement sales/interview chain (`replacementPartner`/`replacementClient`); June applicant order path; remaining unsold engineers get one more sales-stage window; raises become eligible from this month; internal training becomes available from this month | Advance-month CTA | Raise request (one-time/employee), internal training (¥30,000/engineer, only for waiting engineers) | Real: accept vs. replace an assignment; raise hold/small/requested; train or not | Order-confirmation dialog | Raise/training deltas apply | **This is the last month with any assignment-decision UI** — `assignedEngineerIds(month)` from July onward is fixed by June's `nextOrderStatus`/`replacementStage` | Cash: baseline close + any training spend | `state.month == 6 && !isCloseBlocked` | `closeJune → advanceToJuly` (overwrite again) | Replacement chain failure leaves that engineer `waiting` — **no further UI to re-sell them after this month** (see Deadlock Matrix) | Growth cards |
| **July (7)** | Assignment roster now fixed for the rest of the fiscal year | Summer bonus decision (`none`/`half`/`one`, forced before close), raise (if not yet decided), internal training (waiting engineers only) | Confirm a summer-bonus plan, then advance-month CTA | Raise, training | Real, well-tested: `none` is always eligible even at negative cash (Issue #133 fix); a paid plan is rejected atomically if it would leave cash negative, never silently downgraded | — | Bonus paid or not | No new assignment activity (frozen) | Cash: `pendingRevenue` settles first, then `monthlyExpenses + bonusAmount` (or `monthlyExpenses` alone for `none`) | `state.month == 7 && !isCloseBlocked && preview.isEligible` | `closeJuly → advanceToAugust` (`PublicDemoSummerBonusPayment.closeJuly`) | `none` always closable — no deadlock; paid-plan rejection is atomic, no partial charge | Cash-flow card shows bonus line |
| **August (8)** | Bonus decided, roster fixed | Raise (if any employee still undecided), internal training (if any waiting engineer) | Advance-month CTA | Raise, training | Weak — most players have already resolved raise/training by now; the one August-specific UI content is a one-off "7月分の給与を反映しました" recap | — | Only via lingering raise/training | None (frozen) | Cash: baseline close only, via `closeOrdinaryMonth` | `state.month == 8 && !isCloseBlocked` | `closeOrdinaryMonth → advanceToNextOrdinaryMonth` | — | Cash-flow card, generic |
| **September–February (9–14)** | Static roster, static recruitment/sales UI | Raise/training only if still undecided (rare by this point) | Advance-month CTA | Raise, training (if applicable) | **None new** — no recruitment card, no sales-pipeline card, no assignment-decision card renders in this range | — | None structural | **None** — no renewal/expiration/re-sale loop exists after June | Cash: baseline close each month via the same `closeOrdinaryMonth` path | `state.month in [8,15] && !isCloseBlocked` (identical guard every month) | `advanceToNextOrdinaryMonth`, `month += 1` | Cash-shortage/bankruptcy can trigger any month if cash goes negative twice in a row | Generic "{month}開始結果" header only — **confirmed by the domain code's own comment as intentionally undifferentiated**, and the direct subject of open Issue #125 |
| **March (15)** | Whatever the year produced | Advance-month CTA only (no new decision type) | Close March | — | The close itself is the year's most consequential single click — it resolves success vs. failure | — | — | `pendingRevenue` recognized this month correctly stays pending, never collected (year ends first) | `completeFiscalYear`: cash -= expenses, then financial status computed from the result | `state.month == 15 && !isCloseBlocked` | Does **not** advance `month`; sets `fiscalYearCompleted = !status.isTerminal` and freezes forever (`isCloseBlocked`) | `normal`/`cashShortage`→non-negative = success; negative = `bankruptcy` (if already `cashShortage`) or `marchCashShortageFailure` (if previously `normal`) | One static card: "第1期終了" / final cash only — no score, rank, or history (explicit in code doc) |

## DEADLOCK MATRIX

| Area | Severity | Basis |
|---|---|---|
| Month-close guard (`isCloseBlocked`, exact-month checks) | **NONE** | Every `closeX`/`advanceToX` is a proven no-op off-guard; equivalence-tested (`public_demo_monthly_close_test.dart`). |
| July summer bonus (previously a P0 deadlock) | **NONE** (fixed) | Issue #133: `none` plan is unconditionally eligible even at negative cash; a paid plan is rejected atomically, never silently downgraded. Regression-tested down to the exact `¥-210,000` fixture. |
| Duplicate month-advance CTA | **NONE** (fixed) | Issue #118 removed the six legacy per-month buttons; exactly one canonical CTA remains, confirmed by direct code read at the audited SHA. |
| SkillSheet premature stage transition | **NONE** (fixed) | Issue #117: viewing SkillSheet no longer silently advances the sales stage; requires explicit confirmation. |
| Cash shortage → bankruptcy | **NONE** (working as designed) | `cashShortage` gives one grace month; a second consecutive negative close is terminal (`bankruptcy`) and freezes `isCloseBlocked` forever. This is intentional failure, not a bug, and is well tested. |
| "Walking dead" after bankruptcy | **LOW** | `isFinanciallyRestricted`/`isCloseBlocked` block new obligations and month-closing, but sales-pipeline progression and sales-slot consumption are **not** gated by financial-terminal status (only by `fiscalYearCompleted`) — a bankrupt company can still click through sales-stage buttons that can no longer matter. Cosmetic inconsistency, not a progression blocker (the bankruptcy card's only offered action is restart anyway). |
| Recruitment media dead-end (buying candidates nobody can hire) | **NONE at UI level** | The recruitment-media card is gated to render **only in month 5** in the shipped UI at this SHA (`:2173-2180`); the domain technically still permits the transaction in months 4/6/7/8, but no UI path reaches it outside May, so the historically-documented "spend cash on stranded July applicants" trap (12MONTH-3-FIX1 P1-2) is not currently reachable by a normal player. Flagged as a latent domain-only oddity, not a live gap. |
| **An unsold/unassigned engineer after June** | **MEDIUM** | Engineer sales-pipeline UI (`ec(i)`) renders only in months 4 and 6. An engineer who never reaches `ordered` by the end of June has **no UI path to be sold, re-sold, or reassigned for the remaining ~9 months of the fiscal year**, while still drawing full salary (`monthlyExpenseAdjustment` sums salary for every joined hire regardless of assignment status). The game keeps advancing normally, but that employee's state is a permanent, unrecoverable cost — a very plausible outcome of one bad April/June interview streak. Not a hard BLOCKER (game still closes months fine), but a real, silent, unaddressed cost sink. |
| Project/contract renewal after June | **MEDIUM (Fun Gap, not a hard deadlock)** | By explicit code comment (`public_demo_workflow_state.dart`), "once a project assignment is established, the employee continues on the same project until the end of the first fiscal term." There is no monthly renewal/expiration decision after June — this directly means the DEVELOPMENT_PLAN's stated design intent for October–December ("contract continuation/renewal choices") is **not implemented** in Public Demo. Game progresses fine; there is simply nothing to decide. |
| No applicants on recruitment | **NONE** | Not reachable in production; the deterministic generator always returns the requested count from a non-empty pool. The `generationFailed` status exists only behind a test-only injectable hook. |
| Never recruit | **NONE** | Recruitment is fully optional; the 2 starting engineers can carry the company (with reduced revenue), well within tested bankruptcy/success ranges. |
| Sales/interview failure | **NONE** | Retryable in the same month while sales slots remain (`salesRemaining` resets to 0 used every close). |

**BLOCKER count: 0. HIGH count: 0.** The two MEDIUM findings above (stuck engineer, frozen project roster) are Fun/consequence gaps that happen to also read as mild deadlocks — the game never stops, but a real chunk of state becomes permanently inert.

## FUN GAP MATRIX

| Month | Classification | Why |
|---|---|---|
| April | **STRONG** | SkillSheet confirm, sales-pipeline sequencing, interview outcomes with retry — several real, state-changing choices. |
| May | **STRONG** | Free-vs-paid recruitment, salary-offer tier (3 real tradeoffs), continuing April's unsold engineers — the most decision-dense month in the game. |
| June | **STRONG** | Assignment accept-vs-replace decision (the *only* place this decision ever exists), raise eligibility opens, training opens. |
| July | **STRONG** | Summer bonus (none/half/one) is a genuine, well-modeled financial tradeoff with immediate, atomic consequences. |
| August | **THIN** | One-off payroll/bonus recap text; remaining "decisions" (raise/training) are usually already resolved by most playthroughs; nothing new is introduced. |
| September | **EMPTY** | Generic `closeOrdinaryMonth` only; no month-specific UI or mechanic. |
| October | **EMPTY** | Same as above. Also the month DEVELOPMENT_PLAN's own roadmap (Phase 3C) says should introduce "contract continuation/employee satisfaction/retention" decisions — none of that exists in Public Demo. |
| November | **EMPTY** | Same generic path; only tested content at this month is a cash-shortage scenario, not a designed decision. |
| December | **EMPTY** | Same. |
| January | **EMPTY** | Same; only tested content is confirming pending-revenue carries correctly across the fiscal-year boundary — an accounting correctness check, not gameplay content. |
| February | **EMPTY** | Same. |
| March | **OK** | No new decision, but the close itself resolves the entire year's outcome (success/failure) — meaningful as an *event*, weak as *content* (see Year-End Audit). |

Confirmed independently by the codebase's own comment ("no month-specific rule the way July's bonus does") and by open Issue #125, which describes exactly this symptom ("late-year months currently collapse into a generic 'just close the month' fallback message") — but note #125 is scoped to **presentation/copy only**, not new mechanics, so implementing it as currently written would not move any of September–February out of EMPTY.

## COMPANY CHANGE

| Metric | April | July | October | March | Notes |
|---|---|---|---|---|---|
| Cash | ¥4,000,000 (start) | Post-bonus, revenue-dependent | Revenue-dependent, no new inflow/outflow types | Final settled figure (pass/fail determinant) | Real, tracked precisely (`public_demo_balance_regression_test.dart` pins exact figures for all 12 months on one realistic route). |
| Monthly revenue | ¥0 (nobody assigned yet) | `¥500,000 × engineersAssigned` (frozen from July on) | **Identical to July** | **Identical to July** | Revenue is fixed for 9 straight months once June's assignment decisions are made — this is the mechanical root of the Fun Gap above. |
| Monthly expenses | ¥600,000 baseline | Baseline + any hires' salaries + raises | **Identical to July** unless a late raise fires | **Identical** | Changes only via April/May hiring or June-onward raises — no new expense category ever appears. |
| Employee count | 2 engineers (+1 general-affairs, per Issue #122's finding — mislabeled in UI as "2 employees") | + May hires | **Unchanged** | **Unchanged** | No cap exists in code; no resignation/turnover exists (`turnoverIntent` is a hidden field, never read anywhere). |
| Waiting employees | Whoever hasn't sold yet | Anyone stuck since April/June | **Unchanged forever** if stuck past June | **Unchanged** | This is the "stuck engineer" MEDIUM finding materializing as a static company metric. |
| Assigned employees | 0 | Fixed roster from June | **Unchanged** | **Unchanged** | Frozen by design (see Deadlock Matrix). |
| Projects | 0–2 | Fixed | **Unchanged** | **Unchanged** | No renewal/expansion loop after June. |
| Project rates | ¥500,000/assigned engineer (flat) | Same | Same | Same | **Never changes** — no per-project rate variation, no negotiation, no escalation/de-escalation found anywhere. |
| Company trust | N/A | N/A | N/A | N/A | **Does not exist as a company-level stat.** Only per-*employee* morale/trust deltas exist (from raise/salary-offer decisions); no UI aggregates or displays a company-level figure. |
| Morale | Per-employee only | Per-employee only | Per-employee only | Per-employee only | Same as above — tracked per employee, never surfaced as a company KPI, and (see Choice Consequence Audit) never consumed by any other system. |
| Skill growth | Starting values | Growth cards show real deltas | Growth cards show real deltas | Growth cards show real deltas | **Real, changing** — `applyMonthlyGrowth` genuinely increases capability/language over time; this is the one metric that visibly compounds across the year. |
| Office | Static background image | **Unchanged** | **Unchanged** | **Unchanged** | HOME-RUNTIME-2B's "Office Stage" is confirmed to have no tier-specific asset and no upgrade path — it is decorative, not a growth indicator. |
| Recruitment | Available (April onward, UI-limited) | UI card no longer renders | UI card no longer renders | UI card no longer renders | A one-shot May event, not an ongoing system, despite being domain-capable through month 8. |
| Sales pipeline | Active | Active only via June's cards | **Inactive** — no card renders | **Inactive** | Front-loaded into April/June; genuinely absent for the second half of the year. |

**Net read**: the player experiences real growth in exactly one dimension (per-employee skill) for the full year; every other "company growth" metric (revenue, expenses, headcount, project count, rates) is fixed by the end of June and stays flat through March.

## CHOICE CONSEQUENCES

| Choice | Immediate result | Next-month effect | Year-end effect | Converges to same state? |
|---|---|---|---|---|
| SkillSheet confirm vs. cancel | Cancel = no-op, stays `waiting`; confirm = advances to `skillSheet` stage | Confirm unlocks selling | Gate to ever reaching `ordered` at all | No — a real branch (proceed vs. don't). |
| Recruitment medium: free vs. paid | 1 vs. 2 applicants, ¥0 vs. ¥100,000 | More applicant pool → more possible hires | More potential revenue if both hired & assigned by June | No — real, but one-shot (May only). |
| Salary-offer tier (below/at/above requested) | Different acceptance odds; morale/trust delta at hire | Different permanent salary cost | Different long-run cash burn | No — cash differs permanently; **but** morale/trust portion of the "consequence" is inert (see below). |
| Raise: hold / small / requested | ¥0 / +¥20,000 / +¥60,000 permanent salary; morale/trust −4/−5, +2/+2, +5/+4 | Recurring cash difference every month after | Meaningfully different cash trajectory | **Cash: no. Morale/trust: yes, converges** — no code anywhere reads employee morale/trust after it's set (no resignation, no productivity effect, no triggered event). The HR "consequence" the game presents (a visible morale/trust delta) currently has **zero downstream mechanical effect** — it is decorative. This is the clearest instance of "選択肢があるように見えるが、最終的にほぼ同じ状態になる" in the current build. |
| Summer bonus: none / half / one | ¥0 / 0.5mo / 1.0mo of eligible salary paid once | N/A (one-time) | Real, permanent cash difference; well-tested | No — genuinely different, and well-guarded against unaffordable selection. |
| Internal training: yes/no | −¥30,000 if trained | Different growth-source label on the growth card | Slightly different capability trajectory vs. relying on assignment/waiting growth | No, but low-magnitude — the growth-card evidence agents gathered didn't surface a large divergence; likely a minor differentiator. |
| June assignment: accept renewal vs. replacement chain | Accept = continuity, zero risk; replacement = must re-run sales/interview, can fail | Determines whether the engineer generates revenue for the rest of the year | Large — a failed replacement chain reproduces the "stuck engineer" MEDIUM finding | No — genuinely divergent, including a real failure branch. |

## YEAR-END CURRENT STATE

**Implemented:**
- Fiscal completion state machine (`completeFiscalYear`): computes final cash, determines `financialStatus` (`normal`/recovered `cashShortage` → success; `bankruptcy` or `marchCashShortageFailure` → failure), sets `fiscalYearCompleted` only on a non-terminal result.
- `isCloseBlocked` permanently freezes further mutation once the year ends (success or failure) — no accidental post-year state corruption.
- A minimal UI card ("第1期終了" / "1年間の経営が終了しました" / final cash figure only).
- A working restart-to-April path (shared with the bankruptcy card's restart button, via the always-present "テスト用操作" test-controls card), which correctly resets to `PublicDemoAggregate.initial()` and clears only the Public Demo save key.

**Not implemented (confirmed absent, not merely undiscovered):**
- Any score, rank, or qualitative evaluation of the playthrough — explicitly noted in the domain code's own doc comment as out of scope ("12MONTH-3 scope").
- Any recap of annual revenue, profit, headcount trajectory, hiring timeline, or first-collection/first-assignment milestones (all of which DEVELOPMENT_PLAN §3.6 specifies for the main week-based game's Beginner Mode, but which were never built for Public Demo's month-based mode).
- A dedicated "play again" / "Year 2" CTA specific to the year-end moment — the only restart path is the generic, always-visible test-controls button, not a framed year-end action.
- Any bankruptcy-specific "what went wrong" feedback beyond the terminal card's one-line reason text (DEVELOPMENT_PLAN §3.7 asks for 1–3 concrete, state-derived improvement hints; none exist in Public Demo).

**Achievement-feeling assessment**: LOW. The mechanical resolution (pass/fail) is sound and well-tested, but the presentation gives the player one number. Given the stated product goal — "3月終了時に『もう1年やりたい』と思える" — the current year-end screen does not supply the retrospective content (what did I do differently, how did my company actually change) needed to motivate a second playthrough; that content mostly doesn't exist elsewhere in the game either, per the Company Change Audit above.

## TEST COVERAGE

| Area | Status | Evidence |
|---|---|---|
| April | TESTED | `public_demo_monthly_loop_test.dart`, `public_demo_01_success_playthrough_test.dart`, `public-demo-fresh-start.spec.ts` |
| May | TESTED | `public_demo_monthly_close_test.dart`, `public_demo_01_success_playthrough_test.dart` |
| June | TESTED | `public_demo_monthly_close_test.dart`, `public_demo_01_playthrough_test.dart` |
| July | TESTED | `public_demo_monthly_close_test.dart`, `public_demo_summer_bonus_*_test.dart`, `public-demo-july-restart.spec.ts` |
| August | TESTED (thin) | `public_demo_monthly_close_ordinary_month_test.dart`, `public_demo_01_fiscal_year_progression_test.dart` |
| September | PARTIAL | Only generic month-advance/label assertions in the loop test |
| October | PARTIAL | Same |
| November | PARTIAL/TESTED (for bankruptcy) | `public_demo_01_fiscal_year_progression_test.dart` asserts `cashShortage` specifically at this month in one deficit scenario |
| December | PARTIAL | Label/guard checks only |
| January | PARTIAL | Explicit assertion that revenue is not incorrectly reset at the calendar-year boundary — an accounting correctness check, not gameplay coverage |
| February | PARTIAL | Covered only within the bankruptcy-route UI test |
| March / fiscal year-end | TESTED | `public_demo_financial_status_test.dart` covers all four terminal/success branches explicitly |
| Bankruptcy | TESTED | Domain + widget-level, including UI text/card-visibility assertions |
| Restart | TESTED | Domain, widget, and one e2e spec; verified byte-for-byte isolation from the main game's save |
| Persistence/save-reload | TESTED | Round-trip, corruption fallback, cross-field consistency validation, write-race protection |
| Finance/cash correctness | TESTED | Exact per-month cash checkpoints on a realistic route; 30-day AR timing |
| **Full year (April→March) in one test** | **TESTED — but only 2 tests, both pure-domain unit tests, neither UI nor e2e** | `public_demo_balance_regression_test.dart` (realistic route, exact cash per month, **success** outcome) and `public_demo_monthly_close_ordinary_month_test.dart` (mechanical, success outcome) |
| Full year at widget/UI level | PARTIAL | Longest widget-level runs (`public_demo_01_bankruptcy_ux_test.dart`, `public_demo_01_fiscal_year_progression_test.dart`) reach March/December respectively, but **only via bankruptcy** — no widget test exercises a full year to a *successful* close (explicitly noted as a known gap in the tests' own comments) |
| Full year at e2e/Playwright level | **UNTESTED beyond August** | Only 3 of 17 Playwright specs target Public Demo at all, and none goes past month 8 |

**Key takeaway**: the domain layer's correctness is thoroughly proven for the full year in both outcomes. What is *not* proven anywhere is "does a full successful year feel good in the actual UI a player uses" — no UI or browser test ever drives a winning playthrough end to end.

## ROADMAP ISSUE MAPPING

All of #119–#129 form an explicit, stated dependency chain (each names the previous as a prerequisite); #132 is independent. All are open, unlabeled.

| Issue | Maps to which finding above |
|---|---|
| #119 (month-guard warning before advance) | Mitigates the *symptom* of the "stuck engineer" / "undecided raise" MEDIUM findings — warns a player before they click past something consequential — but does not fix the underlying June-lock itself. |
| #120 (stop phantom applicants) | Correctness bug undermining the Company Change Audit's recruitment trust (recruiting should only ever be player-initiated). |
| #121 (first-start intro) | Addresses the Year-End Audit's expectation-setting gap — players currently aren't told the objective or the cash-shortage failure condition up front. |
| #122 (headcount labeling) | Directly the Company Change Audit's "2 engineers +1 general-affairs mislabeled as 2 employees" finding. |
| #123 (growth/progress visibility) | Directly addresses "会社が成長していると感じられるか" — surfaces the one metric (skill growth) that actually does change, which currently isn't well presented. |
| #124 (HOME fits one screen) | UI/G-axis; unrelated to content gaps. |
| #125 (Sep–Feb month-specific guidance) | **Directly names the biggest Fun Gap finding** (Sep–Feb EMPTY), but is explicitly scoped to copy/presentation only ("using existing visible data/mechanics"), not new decisions — implementing it as written would not move any month out of EMPTY into OK/STRONG. |
| #126 (order visual) | Choice Consequence Audit's feedback-strength gap (result of winning a project is text-only). |
| #127 (recruit/salary comparison UI) | Choice Consequence Audit's "weak option selectors" — supports better-informed May/June decisions. |
| #128 (project interview minigame) | H-axis engagement; explicitly not to be prioritized on fun-factor alone per the task brief. |
| #129 (employee 1on1 minigame) | Notably, this is the *only* item on the roadmap that could plausibly route into "existing morale/payroll/trust systems" — but per the Choice Consequence Audit, those systems currently have no downstream mechanical effect to route into. Implementing #129 without first giving morale/trust a real consequence would just be a new UI on top of an inert stat. |
| #132 (SkillSheet redesign) | Cosmetic/G-axis; follow-up to #117. |

**Not covered by any open issue #119–#132**: the "stuck engineer after June" gap, the absence of any post-June project renewal loop, the year-end report/score screen, and making morale/trust mechanically meaningful. These are the report's Top Gameplay Gaps below, and none of them currently has a tracking issue.

## TOP RISKS

1. **No UI/e2e test ever verifies a full, successful April→March playthrough.** All full-year coverage that ends in success is domain-only; the actual screen a player uses has only been proven end-to-end for a *failing* year. A regression that broke the success path specifically at, say, month 10 could ship undetected.
2. **An engineer who fails to sell by end of June is a silent, permanent cost with no recovery UI**, for up to 9 months. This is currently undocumented to the player and untested as a distinct scenario.
3. **Morale/trust is presented as a meaningful consequence (via raise/salary-offer dialogs) but is mechanically inert** — a player who carefully manages "employee happiness" gets no different game outcome than one who ignores it, beyond the one-time text/number shown at the moment of choice.
4. **The roadmap (#119–#132) does not currently contain any item that adds new September–February mechanics** — only #125, which is explicitly copy-only. Without a new work item, the largest Fun Gap in the game has no planned fix.

## TOP GAMEPLAY GAPS

1. September–February have zero month-specific decisions (EMPTY, 6 of 12 months).
2. No project/contract renewal loop exists after June, contradicting the game's own DEVELOPMENT_PLAN roadmap language for Phase 3C.
3. An unsold engineer after June is a permanent, unrecoverable cost sink with no UI recourse.
4. Year-end report is a single number (final cash); no score, trajectory, or qualitative evaluation.
5. Morale/trust choices are decorative — no downstream mechanical consequence exists anywhere in the current domain code.
6. Recruitment and sales-pipeline UI are both front-loaded into 2–3 early months rather than being ongoing systems, despite the domain layer being capable of more (recruitment media is domain-permitted through month 8).

## RECOMMENDED PRIORITY

Reusing existing issue numbers where they exist; inserting new (unnumbered) work only where the roadmap currently has no item for a finding above.

1. **#119** — month-guard warning (cheap, protects against players unknowingly skipping raise/training/replacement decisions).
2. **#120** — stop phantom applicants (correctness/trust bug, cheap).
3. **NEW — fix the "stuck engineer after June" gap.** Either give waiting engineers a re-sell path in any month, or make their permanently-idle state visible and explained rather than silent. Highest-leverage deadlock-adjacent fix not currently tracked by any issue.
4. **#122** — headcount labeling (cheap correctness).
5. **#123** — growth/progress visibility (cheap, reuses existing values, directly supports the E axis).
6. **#121** — first-start intro (sets correct expectations for the F axis before the player ever reaches March).
7. **NEW — real September–February content.** At minimum, one lightweight, repeating decision (e.g., a periodic project-continuation/renewal risk check, or a reopened recruitment/training cadence) so each of these 6 months has at least an OK-tier decision. This is the single biggest B-axis and overall-fun lever in the game.
8. **#125** — Sep–Feb fallback copy, done *after* item 7 exists, so the text describes a real decision rather than dressing up an empty month.
9. **#124** — HOME one-screen layout (cheaper to finalize once content, and therefore card count, is settled).
10. **#126, #127** — order visual, recruit/salary comparison UI (D/C-axis polish).
11. **NEW — year-end report/score screen.** Not on the current roadmap; needed for the stated F-axis goal ("もう1年やりたい").
12. **#132** — SkillSheet redesign (cosmetic).
13. **#128, #129** — minigames, last. Per the task brief's own instruction, do not prioritize these for being fun; #129 in particular should wait until morale/trust/turnover have a real mechanical consequence to plug into, or it will just be new UI over an inert stat.

## MINIMUM GAMEPLAY COMPLETE 1.0

Evaluated against "自分で1年間遊んで面白い" — not the 100-person-test bar.

### MUST

- Real, repeating monthly decision content for September–February (not copy-only — see Recommended Priority item 7).
- A fix (or an honest, visible acknowledgment) for engineers permanently stuck unsold after June.
- A year-end summary beyond final cash: at minimum revenue/cash trajectory, headcount, and a qualitative evaluation, matching what DEVELOPMENT_PLAN §3.6 already specifies for the sibling week-based mode.
- #119 (month-guard warning) — prevents players from unknowingly forfeiting the raise/training/replacement decisions that already exist.
- #120 (phantom-applicant fix) — a visible correctness bug that undermines trust in every other system.

### SHOULD

- #121 (first-start intro).
- #122 (headcount correctness).
- #123 (growth visibility).
- #125 (Sep–Feb copy), once real content exists to describe.
- #124 (HOME one-screen layout).
- Give morale/trust at least one real mechanical consequence (even a small one) so raise/bonus choices stop being decorative.

### LATER

- #126, #127 (visual/comparison polish).
- #132 (SkillSheet redesign).
- #128, #129 (minigames) — after HR-consequence design exists for #129 to plug into.
- Full Phase 6 HR system (resignation, deeper compensation negotiation) per DEVELOPMENT_PLAN.

## RECOMMENDED NEXT IMPLEMENTATION

Give **September through February** at least one real, repeating, consequential decision each — not the copy-only fallback text scoped by #125, but an actual mechanic (for example, a periodic project-continuation/renewal risk check, or reopening the recruitment/training cadence that currently exists only in April–June). This is the single highest-leverage change: it is the literal difference between "half the fiscal year is EMPTY" and a full year of the judgment→result→growth→new-problem loop the product goal describes, and no other single item on the current roadmap (#119–#132) would close it.
