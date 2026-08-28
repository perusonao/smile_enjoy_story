# PR #84 EMPLOYEE-UI-1A — Independent Architecture & Integration Review

Independent re-review of the **current** head. The earlier approval of
`c4e3c800eec615b579350fe27cd4b66bb7e2a45c` was **not** inherited; the diff below was
read from scratch against the recorded base `3055ae849e9e290a766b8058e2af2bf1373bcba0`.

---

# Executive Decision

**KEEP WITH SMALL FIXES**

The architecture is correct. The authority boundaries the PR claims are the ones it
actually implements, and commit `4df7a50` fixes a genuine pre-existing authority
inconsistency rather than introducing one. The projection is a safe foundation for
EMPLOYEE-DATA work.

One presentation change in this PR causes a **real, reproducible CI regression**
(both browsers, both attempts, green on the base commit), and two smaller boundary
issues should be corrected while the file is young. None of this requires redesign.

---

# Reviewed Head

`4df7a50d7fad6c6bc50ca2bafb0152ccbb1086db`

Base recorded by the PR: `3055ae849e9e290a766b8058e2af2bf1373bcba0`
Repository `main` at review time: `dd67e0fa648be2e29967fc67adde8503cf5a3259`
(**PR #93 has already merged to `main`** — see §PR #93 Compatibility; the PR branch is
behind by #81 and #93.)

Changed files (3, +492 / -41):
- `lib/presentation/engineers/engineer_detail_display_data.dart` (new, 202)
- `lib/ui/engineers/engineer_detail_screen.dart` (modified, ~80)
- `test/presentation/engineers/engineer_detail_display_data_test.dart` (new, 251)

CI on the reviewed head (run `33193787247`):

| check | result |
|---|---|
| `validate` (analyze + `flutter test`) | **success** |
| `e2e-chromium` | **failure** — `phase-3b1-fit-reason.spec.ts:344`, 1 failed / 58 passed |
| `e2e-webkit` | **failure** |
| build / deploy / check-latest / replay-package | skipped (gated on e2e) |

---

# Findings

## BLOCKER-1 — The unconditional `現在の案件` card pushes the `面談依頼` CTA out of the freshly-mounted viewport and breaks E2E on both browsers

- **File:** `lib/ui/engineers/engineer_detail_screen.dart`
- **Class/function:** `EngineerDetailScreen.build` (ListView child list), `_CurrentAssignmentCard.build`

**What is wrong.** `_CurrentAssignmentCard` is added to the `ListView` **unconditionally**,
immediately above the `面談依頼` section:

```dart
_SkillSheetSalesCard(...),
const SizedBox(height:12),
_CurrentAssignmentCard(display: display.currentAssignment),   // always built
if(interviewOffers.isNotEmpty)...[const SizedBox(height:12),_SectionCard(title:'面談依頼', ...
```

When `display.currentAssignment == null` the card still renders a full `_SectionCard`
titled `現在の案件` containing `現在参画中の案件はありません。`. Before this PR no assignment
card existed at all — `_CurrentStatusCard` already carried the assignment detail in the
`assigned` state — so this is **purely additive vertical space**, and it is added in
exactly the states where there is no assignment (selling / interviewRequestPending /
waitingSelectionResult), i.e. precisely the states in which `面談依頼` matters.

**Why it matters.** Flutter Web's `SliverList` only materializes semantics for children
in or near the viewport. `e2e/tests/phase-3b1-fit-reason.spec.ts` documents this
explicitly in `scrollUntilButtonFound`'s doc comment, and its offer-wait loop calls
`openEngineerDetail(page)` which returns `snapshotScreen(page)` on a **freshly mounted
route at scroll offset 0, with no scroll**. The `面談へ進む` button therefore has to be
inside the initial viewport to exist in the accessibility tree at all. This PR moves it
one full section card further down.

**Concrete scenario.** Seed 100001, mobile viewport. Sales is started successfully (the
test's earlier `営業を開始する` assertion passes), the engine generates the interview
offer, but for 10 consecutive weeks `openEngineerDetail()` returns a snapshot with no
`面談へ進む` button, and the run fails at line 344 with
`no 面談依頼/面談へ進む appeared within 10 weeks (seed=100001)`.

**This is not a harness flake and not a pre-existing failure.** Separating the three
categories the task asks for:
- **(A) production architecture** — clean; nothing in this PR touches the domain, and the
  offer *does* exist in `GameState`.
- **(B) layout / reachability** — **this is the cause, and it originates in this PR's
  production code**, not in the harness.
- **(C) WebKit/Flutter semantics harness** — ruled out: the failure reproduces
  identically on **mobile-chromium** and **mobile-webkit**, and on the automatic retry.
  Evidence it is this PR: `main` at the PR's own base `3055ae8` (run `33174883338`) and
  at `ea0a4f2` (run `33180904498`) were both **green**, and PR #93 — branched from the
  same `main` — was **green on all three jobs** including this exact spec.

**Minimum recommended correction.** Render the card only when there is an assignment:

```dart
if (display.currentAssignment != null) ...[
  const SizedBox(height: 12),
  _CurrentAssignmentCard(display: display.currentAssignment!),
],
```

This restores the pre-PR layout for every non-assigned engineer (the E2E state) while
keeping the new card where it is actually informative. Do **not** fix this by adding a
scroll, a retry, or a timeout to the spec.

---

## HIGH-1 — The PR branch predates PR #93; it must be merged onto current `main` and re-validated before merge

- **File:** n/a (branch state)

**What is wrong.** The PR's base is `3055ae8`. `main` is now `dd67e0f` and includes
**PR #93 (merged)**, which introduces `EngineerDetailRouteScreen` and re-points
`engineer_list_screen.dart` at it. The reviewed head has never been built or tested
against that route shell.

**Why it matters.** Every E2E result on the reviewed head — including BLOCKER-1's
failure — was measured against a base without #93's bottom-bar CTA. After merging
`main`, `面談へ進む` is served from a persistent `bottomNavigationBar` that is
independent of the `ListView`, which will very likely mask BLOCKER-1's *symptom* in the
E2E suite while leaving the *defect* (an always-rendered empty card above the critical
region) in the product. Fix BLOCKER-1 on its own merits; do not let a green run after
the merge be read as evidence the layout change was harmless.

**Concrete scenario.** #84 is merged without merging `main` first: CI last ran against a
tree where tapping an engineer card opened `EngineerDetailScreen` directly. On `main` it
now opens `EngineerDetailRouteScreen`, a `Scaffold` whose `body` is another `Scaffold`
plus a `bottomNavigationBar` — a nesting this PR's layout has never been rendered inside.

**Minimum recommended correction.** `git merge origin/main` into
`codex/employee-ui-1a-20260828` (no textual conflict is expected — #93 touched
`engineer_detail_route_screen.dart`, `engineer_list_screen.dart` and
`e2e/helpers/artifacts.ts`; #84 touches none of them), then re-run the full suite.

---

## MEDIUM-1 — `EngineerSkillSheetDisplay` merges three different authorities into one class

- **File:** `lib/presentation/engineers/engineer_detail_display_data.dart`
- **Class:** `EngineerSkillSheetDisplay`

**What is wrong.** The class carries, side by side:

| field | real authority |
|---|---|
| `sheet` | stored `SkillSheet` (sales-facing) |
| `actualPrimaryLanguageMonths`, `actualBackend`, `actualLeader` | **actual career facts** (`Engineer.profile`) |
| `companyTrust`, `salesStatus`, `availableFromWeek` | **current employee state** (`Engineer`) |

The doc comment on `sheet` correctly and carefully states the sales-facing authority
rule — and then five actual-career-fact and current-state fields are placed under the
same roof with no separation.

**Why it matters.** This is exactly the boundary EMPLOYEE-DATA-1A exists to establish:
`actual career facts != stored SkillSheet != current assignment != current workflow`.
The class name and grouping teach the opposite. It is not a correctness bug today
(nothing is reconstructed, and the "実際 X / 記載 Y" comparison row legitimately needs
both sides), but it is the one place in this PR that actively works against the
separation it is meant to protect.

**Concrete scenario.** EMPLOYEE-DATA-1A lands `EngineerCareerProfile`. A later engineer
extending the SkillSheet card reads `display.actualBackend` and treats it as a
sheet-scoped value, or adds `certifications` to `EngineerSkillSheetDisplay` because
that is where the "skills" already live — quietly making the sales-facing sheet group
the de-facto home of career facts.

**Minimum recommended correction.** Non-blocking, but do it while the file is young:
split the actual-skill trio into an `EngineerActualSkillDisplay` (the future seam for
`EngineerCareerProfile`) and keep `EngineerSkillSheetDisplay` to `sheet` plus the
current-state fields — or, at minimum, add a comment naming the three authorities and
stating that career facts will move to their own display group in EMPLOYEE-DATA.

---

## MEDIUM-2 — The founding-guide client-interview CTA still bypasses the projection and can target a rejected proposal (pre-existing; this PR is the natural place to close it)

- **File:** `lib/ui/engineers/engineer_detail_screen.dart`
- **Function:** `EngineerDetailScreen.build`, the `_GuideBanner`'s `onCta` switch

**What is wrong.** The guide CTA still resolves its target independently:

```dart
FoundingStage.clientInterview when state.proposalForEngineer(engineerId)?.currentStep == SelectionStep.clientInterview =>
  () => ...ClientInterviewScreen(applicationId: state.proposalForEngineer(engineerId)!.id),
```

`GameState.proposalForEngineer` returns the **first proposal for the engineer regardless
of status** — no `active` filter, no completed-interview exclusion. Meanwhile the status
card, in the very same screen, now targets `display.currentStatus.clientInterviewApplicationId`,
which is active-only and completed-aware. Two CTAs on one screen, two different targets.

**Why it matters.** A rejected proposal keeps its `currentStepIndex` (both
`advanceWeek`'s selection step and `resolveClientInterview`'s failure path copy it
through unchanged) and is **not** purged from `state.proposals` — `activeProposals` only
drops finalized ones. So a stale rejected proposal can sit at `SelectionStep.clientInterview`
at the head of the list indefinitely.

**Concrete scenario.** Engineer has P1 (rejected at `clientInterview`, proposed first)
and P2 (active, at `clientInterview`). The status card correctly offers 面談をプレイ for
P2. The founding guide bubble's CTA opens `ClientInterviewScreen` for **P1** — a
rejected application.

**Minimum recommended correction.** Point the guide CTA at the projection:
`display.currentStatus.clientInterviewApplicationId` (guarded on non-null), deleting both
`proposalForEngineer` calls. One line, no new authority, and it removes the last
independent selection path in the file. This is **pre-existing behaviour, not a
regression introduced by #84** — but #84 is the projection PR, so leaving it is a missed
consolidation rather than a new defect.

---

## LOW-1 — `unlockedClientCount` is projected and then bypassed

- **File:** `lib/ui/engineers/engineer_detail_screen.dart`
- **Function:** `EngineerDetailScreen.build`

`EngineerCurrentStatusDisplay.unlockedClientCount` is populated by the factory, but the
sales card is passed `unlockedClientCount: state.unlockedClientCount` straight from
`GameState`. Both read the same getter so they cannot diverge today; it is simply a
second read path in a PR whose whole point is to have one. **Correction:** pass
`display.currentStatus.unlockedClientCount`.

---

## LOW-2 — `EngineerCurrentAssignmentDisplay` is a single-field wrapper duplicating `currentStatus.assignment`

- **File:** `lib/presentation/engineers/engineer_detail_display_data.dart`
- **Classes:** `EngineerCurrentAssignmentDisplay`, `EngineerCurrentStatusDisplay.assignment`

Both are populated from the **same single call** to `state.assignmentForEngineer(engineerId)`
in `EngineerDetailDisplayFactory.create`, so they are the identical object and cannot
diverge — this is **not** an authority duplication and, per the review brief, is not
objectionable merely because two references point at one object.

The real cost is narrower: `EngineerCurrentAssignmentDisplay` adds a class that holds one
non-null field and no behaviour, so the UI carries both `display.currentAssignment?.assignment`
and `display.currentStatus.assignment` as spellings of the same thing. **Correction
(optional):** drop the wrapper and let the card take `ActiveAssignment?`. Low value; safe
to defer. The *layout* consequence of the card is BLOCKER-1, which is separate.

---

## INFO-1 — `EngineerSummaryDisplay` leaks the raw `Engineer`; the projection is deliberately partial

`EngineerSummaryDisplay` wraps `Engineer` unchanged, and the screen still reads
`engineer.profile.*` directly for 基本情報 / 技術スキル / 人物パラメータ / 営業状況 and calls
`MatchingEngine.monthlyProfit` from the widget. This is a reasonable scope boundary for a
1A PR and is not a defect — but it means the sections that EMPLOYEE-DATA-1B/1C would
eventually extend (career, certifications, project history) are **not** behind the
projection yet. Worth stating plainly so the next task does not assume more coverage than
exists.

## INFO-2 — Every null-handling change in this PR is a strict improvement

The pre-PR screen used four unguarded `firstWhere` calls (`skillSheetFor`,
scheduled proposal, pending offer, offer→proposal) and one `assignmentForEngineer(...)!`.
Each would have thrown `StateError`/null-check and blanked the whole screen on a
malformed save. All five now degrade to a localized `…を確認できません。` message. No
gameplay path depends on the removed throws.

---

# Authority Matrix

| Concern | Authority **today** | Where PR #84 reads it | Authority **after EMPLOYEE-DATA-1A** |
|---|---|---|---|
| Actual employee skills / career facts | `Engineer.profile` (`skillFor(...).actualExperienceMonths`, `techSkills`) | `EngineerSkillSheetDisplay.actual*` — **misfiled, see MEDIUM-1** | `EngineerCareerProfile` (new, persisted). Must **not** be sourced from `EngineerSkillSheetDisplay`. |
| Stored SkillSheet (sales-facing) | `GameState.skillSheets` entry for the employee | `EngineerSkillSheetDisplay.sheet`, **nullable**, never reconstructed ✅ | unchanged — stays the sales-facing authority |
| Current workflow status | `EmployeeWorkflowEngine.forEngineer(state, id)` | `EngineerCurrentStatusDisplay.state` — sole source; the UI switch reads only this ✅ | unchanged |
| Current assignment | `GameState.activeAssignments` via `assignmentForEngineer` | `currentStatus.assignment` and `currentAssignment.assignment`, one lookup ✅ | unchanged — **must stay distinct from completed history** (issue #90 stop condition) |
| Certifications | *does not exist* | not represented | `EngineerCertification` (new, persisted) |
| Completed project history | *does not exist* | not represented — and correctly **not** inferred from `ActiveAssignment` ✅ | `EngineerProjectHistoryEntry` (new, persisted) |
| Presentation projection | `EngineerDetailDisplayFactory` (new) | read-only, no writes, no `copyWith`, no engine calls beyond `forEngineer` ✅ | extend with a *separate* career-facts display group |

**Verdict on §1 (authority boundaries):** preserved. `_firstProposal`, `_firstOffer`,
`_proposalById` and `_pendingClientInterviewProposal` are **read-only lookup
conveniences, not independent workflow reconstruction.** The decisive evidence is
predicate equality: every helper's predicate is character-for-character the predicate
`EmployeeWorkflowEngine.forEngineer` uses in its own `.any(...)` guard for the
corresponding state — including the `!clientInterviews.any(completed)` clause, which is
what commit `4df7a50` added. The projection never decides *which state* the employee is
in; it only answers "given the state the engine already returned, which record satisfies
the engine's own condition". Remove `EmployeeWorkflowEngine` and this projection produces
no status at all.

---

# Parallel Proposal Safety

**Safe** — with one caveat that is a coverage limit, not a correctness bug.

The first-match lookups are safe because of predicate equality (above). Walking §5's four
scenarios against the reviewed head:

| Workflow state | Engine's guard | Projection's pick | Consistent? |
|---|---|---|---|
| `clientInterviewActionRequired` | `any(active && step==clientInterview && !completed)` | `_pendingClientInterviewProposal` — **identical predicate** | ✅ **fixed by `4df7a50`.** The pre-PR screen's `firstWhere` omitted the `!completed` clause, so it could open `ClientInterviewScreen` for an already-completed session while the state was caused by a different parallel proposal. That was a real wrong-target bug in `main`; this PR removes it. |
| `finalOfferPending` | `any(offer.pending)` | `_firstOffer` — identical predicate | ✅ the selected offer always satisfies the guard |
| `assignmentScheduled` | `any(status==accepted)` | `_firstProposal(accepted)` | ✅ and **at most one can exist**: `acceptOffer` cancels every other `active`/`offered` proposal for that employee, and `advanceWeek` removes an accepted proposal once it becomes an assignment |
| `waitingSelectionResult` | `any(status==active)` | `pendingClientInterviewProposal ?? _firstProposal(active)` | ✅ the left operand is provably `null` in this state — `clientInterviewPending` is checked *before* `inSelection` in the engine's priority order, so reaching `waitingSelectionResult` guarantees no pending client interview exists. Behaviourally identical to the pre-PR `firstWhere`. |

**The caveat.** Two *pending* `Offer`s for one employee **are** reachable — `advanceWeek`
creates one per proposal that reaches `SelectionStep.offer`, and two parallel proposals
can reach it in the same week. Likewise two pending client interviews. In those cases the
status card summarizes only the first. This is acceptable because the status card is a
**pointer**, not the response surface: its own copy says
`下記「参画オファー比較・回答」から回答してください。`, and `_OffersComparisonSection`
renders **all** pending offers. No action is lost. It is also not a regression — the
pre-PR code used `firstWhere` with the same effect.

**Is list ordering an explicit authority? No — it is incidental.** Every write path
preserves insertion order (`[...proposals, p]`, in-place `map`, order-preserving
`where`), so first-match is deterministic in practice. But nothing documents or tests
it, and no `sort`/comparator exists. Treat it as an implementation detail.

**Minimum correction:** none required for merge. Do **not** add sorting — that would
invent a new ordering authority. Instead document the contract on
`EngineerCurrentStatusDisplay` ("first record satisfying the engine's own guard; a
summary pointer, not the complete set — parallel items are answered in their dedicated
sections") and add the parallel regression tests listed below.

---

# PR #93 Compatibility

**They can coexist safely — and #93 is already on `main`, so this is now a merge task,
not a hypothetical.**

`EngineerDetailRouteScreen` (merged in #93) wraps `EngineerDetailScreen` in a `Scaffold`
whose `bottomNavigationBar` carries the critical CTAs — `面談へ進む` / `断る` for a pending
`InterviewOffer`, `受諾` / `辞退` for a pending `Offer` — outside the detail `ListView`
entirely. Answering the specific questions:

- **Does the Current Assignment card materially increase layout pressure?** Yes, and
  measurably so: it is unconditional, sits directly above `面談依頼`, and it is the
  proximate cause of BLOCKER-1. With #93 merged the *critical* CTAs no longer depend on
  the list, so the blast radius shrinks to in-list content — but the card is still pure
  additive space in every non-assigned state.
- **Can #84 merge cleanly with the route-level design?** Yes. No file overlap
  (#93: `engineer_detail_route_screen.dart` [new], `engineer_list_screen.dart`,
  `e2e/helpers/artifacts.ts`; #84: `engineer_detail_screen.dart`, plus two new files).
  No textual conflict expected. `EngineerDetailScreen` keeps returning its own `Scaffold`,
  which #93 already nests today.
- **Should the current assignment stay in `EngineerDetailScreen`?** Yes. It is read-only,
  non-time-sensitive information — exactly the class #93's rule says may scroll. It does
  **not** belong in the critical bar.
- **Is a content-ordering change required?** No reordering. Only the conditional render
  (BLOCKER-1). Keeping `_CurrentStatusCard` at the top is correct and unchanged.
- **Should #84 avoid owning critical CTA placement?** Yes, and it already does — with one
  exception worth naming: `面談をプレイ` (`clientInterviewActionRequired`) lives in
  `_CurrentStatusCard` inside the list, and #93's bar does not cover client interviews.
  #84 neither moves nor worsens it (the card is second from the top). **Leave it to #93's
  workstream**; #84 must not start owning CTA placement.

**One integration hazard to record, not to fix here.** After both land, three independent
read paths for the same records coexist in this screen: #93's route shell
(`state.interviewOffers.where(...).first`, `state.offers.where(...).first`), #84's
projection (`_firstOffer`), and `EngineerDetailScreen`'s own inline `pendingOffers` /
`interviewOffers`. All three use first-match on the same stable ordering, so they agree
today. The consolidation — extending the projection to cover offers and interview offers
and having the route shell consume it — is the natural EMPLOYEE-UI-1B follow-up. It is
**out of scope for #84** and must not be attempted in this PR.

---

# EMPLOYEE-DATA-1A Readiness

**READY**

Issue #90's scope is explicitly domain + save only — *"no employee-detail UI additions in
1A"*. It adds `EngineerCareerProfile`, `EngineerCertification` and
`EngineerProjectHistoryEntry` to the domain/persistence layer. PR #84 adds a
presentation-layer projection and touches no domain model, no save schema, and no engine.
**The two work in disjoint layers; there is no technical dependency in either direction,**
and nothing in #84 — including BLOCKER-1, which is a widget-tree ordering issue — can
force rework of 1A.

What #84 contributes positively to 1A:
- It establishes that the stored `SkillSheet` is nullable at the presentation boundary and
  is **never** reconstructed from actual values — the precise discipline 1A needs when
  career facts become a *third* skill-shaped source.
- It correctly declines to infer any history: `ActiveAssignment` is projected as *current*
  only, with no "completed project" inference anywhere. That directly satisfies #90's stop
  condition *"do not duplicate a current active assignment into completed history"*.
- It gives 1C a ready-made read path for a future history card without disturbing the
  workflow authority.

The one thing 1A must **not** do: source actual career facts from
`EngineerSkillSheetDisplay.actual*` (MEDIUM-1). `EngineerCareerProfile` must be its own
authority, and the presentation layer must eventually read career facts from it, not from
the SkillSheet display group.

The dependency stated in issue #90 (*"start only after PR #84 is merged/stabilized"*) is a
**process gate the owner set, not an architectural constraint**. If schedule pressure
exists, 1A can begin in parallel without risk; if the owner prefers to keep the gate, the
fixes below are small and fast.

---

# Required Changes Before Merge

Only these two are genuinely required.

1. **Render `_CurrentAssignmentCard` only when an assignment exists** (BLOCKER-1) —
   `lib/ui/engineers/engineer_detail_screen.dart`.
2. **Merge current `origin/main` (post-#93) into the PR branch and re-run the full suite,
   including `e2e-chromium` and `e2e-webkit`** (HIGH-1). `phase-3b1-fit-reason` must be
   green **without** any change to the spec, its timeouts, its retries, or its scroll
   handling.

Everything else in this report (MEDIUM-1, MEDIUM-2, LOW-1, LOW-2) is a recommended
follow-up, not a merge gate.

---

# Recommended Tests

High regression value, in priority order. All are pure `EngineerDetailDisplayFactory`
tests in the existing file — no widget or E2E tests needed.

1. **Multiple pending Offers → the selected offer and its proposal correspond.**
   Two pending `Offer`s for one engineer; assert `state == finalOfferPending`,
   `pendingOffer.status == pending`, and — the property that actually matters —
   `pendingOfferProposal!.id == pendingOffer!.applicationId`. Locks the pairing
   invariant rather than the arbitrary first-match choice.
2. **Multiple pending client interviews → the target is one of the *pending* ones.**
   Two active proposals at `clientInterview`, neither completed. Assert
   `clientInterviewApplicationId` is non-null and belongs to the pending set, and that
   `activeProposal!.id == clientInterviewApplicationId`. Guards the §5 consistency rule
   under genuine parallelism.
3. **Completed client interview + another pending one → the completed one is never the
   target.** The direct regression test for what `4df7a50` fixed. Currently the only
   uncovered path of the commit that motivated this re-review — the existing
   "pending client interview proposal" test distinguishes by *step*, not by *completion*.
   Highest value test in this list.
4. **Missing linked proposal for a pending Offer.** Offer whose `applicationId` matches no
   proposal; assert `pendingOffer != null && pendingOfferProposal == null` and that
   `create` returns normally. Pins the malformed-save contract the UI's
   `'案件情報を確認できません'` fallback depends on.
5. **`waitingSelectionResult` with several active proposals → `activeProposal` is active
   and `clientInterviewApplicationId` is null.** Cheap, and pins the
   `pendingClientInterviewProposal ?? firstActiveProposal` fallback that today is only
   exercised with a single proposal.
6. **Assignment + a stale accepted proposal → `assigned` wins and `currentAssignment` is
   the `ActiveAssignment`, not the proposal.** Guards the current-vs-scheduled boundary
   that EMPLOYEE-DATA-1C will lean on.

Not recommended: exhaustive state/order permutations. Items 1–3 cover the real risk.

---

# Codex Handoff

Paste directly. Root cause is stated — do not re-investigate it.

```
Branch: codex/employee-ui-1a-20260828 (PR #84)

Two required fixes. Do not change the domain, the engines, the E2E specs, or the
save schema. Do not add scrolls, retries, timeouts, or skips to any test.

--- FIX 1 (required) ---
File: lib/ui/engineers/engineer_detail_screen.dart

_CurrentAssignmentCard is currently added to the ListView unconditionally, directly
above the 面談依頼 section. When there is no assignment it still renders a full
_SectionCard ("現在の案件" / "現在参画中の案件はありません。"), which is pure additive
vertical space in exactly the states where 面談依頼 matters.

ROOT CAUSE (already confirmed — do not re-investigate): Flutter Web's SliverList only
materializes semantics for children near the viewport, and
e2e/tests/phase-3b1-fit-reason.spec.ts opens the engineer detail route fresh at scroll
offset 0 and reads snapshotScreen() WITHOUT scrolling. The extra card pushes 面談へ進む
out of the materialized viewport, so the spec fails at line 344 with
"no 面談依頼/面談へ進む appeared within 10 weeks (seed=100001)" on BOTH mobile-chromium
and mobile-webkit, retry included. main was green on this spec at the PR's base commit
3055ae8 and on PR #93.

Change:
  const SizedBox(height:12),
  _CurrentAssignmentCard(display: display.currentAssignment),
to:
  if (display.currentAssignment != null) ...[
    const SizedBox(height: 12),
    _CurrentAssignmentCard(display: display.currentAssignment!),
  ],
Adjust _CurrentAssignmentCard's parameter to a non-nullable
EngineerCurrentAssignmentDisplay and drop its internal null branch, or keep the
nullable signature — either is fine, but the card must not be built when the engineer
has no assignment.

--- FIX 2 (required) ---
Merge origin/main into this branch. main now contains PR #93
(EngineerDetailRouteScreen: a route-level Scaffold whose bottomNavigationBar carries
面談へ進む/断る and 受諾/辞退 outside the detail ListView). No textual conflict is
expected — #93 touched engineer_detail_route_screen.dart (new),
engineer_list_screen.dart and e2e/helpers/artifacts.ts; this PR touches none of them.
Do NOT move any CTA into or out of the route shell; #84 must not own critical CTA
placement.

Then run: flutter analyze, flutter test, and the full Playwright suite on both
mobile-chromium and mobile-webkit. phase-3b1-fit-reason must pass with the spec file
unmodified. Note: FIX 2 alone may make the spec pass because #93's bottom bar bypasses
the ListView — apply FIX 1 regardless; it is a product defect, not just a test symptom.

--- OPTIONAL, only if trivially safe in the same pass ---
a) engineer_detail_screen.dart: pass display.currentStatus.unlockedClientCount to
   _SkillSheetSalesCard instead of state.unlockedClientCount.
b) engineer_detail_display_data.dart: add a comment on EngineerSkillSheetDisplay
   naming its three distinct authorities (stored SkillSheet / actual career facts /
   current employee state) and noting that career facts will move to their own display
   group in EMPLOYEE-DATA. Do not restructure the class in this PR.
c) test/presentation/engineers/engineer_detail_display_data_test.dart: add a test for
   "completed client interview on proposal A + pending client interview on proposal B"
   asserting clientInterviewApplicationId == B. This is the direct regression test for
   commit 4df7a50 and is currently uncovered.

Do NOT do in this PR: route offers/interviewOffers through the projection, change the
founding-guide CTA's proposal lookup, or split EngineerSkillSheetDisplay. Those are
EMPLOYEE-UI-1B follow-ups.
```

---

# Final Recommendation

The concept is sound and the implementation is closer to correct than the CI signal
suggests. The authority rules in the PR description are the rules the code actually
enforces; `4df7a50` removed a genuine wrong-target bug that exists in `main` today; and
every null-handling change replaces a screen-blanking `firstWhere` throw with a localized
fallback. Nothing here warrants rework or replacement.

What blocks it is one line of layout, plus a branch two commits behind a `main` that has
since changed how this screen is routed.

**PR #84 merge readiness: BLOCKED**
(BLOCKER-1 + HIGH-1. Both are small and mechanical; expect green after the two required
changes.)

**EMPLOYEE-DATA-1A start readiness: PASS**
(No technical dependency on #84 — issue #90 is domain/save only with no UI, and the two
PRs occupy disjoint layers. The gate in #90 is procedural; if the owner keeps it, the
required fixes above are hours, not days. 1A must define `EngineerCareerProfile` as its
own authority and must not read actual career facts from `EngineerSkillSheetDisplay`.)
