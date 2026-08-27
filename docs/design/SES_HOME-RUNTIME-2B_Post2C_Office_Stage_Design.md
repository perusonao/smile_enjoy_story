# SES HOME-RUNTIME-2B — Post-2C Office Stage — Design Record

> ## ⚠️ ORIGINAL EXTERNAL DESIGN DOCUMENT UNAVAILABLE
>
> The formal design authority named for this phase was
> `SES_HOME-RUNTIME-2B_Post2C_Office_Stage_Design.md`, produced by a prior
> Codex DESIGN-ONLY task and stored at the Windows path
> `C:\tmp\SES_HOME-RUNTIME-2B_Post2C_Office_Stage_Design.md`.
>
> **That file could not be read from this environment.** It is not present
> anywhere in this repository (searched by name and by content), the Windows
> path is not reachable from the Linux container this session ran in, and no
> copy was attached to the session.
>
> This document is therefore **not** that design document, and it does not
> reproduce or paraphrase it. It is an *implementation design record*
> written from the **APPROVED DESIGN SUMMARY supplied verbatim in the
> implementation task prompt**, which explicitly authorises itself as the
> design authority when the external document cannot be obtained. Where this
> record states a decision the summary did not cover, it says so explicitly
> and gives the reasoning, rather than presenting it as inherited authority.
>
> A reviewer holding the original document should diff it against this
> record before accepting the implementation.

## Authority actually used

| Source | Status |
|---|---|
| `SES_HOME-RUNTIME-2B_Post2C_Office_Stage_Design.md` (external) | **UNAVAILABLE — not read** |
| APPROVED DESIGN SUMMARY (implementation prompt) | **Used as authority** |
| `SES_HOME-RUNTIME-2C_Recommended_Action_Result.md` (in repo) | Read, as the 2C constraint baseline |
| Repository code + asset catalogue | Read, as the factual baseline |

Base: `origin/main` = `62de4df7db2103b2bbc8cab8dd6261d3a608e1e6`
("Merge PR #72: HOME-RUNTIME-2C Recommended Action"), verified merged before
any implementation work began.

## What the Office Stage is

A read-only picture of the company on the Public Demo runtime HOME: an
office background, up to three employees with portraits and names, and a
`+N` indicator when there are more. It adds **no** gameplay operation, holds
no state, takes no callback, and has no path back into `PublicDemoAggregate`.

## Placement — Candidate A

```
Month header
KPI
Recommended Action      <- primary interaction (HOME-RUNTIME-2C)
Office Stage            <- this phase, visual layer
legacy content
```

The Office Stage is never moved above the Recommended Action. The
Recommended Action is the primary gameplay interaction; the Office Stage is
presentation. Buying a better-looking screen by pushing the primary action
out of the opening view would undo exactly what 2A and 2C achieved.

The section is mounted as a **sibling** of `PublicDemoHomeDashboardSection`,
not a child of it. That section is the read-only projection boundary whose
height the consolidation suite pins to a deliberately tight ceiling
(`_homeBlockCeiling = 320pt`, with the block currently measuring 316pt —
4pt of headroom). A picture is not one of the facts that ceiling was drawn
around, so keeping it outside leaves that guard measuring what it was
written to measure.

## Responsive rule

| | 360x800 (compact) | 390x844 (normal) |
|---|---|---|
| scene target | ≈128pt | ≈152pt |
| whole component target | ≈184pt | ≈208pt |
| absolute safety ceiling (360) | 213pt | — |

`213pt` is a **ceiling, not a target**. The compact design deliberately
lands well under it so that a longer name, a larger text scale, or a later
phase's addition does not blow the first-view budget without warning.

Mode is selected by screen width against a single threshold placed *between*
the two targets (`375`), so neither target is decided by an exact-equality
comparison. All dimensions live in one named `HomeOfficeStageMetrics` class
that the layout tests assert against directly, rather than as literals
scattered through the widget tree.

## Employee display

- At most **3** employees are drawn.
- Selection is the first three in **authoritative emission order**
  (`PublicDemoWorkflowState.engineers`, which `withJoinedEngineers` appends
  to as applicants join). No sampling, no shuffling, no score or recency
  ordering — the same state always draws the same three people in the same
  slots, across rebuilds and across a save/load cycle.
- Employees beyond the third are summarised as `+N`, never dropped silently.
- The Office Stage is **not** an employee roster. Per-employee detail
  remains with the legacy cards until 2E's Employee tab.

## Employee image mapping

Presentation-only. **No** `imagePath`, `portrait`, `asset` or `portraitId`
field is added to any Domain, Workflow, or Save model, and nothing is
persisted. This follows the precedent already in the codebase,
`portraitAssetFor(ApplicantType)` in `lib/ui/widgets/engineer_avatar.dart`.

Fallback chain:

1. **Explicit mapping** for the two founding employees, whose ids are fixed
   constants of Public Demo 0.1 (`publicDemoInitialEngineers`):
   `eng-01` (佐藤 健, Java/SQL, 3 years) → `engineer_midlevel.jpg`;
   `eng-02` (鈴木 葵, JavaScript/Flutter, 2 years) → `engineer_junior.jpg`.
