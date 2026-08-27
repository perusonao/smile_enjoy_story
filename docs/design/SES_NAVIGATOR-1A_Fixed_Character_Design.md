# SES NAVIGATOR-1A — 固定ナビゲーター表示 設計書

STATUS: implemented (this branch)
AUTHOR AUTHORITY: this document is written from the NAVIGATOR-1A implementation prompt supplied in-conversation and from the S.E.S. Public Demo 0.1 codebase as it stands on `claude/home-runtime-2b-office-stage-fa1cpy` (PR #73, head `a3ad6ae`). No separate external NAVIGATOR-1A design file was supplied or found in the repository — this record IS the design authority for 1A, written before/alongside implementation rather than transcribed from one.

## PURPOSE

Give the Public Demo's existing 総務 (general-affairs) employee a face and a name — 佐倉 ひより (Hiyori Sakura) — and introduce her presence to Public Demo HOME. NAVIGATOR-1A is scoped to *existence only*: no advice engine, no expression switching, no tutorial control, no GameState-driven message selection. Those are NAVIGATOR-1B and later.

## AUTHORITY

**NAVIGATOR-1A owns:** her display identity (name, role, one fixed greeting), her portrait asset, and the widget that renders them.

**NAVIGATOR-1A explicitly does NOT own, touch, or gain a path into:**
- Finance calculation, salary calculation, cash calculation, sales calculation
- Recruitment logic, workflow transitions, assignment logic, month closing
- Save schema (no new save field, no asset ID persisted)
- Domain SSOT (`PublicDemoState`, `PublicDemoWorkflowState`) — no new field added to either
- Existing Recommended Action eligibility / `HomeRecommendedAction` authority
- Existing HOME mutation entry point (the Recommended Action CTA remains the only one)
- Existing terminal/financial precedence

The navigator is **not** the SSOT for anything. A future phase's advice is a presentation-layer translation of decisions the existing authorities already make — 1A builds only the character's presence, not that translation.

## DEPENDENCY: PR #73 (HOME-RUNTIME-2B)

Verified against GitHub before starting (not against a prior report or stale SHA):

- `origin/main` HEAD at session start: `62de4df7db2103b2bbc8cab8dd6261d3a608e1e6` ("Merge PR #72: HOME-RUNTIME-2C Recommended Action").
- PR #73 ("HOME-RUNTIME-2B: Office Stage on Public Demo HOME") was **open, not merged**, base `62de4df` (level with main), head `a3ad6ae80a5880a1fd5e4c0a9e1a3cb601c13e69`.
- CI on `a3ad6ae`: all blocking checks green; `e2e-webkit` red, but byte-identically the same failure already present on base `62de4df` (known seed-100001 WebKit flake, `continue-on-error: true` per repo policy) — not this PR's regression.
- Codex's P2 review comment (`home_office_stage_section.dart` — a fixed `SizedBox(height: 20)` title row clipping at increased text scale) was **already fixed** by the PR's own second commit (`a3ad6ae`, "fix: let the Office Stage title row grow with the text scale"), which replaced the fixed height with `ConstrainedBox(minHeight: ...)`. Verified by reading the current file content — no fix was re-applied.

Given #73 was still open, the instructions required either basing NAVIGATOR-1A on `origin/main` (Office Stage absent, deferring test D) or stacking on #73's head (Office Stage present, all tests runnable now, but NAVIGATOR-1A cannot land on `main` until #73 merges). **The user chose to stack on PR #73's head.** This branch (`claude/navigator-1a-fixed-character-x8xjp0`) was therefore reset to `origin/claude/home-runtime-2b-office-stage-fa1cpy` (`a3ad6ae`) rather than to `origin/main`.

Consequence: this PR is **stacked on, and cannot merge before, PR #73**. Its diff against #73's head is Navigator-only (asset registration + two new files + the mount point), so review and merge order is: #73 first, then this.

## WIDGET PLACEMENT

```
ListView > Column
  ├ PublicDemoCashShortageCard        (unchanged)
  ├ PublicDemoHomeDashboardSection     (unchanged: MonthHeaderBar → KpiSection → RecommendedActionSection)
  ├ HomeOfficeStageSection             (PR #73, unchanged by this branch)
  ├ HomeNavigatorSection               (NEW — this phase)
  └ dashboard() / legacy month content (unchanged)
```

`HomeNavigatorSection` is mounted as a **sibling** of `PublicDemoHomeDashboardSection`, immediately after `HomeOfficeStageSection`, in `PublicDemo01PlaceholderScreen`'s `build()`. It is a sibling for the same reason the Office Stage already is: `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` group 15 ("HOME's only mutation path is the whitelisted CTA") and the `_homeBlockCeiling` height guard both scope themselves to `PublicDemoHomeDashboardSection`'s subtree. Mounting an inert card inside that subtree would put it under guards written to measure the read-only KPI/action projection, for no benefit — the navigator carries no projected value at all.

Order — KPI → Recommended Action → Office Stage → Navigator → legacy — matches the instruction exactly and is enforced by tests reading tree traversal order (not just vertical position, which stops being meaningful once increased text scale pushes the navigator off-screen).

## ASSET POLICY

Followed the repository's existing convention exactly (`lib/ui/asset_paths.dart`, `pubspec.yaml`'s directory-form registration):

