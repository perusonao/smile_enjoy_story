# SES Issue #136 — SkillSheet Phase A Reintegration v2 (P2 fix) — Result

## Round 2 update (2026-09-03) — Codex P2 on PR #158 itself

Codex reviewed PR #158 (the round-1 fix below) and found the round-1 fix
incomplete:
https://github.com/perusonao/smile_enjoy_story/pull/158#discussion_r3922332482

> For a non-Java applicant such as the existing `app-02` profile (`Flutter
> 2年 / JavaScript 3年`, `experienceMonths: 36`), the factory still hardcodes
> `primaryLanguage` and the skill-map key to Java, so these assignments now
> fabricate three years of Java experience. ... preserve structured language
> experience or show it as unavailable instead of copying the total into
> Java.

Round 1 fixed the *0-months* fabrication but introduced a second one: it
copied `PublicDemoApplicant.experienceMonths` — the applicant's **aggregate
total IT experience**, not a per-language figure — onto a `LanguageSkill`
hardcoded to `ProgrammingLanguage.java`, regardless of what language the
applicant actually has experience in. For `app-02` (résumé: `Flutter 2年 /
JavaScript 3年`), this displayed a fabricated `Java：実経験 36ヶ月 →
SkillSheet記載 36ヶ月` even though the résumé never mentions Java.

This section documents the round-2 fix, committed to the same PR #158 /
branch `claude/skillsheet-phase-a-reintegration-x9iyh6`.

- **Base SHA (round 2 start):** `70d675acd6ee0e56d61f7fe549a2c61893eaa913`
  (PR #158's HEAD at round-2 task start, i.e. round 1's fix + its own report
  commit)
- **Head SHA (round 2 end):** `031bb6651442467d1106f4a9da67221a6d8dadd0`

### Investigation: is there any confirmed per-language data to carry over?

`PublicDemoApplicant` (`lib/game/public_demo/public_demo_recruitment.dart`)
was inspected in full. It carries exactly two experience-shaped fields:

- `experienceMonths` (`int`) — one aggregate total-IT-experience figure.
- `resumeSummary` (`String`) — free narrative text, e.g. `'Flutter 2年 /
  JavaScript 3年 / 製造〜テスト'` for `app-02`, `'Java 4年 / Spring 3年 /
  基本設計〜テスト'` for `app-01`.

