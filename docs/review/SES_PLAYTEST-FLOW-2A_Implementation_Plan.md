# SES_PLAYTEST-FLOW-2A Implementation Plan

**Reviewed main SHA:** `817f3b634c5293da1e277b7e88c795268880b66b`  
**PR #110 status:** Merged — treated as fully resolved; no conflict.  
**Plan date:** 2026-08-30  
**Architecture reference:** Two distinct systems — (1) Main Beginner Mode game (`GameState` + `GameEngine` + `TaskEngine` + `BeginnerModeEngine`), (2) Public Demo (`PublicDemoState` + `PublicDemoAggregate` + `HomeRecommendedActionKind` + Hiyori navigator).

---

## Architecture Rules (Must Not Violate)

| Rule | Constraint |
|------|-----------|
| UI SSOT | UI must not become a new source of truth; all business logic stays in domain engines |
| Finance recalc | Do not recalculate finance values in widgets; read from `GameState` or engine functions only |
| Game balance | Do not change engineer skills, salary levels, or assignment match thresholds |
| Starting cash | Main Beginner Mode `startingCash = 3500000` — unchanged; Public Demo `PublicDemoState.aprilStart() cash = 3000000` — unchanged |
| Fixed costs | `otherMonthlyFixedCost = 100000`, navigator salary, engineer salaries — unchanged |
| Revenue/payment timing | `dueMonthFor()` logic and AR recognition timing — unchanged; Public Demo uses fixed 30-day term only |
| Sales/interview/recruitment authority | No changes to who can initiate, approve, or gate these actions |
| Terminal/bankruptcy | Do not weaken or bypass terminal/bankruptcy behavior |
| E2E settings | Do not modify retry/sleep/skip/timeout settings |
| Public Demo persistence | Do not modify Public Demo persistence unless absolutely necessary |
| PLAYTEST-SAVE-1B | Separate task; plan for safe parallelization |

---

## Blocker F-01 (P0): Suzuki Aoi Cannot Progress Into Sales in April

### Classification: Type C (UI explanation problem) + Type B (incomplete gameplay implementation)

### Code Evidence

**Prologue seeding (`lib/game/engine/prologue_engine.dart`)**  
Candidate B (Suzuki Aoi — female, junior, backend:2, salary ~380K) enters April Week 1 with:
```dart
// enterAprilWeek1() — called at prologue completion
engineer.status = EngineerStatus.assigned          // assigned to first project
engineer.salesStatus = SalesStatus.assigned         // salesStatus ALSO set to assigned
engineer.availableFromWeek = 1 + project.durationWeeks
```
This is intentional: the prologue correctly models that Aoi is currently on her first assignment.

**TaskEngine gap (`lib/game/engine/task_engine.dart`)**  
```dart
final salesCandidate = state.engineers
    .where((e) =>
        e.status == EngineerStatus.waiting &&
        e.salesStatus == SalesStatus.notSelling)
    .firstOrNull;
if (salesCandidate != null && state.week != 1)
    tasks.add(HomeTask(id: 'sales-start-${salesCandidate.id}', priority: TaskPriority.warning, ...));
```
**CRITICAL GAP:** Filter is `waiting + notSelling`. Aoi is `assigned + assigned`. No task is generated. No home-screen prompt exists at any point in April to start pre-emptive sales while she is on her current project.

**GameEngine capability (`lib/game/engine/game_engine.dart`)**  
`GameEngine.startSales()` does NOT block for `salesStatus == assigned`. The domain already supports pre-emptive sales for engineers currently on a project.

**Engineer Detail screen gap (`lib/ui/engineers/engineer_detail_screen.dart`)**  
`_SkillSheetSalesCard` has a nullable `onStartSales` callback. The parent passes `onStartSales = null` when `engineer.salesStatus == SalesStatus.assigned`, disabling the button. The disabled state shows no explanation of WHY the button is off or what path forward exists.

**BeginnerMode absence:** `BeginnerModeEngine.weeklyMilestones` contains only Phase 3A milestones; none address "what do I do with my engineer while she's on assignment?"

### Root Cause Summary
- The domain CAN do pre-emptive sales (domain-level: ✓)
- The task surface does NOT prompt it (TaskEngine: ✗)
- The UI button is silently disabled (engineer_detail_screen: ✗)
- The game tutorial does not explain the "assigned but can queue next sales" state (BeginnerModeEngine: ✗)

This is intentional design (domain rule: assigned engineers can do pre-emptive sales) with an **incomplete UI/guidance implementation**.

### Implementation Plan

#### Step F-01-A: Update TaskEngine to include pre-emptive sales task

**File:** `lib/game/engine/task_engine.dart`

Add a second check after the existing `salesCandidate` block:

```dart
// Existing: waiting + notSelling
final salesCandidate = state.engineers
    .where((e) =>
        e.status == EngineerStatus.waiting &&
        e.salesStatus == SalesStatus.notSelling)
    .firstOrNull;
if (salesCandidate != null && state.week != 1)
    tasks.add(HomeTask(...)); // unchanged

// NEW: assigned + assigned (pre-emptive sales for engineers on project)
final preEmptiveSalesCandidate = state.engineers
    .where((e) =>
        e.status == EngineerStatus.assigned &&
        e.salesStatus == SalesStatus.assigned &&
        e.availableFromWeek != null &&
        e.availableFromWeek! - state.week <= 8) // show only when ~2 months until available
    .firstOrNull;
if (preEmptiveSalesCandidate != null)
    tasks.add(HomeTask(
        id: 'sales-pre-emptive-${preEmptiveSalesCandidate.id}',
        priority: TaskPriority.info,   // lower priority than warning; not urgent yet
        title: '${preEmptiveSalesCandidate.name}さんの次の案件を探しましょう',
        subtitle: '参画終了まで${preEmptiveSalesCandidate.availableFromWeek! - state.week}週。\n空き期間が生じると給与だけがかかり続けます。',
    ));
```

**Constraint check:** No domain logic change. Reads existing `state.engineers`, `e.availableFromWeek`, `state.week` only.

#### Step F-01-B: Enable pre-emptive sales button in engineer detail screen

**File:** `lib/ui/engineers/engineer_detail_screen.dart`

In `_SkillSheetSalesCard`, change the condition for passing `onStartSales`:
- Current: `if (engineer.salesStatus == SalesStatus.notSelling) onStartSales = widget.onStartSales`
- New: `if (engineer.salesStatus == SalesStatus.notSelling || engineer.salesStatus == SalesStatus.assigned) onStartSales = widget.onStartSales`

Additionally, update the disabled-state explanation text (shown when `onStartSales == null`):
- Current: implicit null / no text
- New: If `salesStatus == interviewing`, show: `'現在、面接・選考中です。結果をお待ちください。'`
- If `salesStatus == selling`, show: `'既に営業活動中です。'`

**Constraint check:** `GameEngine.startSales()` already handles `assigned` engineers correctly. No domain change required.

#### Step F-01-C: Add BeginnerMode explanatory milestone

**File:** `lib/game/engine/beginner_mode_engine.dart`  
**File:** `lib/game/models/beginner_mode_state.dart`

Add `BeginnerMilestone.preEmptiveSalesExplained` to the milestone enum. Fire it once, approximately when the first `preEmptiveSalesCandidate` task appears (triggered in `_advanceWeeklyMilestones`):

```dart
// In BeginnerModeEngine._advanceWeeklyMilestones()
if (!state.hasSeen(BeginnerMilestone.preEmptiveSalesExplained)) {
    final hasPreEmptiveCandidate = gameState.engineers.any((e) =>
        e.status == EngineerStatus.assigned &&
        e.salesStatus == SalesStatus.assigned &&
        e.availableFromWeek != null &&
        e.availableFromWeek! - gameState.week <= 8);
    if (hasPreEmptiveCandidate) {
        return state.markSeen(BeginnerMilestone.preEmptiveSalesExplained);
        // triggers dialog explaining pre-emptive sales concept
    }
}
```

Dialog content (Japanese):
- **Title:** `参画中でも営業活動ができます`
- **Body:** `鈴木さんは現在、プロジェクトに参画中ですが、次の案件の営業活動を今から始めることができます。参画終了後に「待機」期間が生じると、給与だけがかかり続けます。早めに動くことで、空き時間を最小限にできます。`

**Constraint check:** New milestone only — does not change any game balance, salary, or domain rules.

### Acceptance Tests for F-01

