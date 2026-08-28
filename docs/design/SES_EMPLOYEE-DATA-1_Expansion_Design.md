# SES EMPLOYEE-DATA-1 Expansion Design

Status: Design only / implementation not started
Depends on: EMPLOYEE-UI-1A merged and stabilized
Priority: Employee information foundation before deeper HR systems

## 1. Goal

Expand engineer/employee information so the player can understand not only current status and SkillSheet, but also the engineer's accumulated career facts.

The first implementation should make existing/future data displayable without immediately introducing growth, qualification effects, resignation, or new payroll rules.

## 2. Product intent

The employee detail screen should gradually become the player's personnel file for each engineer.

Target information categories:

- qualifications/certifications
- past project participation history
- languages/technologies used in each project
- role
- project/team scale
- participation duration / experience period
- industry/domain experience
- current assignment facts
- sales-facing SkillSheet facts

The player should be able to distinguish:

1. actual career facts,
2. sales-facing SkillSheet representation,
3. current assignment/workflow status.

Do not mix these authorities in UI reconstruction.

## 3. Recommended phase split

### EMPLOYEE-DATA-1A — Domain model only

Add persisted career facts, with no gameplay effect.

Suggested model shape:

`EngineerCareerProfile`

- `certifications: List<EngineerCertification>`
- `projectHistory: List<EngineerProjectHistoryEntry>`

`EngineerCertification`

- stable id/key
- display name
- optional acquired week/year
- optional category

`EngineerProjectHistoryEntry`

- stable id
- project/client display snapshot or durable project reference strategy
- industry/domain
- start week / end week or duration months
- languages/technologies
- role
- team/project scale
- short summary

Use enums or stable codes for fields that will later drive matching. Keep display labels outside serialized authority where practical.

### EMPLOYEE-DATA-1B — Read-only projection + UI

Extend the EMPLOYEE-UI presentation projection rather than letting widgets read and recompute scattered fields.

Add sections to engineer detail:

- `資格`
- `職務経歴`

Each history card should prioritize scannable facts:

`案件名 / 業界`
`期間`
`役割`
`技術`
`規模`

Do not introduce editing in this phase.

### EMPLOYEE-DATA-1C — History accumulation

When an assignment actually ends, append one immutable career-history entry from the completed assignment.

Important rule: snapshot the career facts needed for history at completion time. Do not make old history change when a project master/display name is edited later.

### EMPLOYEE-DATA-2 — Gameplay effects, separately reviewed

Only after the data/display foundation is stable, consider:

- qualifications affecting matching/Fit
- industry history affecting matching
- role history affecting project eligibility
- certification acquisition/training events
- experience growth over time
- SkillSheet auto-suggestions from actual history

These are explicitly not part of EMPLOYEE-DATA-1.

## 4. Save-data strategy

Because career history is persistent player state, this work likely requires a save-schema extension when implementation reaches 1A/1C.

Requirements:

- old saves load with `certifications=[]` and `projectHistory=[]`
- no fabricated historical projects for old saves unless there is an authoritative existing source
- current active assignment must not be silently duplicated into completed history during migration
- unknown future enum values need a safe fallback strategy if enums are serialized by name

If the current save system supports additive fields without schema bump, document that explicitly; otherwise perform a deliberate migration in the implementation PR.

## 5. Qualification model guidance

Do not encode real-world vendor/product trademark behavior into core logic unnecessarily. A certification record should primarily store a stable game key and display label.

Initial categories can be broad:

- programming/development
- cloud/infrastructure
- database
- network/security
- project/management
- general IT

Initial phase may ship with zero certifications for existing engineers. Qualification acquisition mechanics should come later.

## 6. Project-history authority

A completed history entry should represent what the engineer actually experienced.

Recommended immutable facts:

- `projectTitleSnapshot`
- `clientNameSnapshot` or suitable non-sensitive company label snapshot
- `industry`
- `startWeek`
- `endWeek`
- `durationWeeks`
- `technologies`
- `role`
- `teamSizeBand`
- `projectScaleBand`

Avoid storing only a live `projectId` if historical display would then mutate when master data changes.

## 7. UI placement

Keep EMPLOYEE-UI-1A's top-of-screen priority intact:

1. summary
2. current status
3. SkillSheet/sales
4. current assignment
5. time-sensitive interview/offer/contract actions

Career data is reference information, so place it below time-sensitive action sections.

Recommended lower order:

- 基本情報
- 技術スキル
- 資格
- 職務経歴
- 人物パラメータ
- 営業状況 / offers as appropriate to the existing screen architecture

If the detail screen becomes too long, prefer collapsible sections or a secondary tab in a later UI phase rather than hiding action CTAs below more static content.

## 8. Accessibility / E2E constraints

The current Flutter Web E2E has already demonstrated that off-screen ListView children may not exist in the semantics tree until scrolled into view.

Therefore future E2E must:

- scroll using the repository's portable helper before asserting lower career sections
- never assume a button/text below the fold exists in the initial aria snapshot
- keep action/reachability tests separate from static career-data display tests where possible

Do not increase retries or arbitrary sleep merely because the screen grows.

## 9. Test plan

### Domain/save tests

- empty career data is valid
- certification round-trip
- multiple history entries preserve order and values
- old-save migration yields empty new fields safely
- completed assignment creates exactly one history entry
- advancing additional weeks does not duplicate the completed entry

### Presentation tests

- projection returns stored certifications/history unchanged
- missing/empty values render a clear empty state
- current assignment is not shown as completed history
- SkillSheet displayed experience is not substituted for actual career facts

### Widget/E2E tests

- qualification section reachable
- project-history section reachable after real scrolling
- long career list does not prevent Back/action navigation
- existing interview offer / client interview / contract CTAs remain reachable

## 10. Explicit non-goals

EMPLOYEE-DATA-1 must not add:

- certification training costs
- exam pass/fail RNG
- qualification allowances
- salary changes
- resignation/retention effects
- departments/positions
- contractor/freelancer employment types
- leave/absence
- referral recruiting
- security incidents
- ISMS/P-Mark mechanics

Those depend on a stable employee-data foundation but should be separate features.

## 11. Suggested implementation order after current merge queue

1. Merge/stabilize EMPLOYEE-UI-1A.
2. EMPLOYEE-DATA-1A: additive domain/save model.
3. EMPLOYEE-DATA-1B: read-only projection/UI.
4. EMPLOYEE-DATA-1C: assignment-completion history accumulation.
5. Only then select one gameplay integration (qualification or history-based Fit), with its own balance tests.

## 12. Stop conditions

Stop and split the task if:

- implementing display requires changing matching/payroll/game balance
- save migration cannot be additive and deterministic
- history accumulation cannot reliably distinguish active vs completed assignments
- the added static sections push existing critical action CTAs out of reach without a deliberate navigation redesign
