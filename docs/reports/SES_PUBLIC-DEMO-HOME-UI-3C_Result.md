# SES PUBLIC-DEMO-HOME-UI-3C — Result Report

Issue: [#173](https://github.com/perusonao/smile_enjoy_story/issues/173)
Branch: `claude/public-demo-home-ui-3c-q7gnb4`
Audited main SHA (fresh start point, after PR #172's merge): `c7c9719f76d24db542b7a55bc017a22f0517b970`

## 1. Scope

Issue #173 asks to finish HOME's density and add truthful empty states on top
of PUBLIC-DEMO-HOME-UI-3B's (#171/#172) real five-tab architecture, without
reopening domain/save/balance/finance authority. Priority order, as given:

1. Bring HOME substantially closer to a one-screen summary/decision UI.
2. Reduce excessive vertical space in the month-close/monthly-processing
   presentation.
3. Reduce Hiyori Navigator height without weakening the primary CTA.
4. Slightly compact the employee summary.
5. Add truthful empty states to tabs that currently render visually blank,
   especially early-April 営業.

All five are addressed below. Every change is a spacing/padding/composition
trim on existing presentation widgets, or a new read-only, non-interactive
(beyond real tab navigation) empty-state card — no domain file, save codec,
finance formula, Month Guard, Recovery Loop, or Recommended Action ranking
changed.

## 2. What was actually consuming the space

Before touching anything, the real HOME tab tree and its rendered heights
were read and measured (a throwaway widget-test harness pumping the full
`PublicDemo01PlaceholderScreen` and reading `tester.getRect` on each
section's key — not committed; the permanent regression test added in §6
keeps the one assertion that matters). At fresh April, 360×800:

| Section | top | bottom | height |
|---|---:|---:|---:|
| `ListView` viewport | 56 | 720 | 664 |
| `home-navigator` (Hiyori) | 234 | 524 | 290 |
| `public-demo-monthly-primary-cta-card` | 526 | 627 | 101 |
| `home-office-stage` (employee summary) | 629 | 717 | 88 |
| `public-demo-important-tasks` | 725 | 903 | 178 |
| `public-demo-quick-access` | 911 | 1031 | 120 |

今月の重要タスク started at **725px, 5px below** the 720px-tall raw viewport
— structurally, not by a wide margin, but entirely below the fold, exactly
the Issue's own observation. クイックアクセス was further below still.

## 3. Changes made

### 3.1 Hiyori Navigator (`lib/presentation/home/widgets/home_navigator_section.dart`)

Priority 3. Every change is a padding/gap trim; no font size, no button
`minimumSize` (both the primary and secondary CTA stay a real, tappable
48pt), no copy changed:

- `HomeNavigatorMetrics.cardPaddingVertical`: `6` → `4`.
- The gap before the primary CTA and the gap before the secondary CTA
  (`他の行動を確認する`): `6` → `4` each.
- `_AdviceBubble`'s own padding: `EdgeInsets.fromLTRB(10, 3, 10, 3)` →
  `(10, 2, 10, 2)`.

### 3.2 Monthly primary CTA card (`lib/ui/public_demo/public_demo_home_presentation_components.dart`, `PublicDemoMonthlyPrimaryCtaSection`)

Priority 2 (the "month-close/monthly-processing presentation" on HOME
itself — the ${month}開始結果 monthly-close *narrative*, distinct from this
shortcut card, lives on the 会計 tab per PR #172 and was left untouched,
since it is not part of HOME's own budget and carries no redundant chrome).

- Card padding: `EdgeInsets.fromLTRB(12, 6, 12, 6)` → `(12, 4, 12, 4)`.
- Gap after the "月次処理" eyebrow row: `3` → `2`.
- Gap before the button: `6` → `4`.

The button's own `minimumSize` (44pt — pre-existing, unrelated to this
Issue) is unchanged.

### 3.3 Employee summary (`lib/presentation/home/widgets/home_office_stage_section.dart`, `HomeOfficeStageSection`)

Priority 4. Only the card's own chrome (padding/gap around the title row),
never the photo scene itself — `compactSceneHeight` (60) is a previously
measured, test-pinned floor (a smaller compact portrait + name pill
overflows below it; see the class's own existing doc), so it is untouched:

- `_cardPaddingTop`/`_cardPaddingBottom`: `3`/`3` → `2`/`2`.
- `_titleGap`: `2` → `1`.

`HomeOfficeStageMetrics.compactComponentHeight`/`safetyCeiling`-based tests
reference the named constants, not literals, so they continue to hold
(component height dropped from 88pt to 85pt at 360px, still well under the
213pt safety ceiling).

### 3.4 Section-to-section spacing and card interiors (`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, `lib/ui/public_demo/public_demo_home_presentation_components.dart`)

Priority 1, the rest of the budget:

- The two `SizedBox` gaps between 社員の様子 → 今月の重要タスク →
  クイックアクセス on HOME: `8` → `6` each.
- `_HomeSectionCard` (the shared card shell behind 今月の重要タスク,
  クイックアクセス, and 会計's 今月の支出予定): outer padding `14` → `12`,
  gap under the title `10` → `8`.
- `PublicDemoImportantTasksSection`'s row divider: `Divider(height: 16)` →
  `Divider(height: 10)`.

### 3.5 Result (measured again, same harness, after all of the above)

| Section | top | bottom | height | Δ height |
|---|---:|---:|---:|---:|
| `home-navigator` | 234 | 514 | 280 | −10 |
| `public-demo-monthly-primary-cta-card` | 516 | 610 | 94 | −7 |
| `home-office-stage` | 612 | 697 | 85 | −3 |
| `public-demo-important-tasks` | 703 | 869 | 166 | −12 |
| `public-demo-quick-access` | 875 | 989 | 114 | −6 |

今月の重要タスク now starts at **703px — inside the 664px-tall (56–720)
raw viewport** at 360×800, instead of 725px (entirely below it). At
390×844 (viewport 56–764) it now starts at **697**, with enough of the
664px→708px-tall viewport left over that its own second row (資金計画を確認
する) is also visible — see the real-browser screenshots in §7, where the
whole first important-task row (title, chip, fact, and its own "対応する"
button) reads on-screen with no scroll at both required widths. クイック
アクセス still requires a small scroll — see §8's known gap.

No text shrank and no interactive control dropped below 48 logical px; the
diff is entirely padding/gap trims plus two `Divider`/card-padding
reductions shared by non-HOME cards that carry the same "real slack, not a
text-height floor" reasoning already established for this codebase's other
compaction phases (HOME-COMPACT-1B.4, SES-ISSUE-124).

## 4. Truthful empty state for 営業 (Priority 5)

`_buildSalesTab` in `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
previously rendered content only for month 5 (recruitment media + applicant
funnel), month 6 (assignment cards), and month 7 (July result narrative) —
**every other month (April, and August through March) rendered nothing at
all**, a fully blank tab body below the header. This was not only an April
issue; it recurs every month from August on, once the funnel/assignment
cards this tab owns have nothing left to show (any further per-employee
sales progress by then renders on 社員, per PR #172's own tab mapping).

`_buildSalesTab` now builds its real children into a list
(`_salesTabItems`) and, only when that list is genuinely empty, renders one
new `_salesTabEmptyState()` card (`Key('public-demo-sales-empty-state')`)
instead — never alongside real content, and never inventing a
sales/recruiting action:

- **Before May** (fresh April): "営業・採用のアクションは現在ありません" +
  "案件情報の収集や採用の募集は、社員のSkillSheet確認が完了してから始まります。"
  — states the one already-true causal fact (SkillSheet confirmation is the
  real April prerequisite, matching Hiyori's own April guidance), invents
  nothing.
- **From August on**: the same title + "案件の募集・採用の対応は現在ありません。
  社員ごとの営業状況は「社員」タブで確認できます。" — a genuinely different,
  still-truthful message pointing at where real per-employee status
  actually lives.
- A single `OutlinedButton` ("社員の状況を見る", 48pt tall,
  `Key('public-demo-sales-empty-state-cta')`) calling the screen's existing
  `_switchTab(_employeesTabIndex)` — real tab navigation, the same
  mechanism クイックアクセス/今月の重要タスク already use, not a new
  gameplay action.

May/June/July are unaffected: each always has a real card of its own
(recruitment media always renders in May; the July header text always
renders even if the assignment list itself is momentarily empty), so
`_salesTabItems` is never empty there and the empty state never appears
alongside or instead of real content.

## 5. Preserved authority (explicit check against the Issue's "Do NOT" list)

- **No file under `lib/game/**` changed.** `git diff --stat` for this
  branch touches only `lib/ui/**` and `lib/presentation/home/**`
  presentation files, plus tests and this report.
- **Real five-tab architecture (#171/#172) unchanged.** No tab was merged,
  removed, or renamed; `_buildHomeTab`/`_buildEmployeesTab`/
  `_buildSalesTab`/`_buildAccountingTab`/`_buildMenuTab` still each build
  exactly the content PR #172 assigned them (`_buildSalesTab`'s own
  real-content branches are untouched — only the *fallback* when none of
  them fire is new).
- **Fresh-April SkillSheet routing to 社員 preserved.** The empty-state
  card's own CTA is additional navigation into 社員, not a replacement for
  it; the pre-existing `_switchToEligibleSalesDestination` routing PR #172's
  Codex-review follow-up added (今月の重要タスク's 営業 row, クイックアクセス's
  案件・営業, the Navigator's 他の行動を確認する secondary route) is
  untouched and still lands a fresh-April player on 社員's real SkillSheet確認
  action — pinned again by this phase's own new regression test (§6).
- **No employee/accounting detail added back to HOME.** The employee
  summary stays `HomeOfficeStageSection`'s photo + aggregate headcount only;
  no finance figure was added to HOME (`PublicDemoFinanceSummarySection`
  stays 会計-only, unchanged).
- **No fabricated sales/recruiting action.** The 営業 empty state has one
  button, and it is real tab navigation, not a domain command — verified by
  the new test's own callback-target assertion (it switches
  `NavigationBar.selectedIndex`, nothing else).
- **No gameplay/finance formula changed.** No `PublicDemoAggregate`,
  `PublicDemoMonthlyClose`, `PublicDemoSalary`, or Month Guard/Recovery
  Loop/Recommended Action file touched.
- **No CI/workflow file changed.**
- **No unrelated refactoring.** Every edit is scoped to the six files in
  §9; no renames, no signature changes to any domain-facing method.

## 6. Focused tests added/updated

New file: `test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart`
— five `testWidgets`, exercising the real screen end-to-end through
`PublicDemoAggregate` commands (the same "drive the domain to a specific
month via the same commands production uses, injected through a fixed
`PublicDemoSaveService` fake" technique
`public_demo_01_month_guard_recommended_test.dart` already established):

1. 今月の重要タスク's top edge is inside the raw `ListView` viewport at
   360×800 on a genuinely unscrolled screen (`ScrollableState.position.pixels
   == 0`) — the direct regression pin for Priority 1's acceptance criterion.
2. Fresh April: the before-funnel empty state renders on 営業, states the
   truthful SkillSheet-first reason (`textContaining('SkillSheet確認')`),
   its CTA is a real ≥48pt target, and tapping it lands on 社員's tab index
   with `SkillSheet確認` itself visible there (also re-confirms PR #172's
   fresh-April routing fix is intact).
3. August (built via the same domain-command chain
   `public_demo_01_month_guard_recommended_test.dart`'s
   `_reachAugustClean` uses, reproduced here to reach August directly): the
   after-funnel empty state renders with its own distinct copy, no
   recruitment-media card leaks in, and its CTA also switches to 社員.
4. May: the recruitment-media card is present and the empty state is not.
5. July: the closing narrative is present and the empty state is not.

(An early version of test 5 tried to reach May and then July within the
same `testWidgets` by re-pumping a second `PublicDemo01PlaceholderScreen`
with an updated aggregate inside the same test — Flutter reused the
existing `State` rather than restoring from the new fixed save fake, since
neither the widget's type nor position changed. Split into two independent
`testWidgets`, each pumping fresh, which is the correct fix, not a
workaround.)

## 7. Tests / results, in run order

1. `flutter analyze` (files touched by §3/§4) → **No issues found.**
2. `flutter test test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart`
   (new, dedicated) → **5/5 passed.**
3. `flutter test test/ui/public_demo/` (full directory, 23 files, including
   the new one) → **241/241 passed**, 0 failures.
4. `flutter analyze` (whole project) → **No issues found.**
5. `flutter test` (whole project, final PR-stage gate) → **1,527/1,527
   passed**, 0 failures, exit code 0.
6. `flutter test test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart test/presentation/home/`
   (re-run after the git-stash-based before/after screenshot capture in §8,
   to confirm the working tree still matches what was tested above) →
   **192/192 passed**, including
   `home_navigator_section_test.dart`'s own TextScaler 1.0/1.15/**1.3**/
   **2.0** × 360×800/390×844 coverage of the exact card this phase edited
   (§3.1) — no overflow, every required-text key painted at its full
   required height, the card still grows (never clips) with scale, and the
   secondary CTA stays ≥48pt at every scale. `HomeOfficeStageMetrics`'s own
   suite (§3.3's file) passed under the same run.

No test needed a behavior change — only the pre-existing bottom-nav suite's
comment describing 営業's April state as "renders no card of its own" (an
observation, not an assertion it renders nothing else) stayed accurate
without edit, since that test only checks specific absences
(`SkillSheet確認`, `PublicDemoHomeDashboardSection`), not total blankness.

## 8. 360×800 / 390×844 Screen Verification

Captured from a local `flutter build web --release`, served on `localhost`
and driven with Playwright (`e2e/scripts/ses173-home-density-screenshot.mjs`,
modeled on the existing `ses171-tab-screenshot.mjs`) with Flutter Web's
semantics tree enabled (`?e2e=1`), at both required viewports. Google Fonts
was unreachable from the sandbox (network-restricted, same as PR #172's own
capture), so screenshots render with the fallback system font instead of
the bundled webfont; layout and content are otherwise exactly what a real
deploy renders.

**Before** (git-stashed back to this branch's pre-3C working tree, same
build/serve/capture pipeline, saved under `docs/reports/screenshots/before/`):

- `ses-173-home-360x800.png` — 今月の重要タスク's title is clipped at the
  very bottom edge; its own first row (fact + CTA) is entirely below the
  fold.
- `ses-173-sales-empty-360x800.png` / `-390x844.png` — 営業 in fresh April:
  **fully blank body**, nothing but the app bar and bottom nav.

**After** (this branch, saved under `docs/reports/screenshots/`):

- `ses-173-home-360x800.png` — 今月の重要タスク's title **and its first row**
  (営業活動を進める / 営業残: 4回 / 対応する) are now visible with no scroll.
- `ses-173-home-390x844.png` — the same, plus enough room left over that
  the second row (資金計画を確認する) also reads on-screen.
- `ses-173-sales-empty-360x800.png` / `-390x844.png` — 営業 in fresh April
  now shows the truthful empty-state card (icon, title, the SkillSheet-first
  explanation, and the 48pt "社員の状況を見る" button) instead of a blank body.

No horizontal overflow at either width, in either state.

## 9. TextScaler 1.3 / 2.0

Per the existing precedent for this kind of presentation-density change
(PUBLIC-DEMO-HOME-UI-3A's own result report), TextScaler verification is
via the widget-test suites that already pin 1.0/1.15/1.3/2.0 for the exact
sections this phase edited, not a screenshot (Flutter Web's browser build
has no reliable Playwright hook for OS/browser text-scale, unlike the
widget-test harness, which drives the real `MediaQuery.textScaler` the
production widgets read):

- `test/presentation/home/home_navigator_section_test.dart` (Hiyori,
  §3.1) — group **"J: nothing here is a fixed height around text"** and
  **"H, I: the layout budget"**, both parameterized over
  `[360×800, 390×844] × [1.0, 1.15, 1.3, 2.0]`: no clipped text, no
  horizontal overflow, the card grows (never truncates) with scale, and the
  secondary CTA stays ≥48pt. All green post-edit (§7.6).
- `test/presentation/home/home_office_stage_section_test.dart`
  (employee summary, §3.3) — its own compact/normal-layout and
  safety-ceiling assertions, referencing the edited constants by name, not
  literal pixel values. Green post-edit (§7.3, §7.5).
- The new density test (§6, item 1) is pinned at the default scale only —
  the Issue's own acceptance criteria explicitly reserve "closer to one
  screen" for the default scale, and state larger scales are *expected* to
  push content further down (the existing `compactCeiling`/`safetyCeiling`
  docs already establish this design principle; unchanged by this phase).

## 10. Known gaps

- **クイックアクセス still requires a small scroll** at both target widths.
  Fitting it fully into the raw viewport on top of 今月の重要タスク would
  require either shrinking KPI/Hiyori/employee-summary text or touch
  targets below their current, already-tuned floors (the docstrings in
  `HomeNavigatorMetrics`/`HomeOfficeStageMetrics` record these as tested
  floors from earlier phases, not untried slack) — the Issue's own scope
  note ("if fitting all required HOME information would require harmful
  font/touch-target reduction, keep usability and document the remaining
  vertical gap instead") is followed here rather than trading legibility
  for the last ~100–150px.
- **The 会計 tab's own per-month close narrative** (${month}開始結果, the
  夏季賞与 decision card, 第1期終了) was read but left untouched — it lives
  on its own tab (not HOME's budget) since PR #172, carries no duplicated
  chrome, and the Issue's "month-close/monthly-processing" complaint is
  about the HOME-side shortcut card (§3.2), which is what was compacted.
- Every other §6 known gap from PUBLIC-DEMO-HOME-UI-3B's own result report
  (tab scroll-offset not preserved across a switch, deep-link precision
  edge case for a never-exercised recovery-only-eligible scenario) is
  unchanged by this phase.
- **Deployed Screen Verification** (real device, production build) is left
  to the repository owner, per this task's own instruction; §8's
  screenshots are from a local `flutter build web --release` served and
  captured with Playwright at both required widths.

## 11. Changed files

**lib** (4 files):
- `lib/presentation/home/widgets/home_navigator_section.dart`
- `lib/presentation/home/widgets/home_office_stage_section.dart`
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `lib/ui/public_demo/public_demo_home_presentation_components.dart`

**test** (new, 1 file):
- `test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart`

**e2e** (new, 1 file, throwaway Screen Verification script, mirrors the
existing `ses171-tab-screenshot.mjs`):
- `e2e/scripts/ses173-home-density-screenshot.mjs`

**docs** (this report + screenshots):
- `docs/reports/SES_PUBLIC-DEMO-HOME-UI-3C_Result.md`
- `docs/reports/screenshots/ses-173-{home,sales-empty}-{360x800,390x844}.png`
- `docs/reports/screenshots/before/ses-173-{home,sales-empty}-{360x800,390x844}.png`

## 12. Final commit SHA / PR

- Branch: `claude/public-demo-home-ui-3c-q7gnb4`
- Final commit SHA: `3dc826aa045ac2aa7a634b8c7498c29716ea8666`
- PR: [#174](https://github.com/perusonao/smile_enjoy_story/pull/174)

Per this task's instruction, the PR is **not** merged by this session —
Deployed Screen Verification and the merge decision are left to the
repository owner.
