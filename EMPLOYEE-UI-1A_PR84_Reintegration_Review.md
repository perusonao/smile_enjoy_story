# EMPLOYEE-UI-1A — PR #84 Latest-main Reintegration Review

Independent review. No code was modified, committed, pushed, merged or closed on PR #84.
Review date: 2026-08-29.

Toolchain note: this review environment has no Flutter/Dart SDK (`flutter: command not found`)
and no Playwright browser run. Every claim below is therefore evidenced by source lines, git
history, or GitHub Actions results — never by a locally executed suite. Where a conclusion
requires an actual run to confirm, it is labelled as such.

---

## 1. Current main SHA

```
adf1325ed0770d3f8330c8de25d95417e0cc5c2a
Merge pull request #99 from perusonao/agent/payroll-1a-current-main-20260829
```

E2E workflow run for this SHA: run `33227681873` — **success**.

## 2. PR #84 HEAD SHA

```
4df7a50d7fad6c6bc50ca2bafb0152ccbb1086db   Fix client interview status proposal target
c4e3c80...                                  EMPLOYEE-UI-1A: add engineer detail display projection
```

Head branch: `codex/employee-ui-1a-20260828`. 2 commits, 3 files, +492 / −41.

## 3. Mergeability / base divergence

| Fact | Value |
|---|---|
| Recorded PR base | `3055ae849e9e290a766b8058e2af2bf1373bcba0` |
| Actual `git merge-base pr84 origin/main` | `3055ae849e9e290a766b8058e2af2bf1373bcba0` (identical — the branch was never merged forward) |
| Divergence (`git rev-list --left-right --count origin/main...pr84`) | **26 behind, 2 ahead** |
| Trial merge onto current main | `git merge --no-commit --no-ff pr84` → `Automatic merge went well; stopped before committing as requested` |
| Textual conflicts | **None** |

Files after the trial merge: exactly the PR's three files, no other path touched.

The clean textual merge is **not** the whole story — see §7 for semantic drift, which is where
the real reintegration content of this PR lies.

## 4. File-by-file assessment

### 4.1 `lib/presentation/engineers/engineer_detail_display_data.dart` (new, 202 lines)

Read-only projection with four sections plus a factory.

- `EngineerDetailDisplayFactory.create` returns `null` for an unknown id (line ~86 comment and
  the `if (engineer == null) return null;` guard) — the screen keeps its established
  "社員が見つかりません。" state instead of dereferencing.
- Current status is taken from `EmployeeWorkflowEngine.forEngineer(state, engineerId)` and stored
  in `EngineerCurrentStatusDisplay.state`, documented as "Sole current-status authority".
  No parallel re-derivation anywhere in the file.
- `EngineerSkillSheetDisplay.sheet` is `SkillSheet?`, explicitly documented as nullable for a
  malformed/legacy save, with the instruction that callers must show an unavailable fallback
  "rather than recreating a sheet from actual skills". The actual-skill fields
  (`actualPrimaryLanguageMonths`, `actualBackend`, `actualLeader`) are carried **beside** the
  stored sheet, never merged into it.
- All lookups are explicit loops returning `null` (`_firstProposal`, `_firstOffer`,
  `_proposalById`, `_pendingClientInterviewProposal`) — no `firstWhere` without `orElse`.
- `activeProposal` and `clientInterviewApplicationId` are both derived from
  `_pendingClientInterviewProposal` (`activeProposal: pendingClientInterviewProposal ?? firstActiveProposal`,
  `clientInterviewApplicationId: pendingClientInterviewProposal?.id`). This is the fix commit
  `4df7a50` and it does resolve the earlier codex thread `r3881187595`.

Assessment: **sound**. This file is the strongest part of the PR.

Minor convention drift: current main's established projection location is
`lib/presentation/<feature>/models/*_display_data.dart`
(`lib/presentation/home/models/home_dashboard_display_data.dart`, HOME-UI-1C). This PR uses
`lib/presentation/engineers/engineer_detail_display_data.dart` with no `models/` segment.
Cosmetic, non-blocking.

### 4.2 `lib/ui/engineers/engineer_detail_screen.dart` (modified, +/−41)

Widgets now consume the projection instead of reading `GameState` directly. Concretely:

- line 69 `final workflowState = display.currentStatus.state;` replaces a second
  `EmployeeWorkflowEngine.forEngineer` call — good.
