# SES CORE-GAMEPLAY Phase 5: Matching Decision Gameplay — Result

Status: **Implementation complete, full test suite green (1905/1905)**

## BASE SHA / branch / HEAD

- BASE SHA (`origin/main` at session start, confirmed PR #210 — CORE-GAMEPLAY
  Phase 4.5 Recruitment/SkillSheet authority — merged):
  `dffbca883258871a57ae95edb908ec9429219b5c` ("Merge PR #210:
  CORE-GAMEPLAY Phase 4.5 Recruitment/SkillSheet authority").
- Branch: `claude/github-issue-205-4zhj9k` — this branch's prior tip
  (`f4ca78f`, "Phase 0A/0B: SES domain models and random generators") was a
  stale ancestor of `origin/main` with no open PR (`list_pull_requests` for
  this branch returned empty), so per the merged/stale-branch-reuse rule it
  was reset onto the BASE SHA above (`git checkout -B ... origin/main`)
  before any new work.
- HEAD after this work: `04e5744a89d9e910bad379c86f63a7ac85c00617`
  ("CORE-GAMEPLAY Phase 5: Matching Decision Gameplay") — the report/PR-URL
  fill-in commit below does not change any production/test file.
- PR: **filled in below after `create_pull_request`** (this line is
  updated by a follow-up commit once the PR exists).

## Read first (per Issue #205)

- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — read in full.
  CORE-GAMEPLAY (this Phase's own track) is explicitly tracked outside this
  document's "Current execution order"/"Prioritized backlog" (its own
  2026-09-08 entries), so this Phase does not touch it.
- `docs/reports/SES_CORE-GAMEPLAY_Phase4_Random-Projects_Result.md` — read
  in full; this Phase is built directly on its "Phase 5 (Matching) handoff"
  section (project query API, canonical `requiredExperienceMonths`,
  regeneration-by-id).
- `SES_CORE-GAMEPLAY_Phase5_Matching-Decision-UX_Design.md` — **does not
  exist in the repository** (confirmed: no file by this name, or containing
  "Matching-Decision" in its name, anywhere under `docs/`). Per the Issue's
  own fallback instruction, the current main implementations listed in the
  Issue were inspected instead, and the Issue's own body was treated as the
  acceptance contract throughout.
- Phase 4.5's own report
  (`docs/reports/SES_CORE-GAMEPLAY_Phase4.5_Recruitment-SkillSheet_Result.md`)
  was also read: its "Phase 5 handoff" section named
  `PublicDemoSkillSheetSheet.show(...)`/`_viewEmployeeSkillSheet` as the
  reusable SkillSheet entry point for this Phase — used verbatim below,
  never re-implemented.

## Reused authority/classes (no second formula, no fake data)

- **`MatchingEngine.computeFit(Engineer, Project)`** — the sole Fit
  computation call in this Phase (`public_demo_matching_fit.dart`'s
  `PublicDemoEngineerProjectFit.compute`). `matching_engine.dart` itself was
  never opened for editing, only read.
- **`FitBreakdown`/`FitDetailItem`/`FitDimension`/`PlayerVisibleFit`**
  (`lib/game/models/fit_result.dart`) — reused directly, not duplicated.
- **`FitBadge`/`fitDetailLabel`** (`lib/ui/widgets/fit_badge.dart`,
  `lib/ui/widgets/labels.dart`) — `fitDetailLabel` reused verbatim for every
  strength/gap line; a small `_ProspectChip` (new, this Phase's own coarse
  面談通過見込み tier — see below) mirrors `FitBadge`'s visual language but
  is a distinct type since it renders `PublicDemoMatchingProspect`, not
  `PlayerVisibleFit`.
- **`languageLabels`/`techDomainLabels`/`projectRankLabels`/
  `clientSpecialtyLabels`/`formatExperience`/`formatYen`** (labels.dart /
  theme.dart) — reused verbatim for every project-card and Fit-detail label;
  no new label map invented.
- **`PublicDemoAggregate.projectCandidatesForMonth`/
  `PublicDemoProjectCandidate`/`PublicDemoSeededProjectGenerator.regenerate`**
  (Phase 4) — the sole project source; every project shown/proposed is a
  real Phase 4 seeded candidate, never a fabricated one. `proposeMatch`
  validates a caller-supplied `projectId` by calling `regenerate` on it —
  a fabricated id is rejected as a no-op (see "Aggregate/domain layer"
  below).
- **`PublicDemoSkillSheetSheet.show(...)` via `_viewEmployeeSkillSheet`**
  (Phase 4.5) — the exact, already-tested, always-available SkillSheet
  presentation; not reimplemented, not forked. Passed through this Phase's
  screens as a caller-supplied callback (`onViewSkillSheet`), exactly like
  the SkillSheet's own display factory already reads
  `PublicDemoEngineerRuntime`/`PublicDemoAssignment` and nothing new.
- **`PublicDemoWorkflowState.assignedEngineerIds(month:)`** — the single
  existing SSOT for "is this engineer currently staffed", reused as-is to
  define "available engineer" for this decision (`availableEngineersForMatching`)
  rather than inventing a second busy/available definition.
- **Project Interview**: confirmed out of scope and not reachable from this
  Phase. `lib/game/engine/project_interview_engine.dart` (the "legacy"
  engine the Issue names) is a **main-game-only** class — it is never
  imported by anything under `lib/game/public_demo/` or
  `lib/ui/public_demo/` (grep-confirmed), and Public Demo's own
  `PublicDemoInterviewEvaluator`/`PublicDemoEngineerSales.evaluateInterview`
  (partner/client interview for the *existing* generic selling pipeline —
  `beginSelling`/`introduceProject`/`recordOrder`) is a different, already
  wired mechanism this Phase does not touch or extend. This Phase
  implements **only** the qualitative "面談通過見込み" prospect the Issue
  explicitly permits ("Phase 5 may show only a coarse qualitative prospect
  if it can be derived truthfully without a new probability formula") — see
  below — never an interactive interview.

## Key finding from investigation: the existing sales pipeline never used real project data

Before writing any code, the existing "selling" pipeline
(`beginSelling`/`introduceProject`/`recordOrder`/`assignOrderedForMay`,
all pre-existing and unchanged by this Phase) was audited. It hard-codes
every `PublicDemoAssignment.projectName` (`'新規開発支援'`,
`'販売管理システム開発'`, `'業務アプリ改修'` — `public_demo_assignment.dart`)
and never asks the player to pick a project at all. This confirms the
Issue's own framing: Phase 5's job is a genuinely new, additive decision
layer (browse real Phase 4 projects → evaluate a real engineer → record a
proposal), not a modification of that existing generic pipeline — which
this Phase leaves completely untouched (see "Do not" compliance below).

## New files

### `lib/game/public_demo/public_demo_matching_fit.dart`

`PublicDemoEngineerProjectFit` — wraps one `MatchingEngine.computeFit` call
per (employee, project) pair:

- **`_placeholderEngineerFor(PublicDemoEngineerRuntime)`** builds the
  minimal `Engineer`/`Applicant` `computeFit` requires. `MatchingEngine`
  needs several `Applicant` fields Public Demo's own
  `PublicDemoEngineerRuntime` does not model at all
  (`PersonalityTraits.communication`/`.cleanliness`, `japaneseLevel`,
  `desiredWorkStyle`) plus several more the formula never reads at all
  (age/education/major/...). The adapter:
  - uses genuinely authoritative Public Demo data for every input the
    dimensions this Phase actually shows read: `primaryLanguage` as
    `mainLanguage`, only the **confirmed** `languageSkills` entries (the
    exact same "only a confirmed language is real" rule
    `PublicDemoSkillSheetDisplayFactory` already enforces — an unconfirmed
    seeded capability entry, e.g. an experienced non-Java hire's proxy Java
    score, is never treated as real language mastery here either — see the
    dedicated test below), `techSkills` verbatim, and the same confirmed
    primary language's `actualExperienceMonths` as `totalItExperienceMonths`
    (the identical "実経験" figure the SkillSheet itself already shows).
  - uses one fixed, documented, never-varying, never-displayed placeholder
    constant for every field only the personality/condition dimensions or
    unrelated shape fields read. Because it never varies per employee, it
    carries no information and cannot be used to back-solve anything.
- **`visibleDetails`** — filters `FitBreakdown.details` down to only
  `FitDimension.language`/`.techDomain`/`.experience`. The
  personality/condition-derived items are never read out — this is the
  concrete mechanism behind "never expose HiddenParameters, raw
  personality/interview parameters, or a score that allows hidden values to
  be back-solved" and "no invented engineer values": Public Demo has no
  authoritative personality/Japanese-level/work-style data for an employee,
  so the only two `FitDetailItem`s a placeholder input could affect are
  simply never surfaced.
- **`PublicDemoMatchingProspect` (`high`/`medium`/`low`, label 高/中/低)** —
  the Issue's own example wording ("面談通過見込み: 高 / 中 / 低"). Derived
  by `fromDetails`, a disclosed, deterministic rule over `visibleDetails`'
  own ◎○△× tiers only (any × → low; all ◎/○ → high; otherwise → medium) —
  **not** a new probability formula over hidden parameters, and never the
  raw `FitBreakdown.total` (which would fold in the placeholder-driven
  personality/condition scores this class never shows).

### `lib/game/public_demo/public_demo_matching_proposal.dart`

`PublicDemoMatchingProposal { engineerId, projectId, decidedMonth }` — the
"minimum explicit state/action" the Issue asks for to hand a decision to
Phase 6. A "見送る" (pass) decision is **not** persisted anywhere —
recording it would be pure redundant state (mirrors Phase 4's own
"再生成可能なデータを無意味に重複保存しない" precedent); nothing about game
state changes when the player passes.

### `lib/ui/public_demo/public_demo_matching_screen.dart`

Two pushed full screens (mirrors the main game's own
`ProjectComparisonScreen`/`project_list_screen.dart` precedent — never a
desktop-style wide table) plus an inline expansion panel for the
decision step (avoids nesting one modal bottom sheet inside another, so
"スキルシートを見る" can reuse the existing `PublicDemoSkillSheetSheet`
bottom sheet cleanly):

1. `PublicDemoProjectMatchingScreen` — 案件を見る: every Phase 4 seeded
   project candidate for the current month, as a card showing project name,
   monthly rate, required skills/technologies, required experience,
   difficulty/rank, payment term, and client tendency (the Issue's own
   field list, verbatim from `PublicDemoProjectCandidate`/`Project`/
   `Client`).
2. `PublicDemoMatchingEngineerScreen` — 社員を選ぶ: every currently
   available engineer (`PublicDemoAggregate.availableEngineersForMatching`),
   each row showing name/summary and a coarse prospect chip. Tapping a row
   expands `_MatchDecisionPanel` in place:
   - 強み/不足を見る: positives/cautions bullet lines, reusing
     `fitDetailLabel` exactly as `FitReasonSheet`'s own `_ReasonLine` does —
     e.g. "・Java: ◎ かなり有力" / "・経験年数: × 厳しい" (the Issue's own
     example wording shape).
   - 面談通過見込み: 高/中/低 chip.
   - スキルシートを見る → `_viewEmployeeSkillSheet` (Phase 4.5's reusable,
     always-available entry point) — unchanged, read-only.
   - 提案する/見送る: 提案する calls `PublicDemoAggregate.proposeMatch`;
     見送る only collapses the panel (no state change, per the proposal
     model's own doc above).

## Aggregate/domain layer (`public_demo_aggregate.dart`, `public_demo_workflow_state.dart`)

Follows this codebase's own strict "no generic mutator, every transition
named and precondition-gated" convention (see `PublicDemoAggregate`'s own
class doc) — never a caller-supplied closure or whole-entity value:

- `PublicDemoWorkflowState.matchingProposals` — new, additive top-level
  list field, exactly like Phase 3's `interviewSessions` (same
  backward-compatible `fromJson` default: absent key → empty list, not a
  rejected save).
- `PublicDemoWorkflowState.withMatchingProposal({engineerId, projectId,
  month})` — a no-op for an unknown `engineerId`; otherwise replaces any
  existing proposal for that engineer (at most one proposal per engineer —
  a later decision supersedes an earlier one rather than accumulating
  history). Deliberately independent of `PublicDemoSalesStage`/
  `salesCapacity`/`salesUsed` — it never advances `stage` or consumes a
  sales slot, so the existing sales-pipeline authority and sales-capacity
  rules are completely untouched by this Phase (Issue requirement:
  "Preserve existing workflow authority and sales-capacity rules").
- `PublicDemoAggregate.availableEngineersForMatching` — every engineer
  minus `workflow.assignedEngineerIds(month: state.month)` (the existing
  SSOT, not a new definition).
- `PublicDemoAggregate.proposeMatch({engineerId, projectId})` — a no-op
  unless `engineerId` is currently available **and** `projectId` resolves
  to a genuine candidate via `PublicDemoSeededProjectGenerator.regenerate`
  (rejects a fabricated id). Otherwise delegates to
  `workflow.withMatchingProposal`.
- `PublicDemoAggregate.matchingProposalFor(engineerId)` — read-only lookup.

No `MatchingEngine` file, `PublicDemoSalesStage` transition, `salesCapacity`/
`salesUsed` field, Finance/revenue code, Month-transition code, or HOME
layout was touched.

## "Do not" compliance (explicit Issue constraints)

| Constraint | Status |
|---|---|
| Do not modify `MatchingEngine` scoring | `matching_engine.dart` read-only, never edited |
| Do not implement Project Interview gameplay | Only a coarse, disclosed qualitative prospect tier is shown; no interactive interview, no new probability formula |
| Do not change Finance, Month transition, balance, recruitment, or HOME | None of `public_demo_state.dart`, `public_demo_monthly_close.dart`, `public_demo_recruitment*.dart`, `lib/presentation/home/`, or HOME layout in the placeholder screen were touched |
| Do not invent project/engineer values | Every project field is read from Phase 4's real `PublicDemoProjectCandidate`; every Fit-relevant employee field is read from `PublicDemoEngineerRuntime`'s own confirmed data — see `_placeholderEngineerFor`'s doc for the one documented, never-displayed, never-varying filler used only to satisfy `Applicant`'s shape |
| Do not expose hidden/raw parameters | `visibleDetails` never surfaces `FitDimension.communication`/`.japanese`; no total/percentage score is ever rendered anywhere in this Phase's UI (dedicated widget-test assertion: `find.textContaining('%')` finds nothing in the decision panel) |

## Visible vs hidden information (Acceptance Criteria)

- **Visible**: project name, monthly rate, required skills/technologies,
  required experience, difficulty/rank, payment term, client tendency
  (project card); strengths/gaps as ◎○△× + label lines for
  language/tech-domain/experience only; 面談通過見込み 高/中/低; full
  SkillSheet via the existing sheet.
- **Hidden/never rendered**: `HiddenParameters` (any field), personality
  traits, the raw `FitBreakdown.total`/percentage, the
  personality/condition sub-scores, and the interview-only fields the
  SkillSheet itself already excludes pre-Phase-6 (interviewScore/
  acceptanceScore/salesSkillFit — untouched, Phase 4.5's own rule).

## Proposal handoff for Phase 6

- `PublicDemoAggregate.matchingProposalFor(engineerId)` → the current
  `PublicDemoMatchingProposal?` for that engineer — Phase 6 can resolve its
  `projectId` back to the full candidate via
  `PublicDemoSeededProjectGenerator.regenerate({runSeed, projectId})`
  (Phase 4's own id-based recovery, no new lookup needed) and its
  `decidedMonth` for display/ordering.
- No sales-pipeline stage is advanced by proposing — Phase 6 decides how
  (or whether) a proposal feeds into `PublicDemoSalesStage`/
  `beginSelling`/`introduceProject`/the interview pipeline; this Phase
  intentionally leaves that wiring entirely to Phase 6, per "Do not
  implement the interactive Project Interview itself in this Issue."

## UI constraints verification

- Public Demo mobile portrait: both new screens are `Scaffold`+`ListView`,
  no desktop table.
- 390×844 / 360×800: verified via the existing Sales-tab overflow suite
  (`public_demo_sales_visual_complete_test.dart`'s "360x800 / 390x844,
  TextScaler 1.0/1.3/2.0" group), which now also renders this Phase's new
  always-visible "案件マッチング" entry card — all cases still pass, no new
  overflow introduced.
- TextScaler 1.0/1.3/2.0 safety: same suite, unchanged pass rate (63/63 in
  the targeted Sales-tab run below).
- Bottom-sheet/dialog convention: the SkillSheet step reuses the existing
  bottom sheet unchanged; the Fit/strengths-gaps/propose-pass step is an
  inline expansion (no new stacked modal); the two list screens mirror the
  main game's own pushed-screen precedent (`ProjectComparisonScreen`),
  never a desktop table.
- HOME frozen: `lib/presentation/home/` and the placeholder screen's HOME
  tab body were not touched. `public_demo_sales_visual_complete_test.dart`'s
  own "HOME Freeze regression" test (none of the new widgets leak into
  HOME) still passes.

## Entry point

A new, always-visible (not month-gated — Phase 4's seeded pool exists every
month from April onward) "案件マッチング" section was appended as a 5th
section at the end of the 営業タブ (`_buildSalesTab`), after the existing
4 sections from Sales UI Phase 1 (unchanged). A single card with a
"案件を見る" button opens `PublicDemoProjectMatchingScreen`. No existing
Sales-tab section, key, card, or eligibility check was modified.

## Determinism

`PublicDemoEngineerProjectFit.compute` is a pure function of
`(PublicDemoEngineerRuntime, Project)` — same engineer × same project always
produces the same `visibleDetails`/`prospect` (dedicated test: two calls
with identical inputs produce identical ratings/prospect). Since both
inputs are themselves already deterministic (`PublicDemoEngineerRuntime` is
persisted/reload-stable; `Project` is Phase 4's seed-derived, reload-stable
candidate), this satisfies "Same engineer/project produces deterministic
matching output."

## Tests

Environment: Flutter 3.44.9 (matching this repo's CI pin and Phase 1-4's
own environment note), downloaded to `/opt/flutter` for this session (no
Flutter SDK preinstalled).

- `flutter analyze` (whole project): **No issues found.**
- `git diff --check`: clean (screenshot PNGs incidentally modified by an
  unrelated golden/screenshot test during the full-suite run were reverted
  before commit — confirmed via `git log` that they predate this Phase and
  are untouched by any file this Phase changed).
- New: `test/game/public_demo/public_demo_matching_test.dart` (17 tests) —
  `PublicDemoEngineerProjectFit.compute` determinism, the
  language/techDomain/experience-only `visibleDetails` guarantee, proof
  that changing `hidden.projectInterviewSkill` never changes what's shown
  (personality dimension is never surfaced), proof that an *unconfirmed*
  seeded language-capability entry is never treated as real language
  experience, `PublicDemoMatchingProspect.fromDetails`'s tier rule (4
  cases), `availableEngineersForMatching` (before/after a real assignment,
  using the existing `publicDemoAggregateAtMonth`/
  `publicDemoAdvanceEngineerToOrdered` test fixtures), `proposeMatch`
  (records/replaces/no-ops on a fabricated project id, an unknown engineer
  id, and an engineer already staffed elsewhere), and
  `matchingProposals` JSON round-trip + legacy-save (missing key)
  compatibility.
- New: `test/ui/public_demo/public_demo_matching_screen_test.dart` (4
  widget tests) — the Sales-tab entry point opens the project list; picking
  a project opens the engineer list with both founding engineers listed as
  available; picking an engineer expands the strengths/gaps + 面談通過見込み
  panel, opens the real SkillSheet sheet, and proposing disables the button
  and shows "提案済み" (with an explicit `find.textContaining('%')` →
  `findsNothing` assertion guarding against ever rendering a raw score);
  passing collapses the panel without any state change.
- Updated: `test/game/public_demo/public_demo_recovery_aggregate_test.dart`
  — one pre-existing test asserted the exact workflow-JSON key set
  (`{applicants, engineers, assignments, interviewSessions}`); updated to
  include the new additive `matchingProposals` key, exactly mirroring how
  Phase 3 previously updated this same assertion for `interviewSessions`.
  This is the one pre-existing test this Phase's change required editing.
- Regression suites re-run in full and green: the entire Sales-tab suite
  (`public_demo_sales_ui_phase1_test.dart`,
  `public_demo_sales_visual_complete_test.dart`,
  `public_demo_01_home_ui_3c_density_test.dart` — 63/63), plus the full
  project test suite.
- Full suite: `flutter test --concurrency=6` (whole `test/` tree) —
  **1905 passed, 0 failed** (1876 pre-existing + 17 new matching-logic + 4
  new widget tests; the one pre-existing test updated above is counted in
  the 1876).

## Known limitations

- **`PublicDemoMatchingProspect` is a disclosed heuristic, not the real
  Matching/interview formula** — by design (Issue: "may show only a coarse
  qualitative prospect if it can be derived truthfully without a new
  probability formula"). It only ever aggregates the three already-shown
  ◎○△× tiers; Phase 6 is free to define its own real interview-passage
  logic independently.
- **A "見送る" (pass) decision is never recorded** — by design (see
  `PublicDemoMatchingProposal`'s own doc); Phase 6 (or a later phase) may
  choose to add this if the design calls for remembering passed pairs.
- **Personality/condition Fit dimensions are permanently unavailable for
  Public Demo employees** with the current `PublicDemoEngineerRuntime`
  shape (no personality traits, Japanese level, or desired work style
  modeled at all) — not a Phase 5 gap to fix, but a standing fact any
  future phase reusing `MatchingEngine.computeFit` for Public Demo should
  be aware of.
- **Proposing does not consume a sales slot or advance
  `PublicDemoSalesStage`** — intentional (Issue: preserve existing
  authority; do not implement Project Interview). Phase 6 decides how a
  proposal ultimately connects to (or replaces/extends) the existing
  generic selling pipeline this Phase found already hard-coding
  `projectName`.
- **`availableEngineersForMatching` does not exclude an engineer with an
  existing, not-yet-superseded proposal** — a player can still browse and
  re-propose that engineer to a different project (the later proposal
  simply replaces the earlier one, per `withMatchingProposal`'s own doc).
  This was a deliberate simplicity choice, not an oversight; nothing in the
  Issue requires locking an engineer once proposed.

## Phase 6 handoff

1. `PublicDemoAggregate.matchingProposalFor(engineerId)` is the entry point
   for "does this engineer have a pending decision" and what project it
   names.
2. `PublicDemoSeededProjectGenerator.regenerate({runSeed, projectId})`
   (Phase 4, unchanged) recovers the full `Project`/`Client` for a
   proposal's `projectId` with no new lookup needed.
3. `PublicDemoEngineerProjectFit.compute({runtime, project})` is available
   for Phase 6 to reuse if it wants the same truthful strengths/gaps
   framing during the interview itself, rather than re-deriving anything.
4. The existing generic `beginSelling`/`introduceProject`/`recordOrder`/
   `assignOrderedForMay` pipeline is completely untouched — Phase 6 decides
   whether/how a `PublicDemoMatchingProposal` feeds into it, replaces its
   hard-coded `projectName`, or exists alongside it.

## Final verdict

**PASS** — implementation complete, every Acceptance Criteria item verified
above, zero regressions across the full 1905-test suite, `flutter analyze`
clean, `git diff --check` clean.
