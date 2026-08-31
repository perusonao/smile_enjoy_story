# SES_ISSUE-132_Phase-A_Implementation_Result

## STATUS

Complete (Phase A only).

## RESULT

SkillSheet-UX-2A Phase A shipped: the #117 SkillSheet `AlertDialog` was
replaced with a mobile-first bottom sheet (`PublicDemoSkillSheetSheet`) that
reads like a compact sales document — header, quick-glance summary band, and
five accordion detail sections — built entirely from a new read-only display
projection over existing Public Demo domain/runtime data. No Domain
authority, save schema, finance, sales rule, or month-progression code was
touched. Every #117 key, label, and return-value semantic is preserved
unmodified, verified by the pre-existing #117 widget test and Playwright
spec passing without modification, plus a new Playwright spec exercising the
full flow at 360px and 390px with zero horizontal overflow at every
checkpoint.

## SCOPE

Phase A only: UI/layout redesign and display projection of existing domain
data. Explicitly excluded (per instructions) and not implemented:

- career history Domain additions
- qualification/certification Domain additions
- save schema changes
- finance/month-progression/summer-bonus/April-restart/normal-game/sales-rule
  changes
- SkillSheet "盛り" (inflation) gameplay logic
- Phase B/C editable SkillSheet, actual-vs-displayed gameplay effects, Company
  Trust/interview/probability changes

## BASE SHA

`53ea69e725d960872f20adb9046824e9e7ab526d` (origin/main HEAD at session
start — matches the known merge commit for #133/PR #134; the
`claude/issue-132-skillsheet-phase-a-eucg0b` branch was found parked at a
stale, pre-#117 ancestor commit with no unique commits of its own, so it was
reset to this SHA before any work began, per the branch-recovery instructions).

## HEAD SHA

See this branch's own `git log -1` for the exact commit containing this
report (recorded as part of the same commit that adds this file).

## BRANCH

`claude/issue-132-skillsheet-phase-a-eucg0b`

## CURRENT DATA USED

All fields below are read verbatim from existing authoritative Public Demo
sources — nothing was added to any Domain model:

| Displayed field | Authoritative source |
|---|---|
| Employee name | `PublicDemoEngineerSales.name` |
| Current status | `engineerStatus(engineer)` (existing status-label switch, unchanged) |
| 経歴・スキル要約 (career/skill summary) | `PublicDemoEngineerSales.summary` |
| 案件スキル適合 / ヒューマンスキル / モチベーション / 取引先からの信頼 | `PublicDemoEngineerSales.interviewProfile` (`PublicDemoInterviewProfile`) |
| 主要言語 (primary language) | `PublicDemoEngineerRuntime.primaryLanguage` |
| 技術スキル chips (DB/Network/Infra/Frontend/Backend/Leader/Manager) | `PublicDemoEngineerRuntime.techSkills` (`TechSkillLevels`) |
| 実経験 vs SkillSheet記載 (per language) | `LanguageSkill.actualExperienceMonths` vs `LanguageSkill.displayedExperienceMonths` — kept as two distinct fields, never merged, per the explicit instruction |
| 業界経験 (industry experience) | `PublicDemoEngineerRuntime.industryExperience` |
| 案件経歴 (career history) | `PublicDemoEngineerRuntime.careerHistory` (currently always empty in Public Demo — renders the empty state; the row/card structure is defined and ready for when it is populated) |
| 特性 (ability chips) | `PublicDemoEngineerRuntime.abilities` |
| 案件/参画情報 (current assignment) | `PublicDemoAssignment` (looked up by engineer id from `workflow.assignments`; null in the normal SkillSheet-review case — renders an explicit empty state) |

`actualExperienceMonths` and `displayedExperienceMonths` are surfaced as two
separate numbers in the 経験 section (`実経験 X → SkillSheet記載 Y`) and are
never combined into a single value, per the explicit warning in the task.

Fields the current Public Demo model has no authoritative source for
(certifications/learning, desired role/preferences) are **not shown** rather
than fabricated — see PHASE B/C DEFERRED ITEMS.

