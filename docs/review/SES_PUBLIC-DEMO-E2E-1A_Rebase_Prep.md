# PUBLIC-DEMO-E2E-1A Rebase Prep

Audit-only. No production, test, or Playwright config files were changed to
produce this report. PR #111 was not rebased, pushed, or otherwise modified.

**PR #111**: `test: add Public Demo fresh-start browser smoke`
**Branch**: `codex/public-demo-e2e-1a-smoke`
**Old head**: `44696ce9c842543f38c315e7cb7078d726ca3011`
**PR #111 declared base**: `817f3b634c5293da1e277b7e88c795268880b66b`
**Current main baseline**: `68b235fcdd6a0e81e6546e67b701bf008546a8be` (includes merged #112, #113)
**PR #115** (open, not yet merged): `fix(public-demo): explain Suzuki sales lock (rebased)`, head `0b073e469ccc26567c9b938413a88481fce5fba0`, base `68b235f...` (i.e. already rebased onto current main)

# Current PR #111

Single file, 45 insertions, no other changes:
`e2e/tests/public-demo-fresh-start.spec.ts`

The scenario:
1. Navigates to `/?e2e=1#/public-demo-01`, waits for `flt-semantics`.
2. Asserts (via `hasText`/`snapshotScreen`, substring match against the full
   `ariaSnapshot`): the Public Demo title, `4月`, `社員ステージ`, `佐藤 健`,
   `営業準備前`, the Recommended Action CTA `SkillSheetを確認`, and the
   *absence* of the terminal-playthrough string and `倒産`.
3. Clicks the real `SkillSheetを確認` button via `getByRole('button', { name: ..., exact: true })`.
4. Asserts `営業を開始` appears and the terminal string is still absent.
5. Asserts no uncaught page errors / crash / unallowlisted console errors.

Nothing in the file touches persistence, cash, Suzuki, retries, sleeps, or
Playwright config.

# Compatibility With Current Main

All assertions were checked against `origin/main` (`68b235f`, i.e. after
#112 and #113 merged) directly in source:

| Assertion | Source of truth on current main | Status |
|---|---|---|
| `S.E.S. Public Demo 0.1` | `public_demo_01_placeholder_screen.dart:1916` | present, unchanged |
| `4月` | `s.month == 4` / `publicDemoMonthLabel(s.month)` at April fresh start | present, unchanged |
| `社員ステージ` | `public_demo_home_presentation_components.dart:77` (section title) | present, unchanged |
| `佐藤 健` | `publicDemoInitialEngineers` fixture, `eng-01`, `public_demo_sales.dart:251` | present, unchanged |
| `営業準備前` | `PublicDemoSalesStage.waiting => '営業準備前'` (`...placeholder_screen.dart:221`) | present, unchanged |
| `SkillSheetを確認` (CTA, exact) | `HomeRecommendedActionKind.employeeSkillSheetReview.ctaLabel` in `home_recommended_action.dart:157-160`, priority row for `stage == waiting && readyForFieldSales` | present, unchanged |
| `営業を開始` (after click) | `HomeRecommendedActionKind.employeeBeginSelling.ctaLabel`, priority row for `stage == skillSheet && readyForFieldSales` | present, unchanged |
| absence of `このプレイスルーは終了しました。` / `倒産` | terminal-state markup only renders when `isFinanciallyTerminal` | correctly absent at April fresh start |

Important disambiguation caught during this audit: the codebase has **two
different SkillSheet-review labels by design** — the employee card's own
button is `SkillSheet確認` (no `を`, `...placeholder_screen.dart:1745`), while
the Navigator/Recommended Action shortcut CTA is `SkillSheetを確認` (with
`を`, `home_recommended_action.dart:159`). This is documented at
`SES_HOME-RUNTIME-2C_Recommended_Action_Result.md:191` specifically so the
two controls never collide under `find.text`/`getByRole`. PR #111's test
uses the Recommended Action CTA (`exact: true`, with `を`), which is correct
and matches production exactly — this is **not** a typo and needs no
change.

Sato Ken (`eng-01`) has `actualSkill: 78` in
`publicDemoInitialEngineerRuntimes` (`public_demo_engineer_runtime.dart`),
well above the `fieldSalesCapabilityRequirement` of 60 — he is
`readyForFieldSales` at fresh start on current main exactly as he was at
PR #111's original base. All of PR #111's assertions are still accurate on
current main. **No change to PR #111's test file is required for
compatibility with current main.**

# Expected Impact of PR #115

PR #115 (`fix(public-demo): explain Suzuki sales lock`) touches only:
- `lib/game/public_demo/public_demo_engineer_runtime.dart` (extracts the
  existing `60` threshold into a named constant, same value, same behavior)
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (adds a new
  `Container(key: 'public-demo-field-sales-lock-<id>')` explanatory block on
  an employee's card, rendered only `if (!readyForFieldSales(e.id) &&
  stage is waiting/skillSheet)`)
- a new widget test file for Suzuki

Suzuki Aoi (`eng-02`) has `actualSkill: 52` in the same fixture — below the
60 threshold — so the new lock block renders on **her** card only. Sato
(`eng-01`, 78) is unaffected: `!readyForFieldSales('eng-01')` is `false`, so
the `if` guard on his card never renders the lock block. Checked
point-by-point against PR #111's assertions:

- **Initial viewport**: no change. The lock block is additive card content
  on Suzuki's card. The Recommended Action CTA (`SkillSheetを確認`) that
  PR #111 clicks lives in the Navigator/Recommended-Action section, which
  sits structurally above the Employee Stage card list in the HOME layout
  (per `SES_HOME-UI` / `SES_HOME-RUNTIME-2C` design docs) — it is not
  affected by Suzuki's card growing taller.
- **Semantics tree**: `hasText`/`snapshotScreen` do substring matching
  against a full-body `ariaSnapshot` (`e2e/helpers/game-state.ts:122-124`),
  not exact-set comparisons, so extra text nodes from Suzuki's lock block
  cannot break any of PR #111's assertions.
- **Button discovery**: `getByRole('button', { name: 'SkillSheetを確認',
  exact: true })` resolves via the Recommended Action determination logic
  in `home_recommended_action.dart`, which PR #115 does not touch. Sato
  remains the sole priority-26 candidate; the CTA identity/label is
  unchanged.
- **Scroll behavior**: PR #111's test never scrolls; it relies on the
  Recommended Action CTA and the fixed post-click assertion both being
  reachable in the initial materialized semantics tree, same as before.
  Suzuki's card is unrelated to that reachability path.
- **`snapshotScreen` / `hasText` expectations**: no changes needed; verified
  above.

**Conclusion: PR #115 will not require any change to PR #111's test
assertions.** A rebase after #115 merges is purely mechanical (see below).

# Likely Conflicts

`git merge-tree --write-tree` was used to simulate merging PR #111's exact
old head (`44696ce9c8...`) onto:

- `origin/main` (`68b235f`, current baseline, i.e. after #112/#113): **clean
  merge, no conflicts.**
- `origin/claude/pr-114-suzuki-rebase-pr` (PR #115's current head, i.e. the
  state main will be in after #115 merges): **clean merge, no conflicts.**

This is expected: PR #111 adds exactly one new file
(`e2e/tests/public-demo-fresh-start.spec.ts`) that does not exist on main
and that no other open or recently-merged PR touches. #112, #113, and #115
all change files under `lib/` and `test/`, never `e2e/`. There is no
textual overlap, so a rebase is a pure fast-forward-style replay with no
conflict markers expected, both today and after #115 merges.

# Assertions To Keep

Every assertion currently in PR #111's spec — all of them remain accurate
and necessary:
- `S.E.S. Public Demo 0.1` (route identity)
- `4月` (April fresh start)
- `社員ステージ` (employee stage section present)
- `佐藤 健` (initial employee identity)
- `営業準備前` (Sato's initial sales stage)
- `SkillSheetを確認` (Recommended Action CTA discoverable and clickable)
- absence of `このプレイスルーは終了しました。` and `倒産` (non-terminal HOME, both before and after the click)
- `営業を開始` after the click (real workflow transition proven)
- zero uncaught page errors / no crash / no unallowlisted console errors

# Assertions To Change

None. No wording, selector, or ordering change is needed as a result of
current main or PR #115.

# Assertions Not To Add

- **Public Demo starting cash (¥4,000,000, from #113)**: do **not** assert
  it here. E2E-1A's contract is "the route opens and the first real
  workflow action is reachable," not a finance figure. The exact cash value
  is already covered by Flutter widget/domain tests
  (`test/game/public_demo/...`, `test/ui/public_demo/...`); duplicating it
  in a browser smoke would only make this spec fail on the next intentional
  balance tuning PR for a reason unrelated to E2E reachability. No
  assertion here proves a contract that isn't already proven — default answer
  stays NO per the task brief.
- **Suzuki's field-sales lock text (from #115)**: not part of the
  fresh-start's single golden path (Sato → SkillSheet → sales-start). Adding
  it would pull Suzuki-specific balance/copy into a smoke test whose whole
  purpose is being the smallest real-browser reachability check. Suzuki's
  behavior is already covered by
  `test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart` (#115) at
  the widget-test layer, which is the right layer for it.
- **Persistence/autosave assertions (from #112)**: PR #111 never needs to
  assert save/restore behavior; each Playwright test runs in its own
  isolated browser context (no `storageState` configured in
  `e2e/playwright.config.ts`, and no other spec currently visits
  `#/public-demo-01`), so `saveService.load()` returns null and the screen
  falls back to `PublicDemoAggregate.initial()` deterministically. This is
  covered further under Compatibility/Determinism below — no new assertion
  is needed to pin it here.
- **Month-close, finance, terminal, or 12-month coverage**: explicitly out
  of scope per the E2E-1A design rule (smallest browser smoke only).

# Persistence Determinism (PR #112 impact)

`PublicDemo01PlaceholderScreen.initState()` calls
`_restoreAggregate()`, which awaits `widget.saveService.load()` (browser
localStorage-backed) and only falls back to `PublicDemoAggregate.initial()`
when that returns `null` (`...placeholder_screen.dart:87-109`). This is a
real determinism vector *in principle* for a fresh-start E2E test, but it
does not threaten PR #111 in practice:

- Playwright's default browser-context isolation applies (no
  `storageState` in `playwright.config.ts`), so every test — this one
  included — starts with empty localStorage.
- `fullyParallel: false` and no other current spec touches
  `#/public-demo-01`, so there is no cross-test localStorage bleed within
  a worker either.

No change is needed for #111 to stay deterministic after #112. This is
worth re-checking only if a future PR adds a second spec that visits
`#/public-demo-01` and writes state before this one runs, or if
`storageState`/global setup is ever introduced to the Playwright config —
neither is true today.

# Safe Rebase Procedure

1. Wait for PR #115 to actually merge (do not pre-rebase against its
   still-open branch).
