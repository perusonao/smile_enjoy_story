# SES PUBLIC-DEMO-HOME-UI-3B — Result Report

Issue: [#171](https://github.com/perusonao/smile_enjoy_story/issues/171)
Branch: `claude/public-demo-home-ui-3b-3aj3ur`
Audited main SHA (fresh start point): `76ca2b0b6dd598e5d18ed9a88379bf20b95ed79c`

## 1. Audit / sizing decision

Fresh `origin/main` was audited before any change. The Public Demo screen
(`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`) was a single
3,282-line `StatefulWidget` rendering one `Scaffold` with one `ListView`:
HOME's summary sections, the full per-employee sales/SkillSheet/training
cards, the applicant/recruiting funnel, the assignment/project-continuation
pipeline, the finance detail (monthly cash-flow card, payroll/fixed-cost
summary, summer-bonus decision), and the dev/test menu all lived in that
one scrollable list. `NavigationBar.onDestinationSelected` called
`Scrollable.ensureVisible`/`ScrollController.animateTo` against anchors
inside that same list — `selectedIndex` was hardcoded to `0` (ホーム) because
there was no second surface to select.

19 existing widget-test files under `test/ui/public_demo/` (~7,600 lines)
drive this screen end-to-end through real `PublicDemoAggregate` commands —
the majority interleave employee sales-progression, recruiting, and
assignment actions with month-close taps in the same test function. Moving
that content off HOME (required by the Issue's own acceptance criteria)
necessarily breaks every one of those interaction points, regardless of how
the five tabs' content is apportioned — this is inherent to the requested
architecture change, not a consequence of a particular slicing choice.

**Decision:** the full five-tab redistribution (not a Slice A/B split) was
judged safely completable in this session once the test-file rework was
recognized as mechanical (a shared tab-switch helper + inserting one call
before each interaction on content that moved) rather than a redesign of
each test's intent. All five tabs were built with real content in this PR;
the Issue's own "Slice B: quick-access routing + final verification" framing
is reflected here only as the documented known gaps below (deep-link
precision for a couple of cross-cutting actions) and the deployed
verification the Issue explicitly reserves for the repo owner.

## 2. Root cause / old anchor behavior

`_handleBottomNavSelection` (the `NavigationBar` callback) mapped each of
the five destinations to a `_scrollToSection(GlobalKey)`/`_scrollToTop()`
call against the one shared `ListView`. Tapping 社員/営業/会計/メニュー never
changed what was mounted — it only animated the scroll offset to a
`GlobalKey`'s current position inside HOME's own list, and
`NavigationBar.selectedIndex` stayed `0` unconditionally because the code's
own class doc said there was "genuinely no other 'current tab' to track
without inventing one." This is exactly the behavior Issue #171 (following
deployed Screen Verification of #147) asks to replace: bottom navigation
must switch between real logical tab surfaces.

## 3. Architecture chosen

`_S` (the screen's `State`) gained one field, `int _selectedTabIndex`, and
`build()` now does:

```dart
body: ... switch (_selectedTabIndex) {
  _employeesTabIndex => _buildEmployeesTab(c),
  _salesTabIndex => _buildSalesTab(c),
  _accountingTabIndex => _buildAccountingTab(c),
  _menuTabIndex => _buildMenuTab(c),
  _ => _buildHomeTab(c, navigatorAdvice),
},
```

Deliberately a **conditional single-tab build**, not an `IndexedStack`: only
the selected tab's widget subtree is ever constructed. This was chosen over
`IndexedStack` for two reasons:

- It makes "HOME no longer contains the full employee detail/training list"
  (etc.) a **structural** fact — a non-selected tab's content is not merely
  painted-over or excluded from hit-testing, it does not exist in the tree —
  rather than a visual one `find.byKey`/`find.text` could still trivially
  satisfy from an off-screen branch.
- It avoids a well-known Flutter-testing pitfall where `IndexedStack` lays
  out every child at the same position, so a test that forgets to switch
  tabs first can silently tap through to the wrong (currently-visible)
  widget instead of failing.

The five destinations, each a `NavigationDestination` with its own explicit
`Key` (`public-demo-nav-{home,employees,sales,accounting,menu}`) for
unambiguous test targeting:

- `NavigationBar.selectedIndex: _selectedTabIndex` — the highlighted
  destination and the rendered body can never disagree, because both read
  the same field.
- `onDestinationSelected: _handleBottomNavSelection` calls `_switchTab`
  (a plain `setState`), except re-tapping ホーム while already selected,
  which scrolls that tab back to the top (the one convenience carried over
  from the retired scroll-jump design — still never touches domain state).
- Every quick-access item, the Navigator card's secondary "他の行動を確認する"
  route, and the important-task 営業/採用/資金計画 CTAs now call `_switchTab`
  (via `_scrollToOtherActions`, kept as the shared name since several
  destinations reuse it) instead of `_scrollToSection`.
- Restarting the game (`_restartGame`, used by both the bankruptcy terminal
  card and the Menu tab's test-only restart control) resets
  `_selectedTabIndex` back to ホーム, so a fresh playthrough always starts
  on the summary/decision surface regardless of which tab restart was
  triggered from.

No new global router, no `Navigator.push`, no new package — the whole
change is local `State` on the existing screen, exactly as the Issue asks
("avoid introducing a new global router if a small local tab-shell/state
solution is sufficient").

## 4. Content mapping per tab

| Tab | Content (all reused verbatim — same widgets/methods/keys) |
|---|---|
| **ホーム** | Cash-shortage card, bankruptcy terminal card, header/KPI/Hiyori Navigator (`PublicDemoHomeDashboardSection`), monthly primary CTA, `HomeOfficeStageSection` (employee **summary** only), 今月の重要タスク, クイックアクセス. |
| **社員** | Per-employee sales-progression cards (`ec(i)`, all months) — identity, current status, SkillSheet/sales-preparation state, existing training action; `employeeConditionCard` (morale/trust/raise); standalone `internalTrainingCard`s; this month's growth results (split out of the former `dashboard()`). |
| **営業** | Recruitment-media card + applicant funnel (`ac(i)`, May); assignment/project-continuation cards (`assignmentCard(i)`, June); July's assignment-result narrative (`7月開始結果` + per-assignment `julyResult`). |
| **会計** | Monthly cash-flow card (the other half of the former `dashboard()`); `PublicDemoFinanceSummarySection` (payroll/fixed costs); summer-bonus decision card; the ${month}開始結果/給与反映/第1期終了 monthly-close narrative. |
| **メニュー** | `_publicDemoDevMenuSection()` verbatim — the collapsed-by-default 開発・テストメニュー toggle, the test-only April-restart control, `BuildInfoLabel`. |

Every widget/method above is the exact one PUBLIC-DEMO-HOME-UI-3A already
built — this PR only changes **which tab's `build` method constructs it**.
`dashboard()` is the only method actually split (into
`_monthlyCashFlowSection()` and `_growthResultsSection()`), purely to route
its two unrelated halves to their respective tabs; neither half's content,
key, or authority changed.

## 5. Domain / save-schema impact

**None.** No file under `lib/game/public_demo/` changed. No command,
guard, formula, or persistence codec changed —
`PublicDemoSaveCodec`/`PublicDemoAggregate` are untouched, and
`test/ui/public_demo/public_demo_01_persistence_test.dart`'s own
`envelope['aggregate']` assertion (`isNot(contains('selectedTab'))`) pins
that the new `_selectedTabIndex` field is not persisted — it is pure UI
state, reset to ホーム on every fresh load/restart. Month Guard, Recovery
Loop, First Fun Year balance, and the Recommended Action ranking engine are
all unchanged; every `HomeRecommendedActionCandidate`'s `invoke` still
calls the exact same `PublicDemoAggregate` command it always did (only its
*visible location*, when its card is on a non-HOME tab, moved).

## 6. Known gaps

- **Deep-link precision for cross-cutting CTAs.** `_scrollToOtherActions`
  (bound to the important-tasks' 営業/採用 rows, the Navigator's secondary
  route, and quick-access's 案件・営業 icon) always switches to 営業. Most of
  what it used to reach is there (assignment pipeline, recruiting), but a
  few `_salesTaskActionKinds` candidates are an existing employee's own
  sales-progression action, which now renders on 社員 instead. The player
  still lands on a real, relevant tab (not a dead end), but not always the
  exact card. Refining this (e.g. routing per the candidate's actual tab)
  is a reasonable follow-up in the spirit of the Issue's own "Slice B:
  quick-access routing" framing.
- **営業 can be empty in April.** Before May (recruiting) or June
  (assignments) exist, 営業 renders no card at all (see the 360x800
  screenshot below) — structurally correct (there is nothing to show yet)
  but a first-time player tapping it in April sees a blank tab with no
  explanatory empty state. Cosmetic; not required by the acceptance
  criteria.
- Tab switching no longer preserves each tab's scroll offset across a
  switch away and back (the previous single-list design had one scroll
  position by construction). Not required by the acceptance criteria and
  not a regression relative to a real navigation-based UI.
- Deployed Screen Verification (real device, production build) is left to
  the repository owner per this task's instructions; the screenshots below
  are from a local `flutter build web --release` served and captured with
  Playwright at the two required viewports.

## 7. Changed files

**lib** (1 file):
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`

**test** (new, 2 files):
- `test/ui/public_demo/public_demo_tab_test_helpers.dart` — shared
  `switchPublicDemoTab(tester, PublicDemoTab.*)` helper, taps the real
  `NavigationDestination` by key.
- `test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart` — new
  focused coverage for the acceptance criteria: each destination shows its
  own tab's content and HOME's own subtree is gone once another tab is
  selected (not merely off-screen); `NavigationBar.selectedIndex` always
  agrees with the visible tab; selecting a tab never mutates domain state;
  re-tapping the already-selected ホーム scrolls to top instead of no-op.

**test** (updated, 20 files — each interaction with content that moved off
HOME now switches to that content's real tab first, via the new helper;
three genuinely obsolete same-screen positional assertions were rewritten
into the equivalent structural assertion — see inline comments at each
site):
- `test/presentation/build_info_test.dart`
- `test/ui/public_demo/public_demo_01_assignment_carryforward_test.dart`
- `test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart`
- `test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart`
- `test/ui/public_demo/public_demo_01_fiscal_year_progression_test.dart`
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart`
- `test/ui/public_demo/public_demo_01_home_cash_forecast_advice_test.dart`
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart`
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart`
- `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`
- `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart`
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
- `test/ui/public_demo/public_demo_01_month_guard_recommended_test.dart`
- `test/ui/public_demo/public_demo_01_persistence_test.dart`
- `test/ui/public_demo/public_demo_01_playthrough_test.dart`
- `test/ui/public_demo/public_demo_01_recovery_ui_test.dart`
- `test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`
- `test/ui/public_demo/public_demo_01_success_playthrough_test.dart`
- `test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart`

**e2e** (new, 1 file, throwaway — not part of the Playwright suite, mirrors
the existing `ses147-screenshot.mjs`):
- `e2e/scripts/ses171-tab-screenshot.mjs`

## 8. Focused tests / results

Ran narrowest-first, as instructed, before the full suite:

1. `flutter analyze lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
   → **No issues found.**
2. Each touched test file individually while fixing it (19 files + the new
   one), all green.
3. `flutter test test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart`
   (new, dedicated tab-switching/anchor-absence coverage) → **4/4 passed.**
4. `flutter test test/presentation/build_info_test.dart` → **6/6 passed.**
5. `flutter analyze` (whole project) → **No issues found.**
6. `flutter test test/ui/public_demo/` (full directory, 20 files, run
   twice for confidence) → **231/231 passed**, 0 failures both times.
7. `flutter test` (whole project, final PR-stage gate, run once) →
   **1,518/1,518 passed**, 0 failures, exit code 0.

## 9. 360x800 / 390x844 Screen Verification

Captured from a local `flutter build web --release`, served on
`localhost` and driven with Playwright (`e2e/scripts/ses171-tab-screenshot.mjs`)
at both required viewports, with Flutter Web's semantics tree enabled
(`?e2e=1`) so every tap is a real accessible click against production UI —
the same technique the repo's existing Playwright specs use. Google Fonts
was unreachable from the sandbox (network-restricted), so the screenshots
render with the fallback system font instead of the bundled webfont; layout
and content are otherwise exactly what a real deploy renders.

Saved under `docs/reports/screenshots/ses-171-{tab}-{size}.png`:

- `ses-171-home-360x800.png` / `ses-171-home-390x844.png` — HOME: header,
  month, 7-tile KPI, Hiyori Navigator + CTA, monthly primary CTA, 社員の様子
  summary, 今月の重要タスク, クイックアクセス, bottom nav with ホーム highlighted.
  No horizontal overflow at either width; no full employee/accounting
  detail below the summary.
- `ses-171-employees-360x800.png` / `-390x844.png` — 社員: both founding
  engineers' full sales-progression cards, SkillSheet/研修 actions.
- `ses-171-sales-360x800.png` / `-390x844.png` — 営業: empty in April (see
  known gaps) — no crash, no overflow, correct bottom-nav highlight.
- `ses-171-accounting-360x800.png` / `-390x844.png` — 会計: 今月の支出予定
  (給与/固定費) finance summary.
- `ses-171-menu-360x800.png` / `-390x844.png` — メニュー: 開発・テストメニュー
  toggle, collapsed by default.

All ten screenshots show the bottom navigation's selected destination
highlighted consistently with the visible tab, and none show horizontal
overflow at either target width.

## 10. Merge readiness

- `flutter analyze`: clean.
- Focused + full `test/ui/public_demo/` + `test/presentation/build_info_test.dart`:
  all green (see §8; full-suite `flutter test` run at PR-final stage, not
  repeated during implementation, per the Issue's own instruction).
- No `lib/game/**` change; save schema unaffected (pinned by an existing
  persistence test's own assertion).
- Screen Verification: local build/web only, both required widths, no
  overflow, correct tab highlighting — **deployed** Screen Verification is
  intentionally left to the repository owner (per this task's explicit
  instruction not to auto-close #147/#171).
- Known gaps are cosmetic/deep-link-precision only (§6), not acceptance-
  criteria violations; none block merge.

## 11. Branch / commit / PR

- Branch: `claude/public-demo-home-ui-3b-3aj3ur`
- Commit: `87be6d7169ecef4fe53384e45db35c89088429eb`
- PR: [#172](https://github.com/perusonao/smile_enjoy_story/pull/172)

Per this task's explicit instruction, Issues #147 and #171 are **not**
auto-closed — production-deploy Screen Verification is left to the
repository owner.

## 12. Follow-up: Codex review merge-blocker fix (post-PR)

### Root cause

§6's "Deep-link precision for cross-cutting CTAs" known gap turned out to be
a real merge blocker, not merely cosmetic. `_scrollToOtherActions` (the
shared handler behind the important-tasks' 営業 row, the Navigator card's
secondary "他の行動を確認する" route, and quick-access's 案件・営業 icon) always
called `_switchTab(_salesTabIndex)` — unconditionally 営業 — regardless of
which tab actually owned the eligible action. Since PUBLIC-DEMO-HOME-UI-3B
moved every engineer's own sales-progression card (`ec(i)`, incl.
SkillSheet確認) onto 社員 while recruiting (`ac(i)`) and assignment
(`assignmentCard(i)`) cards stayed on 営業, a fresh-April game — where the
only eligible action is an engineer's own SkillSheet確認 — sent the player
through all three shared entry points to 営業, which renders no card at all
that early. Not a dead crash, but a dead-end tab: the one action the game
was recommending was not reachable from where the UI pointed.

### Fix

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`:

- Split the old single `_salesTaskActionKinds` constant into three: the new
  `_employeeTabSalesActionKinds` (the 8 kinds `ec(i)` renders — engineer
  identity/SkillSheet/sales-progression, all on 社員) and
  `_projectTabSalesActionKinds` (the 8 kinds `assignmentCard(i)` renders —
  the assignment/replacement pipeline, all on 営業), with
  `_salesTaskActionKinds` now `{...employee, ...project}` — unchanged for
  every existing caller that only needs "is there any 営業-pipeline action
  left at all" (the 営業 row's own eligibility gate).
- Renamed `_scrollToOtherActions` to `_switchToEligibleSalesDestination`: it
  now checks whether any currently-eligible `_recommendedActionCandidates`
  entry is one of `_employeeTabSalesActionKinds` and, if so, switches to 社員
  instead of 営業; otherwise (only 営業-side/project actions eligible, or
  none) it switches to 営業 as before. The destination is read from the same
  `_recommendedActionCandidates` authority the Recommended Action slot
  itself uses — never a second, independently-maintained routing table — so
  it stays correct as new action kinds are added to either tab.
- The important-tasks' 採用 row, which was also wired to the old shared
  `_scrollToOtherActions`, now calls `_switchTab(_salesTabIndex)` directly
  instead — `_recruitmentTaskActionKinds` is entirely the applicant funnel
  and recruitment-media button, both always on 営業, so this destination was
  never ambiguous and does not need the new tie-break logic. This also
  guards against over-correcting: a generically "smart" router reused here
  could wrongly send a 採用-row tap to 社員 if some unrelated employee-side
  action happened to be eligible at the same time.

No file under `lib/game/**` changed; no domain, balance, save-schema, finance,
or CI/workflow change. The only production file touched is the one above.

### Exact navigation behavior — before / after

| Entry point | Before (blocker) | After (fix) |
|---|---|---|
| 今月の重要タスク → 営業 row ("対応する") | Always 営業 | 社員 if an `_employeeTabSalesActionKinds` action is eligible (e.g. fresh-April SkillSheet確認); otherwise 営業 |
| 今月の重要タスク → 採用 row ("対応する") | Always 営業 | Always 営業 (unchanged — always correct, never ambiguous) |
| クイックアクセス → 案件・営業 | Always 営業 | Same rule as the 営業 row above |
| Navigator card → 「他の行動を確認する」 | Always 営業 | Same rule as the 営業 row above |

Fresh April concretely: all three top-row entry points now land on 社員,
where SkillSheet確認 is the visible, tappable action — no more dead-end
blank 営業 tab as the very first thing a new player's "show me something
else to do" tap can reach.

### New regression coverage

`test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart` — added a new
group, `PR #172 Codex review fix: shared cross-cutting CTAs route to the tab
that actually owns the eligible action, not blindly to 営業`, with 4 new
`testWidgets`:

1. Important-task 営業 row, fresh April → lands on 社員 (`selectedIndex == 1`),
   SkillSheet確認 is visible there, and HOME's own subtree is gone.
2. Quick-access 案件・営業, fresh April → same assertion.
3. Navigator's 「他の行動を確認する」 secondary CTA, fresh April → same assertion.
4. Important-task 採用 row, advanced to May (the first month it is itself
   eligible, and specifically a month where 営業's own row is *not*
   eligible, so the case is unambiguous) → still lands on 営業
   (`selectedIndex == 2`), proving the fix did not over-correct recruiting's
   routing.

### Tests executed and results

1. `flutter test test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart`
   (narrowest — the file with the new regression coverage) → **8/8 passed**
   (4 pre-existing + 4 new).
2. `flutter analyze` (whole project) → **No issues found.**
3. Relevant Public Demo widget tests — `public_demo_01_skill_sheet_flow_test.dart`,
   `public_demo_01_home_recommended_action_test.dart`,
   `public_demo_01_home_consolidation_test.dart`,
   `public_demo_01_home3_integration_test.dart`,
   `public_demo_01_home_navigator_test.dart`,
   `public_demo_01_home_runtime_read_test.dart`,
   `public_demo_home_presentation_components_test.dart`, plus the dedicated
   bottom-nav file above → **131/131 passed**, 0 failures.
4. `flutter test test/ui/public_demo/` (full directory, 22 files) →
   **239/239 passed**, 0 failures.

### Codex blocker status

**Resolved.** The three shared entry points (今月の重要タスク 営業 row,
クイックアクセス 案件・営業, Navigator's 他の行動を確認する) now choose their
destination from the actual eligible `HomeRecommendedActionKind`, and no
longer route a fresh-April player into a blank 営業 tab.

### Remaining known gaps

- The real-architecture five-tab split, the §6 known gaps from the original
  PR (营业 renders no card before May/June — now a correctly-reached, if
  still visually empty, state in that case; tab scroll-offset not preserved
  across switches; deployed Screen Verification left to the repository
  owner) are unchanged by this follow-up.
- No coverage was added for a scenario where only `_projectTabSalesActionKinds`
  (assignment/replacement) actions are eligible while no
  `_employeeTabSalesActionKinds` action is — that path was already the
  pre-existing (and still correct) 営業-routing behavior, and constructing it
  requires driving a full staffing→completion→replacement playthrough. The
  fix's logic handles it (only 社員 is preferred when a 社員-side action is
  actually eligible; otherwise the destination is unchanged from before this
  fix), but it is not pinned by a dedicated regression test in this pass.

### Final commit SHA

Code fix: `531ad8aad1e8d8a08c343a3ad459e9878617802d`
(this report update follows in a subsequent commit on the same branch,
`claude/public-demo-home-ui-3b-3aj3ur`.)
