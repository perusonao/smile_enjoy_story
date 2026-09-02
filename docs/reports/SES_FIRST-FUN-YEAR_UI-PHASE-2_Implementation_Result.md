# SES First Fun Year UI Phase 2 — Implementation Result

## STATUS

**Completed** — implemented, tested (unit/widget + real-browser E2E), committed
and pushed. No PR opened (not requested in the task, though PR creation was
permitted — see "PR / Merge Readiness" below).

## Base SHA

`79c03122a18330db40ca21dd54e59174a7bf4e0f` — `origin/main` HEAD at session
start (merge commit for PR #143, "SES-CI-SPEED-1"). The branch
`claude/ses-first-fun-year-ui-phase-2-53iod9` was reset to this commit before
starting (it previously carried only `f4ca78f`, "Phase 0A/0B", which was
already an ancestor of `origin/main` — already merged — so nothing was
discarded by the reset).

## Branch

`claude/ses-first-fun-year-ui-phase-2-53iod9`

## Commit SHA

`b8051166183131a039d7279c082245cc90d1a9aa` (this report is added in a
follow-up commit on the same branch; see the commit history for its own SHA).

## Investigation summary

The task brief's four real-device findings were checked against the current
`main` (which already carries SES-FIRST-FUN-YEAR-UI-PHASE-1's cleanup):

1. **First view still doesn't fit everything needed.** True in spirit, but
   the specific cause was findings 2 and 3 below, not a missing widget —
   removing the duplication and moving the test-only control freed enough
   height that A's five required facts (month, KPI, Hiyori's guidance, the
   primary CTA, the CTA's subject) already fit with room to spare at both
   360×800 and 390×844 (see the screenshots below).
2. **"ひよりのアドバイス" and "次にやること" duplicated.** Confirmed in code:
   `PublicDemoHomeDashboardSection` composed `HomeNavigatorSection` (name,
   role, a fixed greeting, and — behind a "詳しく見る" tap — an advice bubble
   repeating the *same* action's title/message a second time) immediately
   above a separate `RecommendedActionSection` card stating the identical
   resolved action a third time, with its own always-visible CTA. Three
   renderings of one fact, two of them in visually separate cards.
3. **Test controls mid-flow.** Confirmed: `_publicDemoTestControlsCard()` (a
   distinct amber "テスト用操作" card with a real destructive action) rendered
   directly between the Recommended Action and the Office Stage — inside the
   normal scroll path every player takes.
4. **Office Stage / Employee Stage / Finance Summary bulk.** These were
   already *after* the primary CTA (Phase 1 achieved that ordering) and
   already height-bounded (Office Stage's own safety ceiling, Employee
   Stage's 4+overflow cap, Finance Summary's 2-row trim from Phase 1) — so
   the residual problem here was the test-controls card sitting in the same
   visual weight class between the CTA and this detail, not unbounded
   growth. Removing it, and not asserting anything else that isn't already
   size-bounded, addresses the finding without touching passing structure.

## Implementation

### B — Merge Hiyori's advice and the Recommended Action into one component

- `HomeNavigatorAdvice` (`lib/presentation/home/models/home_navigator_display.dart`)
  gained a `headline` field — the resolved action's own `headline` (e.g.
  `佐藤 健のSkillSheetを確認`), carried separately from `message` (now just the
  guidance line, e.g. `SkillSheetの内容を確認しましょう。`) so a single merged
  card can show "who/what" and "why" without concatenating them into one
  string. `navigatorAdviceFor` sets `headline` from
  `candidate.action.headline` in the `Available` case and leaves it `null`
  for the month-goal/suppressed cases, which name no subject.
- `HomeNavigatorSection` (`lib/presentation/home/widgets/home_navigator_section.dart`)
  is rewritten to be the single guidance component:
  - identity row unchanged (portrait, name, role badge);
  - an eyebrow label — `次にやること` when a CTA is present, `今月やること`
    when the slot fell back to the month goal;
  - the headline (when the slot names a subject), always visible, bold;
  - the guidance message, always visible in full (no longer truncated to
    one ellipsised line behind a tap);
  - the CTA button (`key: home-recommended-action-cta`), directly beneath
    the message, always visible — no tap is needed to reach it, closing the
    gap the old design had (the CTA used to live in a card below, unrelated
    to the "詳しく見る" toggle that gated only the advice bubble);
  - the *optional* educational explanation stays behind the same local
    "詳しく見る"/"閉じる" expand control as before — the one thing this phase
    keeps collapsed by design, so a later phase can still grow it into a
    modal without touching this contract. The bubble no longer repeats the
    title/message/CTA a second time (all three already render above it
    unconditionally) — it now carries only the explanation text.
  - when advice is `null` (a terminal financial state — cash-shortage
    handling stays with `PublicDemoCashShortageCard`/the bankruptcy card,
    unrelated to this widget), the fixed 佐倉ひより greeting is the fallback,
    exactly as before.
- `PublicDemoHomeDashboardSection` no longer composes `RecommendedActionSection`
  at all. It computes an `_effectiveAdvice`: when the resolved slot is
  `HomeRecommendedActionNone` (nothing eligible), it substitutes
  `HomeDashboardDisplayData.monthGoalText` — the existing, more specific
  per-month text — for the generic `HomeNavigatorAdvice.neutral.message|`,
  so the merged card states the concrete monthly goal instead of a vague
  "今すぐ必須の操作はありません。" line. This is a text substitution over two
  already-projected, read-only fields the section already received — no new
  ranking, no new game-state read.
- `RecommendedActionSection`/`home_recommended_action.dart` (the model:
  `HomeRecommendedActionKind`, `selectHomeRecommendedAction`, …) are
  **unchanged and still used** — only the composition into the runtime HOME
  screen changed. The widget itself keeps its own dedicated unit test
  (`test/presentation/home/home_recommended_action_test.dart` /
  `home_navigator_section_test.dart`'s sibling), so it remains a valid,
  independently-tested component simply not wired into this screen anymore.

### C — Test controls out of the normal flow

- `PublicDemo01PlaceholderScreen` gained `_isDevMenuExpanded` (defaults
  `false`) and `_publicDemoDevMenuSection()`: a `Divider` plus a
  `TextButton.icon` toggle labelled "開発・テストメニュー" (`key:
  public-demo-dev-menu-toggle`), placed at the very end of the screen's
  Column — after every per-month/per-employee card, after internal
  training. `_publicDemoTestControlsCard()` itself (key, label, dialog,
  behaviour) is **unchanged**; it now only renders when the fold is open.
- The mid-flow call site (between the merged navigator card and the Office
  Stage) is deleted outright — nothing was left in its place.

### D — Information hierarchy

Office Stage, Employee Stage, Important Events, Finance Summary, and the
per-month/per-employee detail cards keep their existing position (already
after the primary CTA, already height-bounded per Phase 1) — this phase did
not need to additionally collapse or relocate them, because the volume
finding traced to the test-controls card sharing their visual weight class,
not to their own unbounded growth. Removing that one card, and shrinking
the merged guidance block (one card + one CTA instead of two), is what
actually restores the intended hierarchy: month → KPI → Hiyori's one
resolved decision → (everything else, further down, unchanged).

## Domain / Finance / Persistence / save schema / balance / month rules

**None changed.** This phase touched only presentation composition:

- `lib/presentation/home/models/home_navigator_display.dart` (added a field,
  changed `message`'s content, no behavioural/game-state change)
- `lib/presentation/home/widgets/home_navigator_section.dart`
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `lib/ui/public_demo/public_demo_home_dashboard_section.dart`

No file under `lib/game/` was touched. No command, guard, eligibility
predicate, formula, or save-schema field changed. The Recommended Action
CTA still runs the exact same already-bound `PublicDemoAggregate` command
the corresponding per-employee/legacy button runs — only where that button
is drawn changed.

## Changed files

- `lib/presentation/home/models/home_navigator_display.dart`
- `lib/presentation/home/widgets/home_navigator_section.dart`
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `lib/ui/public_demo/public_demo_home_dashboard_section.dart`
- `test/presentation/home/home_navigator_advice_adapter_test.dart`
- `test/presentation/home/home_navigator_section_test.dart`
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart`
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart`
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart`
- `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`
- `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart`
- `test/ui/public_demo/public_demo_01_persistence_test.dart`
- `e2e/helpers/public-demo-player.ts` (`restartFromApril` now opens the dev
  menu fold first, idempotently)
- `e2e/tests/public-demo-july-restart.spec.ts` (opens the fold before the
  restart flow)
- `e2e/tests/public-demo-annual-route.spec.ts` (opens the fold before
  asserting the reset control's post-terminal availability)
- `docs/reports/SES_FIRST-FUN-YEAR_UI-PHASE-2_Implementation_Result.md`
  (this report)

`RecommendedActionSection`/`home_recommended_action.dart` and their own
dedicated tests are unmodified — no longer composed into the runtime
screen, but still valid, still tested, still reusable.

## 360×800 / 390×844 verification

Flutter 3.47.2 (stable, matching `sdk: ^3.9.2`) was installed for this
session (not preinstalled). `flutter build web --release` succeeded; the
bundle was served locally and driven with a headless Chromium (the
session's pre-installed browser) at both target sizes via `?e2e=1#/public-demo-01`,
fresh April state — matching the existing harness's own entry route.

Results at both 360×800 and 390×844 (screenshots captured; ARIA-snapshot
text cross-checked):

- **No horizontal overflow**: `document.documentElement.scrollWidth ===
  clientWidth` at both sizes.
- **First view, top to bottom, in a single unscrolled screenshot**: 月
  (`1年目 4月`) → 7-tile compact KPI (現金/参画/待機/営業残/社員/売上/入金予定) →
  **one** merged 佐倉ひより card — eyebrow `次にやること`, headline `佐藤 健の
  SkillSheetを確認`, guidance text, and a full-width `→ SkillSheetを確認`
  CTA — → Office Stage → Employee Stage. All five of condition A's required
  facts (current month, KPI, Hiyori's guidance, the primary CTA, the CTA's
  subject) are visible with no scrolling, at both sizes, with headroom to
  spare (Office Stage and Employee Stage are visible too, in this
  chrome-free headless capture).
- **No duplicate guidance card**: the string `ひよりからのご案内` (the old
  bubble's own title, still used as `HomeNavigatorAdvice.title`) does not
  appear as a second card heading anywhere in the ARIA snapshot — there is
  exactly one guidance component.
- **No inline test controls**: `テスト用操作` does not appear anywhere in the
  unscrolled or scrolled-through snapshot until the "開発・テストメニュー"
  fold is explicitly opened (confirmed via the real E2E run below, which
  scrolls with real touch gestures and opens the fold before asserting on
  the restart control).

As in Phase 1, this sandbox's headless Chromium does not respond to
synthetic `mouse.wheel`/touch-drag against the CanvasKit-rendered scroll
view when driven ad hoc (outside the project's own Playwright harness), so
the dev-menu fold's own scroll-and-tap behaviour was verified instead
through the **real** Playwright E2E suite (`--project=mobile-chromium`,
real Pixel 7 touch emulation) — see below — which did successfully scroll,
open the fold, and interact with the restart control end-to-end.

## flutter analyze

```
Analyzing smile_enjoy_story...
No issues found! (ran in 7.1s)
```

## flutter test

Full repository suite: **1394 tests, all passing**, exit code 0 (~9m25s of
in-suite elapsed time under this sandbox's software-rendered Flutter test
execution, consistent with Phase 1's ~8.5 minutes; no test was retried,
skipped, or given a longer timeout to reach this result).

Focused re-runs during development (all passing, each confirmed
individually before moving to the next file): `home_navigator_section_test.dart`
(57 tests), `home_navigator_advice_adapter_test.dart`, `public_demo_01_home_navigator_test.dart`
(29), `public_demo_01_home_consolidation_test.dart` (30),
`public_demo_01_home_office_stage_test.dart` (16), `public_demo_01_home_recommended_action_test.dart`
(23), `public_demo_01_home3_integration_test.dart`, `public_demo_01_home_runtime_read_test.dart`,
`public_demo_01_skill_sheet_flow_test.dart`, `public_demo_01_fiscal_year_progression_test.dart`,
`public_demo_home_presentation_components_test.dart`, `public_demo_01_persistence_test.dart`.

No test was skipped, retried, given a longer timeout, or weakened from
`findsOneWidget` to a looser matcher. Every assertion removed for a key that
no longer exists (`home-recommended-action`, `home-month-goal`,
`home-navigator-rationale`, the old bubble's nested
`home-navigator-advice-title`/`-message`/`-cta`) was replaced with an
equal-or-stronger assertion against the same fact's new, correctly-keyed
home (mostly `home-recommended-action-cta`/`-headline`, which are unchanged
keys reused in their new position, and `home-navigator-message`).

`git diff --check`: clean, no whitespace errors.

## E2E impact

Two Playwright specs referenced the moved test-restart control and were
updated (not weakened — they now open the "開発・テストメニュー" fold, exactly
as a real player would have to, before doing what they already did):

- `e2e/tests/public-demo-july-restart.spec.ts` — **PASSED** in a real run
  against this branch's `build/web` (`--project=mobile-chromium`, real
  touch-emulated scrolling): the July-close → test-restart-from-August →
  cancel → confirm → April-again flow works unchanged end to end.
- `e2e/tests/public-demo-annual-route.spec.ts` — **PASSED**, all 8 tests
  (both viewport widths), including the full April→March terminal-close
  route that specifically asserts the reset control remains reachable
  after bankruptcy (now via the fold).
- The shared helper `restartFromApril` (`e2e/helpers/public-demo-player.ts`)
  was updated the same way, so any future spec calling it inherits the
  correct fold-opening step automatically.

No other Playwright spec references the affected keys/text (`home-recommended-action*`,
`home-navigator*`, `home-month-goal`, `テスト用操作`, `4月からやり直す`,
`次にやること`, `今月やること` were grepped across every `e2e/tests/*.spec.ts`
and `e2e/helpers/*.ts`) — no other E2E flow is affected by this phase's UI
changes. Both patched specs were run for real (not just reasoned about) in
this session; no stale-vs-real-bug judgment call was needed because both
came back green after the same one-line fix (open the fold first).

## Known Issues / limitations

- This sandbox's ad hoc (non-harness) Playwright scripting could not
  synthesize a working scroll gesture against CanvasKit — the same
  limitation Phase 1 documented. The dev-menu fold's scroll+tap behaviour
  is verified through the project's own E2E harness instead (which does
  work, and did pass), not through an additional ad hoc screenshot.
- `dart format --output=none --set-exit-if-changed` reports ~169 files
  across the *entire* repository (almost none touched by this phase) as
  needing reformatting under this session's Flutter 3.47.2/Dart 3.13.2
  toolchain — a pre-existing formatter-version drift from whatever
  produced the current `main`, unrelated to this change. Nothing was
  reformatted (that would have been a large, unrelated diff); the task's
  own verification checklist names `flutter analyze`/`flutter test`/`git
  diff --check`, not `dart format`, and all three are clean for this
  change.
- `pubspec.lock` was touched by this session's `flutter pub get` (a few
  transitive dependency bumps) and was reverted before committing — not
  part of this change.
- The Employee Stage/Office Stage/Finance Summary volume named in problem
  #4 was addressed by removing the test-controls card sharing their visual
  weight (see "Implementation" above) rather than by additionally
  collapsing them; they were already ordered after the primary CTA and
  already height-bounded from Phase 1. If a future device pass still finds
  them crowding the reachable-without-much-scrolling zone, collapsing that
  block behind its own fold (mirroring the dev-menu pattern) is the natural
  next step and was deliberately not done here to keep this phase's blast
  radius to the two problems (B, C) that needed a real behavioural change.

## First Fun Year playthrough readiness

No domain, finance, persistence, save-schema, or month-progression rule
changed, so playthrough readiness is unchanged at the mechanics level. On
the UI side: HOME's first view now shows month + KPI + one merged
guidance-and-CTA card + the CTA's subject, with no duplicate card and no
test-only control in the normal flow, matching this phase's "経営判断の入口"
goal. The full April→March annual route (`public-demo-annual-route.spec.ts`,
both Route A/current-behavior and Route B/Recovery-completion, both
viewport widths) was driven end to end against a real browser in this
session and passed, so a First Fun Year playthrough can begin from this
branch with the same confidence Phase 1 left it in, plus this phase's HOME
usability fixes.

## PR / Merge Readiness

No PR was created (not explicitly requested, though permitted). Branch
`claude/ses-first-fun-year-ui-phase-2-53iod9` was pushed to `origin`.
`flutter analyze` is clean, the full repository suite (1394 tests) passes,
`git diff --check` is clean, and both Playwright specs touched by this
phase pass for real against a built `build/web`. Mergeable as-is.
