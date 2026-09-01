# SES First Fun Year UI Phase 1 — Implementation Result

## STATUS

**Completed** — investigation + scoped subtractive cleanup, tested and
committed. No PR opened (not requested).

## BASE SHA

`07c1f523cf080d85bf27e42f724b53cbc8d1e75e` (`origin/main` HEAD at session
start — merge commit for PR #140, "docs: record SES Development Priority as
governing decision"). The branch `claude/ses-first-fun-year-home-ui-s9di49`
was reset to this commit before starting (the branch previously carried only
a single commit, `f4ca78f` "Phase 0A/0B: SES domain models and random
generators", which was already an ancestor of `origin/main` — i.e. already
merged — so nothing was discarded by the reset).

## FINAL HEAD SHA

See the commit created alongside this report (this document is committed in
the same commit).

## Investigation summary — what was already on `main`

Before writing any code, the required reading (`AGENTS.md`,
`docs/DEVELOPMENT_PLAN.md`,
`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`) and the existing
HOME implementation were reviewed. Contrary to the task brief's working
assumption, the *new* HOME dashboard + *legacy* HOME were **not** both still
stacked on `main`. Recent, already-merged work (commits tagged
`HOME-RUNTIME-2A`/`2B`/`2C` and `HOME-3` in code comments and history —
`eedb249`, `e08e53c`, `fc7a3f5`, and follow-ups) had already:

- Removed the duplicate `N月` headline and the legacy 現預金/参画/待機/営業残
  stat row — `MonthHeaderBar` and the compact `KpiSection.compact` are the
  *only* places those figures render.
- Hoisted `PublicDemoCashShortageCard` / the bankruptcy terminal card above
  everything else, so a critical financial alert is never buried.
- Replaced the old "今月やること" static card with `RecommendedActionSection`,
  which shows one concrete, tappable next action (backed by the same
  `PublicDemoAggregate` command the underlying per-employee button runs) and
  falls back to the month-goal text only when nothing is eligible.
- Added an extensive widget-test suite
  (`test/ui/public_demo/public_demo_01_home_consolidation_test.dart`,
  `public_demo_01_home3_integration_test.dart`) that already pins "the
  Recommended Action CTA is reachable with zero scroll, inside a real mobile
  browser-chrome content budget, at both 360×800 and 390×844" and "the whole
  HOME block (month + KPI + navigator advice + recommended action) stays
  under a fixed height ceiling."

So the *first-view priority order* the task asks for (month → critical alert
→ KPI → recommended action, all visible with none of them buried below KPI)
was **already implemented and already tested** on `main`. Re-implementing it
from scratch, or reusing an old HOME-UI-1A/1B/1C design doc, would have
duplicated working code and risked regressing a well-covered area for no
gain — so Phase 1 here is a narrower, evidence-based cleanup of the specific
duplication that *does* still exist, per the task's own "Legacy cleanup"
checklist.

## Before: the problems that were actually still present

1. **`PublicDemoFinanceSummarySection` ("資金サマリー") duplicated the compact
   KPI.** It rendered 現金残高 / 今月売上 / 次回入金予定 a second time, using the
   same authoritative fields (`s.cash`, `_homeDashboardData.revenue`,
   `s.pendingRevenue`) the KPI directly above already always shows. It also
   carried its own `warning` banner that duplicated
   `PublicDemoCashShortageCard`/the bankruptcy terminal card, both already
   composed above HOME for the same conditions.
2. **A literal duplicate of the 参画/待機 KPI figures** in the July
   ("7月開始結果") recap block:
   `'参画 ${s.engineersAssigned}名 / 待機 ${s.engineersWaiting}名'` — restating,
   in different wording, numbers the always-visible compact KPI tiles
   (`home-kpi-compact-assigned` / `home-kpi-compact-waiting`) already show on
   every build, including July's.
3. **`PublicDemoEmployeeStageSection` ("社員ステージ") had no size bound.** It
   rendered every employee unconditionally, so its height grows without
   bound as the roster grows across the fiscal year — the "大型employee
   card" HOME-bloat the task named explicitly. (The Office Stage card right
   above it already solved the same problem for its own visual roster with a
   fixed "+N名" overflow chip; the Employee Stage summary had no equivalent
   cap.)

No other duplication survived from the task's checklist: the month display,
the legacy KPI/stat row, and the "action buried below a wall of info"
problem were confirmed already fixed by the prior HOME-RUNTIME-2A/2B/2C
work (verified both by reading the code and by the passing pre-existing
test suite named above).

## After: HOME structure (unchanged ordering, trimmed content)

Composition order in `PublicDemo01PlaceholderScreen.build()` is unchanged —
it was already correct:

