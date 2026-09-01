# S.E.S. Development Plan

Last updated: 2026-08-16

This document is the source of truth for near-term development priorities for S.E.S. (Smile. Enjoy. Story.).

## Process/priority governance

For *how* work is prioritized, which AI does what, model selection, result
reporting, and E2E blocking policy (as opposed to phase/feature content),
see [`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`](decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md).
That document currently sets the top-level goal — a developer-played,
enjoyable full April-to-March "First Fun Year" — that should be used to
judge priority among the phases below.

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

The first-year goal is **"survive the first year of the company"**, not merely "get the first assignment".

Beginner Mode is not one year of forced tutorial interaction. Assistance must gradually transition through:

**Primary CTA -> recommendations -> contextual help -> mostly independent play**

Tutorial teaching should be event/milestone driven whenever possible rather than appearing simply because a calendar week was reached.

---

# Phase 1 — Playable 0.4C.2 stabilization

Status: **Completed**

Completed scope includes:

- random editable president/company defaults
- recruitment interview duplicate-route/ghost rendering fix
- Failure Recovery stabilization
- Flutter/Replay/Chromium/WebKit regression gates

Preserve these behaviors in later work.

---

# Phase 2 — March-to-April accounting correctness

Status: **Completed**

Completed scope includes:

- March week 4 -> April week 1 settlement
- payroll boundary correctness
- March rent / administrative salary / fixed-cost accounting
- paid recruitment cost recognized once without double cash deduction
- whole-month cash movement tracking via `monthStartCash` / `monthCashMovement`
- legacy MonthlyClosing migration consistency
- deterministic regression coverage

Core invariant to preserve:

**`cashAfter - cashBefore == monthCashMovement`**

Immediate expenses must affect cash exactly once. Accepted employees must not enter payroll before their actual payroll/start boundary.

