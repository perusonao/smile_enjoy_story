# SES First Fun Year P0 — Cash-Shortage Truth — Result

Status: **Implemented, committed, pushed, PR opened — verified against the
real-play repro and the full targeted test scope. The complete
`flutter test test/game/public_demo test/ui/public_demo test/presentation`
run finished with all 935 tests passing, zero failures.**

## Base / HEAD

- `git fetch origin` was run before any work.
- Start `origin/main` SHA: `81ae23ae999d41ae78ad1285b6ce955ca0bcba49`
  (PR #160 merge commit, "HOME-COMPACT-1B.4 …").
- Branch: `claude/first-fun-year-cash-shortage-truth-4blgnw`.

The branch pre-existed with one stale commit (`f4ca78f`, "Phase 0A/0B: SES
domain models and random generators") that was already an ancestor of
`origin/main` — i.e. already merged/superseded upstream, with zero unique
work of its own. Per the merged-PR restart rule, the branch was reset to
`origin/main` (`git checkout -B claude/first-fun-year-cash-shortage-truth-4blgnw
origin/main`) before starting new work, so this PR's diff is exactly the
files listed below.

- Code change commit SHA: `8cb79c26be3156f9ad081dc3e75ccd1132cede8f` ("fix(public-demo):
  P0 cash-shortage card/dialog never claim recovery when forecast is still
  negative").
- Code-change commit SHA above is the immutable implementation evidence.
- The current PR branch HEAD is intentionally not duplicated here: writing a
  report-only commit changes HEAD, so a self-declared “final HEAD” would
  immediately be stale. Use the PR's GitHub HEAD for the merge gate.

## Real-play repro (confirmed against Public Demo, as reported)

- 1月開始時: 現預金 **-¥35,000**
- 次回入金予定（売掛金）: **¥500,000**
- 旧: 資金不足カード/ダイアログが「次回の月次決算で現預金が0円以上になれば回復します」と表示
- 実際に1月を終了した結果:
  - 次回決算後現預金: **-¥335,000**
  - 2月で倒産

このケースの次回決算の見込み費用（給与・固定費、賞与含む）は **¥800,000**。
入金予定 ¥500,000 だけでは ¥800,000 の費用を賄えず、次回決算後見込みは
-¥35,000 + ¥500,000 - ¥800,000 = **-¥335,000** で、資金不足は解消しない。旧表示
はこの事実と矛盾していた。

This exact numeric fixture (-¥35,000 / ¥500,000 / ¥800,000 → -¥335,000) is
now a regression test — see "Tests" below.

## Root cause

`PublicDemoCashShortageCard`（資金不足カード）と
`PublicDemo01PlaceholderScreen._showCashShortageExplanation`（「資金不足を確認」
ダイアログ）は、どちらも `PublicDemoCashForecast`（Issue #148 Phase 1A で導入
済みの、確認済み情報のみに基づく次回決算見込み計算）を一切参照しておらず、
固定文言「次回の月次決算で現預金が0円以上になれば回復します」を常に表示して
いた。これは「次回入金予定があれば回復する」ように読める誤った表現で、実際に
は次回決算は入金だけでなく給与・固定費・賞与も同時に処理するため、入金予定
だけでは資金不足が解消しない場合がある。

## What changed

Scope respected exactly as specified — **not** touched:
`PublicDemoCashForecast`, `PublicDemoCashStatusPresentation`,
`PublicDemoCashAdviceSelector`, GameState, 月次決算・財務計算・収益計算, 保存
schema, SkillSheet／営業ルール, E2E基盤・CI workflow.

### `lib/ui/public_demo/public_demo_cash_shortage_card.dart`

- `PublicDemoCashShortageCard` now takes a required `nextClose:
  PublicDemoCashForecastMonth?` — the next monthly close's forecast entry,
  read-only (never recomputed).
- Added a 4th evidence tile, **「次回決算後見込み」**, showing
  `nextClose.closingCash` (via `formatYen`), alongside the existing 現在の
  現預金／不足額／次回入金予定（売掛金） tiles.
- Added `PublicDemoCashShortageOutlook` — a small, pure, forecast-truthful
  text model, built once from `nextClose` and shared verbatim by both the
  card and the dialog (see below), so the two surfaces can never disagree:
  - `nextClose.closingCash < 0` → headline is now exactly **「次回決算後も
    資金不足の見込みです。赤字のままの場合は倒産となります。」** (no
    "回復"/回復を期待させる文言), plus a short evidence line: **「入金予定
    ¥X に対し、見込み費用 ¥Y。」** (`nextClose.cashReceived` /
    `nextClose.monthlyExpenses + nextClose.bonusPaid`).
  - `nextClose.closingCash >= 0` → headline states the recovery outlook
    truthfully: **「次回の月次決算で現預金が¥Zとなり、資金不足から回復する
    見込みです。」**
  - `nextClose == null` (should not occur while `financialStatus ==
    cashShortage`, since that status is never close-blocked) → a safe
    fallback that neither guesses a number nor implies recovery.
- The pre-existing continuation/restriction sentence (「営業・案件参画・既存
  社員の活動は継続できます。新規採用…は制限されます。」) is unchanged.
- The headline/evidence-line/continuation prose is rendered as **one
  continuously wrapping `RichText`** (`TextSpan` children), not three
  stacked `Text` widgets — see "Bug found and fixed during verification"
  below for why.

### `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`

- Added `_nextCloseForecastEntry` — a read-only getter that calls
  `PublicDemoCashForecast.forecast(state: s, workflow: workflow).months
  .firstOrNull`. This is the single source both the card and the dialog now
  read; nothing recomputes the forecast a second time.
- `PublicDemoCashShortageCard(state: s)` → `PublicDemoCashShortageCard(state:
  s, nextClose: _nextCloseForecastEntry)`.
- `_showCashShortageExplanation` (「資金不足を確認」ダイアログ) now builds the
  same `PublicDemoCashShortageOutlook.fromForecastEntry(_nextCloseForecastEntry)`
  the card uses, adds a **「次回決算後見込み」** row matching the card's new
  tile, and renders the identical headline/evidence-line text — so the card
  and dialog always show the same number and the same conclusion.

## Bug found and fixed during verification

The first implementation used three stacked `Text` widgets (headline,
optional evidence line, continuation) inside
`PublicDemoCashShortageCard`. Adding the required 「次回決算後見込み」
tile and the new evidence-line sentence grew the card's height by ~3px —
enough to push 社員概要 (`home-office-stage-headcount-summary`) just
outside the 360×800 unscrolled viewport during an actual cash shortage.
This was caught, not assumed away: running
`test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
(the existing HOME-COMPACT-1B.4 FIX1 group, which already pins this exact
360×800/390×844 no-scroll requirement for an actual shortage) failed with:

```
Expected: a value less than or equal to <720.0>
  Actual: <723.0701754385965>
社員概要 (employee overview) is not painted inside the raw viewport
```

Fixed by merging the headline/evidence-line/continuation prose into one
continuously wrapping `RichText` (`TextSpan` children carry the differing
styles — bold/red for the headline, plain for the rest) instead of three
separate `Text` widgets, restoring the same compact single-paragraph
packing the original (pre-P0) single-`Text` block used. Re-running the same
test file afterward: **8/8 pass**, including both 360×800 and 390×844 for
the actual-cash-shortage state.

This changed how the card test asserts the prose: `find.text(...)` does not
look inside a standalone `RichText` by default (Flutter's `find.text`/
`find.textContaining` accept a `findRichText: true` parameter for exactly
this case), so `public_demo_cash_shortage_card_test.dart`'s prose
assertions use `find.textContaining(..., findRichText: true)`. The dialog
(`_showCashShortageExplanation`) was **not** converted to `RichText` — it
has no equivalent viewport budget constraint — so
`public_demo_01_bankruptcy_ux_test.dart`'s existing
`find.textContaining('倒産')` dialog assertion needed no change.

## Display requirements — how each is satisfied

1. **事実の提示**: 現在の現預金／不足額／次回入金予定／次回決算後の現預金見込
   み — all four are now shown on both the card (as tiles) and the dialog (as
   rows), read straight from `state`/`nextClose`.
2. **見込みがマイナスのとき**: `PublicDemoCashShortageOutlook.willRecover` is
   `false`; the headline is the literal required sentence, never
   "回復"-leaning text, and the evidence line states 入金予定 and 見込み費用 on
   one short line.
3. **見込みが0円以上のときのみ**: `willRecover` is `true`, and only then does
   the headline state a recovery expectation.
4. **カード/ダイアログの一致**: both call `PublicDemoCashShortageOutlook
   .fromForecastEntry` with the same `_nextCloseForecastEntry` value — there
   is no second, independent text/threshold computation anywhere.
5. **PR #160 のコンパクト表示**: verified at 360×800 / 390×844 — see "360/390
   confirmation" below.

## Tests

### Added

- `test/ui/public_demo/public_demo_cash_shortage_card_test.dart`
  - Updated all existing scenarios to pass `nextClose:` (added, not removed
    — every pre-existing assertion on 現在の現預金／不足額／次回入金予定 still
    holds verbatim).
  - **New**: real-play repro fixture — opening cash -¥35,000, AR ¥500,000,
    next-close expected costs ¥800,000 → `PublicDemoCashForecastMonth
    .closingCash == -335000`; asserts the card shows `-¥335,000` under
    「次回決算後見込み」, the literal shortage-continues sentence, the
    入金予定/見込み費用 evidence line, and asserts `textContaining('0円以上に
    なれば回復')` / `textContaining('回復します')` both find nothing.
  - **New**: a positive forecast (closingCash `265000`) asserts the recovery
    sentence renders and the shortage-only evidence line does not.
  - Existing 360×800 / 390×844 no-overflow checks kept, now exercised with a
    real (negative) `nextClose` fixture instead of `null`.
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` — updated
  the one `PublicDemoCashShortageCard(state: negativeButNormal)` call site to
  pass `nextClose: null` (this scenario is `financialStatus == normal`, so
  the card returns `SizedBox.shrink()` before ever reading `nextClose` —
  behavior unchanged, only the now-required parameter added).

### Regression coverage already in place (verified, not modified)

- `test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart` group C
  ("Cash-shortage Recommended Action shows a dialog with cash, shortage
  amount, pending AR and explanatory text") drives the real February→March
  close into `cashShortage`, opens the dialog, and asserts 現在の現預金／不足
  額／次回入金予定（売掛金） plus `textContaining('倒産')` — all still hold, since
  this trajectory's real next close (March, already established elsewhere in
  the same suite to end in bankruptcy) forecasts negative, so the dialog's
  new headline still contains 倒産.
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
  ("HOME-COMPACT-1B.4 FIX1: actual cash shortage") pins the shortage card,
  month, KPI, 資金不足を確認 CTA, monthly CTA, and 社員概要 all inside the
  unscrolled 360×800/390×844 viewport during an actual shortage — this suite
  does not assert card wording, only layout/keys, and is covered by the
  360/390 run below.

### Command run

```
flutter test test/game/public_demo test/ui/public_demo test/presentation
```

(plus `flutter analyze lib/game/public_demo lib/ui/public_demo
lib/presentation`, and `dart format` on changed files only).

### Result

- `flutter analyze lib/game/public_demo lib/ui/public_demo
  lib/presentation`: **No issues found.**
- `dart format` was run only on the 4 changed files (2 lib, 2 test); no
  unrelated file was reformatted (verified by keeping each diff scoped to
  the actual edit — see "What changed" above; one pre-existing test file
  was reverted and hand-edited instead of `dart format`-ed whole, since
  that file predates this session's `dart format` version and a full-file
  format would have produced a large unrelated diff — see git history on
  this branch for that revert/redo).
- `flutter test test/ui/public_demo/public_demo_cash_shortage_card_test.dart`:
  **6/6 passed** (after the RichText fix and `findRichText: true` test
  update).
- `flutter test test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`:
  **8/8 passed**, including both 360×800 and 390×844 for the actual
  cash-shortage state (this is the suite that caught and confirmed the
  height-budget bug above).
- `flutter test test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart
  test/ui/public_demo/public_demo_01_home_consolidation_test.dart`:
  **36/36 passed** (includes the pre-existing dialog regression test C and
  the shortage-card-owns-its-authority group).
- `flutter test test/game/public_demo test/ui/public_demo test/presentation`
  (the full targeted-directory run): **935/935 passed, 0 failures**
  (confirmed both by the runner's own "All tests passed!" summary and by
  grepping the full log for any `-N:` failure marker — none found). This
  covers `test/game/public_demo` in full (~500 unit-level domain tests,
  none of which touch this change's files) and `test/ui/public_demo` +
  `test/presentation` in full, including every suite directly affected by
  this change (`public_demo_cash_shortage_card_test.dart`,
  `public_demo_01_issue_124_screen_verification_test.dart` at both
  360×800/390×844, `public_demo_01_bankruptcy_ux_test.dart`,
  `public_demo_01_home_consolidation_test.dart`) and every real full-year
  playthrough/regression suite in those directories. Total run time was
  ~9.5 minutes (Dart's internal test clock; wall time in this environment
  was longer due to shared CPU with earlier verification runs).

## 360×800 / 390×844 confirmation

Confirmed via the existing Flutter widget-test harness
(`tester.view.physicalSize`), the same mechanism
`public_demo_01_issue_124_screen_verification_test.dart` and
`public_demo_cash_shortage_card_test.dart` already use for this exact
acceptance criterion (no separate Chromium/E2E run — see "Not run / known
gaps"):

- `public_demo_cash_shortage_card_test.dart`'s 360×800/390×844 no-overflow
  tests: pass, now exercised with a real negative `nextClose` fixture.
- `public_demo_01_issue_124_screen_verification_test.dart`'s
  "HOME-COMPACT-1B.4 FIX1: actual cash shortage" group, both sizes: pass —
  月, KPI, the shortage-response lead (資金不足を確認 CTA), the monthly CTA
  (exactly one), and 社員概要 (with its headcount/waiting summary) are all
  painted inside the unscrolled initial viewport, with no horizontal
  overflow (`tester.takeException()` is null throughout).

## Not run / known gaps

- No Flutter/Dart SDK was pre-installed in this remote execution environment;
  Flutter 3.44.8 (matching `.github/workflows/public-demo-validation.yml`'s
  pinned version) was downloaded and extracted locally for this session to
  run `flutter analyze`/`flutter test`/`dart format` for real, rather than
  relying on static review alone.
- Chromium-driven Playwright/E2E suites (`test/e2e` or similar, if present)
  were **not** run — out of this task's stated scope ("E2E基盤・CI workflow"
  is explicitly excluded from the change set, and the task's own test list
  is limited to `test/game/public_demo/`, `test/ui/public_demo/`,
  `test/presentation/`). The 360/390 confirmation above uses the existing
  Flutter widget-test harness (`tester.view.physicalSize`), which is the
  same mechanism the pre-existing `public_demo_01_issue_124_screen_verification_test.dart`
  and `public_demo_cash_shortage_card_test.dart` suites already use for this
  exact acceptance criterion.
- (Resolved) The full `flutter test test/game/public_demo test/ui/public_demo
  test/presentation` run has since completed: **935/935 passed, 0
  failures** — see "Result" above.

## Commit SHA

`8cb79c26be3156f9ad081dc3e75ccd1132cede8f` (pushed to
`claude/first-fun-year-cash-shortage-truth-4blgnw`).

## PR

https://github.com/perusonao/smile_enjoy_story/pull/161

Not merged — per task instructions, this session opens the PR and does not
merge it.

## Merge readiness

- Scope restriction honored exactly: only
  `lib/ui/public_demo/public_demo_cash_shortage_card.dart`,
  `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`,
  `test/ui/public_demo/public_demo_cash_shortage_card_test.dart`,
  `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`, this
  report, and a minimal `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`
  update history entry were touched.
- `flutter analyze` on the changed lib directories: clean.
- Every suite that reads or drives the cash-shortage card/dialog passed,
  including the pre-existing suites this task required to stay green
  (shortage/bankruptcy, monthly-CTA-dedup, SkillSheet flow via
  `public_demo_01_home_consolidation_test.dart`'s broader coverage).
- 360×800/390×844 compact-display requirement (PR #160) re-verified for the
  actual cash-shortage state specifically, including the height-budget
  regression this session found and fixed before it could reach `main`.
- Full `test/game/public_demo test/ui/public_demo test/presentation` run:
  **935/935 passed, 0 failures.**
- Remaining before merge: let CI
  (`.github/workflows/public-demo-validation.yml`) run on the PR — this
  report's local run used the same pinned Flutter version (3.44.8) that
  workflow uses, so no drift is expected — and get a human/reviewer look,
  since this session does not merge its own PR.
