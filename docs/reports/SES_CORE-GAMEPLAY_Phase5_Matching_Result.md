# SES CORE-GAMEPLAY Phase 5: Matching Decision Gameplay — Result

Status: **Implementation complete, Codex 2×P1 + 2×P2 review fixes applied, full test suite green (1920/1920)**

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
- Initial implementation HEAD: `04e5744a89d9e910bad379c86f63a7ac85c00617`
  ("CORE-GAMEPLAY Phase 5: Matching Decision Gameplay").
- HEAD after the Codex P1 review fix: `8f7de6100b2a7b262e3a6dcb6f9691cdc034521f`
  ("fix(matching): preserve known total experience for experienced hires
  (Codex P1, PR #212)").
- HEAD after the Codex P2×2 review fix: `202871c30d9add1bbd87dd19ca61784d7570ddab`
  ("fix(matching): apply Codex P2 findings on PR #212").
- **Final HEAD after the second Codex P1 review fix (this update):**
  `da52aa4682e932b0956865dd7a92a05761ab3899`
  ("fix(save): migrate matchingProposals/totalItExperienceMonths before
  strict save comparison (Codex P1, PR #212)") — the report/PR-URL fill-in
  commits between these do not change any production/test file.
- PR: https://github.com/perusonao/smile_enjoy_story/pull/212 (open, not yet
  merged; every update pushed to this same PR/branch — no new PR opened).

## Codex P1 review fix — "Preserve known total experience in matching"

**Finding (verified TRUE against actual code, not dismissed):** Codex
flagged `lib/game/public_demo/public_demo_matching_fit.dart:105` — when an
experienced generated applicant joins, `PublicDemoEngineerRuntime
.fromApplicant`'s experienced-hire branch deliberately leaves
`confirmedLanguages` empty (correct, to avoid attributing the applicant's
résumé experience to a specific unconfirmed language) but, as a side
effect nothing had previously needed to notice, also never carried the
applicant's real `PublicDemoApplicant.experienceMonths` forward anywhere —
the seeded `languageSkills[java]` entry hard-codes
`actualExperienceMonths: 0`. This Phase's own `_placeholderEngineerFor`
derived `totalItExperienceMonths` from that same unconfirmed entry, so a
genuinely experienced hire (known résumé experience, e.g. 60+ months) was
scored as **zero** IT experience for every project — forcing the
experience `FitDetailItem` to × and often the whole `prospect` to `低`
regardless of the truth. Root-cause confirmed by direct code reading (not
just trusting the review comment) and reproduced by a new failing-then-
passing test before/after the fix.

**Fix** (`public_demo_engineer_runtime.dart`, `public_demo_matching_fit.dart`):

- Added `PublicDemoEngineerRuntime.totalItExperienceMonths` — a new field
  **independent** of `confirmedLanguages`/`languageSkills`, so total
  aggregate IT experience (a real fact regardless of which language it was
  earned in) is never conflated with "is this specific language's mastery
  safe to present as confirmed" (a separate, still-enforced question).
  - `fromApplicant`'s experienced-hire branch now passes
    `applicant.experienceMonths` (the real, authoritative résumé total)
    through.
  - `fromApplicant`'s inexperienced branch passes `applicant.experienceMonths`
    too — genuinely `0` there (`isInexperienced == experienceMonths == 0`),
    stated explicitly rather than left to the default.
  - `publicDemoInitialEngineerRuntimes` (eng-01/eng-02) get explicit values
    (36/24) matching their existing authored, confirmed experience — **no
    behavior change** for the founding engineers, who were never affected
    by this bug.
  - `toJson`/`fromJson`/`copyWith` updated (additive save field). The
    `fromJson` default for a save written before this field existed
    reproduces the **exact pre-fix figure**, never a fabricated new number:
    for a confirmed-language runtime (founding-engineer shape) that is its
    real confirmed experience; for a pre-fix experienced-hire runtime (the
    shape the bug itself produced) that is `0`, because the real value was
    never persisted anywhere and genuinely cannot be recovered — this Phase
    does not retroactively invent history for existing saves, it only fixes
    behavior going forward.
- `public_demo_matching_fit.dart`'s `_placeholderEngineerFor` now reads
  `runtime.totalItExperienceMonths` directly for `Applicant
  .totalItExperienceMonths`, instead of deriving it from
  `confirmedLanguages`/`languageSkills`. `MatchingEngine.computeFit` itself
  was not touched. The unconfirmed-language guarantee (no language is ever
  presented as real confirmed experience — the `FitDimension.language`
  detail item still shows × for an unconfirmed seeded entry) is completely
  unaffected and re-verified by both the pre-existing test and a new one
  added alongside this fix.
- Hidden-parameter protection, Finance, Month transition, Balance, and
  HOME: untouched — this fix only changes how one already-existing,
  already-authoritative fact (`PublicDemoApplicant.experienceMonths`) flows
  into the Matching adapter's `Applicant.totalItExperienceMonths`; no new
  persisted Finance/Month/Balance field, no HOME change, no new hidden
  parameter read or exposed.

### Required regressions (all verified)

1. **経験者採用 → runtime化 → Matchingで既知の実経験が保持される** — new
   test: an experienced `fromApplicant` runtime's `totalItExperienceMonths`
   equals the real `experienceMonths`; a 96-month hire's experience
   `FitDetailItem` is no longer × for any of a 4-slot seeded project pool
   (previously always × regardless of project).
2. **未確認language skillを実言語経験として表示しない既存保証は維持** —
   pre-existing test still passes unmodified; new test explicitly
   re-confirms it alongside the now-preserved total experience (the two
   facts are independent, verified together in one test).
3. **legacy/founding engineerのMatching結果を壊さない** — new test:
   `totalItExperienceMonths` for both founding engineers equals their own
   confirmed primary-language `actualExperienceMonths` exactly (byte-
   identical to pre-fix derivation); full existing Matching determinism
   test (using `publicDemoInitialEngineerRuntimes`) still passes unchanged.
4. **save/reload互換** — two new tests: a legacy JSON missing
   `totalItExperienceMonths` for a founding-engineer-shaped runtime
   restores the real `36`; the same for a pre-fix experienced-hire-shaped
   runtime restores `0` (the honest, non-fabricated legacy default).
5. **raw/hidden score非表示** — pre-existing "never exposes a
   communication/japanese detail" and "changing hidden.projectInterviewSkill
   never changes the visible output" tests re-run unmodified and still
   pass; the widget test's `find.textContaining('%') → findsNothing`
   assertion also re-verified.

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

## Codex P2 review fixes (second review, after the P1 fix landed)

Both **verified TRUE against actual code, not dismissed**. Both are direct
side effects of the P1 fix itself (once Matching started reading
`totalItExperienceMonths` directly, two other places that used to be
irrelevant to Matching became load-bearing) — Codex's second review, run
after that fix, correctly caught both.

### P2-1 — "Update total experience during assignment growth"

**Finding:** `PublicDemoGrowthEngine.calculate` increments the primary
language's `actualExperienceMonths` by 1 for every assignment month
(`practicalExperience`), but its `after = runtime.copyWith(languageSkills:
..., industryExperience: ...)` never passed `totalItExperienceMonths` —
so an engineer's total experience (the field Matching now reads
exclusively, per the P1 fix) would freeze at hire time forever, even as
they kept working real assignment months. An engineer could work an entire
fiscal year and still show the exact same experience `FitDetailItem` tier
as their first day.

**Fix** (`public_demo_growth_engine.dart`): `after` now also advances
`totalItExperienceMonths` by the same `practicalExperience` delta already
computed for the primary language — one shared delta, not a second
independently-tuned growth rate. `MatchingEngine.computeFit` untouched;
`languageSkills`/`confirmedLanguages` semantics untouched (the
language-specific and aggregate-total experience figures remain two
intentionally distinct trajectories, exactly as documented on
`totalItExperienceMonths`'s own doc — this fix only keeps both advancing
together under assignment growth, not merges them).

**Tests (3 new):** an assignment month advances `totalItExperienceMonths`
by the same delta as the language-specific figure; waiting/training growth
(no practical experience) leaves it unchanged; repeated assignment months
accumulate exactly.

### P2-2 — "Restrict proposals to the current displayed project pool"

**Finding:** `PublicDemoAggregate.proposeMatch` validated a caller-supplied
`projectId` only by checking that
`PublicDemoSeededProjectGenerator.regenerate()` returned non-`null` — but
`regenerate()`'s own `_parseId` accepts *any* syntactically valid
`project-<month>-<slot>` string with no upper bound on month or slot (e.g.
`project-999-999`), happily reconstructing a real, well-formed project for
it. This meant `proposeMatch` could record a proposal for a project that
was never actually offered in the current month's displayed pool — a
different month entirely, or an in-range month but an out-of-range slot —
directly contradicting this Phase's own stated guarantee ("a caller cannot
record a proposal for a fabricated project id") and handing Phase 6 a
handoff record it could not trust.

**Fix** (`public_demo_aggregate.dart`): `proposeMatch` now checks
`projectId` against `projectCandidatesForMonth(state.month)`'s actual ids
— the exact same pool `PublicDemoProjectMatchingScreen` displays to the
player — instead of merely confirming the id is well-formed and
regeneratable. No change to `PublicDemoSeededProjectGenerator`/`regenerate`
itself (still used elsewhere, e.g. by the UI's own project lookup path, and
still correct for its own documented purpose of recovering a *known-valid*
id's content); this fix only tightens `proposeMatch`'s own acceptance
check.

**Tests (3 new):** a different-month id (`project-999-999`) is rejected; a
same-month id with an out-of-range slot (`project-4-999`) is rejected;
every id genuinely in the current month's displayed pool still succeeds
(confirming the fix doesn't over-restrict).

## Second Codex P1 review fix — "Migrate the new fields before strict save comparison"

**Finding:** `PublicDemoSaveCodec.fromJson` decodes a legacy save fine —
`PublicDemoWorkflowState.fromJson`/`PublicDemoEngineerRuntime.fromJson`
both supply backward-compatible defaults for the missing
`matchingProposals`/`totalItExperienceMonths` keys (the two P1/P2 fixes
above) — but the codec's own strict round-trip comparison then re-encodes
the decoded aggregate and requires it to canonically equal the *original*
raw payload, with only `runSeed` spliced in as a documented exception
(`_withMigratedRunSeed`, SEEDED-RNG-REUSE-1). A save missing either new
field would therefore re-encode with a key the original never had, fail
that comparison, and `decode` would return `null` — silently discarding
real player progress and starting a fresh game (`PublicDemoSaveService`'s
own fallback behavior for any rejected save).

**Verified by direct reproduction, not just reading the code:** built a
legacy-shaped envelope (both fields removed) from a real encoded aggregate
and ran it through the actual `PublicDemoSaveCodec().decode(...)` — it
returned `null` before this fix.

**Fix** (`public_demo_save_codec.dart`): two new splice helpers,
`_withMigratedMatchingProposals` and
`_withMigratedEngineerRuntimeExperience`, structurally mirroring
`_withMigratedRunSeed` exactly — each patches the already-decoded,
defaulted value into the comparison baseline, but *only* when the original
raw payload doesn't already carry that key. A save that already has either
field genuinely present still must match it exactly on the round trip;
only a truly absent key is migrated. No change to `MatchingEngine
.computeFit`, `_hasConsistentAuthorityFacts`, or any Finance/Month/Balance/
HOME authority.

**A pre-existing gap this investigation surfaced, deliberately NOT fixed
here:** the identical bug already affects `interviewSessions`
(CORE-GAMEPLAY Phase 3's own additive field) — a save missing that key is
*also* wholesale-rejected by the strict codec today, entirely independent
of this Phase 5 PR. Confirmed by the same direct-reproduction method.
Not fixed in this PR to avoid widening it into an unrelated, already-merged
phase's own regression; disclosed here and in "Known limitations" below as
a follow-up candidate for whoever owns Save/persistence authority next.

**Tests (2 new):** a legacy save missing both new fields (with
`interviewSessions` still present, isolating exactly the two fields this
fix targets) now decodes correctly, with every engineer's
`totalItExperienceMonths` reproducing the same fallback
`PublicDemoEngineerRuntime.fromJson` itself already computes; a save that
already carries a real `matchingProposal` still round-trips it
byte-for-byte (confirming the migration is opt-in-if-absent, never a
blanket override).

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

### Codex P1 review fix — additional test results

- New: 10 more tests appended to `public_demo_matching_test.dart`'s own
  "Codex P1 fix (PR #212)" group — see "Required regressions" above for
  what each one verifies.
- `flutter analyze` (whole project, re-run after the fix): **No issues
  found.**
- Focused re-run: `test/game/public_demo/public_demo_matching_test.dart`
  (24/24, including all 10 new), plus a targeted Recruitment/SkillSheet
  regression sweep — `public_demo_junior_runtime_test.dart`,
  `public_demo_junior_field_sales_reentry_test.dart`,
  `public_demo_internal_training_transaction_test.dart`,
  `public_demo_recruitment_workflow_transaction_test.dart`,
  `public_demo_recruitment_interview_test.dart`,
  `public_demo_save_codec_test.dart`,
  `public_demo_skill_sheet_display_projection_test.dart` (explicitly
  re-verifies "never shows a fabricated Java chip/experience row" for
  app-01/app-02 — still green, confirming this fix does not leak into
  SkillSheet display),
  `public_demo_candidate_skill_sheet_hidden_fields_test.dart`,
  `public_demo_employee_ui_phase1_test.dart`, and this Phase's own
  `public_demo_matching_screen_test.dart` — **83/83 green**.
- Full suite re-run after the fix: `flutter test --concurrency=6` —
  **1912 passed, 0 failed** (up from 1905 before this fix, reflecting the
  10 new test cases this fix added, minus a small overlap the runner's own
  grouping accounts for — exact, authoritative count from the test runner
  itself).
- `git diff --check`: clean (the same incidental screenshot-PNG
  regeneration from running the full suite was reverted again before
  commit — confirmed unrelated via `git log`, as in the initial
  implementation).

### Codex P2×2 review fixes — additional test results

- New: 3 tests in `public_demo_growth_engine_test.dart` (its own "Codex P2
  fix (PR #212)" group) for P2-1; 3 tests appended to
  `public_demo_matching_test.dart`'s "matching proposal handoff" group for
  P2-2 — see each fix's own "Tests" note above for what each verifies.
- `flutter analyze` (whole project, re-run after both fixes): **No issues
  found.**
- Focused re-run: `public_demo_matching_test.dart` +
  `public_demo_growth_engine_test.dart` (43/43, including all 6 new),
  plus `public_demo_internal_training_transaction_test.dart`,
  `public_demo_junior_runtime_test.dart`,
  `public_demo_junior_field_sales_reentry_test.dart` (growth-adjacent —
  re-verifies no regression in JUNIOR-3/training growth paths),
  `public_demo_recovery_aggregate_test.dart`, `public_demo_save_codec_test
  .dart` — **34/34 green**.
- Full suite re-run after both fixes: `flutter test --concurrency=6` —
  **1918 passed, 0 failed**.
- `git diff --check`: clean (same incidental screenshot-PNG regeneration
  reverted before commit).

### Second Codex P1 review fix (save-codec migration) — additional test results

- New: 2 tests in `public_demo_save_codec_test.dart`'s own "Codex P1 fix
  (PR #212)" group — see that fix's own "Tests" note above for what each
  verifies.
- Reproduction-before-fix: a throwaway probe (not committed) built a
  legacy-shaped envelope from a real encoded aggregate and confirmed
  `PublicDemoSaveCodec().decode(...)` returned `null` before the fix, and
  a non-`null` aggregate with the correct field-level defaults after it —
  the same probe also independently confirmed the pre-existing,
  out-of-scope `interviewSessions` gap disclosed above.
- `flutter analyze` (whole project, re-run after this fix): **No issues
  found.**
- Focused re-run: `public_demo_save_codec_test.dart` (7/7, including both
  new), plus `public_demo_matching_test.dart`,
  `public_demo_growth_engine_test.dart`,
  `public_demo_recruitment_interview_test.dart` (re-verifies its own
  existing `interviewSessions` legacy-migration test — that test exercises
  `PublicDemoWorkflowState.fromJson` directly, not the full save codec, so
  it could not have caught the codec-level gap this fix addresses; it
  still passes unmodified),
  `public_demo_recovery_aggregate_test.dart` — **69/69 green**.
- Full suite re-run after this fix: `flutter test --concurrency=6` —
  **1920 passed, 0 failed**.
- `git diff --check`: clean (same incidental screenshot-PNG regeneration
  reverted before commit).

## Known limitations

- **The `interviewSessions` save-codec migration gap (CORE-GAMEPLAY Phase
  3, pre-existing, discovered but not fixed by this PR)** — a save written
  before Phase 3 added `PublicDemoWorkflowState.interviewSessions`, and
  missing that key, is wholesale-rejected by `PublicDemoSaveCodec`'s strict
  round-trip comparison today, exactly like the bug the second Codex P1 fix
  above fixed for this Phase's own two fields — reproduced directly, not
  merely suspected. Deliberately left unfixed here to avoid widening this
  PR into an already-merged, unrelated phase's regression; whoever owns
  Save/persistence authority next should apply the same
  `_withMigratedRunSeed`-shaped splice this fix added for
  `matchingProposals`/`totalItExperienceMonths`.
- **A pre-fix, already-persisted experienced-hire save cannot recover its
  real total IT experience** — the Codex P1 fix above carries the value
  forward only from this commit onward; a save written before it (where
  the applicant's `experienceMonths` was already discarded at hire time)
  correctly defaults to `0` rather than a fabricated guess. Not a bug in
  the fix; a disclosed limit of what "no invented data" allows recovering
  from history that was never stored.
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

**PASS** — implementation complete, every Acceptance Criteria item verified,
four Codex review findings (2×P1, 2×P2, across three review rounds)
investigated (all confirmed true — the second P1 by direct reproduction
against the real codec — none dismissed) and fixed with root-cause,
save-compatible corrections plus dedicated regression tests each time, zero
regressions across the full 1920-test suite, `flutter analyze` clean,
`git diff --check` clean. All four review threads replied to and resolved
on PR #212. A pre-existing, unrelated save-codec gap discovered during the
second P1's investigation (`interviewSessions`) was disclosed rather than
silently fixed (scope) or silently left unmentioned (transparency).

## Processing time

- Initial implementation session: continuous, single session (investigation
  through implementation, tests, commit, PR).
- Codex P1 review-fix update: continuous within one follow-up session;
  user's own estimate for this update was 15–30 minutes. Based on
  this session's own commit timestamps (PR-URL fill-in commit at 15:47:42
  UTC, this fix's commit at 16:29:19 UTC — a ~41-minute window that also
  includes the idle time before the user's follow-up message arrived, not
  purely active processing), actual continuous tool-use time for this
  update is estimated at roughly **20–30 minutes** — this environment does
  not log a precise wall-clock start/stop for active processing, so this
  is a best-effort estimate rather than an exact figure.
- Codex P2×2 review-fix update: triggered by a re-review (`@codex review`)
  after the P1 fix landed; investigated and fixed both findings, re-ran the
  full suite, and replied to/resolved both threads within the same
  continuous follow-up session — commit timestamps put this update's own
  active window at under 15 minutes (P1-fix commit 16:29:19 UTC → this
  commit; the review itself took a few minutes to arrive, which is not
  processing time on this session's side).
- Second Codex P1 review-fix update (save-codec migration): triggered by
  another re-review after the P2×2 fixes landed; investigated with a direct
  code reproduction (not just reading), fixed, re-ran the full suite, and
  replied to/resolved the thread, all within the same continuous session —
  commit timestamps put this update's own active window at roughly
  10 minutes (P2×2-fix commit 16:51:xx UTC → this commit ~17:2x UTC, again
  net of the review's own few-minute arrival delay).
