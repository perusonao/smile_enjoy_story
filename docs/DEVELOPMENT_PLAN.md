# S.E.S. Development Plan

Last updated: 2026-08-16

This document is the source of truth for near-term development priorities for S.E.S. (Smile. Enjoy. Story.).

## Mandatory startup rule for development agents

Before starting any implementation, debugging, refactoring, UI work, or test work in this repository:

1. Read this file (`docs/DEVELOPMENT_PLAN.md`) first.
2. Confirm which phase and priority the requested work belongs to.
3. Do not silently implement later-phase features while P0/P1 work in an earlier phase remains relevant to the task.
4. Preserve existing accounting, save-data, SelectionFlow, Morale/Trust, Guided Founding, Failure Recovery, and E2E behavior unless the task explicitly changes their specification.
5. After implementation, run the relevant unit/Flutter/Playwright tests and report any deviation from this plan.

If a user instruction explicitly changes the plan, the user instruction wins and this document should be updated as part of the change when appropriate.

---

## Product direction

The immediate goal is not to maximize feature count. The goal is to make the first year of founding an SES company understandable, stable, and playable without dead ends.

Target first complete experience:

**Company setup -> founding/prologue -> first assignment -> cash-flow management -> recruitment -> contract decisions -> year-end -> beginner-mode graduation**

The first-year goal should evolve from merely "get the first assignment" to **"survive the first year of the company."**

---

# Phase 1 — Playable 0.4C.2 stabilization

Priority: **P0 / current work**

Do not add major game systems until this phase is stable.

## 1.1 Company setup defaults

- Pre-fill the president name with a randomly generated Japanese name.
- Pre-fill the company name with a randomly generated plausible company name.
- The player can edit both values before starting.
- Prefer allowing re-roll/regeneration without requiring manual deletion.
- Random defaults must not make E2E tests flaky; tests should not depend on one exact generated name unless a seed is explicitly fixed.

## 1.2 Fix ghost/duplicate rendering during transitions

Observed around the recruitment interview transition: text from the previous screen (for example interview-title text) can remain visually over the next screen.

Required investigation/fix:

- Check stale routes, dialogs, overlays, animations, semantics layers, and widgets during navigation.
- Ensure previous interview views are disposed/removed correctly.
- Verify on mobile Chromium and WebKit/iPhone-equivalent viewport.
- Add regression coverage where practical.

## 1.3 Failure Recovery completion

The game must never dead-end after a negative or declined outcome.

Verify at minimum:

- recruitment rejection
- candidate declining an offer
- client interview failure
- interview/request decline
- assignment offer decline/cancellation where applicable
- transient no-action states during navigation

Expected behavior: reconcile state, restore a valid Primary CTA or explicitly present "no action this week -> next week", and allow the founding flow to continue.

`recruitment-reject` has already demonstrated successful recovery through first assignment; preserve that behavior.

## 1.4 Regression gates

Before considering 0.4C.2 stable:

- Flutter analyze/test/build must pass.
- Replay/unit tests must pass.
- Playwright Chromium and WebKit must pass with retries disabled for the stability suite.
- Failure Recovery scenarios must pass.
- No new console errors.
- No progression regression or stage rollback.

---

# Phase 2 — March-to-April accounting correctness

Priority: **P0**

The transition from March week 4 to April week 1 must behave like a real month-end and must not accidentally grant a free founding month unless explicitly designed and communicated.

## 2.1 March week 4 closing

At the end of March week 4, audit and correctly apply all expenses that should already exist, including:

- payroll for employees who are actually on payroll for the period
- administrative/back-office payroll where represented by the game model
- office rent
- fixed operating costs
- any other already-active monthly expenses

The exact charge timing must be consistent with the game model and displayed forecasts.

## 2.2 Finance consistency

Verify that these agree:

- HUD monthly salary estimate
- monthly payment estimate
- month-end projected cash
- actual month-end ledger/payment
- cash after entering April week 1

Accepted offers that have not yet become payroll obligations must not be charged early; once an employee actually enters payroll, forecasts and settlement must switch consistently.

## 2.3 Regression tests

Add/maintain deterministic tests around:

- March week 4 -> April week 1
- payroll boundary
- rent/fixed-cost boundary
- accepted-but-not-yet-started employees
- first assignment occurring near the boundary

---

# Phase 3 — First-year Beginner Mode

Priority: **P1 / next major development phase**

Do **not** merge directly into unrestricted normal mode immediately after the first assignment.

Beginner Mode should continue for approximately the first fiscal year and gradually reduce assistance.

## 3.1 Proposed progression

### March — Founding preparation

Strong guided flow:

- employee confirmation
- SkillSheet
- sales start
- interview request
- client interview
- first assignment

Primary CTA should generally be one clear action.

### April–June — Guided management

Strong assistance remains.

Teach through actual play:

- getting the remaining waiting employee assigned
- payroll and rent
- accounts receivable/payment sites
- why sales are not immediately cash
- basic recruitment
- waiting-cost risk

