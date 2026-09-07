# SES CORE-GAMEPLAY Phase 1: Seeded RNG Reuse — Result

Status: **Implementation complete, all tests green**

## Scope note on the requested input document

`docs/reports/SES_CORE-GAMEPLAY_Main-to-PublicDemo_Port-Audit.md` (listed as
an INPUT) does not exist anywhere in this repository's git history (checked
across all remote branches). Per this task's own priority rule ("過去レポ
ートより最新mainを優先"), this report instead audits `origin/main` directly
— see "Reused original files/classes/functions" below for what that audit
found.

## BASE SHA / branch

- BASE SHA (origin/main at session start, unchanged throughout): `f91810275b09ab23a3bd9473a5ef04040a2a555d`
- Branch: `claude/seeded-rng-reuse-0fwc2a` (reset onto this BASE SHA at session
  start — its single prior commit was already an ancestor of `origin/main`
  with no open PR, so this session restarted it fresh per the merged-PR
  branch-reuse rule)
- HEAD after this work: see the commit pushed at the end of this session

## Reused original files/classes/functions

Audited `lib/game/engine/rng.dart` — the main game's ("本体") authoritative
seeded-RNG primitives:

```dart
int stableHash(String input)                 // FNV-1a 32-bit -> positive int
int weekSeed(int seed, int week, [salt = 0])  // stableHash('$seed:$week:$salt')
Random seededRandom(int seed, int week, [salt = 0])
```

These are already used throughout the main engine (`recruitment_engine.dart`,
`recruitment_interview_engine.dart`, `project_interview_engine.dart`,
`prologue_engine.dart`, `game_engine.dart`) for every derived, reproducible
draw: applicant rolls, interview answers, project pools, morale, etc. — all
as pure functions of `(seed, week, salt)`, never a threaded/cached `Random`.

Also audited `ApplicantGenerator`/`ProjectGenerator`
(`lib/domain/generation/`) — both already `Random`-seedable — and Public
Demo's own current recruitment path
(`PublicDemoRecruitmentCalculation._generateApplicants`,
`public_demo_aggregate.dart`), whose own doc states it deliberately "Selects
from media-specific lightweight profiles **without importing the main
game's random generator**" — Public Demo 0.1 today generates recruitment
candidates by deterministic template/index cycling, not `Random` at all, and
Public Demo's `PublicDemoAggregate`/`PublicDemoState` had no `seed`/`runSeed`
field of any kind before this change.

