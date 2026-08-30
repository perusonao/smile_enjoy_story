# PUBLIC-DEMO-E2E-1B — Final Design

Status: design only. No test code, helper code, or production code changes
ship with this document. See "Recommended PR Breakdown" for what
implements it.

## Goal

Define the smallest real-browser E2E suite that gives first-external-
playtest confidence in **Public Demo 0.1** (`#/public-demo-01`), without
re-proving what Dart/widget tests already prove and without growing into
an unbounded browser-test marathon.

"First external playtest confidence" means: a stranger opens the demo URL,
plays the first month as a normal player would, and nothing on that path
is broken in a real browser — reachability, navigation, the one blocked
employee's explanation, and save/reload. It does not mean re-verifying
game balance, RNG, or financial arithmetic — that is what the Dart suite
under `test/game/public_demo/` already owns.

## Scope

- Real-browser (Playwright) coverage of the **Public Demo 0.1** experience
  only: entry at `#/public-demo-01`, resolved by
  `resolveAppExperience()` (`lib/app/app_entry.dart`,
  `lib/app/app_experience.dart`) into `AppExperience.publicDemo01`. This is
  a distinct experience from the Founding Prologue/Beginner Mode flow
  already covered by `e2e/helpers/ses-player.ts` and
  `beginner-mode-player.ts` — those drive `GameEngine`/`PrologueEngine`;
  Public Demo 0.1 is its own root, `PublicDemoAggregate`
  (`lib/game/public_demo/public_demo_aggregate.dart`), rendered by a single
  screen, `PublicDemo01PlaceholderScreen`
  (`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`). Nothing in
  this design touches the existing Founding Prologue harness.
- One canonical fresh-start-to-first-month-close-to-reload journey.
- Suzuki's field-sales lock explanation (pending PR #115) and Sato staying
  actionable alongside her.
- Browser-observable persistence (a real page reload against real
  `localStorage`), not the codec/invariant logic itself.
- Semantic (meaning-based) finance assertions after the first month close.
- Confirming production month-end/terminal financial states are *not*
  reachable via any debug/injection path in this suite — a design
  constraint, not new coverage.
- Two browser projects: `mobile-chromium`, `mobile-webkit` (the existing
  `e2e/playwright.config.ts` projects — Pixel 7 / iPhone 14 profiles).

## Non-Goals

- **Full fiscal-year playthrough.** Public Demo 0.1 runs April through a
  16-"turn" fiscal year (`PublicDemoState`, `fiscalYearCompleted`,
  `public_demo_fiscal_year_completion_lock_test.dart`). Driving a browser
  through all of it is exactly the "12-month E2E marathon" the brief
  forbids. Months beyond the first close stay Dart-only
  (`public_demo_monthly_close_ordinary_month_test.dart`,
  `public_demo_monthly_growth_test.dart`,
  `public_demo_fiscal_year_save_test.dart`, `public_demo_monthly_loop_test.dart`).
- **Recruitment interview / July order-decision path.** In April both seed
  engineers (佐藤健, 鈴木葵) already exist via
  `publicDemoInitialAssignments` — no recruitment interview is needed to
  reach the first month close, so the canonical journey has no RNG-adjacent
  surface to cross. A recruitment interview only enters later
  (May onward), and the July order-decision UI (`'7月分を受注'` /
  `'7月：現案件継続予定'`) is even further out. Both are deliberately
  deferred past 1B: adding either now would extend the canonical journey by
  months for no first-month-confidence gain, and the task brief's "if
  realistically available" qualifier is satisfied by "it is not realistic
  within a first-month scope."
- **Bankruptcy / cash-shortage terminal states in the browser.**
  `PublicDemoFinancialStatus.isTerminal` (bankruptcy,
  `marchCashShortageFailure`) is only reachable after multiple real losing
  months. Forcing it faster would require a debug/state-injection API,
  which is explicitly forbidden. See "Terminal Coverage."