There is **no structured, per-language breakdown anywhere in the applicant
model** — not even for `app-01`, whose résumé happens to name Java. Parsing
`resumeSummary` to reconstruct per-language months would itself be the kind
of "按分・推測" (apportion/guess) the task's required policy explicitly
forbids, and `ProgrammingLanguage` doesn't even include Flutter/Dart as a
tracked value. **Conclusion: no confirmed per-language data exists for any
Public Demo applicant today** — the honest choice (Option 2 from both the
task brief and Codex's own comment) applies uniformly to every experienced
hire, not just non-Java ones.

### Root cause (round 2) and fix

`PublicDemoEngineerRuntime.fromApplicant`
(`lib/game/public_demo/public_demo_engineer_runtime.dart`), in the
`!applicant.isInexperienced` branch, still:

1. Hardcoded `primaryLanguage: ProgrammingLanguage.java` unconditionally.
2. Seeded `languageSkills[java]` with `displayedExperienceMonths:
   applicant.experienceMonths, actualExperienceMonths:
   applicant.experienceMonths` — the round-1 fix's fabrication.

That `languageSkills[primaryLanguage]` entry, however, is not purely
decorative: `actualCapability` (`languageSkills[primaryLanguage]
?.actualSkill`) gates `isReadyForFieldSales` — which Issue #148's
`PublicDemoCashAdviceSelector` reads — and `PublicDemoGrowthEngine` (EG-2)
keys assignment/training/waiting growth off the same
`languageSkills[primaryLanguage]` entry. Simply emptying `languageSkills`
would have reset every experienced hire's capability to `0` at hire time,
changing Issue #148's cash-advice/field-sales-readiness behavior — explicitly
out of scope for this task.

**Fix**: `PublicDemoEngineerRuntime` gains a new field,
`confirmedLanguages` (`Set<ProgrammingLanguage>`, defaults to `const {}`) —
the set of languages whose `languageSkills` entry is genuine, confirmed,
display-safe experience data, as opposed to an entry that exists only to
carry a capability number.

- `fromApplicant`'s experienced-hire branch: `languageSkills[java]` is still
  seeded with `actualSkill: applicant.salesSkillFit` (capability — unchanged,
  gates `isReadyForFieldSales`/Issue #148 exactly as before), but its months
  now stay `0` (no total-experience transcription) and `confirmedLanguages`
  stays `const {}` — this hire has no confirmed language for the SkillSheet
  to name.
- `fromApplicant`'s genuinely-inexperienced branch
  (`applicant.isInexperienced`, `experienceMonths == 0`): **unchanged**
  behavior, now made explicit via `confirmedLanguages: {java}` — the task
  requires this branch's existing display stay exactly as it was, and it
  does (0 months there is authoritative truth, not a placeholder).
- The two static migration seeds (`eng-01`, `eng-02` in
  `publicDemoInitialEngineerRuntimes`) are authored ground truth, not
  derived from any applicant — both now explicitly declare their real
  confirmed language (`java`, `javascript` respectively) so their SkillSheet
  display is provably unaffected.
- `PublicDemoSkillSheetDisplayFactory.create`
  (`lib/ui/public_demo/public_demo_skill_sheet_display_projection.dart`):
  `primaryLanguageLabel` and each `experienceComparisons` row are now only
  produced for a language present in `runtime.confirmedLanguages`. For an
  unconfirmed runtime this list is empty, and the SkillSheet UI's own
  **pre-existing** empty state
  (`lib/ui/public_demo/public_demo_skill_sheet_sections.dart`'s
  `SkillSheetEmptyState('経験年数の記録を確認できません。')`) renders instead —
  no new UI text was introduced; the same honest "not confirmed" pattern the
  sheet already uses elsewhere (abilities, tech skills, industry experience,
  career history) now covers this case too.
- `confirmedLanguages` is also persisted (`toJson`/`fromJson`) so it survives
  save/load. Backward compatibility: a save written before this field
  existed has no `confirmedLanguages` key; `fromJson` defaults the missing
  key to `{primaryLanguage}` — i.e. it reproduces exactly what that save was
  already displaying before this fix, so no existing save's SkillSheet
  content changes retroactively. Only a *newly created* runtime (via
  `fromApplicant`'s experienced-hire branch) now deliberately withholds
  confirmation.

Net effect: the applicant's real résumé text (`resumeSummary`) is still
shown verbatim in the "経歴・スキル要約" section exactly as before — nothing
about the honest, unstructured résumé display changed. What changed is that
the SkillSheet no longer restructures that free text into a fabricated,
falsely-precise per-language months figure.

### app-02 proof (required regression case)

`app-02` (`田中 美咲`, `resumeSummary: 'Flutter 2年 / JavaScript 3年 /
製造〜テスト'`, `experienceMonths: 36`, `salesSkillFit: 62`) is now asserted,
end to end from `PublicDemoEngineerRuntime.fromApplicant` through
`PublicDemoSkillSheetDisplayFactory.create`, in
`test/ui/public_demo/public_demo_skill_sheet_display_projection_test.dart`:

- `data.primaryLanguageLabel` is `null` — no "Java" chip.
- `data.experienceComparisons` is empty — no fabricated "Java：実経験
  36ヶ月 → SkillSheet記載 36ヶ月" row.
- `data.summaryChips` contains no "Java"-mentioning entry.
- `data.summaryText` equals the applicant's real `resumeSummary` verbatim
  (Flutter/JavaScript wording preserved, not discarded).
- `runtime.actualCapability == applicant.salesSkillFit` (62) — the
  field-sales/Issue #148 gating value is untouched by this display-only fix.
- A widget-level test renders the real `PublicDemoSkillSheetSheet` for
  `app-02` at both 360px and 390px width: no exception (i.e. no
  `RenderFlex` overflow), no literal "Java" text anywhere, and the sheet's
  own empty-state text appears in the "経験" section once expanded.

A companion test proves this isn't Java-specific special-casing: `app-01`
(résumé literally says `'Java 4年'`) gets the **same** empty state, because
its "Java" is free-text narrative, not confirmed structured data — while a
genuinely inexperienced applicant and the `eng-01` static seed both keep
their pre-existing confirmed displays exactly as before.

### Files changed (round 2)

- `lib/game/public_demo/public_demo_engineer_runtime.dart` — adds
  `confirmedLanguages`; `fromApplicant`'s experienced-hire branch no longer
  transcribes `experienceMonths` onto Java and no longer confirms it;
  `publicDemoInitialEngineerRuntimes` (`eng-01`/`eng-02`) explicitly declare
  their genuine confirmed language.
- `lib/ui/public_demo/public_demo_skill_sheet_display_projection.dart` —
  `primaryLanguageLabel`/`experienceComparisons` now filter on
  `runtime.confirmedLanguages`.
- `test/game/public_demo/public_demo_junior_runtime_test.dart` — updates the
  one test that had locked in round 1's fabricated-months behavior.
- `test/ui/public_demo/public_demo_skill_sheet_display_projection_test.dart`
  (new) — the app-02 regression case above, plus the app-01/inexperienced/
  eng-01 comparison cases.

No other file was touched.
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`,
`public_demo_skill_sheet_sheet.dart`, `public_demo_skill_sheet_sections.dart`,
GameState, finance, the save schema (beyond the additive, backward-compatible
`confirmedLanguages` key described above), HOME, and Issue #148's cash
forecast/advice logic are all untouched — confirmed both by not having
opened those files for editing and by every Issue #148/HOME/finance test in
`test/game/public_demo/` and `test/ui/public_demo/` staying green (see Tests
below).

### Tests executed (round 2)

Flutter 3.44.8 (stable), matching this repo's CI pin
(`.github/workflows/public-demo-validation.yml` /
`public-demo-preview.yml`), was downloaded directly from Google's Flutter
release archive for this sandbox — no build-from-source needed this round.

- `dart format` (all four changed/new files, `--set-exit-if-changed`): **0
  files needed changes.**
- `flutter analyze` (whole repo): **No issues found.**
- `flutter test test/game/public_demo/public_demo_junior_runtime_test.dart
  test/game/public_demo/public_demo_engineer_runtime_test.dart
  test/game/public_demo/public_demo_applicant_experience_test.dart
  test/ui/public_demo/public_demo_skill_sheet_display_projection_test.dart
  test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`:
  **22/22 passed** (includes the app-02/app-01/inexperienced/eng-01 cases
  and the existing SkillSheet open/back/confirm/営業開始 widget flow,
  unmodified and still green).
- `flutter test test/game/public_demo/` (full suite, incl. Issue #148's
  `public_demo_cash_forecast_test.dart`,
  `public_demo_cash_status_presentation_test.dart`,
  `public_demo_cash_advice_selector_test.dart`, and the save-schema-invariant
  `public_demo_recovery_aggregate_test.dart`): **500/500 passed.**
- `flutter test test/ui/public_demo/` (full Public Demo UI surface, re-run
  with the final file state including the new
  `public_demo_skill_sheet_display_projection_test.dart`): **221/221
  passed.**
- 360px/390px SkillSheet display: confirmed via a Flutter widget test
  (`public_demo_skill_sheet_display_projection_test.dart`) that pumps the
  real `PublicDemoSkillSheetSheet` for `app-02` at `Size(360, 800)` and
  `Size(390, 844)` — no exception (no overflow), no fabricated "Java" text.
- Playwright `mobile-chromium`/`mobile-webkit` (`e2e/tests/public-demo-
  skillsheet-phase-a.spec.ts`) and the full repo-wide (non-Public-Demo)
  `flutter test` suite: **not run locally this round** — this sandbox has no
  Playwright-managed browser download and round 1 already found this
  sandbox's Chromium had a semantics-tree timing quirk unrelated to actual
  rendering. This round's change is also SkillSheet-display-only (same
  files round 1 touched, no new UI/layout structure), and 360px/390px
  overflow-freedom is independently confirmed by the widget test above.
  **Deferred to PR CI**, which runs Playwright's own matched browser build,
  per the task's own instruction.

### Unconfirmed items (round 2)

- Playwright `mobile-chromium`/`mobile-webkit` for
  `public-demo-skillsheet-phase-a.spec.ts`: not run locally this round: PR
  CI is authoritative.
- Full repo-wide `flutter test` (all suites, not just `test/game/public_demo/`
  and `test/ui/public_demo/`): not run locally; PR CI covers this.
- No manual/eyeball QA on a physical device.

### Merge readiness (round 2)

Not merged by this session, per instructions. Round 2 is committed to the
same PR #158 (no new PR opened). Recommend merging once PR CI is green —
local evidence (all targeted and full Public Demo suites green, `flutter
analyze` clean, a real widget-level 360px/390px render of the exact
regression case with no exception and no fabricated text) indicates a
narrowly-scoped, low-risk, display-only change.

### PR

https://github.com/perusonao/smile_enjoy_story/pull/158
(same PR as round 1 — no new PR opened for round 2, per instructions.)

---

## Round 1 (original) report

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