- line 87 `final skillSheet = display.skillSheet.sheet;` replaces `state.skillSheetFor(engineerId)`.
  `GameState.skillSheetFor` at `lib/game/models/game_state.dart:208` is
  `skillSheets.firstWhere((s) => s.employeeId == id)` with **no `orElse`** — it throws
  `StateError` on a legacy save with no sheet. Replacing it with a null-tolerant path plus an
  explicit fallback card is a genuine robustness improvement, not a behaviour weakening.
- `_CurrentStatusCard` (line 288) no longer takes `GameState`; every `firstWhere` inside its
  `switch` is replaced by a nullable projection field with an explicit
  "…情報を確認できません。" fallback and, for the client-interview case, the action button is only
  built when `clientInterviewApplicationId != null`.
- New `_SkillSheetSalesCard` (line 277) renders
  `_SectionCard(title:'スキルシート / 営業', children:[Text('営業用スキルシートを確認できません。')])`
  when the stored sheet is missing, and both CTAs are passed `null` in that case (line 150) so
  they render disabled rather than crashing.
- New `_CurrentAssignmentCard` (line 282), inserted unconditionally at line 152.

Assessment: **sound except for the card at line 152** — see §5 and §7.

Two concrete defects in this file:

- **D1 (layout)** — line 152 `_CurrentAssignmentCard(...)` is followed directly by the
  `if(interviewOffers.isNotEmpty)` block and then `_SectionCard(title:'基本情報')`. Unlike every
  other adjacent pair on this screen, there is **no `const SizedBox(height:12)` after it**. When
  both conditional blocks are false, 現在の案件 and 基本情報 render flush against each other.
- **D2 (authority)** — line 150 passes `unlockedClientCount: state.unlockedClientCount` even
  though the projection already carries `display.currentStatus.unlockedClientCount`. A second
  read path for a value the projection was created to own.

### 4.3 `test/presentation/engineers/engineer_detail_display_data_test.dart` (new, 251 lines)

Six projection-level tests: stored-sheet passthrough (`expect(display.skillSheet.sheet, same(sheet))`),
assignment present/absent + unknown-id `null`, missing-sheet stays `null`, and three covering the
`4df7a50` parallel-proposal fix (parallel proposals, single proposal, non-client-interview step).

Assessment: **good coverage of the projection**, and correctly located under `test/presentation/`
matching main's `test/presentation/home/` convention.

Gap: there is **no widget test** asserting the rendered behaviour of `_CurrentAssignmentCard` —
neither that it shows the assignment for an assigned engineer, nor that it is absent for an
unassigned one. That gap is exactly why finding #1 reached CI unnoticed.

## 5. Prior finding #1 verification — "`_CurrentAssignmentCard` should render only when assignment is non-null"

**Status: CONFIRMED as written — but it is not the CI blocker, and fixing it alone will not turn CI green.**

Evidence for the finding itself:

`lib/ui/engineers/engineer_detail_screen.dart:282`

```dart
class _CurrentAssignmentCard extends StatelessWidget {
  ...
  Widget build(BuildContext context){
    final a=display?.assignment;
    if(a==null) return const _SectionCard(title:'現在の案件',
        children:[Text('現在参画中の案件はありません。')]);
    ...
```

and the call site at line 152 is unconditional:

```dart
_CurrentAssignmentCard(display: display.currentAssignment),
```

So for every waiting / selling / in-selection / offer-pending engineer the screen gains a
「現在の案件」card stating that no assignment exists. `_CurrentStatusCard` (line 288) already
represents precisely those states — `EmployeeWorkflowState.waiting` renders
「営業を開始すると、案件の面談依頼が届くようになります。」and `.selling` renders
「SkillSheet公開先 N社\n面談依頼待ちです。」— so the new card is redundant and pushes the
sales/interview controls further down. This matches the open codex thread `r3883486206` on line 152.

There is a second, symmetric redundancy the original finding does not mention: when the engineer
**is** assigned, `_CurrentStatusCard`'s `assigned` branch already prints
`a.project.title`, `残り${a.remainingWeeks}週` and `単価 ${formatYen(a.project.monthlyRate)}`
(lines 311-315), and `_CurrentAssignmentCard` then repeats 案件 / 残り / 月単価 immediately below it.
Three of the five rows in the new card are a verbatim second rendering of the status card.

