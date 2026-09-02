# SES Issue #124 — Screen Verification Follow-up Result

`PUBLIC-DEMO-HOME-UI-2A`

## Base

- Base branch: `main`
- Base main SHA: `99032db720401a9de5773cea7cf60d5347b88e3d` (PR #145 merge commit)
- Working branch: `claude/home-viewport-compression-w9hr5y`

## Why the real-device Screen Verification failed

PR #145's deploy was checked on a real iPhone in portrait. In the initial
(unscrolled) viewport the player could see the month, cash, participation/
waiting counts, sales-remaining, headcount, revenue, the pending-deposit
figure, Hiyori's next action + its CTA, and the Office Stage picture — but
**not** each employee's current sales/assignment status ("案件状況") or
anything about what changed this month ("今月何が変わったか"). Screen
Verification for Issue #124 therefore FAILed.

## Root cause

Two HOME sections rendered the *same two employees* back to back at close
to full size:

1. **`HomeOfficeStageSection`** ("社員の様子") — a large office-background
   photo with each employee's portrait and name.
2. **`PublicDemoEmployeeStageSection`** ("社員ステージ") — directly below
   it, a card listing the same two employees again, each as a two-line
   block (name row, then an indented status-chip row).

Together these two sections cost roughly 330pt of vertical space at
360×800 to convey overlapping information (who the employees are), while
never surfacing the sections that answer "案件状況" and "今月何が変わっ
たか" inside the same budget. The picture-based section is architecturally
forbidden from carrying per-employee status text (see the "no 参画/待機
split" rule already pinned in `home_office_stage_section_test.dart` — it
exists because assignment status can disagree across authorities at
different points in a month), so the actual "誰が・どんな状態か" fact
only ever lived in the second, list-based card — and that card was pushed
below the browser-chrome content budget the existing HOME-RUNTIME-2A/2C
suite (`public_demo_01_home_consolidation_test.dart`) already measures the
Recommended Action CTA against (615pt at 360×800, 660pt at 390×844).

## UI change (production code only, no gameplay logic touched)

1. **`HomeOfficeStageSection` metrics shrunk** (`home_office_stage_section
   .dart`, `HomeOfficeStageMetrics`): scene height 108/120 → 64/70,
   portrait size 54/62 → 28/32, card padding 10/10 → 6/6, name font
   10/11 → 8/9. The section keeps its own architecture untouched — still
   presentation-only, still no gesture/callback, still states no
   参画/待機 split, still sits directly after the Recommended Action CTA
   and before the legacy per-employee cards (all pinned by its existing
   suites, still green).
   - The per-employee name caption's text-scale growth is capped at
     `maxScaleFactor: 1.15` (via `Text.textScaler`) rather than left
     unbounded, since the compacted scene no longer carries the original
     design's 2×-scale headroom. The name is never the only place it
     appears — the always-fully-scaling per-employee stage card and the
     always-reachable per-employee cards further down the screen both
     still show it without any cap.

2. **`PublicDemoEmployeeStageSection` ("社員ステージ") compacted**
   (`public_demo_home_presentation_components.dart`): each employee is now
   one row (icon + name + status chip) instead of a name row followed by
   an indented status-chip row — roughly half the previous per-employee
   height, and roughly half the card's own chrome (a new `dense` mode on
   the shared `_HomeSectionCard`: padding 14 → 4, margin removed, title-to-
   body gap 10 → 3). This is the "coherent employee summary" the two
   sections now form together — same two independent widgets (both still
   individually testable, both still separately keyed), reporting
   complementary facts (portrait/name vs. current stage) in far less
   combined space. Full detail for each employee remains one tap away on
   the existing, unmoved per-employee cards further down the screen — this
   view is deliberately only the minimal summary Issue #124 asked for.

3. **Vertical gaps between the HOME sections trimmed**
   (`public_demo_01_placeholder_screen.dart`): the `SizedBox` spacers
   between the HOME dashboard block, the Office Stage, and the per-
   employee stage card went from 8pt to 2pt each — freeing the remaining
   space the shrink above didn't already recover.