## NEW UI STRUCTURE

Three new files under `lib/ui/public_demo/`, kept separate from the parent
screen exactly as requested:

- **`public_demo_skill_sheet_display_projection.dart`** — pure, read-only
  data classes (`PublicDemoSkillSheetDisplayData` and friends) plus
  `PublicDemoSkillSheetDisplayFactory.create(...)`, which maps
  `PublicDemoEngineerSales` + `PublicDemoEngineerRuntime?` +
  `PublicDemoAssignment?` into UI-only display fields. No gameplay
  computation, no write-back to `PublicDemoAggregate`.
- **`public_demo_skill_sheet_sections.dart`** — stateless presentation
  widgets: header facts, summary band (`SkillChip`/`SkillChipRow`, reusing
  the existing `lib/ui/widgets/skill_chip.dart`), the collapsible `_Section`
  wrapper (`ExpansionTile` with `maintainState: true`), and the five section
  bodies (基本プロフィール / 技術スキル / 経験 / 案件・参画情報 /
  営業・面談プロフィール), each with an explicit empty state when its data is
  absent.
- **`public_demo_skill_sheet_sheet.dart`** — `PublicDemoSkillSheetSheet`, the
  `showModalBottomSheet`-based replacement for the #117 `AlertDialog`.
  Height-bounded (90% of viewport) with an internally scrolling body and a
  `SafeArea`-wrapped sticky bottom CTA row (戻る / 内容を確認) that never
  scrolls off screen.

