# SES Issue #132 Phase A Main Integration Result

## STATUS

PASS — ready for PR / review. Full non-negotiable verification (flutter
analyze, full flutter test, targeted #117/#118/#132 tests, Playwright
mobile-chromium at 360px/390px) all green. The one gap is WebKit, which is
not installed in this sandbox and was not run; this is called out explicitly
below and treated as a CI gate rather than a silent skip.

## BASE

- branch: `main`
- SHA: `25a2e9b6b401794090151cc86006e433c8d9a789`
  (confirmed via `git fetch origin main` at task start; matches the exact
  SHA specified in the task instructions — no drift, no need to
  re-evaluate against a moved base)

## ORIGINAL #132

- branch: `claude/issue-132-skillsheet-phase-a-eucg0b`
- original/remote HEAD: `2bbcbfc50bd242ead63cb185242055d3c18d67f3`
  (confirmed via `git fetch origin claude/issue-132-skillsheet-phase-a-eucg0b`
  — matches the "known implementation head" given in the task instructions)
- merge-base with `origin/main`: `53ea69e725d960872f20adb9046824e9e7ab526d`
  (the #132 branch carries exactly **one** commit beyond this merge-base —
  `2bbcbfc50b`, the full Phase A implementation. `origin/main` carries four
  commits beyond the same merge-base: `0542630`, `b6d4ba4`, `f2c6b7b`, and
  the `25a2e9b` merge commit for PR #135 — i.e. all of #118.)

## FINAL INTEGRATION

- branch: `claude/issue-132-phase-a-main-integration`
  (created fresh from `origin/main` in an isolated `git worktree`, per the
  task's isolation requirement — the primary checkout had no uncommitted
  work of its own to protect, but the worktree was used anyway to keep this
  operation fully reversible and independent of the primary working tree)
- HEAD SHA: `28072a5ee66e48e3a6c7751451119e60c3a38020` (this includes the
  #132 Phase A cherry-pick, `342248e11147fd15311e5c47744a4e68158e9ffd`, plus
  this report's own docs-only commit on top; the code/diff described
  throughout this report — DIFF AUDIT, PRESERVATION, DOMAIN/FINANCE/
  PERSISTENCE — is entirely `342248e`'s content, since this report commit
  changes only this file. A final addendum commit adding the PR reference
  below moves the pushed branch tip one commit further than this SHA; see
  the linked PR for the exact final tip.)
- parent: `25a2e9b6b401794090151cc86006e433c8d9a789` (`origin/main`, exact
  expected SHA)

## MERGE / REBASE STRATEGY

`git cherry-pick -x 2bbcbfc50bd242ead63cb185242055d3c18d67f3` onto a fresh
branch off `origin/main`.

Rationale: the #132 branch has exactly one commit since its merge-base with
main, and that commit's own message documents that the placeholder-screen
edit was deliberately scoped to only `_openSkillSheetReview`'s body "to
minimize #118 merge-conflict risk." A single clean cherry-pick preserves the
original commit's authorship, message, and Claude-Session trailer intact
(via `-x`, which also records the source SHA), and is the smallest, most
auditable way to re-home one self-contained commit onto a new parent —
preferable to a multi-commit rebase (there was only one commit to move) or a
merge commit (which would pull in no new content, since #132 has nothing
main doesn't already have except this one commit).

## CONFLICTS

**None.** `git cherry-pick` reported clean `Auto-merging` (not
`CONFLICT`) on both files it touched:

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
  Cause: both #132 and #118 edit this file, but in disjoint regions — #118
  removed legacy per-month "close" controls and consolidated on the single
  `PublicDemoMonthlyPrimaryCtaSection` CTA elsewhere in the widget tree;
  #132 only replaced the body of `_openSkillSheetReview` (the AlertDialog →
  `PublicDemoSkillSheetSheet.show(...)` call) plus one new import and one
  new private helper (`_assignmentForOrNull`). Git's 3-way merge resolved
  both hunks automatically with no overlapping lines.
  Resolution: none needed; verified by reading the full resulting diff by
  hand (see PHASE 6 / DIFF AUDIT below) — the #118 CTA section and the #132
  SkillSheet body coexist exactly as each commit intended.

- `test/ui/public_demo/public_demo_01_persistence_test.dart`
  Cause: #118 touched several call sites in this file (updated for the
  consolidated CTA flow); #132 added one `await tester.pumpAndSettle();`
  line inside the shared `_tapAction` helper's `'SkillSheet確認'` branch, to
  settle the AlertDialog→bottom-sheet transition-animation change. Disjoint
  line ranges; auto-merged cleanly.
  Resolution: none needed.

