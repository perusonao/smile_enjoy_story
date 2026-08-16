# S.E.S. Agent Instructions

## Required reading before work

Before starting any implementation, debugging, refactoring, UI change, or test change in this repository, read:

- `docs/DEVELOPMENT_PLAN.md`

Treat it as the current development-priority source of truth.

## Working rules

- Identify the requested task's phase/priority before changing code.
- Prioritize progression correctness and financial correctness over presentation work.
- Do not silently add later-roadmap features while fixing an earlier-phase task.
- Preserve Failure Recovery: negative outcomes must not leave the player in a dead end.
- Preserve accounting/save/SelectionFlow/Morale/Trust behavior unless the requested task explicitly changes it.
- Run the relevant Flutter/unit/replay/Playwright checks after changes.
- If an explicit user request changes the roadmap, follow the user request and update `docs/DEVELOPMENT_PLAN.md` when the change is intended to persist.

## Current focus

Playable 0.4C.2 stabilization and March-to-April accounting correctness are
complete. Phase 3A (April-June Beginner Mode foundation) has shipped —
implemented, unit/widget-tested, and validated with seeded Playwright runs.
Current focus is a human/video UX review of that Phase 3A slice, then Phase
3B (July-September assisted growth decisions).
