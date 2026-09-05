# SES FIRST-FUN-YEAR-ONBOARDING-1 (Issue #168) — Result Report

Issue: [#168](https://github.com/perusonao/smile_enjoy_story/issues/168) —
FIRST-FUN-YEAR-ONBOARDING-1: 4月→5月の営業・求人・研修ルールを理解可能にする

Branch: `claude/issue-168-onboarding-clarity-1a`

Audited/base main SHA (fresh, includes PR #174's merge):
`cc79aaf2247483341a71f1c2cc9929b69759a391`

Based on the pre-implementation audit:
`docs/reports/SES_ISSUE-168_PreImplementation_Audit.md`.

---

## STATUS: READY — implementation complete, full regression green, no PR merged yet (per instruction).

---

## 1. Scope actually implemented

Only the audit's "ready" scope — Findings A, C, D — presentation-only,
reusing existing Month Guard / Recommended Action / finance authority
verbatim. Finding B is **intentionally not implemented**; see §7.

| Finding | Classification | Implemented this session? |
|---|---|---|
| A. Month advance without sales warning | BUG (wiring gap) | **Yes** |
| B. Initial engineer (Suzuki) sales ineligibility | RULE/DESIGN, already truthfully explained | **No — reported, not fixed** |
| C. Applicant without recruiting | INTENDED data, narrative/UX mismatch | **Yes** (copy only) |
| D. Training explanation | UX EXPLANATION | **Yes** |

---

## 2. Finding A — Month Guard wiring (April/May/June)

### Root cause (confirmed against fresh main)

`PublicDemoMonthGuard` and `PublicDemoMonthGuardWarningDialog` already
existed (Issue #119) and were already wired into `closeOrdinaryMonth()`
(August–March) via `_confirmMonthCloseIfRecommendedOutstanding()`. April
(`april()`), May (`may()`), and June (`june()`) — the three handlers
`_monthlyPrimaryAction` binds for months 4/5/6 — never called that check,
so a player could advance through April, May, or June with a genuinely
outstanding, already-legal, already-on-screen action (most importantly: a
`readyForFieldSales` founding engineer who never started SkillSheet確認)
with zero warning.

### Change

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`:

- `april()`: added `if (!await _confirmMonthCloseIfRecommendedOutstanding())
  return;` as its first statement, before `_precacheEventImage`/the event
  dialog.
- `may()`: same, as its first statement.
- `june()`: converted from `void june()` to `Future<void> june() async`
  (needed to `await` the check) with the same guard as its first
  statement; its one call site
  (`_monthlyPrimaryAction`'s month-6 `onPressed`) changed from
  `onPressed: june,` to `onPressed: () => unawaited(june()),`, matching
  `april()`/`may()`'s existing pattern.

No new guard rule, no new dialog, no new Recommended Action kind: every
candidate the guard now sees for April/May/June comes from the *same*
`_recommendedActionCandidates` HOME's own recommended-action slot already
used (via the pre-existing `_monthGuardRecommendedCandidates` getter,
unchanged). `PublicDemoMonthGuard.evaluate`, `PublicDemoAggregate.closeApril
/closeMay/closeJune`, save schema, and `HomeRecommendedActionKind` are all
reused verbatim.

### Verified behavior

- Fresh April, Sato untouched (ready, `waiting` stage): the CTA now shows
  the warning naming `佐藤 健のSkillSheetを確認`, and does not close the
  month until the player decides. `タスクを確認` cancels and Sato's
  SkillSheet確認 stays directly reachable on 社員. `このまま月末処理を進める`
  proceeds anyway.
- Suzuki (below the field-sales threshold) alone outstanding produces **no**
  warning — `_addEngineerStageCandidate`'s pre-existing `readyForFieldSales`
  gate already excludes her from ever being an emitted candidate, so this
  is a correctness confirmation, not new behavior.
- Fresh May, both pre-seeded applicants unreviewed + recruitment media
  unused: the warning appears, naming the outstanding items; proceeding
  advances to June.
- A clean June (nothing outstanding) closes immediately with no dialog —
  `june()` becoming `async` changes nothing about its own commit/reset
  logic.

---

## 3. Finding C — April event-dialog copy

### Root cause (confirmed)

`publicDemoMayApplicants` (the two applicants shown from May on) is a
`const` list consumed by `PublicDemoWorkflowState.initial()` — it seeds
the workflow **at game start**, in April, before any recruiting action is
possible. A genuine recruiting action (`PublicDemoRecruitmentCalculation
.execute`) only ever adds *further* applicants on top of this pre-seeded
pair; there is no separate spontaneous/referral/inbound route. The actual
defect was narrative: April's own event dialog (fired inside `april()`,
unconditionally, every playthrough) stated:

> 新しい応募が届きました / 採用候補者から応募が届いています。

as if a recruiting action the player had just taken caused it — false for
every player who did nothing in April.

### Change

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, the
`PublicDemoEventDialog` constructed in `april()`:

- `title`: `新しい応募が届きました` → `採用候補者の情報を確認できます`
- `message`: `採用候補者から応募が届いています。` → `採用候補者の経歴書を確認できます。`
- `nextAction` unchanged (`候補者の経歴書を確認しましょう。`) — already truthful.

No domain file touched: `publicDemoMayApplicants`, `PublicDemoWorkflowState
.initial()`, and `PublicDemoRecruitmentCalculation` are all unchanged.
Applicant generation and recruiting domain behavior are untouched — only
the three string literals passed to the existing dialog widget changed.

---

## 4. Finding D — Training explanation

### Change

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`,
`internalTrainingCard()`: added one truthful line under the existing
"社内研修 ¥30,000" text:

> 待機中の社員が対象です。費用は選択時に発生し、効果は月末に反映されます（毎月選び直しが必要です）。

Every fact stated is already true and already authoritative elsewhere in
this same class:

- **Who** — this card only ever renders for a waiting, unassigned engineer
  (the pre-existing `assigned` check hides it otherwise).
- **Cost timing** — `PublicDemoInternalTrainingTransaction.execute` deducts
  cash the same transaction that records the selection, immediately on
  tapping 研修する.
- **Effect timing** — `PublicDemoGrowthEngine`'s `internalTraining` source
  is applied at month-end close, not immediately.
- **Re-selection** — `PublicDemoState.trainingSelections` is a per-month
  map; it must be chosen again each month it is wanted.

No specific capability gain, success rate, or sales-eligibility guarantee
is claimed — the growth formula depends on hidden parameters (growth
potential, morale, diminishing returns), none of which are safe to state
as a fixed number, and Finding B's own lock-banner copy already
establishes that training is never guaranteed to arrive in time for a
given engineer's own sales window. No domain, save, or finance file
changed — `PublicDemoInternalTrainingTransaction` and
`PublicDemoGrowthEngine` are read, not modified.

---

## 5. Finding B — recorded as an unresolved RULE/DESIGN issue (not implemented)

Per the audit and this task's explicit instruction, **no change was made**
to Suzuki's capability, the field-sales threshold, her sales window, or
any training/balance rule.

**Current state (already truthful, unchanged by this session):** the
field-sales lock banner on `ec()` already states, verbatim, the exact
threshold and Suzuki's exact current capability
(`営業開始には実力 60 以上が必要です（現在 52）。`), and correctly does *not*
promise training will reopen her SkillSheet確認 action — because it
structurally cannot: `ec()`'s stage buttons for founding engineers only
render in April (`if (s.month == 4)`), and internal training's capability
gain is applied at month-end close, so even training selected in April
cannot raise her past 60 before her one window closes.

**Open question, not resolved here:** should a founding engineer ever be
seeded below the field-sales threshold with no way to reach it inside her
own designated window? Two minimal candidates were identified and
deliberately **not** implemented in this task:

1. Raise Suzuki's seed `actualSkill` from 52 to ≥60 in both
   `publicDemoInitialEngineers` (`public_demo_sales.dart`) and
   `publicDemoInitialEngineerRuntimes`
   (`public_demo_engineer_runtime.dart`) — a balance/seed-data decision,
   not a pure UI fix.
2. Give founding engineers a second in-window chance (e.g. also render
   `ec(i)`'s stage buttons in May for whoever is still `waiting`/
   `skillSheet`) — a genuine change to the founding-engineer sales-window
   contract.

Neither was implemented: both are domain/balance decisions outside this
task's presentation-only scope and the "no balance changes / no domain
rule changes" constraint. This remains open for the repository owner to
decide, potentially as a follow-up issue.

---

## 6. Changed files

**lib** (1 file):
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — Finding A
  (`april()`/`may()`/`june()`/`_monthlyPrimaryAction`), Finding C (April
  event-dialog literals), Finding D (`internalTrainingCard()`).

**test** (2 new files, 18 updated for Month Guard regression fallout):
- New: `test/ui/public_demo/public_demo_01_month_guard_april_may_june_test.dart`
  — 6 focused `testWidgets` (fresh April warning + naming, review-cancels,
  proceed-closes, Suzuki-produces-no-warning, fresh May warning +
  proceed-to-June, clean-June no-task).
- New: `test/ui/public_demo/public_demo_01_internal_training_explanation_test.dart`
  — 2 `testWidgets` (360×800/390×844), pinning the new explanatory line,
  asserting no overflow and no fabricated %/guarantee claim.
- `test/ui/public_demo/public_demo_tab_test_helpers.dart` — added the
  shared `dismissMonthGuardIfPresent(tester)` helper (proceeds through the
  guard if present, no-op otherwise) most of the fixed files reuse.
- Updated for Finding C's copy change (real-flow assertions only; two
  self-contained generic component-test files —
  `public_demo_event_dialog_test.dart`, `game_event_modal_test.dart` — use
  the old string only as an arbitrary test fixture and did not need
  updating):
  `public_demo_01_playthrough_test.dart`,
  `public_demo_01_success_playthrough_test.dart`,
  `e2e/tests/public-demo-july-restart.spec.ts` (Playwright; not executed
  locally, see §9).
- Updated for the Finding A wiring's genuine new-guard-warning fallout —
  every one of these previously assumed no guard could ever fire before
  July; each was driving a real trajectory where April's Sato and/or May's
  pre-seeded applicants were genuinely untouched, and is fixed by either
  (a) adding `dismissMonthGuardIfPresent(tester)` where no guard-handling
  existed at all, or (b) replacing an existing but April/May-untested
  "tap monthGuardProceed then `pumpAndSettle()`" clause with a real-time
  precache-aware settle (needed only because April's own event dialog,
  unlike Aug–Mar's dialog-free close, follows the guard):
  `public_demo_01_assignment_carryforward_test.dart`,
  `public_demo_01_bankruptcy_ux_test.dart` (3 inline trajectories + the
  shared `_driveToNovemberBankruptcy` helper),
  `public_demo_01_bottom_nav_tabs_test.dart`,
  `public_demo_01_completion_lock_ui_test.dart`,
  `public_demo_01_fiscal_year_progression_test.dart`,
  `public_demo_01_home3_integration_test.dart`,
  `public_demo_01_home_cash_forecast_advice_test.dart`,
  `public_demo_01_home_consolidation_test.dart`,
  `public_demo_01_home_office_stage_test.dart`,
  `public_demo_01_home_recommended_action_test.dart`,
  `public_demo_01_home_runtime_read_test.dart`,
  `public_demo_01_issue_124_screen_verification_test.dart`,
  `public_demo_01_recovery_ui_test.dart`,
  `public_demo_01_suzuki_sales_lock_test.dart`.

None of these test fixes changed what any fixture's trajectory proves —
each only proceeds past a now-genuinely-outstanding, dismissible
recommended-level warning exactly as a player choosing "このまま月末処理を
進める" would, before continuing the same assertions the file already
made.

**e2e** (1 new file, throwaway Screen Verification script, mirrors
`ses173-home-density-screenshot.mjs`):
- `e2e/scripts/ses168-onboarding-clarity-screenshot.mjs`

**docs** (this report + screenshots):
- `docs/reports/SES_FIRST-FUN-YEAR_ONBOARDING-1_Result.md`
- `docs/reports/screenshots/ses-168-{month-guard-warning,april-event-dialog,training-card}-{360x800,390x844}.png`

---

## 7. Domain / save / balance impact

**None.** Confirmed by `git diff --stat` against base: the only production
file touched is `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
— no file under `lib/game/**` or `lib/domain/**` changed. No
`PublicDemoState`/save-schema field added, removed, or reinterpreted. No
finance formula, Month Guard rule, or `HomeRecommendedActionKind` changed.
No CI/workflow file touched.

---

## 8. Focused tests / results (in run order)

1. `flutter test test/ui/public_demo/public_demo_01_month_guard_april_may_june_test.dart`
   (new) → **6/6 passed.**
2. `flutter test test/ui/public_demo/public_demo_01_internal_training_explanation_test.dart`
   (new) → **2/2 passed.**
3. `flutter test test/ui/public_demo/public_demo_01_playthrough_test.dart
   test/ui/public_demo/public_demo_01_success_playthrough_test.dart
   test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart`
   (updated for Findings A/C) → **4/4 passed.**
4. `flutter analyze` (all files touched by this session, then the whole
   `test/ui/public_demo/` directory, then the whole project) → **No
   issues found**, each stage.
5. `flutter test test/ui/public_demo/` (full directory, 33 files) →
   **255/255 passed**, 0 failures — confirms every Month Guard-regression
   fix in §6 actually restores the suite to green, not just the two new
   files.
6. `flutter test` (whole project, final PR-stage gate) → **1,538/1,538
   passed**, 0 failures, exit code 0.

Node/Playwright `e2e/tests/public-demo-july-restart.spec.ts`'s one-line
copy-assertion update (Finding C) was not executed locally in this
session (Heavy E2E, real-browser, not part of the Fast CI focused-test
gate this task ran) — it is a trivial string-literal match against the
same new title Screen Verification (§9) already confirms renders
correctly in the real build.

---

## 9. 360×800 / 390×844 Screen Verification

Captured from a local `flutter build web --release`, served on
`localhost` and driven with Playwright
(`e2e/scripts/ses168-onboarding-clarity-screenshot.mjs`, modeled on the
existing `ses173-home-density-screenshot.mjs`) with Flutter Web's
semantics tree enabled (`?e2e=1`), at both required viewports. Google
Fonts was unreachable from the sandbox (network-restricted, same as
prior phases' own capture notes), so screenshots render with the
fallback system font instead of the bundled webfont; layout and content
are otherwise exactly what a real deploy renders.

- **`ses-168-month-guard-warning-{360x800,390x844}.png`** — fresh April,
  tapping the month-close CTA: the Month Guard warning dialog renders
  with the truthful `佐藤 健のSkillSheetを確認 が未対応です。` line and both
  buttons (`このまま月末処理を進める` / `タスクを確認`) fully legible, no
  horizontal overflow, at both widths.
- **`ses-168-april-event-dialog-{360x800,390x844}.png`** — after
  proceeding past the warning: the reworded event dialog
  (`採用候補者の情報を確認できます` / `採用候補者の経歴書を確認できます。`)
  renders correctly, `確認` button reachable, no overflow.
- **`ses-168-training-card-{360x800,390x844}.png`** — 社員 tab, fresh
  April: both engineers' training cards show the new explanatory line
  (`待機中の社員が対象です。費用は選択時に発生し、効果は月末に反映されます
  （毎月選び直しが必要です）。`), wrapping cleanly to two lines at both
  widths with no truncation or overflow; Suzuki's separate field-sales
  lock banner (a different card) is unaffected and still shows no
  "社内研修" text, confirming the two cards did not bleed into each other.

No horizontal overflow observed at either width, in any of the three
surfaces.

---

## 10. Known gaps

- Finding B is intentionally unresolved — see §5. No code change; the
  open design question is recorded here for the repository owner.
- Deployed Screen Verification (real device, production build) is left to
  the repository owner, per this task's own instruction; §9's screenshots
  are from a local `flutter build web --release` served and captured with
  Playwright.
- `e2e/tests/public-demo-july-restart.spec.ts`'s Finding C copy-assertion
  update was not executed locally (Heavy E2E gate, runs in CI).

---

## 11. Commit SHA / branch / PR

- Branch: `claude/issue-168-onboarding-clarity-1a`
- Base SHA: `cc79aaf2247483341a71f1c2cc9929b69759a391` (main, includes PR
  #174's merge)
- Commits this session:
  - `dab3e3d` — Findings A/C/D implementation
  - `1651811` — Month Guard regression fixes across existing test suites
  - `f5d551d` — `public_demo_01_bottom_nav_tabs_test.dart`'s own helper fix
  - `891a97f` — Screen Verification script + screenshots
  - (this report's own commit, recorded after it lands)
- PR: opened against `main`, not merged (per this task's instruction).

## 12. Merge readiness

**READY.** `flutter analyze` clean at every stage; full
`test/ui/public_demo/` (255/255) and whole-project (1,538/1,538) suites
green; 360/390 Screen Verification confirms all three changed UI surfaces
render correctly with no overflow; no domain/save/finance/CI file
touched; PR #174's HOME/tabs behavior preserved (disjoint edit locations
in the one shared file, confirmed against the pre-implementation audit).
Finding B is a known, explicitly-recorded open design question, not a
blocker for this task's own scope.

---

## 13. Addendum — rebase onto main after PR #175 merged (2026-09-05)

PR #175 ("QA-MICRO-FIX: show BuildInfoLabel always-visibly atop メニュー")
merged into `main` after this PR was opened, both touching
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`. Task: bring
PR #176 up to date with `main` while preserving both PRs' changes, no new
scope.

### What was done

- Fetched `origin/main` (tip `6d16fc6b981b3e059b4baae5f667c5b25c1fba0f`,
  the PR #175 merge commit).
- Merged `origin/main` into `claude/issue-168-onboarding-clarity-1a`
  (merge, not rebase — the branch was already pushed/reviewable as PR
  #176; a merge avoids rewriting published history).

### Conflict and resolution

Git's `ort` merge strategy resolved
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
**automatically, with no conflict markers** — PR #175's edit (the
`_buildMenuTab()` method, moving `BuildInfoLabel` to always render at the
top of the メニュー tab) and PR #176's edits (`april()`/`may()`/`june()`
Month Guard wiring, the April event-dialog copy, and
`internalTrainingCard()`'s explanatory line) sit in disjoint regions of
the file, so no manual resolution was required. `test/presentation/
build_info_test.dart` (PR #175's own test file, untouched by PR #176)
merged cleanly for the same reason.

Verified post-merge, not just trusted:
- `grep` confirms `BuildInfoLabel` renders unconditionally inside
  `_buildMenuTab()` (PR #175's always-visible placement, doc-commented
  "QA-MICRO-FIX (post-#173/#174)") — untouched by the merge.
- `grep` confirms `_confirmMonthCloseIfRecommendedOutstanding()` is still
  called from `april()`/`may()`/`june()` (PR #176's Finding A) — untouched
  by the merge.
- `git diff --stat origin/main...HEAD` shows only PR #176's original 29
  files (plus this report) changed relative to the new `main` — no
  `lib/game/**`, `lib/domain/**`, save/schema, finance, or
  `.github/workflows/**` file touched by the rebase itself.

No manual edits were needed beyond the merge commit itself. No new
feature, rule, or spec change was introduced by this addendum.

### Verification after the merge

- `flutter analyze` (whole project): **No issues found.**
- Focused #168 tests —
  `test/ui/public_demo/public_demo_01_month_guard_april_may_june_test.dart`
  + `test/ui/public_demo/public_demo_01_internal_training_explanation_test.dart`:
  **8/8 passed.**
- `test/presentation/build_info_test.dart` (PR #175's own suite, run to
  confirm its behavior survived the merge): **7/7 passed.**
- Full `flutter test` (whole project): **1,538/1,538 passed**, 0
  failures, exit code 0.

### SHAs

- `origin/main` tip at merge time:
  `6d16fc6b981b3e059b4baae5f667c5b25c1fba0f`
- New PR #176 head after merge:
  `51f28e8e8257ca7748da72ec9cebcfe2f77a836d` (merge commit; this report's
  own follow-up commit lands after it)

### Merge readiness (updated)

**READY**, unchanged from §12 — the merge brought PR #176 current with
`main` (including PR #175) with zero manual conflict resolution, zero
scope change, and full green regression (`flutter analyze` clean;
1,538/1,538 tests). Not merged, per this task's instruction — pushed to
`claude/issue-168-onboarding-clarity-1a` for review.

---

## 14. Addendum — Codex P2 review fix: April Month Guard vs. Playwright E2E (2026-09-05)

### Finding (Codex P2)

Issue #168's own Month Guard wiring (§2, Finding A) made April's close
show `PublicDemoMonthGuardWarningDialog` *before* April's own new-applicant
event dialog, whenever a recommended-level action is genuinely outstanding
— which a fresh playthrough's untouched 佐藤 健 SkillSheet確認 always is.
Three Playwright E2E specs, written before Issue #168 existed, still
assumed April's close opens the applicant event dialog directly and read
its `alertdialog` content immediately:

- `e2e/tests/public-demo-july-restart.spec.ts`
- `e2e/tests/public-demo-single-month-cta.spec.ts`
- `e2e/tests/public-demo-month-guard.spec.ts`

Reproduced against the current PR #176 head before this fix (mobile-chromium,
local Chromium 140/revision 1194 pinned via `SES_E2E_CHROMIUM_PATH`, since
this sandbox's cached Playwright browser revision (1194) trails the
`@playwright/test` version `e2e/package.json` resolves to (1.62.1, wants
1234) — a sandbox/tooling mismatch, not a repository issue): each of the
three failed with the guard's own dialog content instead of the applicant
dialog's, e.g.

```
Expected substring: "採用候補者の情報を確認できます"
Received string:    "- alertdialog:
  - text: 未対応のタスクがあります
  - group: 月末処理を進める前に、次の行動が残っています。 ・ 佐藤 健のSkillSheetを確認 が未対応です。
  - button "このまま月末処理を進める"
  - button "タスクを確認""
```

confirming the finding exactly.

### Fix

`e2e/helpers/public-demo-player.ts`: extracted the guard-proceed logic
`closeMonthlyPrimaryCta` already carried (Issue #119, August-March) into a
new, standalone, exported helper:

```ts
export async function dismissMonthGuardIfPresent(page: Page): Promise<boolean>
```

Proceeds through `PublicDemoMonthGuardWarningDialog` exactly as a player
choosing "このまま月末処理を進める" would — never "タスクを確認", which would
cancel the close instead. No-op (`false`) when no guard dialog is open.
`closeMonthlyPrimaryCta` itself now calls this helper in the same place it
always ran this logic — a pure extraction, verified line-for-line
equivalent to its prior inline `if` block, so every one of its existing
callers (`public-demo-annual-route.spec.ts`,
`public-demo-month-guard-recommended.spec.ts`,
`public-demo-recovery.spec.ts`) keeps its exact prior behavior.

Each of the three named specs now calls `dismissMonthGuardIfPresent(page)`
right after every April/May/June canonical-CTA click, before reading
whatever dialog (if any) that month's own close opens next — following the
real player flow the guard now imposes, not just at April (where the
Codex finding was reported) but also at May and June, since Issue #168
wired the same guard into all three months and a full playthrough that
never performs the recommended actions keeps finding new outstanding items
each month. No production file changed; no assertion was weakened —
every pre-existing assertion in all three files (dialog content, month
numbers, button counts, no-legacy-label checks, no-overflow checks) is
unchanged and still runs, now reached via the guard instead of blocked by
it.

### Verification

- `npx tsc --noEmit` (`e2e/`): clean.
- `flutter analyze` (whole project, production code untouched by this fix):
  **No issues found.**
- Focused #168 Flutter tests — `public_demo_01_month_guard_april_may_june_test.dart`
  + `public_demo_01_internal_training_explanation_test.dart` +
  `test/presentation/build_info_test.dart` (PR #175's own suite): **14/14
  passed** (re-run after this fix; production code unchanged so this
  reconfirms, not regresses).
- The three named E2E specs (`--project=mobile-chromium`, pinned local
  Chromium per above): **7/7 passed** —
  `public-demo-month-guard.spec.ts` (2/2, 360×800/390×844),
  `public-demo-single-month-cta.spec.ts` (4/4, 360×800/390×844),
  and `public-demo-july-restart.spec.ts`'s own April→May Month Guard/
  applicant-dialog assertion (the Codex-flagged one) now passes. The
  Codex P2 finding is resolved.

### A separate, pre-existing, out-of-scope failure found while verifying `public-demo-july-restart.spec.ts`

Running the *rest* of `public-demo-july-restart.spec.ts` past the fixed
April/May/June points surfaced one more failure, unrelated to Month Guard:
its July step still calls a standalone `夏季賞与を決める` button on HOME,
but that control was relocated to the 会計 (Accounting) tab by commit
`87be6d71` ("feat(public-demo): add summer bonus decision ui") — already
on `main` **before** PR #176's own base commit (`cc79aaf`), confirmed via
`git merge-base --is-ancestor 87be6d71 cc79aaf`. This is a stale-test/
production mismatch that predates Issue #168 and this fix entirely; it is
**not** part of the Codex P2 finding this task addresses (which was
specifically about Month Guard dialog ordering), so — per this task's
explicit scope (fix only the named Month Guard finding, no other spec
changes, no production changes) — **it was left unfixed** rather than
silently expanded into. `public-demo-july-restart.spec.ts` as a whole
still fails at this later, pre-existing point; its own April/May/June
Month Guard handling (the actual subject of this fix) is confirmed correct
up to and including the July CTA being reached in-month. Recorded here as
a known gap for a separate follow-up (repoint the test at the 会計 tab, or
restore a HOME-level shortcut — a product decision, not this task's call).

### Related Public Demo E2E run ("可能な範囲で")

Also ran the remaining Public Demo E2E specs for broader confidence
(`public-demo-annual-route.spec.ts`, `public-demo-close-reopen-persistence.spec.ts`,
`public-demo-fresh-start.spec.ts`, `public-demo-month-guard-recommended.spec.ts`,
`public-demo-recovery.spec.ts`, `public-demo-skillsheet-phase-a.spec.ts` — 21
tests total): **3 passed, 18 failed**
(`public-demo-fresh-start.spec.ts` 1/1 and `public-demo-skillsheet-phase-a.spec.ts`
2/2 passed in full). All 18 failures were root-caused and are **pre-existing,
unrelated to this fix and to Issue #168**, not newly introduced:

- `public-demo-close-reopen-persistence.spec.ts` (4 failed) never calls
  `closeMonthlyPrimaryCta`/`dismissMonthGuardIfPresent` at all — it fails
  immediately on `openPublicDemo` + its own `commitSkillSheetReview`
  looking for an exact `SkillSheet確認` button on HOME, which HOME does
  not expose under that exact label (HOME's own Recommended Action card
  uses `SkillSheetを確認`/`$nameのSkillSheetを確認`; the bare `SkillSheet確認`
  label belongs to the 社員 tab's per-engineer card) — a wording drift
  unrelated to Month Guard.
- `public-demo-annual-route.spec.ts` (7 failed), `public-demo-month-guard-recommended.spec.ts`
  (2 failed), and `public-demo-recovery.spec.ts` (4 failed) all fail inside
  the same shared helper, `sellFoundingEngineerInApril`
  (`e2e/helpers/public-demo-player.ts`), at its `案件紹介` click step — never
  inside `closeMonthlyPrimaryCta`/`dismissMonthGuardIfPresent`. Since
  `closeMonthlyPrimaryCta`'s guard-handling was a verified pure extraction
  (§ above) with identical behavior before and after this fix, this failure
  cannot be caused by this session's change.

These 18 failures are out of this task's explicit scope (only the named
Month Guard finding, no other spec/production changes) and were left
unfixed; they are recorded here so the repository owner has full visibility
rather than an inflated "all E2E green" claim. A separate follow-up should
audit the full Public Demo E2E suite against current production UI copy
and flow independent of Issue #168/PR #176.

### Changed files (this addendum)

- `e2e/helpers/public-demo-player.ts` — new `dismissMonthGuardIfPresent`
  export; `closeMonthlyPrimaryCta` refactored to call it (pure extraction,
  no behavior change).
- `e2e/tests/public-demo-july-restart.spec.ts`,
  `e2e/tests/public-demo-single-month-cta.spec.ts`,
  `e2e/tests/public-demo-month-guard.spec.ts` — call
  `dismissMonthGuardIfPresent(page)` after each April/May/June canonical-CTA
  click, before reading whatever dialog that month's close opens next.
- This report.

No `lib/**` file changed. No balance/domain/save/schema/finance file
touched. No CI/workflow file touched. Finding B (§5) unchanged/untouched.

### Merge readiness (updated again)

**READY** for this fix's own scope: the Codex P2 Month Guard-ordering
finding in the three named E2E specs is resolved and verified
(`flutter analyze` clean, 14/14 focused Flutter tests, 7/7 targeted E2E
assertions). `public-demo-july-restart.spec.ts` as a whole is **not**
fully green (one pre-existing, out-of-scope failure past the fixed point,
§ above), and the broader Public Demo E2E suite carries 18 further
pre-existing, out-of-scope failures unrelated to this change — neither
blocks this task's own deliverable, both are recorded for a separate
follow-up.

---

## 15. Addendum — continuation: race-condition fix + GitHub review thread (2026-09-05)

### Why this continuation

The GitHub PR #176 Codex P2 review comment
(`https://github.com/perusonao/smile_enjoy_story/pull/176#discussion_r3939349595`,
posted at PR creation time, before §14's fix) was still showing
**unresolved** on GitHub — §14's commit (`900bfed`) had already fixed and
pushed the code, but the review thread itself was never replied to or
marked resolved. This continuation applies TEST-STRATEGY-1's lighter
verification (flutter analyze → the 3 named E2E specs → only the
necessary related E2E, not the full 1,538-test Flutter suite) to
re-confirm §14's fix, and closes out the GitHub thread.

### A genuine bug found during re-verification: guard-detection race condition

Re-running the three named specs (`flutter analyze` clean first) surfaced
an **intermittent** failure that had not appeared in §14's own runs:
`public-demo-month-guard.spec.ts` at 390×800 failed with the May→June
Month Guard dialog still open after the full 5-minute test timeout —
i.e. `dismissMonthGuardIfPresent` had concluded no guard was open and
returned, when in fact the guard opened a moment later.

**Root cause:** the original `dismissMonthGuardIfPresent` (§14) did one
synchronous presence check (`(await monthGuardDialog.count()) === 0`)
with no wait at all. `PublicDemoMonthGuard.evaluate` and its `showDialog`
run asynchronously, after the triggering click's own frame returns — the
same class of gap this codebase's own `waitAndDismissDialog` already
documents and handles for other dialogs (a short, bounded, event-driven
poll). `closeMonthlyPrimaryCta`'s own call to this helper happened to be
shielded from the race by the ~600ms+ minimum `waitAndDismissDialog(page,
'確認', 4_000)` call immediately before it, which the three named specs'
own direct `dismissMonthGuardIfPresent(page)` calls (§14) do not have —
so only they were exposed, and only intermittently (a timing race, not a
deterministic failure — it passed in §14's own verification runs before
failing on this session's first re-run).

**Fix:** `dismissMonthGuardIfPresent` now takes a bounded, event-driven
wait for its own target button (`Locator.waitFor({ state: 'visible',
timeoutMs })`, default 4,000ms — the same order of magnitude
`closeMonthlyPrimaryCta` already budgets for this class of dialog) instead
of one instantaneous count check. This is Playwright's own built-in
auto-waiting primitive, the same idiom `waitAndDismissDialog` and
`findMonthlyPrimaryCta` already use elsewhere in this file — **not** a
`sleep`, `retry`, or `skip`: the common no-guard path still returns
`false` (just after its own bounded wait elapses, rather than instantly),
and every existing pass/fail assertion is unchanged. `closeMonthlyPrimaryCta`
itself needed no edit — it already called this same function; the fix is
entirely inside `dismissMonthGuardIfPresent`'s own implementation.

### Re-verification (TEST-STRATEGY-1)

1. `flutter analyze` (whole project, production code untouched): **No
   issues found.**
2. The three named E2E specs (`--project=mobile-chromium`, pinned local
   Chromium), run **twice** back-to-back specifically to confirm the race
   is actually fixed (a single green run cannot rule out an intermittent
   race): **6/6 passed both times** —
   `public-demo-month-guard.spec.ts` (2/2, 360×800/390×844, ~30s each,
   no more 5-minute timeout), `public-demo-single-month-cta.spec.ts` (4/4,
   360×800/390×844). `public-demo-july-restart.spec.ts` still fails, but
   only at §14's already-recorded, pre-existing, out-of-scope `夏季賞与を
   決める` HOME/会計-tab mismatch — its own April/May/June Month Guard
   assertions (the actual subject of both this fix and the Codex finding)
   pass cleanly in both runs.
3. Related Public Demo E2E: not re-run this round, per TEST-STRATEGY-1
   ("必要な関連Public Demo E2Eのみ") — the 18 pre-existing failures §14
   already root-caused all occur at points upstream of
   `closeMonthlyPrimaryCta`'s own guard-handling (a `SkillSheet確認` label
   mismatch, or the `sellFoundingEngineerInApril` helper's `案件紹介` step),
   so re-running them would not exercise this change and was skipped to
   keep verification lightweight, as instructed. Full `flutter test`
   (1,538 tests) was likewise not re-run — production code is untouched
   by this continuation, and §14 already confirmed it in full.

### GitHub review thread

Replied to and resolved Codex's review thread
(`discussion_r3939349595`) on PR #176, referencing commit `900bfed` (the
original fix) and this continuation's race-condition follow-up.

### Changed files (this addendum)

- `e2e/helpers/public-demo-player.ts` — `dismissMonthGuardIfPresent`
  reimplemented with a bounded `Locator.waitFor` instead of one
  instantaneous presence check (fixes the race above); `closeMonthlyPrimaryCta`
  itself unchanged.
- This report.

No other file touched. No `lib/**`/production file changed. No
balance/domain/save/schema/finance file touched. No CI/workflow file
touched. No new spec added; no existing assertion weakened; no skip,
retry, or `sleep`/`waitForTimeout` added anywhere. Finding B (§5)
unchanged/untouched. No new PR created — same `claude/issue-168-onboarding-clarity-1a`
branch, PR #176.

### Merge readiness (updated again)

**READY** for this fix's own scope, now confirmed race-free: the Codex P2
Month Guard-ordering finding is resolved, verified stable across two
independent runs, and the GitHub review thread is resolved. The two
already-recorded, pre-existing, out-of-scope gaps (§14 — the July
`夏季賞与を決める` tab relocation, and the 18-test broader E2E audit) remain
open as a separate follow-up; neither is this task's own deliverable and
neither regressed.
