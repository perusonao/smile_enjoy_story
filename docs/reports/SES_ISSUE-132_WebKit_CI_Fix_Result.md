# SES Issue #132 WebKit CI Fix Result

## Status

PASS — fix implemented, verified locally (Flutter analyze/test + Playwright
mobile-chromium), and pushed to the existing PR #136 branch. WebKit itself
could not be executed in this sandbox (network policy blocks the WebKit
binary's download host); this is stated explicitly rather than claimed. PR
CI (mobile-webkit job) is the authoritative verification for that browser.
PR #136 was **not** merged.

## PR

[#136](https://github.com/perusonao/smile_enjoy_story/pull/136) — `feat(public-demo): integrate SkillSheet Phase A redesign`
branch: `claude/issue-132-phase-a-main-integration`

## Base SHA

`25a2e9b6b401794090151cc86006e433c8d9a789` (`origin/main`) — confirmed via
`git fetch origin` at task start; matches the PR's own stated base exactly,
no drift.

## Previous PR HEAD

`1a18a88432e6e1f9b7b1b1bb9561cef125b4c2f0` — confirmed via
`pull_request_read` at task start; matches the task's expected lineage
exactly (3 commits ahead of base: the #132 Phase A cherry-pick + two docs
commits). No unexpected change to head or base was found, so the fix
proceeded.

## Final HEAD

See COMMIT/PUSH section below for the exact pushed SHA (recorded after
push, per the task's verification step).

## Root Cause

**Test/semantics visibility defect — not a production UI defect, and not a
generic "WebKit flake."**

`PublicDemoSkillSheetSheet` (`lib/ui/public_demo/public_demo_skill_sheet_sheet.dart`)
wraps its entire body — header, summary, and all five accordion sections —
in one `SingleChildScrollView`. The last section, `営業・面談プロフィール`
(already `initiallyExpanded: true`, holding `案件スキル適合` /
`ヒューマンスキル` / `モチベーション` / `取引先からの信頼`), sits below the
fold on a phone-height viewport (800px) until that scroll view is actually
scrolled — the sheet itself is bounded to 90% of screen height, and four
other sections (`基本プロフィール`, `技術スキル`, `経験`, `案件/参画情報`)
render above it.

Flutter Web's accessibility/semantics tree only attaches a scrollable
child's semantics once it is scrolled into view. This repository has
already hit and solved the identical class of bug three times before this
fix, each with its own local helper doing the same bounded/polling
`page.mouse.wheel()` scroll (see `clickScrollableButton` in
`public-demo-july-restart.spec.ts`, `scrollToButton` in
`public-demo-single-month-cta.spec.ts`, and `scrollUntilButtonFound` in
`phase-3b1-fit-reason.spec.ts` — the last one's own doc comment states this
exact mechanism was "confirmed directly against the real ariaSnapshot()
output during development"). `e2e/helpers/artifacts.ts` additionally
documents (PR #80 follow-up) that Playwright's native
`page.mouse.wheel()` is unsupported on mobile WebKit and that WebKit
reports Flutter's semantics scrollers as `overflow-y: visible` rather than
`scroll` — which is also why this fix does not rely on Playwright's
built-in `.click()` auto-scroll (`scrollIntoViewIfNeeded`, which depends on
that same overflow CSS) for the accordion-header clicks.

The failing assertions were plain `getByText(...).toBeVisible()` calls made
immediately after opening the sheet, with no scroll step — i.e. the tests
asserted against an unscrolled viewport rather than reproducing what a real
player scrolling the sheet would see. Chromium passed only because its
`page.mouse.wheel()` support (used implicitly nowhere in the *old* test) was
never exercised — the old test simply never needed a working wheel path
because Chromium's own semantics-tree behavior for this particular geometry
happened not to require the scroll (not confirmed further, out of scope —
what matters is that the *content itself* is real, present, and reachable
by scrolling in both engines; this is a test gap, not a Chromium-only
production behavior).

Production code (`public_demo_skill_sheet_sheet.dart`,
`public_demo_skill_sheet_sections.dart`) was read in full and left
unchanged: the sheet is genuinely scrollable, the content is genuinely
present and correct, and a real WebKit/Safari user scrolling the sheet with
a finger would see it exactly as intended. No evidence surfaced that the
production UI is wrong.

## CI Failure Evidence

Playwright run `33450496884`, `mobile-webkit` project: 64 passed / 3 failed,
all three deterministic (failed again on retry):

1. `e2e/tests/public-demo-fresh-start.spec.ts` — blocked at
   `expect(page.getByText('案件スキル適合', { exact: true })).toBeVisible()`.
2. `e2e/tests/public-demo-skillsheet-phase-a.spec.ts` @ 360x800 — same
   assertion, same blocking point.
3. `e2e/tests/public-demo-skillsheet-phase-a.spec.ts` @ 390x800 — same.

All three failures occur immediately after the sheet successfully opens and
after `営業用SkillSheet` / `Java / SQL・開発経験3年` (summary text, above
the fold) are confirmed visible — i.e. exactly at the boundary between
above-the-fold and below-the-fold content within the sheet's own scroll
view, consistent with the root cause above.

## Production Code Changes

**None.** `lib/` is untouched. No Domain, Finance, or Persistence changes
of any kind — this fix is entirely test-side.

## E2E Changes

Two files, both purely additive/reordering (no assertion was weakened or
removed):

- `e2e/tests/public-demo-fresh-start.spec.ts` — added a local
  `scrollSheetUntilVisible` helper (mirrors the existing
  `clickScrollableButton`/`scrollToButton` pattern already used elsewhere in
  this suite: bounded polling loop, re-centers the mouse first, scrolls up
  or down depending on which side of the viewport the target currently
  sits). Inserted one call to it, immediately before the
  `案件スキル適合`/`ヒューマンスキル` assertions, so they run against a
  viewport that has actually scrolled the target into view — the same
  action a real player would take. No assertion text, count, or timeout was
  changed.
- `e2e/tests/public-demo-skillsheet-phase-a.spec.ts` — same helper, plus a
  `scrollSheetAndClick` wrapper (scroll-then-click) used to replace the two
  bare `.click()` calls on the `技術スキル`/`経験` accordion headers.
  Those headers sit above the section the new scroll step advances past, so
  a plain `.click()` would depend on Playwright's native
  `scrollIntoViewIfNeeded`, which `e2e/helpers/artifacts.ts`'s own PR #80
  follow-up documents as unreliable for Flutter's semantics scrollers on
  WebKit (`overflow-y: visible`) — the scroll-and-click wrapper uses the
  same wheel-based mechanism as the rest of this fix instead, for
  consistency and to avoid introducing a new fragile assumption. All
  assertions and their expected text/counts are unchanged; only their
  reachability is fixed.

No timeout was increased as the fix. No test was skipped, weakened, or
converted to a weaker assertion (e.g. count-only). WebKit itself is not
skipped or bypassed anywhere in `playwright.config.ts` or these specs.

## #117 Compatibility

Unaffected. `public_demo_01_skill_sheet_flow_test.dart` (the #117 widget
test) was not touched and passes (see Tests below). The Phase A sheet
preserves every #117 key/semantic verbatim (root `Key('public-demo-skill-sheet-<id>')`,
`Key('public-demo-skill-sheet-cancel-<id>')`,
`Key('public-demo-skill-sheet-confirm-<id>')`, `Navigator.pop(context, true/false)`
semantics) — confirmed by reading `public_demo_skill_sheet_sheet.dart`
directly; this fix did not need to and did not touch it. The e2e fix itself
strengthens #117's own smoke test (`public-demo-fresh-start.spec.ts`) by
making its 案件スキル適合/ヒューマンスキル assertions actually reachable
in WebKit instead of only in Chromium.

## #118 Single CTA Preservation

Unaffected. `public-demo-single-month-cta.spec.ts` was not modified and
passes locally (7/7 chromium, see Tests below); no production file
(`public_demo_01_placeholder_screen.dart`) was touched by this fix.

## #133 Regression Preservation

Unaffected. `public-demo-july-restart.spec.ts` (the #133 July close/restart
regression spec) was not modified by this fix; its own `clickScrollableButton`
helper is exactly the precedent this fix's `scrollSheetUntilVisible`/
`scrollSheetAndClick` helpers were modeled on.

## Domain Impact

None. No `lib/game/` or `lib/domain/`-equivalent file was read for editing
or changed.

## Finance Impact

None. No finance-related file was changed.

## Persistence Impact

None. No persistence-related file was changed.

## Tests

Run locally in this sandbox against Flutter 3.44.9 (matching
`.github/workflows/e2e.yml`'s pinned CI version exactly — the SDK was
downloaded fresh into this sandbox since it was not preinstalled):

- `flutter analyze`: **clean, no issues** (13.3s).
- `flutter test` (full suite): **1324/1324 passed.**
- `flutter test test/ui/public_demo/` (all 25 files, full Public Demo
  surface incl. #117/#118/#132 regressions): **191/191 passed**, including
  `public_demo_01_skill_sheet_flow_test.dart` (#117) and
  `public_demo_01_home3_integration_test.dart` (overflow regression at
  360px/390px).

Neither `flutter analyze` nor `flutter test` could be affected by this fix
in principle — the diff touches zero `.dart` files — but both were run in
full anyway per the task's instructions, against the exact same commit this
fix is built on.

TypeScript: `npx tsc --noEmit` over `e2e/` — clean, no errors.
`npx playwright test --list` — all 7 target tests parse and enumerate
correctly.

## Chromium Result

**7/7 passed** (`npx playwright test --project=mobile-chromium` against a
locally built `flutter build web --release --no-web-resources-cdn`, using
the pre-installed sandbox Chromium binary via the config's
`SES_E2E_CHROMIUM_PATH` escape hatch, since Playwright's own managed
Chromium revision could not be downloaded in this sandbox):

- `public-demo-fresh-start.spec.ts` — 1/1 passed.
- `public-demo-skillsheet-phase-a.spec.ts` @ 360x800 and @ 390x800 — 2/2
  passed (both previously-untested-on-WebKit assertion blocks now verified
  reachable end-to-end, including the accordion re-scroll for
  `技術スキル`/`経験`).
- `public-demo-single-month-cta.spec.ts` @ 360px and @ 390px (April + May)
  — 4/4 passed (untouched by this fix; run as a #118 regression check).

## WebKit Result

**Not run locally — stated explicitly, not claimed as pass.** This
sandbox's network policy blocks the WebKit binary's download hosts
(`cdn.playwright.dev`, `playwright.download.prss.microsoft.com` — all
attempts returned `403 request blocked: no rule or allowlist entry allows
host`), and no WebKit binary is preinstalled here (only a Chromium build,
per `/opt/pw-browsers`). This matches the same constraint the original PR
#136 report already documented for its own local verification. The fix is
pushed and **PR CI's `mobile-webkit` job (run 33450496884's successor on
the new commit) is required to confirm the actual WebKit result** — this
report does not claim WebKit passes.

## Diff Audit

`git diff --check`: clean (no whitespace errors).

`git diff origin/main...HEAD --stat` (cumulative PR diff after this push)
adds exactly the two e2e spec files on top of the PR's existing file set;
no `lib/`, `test/`, or other e2e file beyond the two edited here appears in
the working-tree diff for this fix
(`e2e/tests/public-demo-fresh-start.spec.ts`,
`e2e/tests/public-demo-skillsheet-phase-a.spec.ts` — 128 lines added, 2
lines removed, both purely additive helper functions + their call sites/doc
comments). No unrelated change (formatting, renames, other spec files,
CI config, production code) is present.

## Remaining Risks

- WebKit itself was not run locally (see WebKit Result); this fix's
  correctness for that engine rests on the same wheel-based scroll
  mechanism (`page.mouse.wheel()` via `installPortableWheelFallback`,
  including its explicit mobile-WebKit touch-swipe fallback) that three
  other specs in this suite already rely on successfully in CI's real
  mobile-webkit job — reasoned confidence, not a confirmed local run.
- If a future change reorders or removes sections within
  `PublicDemoSkillSheetBody`, the doc comments on `scrollSheetUntilVisible`
  explain why the scroll exists so a maintainer does not mistake it for
  dead code, but the helper itself does not encode which section is "last"
  — it will keep working correctly regardless of section order since it
  polls for the actual target rather than a fixed scroll distance.

## Merge Readiness

Not merged (out of scope for this task, and not requested). Once PR CI
confirms `mobile-webkit` green on the new HEAD, and Claude Approvals (if
applicable) has no other open findings, PR #136 is ready for human review
and merge decision.