| # | Scenario | Expected |
|---|----------|----------|
| F-01-T1 | April week 1, Aoi on first project, `availableFromWeek = 9` (week 9 = end of 8-week project). Week is 1+. | Home screen shows pre-emptive sales task for Aoi at `info` priority |
| F-01-T2 | Player opens Aoi's engineer detail screen | Sales button is enabled; confirmation dialog shows `availableFromWeek` |
| F-01-T3 | Player taps "営業開始" for Aoi while she is `assigned` | `GameEngine.startSales()` called; Aoi's `salesStatus` transitions to `selling` |
| F-01-T4 | Aoi's `salesStatus == interviewing` | Sales button shows "面接・選考中" message; button disabled |
| F-01-T5 | BeginnerMode milestone dialog fires once when pre-emptive candidate exists | Dialog shown once; `preEmptiveSalesExplained` marked; dialog NOT repeated on subsequent weeks |
| F-01-T6 | Engineer with `salesStatus == notSelling && status == waiting` (existing path) | Existing task still generated correctly; regression test |

---

## Blocker F-03 (P1): Player Cannot Understand First Revenue/Payment Timing Before Decisions

### Code Evidence

**AR tutorial timing (`lib/game/models/founding_progress.dart`)**  
```dart
// OneTimeEvent.firstArTutorial
condition: (state) => state.accountsReceivable.isNotEmpty
```
AR records only exist AFTER April month-end (week 4). The tutorial fires too late — the player has already committed to the project assignment and client choice.

**Revenue explanation milestone (`lib/game/engine/beginner_mode_engine.dart`)**  
```dart
_backfillOnly = [managementPhaseStarted, revenueVsCashExplained]
// revenueVsCashExplained fires when:
// hasSeen(firstAssignmentCelebration) || hasSeen(firstArTutorial)
```
Both trigger conditions are post-April-month-end. The concept is backfilled (shown on next menu entry) but the timing gap still leaves weeks 1-3 unexplained.

**Finance engine calculation (`lib/game/engine/finance_engine.dart`)**  
```dart
static int dueMonthFor(int generatedMonth, int paymentTermDays) {
    return paymentTermDays <= 30 ? generatedMonth + 1 : generatedMonth + 2;
}
// April (absoluteMonth=1):
//   30-day terms → dueMonth=2 (May)
//   60-day terms → dueMonth=3 (June)
```
This is deterministic and can be called pre-assignment with the selected client's `paymentTermDays`.

**First assignment celebration (`lib/game/engine/beginner_mode_engine.dart`)**  
`BeginnerMilestone.firstAssignmentCelebration` fires when first assignment is confirmed. This is the correct hook point — the player just committed to the assignment and now needs to understand when they'll see cash.

### Root Cause Summary
The AR tutorial fires only after AR records exist. The player makes assignment decisions (which client? what payment terms?) in weeks 1-3 without knowing when money arrives. The calculation already exists in `FinanceEngine.dueMonthFor()` and is callable pre-assignment.

### Implementation Plan

#### Step F-03-A: Piggyback payment timing explanation onto firstAssignmentCelebration

**File:** `lib/game/engine/beginner_mode_engine.dart`

After `firstAssignmentCelebration` milestone content, add an inline explanation using the first assignment's actual `paymentTermDays`:

```dart
// In the celebration dialog content builder:
final firstAssignment = gameState.activeAssignments.first; // safe — this milestone only fires once assignment exists
final client = firstAssignment.client;
final paymentTermDays = client.paymentTermDays;
final generatedMonth = 1; // April = absoluteMonth 1
final dueMonth = FinanceEngine.dueMonthFor(generatedMonth, paymentTermDays);
final dueMonthName = _monthName(dueMonth); // helper: 1→4月, 2→5月, 3→6月, etc.
```

Dialog content (append to celebration body):
- **Added section title:** `💰 初回入金のタイミング`
- **Body:** `${client.name}との契約は支払いサイト${paymentTermDays}日。4月分の売上は${dueMonthName}に入金される予定です。売上が立っても、すぐに現金が入るわけではありません。それまでの給与・家賃などの支出は、手元の現金から支払われます。`

**Constraint check:** Reads `client.paymentTermDays` and calls `FinanceEngine.dueMonthFor()` — pure read. No domain mutation. No finance recalc in UI (this is in BeginnerModeEngine, not a widget).

#### Step F-03-B: Add new OneTimeEvent for pre-assignment guidance (alternative path)

If the player somehow reaches April week 3 without the assignment being confirmed (edge case in the guided flow, but defensively useful):

**File:** `lib/game/models/founding_progress.dart`

Add `OneTimeEvent.preAssignmentPaymentExplained`:
```dart
// Fires once when first offer is pending (awaitingAssignment stage) but before assignment confirmed
condition: (state) => state.foundingProgress.currentStage == FoundingStage.awaitingAssignment
    && !state.foundingProgress.hasSeenOneTimeEvent(OneTimeEvent.preAssignmentPaymentExplained)
```

This is a fallback path; F-03-A (piggybacking on celebration) is the primary fix.

#### Step F-03-C: Adjust revenueVsCashExplained trigger

**File:** `lib/game/engine/beginner_mode_engine.dart`

Add `preAssignmentPaymentExplained` as an additional backfill trigger alongside `firstAssignmentCelebration`:
```dart
// Updated _backfillOnly condition for revenueVsCashExplained:
hasSeen(firstAssignmentCelebration) || hasSeen(firstArTutorial) || hasSeen(preAssignmentPaymentExplained)
```

**Constraint check:** Backfill logic only — no domain changes.

### Acceptance Tests for F-03

| # | Scenario | Expected |
|---|----------|----------|
| F-03-T1 | Player confirms first assignment (April week 1-3) | `firstAssignmentCelebration` dialog includes payment timing section with correct `dueMonthName` based on client's `paymentTermDays` |
| F-03-T2 | Client has 30-day terms | Dialog shows "5月に入金予定" |
| F-03-T3 | Client has 60-day terms | Dialog shows "6月に入金予定" |
| F-03-T4 | `FinanceEngine.dueMonthFor()` unit test | Existing test covers 30-day and 60-day cases; regression confirmed |
| F-03-T5 | `revenueVsCashExplained` milestone fires correctly | Still fires after celebration; not fired before assignment |

---

## Blocker F-05 (P1): August–March Risks Becoming Mostly "Advance Month" With Insufficient Decisions

### Code Evidence

**Phase 3B milestone gap (`lib/game/engine/beginner_mode_engine.dart`)**  
```dart
const weeklyMilestones = [
    BeginnerMilestone.waitingCostExplained,       // phase3a
    BeginnerMilestone.firstCollectionCelebrated,   // phase3a
    BeginnerMilestone.recruitmentTradeoffExplained,// phase3a
    BeginnerMilestone.phase3aRecapCelebrated,      // phase3a
];
// Phase 3B (weeks 13-48): NO weekly milestone dialogs
```

**Existing but unused milestones (`lib/game/models/beginner_mode_state.dart`)**  
`BeginnerMilestone.fitReasonViewed` and `BeginnerMilestone.projectComparisonUsed` exist in the phase3B scope but neither has a celebration dialog or weekly milestone entry.

**Phase 3B sub-phases defined but empty (`lib/game/models/beginner_mode_state.dart`)**  
`BeginnerSubPhase.phase3b1` (wks 13-24), `phase3b2` (25-36), `phase3b3` (37-48) are defined but receive no milestone content.

**Contract renewal tutorial (`lib/game/models/founding_progress.dart`)**  
```dart
// OneTimeEvent.contractRenewalTutorial
condition: (state) => state.activeAssignments.any(
    (a) => a.remainingWeeks <= 4 && a.contractDecision == ContractDecision.undecided)
```
Fires when a contract is within 4 weeks of ending. This exists but the content is minimal and fires only once (as a `OneTimeEvent`).

**Task engine July/Aug task scarcity:** `TaskEngine` generates contract-ending tasks (when `remainingWeeks <= 4`) but does not generate proactive recruiting tasks, financial review tasks, or team composition review tasks during the mid-game stretch.

### Root Cause Summary
Phase 3B has zero weekly milestone dialogs. The `weeklyMilestones` list ends at `phase3aRecapCelebrated`. From July onwards, the player receives no engagement prompts from `BeginnerModeEngine` — only the bare contract-ending task from `TaskEngine`. The game turns into an "advance month" grind.

### Implementation Plan

#### Step F-05-A: Add Phase 3B1 weekly milestone content (weeks 13-24, July-September)

