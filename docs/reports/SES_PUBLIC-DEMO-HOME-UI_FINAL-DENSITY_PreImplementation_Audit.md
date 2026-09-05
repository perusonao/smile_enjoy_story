# SES PUBLIC-DEMO-HOME-UI FINAL-DENSITY — Pre-Implementation Audit

STATUS: **Reference note — written at the start of this implementation, not before it**

BASE: `origin/main` @ `a80d6e473e344655f120cac597ff104444b48e51` (PR #177 merged; Issue #168 complete)

## Why this document looks the way it does

The implementation task for SES HOME Final Density names this file as a
reference alongside `public_demo_home_ui_3a_target.jpeg` and
`SES_DEVELOPMENT-PRIORITY_2026-09-02.md`. On checking out a fresh
`origin/main` at the SHA above, this file did not exist anywhere in the
repository or its git history (`git log --all` for this path and for any
`*FINAL-DENSITY*`/`*PreImplementation_Audit*` file returns nothing). Rather
than block the implementation on a document that is not recoverable from
this repository, this report *is* that audit — measured directly against
the real, current production widget tree at the start of this task, using
the same viewport/`ListView`-rect technique the existing PUBLIC-DEMO-HOME-
UI-3C density suite (`test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart`,
Issue #173) already established as this codebase's way of pinning "does
this section start inside the unscrolled initial view".

All numbers below are real `tester.getRect(...)` measurements from a
temporary instrumented widget test pumping `PublicDemo01PlaceholderScreen`
at April 1 (`PublicDemoAggregate.initial()`), default `TextScaler`, before
any code in this phase changed — not estimates.

## Baseline measurement (before this phase)

`PublicDemo01PlaceholderScreen`'s HOME tab (`_buildHomeTab`) renders, top to
bottom, inside one `ListView` under the app's `AppBar` (56pt) and above its
`NavigationBar` (80pt, `Scaffold.bottomNavigationBar` — always visible,
outside the scrollable body):

`PublicDemoCashShortageCard` (only during an actual shortage) →
`PublicDemoHomeDashboardSection` (month header + `KpiSection.compact` + the
`HomeNavigatorSection` "ひより" card) → `PublicDemoMonthlyPrimaryCtaSection`
("月次処理") → `HomeOfficeStageSection` ("社員概要") →
`PublicDemoImportantTasksSection` ("今月の重要タスク") →
`PublicDemoQuickAccessSection` ("クイックアクセス").

| Section | 390×844 top / height | 360×800 top / height |
|---|---:|---:|
| `ListView` viewport bottom | 764 | 720 |
| KPI (`home-kpi-compact`) | 114 / 114 | 112 / 114 |
| ひより (`home-navigator`) | 234 / 264 | 234 / 280 |
| 月次処理 (`public-demo-monthly-primary-cta-card`) | 500 / 94 | 516 / 94 |
| 社員概要 (`home-office-stage`) | 596 / 95 | 612 / 85 |
| 今月の重要タスク (`public-demo-important-tasks`) | 697 / 166 | 703 / 166 |
| クイックアクセス (`public-demo-quick-access`) | **869** / 114 | **875** / 114 |

Every section through 今月の重要タスク already starts inside the
unscrolled viewport at both target widths (PUBLIC-DEMO-HOME-UI-3C's own
Issue #173 guarantee, still intact). クイックアクセス does not:

- **390×844**: top 869 vs. viewport bottom 764 → **105px past the fold**
  (and its own bottom, 983, is 219px past the fold).
- **360×800**: top 875 vs. viewport bottom 720 → **155px past the fold**.

This is the concrete gap SES HOME Final Density closes.

## Sizing the fix: what is actually available to cut

Reading every section's own layout code (`home_navigator_section.dart`,
`kpi_section.dart`, `home_office_stage_section.dart`,
`public_demo_home_presentation_components.dart`,
`public_demo_home_dashboard_section.dart`, and the `_buildHomeTab` ListView
itself in `public_demo_01_placeholder_screen.dart`) before writing any code:

- **Real, cuttable slack** exists in card padding, inter-section
  `SizedBox` gaps, the `Divider` between important-task rows, and the
  `ListView`'s own top padding under the `AppBar`. None of it is a
  text-height floor — the codebase's own prior phases (HOME-COMPACT-1B.4,
  PUBLIC-DEMO-HOME-UI-3C) already established and documented this exact
  distinction when they made earlier passes at the same paddings, and this
  phase continues that same ledger rather than re-litigating it.
- **ひより (`HomeNavigatorSection`) is the single largest component** at
  244–280pt, because it is the one card carrying genuinely uncapped,
  required copy (the advice message, its always-visible explanation
  bubble) plus two full-width 48pt CTAs (`minimumSize`, not reducible —
  Android's minimum accessible touch target). This matches the brief's own
  instruction to treat it as "the biggest lever": its *padding/gap*
  budget, not its text, is where real height comes back.
- **社員概要 (`HomeOfficeStageSection`) is explicitly out of scope for
  further compression.** Its own file docs (`HomeOfficeStageMetrics`)
  already record that `compactSceneHeight: 60` is a measured *floor* — a
  compact portrait (28pt) plus its name pill needs exactly that much room
  before the existing `home_office_stage_section_test.dart` layout-safety
  suite starts failing. The brief's own "Employee Summaryはこれ以上無理に圧縮
  しない" instruction matches what the code already tells us: there is no
  more real slack here without re-opening a settled layout-safety budget.
- **The important-task CTA is a `TextButton` printing the same "対応する"/
  "確認する" text three times.** Converting it to an icon-only control
  (with the label preserved for assistive technology via an explicit
  `Semantics.label` — required per the brief) gives the title/fact column
  real width back at every text scale, which is the brief's own suggested
  lever ("Important Task CTAをicon化する場合はSemantics(label:
  item.ctaLabel)必須").
- **FittedBox(scaleDown) and `maxLines` truncation are excluded on
  principle**, per the brief, and neither is needed here: every reduction
  below comes from padding/gap, not from shrinking or clipping real copy.

## What this audit target implies for implementation

Closing the full 105–155px gap through padding/gap trimming alone, without
touching 社員概要 further and without clipping ひより's required copy, is
not achievable — most of ひより's real height is the advice message and its
explanation bubble, both required, uncapped text. The realistic, honest
target this audit sets is:

- Bring クイックアクセス's own **top** position inside (390×844) or as close
  as possible to (360×800) the unscrolled viewport bottom — the same
  "starts inside the viewport" bar PUBLIC-DEMO-HOME-UI-3C's own suite
  already uses for 今月の重要タスク, not full-card visibility.
- Treat 390×844 as the binding target (the brief's own "原則把握可能" for
  all seven listed pieces) and 360×800 as explicitly weaker ("最低でも
  Quick Accessの存在/入口が認識可能").
- A cumulative reduction in the ~100–150px range, applied to KPI, ひより,
  月次処理, 今月の重要タスク, and the shared `ListView`/section-card
  chrome — not to 社員概要.

See `SES_PUBLIC-DEMO-HOME-UI_FINAL-DENSITY_Result.md` for the actual
measured after-state and the itemized list of every trim this phase made
to reach it.