Nothing else changed. The KPI row, Hiyori's navigator card ("次にやるこ
と" + its CTA), the Recommended Action CTA's own dispatch, Finance,
Persistence, Month Guard, and Recovery are all untouched — every existing
suite that pins those (see Test results below) is green.

### Changed files

- `lib/presentation/home/widgets/home_office_stage_section.dart`
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `lib/ui/public_demo/public_demo_home_presentation_components.dart`
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
  (new — see Test results)

## 360px / 390px verification

Measured directly off the real `PublicDemo01PlaceholderScreen` (April,
turn one — the same state as the real-device screenshots), against the
browser-chrome content budget the existing HOME-RUNTIME-2A/2C suite already
uses (615pt at 360×800, 660pt at 390×844, both measured from the AppBar):

| Fact | 360×800 (budget 615pt) | 390×844 (budget 660pt) |
| --- | --- | --- |
| 月 (month) | ends at 52pt | ends at 52pt |
| 現金 (cash) | ends at 108pt | ends at 108pt |
| 次にやること headline | ends at 269pt | ends at 271pt |
| 次にやること CTA | ends at 356pt | ends at 345pt |
| 社員の様子 (Office Stage) | ends at 525pt | ends at 520pt |
| 社員ステージ (per-employee stage card) | ends at 608pt | ends at 603pt |
| 重要イベント slot (empty in April — see below) | ends at 610pt | ends at 605pt |

Both target widths: no `RenderFlex` overflow, no clipped text, and every
row above stays inside the budget with real (if narrow, ~5-7pt at
360×800) margin. The pre-#124 layout, by contrast, put the per-employee
stage card's real content between roughly 559pt and 765pt at 360×800 —
already past the 615pt budget.

**六项目 (the six Screen Verification questions), both widths:**

1. 今は何月か → `MonthHeaderBar`'s "1年目 4月" — unchanged, still first.
2. 現金はいくらか → the compact KPI's 現金 tile — unchanged.
3. 次に何をすればいいか → Hiyori's headline + CTA — unchanged, structure
   preserved verbatim per the task's own constraint.
4. 誰が待機/利用可能か → the compacted Office Stage photo (both April
   founders, portraits + names) plus the compacted 社員ステージ card.
5. 現在の案件状況はどうか → the compacted 社員ステージ card's per-row
   status chip (both April founders read "営業準備前" — their real,
   authoritative `PublicDemoSalesStage`-derived status, the same mapping
   the pre-existing card already used).