2. `git fetch origin main`
3. `git checkout codex/public-demo-e2e-1a-smoke`
4. `git rebase origin/main`
   - Expected: no conflicts (see Likely Conflicts above — single new file,
     no path overlap with #112/#113/#115).
5. Do **not** touch `e2e/tests/public-demo-fresh-start.spec.ts` content as
   part of the rebase — this audit found no assertion that needs to change.
6. Run the validation commands below before pushing.
7. Force-push only the rebased branch
   (`git push --force-with-lease origin codex/public-demo-e2e-1a-smoke`),
   after explicit user confirmation — this audit does not authorize that
   push.

# Exact Validation Commands

Run from repo root unless noted.

```bash
# Flutter side (should be unaffected by an e2e-only PR, but confirms the
# rebase didn't pick up anything unexpected)
flutter analyze --no-pub
flutter test --no-pub

# Build the web app the E2E suite drives
flutter build web --release --no-pub

# Playwright — run from e2e/
cd e2e
npm ci
npx playwright test tests/public-demo-fresh-start.spec.ts --project=mobile-chromium
npx playwright test tests/public-demo-fresh-start.spec.ts --project=mobile-webkit

# Full existing E2E regression, both projects, to confirm no collateral
# damage from the rebase (matches PR #111's own stated validation)
npx playwright test --project=mobile-chromium
npx playwright test --project=mobile-webkit

# Formatting/whitespace sanity used by every PR in this repo
cd ..
git diff --check
```

Expected result: identical pass profile to PR #111's own stated validation
(new scenario green on both browsers; existing mobile-chromium suite fully
green; existing mobile-webkit suite green except the pre-existing, unrelated
Guided Founding/Beginner Mode transition failures already called out in
PR #111's description — those are not caused by this spec and are not this
audit's concern).

---

## Ready-to-use rebase instruction block for a future Claude Code session

```
TASK: Rebase PR #111 (codex/public-demo-e2e-1a-smoke) onto current main,
now that PR #115 has merged.

CONTEXT:
- See docs/review/SES_PUBLIC-DEMO-E2E-1A_Rebase_Prep.md for the full audit.
  Its conclusion: PR #111's single file
  (e2e/tests/public-demo-fresh-start.spec.ts) needs ZERO assertion changes.
  No merge conflicts are expected against main or against PR #115's content
  (verified via git merge-tree simulation during the audit).

STEPS:
1. git fetch origin main
2. git checkout codex/public-demo-e2e-1a-smoke
3. git rebase origin/main
4. If a conflict appears ANYWHERE OTHER THAN
   e2e/tests/public-demo-fresh-start.spec.ts, stop and report — the audit
   found no reason for one to exist.
5. If a conflict appears in the spec file itself, re-read
   docs/review/SES_PUBLIC-DEMO-E2E-1A_Rebase_Prep.md's "Assertions To Keep"
   / "Assertions Not To Add" sections before resolving it — do not add
   cash, Suzuki, persistence, or scroll/retry/sleep logic to this file
   under any circumstance. Keep it the smallest browser smoke.
6. Run the exact validation commands from that doc's "Exact Validation
   Commands" section.
7. Only after all of them pass, push:
   git push --force-with-lease origin codex/public-demo-e2e-1a-smoke
8. Report the before/after HEAD SHAs and the validation results. Do not
   modify main. Do not modify Playwright config. Do not expand E2E-1A scope.
```

**PUBLIC-DEMO-E2E-1A REBASE PREP COMPLETE**
