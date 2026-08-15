# S.E.S. Playwright E2E

Real-UI QA/UX audit layer for **S.E.S. — Smile. Enjoy. Story.**'s Founding
Prologue (Guided Founding): drives the actual built Flutter Web app, on a
mobile device profile, the same way a first-time player would — following
whatever the UI is currently presenting as the thing to do — from a brand
new game to the first案件参画 (first project assignment).

This is **not** a replacement for the Dart headless simulations under
`/tool` (`simulate_prologue.dart` etc.) — see "Three QA layers" below.

## Three QA layers (don't mix these up)

| Layer | Tool | Checks |
|---|---|---|
| Simulation | `tool/simulate_prologue.dart` (1000s of games) | Game logic, probabilities, balance |
| **This harness** | Playwright (10s of games) | Real UI, navigation, state transitions, progress-blockers |
| Manual Play | a human | Actual UX feel |

Nothing in this harness re-implements or shortcuts any game logic
(acceptance rates, interview rolls, Fit, Morale, Company Trust, …) — every
action is a real tap on real production UI, and every outcome is whatever
`GameEngine`/`PrologueEngine` actually computed.

## Why no debug API

The harness never reads Dart `GameState` directly. Internal state is
inferred from the rendered UI (button labels, on-screen text) via Flutter
Web's accessibility/semantics tree — see `helpers/game-state.ts`. This
matches the E2E brief's instruction not to force a debug/state API into
production code just to make automation easier.

## The one production change this needed

Flutter Web renders to a bare `<canvas>` with **no DOM text at all** until
something enables the accessibility/semantics tree (normally a screen
reader user tapping the invisible "Enable accessibility" placeholder).
Headless CDP automation can't reliably trigger that placeholder click, so
`lib/main.dart` reads two harmless, opt-in launch params that a real player
never sets:

- `?e2e=1` — force-enables the semantics tree immediately (`SemanticsBinding
  .instance.ensureSemantics()`). Pure accessibility/DOM-visibility switch;
  changes no game logic.
- `?seed=12345` — threads into the existing `PrologueEngine`/`GameEngine`
  `seed` parameter (already there for `tool/simulate_prologue.dart`) so a
  Playwright run can reproduce one specific playthrough on demand.

Both default to today's exact behavior (random seed, semantics off until a
real player enables it) when absent. See `lib/main.dart` and
`lib/app/game_controller.dart` for the full diff and rationale in code
comments.

## Findings

### P0 (fixed): stale BuildContext could strand the Upper Company Interview

**Symptom.** Tapping "続ける" to leave the Upper Company Interview (either
result — pass or fail) could throw
`TypeError: Cannot read properties of null` from deep inside Flutter's own
navigation/pointer-dispatch internals and leave the player stuck on the same
result screen, unable to continue. Reproduced on every one of the first 4
seeds tried (100001–100004) before the fix, i.e. this was not a rare edge
case — it sat on the critical path of the single most important flow in the
game.

**Root cause.** `_UpperInterviewIntro` (`lib/ui/prologue/prologue_screen.dart`)
pushed `ClientInterviewScreen` with `onResultContinue: () =>
Navigator.pop(context)`, capturing `context` in a closure that fires *later*
— after the interview's one follow-up choice has already mutated
`GameState`. That mutation makes `PrologueScreen`'s own `AnimatedBuilder`
(still mounted underneath the pushed route) re-derive `stage()` and swap
`_UpperInterviewIntro`'s widget out from under its own `Element`, on the very
same frame. Re-deriving `Navigator.of(context)` from that now-stale context
inside `onResultContinue` risked resolving against a defunct element —
release/profile builds strip the `assert()` that would otherwise catch this
clearly in debug mode, so it surfaced as a raw null-dereference instead.

**Fix.** Capture the `NavigatorState` once, up front (`final navigator =
Navigator.of(context)`), and reuse that (with a `.mounted` guard) instead of
re-deriving from `context` inside the later callback — the exact pattern
`PrologueInterviewScreen`'s `_Summary._decide` already uses correctly for
the identical hazard. See the diff in `lib/ui/prologue/prologue_screen.dart`
(`_UpperInterviewIntro`). Verified fixed by re-running the same 4 seeds
end-to-end after the change — see "10-seed validation" below.

