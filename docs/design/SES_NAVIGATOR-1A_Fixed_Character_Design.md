# SES NAVIGATOR-1A — 固定ナビゲーター表示 設計書

STATUS: implemented (this branch); PR #73 dependency resolved — see STATUS UPDATE below
AUTHOR AUTHORITY: this document is written from the NAVIGATOR-1A implementation prompt supplied in-conversation and from the S.E.S. Public Demo 0.1 codebase as it stood on `claude/home-runtime-2b-office-stage-fa1cpy` (PR #73, head `a3ad6ae`) **at implementation time**. No separate external NAVIGATOR-1A design file was supplied or found in the repository — this record IS the design authority for 1A, written before/alongside implementation rather than transcribed from one.

## STATUS UPDATE (post-review, current repository state)

The DEPENDENCY section below is a historical record of the state at implementation time and is kept as written — do not read it as current. As of this update:

- **PR #73 is merged.** Merge commit `3740af03428ff4ea46b6f926d098d3b1f731cf74` (`Merge pull request #73 from perusonao/claude/home-runtime-2b-office-stage-fa1cpy`), parents `62de4df` (old `origin/main`) and `a3ad6ae` (PR #73's head — the same commit this phase implemented against). Verified via `git fetch origin` + `git merge-base --is-ancestor a3ad6ae origin/main`, not assumed from a prior report.
- **NAVIGATOR-1A has been rebased onto current `origin/main`** (which now includes #73's Office Stage). The rebase was a clean, non-conflicting replay of the single NAVIGATOR-1A commit — `git diff a3ad6ae 3740af0` is empty (the merge commit's tree is byte-identical to #73's head, i.e. a pure merge with no squash or extra changes), so the rebase introduced no risk of duplicating or diverging from #73's content.
- **Implementation-time base:** `a3ad6ae80a5880a1fd5e4c0a9e1a3cb601c13e69` (PR #73 head, before #73 merged).
- **Current NAVIGATOR-1A base after rebase:** `origin/main` at `3740af03428ff4ea46b6f926d098d3b1f731cf74`.
- The stack dependency described below ("cannot merge before PR #73") **no longer applies**. NAVIGATOR-1A can now be reviewed and merged directly against `main`.

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

## DEPENDENCY: PR #73 (HOME-RUNTIME-2B) — historical record, implementation time

**This section describes the state at the time NAVIGATOR-1A was implemented and is preserved as-written. See STATUS UPDATE above for the current, verified state (#73 is now merged).**

Verified against GitHub before starting (not against a prior report or stale SHA):

- `origin/main` HEAD at session start: `62de4df7db2103b2bbc8cab8dd6261d3a608e1e6` ("Merge PR #72: HOME-RUNTIME-2C Recommended Action").
- PR #73 ("HOME-RUNTIME-2B: Office Stage on Public Demo HOME") was **open, not merged**, base `62de4df` (level with main), head `a3ad6ae80a5880a1fd5e4c0a9e1a3cb601c13e69`.
- CI on `a3ad6ae`: all blocking checks green; `e2e-webkit` red, but byte-identically the same failure already present on base `62de4df` (known seed-100001 WebKit flake, `continue-on-error: true` per repo policy) — not this PR's regression.
- Codex's P2 review comment (`home_office_stage_section.dart` — a fixed `SizedBox(height: 20)` title row clipping at increased text scale) was **already fixed** by the PR's own second commit (`a3ad6ae`, "fix: let the Office Stage title row grow with the text scale"), which replaced the fixed height with `ConstrainedBox(minHeight: ...)`. Verified by reading the current file content — no fix was re-applied.

Given #73 was still open, the instructions required either basing NAVIGATOR-1A on `origin/main` (Office Stage absent, deferring test D) or stacking on #73's head (Office Stage present, all tests runnable now, but NAVIGATOR-1A cannot land on `main` until #73 merges). **The user chose to stack on PR #73's head.** This branch (`claude/navigator-1a-fixed-character-x8xjp0`) was therefore reset to `origin/claude/home-runtime-2b-office-stage-fa1cpy` (`a3ad6ae`) rather than to `origin/main`.

Consequence (at implementation time): this PR was stacked on, and could not merge before, PR #73. **This is resolved — see STATUS UPDATE above.** Its diff against #73's head was, and after the rebase remains, Navigator-only (asset registration + two new files + the mount point) — confirmed unchanged by `git diff origin/main --stat` after the rebase.

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

**Post-review addition (P2-2 remediation):** a further test in the same file, group `P2-2: a Navigator asset failure cannot block HOME progression`, closes a gap the independent review found — coverage that a Navigator asset failure degrades gracefully existed only at the component level, not proven on the real HOME with the real owner dispatch. It renders the real `PublicDemo01PlaceholderScreen` wrapped in an `AssetBundle` that fails to load *only* `AssetPaths.navigatorNormal` (every other asset — Office Stage background/portraits, fonts — is served normally, so the test cannot mistake "the whole screen degraded" for "the navigator's fallback specifically works"), confirms the silhouette fallback renders, then **actually taps** the real `home-recommended-action-cta` (no mock, no stand-in handler) and asserts the real production effect landed: `PublicDemoWorkflowState.engineers.first.stage` moves `waiting → skillSheet`, the same effect `SkillSheet確認` has with no navigator on screen at all. Proves Navigator presentation failure ≠ gameplay/navigation failure, without touching Recommended Action eligibility, priority, or owner dispatch to make the test easier.

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

**Post-review addition (P2-2 real-browser acceptance):**

- `docs/screenshots/navigator-1a-cta-before.png` / `-cta-after.png` — the real Recommended Action CTA, tapped through Chromium's accessibility/semantics tree (not a coordinate guess), on the healthy build. Before: "次にやること 佐藤 健のSkillSheetを確認" / button "SkillSheetを確認". After one real tap: "次にやること 佐藤 健の営業を開始" / button "営業を開始", 佐藤健's status badge advances 待機→営業準備. This is the real production `_startSkillSheetReview` handler's effect, observed in a real browser.
- `docs/screenshots/navigator-1a-assetfail-before.png` / `-assetfail-after.png` — the same sequence, served from a build copy with `assets/assets/images/navigator/navigator_normal.webp` deleted (confirmed via Playwright's network log: the browser genuinely requests it and receives HTTP 404 — not a synthetic in-process failure). Navigator's portrait renders the silhouette fallback; Office Stage and the rest of HOME are visually unaffected; the CTA is found via semantics, tapped, and produces the exact same before→after transition as the healthy build. No page error, no blank screen, no broken layout.

This closes the P2-2 gap with real-browser evidence in addition to the widget test: Navigator asset failure, demonstrated in Chromium, does not block Recommended Action / game progression.

## KNOWN GAPS

1. **Browser text-scale screenshots not captured.** Playwright/Chromium does not drive Flutter Web's internal `TextScaler` through CSS zoom or viewport tricks (confirmed: three screenshots taken at simulated "1.0/1.3/2.0" via browser zoom were byte-identical). Text-scale behavior at 1.3/2.0 is verified instead by `flutter test` widget measurements against the real Flutter text-layout pipeline (the same mechanism that renders on web), which is the stronger form of evidence for this specific question (glyph-level clipping) even without a browser screenshot. Marked UNVERIFIED in the visual sense, VERIFIED in the widget-test sense — see Result document.
2. **KPI "社員" vs 総務 discrepancy** — see EMPLOYEE COUNT above. Reported, not fixed; a Domain/projection decision for a later phase. Confirmed still pre-existing/outside-scope as of the post-review update — not touched.
3. ~~This PR is stacked on unmerged PR #73 and cannot itself merge to `main` first.~~ **Resolved** — see STATUS UPDATE above; #73 merged and this branch rebased cleanly onto current `origin/main`.

## P0 / P1 / P2 / P3

- P0: none found (original implementation or post-review remediation).
- P1: none found.
- P2 (from independent review of `3028aeb`): **both resolved.**
  - P2-1 — stale documentation (this design doc and the Result document described PR #73 as open/unmerged and this branch as unable to merge before it). Fixed by the STATUS UPDATE sections added to both documents, distinguishing implementation-time base from current verified state.
  - P2-2 — no real-HOME test proved a Navigator asset failure could not block the Recommended Action CTA / game progression (component-level fallback coverage existed; screen-level did not). Fixed by the new `P2-2` test group in `test/ui/public_demo/public_demo_01_home_navigator_test.dart` — see TEST PLAN above.
- P3: browser-level text-scale visual confirmation remains unavailable in this environment (see Known Gaps #1); mitigated by widget-test coverage of the same property. Unchanged by the post-review remediation.

## NEXT PHASE

NAVIGATOR-1B: GameState-driven message/advice selection (translating existing Finance/Sales/Recruitment/Event authority into natural language), expression switching tied to game state, and — only if separately authorized — tap interaction. None of that groundwork was pre-built here beyond declaring the full `NavigatorExpression` enum and the `expression` parameter `HomeNavigatorSection` already accepts.
