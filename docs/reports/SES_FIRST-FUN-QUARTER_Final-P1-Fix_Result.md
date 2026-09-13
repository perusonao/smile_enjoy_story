# SES First Fun Quarter — Final P1 Fix — Result Report

## Scope

AI Human-like Replay Audit #2 against the current `main` (post PR #261/#262)
found 3 P1 findings still open for the April→July First Fun Quarter loop.
This change fixes exactly those 3, plus the one P2 (P2-6, growth reason
label) that shares P1-1's own root cause, per task instructions. Every
other Audit #2 P2 finding is left as a tracked Known Limitation — not
touched.

Out of scope (unchanged, per task instructions): 採用承諾率そのもの,
training効果値, assignment開始条件, salary balance, monthly accounting,
save schema, Main Game, Aug-Feb, Year-end.

The audit document `SES_FIRST-FUN-QUARTER_AI-Replay-Audit-2.md` referenced
in the task instructions as the Finding SSOT was not actually present in
the repository or attached to this session (checked via repo search and
scratchpad/tmp). This report proceeds from the detailed repro steps,
requirements, and test-case lists embedded directly in the task
description (which are evidently sourced from that same audit), each
independently re-verified against current code before any fix — not
reimplemented blindly.

## P1-1 — 研修成長プレビュー不整合

### Fresh Audit finding

There is no separate "growth preview" mechanism in the codebase at all —
`_growthResultsSection` (社員タブ, Section 4) always renders
`PublicDemoState.latestGrowthResults`, which is written **only** by
`PublicDemoState.applyMonthlyGrowth` at the **previous** month's close (see
that method's own doc: "called only by the month-end commands ... before
the next month transition"). The section was headed **「今月の成長」**
("this month's growth"), sitting directly above the still-open
`internalTrainingCard` for the month in progress, in the same Section 4.