**File:** `lib/game/models/beginner_mode_state.dart`  
Add new milestones to `BeginnerMilestone` enum:
```dart
// Phase 3B1 milestones
teamCompositionReviewed,    // week ~16 (August): 2-person team dynamics
firstYearRunwayReviewed,    // week ~20 (October): mid-year runway check
recruitmentTimingExplained, // week ~14 (July): proactive recruitment window
```

**File:** `lib/game/engine/beginner_mode_engine.dart`  
Extend `weeklyMilestones` list:
```dart
const phase3bMilestones = [
    BeginnerMilestone.recruitmentTimingExplained,    // fires ~week 14
    BeginnerMilestone.teamCompositionReviewed,       // fires ~week 16
    BeginnerMilestone.firstYearRunwayReviewed,       // fires ~week 20
];
```

Each milestone dialog provides a focused decision prompt:
- **recruitmentTimingExplained:** `'採用の最適タイミングとは？'` — explain that hiring when understaffed is too late; point player toward recruitment screen
- **teamCompositionReviewed:** `'チーム構成を見直しましょう'` — prompt to review current assignments and skill coverage; ask whether the current team balance is right for next quarter
- **firstYearRunwayReviewed:** `'上半期を振り返りましょう'` — mid-year cash review; how many months runway? what's the plan for second half?

**Constraint check:** New milestones only. No game balance changes. All data read from `GameState` (cash, assignments, engineers).

#### Step F-05-B: Add Phase 3B2 weekly milestone content (weeks 25-36, November-January)

**File:** `lib/game/models/beginner_mode_state.dart`  
Add:
```dart
// Phase 3B2 milestones
secondHalfGoalSet,         // week ~26 (November): set second-half intent
yearEndPreparationStarted, // week ~34 (February): year-end check
```

**File:** `lib/game/engine/beginner_mode_engine.dart`  
Dialog themes:
- **secondHalfGoalSet:** `'下半期の目標を確認しましょう'` — review financial position; is the runway sufficient to reach March?
- **yearEndPreparationStarted:** `'年度末に向けた準備'` — prompt player to ensure all engineers are placed for the final stretch

#### Step F-05-C: Improve contractRenewalTutorial content (supplements F-06)

**File:** `lib/game/models/founding_progress.dart` (condition — no change)  
**File:** UI layer rendering the OneTimeEvent dialog (exact file TBD at implementation; likely `lib/ui/home/widgets/beginner_tutorial_overlay.dart` or equivalent)

Improve the body text from a generic "decide to extend or withdraw" notice to one that explains:
- What extending means (revenue continues)
- What withdrawing means (engineer becomes available; must find new project)
- What the consequence of `undecided` is (auto-withdraws at deadline with no transition plan in place)

**Constraint check:** Copy change only. No domain logic change. The `contractDecision` update path (`GameEngine.setContractDecision()`) is unchanged.

### Acceptance Tests for F-05

| # | Scenario | Expected |
|---|----------|----------|
| F-05-T1 | Game reaches week 14 (July week 2) | `recruitmentTimingExplained` dialog fires once |
| F-05-T2 | Game reaches week 16 (August week 1) | `teamCompositionReviewed` dialog fires once |
| F-05-T3 | Game reaches week 20 (September week 4) | `firstYearRunwayReviewed` dialog fires once; reads runway from `GameState` |
| F-05-T4 | Each milestone dialog fires exactly once (not on repeated visits) | `hasSeen(milestone) == true` after first showing |
| F-05-T5 | Phase 3B milestones fire in correct week-order | No out-of-order firings |
| F-05-T6 | Weekly simulation test (`test/game/weekly_simulation_test.dart`) passes | No regression on existing simulation |

---

## Blocker F-06 (P1): June Next-Month-Order Decision Does Not Communicate Consequence

### Code Evidence

**TaskEngine contract task subtitle (`lib/game/engine/task_engine.dart`)**  
```dart
// Current subtitle:
'「${a.project.title}」残り${a.remainingWeeks}週・次の案件は未定です'
// Translation: "X weeks remaining; next project undecided"
// Missing: consequence of leaving it undecided
```

**Public Demo recommended action (`lib/presentation/home/models/home_recommended_action.dart`)**  
```dart
HomeRecommendedActionKind.assignmentConfirmNextOrder
// presentationPriority = 50 (P3 — lowest priority band)
// P3 is "supporting work"; easily buried under P0 warnings and P1 deadlines
```

**Public Demo Hiyori copy (`lib/presentation/home/models/home_navigator_display.dart`)**  
```dart
case HomeRecommendedActionKind.assignmentConfirmNextOrder:
    return HomeNavigatorAdvice(
        title: '次の発注内容を確認しましょう',
        message: '継続発注が届いています。...',
        explanation: '次の発注を確認すると、継続する案件の手続きを進められます。表示された内容を確認してください。',
        // explanation is WHAT-only; no mention of idle cost or consequence
    );
```

**OneTimeEvent.contractRenewalTutorial (`lib/game/models/founding_progress.dart`)**  
```dart
condition: (state) => state.activeAssignments.any(
    (a) => a.remainingWeeks <= 4 && a.contractDecision == ContractDecision.undecided)
```
This fires once, but the content is not examined here (the rendering code was not fully read). Based on the pattern of all other OneTimeEvent dialogs, it likely explains WHAT to do but not the cost of delay.

### Root Cause Summary
Three touch points all communicate "you need to decide" without communicating the financial consequence (idle salary cost). The P3 priority of the Public Demo action makes it easy to ignore.

### Implementation Plan

#### Step F-06-A: Update TaskEngine contract task subtitle to include consequence

**File:** `lib/game/engine/task_engine.dart`

Change the contract-ending task subtitle:
```dart
// Current:
subtitle: '「${a.project.title}」残り${a.remainingWeeks}週・次の案件は未定です'

// New:
subtitle: '「${a.project.title}」残り${a.remainingWeeks}週。\n確認が遅れると空き期間が生じ、売上なしで給与がかかり続けます。'
```

**Constraint check:** String change only. No logic change.

#### Step F-06-B: Strengthen contractRenewalTutorial dialog content

**File:** UI rendering file for `OneTimeEvent.contractRenewalTutorial` (exact path TBD at implementation; likely `lib/ui/home/widgets/` or `lib/presentation/home/`)

Update body text to include:
- Current situation: "契約終了が近づいています"
- Consequence of inaction: "未決定のまま期限を過ぎると、エンジニアが「待機」状態になります。待機中は売上がなくなりますが、給与は毎月発生し続けます。"
- Action: "「継続」か「終了」かを選んで、次のステップを準備しましょう。"

**Constraint check:** Copy change only. `OneTimeEvent` condition and `contractDecision` transition logic unchanged.

#### Step F-06-C: Raise priority of assignmentConfirmNextOrder in Public Demo

**File:** `lib/presentation/home/models/home_recommended_action.dart`

Change `assignmentConfirmNextOrder` presentationPriority from 50 (P3) to 35 (P2 — pipeline continuation):
```dart
// Current:
HomeRecommendedActionKind.assignmentConfirmNextOrder: HomeRecommendedAction(
    presentationPriority: 50, // P3
    ...
),

// New:
HomeRecommendedActionKind.assignmentConfirmNextOrder: HomeRecommendedAction(
    presentationPriority: 35, // P2 — pipeline continuation
    ...
),
```

P2 priority rationale: confirming a next order is pipeline continuation — it directly affects revenue continuity. Deprioritizing to P3 means it can be missed under P1 deadline items.

**Constraint check:** Priority value only. No domain logic change. Does not modify Public Demo persistence.

#### Step F-06-D: Update Hiyori explanation for assignmentConfirmNextOrder (see F-07 batch)

This is addressed together with F-07's explanation pass. See F-07-A below.

### Acceptance Tests for F-06

| # | Scenario | Expected |
|---|----------|----------|
| F-06-T1 | Assignment has `remainingWeeks <= 4` and `contractDecision == undecided` | Home task appears with new subtitle including consequence copy |
| F-06-T2 | Subtitle correctly interpolates `project.title` and `remainingWeeks` | Spot-check with title containing special chars |
| F-06-T3 | `contractRenewalTutorial` OneTimeEvent fires once | Dialog shown once when first qualifying assignment exists |
| F-06-T4 | Updated dialog body includes consequence text | Text review |
| F-06-T5 | `assignmentConfirmNextOrder` in Public Demo appears in P2 band | Item appears above P3 items in home recommended action list |
| F-06-T6 | Existing contract task regression test passes | `test/game/task_engine_test.dart` — no regression |

