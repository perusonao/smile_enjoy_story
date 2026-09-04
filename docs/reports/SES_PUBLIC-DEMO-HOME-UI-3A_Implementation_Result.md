# SES_PUBLIC-DEMO-HOME-UI-3A Implementation Result (re-audit session)

## STATUS

Complete. `flutter analyze`, the focused HOME/Public Demo test suites, the
full `flutter test` suite, and `flutter build web --release` are all green
on the final commit. **Issue #147 is intentionally NOT closed by this
session** — see Merge Readiness.

## SESSION SUMMARY

This is a **re-audit and minimal-fix session**, not a fresh implementation.
Issue #147's HOME rebuild was already implemented and merged into `main`
before this session started, via PR #150 (`fec518a`) plus a P2-review-fix
commit (`8736fb0`). This session:

1. Verified that fact directly (`git log --oneline | grep 147`,
   `pull_request_read` on PR #150 — `merged: true`, `base.sha:
   c5d040fcd8a9de12332790629b33b62bf6627f39`).
2. Located and confirmed the approved target image was **not** available
   anywhere in the implementation environment (no attachment, no tracked
   file, no scratchpad copy) and returned `BLOCKED: TARGET IMAGE
   UNAVAILABLE` without touching any code, per the issue's own mandatory
   rule.
3. Once the repository owner supplied the image in-conversation, added it
   to the repository (byte-identical, unmodified) at
   `docs/design/references/public_demo_home_ui_3a_target.jpeg` — now the
   **primary visual source of truth** for Issue #147, per the owner's
   explicit follow-up instruction, superseding the external
   `IMG_2643.jpeg` attachment reference.
4. Re-audited the current, already-merged HOME implementation
   section-by-section against that image plus the actual domain/game
   authorities available on this exact `main`, per the owner's explicit
   instruction to treat PR #150 as substantially complete and apply only
   the real diffs found — not a rewrite.
5. Found and fixed exactly **one** small, real, zero-risk gap (see Fix
   below). Every other visible difference from the mockup was re-verified
   as an already-correct, already-documented truthful reduction (no
   authoritative source, or a change that would violate an explicit,
   tested architectural boundary) — detailed section-by-section below.

## AUDITED BASE SHA

- `origin/main` at session start: `65f9a64134f11c4070c7e93f984f00449f1f083d`
  (confirmed via `git fetch origin main` + `git log -1`, and matches the
  SHA the repository owner's own pre-work Issue #147 comment named as the
  fresh baseline after PR #169).
- This SHA **already contains** PR #150 (`fec518a`, "Merge pull request
  #150 from perusonao/claude/issue-147-home-ui-3a") and its P2-fix
  (`8736fb0`) — both from before this session. Confirmed via `git log
  --oneline --all | grep -i "147\|home-ui-3a"`.
- This session's own commits are layered directly on that base, on branch
  `claude/public-demo-home-ui-3a-5qxt76`:
  - `51cf202` — the one wording fix (see below)
  - `b8be100` — the target image addition

## TARGET IMAGE

`docs/design/references/public_demo_home_ui_3a_target.jpeg` — added this
session, byte-identical to the attachment the repository owner supplied
in-conversation (md5 `f09871f67bf1f889c21f6d9c33ddcfd9` verified equal on
both sides before commit; no recompression, regeneration, or any visual
change). This is now the primary visual source of truth for Issue #147,
per the repository owner's explicit instruction — future sessions should
read this repo-local path directly.

**Gate that preceded this**: this session first returned `BLOCKED: TARGET
IMAGE UNAVAILABLE` and made zero code changes, because the image was not
present anywhere in the implementation environment at that point (verified
by `find` across the repository, the session scratchpad, and confirming no
attachment existed) — matching the repository owner's own prior-session
comment that a repository-wide code search had already failed to find any
tracked `IMG_2643` reference. Work resumed only once the owner supplied the
actual image in this conversation.

## READINESS CLASSIFICATION

**START WITH CONDITIONS**, confirmed on inspection, resolving to a single
small fix. The pre-implementation audit found:

- The Required HOME structure (header → month/phase → KPI → 佐倉ひより
  Navigator → office/employee → 今月の重要タスク → クイックアクセス → bottom
  navigation) is already fully present and in the required order on
  current `main`, built by PR #150.
- Section-by-section comparison against the now-tracked target image found
  **one** real, fixable wording inconsistency (below) and **zero**
  structural, ordering, or authority-boundary defects.
- Every other visible gap from the mockup (cash "+2%" trend, 待機 "Pending"
  badge, "（創業期）" phase suffix, the Navigator card's "20%" progress bar,
  per-task priority/deadline/percentage chips, the Office Stage's "See
  all" link, literal quick-access/bottom-nav destination labels) was
  independently re-verified this session — by reading the actual domain/
  presentation models on this exact `main`, not by trusting the prior
  session's report — as still lacking any authoritative data source, or
  (for "See all" specifically) as blocked by an explicit, tested
  architectural contract. Detail in Target-vs-Approved-Image below.

## FIX APPLIED

**File:** `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
(`_importantTasks`, the "資金計画を確認する" row's `fact` string)

**Before:** `'固定費: ${formatYen(_financeSummary.fixedCosts)}'`
**After:** `'今月の固定費: ${formatYen(_financeSummary.fixedCosts)}'`

The approved target image labels this row "今月の固定費: ¥85万" (this
month's fixed costs). The actual screen wiring used the shorter "固定費:
...", while the **existing, already-committed unit-test fixture** for the
same component
(`test/ui/public_demo/public_demo_home_presentation_components_test.dart`,
lines 65 and 137) already used `'今月の固定費: ¥85,000'` — i.e. the intended/
tested wording already existed in the test suite and simply hadn't been
wired into the real screen. This aligns the two. No data, calculation, or
authority changed — `_financeSummary.fixedCosts` (already the latest
month's actual fixed-cost figure, or the pre-close baseline constant) is
read exactly as before; only its caption text changed. Verified no other
test asserts the old exact string (`grep` across `test/`).

## TARGET-VS-APPROVED-IMAGE, SECTION BY SECTION

Read against `docs/design/references/public_demo_home_ui_3a_target.jpeg`
and this session's own fresh renders (`docs/reports/screenshots/
ses147-reaudit-after-360x800.png` / `-390x844.png`, built from the final
commit).

1. **App header.** Matches: leading menu icon (expands + scrolls to the
   dev/test menu), centered "S.E.S. Public Demo 0.1", a real notification
   icon (shows a truthful "現在お知らせはありません" dialog — no fabricated
   badge count, matching the mockup's header, which also carries no visible
   badge on the bell itself). Deploy/build identity lives in the collapsed
   dev/test menu rather than a second header line — unchanged from PR #150,
   re-verified correct against the issue's own instruction to keep it "in
   a compact developer/test surface without visually dominating the
   gameplay header."
2. **Month/phase band.** "1年目 4月" — the mockup's "（創業期）" suffix is
   omitted. Re-verified this session: `UnlockPhase`
   (`lib/game/models/unlock_phase.dart`, `lib/game/engine/unlock_engine.dart`)
   is used only by normal-game screens (`lib/ui/widgets/navigator_card.dart`,
   `lib/ui/recruitment/recruitment_screen.dart`, `lib/ui/others/
   others_screen.dart`) — `PublicDemoState` has no phase concept at all.
   Adding this suffix would require importing a normal-game-only concept
   into Public Demo, which is out of this issue's presentation-only scope.
   Truthful reduction confirmed still correct.
3. **Company summary / KPI grid.** Matches structurally and in tile count:
   icon-led 4-tile + 3-tile grid, 現金/参画/待機/営業残 then 社員/売上/入金予定
   — 7 tiles total, the same count the target image actually shows (a
   careful recount of the image finds one "入金予定" tile with a two-line
   caption, not two separate tiles — the prior session's report describing
   "one fewer than the mockup's 8" appears to have over-read the mockup;
   this session's own count of the image confirms 7, matching current
   code exactly). Cash's "+2%" trend and 待機's "Pending" badge are
   omitted: re-verified this session that `HomeDashboardDisplayData` and
   the KPI tile model (`kpi_section.dart`) carry no trend-percentage or
   pending-status field for either metric — no authority exists to render
   either honestly. 参画 shows a real count ("0名") rather than the
   mockup's "0%" (which has no defined base/denominator anywhere in the
   domain model either) — the truthful choice per the issue's own "render
   a truthful reduced state... instead of fabricating" rule.
4. **Navigator card ("次にやること").** Matches: 佐倉ひより portrait, name,
   総務 badge, "次にやること" eyebrow, headline, message, a dominant primary
   `FilledButton` CTA, a real secondary `OutlinedButton` ("他の行動を確認する"
   — scrolls to the legacy action surface), and the "ひよりからのアドバイス"
   box always visible below. The mockup's "20%" progress bar is omitted:
   re-verified this session (`grep` across `lib/` for any SkillSheet-review
   or per-action progress field) that no authoritative progress value
   exists for this or any recommended action — fabricating one is
   explicitly forbidden by the issue text.
5. **Employee summary ("社員の様子").** Matches: one office-scene card
   (photo, up to 3 portraits + names, `+N名` overflow, an aggregate
   "社員N名・待機N名" badge). The mockup's "See all" link remains **absent**
   — re-verified this session with a stronger finding than the prior
   session's report: `HomeOfficeStageSection` is governed by an explicit,
   already-committed test contract
   (`test/presentation/home/home_office_stage_section_test.dart`, group
   "M: the Office Stage introduces no mutation authority") asserting it
   "holds no gesture, button, or other interactive element" — by design,
   so that this presentation-only component can never become a second
   mutation surface. Adding a tappable "See all" *inside* this component
   would directly violate that tested contract; adding one *around* it
   would require restructuring the section's title/header composition —
   a materially larger change than "smallest presentation-layer fix,"
   and this session's brief was explicitly to apply only the real, minimal
   diff, not redesign a stable, heavily-tested section. Also independently
   confirmed there is no single always-present "full roster" destination
   to route to truthfully in every month/state (the legacy per-employee
   action cards further down the page only show employees relevant to
   that month's actions, not a stable full-roster view). Left as a
   disclosed, deliberate reduction — see Known Gaps.
6. **今月の重要タスク.** Matches, including the fix above: up to 3 items
   (營業活動を進める / 採用・面談に対応する / 資金計画を確認する — the middle
   row is correctly *absent* in April specifically, verified live in this
   session's own screenshot, because the P2-fix's
   `homeImportantTaskHasEligibleAction` gate correctly finds no eligible
   recruitment-pipeline candidate that early — working as designed, not a
   regression), each with one truthful fact, a neutral category chip
   (営業/採用/資金, never a priority claim), and a real CTA. Priority chips,
   progress percentages, and deadlines remain omitted — no authoritative
   source, re-confirmed this session.
7. **クイックアクセス.** Matches: 4 icon+label buttons (社員の様子/収支・会計/
   案件・営業/開発・テスト), each a real on-page scroll-jump — re-verified via
   `PublicDemoQuickAccessSection`'s source, no dead buttons. The mockup's
   literal 5-item destination set (社員一覧/プロジェクト検索/カレンダー/経理・
   会計/設定) does not exist as real screens in this single-screen Public
   Demo; the 4 truthful substitutes remain correct.
8. **Bottom navigation.** Matches the label set (ホーム/社員/営業/会計/
   メニュー) via a Material 3 `NavigationBar`, confirmed in this session's
   own screenshots at both widths. Every destination is a real scroll-jump.
   The mockup's small red dot on "会計" is omitted — no "unread accounting
   notification" concept exists in the domain model; consistent with the
   header's own truthful "no notifications" dialog.

All 8 sections are visibly distinguishable, in the required order, with no
duplicated fact — re-confirmed by this session's own fresh full-page
renders (`docs/reports/screenshots/ses147-tall-verify-360.png` /
`-390.png`, captured at an extended viewport height purely to make every
section visible in one image for this report; the actual layout at
360×800/390×844 scrolls exactly as before, unchanged by this session).

## SCREENSHOTS

- `docs/reports/screenshots/ses147-reaudit-after-360x800.png` — the real
  360×800 initial viewport, this session's final commit.
- `docs/reports/screenshots/ses147-reaudit-after-390x844.png` — the real
  390×844 initial viewport, this session's final commit.
- `docs/reports/screenshots/ses147-tall-verify-360.png` /
  `ses147-tall-verify-390.png` — supplementary full-page renders (390pt/
  360pt wide, extended viewport height) used only to verify every section
  in one image for this report's section-by-section comparison above; not
  a claim about the actual scrollable viewport height, which is unchanged.

No horizontal overflow or clipped content is visible in any render at
either width. The fix's new text ("今月の固定費: ¥50,000") is confirmed
present and correctly positioned in the 今月の重要タスク section in both
tall verification renders.

## TESTS AND EXACT RESULTS

All runs on the final commit (`b8be100`), sandbox Flutter 3.44.9 stable
(matching CI's `subosito/flutter-action@v2` pin).

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found.** |
| `flutter test test/ui/public_demo/ test/presentation/home/` | **418/418 passed** |
| `flutter test` (full suite) | **1514/1514 passed, 0 failed** |
| `flutter build web --release` | **Succeeds** (`✓ Built build/web`) |

No test was skipped, retried, or given a relaxed assertion to reach these
results — the one production change (a single string literal) required no
test changes at all; every existing test that already covered the
important-tasks section passed against it without modification.

## TEXTSCALER RESULTS

Not verified by a new dedicated capture this session — the existing,
already-green widget-test coverage already exercises the real screen at
the required scales, and this session's only production change is a
one-line string literal with no layout implication, so no new TextScaler
risk was introduced:

- `test/ui/public_demo/public_demo_01_home_navigator_test.dart`, group
  "H, I, J: the required viewports" — pumps the real screen at 360×800 and
  390×844, at textScale 1.0/1.15/**1.3**/**2.0**, asserting no overflow
  exception and that the Navigator card's content stays on screen. Part of
  the full suite's 1514/1514 green result above.
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart`, "at
  Npx with increased text scale" (1.3×) and its TextScaler-cancellation
  regression group (added by the P2-fix session, comparing rendered KPI
  value height at 1.0× vs 1.3×/2.0× and asserting no `FittedBox` still
  clamps it) — same real-screen assertions, part of the same green run.
- `test/presentation/home/home_navigator_section_test.dart`, groups "H, I:
  the layout budget" and "J: nothing here is a fixed height" — isolated
  component coverage at the same four scale factors, both widths.

Per the design's own stated principle, at 2.0× later content is expected
to (and does) push further down the scroll rather than being truncated —
confirmed pre-existing behavior, not a regression from this session.

## DOMAIN / FINANCE / SAVE / NAVIGATION IMPACT STATEMENT

**None.** Proof, this session's two commits against the audited base SHA:

```
$ git diff --stat 65f9a64134f11c4070c7e93f984f00449f1f083d..HEAD -- \
    lib/domain lib/game lib/ui/main_shell.dart lib/ui/home/home_screen.dart \
    e2e/tests e2e/playwright.config.ts .github/workflows
(empty — zero files touched)

$ git diff --stat 65f9a64134f11c4070c7e93f984f00449f1f083d..HEAD
 docs/design/references/public_demo_home_ui_3a_target.jpeg | Bin (new file)
 lib/ui/public_demo/public_demo_01_placeholder_screen.dart |   2 +-
 2 files changed, 1 insertion(+), 1 deletion(-)
```

The entire code diff this session made is one string literal in one
presentation-layer file, plus one new binary asset (the target image) with
no code reference from any `lib/` file other than this report and the
GitHub issue comment. `lib/domain/**`, every `lib/game/**` finance/payroll/
balance/month-progression/recovery path, save schema/serialization,
Recommended Action ranking/suppression, employee/project selection
authorities, normal-game HOME (`lib/ui/main_shell.dart`, `lib/ui/home/
home_screen.dart`), E2E retry/sleep/skip/assertion policy, and CI workflow
files are all untouched.

## PR #136 OVERLAP ASSESSMENT

Not independently re-checked this session (out of this session's small,
targeted scope) — the prior PR #150 report's assessment
(`_openSkillSheetReview`'s body only, a disjoint region from every file
this session or PR #150 touched) is unaffected by this session's one-line
change, which is nowhere near that function.

## KNOWN GAPS

- **"See all" affordance on the Employee summary card** — required by the
  issue's literal Required HOME structure text, but not implemented. See
  Target-vs-Approved-Image section 5 above for the full reasoning: adding
  it would either violate `HomeOfficeStageSection`'s explicit, tested
  "no mutation authority" contract, or require a larger structural change
  than this session's minimal-diff brief allows. Recommend a dedicated,
  separately-scoped follow-up if the repository owner wants this addressed
  (e.g. a roster detail view reached from *outside* the Office Stage
  component, with its own small design/test pass) rather than folding it
  into this small fix session.
- **Cash "+2%" trend, 待機 "Pending" badge, "（創業期）" phase suffix,
  Navigator progress bar, per-task priority/deadline/percentage chips,
  literal quick-access/bottom-nav destination labels** — all re-confirmed
  this session as still lacking any authoritative data source. Deliberate,
  disclosed truthful reductions, not oversights.
- **WebKit not exercised** — this sandbox has no WebKit binary (same
  constraint the original PR #150 report and PR #136 both noted); only
  Chromium renders were captured.
- **Playwright e2e suite not run** — out of this session's explicit scope
  (the task's required minimum was `flutter analyze` / focused tests /
  full `flutter test` / `flutter build web --release` plus render
  comparison, all satisfied above). `e2e/tests/public-demo-fresh-start.spec.ts`
  was greped for any string this session's one-line change could affect
  (`固定費`) — no match outside the already-verified test files listed
  above.
- **Deployed Screen Verification** — explicitly required by Issue #147's
  own acceptance criteria before closing, and explicitly out of reach for
  any sandboxed session (no real device/production deploy available here).
  This is the reason Issue #147 remains open — see Merge Readiness.

## COMMIT / BRANCH / PR

- Fix commit: `51cf202` — "fix(public-demo-home): match approved target
  wording for fixed-cost task fact"
- Target image commit: `b8be100` — "docs(design): add repo-local canonical
  copy of Issue #147 target image"
- This report's own commit: recorded in the branch's push log after this
  file is committed.
- Pushed branch: `claude/public-demo-home-ui-3a-5qxt76`
  (`git push -u origin claude/public-demo-home-ui-3a-5qxt76`, confirmed
  both commits present on `origin` before this report was written).
- PR: see the session's final message for the URL, opened against `main`
  once this report was pushed. Body states plainly this does **not** close
  #147.

## MERGE READINESS

**READY WITH CONDITIONS** for this session's own small diff:

- `flutter analyze`, focused tests, full `flutter test` (1514/1514), and
  `flutter build web --release` all pass.
- Zero domain/finance/save/navigation-authority files touched (proof
  above).
- The one production change is a single string literal aligning already-
  merged screen text with an already-existing test fixture's wording and
  the approved target image — no behavior, calculation, or layout change.
- No new overflow, no new TextScaler risk (verified via the existing,
  unmodified, still-green scale-coverage tests).

**Issue #147 itself is explicitly NOT closed by this session**, per the
repository owner's direct instruction and the issue's own acceptance
criteria: "Deployed Screen Verification is required before closing." That
step needs a real device or production deploy, which no sandboxed session
(this one included) can perform. The HOME rebuild's presentation-layer
work is otherwise complete and re-verified against the now-repo-tracked
approved target image; the sole remaining item to close #147 is that
human-performed verification step.
