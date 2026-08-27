# SES HOME-RUNTIME-2B — Office Stage — Implementation Result

## BASE

| | |
|---|---|
| Repository | `perusonao/smile_enjoy_story` |
| BASE | `62de4df7db2103b2bbc8cab8dd6261d3a608e1e6` (origin/main) |
| BASE subject | `Merge PR #72: HOME-RUNTIME-2C Recommended Action` |
| Branch | `claude/home-runtime-2b-office-stage-fa1cpy` |
| Toolchain | Flutter 3.44.9 / Dart 3.12.2 (the version CI pins) |

### PR #72 merge verification (independent)

Verified from git history **and** the GitHub API, not taken on trust from
the task prompt:

- PR #72 state `closed`, `merged: true`, merged `2026-08-26T22:54:01Z`.
- PR #72 final head `7a40554de00afbd07823bed0d182b60c5dd7447e` — confirmed an
  ancestor of `origin/main`.
- Merge commit `62de4df7…` has parents `d7964e53…` (the HOME-RUNTIME-2A / PR
  #71 merge) and `7a40554d…`, and is `origin/main` HEAD.
- HOME-RUNTIME-2A present (`eaafd54`, merged as `d7964e5`).
- HOME-RUNTIME-2C present (`e974ff5`, `75b1401`, `7a40554`).

Working tree was clean at start; the implementation branch was created from
`origin/main`. No force push, no reset of other work, no direct commit to
`main`.

## DESIGN AUTHORITY

**The original external design document was NOT available.**
`SES_HOME-RUNTIME-2B_Post2C_Office_Stage_Design.md` is not in the
repository, the Windows path `C:\tmp\...` is not reachable from this Linux
container, and nothing was attached to the session. The implementation used
the **APPROVED DESIGN SUMMARY supplied in the task prompt**, which
authorises itself as authority in exactly that case.

An implementation design record recording this, and every decision made
beyond the summary, is committed at
[`docs/design/SES_HOME-RUNTIME-2B_Post2C_Office_Stage_Design.md`](docs/design/SES_HOME-RUNTIME-2B_Post2C_Office_Stage_Design.md).
It does not claim to reproduce the original.

## FILES CHANGED

### CREATE

| File | Purpose |
|---|---|
| `lib/presentation/home/models/home_office_stage_display.dart` | Read-only display model, deterministic 3-of-N selection, portrait mapping |
| `lib/presentation/home/widgets/home_office_stage_section.dart` | The section + `HomeOfficeStageMetrics` layout constants |
| `test/presentation/home/home_office_stage_section_test.dart` | 38 component tests |
| `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` | 16 runtime-screen tests |
| `docs/design/SES_HOME-RUNTIME-2B_Post2C_Office_Stage_Design.md` | Design record |
| `SES_HOME-RUNTIME-2B_Office_Stage_Implementation_Result.md` | This file |
| `docs/screenshots/home-runtime-2b-360x800.png`, `…-390x844.png` | Release-build visual evidence |

### MODIFY

| File | Change |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_officeStageDisplay` projection getter + renders the section between HOME and legacy content |
| `lib/presentation/home/home.dart` | one barrel export |
| `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` | first-view contract updated (see **Design deviations**) |

### DO NOT TOUCH — confirmed untouched

`lib/domain/**`, `lib/game/**` (Domain, Finance, Save, Workflow, Payroll,
Assignment, monthly close, aggregate), `lib/app/**` (Navigation),
`pubspec.yaml`, every asset binary, and all of HOME-RUNTIME-2C's
eligibility / emission / ranking / month gate / owner handler / dispatch /
terminal precedence code.

Verified after the fact by inspecting the actual diff: exactly 9 files, none
outside the lists above. No unrelated diff.

## IMPLEMENTATION SUMMARY

The Office Stage is a read-only picture of the company, mounted on the
Public Demo runtime HOME between the Recommended Action and the legacy
content. It renders an office background, up to three employees with
portraits and names, and a `+N` indicator for the rest.

The owner (`PublicDemo01PlaceholderScreen`) resolves a
`HomeOfficeStageDisplay` while `build` runs and injects it — the same shape
HOME-RUNTIME-2C established for the recommended-action slot. This is
deliberately a **separate** projection from `HomeDashboardDisplayData`:
that model's `fromPublicDemoState` takes only a `PublicDemoState` by design,
and that narrowness is why HOME structurally cannot see an applicant,
a pre-entry stage, or a financial verdict. Employee names are a workflow
fact, so folding them in would have widened that input to the whole
workflow — paying for a picture with the boundary 2A and 2C both rest on.

The widget decides nothing: which employees appear, in which order, with
which portraits, and which background, are all resolved in the display model
before the widget sees them. That is what makes "the same state always draws
the same scene" assertable without pumping a widget at all.

The section is a **sibling** of `PublicDemoHomeDashboardSection`, not a
child, so the consolidation suite's tight `_homeBlockCeiling` (320pt, with
the block at 316pt) keeps measuring exactly what it was written to measure.

## RESPONSIVE DIMENSIONS

All constants live in `HomeOfficeStageMetrics`; mode is picked by screen
width against a single threshold (`375`) placed between the two targets.

| | compact (360) | normal (390) |
|---|---|---|
| scene height | 128pt | 152pt |
| chrome (title row + padding) | 48pt | 48pt |
| component target | 176pt | 200pt |

## 360x800 MEASUREMENTS — MEASURED

All values MEASURED from the real screen via `tester.getRect`, in pt below
the AppBar, at `scrollOffset = 0` (asserted).

| | before (2C) | after (2B) |
|---|---|---|
| scroll offset before interaction | 0 | **0** |
| HOME block (month+KPI+Recommended Action) | 16 → 316 | **16 → 316 (unchanged)** |
| Recommended Action CTA | 254 → 302 | **254 → 302 (unchanged)** |
| Office Stage | — | **324 → 500 (height 176)** |
| — its scene | — | **362 → 490 (height 128)** |
| first legacy action (`SkillSheet確認`) | 503 → 551 | **695 → 743** |
| effective viewport height | 744 | 744 |
| browser-chrome content budget | 615 | 615 |
| overflow | none | **none** |

DERIVED: component 176pt ≤ target 184pt ✔ ; 176pt < ceiling 213pt, with
**37pt of margin** ✔. Result: **PASS**.

## 390x844 MEASUREMENTS — MEASURED

| | after (2B) |
|---|---|
| scroll offset before interaction | **0** |
| HOME block | 16 → 316 |
| Recommended Action CTA | **254 → 302 (unchanged)** |
| Office Stage | **324 → 524 (height 200)** |
| — its scene | **362 → 514 (height 152)** |
| first legacy action (`SkillSheet確認`) | 719 → 767 |
| effective viewport height | 788 |
| browser-chrome content budget | 660 |
| overflow | **none** |

DERIVED: component 200pt ≤ target 208pt ✔. Result: **PASS**.

## FIRST VIEW SAFETY

The Recommended Action CTA is unmoved at **254 → 302pt** at both targets —
the Office Stage sits below it, so adding a whole visual layer cost the
primary interaction nothing. The Office Stage itself is *fully* painted
inside the browser-chrome budget at both sizes (500 ≤ 615; 524 ≤ 660), and
that is now asserted, not merely observed.

## EMPLOYEE DISPLAY

Max 3 drawn; the rest summarised as `+N名`. Selection is the first three in
authoritative emission order (`PublicDemoWorkflowState.engineers`) — no
randomness, no status-based or score-based reordering, so a rebuild cannot
swap who is on the stage. Verified against a real April → May → June
trajectory that the drawn roster keeps matching both the authority's own
engineer list and `PublicDemoState.engineerCount`.

## EMPLOYEE IMAGE MAPPING

Presentation-only; no Domain/Save field added, nothing persisted.

1. explicit — `eng-01` → `engineer_midlevel.jpg`, `eng-02` → `engineer_junior.jpg`
2. deterministic generic — stable FNV-1a over the id (not `String.hashCode`,
   which is not stable across platforms) into a 3-portrait engineer pool
3. silhouette — `Icons.person`, also the `errorBuilder` for a failed decode

## OFFICE BACKGROUND / ASSET SAFETY

`assets/images/locations/office_day.jpg` — verified to exist, verified
bundled. **No tier-specific office asset exists** and none is referenced.
The background is a constructor parameter so a future tier phase has an
extension point without the widget learning about tiers.

`pubspec.yaml` registers these directories already, so this phase changed no
manifest, added no asset, and replaced no binary. A test asserts that *every*
image path this section can produce is in `AssetPaths.all`, so an invented
asset name cannot pass review silently.

## 2C REGRESSION

**None.** Asserted on the real screen: the slot, the
`home-recommended-action` card, the `…-cta` and `…-headline` keys are all
intact; April's recommendation is still the SkillSheet step with 2C's own
`SkillSheetを確認` label; pressing the CTA still moves the real workflow and
the recommendation still advances to `営業を開始`. HOME still has exactly one
button, and the Office Stage subtree contributes none.

DOMAIN: unchanged. FINANCE: unchanged. SAVE: unchanged (no schema, no new
persisted field). WORKFLOW: unchanged. PAYROLL / ASSIGNMENT: unchanged.
NAVIGATION: unchanged.

## VALIDATION

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **1122 passed** (baseline at BASE: 1067; +55 new) |
| `flutter build web --release` | **✓ Built build/web** |
| `flutter build web --release --no-web-resources-cdn` | **✓** (used for the screenshots) |
| `git diff --check` | **clean** |
| `dart format` on the 4 new files | **clean** |

### Note on repo-wide `dart format`

`dart format --output=none --set-exit-if-changed .` **fails on clean
`origin/main`** under Flutter 3.44.9 (167 files reported). This is
pre-existing drift between the formatter version and the committed code, not
introduced here — verified by stashing this branch's changes and re-running
against an untouched `origin/main`. The two pre-existing files this phase
modifies were *already* in that set, so they were deliberately **not**
reformatted: doing so would have produced a large unrelated diff. The four
new files added by this phase are formatter-clean. No CI workflow gates on
repo-wide formatting (the gates are `flutter analyze`, `flutter test`,
`flutter build web`).

## VISUAL VALIDATION

Real `--release` web build, served locally and driven in Chromium at both
required viewports. Screenshots committed:

- `docs/screenshots/home-runtime-2b-360x800.png`
- `docs/screenshots/home-runtime-2b-390x844.png`

Confirmed in both: Office Stage visible; office background visible; both
employee portraits visible and distinct; names legible and not clipped;
Recommended Action CTA inside the initial viewport; KPI intact; legacy
content intact below; no overflow; no clipping; **no horizontal scroll**
(`scrollWidth == clientWidth` at both sizes); initial `scrollY == 0`.

The 4-or-more case (`+N` chip) was verified by an offscreen render at 360pt
and by the widget tests — three portraits plus the `+2` chip, contained, no
overflow. It is **not** covered by a live browser screenshot: reaching four
employees requires a long in-game recruitment trajectory. See UNVERIFIED.

## DESIGN DEVIATIONS

### P1 — one existing test's subject was changed, deliberately

Placing a ~176pt Office Stage above the legacy content necessarily pushes
the legacy per-employee `SkillSheet確認` button below the browser-chrome
content budget (743pt vs the 615pt budget at 360x800). This is unavoidable
given the mandated ordering, and the design's first-view requirement
protects only the Recommended Action CTA.

Consolidation test **16-17** was therefore re-aimed from the legacy button to
the Recommended Action CTA. The assertions are unchanged in form and
strength — painted viewport, browser-chrome budget, genuinely tappable — and
their new subject sits at 302pt, roughly half the depth the old one did, so
the property the group protects holds by a **wider** margin than before. The
test additionally now requires the Office Stage to be fully inside the same
budget.

Nothing was skipped, quarantined, retried, given a longer timeout, deleted,
or loosened to a broader matcher. Group **18/24** gained a **new** test
asserting the legacy button still exists, is still enabled, sits below the
Office Stage, and still works after scrolling — i.e. relocated, not lost.

**This is the one place this phase changed an existing passing assertion and
is flagged for independent review.**

### P2 — no per-employee 参画/待機 status

Implemented, then removed. Public Demo 0.1 has three authorities for that
fact and they legitimately disagree during a month — measured, not assumed:
after a real April→May trajectory, `engineersAssigned == 1` while
`workflow.assignments` is still empty (`assignOrderedForMay` runs at
`closeMay`), and `stage == ordered` misses joined applicants, who become
engineers at the default `waiting` stage. Any single choice would contradict
the KPI two rows above in at least one month, and restating 参画/待機 at all
would duplicate a fact HOME-RUNTIME-2A gave exactly one place on screen.
Reconciling the three is Assignment/Domain work this phase must not touch.
Deferred to 2E's Employee tab. Full reasoning in the design record.

### P3 — the stage is not suppressed in terminal states

2C suppresses the action slot at bankruptcy / March failure / fiscal
completion. The Office Stage is not suppressed: it states who works at the
company, which is still true, and a suppression rule would require this
layer to act on a financial verdict it deliberately cannot see.

## TEST SUMMARY

54 new tests, mapped to the required areas:

| Req | Covered by |
|---|---|
| A renders after Recommended Action | runtime: order + sibling-not-child |
| B 360x800 layout safety | component + runtime, vs target *and* ceiling |
| C 390x844 layout safety | component + runtime |
| D/E/F 1/2/3 employees | component (model + widget) |
| G 4+ → max 3 + deterministic remainder | component, incl. `+N` render and hidden names |
| H explicit image mapping | component, asserted on the painted image |
| I fallback portrait | component, 200 ids, all bundled |
| J silhouette fallback | component |
| K office background fallback | component, incl. "every asset is bundled" |
| L Recommended Action unchanged | runtime, incl. live dispatch |
| M no mutation authority | component + runtime (7 widget types, both subtrees) |
| N no overflow | component (12 size×count combinations) + runtime |
| O deterministic rendering | component (repeat selection, repeat portrait, repaint equality) |

No existing scope guard was weakened. The 2C guards (`runtime_read` test 14,
consolidation group 15) are untouched.

## BLOCKED

None. No STOP condition was hit.

## UNVERIFIED

1. **The original external design document** — could not be read; see
   DESIGN AUTHORITY. A reviewer holding it should diff it against the design
   record.
2. **The provenance of the `213pt` ceiling and the `184/208pt` targets** —
   taken as given from the APPROVED DESIGN SUMMARY; their derivation is in
   the unavailable original. The implementation lands under all three with
   margin.
3. **A live-browser screenshot of the 4+ employee case** — covered by an
   offscreen render and by widget tests, not by a browser screenshot.
4. **Playwright / e2e** — not run; per the task, not a completion condition
   for 2B, and the known WebKit navigation flake is out of scope.
5. **Repo-wide `dart format`** — already failing on `origin/main` before
   this branch; not addressed here to avoid an unrelated diff.

## NEXT

Independent review. **Do not merge** on the strength of this document alone.

Reviewers should look first at the P1 test-subject change, then at the P2
status omission, then confirm the design record against the original design
document if they hold it.
