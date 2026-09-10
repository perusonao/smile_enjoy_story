# SES FIRST-FUN-YEAR P1: Employee Roster Management Data — Fresh Audit (Phase A)

Issue: #235
Status: **READ-ONLY Fresh Audit — no production code / tests / workflow changed**
Audited base: `origin/main` (fetched explicitly, default branch NOT used)
Audited SHA: `160b78ab972b00d787dc827620c23e1335144728`
Report written at: 2026-09-10T14:03Z (issue opened 2026-09-10T13:56:58Z)

## 0. Current status

Phase A audit complete. All 8 authority items required by the issue have been traced to
their concrete source in `origin/main`. Two of the eight (年齢/生年月日, 性別) have **no
authority anywhere in the codebase**, and a third (単金 / current-project unit price) has
**no per-employee/per-assignment authority** — only a flat, uniform constant that is not
tied to any specific project. The remaining five items (氏名, 月給, スキル, 経験年数,
参画状況) already have a single, unambiguous authority that is safely reachable from the
UI layer that would host the roster card.

## 0.1 Next action

Phase B, split as recommended in §7 below. Do not start Phase B until this report has
been read by a human reviewer, per the issue's Definition of Done for Phase A.

## 0.2 Actual elapsed time / Revised ETA

- Actual elapsed time for this Phase A audit: ~6–7 minutes of wall-clock session time
  (issue opened 13:56:58Z, this report written 14:03Z — a single continuous session, no
  interruptions, no re-audits needed).
- Revised ETA for Phase B: unchanged from the issue's own P1 sizing. §7 gives a two-part
  split; Part 1 (salary/skill/experience/status/name — all pre-existing authority, no
  save-schema change) is a small, same-day change. Part 2 (age/gender/unit-price data
  model extension, if the product decision in §5.4 is to add them) is a separate,
  additive save-schema change and should be sized and reviewed on its own.

## 1. Which screen this audit targets

**Important disambiguation, established before auditing individual fields.** This
repository ships two parallel player-facing experiences from the same `lib/domain` /
`lib/game/engine` core-domain layer:

- **`development` experience** (`AppExperience.development`, the URL default) —
  `lib/ui/engineers/engineer_list_screen.dart`, backed by `lib/domain/models/engineer.dart`
  / `Applicant` / `lib/game/engine/*`.
- **`publicDemo01` experience** (`?experience=public-demo-01`) —
  `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`'s `_employeeRosterSection()`
  ("社員一覧・現在状態", Section 1), backed by `lib/game/public_demo/*`
  (`PublicDemoEngineerSales`, `PublicDemoEngineerRuntime`, `PublicDemoApplicant`,
  `PublicDemoAssignment`, `PublicDemoSalary`).

