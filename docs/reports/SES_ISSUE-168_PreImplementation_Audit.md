# SES Issue #168 — Pre-Implementation Audit

Issue: [#168](https://github.com/perusonao/smile_enjoy_story/issues/168) —
FIRST-FUN-YEAR-ONBOARDING-1: 4月→5月の営業・求人・研修ルールを理解可能にする

Audited `origin/main` SHA: `cc79aaf2247483341a71f1c2cc9929b69759a391`
(merge of PR #174, PUBLIC-DEMO-HOME-UI-3C — the most recent main commit at
audit time). This supersedes the earlier informal audit recorded as an
issue comment (audited at stale SHA `d68bd8a9c6d2de50b9bab16dbf8564cbb6990ff8`,
before #174 merged) — its four classifications are re-verified below
against current `main`, file by file, and one (Finding B) is materially
revised.

READ-ONLY task. No production file was modified for this report.

---

## Verdict

**READY WITH CHANGES.**

The Month Guard wiring gap (Finding A) and the training/applicant-narrative
copy gaps (Findings C, D) are ready to implement now, presentation-only,
reusing existing domain/save/finance authority with zero new rules. Finding
B is a genuine **RULE/DESIGN ISSUE**, not a copy gap — it is already
substantially *explained* truthfully on screen, but the underlying rule
(a founding engineer who starts below the field-sales threshold with a
window that closes before training can possibly raise her in time) has no
safe minimal code fix that fits this Issue's own non-goals ("新しい能力値/
レベルシステム" / no balance rewrite). It is reported here, not silently
patched, per the Issue's own instruction ("UX文言で隠さず RULE/DESIGN ISSUEと
して報告").

---

## 1. Finding A — 4月→5月 (and 5月→6月, 6月→7月) month-close warning

### Classification: **BUG (wiring gap)** — confirmed unchanged by PR #174.

### Current behavior

`PublicDemoMonthGuard` (`lib/game/public_demo/public_demo_month_guard.dart`)
already has exactly the two-level design the Issue describes:
`required` (July's summer-bonus decision, unchanged scope) and
`recommended` (a dismissible, truthful warning naming outstanding
already-legal, already-on-screen actions). `PublicDemoMonthGuardWarningDialog`
(`lib/ui/public_demo/public_demo_month_guard_warning_dialog.dart`) already
renders it with exactly the two actions the Issue's copy example asks for:

- `タスクを確認` (`Key('public-demo-month-guard-review')`) — cancels the
  close; the player stays on the current tab where the named action is
  still directly reachable (HOME's Recommended Action slot / 今月の重要タスク
  already surface it — no new navigation needed since nothing left that
  screen).
- `このまま月末処理を進める` (`Key('public-demo-month-guard-proceed')`) —
  proceeds anyway.

Both the guard and the dialog are already wired for `closeOrdinaryMonth()`
(August–March, `public_demo_01_placeholder_screen.dart:1691-1697`) via
`_confirmMonthCloseIfRecommendedOutstanding()`
(`public_demo_01_placeholder_screen.dart:1639-1651`).

**The gap:** `april()` (line 1340), `may()` (line 1455), and `june()`
(line 1529) — the three handlers `_monthlyPrimaryAction` binds for months
4, 5, 6 (lines 660-677) — call `_commitAggregate(_game.closeApril/closeMay/
closeJune(...))` directly. None of them calls
`_confirmMonthCloseIfRecommendedOutstanding()` first. A player can advance
April → May → June with zero warning no matter how many outstanding,
already-legal actions (`_monthGuardRecommendedCandidates`, built from the
same `_recommendedActionCandidates` HOME's one recommended-action slot
already uses) are still untouched. This is exactly Issue #108's P1 finding
#1 and the Issue's own "①" reproduction, still true on fresh `main`.

### Authoritative existing state/data to reuse

- `PublicDemoMonthGuard.evaluate` (unchanged, no new rule needed).
- `_monthGuardItems` / `_monthGuardRecommendedCandidates` /
  `_confirmMonthCloseIfRecommendedOutstanding()` (already generic over any
  month; `monthCloseApplicable: !s.isCloseBlocked` already covers April/May/
  June).
- `_recommendedActionCandidates`'s existing `s.month == 4` branch
  (`public_demo_01_placeholder_screen.dart:2055-2059`) already emits
  `employeeSkillSheetReview`/`employeeBeginSelling` etc. **only when
  `readyForFieldSales(e.id)` is true** — so Suzuki (below threshold, see
  Finding B) correctly produces *no* nagging warning about an action she is
  not actually eligible for; only Sato (ready, untouched) would trigger one.
  This is already exactly the Issue's own scoping ("営業可能/営業準備可能な
  待機技術者に未完了の重要行動がある場合").
- `PublicDemoMonthGuardWarningDialog` (unchanged, no new dialog needed).

### Exact UI files likely to change

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — add an
  `if (!await _confirmMonthCloseIfRecommendedOutstanding()) return;` guard
  at the top of `april()`, `may()`, and `june()`, mirroring
  `closeOrdinaryMonth()`'s own line 1692. `may()`/`june()` already have (or
  can trivially gain) `Future<void>`/async shape — `june()` is currently
  synchronous (`void june()`, line 1529) and must become `Future<void>
  async` to await the confirm dialog; its one caller (`onPressed: june,`
  at line 676) becomes `onPressed: () => unawaited(june()),` to match
  `april()`/`may()`'s existing pattern.

No other file needs a change for this finding.

### Domain/save/finance/Month Guard/Recommended Action changes needed?

**None.** `PublicDemoMonthGuard`, `PublicDemoAggregate.closeApril/closeMay/
closeJune`, save schema, and `HomeRecommendedActionKind` are all reused
verbatim. This is a pure UI wiring fix, structurally identical to how
Issue #119 already wired `closeOrdinaryMonth()`.

### Conflicts/overlap with merged PR #174

None. PR #174 touched `_salesTabEmptyState()`'s copy/overflow and section
spacing/padding in the same file; it did not touch `april()`/`may()`/
`june()`/`_monthlyPrimaryAction`/`_confirmMonthCloseIfRecommendedOutstanding`.
No line ranges overlap.

### Focused tests required

- Extend `test/ui/public_demo/public_demo_01_month_guard_recommended_test.dart`
  (or a sibling file, matching its existing "drive the real screen via
  `PublicDemoAggregate` commands + fixed save fake" technique) with cases
  for April, May, and June:
  - An untouched-but-ready engineer (Sato) at April close produces the
    warning naming `佐藤 健のSkillSheetを確認`; `タスクを確認` cancels and
    the CTA/action are still present; `このまま月末処理を進める` proceeds
    and April genuinely closes.
  - Suzuki alone outstanding (below threshold) produces **no** warning at
    April close (regression pin for the `readyForFieldSales` gating already
    in `_addEngineerStageCandidate`).
  - No-task case: April/May/June close immediately with no dialog, exactly
    as `closeOrdinaryMonth`'s existing no-task case already proves for
    August+.
- Re-run `test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart`
  unchanged after the fix — it already exercises `4月を終了して5月へ` /
  `5月を終了して6月へ` / `6月を終了して7月へ` end to end (via
  `tapAndSettle`/`dismissDialog(tester, '確認')` for the unrelated April
  event dialog) with **no outstanding recommended action** for its own
  fixture (Sato is put into `skillSheet` stage before closing April in that
  test), so it must keep passing with zero behavior change once the guard
  is wired — a direct check that the fix does not introduce a false-positive
  warning on an already-clean month.

---

## 2. Finding B — 鈴木 葵 cannot start sales (RULE/DESIGN, revised from prior audit)

### Classification: **RULE/DESIGN ISSUE, already substantially explained** —
revised from the prior (stale-SHA) audit's plain "RULE DESIGN" note. The
explanatory UX gap the Issue worries about ("なぜ営業できないのか"/
"何が不足しているのか"/"実力等の曖昧語だけで終わらせない") is **already fixed
on current `main`**, but the underlying rule question the Issue also asks
about ("創業時の初期技術者なのに理由なく営業不可" — is this a real design
problem) remains open.

### Current behavior (`lib/ui/public_demo/public_demo_01_placeholder_screen.dart:2500-2537`,
covered by `test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart`)

The field-sales lock card (`Key('public-demo-field-sales-lock-eng-02')`,
rendered only in April, only while `stage` is `waiting`/`skillSheet` and
`!readyForFieldSales`) already states, verbatim, both required numbers —
**not** the vague "実力不足" the Issue warns against:

> 営業開始には実力 60 以上が必要です（現在 52）。
> まだ営業を始められません。

This already answers three of the Issue's four required explanations:
"何が不足しているか" (実力, with the real threshold and her real current
value: `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement` = 60,
`actualCapability` = 52 via `languageSkills[primaryLanguage].actualSkill`),
and (per the fourth, "研修で解消できるか") the card **deliberately and
correctly says no** — a prior review (P1, PR #115) already removed an
earlier version of this copy that promised training would eventually
unlock SkillSheet確認, because that promise was false: `ec(i)` (the card
that renders both the lock banner and the stage buttons) only renders for
founding engineers `if (s.month == 4)` (line 2867), so once April closes
Suzuki gets no SkillSheet確認 action ever again, "however high later
training raises her capability" (existing code comment, lines 2521-2533).
The Suzuki test empirically proves this by training her in April and
walking real April→July closes, confirming no SkillSheet確認 button ever
reappears for her (test lines 195-256).

### Root rule (verified against `PublicDemoGrowthEngine`,
`lib/game/public_demo/public_demo_growth_engine.dart`)

Even confined to April itself, training cannot close the gap in time:
internal training is "charged immediately, capability applied at month-end"
(`PublicDemoInternalTrainingTransaction` charges cash on selection;
`PublicDemoGrowthEngine.calculate` — `internalTraining` base rate 1.2,
modulated by hidden `growthPotential`/`fastLearner`/morale/diminishing
returns — is applied by EG-3 at month-end close, confirmed by the Suzuki
test asserting her post-April capability is `>52` and still `<60`). Her
April-only sales window and the training's own month-end application
timing structurally cannot overlap for her specific starting value (52).

### Why this is still a RULE/DESIGN ISSUE, not "done"

The Issue explicitly asks to flag, not silently patch, the case where "現行
ルールそのものが『創業時の初期技術者なのに理由なく営業不可』となっている".
Suzuki (`salesSkillFit`/`actualSkill` = 52, seeded in both
`publicDemoInitialEngineers` in `public_demo_sales.dart` and
`publicDemoInitialEngineerRuntimes` in `public_demo_engineer_runtime.dart`)
is exactly this case: a founding engineer, present from game start, whose
one and only sales opportunity (April) she cannot mathematically reach
threshold for. The copy is now honest about it, but the rule itself — no
founding engineer should structurally start unable to ever sell in their
own designated window — is a genuine open design question.

### Minimal rule-change candidates (reported, not implemented — sizing/scope reasons below)

1. Raise Suzuki's seed `actualSkill` from 52 to ≥60 (e.g. 60-65) in both
   `public_demo_sales.dart` and `public_demo_engineer_runtime.dart`'s
   initial constants — smallest possible change, but is a balance/seed-data
   decision (changes what founding-team play looks like from month 1), not
   a pure UI fix, and the Issue's non-goals list rules out "balance大改修"
   generally and doesn't clearly authorize even this narrow a balance tweak
   without an explicit decision.
2. Give founding engineers a second in-window chance (e.g. also render
   `ec(i)`'s stage buttons in May for whoever is still `waiting`/
   `skillSheet`) — a genuine scope/rule change to the founding-engineer
   sales-window contract, which is exactly the kind of "domain rule change"
   the Issue says to split into its own slice rather than mix into the
   onboarding-clarity slice.

**Recommendation:** do not implement either in this task. Keep the current
truthful copy (already correct) and record this as an open design question
for the repository owner (`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`
or a follow-up issue), not a code change here.

### Files already correct, need no change

`public_demo_01_placeholder_screen.dart` (`ec()`'s lock banner),
`test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart` (already
green, already pins the exact contract described above).

---

## 3. Finding C — May applicants without an April recruiting action

### Classification: **INTENDED data, narrative/UX mismatch** — confirmed
unchanged by PR #174, not a generation bug.

### Current behavior

`publicDemoMayApplicants` (two applicants, 高橋 翔 and 田中 美咲,
`lib/game/public_demo/public_demo_recruitment.dart:382-403`) is a `const`
list consumed by `PublicDemoWorkflowState.initial()`
(`public_demo_workflow_state.dart:59-62`) — it seeds the workflow's
`applicants` field **at game start**, in April, before any recruiting
action is possible. There is no code path that "generates" these two
applicants in response to a recruiting action; they exist from the first
frame of the game. A genuine recruiting action
(`PublicDemoRecruitmentCalculation.execute`,
`public_demo_aggregate.dart:895-942`) only ever *adds* further applicants
on top of this pre-seeded pair, drawing from the same
`publicDemoMayApplicants`/`publicDemoFreeApplicants` template pools by
`medium`. There is no separate spontaneous/referral/inbound route — the
Issue's "① no other route may exist implicitly" constraint already holds:
this is not an undocumented parallel applicant source, it is the same pool
used twice (seed + recruiting-generated).

**The actual mismatch is narrative, at April's own event dialog**
(`april()`, `public_demo_01_placeholder_screen.dart:1340-1356`): it shows,
**unconditionally, every playthrough, regardless of whether the player did
anything in April**:

> 新しい応募が届きました
> 採用候補者から応募が届いています。
> 候補者の経歴書を確認しましょう。

This states "a new application has arrived" as if it were caused by
something the player just did, when the two applicants it is introducing
are actually pre-seeded ground truth that existed since game start. This
is the literal reproduction of the Issue's finding #3 ("4月に求人募集をして
いないのに5月に応募者が現れる") — not a bug in applicant generation, but a
dialog whose copy implies a causal recruiting action that never happened.

### Minimal fix (presentation-only)

Reword `april()`'s event dialog to state the true fact — an existing
initial candidate pool is now visible for review, not a fresh application
just received — e.g. "応募者の情報を確認できます" / "採用候補者の経歴書が
確認できます" instead of "新しい応募が届きました"/"応募が届いています". No
domain change: same dialog widget, same trigger point, only the three
string literals passed to it.

### Exact files likely to change

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — the three
  string literals at lines 1346, 1349, 1350 (`title`/`message`/
  `nextAction` passed to `PublicDemoEventDialog`).

Optionally, the 営業 tab's May recruitment section could gain one line
clarifying that these two are the initial pool, not media-recruited — but
the Issue's acceptance criteria only requires the no-implicit-route
guarantee (already true) and does not require restating pool provenance a
second time on 営業; the April dialog is the one place that actively
asserts a false causal story, so it is the minimal, sufficient fix.

### Conflicts/overlap with merged PR #174

`_buildSalesTab`/`_salesTabEmptyState()` (PR #174's own change) is a
different code path (May's real recruitment-media card is untouched by
#174; only the *fallback when nothing renders* is new). `april()`'s event
dialog is untouched by #174. No overlap.

### Focused tests required

- A widget test asserting April's event dialog copy no longer contains
  "新しい応募が届きました"/an unconditional "応募が届いています" claim, and
  instead states the truthful pool-visibility fact — mirroring the existing
  pattern in `public_demo_01_suzuki_sales_lock_test.dart`'s
  `dismissDialog(tester, '確認')` helper (the dialog's own confirm button
  is unaffected by a copy-only change).
- No domain/`PublicDemoRecruitmentCalculation` test changes needed — that
  authority is unchanged.

---

## 4. Finding D — Training explanation is still thin

### Classification: **UX EXPLANATION / MISSING FEATURE (presentation-only)** —
confirmed unchanged by PR #174.

### Current behavior (`internalTrainingCard()`,
`public_demo_01_placeholder_screen.dart:1868-1938`)

The card states only:

> （対象社員名）（待機）
> 社内研修 ¥30,000

plus, when unaffordable, "現預金が不足しています。". It does not state (all
of which are real, already-established, authoritative facts elsewhere in
the codebase, per the audit above):

- **Who** — implicitly "this waiting engineer" (the card is per-engineer
  and hidden for assigned engineers, `assigned` check at line 1876), but
  never states training is waiting-employee-only in words.
- **Cost timing** — charged immediately on selection
  (`PublicDemoInternalTrainingTransaction.execute`, cash deducted the same
  transaction that records the selection).
- **Effect timing** — capability growth is computed and applied at
  month-end close (`PublicDemoGrowthEngine`, source `internalTraining`),
  not immediately.
- **Relationship to sales eligibility** — real, but conditional and not
  guaranteed to arrive in time for a specific engineer's own sales window
  (see Finding B) — any new copy here must not re-introduce the false
  promise PR #115's review already removed from the lock banner.
- **Re-selection** — `state.trainingSelections` is per-month
  (`PublicDemoState.copyWith`'s month-close path clears/rebuilds it; the
  card's own `selected` check reads `s.trainingSelections.containsKey`),
  i.e. training must be chosen again each month it is wanted — never
  stated on screen.

### Minimal, truthful fix

Add 1-2 short lines to `internalTrainingCard()`'s existing `Column`, stated
from facts already authoritative elsewhere in this same file/class (no new
domain read):

- "待機中の社員が対象です。選択した月の月末に実力へ反映されます（費用は選択時
  に即時発生、毎月選び直しが必要です）。"

This must **not** claim a specific effect size, success rate, or guaranteed
sales-eligibility outcome — none of those are safe to state as fixed
numbers (the growth formula is stochastic-adjacent via hidden parameters,
diminishing returns, morale) and doing so would fabricate the "存在しない
能力値、必要レベル、成功率、期間をUIで捏造しない" constraint the Issue
explicitly forbids.

### Exact files likely to change

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` —
  `internalTrainingCard()` only (one `Text`/short `Column` addition).

### Domain/save/finance changes needed?

None. Every fact the new copy states is already true and already
authoritative in `PublicDemoInternalTrainingTransaction` and
`PublicDemoGrowthEngine`; this only surfaces it.

### Conflicts/overlap with merged PR #174

None — `internalTrainingCard()` was untouched by #174.

### Focused tests required

- Extend `test/game/public_demo/public_demo_internal_training_transaction_test.dart`'s
  sibling UI coverage (or add one alongside
  `public_demo_01_suzuki_sales_lock_test.dart`, which already exercises
  `public-demo-internal-training-action-eng-02`) with an assertion that the
  card's new explanatory text is present and does not overflow at 360px.
- Re-run `public_demo_01_suzuki_sales_lock_test.dart` unchanged (it already
  asserts the lock banner itself contains no "社内研修" text — a copy
  addition elsewhere on the same card must not leak into that banner).

---

## 5. Overall conflicts/overlap with merged PR #174

Both this Issue's likely change set and PR #174 touch
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, but at
disjoint locations:

| PR #174 touched | This Issue would touch |
|---|---|
| `_salesTabEmptyState()` (~line 3000-3030) | `april()`/`may()`/`june()` (~1340-1548), `_monthlyPrimaryAction` (~657-698) |
| Section spacing/padding (HOME composition) | `internalTrainingCard()` (~1868-1938) |
| — | April event-dialog copy (~1346-1350) |

No line ranges overlap. Since #174 is already merged into `main`, there is
no live parallel-implementation risk (the Issue's own caution, "#147実装中
にこのIssueのproduction fileを同時変更しない", was about avoiding concurrent
edits to the same file while #174/#147 were still in flight — that window
has closed; this audit's base SHA already includes #174).

---

## 6. 360×800 / 390×844 screen impact

- **Month Guard warning dialog** — already an existing, already-verified
  widget (`PublicDemoMonthGuardWarningDialog`) reused verbatim for three
  more trigger sites; its own existing test coverage
  (`public_demo_01_month_guard_recommended_test.dart`) already runs at
  required widths for the August-March case, so wiring it into April/May/
  June carries no new layout risk — only new trigger-site tests are needed
  (§1).
- **Training card copy addition (Finding D)** — one to two short lines
  inside an existing `Card`/`Column` with no fixed height constraint
  (`Column`/`mainAxisSize: MainAxisSize.min`), same pattern as the existing
  "現預金が不足しています。" conditional line already handles gracefully at
  both widths. Needs one focused widget-test assertion (§4) that the new
  line does not overflow at 360px, mirroring the existing 360px overflow
  check pattern in `public_demo_01_suzuki_sales_lock_test.dart` (lines
  190-193).
- **April dialog copy (Finding C)** — pure string replacement inside the
  existing `GameEventModal`/`PublicDemoEventDialog`, which already renders
  at both required widths across the rest of this suite; a shorter or
  similar-length Japanese string carries negligible new overflow risk, but
  should still get one assertion that `tester.takeException()` is `null`
  at 360×800 after the change (cheap, already the established pattern).
- No change to `HomeNavigatorMetrics`/`HomeOfficeStageMetrics`-tuned floors
  from PR #174 is needed or proposed.

---

## 7. Implementation blockers

**None identified.** All three ready-to-implement findings (A, C, D) are
presentation-only, reuse existing authority, and the exact call sites,
literal locations, and existing test scaffolding to extend are identified
above. Finding B has no code blocker either — it is correctly resolved as
"report, do not implement" per the Issue's own instruction, so it blocks
nothing.

One soft dependency, per the Issue's own stated priority order: this
Issue's production implementation should still follow #166 (persistence
classification) and #147 (HOME-UI-3A completion + deployed Screen
Verification) per
`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`'s general execution
order — this audit does not re-verify either of those Issues' current
status; it only confirms #168's own three code-ready findings have no
blocker intrinsic to themselves.

---

## 8. Recommended implementation scope (fits 2–3h)

Single slice — no split needed, since Finding C turned out not to be a
generation BUG (no `recruiting-without-action` fix is required, only a
narrative copy correction at the same site the month-warning work already
touches):

1. **Month Guard wiring (Finding A, ~45-60 min):** guard `april()`/`may()`/
   `june()` with `_confirmMonthCloseIfRecommendedOutstanding()`; convert
   `june()` to `Future<void> async` and its one call site to
   `unawaited(june())`. Add focused tests per §1.
2. **April event-dialog copy (Finding C, ~15-20 min):** reword the three
   string literals to state the true "review the initial candidate pool"
   fact instead of implying causation from a recruiting action. Add one
   focused test per §3.
3. **Training card copy (Finding D, ~30-45 min):** add the truthful
   who/cost-timing/effect-timing/re-selection lines to
   `internalTrainingCard()`. Add/extend focused tests per §4.
4. **Result report + Screen Verification (~20-30 min):** 360×800/390×844
   capture of the three changed surfaces (month-guard dialog on April/May/
   June, the reworded April event dialog, the training card), plus the
   full `flutter test`/`flutter analyze` gate, written up in
   `docs/reports/SES_FIRST-FUN-YEAR_ONBOARDING-1_Result.md` per the Issue's
   own required-result-report path.

Total: **~2-2.5h**, comfortably inside the Issue's 2-3h target, with
Finding B's RULE/DESIGN note carried into that result report (and, if the
repository owner wants it acted on, a separate follow-up issue) rather than
implemented here.

### Non-goals respected

No new Month Guard rule, no new Recommended Action kind, no new
recommendation engine, no domain/save schema change, no balance rewrite, no
referral/inbound recruiting route, no new ability/level system. Every
change above is either a wiring fix that calls an existing guard the same
way `closeOrdinaryMonth()` already does, or a string-literal copy
correction stating facts already true and already authoritative elsewhere
in the same file.

---

## 9. Summary table (per Issue #168's own required format)

| Finding | Classification | Authoritative file | Existing test | Minimal fix scope |
|---|---|---|---|---|
| A. Month advance without sales warning | BUG (wiring gap) | `public_demo_01_placeholder_screen.dart` (`april()`/`may()`/`june()`, `_monthlyPrimaryAction`) | `public_demo_01_month_guard_recommended_test.dart` (Aug-Mar only; extend for Apr/May/Jun) | Call `_confirmMonthCloseIfRecommendedOutstanding()` in all three handlers |
| B. Initial engineer sales ineligibility | RULE/DESIGN (already truthfully explained) | `public_demo_engineer_runtime.dart`, `public_demo_sales.dart`, `ec()` lock banner | `public_demo_01_suzuki_sales_lock_test.dart` (already green, no change needed) | None in this task — report only |
| C. Applicant without recruiting | INTENDED data, narrative/UX mismatch (not a generation bug) | `public_demo_recruitment.dart` (`publicDemoMayApplicants`), `public_demo_workflow_state.dart` (`.initial()`), `april()`'s event dialog | none dedicated (new test needed) | Reword April event-dialog copy only |
| D. Training explanation | UX EXPLANATION (presentation gap) | `internalTrainingCard()`, `PublicDemoInternalTrainingTransaction`, `PublicDemoGrowthEngine` | `public_demo_internal_training_transaction_test.dart` (domain only; new UI test needed) | Add 1-2 truthful lines to the training card |

---

## 10. Files likely to change (implementation phase)

**lib** (1 file):
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — all four
  findings' fixes land here (`april()`/`may()`/`june()`/
  `_monthlyPrimaryAction`, April event-dialog literals,
  `internalTrainingCard()`).

**test** (extend existing, add focused new cases):
- `test/ui/public_demo/public_demo_01_month_guard_recommended_test.dart`
  (or a new sibling file for April/May/June cases).
- A new or extended file covering the April event-dialog copy and the
  training-card copy (naming left to the implementer; both are small
  additions to existing suites' patterns).

**docs**:
- `docs/reports/SES_FIRST-FUN-YEAR_ONBOARDING-1_Result.md` (the Issue's
  own required result report, at implementation time).
- This audit: `docs/reports/SES_ISSUE-168_PreImplementation_Audit.md`.

No `lib/game/**` (domain), `lib/domain/**`, save-schema, or CI/workflow
file needs to change for the recommended scope.
