# Result

SES_WEBKIT-SCROLL-1 — make mobile-WebKit scrolling real, and observable.

**Root Cause Classification: A** — the CTA exists in GameState and in the
widget tree, but is never materialized into Flutter's semantics tree.
Established by direct side-by-side observation, not deduction.

**Merge Readiness: BLOCKED (pending the in-flight Phase 4 validation run).**
See *PR #85 Merge Readiness* for exactly what is outstanding and why nothing
has been pushed to PR #85.

> Status at the time of writing: Phases 1–3 are complete and evidenced.
> Phase 4's full-suite validation run (`33196143453`) was still executing.
> Every unverified item below is marked **PENDING**; none of it is asserted
> as passing. This file is updated in place once that run reports.

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

Phase 4 validation run: **33196143453** — **PENDING** at time of writing.

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
- **Fix validation (run 33196143453): PENDING.**
- Local, against the fix: **47/47** harness specs pass on `mobile-chromium`
  (including all 8 new tests). `tsc --noEmit` clean.

## WebKit Results

- **Diagnostic run 33193672549 — `e2e-webkit`: FAILED**, as expected and as
  intended: `phase-3b1-fit-reason` seed 100001 failed with the pre-existing
  assertion, now accompanied by the full evidence quoted above. 57 passed,
  1 failed, 1 flaky.
- **Fix validation (run 33196143453): PENDING.** This is the run that decides
  whether `wheelEvent`-with-coordinates or `pointerDrag` actually reaches
  Flutter on real mobile WebKit.

**Honest limitation.** That last question could not be answered locally: this
environment has no Flutter SDK (so `build/web` cannot be produced) and no
WebKit binary (`/opt/pw-browsers` ships Chromium only; the Playwright browser
CDN is denied by the same egress policy). The fallback's *logic* is verified
locally against the Flutter-shaped fixture; whether Flutter consumes the
synthetic events is a CI-only question.

## Flutter Analyze

**PASS** — `validate` job, diagnostic run 33193672549, step *flutter analyze*:
success (17:14:40 → 17:14:52).

Phase 4 run: **PENDING**. No production code changed in either commit, so no
change in this result is expected.

## Flutter Test

**PASS** — `validate` job, diagnostic run 33193672549, step *flutter test*:
success (17:14:52 → 17:20:30).

Phase 4 run: **PENDING**. Same reasoning as above.

## Retry Count

**Unchanged.** `playwright.config.ts` still has `retries: process.env.CI ? 1 : 0`
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
| `pointerDrag` / `wheelEvent` may still not reach Flutter on real mobile WebKit | **High until run 33196143453 reports** | Unverifiable locally (no Flutter SDK, no WebKit binary). Mitigated by five verified strategies rather than one, so a partial failure still has paths left. If all five come back inert, the diagnostics now name which and why — a second iteration would be informed, not blind. |
| Synthetic `PointerEvent`s are untrusted | Medium | Flutter Web is not known to check `isTrusted`, but this is an assumption the CI run tests directly. |
| A working scroll changes `phase-3b1-fit-reason`'s timing on WebKit | Low | Expected and desirable: a working scroll exits early. A run still showing ~6.6 s per iteration is itself evidence of failure. |
| The inert-scroll guard could fire on a legitimately short screen | Low | Guarded three ways: it needs an unchanged snapshot **and** recorded fallback invocations **and** zero measured movement. Chromium can never trip it. |
| Two `requestAnimationFrame` barriers per strategy add wall-clock cost | Low | Only on the mobile-WebKit fallback path; Chromium never enters it. |
| `e2e-webkit` remains `continue-on-error: true` | **High**, pre-existing | A red WebKit job still cannot fail a run. Out of scope here; should be removed once WebKit is genuinely green, as that workflow's own comment instructs. |

## PR #85 Merge Readiness

**BLOCKED** — pending run `33196143453`.

PR #85's HEAD `23e5b68` is untouched, and **nothing will be pushed to it until
the fix is proven green on mobile WebKit**, per the Phase 5 gating.

What the evidence already settles about PR #85 itself, independent of the
pending run:

- Its spec line (`a6bc636`) — calling `scrollUntilButtonFound` before looking
  for 面談へ進む — is **correct and worth keeping**. It costs ~0 on Chromium
  and is exactly what is needed once scrolling works.
- Its helper commit (`23e5b68`) is **superseded**. Measured: its
  `overflow-y: scroll|auto` filter matched 0 of 21 nodes on all 150
  invocations, so it is dead code on mobile WebKit; and its early `return`
  makes the fallback strictly narrower than `main`. The fix replaces it.

**Production Change Required: NO.** Real iOS/Safari players scroll
`EngineerDetailScreen` with touch; Flutter lays out the next slivers and the
面談依頼 card materializes normally. Nothing here is reachable by a human
player. The defect is entirely in the test harness's ability to scroll mobile
WebKit. No Phase 5 STOP condition was triggered.

Recorded, not proposed: whether an iPhone-sized viewport should surface a
pending 面談依頼 above the tall `スキルシート / 営業` card is a real UX
question for the Phase 3A human/video review that `AGENTS.md` names as the
current focus. A `cacheExtent:` on that `ListView` would also help assistive
technology — but adopting it *to make this test pass* would be masking a
test-side defect, so it is deliberately not proposed here.

## Recommended Next Task

Gated on run `33196143453`:

**If mobile-webkit is green** — `SES_WEBKIT-SCROLL-2`:
1. Push the fix to PR #85 as an additional commit (Phase 5 permits this only
   now that cause and fix are proven), dropping or rewriting `23e5b68`, and
   keeping `a6bc636`'s spec line.
2. Re-run PR #85's CI; confirm `beginner-mode-waiting-and-recruitment` passes
   **without a retry** on WebKit (it is the other `page.mouse.wheel` caller
   and went flaky at PR #85 HEAD).
3. Remove `continue-on-error: true` from the `e2e-webkit` job, as that
   workflow's own comment instructs, so the signal stops being invisible.

**If mobile-webkit is still red** — stop and re-diagnose, do not iterate
blindly. The new per-strategy `attempts` array names exactly which of the five
strategies ran and whether each moved anything; that plus the
`flt-semantics` histogram is enough to decide between "Flutter ignores
synthetic pointer events" (→ investigate Playwright's real touch input or
Flutter's `GestureMode`) and "the drag reached Flutter but the gesture was not
recognised" (→ tune slop/step count). Report before changing code.

Constraints carried forward unchanged: no retry increase, no arbitrary
waits/sleeps, no skips, no WebKit exclusion, no assertion weakening, no
scenario deletion, no week-limit increase, no GameEngine / RNG / gameplay
change.
