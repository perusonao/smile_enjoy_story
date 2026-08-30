# PUBLIC-DEMO-P0-SUZUKI Preimplementation

**Task:** PUBLIC-DEMO-P0-SUZUKI-PREIMPLEMENTATION  
**Mode:** READ / VERIFY / DESIGN ONLY — no code changes committed  
**Code authority:** `origin/main` (commit `817f3b6`)  
**Date:** 2026-08-30

---

## 1. Exact Public Demo Runtime

```
ROUTE:
  AppExperience.publicDemo01
  → _GameRoot (lib/main.dart:88)
  → const PhoneFrame(child: PublicDemo01PlaceholderScreen())

SCREEN:
  lib/ui/public_demo/public_demo_01_placeholder_screen.dart
  class PublicDemo01PlaceholderScreen (StatefulWidget)
  state: _S

EMPLOYEE COMPONENT:
  _S.ec(int i)  — line 1653
  Renders one PublicDemoEngineerSales from workflow.engineers[i].
  Called inside build() at:
    • month 4: `for (var i = 0; i < workflow.engineers.length; i++) ec(i)`
    • month 6: filtered subset of engineers still in the sales pipeline

DOMAIN STATE:
  _S._game  → PublicDemoAggregate (the single root)
  _S.s      → _game.state   (PublicDemoState — finance side)
  _S.workflow → _game.workflow (PublicDemoWorkflowState — workflow side)
  Engineers live in: workflow.engineers  (List<PublicDemoEngineerSales>)
  Engineer runtime lives in: s.engineerRuntimes  (List<PublicDemoEngineerRuntime>)

ACTION AVAILABILITY SOURCE:
  _S.readyForFieldSales(engineerId)
    → s.runtimeForOrNull(engineerId)?.isReadyForFieldSales ?? false
  _S.capabilityFor(engineerId)
    → s.runtimeForOrNull(engineerId)?.actualCapability ?? 0

LOCK / ELIGIBILITY SOURCE (AUTHORITATIVE):
  PublicDemoEngineerRuntime.isReadyForFieldSales
    → actualCapability >= 60
  PublicDemoEngineerRuntime.actualCapability
    → languageSkills[primaryLanguage]?.actualSkill ?? 0
  File: lib/game/public_demo/public_demo_engineer_runtime.dart

GUIDANCE SOURCE (current):
  NONE — when readyForFieldSales is false the ec() card renders
  no explanatory text and no fallback button.  This is the P0 gap.
```

**Not inferred from Main Beginner Mode.** The Public Demo has its own
`PublicDemoAggregate`, `PublicDemoState`, `PublicDemoWorkflowState`, and
`PublicDemoEngineerRuntime`. None of those files import or reference
`TaskEngine`, `BeginnerModeEngine`, `BeginnerModeState`, or `GameEngine`.
The route guard `experience == AppExperience.publicDemo01` short-circuits
before any Main-mode screen is constructed.

---

## 2. Suzuki Aoi's Authoritative State (origin/main)

### Identity and Sales Profile

Source: `lib/game/public_demo/public_demo_sales.dart`, const `publicDemoInitialEngineers[1]`

| Field | Value |
|-------|-------|
| id | `eng-02` |
| name | `鈴木 葵` |
| summary | `JavaScript / Flutter・開発経験2年` |
| stage (initial) | `PublicDemoSalesStage.waiting` |
| interviewProfile.skillFit | 52 |
| interviewProfile.humanity | 66 |
| interviewProfile.morale | 64 |
| interviewProfile.clientTrust | 55 |
| mental (initial) | 50 |
| trust (initial) | 50 |

### Runtime Profile

Source: `lib/game/public_demo/public_demo_engineer_runtime.dart`, const `publicDemoInitialEngineerRuntimes[1]`

| Field | Value |
|-------|-------|
| engineerId | `eng-02` |
| primaryLanguage | `javascript` |
| actualSkill (JavaScript) | **52** |
| displayedExperienceMonths | 24 |
| growthPotential | **4** (above average; range 1–5) |
| abilities | `{}` (no fastLearner) |
| techSkills.frontend | 3 |

### Derived Values