---

## Blocker F-07 (P1): Hiyori Guidance Explains WHAT To Do But Not WHY It Matters

### Code Evidence

All `explanation` strings in `lib/presentation/home/models/home_navigator_display.dart`, function `_guidanceCopyFor(HomeRecommendedActionKind kind)`:

| Kind | Current explanation | Missing |
|------|---------------------|---------|
| `assignmentConfirmNextOrder` | `'次の発注を確認すると、継続する案件の手続きを進められます。表示された内容を確認してください。'` | Idle cost if delayed |
| `employeeBeginSelling` | `'営業開始は、案件との接点を作るための最初の手続きです。対象者と内容を確認して進めます。'` | Salary-without-revenue cost of waiting |
| `applicantJuneOrder` | (similar WHAT-only pattern) | Revenue loss from unfilled capacity |
| (all other kinds) | WHAT-focused only | WHY / consequence |

**Pattern:** All explanations describe procedure. None contain:
- Financial consequence of NOT acting
- Specific numbers (salary, revenue rate) that make the consequence concrete
- Time-sensitivity signal

### Root Cause Summary
`HomeNavigatorAdvice.explanation` field is documented as "Fixed educational presentation copy explaining why the already-resolved action matters" — but the copy was written as procedural guidance, not educational consequence copy. Pure copy change needed.

### Implementation Plan

#### Step F-07-A: Rewrite all explanation strings to include WHY/consequence

**File:** `lib/presentation/home/models/home_navigator_display.dart`

For each `HomeRecommendedActionKind`, update the `explanation` field:

```dart
case HomeRecommendedActionKind.assignmentConfirmNextOrder:
    return HomeNavigatorAdvice(
        title: '次の発注内容を確認しましょう',
        message: '継続発注が届いています。...',
        explanation: '確認が遅れると、契約終了後にエンジニアが「待機」状態になります。'
            '待機中は売上がゼロでも給与が毎月発生し続けるため、'
            'キャッシュが急速に減少します。早めに確認・決定しましょう。',
    );

case HomeRecommendedActionKind.employeeBeginSelling:
    return HomeNavigatorAdvice(
        title: '営業を始めましょう',
        message: '...',
        explanation: '営業を始めないまま待機期間が続くと、売上のない月でも'
            '給与・家賃などの固定費がかかり続けます。'
            '早期に営業活動を開始することで、空き期間を最短にできます。',
    );

case HomeRecommendedActionKind.applicantJuneOrder:
    return HomeNavigatorAdvice(
        title: '6月の発注を確認しましょう',
        message: '...',
        explanation: '発注が確定しないと、翌月以降の売上計画が立てられません。'
            '6月以降の稼働が止まると、給与などの固定費だけが続き'
            'キャッシュアウトが早まります。期限内に確認してください。',
    );
```

Apply the same WHY pattern to all remaining `HomeRecommendedActionKind` cases, following this template:
1. State the consequence of NOT acting (what goes wrong)
2. Name the financial dimension (salary, cash, revenue)
3. Close with urgency signal (early action benefit)

**Constraint check:** Pure copy change. No model, logic, or persistence changes.

#### Step F-07-B: Verify HomeNavigatorAdvice explanation field is rendered

**File:** Widget that renders `HomeNavigatorAdvice` (exact file TBD; likely `lib/ui/home/widgets/home_navigator_card.dart` or equivalent)

Confirm that `explanation` is actually displayed in the UI. If it is hidden or unused, add a `Text(advice.explanation)` in the card widget below the main message.

**Constraint check:** Display-only change if needed. No domain change.

### Acceptance Tests for F-07

| # | Scenario | Expected |
|---|----------|----------|
| F-07-T1 | Public Demo home screen shows `assignmentConfirmNextOrder` | Explanation text includes consequence of idle cost |
| F-07-T2 | Public Demo home screen shows `employeeBeginSelling` | Explanation text includes salary-without-revenue consequence |
| F-07-T3 | Each explanation string contains at least one financial consequence clause | Text review against all `HomeRecommendedActionKind` cases |
| F-07-T4 | `HomeNavigatorAdvice.explanation` is rendered in UI | Visual review; not hidden behind a toggle |
| F-07-T5 | No existing widget tests broken by copy change | Run `flutter test` against home navigator display tests |

---

## Dependencies

```
F-01-A (TaskEngine)     ──→ F-01-B (UI button) : TaskEngine must surface task before UI button change matters
F-01-C (milestone)      ──→ F-01-A             : milestone fires when TaskEngine first produces pre-emptive task
F-03-A (celebration)    : standalone; reads existing celebration hook
F-03-B (oneTimeEvent)   ──→ F-03-A             : fallback path; F-03-A is primary
F-05-A (phase3b1)       : standalone; adds new milestones
F-05-B (phase3b2)       ──→ F-05-A             : extends F-05-A milestone list pattern
F-05-C (contractTutorial) : supplements F-06-B
F-06-A (task subtitle)  : standalone
F-06-B (tutorial content) : standalone; supplements F-05-C
F-06-C (priority)       : standalone
F-06-D (Hiyori copy)    ──→ F-07-A             : same file; do in one PR
F-07-A (Hiyori copy)    : standalone
F-07-B (rendering check) ──→ F-07-A            : must confirm render before copy is useful
```

---

## Expected Changed Files

| File | Blocker(s) | Change Type |
|------|-----------|-------------|
| `lib/game/engine/task_engine.dart` | F-01-A, F-06-A | Logic (new filter) + Copy (subtitle) |
| `lib/ui/engineers/engineer_detail_screen.dart` | F-01-B | UI (condition for button enable, disabled text) |
| `lib/game/engine/beginner_mode_engine.dart` | F-01-C, F-03-A, F-03-C, F-05-A, F-05-B | Milestone additions + dialog content |
| `lib/game/models/beginner_mode_state.dart` | F-01-C, F-05-A, F-05-B | Enum additions |
| `lib/game/models/founding_progress.dart` | F-03-B | New OneTimeEvent |
| `lib/presentation/home/models/home_recommended_action.dart` | F-06-C | Priority value |
| `lib/presentation/home/models/home_navigator_display.dart` | F-06-D, F-07-A | Copy (explanation strings) |
| UI overlay/card rendering file (TBD) | F-05-C, F-06-B, F-07-B | Copy + possible display fix |

**Total estimated files:** 8-10 (7 confirmed + 1-3 TBD at implementation)

---

## Acceptance Test Matrix (Summary)

| Blocker | Tests | Critical path |
|---------|-------|---------------|
| F-01 | T1–T6 | T1 (task appears), T3 (startSales works), T5 (milestone once) |
| F-03 | T1–T5 | T1 (dialog on assignment), T2/T3 (correct month name) |
| F-05 | T1–T6 | T1–T3 (phase 3B dialogs fire), T6 (weekly simulation regression) |
| F-06 | T1–T6 | T1 (task subtitle), T5 (priority), T6 (regression) |
| F-07 | T1–T5 | T1–T3 (WHY text present), T4 (rendered) |

**Total acceptance tests:** 26 tests across 5 blockers.

**Existing test files to run for regression:**
- `test/game/task_engine_test.dart` — F-01, F-06
- `test/game/beginner_mode_test.dart` — F-01, F-03, F-05
- `test/game/beginner_mode_subphase_test.dart` — F-05
- `test/game/prologue_engine_test.dart` — F-01 (prologue seeding check)
- `test/game/prologue_dead_end_test.dart` — F-01
- `test/game/weekly_simulation_test.dart` — F-05
- `test/game/ux_guidance_test.dart` — F-07
- `test/game/finance_engine_test.dart` — F-03 (dueMonthFor regression)
- `test/game/founding_progression_e2e_test.dart` — F-03, F-06

---

## Recommended PR Split

### NEXT IMPLEMENTATION PR #1: F-01 — Suzuki Aoi Pre-Emptive Sales Path

**Scope:**
- `lib/game/engine/task_engine.dart` — add pre-emptive sales task for assigned engineers
- `lib/ui/engineers/engineer_detail_screen.dart` — enable sales button for assigned engineers; add disabled-state copy
- `lib/game/engine/beginner_mode_engine.dart` — add `preEmptiveSalesExplained` milestone
- `lib/game/models/beginner_mode_state.dart` — add `BeginnerMilestone.preEmptiveSalesExplained`

