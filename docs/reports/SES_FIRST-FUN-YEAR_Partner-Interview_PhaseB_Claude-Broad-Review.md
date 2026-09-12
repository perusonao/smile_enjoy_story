# SES FIRST-FUN-YEAR Partner Interview Phase B — Claude Independent Broad Review

**Target PR:** #247 (Issue #245 Phase B1+B2, Partner Interview interactive mini-game)
**Reviewer:** Claude Code, independent Broad Review (Codex broad review was requested twice but never ran due to usage limit — no Codex findings exist for this PR)
**Method:** `git fetch origin` then explicit SHA verification — repository default branch was not trusted; `origin/main` and the PR head were both re-resolved directly from the remote.

---

## 0. Explicit SHA / PR state (as fetched, before any local work)

| Item | Value |
|---|---|
| `origin/main` HEAD (latest, includes #249) | `01829f30f00fc7e923bacd355c4e4ffca131cc4e` |
| PR #247 base SHA (at PR creation) | `0b90d556b74746c2f82ac0e9111a95e93bd564b6` |
| PR #247 HEAD SHA (reviewed) | `bff360177bda7af825e7f555f31f6a3f71f0a7d4` |
| PR base branch | `main` |
| `mergeable_state` (GitHub API) | `clean` |
| CI on PR HEAD | all 9 check runs green (`validate`, `replay-unit`, `smoke-e2e`, `Public Demo only`, `Build Public Demo browser preview`, plus 4 skipped deploy/build/replay-package/check-latest jobs not applicable to a PR) |
| Final PR HEAD SHA (after this review) | `bff360177bda7af825e7f555f31f6a3f71f0a7d4` (unchanged — no code fix commits were needed; see §7) |

PR #247 was branched from an older `main` (`0b90d556…`) than the current tip. `git merge-base origin/main origin/claude/ses-partner-interview-phase-b-dz4g42` confirms `0b90d556…` is exactly that base — i.e. PR #247 predates PR #249 (`Issue #248: Applicant→Engineer Data Preservation`, merged into `main` after PR #247 was opened). This review therefore explicitly re-verified PR #247's HEAD against the **current** `origin/main`, not just against its own stale base.

---

## 1. #249 integration check (explicit — required by this review's scope)

`git diff --stat` between the merge-base and current `origin/main` shows #249 touched 12 files. Of those, exactly two overlap with PR #247's 23 changed files:

- `lib/game/public_demo/public_demo_aggregate.dart`
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`

A local test merge (`git merge --no-ff --no-commit origin/main` onto the PR #247 branch) was performed to verify this explicitly rather than trusting GitHub's `mergeable_state` alone:

- **Result: automatic merge succeeded with zero conflict markers** in both files. #249's hunk (recruitment candidate generator wiring, lines ~1312/1516 of `public_demo_aggregate.dart`) and #247's hunk (new `startPartnerInterview`/`concludePartnerInterview` methods appended near line 801) are in disjoint regions of the file. Same for the placeholder screen: #249 added a résumé compensation `Text` row at line ~3873; #247's changes are around lines 1714–3919 (interview entry points/buttons) and do not touch that row.
- The merged working tree was inspected directly: the compensation-row `Key('public-demo-applicant-card-compensation-*')` from #249 **and** `_startPartnerInterview`/`startPartnerInterview`/`concludePartnerInterview` from #247 are both present, with no duplicated/reverted text.
- `flutter analyze`, `flutter test test/game/public_demo` (889/889 passed), and `flutter test test/ui/public_demo` (698/698 passed) were all run **on this merged tree** (PR #247 HEAD + current `origin/main`), not just on PR #247's own stale base. All green. See §6.
- PR #247 does not touch `public_demo_engineer_runtime.dart` or `public_demo_recruitment_candidate_generator.dart` at all — the two files #249's Applicant→Engineer Data Preservation work lives in are entirely untouched by this PR, so there is no risk of PR #247 rewinding that work.

**Conclusion: no conflict, no semantic regression, no rewind of #249's Applicant/Engineer preservation work.**

---

## 2. Findings

No P0 or P1 findings. No P2 findings requiring a fix under this review's blocking criteria (progression/save/authority/data-integrity or a direct product requirement). Two P3 (non-blocking, informational) observations are noted for completeness.

| # | Severity | Area | Summary |
|---|---|---|---|
| — | — | — | **No P0/P1 found.** |
| P3-1 | P3 | style | `PublicDemoInterviewResultDialog.score` is now `int?`, kept non-null-safe only by convention (no assertion) for the one remaining legacy caller (`ei()` fallback path). Purely defensive; not a defect. |
| P3-2 | P3 | docs | The pre-existing `docs/reports/SES_FIRST-FUN-YEAR_Partner-Interview_PhaseB_Result.md` (authored by the PR itself) references only the PR's own stale base SHA `0b90d556…`, not the current `main` tip; this Claude-Broad-Review report supersedes it for main-compatibility purposes. |

Neither P3 blocks merge. No fixes were applied to `lib/` or `test/` — the PR's own code is unchanged by this review.

### 2.1 Detailed verification against each requested review point

**(1) Partner Interview state transition**
- Starting (`PublicDemoAggregate.startPartnerInterview`) only ever creates/resumes a `ClientInterviewSession`; it never calls `applyPartnerProjectInterviewResult` or otherwise commits pass/fail. Verified by reading `public_demo_aggregate.dart:806-850`.
- The only production call site that commits a pass/fail is `PublicDemoAggregate.concludePartnerInterview` → `PublicDemoWorkflowState.concludePartnerProjectInterview`, which requires `PublicDemoProjectInterview.isReadyToConclude(session)` (every question has a player-chosen follow-up) as a precondition — verified in `public_demo_workflow_state.dart:1607-1645`.
- In the UI (`public_demo_project_interview_dialog.dart`), `_conclude()` is invoked automatically inside `build()` **only** once `!session.completed && isReadyToConclude(session)` — i.e. only after every question has been answered. The `[X]` close button and the Android back gesture both call only `Navigator.of(context).pop()` — no commit path. Verified by reading the widget and by the new UI tests (`public_demo_partner_interview_dialog_test.dart:151-282`) which explicitly assert engineer stage/session state are byte-identical before and after an `[X]` close, an `handlePopRoute()` (Android back), and a double-`[X]`-tap.
- Reopening after a dismiss resumes the same session (same `session.id`, `completed: false`) rather than starting fresh — verified in the same test file (lines 196-215) and in the domain test `public_demo_partner_interview_test.dart:113` ("resuming does not restart an in-progress session").

**(2) Atomicity / duplicate**
- Double tap / duplicate conclude: `concludePartnerProjectInterview` returns `this` unchanged if `session.completed` is already true (no-op) — `public_demo_workflow_state.dart:1607-1613`. Domain test: "concluding twice in a row is safe" (`public_demo_partner_interview_test.dart:375`). UI test: "double-tapping the [X] close button in quick succession never double-pops or double-commits" (`public_demo_partner_interview_dialog_test.dart:251`).
- Retry: `startProjectInterviewSession`'s existing "at most one incomplete session per employeeId" rule (`public_demo_workflow_state.dart:1449-1456`) is reused unchanged for the partner leg — a genuine resume returns the identical `PublicDemoWorkflowState` instance, detected via `identical()` in `startPartnerInterview` (`public_demo_aggregate.dart:843-849`), which is exactly what gates the sales-slot charge (see §2.2 below).
- Stale state: `concludePartnerProjectInterview` also requires `session.projectId == project.id` and `session.startedWeek == currentMonth`, mirroring the existing Codex P1/P2 (PR #214) defense-in-depth already proven for the client leg — a session from a stale month or a since-replaced proposal can never be concluded. Domain test: "a partner session started in one month is discarded... once the month has advanced" (`public_demo_partner_interview_test.dart:256`).

**(3) Sales capacity**
- New-session-only charge: `startPartnerInterview` calls `state.useSalesSlot()` only when `workflow.startProjectInterviewSession(session)` actually produced a **new** `PublicDemoWorkflowState` (i.e. `!identical(nextWorkflow, workflow)`); a genuine resume leaves `workflow` `identical` and is never charged again. Verified in code (`public_demo_aggregate.dart:827-849`) and in the domain test "consumes exactly one real sales slot on a genuinely new attempt... never on resume" (`public_demo_partner_interview_test.dart:123`).
- Zero-slot no-op: `startPartnerInterview` returns `this` unchanged if `state.fiscalYearCompleted || state.salesRemaining <= 0`, before any session/slot mutation — verified in code and by the domain test "never starts (and never spends a slot) once salesRemaining is [exhausted]" (`public_demo_partner_interview_test.dart:137`).
- This exactly mirrors the pre-existing (pre-B2) generic partner-interview path's own budget contract (`recordEngineerInterviewResult`, `public_demo_aggregate.dart:648-669`), so no new or second slot budget was introduced — B2 only makes an already-charged action interactive.
- The client leg (`startProjectInterview`, reused unchanged from Phase 6) remains a 0-slot step at `partnerInterviewPassed`, exactly as before — confirmed unaffected by reading `public_demo_aggregate.dart:706-730` (no `useSalesSlot` call) and by the (untouched-by-this-PR, still passing) existing Phase 6 test "sales-slot behavior (0-slot, no double consumption)" in `public_demo_project_interview_test.dart`.

**(4) Save / Reload**
- No new enum value and no new persisted field were introduced: `PublicDemoSalesStage` (`public_demo_sales.dart:4-14`) already contained `partnerInterviewFailed`/`partnerInterviewPassed` before this PR; the partner leg reuses the pre-existing `projectInterviewSessions` list and `ClientInterviewSession` shape verbatim — confirmed by grepping the PR diff for enum/schema changes (none found beyond doc comments).
- Domain tests explicitly cover: an in-progress partner session round-tripping through `toJson`/`fromJson` (`public_demo_partner_interview_test.dart:283`), a completed pass and a completed fail each round-tripping (`:302`, `:320`), and legacy-save compatibility is inherited for free from the unmodified `projectInterviewSessions` codec (already proven by the pre-existing Phase 6 persistence tests in `public_demo_project_interview_test.dart`, which still pass unmodified).
- Mid-interview save/reload and conclude-then-reload are exercised by both the new domain tests above and by the UI dialog's own resume-after-dismiss behavior (§2.1 (1)).

**(5) Progression (introduced → partnerInterviewPassed/Failed → clientInterviewPassed/Failed → ordered → assignment)**
- `applyPartnerProjectInterviewResult` requires `stage == introduced` and transitions only to `partnerInterviewPassed`/`partnerInterviewFailed` (`public_demo_sales.dart:346-381`) — it deliberately never mints `interviewRecord` (the unforgeable proof `assignOrderedForMay` gates assignment eligibility on), exactly mirroring the pre-existing generic partner branch's contract. Grepping the full PR diff confirms `assignOrderedForMay` and `hasGenuineInterviewRecord` are never touched by this PR — only referenced in new doc comments and new tests.
- `ordered != assigned` is explicitly exercised end-to-end in the new domain test "end-to-end: introduced → partner pass → client pass → order → assignOrderedForMay produces a genuine assignment..." (`public_demo_partner_interview_test.dart:207-249`), which asserts `stage == ordered` after `recordOrder`, then drives the **real** production `closeApril()` (which internally calls `assignOrderedForMay`) and only then asserts a real `PublicDemoAssignment` exists — never a direct/shortcut workflow-level call.
- The existing golden-path UI test (`public_demo_01_success_playthrough_test.dart`) was updated to genuinely play both the partner and client interactive mini-games (previously the partner leg used a one-tap generic dismiss) and still reaches `受注` (order) successfully — strengthening, not weakening, this coverage.

**(6) Existing authority reuse**
- `ClientInterviewEngine`/`ProjectInterviewEngine` (question generation, follow-up evaluation, final roll) are not modified at all by this PR.
- `PublicDemoProjectInterview.start`/`chooseFollowUp`/`conclude`/`isReadyToConclude`/`failureReasons` (the existing Phase 6 adapter) are called identically by both legs; no new formula was added.
- `ClientInterviewSession` and `PublicDemoWorkflowState.projectInterviewSessions` are the same list/shape for both legs — no new list, no new JSON key.
- `PublicDemoProjectInterviewDialog` is the same widget, parameterized by a new `type` (`client`/`partner`) enum value used purely for label/key-prefix selection and to pick which pair of `start*`/`conclude*` aggregate methods to call — not a second dialog implementation.
- No new/second authority was found. The four new domain methods (`applyPartnerProjectInterviewResult`, `concludePartnerProjectInterview`, `startPartnerInterview`, `concludePartnerInterview`) are thin, one-stage-earlier mirrors of existing methods, each with its own no-op guard, and each verified above.

**(7) #249 integration** — see §1 above (dedicated section).

**(8) Scope** — Parallel Sales, Trade Flow, and the pre-entry applicant/replacement-interview pipeline are untouched by this PR (confirmed: PR #247's 23 changed files do not include any file under the pre-entry applicant pipeline beyond the shared `PublicDemoInterviewResultDialog.score` optionality change, which is backward compatible — see §2.1 note on P3-1). No new regression in these areas was found.

---

## 3. Fixes applied in this review

**None.** No P0/P1 findings and no blocking P2 findings were identified; no changes were made to `lib/` or `test/`. This report itself is the only file added by this review, committed directly to PR #247's branch as requested.

---

## 4. Tests (run on PR #247 HEAD `bff3601` merged with current `origin/main` `01829f3`)

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found!** (18.0s) |
| `flutter test test/game/public_demo` | **889/889 passed** |
| `flutter test test/ui/public_demo` | **698/698 passed** |
| `git diff --check` (PR #247 diff vs. `origin/main`) | clean, no whitespace errors |

(An initial `flutter test test/ui/public_demo` run was invalidated mid-run by the reviewer's own local `git checkout` to a different branch changing files on disk under the running test process — this produced spurious "did not complete" errors unrelated to the PR's code. The suite was re-run cleanly end-to-end with no git operations during the run, producing the 698/698 all-green result recorded above.)

CI on the PR's actual HEAD (`bff3601`, against the PR's original base) was independently confirmed green via the GitHub API before any local verification: `validate`, `replay-unit`, `smoke-e2e`, `Public Demo only`, and `Build Public Demo browser preview` all `success`.

---

## 5. Unresolved items

None outstanding. The two P3 observations (§2) are informational only and not tracked as follow-up work.

---

## 6. VERDICT

**VERDICT: READY**

PR #247 correctly reuses existing Phase 6 authority (`ClientInterviewEngine`/`ProjectInterviewEngine`/`ClientInterviewSession`/`projectInterviewSessions`) to make the Partner Interview genuinely interactive, introduces no new save schema, correctly preserves the existing sales-slot budget contract (charge once per genuinely new attempt, never on resume, never at zero remaining), never commits a result on dismiss (X/back), never double-commits, and does not regress the `ordered != assigned` First Fun Year progression. It merges cleanly with the current `origin/main` (post-#249) with no file-level conflicts and no semantic overlap with the Applicant→Engineer Data Preservation work from #249, which this PR does not touch. `flutter analyze`, the full `test/game/public_demo` suite, and the full `test/ui/public_demo` suite all pass on PR #247's HEAD merged with the current `origin/main`.

Per the task instructions, MERGE is left to be performed separately after an exact-head confirmation.

---

*Generated by an independent Claude Code Broad Review session (Codex broad review could not run twice due to usage limits; no Codex findings exist for this PR).*