- **Re-deriving codec/storage correctness.** `PublicDemoSaveCodec`'s
  round-trip and cross-field invariant rules (`test/game/public_demo/public_demo_save_codec_test.dart`)
  and storage-key isolation (`test/game/public_demo_save_service_test.dart`)
  are already comprehensively covered at the Dart level. The browser layer
  checks *that* a reload restores what the player saw, never *why* the
  codec accepts or rejects a payload.
- **Pixel-exact or currency-formatting assertions.** See "Finance
  Coverage" / "Forbidden Stabilization Techniques."
- **A third browser device profile**, a CI cadence change, or any change
  to `playwright.config.ts`'s existing project list.

## Coverage Matrix

| Concern | Browser E2E (this design) | Dart/widget/domain (existing or unchanged) |
|---|---|---|
| Public Demo route is reachable, semantics attach | ✅ canonical journey | — |
| SkillSheet → sales-start reachable via real taps | ✅ canonical journey | `public_demo_01_playthrough_test.dart` |
| First month close happens via a real tap | ✅ canonical journey | `public_demo_monthly_close_test.dart` |
| Revenue/receivable *meaning* visible after close | ✅ semantic assertions | `public_demo_monthly_cash_flow_card_test.dart` |
| Exact cash-flow arithmetic (opening+in-out=closing) | — | `public_demo_monthly_cash_flow_test.dart` |
| Suzuki sales-lock card visible, reason/threshold/capability text | ✅ Suzuki coverage | `public_demo_01_suzuki_sales_lock_test.dart` |
| Sato unaffected by Suzuki's lock | ✅ Suzuki coverage | same file |
| Reload restores prior on-screen state | ✅ persistence coverage (browser-only) | — |
| Codec accept/reject invariants, corrupt payloads | — | `public_demo_save_codec_test.dart` |
| Storage-key isolation from normal-game saves | — | `public_demo_save_service_test.dart` |
| Save/load race timing (in-flight save, delayed save) | — | `public_demo_01_persistence_test.dart` |
| Bankruptcy / March cash-shortage terminal UX | — | `public_demo_01_bankruptcy_ux_test.dart`, `public_demo_financial_status_test.dart` |
| Multi-month growth, ordinary-month loop, fiscal-year lock | — | `public_demo_monthly_growth_test.dart`, `public_demo_monthly_loop_test.dart`, `public_demo_fiscal_year_completion_lock_test.dart` |
| Recruitment interview, July order decision | — (deferred past 1B) | existing/future Dart suites |

## Canonical Browser Journey

One spec, one seed-free pass (Public Demo 0.1 has no `?seed=` dependency —
engineers are pre-seeded, not RNG-recruited, in April), covering exactly
the brief's candidate flow, trimmed to what's real:

1. **Open** `/?e2e=1#/public-demo-01`, wait for `flt-semantics` to attach
   (same pattern as `playFoundingToFirstAssignment` in `ses-player.ts`;
   `?e2e=1` only forces the accessibility bridge, per `e2e/README.md`
   "Why no debug API" — no gameplay effect, and this design changes nothing
   about that contract).
2. **Fresh April.** Assert the demo opened on a fresh state: `'4月'`,
   `'社員ステージ'`, `'佐藤 健'` visible, no `'このプレイスルーは終了しました。'`,
   no `'倒産'`. (This whole step already exists, unmerged, as PR #111's
   `e2e/tests/public-demo-fresh-start.spec.ts` — 1B extends it, not
   duplicates it; see "Implementation Split.")
3. **SkillSheet.** Tap the button matching `'SkillSheet確認'` for Sato
   (`佐藤健`, `eng-01` — already `isReadyForFieldSales`, no lock card).
   Note this is Public Demo's own SkillSheet action, textually distinct
   from the Founding Prologue's `'SkillSheetを確認しました'` in
   `ses-player.ts` — a different screen, different engine, deliberately not
   shared.
4. **Sales start.** Assert `'営業を開始'` becomes available, tap it.
5. *(No interview/order step — see Non-Goals.)*
6. **First month close.** Tap the month-close action. Its label is
   generated, not literal: `'${publicDemoMonthLabel(s.month)}を終了して翌月へ'`
   (e.g. `'4月を終了して翌月へ'`), backed by `PublicDemoAggregate.closeApril()`.
   Match it by the stable suffix `'を終了して翌月へ'`, not the full
   interpolated string, so the assertion survives `publicDemoMonthLabel`
   wording changes.
