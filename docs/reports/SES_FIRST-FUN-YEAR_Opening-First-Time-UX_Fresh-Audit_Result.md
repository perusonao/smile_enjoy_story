# SES First Fun Year — Opening / First-Time UX Fresh Audit (Result)

**Type:** Read-only design audit. No production code, tests, or workflow files were changed.

- Audited `origin/main` SHA: `aa8fe3f84ce022ecaa57f108a9cce5aff00de5e8`
  (fetched fresh at session start; this matched the reference SHA supplied in the task,
  confirmed by `git rev-parse origin/main` rather than assumed)
- Audit window (UTC): 2026-09-10T07:46:47Z → 2026-09-10T07:56:46Z (~10 min actual processing time)
- Related issues: #225 (Post-Balance Human Replay), #121 (older Opening/tutorial issue — no
  local report cross-references #121 by number; see §8)
- Changed production files: **NONE**
- Changed tests: **NONE**
- Report committed at: this file only

---

## 0. Critical structural finding — this repo ships TWO independent "openings"

This is the single most important fact this audit surfaces, and it reframes every other
finding below. The repository contains **two functionally separate first-time experiences**,
selected by URL at boot (`lib/app/app_entry.dart`, `resolveAppExperience`):

| Experience | Entry | Engine | Reachable from |
|---|---|---|---|
| **Development** (the "real" game) | root URL, no fragment | `PrologueEngine` + `GameEngine` (`lib/game/engine/prologue_engine.dart`) | `StartChoiceScreen` → 【初心者モード】or【自由モード】 |
| **Public Demo** | `#/public-demo-01` fragment | a fully parallel simulation (`lib/game/public_demo/*`, ~40 files) rendered by one 5,300-line screen (`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`) | direct link / QA build |

They do not share state, save data, UI, or even most vocabulary. Evidence that Issue #225's
Human Replay was conducted **against Public Demo, not Development**:

- The fixed navigator name "Hiyori" (佐倉ひより) referenced in the task background is, in code,
  explicitly documented as **"the Public Demo's fixed navigator"**
  (`lib/presentation/home/models/home_navigator_display.dart:22,44,48`). Development's navigator
  is a procedurally-generated 総務 employee with a random name and flavor line
  (`PrologueEngine._generateNavigator`, `prologue_engine.dart:113-124`) — there is no "Hiyori" in
  Development at all.
- The prior triage doc (`docs/reports/SES_FIRST-FUN-YEAR_Post-Balance_Human-Replay_Fresh-Triage.md`)
  cites `PublicDemoInterviewEvaluator.evaluate`, `PublicDemoInterviewResultDialog`,
  `PublicDemoProjectInterviewDialog`, and terms like 「案件紹介」／「発注を受注する」that only exist in
  `lib/ui/public_demo/*` / `lib/game/public_demo/*`.
- Development's opening (Founding Prologue, Playable 0.5A) already implements company naming,
  president naming, a navigator greeting, purpose explanation, and a fixed-cost mention — i.e.
  most of what Issue #225 says is missing. Public Demo implements **none** of those (see §1).

**Implication:** this task's background description matches Public Demo's actual opening, not
Development's. All AUDIT sections below are reported **per experience**, because "the opening"
is not one thing in this codebase, and any implementation package must say explicitly which one
it targets. Recommended packages in §9 target **Public Demo**, since that is what Issue #225
tested and where the gaps are real; Development is cited throughout as a working reference
pattern already proven in this same codebase.

---

## 1. AUDIT 1 — Current Opening trace

### 1A. Development (`PrologueEngine`, `lib/ui/prologue/prologue_screen.dart`)

Entry: `StartChoiceScreen` → 【初心者モード】(recommended) starts `PrologueEngine.newGame()`,
zero engineers, one 総務 employee. Stage machine (`PrologueEngine.stage`, `prologue_engine.dart:729-775`)
derives the screen purely from facts in `GameState`/`PrologueState` — no separate UI flag can get
out of sync with game state.