### July–September — Assisted decisions

Move from one mandatory-looking CTA toward recommendations.

Introduce/teach:

- parallel sales choices
- recruitment timing
- contract renewal preparation
- Morale / Company Trust
- client relationships
- cash runway

### October–December — Independent management

Reduce tutorial intervention.

The player should increasingly choose among several valid strategies while the game explains important new situations when first encountered.

### January–March — Graduation period

Guidance becomes minimal.

The player manages year-end largely independently. Surviving/completing the first fiscal year becomes the Beginner Mode completion milestone.

### Year 2 onward — Normal Mode

- Remove beginner restrictions.
- Keep optional recommendations/help.
- Increase freedom and strategic ambiguity.

## 3.2 Design rule

Beginner Mode must not mean one year of forced一本道 interaction. Assistance should transition through:

**Primary CTA -> recommendations -> contextual help -> mostly independent play**

Use milestones/state reconciliation rather than fragile week-only flags whenever possible.

---

# Phase 4 — UI/UX cleanup

Priority: **P1 after state/accounting stability**

## 4.1 Recruitment interview summary

Current issue: identical evaluation badges can appear in both the upper summary and lower details.

Target structure:

- upper area: concise evaluation/status badges
- lower area: explanatory text/evidence only

Avoid repeating the same badge in both places.

## 4.2 Candidate reverse-question choices

Make the strategic meaning of responses easier to understand without exposing hidden numeric outcomes.

Possible stance labels/icons:

- conditions-focused
- empathetic/supportive
- company-policy focused

The player should understand the tone/intent, but there should not be an obviously correct answer.

## 4.3 Cash-flow warning on first assignment

"Contract/assignment established" must not visually imply immediate cash receipt.

Prominently explain:

**Assignment/contract success does not mean cash increases immediately. Revenue becomes receivable and is collected according to the payment site.**

Use a clearly visible information/warning card rather than small footnote text.

## 4.4 Navigation labels

Replace ambiguous labels such as "Back" where the actual destination/meaning can be clearer, e.g. "Continue founding", "Return to recruitment", or "Next" depending on context.

---

# Phase 5 — Presentation and game-feel improvements

Priority: **P2**

Only prioritize after progression and financial correctness are stable.

Improve simple spinner-only result waits with contextual progress messaging, for example:

- checking SkillSheet...
- upstream company comparing conditions...
- client reviewing interview feedback...
- finalizing result...

A lightweight progress indicator or staged messages may be used. Do not make waits materially longer merely for presentation.

Also consider stronger milestone presentation for:

- first assignment
- first cash collection
- first profitable month
- first hire
- first contract renewal
- first-year completion

---

# Phase 6 — Playable 0.4D: HR consequences

Priority: after Beginner Mode foundation is stable.

Connect existing employee-state systems to meaningful consequences:

- turnoverRisk -> resignation warning / resignation
- salary dissatisfaction
- raise requests
- raise negotiation
- compensation preference
- Morale / Company Trust
- waiting duration
- assignment situation

Core decision: spending cash on compensation/retention should compete with protecting company runway.

---

# Phase 7 — Playable 0.4E / 0.5: deepen SES management

Candidate order:

1. EmployeeAbility expansion
   - interview aptitude
   - incident/fire resistance
   - client friendliness
   - leadership tendency
   - learning speed
   - long-project suitability

2. Client relationships / commercial layers
   - trust and transaction history
   - upstream/end-client distinctions
   - introductions/unlocks

3. Field Lead expansion
   - assignment employees discovering additional openings/projects

4. Sales expansion
   - team/set proposals
   - richer parallel-sales strategy
   - future sales-employee role

5. Later candidates
   - BP/partner companies
   - new graduates/inexperienced hiring
   - financing/loans
   - larger-company management overhead

These should be introduced based on playtest evidence, not simply because they are available ideas.

---

# Priority summary

1. **P0 — Fix ghost/transition rendering and progression defects.**
2. **P0 — Make March week 4 month-end accounting correct.**
3. **P0 — Complete Failure Recovery regression coverage and stabilize 0.4C.2.**
4. **P1 — Add random editable president/company defaults.** (Small enough to include during stabilization.)
5. **P1 — Extend Beginner Mode through the first fiscal year.**
6. **P1 — Clean up interview/decision/cash-flow UI.**
7. **P2 — Improve waiting/result presentation.**
8. **Next systems — resignation, salary/raises, EmployeeAbility, clients/commercial layers, Field Lead, sales expansion.**

---

# Definition of the next major milestone

The next major product milestone is reached when a first-time player can:

1. create the company without input friction,
2. complete the founding flow without a dead end,
3. understand the March-to-April cash movement,
4. get the first employee(s) assigned,
5. understand that revenue and cash collection are different,
6. make guided but increasingly independent decisions through the first year,
7. reach the first fiscal year-end without relying on hidden knowledge of the implementation.

At that point S.E.S. should be treated as having its first coherent **"found and survive Year 1"** playable experience.
