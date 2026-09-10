# Claude Code Prompt — FIRST-FUN-YEAR Order→Assignment Fresh Audit

## Recommended AI
Claude Code Sonnet

## Estimated processing time
20–40 minutes. This is READ-ONLY/Fresh Audit first. Do not implement unless the root cause is unambiguous and a minimal P0/P1 fix is required; if so stop and report the proposed fix before production changes.

## Base
Repository: `perusonao/smile_enjoy_story`

1. `git fetch origin`
2. Use latest `origin/main`, never repo default branch.
3. Record exact audited SHA.

Human Replay on Issue #225 reported: **an engineer appeared to have been ordered in the previous month but was not visibly assigned in the next month**, and proposal/order results were hard to understand.

## Goal
Determine whether this is:
A. real progression/state defect,
B. correct state but missing/ambiguous UI visibility,
C. route/authority mismatch where the UI appeared to order a project without a genuine project/matching proposal.

Do not redesign HOME, Sales, Employee or Finance in this audit.

## Reproduce through production commands / normal UI authority
Trace one joined engineer through:
`SkillSheet → selling → project introduction/proposal → partner interview → client interview → order → month close → next-month assignment`.

Test both where relevant:
- genuine Phase5 Matching proposal / projectId path
- legacy/generic path still reachable from current UI/save compatibility

At every transition capture:
- month
- engineerId
- engineer stage
- projectId
- PublicDemoMatchingProposal
- interview record/session/result
- order state / ordered engineer collection
- assignment object and projectId
- revenue eligibility / assignment headcount
- what HOME/Sales/Employee UI actually displays

## Questions that MUST be answered
1. What exact production action means 「受注」 today?
2. Does it mean client issued an order, company accepted it, or both?
3. When should assignment start — immediately or next month?
4. Which close method materializes the assignment for April→May, May→June, June+ ordinary months?
5. Is assignment created exactly once with genuine engineerId/projectId?
6. Does save/reload before and after month close preserve the order→assignment transition?
7. Can UI show an order/result without a genuine projectId?
8. Why can a player perceive “ordered last month, not assigned this month” on current main?
9. Where is previous proposal/interview/order result visible after month transition?
10. Are the Japanese terms `案件紹介 / 案件へ提案 / 発注 / 受注 / 参画` semantically consistent with the actual state machine?

## Required tests / checks
Use existing tests first; add temporary/local diagnostic test only if needed for reproduction. Do not commit diagnostic-only code during audit.

Verify at minimum:
- April order → May assignment
- May order/pre-entry order → June assignment/join behavior where applicable
- ordinary-month order → following-month assignment
- save/reload before close
- save/reload after close
- retry/double-tap/idempotency
- no double assignment/revenue
- genuine projectId retained

Also ensure #220 and #222 authority assumptions remain valid.

## Output verdict
Choose exactly one:
- `A — REAL P0/P1 PROGRESSION DEFECT`
- `B — STATE CORRECT / P1 VISIBILITY-TERMINOLOGY DEFECT`
- `C — ROUTE/AUTHORITY MISMATCH`
- `D — MIXED` (explain each component)

If real P0/P1 defect exists, provide the **smallest safe fix plan**, affected files, tests and estimated implementation time. Do not broaden scope.

## Progress reporting
Report at:
1. main/root-cause trace complete
2. reproduction complete
3. save/reload + boundary verification complete
4. final verdict/report complete

Each report: `Current status / Next action / Actual elapsed time / Revised ETA`.

## Result Report
Create and commit:
`docs/reports/SES_FIRST-FUN-YEAR_Order-Assignment_Fresh-Audit.md`

Include:
- audited SHA
- exact reproduction steps
- state transition table
- UI-visible wording at each step
- root cause
- verdict A/B/C/D
- P0/P1/P2 classification
- minimal fix plan if needed
- tests executed/results
- actual processing time

Push the report and attach/upload it in the final Claude response so it can be downloaded directly. Local path alone is insufficient.

## Final response
Include actual processing time, audited SHA, verdict, blocker/limitations, report file, and whether implementation should start next.