So the repro (鈴木葵, May, select 社内研修, see "52→52 (+0)" / "今月は大きな
変化なし" directly above the just-confirmed "今月は社内研修" card) was real,
but every number shown was already true — it was April's already-closed
result, mislabeled as if describing the month currently in progress. This
is a **labeling bug**, not a stale-computation or wrong-number bug: the
real May growth from the just-made training selection genuinely does not
exist yet (it is computed once, at May's own close) and was never falsely
fabricated as "+0" — the "+0" belonged to April.

This is also the exact root cause of Audit #2 **P2-6** (an assigned
engineer's still-visible prior-month record reading "社内研修を通じて成長"):
`PublicDemoMonthlyGrowth.source` was always accurate for the month it
recorded — the same "今月の成長" heading ambiguity, not a second,
independent resolver bug. Fixed in the same change.

### Fix

Pure text/label change, no domain change:

- `_growthResultsSection`'s heading: `今月の成長` → `先月の成長結果`.
- `PublicDemoGrowthResultCard`'s own zero-delta line: `今月は大きな変化なし`
  → `大きな変化はありませんでした` (drops the "今月は" framing the card's own
  text carried, for the same reason).

`PublicDemoGrowthEngine`, `PublicDemoState.applyMonthlyGrowth`, and
`PublicDemoMonthlyGrowth` (part of the save schema) are byte-for-byte
unchanged. No new UI authority — the same `latestGrowthResults` field is
read exactly as before.

## P1-2 — HOME社員ステータス誤表示

### Fresh Audit finding

Root cause traced to `_officeStageStatusFor` (HOME's own Office Stage
status resolver):

```dart
String _officeStageStatusFor(PublicDemoEngineerSales engineer) {
  if (engineer.stage == PublicDemoSalesStage.ordered &&
      _currentlyAssignedEngineerIds.contains(engineer.id)) {
    return '参画中';
  }
  return engineerStatus(engineer);
}
```

An applicant who joins already carrying a pre-entry order (the real
`preEntryPartnerPassed → preEntryClientPassed → juneOrdered → closeMay`
path) becomes an engineer at `PublicDemoSalesStage.waiting`
(`PublicDemoEngineerSales.fromApplicant` never inherits the applicant's
own pipeline stage) in the very same close that
`PublicDemoWorkflowState.assignOrderedForMay` also adds them to the
assignment roster (already documented in this file, above
`_cashForecastAdvice`: "an applicant who won a pre-entry order joins as an
engineer at `waiting` ... so `stage == waiting` alone does not mean not
currently on a project"). `_officeStageStatusFor`'s `if` only ever matched
`stage == ordered`, so this genuinely-participating new joiner fell
through to the stale raw `engineerStatus` label (待機) — while 社員's own
`参画中案件` section (`activeProjectStatusCard`, gated purely on assignment
membership, never `stage`) already showed 参画中 for the same person. That
is the exact HOME/社員タブ mismatch the audit reported.

The same gap exists in the shared `PublicDemoEmployeeStatusResolver` used
by 社員's own roster row/SkillSheet — its `waiting` branch never consulted
assignment membership at all, so the roster row for this same case would
also (latently) read 研修が必要/待機/営業可能 rather than 参画中, even though
the `参画中案件` card elsewhere on the same tab already disagreed. Both
surfaces are fixed together, from one shared, non-HOME-owned fact.

### Why the naive fix would regress a known, tested case

`PublicDemoEmployeeStatusResolver`'s own doc/test already documents a
**second** "waiting but currently assigned" case: an engineer whose
assignment was ended mid-month (`PublicDemoWorkflowState.endAssignment`'s
documented pre-July "row kept, stage reset to waiting" behavior) is
genuinely back at `待機`, even though `assignedEngineerIds` can still
include them for the rest of that month. `stage == waiting &&
isCurrentlyAssigned` is **true for both** cases — they are not
distinguishable from `(stage, isCurrentlyAssigned)` alone, and a pinned
regression test (`public_demo_employee_status_resolver_test.dart`) already
locks the ended-assignment case to `研修が必要`, not `参画中`.

### Fix

Added one more fact, read from existing data only (no new domain
authority, cache, or persisted field): whether the assignment row still
carries its default/undecided `PublicDemoAssignment.nextOrderStatus`
rather than `notOffered` (`endAssignment`'s own precondition guarantees
`notOffered` on exactly the released row). A new shared helper,
`_hasActiveAssignmentDespiteWaitingStage`, computes this once from
`_currentlyAssignedEngineerIds` + `workflow.assignments`, and both
`_officeStageStatusFor` (HOME) and `_employeeStatusDisplayFor` (社員タブ/
SkillSheet, via a new optional `PublicDemoEmployeeStatusResolver.resolve`
parameter, default `false` so every pre-existing caller/test is
unaffected) now read it — one authoritative fact, two surfaces, same
answer.

HOME's separate, intentionally-independent implementation of every *other*
raw sales-pipeline status text (the documented "HOME Freeze" wording gap,
e.g. `翌月参画予定` vs `参画予定`) is untouched — only the one broken case is
fixed, following the codebase's own established precedent for touching
HOME-owned code minimally.

## P1-3 — 内定辞退フィードバック欠落

### Fresh Audit finding

`offer(i)` (the salary-offer flow, shared verbatim by HOME's guided
"給与提示へ" CTA and 営業's own "合格・給与提示" button) already fully,
deterministically decides 内定承諾/内定辞退 inside
`PublicDemoOfferAcceptance.accept` the instant the player picks a salary —
but nothing ever displayed that outcome. Reaching it through HOME was
completely silent: HOME's recommended-action ranking simply advanced to
whatever became next (a different candidate's résumé, in the repro), since
an accepted and a declined offer look identical from HOME's perspective
(the candidate stops emitting `applicantSalaryOffer` either way). A player
following 営業 directly could still notice via the card's own status
badge; a player following HOME's guided flow never saw it at all.

### Fix

`offer(i)` now calls a new `_showOfferResultIfDecided(applicantId)` right
after `_commitAggregate`, which:

- Reads back the applicant's already-committed
  `stage`/`acceptedMonthlySalary`/`salaryRelationshipReason` — fields
  `PublicDemoOfferAcceptance.accept` already wrote before this method is
  ever called. No domain call, no second judgement, nothing recomputed.
- Shows nothing when the stage is not (yet) `offerAccepted`/
  `offerDeclined` — the one real no-op case being
  `PublicDemoAggregate.acceptOffer`'s existing `isFinanciallyRestricted`
  guard, where nothing was actually decided.
- Otherwise shows a new, Public-Demo-specific
  `PublicDemoOfferResultDialog` (reuses the existing candidate portrait via
  `homeOfficeStagePortraitFor` — no new image) naming: 候補者名, 結果
  (内定承諾/内定辞退), 提示給与, and the existing
  `PublicDemoSalaryOffer.relationshipReason` short explanation
  (希望給与を上回る/どおり/下回る条件で入社) as the "why", plus a one-line "next
  action" hint.

One call site, one dialog, shown identically regardless of entry point
(HOME CTA or 営業 button) — never a per-entry-point special case. The
modal barrier blocks any further interaction (including HOME's own next
recommendation) until the player dismisses it, satisfying "結果確認後にの
み次候補へ進む" by construction. Closing the dialog only calls
`Navigator.pop()` — no state mutation, so reopening the screen or
reloading a save can never show a different result. `PublicDemoOfferAcceptance`/recruitment
authority/acceptance判定ロジックは無変更.

`lib/ui/widgets/offer_result_dialog.dart` (the separate, pre-existing Main
Game/prologue 内定承諾/辞退 dialog) is untouched — a different screen, out
of scope.

## Changed files

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — P1-1
  heading rename; P1-2 `_officeStageStatusFor` fix +
  `_hasActiveAssignmentDespiteWaitingStage` helper +
  `_employeeStatusDisplayFor` call-site update; P1-3 `offer()` +
  `_showOfferResultIfDecided`.
- `lib/ui/public_demo/public_demo_growth_result_card.dart` — P1-1 zero-delta
  line rename.
- `lib/ui/public_demo/public_demo_employee_status_resolver.dart` — P1-2
  new optional `isActivelyAssignedAtWaitingStage` parameter.
- `lib/ui/public_demo/public_demo_offer_result_dialog.dart` — **new**, P1-3
  result dialog.
- Existing test text-expectation updates for the P1-1 rename and P1-3's
  new modal step: `public_demo_01_playthrough_test.dart`,
  `public_demo_01_success_playthrough_test.dart`,
  `public_demo_growth_result_card_test.dart`,
  `public_demo_01_suzuki_sales_yearend_boundary_test.dart`,
  `public_demo_01_recovery_ui_test.dart`,
  `public_demo_01_home_runtime_read_test.dart`.
- New focused tests: `public_demo_growth_section_label_p1_1_test.dart`,
  `public_demo_home_employee_status_p1_2_test.dart`,
  `public_demo_offer_result_feedback_test.dart`,
  `public_demo_offer_result_dialog_test.dart`.

## P2 resolved in the same change

- **P2-6** (growth reason label mislabeling): same root cause as P1-1
  (see above) — resolved by the same heading fix.

## Known Limitations (left untouched, per task instructions)

Audit #2 P2 findings 1-5 (面談文言重複 / 面談前「採用面談済」/ 受注案件0件瞬間
表示 / 承諾直後Employee痕跡 / 入社通知portrait) do not share a root cause with
any of the 3 P1s fixed here and are left as tracked Known Limitations, not
touched in this change.

HOME's own raw per-sales-substage wording (e.g. `翌月参画予定` vs the 社員
タブ/SkillSheet's unified `参画予定`) remains a separate, previously-known,
tracked cross-surface wording gap — unrelated to the P1-2 status-authority
mismatch this change fixes, and explicitly out of scope for "HOME Freeze"
reasons already established by prior work on this codebase.

## Test results

- `flutter analyze` (whole repo) — no issues found.
- `git diff --check` — clean, no whitespace errors.
- New focused tests (all green):
  - `public_demo_growth_section_label_p1_1_test.dart` (P1-1: training未選択
    / training選択直後 / month close後 / assignment由来growthとの混同なし)
  - `public_demo_home_employee_status_p1_2_test.dart` (P1-2: join +
    assignment at the month boundary / save-reload / assignment終了・待機復帰
    regression guard)
  - `public_demo_offer_result_feedback_test.dart` (P1-3: HOME経由
    acceptance / HOME経由 decline / Sales直接経由 / 二重判定防止 / save-reload)
  - `public_demo_offer_result_dialog_test.dart` (P1-3: 360×800 / 390×844
    overflow check, accepted + declined)
- Existing tests updated for the P1-1 rename and P1-3's new modal step
  (`public_demo_01_playthrough_test.dart`,
  `public_demo_01_success_playthrough_test.dart`,
  `public_demo_growth_result_card_test.dart`,
  `public_demo_01_suzuki_sales_yearend_boundary_test.dart`,
  `public_demo_01_recovery_ui_test.dart`,
  `public_demo_01_home_runtime_read_test.dart`) — all green after the
  update; no assertion's underlying behavior was weakened, only extended
  for the new dialog step or the renamed heading.
- Full `flutter test test/game/public_demo test/ui/public_demo` — **1789
  tests, all green**, zero regressions. (One first-pass failure was found
  and fixed during this work: `public_demo_01_success_playthrough_test
  .dart`'s own updated assertion initially matched both the new result
  dialog's title and the underlying Sales-tab card's already-updated status
  badge simultaneously — narrowed to the dialog's own key; not a product
  bug.)
- Overflow (360×800 / 390×844): covered by the new `public_demo_offer_
  result_dialog_test.dart` directly, and by the many existing overflow
  suites in the full run above (e.g. `public_demo_01_month_start_status_
  recommended_action_test.dart`, `public_demo_01_home3_integration_test
  .dart`) which stayed green with the P1-1/P1-2 changes in place.
- HOME vs 社員 status agreement, training's false +0/変化なし claim, decline
  confirmed before advancing, no accept/decline double-processing, and
  save/reload stability — each directly asserted in the three new P1
  focused-test files above, not just implied by the full suite staying
  green.

## Self-review (Broad-Review-equivalent hardening pass)

Performed per task instructions in lieu of a separate Codex Broad Review
(deferred to a later, separate pass on the PR per task instructions):

- Re-read every changed production line adversarially for a P0/P1: none
  found. The three fixes are each either a pure text/label change (P1-1),
  an additive fact read from already-existing, already-persisted data with
  no new authority and a regression test pinning the one case that could
  have broken (P1-2), or a pure read-only display of an already-committed
  domain decision with no new domain call (P1-3).
- Checked every changed/added file for save-schema impact:
  `PublicDemoMonthlyGrowth`, `PublicDemoAssignment`, `PublicDemoApplicant`,
  and `PublicDemoEngineerSales` are all byte-for-byte unchanged — no
  `toJson`/`fromJson` touched anywhere in this change.
- Checked every changed/added file for domain-authority impact:
  `PublicDemoGrowthEngine`, `PublicDemoState.applyMonthlyGrowth`,
  `PublicDemoOfferAcceptance.accept`,
  `PublicDemoWorkflowState.assignOrderedForMay`/`endAssignment`, and
  `PublicDemoEmployeeStatusResolver`'s existing branches are all
  byte-for-byte unchanged except the one additive, default-`false`
  parameter on the resolver (verified not to change any existing test's
  expected output, since every pre-existing call site/test omits it).
  Assignment start conditions, recruitment/acceptance judgement, training
  effect values, and monthly accounting are untouched.
- No P2 with progression/save/authority/data-integrity relevance was found
  in the diff to flag — the only P2 addressed (P2-6) is a wording
  consequence of the P1-1 fix itself, already covered above.

## Base / Final commits

- Base `main`: `f955f88accfb3324098126f13fdde30bb6f1d83e`
- Final HEAD: `313d6a621b00e041d6caae491482f4748e3a8b2f`
- PR: https://github.com/perusonao/smile_enjoy_story/pull/263