No other file in the #132 commit (`public_demo_skill_sheet_*.dart` ×3,
the new Playwright spec, the original #132 report) exists on `main`, so
those five files applied as pure additions with no conflict surface.

## #118 PRESERVATION

- canonical CTA: `Key('public-demo-monthly-primary-cta')` present exactly
  once, in `lib/ui/public_demo/public_demo_home_presentation_components.dart`
  (unchanged by this integration); `PublicDemoMonthlyPrimaryCtaSection` is
  referenced from `public_demo_01_placeholder_screen.dart` exactly once.
  Verified via `grep -rn` across `lib/`.
- duplicate legacy CTA absence: confirmed no matches for legacy per-month
  close-control text ("4月終了", "5月終了", "6月終了" and equivalents) or
  duplicate month-advance buttons anywhere in `lib/ui/public_demo/`.
  `test/ui/public_demo/public_demo_01_single_month_advance_cta_test.dart`
  (#118's own regression suite, untouched by this integration) passes
  unmodified, including its explicit "exactly one month-advance CTA"
  assertions for April and May at both 360px/390px (via the Playwright
  spec) and widget level.

## #132 PRESERVATION

- Bottom Sheet: `PublicDemoSkillSheetSheet.show(...)` (a
  `showModalBottomSheet`-based mobile sheet) is what
  `_openSkillSheetReview` now invokes, verbatim from the original #132
  commit — no AlertDialog code remains in this path.
- summary: `public_demo_skill_sheet_display_projection.dart`'s read-only
  projection over existing Domain/runtime data ships unmodified.
- accordions: the five accordion detail sections in
  `public_demo_skill_sheet_sections.dart` ship unmodified.
- actual/displayed experience separation: `skill.actualExperienceMonths`
  and `skill.displayedExperienceMonths` are both read and passed through to
  the display projection as two distinct fields (`actualMonths` /
  `displayedMonths`); neither authority was merged, renamed, or
  re-derived from the other. Confirmed by direct inspection of
  `public_demo_skill_sheet_display_projection.dart:183-184` — this
  integration did not touch that file at all (it applied as a pure
  addition), so the separation is exactly as #132 originally shipped it.

## #117 REGRESSION

`test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart` (#117's own
widget-level regression test, untouched by both #118 and this integration)
passes unmodified — including "SkillSheet inspection explicit confirmation
advances once and existing sales start continues," which is the exact
fresh start → HOME → SkillSheet → confirm → HOME → sales-start contract the
task asks to protect. The Playwright spec added by #132
(`public-demo-skillsheet-phase-a.spec.ts`) independently re-verifies the
same flow at the browser/DOM level (fresh start → SkillSheet → Back →
reopen → Confirm → sales start) at both 360px and 390px — both pass. No
#117 key, label, or return-value semantic was renamed or removed; the only
behavioral change from #117 is the presentation container (AlertDialog →
bottom sheet), which is exactly Phase A's documented, in-scope change.

## DOMAIN / FINANCE / PERSISTENCE

**No changes to any of the three.** The final diff
(`git diff origin/main...HEAD --stat`) touches exactly 7 files, all inside
`docs/reports/`, `e2e/tests/`, `lib/ui/public_demo/`, and
`test/ui/public_demo/`. Nothing under `lib/domain/`, `lib/finance/` (or
equivalent finance/sales-rule/month-progression engine code), or any
persistence/save-schema path is touched — confirmed with
`git diff origin/main...HEAD --stat -- lib/domain lib/finance lib/persistence`
returning empty. The one added `pumpAndSettle()` line in
`public_demo_01_persistence_test.dart` is a **test-only** timing fix (for
the AlertDialog→bottom-sheet animation), not a persistence-schema or
save-format change — no assertion in that file was added, removed, or
weakened.

## TEST RESULTS

Environment note: this sandbox ships no Flutter SDK by default. A
stable-channel Flutter 3.47.2 (Dart 3.13.2) was downloaded and installed
locally to run these checks (network egress to
`storage.googleapis.com/flutter_infra_release` is permitted here); this is
a local-verification detail only; the repo's own CI is the SDK version of
record. `flutter pub get` under this newer SDK bumped a handful of
transitive-only dependency pins in `pubspec.lock` (matcher, meta, test_api,
vector_math, etc.) — this drift was **not** committed; `pubspec.lock` was
restored to its `origin/main` byte-for-byte state (`git checkout --
pubspec.lock`) before the final diff audit and commit, so the pushed branch
carries zero `pubspec.lock` changes.

- `flutter analyze`: **clean** — "No issues found! (ran in 16.5s)"
- `flutter test` (full suite, all directories): **1324/1324 passed**, 0
  failures. (Baseline per the original #132 report was 1317/1317; #118 adds
  7 new tests in `public_demo_01_single_month_advance_cta_test.dart`,
  accounting for the +7.)
- `flutter test test/ui/public_demo/` (targeted, all 25 files in the
  directory — the full Public Demo widget-test surface, i.e. #117 + #118 +
  #132 + every other Public Demo regression suite together): **191/191
  passed**, 0 failures. Includes, by name:
  - `public_demo_01_skill_sheet_flow_test.dart` (#117 regression) — pass
  - `public_demo_01_single_month_advance_cta_test.dart` (#118 regression,
    "exactly one month-advance CTA" for April/May, both widths, plus the
    close-blocked-terminal-state-has-no-CTA case) — pass
  - `public_demo_01_persistence_test.dart` (exercises the modified
    `_tapAction` helper's SkillSheet path directly) — pass
  - all remaining Public Demo suites (bankruptcy UX, completion-lock,
    fiscal-year progression, home consolidation/navigator/office-stage/
    recommended-action/runtime-read, assignment carryforward, playthrough,
    success playthrough, Suzuki sales lock, and component-level tests for
    cash-shortage/event-dialog/growth-result/home-presentation/interview-
    result/monthly-cash-flow/raise/salary-offer/summer-bonus) — all pass
    unmodified.

## PLAYWRIGHT

Built once via `flutter build web --release` from the integration branch
(`build/web`), served by the repo's own `e2e/scripts/static-server.js`, run
against the pre-installed Chromium binary
(`/opt/pw-browsers/chromium-1194/chrome-linux/chrome`, via
`SES_E2E_CHROMIUM_PATH`, per `playwright.config.ts`'s documented escape
hatch for sandboxed CI images).

**mobile-chromium — 360px (Pixel-7-equivalent viewport, project default):**

- `public-demo-skillsheet-phase-a.spec.ts` → fresh start → SkillSheet →
  back → reopen → confirm → sales start (360x800): **PASS** (22.5s)
- `public-demo-single-month-cta.spec.ts` → April HOME exactly one CTA
  (360px): **PASS** (20.5s)
- `public-demo-single-month-cta.spec.ts` → May HOME still exactly one CTA
  (360px): **PASS** (25.0s)
- `public-demo-fresh-start.spec.ts` → route opens in April with a
  reachable initial employee action: **PASS** (20.4s)

**mobile-chromium — 390px:**

- `public-demo-skillsheet-phase-a.spec.ts` → fresh start → SkillSheet →
  back → reopen → confirm → sales start (390x800): **PASS** (22.4s)
- `public-demo-single-month-cta.spec.ts` → April HOME exactly one CTA
  (390px): **PASS** (20.6s)
- `public-demo-single-month-cta.spec.ts` → May HOME still exactly one CTA
  (390px): **PASS** (23.4s)

Total: **7/7 passed** (1.5m), 0 failures. Content verified within these
runs: SkillSheet opens as a bottom sheet with no horizontal overflow at
either width, accordions are interactive, Back does not progress the
month, the sheet reopens correctly, Confirm advances exactly once, control
returns to HOME after Confirm, sales can be started afterward, and exactly
one month-advance CTA (#118's canonical
`public-demo-monthly-primary-cta`) is present on HOME at both April and
May.

**WebKit result / CI requirement:**

`mobile-webkit` was attempted and failed at browser launch — this sandbox
ships only a pre-installed Chromium (`/opt/pw-browsers/`); it does not
carry a WebKit binary, and per this environment's own operating
constraints, `playwright install` must not be run here to fetch one
(network-fetching a new browser binary is out of scope for a sandboxed
verification pass, distinct from the one-time Flutter SDK download, which
this task's own instructions implicitly required for `flutter analyze`/
`flutter test` to run at all). No test assertion was weakened or skipped to
route around this — the WebKit project simply did not execute.
**Per the task's own stop condition for this exact situation: this is
recorded here, not silently skipped, and is a required CI gate before
merge.** The repository's own CI (GitHub Actions or equivalent), which
provisions its own matching WebKit binary via `playwright install` per
`playwright.config.ts`'s non-`SES_E2E_CHROMIUM_PATH` branch, must run
`mobile-webkit` for both specs before this PR is considered fully verified.

## DIFF AUDIT

`git diff origin/main...HEAD --stat` (7 files changed, 1219
insertions(+), 57 deletions(-)) — identical in file list and line counts to
the original #132 commit's own diff, because the cherry-pick applied with
zero conflict-resolution edits:

| File | Category |
|---|---|
| `docs/reports/SES_ISSUE-132_Phase-A_Implementation_Result.md` | A — #132 Phase A (original implementation report, carried as-is) |
| `e2e/tests/public-demo-skillsheet-phase-a.spec.ts` | A — #132 Phase A |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | A — #132 Phase A (scoped strictly to `_openSkillSheetReview` + one import + one helper; #118's CTA code in this same file is untouched and auto-merged cleanly) |
| `lib/ui/public_demo/public_demo_skill_sheet_display_projection.dart` | A — #132 Phase A (new file) |
| `lib/ui/public_demo/public_demo_skill_sheet_sections.dart` | A — #132 Phase A (new file) |
| `lib/ui/public_demo/public_demo_skill_sheet_sheet.dart` | A — #132 Phase A (new file) |
| `test/ui/public_demo/public_demo_01_persistence_test.dart` | A — #132 Phase A (one-line animation-timing fix required by the AlertDialog→bottom-sheet change) |

Category B (changes needed purely to follow main): **none** — the cherry-
pick required no additional edits beyond the original commit's own content;
main's #118 work needed no accommodation because it lives in disjoint
regions of the one shared file.

Category C (unrelated/accidental): **none found.** No Domain, Finance,
Persistence, workflow, or normal-game file appears anywhere in the diff
(confirmed separately via `git diff origin/main...HEAD --stat -- lib/domain
lib/finance lib/persistence`, which returns empty). `pubspec.lock` carries
zero diff (local `pub get` drift was reverted before this audit, see TEST
RESULTS above).

## PR

- number: **#136**
- URL: https://github.com/perusonao/smile_enjoy_story/pull/136
- base: `main`
- base SHA: `25a2e9b6b401794090151cc86006e433c8d9a789`
- head SHA at PR-creation time: `28072a5ee66e48e3a6c7751451119e60c3a38020`
  (the branch tip advances by one further docs-only commit, adding this PR
  reference, immediately after — see the PR itself for the exact final
  commit)
- title: `feat(public-demo): integrate SkillSheet Phase A redesign`
- body restates: #132 Phase A only; #118 single CTA preserved;
  Domain/Finance/Persistence/normal-game changes: none; tests executed
  (flutter analyze clean, 1324/1324 + 191/191 flutter test, 7/7 Playwright
  mobile-chromium at 360/390px); WebKit not run locally (environment
  constraint, not a test weakening) and required as a CI gate before merge;
  Phase B/C explicitly deferred. Not merged by this run, per instructions —
  merge is left to CI completion and maintainer review.

## MERGE READINESS

**PASS**, contingent on the repository's own CI running `mobile-webkit`
successfully (the one check this local pass could not execute) before
merge. Every other required signal — flutter analyze, full flutter test,
targeted #117/#118/#132 regressions, and mobile-chromium Playwright at both
360px and 390px — is green, and the diff audit confirms zero unrelated,
Domain, Finance, Persistence, or normal-game changes.

## REMAINING RISKS

- **WebKit untested locally** (see PLAYWRIGHT above) — the single
  outstanding verification gap; mitigated by making it an explicit CI gate
  rather than silently skipping or weakening any assertion. Risk is low:
  the Phase A change is a standard Flutter Material `showModalBottomSheet`,
  and the equivalent Chromium run already exercises the same underlying
  widget tree, animation timing, and DOM structure at both target widths.
- **Local Flutter SDK version (3.47.2 stable) may not exactly match the
  repository's pinned/CI Flutter version** (the repo's `.metadata` records
  Flutter revision `ac4e799d...`, an older commit than 3.47.2 stable's
  `d3b14c8769`). All local results above should be treated as a strong
  pre-flight signal, not a substitute for CI's own `flutter analyze` /
  `flutter test` run on its pinned SDK. `pubspec.lock` itself is unchanged
  on this branch, so CI's own dependency resolution is unaffected.
- No other risks identified: the change is a single clean cherry-pick with
  zero conflict-resolution edits, a diff identical to the original,
  independently-reviewed #132 commit, and full regression coverage across
  #117/#118/#132 all green.
