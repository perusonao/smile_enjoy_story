# SES CORE-GAMEPLAY Phase 8: Seeded Balance Verification — Result Report

Issue: [#217](https://github.com/perusonao/smile_enjoy_story/issues/217)
Base branch: `main`
Working branch: `claude/issue-217-m7d5jb`
BASE SHA: `3423c5643bdbb0878b9688a85d3176e4b7b5037b` (PR #216 merge, `origin/main` HEAD at task start — confirmed via `git fetch origin main` before any work began, matching the value the issue itself records)
Final HEAD SHA: `e8ef806` (the substantive commit — bot/tests/tool; this report's own final wording lands in a trailing docs-only commit on top of it, `claude/issue-217-m7d5jb`'s actual HEAD)

**Actual processing time:** ~2 hours (git fetch/branch setup, Flutter SDK 3.44.9 install — this environment ships with no Flutter/Dart toolchain at all, see §8 — through domain-API research, bot harness implementation/debugging, seed sweeps, test authoring, full-suite verification, and this report), against the issue's 30–60 minute estimate. The overrun is almost entirely the Flutter SDK install (~5 min, one-time) plus the domain-command research needed to build a faithful non-UI player bot (§2) and the two real bot-logic bugs that research caught before they could contaminate the measurement (§3).

## 1. Summary

This is a READ/TEST-primarily verification pass, per the issue's own scope instruction. No baseline-expense, revenue, 30-day-lag, salesCapacity, bankruptcy-grace, capability-threshold, initial-profile, project-generator, or Matching-formula value was changed.

To measure the guardrails, this phase adds:

- `test/game/public_demo/test_support/public_demo_seeded_playthrough_bot.dart` — a deterministic, non-UI "rational player" bot that drives the real `PublicDemoAggregate` command API (the same commands `public_demo_balance_regression_test.dart` and the UI success-playthrough test already use) through a complete April→March year, for any `runSeed`.
- `test/game/public_demo/public_demo_seeded_balance_regression_test.dart` — 27 focused, CI-covered regression tests: reproducibility and characterization of the bot's playthrough for the issue's 7 required seeds, the two static guardrail facts (Sato/Suzuki capability, zero-revenue runway), a per-seed check of the April Matching-fit guardrail against the real project generator, and a reproduction of a confirmed structural finding (§4).
- `tool/simulate_public_demo_seeded_balance.dart` — a `dart run` sweep script (mirrors the existing `tool/simulate_balance_report.dart` pattern) for a broad, non-CI statistical measurement (2,000+ seeds in ~4 seconds).

**Headline result: two confirmed, reproducible findings that violate the issue's own explicit guardrails**, plus one confirmed structural gap outside the guardrail list, and one confirmed-intact guardrail. See §4 for all four, with exact reproduction steps. No fix is applied in this phase — per the issue's scope ("バランス値の変更は…最小変更に限定する", and growth/generator formulas are adjacent to the explicitly protected list) each is reported with root cause, seed(s), and impact, and a recommended follow-up.

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

**Measured result, all 7 required seeds (and confirmed via a 2,000-seed sweep — identical every time, since none of Suzuki's own path touches the seeded project/recruitment generators at all):**

- Suzuki's longest no-order streak = **8 consecutive months (April–November)** in every single playthrough.
- Across the 2,000-seed sweep: Suzuki has a ≥5-month streak in **2,000/2,000 (100%)** of playthroughs. May-hired engineers who don't land a June order also frequently hit this: **1,282/3,347 (38.3%)** of them separately show a ≥5-month streak (none show exactly 4 — the pattern is bimodal: either an early success, or stuck until training/Growth eventually clears the threshold). Aggregate across every engineer-playthrough in the sweep: **≥4-month streak 44.7%, ≥5-month streak 44.7%** (identical — confirming nobody lands in the 4-but-not-5 band) — both figures are roughly **9x** the issue's own "<5%" bar for the 4-month case.

This is the headline finding of this verification pass: **it is not a rare, seed-driven edge case — it is the default, guaranteed outcome for the second founding engineer, every single time**, and a meaningful fraction of May hires share it. It squarely matches the issue's own description of what Phase 8 exists to catch ("理不尽な詰み / 過度な一本道"), even though the root cause here is a fixed formula rather than an unlucky seed.

**Reproduction:** `test/game/public_demo/public_demo_seeded_balance_regression_test.dart`, group `"required-seed playthrough"`, test `"Suzuki (eng-02) has an 8-month no-order streak..."`; broader sweep via `tool/simulate_public_demo_seeded_balance.dart`.

**Recommendation (not applied — `PublicDemoGrowthEngine`'s formula is exactly the kind of "既存バランスガード" value this Issue's own scope says not to change without a dedicated before/after review):** candidates for a follow-up Issue to evaluate: raise `internalTraining`'s `sourceBase` enough that a non-`fastLearner` engineer's floor lands on `+2`/month (roughly halves the wait); let a below-threshold engineer take a reduced-scope/junior assignment (real `source: assignment` Growth is `2.0` base — 2x training's rate — but nothing currently allows an under-60 engineer to be assigned at all); or explicitly re-confirm 8 months is acceptable and adjust the guardrail's own documented tolerance instead. All three are genuine design decisions, not "minimal fixes."

### 4.4 CONFIRMED INTACT — the two guardrails this phase did not find broken

- **Sato/Suzuki initial capability** (`鈴木 actualSkill 52 / requirement 60`): confirmed unchanged — `publicDemoInitialEngineerRuntimes` still authors Sato at 78, Suzuki at 52, against `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement == 60`.
- **"ゼロ売上でも約6か月は耐えられる経済設計"**: confirmed intact by direct check (no bot needed — nobody ever assigned, real baseline expenses, every month closed for real). Cash stays ≥ 0 through August (5 full months from April), enters `cashShortage` in September (month 6), and reaches terminal `bankruptcy` only at the October close (month 7) — a faithful match for "about 6 months."

## 5. Seed-by-seed results (required guardrail seeds)

All 7 seeds reach `PublicDemoAggregate.toJson()`-byte-identical results on a second run with the same seed (reproducibility confirmed for every seed, both via the bot's own two-run check and a separate standalone probe run before the regression test was written).

| Seed | Reached March | Terminal status | May hires joined | Final cash | Sato no-order streak | Suzuki no-order streak |
|---|---|---|---|---|---|---|
| 0 | ✅ | — | 1 | ¥470,000 | 0 | 8 |
| 1 | ✅ | — | 2 | ¥4,260,000 | 0 | 8 |
| 42 | ✅ | — | 2 | ¥4,260,000 | 0 | 8 |
| 13 | ✅ | — | 1 | ¥5,060,000 | 0 | 8 |
| 666 | ❌ | bankruptcy (month 13) | 1 | -¥20,000 | 0 | 8 |
| 315 | ✅ | — | 2 | ¥4,760,000 | 0 | 8 |
| 2147483000 | ❌ | bankruptcy (month 12) | 2 | -¥400,000 | 0 | 8 |

First Fun Year reach rate for these 7 seeds: 5/7 (71.4%) — lower than the broader sweep's 83.7–89% because 7 samples is a small, unrepresentative slice; see §6 for the statistically meaningful figure.

## 6. Broader statistics (non-CI sweep, 2,000 seeds, `tool/simulate_public_demo_seeded_balance.dart`)

```
=== CORE-GAMEPLAY Phase 8 seeded balance sweep (n=2000, seeds 5000000-5001999) ===
First Fun Year reached (fiscalYearCompleted):  1673/2000  (83.7%)
Bankruptcy:   327/2000  (16.4%)
March cash-shortage failure:     0/2000  (0.0%)
```

- **Bankruptcy rate 16.4%** under this bot's policy is a real, if imperfect, signal — this bot's policy hires up to 2 May applicants unconditionally whenever `PublicDemoSalaryOfferEvaluator` says they'd accept, which raises fixed monthly payroll without a guaranteed matching increase in orders (per §4.3, a meaningful fraction of hires never land an order at all). A more selective/conservative hiring policy would likely show a materially lower bankruptcy rate; this number characterizes "hire everyone affordable and reasonably keen," not an optimal player, and should be read as an upper bound on real-player bankruptcy risk, not the true rate.
- **April/May cash is identical across every sampled seed** (`¥3,170,000` / `¥2,240,000`) — see §2's scope note for why (the generic interview path never reads seeded project data).
- **Month 4–6 cash spread**: min/max at month 6 is ¥1,850,000–¥1,910,000 (¥60,000 spread) — well inside the issue's own "±100〜200万円" tolerance, though this reflects the bot's own restricted (non-Matching) April/May scope (§2) more than the full space of real seed-driven variance a Matching-using player would see.
- **No-order streak**: ≥4-month 44.7%, ≥5-month 44.7% (n=7,347 engineer-playthroughs) — see §4.3.
- **May hiring**: 2 applicants generated and both hired in 69.7% of seeds, 1 in 28.0%, 0 (generation failure or unaffordable) in 2.4%.

## 7. Files changed

| File | Change |
|---|---|
| `test/game/public_demo/test_support/public_demo_seeded_playthrough_bot.dart` | New. The deterministic non-UI playthrough bot (§2). |
| `test/game/public_demo/public_demo_seeded_balance_regression_test.dart` | New. 27 focused tests (§Tests below). |
| `tool/simulate_public_demo_seeded_balance.dart` | New. Non-CI sweep CLI (dev-only, mirrors `tool/simulate_balance_report.dart`'s existing pattern). |
| `docs/reports/SES_CORE-GAMEPLAY_Phase8_Seeded-Balance-Verification_Result.md` | New. This report. |

No `lib/` file was changed. No existing test file was changed.

## 8. Environment note

This remote execution environment ships with no Flutter/Dart toolchain pre-installed (`flutter`/`dart` are not on `PATH`, and no SDK exists anywhere on disk). Flutter 3.44.9 (the exact version every `.github/workflows/*.yml` in this repo pins via `subosito/flutter-action`) was installed via a shallow `git clone --branch 3.44.9` into `/opt/flutter-sdk` before any test could run. This is a one-time environment setup cost reflected in §"Actual processing time" above, not a repository change — nothing under `docs/` `session-start-hook`-related or in `.claude/` was touched by this phase, and a future session in a fresh container will need to repeat this same one-time install unless a `SessionStart` hook is added separately (out of this Issue's scope).

## 9. Tests

### New — `public_demo_seeded_balance_regression_test.dart` (27/27 passing)

- Static guardrail facts: Sato/Suzuki initial capability (2 tests, including the zero-revenue-runway check).
- April Matching-fit guardrail per required seed (7 tests — the seed-1 violation is asserted as `0`, not silently loosened).
- Post-May recruitment structural dead end reproduction (1 test).
- Required-seed reproducibility (7 tests — same seed run twice, byte-identical `toJson()`).
- Required-seed exact-outcome characterization (7 tests — reachedMarch/terminal/joinedInMay/finalCash locked per seed).
- April/May cash seed-invariance (1 test, all 7 seeds).
- Sato always-zero-streak (1 test, all 7 seeds).
- Suzuki always-8-month-streak (1 test, all 7 seeds) — the confirmed guardrail violation, locked as a regression so a future change to Growth/interview formulas is forced to re-examine this number rather than silently drift.

### Regression suites re-run (all green, unmodified)

- `flutter test test/game/public_demo/ --concurrency=6`: **759/759 passing** (includes the 27 new tests above; every pre-existing Public Demo domain test — assignment lifecycle, recovery, growth, matching, project interview, cash forecast, binding offer, save codec, and more — passes unchanged).

### Full suite / static checks

- `flutter analyze` (whole repo): **No issues found.**
- `flutter test --concurrency=6` (full suite): **2069/2069 passing.**
- `git diff --check`: clean (no whitespace errors).

## 10. Known limitations

- The bot (§2) never exercises the Phase 5/6 Matching + Project Interview flow for engineer-side order outcomes — only the April project-generator/Matching-fit data itself was checked directly (§4.1) for that axis of Controlled Randomness. A future Phase could add a second bot policy that uses `proposeMatch`/`startProjectInterview` instead, to measure the guardrails from that flow's own perspective.
- The bot's hiring policy (accept every May applicant `PublicDemoSalaryOfferEvaluator` says would accept) is deliberately simple, not optimized — §6's bankruptcy-rate figure should be read as an upper bound, not the balance's true worst case or typical case.
- No balance-formula change was made for any of the 3 confirmed findings (§4.1–4.3) — each needs its own scoped follow-up Issue per this Issue's explicit "minimal change, protected formulas" restriction.

## 11. Unresolved blockers

None — the verification itself completed; findings 4.1–4.3 are explicitly deferred to follow-up Issues per §4's own recommendations, not blockers to closing this one.

## 12. PR

No pull request has been opened yet — per this session's operating rules, a PR is only created when explicitly requested. The branch `claude/issue-217-m7d5jb` is pushed and ready; ask to have a PR opened against `main` when ready.
