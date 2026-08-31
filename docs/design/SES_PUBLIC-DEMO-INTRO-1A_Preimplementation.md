# SES_PUBLIC-DEMO-INTRO-1A — Preimplementation Design

Status: audit / design only. No production code, tests, or workflows were
changed to produce this document. All file/line references below are read
directly from `origin/main` (audited tip: `68b235f`, plus the pending
readiness re-audit at `f7ef8f1` / `docs/review/SES_PUBLIC-DEMO-READINESS-2A_Premerge_Audit.md`
on branch `claude/public-demo-readiness-audit-j2i0qq`, not yet merged).

Note on repository state at authoring time: the branch this document was
written on (`claude/public-demo-intro-audit-m2pmal`) was created from a
minimal domain-only ancestor (`claude/ses-game-core-phase-0-h7e8om`) and
does not itself contain the Public Demo UI. Every file this document
references was read via `git show origin/main:<path>` and exists only on
`origin/main` (and the readiness-audit branch for the audit report itself).
Implementation of this design must branch from `origin/main`, not from this
document's own branch point.

## Source: the P1 finding this resolves

`docs/review/SES_PUBLIC-DEMO-READINESS-2A_Premerge_Audit.md`, **FINDING-2**:

> No first-time onboarding: objective, player role, and win/lose conditions
> are never stated. ... Minimal intervention: A single short intro
> card/dialog on first load stating role + goal + fail condition, shown
> once (state-gated so it doesn't repeat on reload).

That audit's own recommendation already points at Option A below. This
document verifies that recommendation against the actual code and turns it
into an exact, boundary-checked implementation plan.

---

## 1. Current fresh-start UX

Entry: `resolveAppExperience()` (`lib/app/app_entry.dart`) routes the URL
fragment `#/public-demo-01` to `AppExperience.publicDemo01`, which
`lib/main.dart`'s `_GameRoot` renders as a bare
`PublicDemo01PlaceholderScreen()` — no prologue, no start-choice screen, no
character creation. This is deliberate: the full "development" experience
has a Prologue (`lib/ui/prologue/prologue_screen.dart`) that explicitly
states the player is "社長" (president) and the loop ("技術者を採用し、案件へ
参画させ、取引先から売上を得ます" — recruit engineers, get them assigned to
projects, earn revenue from clients); **Public Demo 0.1 skips that screen
entirely** and gives the player none of that framing.

On first paint (`_S.initState` → `_restoreAggregate()`,
`public_demo_01_placeholder_screen.dart:86-111`):

1. `widget.saveService.load()` is awaited (100ms timeout, best-effort).
2. If it returns `null` (true first visit, or after an explicit restart —
   see §7), `_game = PublicDemoAggregate.initial()`, i.e.
   `PublicDemoState.aprilStart()`: month 4 (April), cash ¥4,000,000, two
   engineers already on staff and `waiting`.
3. `_isRestoring` flips to `false` and the screen renders — no dialog, no
   banner, no onboarding screen precedes it.

What the player sees immediately, top to bottom
(`public_demo_01_placeholder_screen.dart:1902-1990`):

- `AppBar`: `"S.E.S. Public Demo 0.1"` + a small build-info label.
- `PublicDemoCashShortageCard` (empty/invisible — `financialStatus` is
  `normal`) and the bankruptcy terminal card (absent).
- `PublicDemoHomeDashboardSection` — month header (`4月`), KPI tiles
  (現金 ¥400万, 技術者数 2名, 参画中 0名, 売上 ¥0), the Navigator card
  (fixed line: *"総務の佐倉です。今月もよろしくお願いします。"*), and the
  Recommended Action slot: for a fresh April start this resolves to
  `employeeSkillSheetReview` for 佐藤健 — headline *"佐藤 健のSkillSheetを
  確認"*, CTA button labelled **"SkillSheetを確認"**
  (`lib/presentation/home/widgets/recommended_action_section.dart`,
  key `home-recommended-action`).
- Office Stage, per-employee stage cards, Important Events, Finance
  Summary, and the raw per-employee action cards below.

Nothing on this screen states: that the player is the company's
president/manager; what "SES" the game's genre even means; that the goal
is to sell engineers' time and keep cash positive; that April is turn 1 of
a fiscal year ending in March; or what happens if cash runs out. All of
that is either shown only as *numbers* (cash, KPIs) with no framing, or not
shown at all until the player is already deep enough to trigger it (e.g.
the cash-shortage dialog only exists once `financialStatus ==
cashShortage`, which is a failure state already in progress).

## 2. Concrete onboarding gaps (mapped to the design target)

| # | Design target requirement | Currently stated in-UI? | Where (if anywhere) |
|---|---|---|---|
| 1 | Player role (president/sales) | **No** | Only in the *development* Prologue, which Public Demo never shows |
| 2 | Immediate objective (ready engineers → win orders → don't run out of cash) | **No** | KPI tiles show the *numbers* (現金/技術者数/参画中/売上) with no stated relationship between them; the month-goal fallback text is close but only appears when no Recommended Action exists |
| 3 | Time structure (April start, monthly, FY ends March) | **Partially, implicitly** | `MonthHeaderBar` shows `4月`; nothing states "this is month 1 of 12, ending in March" |
| 4 | Failure condition (cash shortage → bankruptcy) | **No, until already failing** | `PublicDemoCashShortageCard` / `_showCashShortageExplanation` only render once `financialStatus == cashShortage` — i.e. after the player is already one bad month from bankruptcy |
| 5 | First action understandable | **Partially** | The Recommended Action card (`home-recommended-action`) already exists, is prominent, and is a full-width CTA — but a first-time player has no stated reason "SkillSheetを確認" is the right first move or what a SkillSheet even is |

Grepping `public_demo_01_placeholder_screen.dart` and
`home_navigator_display.dart` for チュートリアル/遊び方/ゲームの目的/目標/
ミッション/社長/資金不足すると/倒産すると confirms: zero matches for any of
these except the reactive (already-failing) cash-shortage/bankruptcy copy.

## 3. Option comparison

| | **A. One-time intro dialog** | **B. Compact intro card on HOME** | **C. First-launch guided explanation via existing components** |
|---|---|---|---|
| **Description** | A single `showDialog` (AlertDialog-style, matching the existing `_showCashShortageExplanation`/`PublicDemoEventDialog` pattern) shown once before the player's first interaction | A permanent-until-dismissed `Card` inserted into the existing `ListView`, above or below `PublicDemoHomeDashboardSection` | Reuse the Recommended Action / Navigator slots to *sequence* 4-5 existing-style bubbles/cards across the first few taps (a mini walkthrough) |
| **Implementation size** | Smallest: 1 new small widget (~60-90 lines) + one call site in `initState`/first build; no new persistent widget, no layout change | Small-medium: new permanently-laid-out widget, needs its own dismiss state, and pushes every card below it down the scroll — directly reopens the exact "action pushed below the fold" regression HOME-RUNTIME-2A/2B/2C were fought to fix (see `public_demo_01_home_consolidation_test.dart`'s own history) | Largest: needs a sequencing/step state machine layered across multiple existing widgets, new coordination logic, new "next" affordances on each — this is a tutorial engine in substance even if built from existing parts |
| **Mobile 360px impact** | None to layout (an overlay; scroll position/heights of the real screen are untouched) | Directly reduces the first-view viewport budget the 2A/2B/2C work explicitly protected (`public_demo_01_home_consolidation_test.dart` pins the Recommended Action CTA inside the "painted, browser-chrome-budgeted, genuinely tappable" viewport at 360×~640) | Same risk as B, multiplied across every step, plus each step's own overflow risk |
| **Persistence implications** | None required — can key off "no save existed on load" (see §5) | Needs its own dismissed-state; without persistence it re-renders every reload as a layout-shifting card (worse than a dialog reappearing) | Needs step-position persistence to avoid re-running the whole sequence on every reload — the most persistence surface of the three |
| **Replay/restart behavior** | Naturally re-appears only on a genuinely fresh aggregate (see §7) — no special-casing needed | Same re-appearance question, but now entangled with layout, not just a modal | Same, but a partially-completed sequence on restart is an extra state to define |
| **E2E impact** | One extra "dismiss the intro dialog" step, added once, in the same place every other Public Demo dialog is already dismissed by taps in the (currently design-only) canonical E2E journey | Every existing/future first-view text-position assertion (`public_demo_01_home_consolidation_test.dart`, the planned canonical E2E journey) shifts and must be re-baselined | Same shift, repeated per step, and the sequence's own step-transition timing becomes new flake surface |
| **Accessibility** | `AlertDialog`/`GameEventModal` already carries semantics (`semanticLabel`, focus trap) via existing production code paths — no new a11y work | A permanent card needs the same care as any other HOME card (already handled elsewhere) but adds one more competing landmark to the one-screen semantics tree | Multiple sequenced overlays multiply the same work, plus focus management between steps |
| **Risk of blocking repeat/experienced testers** | Lowest: appears once per genuinely fresh session, one tap to dismiss, never blocks an in-progress or returning session | Medium: a dismissible-but-not-yet-dismissed-forever card is visible (and pushes content down) on every session until explicitly dismissed and that dismissal is remembered — same persistence question as A but with a layout cost attached | Highest: any experienced tester who reaches Public Demo a second time (e.g. after a bug-triggered restart) re-enters a multi-step sequence unless step state is persisted and correctly resumed/skipped |

**Recommendation: Option A — a one-time intro dialog.** It is the only
option that satisfies "smallest," leaves HOME's already-tuned first-view
layout untouched, needs no new persisted field, and cannot regress the
existing 360px first-view budget that three prior phases (2A/2B/2C) were
specifically about protecting. B risks re-opening exactly the layout
problem those phases fixed; C is a tutorial engine by another name, which
is explicitly out of scope.

## 4. Exact proposed Japanese player-facing copy

Dialog title:

```
ようこそ、S.E.S.へ
```

Dialog body (three short paragraphs, in order — role+objective, time+
failure, pointer to the existing first action):

```
あなたはこの会社の社長です。技術者を育成・営業して案件を受注し、
会社の売上を伸ばしていきましょう。

4月に創業し、毎月経営を進めます。翌年3月の決算までに資金が不足した
状態が続くと、倒産してプレイは終了します。

まずは「次にやること」カードの案内に沿って、最初の操作を進めましょう。
```

Dismiss button:

```
はじめる
```

Copy design notes:

- **"次にやること"** is quoted verbatim from
  `recommended_action_section.dart`'s own eyebrow label (`_ActionCard`'s
  `Text('次にやること', ...)`) — the intro *points at* the existing card by
  its exact on-screen name rather than re-describing or renaming it, so
  there is no duplicated or drifting vocabulary between the intro and the
  card it references.
- No cash figure, engineer count, or month number is restated — those are
  already on-screen the instant the dialog closes (KPI tiles, month
  header), consistent with the "do not duplicate what's already visible"
  instruction.
- "資金が不足した状態が続くと、倒産して" mirrors the existing bankruptcy
  card's own phrasing register (`'資金不足の状態で月次決算を迎え、再度赤字と
  なったため倒産が確定しました。'`) without copying its sentence, since that
  card is reactive/post-hoc and this one is proactive.
- Deliberately does **not** explain SkillSheet, sales stages, or any
  mechanic beyond what's needed to make the Recommended Action card's
  presence make sense — the mechanic itself is explained by the existing
  in-context UI (stage labels, the Recommended Action headline, the
  cash-shortage dialog when it becomes relevant).

## 5. Proposed UI placement

A `showDialog<void>` call, barrier-dismissible off (consistent with how
`GameEventModal`'s existing critical dialogs are typically used — the
player must tap the CTA, not tap outside), triggered from
`_S._restoreAggregate()` (`public_demo_01_placeholder_screen.dart:92-111`)
**only in the branch where `restored == null`**, scheduled via
`WidgetsBinding.instance.addPostFrameCallback` after the `setState` that
finishes restoring, so the dialog opens over an already-painted first
frame rather than blocking initial paint.

New widget: `PublicDemoIntroDialog` (`StatelessWidget`), in a new file
`lib/ui/public_demo/public_demo_intro_dialog.dart`, following the same
shape as the existing `PublicDemoEventDialog` (a thin wrapper around
`GameEventModal`, no `imageAsset` — `GameEventModal.imageAsset` is already
nullable, so this needs no new asset). Keys:

- `Key('public-demo-intro-dialog')` on the dialog root.
- `Key('public-demo-intro-dialog-confirm')` on the `はじめる` button.

This is an overlay only — it adds no widget to `HomeDashboardSection`'s
`ListView`, changes no scroll offset, and cannot affect the 360px
first-view budget `public_demo_01_home_consolidation_test.dart` pins.

## 6. Affected production files

| File | Change |
|---|---|
| `lib/ui/public_demo/public_demo_intro_dialog.dart` | **New.** `PublicDemoIntroDialog` widget (copy from §4), no state, no game references. |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | Add a private `Future<void> _showFreshStartIntroIfNeeded()` called from `_restoreAggregate()` when `restored == null` (see §7 for the restart call site too). No change to any existing method's behavior, no new field beyond a `bool` guard against double-showing within one widget lifetime (not persisted — see §8). |

No other production file changes. Specifically unaffected: `HomeDashboardDisplayData`, `HomeRecommendedActionKind`/`recommended_action_section.dart`, `HomeNavigatorIdentity`/`home_navigator_display.dart`, `PublicDemoSaveService`, `PublicDemoSaveCodec`, `PublicDemoAggregate`/`PublicDemoState`, finance/sales/recruitment/Suzuki-eligibility logic, Main Beginner Mode, and every E2E helper file.

## 7. Replay / restart behavior

`_restartGame()` (`public_demo_01_placeholder_screen.dart:589-608`) clears
the save (`widget.saveService.clear()`) and, on success, sets `_game =
PublicDemoAggregate.initial()` directly — it does **not** re-run
`_restoreAggregate()`. To keep restart behaviorally consistent with a true
fresh load (same signal, same outcome), `_restartGame()` should also
schedule the intro dialog on success, using the same
`_showFreshStartIntroIfNeeded()` call. This is a deliberate design choice:
an explicit restart is a genuinely new playthrough, and the dialog is a
single low-friction tap — re-showing it there is more consistent than
special-casing "restart doesn't count," and avoids inventing a second
notion of "fresh" that could drift from the first.

## 8. Persistence decision

**No new persisted field. No save-schema change.**

The "was this a fresh start" signal the intro needs already exists at the
exact call site that needs it: `_restoreAggregate()`'s local `restored`
variable is `null` precisely when there was no prior save to load — the
same condition that already selects `PublicDemoAggregate.initial()` over
the restored aggregate. The intro's visibility can be derived from that
existing boolean with zero additions to `PublicDemoState`,
`PublicDemoAggregate`, or `PublicDemoSaveCodec`.

Why not persist an explicit `introSeen` flag:

- It would require either widening `PublicDemoAggregate`'s save schema
  (touching `PublicDemoSaveCodec`'s encode/decode and its cross-field
  "authority facts" validation, explicitly called out as high-risk/DO-NOT
  in scope) or a second, independent `SharedPreferences` key.
- Even the independent-key option buys nothing the derived signal
  doesn't already give for free: it would need its own write-on-dismiss,
  its own best-effort-failure handling (mirroring `PublicDemoSaveService`),
  and a decision about whether `_restartGame()`'s `clear()` should also
  clear it — all solved automatically by deriving from `restored == null`
  instead.
- The one behavioral difference a persisted flag would add is
  suppressing a second showing if a player dismisses the dialog and
  refreshes *before* their first action ever gets saved (no
  `_commitAggregate` has run yet, so `load()` still returns `null` next
  time). This is judged an acceptable, low-severity edge case (one extra
  tap, no functional harm, no data loss) rather than a strong enough UX
  reason to add persisted state — consistent with the brief's "prefer
  avoiding a new persisted field unless there is a strong UX reason."

Net effect: `docs/review/...READINESS-2A...`'s own phrasing — "shown once
(state-gated so it doesn't repeat on reload)" — is satisfied for every
case that matters (an in-progress or completed session never sees it
again), using state that already exists.

## 9. Tests required

New:

- `test/ui/public_demo/public_demo_intro_dialog_test.dart` — pumps
  `PublicDemoIntroDialog` in isolation: renders title/body/button text,
  the confirm button pops the dialog, no `RenderFlex` overflow at a 360×800
  test surface.
- A new group inside `test/ui/public_demo/public_demo_01_persistence_test.dart`
  (or a new `public_demo_01_intro_test.dart`, matching that suite's existing
  fake-`PublicDemoSaveService` pattern):
  - A fake save service whose `load()` resolves to `null` → after
    `pumpAndSettle()`, the intro dialog (`Key('public-demo-intro-dialog')`)
    is present.
  - A fake save service whose `load()` resolves to a non-null aggregate
    (simulating a returning player mid-game) → after `pumpAndSettle()`, the
    intro dialog is **absent**.
  - Tapping `public-demo-intro-dialog-confirm` closes the dialog and the
    underlying screen (Recommended Action CTA, KPI tiles) is interactable
    immediately after.
  - After a successful `_restartGame()` (tap `public-demo-restart-button`
    from a reachable terminal state, or drive directly via the same helper
    existing bankruptcy tests use), the intro dialog reappears once.

Existing tests requiring an update (ripple effect — see §10 Risks): every
test in `test/ui/public_demo/` that constructs
`PublicDemo01PlaceholderScreen` fresh (a `load()`-returns-null save
service, which is the default/implicit behavior in ~20 existing test files
per a repository grep) will now see the intro dialog block the widget tree
until dismissed. Each such test's first `pumpAndSettle()` needs one added
step: dismiss the intro (tap `public-demo-intro-dialog-confirm`, or use a
new shared test helper — e.g. `dismissPublicDemoIntroIfPresent(tester)` —
added once to a shared test-support file and called at the top of each
affected test's setup) before its existing assertions run. This is
mechanical, not a design change, but it is real, non-trivial churn across
the existing suite and should be budgeted as the largest single line item
in implementation effort.

## 10. E2E implications

- `docs/design/SES_PUBLIC-DEMO-E2E-1B_Final_Design.md` (design-only,
  unmerged, branch `claude/public-demo-e2e-1b-design-my9oza`) defines a
  canonical fresh-start journey whose step 2 ("Fresh April") asserts
  `'4月'`, `'社員ステージ'`, `'佐藤 健'` are visible immediately after load.
  Once this change ships, that step must add one action first: dismiss the
  intro dialog (tap the button matching `'はじめる'`) before those
  assertions run. This is a one-line addition to a not-yet-implemented
  design, not a change to any shipped E2E spec.
- No currently-shipped Playwright spec under `e2e/tests/` exercises
  `#/public-demo-01` today (they cover the separate Founding
  Prologue/Beginner Mode experience via `ses-player.ts`/
  `beginner-mode-player.ts`), so this change has **zero impact on any
  currently-passing E2E test**.
- The dialog must be reachable/dismissible under the existing `?e2e=1`
  semantics-forcing hook (`lib/main.dart`'s `SemanticsBinding...
  ensureSemantics()`) with no special-casing — `GameEventModal`-based
  dialogs already are, since every other Public Demo event dialog
  (`PublicDemoEventDialog`, the raise/bonus/interview dialogs) already
  relies on exactly that mechanism today.
- No change to E2E retry/timeout/skip/sleep configuration of any kind.

## 11. Risks

- **Existing widget-test churn (§9).** The largest concrete cost of this
  change. Mitigate with one shared test helper rather than 20 hand-edited
  call sites.
- **Barrier-dismissible choice.** Setting `barrierDismissible: false`
  means a player who taps outside the dialog by accident cannot escape it
  without reading the button — intentional (this is the one thing the
  audit says must not be skippable), but should be confirmed against
  house style for other "must-acknowledge" dialogs in this codebase before
  implementation (the cash-shortage explanation dialog is the closest
  precedent to check).
- **Double-show edge case (§8).** A refresh between dismissing the intro
  and the first autosaved action re-shows it once. Accepted as low
  severity; flagged here so it isn't rediscovered as a "bug" later.
- **Copy drift.** The dialog references "次にやること" by literal string.
  If that label ever changes, the intro's pointer sentence silently stops
  matching the on-screen label. Low risk (both live in the same PR's blast
  radius if ever touched), but worth a one-line comment at both sites
  cross-referencing each other, following this codebase's existing
  practice of same-value cross-referencing (e.g.
  `home_navigator_display.dart`'s comments about `HomeRecommendedAction*`).
- **Scope creep temptation.** Because the intro dialog is the first new
  "explain the game" surface, there will be a temptation to fold in
  FINDING-3 (low-content months) or FINDING-4 (no restart-after-win)
  messaging here. Both are explicitly out of scope for this ticket and
  should be left to their own tickets.

## 12. Acceptance criteria

1. On a genuinely fresh Public Demo session (no prior save in this
   browser/profile), the intro dialog appears before the player can
   interact with any other control on the screen, states all five design-
   target points (role, objective, time structure, failure condition,
   pointer to the first action), and is dismissed by a single tap.
2. On any session where a save already exists (returning player,
   mid-playthrough reload, page refresh after any action has been taken),
   the intro dialog does **not** appear.
3. After an explicit restart (`最初からやり直す`), the intro dialog appears
   again exactly once for that new playthrough.
4. No existing HOME layout, KPI value, Recommended Action behavior,
   Navigator copy, finance/sales/recruitment logic, Suzuki eligibility
   rule, or persisted save schema changes as a result of this work.
5. The dialog renders with no overflow at 360×800 (and the existing
   390×844 comparison point) and is reachable/dismissible under `?e2e=1`
   semantics.
6. All new tests (§9) pass, and every existing test that pumps
   `PublicDemo01PlaceholderScreen` fresh continues to pass with the
   mechanical dismiss-step update.
7. `flutter analyze` / the project's existing lint config passes with no
   new warnings.

## 13. Implementation scope boundaries

Explicitly **in scope**:

- One new dialog widget (`PublicDemoIntroDialog`).
- One new trigger call site in `_restoreAggregate()`, and one in
  `_restartGame()`.
- The new tests in §9 and the mechanical dismiss-step update to existing
  Public Demo widget tests.

Explicitly **out of scope** (per the task brief, restated here for the
implementer):

- No HOME redesign — layout, KPI section, Office Stage, Navigator card,
  and Recommended Action section are untouched.
- No tutorial engine, no multi-step sequencing, no persisted step/progress
  state.
- No new gameplay systems.
- No finance/balance changes (starting cash, revenue formulas, expense
  constants — untouched).
- No sales/interview/recruitment authority changes.
- No Suzuki field-sales-eligibility changes.
- No persistence schema change (`PublicDemoState`, `PublicDemoAggregate`,
  `PublicDemoSaveCodec` all untouched — see §8).
- No Main Beginner Mode changes (a different `AppExperience` entirely).
- No E2E retry/timeout/skip/sleep configuration changes.
- No changes to FINDING-1 (entry-path/URL), FINDING-3 (low-content
  months), FINDING-4 (no restart-after-win), FINDING-5, or FINDING-6 from
  the readiness audit — those remain separate, already-scoped tickets.

---

## Ready-to-use Claude Code implementation prompt

```
Implement SES_PUBLIC-DEMO-INTRO-1A per
docs/design/SES_PUBLIC-DEMO-INTRO-1A_Preimplementation.md in this
repository (perusonao/smile_enjoy_story), branching from the current tip
of `main`.

Scope: add a one-time first-load intro dialog to Public Demo 0.1
(`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`) that states,
in Japanese: the player's role (会社の社長), the immediate objective
(engineers → sales → orders → don't run out of cash), the time structure
(April start, monthly progression, March fiscal year end), the failure
condition (sustained cash shortage → bankruptcy), and a pointer to the
existing "次にやること" Recommended Action card as the first concrete
action. Use the exact copy in §4 of the design doc.

Implementation:
1. New file lib/ui/public_demo/public_demo_intro_dialog.dart:
   PublicDemoIntroDialog, a StatelessWidget wrapping the existing
   GameEventModal (no imageAsset — it's already nullable), following the
   same shape as lib/ui/public_demo/public_demo_event_dialog.dart. Keys:
   Key('public-demo-intro-dialog') on the dialog root,
   Key('public-demo-intro-dialog-confirm') on the confirm button
   ("はじめる"). barrierDismissible: false.
2. In public_demo_01_placeholder_screen.dart, add a private
   _showFreshStartIntroIfNeeded() that shows PublicDemoIntroDialog via
   showDialog<void>, scheduled with
   WidgetsBinding.instance.addPostFrameCallback so it opens after the
   current frame. Call it from _restoreAggregate() only in the branch
   where `restored == null` (do NOT add any new persisted field — this
   reuses the existing local nullability of `restored` as the "fresh
   start" signal), and again from _restartGame() after a successful
   clear()+reset to PublicDemoAggregate.initial(). Do not persist an
   "intro seen" flag anywhere — see design doc §8 for why.
3. Do not touch: HomeDashboardDisplayData, home_recommended_action.dart,
   recommended_action_section.dart, home_navigator_display.dart,
   PublicDemoSaveService, PublicDemoSaveCodec, PublicDemoAggregate,
   PublicDemoState, any finance/sales/recruitment/Suzuki-eligibility
   logic, Main Beginner Mode, or any E2E config
   (retry/timeout/skip/sleep).

Tests:
1. New test/ui/public_demo/public_demo_intro_dialog_test.dart: renders
   PublicDemoIntroDialog standalone, asserts title/body/button text is
   present, confirm button pops the dialog, no RenderFlex overflow at a
   360x800 test surface.
2. New test group (new file or appended to
   test/ui/public_demo/public_demo_01_persistence_test.dart, matching its
   existing fake-PublicDemoSaveService pattern):
   - load() resolving to null -> intro dialog present after
     pumpAndSettle().
   - load() resolving to a non-null aggregate -> intro dialog absent.
   - Tapping the confirm key closes the dialog and the screen underneath
     (Recommended Action CTA, KPI tiles) is interactable.
   - After a successful restart (drive _restartGame's tap path from a
     reachable terminal state), the intro dialog reappears once.
3. Add a small shared test helper (e.g.
   `Future<void> dismissPublicDemoIntroIfPresent(WidgetTester tester)`) and
   call it at the top of every existing test/ui/public_demo/*_test.dart
   file that constructs PublicDemo01PlaceholderScreen with a
   load()-returns-null save service, immediately after that test's first
   pumpAndSettle(), so those tests keep passing under the new dialog. Grep
   the test directory for `PublicDemo01PlaceholderScreen(` to find every
   call site — there are roughly 20.

Validation before you consider this done:
- flutter analyze — no new warnings.
- flutter test test/ui/public_demo/ — full pass, including every
  pre-existing file touched by the shared-helper update.
- Confirm no widget outside the new dialog file changed behavior: diff
  should be additive except for the two call sites in
  public_demo_01_placeholder_screen.dart and the mechanical test-helper
  insertions.
- Manually verify (via `flutter run -d chrome` or equivalent) that at a
  360px-wide viewport the dialog has no overflow and the confirm button is
  reachable without scrolling.

Do not implement anything from the readiness audit's other findings
(entry-path/URL, low-content months, no restart-after-win, order/cash
wording, silent persistence) — those are separate tickets.
```

---

PUBLIC-DEMO-INTRO-1A PREIMPLEMENTATION READY
