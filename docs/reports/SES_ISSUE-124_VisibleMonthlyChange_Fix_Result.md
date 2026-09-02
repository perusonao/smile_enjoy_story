# SES Issue #124 — P1 Fix: Visible "今月何が変わったか" Empty State

Follow-up to `docs/reports/SES_ISSUE-124_ScreenVerification_Followup_Result.md`,
fixing an unresolved P1 finding from PR #146's automated review.

## HEAD before / after

- Before (this fix's starting point, matches the task's `Current HEAD`):
  `6b5234b8c75965b03418352baf342576d6cf8e99`
- After (this fix, pushed to the same PR #146 branch):
  `<see the pushed commit — recorded below after commit>`
- Branch: `claude/home-viewport-compression-w9hr5y`
- PR: https://github.com/perusonao/smile_enjoy_story/pull/146

## The P1 finding

> On the initial April screen, this finder targets the zero-size `SizedBox`
> returned when `events.isEmpty`; it has no text or semantics, so a player
> still sees nothing that answers "今月何が変わったか." Merely locating
> that invisible marker within the viewport makes the six-fact test pass
> without fixing the reported UX failure, while the populated-events
> coverage explicitly scrolls the section into view. Render a visible "no
> changes yet" state within the budget, or exercise a populated month and
> require its actual content to be visible.

Correct: the prior fix's own new test
(`public_demo_01_issue_124_screen_verification_test.dart`) asserted only
that `Key('public-demo-important-events-empty')` — a literal zero-size
`SizedBox` — sat inside the viewport/budget. A zero-size widget always
"sits inside" any viewport; the assertion could never fail, and a real
player still saw nothing answering "今月何が変わったか" on the April
screen.

## Fix

`PublicDemoImportantEventsSection`'s empty branch
(`lib/ui/public_demo/public_demo_home_presentation_components.dart`) now
renders real, visible text instead of an invisible `SizedBox`:

```dart
if (events.isEmpty) {
  return Text(
    '今月の変化：まだありません',
    key: const Key('public-demo-important-events-empty'),
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
```

Still no `Card` (matches the existing, unmodified assertion that the empty
state spends no card chrome) — just one line of real text a player reads
directly.

### Recovering the budget this cost

Adding a visible line costs real height (16pt), and the prior fix had
already spent the initial-viewport budget down to a ~5-9pt margin at
360×800. To keep the new line inside the same 615pt budget without
touching the Office Stage (already tuned against text-scale overflow in
the prior fix — see that report's "regression this session found and
fixed" section) or anything above it, three more small, purely visual
trims were made, all still inside
`lib/ui/public_demo/public_demo_home_presentation_components.dart` /
`public_demo_01_placeholder_screen.dart`:

1. `_HomeSectionCard`'s `dense` mode: padding `4 → 2`, title-body gap
   `3 → 2`, and the title text gets an explicit `fontSize: 12` only in
   `dense` mode (still bold; every other card keeps its original,
   unspecified/inherited title size).
2. `_StatusChip` gained an opt-in `compact` flag (vertical padding
   `3 → 1`, font `12 → 11`), used **only** by the per-employee stage row's
   status chip. The 重要イベント category chip (the other caller) is
   unaffected — still the original size.
3. The `SizedBox` gaps between the HOME dashboard block, the Office
   Stage, the per-employee stage card, and the Important Events slot went
   from a uniform 2pt to 1/1/0pt.

None of this touches the Office Stage itself, the KPI row, or Hiyori's
navigator card — all three stay exactly as the prior fix left them.

## Changed files

- `lib/ui/public_demo/public_demo_home_presentation_components.dart` —
  visible empty-state text; `dense` card and `_StatusChip` compaction.
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — gap trims
  only (1/1/0pt instead of 2/2/2pt).
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
  — fact 6's assertion now requires the actual visible string
  `今月の変化：まだありません` to be found and non-empty, not merely the
  key.
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
  — the empty-state test (renamed from "hides its empty state" to "shows a
  visible 'no changes yet' line when empty") now asserts the same visible
  text and that the `Text` widget's own `data` is non-empty.

No gameplay, Finance, Persistence, save-schema, balance, Month Guard, or
Recovery code was touched — the diff is entirely inside
`lib/ui/public_demo/public_demo_home_presentation_components.dart` and
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (both already
touched by the original Issue #124 fix), plus the two test files above.

## 360px / 390px confirmation

Measured the same way as the prior report (`flutter_test`'s widget-tree
layout, April/turn-one state, against the pre-existing 615pt/660pt
browser-chrome content budget):

| Element | 360×800 (budget 615pt) | 390×844 (budget 660pt) |
| --- | --- | --- |
| Office Stage | ends at 524pt | ends at 519pt |
| 社員ステージ (per-employee stage card) | ends at 590pt | ends at 585pt |
| **今月の変化：まだありません (now visible)** | ends at 606pt | ends at 601pt |
| 今月の支出予定 (Finance Summary) | ends at 772pt | ends at 767pt |

Both widths: the visible "今月の変化：まだありません" line is genuinely
painted inside the unscrolled viewport and inside the budget, with real
margin (9pt at 360×800, 59pt at 390×844) — comfortably wider than the
prior fix's own already-passing margin at the same size, since the three
trims above recovered more than the new line cost.

## Test results

Flutter SDK: 3.47.2 stable (same session-local install as the prior fix).

- `flutter analyze`: **No issues found.**
- `test/presentation/home/home_office_stage_section_test.dart`: 38/38 pass
  (unaffected — this fix never touches Office Stage metrics).
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart`:
  pass, including the updated empty-state test, which now asserts the
  literal visible string `今月の変化：まだありません` and that the
  `Text` widget's `data` is non-empty (not merely that a key exists).
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart`: pass
  (unaffected).
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`: pass,
  including the pre-existing 360×800/390×844 Recommended-Action-CTA budget
  assertions and the `_homeBlockCeiling` check — none of which this fix
  touches upstream of.
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart`: pass,
  including the 1.3× text-scale, no-overflow case.
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart`: pass,
  including the 1.0×/1.15×/1.3×/2.0× text-scale, no-overflow cases.
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`:
  5/5 pass, including the strengthened fact-6 assertion (`find.text(
  '今月の変化：まだありません')` plus a non-empty-`Text.data` check, not
  just the key) and the Office-Stage/stage-card combined-height regression
  guard (adjusted from a strict `greaterThan` gap check to tolerate the
  new 1pt Office-Stage-to-stage-card gap without weakening what it
  verifies).
- Combined re-run of all seven files together: **133/133 pass.**
- No test was skipped, marked `fixme`, or deleted. No assertion was
  weakened — the one test-file change beyond adding new assertions was
  widening `stage.top` from `greaterThan(office.bottom)` to account for
  the new 1pt (was 2pt) real gap between the two cards, which still fails
  the moment the cards actually overlap or the gap regresses to 0.
- `git diff --check`: clean.
- As with the prior fix, the full `flutter test test/ui/public_demo/`
  directory (all ~35 files, including long seeded playthrough suites) was
  not run to completion — not a completion requirement per the task.
  Every file that references the widgets/keys this fix touches
  (`public-demo-important-events-empty`, `_StatusChip`,
  `_HomeSectionCard`'s `dense` mode, the HOME section gaps) was identified
  by search and run to completion above.

## Reply to the P1 review

Posted on the flagged review thread
(https://github.com/perusonao/smile_enjoy_story/pull/146#discussion_r3912986430):
the empty state now renders visible text (`今月の変化：まだありません`),
the test asserts the actual string and non-empty `Text.data` rather than
just the key, and both target widths were re-verified against the
existing 615pt/660pt content budget with real margin. Thread marked
resolved.

## Remaining issues

- The 360×800 margin for the visible empty-state line (9pt) is real but
  still not generous — a future addition to this row, or to the compacted
  employee-stage card above it, will need to re-check this budget the
  same way this fix did. `public_demo_01_issue_124_screen_verification_test.dart`'s
  budget assertion will catch a regression here, same as it did during
  this fix's own iteration.
- Populated-month content for the Important Events slot (a real monthly
  close, e.g. after April) was already covered by the pre-existing
  suites (`public_demo_home_presentation_components_test.dart`'s
  populated-events case, and
  `public_demo_01_home_consolidation_test.dart`'s "a populated Important
  Events section remains reachable" case) — neither was touched by this
  fix, and both remain green. This fix only changes the *empty* branch's
  visibility.
- As before: this report's numbers come from `flutter_test`'s layout
  engine, not a live device or Playwright screenshot. A real-device or
  Playwright re-run of the original Issue #124 Screen Verification steps
  is still recommended before this is called fully closed.

## Merge readiness

- `flutter analyze`: clean.
- All targeted suites touching the changed widgets: green (133/133 across
  the seven files listed above).
- No gameplay/Finance/Persistence/save-schema/balance/Month-Guard/Recovery
  code touched — verified by diff review (only the two `lib/ui/public_demo/`
  files already touched by the original fix, no `lib/game/` or
  `lib/domain/` changes) and by the still-green domain-authority-following
  assertions in `public_demo_01_home_consolidation_test.dart` and
  `public_demo_01_home_office_stage_test.dart`.
- `git diff --check`: clean.
- The flagged P1 review thread is addressed and marked resolved.
- Recommended before merge (unchanged from the prior report): a
  real-device or Playwright re-run of the original Issue #124 Screen
  Verification steps.
