# SES HOME-RUNTIME-2C Recommended Action Implementation Result

RECOMMENDED AI: Claude Code
REPOSITORY: perusonao/smile_enjoy_story
BASE: d7964e530b386dc559d9c41dd5421cedf6757c64 (verified: `origin/main` matched the expected 2A merge commit exactly at session start; the pre-existing local branch pointed at an unrelated old commit `f4ca78f` "Phase 0A/0B" and was recreated from latest `origin/main`)
BRANCH: claude/home-runtime-2c-recommended-action-zqow7s
IMPLEMENTATION COMMIT: e974ff5dd2bb1f64c64aa3d68d5a2bfaa3090276
REVIEW-FIX COMMIT: 75b1401e3d05432b5efc00526d474f4ae91b6e85 (Codex P1: July 求人媒体 dead end)
REPORT COMMIT: (this file's own commit, added after the commits above)
HEAD: 75b1401e3d05432b5efc00526d474f4ae91b6e85 (pushed to `origin/claude/home-runtime-2c-recommended-action-zqow7s`)
PR: https://github.com/perusonao/smile_enjoy_story/pull/72 (open, NOT merged)
DIFF: 13 files changed (6 modified, 7 new), 2607 insertions(+), 156 deletions(-); no unrelated files touched (see SCOPE CONTROL)
WORKING TREE AT START: clean — no unrelated user changes existed to separate

## DESIGN AUTHORITY

MISSING DESIGN: `SES_HOME-RUNTIME-2C_Recommended_Action_Design.md` does NOT exist. It is absent from the supplied ZIP, from the repository working tree, and from every branch's history (`git log --all --diff-filter=A` finds no such path). The package's own `START_HERE.md` states this explicitly: *"A standalone file named `SES_HOME-RUNTIME-2C_Recommended_Action_Design.md` is NOT included because it was not available among the supplied files. Do not invent missing rules."*
AUTHORITY USED: `SES_HOME-RUNTIME-2_Integration_Design.md` — `RECOMMENDED ACTION PLAN` (the P0-P3 priority table), `PHASE 2C`, `TERMINAL PLAN`, `FINANCE FAILURE PLAN`, `FIRST VIEW DESIGN`, and the four AUTHORITY sections. No newer dedicated 2C authority exists in the repository (searched; none found).
GAPS: Where that table is silent, the extension is stated explicitly in PRESENTATION PRIORITY below and documented in the code itself, rather than invented silently.

## IMPLEMENTATION SUMMARY

Public Demo HOME now states the single most important next action and offers one tap to it. The slot REPLACES HOME-RUNTIME-2A's `今月やること` card rather than stacking above it, and falls back to that same card when nothing is eligible — the design table's own "none of the above" row. HOME did not become a second dashboard and gained no new large card.

## RECOMMENDED ACTION MODEL

FILE: `lib/presentation/home/models/home_recommended_action.dart` (new).
TYPED: `HomeRecommendedActionKind` is one enum value per *existing* production button, each carrying its presentation rank and its labels. Dispatch is typed end to end — no string tag anywhere between "which action is this" and "which handler runs". Stringly-typed dispatch does not appear in the change.
SPLIT: `HomeRecommendedAction` is a pure, comparable descriptor (kind / subjectName / targetId, no callback), so ranking is testable without any owner wiring. `HomeRecommendedActionCandidate` pairs that descriptor with the owner's already-bound handler.
SLOT: `HomeRecommendedActionSlot` is a sealed type — `Available` / `None` / `Suppressed`.
BOUNDARY: The file imports nothing from `game/` or `domain/`. It structurally cannot see a `PublicDemoState`, a `PublicDemoAggregate`, a `PublicDemoFinancialStatus`, or a workflow stage.

## ELIGIBILITY AUTHORITY

OWNER: `PublicDemo01PlaceholderScreen` remains the eligibility authority. HOME reimplements no game rule.
RULE: A candidate is emitted ONLY from the same `if (s.month == N)` branch, under the same predicate, that already renders AND enables the corresponding button.
WHY: This is the correctness argument, not a style choice. Availability in Public Demo is not a per-action predicate — it is a predicate *inside a month-gated UI branch*. `canUseRecruitmentMediaInMonth(month)` is the standing example: it is satisfied in April, where `build` renders no 求人媒体 card at all, so a recommender consulting the predicate alone would offer a button that does not exist. Reading the predicate at the render site makes that class of bug unrepresentable. Pinned by test (§3 of the runtime suite).
DISABLED: Nothing disabled is ever recommended. Where a button has an enablement condition (`salesRemaining > 0`, affordability, interview score), the candidate carries the same condition, so an unavailable action is ABSENT from the slot rather than greyed out in it.
GUARDS: Every domain guard still runs regardless — `invoke` enters `PublicDemoAggregate` through the same command, so `salesRemaining`, `isCloseBlocked` and `isFinanciallyRestricted` are enforced by the domain exactly as before (WORKFLOW-STATE-1's "never rely on UI alone").

## OWNER DISPATCH

NOT A TABLE: No callback injection table. Each candidate carries the one already-bound closure the corresponding button runs.
ONE BINDING: Several stage handlers were extracted from inline `onPressed:` closures into named methods (`_startSkillSheetReview`, `_beginSelling`, `_introduceProject`, `_reviewResume`, `_beginPreEntrySkillSheet`, `_beginPreEntrySelling`, `_introducePreEntryProject`, `_recordEngineerOrder`, `_recordApplicantJuneOrder`) so the CTA and the button are provably ONE binding, not two closures that agree today. No command, guard, or key changed.
TYPEDEF: `_AddCandidate` names the collector the emit helpers append to, so no helper can take a different one.

## PRESENTATION PRIORITY

PURE: `selectHomeRecommendedAction` is pure, total and deterministic — priority first (lower wins), then EMISSION ORDER (the owner's `workflow.engineers` / `.applicants` / `.assignments` order, as the design requires). Implemented as a single stable scan rather than a sort, so the tie-break holds by construction and the slot cannot flicker between rebuilds.
NOT PERSISTED: Presentation ranking is never written to `_game` and never enters the save schema (SAVE AUTHORITY unchanged).
BANDS: The design table verbatim — P0 `cashShortage`; P1 `summerBonusDecision` / `raiseRequest`; P2 the four named engineer stages; P3 `assignmentConfirmNextOrder` then `recruitmentMedia`, in the design's own order.
EXTENSION (stated, not silent): The design table is a partial inventory. Intermediate steps of pipelines it already names — engineer `selling` / `partnerInterviewPassed` / the two failure stages, the whole month-5 applicant pipeline, the month-6 replacement pipeline — are placed INSIDE their design-named neighbours' bands, ordered by the brief's own rule: finish an already-started pipeline before starting a new one. Nothing is promoted across a design band boundary, and nothing is made eligible that was not already eligible.
ABSENCE 1 — MONTH CLOSE: never recommended. MONTH END CTA PLAN keeps it at the bottom of the scroll on purpose ("finish this month's work first") and it is HOME-RUNTIME-2D's scope.
ABSENCE 2 — INTERNAL TRAINING: never recommended, though its card is rendered and enabled from month 6. Extending the table through a pipeline it already names is presentation; promoting an optional ¥30,000 spend the table never mentions into "the next thing to do" would be a balance decision this layer has no authority to make. (An earlier draft did emit it; that draft changed month-6 behaviour on the no-hire route and was removed.)
ABSENCE 3 — JULY 求人媒体: never recommended. See FINANCE / TERMINAL PRECEDENCE below and REVIEW RESPONSE.

## FINANCE / TERMINAL PRECEDENCE

UNCHANGED AUTHORITY: Domain / Finance / Workflow / Payroll / Assignment / Save authority are untouched. No finance rule was copied into the recommendation path. HOME performs no arithmetic on money.
P0 SHORTAGE: `financialStatus == cashShortage` → `資金不足の対応を確認`, pointing at the existing `PublicDemoCashShortageCard` (which keeps taking `PublicDemoState` directly, above HOME, exactly as before). The CTA is a scroll only — it touches no state and no command. §13's Failure-Recovery rule is preserved: KPI, employee cards and the month-close CTA all stay reachable.
SUPPRESSION: `bankruptcy` / `marchCashShortageFailure` / `fiscalYearCompleted` → slot suppressed entirely, per TERMINAL PLAN ("there is no next action"). The month goal is not offered as a consolation either. Read-only content (KPI, employee names, cash, the inert close CTA) is unaffected.
KEY: Suppression reads `s.isCloseBlocked`, the authority's own name for exactly that three-state set, rather than restating its cases.
BOUNDARY HELD: The decision is made by the owner, which can see `financialStatus`; only its OUTCOME crosses into HOME. `HomeRecommendedActionSuppressed` names an outcome, never its reason, and the projection still carries no `financialStatus` and no `fiscalYearCompleted`. HOME therefore remains structurally unable to render a financial verdict — `public_demo_01_home_runtime_read_test.dart` test 17's boundary is intact, and a dedicated test asserts two different terminal states produce an identical HOME input.

## FIRST VIEW

MEASURED, NOT ASSUMED: Geometry was measured on the real widget tree before and after the change.

| Metric (360x800) | 2A | 2C |
|---|---|---|
| HOME block height | 282pt | 300pt |
| HOME block ends below AppBar | 298pt | 316pt |
| Primary action reachable at | 533pt (`SkillSheet確認`) | **302pt** (CTA) |
| Legacy `SkillSheet確認` | 533pt | 551pt |
| Browser-chrome content budget | 615pt | 615pt |

360x800: PASS — CTA bottom 302pt, legacy button 551pt, both inside the 615pt budget. No overflow.
390x844: PASS — same geometry, budget 660pt. No overflow.
NET EFFECT: The primary action moved UP ~231pt. The 2A first-view improvement is not merely preserved, it is extended.
NO TAP-TARGET TRADE: The 48pt tap target was NOT shrunk to fit. Instead the 2A HOME-block ceiling was raised once, deliberately, from `_smallestBudget / 2` (307.5pt) to an explicit `_homeBlockCeiling = 320` (the 2A block plus one CTA row), documented in the test. It still fails the moment the slot grows back into a second card, which is the regression that assertion exists to catch.
ROLE RECONCILIATION: `今月やること` and Recommended Action are ONE slot showing one of two things, never two stacked cards. `KeyEventsSection` reverted to its Phase 1A empty state; the month-goal presentation MOVED to `RecommendedActionSection` (moved, not copied — there is still exactly one month-goal table, in `HomeDashboardDisplayData`, and the screen still has no `monthGoal()`).

## TEST GUARDS

Both guards the design names were rewritten deliberately, in this change, as PHASE 2C requires ("rewritten deliberately in a reviewable PR ... never quietly relaxed as a side effect of a layout PR").

RUNTIME_READ TEST 14: "HOME has no mutation path back into the aggregate" → "HOME's only mutation path is the whitelisted Recommended Action CTA, bound to an existing aggregate command". STRICTER, not weaker: it now pins which single element may exist, that exactly one `ButtonStyleButton` is present, that it is ENABLED, that the slot handed to HOME carries one bound callback and not an aggregate/state/command API, that pressing it moves the workflow, and that finance is untouched. Non-CTA interactive types are compared against the CTA's own subtree rather than asserted to zero, because a Material button legitimately builds an `InkWell` — so the assertion states the precise claim and still fails if anything else grows a gesture. Split off `14b` keeps the original "poking HOME changes nothing" behavioural check.
2A CONSOLIDATION GROUP 15: same rewrite, same reasoning.
CONSOLIDATION TEST 14: was "the month goal is displayed once"; now pins the role split in BOTH directions — `14` (an action exists → the action is shown, `今月やること` and the goal text are absent, and the month-goal table still has exactly one home) and new `14b` (no action eligible → the same slot shows `今月やること` and the goal, in HOME, as text).
NO BENT AUTHORITY: No production behaviour was changed to make a test pass. The one place a test was relaxed (the HOME-block ceiling) is documented above with its reasoning and remains a real bound.

## TESTS ADDED

`test/presentation/home/home_recommended_action_test.dart` (new, 14 tests) — pure ranking: distinct priorities (total order), design bands preserved exactly, already-started pipeline outranks starting a new one down both pipelines, no-candidates → null, highest priority wins regardless of emission order, ties break on emission order only, determinism across 20 repeated calls, handler carried unchanged, label templates, and a guard that no CTA label is byte-identical to an existing Public Demo control.
`test/ui/public_demo/public_demo_01_home_recommended_action_test.dart` (new, 23 tests) — against the REAL screen, covering the eight required areas:
 1. ACTION SELECTION — April opens on the first engineer's SkillSheet review; exactly one action is offered.
 2. PRIORITY — an already-started pipeline keeps the slot across three real stage advances; an engineer with no button left stops holding it.
 3. MONTH GATE — 求人媒体 is not recommended in April though its predicate is true and no card exists; it becomes eligible in May where the card is rendered; July's is never recommended (see below).
 4. OWNER ELIGIBILITY — an exhausted sales slot removes the interview action instead of offering it disabled (May capacity fully spent via the real buttons); an engineer who is not field-sales ready is never recommended though at the top-ranked stage; the CTA is enabled on every build that offers one, across a real April-to-July trajectory.
 5. DISPATCH — authoritative-state equality against a DIRECT-TAP CONTROL RUN (two independent screens, same two stages, one driven by legacy buttons and one by the CTA, compared on stages, cash, sales slots and month); a CTA that opens a dialog opens the same dialog; the domain slot-consumption guard still runs.
 6. TERMINAL PRECEDENCE — cashShortage outranks everything and ordinary actions stay reachable; the shortage CTA changes nothing; bankruptcy suppresses the slot with no consolation goal; HOME still cannot see a financial verdict; a domain-level check that all three TERMINAL PLAN states reach the one `isCloseBlocked` predicate the screen switches on, and that `cashShortage` does not.
 7. NO ELIGIBLE ACTION — June on the no-hire route falls back to the month goal.
 8. FIRST-VIEW REGRESSION — headline and CTA both inside the viewport and the content budget at both target sizes, CTA usable with no scroll, no overflow.
FIXTURE DISCIPLINE: terminal states are reached through the REAL trajectory and real domain commands. `PublicDemoAggregate` deliberately exposes no reconstruction shortcut ("test fixtures ... build it by chaining these same real commands from initial"); an early draft of this suite poked the private `_game` field and was rewritten to honour that contract instead of reaching past it.

## VALIDATION

flutter analyze: PASS — "No issues found!"
relevant tests: PASS — new 2C suites (37 tests), rewritten guards, and every pre-existing Public Demo suite (playthrough, success-playthrough, fiscal-year-progression, completion-lock, assignment-carryforward, home-runtime-read, home-consolidation).
full flutter test: PASS — **1067 passed** (baseline at BASE: 1026; net +41)
flutter build web --release: PASS — "✓ Built build/web"
git diff --check: PASS — clean
TOOLCHAIN: Flutter 3.44.9 stable / Dart 3.12.2 — the version pinned by the repository's own CI workflows.

## VISUAL VERIFICATION

METHOD: the RELEASE web build was served locally and driven in Chromium at both target viewports (not a widget-test render).
360x800: PASS. 390x844: PASS.
CHECKED: Recommended Action understandable in the initial viewport (`次にやること` / `佐藤 健のSkillSheetを確認` / `[SkillSheetを確認]`); KPI intact (7 values, 2 rows, ¥300万/0名/2名/4回/2名/¥0万/¥0万); employee cards intact (name, badge, summary, 営業進捗 stepper, 営業準備OK, SkillSheet確認, 社内研修 row); no overflow; first view better than 2A.
CTA PRESSABLE IN RELEASE BUILD: PASS — pressing `SkillSheetを確認` advanced the engineer and the recommendation moved to `営業を開始` (with the legacy `営業開始` button below), confirming live dispatch outside the test harness.
ARTIFACTS: `docs/screenshots/home-runtime-2c-360x800.png`, `home-runtime-2c-390x844.png`, `home-runtime-2c-360x800-after-cta.png`.
NOTE: screenshots were captured with `?e2e=1`, which force-enables the semantics tree for automation only and changes nothing a player sees.

## REVIEW RESPONSE

CODEX P1 — "Gate July recruitment until applicants can be processed" (`#discussion_r3863837306`): VERIFIED AND FIXED in `75b1401`.
FINDING CONFIRMED: `build` renders `_RecruitmentMediaCard` in both the month-5 branch (L1579) and the month-7 branch (L1608), but `ac(i)` — the applicant cards that review, interview, offer and sell a candidate — renders only in the month-5 branch (L1583), and no later month renders it either. Applicants generated in July are structurally unadvanceable. Once the summer bonus was decided with no raise pending, recruitment media became July's top recommendation.
WHY IT MATTERED: it would spend up to ¥100,000 (engineer medium) on candidates that can never be used — the dead end AGENTS.md's Failure Recovery rule forbids, and the opposite of what this slot exists to do.
FIX: the candidate is emitted from the month-5 branch only. Being rendered AND enabled is necessary for a recommendation, not sufficient.
NOT DONE (deliberate): adding the July applicant pipeline. That is a product/UI change outside 2C scope — AGENTS.md's "do not silently add later-roadmap features while fixing an earlier-phase task". July's card, button and command are untouched, so a player who wants it can still use it exactly as before.
REGRESSION TEST: asserts the July card is rendered, its button live, and `canUseRecruitmentMediaInMonth(7)` true — while HOME still does not recommend it.
PRE-EXISTING: this dead end predates 2C. `12MONTH-3-FIX1` already recorded it — *"Month 7's identical, pre-existing dead end is left untouched (out of scope for this fix; recorded as a follow-up)"*. 2C stops recommending it; it does not resolve it. See P1 below.

## CI

Build Public Demo browser preview: SUCCESS
Public Demo only: SUCCESS
validate: SUCCESS (flutter analyze / flutter test / flutter build web --release, re-run by CI on head 75b1401)
e2e-chromium: in progress at the time of writing
e2e-webkit: FAILURE — **not this PR's**, established by evidence, not assumption:
 - The identical two tests fail on `main` at `d7964e53`, this PR's exact BASE (run 32954687790): `beginner-mode-waiting-and-recruitment.spec.ts:464` and `phase-3b1-fit-reason.spec.ts:245`, same 2-failed/56-passed split, same errors ("Recruitment root was not stable", `locator.click` timeout waiting for `閉じる`).
 - Both tests exercise the DEVELOPMENT experience (MainShell, recruitment tab, engineer detail, Fitの理由). This diff is confined to the Public Demo experience and touches no file either test reaches.
 - `.github/workflows/e2e.yml` documents the policy: *"WebKit compatibility is also intentionally non-blocking for ordinary PR merge readiness ... a temporary policy boundary for the known WebKit infrastructure flake."* PR #47's merge commit and PR #50 record the same classification.
 - No fix ported: none exists to port (the work lives on unmerged WIP branches), and WebKit/navigation stabilization is explicitly outside this task's scope.
 - No re-run spent: both tests already auto-retried once inside each run and failed on retry, in this run and in the base-branch run; the base-branch evidence is stronger than a re-run.
 - Recorded once on the PR as required (`#issuecomment-5427074666`).
NEW REGRESSION FROM THIS CHANGE: NONE detected.

## CHANGED FILES

NEW (7):
 `lib/presentation/home/models/home_recommended_action.dart`
 `lib/presentation/home/widgets/recommended_action_section.dart`
 `test/presentation/home/home_recommended_action_test.dart`
 `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`
 `docs/screenshots/home-runtime-2c-360x800.png`
 `docs/screenshots/home-runtime-2c-390x844.png`
 `docs/screenshots/home-runtime-2c-360x800-after-cta.png`
MODIFIED (6):
 `lib/presentation/home/home.dart` (barrel export, +1 line)
 `lib/presentation/home/widgets/key_events_section.dart` (reverted to Phase 1A; month-goal slot moved out)
 `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (emit sites, named handlers, slot wiring)
 `lib/ui/public_demo/public_demo_home_dashboard_section.dart` (accepts the resolved slot)
 `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` (group 15 + tests 2/14/14b + first-view + responsive)
 `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart` (test 14 + 14b)

## SCOPE CONTROL

NOT IMPLEMENTED — HOME-RUNTIME-2B Office Stage. Excluded as instructed; first view is to be re-measured after 2C before 2B proceeds.
NOT IMPLEMENTED — HOME-RUNTIME-2D Month End / Legacy Migration.
NOT IMPLEMENTED — the Employee/Sales/Recruitment TAB MIGRATION that the design's PHASE 2C also lists. It depends on 2B, which is excluded here. Consequence: the legacy detail blocks still live on HOME, so "HOME becomes short" is only partly realised. See P1.
NOT TOUCHED — Playwright/WebKit/navigation stabilization; `lib/domain/**`; `lib/main.dart`; `SaveService` and the persistence schema; every finance/workflow/close command.
MAIN: no commit was made to `main`. No force push. No merge. No unrelated change was removed.

## P0

None.

## P1

TAB MIGRATION DEFERRED: the design's 2C includes moving the Employee/Sales/Recruitment detail blocks off HOME into destination screens. It is not implemented (2B dependency, excluded by instruction), so HOME still carries those blocks below the Recommended Action. Confirm this split is acceptable before starting 2B.
JULY 求人媒体 DEAD END (pre-existing, unresolved): July renders the recruitment card without any applicant pipeline, and no later month renders one. 2C stops RECOMMENDING it; the card itself still lets a player spend cash on unusable candidates. `12MONTH-3-FIX1` already recorded this as a follow-up. Resolving it means either removing the July card or adding the July applicant pipeline — a product decision, not a 2C one.

## P2

HOME-BLOCK CEILING RAISED: the 2A assertion moved from 307.5pt to an explicit 320pt, once and deliberately, documented in the test with its rationale. It remains a real bound that fails if the slot grows into a second card.
P3 求人媒体 RARELY SURFACES: in May it is eligible but always outranked by the applicant pipeline, so in practice it is reachable as a recommendation only when every applicant is already advanced. This follows the design's band assignment; confirm it matches intent.

## P3

CTA LABELS DIFFER FROM LEGACY LABELS BY DESIGN (`SkillSheetを確認` vs the card's `SkillSheet確認`), so a player — and a test's `find.text` — can tell the HOME shortcut from the button it leads to. A unit test pins that no CTA label collides with an existing control; it caught `給与を提示` colliding with the salary dialog's title during development.
THREE KINDS SHARE A CTA VERB (`客先面談へ` x3, `上位会社面談へ` x3, `案件を紹介` x2). Harmless — only one is ever shown, and the kinds are distinct — but noted.

## BLOCKED

None.

## UNVERIFIED

Playwright E2E was not run locally (explicitly out of scope). The CI `e2e-webkit` failure is classified above with evidence; `e2e-chromium` on head 75b1401 had not completed at the time of writing.
iOS/Android builds and real-device rendering were not exercised — Flutter web release only.
Screenshots used `?e2e=1` (semantics only; no rendering difference).
`origin/main` was the exact expected commit, so the "or a descendant" branch of the base check was not exercised.

## VERDICT

HOME-RUNTIME-2C COMPLETE within the stated scope. Analyze clean, 1067 tests pass, release web build succeeds, diff check clean, both target viewports visually verified on the release build, both mandated scope guards rewritten to a stricter form, one reviewer P1 verified and fixed. Authority boundaries (Domain / Finance / Workflow / Payroll / Assignment / Save) are intact, and HOME still cannot see a financial verdict.

## NEXT

Review and merge PR #72.
Re-measure the first view on merged 2C, then proceed to HOME-RUNTIME-2B Office Stage (the design's vertical-height problem is the reason for the re-measure).
Decide the two P1 items above: whether the tab migration is required before 2B, and how the pre-existing July 求人媒体 dead end should be resolved.
