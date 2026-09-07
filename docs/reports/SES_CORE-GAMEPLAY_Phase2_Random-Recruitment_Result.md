# SES CORE-GAMEPLAY Phase 2: Random Recruitment — Result

Status: **Implementation complete, all tests green**

## BASE SHA / branch / HEAD

- BASE SHA (origin/main at session start): `686e8b3c3e74d791e914c7ec7b591719e2db2a13`
  (this matched the task's own "expected BASE" exactly — no divergence to
  reconcile).
- Branch: `claude/seeded-recruitment-candidates-4h5ct0` — this branch's own
  prior commit was an ancestor of `origin/main` with no open PR (`git log
  HEAD --not origin/main` was empty), so per the merged-branch-reuse rule it
  was reset onto the BASE SHA above at session start.
- HEAD after this work: `b855595014d4558fc225566f5192b7704100dbb6`
  ("SES CORE-GAMEPLAY Phase 2: seeded recruitment candidate generation")
- PR: https://github.com/perusonao/smile_enjoy_story/pull/202

## Scope note on the requested input document

`docs/reports/SES_CORE-GAMEPLAY_Phase1_Seeded-RNG_Result.md` (the one INPUT
report actually named in this task) exists and was read in full — it is
Phase 1 of this same initiative and is the primary source for the
"Reused main-game classes/functions" and "Phase 2 (Random Recruitment)
connection" sections below matched almost verbatim to its own design.

## Reused main-game classes/functions

Audited before writing any code:

