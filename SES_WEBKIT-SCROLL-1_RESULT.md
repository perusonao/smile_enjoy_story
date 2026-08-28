# Result

SES_WEBKIT-SCROLL-1 — make mobile-WebKit scrolling real, and observable.

**Root Cause Classification: A** — the CTA exists in GameState and in the
widget tree, but is never materialized into Flutter's semantics tree.
Established by direct side-by-side observation, not deduction.

**Merge Readiness: PASS** — every Phase 4 gate is met on run `33196143453`.
`e2e-webkit` is **green for the first time** in this repo's recent history.
Nothing has been pushed to PR #85; see *PR #85 Merge Readiness*.

> One honest caveat, not buried: the WebKit suite reported **1 flaky** —
> `beginner-mode-april-june` seed 100002. It is analysed in *WebKit Results*.
> It cannot be caused by this change (that test never reaches the modified
> code path), but it did pass cleanly in the baseline run, so it is reported
> as a new observation rather than dismissed.

---

## Diagnostic Commit

`6300f07f58963afa52dd6b682eb5ddddc2a265b8` — *test(e2e): log WebKit failure
evidence to CI job log (SES_WEBKIT-SCROLL-1 P1)*

Diagnosis only. No behaviour change: the wheel fallback's control flow, every
event it dispatched, and its early `return` were byte-for-byte identical to
`23e5b68`; only measurement and a return value were added.

Branch: `claude/pr85-webkit-e2e-investigation-ovgiji`, based on PR #85's
reviewed HEAD so the diagnostic observed that exact head.

Diagnostic CI run: **33193672549** (`workflow_dispatch`, one run).

## PR #85 Original HEAD

`23e5b686572a40edd6f1cc1595499c685de9450d` — *test: target Flutter semantics
scroller on mobile WebKit*

**Untouched.** Nothing has been pushed to
`agent/e2e-interview-offer-scroll-reachability`. All work landed on
`claude/pr85-webkit-e2e-investigation-ovgiji`, which branches *from*
`23e5b68`.

## Final HEAD

`7bca23ca1d24dcde65e27525ba143e4d6e0b7fb4` — *test(e2e): make the mobile-WebKit
scroll fallback actually scroll*