**Critical correction to the assumed remediation.** The PR author's instruction to codex
(review comment `r3883469975`) treats "do not build `_CurrentAssignmentCard` when
`display.currentAssignment` is null" as the fix that will let CI pass. It will not. In the failing
E2E scenario the engineer **is assigned**, so `currentAssignment != null` and the null-guard never
fires. The guard is correct on its own merits (redundant section, misleading empty state); it is
orthogonal to the red CI. See §7.

## 6. Authority-boundary verification

| Boundary | Verdict | Evidence |
|---|---|---|
| `EmployeeWorkflowEngine` remains the sole current-status authority | **PASS** | `EngineerCurrentStatusDisplay.state` is set once from `EmployeeWorkflowEngine.forEngineer`; screen line 69 consumes it; no second derivation, no hand-written status string. `_SkillSheetSalesCard` still labels via `EmployeeWorkflowEngine.labels[workflowState]!` (line 280). |
| Stored `SkillSheet` remains the sales-facing authority, never reconstructed | **PASS** | `EngineerSkillSheetDisplay.sheet` is a direct reference to the `state.skillSheets` entry (test asserts `same(sheet)`); actual skills are carried in separate fields; the null case renders an explicit unavailable card, never a synthesized sheet. `SkillSheet.fromActual` appears only in the test file. |
| No duplicated/reconstructed authority in UI | **PASS with two exceptions** | (a) **D2**, line 150 reads `state.unlockedClientCount` directly instead of the projection's copy. (b) **Pre-existing, unchanged by this PR**: the guided-CTA switch at lines 112-114 still uses `state.proposalForEngineer(engineerId)` — which at `game_state.dart:221-226` returns the *first proposal of any status or step* — to decide and to target the client-interview push, rather than the projection's `clientInterviewApplicationId`. This is the same class of parallel-proposal mismatch that `4df7a50` fixed for the status card; the PR neither introduced nor extended it, but left it inconsistent with the projection it just added. |
| SkillSheet reconstruction mistakes | **NONE FOUND** | No path derives displayed values from `profile.techSkills` / `actualExperienceMonths`; those are only ever shown side-by-side with the stored sheet's values ("実際 … / 記載 …", line 280). |

## 7. Current-main reintegration analysis

### 7.1 CI as it stands on PR HEAD `4df7a50` (run `33193787247`)

| Check | Result |
|---|---|
| `validate` (flutter analyze + `flutter test` + release web build + replay unit) | **success** |
| `e2e-chromium` (mobile-chromium) | **failure** — 1 failed, 58 passed |
| `e2e-webkit` (mobile-webkit) | **failure** — 2 failed, 57 passed |
| `build` / `deploy` / `check-latest` / `replay-package` | skipped (gated on e2e) |

`validate` passing is meaningful: the whole Flutter unit + widget suite is green on PR HEAD, so
none of the existing `EngineerDetailScreen` widget tests
(`assignment_acceptance_test.dart`, `first_assignment_mobile_test.dart`,
`sales_04a1_mobile_test.dart`, `guided_flow_consistency_test.dart`,
`founding_progression_ui_test.dart`, `text_quality_widget_test.dart`) regressed.

### 7.2 Root cause of the chromium failure — a real regression, not a flake

Both the initial attempt and retry #1 fail at the identical assertion:

```
e2e/tests/phase-3b1-fit-reason.spec.ts:344
Error: no 面談依頼/面談へ進む appeared within 10 weeks (seed=100001)
       — not a stall/timeout tuning issue, see this file's determinism note
```

Baseline comparison rules out a pre-existing failure:

- main at **exactly this PR's base** `3055ae8` → e2e run `33174883338`: **success**.
- current main `adf1325` → e2e run `33227681873`: **success**.

So the regression is PR #84's.

Mechanism, with line evidence:

1. The spec reaches this point with the engineer **already assigned** — its own comment at
   lines 281-286 says it opens the detail screen to "start a second, parallel sales search (並行営業)
   … A real, always-legal player action **while already assigned**".
2. Therefore `display.currentAssignment != null`, and line 152 renders the **full five-row**
   `_CurrentAssignmentCard` (案件 / 顧客 / 契約期間 / 残り / 月単価) — directly above the
   `面談依頼` section, which is where the `面談へ進む` button lives
   (`engineer_detail_screen.dart:524`).
3. The search for that button uses an **unscrolled** snapshot. `openEngineerDetail`
   (spec lines 178-187) ends with a bare `return snapshotScreen(page);`, and line 328 reads
   `snap.buttons.find(... b.name === PROCEED_TO_INTERVIEW)` from it. No
   `scrollUntilButtonFound` is applied on this path.
