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

### Major (fixed): Company Setup submission flaky under slow conditions

**Symptom.** An independent Codex review of this harness found Company
Setup ("会社を設立する") flaky on both browsers — worse on WebKit (0/4) than
Chromium (2/2 pass, 2/2 fail across a small sample) — with the run stalling
on repeated identical submit clicks.

**Root cause, reproduced (not guessed).** Playwright's `fill()` performs a
bulk DOM value assignment plus one synthetic `input` event. Under slow/
resource-constrained conditions this can race Flutter Web's
TextInputConnection/EditableText sync: the DOM `<input>` — and even
`inputValue()` read immediately after — can end up *not* reflecting what was
requested, and even when it does, that alone never proves Flutter's own
`TextEditingController` (what `PrologueScreen`'s `_submit()` actually reads)
received it. Confirmed locally with Chromium's CPU-throttling: bare
`fill()` dropped to 2/10 success under 6x throttling; real per-character
keystrokes (`pressSequentially`) + an explicit blur (`Tab`) held 10/10 under
the identical throttling.

**Fix.** `helpers/ses-player.ts`'s `submitCompanySetup()` now: fills each
field via real keystrokes with its own confirm-and-retry loop
(`fillCompanySetupField`), Tabs off the last field to force Flutter to
finalize the pending value, submits, and waits specifically for the Company
Setup screen's own marker to disappear (`waitForCompanySetupExit`) — not
just "any semantics change". The whole sequence gets exactly **one** bounded
retry (never an unbounded loop of the same submit); a definitive failure
records a `CompanySetupDiagnostic` (visible field values, which attempt,
whether a transition was ever observed) into the action trace instead of
reporting a generic dead-end. No production code changed for this fix — it
was entirely a harness-side interaction-timing bug.

**WebKit note.** This sandbox has no network access to Playwright's WebKit
download host, so the throttled reproduction and the fix's stress test
(below) were both done on Chromium; the fix itself (real keystrokes +
explicit blur + transition-wait) isn't Chromium-specific, but WebKit's own
event timing should still be verified in CI, which does install and run
both browsers.

### Minor (fixed): console-error policy, font allowlist, and a parsing bug

- **`console.error` now fails the test.** Previously recorded but never
  asserted on; both scenario specs now `expect(errors.consoleErrors).toEqual([])`.
- **Font allowlist narrowed.** The previous single `ERR_CONNECTION_RESET|
  Failed to load font|...` OR-regex could allowlist a bare
  `ERR_CONNECTION_RESET` regardless of which host it was for. Replaced with
  three named, independently-testable conditions
  (`isKnownFontHost`/`isKnownNetworkFailureCode`/`isFontMessageWithHost` in
  `helpers/artifacts.ts`) — Chromium's bare "Failed to load resource"
  console message never includes a URL, so that specific message is only
  ever allowlisted by correlating it with a `requestfailed` page event that
  independently proves both "known font host" and "known network-level
  failure code". See `tests/artifacts.allowlist.spec.ts` for the
  browser-free unit coverage of these conditions.
- **ARIA-snapshot parsing bug.** The line parser only recognized a trailing
  `[disabled]` annotation; any *other* bracket annotation (most commonly a
  heading's `[level=N]`) made the whole line fail to match and get silently
  dropped from both `texts` and `buttons`. Found via the candidate-identity
  check below returning `null` for a screen whose heading visibly had the
  name. Fixed in `helpers/game-state.ts`'s `ARIA_LINE` regex.
- **`start-choice` no longer flagged as a Primary-CTA warning** — 【初心者
  モード】 vs 【自由モード】 is a real, legitimate choice, added to
  `MULTI_CHOICE_SCREENS`.
- **`MAX_WEEKS` off-by-one fixed** — `weekAdvances > maxWeeks` allowed a
  13th week-advance under `maxWeeks=12` before stopping; now `>=`, capping
  at exactly 12.
- **Early-failure artifacts.** Both scenario specs now wrap the play +
  artifact-writing in `try/finally`, so `result.json`/`action-trace.json`
  land even if something throws before the test body's normal end (not just
  on a clean stall).
- **Failure Recovery candidate identity.** `helpers/ses-player.ts` now
  reads the rejected and eventually-hired candidate's names straight off
  the recruitment-interview screen's own AppBar title
  (`"${name}との面接"`, `PrologueInterviewScreen`) — never `GameState` — and
  `failure-recovery.spec.ts` asserts they differ. This assertion is now
  required to actually run, not skipped: both names must be recoverable, or
  the test fails instead of silently passing on a `null`.

### Major (fixed, re-review): WebKit transient-empty semantics mistaken for a dead-end

**Symptom.** On WebKit, a real screen transition (most reproducibly around
the recruitment-interview questions/reverse-question screens) could pass
through a semantics frame with *zero* texts and *zero* buttons for a tick or
two before the next screen's semantics attached. `waitForSemanticsChange`
treated that non-empty → empty transition as "the screen changed" and
returned immediately; the next tick then read that same empty frame,
classified it as `screen="unknown"` with nothing on it, and `decideAction`
correctly (per its own rules) reported an unrecoverable dead-end — a false
failure caused entirely by reading mid-transition, not by the game actually
being stuck.

**Fix.** Two changes in `helpers/ses-player.ts`, both keyed off a new
`isEmptySnapshot()` (`helpers/game-state.ts`):
- `waitForSemanticsChange` no longer accepts a transiently empty read as a
  completed transition — it skips empty frames and keeps polling within its
  existing bounded window for the next *meaningful* (non-empty) frame.
- A new `readStableSemantics()` wraps every top-of-tick snapshot read (and
  `waitForCompanySetupExit`'s own read, which had the identical hazard): if
  the tree is empty, it polls briefly (bounded, event/state-driven — not a
  fixed sleep) for a non-empty recovery; only once that bounded window
  elapses with no recovery does it hand back the (now legitimately stable)
  empty snapshot to the caller.

This distinguishes three cases that were previously conflated into one
"unknown, no buttons, no text" bucket:
- **Transient empty** (WebKit mid-transition) — absorbed by
  `readStableSemantics`/`waitForSemanticsChange`, never reaches
  `decideAction` at all.
- **Real unknown screen** — non-empty semantics `classifyScreen` doesn't
  recognize; still reaches `decideAction` and can still legitimately dead-end
  with real button/text content in the failure message, exactly as before.
- **Stable empty** — genuinely empty even after the bounded recovery window;
  a real dead-end/failure candidate, reported the same way as before (never
  hidden behind further, unbounded retry).

**WebKit note.** As with the Company Setup fix above, this sandbox has no
network access to Playwright's WebKit download host (confirmed again for
this fix: `npx playwright install webkit` gets a policy-denied 403 from
both `cdn.playwright.dev` and `playwright.download.prss.microsoft.com`), so
this fix could not be run against real WebKit in this environment. The
transient-empty behavior itself was reported against WebKit by an
independent review, not reproduced firsthand here; the fix (treat empty as
not-yet-settled, bounded event-driven recovery, no unbounded retry) is
browser-agnostic and applies as a pure `helpers/*.ts` change — verification
against real WebKit still needs to happen in CI.

### Major (fixed, re-review): font allowlist correlation was a blind global count

**Symptom.** The bare "Failed to load resource: net::ERR_..." console
message Chromium emits carries no URL in its own text, so the previous fix
correlated it to a known font-host `requestfailed` via a single global
`pendingKnownFontNetworkFailures` counter: increment on a matching
`requestfailed`, decrement on the *next* bare console message of that shape.
An unrelated resource's own bare failure arriving in between (e.g. font
`requestfailed` → unrelated resource's bare console error → the font's own
bare console error) would consume the pending slot instead — silently
hiding the unrelated failure and reporting the font's own (genuinely
harmless) message as a real error instead.