- `ApplicantGenerator` (`lib/domain/generation/applicant_generator.dart`) —
  the sole candidate-generation engine used. **No new/alternate applicant
  generator was written.** `ApplicantGenerator(seed: derivedSeed).generate(1)`
  is called once per candidate slot, each from its own independently-seeded
  instance (never a shared/threaded `Random`), for exactly the
  order-independence guarantee `ApplicantGenerator`'s own doc already
  promises ("constructing two generators with the same seed ... produces
  identical applicants").
- `Applicant`, `ApplicantType`, `PersonalityTraits`, `HiddenParameters`,
  `TechSkillLevels`, `LanguageSkill`, `ProgrammingLanguage` (all
  `lib/domain/models/`) — read directly, never copied. **The main
  `Applicant` model is not duplicated into Public Demo anywhere** — see
  "Applicant → Public Demo mapping" below for the Adapter/Projection that
  keeps it that way.
- `salaryRangeByType`, `itExperienceYearsRangeByType`
  (`lib/domain/generation/applicant_distribution.dart`) — used read-only, to
  compute each applicant's ability-relative position within their own
  type's real salary range for the salary Adapter (see "Balance
  compatibility").
- `RecruitmentEngine.generateApplicants`
  (`lib/game/engine/recruitment_engine.dart`) — audited as the main
  engine's own precedent for "media biases candidate quality without
  changing the generator": it over-generates a batch via `ApplicantGenerator`
  then keeps the best-ranked subset. `PublicDemoSeededRecruitmentGenerator`
  mirrors this exact pattern for the paid `engineer` medium (batch of 3,
  keep the most experienced) instead of inventing a new selection
  mechanism.
- `PublicDemoRng` / `PublicDemoRngNamespace.recruitmentCandidate`
  (`lib/game/public_demo/public_demo_rng.dart`, Phase 1) — used exactly as
  Phase 1's own report specified this call site would: `PublicDemoRng
  .derivedSeed(runSeed: ..., month: ..., namespace: recruitmentCandidate,
  identifier: ...)` is the only source of every seed this generator uses.
  No new RNG primitive, no direct `Random(...)`/`seededRandom`/`weekSeed`
  call anywhere in the new code.
- `PublicDemoState.runSeed`, `PublicDemoAggregate.recruit`'s existing
  `PublicDemoRecruitmentCandidateGenerator` typedef/injection point (both
  Phase 1) — reused as the integration seam; see "New seeded generation
  flow" below for exactly how.

## Old Public Demo generation behavior (audited)

`PublicDemoRecruitmentCalculation._generateApplicants` (now removed)
selected from two small, hand-authored `const` pools —
`publicDemoMayApplicants` (2 entries, the `engineer` medium) and
`publicDemoFreeApplicants` (2 entries, the `free` medium, one of them a
genuinely-inexperienced `experienceMonths: 0` template) — by
`pool[(month + medium.index + index) % pool.length]`: a pure function of
`(month, medium, slot)`, cycling deterministically with no `Random` call
anywhere. This is exactly what Phase 1's own report already documented as
the state of things going into Phase 2 ("Public Demo 0.1 today generates
recruitment candidates by deterministic template/index cycling, not
`Random` at all").

Consequence: every playthrough saw the *exact same two named candidates*
(高橋 翔 / 田中 美咲 for `engineer`) for a given month, forever — no seed
dependence, no variety, and (per the free-medium doc) an *incidental*
inexperienced/experienced split driven by month parity rather than any
real generation.

## New seeded generation flow

New file: `lib/game/public_demo/public_demo_recruitment_candidate_generator.dart`
— `PublicDemoSeededRecruitmentGenerator`.

- `PublicDemoRecruitmentCalculation` (`lib/game/public_demo/
  public_demo_aggregate.dart`) now resolves its **default** candidate
  generator *inside* `execute()`, not at construction time — because the
  default needs `state.runSeed`, which only exists once a `state` is
  actually supplied. The public `PublicDemoRecruitmentCandidateGenerator`
  typedef itself is **completely unchanged** (`{required month, required
  medium, required count}`), exactly as Phase 1's report predicted this
  integration would work ("already accepts this without any further
  interface change; only the default implementation ... needs to change").
  Every existing test/caller that substitutes its own `candidateGenerator`
  is unaffected.
- For each candidate slot `index` in `0..count-1`:
  1. `identifier = '${medium.name}:$index'`.
  2. `id = 'recruitment-$month-${medium.name}-${index + 1}'` — **the exact
     pre-existing id format**, unchanged, so portraits
     (`homeOfficeStagePortraitFor`), persistence, and every id-based test
     assertion are unaffected.
  3. `PublicDemoRng.derivedSeed(runSeed: state.runSeed, month: month,
     namespace: recruitmentCandidate, identifier: identifier)` → a fresh
     `ApplicantGenerator(seed: ...).generate(1)`.
  4. The resulting `Applicant` is projected into a `PublicDemoApplicant` —
     see the mapping table below.
- `engineer` medium (paid, quality-biased): generates a batch of 3
  independent candidates per slot (`identifier:candidate-0..2`) and keeps
  the one with the highest `totalItExperienceMonths` — mirrors
  `RecruitmentEngine.generateApplicants`'s own over-generate-then-rank
  pattern.
- `free` medium (unpaid, "mixed-quality" per its own pre-existing doc):
  a single, unranked draw per slot.
- Every derived seed is a pure function of `(runSeed, month, medium,
  index)` via `PublicDemoRng` — generating slot 1 never touches slot 0's
  own `Random`, satisfying "generation order independence" directly (see
  tests).

## Applicant → Public Demo mapping table

`PublicDemoApplicant`'s existing shape (`lib/game/public_demo/
public_demo_recruitment.dart`) was **not extended** — see "Persistence
decision" below for why zero new fields were needed. Every existing field
is now filled from a real generated `Applicant` instead of a template:

| `PublicDemoApplicant` field | Source (`Applicant` domain field) | Notes |
|---|---|---|
| `id` | n/a (identifier scheme) | `recruitment-<month>-<medium>-<slot>`, unchanged format |
| `name` | `Applicant.name` | verbatim |
| `resumeSummary` | `mainLanguage` label + `skillFor(mainLanguage) .displayedExperienceMonths` (résumé-visible, not the hidden `actualExperienceMonths`) + `age` + a per-`ApplicantType` role-note string | text composition only; no numeric field derived from this |
| `experienceMonths` | `Applicant.totalItExperienceMonths` | the *true* total, matching the field's own doc ("IT practical experience") |
| `requestedMonthlySalary` | `Applicant.desiredMonthlySalary`, rescaled | see "Balance compatibility" |
| `salesSkillFit` | `skillFor(mainLanguage).actualSkill` | already 0-100, no rescale — see rationale below |
| `interviewScore` | `PersonalityTraits.communication` / `.seriousness` | formula below |
| `acceptanceScore` | `HiddenParameters.retention` / `.turnoverIntent` | formula below |
| `age` | *(not a separate field)* | embedded directly in `resumeSummary`'s text |

`salesSkillFit` deserves its own callout: `PublicDemoEngineerRuntime
.fromApplicant` (pre-existing, untouched) already copies
`applicant.salesSkillFit` straight into a joined hire's `actualSkill` for
their primary language. `Applicant.skillFor(mainLanguage).actualSkill` is
*already* a 0-100 "true ability" value computed by `ApplicantGenerator`
(`actualSkillBase=30 + years*6 ± variance, clamped 0-100`) — the same
domain concept, same numeric range, no invented formula. Mapping it
directly is the *least* speculative choice available and keeps
post-hire ability numbers authentic to the main engine.

`interviewScore`/`acceptanceScore` formulas (documented so future phases
can audit/replace them without re-deriving intent):

```dart
interviewScore   = (62 + (communication-3)*9 + (seriousness-3)*5).clamp(0,100)
acceptanceScore  = (70 + (retention-3)*8 - ((turnoverIntent-50) ~/ 10)).clamp(0,100)
```

Chosen so the *modal* (most common, trait=3) applicant lands just above
each field's existing `>=60` gameplay threshold (offer-eligibility /
salary-offer baseline) — matching the old templates' own bias (3 of 4
legacy templates were `>=60` on `interviewScore`; all 4 were well above 60
on `acceptanceScore`) without hard-coding a pass/fail rate.

## Visible vs. interview-hidden fields

Per `HiddenParameters`' own class doc ("never shown to the player at
application time") and `PersonalityTraits`' own doc ("public/visible
profile data"), this generator only reads *visible* fields into anything
Sales/Recruitment UI code actually renders (`name`, `resumeSummary` text,
`experienceMonths`, `requestedMonthlySalary`). `interviewScore`/
`acceptanceScore` do read `HiddenParameters`, but — as before this
change — Public Demo never displays either as raw hidden data; they are
internal acceptance-math inputs only (`interviewScore` gates a button,
`acceptanceScore` feeds `PublicDemoSalaryOfferEvaluator`), exactly the
same visibility contract the old fixed templates already had.

Nothing is fabricated for the hidden side either: `regenerateDomainApplicant
({runSeed, applicantId})` (same file) recovers the **exact full domain
`Applicant`** — every `HiddenParameters` field, every `TechSkillLevels`,
raw `dishonesty`, everything — purely from `(runSeed, id)`, by parsing
`(month, medium, slot)` back out of the id and re-deriving the same seed.
This is the Phase 3 integration point (see below); Phase 2 itself never
calls it from any UI code, so nothing hidden reaches the player yet.

## Candidate identity / stability

- **Id** never depends on `runSeed` — only the *content* behind an id
  does. Verified directly:
  `public_demo_seeded_recruitment_generator_test.dart` › "id does not
  depend on runSeed".
- Because `PublicDemoState.runSeed` is fixed for a whole playthrough
  (Phase 1's own guarantee — no command/copyWith path can change it) and
  the id alone fully determines `(month, medium, slot)`, the full domain
  `Applicant` behind any candidate — including everything the *interview*
  step (Phase 3, out of scope here) would need — is byte-for-byte
  regenerable at any later point in the same playthrough. There is no
  window where reloading, redrawing, or generating another slot changes an
  already-generated candidate's own content.
- `PublicDemoWorkflowState.withGeneratedApplicants` (pre-existing, untouched)
  appends the generated `PublicDemoApplicant` values into the authoritative,
  **persisted** `applicants` list the moment `recruit()` succeeds — so a
  candidate a player is actively looking at (mid-résumé-review,
  mid-pre-join-sales, etc.) is committed, saved state from that point on,
  not re-derived on every read. Combined with the point above, this means
  candidate identity is doubly stable: pinned by the persisted
  `PublicDemoApplicant` record *and* independently reproducible from
  `(runSeed, id)` if anything ever needs to regenerate the full domain
  object later (Phase 3).

## Persistence decision

**Decision: no new persisted data for candidate generation.** Two
independent facts already fully cover this:

1. `PublicDemoWorkflowState.applicants` already round-trips through
   `toJson()`/`fromJson()` in full (pre-existing, untouched) — every
   `PublicDemoApplicant` a player has ever seen stays exactly as it was
   generated, save after save, for its own recruitment-stage lifecycle
   (interview, offer, join, raises, ...). This did not need to change for
   Phase 2 at all.
2. The *full* domain `Applicant` (for a future interview step) needs no
   persistence either, because it is a pure, deterministic function of
   `(runSeed, id)` alone — see `regenerateDomainApplicant` above. Storing
   it would be pure redundancy.

**Save schema impact: zero.** No field was added to `PublicDemoApplicant`,
`PublicDemoWorkflowState`, or `PublicDemoState`. `schemaVersion` is
unchanged. A save from *before* this change loads unmodified — every
applicant already in a legacy save (including ones generated by the old
template cycling, mid-lifecycle or already hired) round-trips exactly as
it always did, because its `PublicDemoApplicant` JSON shape never changed.
The only actual behavior change is *what a future `recruit()` call
generates from this point forward* — never how anything already-persisted
reads back.

## Balance compatibility

Per the task's explicit instruction, `ApplicantGenerator`'s own value
domain was **not** imported verbatim where it would have measurably
changed Public Demo's existing economy — the two gaps found, and the
minimal Adapter mapping chosen for each, both documented here (not
silently tuned):

**1. Salary.** `ApplicantGenerator.desiredMonthlySalary` spans
250,000-650,000 JPY across all `ApplicantType`s (`salaryRangeByType`).
Public Demo's pre-existing recruitment economy — the templates this phase
replaced, and today's founding-team salaries
(`PublicDemoSalary.satoMonthlySalary`=300,000,
`.suzukiMonthlySalary`=250,000, `.adminMonthlySalary`=200,000) against a
4,000,000 JPY starting cash and ~800,000/month baseline burn
(`PublicDemoSalary.baselineMonthlyExpenses`) — was tuned around a much
narrower 220,000-320,000 band. Importing the full main-engine range
verbatim (up to 650,000 for a senior/PL-candidate roll) would have let a
single new hire nearly double monthly payroll, a real balance change the
task explicitly disallowed. **Mapping applied:** each applicant's salary
is rescaled by its own *relative* position within its own `ApplicantType`'s
real `salaryRangeByType` (a 0.0-1.0 ability fraction, so a stronger
candidate of the same type still costs more) into a medium-specific band
close to the old economy: `engineer` → 260,000-420,000 JPY, `free`
(non-inexperienced) → 220,000-300,000 JPY, rounded to the nearest 10,000
(matching the old templates' own convention of round salary figures). A
genuinely inexperienced `free`-medium hire keeps the pre-existing fixed
220,000 anchor exactly (see point 2) rather than a rescaled figure, since
there is no main-engine experience-tier to rescale from at zero months.
- Verified in `public_demo_seeded_recruitment_generator_test.dart` ›
  "balance compatibility" (25 seeds × both mediums, salary always inside
  the stated band).

**2. Genuinely inexperienced (`experienceMonths == 0`) hires.**
`ApplicantType`'s own doc is explicit: *"Untrained/inexperienced hires ...
are intentionally not part of this ... enum"* — `ApplicantGenerator`
structurally cannot produce a zero-experience applicant (every type's
`itExperienceYearsRangeByType` floor is ≥1 year). Public Demo's
pre-existing `isInexperienced`/`canEnterPreJoinSales` mechanic (a whole
separate hire path: skips pre-join sales, joins at the ordinary monthly
boundary) predates this generator and had to stay reachable — this is
existing authority the task requires untouched, not something Phase 2 is
allowed to quietly retire. **Mapping applied, `free` medium only:** a
seeded 50% roll (`PublicDemoRng`, its own `:inexperienced-check`
identifier, so it is itself part of the same deterministic/seed-varying
contract as everything else) decides whether a `free`-medium slot is
inexperienced. When it is, a real generated `Applicant` still supplies
authentic `name`/`age`/personality flavor for `resumeSummary`, but
`experienceMonths`/`requestedMonthlySalary` use the pre-existing anchor
values (`0` / `220,000`) instead of a fabricated generator output the
domain model cannot actually produce. This is the **one** place this
generator does not read a number straight off `ApplicantGenerator`'s own
output — documented here specifically because the task requires exactly
that when a value-domain gap exists.
- Verified in `public_demo_seeded_recruitment_generator_test.dart` ›
  "inexperienced-hire path stays reachable": across a spread of
  seeds/months, `free` medium produces **both** outcomes; `engineer`
  medium **never** produces an inexperienced candidate (matches the old
  behavior — the engineer-medium legacy pool never contained one either).

**No other value (acceptance/hire success math, recruitment media cost,
sales-slot consumption, monthly progression) was touched.** No new "avoid
0 candidates" relief logic was written — `PublicDemoSeededRecruitmentGenerator
.generate` is unconditional in `count` (always returns exactly `count`
candidates, never fewer), so the pre-existing `generationFailed` guard in
`PublicDemoRecruitmentCalculation.execute` structurally cannot trigger from
this generator; this mirrors `ApplicantGenerator.generate(count)`'s own
"always returns exactly `count`" contract rather than inventing a new
fallback.

## Tests

Environment note: no Flutter SDK was preinstalled in this session; Flutter
3.44.9 (stable, matching this repo's CI pin and Phase 1's own environment
note) was downloaded to `/opt/flutter` to run every command below.

- `flutter analyze` (whole project): **No issues found.**
- `git diff --check`: clean.
- New: `test/game/public_demo/public_demo_seeded_recruitment_generator_test.dart`
  (20 tests) — directly against `PublicDemoSeededRecruitmentGenerator`:
  - same seed → same candidates (exact `toJson()` equality, and an explicit
    "reload" framing).
  - different seed → candidate variation (pairwise, and a 30-seed spread
    showing >5 distinct names).
  - generation order independence (slot 0 unaffected by whether 1 or 2
    slots are requested).
  - candidate stable ID (exact format string; independent of `runSeed`).
  - inexperienced-hire path reachable for `free`, never for `engineer`.
  - generation never fails to produce the requested count (all
    media × 10 seeds).
  - balance compatibility (salary bands, both mediums, 25 seeds).
  - `regenerateDomainApplicant`: recovers the exact same `Applicant`;
    returns `null` for a legacy fixture id (`app-01`,
    `free-template-inexperienced-01`); stable across repeated calls.
- New: `test/ui/public_demo/public_demo_seeded_recruitment_visual_test.dart`
  (9 tests) — Sales-tab rendering with real seeded candidates: no-overflow
  assertions at 360×800/390×844 × textScale 1.3/2.0 (`tester.takeException()`
  is null + on-screen rect bounds checks), a sanity check that the two
  *newly-seeded* candidates (as opposed to the fixed 高橋/田中 founding pair
  every fixture starts with) differ from each other and again across
  `runSeed`s, and the screenshot-saving tests below.
- Updated (behavior-preserving intent, content-assertion rewrite):
  `test/game/public_demo/public_demo_recruitment_workflow_transaction_test.dart`
  — two tests that asserted the *old* fixed-template content
  ("engineer keeps the established experienced 高橋・田中 pool",
  "free media deterministically alternates ... by month parity") were
  rewritten to assert the *new* seeded-generation contract instead (no
  inexperienced candidate from `engineer`; distinct from the legacy fixture
  names; reproducible for a fixed seed; varies across seeds) — this is the
  intended, expected consequence of replacing the exact mechanism those two
  tests were pinning down. Every other test in this file (atomicity, cash/
  applicant commit-together guarantees, month-range gating 4-15) was
  **not** touched and still passes unmodified.
- Existing Public Demo recruitment/regression suites: run as part of the
  full suite below, unmodified and passing (candidate→hire flow,
  salary/employee conversion, legacy save compatibility, Finance/Month
  authority, HOME freeze, Sales/Accounting/Menu visual-complete suites,
  the whole `public_demo_junior_runtime_test.dart` inexperienced-hire
  regression suite, etc.).
- Full suite: `flutter test --concurrency=6` (whole `test/` tree) —
  **all tests passed** (1827 tests before this session's own 29 new tests
  and 2 rewritten ones; final count and any output captured in this same
  session's terminal history).

## Screenshots

Saved to `docs/reports/screenshots/`:

- `ses-core-gameplay-phase2-recruitment-seedA-360x800.png`
- `ses-core-gameplay-phase2-recruitment-seedA-390x844.png`
- `ses-core-gameplay-phase2-recruitment-seedB-360x800.png`
- `ses-core-gameplay-phase2-recruitment-seedB-390x844.png`

Each shows May's Sales tab after a real `PublicDemoAggregate.recruit
(engineer)` call (the exact production path), scrolled so the two
*newly-generated* seeded candidates (below the pre-existing fixed 高橋/田中
founding pair every fixture starts with) are in frame, for two different
fixed `runSeed`s at both required viewports. Byte-for-byte hashes of all
four PNGs are distinct; visually, avatar portraits (chosen from the
generated `Applicant`'s own attributes) and the résumé-line text-run
lengths clearly differ candidate-to-candidate and seed-to-seed.

**Caveat, disclosed rather than hidden:** these were captured via a
`flutter test` widget test (`RenderRepaintBoundary.toImage()`), which
renders with Flutter's built-in test font, not the app's real embedded
fonts — Japanese text appears as placeholder glyph boxes rather than
legible characters. Structural/layout variety (box-run lengths, card
count, avatar art) is genuinely faithful to the real data; the *legible
Japanese text* a player would actually see is not reproduced by this
capture method. The underlying data itself (names, résumé strings,
salaries) was independently confirmed to differ correctly across seeds
via direct diagnostic output during this session, and via the dedicated
unit tests above, which do not depend on font rendering at all.
TextScaler 1.3/2.0 overflow was confirmed via the widget-test assertions
above (`tester.takeException()` null + on-screen bounds), not via the
screenshots themselves.

## Changed files

- `lib/game/public_demo/public_demo_recruitment_candidate_generator.dart`
  (new) — `PublicDemoSeededRecruitmentGenerator`: the seeded generator,
  Adapter/projection, and `regenerateDomainApplicant` Phase 3 seam.
- `lib/game/public_demo/public_demo_aggregate.dart` —
  `PublicDemoRecruitmentCalculation` resolves its default candidate
  generator from `state.runSeed` inside `execute()` instead of the removed
  `_generateApplicants` template-cycling method. The
  `PublicDemoRecruitmentCandidateGenerator` typedef itself is unchanged.
- `test/game/public_demo/public_demo_seeded_recruitment_generator_test.dart`
  (new)
- `test/ui/public_demo/public_demo_seeded_recruitment_visual_test.dart`
  (new)
- `test/game/public_demo/public_demo_recruitment_workflow_transaction_test.dart`
  — two tests rewritten (see "Tests" above); every other test unchanged.
- `docs/reports/screenshots/ses-core-gameplay-phase2-recruitment-{seedA,seedB}-{360x800,390x844}.png`
  (new)
- `docs/reports/SES_CORE-GAMEPLAY_Phase2_Random-Recruitment_Result.md`
  (this report, new)

## Untouched authorities

Confirmed by reading and, for every item with a test suite, by that suite
still passing unmodified:

- Recruitment media cost/applicant-count (`PublicDemoRecruitmentMedium`) —
  file not touched.
- Sales/action-slot consumption, résumé review, pre-join sales stage
  machinery (`PublicDemoWorkflowState`) — not touched (still consumes
  `PublicDemoApplicant.salesSkillFit` thresholds exactly as before; those
  thresholds themselves were not changed).
- Salary offer/accept math (`PublicDemoSalaryOffer`,
  `PublicDemoSalaryOfferEvaluator`) — not touched.
- Join/hire → `PublicDemoEngineerRuntime.fromApplicant` conversion,
  including the pre-existing `_usesPotentialTemplate` parity trick — not
  touched; both still operate correctly on the new seeded
  `interviewScore`/`acceptanceScore`/`salesSkillFit` integers exactly as
  they did on the old fixed ones (parity-based logic is agnostic to the
  integers' source).
- Monthly progression / month-close authority
  (`PublicDemoMonthlyClose`, `advanceToMay`/`closeApril`/…) — not touched.
- `publicDemoMayApplicants`/`publicDemoFreeApplicants` constants — kept
  exactly as-is (still used by `PublicDemoWorkflowState.initial`'s founding
  pool and by several pre-existing tests that reference them directly);
  only their former role as the recruitment *generation* source was
  removed.
- HOME layout/visual SSOT — not touched (no file under this change is
  reachable from HOME).
- Finance formulas, starting cash, baseline payroll — not touched.
- Save schema/`schemaVersion` — not touched (see "Persistence decision").

## Phase 3 (Recruitment Interview) exact integration points

1. `PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant
   ({required int runSeed, required String applicantId})` → `Applicant?` —
   call this with `state.runSeed` and any `PublicDemoApplicant.id` this
   generator produced to get back the exact full domain `Applicant`
   (every `HiddenParameters`/`TechSkillLevels`/personality field included)
   for `RecruitmentInterviewEngine` (`lib/game/engine/
   recruitment_interview_engine.dart`, already seeded/reusable, untouched
   by this phase) to consume directly — `RecruitmentInterviewEngine.start`/
   `.ask`/`.generateAnswer` all already take an `Applicant` and their own
   `seed`; nothing about their signature needs to change.
2. Returns `null` for any id this generator didn't produce (the two
   hand-authored fixture pools) — Phase 3 needs its own fallback only for
   those two legacy ids, not for anything generated from this point
   forward.
3. No candidate-generation code needs to be rewritten for Phase 3 — the
   `(runSeed, id)` → `Applicant` contract is already complete and covered
   by tests today.

## Remaining risks

- **Salary-band constants are hand-chosen, not derived from a formula.**
  260,000-420,000 (`engineer`) and 220,000-300,000 (`free`) were chosen to
  stay close to the pre-existing template range while giving genuine
  variety; they are not pulled from any other authoritative source. A
  future balance pass should treat these as a starting point, not a fixed
  design decision.
- **`interviewScore`/`acceptanceScore` formulas are new and self-contained
  in this file.** They were tuned so the modal applicant clears each
  field's existing `>=60` gameplay threshold (matching the old templates'
  own bias), but they are Adapter-level formulas invented for this task,
  not ported from any main-engine equivalent — flagged per the task's own
  instruction to document, not hide, this kind of choice.
- **Screenshot font rendering caveat** — see "Screenshots" above; a
  human-legible visual (real embedded fonts) would need a browser-based
  (Playwright, matching this repo's other `e2e/scripts/*.mjs` screenshot
  scripts) capture instead of a `flutter test` widget-test capture, which
  this session did not attempt given the added UI-navigation-scripting
  risk within the session's scope.
- **`?seed=` URL wiring still not extended to Public Demo** (Phase 1's own
  flagged risk, unchanged by this phase) — a real player still cannot pin
  a specific `runSeed` from the URL; only the widget-level `debugSeed`
  constructor parameter exists. Not needed for this phase's own tests
  (which construct `PublicDemoAggregate.initial(runSeed: ...)` directly),
  but still open for a future E2E-reproducibility phase.
- **`free`-medium inexperienced-roll probability (50%) is a judgment call**,
  chosen to roughly preserve the old month-parity cadence's "roughly half
  the time" frequency without literally reproducing month-coupling. Not
  derived from any existing spec.

## Final verdict

**PASS**