Trace, in order:

1. `presidentNaming` — 会社名 / 社長名 text fields, pre-filled with a random plausible pair,
   editable, re-rollable (`_CompanySetup`, `prologue_screen.dart:218-310`).
2. `intro` — two-screen 総務 greeting: (a) "技術者を採用し、案件へ参画させ、取引先から売上を得ます"
   (purpose), (b) "事務所は小規模オフィス(家賃 月¥150,000)…社員がいなくても、家賃や総務の給与などの
   固定費は毎月かかります" (fixed-cost warning, pointing at the live Management HUD)
   (`_Intro`, `prologue_screen.dart:312-353`).
3. `week1Recruitment` — player picks a recruitment medium (no auto-selection even in Beginner
   Mode); 総務 only *recommends* free recruitment.
4. `week2CandidateSelect` / `week2Interview` / `week2Decision` — two candidates, one real
   interview, explicit hire/reject decision.
5. `week3SkillSheet` — SkillSheet **confirm** screen (see §2).
6. `week3Sales` → `week4*` — pre-joining sales, interview request, upper-company interview,
   client interview, contract.
7. `complete` → `freeManagement` — `FirstContractCelebration`, explicit "経営を始める" tap.

### 1B. Public Demo (`PublicDemoState.aprilStart`, `public_demo_01_placeholder_screen.dart`)

Entry: a direct URL (`#/public-demo-01`), no start-choice screen of its own. Boots straight
into **month 4 (April)**, already founded, with:

- ¥4,000,000 cash
- 2 named engineers already employed and waiting: 佐藤健 (Java, capability 78) and
  鈴木葵 (JavaScript, capability 52)
- 1 admin/総務 employee ("Hiyori" in UI copy)
- Sales capacity 4, sales used 0

There is **no** company-setup screen, **no** president-naming, and (confirmed by exhaustive
grep across `lib/ui/public_demo/` and `lib/game/public_demo/` for `ようこそ|はじめまして|初めて|
説明|チュートリアル|オンボーディング|Onboarding|firstTime|hasSeenIntro|introShown|showIntro`)
**zero onboarding/welcome copy of any kind**. The player's first frame is the live management
dashboard itself, mid-fiscal-year in narrative terms (labelled month 4) with a pre-existing
company, pre-existing staff, and pre-existing constraints, none of which are explained.

### 1C. IMPLEMENTED / PARTIAL / MISSING matrix

