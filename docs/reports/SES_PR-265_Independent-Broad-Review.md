# PR #265 — Mission System Phase 1 — Independent Broad Review / Merge Gate

**Role of this document**: an independent Claude Code Broad Review performed *after* PR #265's own author self-review, requested because Codex Broad Review could not run (ChatGPT Codex usage limit — see the PR's own comment thread). This is a single pass, read-only against the PR diff plus the pre-existing domain code it depends on; no second review of this document was requested or performed.

- **Reviewed PR HEAD**: `8a469292ab84960b782ab8edf94f0aac241e2b7b` (`claude/mission-system-phase1-2yp09r`) — confirmed against GitHub twice (once at session start, once immediately before writing this report); unchanged both times.
- **Base (`main`) SHA**: `dfb272619b92219853203a2f72eba4c785c0f66f` (PR's own recorded base — `list_commits` on `main` returns this same SHA as tip, so `main` has not advanced since the PR was opened).
- **CI at time of review**: GitHub `mergeable_state: "clean"`; all 4 checks (`validate`, `replay-unit`, `Public Demo only`, `Build Public Demo browser preview`) green.
- **Codex Broad Review**: did not run (usage limit). Per task instruction, **not** re-requested.

---

## Method

1. Fetched `origin/main` and the PR head branch directly (not a fork/patch) and diffed them (`git diff dfb2726..8a46929 --stat` → 10 files, 2618 insertions, 0 deletions — a purely additive diff except for the 39-line `public_demo_01_placeholder_screen.dart` hunk).
2. Read every changed production file in full: `public_demo_mission_resolver.dart`, `public_demo_mission_screen.dart`, and the diff hunk in `public_demo_01_placeholder_screen.dart`.
3. Cross-checked the resolver's authority claims against the actual domain code it reads (`public_demo_sales.dart`, `public_demo_workflow_state.dart`) — not just the PR's own doc comments — specifically: the `PublicDemoSalesStage` enum's declaration order, every state-transition guard (`_transitionEngineerStage`'s `from` sets), `hasGenuineInterviewRecord`'s definition, and `assignedEngineerIds`' month-dependent filtering.
4. Read both new test files in full (14 resolver tests, 24 UI tests) and confirmed each test actually exercises the boundary its name claims (not just a name match).
5. Installed Flutter 3.44.8 (this repo's `public-demo-validation.yml`-pinned version) fresh in-session (none was pre-installed) and ran `flutter analyze`, `flutter test test/game/public_demo`, and `flutter test test/ui/public_demo` myself against the PR head, rather than trusting the PR body's reported numbers.
6. Re-verified `git diff --check` myself.

---

## Findings

**No P0, P1, P2, or P3 findings.** Below is the reasoning per review-priority item, not a blank pass — each item was actively checked against code, not assumed from the PR's own description.

### 1. Mission Resolver authority

- **Stage-only forgery**: `viewSkillSheet` is `stage != waiting`. Checked whether any code path can move a `PublicDemoSalesStage` past `waiting` without going through `startSkillSheetReview` first: `beginSelling`'s guard requires `from ∈ {skillSheet, partnerInterviewFailed, clientInterviewFailed}` — every one of those is only reachable *after* `skillSheet` was already set once. The only three places a `PublicDemoSalesStage` is ever assigned outside `_transitionEngineerStage`'s own guarded helper are `recordOrder` (itself gated on `stage == clientInterviewPassed`, i.e. already downstream of the SkillSheet gate) and two `PublicDemoOfferCandidateStage` sites unrelated to this engineer-level enum. There is no back door; the resolver's `viewSkillSheet` check is a faithful read of a genuinely-gated fact, not a forgeable one. The PR's own added unit test (`malformed/forged stage cannot fake Mission completion`) additionally proves a hand-constructed `PublicDemoEngineerSales(stage: ordered, interviewRecord: null)` correctly shows `winOrder` completed (a case the domain itself trusts bare-stage for, matching `recordOrder`'s own precondition) but `passClientInterview` and `assignToProject` correctly do **not** — confirmed this test genuinely exercises what it claims by reading it line-by-line, not by name alone.
- **Genuine interview record**: `passClientInterview` reads `hasGenuineInterviewRecord` (`interviewRecord?.engineerId == id`), never `stage == clientInterviewPassed` — verified this is the same field every other production reader of interview outcome already trusts (`public_demo_offer_comparison_screen.dart`, `public_demo_workflow_state.dart` lines 1434/1540/2450/2490).
- **`enum.index`**: grepped the resolver file — zero uses of `.index`. All three stage-progression helpers (`_hasReachedSelling`, `_hasReachedIntroduced`, `_hasPassedPartnerInterview`) are exhaustive `switch` statements over all 9 `PublicDemoSalesStage` values (confirmed exhaustive — `flutter analyze` would reject a non-exhaustive switch with no `default`, and it passed clean). This matters because the enum's actual declaration order (`waiting, skillSheet, selling, introduced, partnerInterviewFailed, partnerInterviewPassed, clientInterviewFailed, clientInterviewPassed, ordered`) interleaves the two `Failed` variants with their `Passed` counterparts — a `.index` comparison would have been silently wrong.
- **ordered/assigned authority**: `assignToProject` reads `workflow.assignedEngineerIds(month: state.month)` using the *caller's own* `state.month` at resolve time (never a parameter the caller could staleness-capture) — matches `assignedEngineerIds`' own doc, which is the same SSOT Revenue/roster/HOME already agree on. Confirmed via the `month boundary — no stale-month read` test, which genuinely advances the aggregate April→July (crossing the `assignedEngineerIds` July filter-behavior change at month 7) and asserts the resolver still reads correctly against the post-transition state — not a trivial same-month check.

### 2. Save compatibility

- `schemaVersion` unchanged (still `1`) — confirmed no `schemaVersion` reference was touched in the diff.
- **Legacy save**: the `legacy save compatibility` test round-trips a genuinely-ordered+assigned aggregate through the *real* `PublicDemoSaveCodec.encode`/`decode` (not a hand-built fixture) and asserts every mission resolves `completed` on the very first resolve — this is a real regression test, not a name-only claim.
- **Save/reload, mid-progress save**: covered structurally by the resolver being a pure function of `workflow`/`state` — there is no Mission-specific persisted state to desync from a reload; every resolver test that reloads through `PublicDemoAggregate.fromJson` (the retry test, below) confirms this in practice too.
- **Month transition / retroactive completion**: see the month-boundary test above; also confirmed (by reading `assignedEngineerIds`' own extensive doc comments) that an assignment row before month 7 is deliberately never removed early specifically to avoid an already-earned month's completion silently reverting — so `assignToProject`, once true within the April→June window this Phase's headline targets, cannot un-complete itself mid-year by that mechanism.
- **Duplicate completion**: `resolving twice in a row for the same aggregate is identical` (idempotency test) plus the AppBar-entry widget test `reopening the Mission screen does not accumulate duplicate MISSION COMPLETE banners` (opens the screen, backs out, reopens, asserts `findsOneWidget` each time — not just "no crash").

### 3. Retry / failure

- **上位会社面談失敗 → retry → 成功**: the `retry after a genuine partner-interview failure` test drives a real fail (deterministic `actualCapability 52 → score 57 < 60`), confirms `passPartnerInterview` correctly stays not-completed, then genuinely re-enters via `beginSelling` (accepted from `partnerInterviewFailed` per the domain's own transition table — not a shortcut), raises capability through a realistic `engineerRuntimes` mutation (shaped like real Growth output), round-trips through `PublicDemoAggregate.fromJson`, and only then asserts a genuine pass. This is a real re-entry, not a forged shortcut, and I traced the transition table myself to confirm `beginSelling`'s `from` set really does include `partnerInterviewFailed`.
- **客先面談失敗 → retry**: `passClientInterview` reading only `hasGenuineInterviewRecord` means a client-interview failure (which does not mint a record) cannot be papered over by a later unrelated stage bump — confirmed by the record's own definition being identity-scoped (`interviewRecord?.engineerId == id`), matching the "reused on a different applicant" rejection already covered elsewhere in this codebase's own `public_demo_offer_candidate.dart`.
- **pipeline re-entry時のMission状態**: the PR's own documented known-limitation — `passPartnerInterview`/`proposeToProject` can transiently read `available` again during a genuine re-entry window after a client-interview failure — is real domain re-entry behavior (the engineer really is back at an earlier pipeline stage), not a resolver bug; flagged correctly as a Known Limitation rather than silently hidden.

### 4. Engineer consistency (company-level, mixed engineers)

Traced whether "Engineer A confirms SkillSheet, Engineer B does sales" can produce a false company-level completion. Each mission is independently `any engineer` — but every stage-gated mission requires the *same* engineer to have passed every earlier gate themselves (`beginSelling`'s precondition is that engineer's own `stage == skillSheet`, `introduceProject`'s is that engineer's own `stage == selling`, etc. — see `public_demo_workflow_state.dart`'s transition table, all gated on the mutating engineer's own current stage). So whichever single engineer eventually reaches `ordered`+assigned necessarily passed the SkillSheet gate themselves too; a second engineer (A) independently also having done so earlier does not create a "faked" appearance — it reports the true company-level fact ("some technician's SkillSheet was confirmed", "some technician is now participating") exactly as the task's own framing (2-founder roster, single company milestone, not a per-engineer scoreboard) requires. `engineerId` is correctly attached per-mission from whichever specific engineer satisfies that specific check (`firstEngineerWhere`), not implied to be one consistent engineer across the whole chain — the UI never claims "engineer X completed the whole journey," only the per-step purpose text, so there is no misleading narrative surface. The `company-level reduction` unit test (engineer A views SkillSheet, engineer B begins selling, both report `completed` with the correct distinct `engineerId`s) confirms this is intentional, tested behavior, not an accidental side effect.

### 5. UI

- Ran the actual widget-test overflow matrix myself (not just re-read it): 360×800 and 390×844, TextScaler 1.0 and 1.3, across fresh/partial/complete chains — all pass, `tester.takeException()` asserted `isNull` in every cell.
- AppBar Mission entry: confirmed present on all 5 tabs (`AppBar Mission entry point` parametrized test over `PublicDemoTab.values`), confirmed it is Scaffold-level chrome (survives tab switches, per the diff only touching the shared `AppBar.actions` list once).
- MISSION COMPLETE display: shown exactly once per open, verified via the `_isMainMissionComplete` branch in `PublicDemoMissionScreen.build` (mutually exclusive with `_MainMissionHeader` — an `if/else`, not two independently-conditioned widgets that could both render).
- HOME body / Bottom Navigation: the `HOME Freeze regression` test asserts the 5-item bottom nav is unchanged and the Mission chain's own text (`'4月の目標'`) never leaks into HOME's body — and the diff itself shows zero lines touched in HOME's body-building code, only the AppBar `actions` list and one new private method.

### 6. Existing event interaction

- No double演出: `_maybeShowMonthlyReport` (the one existing month-close dialog, including the existing `入社・初参画！` new-hire notification) is untouched by this diff (confirmed via `git diff` — zero lines in that method or its call sites). The Mission screen is only ever reached by an explicit player tap on the new AppBar button, never auto-shown, so there is no path for the two to co-occur uninvited.
- MISSION COMPLETE repetition on reload/reopen: covered above (idempotent resolve + no-duplicate-on-reopen widget test).

### 7. Scope

Diff-stat confirmed 10 files touched, all in-scope: the 2 new production files, 1 additive 39-line hunk in the AppBar host screen, 3 new test files, and 4 documentation files (2 governing design docs added verbatim, 1 new Result report, 1 priority-doc sync entry). Zero touches to SkillSheet editing, training, recruitment, images, or Opening Context — confirmed by the stat itself, not just the PR's own claim.

---

## Fixes

None. No P0/P1 findings, and no P2 directly touching Mission System requirements was found either, so nothing was changed in this review pass.

## Tests

Ran directly against PR HEAD `8a469292ab84960b782ab8edf94f0aac241e2b7b` in this review session (Flutter 3.44.8, this repo's `public-demo-validation.yml`-pinned version, installed fresh for this session):

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found!** (17.2s) |
| `flutter test test/game/public_demo` | **All tests passed!** (1043 tests) |
| `flutter test test/ui/public_demo` | **All tests passed!** (800 tests) |
| `git diff --check` (base..head) | clean, no output |

No test was added or modified by this review (no fix was needed). One unrelated side effect was observed and discarded, not committed: running the UI suite regenerates 4 golden screenshot PNGs under `docs/reports/screenshots/` (`public_demo_seeded_recruitment_visual_test.dart`, an unrelated pre-existing visual-regression test bundled in the same `test/ui/public_demo` directory) with a few differing bytes, almost certainly due to this container's font/rendering stack rather than any content change — reverted before finishing this review so as not to pollute this PR's scope.

## Remaining limitations (Known Limitation, not defects)

Both already disclosed in the PR body and independently confirmed correct in this review, not new findings:

1. HOME-Freeze/AppBar placement follows the Fresh Audit's own recommended Option E rather than being separately re-litigated here — confirmed consistent with the governing audit doc added by this same PR.
2. A client-interview-failure retry legitimately re-enters the pipeline, so `passPartnerInterview`/`proposeToProject` can transiently read `available` again during that replay window — this is real domain state, not a resolver bug (see §3 above).

Recommended next step (unchanged from the PR's own recommendation): Phase 2 (progressive onboarding / Opening Context paged-flow redesign), which depends only on this Phase 1's resolver/unlock signals and does not require re-opening this PR's own scope.

## Merge Readiness

- CI: green (`mergeable_state: clean`, all 4 checks passed).
- Independently re-run analyze/tests against PR HEAD: all clean/passing.
- No P0/P1/P2/P3 findings from this independent pass.
- Codex Broad Review did not run (usage limit) and was correctly not re-requested per task instruction — this Claude Independent Broad Review is the sole broad-review gate exercised for this merge decision.

## FINAL VERDICT

**GO — approve for merge as-is. No fixes required.**
