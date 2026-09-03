# SES First Fun Year P0-1 — Monthly Guidance (July-March) — Result

Status: **Implemented, not yet CI-verified** (no Flutter/Dart SDK available in
this remote execution environment — see "Unresolved items").

## Base / HEAD

- Start `origin/main` SHA: `fec518aa556973733b5b867055d9b374adb981a7`
- Code change commit SHA: `81c8e03ca154e6ddcc67ce566ae4ff31432c3941`
- Final branch HEAD SHA (this report's own commit, on top of the code
  change): see "Commit SHA" section below.
- Branch: `claude/ses-monthly-guidance-7-3-9rkoa5`

The branch pre-existed with one stale commit (`f4ca78f`, "Phase 0A/0B: SES
domain models and random generators") that was already an ancestor of
`origin/main` (i.e. already merged/superseded upstream). Per the merged-PR
restart rule, the branch was reset to `origin/main` before starting new work,
so this PR's diff is exactly the two files listed below.

## Correspondence to Issue #125

Issue #125 ("PUBLIC-DEMO-MONTHS-1A: add truthful month-specific guidance for
September-February") asked for truthful, month-specific fallback guidance for
Public Demo's late-year months, reusing only existing visible state/mechanics,
never outranking existing Recommended Action candidates, and never reopening
an unreachable recruiting/media path. The task prompt for this session widened
the literal month range to July-March (9 months: internal months 7-15) to
match the "9月〜2月が単なる週送り期間にならない" / all-of-second-half framing in
`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`, so July and August are
included alongside Issue #125's named September-February range. All of Issue
#125's constraints (truthfulness, no new mechanics, Recommended Action
precedence unchanged, no reopened dead recruiting paths) were applied
uniformly across all nine months.

## What changed

Only `_monthGoalTextFor` in
`lib/presentation/home/models/home_dashboard_display_data.dart` was widened.
This function is a pure `switch (month) => String` table; before this change
every month from 7 (July) through 15 (March) fell through to the same `_`
case:

```
今月の経営状況を確認し、翌月への準備をしましょう
```

That fallback is what HOME's single recommended-action slot renders via
`HomeRecommendedActionNone` — i.e. **only** when the owner
(`PublicDemo01PlaceholderScreen`) found no higher-priority Recommended Action
candidate for the current month (see `HomeRecommendedActionKind`'s
presentation-priority bands in `home_recommended_action.dart`). Nothing about
selection, ranking, or eligibility of the recommended-action slot itself was
touched — this PR only changes what text shows in the one case where nothing
else already outranks it.

### Months changed and guidance summary

