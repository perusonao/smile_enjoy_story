# SES First Fun Year — Next Priorities (2026-09-10)

Status: **Working priority addendum — must be reflected into the governing `SES_DEVELOPMENT-PRIORITY_2026-09-02.md` before PR #230 merge**

This addendum records the latest Human Replay-driven execution order while PR #230 is open. The governing SSOT remains `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`; Claude Code should fold these decisions into that file as part of the existing Codex P1 on PR #230, then this addendum may remain as history or be removed.

## Primary goal

First Fun Year remains the highest priority: April through the following March must be understandable, playable, and worth replaying. New large systems, 1-turn=1-week redesign, and Visual Complete work remain behind core-loop comprehension.

## Current execution order

1. **PR #230 / Issue #229 — Opening Context Package A** — finish Codex P1 plan update, CI, merge. Outcome: first-time player understands purpose, starting cash, monthly baseline cost, and bankruptcy risk before April play.
2. **Initial Employee + SkillSheet Clarity Package B** — P1, estimated 1.5–2.5h. Explain that the initial sales-ready employee can act now while the other needs training; clarify why SkillSheet matters; review the Public Demo tutorial-only hard gate. Do not redesign Employee UI or add SkillSheet editing in this package.
3. **Monthly Hiyori Management Report** — P1, estimated 2–4h. At month end, before entering the next month, Hiyori summarizes authoritative Finance, cash before/after, recruitment/join state, sales/order/next-month assignment, active/waiting employees, and one concise next-month observation. Presentation/read-only layer only; no duplicate business authority.
4. ~~**Employee lifecycle status clarity**~~ — **Done (2026-09-11, PR #238, incl. same-day review follow-up).** Make waiting → sales-ready/in-sales → interview → ordered → next-month assignment → assigned understandable and consistent **between the 社員タブ roster and SkillSheet**. Implemented as `PublicDemoEmployeeStatusResolver` (a single pure resolver shared by both), producing the exact six-value taxonomy Fresh Audit §4 specifies: 研修が必要/営業可能/**営業中**(collapsing all six sales-pipeline sub-stages)/**参画予定**(ordered, not yet assigned)/参画中/待機. Fixed the two inconsistencies the Fresh Audit found (SkillSheet stale 翌月参画予定 for an already-assigned engineer; training-selection overriding an otherwise-correct label's tone), one related label/tone gap found during implementation, and one PR-review follow-up (the first version still fell back to the raw, un-collapsed `engineerStatus` label for every pipeline sub-stage and for ordered-not-assigned). **HOME's own `_officeStageStatusFor` remains intentionally outside this resolver (HOME Freeze) and still shows the raw, un-collapsed `engineerStatus` wording** (待機 for every not-yet-ready-or-ready waiting engineer, 翌月参画予定/営業準備/案件紹介済/etc. for the pipeline) — this is a known, tracked cross-surface **wording** gap, not a fact disagreement (both sides key off the same `stage`/`assignedEngineerIds` authority and never contradict each other on *what is actually true*, only on how it is *worded*). Routing HOME through the shared resolver remains an explicit, ready-to-do follow-up once HOME Freeze is lifted or a behavior-preserving internal refactor is confirmed acceptable — see the governing plan's 2026-09-11 Update history entries and `docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Result.md` for the full rationale and test evidence.
5. **Project/order/assignment continuity** — P1, estimated 2–4h. Preserve and expose project identity/status so the player can answer “what happened to last month’s project?” without inference.
6. **Recruitment lifecycle + next action clarity** — P1, estimated 2–3h. Make applicant → interview → candidate/offer → joining schedule and the next required action legible.
7. **Month-start situation / recommended action** — P1, estimated 1.5–3h. Surface important joins, assignment starts/ends, risks, and one prioritized management cue without changing gameplay authority.
8. **April→March Human Replay #225 restart** — 1–2h after the above P1 comprehension loop is integrated. Judge completion, decision clarity, boredom, bankruptcy anticipation, and replay desire.
9. **Success feedback** — P2, estimated 1.5–2.5h. First order, first assignment, first profitable month, etc.
10. **Late-game/monthly themes #167 re-evaluation** — P2, 3–6h+ split as needed, based on fresh Human Replay rather than stale assumptions.
11. **HOME information re-evaluation** — P2, 2–4h, only from Human Replay evidence; HOME Freeze remains unless a new P1 usability finding justifies reopening it.
12. **Visual Complete 2** — P2, 3–6h+ after core comprehension is stable.
13. **1 turn = 1 week / new management systems** — P3 / large redesign, only after First Fun Year core loop is signed off.

## Monthly management report design direction

The month-end report should close the management loop as:

**month start → management decisions → authoritative state changes → month close → Hiyori report → next-month cue → next month**.

The report should explain cause and effect, not merely dump numbers. It must read existing authorities rather than recalculate or persist a competing truth. Minimum useful sections are:

- Finance: revenue, payroll/major expenses, net result, cash before → after.
- Recruitment: applicants/interviews/decisions and scheduled joins where available.
- Sales/project: proposals/interviews/orders and next-month assignment state.
- Employees: assigned / next-month assignment / waiting states that materially changed.
- One short Hiyori observation that helps the player understand the next decision without revealing a single “correct route”.

## Execution policy

One implementation phase ≒ one PR. Do not combine Package B and Monthly Management Report into the same production PR. Use implementation → self-hardening → focused tests → full verification/CI. One broad Codex review at most; fix P0/P1 and progression/save/authority/data-integrity P2, but issueize low-impact P2/P3 instead of recursively reviewing.

Every implementation task must include recommended AI/model, estimated processing time, milestone progress reports with elapsed time and revised ETA, and a committed + directly downloadable Result Report containing changed files, tests, unresolved items, PR URL, HEAD SHA, and actual processing time.
