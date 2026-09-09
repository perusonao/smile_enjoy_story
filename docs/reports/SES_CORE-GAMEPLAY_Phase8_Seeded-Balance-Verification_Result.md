# SES CORE-GAMEPLAY Phase 8: Seeded Balance Verification — Result Report

Issue: [#217](https://github.com/perusonao/smile_enjoy_story/issues/217)
PR: [#218](https://github.com/perusonao/smile_enjoy_story/pull/218)
Base branch: `main`
Working branch: `claude/issue-217-m7d5jb`
BASE SHA: `3423c5643bdbb0878b9688a85d3176e4b7b5037b` (PR #216 merge, `origin/main` HEAD at task start — confirmed via `git fetch origin main` before any work began, matching the value the issue itself records)
Reviewed HEAD at P1-fix start: `c9819b96375d387c5d41055fd62f0ee28b64630c` (PR #218's Codex 1st-review HEAD)
Final HEAD SHA: the single fix/tests/report commit this pass pushes onto `claude/issue-217-m7d5jb` (see PR #218's own commit list for its exact hash — noted here without self-reference, since a commit cannot name its own hash in its own content)

**Actual processing time (original Phase 8 pass):** ~2 hours (see §8 for the Flutter SDK install cost).
**Actual processing time (this P1-fix pass):** ~50 minutes (root-cause confirmation → fix → re-measurement of 7 required seeds + 2,000-seed sweep → 4 new focused regression tests, including debugging two ordering bugs in the new tests themselves → full `test/game/public_demo/` + full suite + analyze → report rewrite), against the issue's 10–25 minute estimate — the overrun is almost entirely the 2,000-seed sweep + full-suite re-verification the fix's own severity (§0) warranted, not scope creep.

## 0. Codex P1 fix (PR #218, this pass) — READ FIRST, invalidates most of the original numbers below

Codex's 1st review of PR #218 found a real bug in the Phase 8 **bot** (never in production/game code): `PublicDemoSeededPlaythroughBot`'s May-close handler computed `monthlyExpenses` **once**, from a snapshot of applicants taken **before** `closeMay` actually joined them (`hasJoined == false` at that moment). `PublicDemoSalary.currentMonthlySalaryFor` requires `hasJoined` to return a salary at all (`lib/game/public_demo/public_demo_salary.dart:43`) — a pre-join snapshot silently contributes **¥0** per hire. That wrong, ¥0-hire-inflated `monthlyExpenses` value was then reused unchanged for every month from June through March, so **no May hire's salary was ever actually deducted for the rest of the fiscal year, in the original Phase 8 measurement.**

**Fix:** replaced the single cached `monthlyExpenses` local with `_monthlyExpensesFor(PublicDemoAggregate)`, called fresh immediately before every single month-end close (April through March) — always derived from that moment's real, authoritative `workflow.joinedApplicants`, via the exact same production `PublicDemoSalaryFinance.monthlyExpenses` formula every other Public Demo fixture already uses (no bot-authored substitute). April/May's own close still correctly charges nobody yet (`joinedApplicants` is genuinely empty until `closeMay` runs the join internally) — only June onward now correctly reflects real payroll.

**Impact is severe and confirmed by re-measurement (§4.3, §5, §6 below, all rewritten from the corrected re-run):** with real payroll now deducted, bankruptcy under this bot's own unchanged hiring policy jumps from 16.4% to **60.1%** across the 2,000-seed sweep, and 6 of the 7 required seeds now go bankrupt (only seed 13 still reaches March) — see §0a for the full before/after table. **Every quantitative figure in the original version of this report (final cash, bankruptcy rate, First-Fun-Year completion rate, exact per-seed cash checkpoints) was wrong and is superseded below; none of it is preserved as-is anywhere in this file.** The 3 structural/qualitative findings from the original pass (§4.1 seed-1 April Matching gap, §4.2 post-May recruitment dead end, §4.4 the two intact guardrails) are unaffected by this bug — they never depended on `monthlyExpenses` — and remain valid unchanged.

No production/game code changed to fix this — `test/game/public_demo/test_support/public_demo_seeded_playthrough_bot.dart` is the only file with a behavioral change. Two ordering bugs in the *new* regression tests themselves (accepting a May offer before `closeApril`, which mints a stale `PublicDemoFiscalCloseId` and silently fails the join — a real, separate footgun this pass's own test-writing caught) were found and fixed in the same pass; see §9.

### 0a. Before / after (the fix's own effect, all other variables held constant)

| Metric | Before this fix (original report) | After this fix (this report) |
|---|---|---|
| 2,000-seed First Fun Year reach rate | 83.7% | **39.8%** |
| 2,000-seed bankruptcy rate | 16.4% | **60.1%** |
| 2,000-seed March cash-shortage failure rate | 0.0% | 0.1% |
| Required seeds reaching March (of 7) | 5/7 | **1/7** (seed 13 only) |
| Seed 13 final cash | ¥5,060,000 | ¥1,560,000 |
| Seed 1 outcome | reaches March, ¥4,260,000 | **bankrupt month 9**, -¥720,000 |

## 1. Summary

This is a READ/TEST-primarily verification pass, per the issue's own scope instruction. No baseline-expense, revenue, 30-day-lag, salesCapacity, bankruptcy-grace, capability-threshold, initial-profile, project-generator, or Matching-formula value was changed — in either the original Phase 8 pass or this P1-fix pass. The P1 fix (§0) is entirely inside the bot's own test-support code.

To measure the guardrails, this phase (original pass) added:

- `test/game/public_demo/test_support/public_demo_seeded_playthrough_bot.dart` — a deterministic, non-UI "rational player" bot that drives the real `PublicDemoAggregate` command API (the same commands `public_demo_balance_regression_test.dart` and the UI success-playthrough test already use) through a complete April→March year, for any `runSeed`. **This pass fixed a real payroll-accounting bug in it — see §0.**
- `test/game/public_demo/public_demo_seeded_balance_regression_test.dart` — now 31 focused, CI-covered regression tests: reproducibility and characterization of the bot's playthrough for the issue's 7 required seeds, the two static guardrail facts (Sato/Suzuki capability, zero-revenue runway), a per-seed check of the April Matching-fit guardrail against the real project generator, a reproduction of a confirmed structural finding (§4.2), and (new this pass) 4 focused tests directly exercising the fixed `monthlyExpenses` recomputation against real production Finance authority (§9).
- `tool/simulate_public_demo_seeded_balance.dart` — a `dart run` sweep script (mirrors the existing `tool/simulate_balance_report.dart` pattern) for a broad, non-CI statistical measurement (2,000+ seeds in ~4 seconds).

**Headline result, after the P1 fix: the same two confirmed guardrail-violation findings as before (§4.1, §4.3 — §4.3's own numbers are re-measured and, if anything, more severe), the same confirmed structural gap (§4.2), the same confirmed-intact guardrail pair (§4.4), PLUS a newly-surfaced, correctly-measured-for-the-first-time finding: real payroll costs make this bot's (unchanged) hiring policy financially unsustainable in the majority of playthroughs (§4.5, new this pass).** No production balance/generator/Matching/Growth formula was changed in this pass either — per the fix-task's own explicit instruction, §4.5 is reported, not fixed.

## 2. Bot methodology and scope (read first — governs how to read every number below)

The bot (`PublicDemoSeededPlaythroughBot.run(seed)`) plays a single, fixed, "informed rational player" policy:

- Every engineer works the pre-existing **generic** sales pipeline (`startSkillSheetReview` → `beginSelling` → `introduceProject` → partner interview → client interview → `recordOrder`) — free steps run to a fixed point every month, then the month's real `salesCapacity` (4 slots/month, unchanged) is spent on the highest-priority slot-costing action.
- Recruits exactly once, in May (`PublicDemoRecruitmentMedium.engineer`), and walks every generated applicant through the real hire/pre-entry pipeline within the same shared slot budget.
- Trains any waiting, unassigned engineer below the field-sales capability threshold (60) every month via `selectInternalTraining` (¥30,000, real production command).
- Decides July continuation in June via the real, pure `PublicDemoAssignment.willOfferNextMonthFor`/`decideOrder`/`acceptOrder` sequence, then releases any declined continuation via `endAssignment` (Phase 7A's real end→available→re-entry lifecycle).
- Picks up any waiting engineer who lands a fresh order in the month-7–14 window via the real `recoverAssignment` (RECOVERY-LOOP-1).

**What this bot deliberately does NOT do**, and why that matters for reading the numbers below:

1. **It never uses the Phase 5/6 Matching + Project Interview flow** (`proposeMatch`/`startProjectInterview`/`chooseProjectInterviewFollowUp`/`concludeProjectInterview`). It always uses the generic interview path — the same path every pre-existing Public Demo balance fixture (`public_demo_balance_regression_test.dart`) and the UI success-playthrough test already use. **This is the reason April/May cash is byte-identical across every one of the 7 required seeds** (`¥3,170,000` / `¥2,240,000`, confirmed by regression test): the generic path's `PublicDemoInterviewEvaluator.evaluate` scores purely from the engineer's own fixed `PublicDemoInterviewProfile` + current `actualCapability` — it never reads project data, so a founding engineer's April/May order outcome never depends on `runSeed` at all. To still exercise the **project-generator/Matching side** of Controlled Randomness for the required seeds, §4.1 below checks the real `PublicDemoEngineerProjectFit`/`PublicDemoMatchingProspect` output directly, independent of the bot.
2. **It never recruits after May.** §4.2 explains why: it is a confirmed, real dead end, not a policy choice.

Both scope boundaries are documented in the bot file's own class doc, not just here.

## 3. Two real bot-logic bugs caught and fixed before measurement (methodology honesty)

Building the bot surfaced two bugs in the bot itself — not the game — both caught by the first seed-sweep run producing implausible, seed-invariant results (a red flag: real Controlled Randomness should vary by seed) and root-caused before any guardrail measurement was trusted:

1. **Futile immediate retry.** `PublicDemoInterviewEvaluator.evaluate` is a pure function of fixed inputs — a failed partner or client interview is *guaranteed* to fail again if retried the same month (nothing about the inputs changed). The bot's first version let the free `beginSelling`→`introduceProject` cycle send a just-failed engineer straight back to `introduced`, where the slot-spender would burn the whole month's `salesCapacity` re-attempting the identical guaranteed failure — starving every other candidate that month. Fixed with a per-month "already attempted and failed" set (both the partner-interview-fails and the partner-passes-but-client-fails cases), so a real retry only happens in a later month, after training/Growth has actually changed `actualCapability`.
2. **Training only wired in from July.** The bot's first version only called `selectInternalTraining` from month 7 onward, leaving April–June's three months of Suzuki's own capability growth on the table for free. Fixed by training every month from April.

Both fixes are visible in the bot file's own doc comments at the exact code they fixed, and both are what make the seed sweep below trustworthy. Neither bug affected the domain/game code itself.

## 4. Findings

### 4.1 CONFIRMED — seed 1 has zero April Matching-fit-viable projects for Sato (guardrail violation, Controlled-Randomness-driven)

The issue's own guardrail: *"April は初期の実用可能な佐藤に適合する案件が最低1件存在すること"*. Checked directly against `PublicDemoSeededProjectGenerator.forMonth(runSeed:, month: 4)` → `PublicDemoEngineerProjectFit.compute(runtime: satoRuntime, project:)`.prospect, for all 7 required seeds:

| Seed | April candidates | Non-`low` prospect for Sato |
|---|---|---|
| 0 | 4 | 1 |
| **1** | **4** | **0 — VIOLATION** |
| 42 | 4 | 3 |
| 13 | 4 | 3 |
| 666 | 4 | 3 |
| 315 | 4 | 1 |
| 2147483000 | 4 | 2 |

For seed 1, all 4 of April's generated project candidates rate `PublicDemoMatchingProspect.low` for Sato — zero candidates a Matching-informed player would consider viable. This is a genuine Controlled-Randomness finding: the project generator, for this specific seed, happens to produce a April slate with no good fit.

**Impact is bounded, not a dead end.** The generic (pre-Matching) interview path Sato also has access to does not consult project data at all, so Sato still wins an April order under it regardless (confirmed: seed 1's bot playthrough has Sato's no-order streak = 0, same as every other required seed). The violation is specific to a player who is using the newer Matching + Project Interview flow (Phase 5/6) for their April decision — for that player, seed 1 genuinely offers nothing attractive.

**Reproduction:** `test/game/public_demo/public_demo_seeded_balance_regression_test.dart`, group `"April Matching-fit guardrail per required seed (CONFIRMED FINDING)"`.

**Recommendation (not applied — outside this Issue's minimal-change scope, and the project generator is on the issue's own do-not-touch list):** file a follow-up to decide between (a) accepting this as within-tolerance variance (1 in 7 sampled seeds, not the majority), or (b) a small floor in the April slot of `PublicDemoSeededProjectGenerator` guaranteeing at least one non-`low`-for-founding-Sato candidate — a generator-formula change that needs its own scoped Issue and evidence review, exactly per this Issue's own restriction.

### 4.2 CONFIRMED — post-May recruitment is a structural dead end (real cash/slot cost, zero possible return)

Not a Controlled-Randomness finding — **fully deterministic, reproduces on every seed identically.** `PublicDemoState.isRecruitmentMediaWindowMonth`/`canUseRecruitmentMediaInMonth` allow one `recruit()` purchase per month for April–August (and the Sales tab UI, per its own PR #210 merge-blocker doc comment, deliberately shows this for May–August, framed as "the domain already allows *later* recruitment"). But `PublicDemoWorkflowState.joinAndKeepOnly`/`withJoinedEngineers`/`assignOrderedForMay` — the only production code that ever converts an applicant into an `engineer` or builds an assignment from one — are called from exactly one place: `PublicDemoAggregate.closeMay`.

**Direct reproduction** (also encoded as a regression test): recruit in August, walk the generated applicant through `completeInterview` → `acceptOffer` → the full pre-entry pipeline → `recordPreEntryClientInterviewResult` → `recordJuneOrder`. Every real precondition passes; the applicant genuinely reaches `PublicDemoApplicantStage.juneOrdered` (an "order won"). `applicant.hasJoined` is `false` and stays `false` forever — `closeOrdinaryMonth` afterward leaves `workflow.engineers` at its prior count and `workflow.assignments` empty. The ¥100,000 recruitment cost and every sales slot spent on that applicant's interviews are real, permanent losses for zero possible return.

**Impact:** any player who recruits after May (which the UI actively invites them to do, May through August) is spending real cash and real sales-slot budget on candidates who can never be staffed. This directly bears on the issue's "初回参画時期"/"参画人数" verification items — Public Demo 0.1's effective headcount is capped at "founders + May's hire(s)" for the entire fiscal year, regardless of player effort in June–August.

**Reproduction:** `test/game/public_demo/public_demo_seeded_balance_regression_test.dart`, group `"post-May recruitment structural dead end (CONFIRMED FINDING)"`.

**Recommendation (not applied — a real feature gap, not a minimal balance tweak; needs its own scoped Issue):** either (a) generalize `joinAndKeepOnly`/`assignOrderedForMay`-equivalent logic to run at every month-end close so a later hire can actually join (the larger, more correct fix — likely what the PR #210 UI decision assumed already worked), or (b), as a minimal stopgap, narrow the recruiting window/UI back to May only until (a) is built, so the game never invites a purchase that cannot pay off.

### 4.3 CONFIRMED — Suzuki's no-order streak structurally exceeds the guardrail in every playthrough (deterministic, not seed-driven)

The issue's own guardrail: *"5か月連続 no-order は実質的に禁止"* / *"4か月連続 no-order が5%以上にならないこと"*.

Suzuki (`eng-02`) starts at `actualCapability = 52` against the field-sales/interview requirement of `60` (confirmed unchanged — see §4.4). The generic client-interview score formula for Suzuki's fixed profile (`humanity=66, morale=64, clientTrust=55`) needs `actualCapability >= 59` to clear 60 points (`(actualCapability*50 + 1320 + 640 + 1100)/100 >= 60`). `PublicDemoGrowthEngine._capabilityDelta`'s `internalTraining` source (`1.2 * potentialMultiplier`, `.floor()`'d) evaluates to **exactly +1 capability per month** for Suzuki's `growthPotential: 3` profile (`1.2 * 1.15 = 1.38 → floor → 1`) — and no combination of morale/ability multipliers this engine models can push a non-`fastLearner` engineer's *training* growth past +1/month (see the bot's own doc comment for the arithmetic). Reaching capability 59 from 52 therefore takes a **minimum of 7 real months of training**, regardless of cash spent or player skill — the growth formula, not chance, is the bottleneck.

**Measured result, all 7 required seeds, RE-MEASURED after the §0 P1 fix (and confirmed via a re-run 2,000-seed sweep — Suzuki's own figure is identical every time, since none of Suzuki's path touches the seeded project/recruitment generators at all):**

- Suzuki's longest no-order streak is **still exactly 8 consecutive months (April–November) wherever the company survives long enough to show the full structural minimum** — confirmed unchanged on seed 13, the one required seed that still reaches March after the fix. On the other 6 required seeds, the now-correctly-modeled bankruptcy (§0a) cuts the company off at month 9–10, **truncating the OBSERVED streak to 6 or 7 months** — not because Suzuki's own path changed at all, but because there is no company left to keep counting. Either way, every one of the 7 required seeds still shows a streak **≥ 6 months**, still a confirmed violation of the "5か月連続禁止" guardrail.
- Across the re-run 2,000-seed sweep: Suzuki has a ≥5-month streak in **2,000/2,000 (100%)** of playthroughs — unchanged from before the fix (Suzuki's own path was never affected by the payroll bug). May-hired engineers who don't land a June order also frequently hit this: **1,271/3,347 (38.0%)** of them separately show a ≥5-month streak (down slightly from 38.3% pre-fix — some now-earlier bankruptcies truncate a few of THEIR streaks too, below what they'd have reached). Aggregate across every engineer-playthrough in the sweep: **≥4-month streak 44.7%, ≥5-month streak 44.5%** (both essentially unchanged from the pre-fix 44.7%/44.7%) — still roughly **9x** the issue's own "<5%" bar for the 4-month case.

This remains the headline structural finding of this verification pass, **unchanged in substance by the P1 fix**: it is not a rare, seed-driven edge case — it is the default, guaranteed outcome for the second founding engineer, every single time. It squarely matches the issue's own description of what Phase 8 exists to catch ("理不尽な詰み / 過度な一本道"), even though the root cause here is a fixed formula rather than an unlucky seed. The fix does add one new wrinkle worth naming precisely: because most seeds now go bankrupt before Suzuki would have finished the 8-month climb anyway (§4.5), Suzuki's slow growth path is, in most now-realistic playthroughs, moot — the company fails for an entirely different, faster-acting reason (real payroll cash burn) before Suzuki's own problem ever gets to matter on its own.

**Reproduction:** `test/game/public_demo/public_demo_seeded_balance_regression_test.dart`, group `"required-seed playthrough"`, test `"Suzuki (eng-02) has a >=6-month no-order streak..."`; broader sweep via `tool/simulate_public_demo_seeded_balance.dart`.

**Recommendation (not applied — `PublicDemoGrowthEngine`'s formula is exactly the kind of "既存バランスガード" value this Issue's own scope says not to change without a dedicated before/after review):** candidates for a follow-up Issue to evaluate: raise `internalTraining`'s `sourceBase` enough that a non-`fastLearner` engineer's floor lands on `+2`/month (roughly halves the wait); let a below-threshold engineer take a reduced-scope/junior assignment (real `source: assignment` Growth is `2.0` base — 2x training's rate — but nothing currently allows an under-60 engineer to be assigned at all); or explicitly re-confirm 8 months is acceptable and adjust the guardrail's own documented tolerance instead. All three are genuine design decisions, not "minimal fixes." Given §4.5, this recommendation should be evaluated together with the payroll-risk finding, not in isolation — Suzuki's slow start compounds the same-cash-flow problem, it does not cause it alone.

### 4.4 CONFIRMED INTACT — the two guardrails this phase did not find broken (unaffected by the P1 fix — neither depends on `monthlyExpenses`/hiring)

- **Sato/Suzuki initial capability** (`鈴木 actualSkill 52 / requirement 60`): confirmed unchanged — `publicDemoInitialEngineerRuntimes` still authors Sato at 78, Suzuki at 52, against `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement == 60`.
- **"ゼロ売上でも約6か月は耐えられる経済設計"**: confirmed intact by direct check (no bot needed — nobody ever assigned, real baseline expenses, every month closed for real). Cash stays ≥ 0 through August (5 full months from April), enters `cashShortage` in September (month 6), and reaches terminal `bankruptcy` only at the October close (month 7) — a faithful match for "about 6 months."

### 4.5 NEW THIS PASS — real payroll cost makes this bot's (unchanged) hiring policy financially unsustainable in most playthroughs

This finding only became visible once the P1 fix (§0) started actually deducting May hires' salaries — it was invisible under the original, bugged measurement (every May hire was accidentally free).

The bot's hiring policy (unchanged by this pass, and explicitly unmodified per this fix task's own instruction: *"production balance formulaはこのPRでは変更しない"*) accepts every May applicant `PublicDemoSalaryOfferEvaluator` says would accept — 1 or 2 new hires in 98% of playthroughs (§6), each adding ¥300,000–¥410,000/month in real payroll on top of the ¥800,000 baseline. Combined with two already-confirmed facts this report established independently (§4.2: nobody hired after May can ever be productive; §4.3: a meaningful share of May hires — and Suzuki structurally, always — take many months to land any revenue-generating order at all), this payroll commitment is frequently not matched by revenue in time: **bankruptcy jumps from 16.4% to 60.1%** across the 2,000-seed sweep purely from correctly deducting real salaries (§0a), with no other variable changed.

**This is not itself presented as a proven production balance defect** — it is a direct, mechanical consequence of pairing a real Finance formula with a specific, simple, "accept every affordable willing hire" policy that was never validated as representative of real play, and the issue's fix-task instruction explicitly excludes changing any balance formula in this pass. It is reported, per that instruction, as a genuine new signal worth a follow-up look: either (a) a more selective/conservative real-player hiring heuristic would likely show materially lower bankruptcy (worth measuring with a second bot policy in a future phase), or (b) if a reasonably cautious real player would ALSO hire similarly (Public Demo 0.1 gives no in-game financial forecast tool beyond `PublicDemoCashForecast`, which this bot does not consult), the ¥300,000+/month cost of a hire who may not produce revenue for months is a real, first-class First Fun Year risk the existing balance guardrails do not explicitly cover ("ゼロ売上でも約6か月は耐えられる" only covers the *baseline* no-hire case, not a company carrying extra payroll from an unproductive hire).

**Recommendation (not applied):** a follow-up Issue should (1) build a second, more conservative bot policy (e.g., only hire if `PublicDemoCashForecast` shows a safe post-hire runway) and re-measure, to separate "this specific naive policy is unsustainable" from "May hiring is unsustainable for any reasonable player," and (2) if the latter holds, treat it as a genuine First Fun Year balance risk alongside §4.3.

## 5. Seed-by-seed results (required guardrail seeds) — RE-MEASURED after the §0 P1 fix

All 7 seeds still reach `PublicDemoAggregate.toJson()`-byte-identical results on a second run with the same seed (reproducibility re-confirmed after the fix, both via the bot's own two-run check and a separate standalone probe run).

| Seed | Reached March | Terminal status | May hires joined | Final cash | Sato no-order streak | Suzuki no-order streak |
|---|---|---|---|---|---|---|
| 0 | ❌ | bankruptcy (month 10) | 1 | -¥1,140,000 | 0 | 7 |
| 1 | ❌ | bankruptcy (month 9) | 2 | -¥720,000 | 0 | 6 |
| 42 | ❌ | bankruptcy (month 9) | 2 | -¥960,000 | 0 | 6 |
| **13** | **✅** | — | 1 | ¥1,560,000 | 0 | 8 |
| 666 | ❌ | bankruptcy (month 10) | 1 | -¥1,240,000 | 0 | 7 |
| 315 | ❌ | bankruptcy (month 10) | 2 | -¥790,000 | 0 | 7 |
| 2147483000 | ❌ | bankruptcy (month 9) | 2 | -¥1,660,000 | 0 | 6 |

First Fun Year reach rate for these 7 seeds: **1/7 (14.3%)**, down from 5/7 (71.4%) pre-fix — lower than the broader sweep's 39.8% because 7 samples is a small, unrepresentative slice; see §6 for the statistically meaningful figure. Every seed that now goes bankrupt does so at month 9 or 10 (August/September close) — the exact window where correctly-deducted May-hire payroll first starts compounding against baseline expenses (§4.5).

## 6. Broader statistics (non-CI sweep, 2,000 seeds, `tool/simulate_public_demo_seeded_balance.dart`)

**Re-run after the §0 P1 fix** (same 2,000 seeds, same seed range, same bot policy — only the payroll-deduction bug is different):

```
=== CORE-GAMEPLAY Phase 8 seeded balance sweep (n=2000, seeds 5000000-5001999) ===
First Fun Year reached (fiscalYearCompleted):   795/2000  (39.8%)
Bankruptcy:  1202/2000  (60.1%)
March cash-shortage failure:     3/2000  (0.1%)
```

(Pre-fix, for direct comparison: 1673/2000 (83.7%) reached / 327/2000 (16.4%) bankrupt / 0/2000 (0.0%) March-shortage — see §0a.)

- **Bankruptcy rate 60.1%** (up from a pre-fix 16.4% that never actually charged May-hire payroll) is the corrected, trustworthy figure under this bot's specific hiring policy — see §4.5 for why this is reported as a new finding, not asserted as a proven balance defect: this bot's policy hires up to 2 May applicants unconditionally whenever `PublicDemoSalaryOfferEvaluator` says they'd accept, which now correctly raises fixed monthly payroll without a guaranteed matching increase in orders (per §4.3, a meaningful fraction of hires never land an order at all). A more selective/conservative hiring policy would likely show a materially lower bankruptcy rate; this number characterizes "hire everyone affordable and reasonably keen," not an optimal player, and should be read as an upper bound on real-player bankruptcy risk under real payroll accounting, not necessarily the true rate for every reasonable player.
- **April/May cash is still identical across every sampled seed** (`¥3,170,000` / `¥2,240,000`, unchanged from pre-fix) — see §2's scope note for why (the generic interview path never reads seeded project data, and May's own close still correctly charges nobody yet — §0's fix only changes June onward).
- **Month 6 cash spread is now much wider**: min ¥1,090,000 / p10 ¥1,140,000 / median ¥1,190,000 / max ¥1,910,000 (¥820,000 spread — up sharply from a pre-fix ¥60,000 spread that was itself an artifact of the bug never charging real payroll). This is expected and correct: June is the first month a real May hire's salary is deducted, so the spread now genuinely reflects 0-vs-1-vs-2 hires (§4.5), not an accident of the bug. It no longer stays inside the issue's own "±100〜200万円" 4–6-month tolerance band as cleanly as the pre-fix (buggy) number appeared to — worth folding into the §4.5 follow-up's own review.
- **No-order streak**: ≥4-month 44.7%, ≥5-month 44.5% (n=7,347 engineer-playthroughs) — essentially unchanged from pre-fix (44.7%/44.7%); see §4.3.
- **May hiring**: unchanged from pre-fix (this axis has nothing to do with payroll deduction) — 2 applicants generated and both hired in 69.7% of seeds, 1 in 28.0%, 0 (generation failure or unaffordable) in 2.4%.

## 7. Files changed

| File | Change (original Phase 8 pass) | Change (this P1-fix pass) |
|---|---|---|
| `test/game/public_demo/test_support/public_demo_seeded_playthrough_bot.dart` | New. The deterministic non-UI playthrough bot (§2). | **Modified — the actual P1 fix (§0):** replaced the single cached `monthlyExpenses` local with `_monthlyExpensesFor(aggregate)`, called fresh before every month-end close from `workflow.joinedApplicants`. |
| `test/game/public_demo/public_demo_seeded_balance_regression_test.dart` | New. 27 focused tests. | **Modified:** added 4 new focused tests directly exercising the fix against real production Finance authority; updated the required-seed exact-outcome table (§5) and the Suzuki-streak test to the re-measured, corrected values (31 tests total). |
| `tool/simulate_public_demo_seeded_balance.dart` | New. Non-CI sweep CLI (dev-only, mirrors `tool/simulate_balance_report.dart`'s existing pattern). | Unchanged this pass — re-run only, not edited. |
| `docs/reports/SES_CORE-GAMEPLAY_Phase8_Seeded-Balance-Verification_Result.md` | New. This report. | **Rewritten** with the P1 fix, before/after data, and the new §4.5 finding — no original quantitative figure is preserved as-is (§0). |

No `lib/` file was changed, in either pass.

## 8. Environment note

This remote execution environment ships with no Flutter/Dart toolchain pre-installed (`flutter`/`dart` are not on `PATH`, and no SDK exists anywhere on disk). Flutter 3.44.9 (the exact version every `.github/workflows/*.yml` in this repo pins via `subosito/flutter-action`) was installed via a shallow `git clone --branch 3.44.9` into `/opt/flutter-sdk` before any test could run. This is a one-time environment setup cost reflected in §"Actual processing time" above, not a repository change — nothing under `docs/` `session-start-hook`-related or in `.claude/` was touched by this phase, and a future session in a fresh container will need to repeat this same one-time install unless a `SessionStart` hook is added separately (out of this Issue's scope).

## 9. Tests

### `public_demo_seeded_balance_regression_test.dart` — now 31/31 passing (27 original + 4 new this pass)

New this pass — `"monthlyExpenses recomputation regression (Codex P1 fix, PR #218)"` group, exercising the fix directly against real production `PublicDemoAggregate`/`PublicDemoSalaryFinance` (independent of the bot's own emergent play):

- No May hire → recomputed June expenses equal exactly the baseline.
- One May hire → recomputed June expenses increase by exactly that hire's own accepted salary; May's own close (the month they joined) is unaffected — locked against the same runSeed-46 fixture value (`¥1,120,000`) `public_demo_balance_regression_test.dart` already established.
- Two May hires → both are included.
- An applicant whose offer is never accepted → contributes nothing (never joins).

While writing these, two real ordering bugs were caught and fixed in the test code itself (never production code): accepting a May offer *before* calling `closeApril` mints the offer's `PublicDemoFiscalCloseId` for the wrong month, which `PublicDemoJoinTransaction.join`'s own "stale fiscal close" guard then silently rejects at `closeMay` — the join never happens and the test's own `joinedApplicants` assertion catches it immediately (`Bad state: No element` / an empty list where a hire was expected). Fixed by recruiting before `closeApril` but deferring the interview/offer to after it (mirroring `public_demo_balance_regression_test.dart`'s own established fixture ordering exactly).

Retained from the original pass, all re-verified green (now reflecting the corrected data — see §5's per-seed table and §4.3):

- Static guardrail facts: Sato/Suzuki initial capability (2 tests, including the zero-revenue-runway check) — unaffected by the fix, unchanged.
- April Matching-fit guardrail per required seed (7 tests — unaffected by the fix, unchanged).
- Post-May recruitment structural dead end reproduction (1 test — unaffected by the fix, unchanged).
- Required-seed reproducibility (7 tests — re-verified still byte-identical on a second run after the fix).
- Required-seed exact-outcome characterization (7 tests — **all 7 values updated** to the re-measured, corrected figures; §5).
- April/May cash seed-invariance (1 test, all 7 seeds — unaffected by the fix, unchanged values).
- Sato always-zero-streak (1 test, all 7 seeds — unaffected by the fix, unchanged).
- Suzuki's no-order streak (1 test, all 7 seeds — **rewritten from a single flat expected value of 8 to a per-seed table** of 6-8, since the now-correctly-modeled bankruptcy truncates the observed streak below the true structural minimum on 6 of the 7 seeds; §4.3).

### Regression suites re-run (all green)

- `flutter test test/game/public_demo/ --concurrency=6`: **763/763 passing** (759 pre-existing/original-pass + 4 new this pass; every pre-existing Public Demo domain test — assignment lifecycle, recovery, growth, matching, project interview, cash forecast, binding offer, save codec, and more — passes unchanged).

### Full suite / static checks

- `flutter analyze` (whole repo): **No issues found.**
- `flutter test --concurrency=6` (full suite): **2073/2073 passing** (2069 pre-existing/original-pass + 4 new this pass).
- `git diff --check`: clean (no whitespace errors).

## 10. Known limitations

- The bot (§2) never exercises the Phase 5/6 Matching + Project Interview flow for engineer-side order outcomes — only the April project-generator/Matching-fit data itself was checked directly (§4.1) for that axis of Controlled Randomness. A future Phase could add a second bot policy that uses `proposeMatch`/`startProjectInterview` instead, to measure the guardrails from that flow's own perspective.
- The bot's hiring policy (accept every May applicant `PublicDemoSalaryOfferEvaluator` says would accept) is deliberately simple, not optimized — §6's bankruptcy-rate figure (now correctly reflecting real payroll: 60.1%) should be read as an upper bound for THIS policy, not the balance's true worst case or typical real-player case. See §4.5.
- No balance-formula change was made for any of the 4 confirmed/new findings (§4.1–4.3, §4.5) — each needs its own scoped follow-up Issue per this Issue's explicit "minimal change, protected formulas" restriction, restated identically in this pass's own fix-task instructions.

## 11. Unresolved blockers

None — the verification (and this P1 fix) both completed; findings §4.1, §4.2, §4.3, and the new §4.5 are explicitly deferred to follow-up Issues per §4's own recommendations, not blockers to closing this one or merging PR #218.

## 12. PR

[#218](https://github.com/perusonao/smile_enjoy_story/pull/218) — this P1 fix is pushed directly onto the same branch (`claude/issue-217-m7d5jb`) that PR already tracks. No new PR was opened, per this fix task's own explicit instruction ("新しいPRは作らない"), and no `@codex review` is re-requested, per the same instruction — focused/full tests plus GitHub CI are this fix's own merge gate.
