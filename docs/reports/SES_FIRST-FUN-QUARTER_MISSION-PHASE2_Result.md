# SES First Fun Quarter — Mission System Phase 2 (Progressive Onboarding) — Implementation Result

## Scope

Implements Phase 2 of the Mission System / Beginner Onboarding initiative,
per the task's own instructions and the governing design documents:

- `docs/reports/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Fresh-Audit.md`
- `docs/design/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md`
  §5 (Phase 2 — Mission-Driven Progressive Onboarding)
- `docs/reports/SES_FIRST-FUN-QUARTER_MISSION-PHASE1_Result.md` (Phase 1,
  merged as PR #265)

Goal: replace "SkillSheetを確認してから経営開始" with a progressive flow —
会社設立 → ひよりの短い説明 → 4月の目標 → 経営開始 → 必要になったタイミングで
説明 — using Phase 1's Mission System as the beginner-onboarding authority,
without explaining every feature up front.

**Explicitly out of scope** (per the task's own instruction): SkillSheet
editing, SkillSheet English-label fix, "実力" label change, training
missions, recruitment missions, document screening, pre-entry sales,
accounting/bonus missions, character/event image changes, HOME body layout
changes, Bottom Navigation changes. None of these were touched.

## Base main SHA

`34a8e4d9f8cd79ef7e27d189c1345087d195e4dd` — confirmed via
`git fetch origin main && git rev-parse origin/main` at session start; this
is also the exact SHA the task supplied as "Phase 1 merge SHA" (PR #265),
and `origin/main` had not advanced further at session start. The working
branch (`claude/mission-phase2-progressive-onboarding-a1pwq6`) was found
pointing at a stale ancestor (`f4ca78f`, "Phase 0A/0B") far behind
`origin/main` with no unmerged work of its own
(`git log origin/main..origin/<branch>` = empty), so it was reset to
`origin/main`'s tip before implementation (`git checkout -B <branch>
origin/main`), matching this repo's own convention for a stale branch with
no work to preserve.

## Fresh Audit — before implementing (per the task's own instruction)

Before writing any code, the current (post-Phase-1) state of the Opening
flow, the SkillSheet gate, and the Mission screen's own copy was re-read in
full, specifically to check for the duplicate-copy/duplicate-dialog risk the
task calls out. Two findings shaped the implementation:

1. **The "経営開始前にSkillSheet確認が必須" premise did not match the
   current code.** `PublicDemoOpeningContextScreen` (as shipped) already
   offered two buttons — "まずSkillSheetで2人を確認する" (opens 社員タブ) and
   "4月の経営を始める" (starts management directly) — and **both** already
   dismissed the Opening screen and let the player into HOME/社員. There was
   no domain-level gate anywhere blocking management start on an unconfirmed
   SkillSheet; the real issue was the **framing** — presenting SkillSheet
   confirmation as a competing, seemingly-required first choice, not an
   actual mechanic. This Result faithfully implements the task's "Critical
   change" by removing that dual-CTA framing (a single "経営を始める" CTA
   now ends the Opening flow) and moving SkillSheet confirmation entirely
   into Mission #1 — the *outcome* the task asked for — while reporting
   accurately that no runtime gate needed to be "abolished" in the domain
   sense.
2. **The Just-in-time explanations A–E the task asks for are, in
   substance, already what Phase 1's Mission screen shows.** Each Mission
   tile (`public_demo_mission_screen.dart`, Phase 1) already carries a 目的
   (purpose) / 次の操作 (next action) / ひよりコメント for exactly the A–E
   transitions:
   - A (SkillSheet) → `viewSkillSheet` tile
   - B (営業) → `beginSelling` tile
   - C (案件提案) → `proposeToProject` tile
   - D (面談) → `passPartnerInterview`/`passClientInterview` tiles
   - E (受注→参画, 売上との関係) → `winOrder`/`assignToProject` tiles +
     the MISSION COMPLETE banner, which already states verbatim "参画すると
     売上が発生します。ただし、入金は後になります。"

   Per the task's own UX rule (priority 1: Mission-screen-internal
   explanation; priority 3, only if needed: a one-time dialog) and its
   explicit "既存UIで十分説明している場合は二重dialogを作らない"
   instruction, **Phase 2 does not add five new one-time dialogs for A–E.**
   Doing so would have been the exact duplicate-explanation anti-pattern the
   task warns against. Instead, Phase 2's job for A–E became: (a) fix the
   one genuine copy gap Fresh Audit §6.3 already identified (the SkillSheet
   sheet's own subtitle stated *what* it was but never *why* to check it),
   and (b) make sure the player is actually nudged to open the Mission
   screen at the moments A–E matter — the "Mission visibility" mechanism
   below — rather than duplicating content that already exists there.

## Implementation

### 1. Opening Context → paged "次へ" flow (Implementation Plan §5.1)

`PublicDemoOpeningContextScreen` was converted from one long scrollable list
to a 5-page, index-driven "次へ" flow (`_PublicDemoOpeningContextScreenState
._pages`), matching the task's own example structure:

| Page | Content | Source of numbers |
|---|---|---|
| 1/5 | 会社設立 + ひよりの自己紹介 | static copy, reused `_NavigatorIntro` |
| 2/5 | 社員紹介 — headcount + names/summaries | `founders.length` / `founders` (never hardcoded "2名") |
| 3/5 | 4月の目標 | `publicDemoAprilHeadlineGoal` — the **exact same constant** `public_demo_mission_screen.dart`'s own headline uses, so the two surfaces cannot drift apart |
| 4/5 | 資金 + 注意（倒産リスク） | `startingCash` / `monthlyFixedCost` (verbatim from Finance/Payroll authority, as before) |
| 5/5 | MISSIONへの案内 + 単一CTA「経営を始める」 | static copy |

Each page reuses the existing `_OpeningSection`/`_FoundingRosterSection`/
`_NavigatorIntro` widgets and their existing wording verbatim (per the
Implementation Plan's own "reuse the existing section widgets and copy" §5.1
constraint) — this is a presentation-shape change, not a rewrite of the
underlying facts. "戻る" navigates back one page (never past the first); the
page indicator ("n / 5") is a plain, testable text widget.

**Critical change implemented**: the former second CTA
("まずSkillSheetで2人を確認する") is gone. There is now exactly one exit —
"経営を始める" on page 5 — which always lands on HOME
(`PublicDemo01PlaceholderScreen._acknowledgeOpeningContext`, simplified to
drop the `openEmployeesTabFirst` branch entirely). SkillSheet confirmation
is reachable only as April Mission #1, discovered "when it becomes
necessary," never as a pre-management choice. Per the task's own comparison
of "Openingの最後からMission screenを開く" vs. "Openingの最後で4月目標を明示
し、そのままHOMEへ入る", this implementation takes the latter (page 5 states
the April goal implicitly via page 3's earlier headline + a MISSION pointer,
then goes straight to HOME) — the more natural of the two per the task's own
stated preference, and it keeps Opening's only side effect the same
`PublicDemoOpeningMarker.markSeen()` call it always had.

### 2. Just-in-time explanation — the one real gap (Fresh Audit §6.3)

`PublicDemoSkillSheetBody`'s subtitle
(`public_demo_skill_sheet_sections.dart`) was extended with the "why" clause
the Fresh Audit had already identified as missing:

> 取引先へ提示する営業用プロフィールです。営業を開始する前に、案件との相性を
> 自分で判断するために内容を確認しましょう。

A copy-only change to an existing sentence — no new dialog, no new gate.

### 3. Mission visibility — a badge, not a modal (UX rule compliance)

To satisfy "Opening終了後、プレイヤーが4月の目標を認識できること" on an
ongoing basis (not just once, right after Opening) without violating "操作
のたびにmodalを出して邪魔をしない" / "Mission達成のたびに強制dialogを連発する
実装は禁止", a small, non-blocking **badge dot** was added to the existing
AppBar Mission icon (`public-demo-app-bar-mission-badge`):

- Shows whenever the Mission chain's current "front" (the first
  not-yet-`completed` mission, via the new, pure, top-level
  `publicDemoMissionFrontIndex` helper) has advanced past what the player
  last acknowledged by actually opening the Mission screen.
- Clears the moment the Mission screen is opened, re-resolved fresh
  (`_openMissionScreen` now records `publicDemoMissionFrontIndex` of the
  just-resolved list into `_missionBadgeAcknowledgedIndex`).
- **Deliberately session-scoped only — `int? _missionBadgeAcknowledgedIndex`
  is plain `State`, never persisted** (no new save field, no new
  SharedPreferences key). A fresh boot/reload re-showing the badge once more
  is the intended "haven't you checked the current goal yet?" nudge, not a
  bug — see the Persistence section below for why no new field was needed
  here either.

This is the mechanism that operationalizes A–E's "just-in-time" framing:
each time SkillSheet confirmation, 営業開始, 案件提案, 面談, or 受注/参画
completes and the chain's front mission changes, the badge reappears,
pointing the player back to the Mission screen — where Phase 1's own
per-tile copy (see Fresh Audit finding #2 above) already explains what
changed and what's next. No new dialog was added anywhere in this Phase.

## Save / persistence strategy

**Zero new persisted fields — game save (`PublicDemoSaveCodec`) and
`PublicDemoOpeningMarker` (SharedPreferences) are both bit-for-bit unchanged
in shape.** Explicit audit per mechanism:

| State | Tier | New field? | Why |
|---|---|---|---|
| Opening page index (`_pageIndex`) | `State` (in-memory) | No | Mirrors Fresh Audit §10.4's own precedent for the pre-Phase-2 screen — pure UI navigation position, not a gameplay fact; a rare mid-flow interruption re-showing page 1 is an acceptable, already-established granularity. |
| "Has this browser seen Opening" | `PublicDemoOpeningMarker` (SharedPreferences) | No — reused as-is | The single boolean flag from Phase 1/pre-Phase-2 is untouched; still isolated from save schema. |
| Mission completion (all 7 April missions) | Derived from existing save-serialized state | No — unchanged from Phase 1 | Phase 2 adds no new mission id and no new authority read. |
| Mission-visibility badge acknowledgement | `State` (in-memory, session-scoped) | No | Deliberately not persisted — see "Mission visibility" above. |

Since nothing new is persisted, there is no migration to design and no
legacy-save default to get right — the existing legacy/mid-game/reload
matrix (below) exercises this directly rather than needing a new fixture.

## Mission integration

No changes to `public_demo_mission_resolver.dart`'s authority logic. The
only cross-file coupling Phase 2 introduces is a **shared display-copy
constant** (`publicDemoAprilHeadlineGoal`, defined once in
`public_demo_mission_screen.dart`, imported by the Opening screen) so the
Opening's own "4月の目標" page and the Mission screen's own header can never
independently drift — this was a design goal explicitly named in the task
("数値や社員人数をhard-codeして将来driftさせないこと" extended here to the
one other hand-typed sentence that existed in two places).

## Tests

### New/updated widget test coverage

- **`test/ui/public_demo/public_demo_01_opening_context_test.dart`**
  (rewritten for the paged flow, 18 tests): gating (fresh/persistent
  marker/restored-save, unchanged from Phase 1/pre-Phase-2), paged-flow
  content per page (headcount/names never hardcoded, April headline goal
  matches the Mission screen's own constant, cash/fixed-cost still
  authority-derived, single CTA on page 5, no second CTA anywhere), "戻る"
  navigation, dismissal (SkillSheet not required first, lands on HOME —
  `public-demo-home-tab`, never `public-demo-employees-tab`), reload
  (Opening-completed save never re-shown), restart ("4月からやり直す" shows
  Opening again at page 1/5), and a full 5-page overflow matrix at
  360×800/390×844 × TextScaler 1.0/1.3.
- **`test/ui/public_demo/public_demo_mission_appbar_entry_test.dart`**
  (extended, +6 tests): the new Mission-visibility badge (shows on a fresh
  game, clears on open, reappears once the chain front genuinely advances)
  and two mid-game restored-save scenarios (a plain May save with no Mission
  progress; a save already at April headline completion) confirming Opening
  never re-shows and the Mission entry/badge reflect real, current state —
  not stale/cached data.
- **`test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`**
  (+1 assertion): the new "why check this" clause is present in the
  SkillSheet sheet.

### Full suite results

- `flutter analyze` (whole repo): **No issues found.**
- `flutter test test/game/public_demo`: **1042/1042 passed** (unchanged
  from Phase 1 — Phase 2 touches no domain/game-layer file).
- `flutter test test/ui/public_demo`: **803/803 passed** (Phase 1 baseline
  800 + Phase 2's net new/updated assertions above — the Opening Context
  file was rewritten in place rather than purely additive, so the delta is
  not a simple sum of new `testWidgets` blocks).
- `git diff --check`: clean.

(Flutter SDK not present in this session's container; installed `3.44.9`
stable — the exact version pinned by `.github/workflows/e2e.yml`/
`e2e-heavy.yml` — matching Phase 1's own session.)

## Self-hardening (Broad Self Review)

One Broad Self Review pass was run after implementation, focused on the
task's own listed concerns:

- **Onboarding replay**: verified — reload after dismissal never re-shows
  Opening; "4月からやり直す" always shows Opening again starting at page
  1/5 (dedicated tests for both).
- **Save compatibility**: verified — zero new save-schema fields; zero new
  SharedPreferences keys; the only new in-memory bookkeeping (the Mission
  badge's acknowledged index) is deliberately never persisted.
- **Duplicate dialog**: verified by design and by test — no new dialog was
  added anywhere in this Phase (the badge is a passive icon decoration, not
  a dialog; the SkillSheet copy change extends an existing sentence). The
  existing "reopening the Mission screen does not accumulate duplicate
  MISSION COMPLETE banners" test (Phase 1) still passes unchanged.
- **Back navigation**: "戻る" steps back exactly one page and is hidden on
  page 1 (tested). The paged flow uses in-`State` page index, not a
  `Navigator` route stack — identical to the pre-Phase-2 screen's own
  architecture, so the system/browser back button's behavior (a no-op, since
  this screen was never a pushed route to begin with) is unchanged, not a
  regression Phase 2 introduces.
- **Browser reload**: verified — the "reload after dismissal" and the two
  new mid-game restored-save tests all confirm Opening is correctly skipped
  and Mission state reflects real, current progress after a fresh mount.
- **April→May**: verified via a dedicated restored-May-save test — Opening
  never re-shows once any save exists, at any month.
- **Existing save**: verified via two mid-game restored-save scenarios (a
  plain May save with no Mission progress; a save already at April headline
  completion, exercising Fresh Audit §10.5's retroactive-detection design
  again under Phase 2's changes).
- **Overflow**: verified — a full 5-page × 360×800/390×844 × TextScaler
  1.0/1.3 matrix (20 cases) on the new Opening flow, zero exceptions.
- **Stale copy**: caught and fixed during this review — a leftover doc
  comment on the Opening screen's `_PageBuilder` typedef referenced two
  classes (`_FoundingRosterPage`/`_FinalPage`) from an earlier draft
  structure that were never implemented (the actual implementation uses
  five `_build*Page` methods on the State class, not per-page widget
  classes); corrected to describe the real shape. No other stale copy was
  found — the old "まずSkillSheetで2人を確認する"/two-CTA wording and the
  old single-scrollable-list "経営を始める前に" header text were fully
  removed, not left dead in the file, and a repo-wide grep confirmed no
  test or e2e spec depends on either.
- **Mission resolver authority drift**: none — `public_demo_mission_resolver
  .dart` is untouched by this Phase; the only new cross-file coupling is the
  shared *display-copy* constant `publicDemoAprilHeadlineGoal`, which
  carries no authority and cannot affect mission completion logic.
- **Additional fix found during this review (not in the task's own
  checklist, but a real correctness gap in the badge feature this Phase
  added)**: `_missionBadgeAcknowledgedIndex` was not reset on "4月からやり
  直す" (restart). Without a reset, a restart whose fresh Mission-chain
  front (`index 0`) happened to coincide with the value acknowledged in the
  abandoned playthrough would incorrectly suppress the badge on a genuinely
  fresh game. Fixed by resetting `_missionBadgeAcknowledgedIndex = null` in
  the same `setState` block that already resets `_game`/`_showOpening` on
  restart — verified correct by construction (`null` can never equal an
  `int`, so the badge is guaranteed visible immediately after any restart
  until explicitly re-acknowledged) and confirmed via a full re-run of the
  affected test files (32/32 passed) after the fix.

No P0 was found. The one P1-equivalent finding (the restart/badge
interaction above) was fixed in this same session before finishing.

## Unresolved issues

None known for Phase 2's own scope.

## Phase 3 recommendation

Proceed with Phase 3 (SkillSheet comprehension + editing,
Implementation Plan §6): the English-label fix (`_techSkillDomainLabels`/
`techDomainLabels`, both files, with the mandatory main-game regression
check since `labels.dart` is shared), and SkillSheet editing
(`displayedExperienceMonths`, display-only scope, no Fit/Trust wiring) —
per the Plan's own dependency graph, Phase 3 has no hard dependency on
Phase 2 beyond "logically follows Phase 2's onboarding-copy pass," and both
sub-phases (3a/3b) are already scoped independently in the Plan.

## FINAL VERDICT

**GO — Phase 2 shipped as scoped.** `flutter analyze` clean, 1042 (game,
unchanged) + 803 (UI) tests passing, 0 regressions, `git diff --check`
clean, zero new persisted fields (save schema and `PublicDemoOpeningMarker`
both unchanged in shape), the "SkillSheet未確認でも経営開始できる" outcome
achieved via a single-CTA paged Opening that removes the old competing-CTA
framing, the 4月目標 explicitly stated to the player before entering HOME,
just-in-time explanations A–E satisfied by (a) one real copy-gap fix and
(b) reusing Phase 1's existing Mission-screen copy rather than duplicating
it into new dialogs, HOME body/Bottom Navigation verified unchanged by
existing regression tests, and the one self-review finding (the restart/
badge interaction) was fixed and re-verified in this same session before
finishing.