6. 今月何が変わったか → the 重要イベント slot. April is turn one, so
   nothing has closed yet and the slot is correctly the pre-existing
   zero-footprint empty marker (verified in
   `public_demo_home_presentation_components_test.dart`'s existing
   populated-state coverage, and now additionally verified reachable
   within budget once populated by
   `public_demo_01_home_consolidation_test.dart`'s "a populated Important
   Events section remains reachable" case) — its slot no longer sits
   beyond the budget the way it did pre-#124, so a later month's real
   content is not pushed out of the first view by this section's own
   footprint.

All six are readable without scrolling at both target widths.

## Test results

Flutter SDK used: 3.47.2 stable (fetched fresh into the session — none was
pre-installed in this environment).

- `flutter analyze`: **No issues found.**
- Targeted HOME/office-stage/employee-stage suites (all previously-passing
  assertions still hold, unmodified — only the new Issue #124 file was
  added):
  - `test/presentation/home/home_office_stage_section_test.dart` — 38/38
    pass (includes the 360×800/390×844 layout-safety group).
  - `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
    — 17/17 pass.
  - `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` —
    23/23 pass (real-screen ordering, roster-authority, and no-new-
    mutation-authority groups).
  - `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` —
    all pass, including the pre-existing 360×800/390×844
    browser-chrome-budget assertions on the Recommended Action CTA and the
    `_homeBlockCeiling` check.
  - `test/ui/public_demo/public_demo_01_home3_integration_test.dart` —
    all pass, including the 1.3× text-scale, no-overflow case.
  - `test/ui/public_demo/public_demo_01_home_navigator_test.dart` — all
    pass, including the 1.0×/1.15×/1.3×/2.0× text-scale, no-overflow
    cases.
  - `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
    (**new**) — 5/5 pass: the six-fact-in-viewport assertion at both
    widths, the combined Office-Stage-plus-stage-card height regression
    guard, and a gameplay-untouched check (the Recommended Action CTA
    still dispatches the real `startSkillSheetReview` domain command).
  - Combined total re-run together: 98/98 pass.
- No test was skipped, marked `fixme`, deleted, or had an assertion
  weakened. No `retry`/`timeout` value was touched.
- The full `flutter test test/ui/public_demo/` directory (all ~35 files,
  including the long seeded playthrough/E2E-style suites) was started but
  not run to completion in this session — per the task's own instruction,
  waiting out that Heavy E2E run was not treated as a completion
  requirement. Every file in that directory that actually references the
  widgets, keys, or metrics this change touched (`home-office-stage`,
  `public-demo-employee-stage`, `社員ステージ`,
  `public-demo-important-events`, `HomeOfficeStageMetrics`) was identified
  by search and run individually to completion above.
- `git diff --check`: clean (no whitespace errors).

### A regression this session found and fixed along the way

The first compaction pass (smaller scene/portrait/padding, no text-scale
handling) passed at the default text scale but overflowed
`RenderFlex` by 2pt inside the Office Stage figure at 1.3×–2.0× text
scale, because the smaller scene no longer had the original design's
generous 2×-scale margin. This was caught by the pre-existing
`public_demo_01_home3_integration_test.dart` (1.3×) and
`public_demo_01_home_navigator_test.dart` (1.0×/1.15×/1.3×/2.0×) suites —
neither assertion was weakened; the fix (capping the name caption's own
text-scale growth at 1.15×, plus a small additional scene-height margin)
made both pass again at their existing, unmodified thresholds.

## Remaining issues

- The 615pt/360×800 budget margin for the per-employee stage card is
  narrow (~5-7pt) by design — it is spending nearly all of the space the
  compaction recovered on bringing real content into view rather than
  banking margin. A future addition to that card (a third/fourth employee
  becoming visible, per its existing `_maxVisible = 4` cap) will grow it
  further; `home_office_stage_section_test.dart`'s and
  `public_demo_home_presentation_components_test.dart`'s own overflow/
  text-scale suites already exercise that growth path and stay green, but
  a wider margin was out of scope for this minimal-diff follow-up.
- This report's 360px/390px numbers are measured against
  `flutter_test`'s widget-tree layout, the same method the pre-existing
  HOME-RUNTIME-2A/2C budget suite already uses — not a live device or
  Playwright screenshot. Playwright/manual on-device re-verification of
  Issue #124 (mirroring the original real-device Screen Verification that
  opened it) is still recommended before this is called fully closed,
  since no browser or device automation was available in this session.

## Commit / branch / PR

- Repository: `perusonao/smile_enjoy_story`
- Branch: `claude/home-viewport-compression-w9hr5y`
- Commit SHA: _(filled in after commit — see the pushed branch)_
- PR URL: _(filled in after the PR is opened)_
- Result report (this file, repository-relative path):
  `docs/reports/SES_ISSUE-124_ScreenVerification_Followup_Result.md`

## Merge readiness

- `flutter analyze`: clean.
- All targeted HOME/office-stage/employee-stage/Issue-124 tests: green
  (98/98 across the suites listed above), including two pre-existing
  text-scale suites this change's first pass regressed and the second
  pass fixed without weakening any assertion.
- No gameplay/Finance/Persistence/save-schema/balance/Month-Guard/
  Recovery code was touched — verified both by diff review (three
  production files, all inside `lib/presentation/home/widgets/` and
  `lib/ui/public_demo/`, none touching `lib/game/` or `lib/domain/`) and
  by the still-green domain-authority-following assertions inside
  `public_demo_01_home_consolidation_test.dart` and
  `public_demo_01_home_office_stage_test.dart`.
- `git diff --check`: clean.
- Recommended before merge: a real-device or Playwright re-run of the
  original Issue #124 Screen Verification steps, since this session
  verified the same facts through `flutter_test`'s layout engine rather
  than a browser.