| Property | Computation | Result |
|----------|-------------|--------|
| `actualCapability` | `languageSkills[javascript]?.actualSkill` | **52** |
| `isReadyForFieldSales` | `52 >= 60` | **false** |

### Why Sales Are Blocked

**DOMAIN REASON:**  
`actualCapability = 52` does not satisfy `isReadyForFieldSales` threshold `>= 60`.  
The threshold is a hardcoded literal in `PublicDemoEngineerRuntime.isReadyForFieldSales`.

**UI PRESENTATION:**  
In `ec(int i)`, the SkillSheet and sales buttons are gated by
`readyForFieldSales(e.id)`. With `waiting` stage AND `readyForFieldSales = false`:
- No "営業準備OK" label is rendered
- No "SkillSheet確認" FilledButton is rendered
- No other CTA or explanatory text is rendered
- The `internalTrainingCard(...)` IS rendered (training is available), but
  its copy ("社内研修 ¥30,000") does not mention the sales threshold or
  that training will unlock the sales path

**PLAYER EXPLANATION:**  
Nothing. The player sees: name → "待機" badge → summary → progress bar at
step 0 → a training card saying "社内研修 ¥30,000". No explanation of why
she is blocked, no indication that training leads to unlocking sales.

### Growth Math for Suzuki (Internal Training)

```
source:              internalTraining
sourceBase:          1.2
potentialMultiplier: 0.70 + (4 × 0.15) = 1.30
fastLearnerBonus:    1.0 (no ability)
moraleMultiplier:    1.0 (morale = 64, range 30–75)
diminishing:         1.0 (skill = 52, below 70)

delta = floor(1.2 × 1.30 × 1.0 × 1.0 × 1.0)
      = floor(1.56)
      = 1 per month
```

Suzuki needs: **60 − 52 = 8 skill points**  
At 1/month with training every month: **8 months of training = unlocks by November**  
(April = month 4, November = month 11; game runs to March = month 15).

This path exists within the game's first fiscal year. It is tight but achievable.

---

## 3. UI-Only Determination

**YES — this P0 can be fixed without changing any of the following:**

- Suzuki's initial `actualSkill` (52)
- The `isReadyForFieldSales` threshold (60)
- Salary, assignment rules, project matching
- Recruitment flow or finance
- Growth rates or training costs
- Any balance parameter whatsoever

The domain already does the right thing:
1. `actualCapability = 52 < 60` → correctly blocks field sales
2. Training correctly grows `actualCapability` by 1/month
3. Once `actualCapability >= 60`, `isReadyForFieldSales` becomes `true` and the
   "SkillSheet確認" button appears automatically — **no domain change needed**

The only gap is that **the player is not told** any of this. The fix is
purely additive UI text within `ec()`.

---

## 4. Minimum Player-Facing Fix

The fix adds explanatory copy inside `ec(int i)` under the branch:

```
e.stage == PublicDemoSalesStage.waiting && !readyForFieldSales(e.id)
```

### Required Experience After Fix

| Question | Answer shown to player |
|----------|----------------------|
| **WHY** — Why can't she start sales? | スキルが営業基準（60）に達していません |
| **STATUS** — What state is she in? | 現在のスキル: [actualCapability] / 60 |
| **NEXT** — What can the player do? | 社内研修でスキルを伸ばすと、60に達したとき営業準備を開始できます |

### Minimum Widget Change (in `ec()`)

Replace the current implicit no-op (no widget rendered in waiting+not-ready branch)
with a small, domain-backed info block. Pseudocode:

```dart
// In ec(int i), after the sales-progress widget:

if (e.stage == PublicDemoSalesStage.waiting && !readyForFieldSales(e.id)) ...[
  const SizedBox(height: 4),
  Text(
    'スキルが営業基準に達していません（現在 ${capabilityFor(e.id)} / 60）',
    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
  ),
  const SizedBox(height: 2),
  Text(
    '社内研修でスキルを伸ばすと、基準（60）到達後に営業準備を開始できます。',
    style: Theme.of(context).textTheme.bodySmall,
  ),
],
// followed by the existing internalTrainingCard(...)
```

**Values used:**
- `capabilityFor(e.id)` — already defined in `_S`, reads from `s.runtimeForOrNull`
- `60` — the literal from `isReadyForFieldSales`; inline here as a presentation
  constant rather than importing from domain (it is already a hardcoded literal
  in the domain, not a named constant, so this duplication is acceptable until
  the threshold is made a named constant in a separate PR)

