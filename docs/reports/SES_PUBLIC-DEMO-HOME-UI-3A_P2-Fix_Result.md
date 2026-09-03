# SES_PUBLIC-DEMO-HOME-UI-3A P2 Fix — Implementation Result

## STATUS

Complete. `flutter analyze` (whole repository) and the focused HOME/Public
Demo test suites are green on the final commit.

## SCOPE

PR #150 ("Public Demo HOME rebuild to approved visual target", Issue #147)
received two unresolved P2 review threads from `chatgpt-codex-connector`,
both explicitly triaged by the repository owner as merge-blocking. This
session's only job was to fix exactly those two findings with the smallest
possible change, add focused regression tests, and correct one stale claim
in the PR body — nothing else.

## Pre-work audit

- Base branch: `claude/issue-147-home-ui-3a`.
- Expected HEAD given in the task: `2480dd9673d50ba37d3e238425a66bb730141722`.
- Verified `origin/claude/issue-147-home-ui-3a` HEAD was exactly that SHA
  before any change in this session (`git fetch` + `git rev-parse` and
  `git log --oneline -1`, both confirmed the exact SHA before work began).
- Confirmed both review threads via `pull_request_read` (`get_review_comments`
  on PR #150): thread `PRRT_kwDOT2htY86enBwL` (dead important-task CTA,
  `lib/ui/public_demo/public_demo_01_placeholder_screen.dart:241`) and thread
  `PRRT_kwDOT2htY86enBwP` (KPI TextScaler cancellation,
  `lib/presentation/home/widgets/kpi_section.dart:308`) — both `is_resolved:
  false`, each already carrying the repository owner's own reply confirming
  it as merge-blocking and describing the intended fix, matching this task's
  brief.
- Read `AGENTS.md`'s mandatory startup rule and `docs/DEVELOPMENT_PLAN.md`.
  This task is an explicit, scoped bug-fix request against an open PR's own
  review findings; it does not conflict with the development plan's phase
  ordering and needed no plan update.

## P2 fix #1 — dead CTA in "今月の重要タスク"

**File:** `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`