**Tests to add/update:**
- `test/game/task_engine_test.dart` — new test: pre-emptive task appears for assigned engineer
- `test/game/beginner_mode_test.dart` — new test: milestone fires once; not repeated

**Why isolated:** F-01 is P0. It blocks the core April tutorial flow. It should land first and can be tested independently.

**Estimated LOC change:** ~60-100 lines (mostly new task filter logic + new milestone content strings)

---

### NEXT IMPLEMENTATION PR #2: F-03 + F-06 — Payment Timing Explanation + Contract Decision Consequence

**Scope:**
- `lib/game/engine/beginner_mode_engine.dart` — extend `firstAssignmentCelebration` with payment timing section
- `lib/game/models/founding_progress.dart` — add `preAssignmentPaymentExplained` OneTimeEvent (F-03 fallback)
- `lib/game/engine/task_engine.dart` — update contract task subtitle (F-06-A)
- UI rendering file for `contractRenewalTutorial` — update dialog body (F-06-B)
- `lib/presentation/home/models/home_recommended_action.dart` — update `assignmentConfirmNextOrder` priority (F-06-C)

**Tests to add/update:**
- `test/game/beginner_mode_test.dart` — payment timing dialog fires after first assignment with correct month name
- `test/game/task_engine_test.dart` — contract task subtitle includes consequence text
- `test/game/finance_engine_test.dart` — regression: `dueMonthFor()` unchanged

**Why grouped:** F-03 and F-06 both touch the assignment/contract lifecycle; they share `beginner_mode_engine.dart` and the contract tutorial rendering path. Grouping reduces review surface and avoids three-way merge on the same file.

**Estimated LOC change:** ~80-120 lines (mostly new dialog content strings)

---

### NEXT IMPLEMENTATION PR #3: F-05 + F-07 — Phase 3B Engagement + Hiyori WHY Copy

**Scope:**
- `lib/game/models/beginner_mode_state.dart` — add Phase 3B milestone enums
- `lib/game/engine/beginner_mode_engine.dart` — add Phase 3B weekly milestone list + dialog content
- `lib/presentation/home/models/home_navigator_display.dart` — rewrite all `explanation` strings with WHY/consequence copy
- UI home navigator card (TBD) — confirm `explanation` field rendered (F-07-B)
- Improve `contractRenewalTutorial` content if not done in PR #2 (F-05-C)

**Tests to add/update:**
- `test/game/beginner_mode_subphase_test.dart` — new phase3b1/3b2/3b3 milestones fire at correct weeks
- `test/game/weekly_simulation_test.dart` — run 48-week simulation; verify all new milestones fire exactly once
- `test/game/ux_guidance_test.dart` — verify Hiyori explanation strings contain WHY keywords

**Why grouped:** F-05 and F-07 are both "engagement content" changes (copy and milestone content). They do not touch the same files as PR #1 and PR #2. The phase 3B content is entirely additive; it cannot conflict with F-01/F-03 work.

**Estimated LOC change:** ~150-200 lines (mostly string content for 5 new milestone dialogs + 6-8 explanation rewrites)

---

## Implementation Order

```
Week 1:
  PR #1 (F-01)   ── highest priority P0; unblocks core April flow
  PR #2 (F-03+F-06) ── can be drafted in parallel with PR #1

Week 2:
  PR #3 (F-05+F-07) ── after PR #1 merges; no shared files

Review sequence: PR #1 → PR #2 → PR #3
```

