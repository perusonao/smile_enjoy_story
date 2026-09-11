# SES FIRST-FUN-YEAR P1: Project / Order / Assignment Continuous Visibility — Fresh Audit

GitHub Issue #239. Read-only audit, performed at `origin/main`
`4a19b27daa93f53b7888e721b7c8e9486d5b95c1` (post PR #238 merge; Fast CI #632
SUCCESS on this SHA, confirmed via `git fetch origin main` before any other
work).

## 1. Scope

Trace the normal-play authority/UI for:

`Project Candidate → Matching/Proposal → Partner Interview → Client
Interview → Ordered → Next-month Assignment → Active Assignment →
End/Renewal/Available`

and identify exact comprehension gaps/contradictions, never proposing a new
lifecycle state machine or domain/save change.

## 2. Lifecycle authority map (unchanged by this Issue)

| Stage | Authoritative source | Reachable only via |
|---|---|---|
| Project candidate | `PublicDemoSeededProjectGenerator.forMonth`/`.regenerate` (`public_demo_project_generator.dart`) — pure `(runSeed, month, slot)` derivation, nothing persisted | `PublicDemoAggregate.projectCandidatesForMonth` |
| Matching proposal | `PublicDemoMatchingProposal` (engineerId, projectId, decidedMonth) — at most one per engineer | `PublicDemoWorkflowState.withMatchingProposal` (a no-op once `clientInterviewPassed`/`ordered` — Codex P1-2, PR #214) |
| Partner interview | `PublicDemoEngineerSales.stage` (`introduced` → `partnerInterviewPassed`/`Failed`) | `PublicDemoEngineerSales.evaluateInterview`, called only via `PublicDemoWorkflowState.recordEngineerInterviewResult` ← `PublicDemoAggregate.recordEngineerInterviewResult` |
| Client interview (project-bound, Phase 6) | `PublicDemoEngineerSales.stage` (`clientInterviewPassed`/`Failed`) + `PublicDemoEngineerInterviewRecord.projectId` (non-null only for a genuine Phase 6 pass) | `PublicDemoEngineerSales.applyProjectInterviewResult` ← `PublicDemoWorkflowState.concludeProjectInterview` ← `PublicDemoAggregate.concludeProjectInterview` |
| Ordered | `PublicDemoEngineerSales.stage == ordered` | `PublicDemoWorkflowState.recordOrder` (requires `clientInterviewPassed`) |
| Assignment materialization | `PublicDemoAssignment` in `PublicDemoWorkflowState.assignments` | `assignOrderedForMay` (April close, Issue #227) / `recoverLateYearAssignment` (RECOVERY-LOOP-1, July–February) / `appendPreEntryOrderAssignments` (pre-entry hires) — all gated on `hasGenuineInterviewRecord`, never `stage` alone |
| Active/assigned | `PublicDemoWorkflowState.assignedEngineerIds(month:)` | Through June: `assignedEngineerIdsUnfiltered` (every roster entry). July on: only `nextOrderStatus == accepted \|\| replacementStage == ordered` |
| End/renewal/available | `PublicDemoAssignment.nextOrderStatus`/`replacementStage` + `PublicDemoWorkflowState.endAssignment` | End requires `notOffered` + `replacementStage != ordered` + engineer genuinely `ordered`; releases the engineer back to `waiting` via `releaseFromAssignment` |

Confirmed: engineer identity (`engineerId`) and project identity
(`projectId`, when genuine) are carried unforgeably end-to-end —
`PublicDemoEngineerInterviewRecord.engineerId`/`.projectId` →
`PublicDemoAssignment.projectId` → `PublicDemoSeededProjectGenerator
.regenerate(runSeed, projectId)` — the same triad `_currentUnitPriceDisplayFor`
(PR #236) and `PublicDemoAggregate._careerHistoryEntryFor` (Phase 7B) already
resolve independently. No new domain/save authority is required for this
Issue: every fact this Issue needs to show already exists.

## 3. Player-facing visibility map (before this change)

| Surface | What it already showed |
|---|---|
| 社員 roster row (`_employeeRosterCard`) | Unified status badge (`PublicDemoEmployeeStatusResolver`, #238: 研修が必要/営業可能/営業中/参画予定/参画中/待機) + 経験/月給/単金 (単金 real-project-backed for 参画中 only, PR #236) |
| 社員 Section 2 action card (`ec(i)`) | Raw 9-stage `PublicDemoSalesProgress` stepper + the one actionable button for the current stage — **no project identity at all** |
| 社員 Section 3 (`activeProjectStatusCard`) | name/`projectName`/deliveryPressure/budgetHealth for a currently-assigned engineer — `projectName` was always `PublicDemoAssignment.projectName`'s own field verbatim |
| 営業 Matching screen | Full project/fit/proposal detail — but only while that screen itself is open |
| 営業 June assignment-decision card (`assignmentCard`) | `a.projectName` verbatim, next-order/replacement stage buttons |
| 営業 July result row | 継続/切替 badge only, no project name |
| SkillSheet | Raw stage label (via the same 9-stage switch), no current-project line |
| Monthly Report | 参画/待機 headcounts only (already sourced from the same authority, no separate lifecycle judgment) |

## 4. Confirmed comprehension gaps

1. **No project identity while proposing/interviewing.** From the moment a
   player leaves the Matching screen (or `案件紹介`'s own auto-pick fallback
   fires — Issue #219), there is no surface anywhere that states which real
   project an `introduced`/`partnerInterviewPassed`/`clientInterviewPassed`
   engineer is actually pursuing, even though a real `projectId` already
   exists on either `PublicDemoMatchingProposal` or the engineer's own
   `PublicDemoEngineerInterviewRecord`. The player must reopen Matching (which
   itself does not indicate an in-progress interview state) to be reminded.
2. **Generic placeholder name shown instead of the real project title once
   ordered/assigned.** `PublicDemoAssignment.forOrderedEngineer` always sets
   `projectName: '新規開発支援'`, **even when a genuine `projectId` is attached**
   (a real Phase 6 pass). `activeProjectStatusCard` and the June
   `assignmentCard` both rendered this literal field — so a player who
   genuinely won a real, seeded "ECサイト追加開発" project for a real client
   still saw the generic template name on every card, while the roster's own
   単金 (PR #236) and Career History (Phase 7B's `_careerHistoryEntryFor`)
   already resolved and showed the *real* title/rate for the exact same
   assignment. This is the "同じ事実を複数UIが異なる文言で表示" case the Issue's
   Fresh Audit checklist calls out.
3. **参画予定 (ordered, not yet assigned) has no project context at all** on
   the roster row — only the status badge. The 単金 field intentionally stays
   `—` at this stage (correct: not yet earning), but nothing else states
   *which* project was won.
4. Pre-entry (applicant) sales pipeline (`preEntrySkillSheet` →
   `preEntryClientPassed` → `juneOrdered`) has **no real project-matching
   authority at all** — no Phase 4/5/6 project is ever attached to an
   applicant's pre-join sales flow. This is an existing, intentional
   authority gap (no `PublicDemoMatchingProposal` equivalent exists for
   applicants), not something this Issue's slice can or should fabricate a
   project identity for.

## 5. Non-issues / things already correct (verified, not re-derived)

- `PublicDemoEmployeeStatusResolver` (#238) already gives one, non-duplicated
  参画予定/参画中/営業中/待機/研修が必要/営業可能 taxonomy shared by roster and
  SkillSheet — unaffected by this Issue, reused as-is.
- `assignOrderedForMay`/`recoverLateYearAssignment`'s `ordered != assigned`
  distinction, `assignedEngineerIds`'s month-7 filter switch, and
  `endAssignment`'s pre-July "row kept" behavior are all correct and
  unchanged by this slice — this Issue only adds read-only project-identity
  *text*, never a new eligibility/materialization rule.
- `_currentUnitPriceDisplayFor` (PR #236)'s "assigned-only" gate for 単金 is
  intentional (revenue != a not-yet-earned rate) and is preserved verbatim;
  this Issue's new roster segment explicitly avoids duplicating that number
  when it is already shown.
- HOME's own `_officeStageStatusFor` is untouched (HOME Freeze) — its
  existing 参画中/翌月参画予定 text already reads the same underlying
  `stage == ordered && isCurrentlyAssigned` fact this Issue's resolver also
  reads, so no new cross-surface contradiction is introduced by this slice.

## 6. Smallest safe implementation slice

A single pure resolver (mirroring `PublicDemoEmployeeStatusResolver`'s own
convention exactly) that decides, for one engineer right now:

- **which** of the three already-existing project-id sources
  (`PublicDemoAssignment.projectId` > `PublicDemoEngineerSales
  .genuineInterviewProjectId` > `PublicDemoMatchingProposal.projectId`,
  read in that priority) is authoritative for their current stage, and
- **which** stage-appropriate label (提案中の案件/受注案件/参画中案件) to show it
  under,

then reusing the exact same `project?.title ?? assignment.projectName`
resolution `PublicDemoAggregate._careerHistoryEntryFor` already established,
wired into four existing render sites:

1. Section 2 sales-pipeline card (`ec(i)`) — new project-context line under
   the existing stepper, for every stage `introduced` through `ordered`.
2. Section 1 roster row (`_employeeRosterCard`) — one minimal addition
   (title, plus rate only when 単金 does not already show it) for `ordered`
   only (参画予定/参画中), per the Issue's own UX direction.
3. `activeProjectStatusCard` — real title instead of the generic
   placeholder, when resolvable.
4. `assignmentCard` (June's decision card) — same real-title fix.

No new domain field, enum, or persisted value; no change to any
eligibility/materialization rule; no HOME file touched.

## 7. Expected changed files

- New: `lib/ui/public_demo/public_demo_project_context.dart` (display value
  object)
- New: `lib/ui/public_demo/public_demo_project_context_resolver.dart` (pure
  resolver)
- New: `test/ui/public_demo/public_demo_project_context_resolver_test.dart`
- Modified: `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
  (four render sites + two small helpers, all additive)

## 8. Save/domain impact

None. Every field read (`PublicDemoAssignment.projectId`,
`PublicDemoEngineerSales.genuineInterviewProjectId`,
`PublicDemoMatchingProposal.projectId`) is already persisted and already
validated by `PublicDemoSaveCodec`. No schema change, no new authority.

## 9. Mobile layout impact

New/changed `Text` widgets use `overflow: TextOverflow.ellipsis` (matching
this file's existing convention); the roster's compensation line already
wraps its whole joined string in `overflow: TextOverflow.ellipsis`. Project
titles/client names in this codebase's own generators are short
(`titleTemplatesByProjectType`, `sampleClients`), consistent with the
existing generic placeholder's own length. Verified at 360×800/390×844,
TextScaler 1.0/1.3 (see Result Report §Verification).

## 10. Test matrix (executed as focused verification, see Result Report)

- Fresh April: proposal → interviews → ordered — project context appears
  and stays identity-consistent at each stage.
- Ordered-not-assigned = 参画予定 + correct project context (title + rate).
- Next-month assigned = 参画中 + same project identity/context.
- Failed interview returns safely, no stale project context lingers.
- Assignment end/renewal/available.
- Founding engineer + recruited engineer.
- Save/reload at proposal/interview/ordered/assigned boundary.
- Legacy/generic (`projectId == null`) path still falls back to the
  existing generic placeholder/dash, never fabricates a project.
- 360×800/390×844, TextScaler 1.0/1.3, no overflow.
- Full existing `test/ui/public_demo/` + `test/game/public_demo/` suites
  green (regression).

## 11. Verdict

**GO.** No domain/schema change needed; every fact required already exists
and is already independently resolved elsewhere in the codebase (単金,
Career History) — this Issue's slice is purely wiring the same, already-
validated resolution into three currently-silent presentation surfaces via
one new shared, pure resolver.