7. **Visible revenue/receivable meaning.** Assert the monthly cash-flow
   summary (`PublicDemoMonthlyCashFlowCard`) is showing after close — see
   "Finance Coverage" for exactly what "meaning" means here.
8. **Reload.** `page.reload()` — a real browser reload, not a SPA route
   change, so `PublicDemo01PlaceholderScreen.initState()` really re-runs
   `_restoreAggregate()` against real `localStorage`.
9. **Restored state.** Assert the post-reload screen shows the same month
   and the same post-close state category the player left (not exact cash
   digits — see "Finance Coverage").

This is one spec file, one browser pass per project (2 total: chromium +
webkit) — not per-seed fan-out like `founding-first-assignment.spec.ts`;
Public Demo 0.1's April path has no RNG branch to fan out over.

## Suzuki Coverage

Verified in the same spec (or a sibling spec sharing the helper), against
the unmerged sales-lock UI (PR #115 — `public-demo-field-sales-lock-eng-02`
key, `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`):

- **Suzuki is visible**: `'鈴木 葵'` on screen.
- **Cannot begin field sales**: no enabled `'SkillSheet確認'`/sales-start
  affordance scoped to her card; the lock container
  (`Key('public-demo-field-sales-lock-eng-02')`) is present instead.
- **Reason is visible**: text containing `'まだ営業を始められません'`.
- **Current capability is visible**: text containing `'現在 52'` (her seeded
  `actualCapability`) — matched as a substring against whatever her live
  capability reads as, not hardcoded to `52` forever (see "Stable
  Assertions" — training can move this number).
- **Required threshold is visible**: text containing
  `'営業開始には実力'` and `'60'` (`PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement`).
- **Internal training presented as the next path**: the
  `public-demo-internal-training-action-eng-02` button, label containing
  `'社内研修'`, is present and enabled.
- **Sato remains actionable**: her `'SkillSheet確認'` button is still
  enabled and tapping it (already exercised by the canonical journey)
  changes nothing about Suzuki's card or the company's cash/sales capacity
  — a light cross-check, not a duplicate of the Dart test's stronger
  "unchanged fields" assertion.

The corresponding Dart widget test,
`test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart`, already
asserts the precise domain linkage (lock card ↔ `isReadyForFieldSales` ↔
`actualCapability` ↔ `fieldSalesCapabilityRequirement`) and a no-overflow
layout check at 360×800. The browser test does not re-derive that
linkage — it only confirms the same three facts (reason, capability,
threshold) render as real text in a real mobile browser and that Sato's
own action still works alongside it.

## Persistence Coverage

**Browser-level** (this design, one assertion pair inside the canonical
journey — step 8/9 above): after a first month close, a real
`page.reload()` restores the same month and the same post-close state
category. This is the one thing a Dart widget test structurally cannot
prove the same way: `public_demo_01_persistence_test.dart` uses
`_RecordingSaveService`/`_DelayedSaveService` test doubles, not a real
browser reload against real `localStorage` (`shared_preferences`'s web
backend). The browser suite is the only place that boot-time-load contract
— `initState()` → `_restoreAggregate()` → `widget.saveService.load()` on a
freshly-created `PublicDemo01PlaceholderScreen` — gets exercised
end-to-end, for real.

**Dart-level** (already exists, not duplicated):
- `test/game/public_demo/public_demo_save_codec_test.dart` — round-trip
  correctness, rejection of corrupt/normalized/cross-inconsistent
  payloads, schema-version mismatch.
- `test/game/public_demo_save_service_test.dart` — storage-key isolation
  (`ses_public_demo_01_aggregate_v1` vs. the normal-game save key), corrupt
  storage falls back to null.
- `test/ui/public_demo/public_demo_01_persistence_test.dart` — save/load
  timing races via test doubles.

Explicitly **not** re-tested in the browser: what happens on a corrupt
payload, a schema-version bump, or a save/load race. Those need
white-box control over the stored bytes that only the Dart suite can give
cheaply; reproducing them in a real browser would mean either a
production debug hook (forbidden) or hand-editing `localStorage` via
`page.evaluate()`, which tests Playwright's own storage API, not the app.

## Finance Coverage

Semantic, not literal:

- **Month close happened**: the month indicator advanced (e.g. `'4月'` →
  `'5月'`), or the close-action button's label suffix changed to the next
  month's — never assert the exact yen figure the close produced.
- **Cash changed**: read the cash figure before and after close (via
  whatever text/semantics node currently renders it) and assert it is
  *different*, not equal to a specific number. `PublicDemoState.cash`
  starts at exactly `4,000,000` (PR #113) at game start, but nothing
  downstream of one month's revenue/expense mix should be hardcoded here.
- **Receivable/revenue meaning is visible**: the monthly cash-flow card
  (`PublicDemoMonthlyCashFlowCard`) shows its `'売上'` (revenue) and
  `'売掛金（来月入金予定）'` (receivable — "due next month") rows, and — when
  revenue is nonzero — the explanatory line
  `'今月の売上は来月に入金されます'`. Assert these *labels and the
  explanatory sentence* are present, not the numbers next to them.

Exact cash-flow arithmetic (`monthOpeningCash + inflow − outflow ==
closingCash`, revenue-equals-receivable-equals-pendingRevenue) stays where
it already is, proven precisely: `public_demo_monthly_cash_flow_test.dart`,
`public_demo_monthly_close_revenue_test.dart`,
`public_demo_balance_regression_test.dart`. The browser suite would only
ever be able to re-derive those same numbers by reading the same UI it's
supposed to be black-box testing — a fragile, circular check that adds no
confidence beyond what the Dart suite already gives precisely.

## Terminal Coverage

"Terminal" here is `PublicDemoFinancialStatus.isTerminal` (bankruptcy,
`marchCashShortageFailure`) — there is no separate "terminal device/POS"
screen in this codebase; the one unrelated "端末" string
(`others_screen.dart`: `'このゲームは端末のローカルストレージに自動保存されます。'`)
just means "this device," not a screen to test.

Reaching a terminal financial state legitimately requires several real
consecutive losing months — out of scope for a first-month canonical
journey, and explicitly not to be short-circuited: **no production-only
state injection API**, and **no test-only gameplay mutation path**, will
be added to reach it faster. Per the task brief, that means terminal-state
UX (`'倒産'`, the cash-shortage card, the fiscal-year-completion lock)
stays exactly where it already is:

- `test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart`
- `test/game/public_demo/public_demo_financial_status_test.dart`
- `test/game/public_demo/public_demo_fiscal_year_completion_lock_test.dart`

1B's canonical journey does assert the *negative* — `'このプレイスルーは
終了しました。'` and `'倒産'` are absent after a normal first month close —
as a cheap regression guard, since that text is already being read on the
same snapshot for other reasons. It adds no dedicated terminal-state test.

## Chromium / WebKit Strategy

Reuse the existing two `playwright.config.ts` projects verbatim —
`mobile-chromium` (Pixel 7) and `mobile-webkit` (iPhone 14). No new
project, no new device profile.

Public Demo 0.1's canonical journey has no seed-fan-out and no long
week-by-week loop, so it does not inherit the Founding-Prologue harness's
WebKit-specific transient-empty-semantics hazards the same way — those
were found on multi-step recruitment/interview transitions, which the
canonical journey doesn't cross (see Non-Goals). It still reuses the same
defenses as a matter of consistency and cheap insurance, not because a new
WebKit-specific failure is expected:

- `readStableSemantics()`-equivalent read before every assertion (never a
  bare single `ariaSnapshot()` read).
- `waitForSemanticsChange()`-equivalent wait after every tap, keyed on the
  snapshot actually changing — never a fixed `page.waitForTimeout()` as
  the *only* wait.
- The existing `watchForErrors()` console/page-error policy
  (`e2e/helpers/artifacts.ts`) applied to every Public Demo spec, same as
  the Founding Prologue specs.

If a genuine WebKit-only flake shows up during implementation, it gets
root-caused and fixed the same way `e2e/README.md`'s "Findings" section
documents for the existing harness — never papered over with a longer
timeout or a skip (see "Forbidden Stabilization Techniques").

## Helper API

**Yes** — introduce `e2e/helpers/public-demo-player.ts`. Public Demo 0.1
is a genuinely separate engine/screen from what `ses-player.ts` and
`beginner-mode-player.ts` drive; forcing Public Demo actions through
either of those would blur two already-cleanly-separated harnesses for no
benefit. It reuses `e2e/helpers/game-state.ts`'s existing
`snapshotScreen`/`hasText`/`enabledButton` primitives and
`e2e/helpers/artifacts.ts`'s `watchForErrors` — no new low-level DOM/ARIA
parsing.

Only these actions are defined, because only these are real, existing,
production UI affordances the design above actually exercises:

```ts
openPublicDemo(page): Promise<void>
// goto('/?e2e=1#/public-demo-01') + wait for flt-semantics attached.

readPublicDemoHome(page): Promise<ScreenSnapshot>
// One stable-read snapshot of the current screen (reuses
// game-state.ts's readStableSemantics-equivalent).

openSkillSheet(page, employeeLabel = '佐藤 健'): Promise<void>
// Taps the 'SkillSheet確認' action for the given (actionable) employee.
// Never used against Suzuki — her card has no such enabled action; the
// Suzuki coverage above reads her lock card via readPublicDemoHome()
// instead of calling this.

startSales(page): Promise<void>
// Taps the '営業を開始' action.

closeMonth(page): Promise<void>
// Taps the month-close action, matched by its stable
// 'を終了して翌月へ' suffix (see Canonical Browser Journey step 6).

reloadAndRestore(page): Promise<ScreenSnapshot>
// page.reload(), wait for flt-semantics re-attach, return one stable
// snapshot of the post-restore screen.
```

Explicitly **not** added in this design, because the actions don't exist
on the canonical/Suzuki path defined above: any recruitment-interview
step, any July order-decision step, any bankruptcy/cash-shortage
trigger, any multi-month loop helper. If a later increment adds real
coverage for one of those, its own helper function gets added then — not
speculatively now.

## Stable Assertions

- Match button/card text by a **stable substring or suffix**, never a full
  interpolated string that embeds a number expected to change run-to-run
  (e.g. `'を終了して翌月へ'`, not `'4月を終了して翌月へ'` hardcoded, since a
  spec re-run after a reload or a future increment could be looking at a
  different month).
- Where a number is asserted (Suzuki's `52`, the `60` threshold), assert
  it as **today's known seed values** for the pre-seeded engineers
  (`publicDemoInitialAssignments` — these are fixed data, not RNG), with a
  comment noting they come from that fixture, not a magic constant.
- Assert **presence/absence of semantic elements** (a card, a row label, an
  explanatory sentence) over **exact rendered numbers**, except where the
  number itself is the fact under test and is deterministic (start cash =
  `4,000,000`, capability = `52`, threshold = `60` — all fixed by
  production data, not by formatting).
- Prefer the existing ARIA-tree helpers (`hasText`, `enabledButton`,
  `snapshotScreen`) over raw CSS selectors, consistent with "Why no debug
  API" in `e2e/README.md`.
- Every spec runs `watchForErrors()` and asserts an empty allowlisted error
  set, same as every existing spec.

## Forbidden Stabilization Techniques

Per the task brief, none of the following are acceptable ways to make this
suite pass, in implementation or in any future maintenance of it:

- Arbitrary `sleep`/fixed `waitForTimeout` used as the *only* wait for a
  transition (bounded, state-driven polling only, matching the existing
  harness's own pattern).
- Increasing retries or `playwright.config.ts`'s `retries`/`timeout`
  values to mask a real flake.
- `test.skip`/`test.fixme` to get CI green.
- Inflating `actionTimeout`/`navigationTimeout`/`expect.timeout` as a
  substitute for root-causing a slow or flaky interaction.
- Any production debug/state-injection API (e.g. a hidden route or launch
  param that sets `PublicDemoAggregate` directly, forces
  `financialStatus`, or unlocks Suzuki's capability).
- Any test-only gameplay mutation path (a "cheat" command reachable only
  under `?e2e=1`) beyond the existing, already-reviewed semantics-bridge
  contract (`?e2e=1` enabling accessibility only; `?seed=` is not even
  used by Public Demo 0.1, since April has no RNG branch).
- Balance changes or RNG/gameplay changes made *in service of* making a
  test pass.

A genuine flake found during implementation gets root-caused and fixed the
same way `e2e/README.md`'s "Findings" log already documents three times
over for the existing harness (transient-empty semantics, non-empty
no-action frames, Company Setup input races) — never hidden behind one of
the techniques above.

## Implementation Split

1B does not start from zero — two pending PRs already carry most of the
groundwork:

- **PR #111** (`codex/public-demo-e2e-1a-smoke`,
  `e2e/tests/public-demo-fresh-start.spec.ts`) already covers "Public Demo
  open → fresh April → SkillSheet reachable → sales-start visible." 1B's
  canonical journey is this spec **rebased and extended** with the
  month-close + reload/restore steps — not a new spec written from
  scratch.
- **PR #115** (`codex/public-demo-p0-suzuki-1a` /
  `claude/pr-114-suzuki-rebase-*`) already ships the production Suzuki
  lock UI and its Dart widget test. 1B's Suzuki browser coverage only adds
  the browser-level read of what #115 already renders — it has no reason
  to touch `lib/` itself.

Both must land (or at least be rebased to a mergeable, reviewed state) on
`main` before 1B's browser spec can assert against their UI. This ordering
constraint is the main driver of the PR-split recommendation below.

## Acceptance Criteria

- One new spec (or two small sibling specs sharing
  `public-demo-player.ts`) passes on both `mobile-chromium` and
  `mobile-webkit`, with zero unallowlisted console/page errors.
- The canonical journey (open → fresh April → SkillSheet → sales start →
  first month close → semantic finance check → reload → restored state)
  passes as one continuous real-browser run, no fixed sleeps, no retries
  beyond the suite's existing CI default (1).
- Suzuki's lock reason, current capability, threshold, and training path
  are all asserted present via real rendered text; Sato's own action is
  asserted still enabled in the same run.
- No changes to `lib/` are required by this suite beyond whatever #111 and
  #115 already ship (this design adds zero new production code).
- `e2e/helpers/public-demo-player.ts` contains only the six functions
  listed above — no unused/speculative exports.
- CI runtime for the new spec(s) stays in the tens-of-seconds-to-low-
  minutes range per project, consistent with the existing suite's budget
  (`playwright.config.ts`'s 5-minute per-test timeout is a ceiling, not a
  target).

## Recommended PR Breakdown

**1B-A / 1B-B split — not one PR.**

- **1B-A — Canonical journey + persistence.** Rebase/land PR #111's smoke
  spec, extend it with `closeMonth()`/finance-semantic-assertions/
  `reloadAndRestore()`, and introduce
  `e2e/helpers/public-demo-player.ts` with the four actions that flow
  needs (`openPublicDemo`, `readPublicDemoHome`, `openSkillSheet`,
  `startSales`, `closeMonth`, `reloadAndRestore`). Depends only on #111's
  already-in-review UI, not on #115.
- **1B-B — Suzuki coverage.** Once #115 is rebased/merged, add the Suzuki
  read-only assertions (reason/capability/threshold/training-path/Sato-
  still-actionable) reusing 1B-A's helper — no new helper functions
  needed, since Suzuki coverage only reads state 1B-A's `readPublicDemoHome`
  already exposes.

Splitting avoids blocking the canonical-journey work (which only needs
#111, already further along per STATUS) on #115's still-pending CI/merge,
and keeps each PR's review scope matched to exactly one upstream
dependency — consistent with this suite's existing pattern of small,
single-concern PRs (§ the Findings log in `e2e/README.md`, each one a
narrowly-scoped fix). A single combined PR would either stall entirely on
#115 or require reviewers to evaluate two independent UI surfaces' browser
coverage in one pass.

---
PUBLIC-DEMO-E2E-1B DESIGN COMPLETE
