# SES FIRST-FUN-YEAR Human Replay UX — Phase A Implementation Result

## STATUS

IMPLEMENTATION COMPLETE (production + regression tests + verification),
committed and pushed to the designated branch. No Codex broad review in
this pass, per instructions.

## Issue / source documents

- **Issue:** #245 (FIRST-FUN-YEAR Human Replay UX Findings)
- **Fresh Audit (SSOT for this Phase):**
  `docs/reports/SES_FIRST-FUN-YEAR_Human-Replay-UX-Findings_Fresh-Audit.md`
  (read in full from `origin/claude/issue-245-fresh-audit-3600u9`, which is
  where that audit was committed — it does not yet exist on `origin/main`).
  This Phase implements exactly the Fresh Audit's own **Phase A** split:
  Findings #1, #2, #8, #9 (regression-test only), #11.

## Base SHA / Final HEAD

- **Base SHA (explicit `origin/main`, verified via `git fetch origin` +
  `git rev-parse origin/main` before any work):**
  `0ba21f2021c0963d8acfad28c2c99de096b776a9` (PR #244 merge — matches the
  Fresh Audit's own audited SHA exactly; no drift).
- **Final HEAD (pushed):** `c2801ae7aa5534f582bf89143d3f5b809ca9a945` (the
  commit that adds this report itself — as with PR #244's own Result
  Report, a report cannot embed the hash of the commit that contains it
  before that commit exists; this value was filled in via a follow-up
  metadata-only amendment of this same file, verified against `git log -1`
  after pushing).
- **Branch:** `claude/phase-a-fresh-audit-245-hymp9b`

The designated branch existed locally but pointed at a stale, unrelated
single commit (`f4ca78f`, "Phase 0A/0B: SES domain models and random
generators" — a leftover scaffold commit already an ancestor of
`origin/main`, contributing nothing of its own). Per the "already-merged /
stale branch" restart instructions, it was reset to `origin/main`
(`git checkout -B claude/phase-a-fresh-audit-245-hymp9b origin/main`)
before starting. No open PR existed for this branch.

## Scope actually implemented

Per the Fresh Audit's own Phase A definition — presentation-only, no
schema/domain change:

| Finding | Change |
|---|---|
| **#1** | Opening Context now introduces the 2 founding engineers by their existing `name`/`summary` (from `publicDemoInitialEngineers` — already player-facing text reused from SkillSheet/Matching, nothing new), plus a second CTA button ("まずSkillSheetで2人を確認する") that dismisses the Opening Context onto the 社員 (Employees) tab instead of HOME, giving SkillSheet confirmation an actual reason to be the first action. |
| **#2** | `案件紹介` (`_introduceProject`) now shows a non-blocking `SnackBar` naming the real project title/client/monthly rate the existing `PublicDemoMatchingProposal` + `projectCandidatesForMonth` authority already resolves (Issue #219's auto-propose). Previously this button only flipped a stage badge with zero visible feedback. |
| **#8** | The Sales-tab applicant card no longer renders `評価 ${a.interviewScore}` as a raw number. `publicDemoApplicantEvaluationLabel(int)` states the exact same `>= 60` pass line the offer button (`合格・給与提示`) already gates on, in words — plus one explanatory line on what the evaluation reflects (communication/attitude, truthfully derived from the existing generator). No new score, no new threshold. |
| **#9** | Regression-locks the Fresh Audit's own §1 finding: dismissing (X button, and the OS-level back/route-pop gesture) either interactive interview dialog — Project Interview (`PublicDemoProjectInterviewDialog`) and Recruitment Interview (`PublicDemoRecruitmentInterviewDialog`) — never commits a pass/fail or hire/reject outcome, and reopening resumes the exact same in-progress session (same session id, same partial answers/follow-ups), never a fresh one. 4 new test cases across the two dialogs' existing test files. |
| **#11** | The 営業 tab's "現在の営業・採用状況" third stat tile is relabeled from ambiguous `案件 N件` to `受注案件 N件` — it has only ever counted `workflow.assignments` (records that exist only after a genuine order), never leads/candidates/introduced-but-not-ordered projects. Same underlying count, label only. |

**Explicitly excluded from this pass** (per the Fresh Audit's Phase split
and the task instructions): Finding #3 (上位会社面談 mini-game/explanation),
#4 (parallel sales), #6 (monthly report polish), #7 (紹介会社/商流), #10
(interview modal density), #12/#13 (applicant lifecycle visibility).

## Files changed

**Production (2 files):**

| File | Change |
|---|---|
| `lib/ui/public_demo/public_demo_opening_context_screen.dart` | Finding #1 — `PublicDemoOpeningFounder` data class, `_FoundingRosterSection` widget, new `onViewSkillSheetFirst` callback/button. |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | Finding #1 (call site + `_acknowledgeOpeningContext(openEmployeesTabFirst:)`), Finding #2 (`_introduceProject` SnackBar), Finding #8 (`publicDemoApplicantEvaluationLabel` + `ac(i)` display), Finding #11 (stat tile relabel). |

**Tests (7 files — 2 new, 5 modified):**

| File | Change |
|---|---|
| `test/ui/public_demo/public_demo_01_opening_context_test.dart` | Finding #1 — founding-roster content assertions, SkillSheet-first CTA test, TextScaler 1.0/1.3 added to the existing 360×800/390×844 layout loop; existing start-button taps updated to scroll into view first (see Unresolved/notes below). |
| `test/ui/public_demo/public_demo_project_interview_dialog_test.dart` | Finding #9 — 2 new regression tests (X-button close, OS back gesture). |
| `test/ui/public_demo/public_demo_recruitment_interview_visual_test.dart` | Finding #9 — 2 new regression tests (X-button close, OS back gesture). |
| `test/ui/public_demo/public_demo_applicant_evaluation_label_test.dart` | **NEW** — Finding #8 unit tests: no digit ever appears in the label (0–100 sweep), exact text for both branches of the existing `>=60` gate. |
| `test/ui/public_demo/public_demo_01_success_playthrough_test.dart` | Finding #8 — `評価 80` raw-score assertion updated to the new qualitative label. |
| `test/ui/public_demo/public_demo_01_recovery_ui_test.dart` | Finding #8 — same raw-score assertion update. |
| `test/ui/public_demo/public_demo_sales_visual_complete_test.dart` | Finding #11 — 2 assertions using `primaryText.startsWith('案件')` updated to `startsWith('受注案件')` (caught by the full `test/ui/public_demo` run, see below). |

No file under `lib/game/`, `lib/domain/`, or any save/schema file was
touched. `test/ui/public_demo/public_demo_sales_ui_phase1_test.dart`'s own
`textContaining('案件 0件')`/`('案件 1件')` assertions needed **no** change —
they still match as a literal substring of the new `受注案件 N件` label.

## Tests

All run against this branch's final HEAD, via a Flutter 3.47.3 (stable)
SDK fetched into the sandbox for this session (not preinstalled in this
environment — see **Environment note** below).

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found.** |
| `flutter test test/game/public_demo` | **861/861 passed** (matches the pre-existing baseline noted in PR #244's own Result Report — Phase A touched no domain code, so this count is an unchanged-baseline confirmation, not new coverage). |
| `flutter test test/ui/public_demo` | **680/680 passed** (full suite, two runs — see below). |
| `flutter test test/app/ses_app_opening_marker_test.dart` | 2/2 passed (Opening Context is also mounted here; confirmed unaffected). |
| `git diff --check` | Clean (no whitespace errors). |

**Self-hardening note:** the first full `test/ui/public_demo` run (before
the final commit) surfaced 2 real regressions from Finding #11's relabel —
`public_demo_sales_visual_complete_test.dart` had two assertions matching
via `primaryText.startsWith('案件')`, which `受注案件 N件` no longer starts
with (unlike the `textContaining` checks elsewhere, which still matched as
a substring). Both were fixed and the full suite was re-run clean
(680/680) before finalizing — this is exactly the loop the task asked for
(self-hardening → focused verification, not "changed files pass, ship it").

**Environment note:** this sandbox has no Flutter/Dart SDK preinstalled.
Flutter 3.47.3 stable was cloned from `github.com/flutter/flutter` and
used only to run `analyze`/`test` locally in this session — it is not part
of the diff and nothing in the repository was changed by its use (verified
via `git status`/`git diff --check` after every run; two runs regenerated
4 PNG screenshots under `docs/reports/screenshots/` as a side effect of an
unrelated pre-existing visual test — both times reverted with
`git checkout --` before committing, confirmed not part of any commit).

## Viewport / TextScaler results

Required by Issue #245: 360×800 / 390×844, TextScaler 1.0/1.3.

- **Finding #1 (Opening Context):** new `mobile layout` loop in
  `public_demo_01_opening_context_test.dart` — both sizes × both
  TextScaler values, asserts the founding-roster card renders and
  `tester.takeException()` is null (no overflow). Passing.
- **Finding #2 (SnackBar):** no new dialog/modal geometry — a standard
  Material `SnackBar`, already exercised at both sizes across every
  existing `pumpSalesTab`-based test in `test/ui/public_demo` that now
  passes through `_introduceProject`.
- **Finding #8 (evaluation label):** shorter text than the value it
  replaced (`評価: 採用基準を満たしています` vs. `評価 74`) — covered by the
  existing `public_demo_seeded_recruitment_visual_test.dart` /
  `public_demo_sales_visual_complete_test.dart` viewport coverage, both
  passing at 360×800/390×844 × TextScaler 1.0/1.3/2.0.
- **Finding #9 (regression dialogs):** the two dialogs' own existing
  `public_demo_project_interview_dialog_test.dart` viewport/TextScaler
  group (390×844/360×800 × 1.0/1.3/2.0) is untouched by this change and
  still passes; the new dismiss/reopen tests run at 390×844 (the dialogs'
  own layout is unaffected by Finding #9 — it verifies state, not pixels).
- **Finding #11 (stat tile):** `受注案件 N件` is never longer than the
  `案件 N件` text it replaced by more than 4 full-width characters —
  `public_demo_sales_visual_complete_test.dart`'s own 360×800/390×844 ×
  TextScaler 1.0/1.3/2.0 overflow assertions for this exact section pass.

## Schema / domain impact

**None.** No file under `lib/game/` or `lib/domain/` was modified. No new
`PublicDemoWorkflowState` field, no new score, no new persisted state, no
change to any save-file shape. Finding #2's SnackBar and Finding #8/#11's
labels are pure re-renderings of data the domain layer already produces
(`PublicDemoMatchingProposal`/`PublicDemoProjectCandidate`,
`PublicDemoApplicant.interviewScore`, `workflow.assignments`). Finding #1
reads `publicDemoInitialEngineers`' existing `name`/`summary` fields
verbatim. Finding #9 added test coverage only — the production dismiss
behavior it locks in was already correct on `origin/main` (see the Fresh
Audit's §1, "NOT REPRODUCIBLE" for both interactive dialogs).

Guardrails honored: no hidden parameter (`interviewScore`'s underlying
number, `interviewProfile.skillFit`/etc.) is newly disclosed anywhere; no
raw score/percentage appears in any new or changed UI text;
`ordered != assigned` and `revenue != cash receipt` are untouched;
Finance/Payroll/Matching/Interview outcome formulas are untouched.

## Unresolved items / follow-ups

1. **Test-helper viewport sensitivity (Finding #1):** adding the
   founding-roster card + second CTA button to the Opening Context pushed
   its total content past flutter_test's default (short, ~800×600)
   window's `Viewport` cache extent in three pre-existing tests that
   `tester.tap()`ped the start button without scrolling first. Fixed by
   switching those calls to `tester.scrollUntilVisible` (the screen is
   already a `ListView` by design, specifically so TextScaler growth
   scrolls rather than overflows — this is the same mechanism, just now
   also exercised by the default test window). No production behavior
   changed; flagged here since it is exactly the kind of test-fragility a
   future content addition to this screen should expect.
2. **Finding #3/#9's real complaint (Partner Interview mini-game)** is
   explicitly out of scope for Phase A per the Fresh Audit — the
   regression tests added here lock the *current, correct* dismiss
   behavior for the two dialogs that already have real interactivity, but
   do not address 上位会社面談's own lack of any interactive content
   (Fresh Audit §1c / Phase B's own scope).
3. **Findings #6/#11's coordination with Issue #239** — the Fresh Audit
   recommended folding Finding #11 into #239's resolver work rather than a
   standalone relabel. This Phase implemented it standalone (small,
   isolated, no conflict expected) since #239 has not landed; a future
   #239 implementation should treat this label as the current baseline,
   not something to re-derive.
4. **Codex broad review** was explicitly deferred per the task's own
   instructions — not run in this pass.

## PR

<!-- filled in after PR creation -->

## Actual elapsed time

Session start ≈ 2026-09-11 14:47 UTC (environment provisioning) — this
report finalized ≈ 2026-09-11 15:33 UTC. **≈ 46 minutes** end-to-end,
including cloning a full local Flutter SDK (~55s) mid-session to run
`analyze`/`test` (no SDK was preinstalled), one full-suite regression catch
requiring a follow-up commit, and two full `test/ui/public_demo` runs
(~13 minutes each).