**What this does NOT do:**
- Does not change Sato's path in any way
- Does not add a new gameplay mechanic
- Does not invent a threshold the domain does not use
- Does not alter the training card's domain binding or cost

---

## 5. Hiyori Interaction

### Current State

`navigatorAdviceFor(_recommendedActionSlot)` is the ONLY path into Hiyori.
The navigator guidance lookup is exhaustive over `HomeRecommendedActionKind`
values — there is no entry for "engineer not ready for field sales."

In April, when Sato is `waiting + readyForFieldSales`, the recommended action
slot will surface Sato's `employeeSkillSheetReview` candidate first. Hiyori
shows that. Suzuki's blocked state is not surfaced to the recommended-action
system at all (`_addEngineerStageCandidate` emits nothing for
`waiting && !readyForFieldSales`).

### Decision: No New Hiyori Entry for 1A

**Recommendation: Do NOT add a new HomeRecommendedActionKind or navigator
entry in this fix.**

Reasons:
1. The player already sees Suzuki's card on screen. Adding navigator text
   for a non-actionable state would compete with and potentially obscure
   Sato's actionable navigator tip.
2. The `HomeNavigatorAdvice` system is designed for actionable next steps,
   not passive status. A "Suzuki is blocked" tip has no CTA.
3. The fix in `ec()` is co-located with the blocked card — the player sees
   the reason exactly where they encounter the problem.
4. The navigator runs in HOME; the ec() card runs below HOME. Explaining in
   the card avoids double-reporting.

**If Hiyori guidance is desired in a future phase (NAVIGATOR-1B+):**
- Trigger: month == 4 AND any engineer has `waiting && !readyForFieldSales`
- Copy intent: "○○はまだ営業基準に達していません。研修でスキルを伸ばしましょう。"
- Only when no higher-priority recommended action exists

That is future scope. This preimplementation does not design it.

---

## 6. Test Plan

### A. Suzuki is visible on fresh Public Demo (regression guard)

```dart
// File: test/ui/public_demo/public_demo_01_suzuki_p0_test.dart
testWidgets('Suzuki is visible in April initial state', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  expect(find.text('鈴木 葵'), findsOneWidget);
  expect(find.text('待機'), findsOneWidget);
});
```

### B. Blocked action is not presented as silently broken

```dart
testWidgets('Suzuki shows no SkillSheet button but shows reason text', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  // No SkillSheet button for Suzuki
  // (Sato's button IS present — only assert absence after confirming
  //  that text uniquely identifies Suzuki's block)
  expect(
    find.byKey(const Key('public-demo-suzuki-not-ready-label')),
    findsOneWidget,
  );
  // Must NOT be a silent no-op
  expect(
    find.text('今はできません'),
    findsNothing,
    reason: 'Vague text is explicitly excluded',
  );
});
```

### C. Player can see the reason

```dart
testWidgets('Suzuki block shows domain-backed skill and threshold', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  // The exact current skill value (52) and the threshold (60) must be visible
  expect(find.textContaining('52'), findsAtLeastNWidgets(1));
  expect(find.textContaining('60'), findsAtLeastNWidgets(1));
});
```

### D. Player can see the next condition/path

```dart
testWidgets('Suzuki card shows training as the unlock path', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  // Training card still present
  expect(
    find.byKey(const Key('public-demo-internal-training-eng-02')),
    findsOneWidget,
  );
  // Next-step hint is visible in her card
  expect(
    find.byKey(const Key('public-demo-suzuki-training-hint')),
    findsOneWidget,
  );
});
```

### E. Sato's normal SkillSheet/sales route unchanged

```dart
testWidgets('Sato SkillSheet button is unaffected', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  expect(find.text('営業準備OK'), findsOneWidget);  // Sato only
  expect(find.text('SkillSheet確認'), findsOneWidget);  // Sato only
  // Confirm it belongs to 佐藤 健's card, not 鈴木 葵's
  final satoCard = find.ancestor(
    of: find.text('佐藤 健'),
    matching: find.byType(Card),
  ).first;
  expect(find.descendant(of: satoCard, matching: find.text('SkillSheet確認')),
    findsOneWidget);
});
```

