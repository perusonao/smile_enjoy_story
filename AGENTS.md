# S.E.S. Agent Instructions

## Required reading before work

Before starting any implementation, debugging, refactoring, UI change, or test change in this repository, read:

- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — current governing priority/process plan
- `docs/DEVELOPMENT_PLAN.md` — phase/feature plan

Treat these together as the current development source of truth. The priority decision governs **why/what to prioritize now**; the development plan contains the detailed phase/feature sequence.

## Working rules

- Identify the requested task's phase/priority before changing code.
- Optimize work toward the First Fun Year goal: April through the following March should be playable and enjoyable enough to make another strategy/year appealing.
- Prefer implementation tasks sized for roughly 2–3 hours of Claude Code/Codex processing; split work expected to exceed a 5-hour usage window.
- Prioritize progression correctness and financial correctness over presentation work.
- Do not silently add later-roadmap features while fixing an earlier-phase task.
- Preserve Failure Recovery: negative outcomes must not leave the player in a dead end.
- Preserve accounting/save/SelectionFlow/Morale/Trust behavior unless the requested task explicitly changes it.
- Run the relevant Flutter/unit/replay/Playwright checks after changes.
- Coding-agent prompts should state the minimum recommended model and require a result-report Markdown under `docs/reports/` unless there is a clear reason not to.
- If an explicit user request changes the roadmap, priority, completion status, estimate, or persistent working policy, follow the user request and update the governing plan/document as part of the change.

## AI knowledge base

Before investigating a non-trivial bug or architecture change: read the
development plan, classify the problem, search `docs/ai-knowledge/INDEX.md`,
then load only relevant entries and verify them against current code/tests.
Historical knowledge is never stronger than current code or tests.

After substantial work, record a reusable, evidenced incident/pattern/decision
when appropriate. Do not promote a one-off observation directly to a core rule.

## Current focus

The governing focus is **First Fun Year**. Complete the current HOME/Public Demo
UI work, perform an April-to-March human playthrough, fix only true annual-play
blockers immediately, then choose the next improvement from observed fun/clarity/
feedback gaps rather than mechanically following issue number order.