This is the one change to game UI code this effort made, and it's a
defensive-navigation fix, not a change to any probability, balance, Fit,
SelectionFlow, or other gameplay logic — see "Existing Game Impact" in the
completion report for the full accounting.

## Local setup

### Windows / macOS / Linux

```powershell
# 1. Install Flutter deps (repo root)
flutter pub get

# 2. Build the web app the harness will drive (self-contained, no CDN)
flutter build web --release --no-web-resources-cdn

# 3. Install E2E deps
cd e2e
npm install

# 4. Install Playwright's own browsers (one-time; downloads Chromium + WebKit)
npx playwright install --with-deps chromium webkit
# (On Windows, drop --with-deps — it's a Linux-only apt step; just
#  `npx playwright install chromium webkit`.)

# 5. Run the E2E suite
npm test
```

The Playwright config starts a small static file server
(`scripts/static-server.js`, zero extra dependencies) over `../build/web`
automatically — no separate terminal needed. Re-run `flutter build web
--no-web-resources-cdn` after any Dart change; the harness always tests
whatever is currently in `build/web`.

### Useful variants

```bash
npm run test:chromium      # Android/Chrome-equivalent profile only
npm run test:webkit        # iPhone/Safari-equivalent profile only
npm run test:headed        # watch it play, in a real browser window
npm run seeds:10           # the full 10-seed founding-first-assignment batch (§24)
SES_E2E_SEEDS=42,777 npx playwright test tests/founding-first-assignment.spec.ts   # your own seed list
npx playwright test --headed --debug   # Playwright's step debugger
npm run report              # open the last HTML report
```

## What gets produced

Every run writes, per test, into `e2e/test-results/<test-name>/`:

- `result.json` — scenario, seed, completed?, firstAssignmentWeek, action
  count, client-interview count, selection-failure count, stall detection,
  Primary-CTA warnings, stage-regression warnings, console/page errors,
  duration (§18).
- `action-trace.json` — every action the player took, in order, with the
  screen and Primary CTA it was reacting to (§16).
- `milestone-*.png` — named screenshots at Game Start / 営業開始 / 面談依頼 /
  客先面談 / first assignment on success (§15).
- `video.webm` — kept for every **failed** run; set `SES_E2E_VIDEO=on` to
  also keep it for passing runs (§14).
- `trace.zip` — Playwright's own trace viewer bundle, on failure/retry.

Plus `e2e/playwright-report/` (the HTML report — `npm run report` opens it)
and `e2e/test-results/playwright-report.json`.

## Reproducing a failure

Every failure's `result.json`/console log states the exact seed and device
project. Re-run just that one:

```bash
SES_E2E_SEEDS=<seed> npx playwright test tests/founding-first-assignment.spec.ts --project=<device> --headed --debug
```

Or open the app directly with the same params in any browser:
`http://localhost:4173/?e2e=1&seed=<seed>`.

## Stall/dead-end detection (§13)

The auto-player (`helpers/ses-player.ts`) fails a run when any of:

- **max actions** (100) exceeded without reaching first assignment,
- **max weeks** (12 — the same `prologueWeek <= 12` bucket
  `tool/simulate_prologue.dart` already reports as "4月3週初参画率"),
- **idle timeout** (30s) with no legal action found,
- the **same (screen, Primary CTA, button set)** observed 5 ticks in a row
  (Next Week / an action not actually changing GameState), or
- a genuine **dead-end**: no Primary CTA, no pending interview/selection/
  offer, and no "次の週へ" fallback on screen.

A screen that's legitimately just waiting ("今週やる操作はありません → 次の
週へ") is never treated as a dead-end by itself — see rule 10 in
`decideAction`.

## CI

`.github/workflows/e2e.yml` — independent from `.github/workflows/deploy.yml`
(never touched by this change). Runs on every PR into `main`
(`flutter analyze` → `flutter test` → `flutter build web` → Playwright on
both mobile profiles) and on demand via "Run workflow" (optionally with a
custom seed list for a full validation pass). Results are uploaded as the
`ses-playwright-results` artifact.

**To view results from a GitHub Actions run (incl. from a phone browser):**
GitHub → **Actions** tab → the "Playwright E2E (S.E.S.)" run → scroll to
**Artifacts** → download `ses-playwright-results`. It contains
`test-results/` (videos, screenshots, result JSON, action traces) and
`playwright-report/` (open `playwright-report/index.html` locally for the
interactive HTML report with embedded video/trace links).
