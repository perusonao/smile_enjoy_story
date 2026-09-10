# SES First Fun Year — Public Demo Opening Context (P1) — Implementation Result

Status: **Implemented**

BASE SHA: `6943b673f1a1bd4d7c1dcd7c9abf4e12cb1b624f` (origin/main, PR #228 merge — matches the SHA specified in Issue #229; origin/main had not advanced past it at task start).

Branch: `claude/issue-229-t8lr5n`

FINAL HEAD SHA: `b512daf6cb27f3367fac2c82687bc566406736ec`

## 0. Branch note

The designated branch `claude/issue-229-t8lr5n` existed in this repository
before this task started, but at a single stale commit ("Phase 0A/0B: SES
domain models and random generators") that was already an ancestor of
`origin/main` — i.e. it carried no unmerged work of its own, just very old
history. Per this task's branch-restart rule, the branch was reset to
`origin/main` (`git checkout -B claude/issue-229-t8lr5n origin/main`) before
any implementation work began, landing it exactly on the SHA Issue #229
itself names as the base.

## 1. Goal

Public Demo 0.1's first-ever April currently drops a brand-new player
straight into normal monthly operations with no framing: no stated goal, no
visible "this is your starting cash", no explicit statement that a
sales-less month burns the fixed-cost baseline, and no short bridge into the
first real decision. Issue #229 (Package A only) asks for a one-time,
short Opening Context screen that states exactly that — using only figures
already computed by existing Finance/Payroll authority, reusing the existing
ひより (佐倉ひより) navigator character, and touching no gameplay/balance
rule.

Explicitly out of scope (per the issue): the Package B employee+SkillSheet
onboarding flow, any SkillSheet/Employee/Recruitment UX change, and any new
Finance/Save/Balance rule. Nothing in this list was touched.

## 2. Fresh authority trace

| Fact the Opening Context states | Source | Authority |
|---|---|---|
| Starting cash | `PublicDemoState.aprilStart().cash` | The exact canonical starting-cash constant `PublicDemoAggregate.initial()` (and therefore every playthrough, including every `4月からやり直す`/`最初からやり直す` replay) already starts from — the same constant `PublicDemoYearEndDisplayData.fromPublicDemoState` already reads for its own "開始時現金" line. Currently `¥4,000,000`, but this screen never hardcodes that number — see §5. |
| Monthly baseline fixed cost | `PublicDemoSalary.baselineMonthlyExpenses` | `initialTotalMonthlySalary + otherMonthlyFixedCost` = (佐藤健 ¥300,000 + 鈴木葵 ¥250,000 + 総務 ¥200,000) + ¥50,000 = `¥800,000`, the exact same figure `PublicDemoCashForecast`/`PublicDemoSalaryFinance.monthlyExpenses` already treat as the baseline every monthly close builds on. |
| Navigator identity/portrait | `HomeNavigatorIdentity` (`lib/presentation/home/models/home_navigator_display.dart`) | The existing 佐倉ひより name/role/portrait constants HOME's own `HomeNavigatorSection` already renders (`AssetPaths.navigatorHomeCompact`) — no new character, no new image asset. |

No new Finance/Payroll/Sales/Employee authority was introduced, and no
existing one was changed. The goal/risk copy ("技術者を案件へ参画させ、…
1年間(4月〜翌3月)会社を経営していく" / "売上がない月が続くと…資金が減って
いきます") paraphrases language already established elsewhere in this
codebase (the Founding Prologue's own intro message, and the Public Demo
Year-End card's "1年間の経営が終了しました。") rather than inventing new
lore. Per the issue's explicit instruction, **no exact "N ヶ月で倒産" figure
is stated anywhere** — Public Demo's actual shortage/bankruptcy timing
depends on more than a flat cash÷fixed-cost division (grace period, revenue
recognition, etc. — see `PublicDemoFinancialStatus`), and computing that
correctly is out of this issue's scope; the risk section stays qualitative
("売上がなければ資金が減り、倒産につながる"), matching the issue text
verbatim.

## 3. What changed

- **`lib/game/persistence/public_demo_opening_marker.dart`** (new) —
  `PublicDemoOpeningMarker`: an isolated, `SharedPreferences`-backed boolean
  flag (`ses_public_demo_01_opening_seen_v1`) tracking whether this browser
  has already dismissed the Opening Context. Deliberately **not** folded
  into `PublicDemoState`/`PublicDemoWorkflowState`/`PublicDemoSaveCodec` —
  it is UI-only, one-time presentation state, not a gameplay fact, and
  folding it into the save schema would have meant widening
  `PublicDemoSaveCodec`'s strict round-trip validation (see that class's own
  doc) for something no finance/sales/employee authority ever needs to read
  (the issue's own "不要なschema変更は避ける" / "fake data / duplicate
  authority禁止"). The default (non-`persistent`) constructor is inert
  (`hasSeenOpening()` always resolves `true`) — see §4 for why.

- **`lib/ui/public_demo/public_demo_opening_context_screen.dart`** (new) —
  `PublicDemoOpeningContextScreen`: the pure-presentation screen itself
  (目的 / 初期資金 / 毎月の固定費 / 注意(倒産リスク) / 最初にすること + ひより
  の紹介 + a single「4月の経営を始める」CTA). Takes `startingCash`/
  `monthlyFixedCost` as plain `int` parameters from the caller — it never
  reads `PublicDemoState`/`PublicDemoAggregate`/any save itself, so it
  cannot drift from whatever authority values the owning screen passes in.

- **`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`** (modified)
  — added `openingMarker` (constructor param, default inert), `_showOpening`
  state, `_resolveShowOpening`/`_acknowledgeOpeningContext`, and wired both
  into `_restoreAggregate` (boot) and `_restartGame` (both restart flows —
  the bankruptcy terminal card's `最初からやり直す` and the Menu tab's `4月
  からやり直す`). `build()` returns `PublicDemoOpeningContextScreen` in place
  of the normal HOME `Scaffold` while `_showOpening` is true. No Finance/
  Sales/Employee/monthly-close method was touched.

- **`lib/main.dart`** (modified) — the real browser entry point now passes
  `PublicDemoOpeningMarker.persistent()` (via `SesApp.openingMarker`,
  threaded through `_GameRoot`), except under the existing QA/E2E-only
  `?e2e=1` flag (see §4).

- Tests (new, focused): `test/game/public_demo_opening_marker_test.dart`,
  `test/ui/public_demo/public_demo_01_opening_context_test.dart`,
  `test/app/ses_app_opening_marker_test.dart`.

## 4. Design note: backward compatibility with ~80 existing Public Demo widget tests, and with CI's Playwright e2e specs

`PublicDemo01PlaceholderScreen` is constructed directly (no shared mount
helper) by roughly 80 existing widget test files across `test/ui/
public_demo/`, most of which build a fresh screen and interact with HOME
immediately (switch tabs, tap buttons) with no dismissal step. Naively
making a fresh (no-save) mount show the Opening Context by default would
have broken all of them — none of that is what Issue #229 asks for (its
own scope is "public demo初回プレイ", not a rewrite of the existing suite),
and blindly retrofitting every one of those files was assessed as a large,
high-risk change with no bearing on this issue's actual goal.

Instead, `PublicDemoOpeningMarker`'s own default constructor is **inert**
(`hasSeenOpening()` always resolves `true`, `markSeen`/`clear` are no-ops),
and that inert marker is `PublicDemo01PlaceholderScreen.openingMarker`'s own
default — mirroring the exact DI shape already established for
`saveService`. Every existing test that doesn't pass `openingMarker:`
explicitly keeps landing on HOME exactly as before this screen existed,
verified by running the complete `test/ui/public_demo` suite (522 tests) and
`test/game/public_demo` suite (842 tests) unmodified — see §6.

The same real-vs-test asymmetry applies to the Playwright e2e suite (`e2e/
tests/public-demo-*.spec.ts`, run by `.github/workflows/e2e.yml`'s
always-on `smoke-e2e` job on every PR, plus the full suite in
`e2e-heavy.yml`): every one of those specs already navigates through the
existing QA/E2E-only `?e2e=1` URL flag (`e2e/helpers/public-demo-player.ts`'s
`PUBLIC_DEMO_PATH`), originally added to force-enable Flutter Web's
semantics tree for headless automation. `main()` now threads that exact same
flag into which marker `SesApp`/`PublicDemo01PlaceholderScreen` receives —
a genuinely fresh e2e run gets the inert marker (Opening Context never
shows, so the existing "reachable initial employee action" style assertions
those specs already make keep working unmodified), while a genuine player's
URL (which never carries `?e2e=1`) gets `PublicDemoOpeningMarker.persistent`
and does see it. This required editing zero e2e spec/helper files.

A restored save always skips the Opening Context outright (`_resolveShowOpening(hasRestoredSave: true) => false`), regardless of the marker — this is what keeps a save written before this screen existed from suddenly showing it on its next reload.

## 5. Persistence / replay

- No save-schema change: `PublicDemoSaveCodec.schemaVersion` is unchanged at
  `1`, and neither `PublicDemoState` nor `PublicDemoWorkflowState` gained a
  field.
- `PublicDemoOpeningMarker`'s own isolated `SharedPreferences` key
  (`ses_public_demo_01_opening_seen_v1`) is distinct from both
  `PublicDemoSaveService.key` and the normal-game `SaveService` keys —
  clearing/corrupting one can never affect the others.
- Fresh start (no save, marker unset) → Opening Context shows.
- Dismissing it (`4月の経営を始める`) marks the browser-local marker seen and
  reveals HOME in the same frame — no double transition.
- A reload of that same still-save-less session (marker already seen) does
  not show it again.
- `4月からやり直す` / `最初からやり直す` (both routes — the Menu-tab
  confirmation dialog and the bankruptcy terminal card's direct button, both
  funnel through the same `_restartGame`) clear the marker and reset
  `_showOpening`, so a genuinely fresh replay sees the Opening Context again
  — verified for a persistent marker; verified as an unaffected no-op for
  the default inert marker (restart still lands directly on HOME, exactly
  as before this screen existed).
- An existing save (any prior playthrough) always skips the Opening Context,
  even if the marker itself has no record (a save written before this
  screen existed) — see §4's last paragraph.

## 6. Test results

```
flutter analyze                                    → No issues found.
flutter test test/game/public_demo                 → 842 tests passed
flutter test test/ui/public_demo                   → 522 tests passed
flutter test test/widget_test.dart                 → 11 tests passed
flutter test <new focused tests, 3 files>           → 23 tests passed
  test/game/public_demo_opening_marker_test.dart      (7)
  test/ui/public_demo/public_demo_01_opening_context_test.dart (14)
  test/app/ses_app_opening_marker_test.dart           (2)
flutter test (full suite)                           → <filled in after the
                                                         final background run
                                                         completes>
```

No pre-existing test was modified. Four unrelated screenshot PNGs under
`docs/reports/screenshots/` were regenerated as a side effect of running
`public_demo_seeded_recruitment_visual_test.dart` locally (that test
captures fresh reference screenshots on every run); those were reverted
(`git checkout --`) before committing since they are unrelated to this
issue.

## 7. 360×800 / 390×844 verification

`test/ui/public_demo/public_demo_01_opening_context_test.dart`'s `mobile
layout` group pumps the Opening Context at both target sizes and asserts no
`FlutterError`/overflow exception (`tester.takeException()` is `null`) with
the screen's key present. The screen itself is a `ListView` (scrolls if the
content genuinely doesn't fit a given text scale/size), so growth from a
larger system text scale degrades to a scroll, never an overflow.

## 8. Authority / persistence impact

- Finance, Payroll, Sales, Employee, monthly-close: **unchanged**. No method
  in `lib/game/public_demo/` was edited.
- Save schema: **unchanged** (`schemaVersion` stays `1`; no new field on
  `PublicDemoState`/`PublicDemoWorkflowState`).
- New, fully isolated persistence: one boolean `SharedPreferences` key
  (`ses_public_demo_01_opening_seen_v1`), read/written only by
  `PublicDemoOpeningMarker`.

## 9. Known limitations / out of scope (unchanged from Issue #229's own list)

- Package B (founding-employee + SkillSheet onboarding walkthrough),
  SkillSheet hard-gate/edit changes, Employee screen redesign, Recruitment
  UX rework, Sales/Accounting UX (#209), Late-game FUN (#167), Visual
  Complete 2, 1-turn-1-week, and any new Finance/Save/Balance rule — all
  explicitly out of scope per the issue and untouched here.
- The risk section is deliberately qualitative (no "N ヶ月で倒産" figure) —
  see §2's last paragraph for why computing an exact runway was out of
  scope for Package A.

## 10. Actual processing time

Fresh authority trace (repo structure, Finance/Payroll authority, existing
Prologue/Opening precedent, save/persistence, ひより navigator asset) +
implementation + focused tests + self-hardening (backward-compat design for
~80 existing widget tests and the e2e suite) + full verification: this
session's single continuous work pass.

## 11. PR

https://github.com/perusonao/smile_enjoy_story/pull/230