**Investigated, not guessed.** A small standalone script against real
Chromium (`requestfailed`/`console` listeners on a page with both a
fonts.gstatic.com request and an unrelated-host request failing) found that
Playwright's `ConsoleMessage.location()` — distinct from `msg.text()` —
reliably carries the exact URL of the resource that failed, for this
message shape, even though the text never does.

**Fix.** `helpers/artifacts.ts`'s `watchForErrors()` now keys its pending
map by the exact failing URL (`pendingKnownFontFailuresByUrl: Map<string,
number>`) instead of a bare count, and only allowlists a bare console
message when its own `location().url` matches a URL that independently
proved "known font host + known network-level failure" via `requestfailed`.
An unrelated URL can never consume a different URL's slot, regardless of
event interleaving. If a message has no `location().url` at all, it is
never allowlisted (§12 safe fallback: a false negative — occasionally
flagging real font noise — is preferred over a false positive that could
hide an unrelated resource's real failure).

`tests/artifacts.watchForErrors.spec.ts` exercises this at the
`watchForErrors()` level (not just the pure helper functions already
covered in `tests/artifacts.allowlist.spec.ts`) against a minimal fake
`Page` that fires `requestfailed`/`console` events in explicit, deterministic
sequences — including the exact "font request fails, then an unrelated
resource's bare console error arrives, then the font's own bare console
error arrives" interleaving the bug depended on. Confirmed to actually catch
the regression by running the same tests against the pre-fix
`artifacts.ts`: the interleaved-order cases fail there and pass against the
fix.

### Major (fixed, second re-review): a real, non-empty no-action frame was also mistaken for a dead-end

**Symptom.** The transient-empty fix above only guarded against a fully
*empty* semantics tree. An independent WebKit run still failed 4/10 on a
10-repeat seed-100001 stress test, on a different (but structurally
identical) transient screen: right after a hire decision, `screen =
candidate-select` briefly read `buttons=[]`, `texts=["応募者が見つかりません"]`
— genuinely non-empty, so `readStableSemantics` passed it straight through,
`decideAction` correctly found no legal action on it, and the single read
was reported as an immediate dead-end. Company Setup failures and empty-
semantics failures were both confirmed at 0 across the same run, ruling out
the previous two fixes as the cause — this was a new, distinct gap.

**Fix.** A new, deliberately content-agnostic `waitForActionableOrStableDeadEnd()`
(`helpers/ses-player.ts`) runs whenever `decideAction()` finds no legal
action on a snapshot, generalizing the same "don't trust a single
mid-transition read" principle to *any* no-action snapshot, not just empty
ones. Bounded polling (`NO_ACTION_POLL_INTERVAL_MS`=150ms,
`NO_ACTION_STABILITY_WINDOW_MS`=2000ms — the same order of magnitude as the
empty-recovery window above) against three outcomes:
- a later read becomes actionable → hand that back to the caller as normal;
- the tree changes to some *other* non-actionable state → returns
  `'transitioning'` immediately (does not keep polling inside the same
  call — the main loop's `continue` re-enters fresh next tick, so a long
  chain of transitions is still bounded by the loop's own idle-timeout
  watchdog, not by nested timeouts inside this helper);
- the snapshot never changes for the entire window → `'stable-dead-end'`,
  reported exactly as before.

Deliberately never checks for `"応募者が見つかりません"` or any other specific
string — matching only "did the accessibility tree actually stop changing"
keeps this general against whatever the next transient screen turns out to
be, rather than allowlisting today's specific symptom.

`tests/ses-player.deadEndStability.spec.ts` exercises this against a real
Playwright `page` (plain HTML driven via `page.evaluate()`, not Flutter, so
the actual `ariaSnapshot()`-parsing path is exercised end to end) covering:
a transient non-empty/no-action frame resolving to actionable; a genuinely
stable non-empty/no-action dead-end; a fully-empty frame inside the window
still recovering (confirms the empty-recovery fix above isn't broken by
this one); and multiple distinct transitional frames before landing on an
actionable screen.

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
