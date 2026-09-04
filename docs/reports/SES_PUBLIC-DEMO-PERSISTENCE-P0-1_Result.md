# SES Public Demo Persistence P0-1 — Result Report (Issue #166)

## Audited base SHA

- `origin/main` was fetched fresh at the start of this session.
- **Audited SHA: `d68bd8a9c6d2de50b9bab16dbf8564cbb6990ff8`** — the PR #164
  merge commit, matching the SHA Issue #166 names as its baseline. Confirmed
  by re-fetching `origin/main` rather than assuming the issue's cited SHA
  was still current (it was).
- Working branch `claude/public-demo-persistence-p0-1-oz1ipm` was recreated
  from this exact `origin/main` HEAD (a stale local copy of the branch from
  an unrelated, long-superseded earlier phase of the project — no unmerged
  work — was discarded first).

## Summary

**Production Public Demo persistence and the PR #164 Development/Public
Demo routing contract are both already correct.** No production code was
changed. The PR #164 audit's earlier report of a "new browser context"
restore failure was a **test-harness methodology artifact (classification
D)**, not a production bug: a bare `browser.newContext()` with no
`storageState` is Playwright's equivalent of a *different browser profile*,
not "the same browser, tab/window closed and reopened". Reproduced with a
real, non-headless-equivalent Chromium build (`flutter build web --release`,
the same methodology the PR #164 audit used) across five real-browser
scenarios; all five behave correctly.

## Reproduction result

**Could not reproduce a production persistence failure** in any scenario
that corresponds to an actual player action (closing a tab, reloading,
quitting and reopening the same browser profile, or visiting fresh with an
existing save present). The only scenario that "loses" the save is a
Playwright `browser.newContext()` with no `storageState` transferred — which
is expected, correct storage-partition isolation, not a bug (see
**Root cause** below).

## Exact reproduction steps, browser/context/origin, storage keys, storage survival observations

Environment: Flutter 3.44.9 (matches `.github/workflows/e2e.yml`'s pinned
version), `flutter build web --release`, Chromium 140 (pre-cached
`chromium-1194` build, `mobile-chromium` Playwright project /
`devices['Pixel 7']`, headless), served locally via the existing
`e2e/scripts/static-server.js` on `http://localhost:4173` (single origin for
every scenario below — no cross-origin transition is ever involved).

All five real-browser cases below are implemented as the permanent E2E spec
`e2e/tests/public-demo-close-reopen-persistence.spec.ts` (4 committed tests)
plus one additional documentation-only case run during investigation and
not committed (see **Known gaps**). Each uses the real production UI action
`SkillSheet確認` → `内容を確認` (`_openSkillSheetReview` →
`_startSkillSheetReview` → `_commitAggregate`, exactly the mutation
`test/ui/public_demo/public_demo_01_persistence_test.dart` already exercises
at the widget-test layer) to produce a real, non-trivial save, and asserts a
UI signal that only a genuine restore can produce — the reviewed engineer's
button flips from `SkillSheet確認` (`PublicDemoSalesStage.waiting`) to
`営業開始` (`PublicDemoSalesStage.skillSheet`) — never `1年目 4月` alone,
which a *fresh* aggregate also satisfies and therefore cannot distinguish
"restored" from "silently started a new game".

Storage key observed for every case: **`flutter.ses_public_demo_01_aggregate_v1`**
in `localStorage` — the `flutter.` prefix `shared_preferences`'s legacy web
implementation (`shared_preferences` 2.5.5 → `shared_preferences_web`
2.4.3) adds automatically in front of `PublicDemoSaveService.key`. Confirmed
byte-for-byte identical across every transition below except case D
(genuinely absent, as expected).

| # | Scenario | Context/page setup | localStorage present after? | `PublicDemoSaveService.load()` restore? | Verdict |
|---|---|---|---|---|---|
| A | Close the **tab**, reopen `#/public-demo-01` in a **new page of the same `BrowserContext`** | `context.newPage()` → save → `page.close()` → `context.newPage()` → `#/public-demo-01` | Yes, byte-identical | Yes — `営業開始` shown | Matches the issue's literal "close tab, reopen" |
| B | Close the **whole browser**, reopen later, **same profile** (correctly simulated via `context.storageState()` transferred into a new `browser.newContext({storageState})`) | save in context A → `storageState = await contextA.storageState()` → `contextA.close()` → `browser.newContext({storageState})` | Yes, byte-identical | Yes — `営業開始` shown | This is what a real desktop/mobile browser gives for free across a full quit/reopen (localStorage is written to disk per-profile) |
| C | Same-tab reload (`page.reload()`) of an **active** Public Demo session | save via `#/public-demo-01` → `page.reload()` | Yes, byte-identical | Yes — `営業開始` shown | PR #164's own original fix target; re-confirmed in a real browser, not just the pure-function unit test |
| D | **Genuinely new/unrelated `BrowserContext`**, no `storageState` transferred | save in context A → `contextA.close()` → `browser.newContext()` (fresh, no storageState) → same URL | **No** — `localStorage.getItem(...)` is `null` | N/A — starts a fresh game (correct fallback, `_isRestoring` gate → `PublicDemoAggregate.initial()`) | Expected storage-partition isolation, **not a bug** — see **Root cause** |
| E | **Genuine new tab at root** (`/?e2e=1`, no hash) in the **same** `BrowserContext` that still has a real Public Demo save | save via `#/public-demo-01` → `page.close()` → `context.newPage()` → `/?e2e=1` (root, no hash) | localStorage: yes (context-partitioned); **sessionStorage `ses_public_demo_01_session_marker_v1`: no** (tab-partitioned, does not carry to a new tab) | N/A — resolves to Development, not Public Demo | PR #164 regression check: mere save presence must never hijack a genuine Development/root entry — confirmed correct in a real browser |

Case D is the one that matches the PR #164 audit's original "new browser
context" failure description. It reproduces cleanly — but as *expected*
storage isolation (real players never get a genuinely empty, unrelated
storage partition when they close and reopen their own browser; only an
automated test that constructs a brand-new, storageState-less context does
that), not as a defect in `PublicDemoSaveService` or `SharedPreferences`.

## Origins used

Exactly one origin throughout every scenario: `http://localhost:4173`
(the local static server serving `build/web`). No cross-origin or
`--base-href` subpath variation was part of this investigation (Issue #166
did not ask for that, and PR #164's routing fix is origin-agnostic — it
operates purely on `Uri.fragment`).

## Root cause

**Classification: D — test/browser-context/test-harness issue. No
production bug.**

The PR #164 audit's "新規に完全に新しいブラウザコンテキストへ...開く" repro
attempt failed to restore a real, pre-existing save not because
`SharedPreferences`/`localStorage` reading is broken in production, but
because:

1. A bare `browser.newContext()` with no `storageState` is Playwright's
   deliberate storage-partition isolation — equivalent to switching to a
   different browser profile, not to closing and reopening the same
   browser/tab. This alone fully explains "a real, valid save existed but
   the new context started fresh": the new context's `localStorage` was
   genuinely, correctly empty (case D above).
2. Separately, `package:shared_preferences`'s **legacy** `SharedPreferences`
   API (`shared_preferences-2.5.5/lib/src/shared_preferences_legacy.dart`)
   caches its entire preferences map in a **process-wide static
   `Completer`** (`_completer`/`_preferenceCache`), populated once by
   whichever `SharedPreferences.getInstance()` call in the whole app
   resolves first, and never re-read from `localStorage` again for the rest
   of that page load unless `.reload()` is explicitly called. (The
   *underlying* `shared_preferences_web` plugin itself has no such cache —
   it re-reads `window.localStorage` on every call — the caching is purely
   in the legacy wrapper on top of it.) If a prior ad-hoc audit script
   injected raw `localStorage` data via `page.evaluate()` **after**
   Flutter's own JS had already booted and made its first
   `getInstance()` call (e.g. from `GameController`'s own save load, which
   runs unconditionally and very early in `main()`), that first call would
   have cached an empty snapshot before the injected data ever existed —
   explaining the previously-reported "not a timeout, not an error, simply
   not found" symptom without implicating production code at all. This is
   consistent with, but does not require, cause (1) alone; either one on
   its own (or both together, as the prior ad-hoc script likely combined)
   fully accounts for the previously observed failure.

Neither of these describes anything a real player experiences: a real
`localStorage` write completes before the tab is closed (case A), and a
real OS-persisted browser profile has already written it to disk long
before Flutter's JS runs again on the next launch (case B) — so the legacy
cache's very first `getInstance()` call in that fresh page load already
sees the real data, with nothing racing it.

`resolveAppExperienceWithSaveFallback`'s session-marker design (PR #164) is
unrelated to any of this and was re-confirmed correct in a real browser
(cases C and E): `sessionStorage` is genuinely tab-scoped (survives a
same-tab reload, absent in a new tab) exactly as its own doc comments in
`lib/app/public_demo_session_marker_web.dart` state.

## Production bug / test-harness bug classification

**Test-harness (classification D).** No production defect was found or
reproduced. `lib/app/app_entry.dart`, `lib/main.dart`,
`lib/app/public_demo_session_marker*.dart`, and
`lib/game/persistence/public_demo_save_service.dart` are all unchanged and,
per the evidence above, already correct.

## Implementation decision

Per Issue #166's explicit instruction ("原因がtest harnessのみの場合:
productionコードは変更しないでください"):

- **No production code was modified.**
- Added one permanent E2E regression spec
  (`e2e/tests/public-demo-close-reopen-persistence.spec.ts`) that exercises
  the real close/reopen and full-restart paths with the *correct*
  Playwright methodology (same-context reuse and `storageState` transfer),
  plus the two PR #164 routing invariants, in a real browser — closing the
  gap the prior ad-hoc, never-committed audit script left (it was written,
  used, and deleted without ever landing a lasting regression test, per its
  own report).
- No `.dart` file, no save schema, and no CI workflow file was touched.

## Changed files

- `e2e/tests/public-demo-close-reopen-persistence.spec.ts` (new — 4 tests)
- `docs/reports/SES_PUBLIC-DEMO-PERSISTENCE-P0-1_Result.md` (this report)

No `lib/`, `test/`, `pubspec.yaml`/`pubspec.lock`, or `.github/workflows/`
file changed.

## Tests and exact results

Environment note: this sandbox had no pre-installed Flutter SDK; Flutter
3.44.9 (matching the CI-pinned version) was downloaded for this
investigation only and is not part of the commit.

```
flutter analyze
  → No issues found! (ran in 14.6s)

flutter test test/app/app_experience_test.dart \
  test/game/public_demo_save_service_test.dart \
  test/ui/public_demo/public_demo_01_persistence_test.dart \
  test/web/public_demo_entry_page_test.dart
  → 25/25 passed (before AND after this change — no .dart file changed)

flutter test test/ui/public_demo test/app
  → 239/239 passed (broader sanity check; see note below)
```

New/permanent E2E spec (real headless Chromium against a
`flutter build web --release` build, pinned to the sandbox's pre-cached
`chromium-1194` binary via the existing `SES_E2E_CHROMIUM_PATH` escape
hatch documented in `e2e/playwright.config.ts` — no CI workflow change
required, since `e2e-heavy.yml` already runs the full `e2e/tests/*.spec.ts`
glob):

```
npx playwright test public-demo-close-reopen-persistence.spec.ts --project=mobile-chromium
  → 4 passed (2.4m)
    ✓ a Public Demo save survives closing the tab and reopening the same origin
    ✓ a Public Demo save survives a full browser restart
    ✓ a same-tab reload resumes an active Public Demo session (PR #164 regression)
    ✓ a genuine new tab at root stays on Development despite an existing Public Demo save (PR #164 regression)
```

A fifth scenario (case D in the table above — a brand-new context with no
`storageState`, documenting the expected/non-bug isolation boundary) was
run during investigation as a throwaway, never-committed script (matching
the PR #164 audit's own precedent of deleting temporary
`zz-audit-*.spec.ts` files before finishing) and is not part of the
committed suite — see **Known gaps**.

Full `flutter test` (whole-project regression) was intentionally **not**
run, per the issue's instruction to defer it to CI/PR-final-check and avoid
spending time re-running full regression repeatedly mid-investigation.
`test/ui/public_demo test/app` (239 tests) was run once as a broader sanity
check after confirming the focused suite was stable, since no production
code changed and the issue's own required-verification list is fully
covered by the focused + new E2E suites above.

`dart format` was not needed — no `.dart` file was added or modified.

## Save schema impact

**None.** `PublicDemoSaveCodec`/`PublicDemoSaveService.key`
(`ses_public_demo_01_aggregate_v1`) and `SaveService`'s own Development key
are both unchanged. No migration, no new field, no schema version bump.

## Development/Public Demo routing impact

**None — all PR #164 invariants re-confirmed, including in a real browser
for the first time (cases C and E above):**

- A genuine Development/root entry is never hijacked into Public Demo
  merely because a Public Demo save exists (case E, real browser).
- Explicit `#/public-demo-01` is always Public Demo (`resolveAppExperience`
  unchanged; every case above enters via this exact URL and always lands on
  Public Demo).
- A same-tab Public Demo reload resumes Public Demo (case C, real browser —
  previously only unit-tested via the pure `resolveAppExperienceWithSaveFallback`
  function).
- Development and Public Demo saves' documented coexistence contract
  (`save_service_isolation_test.dart`) is untouched; this investigation
  wrote no Development save at all, so no interaction with it was possible
  to break.

## Known gaps

- The full "new, unrelated browser context with no storageState" boundary
  case (table row D) was verified during investigation but was deliberately
  **not** added to the committed E2E suite: it asserts Playwright's own
  storage-partition behavior, not anything `PublicDemoSaveService` or
  `SharedPreferences` controls, so permanently gating CI on it would test
  the test framework rather than the product. It is recorded here instead,
  so a future investigation does not repeat the PR #164 audit's mistake of
  treating it as a production symptom.
- A genuinely non-headless, human-hands-on-keyboard Chromium/Safari
  reproduction (as opposed to headless Chromium driven by Playwright) was
  **not** performed in this sandboxed session (no GUI available). All five
  real-browser cases above ran against the same production
  `flutter build web --release` artifact CI/GitHub Pages ships, through the
  same rendering/JS engine a real Chromium user has — the headless flag
  changes nothing about `localStorage`/`sessionStorage`/`SharedPreferences`
  behavior — but this is recorded as the one verification layer Issue #166
  asked to cover "where practical" that this session could not perform
  directly.
- The legacy `SharedPreferences` static-cache behavior described under
  **Root cause** point 2 is a real, general `shared_preferences` package
  characteristic (not something this codebase can or should change) worth
  keeping in mind for any *future* code that might call
  `SharedPreferences.getInstance()` before a boot-time `localStorage` write
  it depends on has actually happened — that ordering constraint already
  holds today (no such code exists) and is unaffected by this investigation.

## Commit SHA / pushed branch / PR URL

See the end of this session's chat response for the exact commit SHA, the
pushed branch (`claude/public-demo-persistence-p0-1-oz1ipm`), and the PR
URL.

## Merge readiness

**Ready to merge**, pending CI (in particular `e2e-heavy.yml`, which will
run the new spec for the first time in CI's own environment). This PR adds
test coverage only; it carries no production risk since no `lib/` file
changed. `flutter analyze` is clean and every focused/relevant test suite
passes.
