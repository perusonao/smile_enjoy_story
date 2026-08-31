# SES Issue #118 (PUBLIC-DEMO-NAV-1A) Implementation Result

## STATUS
Implemented, tested, pushed. PR not opened/auto-merged (per instructions).

## RESULT
Fixed. Public Demo HOME now exposes exactly one month-advance Primary CTA
(the canonical `PublicDemoMonthlyPrimaryCtaSection`,
`Key('public-demo-monthly-primary-cta')`) for every month it can be in
(April through the fiscal-year close), and none once the screen is
close-blocked (terminal). The legacy per-month duplicate control has been
removed.

## BASE SHA
`53ea69e725d960872f20adb9046824e9e7ab526d` (merge commit for PR #134 /
Issue #133 — "fix(public-demo): unblock July close and add April restart").
Confirmed as an ancestor of `origin/main`'s HEAD at the start of this work,
and `origin/main`'s HEAD was exactly this commit (no further main commits
existed at start time).

## HEAD SHA
`b6d4ba4e0ac598fb743f6b70636ca7863bf237fd`

## BRANCH
`claude/issue-118-single-monthly-cta-f3trqr` (pushed to `origin`)

## ROOT CAUSE
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart` rendered **two**
independent month-advance controls on the same screen, for every month:

1. **Canonical**: `PublicDemoMonthlyPrimaryCtaSection` (from
   `_monthlyPrimaryAction`), rendered once, right after
   `PublicDemoFinanceSummarySection`, with the key
   `public-demo-monthly-primary-cta`.
2. **Legacy**: a per-month `OutlinedButton` further down the same
   `ListView`, inside each `if (s.month == N) ...` block (April, May, June,
   July, August–March, and the March fiscal-year close), each hard-coded
   with an older dash-arrow label (e.g. `'4月終了→5月'`, `'3月終了→第1期終了'`).

Both controls called the **exact same** `PublicDemoAggregate` command for a
given month (`closeApril` / `closeMay` / `closeJune` / `closeJuly` /
`closeOrdinaryMonth`) — this was a pure UI presentation duplication, not two
independently-authoritative transition paths. No second month-progression
authority existed in the domain layer; the legacy button was simply a
leftover UI element from before the canonical CTA section was introduced.

This was the single root cause — no other source of duplicate month-advance
UI was found in the current `main` after re-verifying the live code (the
`known investigation results` supplied in the task matched the current
codebase exactly).

## CHANGED FILES
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — removed the
  six legacy `OutlinedButton` month-advance controls (April, May, June,
  July, August–March, March fiscal-year close). No other line in this file
  changed: descriptions, event cards, employee/applicant cards, summer
  bonus card, required-task displays, and all per-month explanatory text
  are untouched.
- 12 existing widget test files updated to drive month progression through
  the canonical CTA's own label text (e.g. `'4月を終了して5月へ'`) instead of
  the now-removed legacy label format (e.g. `'4月終了→5月'`) — a pure
  find/replace of which control the test taps, not a change to what is
  asserted or how strongly.
- `test/ui/public_demo/public_demo_01_single_month_advance_cta_test.dart`
  (new) — dedicated regression suite.
- `e2e/tests/public-demo-single-month-cta.spec.ts` (new) — Playwright
  regression spec for the 360px/390px Screen Verification Gate.

## IMPLEMENTATION SUMMARY
Deleted the six legacy `OutlinedButton` widgets (and their now-empty
wrapping guards) from `public_demo_01_placeholder_screen.dart`. The
canonical `_monthlyPrimaryAction` getter and `PublicDemoMonthlyPrimaryCtaSection`
were **not modified** — they already covered every month (4, 5, 6, 7, 8–14,
15) with the correct `isCloseBlocked` guard, so removing the legacy
duplicates required no new logic, no new state, and no change to any
`PublicDemoAggregate` command. This satisfies "presentation must not
duplicate transition logic" directly: there was never a second transition
path to remove, only a second button bound to the first one's existing
command.

## CANONICAL CTA
`PublicDemoMonthlyPrimaryCtaSection`, keyed `Key('public-demo-monthly-primary-cta')`,
rendered from `PublicDemo01PlaceholderScreen._monthlyPrimaryAction`. Key
preserved verbatim (unchanged).

## REMOVED LEGACY CTA
Six `OutlinedButton` widgets, one per month-close case, previously rendered
below the Employee Stage / Finance Summary sections inside `s.month == N`
blocks:
- `'4月終了→5月'` (April)
- `'5月終了→6月'` (May)
- `'6月終了→7月'` (June)
- `'7月終了→8月'` (July)
- `'${month}を終了して...'`-shaped label for August–March (`OutlinedButton`
  guarded by `!s.isCloseBlocked`)
- `'3月終了→第1期終了'` (`Key('public-demo-march-close')`, March fiscal-year
  close, guarded by `!s.isCloseBlocked`)

No production code or test references the removed
`Key('public-demo-march-close')` any more (verified via full-repo search
before removal).

## APRIL確認結果
- Fresh April state renders exactly one month-advance CTA
  (`public-demo-monthly-primary-cta`, label `'4月を終了して5月へ'`).
- Tapping it fires the same `closeApril` command as before (verified via
  the new widget-test suite driving the real `PublicDemo01PlaceholderScreen`
  and via the pre-existing playthrough suites, which now tap this same
  label and still pass end to end).
- 「4月からやり直す」(April restart) control is unaffected — it is a
  separate `OutlinedButton.icon` in the unrelated "テスト用操作" test-controls
  card, never touched by this change.
- Playwright (mobile-chromium) confirms, in a real browser at both 360px
  and 390px, that April HOME exposes exactly one `'4月を終了して5月へ'`
  button and no residual `'終了→'`-shaped legacy label anywhere on screen.

## JULY / ISSUE #133 REGRESSION確認
Re-verified against the current `main` (PR #134 logic unchanged by this
work):
- **Summer bonus none / ¥0**: `test/game/public_demo/public_demo_summer_bonus_payment_test.dart`
  and the new suite's July test both pass; a `PublicDemoSummerBonusPlan.none`
  decision still closes July with `summerBonusPaidAmount == 0`.
- **July close proceeding to August despite negative cash, under Issue
  #133's permitted conditions**: `public_demo_monthly_close_test.dart` /
  `public_demo_monthly_close_revenue_test.dart` (both updated by PR #134)
  pass unmodified by this change — the domain guard
  (`PublicDemoMonthlyClose.previewJuly`/`closeJuly`) was never touched.
- **Unaffordable paid bonus is rejected**: same domain tests, unmodified,
  still pass — `PublicDemoAggregate.closeJuly` still checks
  `preview.isEligible` before applying any close, exactly as PR #134 left
  it.
- **No re-introduced July deadlock**: the canonical CTA is the only control
  left, and it is still hidden only when `s.isCloseBlocked`; there is no
  new circumstance under which July can no longer close. Confirmed via
  `test/ui/public_demo/public_demo_01_single_month_advance_cta_test.dart`'s
  July tests (before and after the summer bonus decision) and via
  `e2e/tests/public-demo-july-restart.spec.ts`'s real-browser July→August
  flow (passes; see TEST RESULTS below for this sandbox's timing caveat).

## RESTART REGRESSION確認
- 「4月からやり直す」control still present and untouched (separate
  `OutlinedButton.icon`, separate card, separate command path).
- Cancel path: dialog dismissal leaves `_game`/`workflow` untouched — the
  existing `_confirmRestartFromApril`/`_restartGame` implementation was not
  modified. Verified via `public_demo_01_bankruptcy_ux_test.dart` test D
  and `public_demo_01_persistence_test.dart`'s restart-under-persistence
  coverage (both pass, unmodified logic).
- Confirm path: returns to `PublicDemoAggregate.initial()` (canonical
  initial state) and clears saved persistence via
  `PublicDemoSaveService.clear()` — unmodified, still passes.
- normal-game save is untouched: `PublicDemoSaveService` only ever touches
  the Public Demo's own storage key; nothing in this change reads or writes
  any normal-game save path, and the full `flutter test` run (which
  includes normal-game `widget_test.dart`, 1300+ cases) passed with zero
  regressions.
- Verified live in a real browser via `public-demo-july-restart.spec.ts`:
  cancel leaves the game at August unchanged, confirm returns to April with
  the canonical initial roster (佐藤 健 visible, `SkillSheetを確認` reachable).

## TEST RESULTS
- **`flutter analyze`**: `No issues found!` (0 issues), both before and
  after adding the new test file.
- **Flutter unit/widget tests, full suite** (`flutter test`): **1324/1324
  passed**, 0 failures. This includes normal-game coverage
  (`test/widget_test.dart`), all Public Demo domain/finance tests
  (`test/game/public_demo/**`), and all Public Demo widget tests
  (`test/ui/public_demo/**`), plus the new
  `public_demo_01_single_month_advance_cta_test.dart` (7/7 passing:
  April, May, June, July-before-decision, July-after-decision-and-tap,
  August, and a terminal/close-blocked case).
- **Public Demo monthly CTA tests**: covered by the new dedicated suite
  above plus the existing `public_demo_home_presentation_components_test.dart`
  (canonical CTA section, unmodified, still passes) and the 12 updated
  playthrough/consolidation/bankruptcy/persistence suites (all pass, now
  driving through the canonical label).
- **July regression tests**: `public_demo_monthly_close_test.dart`,
  `public_demo_monthly_close_revenue_test.dart`,
  `public_demo_summer_bonus_payment_test.dart`,
  `public_demo_summer_bonus_dialog_test.dart` — all pass, unmodified by
  this change (domain layer untouched).
- **Persistence/restart tests**: `public_demo_01_persistence_test.dart`,
  `public_demo_01_bankruptcy_ux_test.dart` — pass after the label-only
  update described above.
- **Flutter/Dart toolchain used**: Flutter 3.44.9 stable (matching this
  repo's own CI pin in `.github/workflows/*.yml`), installed fresh for this
  session since no SDK was pre-provisioned in this sandbox.

## CHROMIUM結果 (mobile-chromium)
Built `flutter build web --release --no-web-resources-cdn` and ran
Playwright against it with the environment's pre-installed Chromium
(`SES_E2E_CHROMIUM_PATH`, since this sandbox has no network access to
Playwright's own browser CDN for a fresh managed install — see WEBKIT
below for the same constraint documented already in this repo's own
`e2e/README.md`).

- `public-demo-fresh-start.spec.ts`: **pass**, unmodified by this change.
- `public-demo-single-month-cta.spec.ts` (new, this change): **pass**,
  4/4, reproduced twice — April and May, at both 360px and 390px, each
  asserting exactly one month-advance button and no legacy `'終了→'` label
  anywhere on screen.
- `public-demo-july-restart.spec.ts` (pre-existing, from PR #134): **pass**
  when given adequate cold-start allowance in this sandbox (confirmed with
  a one-off local timeout increase on this specific machine only, not
  committed to the repo — the file is unchanged). At its own committed
  default (`waitFor({state:'attached'})` with no explicit timeout, i.e.
  the config's 15s action timeout), it intermittently times out waiting for
  Flutter Web's first semantics attach in this specific CPU-constrained
  sandbox before any of its assertions run — never on a content mismatch.
  A full end-to-end run (43.1s total, well past the naive 15s wait) passed
  cleanly: SkillSheet → sales → interview → order → April close → May close
  → June close → July close with `none` summer bonus → August, then April
  restart cancel (state unchanged) and confirm (returns to canonical
  initial state). This is the same class of environment-specific cold-start
  flakiness this repo's own `e2e/README.md` already documents for other
  specs in slow/resource-constrained conditions ("Company Setup submission
  flaky under slow conditions"); it is not a regression this change
  introduced, and this change did not modify that spec file.

## WEBKIT結果
**Not executed.** This sandbox has no network access to Playwright's WebKit
download host (`npx playwright install webkit` → 403 from both
`cdn.playwright.dev` and `playwright.download.prss.microsoft.com`), and no
WebKit binary is pre-provisioned in this environment (only Chromium is).
This is the exact same constraint this repo's own `e2e/README.md` already
documents for prior work ("this sandbox has no network access to
Playwright's WebKit download host"). Real-WebKit verification of this
change still needs to happen in CI, which does install and run both
browsers per `.github/workflows/e2e.yml`.

## 360PX結果
`public-demo-single-month-cta.spec.ts` at 360×800: April and May HOME each
render exactly one month-advance button
(`'4月を終了して5月へ'` / `'5月を終了して6月へ'`), reached by scrolling the
same way a real player would (Flutter Web only attaches a scrolled-out
child's semantics once actually scrolled into view — confirmed directly by
comparing an un-scrolled snapshot, which omits the CTA, against a scrolled
one, which shows it — the existing `public-demo-july-restart.spec.ts`'s own
`clickScrollableButton` helper exists for the identical reason). No
`'終了→'`-shaped legacy label anywhere in the full-page accessibility
snapshot. **Pass.**

## 390PX結果
Same checks, same result, at 390×844. **Pass.**

## NORMAL-GAME IMPACT
None. `public_demo_01_placeholder_screen.dart` is Public-Demo-only; no
normal-game screen, model, or command was touched. Full `flutter test`
(1324 tests, including `test/widget_test.dart`'s normal-game coverage)
passes with zero regressions.

## PERSISTENCE IMPACT
None beyond the label-driven test updates. `PublicDemoSaveService` and
`PublicDemoAggregate.toJson`/`fromJson` were not touched; the canonical CTA
already used the exact same commands the legacy buttons called, so no save
shape, migration, or restore path changed. `public_demo_01_persistence_test.dart`
passes unmodified in substance (only the button label it taps changed).

## REMAINING RISKS
- **WebKit**: unverified in this sandbox for the reason stated above; CI
  should confirm on its next run of `.github/workflows/e2e.yml`.
- **This sandbox's cold-start timing margin**: `public-demo-july-restart.spec.ts`'s
  own (pre-existing, unmodified) 15s default wait for the first semantics
  attach is marginal on this specific constrained machine, independent of
  this change. Not fixed here as it is out of this issue's scope (no
  product or test-assertion change was needed — only wall-clock headroom on
  this one sandboxed host); CI's own machines are presumably where PR #134
  originally validated this same spec successfully.
- No other risks identified: the domain layer, finance calculations, and
  Public Demo persistence format are byte-for-byte unchanged from
  `53ea69e`.

## PR READINESS
Ready for review. Branch pushed to `origin/claude/issue-118-single-monthly-cta-f3trqr`
at `b6d4ba4e0ac598fb743f6b70636ca7863bf237fd`. No PR opened per instructions
("PRはまだ自動マージしないでください" — and no explicit request to open one
here). `flutter analyze` clean, full Flutter test suite green (1324/1324),
Chromium Playwright green on all Public Demo specs (with the one
sandbox-timing caveat above, resolved by re-running with headroom), WebKit
unverifiable in this sandbox.