4. That same spec file documents why this matters (lines 189-200): "Flutter Web's `SliverList`
   only materializes semantics for children within/near the current viewport, so a fresh route
   mount never has it in the accessibility tree until scrolled into view, confirmed directly
   against the real `ariaSnapshot()` output".
5. PR #84 touches **no** game logic — only a projection, a widget file, and a test. Offer
   generation for seed 100001 is bit-identical to the green baseline. The button therefore
   exists in state; it is no longer inside the initially materialized viewport.

Conclusion: an ~5-row card inserted above a time-sensitive CTA pushed that CTA out of the
initial semantics tree. This is a genuine above-the-fold reachability regression on the PR's own
base, and it is a *player-facing* concern, not merely a test artifact.

Verification caveat: the definitive artefact (`error-context.md` / `test-failed-1.png` in the
uploaded `ses-playwright-results-mobile-chromium`) was not opened for this review. The causal
chain above is established by elimination — clean baselines on both sides, zero game-logic delta,
and the spec's own documented semantics-materialization constraint.

### 7.3 Root cause of the extra webkit failure

`e2e-webkit` additionally fails
`beginner-mode-waiting-and-recruitment.spec.ts:493` (`TimeoutError` waiting for
`getByRole('button', { name: /未面接/ })`) — a recruitment-screen path that never touches
engineer detail.

`git diff --stat pr84 origin/main -- e2e/` shows PR #84's tree is missing two e2e changes that
current main has:

```
e2e/helpers/artifacts.ts                  | 111 ++++++++++++++++++++++++++++++
e2e/tests/portable-wheel-fallback.spec.ts |  10 +++
```

These are the mobile-WebKit wheel-scroll fallback from PR #81 (`ea0a4f2`), merged **after**
PR #84's base `3055ae8` (13:19 vs 14:35 on 2026-08-28). So this second webkit failure is very
likely a missing-fix artefact of the stale base, resolved by reintegration alone.

### 7.4 What reintegration onto current main changes