| Item | Development | Public Demo |
|---|---|---|
| 会社名設定 | **IMPLEMENTED** — `_CompanySetup` | **MISSING** — no such field/screen exists in `PublicDemoState` |
| プレイヤー/社長名設定 | **IMPLEMENTED** — same screen | **MISSING** |
| Hiyori/総務の初回挨拶 | **PARTIAL** — a 総務 greets, but is a random employee, never "Hiyori" | **MISSING** — Hiyori is present throughout play as advisor copy, but there is no *first-contact greeting/introduction* beat at all |
| ゲーム目的説明 | **IMPLEMENTED** — intro message 1 | **MISSING** |
| 倒産条件説明 (at open) | **MISSING** — bankruptcy is never mentioned until `others_screen.dart`'s reactive "資金がマイナスになります" warning or the terminal `game_over_screen.dart` | **MISSING** — 倒産 copy exists only reactively (`public_demo_cash_shortage_card.dart`, the bankruptcy result screen), never proactively at open |
| 初期現金説明 | **PARTIAL** — visible live on `ManagementHud` from the first Prologue frame, never narrated in text | **PARTIAL** — visible on the dashboard, never narrated |
| 給与 (initial engineer) | **PARTIAL** — implied by SkillSheet confirm screen showing the hired candidate; no explicit "¥X/month" salary line in intro copy | **MISSING** — ¥300,000 / ¥250,000 per-engineer salary never surfaced as onboarding text (visible only inside detail views later) |
| 総務給与 | **MISSING as a number** — never stated in copy (¥280,000 constant exists, HUD shows aggregate burn only) | **MISSING** (¥200,000 constant, same pattern) |
| 家賃/固定費 | **PARTIAL** — intro message 2 names rent (¥150,000) explicitly; the ¥100,000 other-fixed-cost line and total monthly burn are never spelled out as one number | **MISSING** — no text ever states the ¥50,000 other-fixed-cost or the combined baseline burn |
| 初期社員紹介 | **IMPLEMENTED** — week3SkillSheet screen names the hired candidate and shows their SkillSheet | **PARTIAL** — the roster shows 佐藤/鈴木 with a one-line summary each, but nothing frames them as "these are your two founding employees, here is what each can/can't do yet" |
| 最初に何をすべきかの説明 | **IMPLEMENTED** — every Prologue stage is a single `NavigatorCard` with exactly one CTA (`week1Recruitment`'s "どの募集方法を使いますか？" etc.) | **PARTIAL** — a "今やるべき社員アクション" card per employee exists, and a capability-lock banner explains why 鈴木 can't sell yet (see §3), but there is no single "do this first" beat at the very first frame |

---

## 2. AUDIT 2 — SkillSheet Gate

### Technical evidence

Both experiences implement **the identical pattern**: a boolean flag flips to `true` the moment
the player taps a "confirm" button after *viewing* the SkillSheet, and that flag — not any
change to the SkillSheet's actual content — is what unlocks the next stage.

**Development:**
```dart
// prologue_engine.dart:481
static GameState confirmSkillSheet(GameState state) =>
    state.copyWith(prologueState: state.prologueState.copyWith(skillSheetConfirmed: true));

// prologue_engine.dart:756 (inside PrologueEngine.stage)
if (!ps.skillSheetConfirmed) return PrologueStage.week3SkillSheet;
```
The UI button is literally labelled "SkillSheetを確認しました" (`prologue_screen.dart:639`) — a
one-tap acknowledgement, not an edit or a decision. Tapping it is the *only* precondition;
nothing about the SkillSheet's content is read or validated.

**Public Demo:**
```dart
// public_demo_workflow_state.dart:334-351
PublicDemoWorkflowState beginPreEntrySkillSheet(String applicantId) => _withApplicant(
  applicantId,
  (applicant) => applicant.stage == PublicDemoApplicantStage.offerAccepted &&
          applicant.canEnterPreJoinSales
      ? applicant.copyWith(stage: PublicDemoApplicantStage.preEntrySkillSheet)
      : applicant,
);

PublicDemoWorkflowState beginPreEntrySelling(String applicantId) => _transitionApplicantStage(
  applicantId,
  from: const {PublicDemoApplicantStage.preEntrySkillSheet},
  to: PublicDemoApplicantStage.preEntrySelling,
);
```
Same shape: `offerAccepted → preEntrySkillSheet → preEntrySelling`, gated by a stage transition
call the UI fires on a confirm tap, not by any read of the sheet's fields.

### Classification

**B — tutorial-only gate, in both experiences**, for the specific "confirm you looked" tap.
Nothing in either engine reads the SkillSheet's field values to permit or deny the transition —
only the boolean/stage flag matters. This matches the Human Replay's suspicion exactly: *as a
click gate*, this step has no gameplay authority.

However, this needs one important qualification for Development, which the original Human
Replay finding did not have visibility into: the SkillSheet **itself** is not decorative. Once
past the gate, `SalesEngine.skillSheetMatch(sheet, project)` (`prologue_engine.dart:568`) uses
the SkillSheet's *displayed* values (not the employee's actual skill) to compute match quality
against client projects, and `GameEngine.editSkillSheet` (wired from `engineer_detail_screen.dart`
`_editSkillSheet`, lines 246-286) lets the player inflate displayed language/backend/leader
levels above actual ability for better sales opportunities, at a `SalesEngine.riskLabel` /
`inflationDetails` trust-and-interview-risk cost. That is real, meaningful gameplay authority —
it is simply **not exposed during the gate itself**: the Prologue's `week3SkillSheet` screen is
read-only (`_SkillSheetConfirm`, `prologue_screen.dart:605-643`), and editing only becomes
possible later, from the Engineer Detail screen, post-Prologue.

