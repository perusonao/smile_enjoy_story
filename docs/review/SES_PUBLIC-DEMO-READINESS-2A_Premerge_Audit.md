# SES_PUBLIC-DEMO-READINESS-2A — Public Demo 0.1 External Playtest Readiness Re-Audit (Premerge)

Audit type: audit only. No production code, tests, or workflows were changed to produce this report.

# Executive Summary

Public Demo 0.1 has clearly benefited from a sequence of targeted fixes (PLAYTEST-BLOCKER-1A, PLAYTEST-BALANCE-1B, the persistence-hardening series). Terminal-failure states, the cash-shortage UX, starting cash, and save/reload safety are all in good shape and backed by tests. PR #115, if it merges unchanged, closes the one remaining onboarding gap that was explicitly in scope for it: Suzuki Aoi's sales lock becomes self-explanatory.

However, even assuming PR #115 merges cleanly, this audit finds **one P0-severity blocker and three P1 findings that PR #115 does not touch**, because none of them are in its diff (confirmed: PR #115 only changes `public_demo_engineer_runtime.dart`, `public_demo_01_placeholder_screen.dart`'s Suzuki-lock card, and a new test file). The P0 is that the game's live GitHub Pages URL does not default to the Public Demo experience, and no player-facing documentation states the URL fragment (`#/public-demo-01`) required to reach it. This is squarely an "entry path" failure for anyone who is not handed a pre-built, fragment-included link by a person who already knows the convention.

Recommendation: **CONDITIONAL GO**, assuming PR #115 merges unchanged, contingent on the entry-path issue (FINDING-1) being resolved procedurally (a correct, documented link handed to testers) before the first external session. The other P1 findings (no onboarding/objective text, six low-content months, no restart-after-win) do not block a single playthrough but should be triaged before a wider playtest wave.

# Audit Baseline