1. `PublicDemoCashShortageCard` / bankruptcy terminal card (critical alert,
   shown only when applicable)
2. `PublicDemoHomeDashboardSection` — `MonthHeaderBar` (A. Month) →
   `KpiSection.compact` (C. Compact KPI: 現金/社員/参画/売上/入金予定/待機/営業残)
   → `HomeNavigatorSection` (Hiyori's advice) → `RecommendedActionSection`
   (D. Recommended Action, replacing the month-goal fallback when an action
   is eligible)
3. Test-controls card (Public Demo-only QA affordance, unchanged)
4. `HomeOfficeStageSection` — bounded visual roster (unchanged, already
   capped)
5. `PublicDemoEmployeeStageSection` (E. Summary) — **now capped at 4 visible
   employees + "他N名" overflow**, matching the Office Stage's own idiom
6. `PublicDemoImportantEventsSection` (unchanged — already capped at 2, hides
   itself when empty)
7. `PublicDemoFinanceSummarySection`, retitled **"今月の支出予定"** — **now only
   給与 / 固定費** (payroll / fixed costs), the two figures the KPI does not
   carry; the duplicate cash/revenue/next-payment rows and the duplicate
   warning banner are gone
8. `PublicDemoMonthlyPrimaryCtaSection` — the month-close action (this is
   the *only* place the month-close command is bound; not a duplicate)
9. Legacy monthly-close detail (`PublicDemoMonthlyCashFlowCard`, growth
   results) and the existing per-month/per-employee action cards, unchanged

## Removed/consolidated duplicate UI

- `PublicDemoFinanceSummaryModel`/`PublicDemoFinanceSummarySection`: dropped
  `cash`, `revenue`, `nextMonthEstimate`, `warning` — kept only `payroll`,
  `fixedCosts`. `_FinanceRow`'s now-unused `emphasis`/`expense`/`subdued`
  flags were removed along with them (both remaining rows are the same
  shape).
- Deleted the duplicate `'参画 X名 / 待機 Y名'` `Text` in the July recap block
  in `public_demo_01_placeholder_screen.dart`.
- `PublicDemoEmployeeStageSection`: capped to 4 visible employees + a
  `他N名` overflow line (new key:
  `public-demo-employee-stage-more`), so the card no longer grows unbounded
  with roster size.

## Authoritative state usage

No new formulas were introduced. Every remaining figure is read verbatim
from the same sources as before:

- `PublicDemoFinanceSummaryModel.payroll`/`fixedCosts` — unchanged read of
  `s.latestMonthlyCashFlow?.salaryPaid`/`.fixedCostsPaid`, falling back to
  the same `PublicDemoSalary` baseline constants.
- The compact KPI (`HomeDashboardDisplayData.fromPublicDemoState`) —
  untouched; still the single source for 現金/社員/参画/売上/入金予定/待機/営業残.
- `PublicDemoEmployeeStageSection`'s roster and per-employee status text —
  untouched (`_employeeStageItems`), only the *rendering* of that already-
  correct list is now capped.

## Domain / Finance / Persistence changes

**None.** This phase touched only two presentation files
(`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`,
`lib/ui/public_demo/public_demo_home_presentation_components.dart`) plus
their tests. No changes to:

- Public Demo domain logic, finance/payroll/revenue formulas
- save schema
- game balance / month progression rules
- routing, navigation, or `main.dart`

## Changed files

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `lib/ui/public_demo/public_demo_home_presentation_components.dart`
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart`
- `test/ui/public_demo/public_demo_01_playthrough_test.dart`
- `test/ui/public_demo/public_demo_01_success_playthrough_test.dart`
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
- `docs/reports/SES_FIRST-FUN-YEAR_UI-PHASE-1_Implementation_Result.md` (this
  report)

## 360×800 / 390×844 verification

Flutter SDK (3.47.2 stable) was installed into this session to run the app.
`flutter build web --release` succeeded; the built bundle was served
locally and opened with a headless Chromium at both target sizes via a
one-off Playwright script (`?e2e=1#/public-demo-01`, April state, matching
the existing e2e harness's own entry route).

Results at both 360×800 and 390×844:

- **No horizontal overflow**: `document.documentElement.scrollWidth ===
  clientWidth` at both sizes (360 and 390 respectively).
- **No page/console errors** during load and initial paint.
- **First view** (screenshots captured, see below) shows, top to bottom, in
  a single unscrolled viewport: 月 (`1年目 4月`) → Compact KPI (現金/参画/待機/
  営業残/社員/売上/入金予定) → Hiyori's advice → **Recommended Action**
  ("次にやること / 佐藤 健のSkillSheetを確認" with a full-width CTA) → test
  controls → Office Stage. No critical alert was present in this state
  (normal financial status), consistent with `PublicDemoCashShortageCard`
  rendering nothing when `financialStatus != cashShortage` — the existing
  widget-test suite (group "19-20" in the consolidation test) separately
  proves the alert renders above HOME and is never hidden when it *is*
  applicable, at both target sizes.
- No duplicate month or cash/KPI figures are visible anywhere in the
  captured views.

I was not able to automate a scroll gesture against the canvas-rendered
Flutter Web build in this sandbox (mouse wheel / synthetic touch-drag had no
effect on the CanvasKit-rendered scroll view), so the trimmed
`今月の支出予定`/`社員ステージ` sections further down the page were verified via
the widget-test suite instead of a second screenshot — both are checked in
`public_demo_home_presentation_components_test.dart` (unit-level, exact
rendered text/keys) and `public_demo_01_home3_integration_test.dart`
(integration-level, real state wiring), all passing.

## Test results

Environment note: Flutter was not preinstalled in this session; Flutter
3.47.2 (stable, matching the project's `sdk: ^3.9.2` constraint) was
downloaded and installed to run these checks.

- `flutter analyze`: **No issues found.**
- Focused HOME/Public Demo suites — every test file under `test/ui/public_demo/`
  and `test/presentation/home/`: **355 tests, all passing**, including:
  - `public_demo_01_home_consolidation_test.dart` (45 tests — the first-view
    ordering/budget assertions from the prior HOME-RUNTIME-2A/2B/2C phases)
  - `public_demo_01_home3_integration_test.dart` (updated to assert the new
    "今月の支出予定"/payroll+fixedCosts shape instead of the deleted
    cash/revenue/warning fields)
  - `public_demo_home_presentation_components_test.dart` (updated finance-
    summary test; new test asserting the Employee Stage cap/overflow
    behavior)
  - `public_demo_01_playthrough_test.dart` and
    `public_demo_01_success_playthrough_test.dart` (updated to assert the
    July 参画/待機 fact via the KPI tile instead of the deleted duplicate
    line — no assertion was weakened; the same fact is checked through its
    one remaining, more precisely-keyed home)
- `git diff --check`: clean, no whitespace errors.
- Full `flutter test`: was still running in the background at report-writing
  time (this repository's suite is large and this sandbox runs Flutter
  tests with software rendering, which is slow). See Known Issues below —
  will be confirmed and this report updated if anything unrelated surfaces.

No test was skipped, retried, given a longer timeout, or weakened from
`findsOneWidget` to a looser matcher. Every assertion removed for a deleted
duplicate line was replaced with an equal-or-stronger assertion against the
fact's one remaining, correctly-keyed home.

## Known Issues

- The full-repository `flutter test` run had not finished by the time this
  report and commit were prepared (large suite, slow software-rendered CI
  sandbox). The targeted suites that exercise every file this phase touched
  (`test/ui/public_demo/`, `test/presentation/home/`, 355 tests) all pass.
  If the full run later surfaces an unrelated failure, it predates this
  change (this phase's diff is two presentation files plus their direct
  tests) and will be reported as a follow-up rather than silently ignored.
- The Employee Stage cap (4 visible + overflow) is a display-only bound;
  Public Demo 0.1's roster is small enough in practice that this rarely
  triggers yet. It is validated at the component level (5+ employees) but
  not observed in a real July+ playthrough screenshot in this session.
- E2E (Playwright) Founding/first-assignment specs were not run in this
  session — out of scope for this phase per the task's E2E policy
  (non-blocking, and this phase does not touch Founding).

## First Fun Year playthrough readiness

This phase does not change any domain rule, so playthrough readiness is
unchanged at the mechanics level. On the UI side, the first-view priority
the task cares about (month, critical alert, KPI, recommended action all
visible without scrolling) was **already met on `main`** before this
session; this phase removes the remaining duplicate/unbounded HOME content
named in the task's cleanup checklist without touching any existing
operation's reachability. A developer full-year playthrough (April→March)
was not re-run end-to-end in this session; the targeted widget-test suite
(which drives the real `PublicDemo01PlaceholderScreen`/`PublicDemoAggregate`
through April→July, summer bonus, training, recovery-loop, and terminal
states) passing is the evidence available here.

## Commit SHA

See the commit this report is part of (created immediately after this
file was written, in the same commit).

## PR / Merge Readiness

No PR was created (not requested — "PRはまだ作成しない" per the task). Branch
`claude/ses-first-fun-year-home-ui-s9di49` was pushed to `origin`. Given
`flutter analyze` is clean and every test file this phase touches passes
(355/355 in the targeted suites), this is mergeable pending the full-suite
confirmation noted above.