Non-blocking follow-ups are tracked separately (for example Issue #14).

---

# Phase 3 — First-year Beginner Mode

Priority: **P1 / current major development phase**

Phase 3A (April-June foundation) status: **Implemented, tested (unit +
widget + seeded Playwright), human/video UX review completed and fixes
landed.** See §3.9 below for what shipped and what's still open before
Phase 3B starts.

Do **not** merge directly into unrestricted normal mode immediately after the first assignment.

Beginner Mode should continue through the first fiscal year and gradually reduce assistance. The product goal is for the player to learn SES management by actually experiencing the financial and personnel consequences.

## 3.0 Core design rules

1. **Event-driven teaching over calendar-only teaching.**
   - Explain accounts receivable when the player first creates revenue/receivable.
   - Explain payment sites when the player first has money scheduled for future collection.
   - Explain waiting cost when the player actually has a waiting employee costing salary.
   - Explain recruitment risk when hiring would materially increase fixed cost.

2. **Do not expose hidden optimal answers.**
   Guidance may explain tradeoffs, but should not turn strategy into a single obvious correct choice.

3. **Failure is allowed.**
   Beginner Mode should not guarantee survival. Bankruptcy/failure should provide useful management feedback and make the next attempt more understandable.

4. **Guidance weakens over time.**
   The player should move from one clear Primary CTA to multiple recommendations, then contextual hints, then largely independent play.

5. **Use milestone/state reconciliation rather than fragile week-only flags.**
   A player who reaches a milestone early/late must still receive the correct guidance and must not dead-end.

6. **Do not implement the whole year in one risky change.**
   Build and validate Beginner Mode in stages, beginning with April–June.

---

## 3.1 March — Founding preparation

Guidance strength: **★★★★★**

Existing strong guided flow:

- employee confirmation
- SkillSheet
- sales start
- interview request
- client interview
- first assignment

Primary CTA should generally be one clear action.

After the first assignment, the tutorial must **continue** rather than immediately handing the player to unrestricted normal mode.

The visible objective transitions from:

**"Get the first assignment"**

to:

**"Keep the company alive and learn how cash actually moves."**

---

## 3.2 April–June — Guided Management / Survival

Guidance strength: **★★★★☆**

This is the **first implementation slice for Phase 3**. Implement and playtest this period before building July onward.

### Player goal

**Keep the company operating for the first three management months.**

### Systems to teach through actual events

- get remaining waiting employees assigned
- payroll
- office rent / fixed costs
- accounts receivable
- payment sites (30/60 days etc.)
- why revenue/contract success is not immediate cash
- waiting employee salary burden
- basic recruitment
- recruitment increases future fixed-cost risk
- first cash collection
- basic cash runway awareness

### Recommended-action presentation

The home screen should help the player understand both **what to do** and **why it matters**.

Example concept:

- 🔴 Waiting employee: start/continue sales activity
- 🟡 Month-end payments: approximately ¥X
- 🟢 First expected collection: Month/Week or date equivalent

Avoid presenting every item as mandatory. Primary CTA may remain strong for critical onboarding actions, but financial information should increasingly support player judgment.

### Event-driven tutorial examples

#### First revenue / receivable

Explain clearly that assignment/contract success does not immediately increase cash.

Teach:

- revenue was created
- it becomes receivable
- collection occurs according to the payment site

#### First waiting-cost pressure

When a waiting employee remains unassigned while salary is due, explain that waiting employees still consume cash and that sales priority matters.

#### First cash collection

Show a milestone explaining the difference between prior revenue recognition and actual cash receipt.

#### Recruitment decision

Before/when recruitment becomes relevant, show the tradeoff:

- more employees can increase future revenue
- salaries and related costs begin creating additional runway pressure

Do not simply tell the player "hire now" unless the current guided step truly requires it.

### April–June acceptance criteria

Before implementing July–September, verify through automated and recorded play that a first-time player can reasonably understand:

1. why cash did not increase immediately after first assignment,
2. when money is expected to arrive,
3. why waiting employees are dangerous to cash flow,
4. what the next recommended management action is,
5. how month-end salary/rent affects runway,
6. that recruitment is a growth-versus-fixed-cost decision,
7. that negative outcomes still recover without a dead end.

Use Playwright seeded runs plus human/video UX review before proceeding.

---

## 3.3 July–September — Assisted Growth Decisions

Guidance strength: **★★★☆☆**

Only begin after April–June is validated.

### Player goal

Move from survival to controlled growth.

### Teach/introduce

- recruitment timing
- multiple employees / parallel sales
- comparing safe growth vs aggressive growth
- contract renewal preparation
- Morale / Company Trust
- client relationships
- cash runway

### Decision style

Stop giving a single mandatory-looking answer for ordinary management choices.

Example tradeoff pattern:

- **Hire another employee** — faster growth potential / higher fixed cost
- **Prioritize assigning existing employees** — safer / slower growth
- **Invest in work environment/welfare** — employee benefit / immediate cash reduction

The game may recommend actions based on state, but multiple strategies should remain valid.

---

## 3.4 October–December — Independent Management / People Decisions

Guidance strength: **★★☆☆☆**

### Player goal

Make meaningful management decisions with less tutorial intervention.

### Focus

- contract continuation/renewal choices
- employee satisfaction
- Morale / Company Trust consequences
- compensation pressure
- welfare decisions
- retention risk
- balancing cash protection against employee investment

This period should increasingly connect to Phase 6 HR systems as they become available. Do not prematurely build all Phase 6 features merely to fill this period; use existing systems first and add HR consequences deliberately.

Example future event:

An employee questions whether compensation matches their assignment/value, creating choices such as raise, bonus, or deferment with different cash and trust consequences.

---

## 3.5 January–March — Graduation Period

Guidance strength: **★☆☆☆☆**

### Player goal

**Survive/complete the first fiscal year largely through independent management.**

New tutorial explanations should be rare and mostly reserved for genuinely new situations.

The home screen may show a simple year-end objective/progress indicator, for example:

**"Survive your first year — 8 weeks remaining"**

but should not prescribe every weekly action.

---

## 3.6 First-year completion report

At the end of March week 4, provide a meaningful first-year management report before graduating Beginner Mode.

Candidate metrics:

- annual revenue
- annual profit / operating result
- ending cash
- employee count
- assigned employee count
- waiting employee count
- resignations (when implemented)
- first assignment timing
- first cash collection timing
- first hire timing
- contract renewal results (when applicable)

Provide an understandable qualitative management evaluation such as a conservative/steady/growth-oriented result. Avoid pretending there is only one ideal play style.

Then clearly present:

**Beginner Mode complete -> Year 2 / Normal Mode unlocked**

---

## 3.7 Beginner Mode failure / bankruptcy feedback

Failure is a learning outcome, not merely a reset screen.

When the company fails during Beginner Mode, provide state-based feedback such as:

- waiting salary burden became too high
- hiring occurred before enough runway existed
- collections arrived too late relative to expenses
- too many employees remained unassigned

Offer 1–3 concrete improvement hints based on the actual run.

Do not fabricate a cause that is not supported by game state/accounting data.

---

## 3.8 Year 2 onward — Normal Mode

After first-year graduation:

- remove beginner restrictions
- keep optional recommendations/help
- increase freedom and strategic ambiguity
- do not continue mandatory tutorial sequencing

Normal Mode should feel like the same game with assistance removed, not an unrelated second ruleset.

---

## 3.9 Phase 3 implementation order

Implement Phase 3 incrementally:

### Phase 3A — April–June foundation **(IMPLEMENTED)**

- continue Beginner Mode after first assignment — `BeginnerModeEngine`
  (`lib/game/engine/beginner_mode_engine.dart`) + `BeginnerModeState`
  (`lib/game/models/beginner_mode_state.dart`), separate from the March
  `FoundingProgress`/`OneTimeEvent` tutorial machinery
- Home shows a "初心者経営期間 (4〜6月)" card
  (`lib/ui/widgets/beginner_mode_card.dart`) while
  `BeginnerModeEngine.isPhase3AActive` is true (post first-assignment,
  week <= 12)
- first revenue/receivable explanation — reuses the existing
  first-assignment celebration / `firstArTutorial` dialogs rather than a
  duplicate popup (tracked as `BeginnerMilestone.revenueVsCashExplained`)
- payment-site / expected-collection explanation — the Beginner Mode card's
  "次回入金予定" fact (`BeginnerModeEngine.nextExpectedCollection`)
- waiting-cost explanation — one-time dialog
  (`BeginnerMilestone.waitingCostExplained`) the first time a genuinely idle
  employee is actually drawing salary post-founding
- first cash-collection milestone — one-time "🎉 初入金！" dialog
  (`BeginnerMilestone.firstCollectionCelebrated`) the first time an AR
  record actually moves from pending to paid
- recommended-action presentation for survival/cash flow — reuses the
  existing `RecommendationEngine`/`TaskEngine` (no new UI-side game logic)
- recruitment growth-vs-cost guidance — one-time dialog
  (`BeginnerMilestone.recruitmentTradeoffExplained`) the first time a new
  listing is posted after founding
- Failure Recovery reconciliation — all milestones are derived facts
  (`BeginnerModeEngine.reconcile`/`pendingMilestones`), never tied to a
  specific successful action sequence
- seeded Playwright coverage through June —
  `e2e/tests/beginner-mode-april-june.spec.ts` +
  `e2e/helpers/beginner-mode-player.ts`
- end-of-June recap — one-time "🎉 初心者経営・前半クリア！" dialog
  (`BeginnerMilestone.phase3aRecapCelebrated`) once Phase 3A's own window
  has passed (`state.week > BeginnerModeEngine.lastWeek`), summarizing real
  playthrough figures (cumulative revenue/collection, closings experienced,
  current runway) — a look-back only, no Phase 3B preview
- Beginner Mode card shows a dynamic "今月の経営ポイント"
  (`BeginnerModeEngine.currentThemeLabel`) instead of a static blurb, so the
  card reads as this week's lesson rather than a fixed info box
- dedicated real-UI Playwright coverage for the two milestones the general
  playthrough never exercises on its own —
  `e2e/tests/beginner-mode-waiting-and-recruitment.spec.ts` drives an actual
  second recruitment-media post and an actual interview→hire→wait sequence

Human/video UX review pass (§3.2's "Acceptance criteria" list) completed on
the recorded Playwright runs; fixes landed in the same PR (yen-sign font
coverage, interview-offer client name sourcing, transient "not found" text,
monthly-closing value coloring, week-advance modal-fatigue reduction, cash
warning severity, the end-of-June recap and Beginner Mode card items above).
That review's own real-UI E2E pass also found and fixed a genuine engine bug:
`recruitmentTradeoffExplained` read `state.listings.length`, which
`GameEngine.advanceWeek` replaces with the *currently active* listings only
every week (§3 求人掲載終了の検出) — so the March founding listing's later
expiry silently un-satisfied the milestone before Beginner Mode's own
recruitment unlock ever opened. Fixed by adding a genuinely cumulative
`GameStats.recruitmentListingsPosted` counter instead. No unit test had
caught this because unit tests construct `listings` directly rather than
going through the engine's weekly pruning — exactly the gap dedicated
real-UI E2E coverage exists to close.

### Phase 3B — July–September

- reduce guidance strength
- recommendation model for growth choices
- parallel-sales/recruitment/runway guidance
- contract-renewal preparation

### Phase 3C — October–December

- contextual guidance only for most systems
- people/retention/benefit decisions using available mechanics
- Public Demo-only Phase 2F precursor: after joining, an employee can make a
  compensation request from June. The player chooses hold / small raise /
  requested raise; the chosen salary starts next month and records one
  qualitative Morale/Trust consequence. This is not yet Engineer-runtime,
  resignation, bonus, loan, or employee-growth integration.

### Phase 3D — January–March + graduation

- minimal guidance
- first-year completion tracking
- first-year report
- Beginner Mode graduation -> Normal Mode
- bankruptcy/failure feedback refinement

Do not start Phase 3B until Phase 3A has passed automated regression tests and a recorded UX review.

---

# Phase 4 — UI/UX cleanup

Priority: **P1 alongside/after stable Phase 3 slices where directly relevant**

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

This now directly supports Phase 3A and may be implemented as part of that slice.

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

## 7.1 Employee basic profile

Add/preserve structured profile information for technical employees and recruitment candidates so people are represented as individuals in addition to their skills and career evidence.

The basic profile should include at least:

- **age**
- **gender**
- **education / highest educational background**

Education should be represented as structured data rather than only arbitrary display text where practical. Candidate categories may include, for example:

- high school
- vocational / technical school
- junior college
- university
- graduate school

Where useful, school/department or major may be represented separately, but avoid requiring unnecessary detail for every generated employee.

### Gameplay principle

Age, gender, and education are primarily **profile/background information**. Do not automatically turn protected or demographic characteristics into universal ability modifiers.

- Gender must not provide a direct positive/negative ability, salary, interview, or project-selection modifier.
- Age should primarily support career plausibility and presentation. Any gameplay relationship should come from actual experience/history rather than a raw age bonus/penalty.
- Education may participate only where a project/recruitment condition explicitly and legitimately references educational background; it must not silently substitute for technical experience.

Career history, certifications, skills, and demonstrated experience should remain the main evidence for engineer capability and project fit.

### Generation / save compatibility

When this model is implemented:

1. add backward-compatible save migration/defaults,
2. generate age/gender/education deterministically from the game seed for generated candidates/employees,
3. preserve these values through candidate -> hired employee transitions,
4. display them consistently in recruitment/employee profile UI where useful,
5. ensure save -> load -> save preserves them exactly.

Do not regenerate identity/profile fields after hiring or loading an existing save.

## 7.2 SkillSheet / Career History expansion

Add structured past-project history to each engineer so a SkillSheet represents actual career evidence rather than only aggregate skill values.

Each past assignment/career entry should be able to represent, where applicable:

- project / business-domain summary (for example EC, banking, public-sector, infrastructure)
- participation period / duration
- programming languages
- frameworks / libraries
- database / infrastructure technologies
- role (PG / SE / PL / PM etc.)
- team/project scale
- process / responsibilities (requirements, basic design, detailed design, implementation, test, operations, incident response etc.)

### Experience aggregation

Prefer deriving experience summaries from career history instead of storing only independent totals.

Examples:

- Java: 4 years 2 months
- Spring: 2 years 8 months
- basic design: 1 year 4 months
- leader experience: 6 months

Avoid double-counting overlapping periods when multiple technologies were used on the same assignment. Define aggregation semantics before connecting them to matching.

### Actual history vs sales SkillSheet

Preserve the existing concept that the sales-facing SkillSheet can differ from reality.

The system should eventually distinguish:

- **actual career history / actual experience**
- **sales-facing SkillSheet representation**

This enables realistic exaggeration such as actual Java experience of 2 years 8 months being represented as 3 years, while Company Trust / interview risk reacts to the gap.

Do not allow the editable SkillSheet to overwrite or destroy the underlying factual career history.

### Career growth during play

Long-term target: assignments completed during gameplay should become part of the engineer's career history automatically.

An engineer who spends one or two in-game years on projects should therefore have a visibly stronger SkillSheet than when they joined the company.

Implementation should be staged:

1. data model + backward-compatible save migration
2. deterministic generation of initial career history for existing/new engineers
3. employee/SkillSheet UI display
4. derived experience summaries
5. matching / document-screening effects
6. automatic career-history growth from in-game assignments

Do not change the core matching algorithm in the same PR as the initial data-model introduction unless separately reviewed and tested.

## 7.3 Engineer Certifications

Add certifications/qualifications to technical employees.

Initial certification families may include examples such as:

- 基本情報技術者
- 応用情報技術者
- AWS certifications (Cloud Practitioner / Solutions Architect etc.)
- Azure certifications
- Oracle Java certifications
- Oracle Database certifications
- CCNA
- LPIC / LinuC

Use a structured certification model rather than free-text-only strings so certifications can later participate in matching and employee development.

Candidate fields include:

- certification ID/type
- display name
- acquired status/date or career timing where useful
- category (development / cloud / network / database / general IT)
- level/rank where applicable

### Gameplay role of certifications

Certifications should primarily support **sales/document screening and credibility**, not act as a simple universal `ability +5` modifier.

Example principle for an AWS project:

- AWS practical experience: △
- AWS SAA certification: ◎ supporting evidence
- infrastructure experience: ○

A certification may partially compensate for limited experience, but should not completely replace required practical experience unless the project explicitly accepts that.

Later project requirements may include:

- required certification
- preferred certification
- certification as a tie-breaker / screening bonus

## 7.4 Qualification acquisition / employee development (later extension)

After certification data and matching behavior are stable, consider a qualification-support management system:

**company pays exam/training cost -> employee studies -> pass/fail -> certification acquired -> sales credibility / Morale / employee growth changes**

Potential decisions:

- company pays all exam costs
- partial subsidy
- study/training time support
- no support

This should connect employee development, welfare spending, retention/Morale, and future project opportunities. Do not implement it before the underlying certification and career-history models are stable.

## 7.5 EmployeeAbility expansion

- interview aptitude
- incident/fire resistance
- client friendliness
- leadership tendency
- learning speed
- long-project suitability

Career history and certifications should remain distinct from hidden/innate EmployeeAbility. A qualification is evidence/achievement; it is not the same thing as personality or innate aptitude.

## 7.6 Client relationships / commercial layers

- trust and transaction history
- upstream/end-client distinctions
- introductions/unlocks

## 7.7 Field Lead expansion

- assignment employees discovering additional openings/projects

## 7.8 Sales expansion

- team/set proposals
- richer parallel-sales strategy
- future sales-employee role

## 7.9 Later candidates

- BP/partner companies
- new graduates/inexperienced hiring
- financing/loans
- larger-company management overhead

These should be introduced based on playtest evidence, not simply because they are available ideas.

### Phase 7 design principle

The long-term SES matching model should be able to distinguish at least:

**basic profile + career evidence + experience duration + role/process experience + certifications + sales SkillSheet representation + EmployeeAbility + human traits**

This allows two engineers with the same nominal language skill to have meaningfully different sales value and project fit without treating demographic characteristics as hidden universal ability modifiers.

---

# Priority summary

1. **DONE — Phase 3A: April–June Beginner Mode foundation (implemented and unit/widget/seeded-Playwright tested).**
2. **DONE — Human/video UX review of the Phase 3A recordings, fixes landed in the same PR.**
3. **CURRENT P1 — Phase 3B: July–September assisted growth decisions.**
4. **P1 — Phase 3C: October–December independent/people decisions.**
5. **P1 — Phase 3D: January–March graduation + first-year report.**
6. **P1 — UI/UX cleanup where it directly supports Beginner Mode comprehension.**
7. **P2 — Waiting/result presentation and milestone game-feel.**
8. **P3 — Non-blocking technical follow-ups such as Issue #14.**
9. **NEXT SYSTEM FOUNDATION — employee basic profile + SkillSheet career history + engineer certifications.**
10. **Later systems — qualification acquisition, resignation, salary/raises, EmployeeAbility, clients/commercial layers, Field Lead, sales expansion.**

---

# Definition of the next major milestone

The next major product milestone is reached when a first-time player can:

1. create the company without input friction,
2. complete the founding flow without a dead end,
3. understand the March-to-April cash movement,
4. get the first employee(s) assigned,
5. understand that revenue and cash collection are different,
6. understand waiting cost and basic runway pressure,
7. make guided but increasingly independent decisions through the first year,
8. learn from bankruptcy/failure when it occurs,
9. reach the first fiscal year-end without relying on hidden knowledge of the implementation,
10. receive a first-year management report and graduate into Normal Mode.

At that point S.E.S. should be treated as having its first coherent **"found and survive Year 1"** playable experience.