2. **Deterministic generic portrait** for generated hires, keyed on the
   employee's already-permanent id via a hand-rolled FNV-1a masked to 31
   bits — deliberately *not* `String.hashCode`, which Dart does not
   guarantee stable across runs or platforms and which would let a face
   change between the VM and the web build of the same save.
   Pool: `engineer_junior` / `engineer_midlevel` / `engineer_veteran` only.
   The catalogue's other faces are a recruiter, two sales staff, a client
   contact and an *applicant* — none depicts an employee of the company.
3. **Generic silhouette** (`Icons.person`) when a member carries no portrait
   path, and as the `errorBuilder` when a bundled image fails to decode.

## Office background

The asset tree was re-checked. There are **no** office-tier assets: the
`locations/` folder holds `office_day.jpg`, `office_night.jpg`,
`meeting_room.jpg`, `cafe_meeting.jpg` and nothing else. No `home_office`,
`small_office` or `medium_office` image exists, and none is referenced.

`office_day.jpg` is the common fallback. It is a constructor parameter on
`HomeOfficeStageDisplay` rather than a constant inside the widget, so a
later phase that does introduce tiers can choose the scene at the
construction site without the rendering widget learning about tiers — and
without inventing an asset name that is not in the bundle today.

Assets are registered in `pubspec.yaml` by directory
(`assets/images/locations/`, `assets/images/characters/`), so this phase
needed **no** `pubspec.yaml` change, added no asset file, and replaced no
binary.

## Decisions this record makes that the APPROVED DESIGN SUMMARY did not cover

### 1. No per-employee 参画/待機 status, and no participation counts

The summary asks for "必要最低限の状態表示" without specifying it. An office
scene distinguishing "at a client" from "in the office" was implemented
first, then **removed**, for two independent reasons.

**(a) Three authorities disagree.** Public Demo 0.1 has three sources for
that fact and they are legitimately out of step at different points in a
month:

| Source | Behaviour |
|---|---|
| `PublicDemoState.engineersAssigned` | finance-side count the KPI already renders; advances at month close |
| `PublicDemoWorkflowState.assignments` | assignment roster; `assignOrderedForMay` does not build it until `closeMay`, so it is **empty for all of May** while the count above already reads 1 |
| `PublicDemoEngineerSales.stage == ordered` | moves the instant an order is won, and a `juneOrdered` applicant becomes an engineer at the default `waiting` stage, so it misses joined hires |

This was found empirically, not assumed: a real April→May trajectory
produces `engineersAssigned == 1` with `assignedEngineerIds(month: 5) == {}`.
Picking any one of them would put a per-employee claim on screen that
contradicts the KPI two rows above it in at least one month. Reconciling
them is Assignment/Domain work, which this phase must not touch.

**(b) It would duplicate the KPI.** HOME-RUNTIME-2A's rule is that every
fact has exactly one place on screen; the KPI row owns 参画/待機.

So the Office Stage shows who works here and how many there are, and leaves
per-employee state to 2E. Recorded as a **P2 follow-up**, not a silent
omission.

### 2. The stage renders in terminal states too

2C suppresses the Recommended Action slot at bankruptcy / March failure /
fiscal completion. The Office Stage is not suppressed: it is read-only
presentation of who works at the company, which remains true in those
states, and adding a suppression rule the design did not ask for would be
this layer inventing a financial-verdict behaviour it deliberately cannot
see.

### 3. Legacy content is not deleted

Per the task's own boundary, no legacy employee/detail block is removed.
That is 2D/2E's scope. Where the judgement was ambiguous, content was kept.

## Test-contract change this design requires

Adding a ~176pt visual layer above the legacy content necessarily pushes the
legacy per-employee `SkillSheet確認` button below the browser-chrome content
budget the consolidation suite asserts (615pt at 360x800). This is a direct,
unavoidable consequence of the placement the summary mandates (Office Stage
above legacy content), and the summary's own first-view requirement protects
only the Recommended Action CTA.

Consolidation test 16-17 is therefore **re-aimed**, once and deliberately,
from the legacy button to the Recommended Action CTA — the element that
actually carries "the month's top action" after 2C, and which sits at 302pt,
roughly half the depth the legacy button ever did. The assertions themselves
(painted viewport, browser-chrome budget, genuinely tappable) are unchanged
in form and strength, and 16-17 additionally now requires the Office Stage
to be fully painted inside the same budget. Group 18/24 gained an explicit
new test that the legacy button is **relocated, not lost**.

This is recorded as a **P1 item for independent review**: it is the one
place where this phase changed an existing passing assertion.

## Boundaries

**DO NOT TOUCH (and were not touched):** Domain, Finance, Save, Workflow,
Payroll, Assignment, Navigation, and HOME-RUNTIME-2C's eligibility,
candidate emission, ranking, month gate, owner handler, dispatch and
finance/terminal precedence.