Every regression risk Issue #235 names — Package B / PR #233 (`営業可能`/`研修が必要`
clarity), #228 (April→May assignment materialization), Opening Context #229/#230 — is
implemented entirely inside `lib/game/public_demo/*` and
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`. PR #233's own body confirms
it edited `public_demo_01_placeholder_screen.dart` and `public_demo_employee_visual.dart`
only. This audit therefore treats **the `publicDemo01` roster (Section 1,
`_employeeRosterSection()` / `_employeeRosterCard()`)** as the "社員タブ" the issue means,
and traces every item's authority inside that experience's domain layer. Where the
`development` experience's model differs materially, it is noted in the same row for
completeness, but it is not this audit's implementation target.

Current `_employeeRosterCard()` (public_demo, today) shows: avatar, `e.name`, a status
badge (`_currentEmployeeStatusLabel` / `_employeeStatusTone`), and — when a runtime
exists — a primary-skill capability bar (`_primarySkillDisplayFor`). It shows nothing
else: no age, gender, salary, experience years, or unit price.

## 2. Authority table

| # | 項目 | 現在のauthority | 初期社員 (eng-01/02) での保持場所 | 採用社員 (hired applicant) での保持場所 | save/reload persistence | UIから安全に取得できるか | data gap | Phase Bで必要な最小変更 |
|---|---|---|---|---|---|---|---|---|
| 1 | 氏名 | `PublicDemoEngineerSales.name` (String) | Hardcoded literal in the initial-sales-entry constructor (`公開Demo` founding roster; e.g. `'佐藤 健'`, `'鈴木 葵'` — same literal also lives on `publicDemoInitialAssignments`'s `engineerName`, `lib/game/public_demo/public_demo_assignment.dart:219,227`) | `PublicDemoEngineerSales.fromApplicant(applicant)` reads `PublicDemoApplicant.name`, itself drawn from `surnamePool`/`givenNamePool` in `lib/domain/generation/name_pool.dart` at applicant generation | Yes — `PublicDemoEngineerSales` round-trips via `workflow.engineers`/save codec, already exercised by existing roster tests | **Yes, already used** — `e.name` is already read directly in `_employeeRosterCard` today | None | None — already displayed |
| 2 | 年齢 / 生年月日 | **No authority exists** | — | — | — | No — nothing to read | **Confirmed gap.** `PublicDemoApplicant` (public_demo) has no age/birthdate field at all. Even the `development` experience's `Applicant.age` (`lib/domain/models/applicant.dart:22`) is not wired into public_demo anywhere, and it is a static hire-time snapshot only (no in-game aging) even there. | **New field required.** See §5.1 — minimal, additive `age: int` (not birthdate/calendar-derived) on `PublicDemoApplicant`/founding-engineer seed data, generated once at applicant/candidate creation, never mutated |
| 3 | 性別 | **No authority exists anywhere in the repository** | — | — | — | No — nothing to read | **Confirmed gap**, and deliberately so: `lib/game/engine/prologue_engine.dart:14-18` documents that `Applicant`/`PublicDemoApplicant` "has no gender field at all, so there is nothing here for a mechanical bias to attach to" — the `development` experience's `_maleGivenNames`/`_femaleGivenNames` split there is a *cosmetic name-pool partition only*, never a stored attribute, and public_demo's own `name_pool.dart` doesn't even have that split. Out-of-scope item "年齢・性別によるゲーム内能力差や採否差" in the issue is consistent with this — the domain was deliberately built gender-blind. | **Do not add a mechanical field.** See §5.2 — if display is required, this needs a genuinely new, explicit product decision (not inferable from name text), and a minimal opt-in cosmetic-only field, kept fully isolated from any scoring/matching path, per the existing design precedent (§1's own doc comment) |
| 4 | 月給 | `PublicDemoSalary.currentMonthlySalaryFor(employeeId, applicants: s.applicants, month: s.month)` (`lib/game/public_demo/public_demo_salary.dart`) — the same function `PayrollEngine`-equivalent totals for public_demo are built from (`bonusEligibleMonthlySalaryTotal`) | `PublicDemoSalary._initialEngineerMonthlySalaries` fixed map (`eng-01`→300,000 / `eng-02`→250,000) | `PublicDemoApplicant.acceptedMonthlySalary` / `.salaryForMonth(month)` (post-raise-aware) | Yes — `PublicDemoApplicant` and the fixed initial-salary constants both round-trip; `acceptedMonthlySalary`/raise fields are already part of the save codec | **Yes, reachable** — `s.applicants` and `s.month` are both already available getters on the roster screen's `State` object; `currentMonthlySalaryFor` is a pure static call, no new plumbing needed beyond passing the two existing values in | None for the value itself | None — wire the existing call into the card; do not invent a second salary source or recompute it |
| 5 | スキル | `s.runtimeForOrNull(engineerId)` → `PublicDemoEngineerRuntime.primaryLanguage` / `.actualCapability` (already surfaced via `_primarySkillDisplayFor`) | `publicDemoInitialEngineerRuntimes` literal | `PublicDemoEngineerRuntime.fromApplicant(applicant)` | Yes — `engineerRuntimes` list is part of `PublicDemoState` and round-trips | **Yes, already used** — the roster card already renders this via `PublicDemoEmployeeSkillBar` | None | None — already displayed; do not duplicate SkillSheet's separate sales-facing representation (`PublicDemoSkillSheetDisplayFactory`) here |
| 6 | 経験年数 | `PublicDemoEngineerRuntime.totalItExperienceMonths` (int, months) | `publicDemoInitialEngineerRuntimes` literal (36 / 24 months) | `PublicDemoEngineerRuntime.fromApplicant` carries `applicant.experienceMonths` forward (Codex P1 fix, PR #212 — this is the one place a prior bug silently dropped this fact, now fixed and covered) | Yes — same `engineerRuntimes` persistence as §5 | **Yes, reachable** — same `s.runtimeForOrNull(id)` call the skill bar already makes | None | None — reuse `s.runtimeForOrNull(id)?.totalItExperienceMonths`; reuse the existing `formatExperience()`-style month→year formatting already used elsewhere in the app (`lib/ui/widgets/labels.dart:186`) rather than inventing a second formatter |
| 7 | 参画状況 | `_currentlyAssignedEngineerIds` (⊇ `workflow.assignedEngineerIds`) for 参画中; `s.trainingSelections` for 研修; else 待機 — exactly the two facts `_employeeStatusTone`/`_currentEmployeeStatusLabel` already read | `workflow.engineers` entry present from game start; assignment membership from `publicDemoInitialAssignments` | Same membership check, populated by `PublicDemoWorkflowState.assignOrderedForMay`/`closeApril`/`closeMay` (the exact machinery #228 fixed) | Yes — `assignments`, `trainingSelections`, and engineer stage are all part of the save codec, and #228's fix specifically hardened this against April→May loss | **Yes, already used** — the roster card already renders this via `PublicDemoEmployeeStatusBadge` | None | None — already displayed; Phase B must not introduce a second status-deriving switch. Reuse `_currentEmployeeStatusLabel`/`_employeeStatusTone` verbatim |
| 8 | 現在案件の単金 | **No per-employee/per-assignment authority.** `PublicDemoAssignment` (`lib/game/public_demo/public_demo_assignment.dart`) has no `monthlyRate`/unit-price field at all — not on the struct, not in `toJson`/`fromJson`, not in any of its four construction sites (`publicDemoInitialAssignments`, `withAssignmentUpdate`, `assignOrderedForMay`'s two call sites). The only revenue-facing rate that exists is `PublicDemoRevenue.ratePerAssignedEngineer` — a **flat constant (¥600,000/月)** applied uniformly per assigned headcount (`monthlyRevenueForAssignedCount`), not per project and not per employee. A project-specific `monthlyRate` *does* exist, but only on the pre-assignment candidate/offer objects (`PublicDemoSeededProjectGenerator`/matching candidates) shown before an order is placed — it is discarded once the order becomes an assignment; it is never copied onto `PublicDemoAssignment`. | `publicDemoInitialAssignments` carries no rate at all | Same — `assignOrderedForMay` never receives or stores a rate | N/A — nothing to persist today | **No — genuinely absent**, not merely hard to reach | **Confirmed gap**, and the most consequential one: revenue accounting for an assigned engineer does **not** vary by project in this model at all | **New field or a "no per-project rate exists" display decision required.** See §5.3 — either (a) persist the order-time candidate `monthlyRate` onto `PublicDemoAssignment` as a new additive field (save-schema impact), sourced verbatim from the same candidate object the player already saw before ordering, never fabricated after the fact; or (b) if the product intent is that the flat `ratePerAssignedEngineer` constant genuinely *is* every assigned employee's authoritative rate, display that constant directly with no new field — but this must be an explicit product decision, not an audit assumption, because it changes what "単金" means to the player from "this employee's negotiated rate" to "a company-wide flat rate" |

## 3. 初期社員 vs 採用社員 — data-shape difference (issue's question #8)

Confirmed structural difference, but it does **not** create a read-side gap:

- **氏名 / 月給**: founding engineers (eng-01/eng-02) are backed by hardcoded literals
  (`engineerName` on `publicDemoInitialAssignments`, `_initialEngineerMonthlySalaries`
  map), while hired applicants are backed by `PublicDemoApplicant.name` /
  `.acceptedMonthlySalary`. Two different storage shapes.
- **スキル / 経験年数 / 参画状況**: both use the *same* runtime classes
  (`PublicDemoEngineerRuntime`, `PublicDemoEngineerSales`, `PublicDemoAssignment`) —
  founding engineers just get literal-constructed instances instead of
  `.fromApplicant()`-constructed ones. Identical shape, different construction site.

Despite the storage-shape difference for name/salary, every read the roster card would
make already goes through a **single unifying accessor** that internally branches on
both sources (`_engineerName()` at `public_demo_01_placeholder_screen.dart:2357`;
`PublicDemoSalary.currentMonthlySalaryFor` at `public_demo_salary.dart:35`). Phase B can
call these unifying accessors directly and never needs to know which underlying storage
an employee came from — this is not a new risk to design around, it is already solved.

Age/gender/unit-price have no authority in *either* source, so this question does not
apply to them (§5).

## 4. save/reload persistence — summary

All five items with existing authority (氏名, 月給, スキル, 経験年数, 参画状況) are
already part of `PublicDemoState`'s JSON round trip (`schemaVersion == 1`,
`lib/game/persistence/public_demo_save_codec.dart`) and already exercised by existing
save-codec tests, including the specific April→May timing fix in #228 and the
experience-months carry-forward fix in PR #212. **No persistence gap exists for these
five items** — Phase B display work does not touch the save schema for them.

Age/gender/current-project unit price have no field to persist today (§2, §5) — any of
them, if added, is additive-only (§5.4/§6) and never a `schemaVersion` bump by itself,
per the same backward-compatible-default pattern every other additive field in this save
codec already follows (`?? default` in every `fromJson`).

## 5. Data gaps — minimal extension proposals

The issue is explicit: **do not add UI-local placeholder/guessed values, and do not
invent a display-only threshold.** Nothing below is a UI value — every proposal is an
additive employee/master-data field with a real generation-time or order-time source,
consistent with how every other field in these models already works.

### 5.1 年齢 (age)

- Add `age: int` to `PublicDemoApplicant` (and the equivalent founding-engineer seed
  constants), generated once at applicant/candidate creation from the same kind of
  generation logic `applicant_generator.dart`'s `development`-experience `age` already
  uses (real generation, not a fixed display number).
- Static after hire — the existing `development`-experience `Applicant.age` is likewise
  never incremented in-game, so this is consistent with existing precedent, not a new
  design decision.
- Save impact: additive field on `PublicDemoApplicant`/founding-engineer save data;
  `fromJson` defaults for pre-existing saves need a documented, non-fabricated fallback
  (e.g., a fixed default consistent with the founding engineers' already-established
  backstory) — same pattern as `totalItExperienceMonths`'s own migration default.
- Birthdate is explicitly **not** recommended: the issue only asks to display "年齢", and
  a birthdate would require a calendar authority (real-world date vs in-game week/month)
  that does not exist anywhere in this game's time model — adding one would be a second,
  unrelated authority just to derive a value already obtainable directly as an int.

### 5.2 性別 (gender)

- **This is the one item where "minimal data extension" may not be the right call at
  all**, and the audit flags it rather than assumes it. The domain was built
  deliberately gender-blind (`prologue_engine.dart:14-18`), and the issue's own
  out-of-scope list ("年齢・性別によるゲーム内能力差や採否差") confirms the game never
  wants gender to affect anything mechanical — consistent with that existing design
  intent.
- If display is still wanted, the only safe shape is a purely cosmetic, non-authoritative
  field (e.g., an enum with no scoring/matching consumer, generated alongside the name at
  applicant-creation time — not derived from the given name text at display time, which
  would silently encode a mechanical-looking correlation into presentation even without
  being "used" by any rule).
- Recommend surfacing this as an explicit product question before Phase B, not deciding
  it inside the implementation PR.

### 5.3 単金 (current-project unit price)

Two genuinely different options, both real (§2 row 8) — this needs a product decision,
not a default:

- **(a) Persist the order-time rate.** Add `monthlyRate: int?` to `PublicDemoAssignment`,
  populated from the same candidate/project `monthlyRate` the player already saw and
  accepted before the order became an assignment (`PublicDemoSeededProjectGenerator`
  candidate, or the founding-engineer template's own already-fixed backstory rate if one
  is authored for eng-01/eng-02). `null` for any assignment created before this field
  existed (no retroactive fabrication) and for a founding-engineer assignment if no
  authored rate is decided for it. This makes 単金 a genuine per-employee fact that can
  vary, matching what the card mockup in the issue implies ("単金 65万" as a specific,
  presumably project-dependent number).
- **(b) Display the flat authoritative constant.** Show
  `PublicDemoRevenue.ratePerAssignedEngineer` for every currently-assigned employee,
  unconditionally. This requires no save-schema change at all, but it is **not really
  "this employee's unit price"** — it is the company-wide flat rate the finance model
  actually uses for revenue, and showing it per-employee card would misleadingly imply
  project-specific variance that does not exist in this model today.
- This audit does not pick between (a)/(b) — that is a Phase B product decision to make
  explicitly, exactly as the issue instructs ("表示用に再計算ルールを作らないでください"
  — recomputing/deriving a rate for display when none is persisted would violate that
  instruction, so (b)'s "flat constant" framing must be presented to the player honestly
  if chosen, not disguised as a per-project figure).

### 5.4 Combined save-schema impact if all three are added

All three are additive fields on existing, already-versioned structures
(`PublicDemoApplicant`, founding seed constants, `PublicDemoAssignment`). None of them
requires a `schemaVersion` bump under the codec's existing "absent → deterministic
default" migration pattern, provided each default is documented and non-fabricated
(consistent with `totalItExperienceMonths`'s own PR #212 precedent). If (5.3)'s option
(a) is chosen and no authored rate exists for legacy/founding assignments, the default
must render as an honest "—" (per the issue's own card mockup), never a guessed number.

## 6. UI card — 360x800 / 390x844

Existing `_employeeRosterCard` already renders, per row: avatar, name, status badge, and
a skill bar (2 visual rows). The issue's own mockup is 3 lines of text:

```text
佐藤 健　28歳・男性
参画中　Java / Spring　経験5年
月給 32万 ｜ 単金 65万
```

Adding 年齢/経験年数/月給/単金 as a second text line (age + existing skill label +
experience) and a third line (salary + unit price, `—` when not currently assigned)
fits within the existing card's row budget without adding a new visual chrome element —
the skill bar can stay as-is or be folded into line 2. This audit does not lock the exact
line layout (that is Phase B/UI work), but confirms no additional card *height* class is
needed beyond what `docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/` already
established for this section (`01_Employee_LayoutDraft.png` /
`02_Employee_DetailedLayout.png` exist as prior references for this exact section) — the
existing `test/ui/public_demo/*` 360x800/390x844 overflow-check pattern
(`_targetSizes = [Size(360, 800), Size(390, 844)]`) already covers this screen and should
be extended, not replaced, for Phase B.

Detail-level information — full career history, certifications, process-by-process
technology breakdown, team size, résumé qualifications — is already correctly kept out
of this card and routed to the SkillSheet sheet (`_viewEmployeeSkillSheet`,
`PublicDemoSkillSheetDisplayFactory`) or the separate `EMPLOYEE-DATA-1` design track
(`docs/design/SES_EMPLOYEE-DATA-1_Expansion_Design.md`, `development`-experience-scoped,
covers `Engineer.careerHistory`/certifications — a different item set from this issue,
not overlapping with the 8 fields audited here). Phase B must not pull any of that back
into the roster card.

## 7. Recommended Phase B split

1. **Phase B-1 (no save-schema change).** Wire 月給, スキル (already shown), 経験年数,
   参画状況 (already shown), 氏名 (already shown) onto the roster card via the existing
   accessors in §2/§3. Extends `_employeeRosterCard()` and its widget tests only.
2. **Phase B-2 (product decision required first, then additive save-schema change).**
   年齢 (§5.1) and, if approved, 性別 (§5.2) as new `PublicDemoApplicant`/founding-seed
   fields.
3. **Phase B-3 (product decision required first, then additive save-schema change).**
   単金 — pick option (a) or (b) from §5.3, then implement.

B-2 and B-3 are independent of each other and of B-1; none blocks the others structurally,
but B-2/B-3 should not start implementation until their respective product decisions are
made, per the issue's own "UIへ仮値・推測値を追加しない" rule.

## 8. Predicted changed files (Phase B)

Phase B-1 (no schema change):
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (`_employeeRosterCard`,
  possibly `_employeeRosterSection`)
- `lib/ui/public_demo/public_demo_employee_visual.dart` (if a new compact row widget is
  needed, following PR #233's precedent)
- `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` and/or a new focused
  roster test file, plus the existing 360x800/390x844 viewport suite

Phase B-2 (age/gender, additive schema):
- `lib/game/public_demo/public_demo_recruitment.dart` (`PublicDemoApplicant`)
- `lib/game/public_demo/public_demo_assignment.dart` or wherever founding-engineer seed
  identity constants live, for eng-01/eng-02's authored values
- `lib/game/persistence/public_demo_save_codec.dart` migration-default coverage
- corresponding domain/save tests

Phase B-3 (単金, additive schema, option (a)):
- `lib/game/public_demo/public_demo_assignment.dart` (`PublicDemoAssignment`,
  `toJson`/`fromJson`, all four construction sites)
- `lib/game/public_demo/public_demo_workflow_state.dart`
  (`assignOrderedForMay`/`withAssignmentUpdate` call sites that construct a new
  assignment)
- `lib/game/persistence/public_demo_save_codec.dart` migration-default coverage
- corresponding domain/save tests

No file outside `lib/game/public_demo/*`, `lib/ui/public_demo/*`, and their matching
`test/**/public_demo/*` trees is expected to change. In particular, no file PR #234
(Monthly Report) touches (`public_demo_monthly_cash_flow.dart`,
`public_demo_monthly_report_snapshot.dart` and their tests) is expected to be touched by
this issue's Phase B, and no file PR #233 already changed
(`public_demo_01_placeholder_screen.dart`, `public_demo_employee_visual.dart`) is
expected to conflict on unrelated lines — but both files are shared editing surfaces, so
Phase B should rebase onto whichever of #233/#234 merges first rather than assuming a
clean merge.

## 9. Regression cross-check

- **PR #233 (Package B)**: touches `_currentEmployeeStatusLabel`/`_employeeStatusTone`
  and adds `PublicDemoEmployeeStatusTone.readyForSales`. Phase B-1 reuses these verbatim
  (§2 row 7) and adds new lines to the same card function PR #233 already edits —
  same-file overlap, not same-logic overlap. No conflict with the underlying authority.
- **PR #234 (Monthly Report)**: touches only `public_demo_monthly_cash_flow.dart` and a
  new `public_demo_monthly_report_snapshot.dart`. Zero file overlap with this issue's
  predicted Phase B changes (§8).
- **#228 (April→May Assignment regression, closed/merged)**: the fix
  (`assignOrderedForMay` idempotent upsert) is exactly the authority §2 row 7 (参画状況)
  and any §5.3-option-(a) `monthlyRate` field would need to flow through. Confirmed: the
  idempotent-upsert `copyWith` in `PublicDemoAssignment` (`lib/game/public_demo/public_demo_assignment.dart:78-102`)
  already preserves every existing field it doesn't explicitly update — a new
  `monthlyRate` field added there would need the same "preserve unless explicitly passed"
  treatment to avoid resurrecting the class of bug #228 fixed.
- **Opening Context (#229/#230)**: not touched by any file in §8's prediction.

## 10. Final verdict

**B. GO WITH DATA MODEL CHANGE.**

Rationale: 5 of 8 fields (氏名, 月給, スキル, 経験年数, 参画状況) are GO as-is — real
authority exists, is already reachable from the roster screen, and needs no save-schema
change (§7 Phase B-1). The remaining 3 fields (年齢, 性別, 単金) have no adequate existing
authority and require an explicit, additive employee/master-data extension before they
can be displayed truthfully (§5, §7 Phase B-2/B-3) — exactly the situation Issue #235
itself anticipated and asked this audit to identify rather than paper over with UI-local
placeholder values.

## 11. Unresolved items (for Phase B kickoff, not for this audit to decide)

1. **性別**: should it be displayed at all, given the domain's deliberate gender-blind
   design (§5.2)? Needs an explicit product decision, not an implementation default.
2. **単金**: option (a) persist an order-time rate, or option (b) display the flat
   `ratePerAssignedEngineer` constant honestly labeled as company-wide (§5.3)? Needs an
   explicit product decision before Phase B-3 starts.
3. **年齢 for founding engineers**: no authored age currently exists for eng-01/eng-02;
   Phase B-2 needs an authored, non-arbitrary value (e.g., consistent with their existing
   backstory/capability level), not a placeholder.
4. Exact card line layout for Phase B-1 (§6) — left to the implementing PR's own
   360x800/390x844 verification, not fixed by this audit.