Lineage: `ea0a4f2` (main) → `a6bc636` → `23e5b68` (PR #85 HEAD) → `6300f07`
(diagnostic) → `7bca23c` (fix + tests).

Phase 4 validation run: **33196143453** — `validate` ✅, `e2e-chromium` ✅,
**`e2e-webkit` ✅**.

## Failure Evidence

All of it from the GitHub Actions **job log**, exactly as Phase 1 required —
no 300 MB+ artifact download, which this session cannot perform anyway
(the artifact host `productionresultssa15.blob.core.windows.net` is denied by
the egress policy, `CONNECT tunnel failed, response 403`).

Diagnostic run 33193672549, `e2e-webkit`, `phase-3b1-fit-reason` seed 100001:

```
[SES-DIAG] week#1  homeWeek=13 weeksWaited=1  homeOffer=false settleOffer=false
           detailOfferText=false cta(before/after)=false/false detailButtons=3->3
           scroll{steps=15 everChanged=false changes=0 exit=maxSteps
                  wheel=15 wheelMoved=0 strategies={"generic":15}
                  fltSemantics=19/0 overflowY={"visible":18,"hidden":1}}
[SES-DIAG] week#2  homeWeek=14 weeksWaited=2  homeOffer=false settleOffer=true   ← offer arrives
[SES-DIAG] week#3  homeWeek=15 weeksWaited=3  homeOffer=true  settleOffer=true
...
[SES-DIAG] week#10 homeWeek=22 weeksWaited=10 homeOffer=true  settleOffer=true
           detailOfferText=false cta(before/after)=false/false detailButtons=3->3
           scroll{steps=15 everChanged=false changes=0 exit=maxSteps
                  wheel=15 wheelMoved=0 strategies={"generic":15}
                  fltSemantics=21/0 overflowY={"visible":20,"hidden":1}}

[SES-DIAG] === SUMMARY seed=100001 ===
[SES-DIAG] offerAccepted=false weeksWaited=10 iterations=10 exit=maxWeeks
           homeOfferEverSeen=true settleOfferEverSeen=true
           detailOfferTextEverSeen=false ctaEverSeen=false
           anyScrollEverChanged=false
           totalWheelInvocations=150 totalWheelMoved=0
```

The offer's existence, from two surfaces that do not depend on scrolling:

```
[SES-DIAG] week#2 settleOfferMarkers=[
  "今週の重要な変化 1 面談依頼！ 田中 亮さん / QA体制強化支援 → 面談を見る",
  "今やること 最優先 田中 亮さんに面談依頼があります 受けるか断るか判断してください"]
[SES-DIAG] week#3 settleOfferMarkers=[
  "重要事項が残っています まだ今週対応できる重要事項があります。
   ・田中 亮さんに面談依頼があります このまま次の週へ進みますか？", ...]
```

Both surfaces are load-bearing and were chosen deliberately:

- `TaskEngine.generateTasks` adds a **critical** Home task per pending
  `InterviewOffer`, ungated by the employee's workflow state — necessary
  here, because `EmployeeWorkflowEngine` ranks `assigned` above
  `interviewRequestPending`, so this engineer reads 参画中 everywhere and the
  status card never mentions the offer.
- `home_screen.dart`'s `_handleNextWeek` lists **every** Critical task in a
  「重要事項が残っています」 dialog before it will advance the week —
  deliberately exhaustive rather than the top-N the hero card ranks.

That second surface was added after the first diagnostic dispatch was
cancelled: the hero card shows only the single top-ranked task, and at week#2
it was showing 「面接待ちの応募者が9名います」 instead — so a hero-card-only
reading would have reported `homeOffer=false` on the very week the offer
arrived, and risked a false **B**. The exhaustive dialog cannot be ranked out
of view.

## ARIA Snapshot Findings

The decisive comparison. Same seed, same Week 14, same offer
(`Axis Soft / QA体制強化支援 / ¥523,595`), same GameState — only the browser
and viewport differ.

**mobile-webkit (iPhone 14, 390×664) — engineer detail, before AND after 15 scroll steps (identical):**

```
---- engineer detail BEFORE scroll: 4 texts, 3 buttons ----
  text   | 田中 亮
  text   | 田中 亮 参画中 参画中 ネットワーク基盤保守 残り14週 / 単価 ¥790,147 ...
  text   | 社員コンディション モチベーション 😊 高い ...
  text   | スキルシート / 営業 会社信頼 普通 Java ... 営業状態 営業中（公開先 2社）...
  button | enabled  | アップグレード
  button | enabled  | 営業用記載を編集
  button | disabled | 営業を開始する
---- engineer detail AFTER scroll: 4 texts, 3 buttons ----   ← byte-identical
```

**mobile-chromium (Pixel 7, 412×839) — engineer detail, before any scroll:**

```
---- engineer detail BEFORE scroll: 7 texts, 5 buttons ----
  ... same first four ...
  text   | 面談依頼
  text   | 面談依頼！ Axis Soft QA体制強化支援 単価 ¥523,595 / tokyo / other ...
  text   | 基本情報 月給 ¥534,312 主言語 Java ...
  button | enabled  | アップグレード
  button | enabled  | 営業用記載を編集
  button | disabled | 営業を開始する
  button | enabled  | 断る
  button | enabled  | 面談へ進む          ← materialized without any scrolling
```

Chromium summary for the same test: `offerAccepted=true weeksWaited=2
iterations=2 exit=offerAccepted ctaEverSeen=true anyScrollEverChanged=true
totalWheelInvocations=0` (native wheel; the fallback never runs there).

Two further points the snapshots settle:

- The offer arrives at **exactly** the week and with **exactly** the project
  the spec's own determinism note documents ("seed 100001 reaches a
  QA体制強化支援 offer exactly 2 week-advances after starting the second sales
  search at Week 13"). The RNG determinism claim is therefore confirmed *on
  WebKit*, not merely assumed.
- The WebKit tree stops precisely after the tall `スキルシート / 営業` card —
  which is the child immediately preceding `if (interviewOffers.isNotEmpty)
  ... _SectionCard('面談依頼')` in `EngineerDetailScreen`'s `ListView`
  (`engineer_detail_screen.dart:98`, `:164`, `:526`).

## Root Cause Classification

### A — CTA/event exists, but is not materialized into Flutter semantics

Proven, not inferred:

1. The offer exists in GameState on WebKit — Home reports it every week from
   Week 14 through Week 22, on two independent surfaces.
2. The engineer detail screen's semantics tree never contains 面談依頼 or
   面談へ進む, on any of 10 weeks, before or after any scroll.
3. Chromium, at the same seed/week/offer, materializes it with no scrolling
   at all.
4. `EngineerDetailScreen.body` is a plain `ListView(children:)` →
   `SliverChildListDelegate` → `RenderSliverList`, which lays out only
   viewport + `cacheExtent` children. An un-laid-out child has no render
   object and therefore no semantics node — invisible to every Playwright
   locator, `expect`, and actionability check.
5. iPhone 14 has **175 px (≈21 %) less vertical space** than Pixel 7
   (390×664 vs 412×839, Playwright device registry), and after the AppBar the
   usable list height is smaller still.

**B is excluded** by (1) and (3): the offer is generated on WebKit, at the
documented week, with the documented project.

This supersedes the earlier review's verdict of *B (PARTIALLY CONFIRMED)*,
which was limited only by the blocked artifacts. The single diagnostic CI run
that review asked for is what closed the gap.

## Scroll Root Cause

Separate from, and downstream of, the classification above: **why 150 scroll
attempts moved nothing.** Two independent defects, both measured.

**1. The synthetic `WheelEvent` was constructed with no `clientX`/`clientY`.**

```js
new WheelEvent('wheel', { bubbles, cancelable, deltaX: x, deltaY: y, deltaMode })
//  ^ no coordinates -> clientX = clientY = 0
```

Flutter's `PointerBinding` hit-tests a wheel signal by the event's **own
client coordinates**, never by its DOM target. So every scroll the fallback
has sent since PR #81 was aimed at (0, 0) — the AppBar, which is not
scrollable. Choosing the right dispatch element via `elementFromPoint` could
not compensate, because that choice was never what Flutter consulted.

**2. PR #85's `flt-semantics` filter matched nothing, on every invocation.**

Measured `overflowY` histogram across all `flt-semantics` nodes:
`{"visible": 20, "hidden": 1}` of 21. The filter required
`overflow-y: scroll | auto`, so it matched **0 of 21 nodes on all 150
invocations** — `strategies={"generic":15}` every single week. Flutter's real
scroller is never `scroll`/`auto` here.

The generic branch behind it then picked an element with
`scrollHeight > clientHeight` but non-scrollable overflow, whose `scrollTop`
never moves: `wheelMoved=0/150`.

Both defects were silent. Nothing in the harness checked whether a scroll had
any effect, so the spec failed with the ordinary "CTA not found" assertion —
indistinguishable from the CTA legitimately not being there. That conflation
is what allowed the defect to survive PR #81 and PR #85.

This also **falsifies PR #85's premise**: commit `23e5b68` is dead code on
mobile WebKit. The earlier review inferred this from timing arithmetic; it is
now directly measured.

## Fix

`installPortableWheelFallback` now tries strategies in order and **verifies
each one against a semantics-tree signature** before accepting it, stopping at
the first that demonstrably moved something:

| Strategy | What changed |
|---|---|
| `wheelEvent` | now carries real `clientX`/`clientY` (and `screenX/Y`) at the viewport centre |
| `pointerDrag` | new — a synthetic touch-pointer drag through Flutter's ordinary gesture pipeline |
| `semanticsScroll` | every *programmatically* scrollable `flt-semantics`, tried in turn, since computed `overflow-y` does not identify Flutter's real scroller |
| `genericScroll` | largest-overflow elements, tried in turn rather than only the first |
| `windowScroll` | unchanged, last resort |

Design points that are load-bearing:

- **`pointerType` must be `'touch'`.** Flutter's default
  `MaterialScrollBehavior.dragDevices` excludes `PointerDeviceKind.mouse`
  (this app defines no custom `ScrollBehavior` — verified), so a mouse-typed
  drag is ignored by every Scrollable in the app. Playwright's `page.mouse`
  produces mouse-typed pointers, which is why the drag is synthesized in-page
  rather than driven through `page.mouse`.
- **Released at ~zero velocity** (two stationary moves before `pointerup`) so
  no fling makes the resulting offset unpredictable.
- **No strategy returns unconditionally.** An ineffective one falls through to
  the next instead of ending the invocation — which is exactly what PR #85's
  early `return` did, and what made it strictly narrower than `main`.
- **The oracle.** Flutter paints into a canvas, so no DOM scrollbar moves when
  a ListView scrolls. What does change is the semantics tree Flutter rebuilds
  for the new viewport, so "did anything happen?" is a signature over
  `flt-semantics` count, geometry, label lengths and `scrollTop`, plus
  `window.scrollY`.
- **Two `requestAnimationFrame` barriers** are frame synchronisation, required
  because Flutter applies a scroll and republishes semantics on its *next*
  frame. They are not timeouts and not a stability workaround; without them
  the oracle would read the pre-scroll tree and report every strategy inert.

**Inert-scroll guard.** `scrollUntilButtonFound` now calls the extracted pure
`assertScrollWasEffective()`, which throws when a scroll loop is *provably*
inert: steps ran, the fallback moved nothing, and the accessibility snapshot
never changed. Deliberately conservative — it stays silent when the snapshot
genuinely could not change (a screen with nothing below the fold) and on
Chromium's native wheel path, which produces no movement measurements at all
and so proves nothing. It can only turn a misleading failure message into an
accurate one.

## Fix Verification

Run **33196143453**, `e2e-webkit`, `phase-3b1-fit-reason` seed 100001 — the
same seed, the same Week 14, the same offer as the failing diagnostic run:

```
[SES-DIAG] === SUMMARY seed=100001 ===
[SES-DIAG] offerAccepted=true weeksWaited=2 iterations=2 exit=offerAccepted
           detailOfferTextEverSeen=true ctaEverSeen=true
           anyScrollEverChanged=true
           totalWheelInvocations=7 totalWheelMoved=7
```

And the exact behaviour the task asked for — a real scroll materializing
off-screen content that Playwright can then act on:

```
---- engineer detail BEFORE scroll: 4 texts, 3 buttons ----
  ... 田中 亮 / 社員コンディション / スキルシート・営業 ...
  button | enabled  | アップグレード
  button | enabled  | 営業用記載を編集
  button | disabled | 営業を開始する
---- engineer detail AFTER scroll: 7 texts, 5 buttons ----
  text   | 面談依頼
  text   | 面談依頼！ Axis Soft QA体制強化支援 単価 ¥523,595 ...
  button | enabled  | 断る
  button | enabled  | 面談へ進む          ← materialized by the scroll, then clicked
```

Before / after, on the same job and the same seed:

| | diagnostic `33193672549` | fix `33196143453` |
|---|---|---|
| `phase-3b1-fit-reason` (webkit) | ❌ FAIL | ✅ **PASS (1.3m)** |
| `offerAccepted` | `false` after 10 weeks | `true` after **2** weeks |
| wheel invocations moved | **0 / 150** | **7 / 7** |
| `anyScrollEverChanged` | `false` | `true` |
| CTA ever seen in semantics | `false` | `true` |

`weeksWaited=2` matches the spec's own determinism note exactly — the
scenario now completes in the documented number of weeks rather than
exhausting its bound.

## Changed Files

Against PR #85's HEAD `23e5b68`:

```
 e2e/helpers/artifacts.ts                  | 294 +++++++++++++---
 e2e/tests/phase-3b1-fit-reason.spec.ts    | 246 ++++++++++++-
 e2e/tests/portable-wheel-fallback.spec.ts | 100 +++++-
 e2e/tests/scroll-inert-guard.spec.ts      |  43 +++   (new)
 SES_WEBKIT_STABILIZATION_REVIEW_RESULT.md | 567 ++++++  (previous task's review)
```

- `e2e/helpers/artifacts.ts` — rewritten mobile-WebKit fallback with verified
  multi-strategy scrolling; `WheelFallbackDiagnostic` / `WheelStrategyAttempt`
  / `drainWheelDiagnostics()`; extracted `assertScrollWasEffective()`.
- `e2e/tests/phase-3b1-fit-reason.spec.ts` — per-week diagnostics into the job
  log; `settleAndScan` gained an optional observer (control flow unchanged);
  the inert-scroll guard wired into `scrollUntilButtonFound`.
- `e2e/tests/portable-wheel-fallback.spec.ts` — Flutter-shaped fixture and two
  new tests.
- `e2e/tests/scroll-inert-guard.spec.ts` — new, 6 tests.

**No production file is touched.** `lib/` is untouched in full.

## Tests Added

**1. Flutter-shaped semantics-scroller fixture** (Phase 4.1) — reproduces the
shape measured in CI: a non-scrollable decoy (`overflow: visible`, tall
content) that wins a naive largest-overflow search, plus the real scroller as
an `flt-semantics` with `overflow-y: hidden`. The page itself cannot scroll, so
the fixture cannot be satisfied by the window fallback.

The fixture was verified to **discriminate**, rather than assumed to:
PR #85/#81's logic was replayed verbatim against it in a throwaway spec —

```
OLD_SEMANTICS_MATCHED={"matched":0}  OLD_SCROLLED={"decoy":0,"real":0,"windowY":0}   ← inert
NEW_SCROLLED={"decoy":0,"real":300,"windowY":0}
NEW_DIAG={"movedBy":"semanticsScroll","attempts":[
  {"strategy":"wheelEvent","moved":false},
  {"strategy":"pointerDrag","moved":false},
  {"strategy":"semanticsScroll","moved":false,"detail":"decoy"},
  {"strategy":"semanticsScroll","moved":true,"detail":"real"}]}
```

`matched: 0` is the same 0-match failure measured in CI, reproduced in a unit
test. Both fixture tests force the mobile-WebKit rejection so the branch is
exercised on **Chromium too** — no test is skipped anywhere.

**2. Inert-scroll guard** (Phase 4.2) — 6 tests in
`scroll-inert-guard.spec.ts`, covering the exact SES_WEBKIT-SCROLL-1 failure
shape (throws, and names the context) plus the three cases that must stay
silent: a changed snapshot, a fallback that did move something, and Chromium's
no-measurement native path.

## Chromium Results

- **Diagnostic run 33193672549 — `e2e-chromium`: 59 passed (3.8m)**, with
  `phase-3b1-fit-reason` seed 100001 passing in 1.3m —
  `offerAccepted=true weeksWaited=2`.
- **Fix run 33196143453 — `e2e-chromium`: 67 passed (4.4m), 0 failed,
  0 flaky.** 59 + the 8 new tests = 67, all green. Chromium is unaffected by
  the change, as intended: it never enters the fallback
  (`totalWheelInvocations=0`).
- Local, against the fix: **47/47** harness specs pass on `mobile-chromium`
  (including all 8 new tests). `tsc --noEmit` clean.

## WebKit Results

- **Diagnostic run 33193672549 — `e2e-webkit`: FAILED**, as expected and as
  intended: `phase-3b1-fit-reason` seed 100001 failed with the pre-existing
  assertion, now accompanied by the full evidence quoted above. 57 passed,
  1 failed, 1 flaky.
- **Fix run 33196143453 — `e2e-webkit`: SUCCESS. 66 passed (4.8m), 0 failed,
  1 flaky.** 58 + the 8 new tests = 66. This is the first green `e2e-webkit`
  job in the runs examined for this task and the previous review
  (`3055ae8`, `ea0a4f2`, PR #85 `a6bc636` and `23e5b68`, and the diagnostic
  commit were all red).
- **Phase 4.3** `phase-3b1-fit-reason` seed 100001 — ✅ PASS (1.3m).
- **Phase 4.4** `beginner-mode-waiting-and-recruitment` — ✅ PASS, **no
  retry**. It is the other `page.mouse.wheel` caller and was *flaky* at
  PR #85's HEAD, so this is a direct improvement on the reviewed head.
- **Phase 4.1 / 4.2** the 8 new tests all pass on mobile-webkit.

### The one flaky result, reported not dismissed

`beginner-mode-april-june` seed 100002 failed once and passed on retry:

```
Error: Phase 3A dead-end/stall (seed=100002): dead-end at week 1:
       no recognized action. buttons=[] texts=[]
```

What can be established:

- **It cannot be caused by this change.** That spec and its drivers
  (`beginner-mode-player.ts`, `ses-player.ts`) never call `page.mouse.wheel`
  — verified by grep across the whole harness. The only callers are
  `phase-3b1-fit-reason.spec.ts`, `beginner-mode-waiting-and-recruitment.spec.ts`
  and `portable-wheel-fallback.spec.ts`. The modified code is unreachable
  from the failing test.
- **The failure mode is the known startup class**, not a scroll: a
  *completely empty* semantics tree (`buttons=[] texts=[]`) at week 1, before
  any scrolling is involved. The harness already carries dedicated regression
  coverage for empty-frame recovery (`ses-player.deadEndStability.spec.ts`
  Case 3).
- **It is nonetheless a new observation.** The same test with the same seed
  passed cleanly (50.6s) in the diagnostic run, so it is not claimed to be
  pre-existing. One plausible indirect contributor: the 8 added tests change
  worker scheduling across the two CI workers, which perturbs cold-start
  timing — a mechanism, not a proven cause.
- **Recommendation:** watch it on the next WebKit run. If it recurs it is a
  separate, pre-existing Flutter-Web-semantics-startup issue and deserves its
  own task; it should not be absorbed into this one.

**Resolved limitation.** The open question in the pre-run version of this
report — whether `wheelEvent`-with-coordinates or `pointerDrag` actually
reaches Flutter on real mobile WebKit — is now answered affirmatively by CI:
7 of 7 invocations moved something, and the CTA materialized. It could not be
answered locally (no Flutter SDK, so no `build/web`; no WebKit binary —
`/opt/pw-browsers` ships Chromium only and the Playwright browser CDN is
denied by the same egress policy), which is why it was left open rather than
asserted.

## Flutter Analyze

**PASS** — both runs.

- Diagnostic run 33193672549, step *flutter analyze*: success (17:14:40 → 17:14:52).
- Fix run 33196143453, step *flutter analyze*: success (17:46:35 → 17:46:45).

## Flutter Test

**PASS** — both runs.

- Diagnostic run 33193672549, step *flutter test*: success (17:14:52 → 17:20:30).
- Fix run 33196143453, step *flutter test*: success (17:46:45 → 17:52:15).

Unchanged, as expected: no production code was touched in either commit.

## Retry Count

**Unchanged, and one fewer retry actually consumed.** `playwright.config.ts`
still has `retries: process.env.CI ? 1 : 0`
— untouched in both commits. No retry was added, raised, or introduced
anywhere, and no test-level retry annotation exists.

## Assertion Changes

**No assertion was weakened, deleted, or relaxed.**

- The failing assertion `expect(offerAccepted, ...).toBe(true)` at
  `phase-3b1-fit-reason.spec.ts` is unchanged in text and in strictness.
- `MAX_WEEKS_TO_WAIT_FOR_OFFER` remains **10**.
- No `test.skip`, no `continue-on-error` change, no scenario removed, no
  WebKit exclusion.
- Assertions were only **added**: 8 new tests, plus the inert-scroll guard,
  which strictly *strengthens* the harness — it converts a silently
  misleading failure into an accurate one and can never convert a failure
  into a pass.

## Gameplay Changes

**None.** `lib/` is untouched. No `GameEngine` change, no RNG change, no
seed/week/salt change, no route change, no UI change. The diagnostic reads
only the real accessibility tree the harness already acted on — the repo's
"no debug API" rule is respected throughout (`e2e/README.md`).

`settleAndScan` gained an optional observer parameter; its dismissal loop and
control flow are unchanged, so the actions the playthrough performs are
identical.

## Risks

| Risk | Severity | Note |
|---|---|---|
| ~~`pointerDrag` / `wheelEvent` may not reach Flutter on real mobile WebKit~~ | **RESOLVED** | Run 33196143453: 7/7 invocations moved something and the CTA materialized. |
| ~~Synthetic `PointerEvent`s are untrusted and may be ignored~~ | **RESOLVED** | Same run; Flutter consumed them. |
| `beginner-mode-april-june` seed 100002 went flaky | Medium | Cannot be caused by this change (no call path to the modified code) and is the known empty-startup class, but it did pass cleanly in the baseline run. Watch on the next WebKit run; see *WebKit Results*. |
| Which strategy carries the fix is not pinned by a test | Low | The suite asserts *that* scrolling works, not that `wheelEvent` specifically does. If Flutter's event handling changes, another strategy may silently take over — visible in the `movedBy` diagnostics, but not asserted. |
| A working scroll changes `phase-3b1-fit-reason`'s timing on WebKit | **RESOLVED** | 2.5m → 1.3m, and 10 wasted weeks → the documented 2. |
| The inert-scroll guard could fire on a legitimately short screen | Low | Guarded three ways: it needs an unchanged snapshot **and** recorded fallback invocations **and** zero measured movement. Chromium can never trip it. |
| Two `requestAnimationFrame` barriers per strategy add wall-clock cost | Low | Only on the mobile-WebKit fallback path; Chromium never enters it. |
| `e2e-webkit` remains `continue-on-error: true` | **High**, pre-existing | A red WebKit job still cannot fail a run. Out of scope here; should be removed once WebKit is genuinely green, as that workflow's own comment instructs. |

## PR #85 Merge Readiness

**PASS** — all Phase 4 gates met on run `33196143453`:

| Gate | Result |
|---|---|
| 4.1 Flutter-shaped fixture, fails before / passes after | ✅ verified to discriminate (old logic: 0 matches, inert) |
| 4.2 inert-scroll guard test | ✅ 6 tests |
| 4.3 `phase-3b1-fit-reason` seed 100001 mobile-webkit | ✅ PASS (1.3m) |
| 4.4 `beginner-mode-waiting-and-recruitment` mobile-webkit, no retry | ✅ PASS, no retry |
| 4.5 full mobile-webkit suite | ✅ 66 passed, 0 failed, 1 flaky (analysed above) |
| 4.6 full mobile-chromium suite | ✅ 67 passed, 0 failed, 0 flaky |
| 4.7 `flutter analyze` / `flutter test` | ✅ both PASS |

**I have not pushed anything to PR #85.** Its HEAD is still
`23e5b686572a40edd6f1cc1595499c685de9450d`. Phase 5 permits adding a fix
commit once cause and fix are proven — that condition is now met, and this
report is the required prior report — but pushing to a PR branch that is not
mine is an outward-facing action, so it waits on your explicit go-ahead.

What the evidence settles about PR #85 itself:

- Its spec line (`a6bc636`) — calling `scrollUntilButtonFound` before looking
  for 面談へ進む — is **correct and should be kept**. It is precisely what
  makes the scenario pass now that scrolling works.
- Its helper commit (`23e5b68`) is **superseded and should be dropped or
  rewritten**. Measured: its `overflow-y: scroll|auto` filter matched 0 of 21
  nodes on all 150 invocations, so it was dead code on mobile WebKit; and its
  early `return` made the fallback strictly narrower than `main`.

**Production Change Required: NO.** Real iOS/Safari players scroll
`EngineerDetailScreen` with touch; Flutter lays out the next slivers and the
面談依頼 card materializes normally. The defect was entirely in the test
harness's ability to scroll mobile WebKit. `lib/` is untouched in full, and
no Phase 5 STOP condition was triggered.

Recorded, not proposed: whether an iPhone-sized viewport should surface a
pending 面談依頼 above the tall `スキルシート / 営業` card is a real UX
question for the Phase 3A human/video review that `AGENTS.md` names as the
current focus. A `cacheExtent:` on that `ListView` would also help assistive
technology — but adopting it *to make a test pass* would mask a test-side
defect, so it is deliberately not proposed.

## Recommended Next Task

**`SES_WEBKIT-SCROLL-2` — land the fix on PR #85 and stop hiding the WebKit signal.**

1. On your go-ahead, add the fix to PR #85: keep `a6bc636`'s spec line, drop
   or rewrite `23e5b68`, and carry `6300f07` + `7bca23c`.
2. Re-run PR #85's CI and confirm `e2e-webkit` is green on its own head.
3. **Remove `continue-on-error: true` from the `e2e-webkit` job.** That
   workflow's own comment says to remove it once the WebKit issue is fixed,
   and it is why a job that was red across every run examined here never once
   turned a run red. Leaving it in place now would re-hide the very signal
   this task restored. This is the single highest-value follow-up.
4. Watch `beginner-mode-april-june` seed 100002 on the next WebKit run. If the
   flake recurs, open a separate task for Flutter Web semantics startup
   (empty tree at week 1); do not absorb it into this one.

Optional hardening, not required: assert *which* strategy carries the fix
(`movedBy === 'wheelEvent'`) so a silent handover to another strategy shows up
as a test change rather than only in diagnostics.

Constraints carried forward unchanged: no retry increase, no arbitrary
waits/sleeps, no skips, no WebKit exclusion, no assertion weakening, no
scenario deletion, no week-limit increase, no GameEngine / RNG / gameplay
change.