| Month (internal) | Calendar | New fallback text | Grounding |
|---|---|---|---|
| 7 | July | 夏季賞与の対応を終えたら、待機中の技術者がいれば案件復帰できないか確認しましょう | Recovery window opens in July (`PublicDemoRecoveryEligibility.firstEligibleMonth == 7`); summer bonus itself is a higher-priority Recommended Action (`summerBonusDecision`) while undecided, so this only shows once that's already resolved. |
| 8 | August | 今月の営業活動の状況と、待機中の技術者がいないか確認しましょう | Generic but truthful nudge toward the always-visible `salesRemaining`/waiting-headcount facts; deliberately does **not** mention recruitment media (see below). |
| 9 | September | 下半期に入りました。資金の増減と案件の稼働状況を見直しましょう | Calendar-position framing ("下半期") + cash (`cash`) and assignment (`assignedEmployeeCount`) awareness, both already-projected fields. |
| 10 | October | 案件の稼働状況を確認し、待機中の技術者がいれば案件復帰を検討しましょう | Mid-Recovery-window reminder (month 10 is inside `PublicDemoRecoveryEligibility`'s July-February range). |
| 11 | November | 資金の増減を確認し、年度末までの運転資金を意識しましょう | Cash/runway awareness using the existing `cash` field. |
| 12 | December | 年内最後の月です。ここまでの稼働状況と資金の推移を振り返りましょう | Calendar-position framing (last calendar-year month) + look-back framing consistent with `DEVELOPMENT_PLAN.md` §3.4's "less tutorial intervention" guidance strength. |
| 13 | January | 年度末まで残り3か月。案件と待機中の技術者の状況を点検しましょう | Fiscal-year-end countdown, matching `DEVELOPMENT_PLAN.md` §3.5's "Survive your first year — N weeks remaining" framing, without inventing a week counter this projection cannot compute. |
| 14 | February | 待機中の技術者を案件へ戻せる最後の月です。復帰できないか確認しましょう | Last-chance framing: `PublicDemoRecoveryEligibility.lastEligibleMonth == 14` — truthfully the final month Recovery is reachable. |
| 15 | March | 年度末の月です。今月の締めで一年間の経営結果が確定します | March (internal month 15) is the fiscal year's last close (`PublicDemoState.completeFiscalYear`); this only renders when `fiscalYearCompleted` is still false (the slot is suppressed entirely once terminal — see below), so it never mis-describes an already-closed year. |

April (4), May (5), June (6) were **not** changed — verified unchanged both by
diff and by a dedicated regression test (see Tests below).

### Existing authority/state reused (nothing new)

- `PublicDemoState.cash`, `.engineersWaiting`/`.engineersAssigned` (via the
  already-existing `waitingEmployeeCount`/`assignedEmployeeCount` projection
  fields), `.salesRemaining` — all pre-existing, already-projected facts.
- `PublicDemoRecoveryEligibility.firstEligibleMonth` (7) /
  `.lastEligibleMonth` (14) — existing constants, referenced only in doc
  comments/reasoning, not as new runtime logic.
- `PublicDemoState.completeFiscalYear`'s month-15 boundary — existing.
- `HomeRecommendedActionKind` presentation-priority bands
  (`summerBonusDecision`, `raiseRequest`, `recoveryAssignment`,
  `cashShortageResponse`) — read only to confirm this fallback text is never
  shown when one of those already-higher-priority actions is eligible; their
  ranking/eligibility itself is untouched.
- `HomeRecommendedActionSuppressed` (terminal financial status or completed
  fiscal year) — untouched; the whole recommended-action slot, including this
  fallback, is already suppressed there by existing code, so no new
  terminal-state handling was needed or added.

### Deliberately NOT referenced (to avoid reopening a dead path)

Investigated and confirmed before writing any July-September text:

- Recruitment media's own card (`_RecruitmentMediaCard`) is rendered only in
  the month-5 branch of `PublicDemo01PlaceholderScreen.build()` — it never
  renders again in July or August, and no code path past
  `PublicDemoState.advanceToJune` (month 5→6) ever increases `engineerCount`.
  So a July/August/September line that told the player to "finish hiring"
  would point at a structurally unreachable action — exactly what Issue #125
  says not to do. None of the nine new lines mention recruitment/hiring.
- There is no per-month assignment-renewal decision in Public Demo 0.1: an
  assigned engineer stays on the same project through fiscal year end
  (`PublicDemoWorkflowState`'s documented
  "一度案件参画が成立した社員は、第1期終了まで同じ案件へ継続参画する" rule). None of the
  nine lines mention "更新"/renewal.

## Impact on game/domain/finance/save

None. `PublicDemoState`, `PublicDemoAggregate`, `PublicDemoWorkflowState`,
finance/accounting formulas, `PublicDemoMonthGuard`, save schema/codec, and
`HomeRecommendedActionKind`'s selection/priority logic are all untouched.
The only production diff is a `String` table keyed by `int month` inside a
pure presentation projection (`HomeDashboardDisplayData`) that already existed
for months 4-6; this PR only adds more cases to the same existing `switch`.

## Changed files

- `lib/presentation/home/models/home_dashboard_display_data.dart` — widened
  `_monthGoalTextFor` from a 3-case + fallback switch to a 12-case (4-15) +
  fallback switch, plus an expanded doc comment explaining the reasoning
  above.
- `test/presentation/home/home_dashboard_display_data_test.dart` — added:
  - one test per month 7-15 asserting its exact expected text and that it is
    not the old generic fallback string,
  - one test asserting all nine months' texts are pairwise distinct,
  - one test asserting none of the nine months' texts contain 求人/採用/更新
    (guards against reopening the recruitment/renewal dead path),
  - one regression test confirming months 4/5/6 keep their pre-existing text
    unchanged.

No changes were made to `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
— not needed, since it already reads `monthGoalText` from the existing
projection without its own switch (per the file's own HOME-RUNTIME-2A history).

## Tests

Focused tests added/reviewed (not run locally — see Unresolved items):

- `test/presentation/home/home_dashboard_display_data_test.dart` — the four
  new test groups described above (13 individual `test()` cases: 9 per-month
  + distinctness + no-dead-path guard + April-June regression, some grouped).
- Confirmed by reading (not by re-running) that no other test file pins the
  old generic fallback string or a July-March `monthGoalText` value that this
  change would break:
  `grep -rn "今月の経営状況を確認し|monthGoalText" test/` shows only
  `home_dashboard_display_data_test.dart` (this PR's own new/updated
  assertions), `home_recommended_action_test.dart` (uses an unrelated empty
  `monthGoalText: ''` fixture, untouched), and
  `public_demo_01_home_consolidation_test.dart` (pins only April's and May's
  text, both unchanged by this PR).

## `flutter analyze` result

**Not run.** This remote execution environment has no Flutter or Dart SDK
installed (`flutter`/`dart` are not on `PATH` and no SDK directory was found
anywhere under `/`, confirmed by an explicit search). The diff was reviewed
manually instead:

- The widened `switch` keeps the exact same `String _monthGoalTextFor(int
  month) => switch (month) { ... }` shape as before, only with more `int =>
  String` arms — no new syntax construct.
- All added doc-comment cross-references to symbols not imported in this file
  (`HomeRecommendedActionNone`, `PublicDemoRecoveryEligibility`, etc.) use
  backtick code-spans, not `[Bracket]` dartdoc links, to avoid an unresolved-
  reference issue; the only bracket reference this change would have added
  (`[HomeRecommendedActionNone]`) was corrected to a backtick before
  finalizing.
- Every new/edited string literal was checked for balanced quotes/braces by
  reading the file back in full after editing.

Per this task's own instructions, full `flutter test`/`flutter analyze`/
Playwright verification is left to PR CI rather than being run repeatedly
locally — this is consistent with that instruction, but is also the actual
reason no local run could be attempted at all in this environment.

## Unresolved items / known issues

- **`flutter analyze` and the focused tests above have not actually been
  executed** in this session — there is no Flutter/Dart SDK in this remote
  container. This is a genuine gap versus the task's "最後: flutter analyze +
  関連focused tests" instruction, not a deliberate skip. CI on the PR is the
  first real execution of both. If CI reports a failure (e.g. a typo-level
  syntax issue this manual review missed), it should be fixed in a follow-up
  commit on this same branch/PR.
- The nine July-March lines are static per-month text (no per-instance
  conditionals on the player's actual `cash`/`waitingEmployeeCount` values,
  matching the existing style of the April-June entries) — they name real,
  always-true mechanic boundaries (Recovery's window, March's close) rather
  than reflecting the current run's specific numbers. This was a deliberate
  scope choice to fit the 2-3 hour budget and match the existing code's own
  pattern; a future task could make the text dynamically reference the
  player's actual waiting-employee count if desired.

## Push status

Committed locally (see commit SHA below); pushed to
`origin/claude/ses-monthly-guidance-7-3-9rkoa5` — see the accompanying final
chat response for confirmation status at the time this report was written.

## Commit SHA

- Code change: `81c8e03ca154e6ddcc67ce566ae4ff31432c3941`
- This report (final branch HEAD at push time): committed on top of the code
  change commit above; see the PR's commit list / `git log` on
  `claude/ses-monthly-guidance-7-3-9rkoa5` for its exact SHA.

## PR / Merge readiness

PR to be opened against `main` from `claude/ses-monthly-guidance-7-3-9rkoa5`.
**Not merge-ready without CI confirmation**: `flutter analyze` and the focused
tests listed above have not been executed in this environment (see Unresolved
items). The change itself is small, additive, and scoped to a single
presentation-layer `switch` plus its focused tests, with no touch to
game/domain/finance/save/navigation authority.