**Problem:** `_importantTasks` always returned all three rows ("営業活動を進め
る" / "採用・面談に対応する" / "資金計画を確認する"), each pointing its CTA at
`_scrollToOtherActions` (the legacy per-employee/applicant action surface)
or the finance summary. In a terminal/completed month (`s.isCloseBlocked` —
bankruptcy, March cash-shortage failure, or fiscal-year completion) the
legacy action surface has nothing eligible left in it at all, and in an
ordinary month one of the two categories (existing-employee "営業" work vs.
recruitment "採用" work) can be genuinely exhausted or not-yet-applicable
(e.g. April has no recruitment pipeline yet; May has no existing-employee
sales-pipeline candidate at all — see `_recommendedActionCandidates`'s own
`if (s.month == ...)` branches). The CTA still rendered as a normal, enabled
button in every case, inviting a tap into a section with no matching action
to perform — a dead end, not a shortcut.

**Fix:** Added two top-level, testable pieces to
`public_demo_01_placeholder_screen.dart` (kept top-level rather than as
private members of `_S` specifically so a plain `test()` can exercise them
without pumping a widget):

- `_salesTaskActionKinds` / `_recruitmentTaskActionKinds` — two `Set<
  HomeRecommendedActionKind>` constants. This is a pure *category* read of
  the kinds `_recommendedActionCandidates` already emits (`employee*` /
  `assignment*` kinds for "営業"; `applicant*` kinds plus `recruitmentMedia`
  for "採用"). No kind was added to or removed from
  `_recommendedActionCandidates` itself, and no new eligibility predicate
  was written — every kind in these sets is only ever present in the
  candidate list when the existing owner-side emit site already judged it
  legal (the exact same authority the Recommended Action slot uses).
- `homeImportantTaskHasEligibleAction(state, candidates, kinds)` — `true`
  only when `!state.isCloseBlocked` (the identical gate
  `_recommendedActionSlot` already suppresses on) **and** at least one
  already-legal candidate's kind is in `kinds`.

`_importantTasks` now wraps the 営業 and 採用 rows in
`if (homeImportantTaskHasEligibleAction(s, candidates, ...kinds))` — each
row is omitted entirely (not disabled) once nothing eligible backs it. The
資金計画 row is never gated: viewing the finance summary is not an action
that becomes illegal, and its target section (`_financeSummaryKey`) always
renders (baseline constants pre-close, authoritative figures after).

Doc comments on `_importantTasks` and `PublicDemoImportantTasksSection`
(in `public_demo_home_presentation_components.dart`) were updated from
"always exactly three" to "up to three", matching the new behavior.

**Domain/game-rule impact:** none. The fix reads `PublicDemoState
.isCloseBlocked` (existing getter) and `_recommendedActionCandidates`
(existing getter, unmodified) — it does not add, remove, or reorder a
single command, guard, or eligibility check anywhere in `lib/game/**` or
`lib/domain/**`.

## P2 fix #2 — KPI value cancels TextScaler at large text scale

**File:** `lib/presentation/home/widgets/kpi_section.dart`

**Problem:** `_CompactKpiTile`'s value text was unconditionally wrapped in
`FittedBox(fit: BoxFit.scaleDown)`. At the default text scale this is a
genuine, tested fix for real digit truncation (a cramped ~60pt four-across
tile at 390px). At an enlarged ambient `TextScaler` (1.3×/2.0×), the same
mechanism measured the now-larger value and scaled it back down to fit the
same fixed-width tile — silently cancelling most or all of the requested
accessibility scale. The only existing regression test for this tile
(`public_demo_01_home_consolidation_test.dart`'s "effective font size"
test) pumped exclusively at the default scale, so it could not catch this.

**Fix — responsive column count, not a shrink-back:**

- `lib/presentation/home/widgets/kpi_section.dart` now computes an
  ambient-scale-aware column count in `_CompactKpi`/new `_CompactKpiRow`:
  below `_largeTextScaleThreshold` (1.3×) the two logical rows (4 tiles,
  then 3) render exactly as before, unchanged. At 1.3× and above, each
  logical row is chunked into 2-wide sub-rows (`_wideColumnsPerRow`); at
  1.7× and above (`_veryLargeTextScaleThreshold`) it drops to 1-wide
  sub-rows (`_narrowColumnsPerRow`) — i.e. the tile gets the entire row's
  width. This is what actually keeps an enlarged value fitting: extra
  column width, not a shrink applied after the fact.
- `_CompactKpiTile` now checks the same threshold
  (`_effectiveTextScale(context) >= _largeTextScaleThreshold`): below it,
  the value stays wrapped in the original `FittedBox(scaleDown)`
  (unchanged, zero risk to the just-verified default-scale behavior). At or
  above it, the `FittedBox` is skipped entirely — the value renders as a
  plain, unshrunk `Text`, allowed to wrap to a second line
  (`maxLines: 2`) rather than being measured against a box no longer
  guaranteed to hold it on one, so a genuinely long value can grow the tile
  instead of being clipped, ellipsized, or scaled back down.

**Domain/data impact:** none. `_KpiTileData`'s `icon`/`label`/`value`/
`tileKey` fields, `_compactRowsFor`'s per-tile values, and every existing
`Key` (`home-kpi-compact-*`) are byte-identical to before this fix — only
the *rendering* of the already-computed value string changed.

## Tests added/updated

### `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`

New group `9: important-task rows never invite the player into a dead end`:

- `homeImportantTaskHasEligibleAction is false for every terminal/completed
  state the design names, regardless of the candidate list` — plain
  `test()`, constructs `PublicDemoState.aprilStart().copyWith(...)` for
  bankruptcy, March cash-shortage failure, and fiscal-year completion (the
  same three states this file's existing group 6 already pins as
  `isCloseBlocked`), asserts the helper returns `false` even with a
  matching eligible candidate present.
- `homeImportantTaskHasEligibleAction is false once the requested category
  is exhausted — no matching candidate, or none at all` — plain `test()`,
  a not-blocked state with only an unrelated candidate, and with an empty
  candidate list.
- `homeImportantTaskHasEligibleAction is true only once both conditions
  hold` — plain `test()`, positive case (not a tautology check).
- `after bankruptcy, the important-tasks section drops the 営業/採用 rows
  instead of offering a CTA into a section with nothing left to do` —
  `testWidgets()`, drives the real screen through
  `playIntoCashShortage` + one more ordinary-month close (the file's own
  existing bankruptcy driver, reused verbatim) to real bankruptcy, then
  asserts within `Key('public-demo-important-tasks')`: `find.text('資金')`
  present, `find.text('営業')` and `find.text('採用')` both absent.

### `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`

Fixed the now-stale `the important tasks section remains reachable after a
month closes` test: it asserted `find.text('営業')` inside the section right
after an April→May close. May genuinely has no 営業-category candidate (see
fix #1's doc), so this assertion is exactly the bug the fix corrects — the
test was asserting the presence of a dead CTA. Re-pointed the assertion at
`find.text('資金')` (the one row that is never gated) with a doc comment
explaining why, and updated the surrounding doc comment from "always
exactly three" to reflect the new "up to three" behavior.

### `test/ui/public_demo/public_demo_01_home3_integration_test.dart`

New loop over `width ∈ {360, 390} × scale ∈ {1.3, 2.0}`, 4 new
`testWidgets()`:

- Pumps the real screen once at scale 1.0 (baseline) and once at the scale
  under test, both at the same width.
- Asserts `tester.takeException()` is `null` (no `RenderFlex`/overflow
  exception) at the enlarged scale.
- Asserts `find.ancestor(of: <cash value Text>, matching:
  find.byType(FittedBox))` finds **nothing** at the enlarged scale — the
  structural proof that nothing can shrink the value back down.
- Asserts the cash value's rendered height at the enlarged scale is
  `>= baselineHeight * scale * 0.9` — the value genuinely grew with the
  requested scale rather than staying pinned near its 1.0× size (a 10%
  tolerance absorbs rounding/line-height noise, not the ~cancellation the
  bug produced).
- Re-checks every compact tile (`cash`/`assigned`/`waiting`/
  `sales-remaining`/`employees`/`revenue`/`pending-revenue`) stays inside
  `[0, width]` horizontally at the enlarged scale — no horizontal overflow.

## Test results

```
flutter analyze                                          → No issues found! (ran in 4.5s)

flutter test test/ui/public_demo/public_demo_01_home_recommended_action_test.dart \
              test/ui/public_demo/public_demo_01_home_consolidation_test.dart \
              test/ui/public_demo/public_demo_01_home3_integration_test.dart \
              test/ui/public_demo/public_demo_home_presentation_components_test.dart
                                                           → 79/79 passed, 0 failed

flutter test test/ui/public_demo/ test/presentation/home/
                                                           → 383/383 passed, 0 failed
```

Per the task's explicit instruction, the full `flutter test` (1417+ tests)
and the Playwright E2E suites were **not** re-run locally in this session —
that is left to PR CI. `flutter build web --release` was likewise not
re-run in this session (the prior session already verified it green on a
predecessor commit, and this fix touches only two widget-tree
rendering paths plus one list-construction getter, none of which affect
the web build's own compile/bundle step).

## Changed files

```
 lib/presentation/home/widgets/kpi_section.dart                          | 84 ++++++++--
 lib/ui/public_demo/public_demo_01_placeholder_screen.dart               | 79 ++++++++-
 lib/ui/public_demo/public_demo_home_presentation_components.dart        |  9 +-
 test/ui/public_demo/public_demo_01_home3_integration_test.dart          | 85 +++++++++
 test/ui/public_demo/public_demo_01_home_consolidation_test.dart         | 23 ++-
 test/ui/public_demo/public_demo_01_home_recommended_action_test.dart    | 147 +++++++++++++
```

(Exact per-fix line counts above are from this session's own diff of the
six files it touched; see `git show <commit>` for the literal patch.)

## Domain / save / navigation-authority impact

**None.** Verified via `git diff --stat` for this session's changes against
every hard-boundary path named in the original Issue #147 prompt and this
task's own instructions:

```
lib/domain/**                    → no changes
lib/game/**                      → no changes
lib/game/persistence/**          → no changes (save schema/serialization)
home_recommended_action.dart     → no changes (ranking/selection logic untouched;
                                    only its *kinds* are read, never redefined)
lib/ui/main_shell.dart           → no changes
lib/ui/home/home_screen.dart     → no changes (normal-game HOME)
e2e/tests/**                     → no changes IN THIS SESSION (see "PR body
                                    correction" below for the pre-existing,
                                    already-committed change from before this
                                    session)
e2e/playwright.config.ts         → no changes
.github/workflows/**             → no changes
```

Only presentation-layer files changed: two `lib/` widget/screen files, one
doc-comment-only edit in a third `lib/` file, and three `test/` files.

## PR body correction

The task named one stale claim in PR #150's existing body: "`e2e/tests/**`
diff is empty" under the Domain/finance/save/navigation impact section.
That was true when originally written, but is no longer accurate — a prior
commit on this same branch (`test(e2e): decouple public demo smoke from
HOME copy`, already on the branch before this session started, not authored
by this session) updated `e2e/tests/public-demo-fresh-start.spec.ts` to stop
asserting on two now-deleted/relocated presentation strings (`社員ステージ`,
`営業準備前`) that the earlier HOME-3A redesign already removed from the
screen, plus added a new screenshot-capture helper script,
`e2e/scripts/ses147-screenshot.mjs`. Neither change touches E2E
retry/sleep/skip/assertion **policy** — the spec still asserts the same
kind of contract (fresh-start identity, month, initial employee, initial
real action, no premature terminal/bankrupt state), only two of its
expected strings were updated to match the screen the earlier commits in
this same PR already produced. The PR body has been corrected to state
this accurately instead of claiming an empty `e2e/` diff.

## PR #136 overlap assessment

Unchanged from the existing PR #150 report: PR #136 (SkillSheet Phase A,
open, unmerged) touches the same file
(`public_demo_01_placeholder_screen.dart`) but only inside
`_openSkillSheetReview`'s body (confirmed at lines 617–671 on this branch's
current HEAD). This session's two fixes live at lines ~46–125 (new
top-level helpers) and ~309–345 (`_importantTasks`) — a disjoint region.
Re-verified with `grep -n` after this session's commit: no overlap.
Recommended order unchanged: merge this PR first, then rebase #136's small,
localized diff on top.

