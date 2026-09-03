# SES_ISSUE-136_Main_Reintegration_Result

## STATUS

Complete. SkillSheet Phase A (#132) is re-integrated onto the current `main`
(which now carries Issue #148 Phase 1A / 1B.1 / 1B.2, from merged PR #153 and
PR #154), with zero conflict-resolution edits and zero changes to any #148
file. Not merged, per instructions.

## SHAs

- **Base SHA (new branch point):** `8d510e6a3af98d28bb4d15b6d93ad94eb99f776f`
  (`origin/main` HEAD at task start — "Issue #148 Phase 1B.1 + 1B.2: 資金状態
  Presenter + ひより助言候補選定")
- **Head SHA (this branch):** `947b446998b784d34489b0ed89ef429f85c5d2fe`
- **PR #136's own original base/head** (for reference, now stale):
  base `25a2e9b6b401794090151cc86006e433c8d9a789`,
  head `7946e162a383708da7f921328f14eb1acb588027`

## Branch / integration method

New branch `claude/pr-136-skillsheet-reintegration-kk6fl5`, created directly
from `origin/main` (`git checkout -B ... origin/main`) — not from PR #136's
existing branch, since that branch's history sits on the stale base.

Re-applied only the two commits that carry #132/#136's actual SkillSheet
Phase A work, via `git cherry-pick -x`, in original order:

1. `342248e1` — `feat(public-demo): SKILLSHEET-UX-2A Phase A — redesign
   SkillSheet as mobile-first sheet`
2. `7946e162` — `fix(e2e): scroll SkillSheet before asserting below-the-fold
   Phase A content` (WebKit CI fix; e2e-spec-only, no production code)

PR #136's two `docs:` commits (recording the *previous* integration's SHAs
against the now-stale base) were deliberately **not** cherry-picked — they
described a prior integration attempt that no longer applies; this report
replaces them for the current state.

## Merge-base / conflict analysis

Common ancestor of `origin/main` and PR #136's head:
`25a2e9b6b401794090151cc86006e433c8d9a789` (PR #136's own stated base). Since
that point, `main` gained 641 insertions / 109 deletions in
`public_demo_01_placeholder_screen.dart` (Issue #148 Phase 1A/1B.1/1B.2, plus
unrelated HOME work from PRs #144/#147/#150/#153/#154 and Month Guard/Recovery
Loop changes) — a large amount of unrelated churn in the *same file* #132/#136
touches.

Despite that churn, **both cherry-picks applied with zero manual conflict
resolution** (`git cherry-pick` auto-merged cleanly). This was possible
because:

- #132/#136's only edit to `public_demo_01_placeholder_screen.dart` is a
  full-body replacement of a single method, `_openSkillSheetReview`, plus one
  new import (`public_demo_skill_sheet_sheet.dart`) and one new small helper
  method (`_assignmentForOrNull`) added immediately after it.
- Issue #148 (cash forecast/status/advice, on `main`) and every other PR
  merged into `main` since the stale base touch entirely different regions of
  the file (HOME dashboard, Month Guard, Recovery Loop, monthly-close render
  blocks, dev menu) — none of them touch `_openSkillSheetReview` or add a
  competing SkillSheet entry point.
- `main`'s current `_openSkillSheetReview` was byte-for-byte identical to the
  one in PR #132/#136's merge-base, so Git's 3-way merge replaced it cleanly
  with the Phase A body.

Resulting diff vs. `origin/main` in that file is a minimal 83-line change
(-57/+83 net through cherry-pick bookkeeping, effectively the same isolated
edit #132 always was): one new import, `_openSkillSheetReview`'s body
replaced to call `PublicDemoSkillSheetSheet.show(...)`, and the new
`_assignmentForOrNull` helper. No other line in the file was touched.

**No manual conflict resolution was needed or performed.** Issue #148's
`PublicDemoCashForecast`, `PublicDemoCashStatusPresentation`, and
`PublicDemoCashAdviceSelector` (all under `lib/game/public_demo/`) are
untouched by this branch — confirmed by `git diff origin/main..HEAD` showing
no changes under `lib/game/public_demo/` at all.

## Files changed (this branch vs. `origin/main`)

```
 docs/reports/SES_ISSUE-132_Phase-A_Implementation_Result.md | 309 ++++++++++
 docs/reports/SES_ISSUE-132_WebKit_CI_Fix_Result.md          | 266 +++++++++
 e2e/tests/public-demo-fresh-start.spec.ts                   |  54 ++
 e2e/tests/public-demo-skillsheet-phase-a.spec.ts            | 192 +++++++
 lib/ui/public_demo/public_demo_01_placeholder_screen.dart   |  83 ++---
 lib/ui/public_demo/public_demo_skill_sheet_display_projection.dart | 250 ++++
 lib/ui/public_demo/public_demo_skill_sheet_sections.dart    | 368 +++++++++
 lib/ui/public_demo/public_demo_skill_sheet_sheet.dart       | 139 +++++
 test/ui/public_demo/public_demo_01_persistence_test.dart    |   7 ++-
 9 files changed, 1611 insertions(+), 57 deletions(-)
```

The two `docs/reports/SES_ISSUE-132_*` files are the original #132/#136
implementation and WebKit-fix reports, carried over unmodified as part of the
cherry-picked commits (historical record of that prior work); this file is
the new record for the present reintegration.

No file under `lib/game/`, `lib/persistence/`, or any Issue #148 file
(`public_demo_cash_forecast.dart`, `public_demo_cash_status_presentation.dart`,
`public_demo_cash_advice_selector.dart`) appears in this diff.

## Scope compliance

- ✅ SkillSheet's existing entry point, Back, Confirm, and 営業開始
  ("begin selling") semantics preserved exactly — `_openSkillSheetReview`
  still returns `confirmed == true` only on explicit confirmation, and only
  then calls `_startSkillSheetReview`; Back/dismiss returns `false`/`null`
  and leaves state untouched, unchanged from #132.
- ✅ Issue #148's `PublicDemoCashForecast`, `PublicDemoCashStatusPresentation`,
  `PublicDemoCashAdviceSelector` — untouched (verified via diff, and via their
  own test suites passing unmodified, see Tests below).
- ✅ No HOME cash-warning display, ひより advice copy, or CTA wiring added —
  this branch carries none of that (it belongs to #148 Phase 1B.3/HOME
  connection, explicitly out of scope here).
- ✅ No Phase B/C SkillSheet work added (still read-only projection only).
- ✅ `GameState`, monthly close, finance, persistence schema, sales success
  rate, and E2E mechanics untouched.
- ✅ Conflict resolution was mechanical (Git auto-merge); no manual edits,
  hence no incidental refactoring.

## Tests executed

Toolchain: this sandbox ships neither Flutter nor Dart. Flutter SDK 3.44.9
(Dart 3.12.2) was fetched locally to match the version this repo's own CI
pins (`.github/workflows/e2e.yml`, `e2e-heavy.yml`: `flutter-version:
"3.44.9"`). `pubspec.lock` was left byte-identical to the committed version
(verified via `git status` after every `pub get`).

- **`flutter analyze`** — clean, no issues (11.3s / 10.2s across two SDK
  builds tested).
- **`flutter test test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`**
  (SkillSheet flow widget test) — **2/2 passed**.
- **`flutter test test/ui/public_demo/`** (full Public Demo UI surface, 28
  files) — **215/215 passed**.
- **`flutter test test/game/public_demo/public_demo_cash_forecast_test.dart
  test/game/public_demo/public_demo_cash_status_presentation_test.dart
  test/game/public_demo/public_demo_cash_advice_selector_test.dart`**
  (Issue #148 cash forecast / status / advice-selector suites) —
  **49/49 passed**, confirming #148 is intact and unaffected by this
  reintegration.
- **Playwright, `mobile-chromium`, 360×800 and 390×800**
  (`public-demo-skillsheet-phase-a.spec.ts`, `public-demo-fresh-start.spec.ts`,
  `public-demo-single-month-cta.spec.ts` — fresh start → SkillSheet → Back →
  reopen → Confirm → sales start, plus the single-month-CTA regression at
  both widths) — **7/7 passed**, against a `flutter build web --release`
  build of this branch, using the sandbox's pre-installed Chromium
  (`/opt/pw-browsers`). No horizontal overflow at either viewport; exactly
  one month-advance CTA per HOME render at both widths.

### `dart format` — not applied to the full files (documented, not skipped silently)

`dart format --set-exit-if-changed` was run against every changed file under
both Flutter 3.44.9 (Dart 3.12.2, CI's pinned version) and 3.47.2 (Dart
3.13.2). Both flagged 3 of the 5 changed `.dart` files. Inspecting the actual
diffs (`dart format --output=show`) showed the formatter wanting to rewrite
**pre-existing, untouched code far outside this branch's diff** — e.g. ~350
reformatted lines in `public_demo_01_placeholder_screen.dart`, almost all in
`main`-inherited blocks (Month Guard, Recovery Loop, monthly-close rendering)
that this branch never edits, plus whole-`testWidgets`-block reformatting in
`public_demo_01_persistence_test.dart`. This is Dart formatter-version skew
(the checked-in code predates the "tall style" multi-line-argument formatter
that shipped in later Dart releases), not a real formatting defect in this
branch's own new/changed lines — and the repo's CI does not run `dart format
--set-exit-if-changed` as a gate (only one legacy workflow runs plain `dart
format` against one specific file, not as a check;
`.github/workflows/*.yml` was grepped to confirm). Applying the formatter
here would have meant hundreds of lines of unrelated reformatting, which the
task explicitly rules out ("競合解消のための無関係なリファクタリングをしな
い"). The new code itself (the three new `public_demo_skill_sheet_*.dart`
files' substantive logic, and the tiny hunk in `_openSkillSheetReview`) is
unmodified from the original #132/#136 commit, which reported a clean
`flutter analyze` in its own authoring environment. Left as-is; flagged here
rather than silently skipped.

## Known unverified items

- **WebKit** (`mobile-webkit` Playwright project) — **not run**. This
  sandbox has no WebKit binary and no path to install one (network policy
  scopes browser downloads to the pre-installed Chromium only). This is the
  same limitation #136's own report already flagged; **PR CI's
  `mobile-webkit` job is the required gate for this**, not a substitute
  already satisfied here.
- **Full flutter test suite** (all ~1300+ tests repo-wide) — not run in this
  pass; only the SkillSheet flow test, the full Public Demo UI surface (28
  files / 215 tests), and the three Issue #148 game-logic suites were run, as
  the task specified. `flutter analyze` (repo-wide) did run clean, which
  covers static/type-level regressions across the whole codebase.
- **`dart format` on the two touched files it flagged beyond formatter-version
  skew** — see above; not applied, to avoid unrelated reformatting. If the
  project's actual pinned formatter version differs from both SDKs tried
  here (3.44.9 / 3.47.2), a maintainer with that exact toolchain should
  re-check with `dart format --set-exit-if-changed` on just this branch's
  diff.
- **Manual/eyeball QA on a real device** — not performed; only the automated
  Playwright checks above were run.

## PR

[#157](https://github.com/perusonao/smile_enjoy_story/pull/157) — `feat(public-demo): re-integrate SkillSheet Phase A (#136) onto main with Issue #148`
branch: `claude/pr-136-skillsheet-reintegration-kk6fl5`

## Merge readiness

- Mergeable against current `main`: **yes** (branched directly from
  `origin/main` HEAD; no conflicts by construction).
- CI-equivalent local checks (analyze, targeted widget/unit tests, Chromium
  E2E at both required widths): **all green**.
- Outstanding before merge: **WebKit CI job**, per PR CI (not run locally,
  as documented above and in the original #136 report). No other blockers
  identified. Not merged, per task instructions.