### F. No Main Beginner Mode behavior changes

```dart
// Structural check: the fix file imports nothing from the main-mode
// domain and the test simply verifies Main-mode widgets are absent
// from the Public Demo screen tree.
testWidgets('Public Demo screen does not mount main-mode widgets', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  // No MainShell, no PrologueScreen, no TaskEngine-derived widget
  expect(find.byType(MainShell), findsNothing);
});
// (MainShell import not needed — just byType finder fails gracefully.)
```

### G. No finance/balance values change

Domain-level: no test needed because the fix touches only `ec()` (a Widget
method). No `PublicDemoAggregate` command is called. No new `setState` path
is added.

Verify by inspection: the proposed pseudocode above calls only `capabilityFor(e.id)`
(read-only) and renders `Text` widgets. No `_game =` assignment.

### H. 360px layout does not overflow

```dart
testWidgets('Suzuki card does not overflow at 360px width', (tester) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3.0;
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  // scrollUntilVisible confirms the card renders in the scroll view
  await tester.scrollUntilVisible(
    find.text('鈴木 葵'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  expect(tester.takeException(), isNull);
  addTearDown(tester.view.resetPhysicalSize);
});
```

### Future Playwright Assertion (post-production)

After the fix lands, add to the E2E suite:

```javascript
// e2e/public_demo_suzuki_p0.spec.ts
test('Suzuki shows training path explanation in April', async ({ page }) => {
  await page.goto('/?e2e=1');
  await expect(page.getByText('鈴木 葵')).toBeVisible();
  await expect(page.getByText(/52.*60|60.*52/)).toBeVisible();
  // No silent "今はできません"
  await expect(page.getByText('今はできません')).not.toBeVisible();
});
```

---

## 7. Conflict Analysis

### PR #111

Status: open (per task instructions, do not modify).  
The task says the implementation branch must not interact with PR #111.

The fix targets `ec()` in `public_demo_01_placeholder_screen.dart`. If
PR #111 modifies the same method, a rebase will be needed after #111 merges.
Likely **MUST REBASE AFTER** #111 if it touches `ec()`.

### PLAYTEST-SAVE-1B

Involves save/restore. If it changes `publicDemoInitialEngineerRuntimes` or
`PublicDemoEngineerRuntime.fromJson`, that could affect Suzuki's initial
`actualSkill`. The UI fix reads `capabilityFor(e.id)` dynamically — it will
display whatever the runtime holds, so the fix is **robust to skill value
changes** from save migrations.

Status: **CAN IMPLEMENT IN PARALLEL** (no shared files expected).

### PLAYTEST-BALANCE-1B

