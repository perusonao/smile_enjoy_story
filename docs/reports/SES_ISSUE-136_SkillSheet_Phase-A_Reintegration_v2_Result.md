# SES Issue #136 — SkillSheet Phase A Reintegration v2 (P2 fix) — Result

## Summary

This task was scoped as "re-integrate SkillSheet Phase A onto the latest
`origin/main` and fix the P2 finding from PR #156's review." Investigation
found that **SkillSheet Phase A was already merged onto `main`** via PR #157
(merged 2026-09-03, commit `f0c0f11`, itself a clean re-application of PR
#136 / #132's work onto the `main` that already carried Issue #148 Phase
1A/1B.1/1B.2). No SkillSheet UI re-application was needed or performed.

The remaining, real work was the **P2 fix**: the review comment on PR #156
(https://github.com/perusonao/smile_enjoy_story/pull/156#discussion_r3921670930)
identified that an experienced hire's SkillSheet could show a fabricated
`実経験 0ヶ月 → SkillSheet記載 0ヶ月`, contradicting the fact that they were
hired as an experienced applicant (e.g. alongside a `Java 3年` résumé
summary). This PR fixes that root cause and re-verifies the whole SkillSheet
surface plus Issue #148's untouched suites on the current `main`.

- **Base SHA:** `9d1b9933c22da64fe7294b1ff30f8cc998725947` (`origin/main` HEAD
  at task start, already containing PR #157 / SkillSheet Phase A and Issue
  #148 Phase 1A/1B.1/1B.2)
- **Head SHA:** recorded at PR creation time (see PR description)
- **Branch:** `claude/skillsheet-phase-a-reintegration-x9iyh6`, reset from a
  stale unrelated commit directly onto `origin/main` (no rebase/merge —
  a hard reset of a branch that carried only one throwaway commit not
  otherwise referenced anywhere)

## What PR #136 / #156 / #157 actually were

- **#136**: SkillSheet Phase A re-integration onto a `main` that was already
  stale by the time of this task (predates Issue #148).
- **#156**: A second re-integration attempt, opened against a newer `main`
  (post-#148). Closed as a duplicate of #157, which was opened moments
  earlier from the same current `main` and merged. #156's own review
  produced the P2 finding this PR fixes.
- **#157**: The PR that was actually merged into `main`. Cherry-picked the
  same two commits #136 carried (`SKILLSHEET-UX-2A Phase A` +
  `fix(e2e): scroll SkillSheet…`) cleanly onto post-#148 `main`. This is why
  `lib/ui/public_demo/public_demo_skill_sheet_*.dart` and the SkillSheet
  entry point in `public_demo_01_placeholder_screen.dart` are already
  present on today's `main` — confirmed directly from `origin/main`'s
  history and file contents before any change in this session.

Per the task's own instruction not to reuse #136/#156 directly: this
session did not check out, merge, or cherry-pick either branch. It worked
from `origin/main` as-is and used #156's GitHub review thread only as the
source of the P2 finding to fix.

## P2 root cause and fix

**Root cause** — `PublicDemoEngineerRuntime.fromApplicant`
(`lib/game/public_demo/public_demo_engineer_runtime.dart`), in the branch
for `!applicant.isInexperienced` (i.e. an applicant hired as *experienced*),
unconditionally constructed the hire's `LanguageSkill` with:

```dart
displayedExperienceMonths: 0,
actualExperienceMonths: 0,
```

regardless of the applicant's own `experienceMonths` field
(`PublicDemoApplicant.experienceMonths`, default `36`,
`isInexperienced == (experienceMonths == 0)`) — the one authoritative,
domain-tracked figure Public Demo has for an applicant's real IT experience
at hire time. The SkillSheet's display projection
(`PublicDemoSkillSheetDisplayFactory` /
`PublicDemoSkillSheetExperienceComparison`) already reads
`actualExperienceMonths`/`displayedExperienceMonths` verbatim and never
merges them — the bug was entirely upstream, at hire time, not in the
projection or the UI.

**Data source confirmed authoritative**: `PublicDemoApplicant.experienceMonths`
is a required, asserted-non-negative field set at applicant generation and
carried unchanged through `copyWith`/`toJson`/`fromJson`; it is the same
field `isInexperienced`/`canEnterPreJoinSales` already gate real gameplay
decisions on. No experience value was invented — this fix only stops
discarding a value the domain already had.

**Fix applied** (this is Option 1 from the task: an authoritative source
exists, so read it into the display projection instead of fabricating an
empty state):

```dart
displayedExperienceMonths: applicant.experienceMonths,
actualExperienceMonths: applicant.experienceMonths,
```

Both fields are set from the same value because Public Demo's `Applicant`
model (unlike the full `domain/models/Applicant`/`LanguageSkill` dishonesty
model) tracks only one experience figure per applicant — there is no
separate résumé-inflation concept at this layer to preserve. `actual` and
`displayed` are **not** merged or derived from each other after this point:
`PublicDemoGrowthEngine` already grows only `actualExperienceMonths` via
assignment/training (`displayedExperienceMonths` is deliberately left
untouched — see its existing comment), so the two figures correctly diverge
over time exactly as the "経験" section's actual-vs-displayed comparison is
meant to show.

The truly inexperienced branch (`applicant.isInexperienced`,
`experienceMonths == 0`) was **not** changed — `0` there is the authoritative
truth (a junior hire genuinely has zero prior IT experience), not a
placeholder, so showing `0ヶ月` is factual and Option 2's empty state does
not apply.

### Files changed

- `lib/game/public_demo/public_demo_engineer_runtime.dart` — the fix above,
  plus an updated doc comment explaining the new behavior.
- `test/game/public_demo/public_demo_junior_runtime_test.dart` — updated the
  one test (`experienced runtime retains the established sales skill
  values`) that had locked in the old `0`/`0` behavior; it now asserts both
  fields equal the applicant's `experienceMonths` (24 in that test's
  fixture). All other tests in this file use `experienceMonths: 0`
  (genuinely inexperienced fixtures) and were already correct — unchanged.
- `docs/reports/SES_ISSUE-136_SkillSheet_Phase-A_Reintegration_v2_Result.md`
  — this report.

No other file was touched. In particular:
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`,
`public_demo_skill_sheet_sheet.dart`,
`public_demo_skill_sheet_display_projection.dart`, and
`public_demo_skill_sheet_sections.dart` are all untouched — SkillSheet's
open/back/confirm/営業開始 semantics are exactly what PR #157 already put on
`main`.

## Conflicts

None. This branch was reset directly from `origin/main`
(`9d1b9933c22d...`); the only change is the single targeted fix above, made
directly against current `main` content. Issue #148's
`PublicDemoCashForecast` / `PublicDemoCashStatusPresentation` /
`PublicDemoCashAdviceSelector` and all HOME/GameState/finance/persistence
code were not read for editing and are provably untouched (`git diff
--stat` shows only the two files listed above until this report was added).

## Tests executed

Environment note: this sandbox has no pre-installed Flutter/Dart SDK. A
Flutter 3.35.5 SDK was built locally from source (`flutter/flutter` git
tag `3.35.5`) to run these checks — CI pins `3.44.9`/`3.44.8`; the
`dart format` check below was run against the two changed source files
only, so formatter-version skew on unrelated files is not a concern here.

- `dart format` (changed files only —
  `lib/game/public_demo/public_demo_engineer_runtime.dart`,
  `test/game/public_demo/public_demo_junior_runtime_test.dart`):
  **0 files needed changes.**
- `flutter analyze` (whole repo): **No issues found.**
- `flutter test test/game/public_demo/public_demo_junior_runtime_test.dart
  test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`:
  **8/8 passed** (includes the updated P2-fix assertion and the existing
  SkillSheet open/back/confirm widget flow, unmodified and still green).
- `flutter test test/game/public_demo/` (full Public Demo domain/game
  suite, including Issue #148's own
  `public_demo_cash_forecast_test.dart`,
  `public_demo_cash_status_presentation_test.dart`, and
  `public_demo_cash_advice_selector_test.dart`): **500/500 passed.**
- `flutter test test/ui/public_demo/` (full Public Demo UI surface, 28
  files): **215/215 passed.**
- Playwright `mobile-chromium`, 360×800 and 390×800
  (`e2e/tests/public-demo-skillsheet-phase-a.spec.ts`, the existing
  SkillSheet Phase A spec): ran against a local `flutter build web
  --release` build. Both viewport runs hit the same Playwright
  `getByText('案件スキル適合')` locator timeout after scrolling — **but the
  failure screenshots captured at the moment of timeout show the target
  text (`案件スキル適合 78`, `ヒューマンスキル 70`, `モチベーション 72`,
  `取引先からの信頼 60`) fully rendered on screen with no horizontal overflow
  at either width.** This is consistent with a semantics-tree
  timing/exposure quirk of this sandbox's Chromium binary (loaded via the
  spec's existing `SES_E2E_CHROMIUM_PATH` escape hatch, since the
  Playwright-managed browser download is blocked here) rather than a real
  rendering or functional regression — this session's change does not touch
  any SkillSheet UI/rendering file. Given this, and per the task's own
  allowance, **authoritative confirmation of this spec is deferred to PR
  CI**, which runs Playwright's own matched browser build.
- WebKit (`mobile-webkit` project) and the full non-Public-Demo `flutter
  test` suite (~1300+ tests repo-wide): **not run locally** — no WebKit
  binary in this sandbox, and full-suite runtime was out of scope for the
  targeted verification requested. **Both are deferred to PR CI.**

## Unconfirmed items

- Playwright `mobile-chromium` pass/fail for
  `public-demo-skillsheet-phase-a.spec.ts` is not locally green (locator
  timeout described above); visual evidence strongly suggests it is a
  sandbox artifact, not a regression, but this is not the same as a clean
  local pass. PR CI will give the authoritative result.
- `mobile-webkit` Playwright project: not run locally at all.
- Full repo-wide `flutter test` (all suites, not just `test/game/public_demo/`
  and `test/ui/public_demo/`): not run locally; PR CI covers this.
- No manual/eyeball QA on a physical device.

## Merge readiness

Not merged by this session, per instructions. Recommend merging once PR CI
(Playwright `mobile-chromium` + `mobile-webkit`, plus the repo-wide Flutter
test suite) is green — the local evidence above (full targeted Flutter test
suites green, `flutter analyze` clean, screenshots showing correct
non-overflowing rendering) indicates a low-risk, narrowly-scoped change with
no expected CI surprises, but CI is the final gate as it was for #157.

## PR

https://github.com/perusonao/smile_enjoy_story/pull/158
