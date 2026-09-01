# SES Issue #119 Month Guard PR1 Result

## Status

Complete. All local gates green: `flutter analyze` clean, `flutter test`
1330/1330 passed, and the relevant Playwright mobile-chromium suite (8/8)
passed at 360×800 and 390×800. WebKit was not runnable in this sandbox (see
[WebKit](#webkit)) and is a required CI gate before merge.

## Base SHA

`25a2e9b6b401794090151cc86006e433c8d9a789` (origin/main, "Merge pull request
#135 from perusonao/claude/issue-118-single-monthly-cta-f3trqr"). The working
branch `claude/month-guard-pr1-rsi7p0` existed locally as a stale Phase-0
branch (446 commits behind main, no unmerged work); per the task's isolation
requirement it was reset to this exact `origin/main` HEAD before any work
began, rather than developed on top of the stale history.

PR #136 ("SkillSheet Phase A redesign") shares this same base SHA but is
**open, not merged** — main at this SHA does not include it, and this PR1
branch was created independently from it, never from PR #136's branch. No
changes here touch the file PR #136 also touches
(`lib/ui/public_demo/public_demo_01_placeholder_screen.dart` is modified by
both, but in disjoint regions: PR #136 touches only its SkillSheet bottom
sheet integration; this PR touches only the July CTA/month-close logic).

No unexpected changes affecting July/Public Demo month-close behavior were
found on main at this SHA — see [July Behavior](#july-behavior) and
[#133 Compatibility](#133-compatibility).

## Final HEAD

`ef5880091943c6a8f359e0f3657faefd42e527a4` (implementation + tests commit).
This report is added in a follow-up commit on top of it, matching this
repo's existing convention (e.g. Issue #118: implementation commits, then a
separate `docs:` result commit).

## Scope

PR1 only, per Issue #119. Added exactly one new Domain file, refactored
three call sites in the existing July UI to consult it instead of
independently re-deriving the same condition, and added the required
domain + widget + Playwright test coverage. No generic 12-month task engine,
no new success requirements (recruiting, sales, assignment, cash, or a paid
bonus choice), no speculative WARNING items, no HOME redesign, no Recovery
Loop, no Finance changes, and no persistence schema changes.

## Implementation

**New file:** `lib/game/public_demo/public_demo_month_guard.dart`

- `PublicDemoMonthGuardLevel` — currently one value, `required`.
- `PublicDemoMonthGuardItem` — `{id, level, message}`.
- `PublicDemoMonthGuard.evaluate({month, monthCloseApplicable,
  summerBonusDecisionConfirmed})` — a pure function returning
  `List<PublicDemoMonthGuardItem>`. No other parameters exist, so it
  structurally cannot inspect cash, sales, recruiting, or assignment state.

**Integration:** `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`

- Added `_monthGuardItems` (calls `PublicDemoMonthGuard.evaluate` with
  `monthCloseApplicable: !s.isCloseBlocked`) and
  `_summerBonusDecisionRequired` (whether the guard's
  `summer-bonus-decision` item is present) as the single source of truth.
- `july()` now checks `_summerBonusDecisionRequired` instead of directly
  reading `!s.summerBonusDecisionConfirmed`; behavior is identical (open the
  decision dialog when required, otherwise call
  `PublicDemoAggregate.closeJuly`).
- The July branch of `_monthlyPrimaryAction` (which builds the canonical
  CTA's model) now derives its `description` text from
  `_summerBonusDecisionRequired` instead of a separate direct read.
- The July summer-bonus card's status text and button label (which
  previously read `s.summerBonusDecisionConfirmed` twice more) now use the
  same `_summerBonusDecisionRequired` getter.
- `PublicDemoAggregate.closeJuly` itself is **untouched** — it is still
  ungated at the Domain layer; enforcement lives entirely in the UI layer,
  above it, exactly as the pre-existing `summerBonusDecisionConfirmed` check
  already did.
- The HOME "recommended action" candidate list (month 7's
  `summerBonusDecision` suggestion) was deliberately left reading
  `s.summerBonusDecisionConfirmed` directly — it is a separate HOME
  affordance system, and the task explicitly excludes a HOME redesign from
  this PR's scope.

## Month Guard Rules

Exactly one rule, as specified: July, month close otherwise applicable
(`!isCloseBlocked`), and `summerBonusDecisionConfirmed == false` →
one `REQUIRED` item `summer-bonus-decision`. Every other month, and July
once confirmed, returns no items. No other rules exist, and none should be
added without a separate issue.

## July Behavior

- Canonical CTA (`Key('public-demo-monthly-primary-cta')`) is the sole
  entry point for both actions in July: tapping it before the decision is
  acknowledged opens the existing `PublicDemoSummerBonusDialog`; tapping it
  after acknowledgement calls `PublicDemoAggregate.closeJuly`. No second
  close control was introduced.
- The CTA's own description text now truthfully reflects guard state:
  outstanding → "夏季賞与が未決定です。タップすると決定画面が開きます。";
  satisfied → "夏季賞与の決定が完了しました。月末処理へ進みます。"
- The July card's status text/button label (`'夏季賞与を決める'` /
  `'夏季賞与を変更'`) is unchanged in wording, only re-sourced from the
  guard.

## Failure Route Preservation

The guard only ever inspects `month`, `monthCloseApplicable`, and
`summerBonusDecisionConfirmed`. It has no parameters for cash, sales,
recruiting, or assignment outcomes, so it structurally cannot convert any
of the following into a blocked route, and none of the existing tests for
these routes needed to change:

- sales failure route
- no-hire route
- waiting-employee route
- no-bonus route (choosing `none` is a fully valid, mandatory-closable
  decision — the guard only cares that a decision was made, never which one)
- red/poor company routes (financial-status-driven `isCloseBlocked` already
  short-circuits the guard to "no items", matching the pre-existing CTA
  disappearing entirely when close-blocked)
- April restart (untouched; not part of the July guard at all)

## #118 Single CTA Preservation

`Key('public-demo-monthly-primary-cta')` remains present exactly once at
every month, including July before and after the decision. No second close
button was added. Verified by:

- Existing suite: `test/ui/public_demo/public_demo_01_single_month_advance_cta_test.dart`
  (all pre-existing cases still pass unmodified in assertion shape) plus a
  new case added in this PR (see [Tests](#tests)).
- New Playwright suite: `e2e/tests/public-demo-month-guard.spec.ts` asserts
  `toHaveCount(1)` on the canonical CTA both before and after the decision,
  at both 360px and 390px.

## #133 Compatibility

The full #133 route — July → choose summer bonus "none" → July closes →
August — was re-verified end-to-end at three layers without any source
changes to the #133 fixture or to `PublicDemoAggregate`/
`PublicDemoMonthlyClose`/`PublicDemoSummerBonusPayment`:

1. `test/game/public_demo/public_demo_monthly_close_revenue_test.dart`
   ("Issue #133 fixture: none closes July at -210,000...") — untouched,
   still passes (part of the 1330/1330 full-suite run).
2. `test/ui/public_demo/public_demo_summer_bonus_dialog_test.dart`
   ("Issue #133: none stays enabled at projected -210,000...") — untouched,
   still passes.
3. `test/ui/public_demo/public_demo_01_single_month_advance_cta_test.dart`
   ("July (summer bonus none confirmed): ... tapping it closes into August
   exactly once") — untouched, still passes.
4. `e2e/tests/public-demo-july-restart.spec.ts` (choosing "none" via the
   card button, then closing July via the canonical CTA, then April
   restart) — untouched, still passes against the built app with this PR's
   changes.
5. The new `e2e/tests/public-demo-month-guard.spec.ts` additionally drives
   the same "none" route strictly through the canonical CTA (not the
   card's own decision button) at both viewports, and reaches August.

## Domain Impact

Limited to one new file (`public_demo_month_guard.dart`) that is a pure,
stateless decision function with no dependency on `PublicDemoAggregate`,
`PublicDemoState`, or any other Domain type — it takes only primitives in
and returns a plain list out. No existing Domain file was modified.
`PublicDemoAggregate.closeJuly` is byte-for-byte unchanged.

## Finance Impact

None. No file under Finance-related logic
(`public_demo_salary*.dart`, `public_demo_revenue*.dart`,
`public_demo_monthly_cash_flow.dart`, `public_demo_summer_bonus_payment.dart`,
`public_demo_financial_status.dart`, `finance_engine.dart`, etc.) was
touched.

## Persistence Impact

None. No file under `lib/game/persistence/` was touched, and no field was
added to or removed from any serialized state. `summerBonusDecisionConfirmed`
already existed before this PR; the guard reads it, it does not add or
change any persisted representation.

## Tests

**New:** `test/game/public_demo/public_demo_month_guard_test.dart` (5 tests):

1. July + no bonus decision → REQUIRED `summer-bonus-decision`.
2. July + bonus decision confirmed → no required item.
3. Every non-July month (1–6, 8–15) → no summer-bonus required item, even
   with an unconfirmed decision.
4. Month close not applicable (blocked) in July with an unconfirmed
   decision → no items (mirrors the CTA disappearing when close-blocked).
5. Full boolean-matrix pass pinning that `evaluate`'s API surface has no
   parameter besides month/applicability/confirmed-decision, so it
   structurally cannot inspect or require unrelated success state.

**Extended:** `test/ui/public_demo/public_demo_01_single_month_advance_cta_test.dart`
— added one widget test: tapping the canonical CTA in July before the
decision opens `PublicDemoSummerBonusDialog` and leaves the screen's month
at 7; choosing "none" leaves the month at 7 (decision alone does not close);
a second tap of the same canonical CTA reaches August.

**New:** `e2e/tests/public-demo-month-guard.spec.ts` — Playwright coverage
at 360×800 and 390×800: exactly one canonical CTA in July; tapping it before
the decision opens the dialog; Escape-dismissing it without deciding proves
the month did not silently advance while it was open; choosing "none" then
lets the same CTA close July into August; `document.documentElement.
scrollWidth` never exceeds the viewport width at any checkpoint (no
horizontal overflow).

**Full local runs:**

- `flutter analyze`: **No issues found.**
- `flutter test` (full suite): **1330/1330 passed** (main was 1324; +6 from
  this PR's 5 domain tests + 1 widget test).
- `flutter test test/ui/public_demo/ test/game/public_demo/`: **all passed**
  (579 tests) — the full existing Public Demo domain + widget surface,
  confirming no regression outside the touched files.

## Chromium

`npx playwright test --project=mobile-chromium` against a `flutter build web
--release` build, run via a locally cached Chromium binary
(`SES_E2E_CHROMIUM_PATH`) since this sandbox has no managed Playwright
browser install:

- `tests/public-demo-month-guard.spec.ts` (new, 360px + 390px): **2/2 passed**
- `tests/public-demo-single-month-cta.spec.ts` (#118 regression, 360px +
  390px, April/May): **4/4 passed**
- `tests/public-demo-july-restart.spec.ts` (#133 route + April restart):
  **1/1 passed**
- `tests/public-demo-fresh-start.spec.ts` (baseline smoke): **1/1 passed**
- **8/8 passed total**, no uncaught page errors, no crashes.

## WebKit

Not run locally. This sandbox has only a pre-installed Chromium
(`/opt/pw-browsers`); `npx playwright install webkit` was attempted and
failed with `403 request blocked` against every WebKit download host
(`cdn.playwright.dev`, `playwright.download.prss.microsoft.com`) under this
environment's network policy — the same constraint PR #136 hit. No WebKit
result is claimed here. **This is a required CI gate before merge**, not a
silently skipped or weakened check.

## Diff Audit

`git diff --check` against the implementation commit: clean (no whitespace
errors). `git diff origin/main...HEAD` (implementation commit): 5 files
changed, 382 insertions, 9 deletions —

- `lib/game/public_demo/public_demo_month_guard.dart` (new, 53 lines)
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (+30/-9,
  three call sites refactored to consult the guard, one import added)
- `test/game/public_demo/public_demo_month_guard_test.dart` (new, 73 lines)
- `test/ui/public_demo/public_demo_01_single_month_advance_cta_test.dart`
  (+75, one new widget test + one new import)
- `e2e/tests/public-demo-month-guard.spec.ts` (new, 151 lines)

No file under Finance, persistence, HOME redesign, or Recovery-Loop scope
appears in the diff. `pubspec.lock` was incidentally touched by `flutter pub
get` while setting up this sandbox's Flutter SDK and was reverted before
committing (not part of the diff).

- Domain impact: limited to Month Guard decision authority (one new
  stateless file; no existing Domain file modified).
- Finance impact: NONE.
- Persistence schema impact: NONE.
- Normal game impact: NONE outside the July CTA's own description/button
  text, which was already conditional on the same underlying state and now
  just reads it through one shared getter instead of three separate reads.

## Remaining Risks

- WebKit is unverified locally (see above) and remains a hard CI gate.
- The HOME "recommended action" card for month 7 still reads
  `s.summerBonusDecisionConfirmed` directly rather than through the guard;
  this was a deliberate scope decision (task excludes HOME redesign) and is
  not a behavior change, but a future PR consolidating all July-decision
  read sites onto the guard could pick this up too.
- This PR1 Month Guard has exactly one rule by design; any future guard
  rule (e.g. other Domain-owned month-close acknowledgements) needs its own
  issue and should not be added here.

## Merge Readiness

Ready for CI once WebKit runs there. All local gates pass: `flutter
analyze` clean, `flutter test` 1330/1330, relevant Playwright
mobile-chromium 8/8. No Finance, persistence, or unrelated-domain changes.
Do not merge until the required WebKit CI gate has run and passed.
