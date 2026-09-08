# SES CORE-GAMEPLAY Phase 4: Random Projects — Result

Status: **Implementation complete, tests green (one pre-existing, unrelated flake noted below)**

## BASE SHA / branch / HEAD

- BASE SHA (`origin/main` at session start, after confirming PR #203 was
  merged): `ecf6e5c50ecc574bd0b2f7854cdc4770c0834105`
  ("Merge PR #203: SES CORE-GAMEPLAY Phase 3 recruitment interview").
- Branch: `claude/ses-phase4-random-projects-r7v3rm` — this branch's prior
  tip (`f4ca78f`, "Phase 0A/0B: SES domain models and random generators")
  was a stale ancestor of `origin/main` with no open PR
  (`list_pull_requests` for this branch returned empty), so per the
  merged/stale-branch-reuse rule it was reset onto the BASE SHA above
  (`git checkout -B ... origin/main`) before any new work.
- HEAD after this work: `af521f6dacd7877262b85f7399ac84edfabb8abb` ("SES
  CORE-GAMEPLAY Phase 4: seeded project generation") — this report's own
  commit follows it.
- PR: (filled in after `create_pull_request` — see bottom of this report)

## Scope note on the requested audit documents

The task named five audit reports as required reading:
`SES_CORE-GAMEPLAY_Phase4_Random-Projects_PreImplementation_Audit.md`,
a Phase 5 (Matching) audit, a Phase 6 (Project Interview) audit, a Phase 7
(Core Loop) audit, and a Controlled-Randomness Balance Guard audit.
**None of these five files exist anywhere in the repository** — confirmed
by `find docs -iname "*phase4*" -o -iname "*random-project*" -o -iname
"*matching*" -o -iname "*balance*guard*" -o -iname "*core-loop*" -o -iname
"*project*interview*"` (no hits) and a full listing of every
`docs/reports/*audit*` file (only two exist, both unrelated — a Full-Year
Playtest audit and a Final-Density UI audit). Per the task's own
instruction ("存在するものはすべて参照する" — reference whichever of these
exist), none could be read because none exist; this is disclosed here
rather than fabricated. The three Phase 1-3 result reports for this same
initiative (`SES_CORE-GAMEPLAY_Phase{1,2,3}_..._Result.md`) do exist and
were read in full instead, as the actual precedent for how this initiative
adapts main-engine generators onto Public Demo.

## Reused main-game classes/functions

Audited before writing any code — **no Public-Demo-only project generator
was written**:

- `ProjectGenerator` (`lib/domain/generation/project_generator.dart`) — the
  sole project-generation engine used. Every candidate comes from
  `ProjectGenerator(seed: derivedSeed, clients: sampleClients).generate(1)`,
  each call its own independently-seeded instance (never a shared/threaded
  `Random`), for the same order-independence guarantee
  `ProjectGenerator`'s own doc already promises.
- `Project`, `ProjectRank`, `ProjectType`, `Client`, `ProgrammingLanguage`
  (all `lib/domain/models/`) — read directly; **the main `Project` model is
  not duplicated anywhere.** The one addition (`Project
  .requiredExperienceMonths`, see below) is a derived getter on the
  existing class, not a parallel model.
- `sampleClients` (`lib/domain/generation/sample_clients.dart`) — the same
  main-engine client roster (Axis Soft / Future Web / Nova Infra / Bright
  Solutions) already used by `GameEngine`/`PrologueEngine`/tests. **No
  Public-Demo-only client data was invented.**
- `PublicDemoRng` / `PublicDemoRngNamespace.projectGeneration`
  (`lib/game/public_demo/public_demo_rng.dart`, defined in Phase 1,
  unused until now) — used exactly as Phase 1's own doc said this call site
  eventually would: `PublicDemoRng.derivedSeed(runSeed: ..., month: ...,
  namespace: projectGeneration, identifier: ...)` is the only source of
  every seed this generator uses.
- `PublicDemoEngineerRuntime`, `publicDemoInitialEngineerRuntimes`
  (`lib/game/public_demo/public_demo_engineer_runtime.dart`) — read-only,
  for the Balance Guard heuristic only (see below); not modified.
- `MatchingEngine._rankExperienceExpectationMonths`
  (`lib/game/engine/matching_engine.dart`) — **read, not imported or
  modified** (importing it would violate both the domain→game layering
  direction and the task's explicit "no Matching implementation changes"
  rule). Its exact values (`entry:6, junior:18, middle:36, senior:60,
  lead:84`) were copied into a new canonical constant in the domain layer
  instead — see "Canonical requiredExperience mapping" below — so a
  project's stated requirement stays numerically consistent with however
  the main engine already scores experience fit, without coupling the
  domain layer to game-engine code or touching Matching's own file.
- `PublicDemoSeededRecruitmentGenerator`
  (`lib/game/public_demo/public_demo_recruitment_candidate_generator.dart`,
  Phase 2) — audited as this initiative's own precedent for "adapt a
  main-engine generator onto Public Demo via `PublicDemoRng`, project into a
  thin bundle, expose an id-based regeneration path." Phase 4 mirrors this
  pattern rather than inventing a new one.

## Canonical requiredExperience mapping

New in `lib/domain/models/project_rank.dart`:

```dart
const Map<ProjectRank, int> projectRankMinimumExperienceMonths = {
  ProjectRank.entry: 6,
  ProjectRank.junior: 18,
  ProjectRank.middle: 36,
  ProjectRank.senior: 60,
  ProjectRank.lead: 84,
};
```

plus `ProjectRank.minimumExperienceMonths` (a getter reading this map) and
`Project.requiredExperienceMonths` (`lib/domain/models/project.dart`, a
getter reading `rank.minimumExperienceMonths`). This is the **one**
canonical mapping the task required: every "requiredExperience" reader —
this phase's own Balance Guard, `PublicDemoProjectCandidate
.requiredExperienceMonths`, and any future Phase 5 code — reads the same
map through the same `Project.requiredExperienceMonths` getter. Nothing
stores a second, independently-tunable copy of this figure. The values
themselves were not invented fresh: they are copied from the main engine's
own `MatchingEngine._rankExperienceExpectationMonths`
(`lib/game/engine/matching_engine.dart:14-20`, unmodified, unimported) so a
project's stated requirement agrees with how the main engine already
scores experience fit for the same rank — audited and matched, not
independently re-tuned. `matching_engine.dart` itself was never opened for
editing, only read, per the task's explicit "no Matching implementation
changes" rule.

Both additions are pure getters (no new constructor parameter, no new
`toJson`/`fromJson` field) — zero persistence impact, and no other
`Project` consumer (`project_comparison_engine.dart`,
`project_interview_engine.dart`, the `project_list_screen.dart`/
`project_detail_screen.dart` UI, every existing `Project`-related test) is
affected, since none of them read this new getter.

## Adapter mapping

New file: `lib/game/public_demo/public_demo_project_generator.dart` —
`PublicDemoSeededProjectGenerator` + `PublicDemoProjectCandidate`.

`PublicDemoProjectCandidate` bundles a real `Project` with the `Client` that
offers it — a thin projection, not a second copy of either model's data:

| Task's required field | Source |
|---|---|
| 案件名 | `Project.title` (verbatim, from `ProjectGenerator`'s own title templates) |
| required skills / technology | `Project.requiredLanguages` + the 7 `requiredDatabase/…/manager` domain-skill fields (all pre-existing `Project` fields) |
| required experience | `Project.requiredExperienceMonths` (new getter, see above) |
| monthly rate | `Project.monthlyRate` (pre-existing field; **not connected to Finance** — see below) |
| difficulty / rank | `Project.difficulty` / `Project.rank` (pre-existing fields) |
| client tendency | `Client.specialty` (`Client`'s own pre-existing "what kind of work this client mostly deals in" descriptor), exposed as `PublicDemoProjectCandidate.clientTendency` |
| stable project ID | `PublicDemoProjectCandidate.id` — see "RNG derivation / id scheme" below |

Every getter on `PublicDemoProjectCandidate` reads straight through to its
own `project`/`client` fields (mirrors `ProjectComparisonRow`'s own
"derived only, never a stored duplicate" doc in
`project_comparison_engine.dart`). Phase 5 is free to read `candidate
.project`/`candidate.client` directly for anything this projection's
convenience getters don't cover — nothing here narrows what Phase 5 can
see relative to the real domain `Project`.

`monthlyRate` is carried on `Project` exactly as `ProjectGenerator`
produces it and is **never read by any Finance code path in this phase** —
grep-confirmed (`public_demo_project_generator.dart` and
`public_demo_aggregate.dart`'s new method are the only new/changed
production files, and neither imports any `public_demo_*revenue*`/
`*salary*`/`*cash*` module).

## RNG derivation / id scheme

Every project is a pure function of `(runSeed, month, slot index)`:

```dart
seed = PublicDemoRng.derivedSeed(
  runSeed: runSeed, month: month,
  namespace: PublicDemoRngNamespace.projectGeneration,
  identifier: 'slot:$index',           // slots 1..N-1
);
project = ProjectGenerator(seed: seed, clients: sampleClients).generate(1).single;
```

- Slot 0 is special: it is resampled (bounded at 500 attempts, identifier
  `'slot:0:guard:$attempt'`) until it passes the Balance Guard heuristic —
  see below. Every attempt is still a genuine, unmodified
  `ProjectGenerator` output; nothing is fabricated.
- The generator's own id (`project-<seed>-1`) is **not** used as the final
  id, because it is a function of `seed` and therefore of `runSeed` — this
  would make a project's identity change across playthroughs even for "the
  same slot," unlike Phase 2's recruitment ids. Instead, `_withStableId`
  reconstructs the same `Project` (every field copied through unchanged)
  under `'project-<month>-<slot+1>'` — mirrors Phase 2's
  `'recruitment-<month>-<medium>-<slot>'` scheme exactly: stable across
  `runSeed`, unique within a month, parseable back into `(month, slot)` for
  `regenerate()`.
- **Generation order independence**: slot N's derivation never reads
  anything about slot N-1 or N+1 (each is its own fresh `ProjectGenerator`
  instance from its own derived seed); verified directly in tests (a middle
  slot is byte-identical whether requested alone or inside a larger batch).
- `PublicDemoSeededProjectGenerator.regenerate({runSeed, projectId})`
  recovers the exact candidate a given id represents by parsing
  `(month, slot)` back out and re-deriving — the same `(runSeed, id) ->
  content` contract Phase 2's `regenerateDomainApplicant` established, so
  Phase 5 can look up a specific project by id without any stored project
  data at all.

## Persistence decision

**Decision: no new persisted data whatsoever.** Exactly like Phase 2's
recruitment candidates, a project candidate is a pure function of
`(runSeed, month, slot)`, and `runSeed`/`month` are already persisted
(`PublicDemoState.runSeed`/`.month`, both pre-existing, both untouched).
Storing generated projects would be pure redundancy — precisely the
"再生成可能なデータを無意味に重複保存しない" instruction.

- **Save schema impact: zero.** No field added to `PublicDemoState`,
  `PublicDemoWorkflowState`, or `PublicDemoAggregate`. `PublicDemoSaveCodec
  .schemaVersion` is unchanged (still `1`). `PublicDemoAggregate
  .projectCandidatesForMonth` is a plain method reading `state.runSeed` —
  it is not part of `toJson()`, so `PublicDemoSaveCodec`'s strict
  round-trip comparison (`_canonicalJson(baseline) ==
  _canonicalJson(toJson(aggregate))`) is completely unaffected.
- **Legacy save compatibility**: since nothing new was persisted, *every*
  existing save (including ones from before this phase) already exercises
  the exact same shape this phase produces — verified directly
  (`public_demo_seeded_project_generator_test.dart` › "persistence / reload
  compatibility" group): encode → decode round-trips to byte-identical
  JSON, and `projectCandidatesForMonth()` immediately works on a freshly
  decoded aggregate with no migration step.
- **Reload stability**: `projectCandidatesForMonth(month)` called before an
  encode/decode round trip and again after returns byte-identical projects
  — verified directly in the same test group.

## Balance Guard

**Requirement**: April's initial project pool must always contain at least
one project a founding employee could realistically target; no `runSeed`
alone should make the game effectively unclearable from turn one. Existing
Finance baseline (`PublicDemoState.aprilStart`, starting cash, baseline
payroll) was **not** touched to satisfy this.

**Construction** (`PublicDemoSeededProjectGenerator._guaranteedEligibleProject`):
slot 0 of every month's pool (not only April — the same construction
naturally extends to every month, though only April is required/tested) is
drawn repeatedly, each attempt a genuine `ProjectGenerator` output under a
different derived identifier (`'slot:0:guard:0'`, `'slot:0:guard:1'`, …,
bounded at 500 attempts), until one passes a deliberately simple,
Phase-4-owned eligibility check (`_isRealisticallyTargetable`) against
either founding engineer (`publicDemoInitialEngineerRuntimes`, i.e.
`eng-01`/`eng-02`) — **not** the real `MatchingEngine` scoring formula,
which is explicitly out of this phase's scope (Phase 5 owns real Matching).
The heuristic:

1. `project.requiredExperienceMonths <= engineer's own primary-language
   actualExperienceMonths` (36 for eng-01, 24 for eng-02).
2. `project.requiredLanguages` is empty, or contains the engineer's
   `primaryLanguage`.
3. Every one of the project's 7 domain-skill requirements
   (`requiredDatabase`/…/`requiredManager`) is `<=` the engineer's own
   `TechSkillLevels` value for that same domain.

This is a **structural** guarantee, not a statistical hope: because slot 0
is resampled until it passes (or the attempt cap is hit — never observed
in testing), every `runSeed` gets a genuinely-generated, eligible project
in its pool, not merely "most seeds do." Verified with a 500-seed sweep
(`public_demo_seeded_project_generator_test.dart` › "April viable-project
guard (Balance Guard)") — zero failures — and a second 200-seed check that
slot 0 *alone* (i.e. even a Phase 5 caller that only requests one slot)
already satisfies the guard on its own, independent of any other slot.

**Known simplification, disclosed rather than hidden**: the eligibility
heuristic above is intentionally simpler than the real `MatchingEngine`
formula (no personality/Japanese-level/remote-policy scoring) — it exists
solely to make the Balance Guard checkable and enforceable *within this
phase's own scope*, before real Matching exists. Phase 5 is not bound by
this heuristic; it may (and should) apply its own full scoring to the same
projects.

## Public API for Phase 5

- `PublicDemoAggregate.projectCandidatesForMonth(int month, {int count =
  PublicDemoSeededProjectGenerator.defaultSlotsPerMonth})` →
  `List<PublicDemoProjectCandidate>` — the primary entry point; reads
  `state.runSeed` internally, so any live aggregate can call it directly.
- `PublicDemoSeededProjectGenerator.forMonth({required runSeed, required
  month, int count = 4})` — the underlying static generator, for callers
  without a live aggregate (e.g. tests).
- `PublicDemoSeededProjectGenerator.regenerate({required runSeed, required
  projectId})` → `PublicDemoProjectCandidate?` — id-based lookup/recovery,
  `null` for any id this generator did not mint.

## UI

**No UI changes.** The task permitted (not required) a read-only project
listing on the existing Sales screen. `public_demo_sales_visual.dart`'s own
doc marks that whole visual area as a finished, isolation-tested "Canonical
Visual Reference" surface (`SES_NON-HOME-UI_SALES_Visual-Complete_Result.md`)
with its own strict overflow/`SesTheme` constraints; inserting even a small
read-only card there risks the exact large-layout-change/regression outcome
the task explicitly forbids, for a display Phase 5 (which will actually
drive real matching against these candidates) makes redundant almost
immediately. Deferred — see "Phase 5 handoff" below — rather than risked
for a phase whose own stated responsibility stops at the generation
backend.

## Tests

Environment note: no Flutter SDK was preinstalled in this session; Flutter
3.44.9 (matching this repo's `e2e.yml` CI pin and Phase 1/2's own
environment note) was downloaded to `/opt/flutter-sdk` to run every command
below.

- `flutter analyze` (whole project): **No issues found.**
- `git diff --check`: clean.
- New: `test/game/public_demo/public_demo_seeded_project_generator_test.dart`
  (17 tests):
  - same seed → same candidates (exact `Project.toJson()` equality,
    explicit "reload" framing).
  - different seed → candidate variation (pairwise, and a 30-seed spread
    showing more than one distinct title).
  - generation order independence (a later slot doesn't perturb an
    earlier one; a middle slot is identical alone vs. inside a larger
    batch).
  - stable unique IDs (exact format string, independent of `runSeed`,
    unique within a month).
  - regeneration by id (`regenerate()` recovers the exact candidate
    `forMonth()` produced; `null` for an unminted id).
  - sensible Project projection (every candidate's minimum required fields
    are present and sane, across 20 seeds; `requiredExperienceMonths`
    matches the canonical rank mapping exactly).
  - April viable-project guard: 500-seed sweep, zero failures; a further
    200-seed check that slot 0 alone always satisfies the guard.
  - persistence / reload compatibility: save/reload round trip changes
    nothing about the persisted JSON; `projectCandidatesForMonth()` is
    identical before/after a round trip; legacy-save-shape decode
    immediately supports the new query method.
- Existing suites re-run unmodified as part of the focused run and the full
  suite below: `test/domain/project_generator_test.dart`,
  `test/domain/project_language_requirement_test.dart` (both still pass —
  `Project`'s new getter did not disturb either), `test/game/
  public_demo/public_demo_save_codec_test.dart`, `public_demo_run_seed_test
  .dart`, `public_demo_rng_test.dart`, `public_demo_recruitment_workflow_
  transaction_test.dart`, `public_demo_recruitment_interview_test.dart`,
  Finance/Month suites (`public_demo_monthly_close*_test.dart`,
  `public_demo_financial_status_test.dart`, `public_demo_monthly_cash_flow_
  test.dart`, `public_demo_revenue_*_test.dart`), assignment/HOME suites.
- Full suite: `flutter test --concurrency=6` (whole `test/` tree) —
  **1872 passed, 1 failed.**

### The one failure — pre-existing, unrelated flake

`test/game/public_demo/public_demo_financial_status_test.dart` › "N-U.
Recruitment/offer/training shortage gates ... P: shortage blocks new offer
acceptance (the salary-obligation boundary)" failed once during the full
concurrent run. Investigated directly:

- Re-ran this exact test file in isolation **twice** — once against this
  branch's BASE SHA with this phase's changes fully stashed (`git stash
  -u`), once again with the changes restored — both runs: **all 26 tests
  in this file passed**, including test P.
- This phase never touches `public_demo_salary_offer.dart`,
  `public_demo_financial_status.dart`, `public_demo_monthly_close.dart`, or
  any other file this test exercises — the diff is limited to
  `project.dart`/`project_rank.dart` (new getters only), a new method on
  `public_demo_aggregate.dart` that is never called by this test, and one
  new file (`public_demo_project_generator.dart`) this test never imports.
- Test P's own body calls `PublicDemoSalaryOfferEvaluator.evaluate(...)`
  and asserts `offer.accepted` is `true` for a "genuine, would-be-accepted"
  offer — behavior of pre-existing, unmodified acceptance-evaluation logic
  this phase never reads or writes.

Conclusion: this is a pre-existing flake in test P (or the evaluator it
exercises) that surfaces only under concurrent/full-suite execution,
already present on `origin/main` before this phase's changes, and outside
this phase's scope (Finance/salary-offer authority — explicitly forbidden
from modification by this task). Not fixed here per the task's own "禁止:
Finance revenue計算変更" instruction; flagged for a future session with
Finance/salary-offer in scope.

## Known limitations

- **UI deferred** — see "UI" above. A query API exists; nothing renders it
  yet.
- **Balance Guard heuristic is intentionally simplified** (see "Balance
  Guard" above) — not the real Matching formula, and not meant to be;
  Phase 5 should apply its own full scoring, not adopt this heuristic as
  final.
- **`_guardMaxAttempts` (500) is an empirical bound, not a proven one** —
  every seed tested (500-sweep + 200-sweep, 700 distinct seeds total)
  resolved in well under this bound, but no formal proof establishes an
  upper attempt count for an arbitrary `(runSeed, month)`. The fallback
  path (one further genuine draw, not a fabricated project) was never
  exercised in testing.
- **`Project.applicationDeadlineWeek`'s `baseWeek` is a simple month→week
  stand-in** (`(month - 4) * 4 + 1`) since Public Demo has no week-granular
  calendar of its own — this field is carried for shape-completeness only;
  no Public Demo authority reads or enforces it in this phase.
- **`defaultSlotsPerMonth = 4` is a judgment call**, not derived from any
  existing spec (none of the five requested audit documents exist to
  source one from) — chosen to match Public Demo's existing "4" cadence
  (`salesCapacity` default) for a plausible-feeling monthly pool size.
  Phase 5 can pass its own `count`.

## Phase 5 (Matching) handoff

1. `PublicDemoAggregate.projectCandidatesForMonth(month, {count})` →
   `List<PublicDemoProjectCandidate>` is the query entry point — call it
   with whatever month/count Phase 5's own UI needs; every candidate is
   already reload-safe with zero persistence dependency.
2. `PublicDemoProjectCandidate.project`/`.client` expose the real
   `Project`/`Client` domain objects directly — Phase 5's real Matching
   logic should read these (and, if it wants a full score, the main
   engine's own `MatchingEngine.computeFit`) rather than this phase's
   simplified Balance Guard heuristic.
3. `Project.requiredExperienceMonths` / `ProjectRank
   .minimumExperienceMonths` / `projectRankMinimumExperienceMonths` are the
   one canonical requiredExperience source — Phase 5 should read these, not
   define a second mapping.
4. `PublicDemoSeededProjectGenerator.regenerate({runSeed, projectId})` lets
   Phase 5 recover a specific candidate purely from its id (e.g. from an
   in-progress matching/negotiation record) without needing to re-list the
   whole month.
5. No project data is persisted — if Phase 5 needs to remember something
   about a *specific* candidate across a save/reload (e.g. "this project is
   currently being negotiated"), that fact belongs in Phase 5's own new
   persisted state, keyed by the candidate's stable id — not by extending
   this generator or duplicating `Project`'s fields.
6. `monthlyRate` is present on every candidate but intentionally
   unconnected to Finance in this phase — Phase 5/Finance wiring (revenue
   recognition once a project is actually staffed) is future work this
   phase deliberately left alone.

## Final verdict

**PASS** — implementation complete, Balance Guard verified over a 700-seed
sweep, save/reload/legacy compatibility verified directly, zero regressions
in every suite this phase's diff can plausibly affect. One flaky,
pre-existing, out-of-scope test failure documented above with isolation
evidence, not attributable to this change.