Involves balance. If Suzuki's initial skill is raised to ≥ 60, the new UI
block would no longer render (it's guarded by `!readyForFieldSales`), and
the fix silently becomes a no-op. That is acceptable — the fix is defensive.

Status: **CAN IMPLEMENT IN PARALLEL**. If BALANCE-1B lands first and raises
Suzuki's skill ≥ 60, the P0 resolves at domain level and the UI fix becomes
unreachable but harmless.

### FLOW-2A

Earlier planning incorrectly targeted Main Beginner Mode. This
implementation explicitly avoids all Main-mode classes. The fix is scoped
entirely to `ec()` in `public_demo_01_placeholder_screen.dart`.

Status: **No conflict** — FLOW-2A is superseded by this document.

### Summary Table

| Work item | Relation | Note |
|-----------|----------|------|
| PR #111 | MUST REBASE AFTER if it touches `ec()` | Check diff before branching |
| PLAYTEST-SAVE-1B | CAN IMPLEMENT IN PARALLEL | Fix is resilient to runtime value changes |
| PLAYTEST-BALANCE-1B | CAN IMPLEMENT IN PARALLEL | If skill raised ≥ 60, UI block becomes unreachable (harmless) |
| FLOW-2A | SUPERSEDED | This document replaces the mistargeted planning |

---

## 8. Implementation Prompt (PUBLIC-DEMO-P0-SUZUKI-1A)

> **Ready to paste to Codex. Do NOT execute in this task.**

---

```
TASK: PUBLIC-DEMO-P0-SUZUKI-1A

BRANCH: codex/public-demo-p0-suzuki-1a
  Branch from: origin/main (commit 817f3b6 or the current HEAD of main
  at implementation time). Rebase on top of PR #111 after it merges if
  that PR touched public_demo_01_placeholder_screen.dart.

===========================================================
SCOPE GUARD — READ BEFORE WRITING ANY CODE
===========================================================

You MAY only modify:
  lib/ui/public_demo/public_demo_01_placeholder_screen.dart
  test/ui/public_demo/public_demo_01_suzuki_p0_test.dart  (new file)

You MAY NOT touch:
  - lib/game/public_demo/public_demo_engineer_runtime.dart
    (do not change actualSkill, isReadyForFieldSales, threshold, or any
    runtime field)
  - lib/game/public_demo/public_demo_sales.dart
    (do not change Suzuki's initial engineer definition)
  - lib/game/public_demo/public_demo_state.dart
  - lib/game/public_demo/public_demo_aggregate.dart
  - lib/game/public_demo/public_demo_workflow_state.dart
  - Any file in lib/game/ not listed above
  - Any file in lib/ui/ other than public_demo_01_placeholder_screen.dart
  - Any domain model, salary, assignment, or finance file
  - Any Main Beginner Mode file (TaskEngine, BeginnerModeEngine,
    BeginnerModeState, GameEngine, GameState)
  - pubspec.yaml, assets/, or any test file not listed above

===========================================================
AUTHORITY
===========================================================

Code authority: origin/main
Suzuki's actual skill:   52  (publicDemoInitialEngineerRuntimes[1].actualSkill)
isReadyForFieldSales:    actualCapability >= 60
Training unlocks sales:  domain already handles this; no domain change needed

These values are read dynamically via capabilityFor(e.id) — do NOT
hardcode the number 52 in the UI. Read it from the existing method.
The threshold 60 MAY be inlined as a literal (it is already a literal
in the domain; a named constant is future scope).

===========================================================
PROBLEM STATEMENT
===========================================================

In ec(int i), when:
  e.stage == PublicDemoSalesStage.waiting
  AND readyForFieldSales(e.id) == false

The card currently renders:
  • Name + "待機" badge
  • Summary text
  • PublicDemoSalesProgress at step 0
  • internalTrainingCard (no explanation of its connection to sales unlock)
  • Nothing else

The player does not know:
  - WHY Suzuki cannot proceed to sales
  - WHAT her current skill is vs the required threshold
  - THAT training will eventually unlock the sales path

This is the P0 blocker.

===========================================================
MINIMUM UI BEHAVIOR
===========================================================

Add, inside ec(int i), AFTER PublicDemoSalesProgress and BEFORE
internalTrainingCard, under the branch
  e.stage == PublicDemoSalesStage.waiting && !readyForFieldSales(e.id):

1. A compact status row (widget key: 'public-demo-suzuki-not-ready-label')
   showing current skill vs threshold:
   "スキルが営業基準に達していません（現在 [capabilityFor(e.id)] / 60）"
   — use a subdued error or muted color; do NOT use red bold; this is
   informational, not alarming.

2. A next-step hint (widget key: 'public-demo-suzuki-training-hint')
   ONE line below the training card:
   "社内研修でスキルを伸ばすと、基準（60）到達後に営業準備を開始できます。"
   — use bodySmall style, subdued color.

Widget keys must use the engineer id, not the name, so they work for any
future below-threshold engineer. Use Key('public-demo-not-ready-${e.id}')
for the status label and Key('public-demo-training-hint-${e.id}') for the
hint. The test plan below references these keys.

Do NOT add:
  - A new HomeRecommendedActionKind
  - A new Hiyori navigator entry
  - A dialog or modal
  - Any route or navigation
  - Any setState call
  - Any new import beyond what public_demo_01_placeholder_screen.dart
    already imports

===========================================================
EXPLICIT NON-GOALS
===========================================================

- Do NOT change Suzuki's initial actualSkill (52)
- Do NOT change the isReadyForFieldSales threshold (60)
- Do NOT change Sato's sales path
- Do NOT change any finance, salary, or balance value
- Do NOT change any Main Beginner Mode file
- Do NOT add a new domain concept or a new gameplay mechanic
- Do NOT modify PR #111

===========================================================
NEW TEST FILE
===========================================================

Create: test/ui/public_demo/public_demo_01_suzuki_p0_test.dart

Include all of the following tests:

A. 'Suzuki is visible on fresh Public Demo'
   — expect find.text('鈴木 葵') and find.text('待機') both find one widget

B. 'Suzuki card shows not-ready label when skill < 60'
   — expect find.byKey(Key('public-demo-not-ready-eng-02')) finds one widget
   — expect find.text('今はできません') finds nothing (vague text excluded)
   — expect find.textContaining('52') finds at least one widget (domain value)
   — expect find.textContaining('60') finds at least one widget (threshold)

C. 'Suzuki card shows training hint'
   — expect find.byKey(Key('public-demo-training-hint-eng-02')) finds one widget
   — expect find.byKey(Key('public-demo-internal-training-eng-02')) finds one widget

D. 'Sato SkillSheet button is unaffected'
   — expect find.text('営業準備OK') finds one widget
   — expect find.text('SkillSheet確認') finds one widget
   — verify it is inside 佐藤 健's card

E. 'No Main-mode widgets mounted'
   — pump PublicDemo01PlaceholderScreen
   — expect find.text('Main') or any known Main-mode label is not found

F. '360px layout does not overflow'
   — set physicalSize = Size(360 * 3, 800 * 3), devicePixelRatio = 3.0
   — pump and scrollUntilVisible '鈴木 葵'
   — expect tester.takeException() isNull
   — addTearDown(tester.view.resetPhysicalSize)

===========================================================
VALIDATION COMMANDS
===========================================================

Run these before pushing:

  flutter analyze lib/ui/public_demo/public_demo_01_placeholder_screen.dart
  flutter test test/ui/public_demo/public_demo_01_suzuki_p0_test.dart --reporter=expanded
  flutter test test/ui/public_demo/ --reporter=compact
  flutter test test/game/public_demo/ --reporter=compact

All must pass with zero failures.

===========================================================
PUSH TARGET
===========================================================

git push -u origin codex/public-demo-p0-suzuki-1a

Do NOT open a PR until the validation commands pass clean.

===========================================================
COMPLETION MARKER
===========================================================

When all validation commands pass and the branch is pushed, output:

  PUBLIC-DEMO-P0-SUZUKI-1A IMPLEMENTATION COMPLETE
  Branch: codex/public-demo-p0-suzuki-1a
  Tests: [N] passed
  Sato unchanged: YES
  Balance changed: NO
```

---

## Summary

**PUBLIC DEMO TARGET VERIFIED:**
YES

The `#/public-demo-01` route loads `PublicDemo01PlaceholderScreen` directly.
Suzuki Aoi (`eng-02`) is rendered by `ec(int i)`. Her runtime lives in
`publicDemoInitialEngineerRuntimes[1]`. Everything traced from route to pixel —
no inference from Main Beginner Mode.

**ROOT CAUSE:**
`actualCapability = 52 < 60` → `isReadyForFieldSales = false` → `ec()` renders
no explanation, leaving the player with a silent, unlabelled blocked state.

**BALANCE CHANGE REQUIRED:**
NO

**MINIMUM FIX:**
Add two Text widgets inside `ec()` under the
`waiting && !readyForFieldSales` branch: one showing current skill vs threshold
(domain-backed via `capabilityFor()`), one explaining that training unlocks
the sales path. No domain file changes. No new commands. No navigator entry.

**SAFE TO IMPLEMENT:**
YES — the change is purely additive UI text in one method of one file,
gated by the existing `readyForFieldSales` predicate, with no side effects.

**IMPLEMENTATION TARGET FILES:**

```
PRIMARY (modify):
  lib/ui/public_demo/public_demo_01_placeholder_screen.dart

NEW (create):
  test/ui/public_demo/public_demo_01_suzuki_p0_test.dart

READ-ONLY AUTHORITY (do not modify):
  lib/game/public_demo/public_demo_engineer_runtime.dart
  lib/game/public_demo/public_demo_sales.dart
```

---

PUBLIC-DEMO-P0-SUZUKI PREIMPLEMENTATION READY
