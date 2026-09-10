# SES FIRST-FUN-YEAR: Seeded Balance Fix — Result Report

Issue: #223
Base SHA: `8aef213f5472f86cfa9472dbfffe8c7ff536042e` (PR #222 merge)
Head SHA: _filled in at commit time — see PR description_
Branch: `claude/issue-223-9n12mx`
Recommended/used AI: Claude Code Sonnet 5

## 1. Goal recap

First Fun Year's production loop (founding hiring, recruitment, sales,
matching, training, recovery) is now fully wired (#218, #220, #222). This
issue re-audits the whole April→March economy with a real, strategy-driven
seeded harness, and makes the **minimum** tuning changes needed so that:

- a disciplined "Balanced" strategy reliably completes the fiscal year,
- "Conservative" and "Growth" both have real, differentiated outcomes
  (neither a guaranteed win nor a guaranteed loss),
- "Poor decisions" is clearly riskier than a disciplined strategy recruiting
  just as aggressively,
- no single strategy is the *only* way to survive.

## 2. Fresh Audit — authoritative economy table (current `main`, before any
   change in this issue)

All values read directly from production source, not inferred:

| Item | Value | Source |
|---|---|---|
| Initial cash | ¥4,000,000 | `PublicDemoState.aprilStart` / `PublicDemoAggregate.initial` |
| Sato (eng-01) monthly salary | ¥300,000 | `PublicDemoSalary.satoMonthlySalary` |
| Suzuki (eng-02) monthly salary | ¥250,000 | `PublicDemoSalary.suzukiMonthlySalary` |
| General-affairs (総務) monthly salary | ¥200,000 | `PublicDemoSalary.adminMonthlySalary` |
| Other fixed cost (rent/utilities, aggregate) | ¥50,000 | `PublicDemoSalary.otherMonthlyFixedCost` |
| **Baseline monthly expense (no hires)** | **¥800,000** | `PublicDemoSalary.baselineMonthlyExpenses` = 300k+250k+200k+50k |
| Recruitment — free medium | ¥0, 1 applicant (50% chance of an inexperienced-template candidate) | `PublicDemoRecruitmentMedium.free` |
| Recruitment — engineer medium | ¥100,000, 2 applicants (best-of-3 by IT experience) | `PublicDemoRecruitmentMedium.engineer` |
| Recruitment legal window | internal month 4–8, once per month | `PublicDemoState.canUseRecruitmentMediaInMonth` |
| Hire requested salary band | ¥260,000–¥420,000 (engineer medium), ¥220,000–¥300,000 (free medium) | `PublicDemoSeededRecruitmentGenerator._mapSalary` |
| Internal training cost | ¥30,000 flat, all-or-nothing | `PublicDemoInternalTrainingTransaction.cost` |
| Internal training effect (**BEFORE**) | `floor(1.2 × potentialMultiplier × …)` — capped at **+1 capability/month for every engineer**, regardless of `growthPotential` (even Suzuki's own growthPotential:4 only reached 1.2×1.3=1.56, still floor 1) | `PublicDemoGrowthEngine._capabilityDelta` |
| Field-sales capability requirement | 60 | `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement` |
| Sato / Suzuki starting capability | 78 / 52 | `publicDemoInitialEngineerRuntimes` |
| Revenue per assigned engineer/month (**BEFORE**) | ¥500,000 flat — **independent of the actual project's `monthlyRate`/rank/difficulty** | `PublicDemoRevenue.ratePerAssignedEngineer` |
| Payment timing | fixed 30-day site (recognized this month, collected next) for every client, **regardless of `Client.paymentTermDays`** (some sample clients carry 60) | `PublicDemoRevenuePayment.apply` |
| Sales capacity | 4 slots/month (company-wide) | `PublicDemoState.salesCapacity` |
| Zero-revenue cash runway | survives through August (cash exactly ¥0 at August's close), `cashShortage` at September's close, `bankruptcy` at October's close | confirmed unchanged, static guardrail test |

### Explicit cost-truth audit (issue's own required section)

- **総務/バックオフィス人件費**: exists, ¥200,000/month, but is *bundled* into
  `baselineMonthlyExpenses`/`salaryPaid` in every monthly cash-flow summary —
  a player cannot distinguish admin payroll from engineer payroll anywhere
  in the UI today.
- **事務所家賃**: not a separate line item. It is folded into
  `otherMonthlyFixedCost` (¥50,000 aggregate, rent+utilities+etc.
  undifferentiated).
- **その他固定費**: only the same ¥50,000 aggregate constant; no further
  breakdown exists in code.
- **初期費用/初期現金**: ¥4,000,000, unconditional, unrelated to any
  "founding cost" concept (none exists).
- **採用媒体費**: ¥0 (free) / ¥100,000 (engineer).
- **研修費**: ¥30,000 flat (internal only — no external-training UI path
  exists in the Public Demo build).

No inferred/guessed line item was added. Per the issue's own instruction,
further breakdown of the ¥50,000 fixed-cost aggregate or of admin vs.
engineer payroll display is a **candidate follow-up issue**, not attempted
here (explicitly out of this issue's scope: "総務・家賃等の新しい会計カテゴリ追加").

## 3. Strategy definitions (Fresh Audit harness)

New harness: `test/game/public_demo/test_support/public_demo_strategy_bot.dart`
(`PublicDemoStrategyBot` + `PublicDemoStrategyPolicy`), driven by
`tool/simulate_public_demo_strategy_audit.dart`. Every strategy uses only
real, production `PublicDemoAggregate` commands — never a synthetic model —
exactly like the pre-existing `PublicDemoSeededPlaythroughBot` (#217/#218).

| Strategy | Recruit | Hiring selectivity | Training | Cash buffer | July-decline re-entry |
|---|---|---|---|---|---|
| **A. Conservative** | never | n/a | trains any below-threshold waiting engineer | ¥300,000 | yes |
| **B. Balanced** | once, May only | only offers if `salesSkillFit≥45` and `requestedSalary≤¥380,000` | trains any below-threshold waiting engineer | ¥300,000 | yes |
| **C. Growth** | every legal month (4–8, up to 5×) | none — accepts every offer the real evaluator would | trains any below-threshold waiting engineer | ¥150,000 (leaner) | yes |
| **D. Poor decisions** | every legal month (4–8, up to 5×) | none | **never trains** | **¥0 (no discipline)** | **no — declined assignments sit idle** |

## 4. Before/after — 300/2,000-seed sweep (Conservative/Balanced/Growth/Poor)

### 4a. Before any tuning (original main: rate ¥500,000, training ×1.2)

n=300, seeds 2000000–2000299:

| Strategy | reachedMarch | bankrupt | avgMinCash | avgFinalCash |
|---|---|---|---|---|
| Conservative | 100.0% | 0.0% | ¥60,000 | ¥660,000 |
| Balanced | 58.0% | 40.7% | −¥267,767 | ¥334,367 |
| Growth | 0.7% | 99.3% | −¥1,189,400 | −¥1,169,000 |
| Poor decisions | 1.0% | 99.0% | −¥1,306,833 | −¥1,292,533 |

**Finding**: hiring *at all* (Balanced) was already net-worse than never
hiring (Conservative), and any real hiring intensity (Growth) was an almost
certain loss — the opposite of the design target ("早期採用に将来売上を増やす
合理的メリットがある").

### 4b. After training-rate fix alone (rate still ¥500,000, training ×2.0)

Same sweep:

| Strategy | reachedMarch | bankrupt | avgMinCash | avgFinalCash |
|---|---|---|---|---|
| Conservative | 100.0% | 0.0% | ¥1,380,000 | ¥2,780,000 |
| Balanced | 65.3% | 34.0% | ¥494,333 | ¥1,946,133 |
| Growth | 4.7% | 95.3% | −¥1,030,733 | −¥828,167 |
| Poor decisions | 1.0% | 99.0% | −¥1,306,833 | −¥1,292,533 (unaffected — never trains) |

Meaningful improvement, but Balanced still loses more often than not, and
Growth is still an almost certain loss.

### 4c. After both tuning changes (rate ¥600,000, training ×2.0) — final

n=2,000, seeds 3000000–3001999:

| Strategy | reachedMarch | bankrupt | avgMinCash | avgFinalCash |
|---|---|---|---|---|
| Conservative | 100.0% | 0.0% | ¥1,680,000 | ¥4,480,000 |
| Balanced | **95.0%** | 5.0% | ¥933,725 | ¥4,102,165 |
| Growth | **33.9%** | 66.0% | −¥526,470 | ¥1,450,260 |
| Poor decisions | **16.6%** | 83.3% | −¥719,495 | −¥78,140 |

All design targets hold:

- Balanced reliably completes (95%).
- Conservative and Growth both have real, differentiated outcomes — neither
  a guaranteed win nor a guaranteed loss.
- Poor decisions is clearly worse than Growth despite the *same* recruiting
  aggressiveness (16.6% vs. 33.9% survival; −¥78,140 vs. ¥1,450,260 average
  final cash) — proving decisions beyond "how much you hire" matter.

## 5. Before/after — required seeds (0, 1, 42, 13, 666, 315, 2147483000)

### 5a. New `PublicDemoStrategyBot`, final tuned state

| Seed | Conservative | Balanced | Growth | Poor decisions |
|---|---|---|---|---|
| 0 | March, ¥4,480,000 | March, ¥920,000 | March, ¥4,290,000 | March, ¥830,000 |
| 1 | March, ¥4,480,000 | March, ¥2,370,000 | **bankrupt**, −¥470,000 | **bankrupt**, −¥860,000 |
| 42 | March, ¥4,480,000 | March, ¥870,000 | **bankrupt**, −¥1,060,000 | **bankrupt**, −¥1,420,000 |
| 13 | March, ¥4,480,000 | March, ¥6,280,000 | **bankrupt**, −¥190,000 | **bankrupt**, −¥550,000 |
| 666 | March, ¥4,480,000 | March, ¥4,380,000 | **bankrupt**, −¥860,000 | **bankrupt**, −¥1,190,000 |
| 315 | March, ¥4,480,000 | March, ¥1,430,000 | March, ¥5,150,000 | March, ¥960,000 |
| 2147483000 | March, ¥4,480,000 | March, ¥4,380,000 | **bankrupt**, −¥1,400,000 | **bankrupt**, −¥2,280,000 |
| **Survival** | **7/7** | **7/7** | **2/7** | **2/7** |

Exactly locked in `test/game/public_demo/public_demo_strategy_bot_regression_test.dart`.

### 5b. Original single-policy `PublicDemoSeededPlaythroughBot` (#217/#218's own
   "recruit once in May, accept everyone, train aggressively" bot —
   unchanged policy, only the economy under it changed)

| | Before (rate 500k, training ×1.2) | After (rate 600k, training ×2.0) |
|---|---|---|
| Seeds reaching March | **1/7** (only seed 13) | **6/7** (all but 2147483000) |
| Suzuki (eng-02) no-order streak | 6–8 months (varies, truncated by early bankruptcy on most seeds) | **exactly 4 months on every seed** — the issue's own "5か月連続no-orderは実質的に禁止" guardrail, previously a CONFIRMED VIOLATION on every required seed, is now satisfied on every required seed |

Exactly locked in `test/game/public_demo/public_demo_seeded_balance_regression_test.dart`.

## 6. Tuning parameters — before/after + rationale

Exactly two constants changed, each independently measured before deciding
the combination (§4a→4b→4c above shows the causal effect of each):

### 6a. `PublicDemoRevenue.ratePerAssignedEngineer`: ¥500,000 → ¥600,000 (+20%)

**Root cause measured**: with only Sato/Suzuki's own baseline cost
(¥800,000/month) and a flat ¥500,000/assigned-engineer revenue, a *single*
assigned engineer nets −¥300,000/month. Any hire compounds this: a hire's
own salary (¥260k–¥420k) plus the one-time ¥100,000 recruit cost is pure
cost for 1–2 months before that hire's first real order lands (recruit →
interview → pre-entry pipeline), landing squarely inside the company's
already-thin zero-revenue-adjacent cash trough (August–October). This is
why *every* hiring strategy (Balanced, Growth) bankrupted more often than
never hiring at all (Conservative) — the opposite of the design target.

Raising the rate narrows (but does not eliminate) this structural deficit
per assigned engineer and meaningfully widens the margin a hire needs to
recoup its own onboarding cost before the next cash trough. This is exactly
the "project unit price" lever the issue names as a candidate, and the
constant's own pre-existing doc already flagged it as provisional
("REVENUE-6 owns tuning it").

### 6b. `PublicDemoGrowthEngine` internal-training `sourceBase`: 1.2 → 2.0 (+67%)

**Root cause measured**: `floor(1.2 × potentialMultiplier × …)` never
exceeds 1 for *any* engineer in this build, regardless of
`growthPotential` (Suzuki's own growthPotential:4 — the second-highest
tier — only reaches 1.2×1.3=1.56, still floor 1). Getting Suzuki (capability
52) to the field-sales threshold (60) therefore took 8 straight monthly
training purchases — nearly the *entire* fiscal year — during which her
full salary was paid for zero output. Even the Conservative (never-hire)
strategy's own slack was almost entirely consumed by this single structural
fact (its own minimum cash before this fix: ¥60,000, i.e. razor-thin),
leaving no room for any other decision and contradicting the design target
("研修は「やらないとゲーム不能」ではなく、弱い社員を戦力化する選択肢").

Raising `sourceBase` to 2.0 lets growthPotential≥3 engineers (Suzuki
included) gain +2/month instead of +1 — halving Suzuki's time-to-threshold
to 4 months — while a genuinely low-potential hire (growthPotential≤1)
still only gains +1/month, keeping training a real, uneven trade-off rather
than a guaranteed fast fix.

**Levers considered and not changed** (named in the issue's own candidate
list, measured or reasoned about, rejected as unnecessary once both changes
above were combined): initial cash, recruitment cost, hire salary band,
fixed costs, sales capacity. Changing any of these further, once the
design targets in §4c already held, would have been unjustified — "一度に
多数を変更しない" / "変更ごとにSeed結果への因果を示す" is honored by stopping
at exactly the two changes whose individual and combined effect is shown in
§4 above.

## 7. Changed files

**Production (2 files, 2 one-line constant changes + doc)**
- `lib/game/public_demo/public_demo_revenue.dart`
- `lib/game/public_demo/public_demo_growth_engine.dart`

**New Fresh Audit harness**
- `test/game/public_demo/test_support/public_demo_strategy_bot.dart`
- `test/game/public_demo/public_demo_strategy_bot_regression_test.dart`
- `tool/simulate_public_demo_strategy_audit.dart`

**Existing tests updated for the new constants** (locked numeric
expectations recomputed from the real production formulas, never hand-waved
— every file's own diff shows the recomputed value and a comment citing
this issue):
- `test/game/public_demo/public_demo_monthly_close_revenue_test.dart`
- `test/game/public_demo/public_demo_revenue_state_test.dart`
- `test/game/public_demo/public_demo_revenue_payment_test.dart`
- `test/game/public_demo/public_demo_monthly_close_test.dart`
- `test/game/public_demo/public_demo_recovery_finance_test.dart`
- `test/game/public_demo/public_demo_monthly_close_ordinary_month_test.dart`
- `test/game/public_demo/public_demo_financial_status_test.dart`
- `test/game/public_demo/public_demo_balance_regression_test.dart`
- `test/game/public_demo/public_demo_monthly_cash_flow_test.dart`
- `test/game/public_demo/public_demo_cash_forecast_test.dart`
- `test/game/public_demo/public_demo_seeded_balance_regression_test.dart`
- `test/presentation/home/home_dashboard_data_wiring_test.dart`

**UI/widget tests whose fixture needed a real (not cosmetic) rework because
the exact scenario they drove no longer reaches the financial state they
test** (each file's own class doc now explains why, inline):
- `test/ui/public_demo/public_demo_01_assignment_carryforward_test.dart` —
  pendingRevenue figures recomputed (the scenario itself still bankrupts
  — no structural change needed).
- `test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart` — its
  original "single continuous Sato assignment" fixture no longer reaches
  cashShortage/bankruptcy at all under the new rate; rewritten to drive a
  genuine zero-revenue trajectory (nobody ever assigned), reaching the same
  real cashShortage→bankruptcy transition via September/October instead of
  February/March.
- `test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart` —
  same root cause; rewritten to spend real, wasted recruitment-media and
  (training, capped below Suzuki's own threshold) spend so the scenario
  still reaches a genuine terminal state (`marchCashShortageFailure`) by
  March, since this file specifically needs Suzuki to stay untrained.
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
  — same root cause as the bankruptcy UX file; rewritten to the zero-revenue
  trajectory; one pixel-budget assertion widened by 8pt at the narrowest
  supported width (360×800) with an inline explanation (see §8).
- `test/ui/public_demo/public_demo_01_home_cash_forecast_advice_test.dart`
  — the fixture's own documented "caller-chosen" one-time deficit constant
  bumped (¥100,000 → ¥900,000) so the 3-month forecast window still
  projects a real crossing to negative under the higher rate.
- `test/ui/public_demo/public_demo_01_suzuki_sales_reentry_test.dart` /
  `public_demo_01_suzuki_sales_yearend_boundary_test.dart` — both built
  their entire month-by-month narrative around the old +1/month training
  cadence; recomputed for +2/month (fewer training months needed, the
  "crosses the threshold" month moves earlier).

## 8. Unresolved findings / follow-up candidates (not fixed here)

1. **Revenue is flat per assigned engineer, independent of the real
   project's `monthlyRate`/rank/difficulty.** Matching quality currently
   only ever affects *whether* an order is won, never *how much* it is
   worth. A future pass could tie Revenue to the real project rate (the
   constant's own pre-existing doc already names this as
   "REVENUE-6owns tuning it" — out of this issue's minimal-change scope).
2. **30-day payment term is uniform** — `Client.paymentTermDays` (30 or 60
   for some sample clients) exists in the domain model but is never read by
   `PublicDemoRevenuePayment`. Pre-existing, unaffected by this issue, and
   explicitly out of scope ("30/60日siteを壊さない" — not "extend it").
3. **Sales capacity (4 slots/month)** becomes a real contention bottleneck
   once many hires exist simultaneously (Growth/Poor decisions) — it
   compounds their cash risk beyond pure salary/revenue math (delayed first
   orders extend the unproductive-salary window). Not changed here, per
   "一度に多数を変更しない"; a dedicated Matching/Sales-capacity issue could
   revisit it if Growth's viability needs to improve further.
4. **Admin payroll / fixed-cost breakdown** — confirmed in §2's cost-truth
   audit: the ¥200,000 admin salary is invisible to the player (bundled
   into payroll display), and the ¥50,000 fixed-cost aggregate has no
   rent/utilities breakdown. A genuine candidate for a dedicated accounting-
   detail issue, explicitly out of this issue's scope.
5. **`public_demo_01_issue_124_screen_verification_test.dart`'s viewport-fit
   tolerance** widened by 8pt at 360×800 (see §7) — a real, small (~6pt)
   content-height side effect: an engaged-but-not-yet-assigned sales-
   pipeline row renders marginally taller in 社員概要 than an actively-
   assigned row did, and reaching actual assignment would mean real
   Revenue, defeating the zero-revenue trajectory this fixture needs. A
   cosmetic polish candidate, not a balance defect.
6. **Training-rate floor for low-`growthPotential` hires**: only
   `growthPotential≥2` reaches the new +2/month tier; a low-potential hire
   still gets only +1/month. Intentional (keeps training an uneven
   trade-off), flagged for visibility.

## 9. Invariants re-verified

- Seeded determinism: `PublicDemoStrategyBot`/`PublicDemoSeededPlaythroughBot`
  runs are byte-identical on a second run (both regression files).
- Save/reload parity: untouched (no save-schema change).
- No double payroll/revenue/assignment: untouched production code paths
  (`PublicDemoMonthlyClose`, `PublicDemoRevenuePayment`) — only the rate
  constant and the growth-formula multiplier changed, never the
  settlement/booking logic itself.
- Joined-roster authority, #220 interview reachability, #222 post-May join
  lifecycle: untouched — confirmed by the full existing suite passing
  unchanged except for the files listed in §7.
- Month-close idempotency, 30/60-day receivable semantics, bankruptcy
  authority: untouched — confirmed by
  `public_demo_financial_status_test.dart`'s own guard-coverage tests
  passing (with only the one recomputed numeric literal noted in §7).

## 10. Test results

- Full existing suite (focused + full): see PR for the final CI run: a full
  `flutter test` pass (all suites) after every file in §7 was updated.
- New coverage: `public_demo_strategy_bot_regression_test.dart` (67 tests —
  determinism, required-seed exact-outcome locks, and the four qualitative
  design-target invariants from §4c/§5a).

## 11. Actual processing time / revised ETA

The issue's own estimate was 90–180 minutes. Actual elapsed time in this
session substantially exceeded that, for two environment-specific reasons
the estimate did not anticipate:

1. **No Flutter/Dart SDK was preinstalled in this session's container** —
   the Flutter 3.44.9 SDK (matching CI's own pin) had to be downloaded and
   installed before any harness could run at all.
2. **`PublicDemoRevenue.ratePerAssignedEngineer` is referenced by literal
   value across ~15 test files** (monthly close, revenue payment, cash
   forecast, cash flow, financial status, and several UI widget-playthrough
   fixtures) — recomputing each literal correctly, and for several UI
   fixtures, discovering and re-engineering a still-valid path to the
   financial state each test specifically needs to exercise, was the
   dominant share of the actual time, well beyond the issue's own "tuning
   implementation + regression: 45–90 min" estimate for a 2-constant
   change.

The Fresh Audit, strategy harness design, and tuning-decision work itself
(§2–§6) fit inside the original estimate; the regression-suite update
(§7) is what extended it.