## Known gaps

- Full `flutter test` (whole suite, 1417+ tests) and the Playwright E2E
  suites were not re-run locally in this session, per explicit instruction
  ("開発速度を優先... full regression / smoke E2Eはpush後のPR CIに任せます").
  PR CI is the authority for that full-suite/E2E result.
- `flutter build web --release` was not re-run in this session for the same
  reason; the change is presentation-only and does not alter any import,
  asset, or build configuration.
- No new screenshot was captured for this fix (the visual difference is
  only visible at an enlarged text scale, which the existing before/after
  screenshots in `docs/reports/screenshots/` do not cover) — the new
  widget tests are the verification for this fix instead.

## Commit / push

- Commit SHA: `8736fb027f1d9f7fb8c3ec56bc618f847699d15e`
- Work-before HEAD: `2480dd9673d50ba37d3e238425a66bb730141722`
- Pushed branch: `claude/issue-147-home-ui-3a`.
- PR: [#150](https://github.com/perusonao/smile_enjoy_story/pull/150),
  still open against `main`, not merged.

## Review threads

Both P2 threads (`PRRT_kwDOT2htY86enBwL` — dead CTA, `PRRT_kwDOT2htY86enBwP`
— KPI TextScaler) were replied to with the fix description and this
session's commit SHA, and marked resolved, since both are now fixed with
passing focused tests as described above.

## Merge readiness

**READY WITH CONDITIONS** — both named P2 findings are fixed with passing
focused tests, `flutter analyze` is clean, and the domain/save/navigation
boundary is unbroken. The condition is the same one the original PR #150
report already named and this task did not ask to resolve: full-suite
`flutter test`, `flutter build web --release`, and the Playwright E2E
suites should be confirmed green on PR CI before merge, and a real deployed
Screen Verification (out of scope for any sandboxed session) is still
recommended before closing Issue #147 itself.
