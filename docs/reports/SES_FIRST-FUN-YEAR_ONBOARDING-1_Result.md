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