- New directory `assets/images/navigator/`, registered in `pubspec.yaml` the same way `characters/`, `events/`, `locations/` already are (whole-directory bundling, no per-file listing).
- New constant `AssetPaths.navigatorNormal = 'assets/images/navigator/navigator_normal.webp'`, added to `AssetPaths.all` (so `test/ui/asset_paths_test.dart`'s existing bundle-load smoke test covers it automatically).
- No screen or model references the path as a string literal — resolution goes through `HomeNavigatorIdentity.portraitAssetFor(NavigatorExpression)`.
- **Presentation-only, by construction**: `HomeNavigatorIdentity` and `HomeNavigatorSection` are the only two files that know the asset path exists. No domain model gained an `imagePath`/`portrait`/`asset` field; no save field was added; Finance/Workflow have no image concept and none was added to them.
- **Failure-tolerant**: `Image.asset(...).errorBuilder` falls back to a plain silhouette icon (`Icons.person`) on decode failure, and `portraitAssetFor` returns `null` for every expression NAVIGATOR-1A has no artwork for (everything but `normal`), which the widget also renders as the silhouette. Neither path throws during layout or blocks the rest of HOME from rendering.

Source image: `01_Hiyori_Sakura_normal_reference.png` (1448×1086) from the supplied attachment set, matching the character brief (dark-brown long hair, brown eyes, beige jacket, white blouse, blue neck strap, S.E.S. badge reading 佐倉 ひより / Hiyori Sakura / 総務). Cropped to a 760×760 head-and-shoulders square and resized to 512×512 WebP (quality 88), comfortably above the requested 256×256 floor.

## CHARACTER IDENTITY

`HomeNavigatorIdentity` (in `lib/presentation/home/models/home_navigator_display.dart`) is a bag of constants, not a projection of game state:

- `name = '佐倉 ひより'`, `romanizedName = 'Hiyori Sakura'` (unused in 1A's UI, kept for later phases), `role = '総務'`.
- `greeting` — one fixed string: `'総務の佐倉です。今月もよろしくお願いします。'`
- `NavigatorExpression` enum declares the full vocabulary the character brief specifies (`normal, smile, worried, warning, celebration`) so a later phase extends rather than redefines the type, but `portraitAssetFor` resolves an asset only for `normal` — every other value returns `null` today. **NAVIGATOR-1A never constructs `HomeNavigatorSection` with anything but the default (`normal`).**

## EMPLOYEE COUNT — investigated, not changed

Confirmed in `lib/game/public_demo/public_demo_state.dart`: `PublicDemoState.aprilStart()` already sets `adminCount: 1` alongside `engineerCount: 2`, and `lib/game/public_demo/public_demo_salary.dart`'s `adminMonthlySalary` (¥200,000) is already folded into `baselineMonthlyExpenses`. **総務1名 already exists in both Domain and Finance** — 佐倉ひより is that employee's presentation identity, not a fourth hire. No `adminCount`, no salary constant, and no save field was touched.

**Discrepancy found, not fixed (reported per instructions):** the HOME KPI's "社員" tile (`HomeDashboardDisplayData.employeeCount`) reads `PublicDemoState.engineerCount` — engineers only, 2, not `engineerCount + adminCount`. So the existing on-screen "社員" figure already excludes 総務, and it continues to after this phase. NAVIGATOR-1A does not change this projection or this KPI in either direction; making 総務 count toward "社員" would be a Domain/HOME-RUNTIME-READ-1 projection decision outside this phase's scope.

## NON-GOALS (explicitly not implemented)

Recommended Action replacement, GameState advice engine, Finance/Sales/Recruitment/Event recommendation, monthly message variation, automatic expression switching, tap-to-navigate, automatic decision-making, tutorial engine, any new navigation authority. `HomeNavigatorSection` takes no callback, builds no `GestureDetector`/`InkWell`/button, and its only constructor parameter (`expression`) defaults to and is only ever called with `NavigatorExpression.normal`.

## TEST PLAN

Two suites, mirroring the existing 2B split between component and screen coverage:

- `test/presentation/home/home_navigator_section_test.dart` — the widget in isolation: identity constants, inertness, portrait fallback (missing asset, failing bundle, corrupt bytes), and text-scale-driven growth (no fixed height around any text) at both target sizes × four text scales.
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart` — the real screen, driving the real `PublicDemoAggregate`: exactly one navigator (A), name+role visible (B), position after Recommended Action (C) and after Office Stage (D), no duplicate across a real domain-command rebuild (E), zero state mutation from the navigator including a real trajectory that *does* change state elsewhere (F), fallback tolerance carried through to the real screen (G), and overflow-free layout at 360×800/390×844 across text scales 1.0/1.15/1.3/2.0 (H, I, J).

All items A–J from the implementation prompt are covered; see the Result document for the pass/fail table.

## MEASUREMENTS

Real-build measurements (`flutter test`, MediaQuery-driven, no assumptions carried from the Office Stage's budget):

| textScale | 360×800 card height | 390×844 card height |
|---|---|---|
| 1.0 | 64.0pt | 64.0pt |
| 1.15 | 73.0pt | 74.0pt |
| 1.3 | 79.0pt | 83.0pt |
| 2.0 | 140.0pt | 116.0pt |

`HomeNavigatorMetrics.compactTargetHeight = 64` matches the design's "≈64pt" request exactly at scale 1.0. `compactCeiling = 84` is the scale-1.0 ceiling (79pt at 360×800 lands under it with margin); at 1.3 and 2.0 the card is *permitted* to exceed it and push below the first view, per the instruction's explicit textScale ≥1.3 allowance. Recommended Action CTA position is unchanged by the navigator's presence at every measured scale (verified in the same test run — the CTA sits above the Office Stage, which is unaffected by anything below it).

## SCREENSHOTS

`docs/screenshots/navigator-1a-360x800.png`, `docs/screenshots/navigator-1a-390x844.png` — release web build (`flutter build web --release`), rendered in the environment's bundled Chromium via Playwright, textScale 1.0 (default). Both show: KPI → Recommended Action → Office Stage (2 portraits + names) → Navigator (portrait, 佐倉 ひより, 総務 badge, two-line greeting) → legacy 佐藤健 card, no horizontal overflow, no visual collision between Office Stage and Navigator.

## KNOWN GAPS

1. **Browser text-scale screenshots not captured.** Playwright/Chromium does not drive Flutter Web's internal `TextScaler` through CSS zoom or viewport tricks (confirmed: three screenshots taken at simulated "1.0/1.3/2.0" via browser zoom were byte-identical). Text-scale behavior at 1.3/2.0 is verified instead by `flutter test` widget measurements against the real Flutter text-layout pipeline (the same mechanism that renders on web), which is the stronger form of evidence for this specific question (glyph-level clipping) even without a browser screenshot. Marked UNVERIFIED in the visual sense, VERIFIED in the widget-test sense — see Result document.
2. **KPI "社員" vs 総務 discrepancy** — see EMPLOYEE COUNT above. Reported, not fixed; a Domain/projection decision for a later phase.
3. This PR is stacked on unmerged PR #73 and cannot itself merge to `main` first.

## P0 / P1 / P2 / P3

- P0: none found.
- P1: none found.
- P2: none found.
- P3: browser-level text-scale visual confirmation is unavailable in this environment (see Known Gaps #1); mitigated by widget-test coverage of the same property.

## NEXT PHASE

NAVIGATOR-1B: GameState-driven message/advice selection (translating existing Finance/Sales/Recruitment/Event authority into natural language), expression switching tied to game state, and — only if separately authorized — tap interaction. None of that groundwork was pre-built here beyond declaring the full `NavigatorExpression` enum and the `expression` parameter `HomeNavigatorSection` already accepts.