**Critical path:** F-01 (PR #1) must land first. It is P0 and the most impactful unblock.

---

## PLAYTEST-SAVE-1B Conflict Risk and Parallelization Plan

### Estimated conflict risk: LOW

Based on the description of PLAYTEST-SAVE-1B as a save/persistence feature:

| File | FLOW-2A touches | SAVE-1B likely touches | Conflict risk |
|------|-----------------|----------------------|---------------|
| `lib/game/models/game_state.dart` | No (read-only) | Yes (serialization) | None |
| `lib/game/engine/task_engine.dart` | Yes (new task filter) | Possible (task save) | Low (different functions) |
| `lib/game/engine/beginner_mode_engine.dart` | Yes (new milestones) | Yes (milestone save/restore) | Medium |
| `lib/game/models/beginner_mode_state.dart` | Yes (new enum values) | Yes (serialization) | Medium |
| `lib/game/models/founding_progress.dart` | Yes (new OneTimeEvent) | Yes (serialization) | Medium |
| `lib/presentation/home/` | Yes (copy changes) | Unlikely | Low |
| `lib/ui/engineers/` | Yes (button condition) | Unlikely | None |

### Specific conflict scenarios

**`beginner_mode_state.dart` enum additions:**  
FLOW-2A adds new `BeginnerMilestone` values. SAVE-1B may add serialization for the same enum. Conflict is in the enum declaration block. Resolution: coordinate the specific enum values and their ordinal positions before merging.

**`founding_progress.dart` OneTimeEvent:**  
FLOW-2A adds `preAssignmentPaymentExplained`. SAVE-1B may add serialization for `OneTimeEvent`. Conflict only if SAVE-1B adds values to the same enum. Resolution: add new values at the end of the enum list (not insert in middle).

**`beginner_mode_engine.dart` milestone list:**  
FLOW-2A extends `weeklyMilestones`. SAVE-1B may add save/restore logic referencing milestone indices. Resolution: milestone content changes (strings) will not conflict with serialization logic (separate function); only ordering matters.

### Safe parallelization plan

1. **FLOW-2A PR #1 (F-01)** — can be developed and merged independently. No overlap with SAVE-1B scope.

2. **FLOW-2A PR #2 (F-03+F-06)** — develop in parallel with SAVE-1B. Before merging, confirm:
   - `founding_progress.dart`: new `OneTimeEvent.preAssignmentPaymentExplained` added at end of enum
   - `beginner_mode_engine.dart`: no changes to function signatures used by SAVE-1B

3. **FLOW-2A PR #3 (F-05+F-07)** — highest risk. Recommend merging SAVE-1B first if it is nearly ready, then rebase FLOW-2A PR #3 onto the result. If SAVE-1B is still in progress, flag the `BeginnerMilestone` enum additions to the SAVE-1B author for coordination.

4. **Communication protocol:** Before merging any FLOW-2A PR that touches `beginner_mode_state.dart` or `founding_progress.dart`, check the SAVE-1B PR's open status. If SAVE-1B has an open PR touching the same files, do a pre-merge review pass together.

---

## Summary Table

| Blocker | Priority | PR | Files Changed | Risk Level | Dependencies |
|---------|----------|-----|--------------|------------|-------------|
| F-01 | P0 | PR #1 | task_engine, engineer_detail_screen, beginner_mode_engine, beginner_mode_state | Low | None |
| F-03 | P1 | PR #2 | beginner_mode_engine, founding_progress | Low | F-01 merged (shared file) |
| F-05 | P1 | PR #3 | beginner_mode_state, beginner_mode_engine | Medium (SAVE-1B) | PR #2 merged |
| F-06 | P1 | PR #2 | task_engine, home_recommended_action, home_navigator_display, UI overlay | Low | None |
| F-07 | P1 | PR #3 | home_navigator_display, UI card | Low | None |

---

## PLAYTEST-FLOW-2A PLAN READY

---

## Public Demo Architecture Consistency Review

**Review date:** 2026-08-30  
**Reviewed at SHA:** `817f3b634c5293da1e277b7e88c795268880b66b`  
**Trigger:** PUBLIC-DEMO-E2E-1 (no Playwright coverage) + PLAYTEST-SURVIVAL-1B (fragile fiscal survival route) require verifying that each FLOW-2A fix targets the actual playtest runtime, not the separate Main Beginner Mode.

---

### 1. Actual Public Demo Runtime — Architecture Map

| Dimension | Public Demo 0.1 (Actual Playtest Runtime) | Main Beginner Mode |
|-----------|------------------------------------------|-------------------|
| **Entry route** | `PublicDemoAggregate.initial()` → `PublicDemoState.aprilStart()` | `GameState` seeded by `PrologueEngine.completePrologue()` |
| **Root aggregate** | `PublicDemoAggregate` (single atomic root in `PublicDemo01PlaceholderScreen`) | `GameState` + `GameEngine` |
| **State machine** | `PublicDemoWorkflowState` (engineer/applicant sales stages) | `UnlockEngine` + `ProgressionEngine` + `FoundingProgress` |
| **Screen/widget** | `PublicDemo01PlaceholderScreen` (single stateful widget; one `PublicDemoAggregate` field) | Multiple game screens via `GameEngine` |
| **Month model** | `month: int` (4=April … 15=March); no `week` concept | `week: int` (1–48); month derived via `Calendar.absoluteMonth(week)` |
| **Starting cash** | **`cash: 3000000`** — set in `PublicDemoState.aprilStart()` | `startingCash = 3500000` — set in `GameState` |
| **April engineer seed** | `engineerCount: 2, engineersWaiting: 2, engineersAssigned: 0` — **both waiting** | Candidate B (`Suzuki Aoi`) set to `status=assigned, salesStatus=SalesStatus.assigned` by `PrologueEngine.enterAprilWeek1()` |
| **Suzuki Aoi identity** | `eng-02`, `PublicDemoSalesStage.waiting`, `actualSkill: 52`, `isReadyForFieldSales: false` (52 < 60) | Candidate B, `status=assigned`, `salesStatus=SalesStatus.assigned`, `backend: 2` |
| **Sato Ken identity** | `eng-01`, `PublicDemoSalesStage.waiting`, `actualSkill: 78`, `isReadyForFieldSales: true` | Candidate A, `status=assigned` (same first project) |
| **Engineer skills** | Java: actualSkill 78 (eng-01); JavaScript: actualSkill 52 (eng-02); capability from `PublicDemoEngineerRuntime` | `backend: 4` (Candidate A); `backend: 2` (Candidate B); from `SalesEngine` skill sheet |
| **Sales eligibility** | `isReadyForFieldSales = actualCapability >= 60` on `PublicDemoEngineerRuntime`; checked at `HomeRecommendedActionKind` emit in `PublicDemo01PlaceholderScreen` | `SalesEngine.startSales()` via `GameEngine`; no explicit capability gate on starting sales |
| **Sales pipeline stages** | `PublicDemoSalesStage`: `waiting → skillSheet → selling → introduced → partnerInterviewFailed/Passed → clientInterviewFailed/Passed → ordered` | `SalesStatus`: `notSelling → selling → interviewing → assigned` |
| **Assignment state machine** | `PublicDemoWorkflowState.assignOrderedForMay()` builds roster at May close; `PublicDemoNextOrderStatus` for June decisions; `PublicDemoReplacementStage` for replacements | `ContractDecision` + `remainingWeeks` on each `Assignment` |
| **Month progression** | `PublicDemoAggregate.closeApril/closeMay/closeJune/closeJuly/closeOrdinaryMonth/completeFiscalYear()` | `GameEngine.advanceWeek()` x4 per month; `MonthlyClosing` at week 4/8/12/… |
| **AR / revenue timing** | Fixed 30-day term only: `pendingRevenue` → cash at next month-end close | `dueMonthFor(generatedMonth, paymentTermDays)` supports 30-day (+1 month) and 60-day (+2 months) |
| **Hiyori source** | `lib/presentation/home/models/home_navigator_display.dart` `_guidanceCopyFor(HomeRecommendedActionKind)` | `BeginnerModeEngine` milestone dialogs (separate system; Hiyori not used) |
| **Recommended-action source** | `HomeRecommendedActionKind` + `HomeRecommendedActionCandidate` emitted by `PublicDemo01PlaceholderScreen`; sorted by `presentationPriority` | `TaskEngine` (generates `HomeTask` list for main game HOME) |
| **TaskEngine** | **NOT USED by Public Demo** | Main Beginner Mode only |
| **BeginnerModeEngine** | **NOT USED by Public Demo** | Main Beginner Mode only |
| **BeginnerModeState / BeginnerMilestone** | **NOT USED by Public Demo** | Main Beginner Mode only |
| **FoundingProgress / OneTimeEvent** | **NOT USED by Public Demo** | Main Beginner Mode only |
| **engineer_detail_screen.dart** | NOT the Public Demo engineer UI (`lib/ui/engineers/engineer_detail_screen.dart` belongs to main game) | Main game engineer detail screen |

---

### 2. Starting Cash Authority — Discrepancy Resolved

| Source | Value | Authority |
|--------|-------|-----------|
| `GameState.startingCash` (Main Beginner Mode) | **¥3,500,000** | Main Beginner Mode game |
| `PublicDemoState.aprilStart()` (Public Demo) | **¥3,000,000** | Public Demo 0.1 — the **actual playtest runtime** |

**Resolution:** The external playtest uses the Public Demo. The authoritative starting cash for the playtest is **¥3,000,000**, confirmed at `lib/game/public_demo/public_demo_state.dart` line: `cash: 3000000`. The ¥3,500,000 figure in the original plan body was incorrect — it was sourced from `GameState` (Main Beginner Mode only) and must not be used in any Public Demo implementation context. Neither value is to be changed; both are documented for clarity.

---

### 3. Blocker Classification by Runtime Target

#### F-01 (P0): Suzuki Aoi Cannot Progress Into Sales in April

**PUBLIC DEMO: YES — but with a completely different root cause than the plan identified.**  
**MAIN BEGINNER MODE ONLY: NO**  
**Plan status: WRONG TARGET for all four proposed file changes.**

**Actual Public Demo root cause (newly identified):**

In Public Demo April, `eng-02` (Suzuki Aoi) starts `PublicDemoSalesStage.waiting` with `actualSkill: 52`. The `isReadyForFieldSales` property on `PublicDemoEngineerRuntime` requires `actualCapability >= 60`. Aoi's capability is 52 — below the threshold.

`HomeRecommendedActionKind.employeeSkillSheetReview` (priority 26) is only emitted by `PublicDemo01PlaceholderScreen` when `stage == waiting && readyForFieldSales`. Aoi does not meet `readyForFieldSales`. She receives **no recommended action at all** in the April home screen.

`PublicDemoWorkflowState.startSkillSheetReview()` can still be called for any `waiting` engineer — there is no domain guard on capability. The skill sheet review itself is not blocked. The player is blocked only at the **recommended-action emit level** — Aoi's card is on screen but the home shortcut is silent.

Further: `beginSelling()` in the workflow requires `from: {skillSheet, partnerInterviewFailed, clientInterviewFailed}`. Even if the player manually starts Aoi's skill sheet review, `beginSelling` is reachable from `skillSheet`. But `employeeBeginSelling` recommended action (priority 25) is emitted only when `stage == skillSheet && readyForFieldSales`. Aoi would still not appear in the recommended action after completing skill sheet review.

The player has no explanation of WHY Aoi is not surfaced for sales, and no path forward is communicated. This is the actual F-01 blocker in Public Demo.

**Correct Public Demo F-01 fix targets:**
1. `PublicDemo01PlaceholderScreen` — the emit site for `HomeRecommendedActionCandidate`s; add a candidate for `stage == waiting && !readyForFieldSales` → emit a new kind or the `recruitmentMedia`/internal-training path with explanation
2. `lib/presentation/home/models/home_recommended_action.dart` — add `HomeRecommendedActionKind.employeeGrowthNeeded` (or equivalent) at a suitable priority band for engineers not yet field-sales-ready
3. `lib/presentation/home/models/home_navigator_display.dart` — add Hiyori guidance explaining WHY Aoi is not ready (capability below threshold) and what the player can do (internal training, or wait for growth from first assignment of Sato Ken)

**Plan's proposed targets vs actual — verdict:**

| Plan proposed file | Actual target? | Verdict |
|-------------------|----------------|---------|
| `lib/game/engine/task_engine.dart` | NOT USED by Public Demo | **WRONG TARGET** |
| `lib/ui/engineers/engineer_detail_screen.dart` | Main game only; not Public Demo engineer UI | **WRONG TARGET** |
| `lib/game/engine/beginner_mode_engine.dart` | NOT USED by Public Demo | **WRONG TARGET** |
| `lib/game/models/beginner_mode_state.dart` | NOT USED by Public Demo | **WRONG TARGET** |

**Note on design classification:** F-01 is also NOT Type B (incomplete gameplay) in Public Demo. The domain CAN run `startSkillSheetReview` for Aoi — no domain block exists. It is Type C (UI/presentation gap): the recommended-action emit in `PublicDemo01PlaceholderScreen` silently excludes below-threshold engineers with no explanation. The design decision to gate `employeeSkillSheetReview` on `readyForFieldSales` may be intentional game balance — the fix is to surface WHY and offer a path forward (growth), not to lower the threshold.

---

#### F-03 (P1): Player Cannot Understand First Revenue/Payment Timing Before Making Decisions

**PUBLIC DEMO: YES — different mechanism.**  
**MAIN BEGINNER MODE ONLY: NO**  
**Plan status: WRONG TARGET for all proposed file changes.**

**Public Demo payment model:**
- Fixed 30-day term only (no 60-day option in `PublicDemoState`)
- April revenue (`pendingRevenue` credited at April close) → cash at May month-end close
- `advanceToMay()` does not pay out `pendingRevenue`; it is paid by `PublicDemoMonthlyClose.closeMay()` at May close
- The player makes April decisions (start Sato Ken's sales pipeline, decide assignment) without knowing that April revenue arrives in May, not April

**Correct Public Demo F-03 fix targets:**
1. `lib/presentation/home/models/home_navigator_display.dart` — add/extend Hiyori guidance at the order-confirmation point (when `HomeRecommendedActionKind.employeeAcceptOrder` or `assignmentAcceptNextOrder` is shown) to explain "4月の売上は5月に入金されます"
2. `PublicDemo01PlaceholderScreen` — the assignment-confirmation callback (the point where the player accepts an order and a revenue relationship is created) is the correct hook; add an inline explanatory dialog after first order confirmation

**Plan's proposed targets vs actual — verdict:**

| Plan proposed file | Actual target? | Verdict |
|-------------------|----------------|---------|
| `lib/game/engine/beginner_mode_engine.dart` (`firstAssignmentCelebration`) | NOT USED by Public Demo | **WRONG TARGET** |
| `lib/game/models/founding_progress.dart` (`OneTimeEvent`) | NOT USED by Public Demo | **WRONG TARGET** |

---

#### F-05 (P1): August–March Risks Becoming Mostly "Advance Month"

**PUBLIC DEMO: YES — same symptom, different mechanism.**  
**MAIN BEGINNER MODE ONLY: NO**  
**Plan status: WRONG TARGET for all proposed file changes.**

**Public Demo month 8–15 mechanics:**
- `advanceToNextOrdinaryMonth()` (months 8–14): only ordinary expenses settle; `engineersAssigned/Waiting` carry forward unchanged from June; no new assignment UI
- `completeFiscalYear()` (month 15 = March): same
- Recommended actions in months 8–14 are limited to: training selections, growth results review, `assignmentConfirmNextOrder` (for any undecided June assignments), `recruitmentMedia` (months 4–8 only), raise decisions
- If all June assignments were accepted and no raise requests exist, the home recommended action slot can be `HomeRecommendedActionNone` for months 8–14 — the player truly has nothing to do

**Correct Public Demo F-05 fix targets:**
1. `HomeRecommendedActionKind` — consider adding engagement prompts specific to months 8–14 (e.g., reviewing growth results, planning next year's headcount)
2. `lib/presentation/home/models/home_navigator_display.dart` — add month-range-specific Hiyori messages for the August–March stretch acknowledging the operational state
3. `PublicDemo01PlaceholderScreen` — the emit site for recommended actions; adding month-specific candidates for the quiet months

**Plan's proposed targets vs actual — verdict:**

| Plan proposed file | Actual target? | Verdict |
|-------------------|----------------|---------|
| `lib/game/models/beginner_mode_state.dart` (new milestones) | NOT USED by Public Demo | **WRONG TARGET** |
| `lib/game/engine/beginner_mode_engine.dart` (milestone dialogs) | NOT USED by Public Demo | **WRONG TARGET** |

---

#### F-06 (P1): June Next-Month-Order Decision Does Not Communicate Consequence

**PUBLIC DEMO: YES (partially).**  
**MAIN BEGINNER MODE ONLY: NO**  
**Plan status: PARTIAL — two of four steps are correct; two are wrong target.**

**Verification:**

| Plan proposed step | File | Actual target? | Verdict |
|-------------------|------|----------------|---------|
| F-06-A: Update contract task subtitle | `lib/game/engine/task_engine.dart` | NOT USED by Public Demo | **WRONG TARGET** |
| F-06-B: Strengthen `contractRenewalTutorial` dialog | `founding_progress.dart` rendering | NOT USED by Public Demo | **WRONG TARGET** |
| F-06-C: Raise `assignmentConfirmNextOrder` priority P3→P2 | `lib/presentation/home/models/home_recommended_action.dart` | **YES — Public Demo** | **CORRECT TARGET** |
| F-06-D: Update Hiyori explanation for `assignmentConfirmNextOrder` | `lib/presentation/home/models/home_navigator_display.dart` | **YES — Public Demo** | **CORRECT TARGET** |

**Note on F-06-C priority rationale:** `assignmentConfirmNextOrder` at priority 50 (P3) is below all pipeline-continuation actions. During June when an assignment's `nextOrderStatus == undecided`, the player is not prompted to decide until after completing all P2 pipeline work. If Sato Ken's June replacement pipeline is also in progress, `assignmentConfirmNextOrder` can be buried. Raising to 35 (P2, alongside `assignmentBeginReplacementSelling`) is correct.

---

#### F-07 (P1): Hiyori Guidance Explains WHAT But Not WHY

**PUBLIC DEMO: YES — confirmed correct target.**  
**MAIN BEGINNER MODE ONLY: NO**  
**Plan status: CORRECT TARGET — no revision needed.**

`lib/presentation/home/models/home_navigator_display.dart` is exclusively Public Demo. The `explanation` field rewrites are appropriate and do not touch any domain logic.

---

### 4. Revised Blocker Target Summary

| Blocker | Public Demo? | Main Beginner Mode Only? | All Plan Targets Correct? |
|---------|-------------|-------------------------|--------------------------|
| F-01 | YES — different root cause | NO | **WRONG TARGET** (all 4 files) |
| F-03 | YES — different mechanism | NO | **WRONG TARGET** (all 2 files) |
| F-05 | YES — same symptom | NO | **WRONG TARGET** (all 2 files) |
| F-06 | PARTIAL | NO | **PARTIAL** (2 correct, 2 wrong) |
| F-07 | YES | NO | **CORRECT** |

---

### 5. Revised Implementation Targets

All file changes must target the actual Public Demo runtime. The following replaces the per-blocker implementation steps for F-01, F-03, F-05, and the wrong-target steps in F-06.

#### F-01 — Revised Correct Targets

**File 1: `PublicDemo01PlaceholderScreen` (TBD exact path — `lib/ui/` or `lib/presentation/`)**  
Add emit logic for engineers where `stage == waiting && !isReadyForFieldSales`:
```dart
// NEW emit for below-threshold waiting engineers
if (engineer.stage == PublicDemoSalesStage.waiting &&
    !runtime.isReadyForFieldSales) {
    candidates.add(HomeRecommendedActionCandidate(
        action: HomeRecommendedAction(
            kind: HomeRecommendedActionKind.employeeGrowthNeeded,
            subjectName: engineer.name,
            targetId: engineer.id,
        ),
        invoke: () { /* open engineer card to show growth status */ },
    ));
}
```

**File 2: `lib/presentation/home/models/home_recommended_action.dart`**  
Add new kind:
```dart
/// An engineer exists but is not yet ready for field sales. Player should
/// understand why and what action is available (training, or wait for Sato
/// Ken's assignment to complete growth).
employeeGrowthNeeded(
    presentationPriority: 28, // P2, below employeeSkillSheetReview=26
    ctaLabel: '成長状況を確認',
    headline: '{name}の営業準備状況',
),
```

**File 3: `lib/presentation/home/models/home_navigator_display.dart`**  
Add `case HomeRecommendedActionKind.employeeGrowthNeeded:` with WHY copy:
```dart
explanation: '${name}さんは現在、案件参画に必要なスキルレベルに達していません。'
    'スキルが向上すると営業活動が開始できます。'
    '内部研修の活用や、他の社員の参画実績を積むことで成長を促せます。'
```

#### F-03 — Revised Correct Targets

**File: `lib/presentation/home/models/home_navigator_display.dart`**  
Add to `case HomeRecommendedActionKind.employeeAcceptOrder:` (or the first order-acceptance kind):
```dart
explanation: '発注を受けると、4月分の売上が月末に計上されます。'
    '支払いサイト30日のため、実際の入金は翌月（5月末）です。'
    'それまでの給与・家賃は手元の現金から支払われます。資金繰りを確認しておきましょう。'
```

**File: `PublicDemo01PlaceholderScreen`**  
After the first `recordOrder` callback, show a one-time dialog with the payment timing explanation (equivalent to F-03-A in Main Beginner Mode, but targeting Public Demo's order confirmation flow).

#### F-05 — Revised Correct Targets

**File: `lib/presentation/home/models/home_recommended_action.dart`**  
No new `HomeRecommendedActionKind` values are strictly needed if training is already on-screen. The `HomeRecommendedActionNone` fallback already shows a month goal. The fix may be in improving that fallback content rather than adding new recommended action kinds.

**File: `lib/presentation/home/models/home_navigator_display.dart`**  
Add month-range-aware Hiyori messages for months 8–14. The navigator display could inspect `state.month` (passed to `_guidanceCopyFor`) to provide:
- Months 8–10: "現在の参画状況は順調ですか？成長結果を確認しましょう。"
- Months 11–13: "下半期も引き続き参画が続きます。資金繰りを定期的に確認してください。"
- Month 14 (February): "来月で今期が終わります。通期の振り返りを準備しましょう。"

**Constraint check:** `home_navigator_display.dart` does NOT read `PublicDemoState` directly (per file design); the month value must be passed into `_guidanceCopyFor()` as a parameter, or the display model must be extended. Verify this does not violate SSOT rules at implementation time.

#### F-06 — Retain Only Correct-Target Steps

Retain F-06-C (priority change in `home_recommended_action.dart`) and F-06-D/F-07-A (Hiyori copy in `home_navigator_display.dart`).

Remove F-06-A (`task_engine.dart` subtitle) and F-06-B (`contractRenewalTutorial` dialog) — these are Main Beginner Mode only and not applicable to the playtest.

---

### 6. Revised Expected Changed Files

| File | Blocker(s) | Change Type | Runtime |
|------|-----------|-------------|---------|
| `PublicDemo01PlaceholderScreen` (TBD exact path) | F-01, F-03 | Emit logic + one-time order dialog | **Public Demo** |
| `lib/presentation/home/models/home_recommended_action.dart` | F-01, F-06-C | New kind + priority | **Public Demo** |
| `lib/presentation/home/models/home_navigator_display.dart` | F-01, F-03, F-05, F-06-D, F-07 | Explanation copy + new cases | **Public Demo** |
| ~~`lib/game/engine/task_engine.dart`~~ | ~~F-01, F-06-A~~ | ~~REMOVED~~ | ~~Main Beginner Mode only~~ |
| ~~`lib/ui/engineers/engineer_detail_screen.dart`~~ | ~~F-01~~ | ~~REMOVED~~ | ~~Main Beginner Mode only~~ |
| ~~`lib/game/engine/beginner_mode_engine.dart`~~ | ~~F-01, F-03, F-05~~ | ~~REMOVED~~ | ~~Main Beginner Mode only~~ |
| ~~`lib/game/models/beginner_mode_state.dart`~~ | ~~F-01, F-05~~ | ~~REMOVED~~ | ~~Main Beginner Mode only~~ |
| ~~`lib/game/models/founding_progress.dart`~~ | ~~F-03~~ | ~~REMOVED~~ | ~~Main Beginner Mode only~~ |

**Total revised confirmed files: 3 Public Demo files + 1 TBD screen path**

---

### 7. Revised PR Split

The previous three-PR split must be revised. All implementation targets are now in the Public Demo layer.

#### REVISED NEXT IMPLEMENTATION PR #1: F-01 — Aoi Growth-Needed State + Hiyori WHY (F-07 combined)

**Scope:**
- `PublicDemo01PlaceholderScreen` — add `employeeGrowthNeeded` candidate emit for `stage == waiting && !isReadyForFieldSales`
- `lib/presentation/home/models/home_recommended_action.dart` — add `HomeRecommendedActionKind.employeeGrowthNeeded` at priority 28
- `lib/presentation/home/models/home_navigator_display.dart` — add `employeeGrowthNeeded` case + rewrite ALL existing `explanation` strings with WHY/consequence copy (F-07 combined here since same file, same pass)

**Why F-01 + F-07 combined:** Both touch `home_navigator_display.dart`; doing F-07's full copy pass while also adding the new F-01 case avoids a two-PR conflict on the same file.

**Tests to add:**
- `PublicDemo01PlaceholderScreen` widget test: April home shows `employeeGrowthNeeded` for Aoi (actualSkill 52); does NOT show `employeeSkillSheetReview` for Aoi
- `home_recommended_action.dart`: new kind sorted correctly relative to `employeeSkillSheetReview`
- Hiyori explanation strings contain WHY keywords for each existing kind

#### REVISED NEXT IMPLEMENTATION PR #2: F-03 + F-06 — Payment Timing + Contract Consequence

**Scope:**
- `PublicDemo01PlaceholderScreen` — add one-time order-acceptance dialog explaining April→May payment timing
- `lib/presentation/home/models/home_navigator_display.dart` — add payment timing copy to `employeeAcceptOrder` explanation (F-03); update `assignmentConfirmNextOrder` explanation with idle-cost consequence (F-06-D)
- `lib/presentation/home/models/home_recommended_action.dart` — raise `assignmentConfirmNextOrder` priority from 50 (P3) to 35 (P2) (F-06-C)

**Tests to add:**
- One-time dialog appears after first `recordOrder()` call; not repeated on subsequent orders
- `assignmentConfirmNextOrder` appears above P3 items in home slot when active
- Hiyori explanation for `assignmentConfirmNextOrder` contains consequence language

#### REVISED NEXT IMPLEMENTATION PR #3: F-05 — August–March Month Engagement

**Scope:**
- `lib/presentation/home/models/home_navigator_display.dart` — add month-range Hiyori messages for months 8–14 (requires verifying whether `month` can be passed to `_guidanceCopyFor` without SSOT violation; if not, create a new `HomeNavigatorMonthContext` value object the presenter can supply)
- `PublicDemo01PlaceholderScreen` — if fallback month goal text needs improvement for quiet months, update the `HomeRecommendedActionNone` display

**Tests to add:**
- Month 8 Hiyori message is different from month 4 Hiyori message
- Month 14 (February) Hiyori message includes year-end language
- `HomeRecommendedActionNone` fallback does not show an impossible CTA

---

### 8. PLAYTEST-SAVE-1B Conflict Risk — Revised

PLAYTEST-SAVE-1B touches Public Demo persistence (`PublicDemoAggregate.toJson/fromJson`, `PublicDemoState`, `PublicDemoWorkflowState`). FLOW-2A's revised targets touch only presentation/UI files.

| File | FLOW-2A (revised) | SAVE-1B likely | Conflict risk |
|------|-------------------|----------------|---------------|
| `PublicDemoState` | No | Yes | **None** |
| `PublicDemoWorkflowState` | No | Yes | **None** |
| `PublicDemoAggregate` | No | Yes | **None** |
| `PublicDemo01PlaceholderScreen` | Yes (new emit + dialog) | Possible (save/restore hooks) | **Low–Medium** |
| `home_recommended_action.dart` | Yes (new kind) | Unlikely | **Low** |
| `home_navigator_display.dart` | Yes (copy changes) | Unlikely | **Low** |

**Revised conflict risk: LOW overall.** The previous plan's Medium risk on `beginner_mode_state.dart` enum additions is entirely eliminated — those files are no longer touched by FLOW-2A.

---

### 9. Actions Required Before Implementation Begins

1. **Locate `PublicDemo01PlaceholderScreen` exact path** — the file was referenced but not read; all F-01/F-03 emit logic changes depend on it. Likely in `lib/ui/home/` or `lib/presentation/home/`.
2. **Verify `_guidanceCopyFor()` parameter surface** — confirm whether `home_navigator_display.dart` can receive `state.month` without violating the "no domain objects in presentation" rule. If not, design a `HomeNavigatorMonthContext` value before implementing F-05.
3. **Confirm `employeeGrowthNeeded` design authority** — the `isReadyForFieldSales` threshold (60) is a game-balance value. Adding a recommended action for below-threshold engineers is a presentation fix, not a threshold change. Confirm this does not require design sign-off before implementation.
4. **PUBLIC-DEMO-E2E-1 coverage** — every acceptance test in this plan requires a Public Demo Playwright test fixture. Since there is currently no Playwright coverage for Public Demo, the E2E acceptance tests must be written as part of implementation (not post-implementation). Treat each REVISED PR as requiring at least one Playwright happy-path test covering its own changes.

---

PLAYTEST-FLOW-2A PUBLIC DEMO TARGET VERIFIED