Given that, **no new RNG primitive was written**. `lib/game/public_demo/public_demo_rng.dart`
is a thin adapter that calls `weekSeed` directly (with the playthrough's
`runSeed` as the `seed` and the in-game `month` standing in for the main
engine's `week`), and `PublicDemoState`'s own legacy-seed fallback (see
below) reuses `stableHash` — the same primitive, never a reimplementation.

## Adapter design

`lib/game/public_demo/public_demo_rng.dart`:

- `PublicDemoRngNamespace` enum — the four future independent streams named
  in this task: `recruitmentCandidate`, `recruitmentInterview`,
  `projectGeneration`, `projectInterview`. Nothing in this build calls into
  any of them yet (see "Scope boundary" below).
- `PublicDemoRng.derivedSeed({runSeed, month, namespace, identifier})` →
  `weekSeed(runSeed, month, '${namespace.name}:$identifier')`.
- `PublicDemoRng.random({runSeed, month, namespace, identifier})` → `Random(derivedSeed(...))`.

Both are pure functions of their four inputs — no live `Random` instance is
held or threaded anywhere, mirroring `seededRandom`'s own contract
(recomputable on demand, including after a reload, order-independent,
namespace-independent). `test/game/public_demo/public_demo_rng_test.dart`
verifies: same inputs → same result; different `runSeed`/`month`/`identifier`
→ different result; every namespace draws an independent stream for the same
`(runSeed, month, identifier)`; interleaving draws from two namespaces in
either order never perturbs either one.

## runSeed lifecycle

`PublicDemoState.runSeed` (not a new field on `PublicDemoAggregate` —
that class's own doc is explicit about atomically owning exactly `state`
and `workflow`, never a third caller-suppliable value, so `runSeed` lives
where every other per-playthrough fact already lives, and `PublicDemoAggregate.runSeed`
is a derived getter onto `state.runSeed`):

- **New game**: `PublicDemoState.aprilStart({int? runSeed})` — when omitted,
  draws `DateTime.now().millisecondsSinceEpoch & 0x7fffffff`, the exact
  convention `GameEngine.newGame`/`PrologueEngine.newGame` already use for
  the main game's own market seed. `PublicDemoAggregate.initial({int? runSeed})`
  threads straight through.
- **Reload**: `runSeed` round-trips through `PublicDemoState.toJson()`/
  `fromJson()` like every other field, so a restored save always carries
  forward the exact seed it was created with.
- **Ordinary month/command transitions**: `runSeed` has no parameter on the
  public `copyWith` at all — every transition reaches construction only
  through `_copyWith`, which always forwards `this.runSeed` unchanged. It is
  therefore structurally impossible for any existing command (Finance,
  Growth, recruitment, offers, ...) to alter it.
- **"4月からもう一度" (restart)**: `PublicDemo01PlaceholderScreen._restartGame`
  calls `PublicDemoAggregate.initial(runSeed: widget.debugSeed)` again —
  for a real player (`debugSeed == null`) this draws a brand-new wall-clock
  seed, never the abandoned playthrough's.
- **Fixed seed injection for tests**: `PublicDemoState.aprilStart(runSeed: ...)`,
  `PublicDemoAggregate.initial(runSeed: ...)`, and a new
  `PublicDemo01PlaceholderScreen(debugSeed: ...)` widget parameter (mirroring
  `GameController.debugSeed`'s existing QA/E2E convention) — applied at every
  call site that can start a fresh aggregate (initial mount, no-save
  fallback, restart).

## Derived seed algorithm

`PublicDemoRng.derivedSeed` = `weekSeed(runSeed, month, '${namespace.name}:$identifier')`
= `stableHash('$runSeed:$month:${namespace.name}:$identifier')`. Reuses the
main engine's own `(seed, week, salt)` hash verbatim; `month` takes the
`week` slot and the salt is a namespace-qualified string, giving namespace
independence for free (different `namespace.name` prefix ⇒ different hash
input ⇒ independent stream) exactly the way distinct salt strings already
keep the main engine's own week-scoped streams (e.g. `'listingId:count'` vs
`'listingId:pool'`) from colliding.

## Save/schema migration

`schemaVersion` stays `1` — no bump. `PublicDemoState.toJson()`/`fromJson()`
gained one additive key, `runSeed`, inside the existing `state` object (no
new top-level key on `PublicDemoAggregate.toJson()`, confirmed by the
existing regression test asserting the aggregate JSON "still has exactly
`{state, workflow}`").

`PublicDemoSaveCodec` (`lib/game/persistence/public_demo_save_codec.dart`)
enforces a strict decode-or-reject-whole round trip for every field — by
design, so that any other silently-normalized field is rejected outright.
`runSeed` is the one deliberate, narrow exception (documented at both the
class doc and the `fromJson` call site): a save missing it (or carrying a
corrupted non-int value) has a replacement value spliced into the
comparison baseline before the round-trip check, using the exact value
`PublicDemoState.fromJson`'s own legacy fallback already derived —
`stableHash(jsonEncode(stateJson))`, a pure/deterministic function of the
save's own `state` object. Every other field is still required to match
exactly or the whole save is rejected, unchanged from before this field
existed.

## Backward compatibility

- A save with no `runSeed` key restores successfully, keeping every other
  field byte-for-byte, and is assigned a `runSeed` derived deterministically
  from its own content — the same legacy payload always migrates to the
  same value, so a reload before the first post-migration save still agrees
  with itself.
- A save that already carries a genuine `runSeed` is completely unaffected.
- Every other kind of missing/normalized field is still rejected as a whole
  save, exactly as before.
- No Finance/Month/assignment/HOME/visual behavior changed. `flutter analyze`
  is clean; the full existing Public Demo test suite (unit + widget) is
  unchanged in behavior except the 5 places (4 existing tests + 1 existing
  helper) that asserted full-JSON equality between two *independently*
  constructed fresh/canonical aggregates — those now fix a `debugSeed`/
  `runSeed` on both sides for a deterministic comparison instead of relying
  on two wall-clock draws happening to agree (see "Tests/results").

## Tests/results

Environment note: no Flutter SDK was preinstalled in this session; Flutter
3.44.9 (stable, matching this repo's CI pin) was downloaded and installed
under `/opt/flutter` to run the commands below directly.

- `flutter analyze` (whole project): **No issues found.**
- `git diff --check`: clean (no whitespace errors).
- New tests added:
  - `test/game/public_demo/public_demo_rng_test.dart` (8 tests) — `PublicDemoRng`
    determinism, cross-runSeed/month/identifier variation, namespace
    independence, order independence, `Random` stream equality/distinctness.
  - `test/game/public_demo/public_demo_run_seed_test.dart` (21 tests) —
    generation (fresh draw, fixed injection, `PublicDemoAggregate.initial`
    threading), survival across every month-close command and an unrelated
    `copyWith`, save round trip (`PublicDemoState` and the strict codec,
    including after a mutation), and the full legacy-migration matrix: no
    key at all, deterministic re-migration of the same payload, two
    different payloads migrating to two different seeds, every other field
    preserved exactly, an already-genuine seed left untouched, a corrupted
    (non-int) seed migrated rather than rejected, and confirmation that
    every *other* kind of normalized field is still rejected as a whole
    save.
  - `test/ui/public_demo/public_demo_01_persistence_test.dart` — one new
    widget test: restart draws a fresh, different `runSeed` from the
    abandoned playthrough's own (using two distinct fixed seeds for a
    deterministic assertion, since two wall-clock draws are not guaranteed
    to differ within a single fast test run — see below).
- Existing tests updated (behavior-preserving, JSON-equality assertions only):
  4 tests in `public_demo_01_persistence_test.dart` and 1 in
  `public_demo_01_home_navigator_test.dart` that compared full
  `state.toJson()`/`aggregate.toJson()` equality between two separately
  constructed fresh aggregates now fix a shared seed (via the new
  `debugSeed`/`runSeed` parameters) on both sides instead. This was required
  because those aggregates are no longer bit-for-bit identical by
  construction — `runSeed` is now genuinely random per call, which is the
  entire point of the field — not because any other behavior changed.
  (One such fix, mid-implementation, briefly asserted two *independent*
  wall-clock draws would differ and flaked when both landed in the same
  millisecond inside the fast in-memory test VM; every such assertion in
  the final diff instead pins explicit seed values so no test's outcome
  depends on timing.)
- Full suite: `flutter test` (whole `test/` tree, concurrency 6) — **1812
  tests, 0 failures** (existing Public Demo save/restart/month/regression
  suites included; this is the actual final run after every fix above).

## Changed files

- `lib/game/public_demo/public_demo_rng.dart` (new) — the adapter.
- `lib/game/public_demo/public_demo_state.dart` — `runSeed` field,
  `aprilStart({runSeed})`, JSON round trip, legacy fallback.
- `lib/game/public_demo/public_demo_aggregate.dart` — `initial({runSeed})`,
  `runSeed` getter, one added invariant (`runSeed >= 0`).
- `lib/game/persistence/public_demo_save_codec.dart` — the one narrow
  legacy-`runSeed` migration exception to the strict round-trip check.
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` —
  `debugSeed` widget parameter, threaded into every fresh-aggregate call
  site (initial mount, no-save fallback, restart).
- `test/game/public_demo/public_demo_rng_test.dart` (new)
- `test/game/public_demo/public_demo_run_seed_test.dart` (new)
- `test/ui/public_demo/public_demo_01_persistence_test.dart` — `debugSeed`
  plumbing in `_mount`, `_bankruptAggregate`, and the seed-equality fixes
  above.
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart` — same
  seed-equality fix, one test.

## Untouched authorities

No change to: HOME layout/visual SSOT, Finance calculation formulas,
Balance figures, month-transition authority (`advanceToMay`/`closeApril`/
.../`completeFiscalYear`), existing assignment/revenue authority
(`PublicDemoWorkflowState`, `PublicDemoAssignment`, `PublicDemoRevenue*`),
Employee/Sales/Accounting/Menu visual components, gameplay balance, or any
Applicant/Project domain shape. `PublicDemoRecruitmentCalculation
._generateApplicants` still generates candidates by its existing
deterministic template cycling — Phase 1 adds no `Random`/`PublicDemoRng`
call anywhere in production recruitment/project/interview code.

## Phase 2 (Random Recruitment) connection

A future `PublicDemoRecruitmentCandidateGenerator` implementation draws its
`Random` via `PublicDemoRng.random(runSeed: state.runSeed, month: state.month,
namespace: PublicDemoRngNamespace.recruitmentCandidate, identifier: <listing
or medium id>)` and passes it into `ApplicantGenerator`
(`lib/domain/generation/applicant_generator.dart`, already seedable) — or an
equivalent Public-Demo-shaped generator — instead of the current template
pool. `PublicDemoAggregate.recruit`'s existing `candidateGenerator` injection
point (`PublicDemoRecruitmentCandidateGenerator` typedef) already accepts
this without any further interface change; only the default implementation
passed at that call site needs to change.

## Phase 3 (Recruitment Interview) connection

The main engine's `RecruitmentInterviewEngine`
(`lib/game/engine/recruitment_interview_engine.dart`) already derives every
interview draw (answer generation, reverse-question selection) from
`seededRandom(seed, week, salt)`. A Public Demo interview flow calls
`PublicDemoRng.random(runSeed: state.runSeed, month: state.month, namespace:
PublicDemoRngNamespace.recruitmentInterview, identifier: applicantId)` for
the same purpose, keeping the interview stream independent of
`recruitmentCandidate`'s (different namespace ⇒ different hash) so
generating a candidate and interviewing them the same month never
correlates in ways that would leak information between the two steps.
`projectGeneration`/`projectInterview` mirror this identically for the
project side once that phase begins.

## Remaining risks

- **`?seed=` URL wiring not added.** `main.dart`'s existing `?seed=` →
  `GameController.debugSeed` E2E convention was deliberately not extended to
  `PublicDemo01PlaceholderScreen` in this phase (out of the stated scope,
  and the widget-level `debugSeed` constructor parameter already gives
  Playwright/E2E harnesses a seam to use once that specific wiring is
  wanted) — a future phase wiring E2E reproducibility end-to-end only needs
  to pass `debugSeed: debugSeed` at the existing `PublicDemo01PlaceholderScreen()`
  construction site in `main.dart`.
- **Legacy-seed fingerprint stability.** The migrated `runSeed` for a
  pre-existing save is derived from that save's own JSON content
  (`stableHash(jsonEncode(stateJson))`). If a future change reorders or
  reformats `PublicDemoState.toJson()`'s own key set in a way that changes
  its `jsonEncode` output for otherwise-identical state, an in-flight legacy
  save decoded before vs. after that future change could migrate to a
  different fingerprint. This has no correctness impact today (nothing
  reads `runSeed` yet) but is worth flagging before Phase 2/3 start relying
  on it for actual gameplay determinism.
- **Audit input report absent.** As noted above, the named input document
  does not exist in this repository; this report's own file-level audit
  (rng.dart, the generators, the recruitment calculation, the save codec)
  stands in its place. If that document exists elsewhere and turns up
  later, it should be reconciled against this report's findings.

## Final verdict

**PASS**