The most important semantic drift is in the PR's favour. Current main added the critical-CTA
shell (PR #93):

- `lib/ui/engineers/engineer_list_screen.dart:301` now routes the 社員 tab to
  `EngineerDetailRouteScreen`, not `EngineerDetailScreen`.
- `lib/ui/engineers/engineer_detail_route_screen.dart:39-45` wraps the detail screen in a
  `Scaffold` whose `bottomNavigationBar` is `_InterviewCriticalBar` when a pending interview
  offer exists.
- That bar's primary button is `面談へ進む` (`engineer_detail_route_screen.dart:85`) — the exact
  name the failing assertion looks for — and it is persistently on screen, independent of the
  `ListView`'s scroll position and therefore always in the semantics tree.

`openEngineerDetail` navigates via the 社員 tab, so after reintegration the phase-3b1 lookup at
spec line 328 should find `面談へ進む` in the bottom bar regardless of how far the body content
was pushed down. **This is a strong hypothesis, not a verified result** — it must be confirmed by
an actual chromium + webkit run on the reintegrated branch, with the spec unmodified.

Two residual concerns to carry into that run:

- The bottom-bar mitigation covers only the 社員-list entry point. `home_screen.dart:180` and
  `:218`, and `sales_overview_screen.dart:489`, `:533`, `:628` still push a bare
  `EngineerDetailScreen` with no critical bar. A player arriving from Home or 営業状況 still has
  the extra card between them and the 面談依頼 CTA.
- Phase 3 of the same spec uses `scrollUntilButtonFound(..., maxSteps = 15)` at 500 px/step to
  reach 営業状況 / `Fitの理由を見る`. The new card adds roughly one card-height to that distance.
  7500 px of budget should still be ample, but it is now measurably tighter.

### 7.5 Design-doc alignment

`docs/design/SES_EMPLOYEE-DATA-1_Expansion_Design.md` — added to main at `091313f`, **after**
PR #84's base, and explicitly "Depends on: EMPLOYEE-UI-1A merged and stabilized" — §7 prescribes
exactly this order:

```
1. summary  2. current status  3. SkillSheet/sales  4. current assignment
5. time-sensitive interview/offer/contract actions
```

So the PR's *placement* of 現在の案件 at position 4 is design-conformant, and it should not be
moved below the action sections to appease the E2E. §8 of the same document independently warns
that "off-screen `ListView` children may not exist in the semantics tree until scrolled into view"
and that one must "never assume a button/text below the fold exists in the initial aria snapshot"
and "not increase retries or arbitrary sleep merely because the screen grows". The correct
resolution is therefore the current-main critical-CTA bar, not a layout reshuffle and not a
spec relaxation.

`AGENTS.md` compliance: the PR preserves accounting/save/SelectionFlow/Morale/Trust behaviour
(zero files touched in those areas, §10) and adds no later-roadmap features — no Career History,
no certifications, no employment/payroll model. Conformant.

## 8. Minimal fix list

Ordered. Nothing here weakens phase-3b1 or any other E2E behaviour.

| # | Fix | File / line | Why |
|---|---|---|---|
| **F1** | Merge current `origin/main` (`adf1325`) into `codex/employee-ui-1a-20260828`. The merge is textually clean; do not rebase or force-push. | branch-level | Picks up the critical-CTA bar (§7.4) and the mobile-WebKit wheel fallback (§7.3) — the two changes most likely to turn CI green without touching a spec. **This is the load-bearing fix.** |
| **F2** | Build `_CurrentAssignmentCard` only when the projection has an assignment, e.g. `if (display.currentAssignment != null) ...[ const SizedBox(height:12), _CurrentAssignmentCard(display: display.currentAssignment!), ]`. Keep the widget itself; drop the empty-state branch or leave it unreachable. | `engineer_detail_screen.dart:152` (+ `:282`) | Prior finding #1 / codex `r3883486206`. Removes a redundant, misleading section and reduces above-the-fold pressure for unassigned engineers. Does **not** by itself fix CI (§5). |
| **F3** | Add the missing `const SizedBox(height:12)` after the assignment card so 現在の案件 and 基本情報 do not render flush. | `engineer_detail_screen.dart:152-153` | Defect D1. |
| **F4** | Pass `display.currentStatus.unlockedClientCount` instead of `state.unlockedClientCount`. | `engineer_detail_screen.dart:150` | Defect D2 — closes the last duplicate read path the projection was meant to own. |
| **F5** | Add one widget test: assigned engineer → 現在の案件 renders with the project title; unassigned engineer → `find.text('現在の案件')` is `findsNothing`. | new, `test/ui/…` | Closes the gap that let F2 reach CI (§4.3). |

Explicitly **not** recommended:

- Do **not** move 現在の案件 below the action sections — it contradicts design §7 (§7.5).
- Do **not** modify `e2e/tests/phase-3b1-fit-reason.spec.ts`, add a scroll to
  `openEngineerDetail`, raise `MAX_WEEKS_TO_WAIT_FOR_OFFER`, add retries/sleeps, or skip the test.
  The failure is a real reachability regression; masking it would violate design §8 and the
  spec's own determinism note.
- Do **not** collapse `_CurrentStatusCard`'s assigned detail to remove the duplication noted in
  §5 — that card is the workflow-authority surface and is out of this PR's minimal-fix scope.

## 9. Tests to rerun

Full CI on the reintegrated head. No subset is sufficient, because the blocking evidence is E2E.

1. `flutter analyze` — must stay clean.
2. `flutter test` (full suite, the `validate` job). Specifically re-confirm the
   `EngineerDetailScreen` widget tests, which F2/F3 change the layout of:
   `test/ui/assignment_acceptance_test.dart` (fixed 800×2600 viewport — height-sensitive),
   `test/ui/first_assignment_mobile_test.dart` (360/390 px overflow checks, incl. the
   参画中 / 参画予定 groups), `test/ui/sales_04a1_mobile_test.dart`,
   `test/ui/guided_flow_consistency_test.dart`, `test/ui/founding_progression_ui_test.dart`,
   `test/ui/parallel_sales_ux_test.dart`, `test/ui/text_quality_widget_test.dart`,
   `test/ui/engineer_list_screen_test.dart`.
3. New `test/presentation/engineers/engineer_detail_display_data_test.dart` (6 tests) + F5.
4. `npm run test:replay-unit` (replay unit tests in the `validate` job).
5. **`e2e-chromium`, full `--project=mobile-chromium`** — `phase-3b1-fit-reason.spec.ts` seed
   100001 must pass **with the spec unmodified**. This is the gate.
6. **`e2e-webkit`, full `--project=mobile-webkit`** — both `phase-3b1-fit-reason.spec.ts` and
   `beginner-mode-waiting-and-recruitment.spec.ts:493` must pass.
7. Do not judge on a single green run of a previously-red spec if it required a retry: the
   chromium failure was deterministic across attempt + retry, so a *clean* first-attempt pass is
   the expected signal after F1.

## 10. Files that must NOT change

Confirmed unchanged in the PR (`git diff --stat` = 3 files) and required to stay that way:

- **E2E / workflows**: `e2e/tests/phase-3b1-fit-reason.spec.ts` (especially
  `openEngineerDetail`, `scrollUntilButtonFound`, `MAX_WEEKS_TO_WAIT_FOR_OFFER`, retries,
  timeouts), all other `e2e/tests/**`, `e2e/helpers/**`, `playwright.config.*`,
  `.github/workflows/**`.
- **Critical CTA placement**: `lib/ui/engineers/engineer_detail_route_screen.dart`,
  `lib/ui/engineers/engineer_list_screen.dart`.
- **Domain / engines / save**: `lib/domain/**`, `lib/game/models/game_state.dart`,
  `lib/game/engine/employee_workflow_engine.dart`, `lib/game/engine/matching_engine.dart`,
  `lib/game/engine/progression_engine.dart`, `lib/game/engine/payroll_engine.dart`,
  everything else under `lib/game/engine/**`, and any save-schema/serialization code.
- **Out-of-domain UI**: `lib/ui/home/**`, `lib/presentation/home/**`,
  `lib/ui/public_demo/**`, `lib/presentation/build_info.dart`, Navigator/SelectionFlow screens.
- **Morale / trust / finance / payroll** logic anywhere.
- No Career History, Employment, Payroll or Public Demo domain work — those belong to
  EMPLOYEE-DATA-1A/1B and PAYROLL-1B per their design docs.

## 11. Risk classification

**Overall: MEDIUM.**

| Dimension | Rating | Basis |
|---|---|---|
| Merge risk | **Low** | Clean automatic merge, 3 files, no shared file with the 26 intervening commits. |
| Domain / save / accounting risk | **Very low** | Zero domain, engine, or serialization lines touched. `validate` green. |
| Authority-boundary risk | **Low** | Both authorities verified intact (§6); two minor duplicate-read nits, one of them pre-existing. |
| Player-facing UX risk | **Medium** | A redundant empty 現在の案件 card for every unassigned engineer, three duplicated rows for assigned ones, and a missing spacer — all visible, all cheap to fix. |
| Above-the-fold / reachability risk | **Medium-high before F1, low after** | Demonstrated CTA-reachability regression on the PR's base; current main's persistent critical bar is the mitigation, but it does not cover the Home / 営業状況 entry points. |
| CI risk | **Medium** | Currently red on both browsers. The proposed remedy (F1) is a hypothesis that must be proven by an actual run, not asserted. |

## 12. Final decision

## **KEEP WITH SMALL FIXES**

Reasoning:

- The projection itself is well-designed and correctly bounded: `EmployeeWorkflowEngine` stays the
  single current-status authority, the stored `SkillSheet` is never reconstructed, and the PR
  actually **removes** a latent `StateError` crash path (`GameState.skillSheetFor`'s bare
  `firstWhere`, `game_state.dart:208`) for legacy saves. That is real value worth keeping.
- The scope is exactly as declared: 3 files, no domain/save/engine/E2E/workflow changes. Nothing
  in the diff needs to be unwound.
- Every defect found is small and local: one unconditional widget at line 152, one missing
  `SizedBox`, one duplicate `unlockedClientCount` read, one missing widget test.
- The branch is 26 commits behind but merges cleanly, and the intervening work — the critical-CTA
  bottom bar and the WebKit wheel fallback — is precisely what the PR's failing CI needs. The
  reintegration is the fix, not a chore performed around it.
- A rebuild would discard a sound 202-line projection and 251 lines of correct tests to re-derive
  the same design; close-supersede would lose the `4df7a50` parallel-proposal fix that already
  resolved a review thread. Neither is justified by anything found here.

Merge condition — all of the following, none optional:

1. F1 applied (current main merged in), then F2-F5.
2. `validate` green.
3. `e2e-chromium` **and** `e2e-webkit` green, with `phase-3b1-fit-reason.spec.ts` passing on an
   **unmodified** spec and without added retries, sleeps, or skips.
4. If phase-3b1 is still red after F1, the PR reverts to **REBUILD ON CURRENT MAIN** — because
   that outcome would mean the extra section is unreachable-by-construction on entry points the
   critical bar does not cover, and the section's placement is fixed by design §7. Relaxing the
   E2E is not an available answer at that point.