Public Demo has **no editing capability anywhere** — confirmed by an empty match for
`editSkillSheet|SkillSheetEdit|adjustSkillSheet` across every `public_demo` UI and game file.
Its SkillSheet is purely informational in both the gate and forever after.

### Editable / read-only inventory

| | Development | Public Demo |
|---|---|---|
| Editable fields | Primary-language displayed experience months, displayed Backend level, displayed Leader level (`_editSkillSheet`) — **but only from Engineer Detail, never from the Prologue gate screen** | none |
| Read-only fields | Everything else (DB, Network, Infrastructure, Frontend, qualifications, role history) | Everything (entire sheet) |
| Edit function exists? | Yes — `GameEngine.editSkillSheet`, real risk/reward mechanic | No |
| Gameplay authority | Displayed values feed `SalesEngine.skillSheetMatch` against project requirements; inflation raises `SkillSheetRisk` (interview/trust penalty) | None — sheet has no effect on any roll; matching uses actual capability directly |

**Conclusion for §2:** the "must view SkillSheet before selling" tap itself is category B
(tutorial-only) in both builds. In Development, that is a defensible pacing choice **only if**
the copy is fixed to say what the SkillSheet actually is (a sales profile clients will see, with
optional risky embellishment) — right now the confirm screen states this in one small caption
but the gate exists before the player has ever been told editing is even possible. In Public
Demo, the gate is pure friction: the sheet is inert data, editing doesn't exist, and the human
finding ("SkillSheetが編集できない") is verified true.

---

## 3. AUDIT 3 — Initial Employees

### Development

