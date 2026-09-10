# SES First Fun Year — Post-Balance Human Replay Fresh Triage

Date: 2026-09-10
Audited main: `82fc07aeab634dca0392da57dbc8bfc1af857089`
Source: Human Replay findings recorded in Issue #225 + fresh inspection of current production UI code.

## Verdict

**B/C boundary — NOT READY for final First Fun Year sign-off.**

The replay has already exposed enough early-loop comprehension gaps that continuing blindly to March would understate the problem. The next work should separate actual state/progression defects from copy/visibility/design gaps, then fix only P0/P1 first.

## 1. Opening / onboarding — P1

Human finding: a new player does not have a clear reason to understand why SkillSheet confirmation is the first important action.

Recommended opening sequence for design:
1. Company name / player name
2. Hiyori / general-affairs greeting
3. Game objective + survival/economy basics (salary, fixed costs, cash)
4. Initial employee introductions
5. Start management

Fresh triage questions:
- Is SkillSheet-open-before-sales a meaningful management decision, or only a click gate?
- If it remains, UI must explain that SkillSheet is the sales profile used to judge/project fit.
- If it has no decision value, remove/relax the gate rather than tutorializing a meaningless click.

Do not implement this sequence until the current startup/navigation authorities are audited.

## 2. Sales / project / interview / order / assignment — P1, possible P0/P1 defect

Human findings:
- 「案件紹介」does not tell the player which project was introduced or whether there is only one target.
- Partner interview is an automatic result rather than an interactive mini-game.
- After order, remaining sales slots have unclear purpose.
- The player cannot understand the previous month's proposal result.
- The player believes an ordered engineer did not become assigned the following month.
- 「発注を受注する」style terminology is confusing.

Fresh code confirmation:
- `ei(... partner ...)` currently calls `PublicDemoInterviewEvaluator.evaluate`, commits the result, then shows `PublicDemoInterviewResultDialog`; therefore the existing joined-engineer partner interview is intentionally an automatic evaluation/result dialog, not a mini-game.
- Client interview has a split path: when a genuine Matching proposal exists `_startClientInterview` opens `PublicDemoProjectInterviewDialog`; otherwise it falls back to the old generic automatic `ei` evaluation. Thus player experience can still differ depending on whether a proposal is actually connected.
- April close copy says recruitment begins from recruitment media; this is not the reported assignment defect and should not be conflated with it.

Highest-priority reproduction before any broad UI work:
`project selected/introduction → partner interview → client interview → order → month close → next-month assignment`

Record authoritative IDs at every step:
- engineerId
- projectId / matching proposal
- interview record
- ordered state
- assignment
- month

Classify outcome:
- state is correct but UI does not surface it => P1 visibility/terminology fix
- order exists but assignment is missing => P0/P1 progression defect; fix before other UX work
- no genuine project/proposal existed despite UI wording => P1 route/authority mismatch

## 3. SkillSheet / employee tab / training — P1/P2

Human findings:
- SkillSheet cannot be edited.
- Employee tab appears to offer training only.
- Player wants SkillSheet edit and project proposal from employee context.
- 「実力」does not explain what is being measured.
- Training consequence is unclear.
- Need to verify whether 「社員の様子」 scales or remains useful as employee count grows.

Design direction for audit, not yet implementation:
Employee detail should answer three questions: **who is this employee / how ready are they / what can I do next?**

Candidate actions:
- SkillSheet view/edit
- training
- find/propose suitable project
- assignment/current project status

Do not rename `実力` to `技術力` until the underlying capability formula is audited. If it combines multiple factors, a narrower label would be misleading.

## 4. Project proposal rules — P1

Human questions:
- What happens after proposing?
- Can a clearly under-qualified engineer be proposed?
- Would it be clearer to allow proposal when project requirements are satisfied?

Audit required before changing guards:
- exact Phase5 fit inputs
- hard eligibility vs soft fit/scoring
- which requirements are visible to player
- whether low-fit proposal is an intentional risky choice or just noise

Desired UX: before confirming, show `employee × project`, important requirements, fit/reason, and expected next step. After confirming, keep the proposal/result visible into the next relevant step/month.

## 5. Recruitment — P1

Human findings:
- timing from media use to applicants is unclear / may feel instantaneous
- questions are inappropriate for inexperienced candidates
- after 「採用候補として進める」 the next action is unclear

Audit separately:
- authoritative applicant generation timing
- interview question pool and whether experience category is known
- candidate stage labels/CTA after interview
- offer/acceptance/join timing

Do not change applicant timing casually because it affects payroll and #223 balance results. If immediacy is retained, explain it as candidate sourcing from a recruitment medium rather than literal same-day spontaneous application.

## 6. Employee age / sex — separate product-data decision, not current P1 fix

Age/sex can improve profile realism, but persistence/schema/data-generation/UI impact must be audited separately. Do not couple protected-characteristic-like profile data directly to hiring success or candidate quality without an explicit game-design reason and review. For the immediate First Fun Year loop, this is lower priority than understanding skill, salary, fit and employment stage.

## 7. HOME information blocks

### 社員の様子
Fresh Human Replay question is valid. Before removal, audit what unique decision it supports compared with Employee tab and Recommended Action. If it duplicates other information and cannot scale beyond a few employees, replace it with a compact exception/attention summary rather than a full roster.

### 今月の重要タスク
Audit whether contents actually change by month/state and whether they are authoritative. If mostly static, it is not earning HOME space. Desired behavior is state/month-dependent and limited to decisions that matter now.

## 8. Recommended next implementation order

1. **P0/P1 focused reproduction: order → next-month assignment and proposal/result persistence.** No redesign in this task.
2. **P1 core-loop comprehension:** project identity/requirements, proposal result, partner/client interview distinction, order/assignment terminology and next-action continuity.
3. **P1 onboarding + employee/recruitment comprehension:** startup sequence, SkillSheet gate necessity, training meaning, recruitment stage/CTA. Split implementation if >2–3h.

Visual Complete 2, age/sex expansion, 1-turn=1-week, and new systems remain after these.

## Handback-reduction rule

For each implementation slice:
`Fresh Audit → minimal design → implementation → self-hardening → Codex review principally once → batch P0/P1/material P2 fix → focused/full tests → CI → merge`.

Do not recursively reopen broad reviews for low-impact P2/P3.

## Human Replay status

Pause full April→March sign-off until item 1 is reproduced. Existing replay evidence is retained in Issue #225. After P0/P1 fixes, restart from April on the deployed main rather than continuing a state whose interpretation is already uncertain.
