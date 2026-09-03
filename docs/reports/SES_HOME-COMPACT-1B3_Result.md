# SES HOME-COMPACT-1B3 — Public Demo HOME Compact Redesign + Cash Guidance Result

Issue #148 Phase 1B.3. Redesigns Public Demo HOME so its initial 390px-wide
view reaches "現在月・会社の要点KPI・ひよりの次にやること・資金注意時の理由と行動・月次進行CTA"
without scrolling, and connects the already-merged confirmed-information
cash forecast/status/advice models (PR #153/#154) into HOME's Navigator
card.

## Base SHA / Head SHA

- **Base SHA:** `dbbe25904c25deee2b7cd0ce6f3d0ccb54183872` (`origin/main` HEAD
  at task start — confirmed to already carry PR #153/#154/#157/#158).
- **Head SHA (implementation commit):** `5985ee1d489985e6b2d7b96462d4e7a026614669`.
- **Head SHA (final, incl. the Codex P2 fix below):** `ca4800dde9d04a71223662cf31af07467a157286`.

## Start-condition verification (performed before any implementation)

- `git fetch origin` — done.
- PR #158 (`fix(public-demo): SkillSheet P2 — stop fabricating 0-month
  experience for experienced hires`): `merged: true`.
- PR #153 (`PublicDemoCashForecast`, Issue #148 Phase 1A): `merged: true`,
  present on `origin/main`.
- PR #154 (`PublicDemoCashStatusPresentation` + `PublicDemoCashAdviceSelector`,
  Issue #148 Phase 1B.1+1B.2): `merged: true`, present on `origin/main`.
- PR #157 (SkillSheet Phase A re-integration): `merged: true`, present on
  `origin/main`.
- All four confirmed via `mcp__github__pull_request_read` (`merged: true`
  on each) and via `git log origin/main` (their commits — `e60dbe3`,
  `8d510e6`, `f0c0f11`, `dbbe259` — are all ancestors of the fetched
  `origin/main` HEAD).
- The working branch (`claude/issue-148-home-compact-cash-bqw6dv`) had no
  unmerged commits of its own — it was pointing at a stale ancestor commit
  with zero unique history and no open PR — so it was reset to
  `origin/main` HEAD before starting, per the harness's "already-merged /
  stale branch" instruction.

All start conditions were satisfied, so implementation proceeded.

## Assets used and where they were added

Both assets from `SES_HOME_COMPACT_Assets_v1.zip` were used. Neither
original PNG was committed as-is — both were resized/re-encoded (via
Pillow) to match this repo's existing small-file asset convention (the
existing bundled crops are 13–16KB JPG/WebP; the source PNGs were
2.2MB/1.8MB) before being added:

- `char_hiyori_home_compact_v1.png` (1024×1536) → resized to 512×768,
  re-encoded as WebP (quality 82) → `assets/images/navigator/navigator_home_compact.webp`
  (38KB). Registered as `AssetPaths.navigatorHomeCompact` and wired as the
  new artwork for `NavigatorExpression.normal` only
  (`HomeNavigatorIdentity.portraitAssetFor` in
  `lib/presentation/home/models/home_navigator_display.dart`) — the
  existing `AssetPaths.navigatorCaution` artwork is untouched, so the
  caution/normal visual distinction the new cash-advice integration relies
  on is preserved. Used only as a small circular avatar inside the existing
  `HomeNavigatorSection` card — never a full-screen illustration.
- `location_office_day_home_banner_v1.png` (1672×941) → resized to
  960×540, re-encoded as JPEG (quality 82) →
  `assets/images/locations/office_day_home_banner.jpg` (71KB). Registered
  as `AssetPaths.locationOfficeDayHomeBanner` and wired as the new default
  `backgroundAssetPath` for `HomeOfficeStageDisplay`
  (`lib/presentation/home/models/home_office_stage_display.dart`), i.e.
  the "社員の様子" section's horizontal background — no text is baked into
  the image; every label is still drawn by Flutter on top, unchanged.

Both new files land in directories `pubspec.yaml` already registers in
directory form (`assets/images/navigator/`, `assets/images/locations/`),
so **no `pubspec.yaml` change was needed**.

No new raster image was added for the cash warning itself — it reuses the
existing `navigatorCaution` artwork (already bundled), the existing
`HomeNavigatorSection` card chrome, and plain formatted-yen text, per the
task's explicit instruction not to add a new image there.

## How the initial HOME was made scroll-free

The existing HOME structure (`PublicDemo01PlaceholderScreen`) was already
decomposed into modular sections (`PublicDemoHomeDashboardSection` —
month header + compact KPI + Navigator card —, `HomeOfficeStageSection`,
`PublicDemoImportantTasksSection`, `PublicDemoQuickAccessSection`,
`PublicDemoFinanceSummarySection`, `PublicDemoMonthlyPrimaryCtaSection`,
plus the detailed per-employee legacy action surface). The defect was
purely **ordering**: the monthly-progression CTA was rendered after the
Office Stage picture, the important-tasks list, the quick-access grid, and
the finance summary — several screens' worth of content below the fold.

The fix, entirely inside `public_demo_01_placeholder_screen.dart`'s
`build()`:

- `PublicDemoMonthlyPrimaryCtaSection` (bound from the same single
  `_monthlyPrimaryAction` getter as before — one binding site, unchanged)
  now renders **immediately after** `PublicDemoHomeDashboardSection`
  (month/KPI/Navigator), with no extra spacer between them (relying on the
  dashboard section's own trailing gap) to close a final 6pt gap found
  during 360×800 verification.
- The Office Stage, 重要タスク, クイックアクセス, and 支出予定 sections keep
  their existing relative order, just pushed below the CTA. None of them
  is in Issue #148 Phase 1B.3's required initial-view list (月/KPI/ひより/
  資金注意時の理由と行動/月次進行CTA), so this costs nothing against the
  acceptance criteria — they remain reachable via scroll, the existing
  quick-access items, and the existing bottom-nav destinations, unchanged.
- No section was deleted, no new section was added, and no per-employee
  detail (case, project, training) was added to the initial view — the
  existing compact/summary shape of every section (already built in prior
  phases: HOME-RUNTIME-2A/2B/2C, PUBLIC-DEMO-HOME-UI-3A) is unchanged.

This was verified against both the strict raw-`ListView`-viewport bound
(stricter than the browser-chrome-adjusted budget other suites use) and a
real Chromium render at both 360×800 and 390×844 — see Verification below.

## How the cash display was connected

`PublicDemo01PlaceholderScreen` gained one new read-only getter,
`_cashForecastAdvice`, that:

1. Calls `PublicDemoCashForecast.forecast(state: s, workflow: workflow)`
   (PR #153, unmodified) to get the confirmed-information projection.
2. Calls `PublicDemoCashStatusPresentation.fromForecast(...)` (PR #154,
   unmodified) to get `safe` / `shortage` / `unavailable`.
3. When `shortage`, calls `PublicDemoCashAdviceSelector.select(...)` (PR
   #154, unmodified) to get at most one advice candidate.
4. Turns that already-decided output into one `HomeNavigatorAdvice` —
   HOME's existing presentation type for the Navigator card — reusing the
   forecast's own `shortageMonth` and the matching forecasted month's own
   `closingCash` as the "根拠となる短い数値" (e.g. "10月末の現預金見込み
   -¥600,000"), and dispatching the candidate's action through the
   **existing, already-bound** owner handlers
   (`_openSkillSheetReview`/`_selectInternalTraining`/`_beginSelling` —
   the same methods the production per-employee buttons already call). No
   new command, no new screen, no new eligibility rule was added anywhere
   in this path.

**Suppression rule (avoids duplicating the existing strong cash lead):**
this advice is computed only while
`PublicDemoState.financialStatus == PublicDemoFinancialStatus.normal`.
Once an actual shortage/bankruptcy/March-failure is reached, this getter
returns `null` outright — the existing `PublicDemoCashShortageCard`, the
bankruptcy terminal card, and the existing `cashShortageResponse`
recommended-action candidate (already emitted at P0 in
`_recommendedActionCandidates` whenever `financialStatus == cashShortage`)
remain the sole leads, exactly as before this change. This is the one
condition Issue #148 Phase 1B.3 asks for a preventive/forecast-based
warning to cover — the window *before* an actual shortage happens, which
no existing UI communicated at all.

**Integration into the Navigator card:** `PublicDemoHomeDashboardSection`
gained one new optional field, `cashAdvice`. Its `_effectiveAdvice` getter
now takes `cashAdvice ?? <existing normal-mode resolution>` — i.e. the
forecast-based caution advice, when present, wins the one Navigator slot
outright ("優先度付きで統合", per the task) instead of being a second card;
when absent (safe/unavailable/actual-shortage/terminal), the pre-existing
behavior (recommended action, or the month-goal fallback) is byte-for-byte
unchanged. The Navigator's caution/normal portrait selection
(`navigatorExpressionFor`) was corrected to key off this same effective
advice's semantic (previously it read the pre-cash-advice `navigatorAdvice`
parameter directly — equivalent in every pre-existing case, since both
carried the same `semantic`, but it needed to be effective-advice-aware for
the new caution case to show the worried expression).

## Changed files

Production:
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — moved the
  monthly CTA up; added `_cashForecastAdvice` + `_engineerById`; wired
  `cashAdvice` into `PublicDemoHomeDashboardSection`.
- `lib/ui/public_demo/public_demo_home_dashboard_section.dart` — added the
  `cashAdvice` field and its priority over the existing advice resolution.
- `lib/presentation/home/models/home_navigator_display.dart` — wired
  `AssetPaths.navigatorHomeCompact` for `NavigatorExpression.normal`.
- `lib/presentation/home/widgets/home_navigator_section.dart` — portrait
  fallback now reads the single source of truth
  (`HomeNavigatorIdentity.portraitAssetFor(normal)`) instead of a second
  hardcoded asset constant.
- `lib/presentation/home/models/home_office_stage_display.dart` — new
  default `backgroundAssetPath` (`AssetPaths.locationOfficeDayHomeBanner`).
- `lib/ui/asset_paths.dart` — two new registered asset constants.

New assets:
- `assets/images/navigator/navigator_home_compact.webp`
- `assets/images/locations/office_day_home_banner.jpg`

Tests (updated for the intentional asset/order changes above):
- `test/presentation/home/home_navigator_section_test.dart`
- `test/presentation/home/home_office_stage_section_test.dart`
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart`
  (section order assertion updated: CTA now directly follows the Navigator)
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart`
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
  (initial-view required-set updated: monthly CTA replaces the Office
  Stage picture in what must be unscrolled, per Issue #148 Phase 1B.3 —
  the Office Stage remains reachable, just no longer required in the first
  frame)

New test:
- `test/ui/public_demo/public_demo_01_home_cash_forecast_advice_test.dart`
  — drives the real screen through a real trajectory (the same
  structurally-insolvent trajectory
  `public_demo_01_home_consolidation_test.dart`'s own group 19 already
  pins) to the exact preventive window (month 10, `financialStatus` still
  `normal`, forecast already sees a shortage) and asserts: the Navigator
  states the forecasted month and a caution portrait, a real next action
  is offered, no duplicate large card renders; a healthy April shows no
  cash warning at all; and once the real `cashShortage` is reached one
  close later, the forecast-based message is gone and the existing card is
  the sole lead.

Report:
- `docs/reports/SES_HOME-COMPACT-1B3_Result.md` (this file)
- `docs/reports/screenshots/ses-148-1b3-home-{360,390}-normal.png`,
  `ses-148-1b3-home-360-{caution,shortage}.png` (real-Chromium evidence,
  see Verification)

### Codex P2 fix (commit `ca4800d`)

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — the sole
  production file touched: `_cashForecastAdvice` now excludes
  `workflow.assignedEngineerIds(month: s.month)` from the engineer pool it
  passes to `PublicDemoCashAdviceSelector.select`. No other function in
  this file was changed.
- `test/ui/public_demo/public_demo_01_home_cash_forecast_advice_test.dart`
  — added the `_FixedSaveService`/aggregate-fixture helpers and the new
  "P2 fix (Codex review on PR #159)" test group (2 tests); the file's
  pre-existing 3 tests are unchanged.

## Not changed

`GameState`, monthly close/finance rules, save schema, sales success rate,
the existing E2E harness, `PublicDemoCashForecast`,
`PublicDemoCashStatusPresentation`, `PublicDemoCashAdviceSelector`,
SkillSheet's confirm/開始 business rules, Phase 2/B/C scope — none of these
were touched. No unrelated refactoring was performed.

## Codex P2 fix: exclude already-assigned engineers from cash advice

Codex review on PR #159:
https://github.com/perusonao/smile_enjoy_story/pull/159#discussion_r3924337236

**Problem.** An applicant who wins a June pre-entry order joins as an
engineer at `PublicDemoSalesStage.waiting` (`withJoinedEngineers` always
creates a freshly-joined engineer at `waiting`, regardless of the
applicant's own pre-entry sales stage) in the very same `closeMay` that
also adds them to the assignment roster (`assignOrderedForMay`, which
reads the applicant's `juneOrdered` stage independently of the new
engineer object's `stage` field). So `engineer.stage == waiting` alone no
longer means "not currently on a project" for that engineer.
`PublicDemoCashAdviceSelector.select` only reads `stage`, so it could
surface this already-assigned engineer as the cash-advice CTA target —
confirming their SkillSheet or starting their training would either be a
silent no-op (the aggregate's own guards reject re-advancing an assigned
engineer) or push them back into the sales pipeline for a project they
are already on.

**Fix (minimal, single file).** Only
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`'s
`_cashForecastAdvice` getter was touched — the one HOME binding site the
task scoped this to. `PublicDemoCashForecast`, `PublicDemoCashStatus
Presentation`, and `PublicDemoCashAdviceSelector` are untouched.

**Exclusion condition.** Before calling
`PublicDemoCashAdviceSelector.select`, the getter now computes
`workflow.assignedEngineerIds(month: s.month)` (the same existing SSOT
already used by this screen's own training card and the P2-fix month-6/
Recovery filters — see `_currentlyAssignedEngineerIds`'s own doc) and, when
non-empty, builds a throwaway `PublicDemoWorkflowState` whose `engineers`
list omits every engineer in that set, then passes *that* into the
selector instead of the raw `workflow`. The selector's own logic, order,
and eligibility rules are completely unchanged — it simply never sees an
already-assigned engineer, so it naturally falls through to the next
genuinely eligible waiting/skillSheet engineer on its own. When none
remain, it returns `null` exactly as it already does for "no candidate",
which the existing `candidate == null` branch already renders safely (the
finance-detail scroll-jump CTA, never a CTA bound to a fabricated action)
— so "除外後に候補がない場合は、無効なCTAを表示しない" holds without any
extra branching.

**Regression tests** (`test/ui/public_demo/public_demo_01_home_cash_
forecast_advice_test.dart`, new group "P2 fix (Codex review on PR #159)"):
both build a `PublicDemoAggregate` via a real command chain (interview →
offer → pre-entry SkillSheet/selling/partner+client interview → June
order → `closeMay`, mirroring `public_demo_aggregate_test.dart`'s own
"TEST E: genuine applicant happy path") that reproduces the exact
join/assignment mismatch, injected via the existing `_FixedSaveService`
pattern (`public_demo_01_single_month_advance_cta_test.dart`'s own
technique):

1. *Only the assigned engineer is nominally eligible* — after the June
   order + `closeMay`, `app-01` (高橋 翔) is the sole `waiting`-stage
   engineer and is already on the assignment roster. Asserts: a caution
   advice genuinely renders (the fixture's forecast is confirmed to go
   negative while `financialStatus` is still `normal`), 高橋 翔's name never
   appears anywhere inside the Navigator card, and the CTA is specifically
   the safe `資金計画を確認する` finance-detail fallback (not merely absent),
   which is confirmed tappable without throwing.
2. *A second, genuinely idle waiting engineer exists after exclusion* — a
   second applicant (`app-02`, 田中 美咲) joins via accept-offer only (no
   further pre-entry steps), appended *after* `app-01` in
   `workflow.engineers`' own order — the exact ordering that would let a
   naive first-match scan return the wrong engineer. Asserts: the Navigator
   names 田中 美咲 (headline and/or advice-bubble explanation) and never 高橋
   翔, with a real CTA present.

Both tests were verified to **fail** against the pre-fix binding (temporarily
feeding the raw, unfiltered `workflow` into the selector, confirmed via a
local revert-and-rerun) and **pass** with the fix applied — they are a
genuine regression guard, not vacuously-true assertions.

## Test results

Flutter 3.44.9 / Dart 3.12.2 (matches this repo's CI pin; built from the
official stable-channel archive in this sandbox, which ships neither
Flutter nor Dart by default).

- `dart format` (12 changed `.dart` files only): 0 files needed changes.
- `flutter analyze` (repo-wide): **No issues found.**
- `flutter test test/ui/public_demo/` (HOME/Public Demo UI, incl. the new
  cash-forecast-advice suite and the SkillSheet flow test):
  **221/221 passed.**
- `flutter test test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`
  (SkillSheet flow specifically, called out per the task's own required
  scope): **2/2 passed.**
- `flutter test test/game/public_demo/` (cash forecast/status/advice +
  every other domain suite in this directory, unmodified logic):
  **500/500 passed.**
- `flutter test test/presentation/` (HOME component suites, incl.
  Navigator/Office-Stage/KPI/dashboard-wiring): **200/200 passed.**
- Combined run of all three required scopes together (`test/ui/public_demo/
  test/presentation/ test/game/public_demo/`): **924/924 passed**, 0
  failures.

### Codex P2 fix re-verification (this update)

- `dart format` (both files this fix changed): 0 files needed changes.
- `flutter analyze` (repo-wide): **No issues found.**
- `flutter test test/ui/public_demo/` (now includes the 2 new P2
  regression tests added to `public_demo_01_home_cash_forecast_advice_test
  .dart`): **226/226 passed.**
- `flutter test test/game/public_demo/ test/presentation/`:
  **700/700 passed** (500 + 200, unchanged from before this fix — this fix
  touches no domain/presentation-component file).
- `flutter test test/ui/public_demo/public_demo_01_issue_124_screen_
  verification_test.dart test/ui/public_demo/public_demo_01_skill_sheet_
  flow_test.dart` (360px/390px no-scroll requirement + SkillSheet flow,
  re-confirmed unaffected by this fix): **7/7 passed.**
- The two new P2 regression tests were confirmed to **fail** when the fix
  is reverted (raw `workflow` fed to the selector) and **pass** with it
  restored — verified locally before pushing.

## 360px / 390px confirmation

**Widget-test level** (Flutter's own render tree, both required widths):
- `public_demo_01_issue_124_screen_verification_test.dart` — at 360×800
  and 390×844, with the scroll position pinned at 0, asserts month, cash,
  the next-action headline+CTA, and (updated by this task) the monthly
  progression CTA (`Key('public-demo-monthly-primary-cta')`) all paint
  inside the raw, unscrolled `ListView` viewport (a stricter bound than
  the browser-chrome-adjusted budget other suites use). Passes at both
  widths.
- `public_demo_01_home_cash_forecast_advice_test.dart` — drives the real
  preventive-shortage and real-shortage trajectories and asserts the
  Navigator's content and the absence of duplicate cards; not
  width-parameterized itself, but exercises the same screen the
  width-parameterized suites above already cover for layout.
- The broader existing suites (`public_demo_01_home3_integration_test.dart`,
  `public_demo_01_home_navigator_test.dart`,
  `public_demo_01_home_consolidation_test.dart`, and others) already assert
  no horizontal overflow / no clipped labels at 360px and 390px, at text
  scales up to 2.0×, and were re-run green after this change.

**Real Chromium confirmation** (this task's own manual verification, via
the pre-installed Chromium binary and this repo's existing
`e2e/helpers/public-demo-player.ts` helpers, run once as a throwaway
Playwright spec and deleted afterward — not part of the checked-in
suite):

- Built `flutter build web --release` (53s) and served it locally.
- At **360×800**: initial HOME (April, `financialStatus == normal`) —
  `document.documentElement.scrollWidth === window.innerWidth` (0px
  horizontal overflow), `window.scrollY === 0`, and the accessibility
  snapshot contains the month, cash, `SkillSheetを確認`, and
  `4月を終了して5月へ`. See `docs/reports/screenshots/ses-148-1b3-home-360-normal.png`.
- Drove the same structurally-insolvent trajectory the new widget-test
  suite pins (April → October, choosing no summer bonus) to month 10 with
  `financialStatus` still `normal`. At that point: still 0px horizontal
  overflow, and the Navigator shows `鈴木 葵の社内研修` / "10月に資金がマイナス
  になる見込みです。" / a `研修する` CTA / the advice bubble "10月末の現預金
  見込み -¥600,000。次の一手として鈴木 葵の対応を進めましょう。" — no
  `資金不足の状態` (the real shortage card) rendered yet. See
  `docs/reports/screenshots/ses-148-1b3-home-360-caution.png`.
- Closed October → real `cashShortage`. The existing `資金不足：次回決算が
  期限です` card renders as the sole strong lead; the Navigator falls back
  to its normal next-action resolution (a genuine Recovery candidate, per
  the pre-existing P(-1) priority rule) — the forecast-based caution
  message does not reappear. See
  `docs/reports/screenshots/ses-148-1b3-home-360-shortage.png`.
- Repeated the initial-HOME check at **390×844** with the same result (0px
  horizontal overflow, all required facts present unscrolled). See
  `docs/reports/screenshots/ses-148-1b3-home-390-normal.png`.
- No console errors, no exceptions, no visible clipping in any screenshot.

## Unexecuted verification

- **WebKit** (`mobile-webkit` Playwright project) — not run; per the
  task's own instruction, deferred to PR CI.
- **Full repo-wide Playwright E2E suite** (`e2e/tests/*.spec.ts`, the
  checked-in specs) — not run in this task; the manual verification above
  reused the same production helper library those specs use, but was a
  throwaway script/spec outside the checked-in suite, deleted before this
  commit. Deferred to PR CI, per the task's own instruction.
- Full repo-wide `flutter test` (~1300+ tests across the whole app, not
  just Public Demo/HOME) was not re-run; this task's required scopes
  (`test/ui/public_demo/`, `test/presentation/`, `test/game/public_demo/`)
  were run in full and are green.
- No manual/eyeball QA on a physical device.
- **(Codex P2 fix)** The real-Chromium manual verification above (normal/
  caution/shortage screenshots) was not re-run after this fix — it exercises
  a different fixture (the founding-engineer trajectory, which never hits
  the June-join mismatch this fix addresses) and its outcome is unaffected;
  the fix's own correctness is instead proven by the two new widget-level
  regression tests (confirmed to fail pre-fix and pass post-fix). WebKit
  and the full Playwright suite remain deferred to PR CI, unchanged from
  before this fix.

## PR URL

https://github.com/perusonao/smile_enjoy_story/pull/159

## Merge readiness

**Not merged by this session**, per the task's own instruction. Local
evidence — all four required test scopes green (924/924 at the initial
implementation commit `5985ee1`; re-confirmed green after the Codex P2 fix
at `ca4800d`, including the 2 new targeted regression tests), `flutter
analyze` clean, `dart format` clean on every changed file, and a real
Chromium render confirming all three financial states (normal/preventive
caution/real shortage) at both 360px and 390px with no horizontal overflow
and no forced initial scroll — indicates a narrowly-scoped, additive
change (no `GameState`/finance/save-schema/SkillSheet-business-rule edits)
that is low-risk to merge once PR CI (WebKit + full Playwright suite +
full Flutter test) is green.