The Prologue always starts with **zero** engineers; the "initial employee" a new player meets is
whichever March-Week-2 candidate they interview and hire (two auto-generated candidates offered,
themselves chosen from `RecruitmentMediaType`-tendency-adjusted stats — not fixed named
characters). Capability/eligibility is not really a first-5-minutes question here since the
player picks who to hire; the tutorial's job is just walking them through hire → SkillSheet →
sell → interview → contract, which it does end-to-end with an explicit CTA at every step
(§1, `PrologueEngine.canInterviewThisWeek`'s P0 dead-end invariant guarantees this).

### Public Demo

Two **fixed, named** founding engineers exist from the very first frame
(`publicDemoInitialEngineerRuntimes`, `public_demo_engineer_runtime.dart:287-350`):

| Employee | Language | `actualCapability` | `fieldSalesCapabilityRequirement` (60) | Can sell immediately? |
|---|---|---|---|---|
| 佐藤 健 (eng-01) | Java | 78 | met | Yes |
| 鈴木 葵 (eng-02) | JavaScript | 52 | not met | No — needs training first |

`isReadyForFieldSales` (`public_demo_engineer_runtime.dart:82-83`) is a real, derived rule
(`actualCapability >= 60`), not a fake gate — 鈴木 genuinely cannot generate a client interview
until trained above the threshold. This **is** explained in-UI once the player reaches the
Employees tab: a locked card states, verbatim, "営業開始には実力 60 以上が必要です（現在 52）。ま
だ営業を始められません。" (`public_demo_01_placeholder_screen.dart:3338-3346`). That line is
factually accurate and reasonably clear — this is a genuine PARTIAL, not a MISSING, contrary to
what a first read of the Human Replay complaint might suggest.

**What is missing** is context *before* the player ever reaches that card: nothing on first
launch tells the player who these two people are, that they are the company's only two
employees, that one is sales-ready and one is not, or why that split exists (経験/スキルの違い).
The explanation exists at the point of friction, not at the point of introduction — a player has
to go looking (Employees tab) to discover it, and prior work (Issue #168 / `SES_FIRST-FUN-YEAR_
ONBOARDING-1_Result.md`) explicitly logged this exact gap as **Finding B: "already truthfully
explained… reported, not fixed"** and left it unresolved by design choice at the time (scope cut).
Fresh-Auditing this: Finding B is still unresolved on current `origin/main` — confirmed by the
absence of any pre-Employees-tab surfacing of 鈴木's ineligibility.

**Verdict:** "why can't this employee sell" is understandable **once the player finds the right
tab**, but **not** from the opening screen alone — partial credit, not full MISSING.

---

## 4. AUDIT 4 — Opening Economy (authoritative values, both experiences)

All values pulled directly from source constants — no new figures invented.

### Development (`lib/game/models/game_state.dart`, `lib/game/engine/finance_engine.dart`,
`lib/game/models/office.dart`, `lib/game/engine/prologue_engine.dart`)

| Item | Value | Source |
|---|---|---|
| Initial cash | ¥3,500,000 | `startingCash`, `game_state.dart:37` |
| Initial credit | 20 | `startingCredit`, `game_state.dart:38` |
| Office (small) rent | ¥150,000/mo | `officeConfigs[OfficeType.smallOffice]`, `office.dart:45-51` |
| Other fixed cost | ¥100,000/mo | `otherMonthlyFixedCost`, `game_state.dart:41` |
| 総務 (navigator) salary | ¥280,000/mo | `PrologueEngine.generalAffairsSalary`, `prologue_engine.dart:55` |
| First engineer salary | candidate-dependent, ¥380,000–¥520,000 base (±jitter, media multiplier) | `PrologueEngine._buildCandidate` desiredMonthlySalary, `prologue_engine.dart:279,310` |
| March baseline burn (before any engineer joins) | rent + other + navigator = **¥530,000/mo** | `enterAprilWeek1`, `prologue_engine.dart:646-649` |
| Post-join baseline burn | ¥530,000 + engineer salary ≈ **¥910,000–¥1,050,000/mo** | `FinanceEngine.projectedMonthlyBurn` |
| Runway with zero revenue (March) | ≈ 6.6 months | ¥3,500,000 / ¥530,000 |

### Public Demo (`lib/game/public_demo/public_demo_salary.dart`, `public_demo_state.dart`)

| Item | Value | Source |
|---|---|---|
| Initial cash | ¥4,000,000 | `PublicDemoState.aprilStart`, `public_demo_state.dart:166` |
| 佐藤健 salary | ¥300,000/mo | `satoMonthlySalary`, `public_demo_salary.dart:11` |
| 鈴木葵 salary | ¥250,000/mo | `suzukiMonthlySalary`, `public_demo_salary.dart:12` |
| Admin (Hiyori) salary | ¥200,000/mo | `adminMonthlySalary`, `public_demo_salary.dart:13` |
| Other fixed cost | ¥50,000/mo (no separate rent line — bundled) | `otherMonthlyFixedCost`, `public_demo_salary.dart:14` |
| Baseline monthly expense | ¥750,000 (salaries) + ¥50,000 = **¥800,000/mo** | `baselineMonthlyExpenses`, `public_demo_salary.dart:30-31` |
| Runway with zero revenue | exactly 5 months | ¥4,000,000 / ¥800,000 |

Both figures are real, load-bearing engine constants (not UI copy invented for this audit); either
is safe to quote verbatim in future onboarding copy.

### What should be shown at open (recommendation, not implementation)

For whichever experience is fixed: one screen stating, in the player's own numbers pulled from
the constants above — "現金 ¥X で創業。毎月、家賃・総務給与・固定費だけで¥Y が減ります。売上がなければ
Z か月で資金が尽き、倒産します。" This is exactly Development's intro message 2 pattern
(`prologue_screen.dart:329`), just made complete (it currently names rent alone, not the total,
and never states the bankruptcy consequence).

---

## 5. AUDIT 5 — Recommended First-Time Flow, evaluated against the 7-step hypothesis

Evaluating the proposed order (1 company/player name → 2 Hiyori greeting → 3 purpose/goal →
4 cash/fixed-cost/bankruptcy → 5 employee intro → 6 SkillSheet check → 7 first decision):

**Verdict: the order is correct and is already exactly what Development implements**, steps
1–3 and 5–7 (step 4's bankruptcy half is the one gap even there). The hypothesis fails only in
assuming a single fixed "Hiyori" greets the player — Development's navigator is intentionally
randomized, which is a deliberate design choice (flavor variety per playthrough,
`_navigatorFlavors`), not a bug; recommend keeping that as-is for Development, and treating
"Hiyori" as Public-Demo-specific vocabulary only.

For **Public Demo**, none of steps 1, 2 (as a first-contact beat), 3, or 4 exist at all; step 5
exists in weakened form (reachable, not surfaced); step 6 exists as a pure click-gate on new
recruits but never applies to the two founding employees who are simply present from frame one;
step 7 partially exists via the "今やるべき社員アクション" cards but nothing marks it as *the*
first thing to do.

### Should the SkillSheet-before-sales gate be kept, weakened, or removed?

**Recommendation: weaken it from a hard gate to copy-plus-recommendation, in both experiences,
OR keep the hard gate but fix the copy so it explains real gameplay stakes (Development only,
since Development's SkillSheet does carry real stakes once editing is discoverable).**

Reasoning:
- The gate itself changes no simulation state (§2) — removing it costs nothing mechanically in
  either build.
- In Development, the SkillSheet *does* matter later (edit-for-risk mechanic feeding
  `SalesEngine.skillSheetMatch`), so there is a legitimate argument for keeping a soft
  speed-bump — but only if the confirm screen's copy is upgraded to say "this is what clients
  will see; you can inflate it for more opportunities at some risk" **before** the tap, since
  right now the copy undersells why looking matters and editing isn't even offered at this point
  in the flow.
- In Public Demo, the SkillSheet has zero downstream effect (§2) — there is no gameplay
  justification for a hard gate at all. Recommend either removing the gate entirely for Public
  Demo's pre-entry flow, or reducing it to "SkillSheetを見る (推奨)" with sales already available.

Do not implement either change in this task (read-only audit) — recorded as Package B below.

---

## 6. Screens/flows NOT audited in depth (time-boxed out)

- Public Demo's full recruitment pipeline UI beyond the pre-entry SkillSheet/selling stages
  (interview mini-flow, offer/decline copy) — referenced only structurally via
  `PublicDemoApplicantStage`.
- Public Demo's month-to-month HUD/dashboard composition in full (`public_demo_01_placeholder_
  screen.dart` is 5,300 lines; only the opening-relevant sections were read).
- Any Welfare/PC/health-check first-time explanation in either build.

These do not change any conclusion above but are flagged so a follow-up audit doesn't assume
this report covered them.

---

## 7. Unresolved questions (need a human product decision, not further code reading)

1. **Which experience is the actual target for "First Fun Year" polish** — Development (root
   URL, already far along) or Public Demo (the one Issue #225 tested, and the one with the real
   gaps)? The task background reads as if there is one opening; there are two, and they are not
   in the same state of completeness. Recommend confirming this explicitly before scoping
   implementation, since Package A/B/C below are sized for Public Demo specifically.
2. Is Public Demo meant to *become* a scaled-down Development-style prologue (add company/
   president naming, add a real founding sequence), or does its design intentionally start
   mid-story at month 4 with 2 pre-existing staff (a "you just inherited this company" premise)?
   If the latter is intentional, Package A's scope changes from "add a founding sequence" to
   "add a compact context/orientation screen" — materially different effort.
3. Should Development's random-navigator-name design extend to Public Demo (drop the fixed
   "Hiyori" identity), or is Hiyori a deliberate mascot/brand choice for the public-facing build
   that should be preserved and Development should adopt instead? Not decidable from code alone.
4. Issue #121 could not be located or cross-referenced from any file in this repository (no
   report, no code comment cites it by number). If it is still open on GitHub, its content
   should be re-read directly rather than inferred — this audit could not verify how much of it
   the current implementation satisfies, only that no artifact in-repo cites it.

---

## 8. Historical-issue reality check (per instructions: don't take old issues as correct)

The closest in-repo analog to an "old opening/tutorial issue" is the pre-Prologue two-founder
guided tutorial (`FoundingStage`/`FoundingMilestone`/`ProgressionEngine`, Playable 0.4C.1/0.4C.2).
It is **still fully implemented in the codebase** (`progression_engine.dart`, `game_engine.dart`
milestone plumbing, `engineer_detail_screen.dart` UI hooks) but **is no longer reachable from the
live Development start screen** — `StartChoiceScreen` only wires `chooseBeginnerStart()`
(Prologue) and `chooseFreeStart()` (skip-everything); the `chooseGuidedStart()` method that would
enter the old two-founder tutorial exists on `GameController` (line 60-63) but has no caller in
any UI file. Treat that whole subsystem as legacy/dead-UI-path, not as a second live opening —
it is retained only so `GameEngine.newGame()` (still used as the `GameController`'s field
initializer default and by `restart()`) and old saves keep working, and because Prologue
completion auto-marks its milestones done (`enterAprilWeek1`/`completePrologue`,
`prologue_engine.dart:695-697,711`) rather than actually routing through it.

Issue #168 (`SES_FIRST-FUN-YEAR_ONBOARDING-1_Result.md`) already investigated part of this same
ground for Public Demo specifically and left "Finding B" (鈴木's sales ineligibility explanation
placement) explicitly unfixed by scope decision, not by oversight — this audit confirms that gap
is still open on current `main` and is folded into Package B below rather than treated as new.

---

## 9. Recommended implementation packages (max 3)

All three target **Public Demo** (`lib/ui/public_demo/`, `lib/game/public_demo/`), since that is
the build Issue #225's Human Replay actually exercised and where every MISSING item in the
matrix lives. Development is intentionally excluded from new-build recommendations — it already
implements the equivalent flow — but is cited as the pattern to copy.

### Package A — Opening Context

- **Problem:** Public Demo has zero onboarding copy. The player's first frame is a live
  month-4 dashboard with pre-existing company/staff/finances and no framing at all (§1B, §1C).
- **Current implementation:** `PublicDemoState.aprilStart()` constructs state directly; the
  screen renders whatever tab is default with no first-run overlay, dialog, or narrated intro.
- **Proposed behavior:** A one-time, dismissible sequence shown before the first dashboard frame
  (reuse Development's `_Intro` two-card pattern as a template, not its text): (1) who you are /
  what this company is, (2) the authoritative economy numbers from §4 stated as one sentence with
  real figures (¥4,000,000 cash; ¥800,000/mo baseline burn; 5-month runway at zero revenue;
  explicit bankruptcy consequence). Persist a "seen" flag in `PublicDemoState` (new field) so it
  never replays.
- **Files likely affected:** `public_demo_state.dart` (new persisted flag),
  `public_demo_01_placeholder_screen.dart` (new intro overlay/dialog), possibly a new small
  widget file mirroring `NavigatorCard`/`_Intro`'s shape.
- **Domain/state impact:** additive field only; no existing transition, salary, or rent constant
  changes.
- **UI impact:** new first-run screen/dialog; no change to existing tabs.
- **Estimated Claude Code implementation time:** 2–3 hours.
- **Priority: P1** (directly answers the Human Replay's top complaint — "no context at all" —
  but is additive/low-risk, not a correctness bug).

### Package B — Initial Employee / SkillSheet Gate Clarity

- **Problem:** (a) 鈴木's sales ineligibility is truthfully explained but only once the player
  navigates to the Employees tab, never at open (§3); (b) the pre-entry SkillSheet gate for new
  recruits is a pure click-gate with no gameplay effect in Public Demo, and its copy never says
  what the sheet actually is or why viewing it matters (§2, §5).
- **Current implementation:** `beginPreEntrySkillSheet`/`beginPreEntrySelling`
  (`public_demo_workflow_state.dart:334-351`); ineligibility banner only inside
  `_buildEmployeesTab`'s per-employee card (`public_demo_01_placeholder_screen.dart:3324-3346`).
- **Proposed behavior:** Surface both founding employees' status (ready / needs training, with
  the same real numbers the locked-card already computes) inside Package A's opening context, so
  the player learns it once, up front, instead of discovering it by navigating. For the pre-entry
  gate: either drop it to a "推奨" (non-blocking) step, or keep it but add one line stating what
  the SkillSheet is for in this build (currently: nothing, since Public Demo's sheet has no
  downstream effect — so the honest copy is "this is your new hire's profile," not a sales-risk
  explanation borrowed from Development).
- **Files likely affected:** `public_demo_workflow_state.dart` (only if the gate itself is
  weakened/removed), `public_demo_01_placeholder_screen.dart` (copy + the new opening-context
  employee summary from Package A).
- **Domain/state impact:** if the gate is removed, `PublicDemoApplicantStage.preEntrySkillSheet`
  becomes a pass-through rather than a blocking stage — small, contained change confined to the
  `_transitionApplicantStage`/`beginPreEntrySkillSheet` pair.
- **UI impact:** copy changes to an existing card; optional button-enablement change on the
  pre-entry SkillSheet screen.
- **Estimated Claude Code implementation time:** 1.5–2.5 hours.
- **Priority: P1** (directly answers Issue #225's SkillSheet-gate confusion and Issue #168's
  logged-but-unfixed Finding B).

### Package C — First Management Decision

- **Problem:** Even after Packages A/B, nothing marks *one* action as "do this first" on the very
  first dashboard frame — the player is handed two employees, two possible actions per employee,
  a Sales tab, a Recruitment tab, and no ranked next step (§1C, last row).
- **Current implementation:** "今やるべき社員アクション" cards exist per-employee
  (`public_demo_01_placeholder_screen.dart:3268-…`) but are peers, not a single ranked CTA; no
  Home-level "do this next" equivalent to Development's single-`NavigatorCard`-per-stage pattern
  exists in Public Demo.
- **Proposed behavior:** One prioritized banner/card at the top of the first-run dashboard: "まず
  は佐藤さんの営業を開始しましょう（鈴木さんは実力60が必要です、あと8）" — computed from existing
  `capabilityFor`/`fieldSalesCapabilityRequirement`/`readyForFieldSales` data already in the file,
  not new game logic.
- **Files likely affected:** `public_demo_01_placeholder_screen.dart` only (presentation-layer
  composition of existing authoritative values).
- **Domain/state impact:** none — pure read/compose of existing fields.
- **UI impact:** new top-of-dashboard banner, first-run only or persistent (product decision).
- **Estimated Claude Code implementation time:** 1–1.5 hours.
- **Priority: P2** (valuable but the weakest of the three — Packages A+B already give the player
  enough context to find the existing per-employee action cards themselves).

---

## 10. Summary

| Package | Priority | Est. time |
|---|---|---|
| A — Opening Context | P1 | 2–3h |
| B — Initial Employee / SkillSheet Gate Clarity | P1 | 1.5–2.5h |
| C — First Management Decision | P2 | 1–1.5h |

No production code, tests, or CI/workflow files were modified during this audit. This report is
the only artifact committed.