- Audited `main` SHA: `68b235fcdd6a0e81e6546e67b701bf008546a8be` (merge commit for PR #113, "raise starting cash to 4m").
- PR #115 (`fix(public-demo): explain Suzuki sales lock (rebased)`) was treated as **pending, not merged**, throughout this audit. At the time of writing: `state: open`, `merged: false`, base SHA exactly `68b235fcdd6a0e81e6546e67b701bf008546a8be` (i.e. rebased onto the exact audited tip — no rebase-induced drift risk). CI on the PR head: `Public Demo only` = success, `Build Public Demo browser preview` = success, `validate` = in progress at time of audit.
- PR #115's full diff was read directly (3 files, +188/−1): `lib/game/public_demo/public_demo_engineer_runtime.dart` (adds `fieldSalesCapabilityRequirement = 60` constant), `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (adds a lock-explanation card gated on `!readyForFieldSales(e.id)`), and a new test file `test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart`. No finance, balance, persistence, or navigation code is touched.
- Method: automated code/test reading across `lib/game/public_demo/`, `lib/ui/public_demo/`, `lib/app/`, `test/`, `.github/workflows/`, and `README.md`, plus targeted manual verification of the highest-stakes claims (entry-path routing, restart-after-win gating) by direct file reads.
- No game balance, mechanics, or production code was modified as part of this audit.

# Confirmed Resolved Items

These were previously identified risks (per commit history / prior PLAYTEST-BLOCKER work) and are confirmed fixed and tested on current `main`, independent of PR #115:

1. **Cash-shortage dead-end UX** — the prior "scroll to find the card" affordance is gone. `PublicDemoCashShortageCard` is always visible, and an explicit dialog (`_showCashShortageExplanation`, `public_demo_01_placeholder_screen.dart:461-505`) states cash, deficit, next AR collection, and the recovery/bankruptcy rule in plain Japanese. Covered by `test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart`.
2. **Terminal states show a clear, safe outcome screen** — both bankruptcy and March failure render `_bankruptcyTerminalCard` (`public_demo_01_placeholder_screen.dart:525-584`) with a stated reason, final cash, final month, and a working `'最初からやり直す'` restart button that is failure-aware (a failed `clear()` shows a SnackBar and preserves the terminal session rather than silently resetting).
3. **No dead/no-op buttons at terminal states** — every month-close button is now guarded by `if (!s.isCloseBlocked)` (lines 2117, 2134), so a terminal playthrough never shows an active-looking button that silently does nothing.
4. **Starting cash and year-long solvency** — `PublicDemoState.aprilStart()` sets `cash: 4000000` (`public_demo_state.dart:147-156`), confirmed applied at game start with no earlier gate. This is exercised end-to-end by an existing balance-regression test (see Q8 below), which is a real simulation, not a hunch.
5. **Persistence hardening** — save/restore goes through a strict encode→decode→re-encode round-trip plus a wide "authority facts" consistency check (`public_demo_save_codec.dart`) that rejects a large class of contradictory states; any decode failure falls back safely to a fresh game, never a crash. Saves are serialized in commit order so a late-arriving stale write cannot overwrite a newer one. All backed by dedicated tests (`public_demo_save_codec_test.dart`, `public_demo_01_persistence_test.dart`).
6. **Recruitment domain-range guard** — `PublicDemoState`'s recruitment-medium range is explicitly restricted to months 4–8, with a test (`public_demo_fiscal_year_save_test.dart:60-75`) that rejects widening it, specifically to prevent players from paying for applicants nobody could ever act on after month 5's UI window closes. (Note: this guards the *domain* rule; the July recruitment card itself is still a live, spendable dead end in the UI — see FINDING-3.)
7. **Order → Interview → Assignment pipeline has a visible action at every step** except the deliberate one-month handoff after `ordered` (assignment happens automatically at next month's close) and the pre-readiness gate on `waiting`/`skillSheet`, which is Suzuki Aoi's case, addressed by PR #115 below.

# Pending Resolution via PR #115

**Assuming PR #115 merges unchanged:**

- **Q4 (Suzuki Aoi's sales lock) becomes understandable.** On current `main`, an engineer below the 60-capability field-sales threshold (Suzuki, `actualCapability: 52`) renders **nothing** where a ready engineer would show a button — no message, no number, no link to the training action that could fix it. PR #115 adds a keyed card (`public-demo-field-sales-lock-$id`) showing `'営業開始には実力60以上が必要です（現在52）。'` plus `'まだ営業を始められません。社内研修で実力を伸ばし、基準に届くと営業準備（SkillSheet確認）を始められます。'`, deriving both numbers from the same `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement` constant the gate itself uses (no risk of the copy drifting from the rule). A dedicated widget test asserts the card appears only for Suzuki (not Sato), that it doesn't move cash/capacity/other-engineer capability, and that it doesn't overflow at 360px width.
- This closes the entire evidence gap identified for Q4. It does **not** touch finance, balance, navigation, onboarding, or any of the P0/P1 items below — confirmed by reading its full diff (3 files, listed above).

# Remaining Findings

## FINDING-1 — Browser entry path does not reach the Public Demo by default, and is undocumented

- **Severity:** P0
- **Player impact:** An external tester who is not handed a pre-built link containing the exact URL fragment will not reach Public Demo 0.1 at all — they will land on the unrelated, in-development full game (`StartChoiceScreen`), or nothing playable if the fragment is malformed.
- **Evidence:**
  - `lib/app/app_entry.dart:7-13`: `resolveAppExperience` routes to `AppExperience.publicDemo01` only for fragment `public-demo-01` (after stripping a leading `/`); every other fragment, **including none**, falls through to `AppExperience.development` — the full internal game with `StartChoiceScreen` (`lib/main.dart:96-107`).
  - `.github/workflows/e2e.yml` deploys the built app to GitHub Pages on every push to `main` with `--base-href "/${{ github.event.repository.name }}/"` (line 511), i.e. a live URL of the form `https://<owner>.github.io/smile_enjoy_story/` — the bare root, no fragment.
  - `README.md` (24 lines) is unmodified Flutter boilerplate plus one section pointing at Playwright E2E setup. It contains **no hosted demo URL, no mention of GitHub Pages, and no instruction to append `#/public-demo-01`.**
  - The only place the correct path (`/public-demo-01/#/public-demo-01`) is written down is inside `.github/workflows/public-demo-preview.yml` (lines 50-55), which writes it into a `PLAY_PUBLIC_DEMO.txt` file bundled into a `actions/upload-artifact` zip — that requires a GitHub login and a manual download, is PR-preview-only (not the live production URL), and even has a mismatched base-href (`/public-demo-01/` vs. the production deploy's `/smile_enjoy_story/`).
- **Reproduction / code path:** Open `https://<owner>.github.io/smile_enjoy_story/` with no fragment → `resolveAppExperience` returns `AppExperience.development` → `_GameRoot` renders `StartChoiceScreen`, not `PublicDemo01PlaceholderScreen` (`lib/main.dart:96-107`).
- **Minimal intervention (not implemented in this audit):** Either (a) document the exact tester-facing URL (with fragment) in README and hand it directly to testers, or (b) change the default fallback in `resolveAppExperience` so the bare root serves the Public Demo during the playtest window. Either is a small, low-risk change, but this audit does not implement it per scope.

## FINDING-2 — No first-time onboarding: objective, player role, and win/lose conditions are never stated

- **Severity:** P1
- **Player impact:** A first-time player is given no explicit statement of what the game is, what role they play, or what winning/losing means. They must infer everything from a fixed navigator character's ambient, jargon-assuming dialogue.
- **Evidence:** Grepping `public_demo_01_placeholder_screen.dart` and the navigator copy (`lib/presentation/home/models/home_navigator_display.dart:44-128`) for チュートリアル/遊び方/ゲームの目的/目標/ミッション returns no matches. The default navigator line is `'今すぐ必須の操作はありません。'` / `'SESでは、案件・人員・予定を確認しながら次の対応を進めます。新しい案内が出たら、その内容を確認してください。'` — this presumes the player already knows what "SES" (IT staffing/dispatch) is, and never states the player is the company's manager or what success/failure looks like.
- **Reproduction / code path:** Load the Public Demo fresh (`PublicDemoAggregate.initial()`) — no dialog, banner, or screen precedes the April action screen.
- **Minimal intervention:** A single short intro card/dialog on first load stating role + goal + fail condition, shown once (state-gated so it doesn't repeat on reload).

## FINDING-3 — Six consecutive low/no-content months, plus a known unresolved "paid dead end" recruitment card

- **Severity:** P1
- **Player impact:** September through February render only a title (`"○月開始結果"`) and a "close month" button — no month-specific content, decision, or event for six of twelve months. Separately, the July recruitment-media card remains live and spendable even though the domain layer already documents (and tests) that no UI past month 5 can ever process an applicant sourced from it — a player can pay for it and get nothing actionable.
- **Evidence:** `public_demo_01_placeholder_screen.dart:2101-2124` — the `s.month >= 8 && s.month <= 14` block has no per-month branching except `s.month == 8` (salary/bonus recap text). `PublicDemoState`'s recruitment-medium range is restricted to months 4-8 (`public_demo_state.dart:286-294`), with `test/game/public_demo/public_demo_fiscal_year_save_test.dart:60-75` carrying the comment: *"no UI past month 5 can process a generated applicant, so a widened domain range let a player pay for a medium in September-March with no way to ever act on the result — a paid dead end (Codex P1-2)."* That comment describes the domain-range fix, not a fix to the UI card itself, which is still rendered in month 7.
- **Reproduction / code path:** Play forward past month 8 with the raise decision already made — no button other than "close month" appears until month 15.
- **Minimal intervention:** Add at least one small per-month beat (even a flavor/status card) across Sep–Feb, and either hide or clearly label the July recruitment card as non-actionable in later contexts.

## FINDING-4 — No restart/new-game action after a successful (winning) fiscal-year completion

- **Severity:** P1
- **Player impact:** A player who completes the fiscal year successfully — which the existing balance-regression test shows is the expected outcome of ordinary, non-optimized play — lands on a static `'第1期終了'` card with final cash and no further action. Unlike the two failure terminal states, there is no restart button here, and because persistence auto-restores the exact same completed state on reload, the player has no in-app way to start a new playthrough.
- **Evidence:** `public_demo_01_placeholder_screen.dart:2141-2161` (the `public-demo-fiscal-year-complete` card) contains only a title, one line of text, and final cash — no button. The restart button (`public-demo-restart-button`, `_restartGame`) is defined inside `_bankruptcyTerminalCard` and rendered only when `s.isFinanciallyTerminal` is true (line 1961); `fiscalYearCompleted` does not gate it anywhere in the file (confirmed by search across all `fiscalYearCompleted`/`isFinanciallyTerminal`/`restart` occurrences in this file).
- **Reproduction / code path:** Reach month 15 close with `financialStatus == normal` → `completeFiscalYear` sets `fiscalYearCompleted: true` (`public_demo_state.dart:598`) → UI renders the completion card with no restart affordance → reload restores the same completed state indefinitely.
- **Minimal intervention:** Add a restart button to the fiscal-year-complete card, reusing the existing `_restartGame` flow (already failure-aware for a failed `clear()`).

## FINDING-5 — "Order" is never explicitly tied in-UI to "does not equal cash"

- **Severity:** P2
- **Player impact:** Minor comprehension gap. The AR/timing concept itself is well explained (see below), but a player relying only on in-UI text would have to infer, rather than read, that placing an order (受注) doesn't itself move cash.
- **Evidence:** `PublicDemoMonthlyCashFlowCard` (`public_demo_monthly_cash_flow_card.dart:49-56`) shows `売上` and `売掛金（来月入金予定）` as separate rows with explicit text `'今月の売上は来月に入金されます'`; the cash-shortage UI shows `次回入金予定（売掛金）`. Both explain the AR/collection-timing mechanic in plain language. No string anywhere pairs "受注" with an explicit "this alone does not generate cash" statement.
- **Reproduction / code path:** N/A — this is an absence, not a bug.
- **Minimal intervention:** One additional sentence in the order-confirmation UI, if desired; genuinely optional given the AR mechanic is otherwise well explained.

## FINDING-6 — Persistence saves and their failures are silent to the player

- **Severity:** P2
- **Player impact:** No "saved" confirmation is ever shown after an action; save/load swallow exceptions and time out at 100ms. In theory, a browser refresh immediately after an action could lose that action with no indication either way.
- **Evidence:** `public_demo_save_service.dart:20-25, 33-38, 51-56` — `save()`/`load()`/`clear()` catch-and-degrade silently. The only player-visible persistence UI is the startup `'セーブデータを確認中…'` restoring overlay.
- **Reproduction / code path:** Perform an action, immediately close the tab before the async save resolves — no evidence either way of what was saved.
- **Minimal intervention:** Optional; no concrete evidence of actual data loss was found (the architecture is best-effort but well-hardened against corruption), so this is a defensive-robustness item rather than a demonstrated bug.

# External Playtest Gate

**GO / CONDITIONAL GO / NO-GO: CONDITIONAL GO** (assuming PR #115 merges unchanged).

Rationale: the core loop (employee → SkillSheet → sales → interview → order → assignment), finance timing, terminal-state safety, and persistence are all in good, tested shape, and normal play is balance-tested to complete the fiscal year with a positive cash buffer. The blocking condition is entirely about **getting testers to the right screen**: FINDING-1 must be resolved procedurally (hand testers the exact, correct, fragment-included URL, or add a redirect) before opening any external session, because without it testers may not reach Public Demo 0.1 at all. This is not a code-quality or balance concern — it is solvable without a code change if the person running the playtest personally distributes the correct link — but it must not be left to a generic "here's our GitHub Pages site" invitation.

If PR #115 does **not** merge unchanged (i.e. rebase conflicts, scope creep, or CI failure requiring rework), Q4/Suzuki reverts to a documented P1-equivalent gap and should be re-evaluated, though it would not by itself change the Gate below P0 status of FINDING-1.

# Required Before First External Playtest

1. **FINDING-1 (P0):** Confirm and hand testers the exact working URL (`.../smile_enjoy_story/#/public-demo-01` on the live Pages deploy, verified by the auditor actually loading it) — do not distribute the bare repository/Pages root. Document this URL somewhere testers/organizers can find it (even just the playtest invite message) so the next person running a session doesn't repeat the gap.
2. **PR #115:** Merge only after its `validate` CI check (in progress at time of this audit) completes successfully — do not treat "Public Demo only" and "Build Public Demo browser preview" passing alone as sufficient.
3. **FINDING-2 (P1) recommended, not blocking:** A minimal one-time intro stating player role and goal would materially reduce first-contact confusion; worth doing before a wider (not first) playtest wave if not before the very first session.

# Safe To Defer Until After Playtest

- FINDING-3 (low-content Sep–Feb months, stale July recruitment card) — real but not blocking a single playthrough; six months of "just click through" is a few seconds of real time each, not a hard stop.
- FINDING-4 (no restart-after-win) — affects only players who reach the successful ending and then want to immediately replay; does not affect completing the first playthrough itself.
- FINDING-5 (order/cash wording gap) — the AR mechanic is already explained; this is a wording nicety.
- FINDING-6 (silent persistence) — no concrete evidence of actual data loss; defensive hardening only.

---

SES_PUBLIC-DEMO-READINESS-2A COMPLETE