The `営業・面談プロフィール` section is `initiallyExpanded: true` (matching
its always-visible #117 predecessor exactly); all sections use
`maintainState: true` so collapsed content stays mounted rather than being
removed from the tree.

## CHANGED FILES

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — **net −31
  lines** (26 insertions / 57 deletions). Only `_openSkillSheetReview`'s body
  was replaced (now calls `PublicDemoSkillSheetSheet.show(...)`), one import
  added, and one small `_assignmentForOrNull` helper added. No other method,
  call site, key, or command changed.
- `lib/ui/public_demo/public_demo_skill_sheet_display_projection.dart` (new)
- `lib/ui/public_demo/public_demo_skill_sheet_sections.dart` (new)
- `lib/ui/public_demo/public_demo_skill_sheet_sheet.dart` (new)
- `e2e/tests/public-demo-skillsheet-phase-a.spec.ts` (new) — 360px/390px
  verification spec, see PLAYWRIGHT RESULT.
- `test/ui/public_demo/public_demo_01_persistence_test.dart` — one-line
  timing fix in the shared `_tapAction` helper (`pump()` → `pumpAndSettle()`
  before locating the confirm button), required by the intentional
  AlertDialog → showModalBottomSheet transition change; see TEST RESULTS.
- `docs/reports/SES_ISSUE-132_Phase-A_Implementation_Result.md` (new, this
  file).

No other file was touched. `public_demo_01_placeholder_screen.dart`'s diff
is small and localized specifically to reduce merge-conflict risk with #118
on its sibling branch.

## #117 COMPATIBILITY

All #117 keys/labels/semantics preserved verbatim:

- Root key: `public-demo-skill-sheet-<id>`
- Back/cancel key: `public-demo-skill-sheet-cancel-<id>` (text `戻る`)
- Confirm key: `public-demo-skill-sheet-confirm-<id>` (text `内容を確認`)
- `Navigator.pop(context, true)` only from explicit confirm; `false` from
  Back; `null` on barrier dismiss — the caller treats `false`/`null`
  identically as "do not advance," unchanged.
- Labels preserved exactly: `経歴・スキル要約`, `営業・面談プロフィール`,
  `案件スキル適合`, `ヒューマンスキル`, `モチベーション`, `取引先からの信頼`,
  and the `engineer.summary` text.

Verified by running `test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`
(the #117 widget test) **unmodified** — both cases pass. Also verified by
running `e2e/tests/public-demo-fresh-start.spec.ts` (the #117 Playwright
spec) **unmodified** — passes.

## 360PX RESULT

Pass. `e2e/tests/public-demo-skillsheet-phase-a.spec.ts` at 360×800: fresh
start → HOME → Sato SkillSheet → real-data content verified → 技術スキル and
経験 accordions expanded (tap-tested) → Back (HOME progress unchanged, action
still available) → reopen → explicit confirm → HOME → sales start. Zero
horizontal overflow (`document.documentElement.scrollWidth <=
window.innerWidth`) asserted at 8 separate checkpoints through the flow.
Screenshots captured (see PLAYWRIGHT RESULT).

## 390PX RESULT

Pass. Same flow and same assertions as 360PX RESULT, at 390×800. Zero
horizontal overflow at every checkpoint. Screenshots captured.

## BACK RESULT

Pass. Tapping 戻る (`public-demo-skill-sheet-cancel-<id>`) pops `false`;
`_openSkillSheetReview` returns without calling `_startSkillSheetReview`, so
the engineer's `PublicDemoSalesStage` remains `waiting` and no aggregate is
committed (no persistence write). The SkillSheet action (`SkillSheet確認`)
remains visible and reachable afterward — verified by both the #117 widget
test and the new Playwright spec at both widths.

## CONFIRM RESULT

Pass. Tapping 内容を確認 (`public-demo-skill-sheet-confirm-<id>`) pops `true`;
`_openSkillSheetReview` then calls `_startSkillSheetReview`, committing
`PublicDemoAggregate.startSkillSheetReview` exactly as before — the engineer
advances `waiting → skillSheet` exactly once. Verified by the #117 widget
test, `public-demo-fresh-start.spec.ts`, and the new Phase A spec at both
widths.

## SALES START RESULT

Pass. After confirmation, the existing `営業開始` action (`_beginSelling`,
unchanged) is reachable from HOME and advances the engineer to
`PublicDemoSalesStage.selling` — verified at both 360px and 390px.

## TEST RESULTS

- `flutter analyze` (whole project): **No issues found.**
- `test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart` (#117
  SkillSheet flow, unmodified): **2/2 passed.**
- `flutter test test/ui/public_demo/ test/game/public_demo/
  test/game/public_demo_save_service_test.dart` (all Public Demo widget/unit
  tests, incl. #117 persistence/reachability tests
  `public_demo_01_persistence_test.dart`,
  `public_demo_01_home_runtime_read_test.dart`,
  `public_demo_01_home_recommended_action_test.dart`): **569/569 passed.**
- Full `flutter test` (whole project, after the timing fix below):
  **1317/1317 passed.**

### One test-timing fix required (not a functional regression)

The first full-suite run surfaced 2 failing tests in
`test/ui/public_demo/public_demo_01_persistence_test.dart`: `each
authoritative mutation queues its resulting aggregate` and `a delayed
earlier save cannot overtake the later aggregate` (the latter hung for the
framework's full 10-minute test timeout). Root cause: that file's shared
`_tapAction` test helper tapped the SkillSheet action button, did a single
bare `await tester.pump();`, and then immediately looked up and tapped the
`内容を確認` button — a timing assumption that held for the #117
`AlertDialog`'s transition but not for the new `showModalBottomSheet`'s
slide-in entrance transition, so the confirm tap landed on a still-animating,
off-screen button and did nothing.

Fix: changed that one `pump()` to `pumpAndSettle()` in `_tapAction` (see
`test/ui/public_demo/public_demo_01_persistence_test.dart`) so the sheet
finishes entering before the confirm button is located and tapped. No
assertion was weakened, relaxed, or skipped — same expectations, correctly
timed. Re-run after the fix: **13/13 passed** in that file, and **569/569**
across the full Public Demo subset.

## PLAYWRIGHT RESULT

- `tests/public-demo-fresh-start.spec.ts` (#117, unmodified): **1/1 passed**
  (mobile-chromium, pre-installed Chromium at `/opt/pw-browsers`).
- `tests/public-demo-skillsheet-phase-a.spec.ts` (new): **2/2 passed**
  (360×800 and 390×800), covering fresh start → HOME → SkillSheet → real-data
  verification → accordion expand → no-overflow checks → Back → reopen →
  confirm → HOME → sales start. Milestone screenshots captured for both
  widths (`01-home`, `02-skillsheet-open`, `03-accordion-expanded`,
  `04-confirmed-home`, `05-sales-started`) and attached to the Playwright
  report/test-results directory.
- No uncaught page errors, no page crash, no unallowlisted `console.error` at
  either width.

## DOMAIN CHANGES

None. No field, class, enum value, or method was added to
`lib/domain/models/**` or `lib/game/public_demo/**`. All new code is
presentation-only (`lib/ui/public_demo/public_demo_skill_sheet_*.dart`)
reading existing objects verbatim.

## SAVE SCHEMA CHANGES

None. No `toJson`/`fromJson` was touched on any model. Persistence behavior
is unchanged — same aggregate, same commands, same commit boundary.

## NORMAL GAME IMPACT

None. All changes are scoped to `lib/ui/public_demo/**` (Public Demo only).
The normal game's `engineer_detail_screen.dart` and related engineer-detail
presentation files were read for convention reference (the existing
実際/記載 comparison pattern) but not modified.

## KNOWN LIMITATIONS

- `PublicDemoEngineerRuntime.careerHistory` is currently always empty in
  Public Demo, so the 案件経歴 (career history) list always renders its empty
  state today. The row/card rendering for a populated entry is implemented
  and ready, per the issue's request to "evaluate a reusable row/card
  structure," but is not exercised by current data.
- The 案件/参画情報 section renders its empty state for every engineer this
  dialog is currently reachable for, since `_openSkillSheetReview` is only
  invoked pre-assignment (`PublicDemoSalesStage.waiting`). The section's
  populated-assignment rendering is implemented but likewise not exercised by
  the current reachable flow.
- Certifications/learning and desired-role/preferences have no placement in
  this Phase A layout at all (not even an empty-state placeholder) — see
  PHASE B/C DEFERRED ITEMS for why.

## PHASE B/C DEFERRED ITEMS

Deliberately not implemented, per explicit task scope:

- Certifications/learning section (no authoritative Public Demo source
  exists yet; Issue #132's acceptance criteria mention a "defined placement,"
  but the task's own explicit Phase A section list omits it, and adding even
  an empty placeholder was judged out of scope for this pass — flagged here
  instead so it's a deliberate, visible omission rather than a silent one).
- Desired role/career preferences section (same reasoning).
- Editable sales-facing SkillSheet values, actual-vs-displayed gameplay
  effects (Company Trust, project-proposal probability, interview risk),
  pre-save impact preview, aggressive-representation confirmation — all
  explicitly deferred to the follow-up SkillSheet editing/gameplay issue per
  #132's own "Follow-up issue" section.
- Project/career history Domain expansion, qualification Domain expansion —
  explicitly out of scope per the task instructions.

## MERGE CONFLICT RISK

Low. `public_demo_01_placeholder_screen.dart`'s diff is a single method body
replacement (`_openSkillSheetReview`), one import line, and one small new
private helper method (`_assignmentForOrNull`) — no other line in the file
changed. All new logic lives in three new files under
`lib/ui/public_demo/public_demo_skill_sheet_*.dart` that #118 (developing on
a sibling branch) has no reason to also touch, per the task's explicit
request to minimize this file's diff for exactly that reason.

## PR READINESS

Ready for review. `flutter analyze` is clean, the #117 widget test and
Playwright spec pass unmodified, the new Phase A widget/E2E coverage passes
at both required widths, and no domain/save/finance/sales-rule/month-
progression code was touched. No PR was opened automatically per
instructions ("PRは自動マージしないでください" — read as: do not push straight
to an auto-merging PR flow; PR creation itself was not requested in this
task and none was created).
