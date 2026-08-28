# Result

Independent review of PR #85 — S.E.S. WebKit / E2E stabilization.

**Verdict: B. ROOT CAUSE PARTIALLY CONFIRMED**
**Merge recommendation: CHANGES REQUIRED**

No code was changed by this review. This document is the whole deliverable.

---

## Task

Independently investigate PR #85 (`E2E: scroll to interview offer in engineer
detail`) and the underlying Flutter Web mobile-WebKit off-screen CTA /
semantics / scrolling failure, using CI evidence rather than assumption, and
classify the root cause as A / B / C / D before proposing any fix.

Explicitly out of scope by instruction (and respected throughout): retry
increases, arbitrary waits/sleeps, test skips, WebKit exclusion, assertion
deletion or weakening, scenario deletion, week-limit increases, GameEngine
changes, RNG changes, gameplay changes.

## 担当AI

Claude Code (Anthropic official CLI), running as an autonomous remote session
against `perusonao/smile_enjoy_story`.

## 使用モデル

Session-configured model: `claude-opus-5` (Opus 5), extended thinking / high
reasoning effort. The model actually serving an individual turn can differ
from the configured identifier.

## main HEAD

```
ea0a4f24a9f55916122b9644aaf6ff65c2e0b57c
Merge pull request #81 from perusonao/agent/webkit-mobile-scroll-fallback
("E2E: add mobile WebKit wheel fallback")
```

## PR #85 HEAD

```
23e5b686572a40edd6f1cc1595499c685de9450d
test: target Flutter semantics scroller on mobile WebKit
```

- Branch: `agent/e2e-interview-offer-scroll-reachability`
- Base: `main` @ `ea0a4f2` (so PR #84 is **not** in this PR's base)
- State: open, `mergeable_state: unstable`, 2 commits, 2 files, +34 / −2
- Commit 1: `a6bc636` `test: scroll to pending interview offer in engineer detail`
- Commit 2: `23e5b68` `test: target Flutter semantics scroller on mobile WebKit`

## Evidence Reviewed

Sources actually read (no inference presented as observation):

| Evidence | Source | Status |
|---|---|---|
| `main` HEAD, PR #85 HEAD, full PR diff | local git against `origin` | ✅ read |
| PR #85 metadata / body / base | GitHub API | ✅ read |
| PR #85 check runs (7) | GitHub API | ✅ read |
| PR #85 run 33186416865 — `e2e-webkit` job log (98902635033) | GitHub API | ✅ read |
| PR #85 run 33186416865 — `e2e-chromium` job log (98902634971) | GitHub API | ✅ read |
| PR #85 run 33183274596 (commit 1) — job list / conclusions | GitHub API | ✅ read |
| `main` @ `ea0a4f2` run 33180904498 — `e2e-webkit` job log (98883544733) | GitHub API | ✅ read |
| `main` @ `ea0a4f2` run 33180904498 — `e2e-chromium` job log (98883544898) | GitHub API | ✅ read |
| `main` @ `3055ae8` run 33174883338 — job conclusions | GitHub API | ✅ read |
| `e2e/tests/phase-3b1-fit-reason.spec.ts` (main + PR) | source | ✅ read |
| `e2e/helpers/artifacts.ts` — `installPortableWheelFallback` (main + PR) | source | ✅ read |
| `e2e/helpers/game-state.ts` — `snapshotScreen` / `parseAriaSnapshot` | source | ✅ read |
| `e2e/tests/portable-wheel-fallback.spec.ts` | source | ✅ read |
| `e2e/tests/beginner-mode-waiting-and-recruitment.spec.ts` scroll helper | source | ✅ read |
| `e2e/playwright.config.ts` (projects / devices) | source | ✅ read |
| Playwright device descriptors for `iPhone 14` / `Pixel 7` | local playwright 1.56.1 | ✅ read |
| `lib/ui/engineers/engineer_detail_screen.dart` (ListView + `_InterviewOfferCard`) | source | ✅ read |
| `.github/workflows/e2e.yml` (job gating, `continue-on-error`) | source | ✅ read |
| `AGENTS.md` | source | ✅ read |
| **failure artifact zip** (`ses-playwright-results-mobile-webkit`, 330 MB) | GitHub artifact | ❌ **BLOCKED** |
| **trace.zip / test-failed-1.png / video.webm / error-context.md** | inside that artifact | ❌ **BLOCKED** |
| **accessibility snapshot at failure time** | inside `error-context.md` | ❌ **BLOCKED** |
| GitHub Pages replay viewer | `perusonao.github.io` | ❌ **BLOCKED** |

### Why the artifacts could not be read — this is material

This session's outbound HTTPS goes through a policy-enforcing egress proxy.
GitHub's artifact download redirects to
`productionresultssa15.blob.core.windows.net`, which the organization's egress
policy denies (`CONNECT tunnel failed, response 403`). `perusonao.github.io`
is denied the same way. Per the proxy's own documented rules, a 403 policy
denial must be reported, not retried or routed around.

Consequence: **screenshot, video, trace and the failure-time ARIA snapshot
were never available to this review.** Everything below is derived from CI
logs, source, and arithmetic on published test durations. Where a conclusion
rests on deduction rather than direct observation, it is labelled as such.
That gap is the sole reason this verdict is **B** and not **A**.

## Failure Reproduction

No local reproduction was possible and none is claimed:

- No Flutter SDK in this environment (`flutter` not on PATH) → cannot build
  `build/web`.
- No WebKit browser (`/opt/pw-browsers` has Chromium only); the Playwright
  browser CDN (`cdn.playwright.dev`) is denied by the same egress policy.
- The prebuilt `build-web` CI artifact and the Pages deployment are both
  behind blocked hosts.

Reproduction was therefore done **against CI history**, which is stronger than
a single local run for this particular question because it isolates the PR:

| Commit | Browser | `phase-3b1-fit-reason` (seed 100001) | Suite result |
|---|---|---|---|
| `main` `ea0a4f2` | mobile-chromium | ✅ PASS **1.3m** | 59 passed |
| `main` `ea0a4f2` | mobile-webkit | ❌ FAIL **1.4m**, retry ❌ **1.2m** | 58 passed, 1 failed |
| PR#85 `23e5b68` | mobile-chromium | ✅ PASS **1.3m** | 59 passed |
| PR#85 `23e5b68` | mobile-webkit | ❌ FAIL **2.5m**, retry ❌ **2.3m** | 57 passed, 1 failed, 1 flaky |

Both failures are byte-identical in message and in assertion:

```
Error: no 面談依頼/面談へ進む appeared within 10 weeks (seed=100001)
       — not a stall/timeout tuning issue, see this file's determinism note
expect(offerAccepted).toBe(true)   Expected: true   Received: false
  main : phase-3b1-fit-reason.spec.ts:344
  PR#85: phase-3b1-fit-reason.spec.ts:345   (same statement, +1 line from the patch)
```

`e2e-webkit` also failed on the previous `main` tip `3055ae8` (run
33174883338), i.e. before PR #81 merged. The failure is **pre-existing,
deterministic and persistent on mobile WebKit**, exactly as PR #85's body
states. It is masked at the workflow level because `.github/workflows/e2e.yml`
marks `e2e-webkit` `continue-on-error: true`, so the *run* reports success
while the *job* is red.

## Root Cause

Stated as three separate claims at three different confidence levels.

### Claim 1 — CONFIRMED (from logs, direct)

**PR #85 does not fix the failure it targets.** The mobile-WebKit run at PR
HEAD fails on the same seed, at the same statement, with the same message, as
`main`. The only measured change is +66 s of wall clock per attempt.

### Claim 2 — CONFIRMED (from published durations, arithmetic)

**On mobile WebKit the scroll path introduced/extended by this PR performs
zero observable work: the accessibility snapshot never changes across any
scroll attempt.**

`scrollUntilButtonFound(page, name, maxSteps = 15)` exits early only when
`everChanged && stableStreak >= 3` — i.e. only after it has seen the
`snap.texts` fingerprint change at least once. If the fingerprint never
changes, `everChanged` stays `false` and the loop always burns all 15 steps.

The measured delta separates those two behaviours cleanly:

```
mobile-webkit  phase-3b1  main 1.4m (84s) → PR 2.5m (150s)   Δ = +66s
               retry      main 1.2m (72s) → PR 2.3m (138s)   Δ = +66s
loop bound     MAX_WEEKS_TO_WAIT_FOR_OFFER = 10 iterations
per iteration  66s / 10 = 6.6s

full 15 steps : 200ms + 15 × (wheel-fallback evaluate + 300ms + ariaSnapshot)
                ≈ 0.2s + 15 × ~0.43s ≈ 6.6s          ← matches exactly
early exit (~4 steps) ≈ 1.9s → would have shown Δ ≈ +17s, not +66s
```

Chromium is the control: `main` 1.3m → PR 1.3m, delta ≈ 0, because there the
CTA is already in the tree (step 0 return) and, in an offer-less week, real
scrolling trips the early exit within a few steps.

So on mobile WebKit the helper attempted **15 × 10 = 150 scrolls per attempt
and produced no semantics change at all** — with the pre-#85 generic
`scrollHeight` fallback *and* with #85's new `flt-semantics` branch.

### Claim 3 — PARTIALLY CONFIRMED (deduction + source, not observation)

**The `面談依頼` / `面談へ進む` CTA does exist in game state on WebKit and is
absent from the semantics tree because `EngineerDetailScreen`'s `ListView` has
not laid it out on the shorter iPhone 14 viewport.**

The supporting chain:

1. The spec's own determinism note (and `project_interview_engine.dart`) state
   every RNG draw is a pure function of `(state.seed, state.week, salt)`.
2. Both browsers assert `founding.completed` and `beginner.completed`, so both
   reach the same Week 13 with the same seed before Phase 2 starts.
3. Both then execute the same fixed action sequence. `営業を開始する` →
   `営業開始` both go through `clickResilient`, which **throws** after 15 s if
   the click never lands. Neither run threw there, so the parallel sales
   search really started on WebKit.
4. The WebKit loop demonstrably ran all 10 iterations (see the timing model
   above — and on `main`, ~29 s of post-Phase-1 time over 10 × ~2.9 s
   iterations). A missing `次の週へ` would have hit `if (!next) break` after
   one iteration and finished far faster. So weeks really advanced.
5. Given (1)+(2)+(3)+(4), the offer must be generated on WebKit at the same
   week as on Chromium. Therefore the CTA's absence is a *presentation /
   semantics* fact, not a game-state fact.

**What is missing to make this CONFIRMED:** the failure-time ARIA snapshot
(`error-context.md`) and `test-failed-1.png`, which would show directly
whether `面談依頼` text was present-but-unbuttoned, entirely absent, or
visually on screen. Those are the blocked artifacts. Until someone reads them,
Claim 3 stays an inference.

## Semantics Findings

- `snapshotScreen()` reads `page.locator('body').ariaSnapshot()` only. Flutter
  Web renders to canvas; the *only* thing Playwright can see is the
  `flt-semantics` tree. A widget that Flutter has not laid out has no
  semantics node, so it is invisible to every locator, `expect`, and
  actionability check — this is a genuine "exists in UI intent, absent from
  the a11y tree" situation, and the harness has no other observation channel.
- `EngineerDetailScreen.body` (`lib/ui/engineers/engineer_detail_screen.dart:98`)
  is a plain `ListView(children: [...])` → `SliverChildListDelegate` →
  `RenderSliverList`, which lays out only viewport + `cacheExtent` children.
  Off-screen children get no render object and therefore no semantics node.
- Child order before the target: optional `_GuideBanner`, name row + status
  chip, `_CurrentStatusCard`, optional `_WaitingWarningBanner`,
  `_ConditionCard`, optional `_ContractPreferenceHint`, then the tall
  `_SectionCard('スキルシート / 営業')` (6 `_Row`s + a note + a button row) —
  and only then `if (interviewOffers.isNotEmpty) … _SectionCard('面談依頼')`
  containing `_InterviewOfferCard` with `面談へ進む`
  (`engineer_detail_screen.dart:164`, `:526`).
- The repo already documented this exact class of problem twice, in its own
  words, before PR #85: `scrollUntilButtonFound`'s doc comment ("Flutter Web's
  `SliverList` only materializes semantics for children within/near the
  current viewport … confirmed directly against the real `ariaSnapshot()`
  output"), and `beginner-mode-waiting-and-recruitment.spec.ts:375` ("Flutter
  Web does not always materialize that off-screen child in the current
  semantics snapshot"). The mechanism is established repo knowledge; what is
  unproven is that it is *this* failure's cause.

## Scroll Findings

`installPortableWheelFallback` (`e2e/helpers/artifacts.ts:155`) is monkey-
patched onto `page.mouse.wheel` and fires only on the mobile-WebKit
"Mouse wheel is not supported in mobile WebKit" rejection. Its fallback has
three stages; PR #85 inserts a new second stage:

1. dispatch a synthetic `WheelEvent` on `document.elementFromPoint(center)`
2. **(new in #85)** find the first visible `flt-semantics` with
   `overflow-y: scroll|auto`, call `scrollBy()`, dispatch a synthetic
   `Event('scroll')`, and **`return`**
3. otherwise: largest `scrollHeight − clientHeight` element, else `window.scrollBy`

Problems, in order of importance:

1. **The new stage is self-defeating by its own premise.** Its comment says
   these nodes "can have `scrollHeight === clientHeight` until Flutter
   materializes the next Sliver children". On such a node `scrollBy()` is a
   no-op, `scrollTop` stays at Flutter's neutral offset, and the synthetic
   `Event('scroll')` therefore carries **zero delta** — which is exactly the
   input Flutter's semantics scroll handler reads to decide whether to emit
   `SemanticsAction.scrollUp/scrollDown`. A zero-delta scroll event cannot
   move a Flutter scrollable. The code acknowledges the blocking condition and
   then relies on a path that condition disables.
2. **The `return` narrows the fallback.** Once any matching `flt-semantics`
   node exists, stage 3 is unreachable. On `main` that stage was at least
   attempted. This makes PR #85 strictly *less* capable than `main` on pages
   where a semantics scroller matches but is not usefully scrollable.
3. **Both synthetic events are untrusted and never verified.** The fallback
   never checks that anything actually moved, so an inert scroll is silent.
   Combined with (1), that is precisely the +66 s of measured no-op.
4. **A plausible additional blocker, not verified here:** Flutter Web's
   `SemanticScrollable` only exposes browser-driven scrolling in
   `GestureMode.browserGestures`; while the engine is in `pointerEvents` mode
   (entered on pointer input, which the spec generates continuously via
   `.click()` and the `page.mouse.move` immediately before scrolling) the
   container's overflow is not browser-scrollable. If that holds for the
   pinned Flutter version, #85's `overflowY === 'scroll' | 'auto'` filter
   matches nothing and stage 2 silently falls through to the same inert
   stage 3. **This is a hypothesis** — it could not be verified without the
   Flutter engine source or a live WebKit page, and it is not required for
   Claim 2, which stands on measurement alone.

## Chromium Comparison

- `phase-3b1-fit-reason` passes on mobile-chromium at `main` **and** at PR
  HEAD, at the same 1.3m.
- Viewport is the single clearest environmental difference (Playwright device
  registry, verified locally against playwright 1.56.1; the repo pins
  `^1.55.0`, and these descriptors are stable across that range):

  | Project | Device | Viewport | isMobile / hasTouch |
  |---|---|---|---|
  | mobile-chromium | Pixel 7 | 412 × **839** | true / true |
  | mobile-webkit | iPhone 14 | 390 × **664** | true / true |

  WebKit has **175 px (≈21 %) less vertical space**, and after the AppBar the
  usable list height is smaller still. Given the child order above, the
  `面談依頼` card plausibly sits inside Pixel 7's viewport + `cacheExtent` and
  outside iPhone 14's. Plausibly — not measured, because the screenshots are
  blocked.
- Chromium never exercises the fallback at all: `page.mouse.wheel` is native
  there, so the entire `installPortableWheelFallback` body — including
  everything PR #85 adds — is **mobile-WebKit-only code that a green Chromium
  job can never validate**.
- PR #85's body cites Chromium reproducibility "when the detail layout grows
  (PR #84)". PR #84 is not in this PR's base (`ea0a4f2`) and Chromium is
  currently green, so that is a forward-looking argument, not present evidence.

## WebKit Findings

1. `e2e-webkit` is red on `main` at `ea0a4f2` and at `3055ae8`; the single
   failure both times is `phase-3b1-fit-reason` (seed 100001). Pre-existing,
   not introduced by PR #85.
2. `continue-on-error: true` on the `e2e-webkit` job means a red WebKit job
   never turns the run red. The workflow's own comment says to remove that
   once the WebKit issue is fixed. Anyone reading run-level status alone will
   believe WebKit is green.
3. At PR HEAD the failure is unchanged and the test is 79 % slower.
4. `beginner-mode-waiting-and-recruitment` ("recruitment flow stays operable
   in real UI, seed 100001") went from **clean pass on `main`** to **fail →
   pass on retry (flaky)** at PR HEAD. That spec is the other caller of
   `page.mouse.wheel` (`:393`), so it goes through the same patched fallback.
   One observation is a signal, not proof — but it is the expected shape of
   finding 2 in *Scroll Findings*, and it deserves a rerun before merge.
5. Test coverage for the changed code is zero.
   `portable-wheel-fallback.spec.ts` calls `page.setContent('<div
   style="height:2000px">scroll</div>')` and asserts `window.scrollY > 0`.
   That page contains **no `flt-semantics` element at all**, so PR #85's new
   branch is never entered and the test passes whether the new code works or
   not. It passed on mobile-webkit in both runs (475 ms → 677 ms) and proves
   nothing about the change.

## PR #85 Assessment

**What is right about it**

- The diagnosis direction (off-screen CTA / semantics materialization) matches
  the repo's own prior findings and is the right thing to be looking at.
- The PR body is honest: it says the failure is pre-existing on WebKit rather
  than claiming a clean fix.
- The spec change reuses the file's existing `scrollUntilButtonFound` instead
  of inventing a new mechanism — correct instinct.
- It respects every stated constraint: no week-limit increase, no retry/skip
  change, no RNG/gameplay change, no production change, same route, same
  assertion.

**What is wrong with it**

1. **It does not fix the failure.** Identical error on the same seed at PR
   HEAD. The PR title and the change both promise reachability that CI
   disproves.
2. **The helper change is unvalidated and cannot be validated by this CI.**
   The only job that exercises it is the one job that stays red, and the only
   test that names it never reaches the new branch.
3. **It measurably regresses WebKit runtime** by +66 s per attempt, ×2
   attempts = +132 s per run, spent entirely on no-op scrolling.
4. **It narrows the existing fallback** via the early `return` (Scroll
   Findings 2), with a matching flaky-transition signal on the other wheel
   caller.
5. **Nit:** the patch deletes the trailing newline at
   `phase-3b1-fit-reason.spec.ts` EOF (`\ No newline at end of file`) — an
   unrelated, unnecessary change to a reviewed file.

**Reading of the two commits.** `a6bc636` (spec: call
`scrollUntilButtonFound`) is defensible on its own — it is cheap on Chromium,
harmless in principle, and correct if/when WebKit scrolling ever works.
`23e5b68` (helper: prefer the `flt-semantics` scroller) is the commit that
carries all the risk and delivers no measured benefit.

## Production Change Required

**No.**

Real Safari/iOS users scroll `EngineerDetailScreen` with touch; Flutter
handles that natively, lays out the next slivers, and the `面談依頼` card
materializes normally. Nothing here shows a defect reachable by a human
player. What is broken is the **test harness's ability to scroll mobile
WebKit**, not the app.

Two optional, non-required production notes, recorded for the roadmap rather
than proposed here:

- A `cacheExtent:` on that `ListView` would materialize more off-screen
  children into the semantics tree and would incidentally help assistive
  technology as well as this harness. It is a real (small) production change
  and would be masking a test-side defect if adopted for that reason — do not
  adopt it to make this test pass.
- Whether an iPhone-sized viewport should surface a pending `面談依頼` above
  the tall `スキルシート / 営業` card at all is a genuine UX question for the
  Phase 3A human/video review that `AGENTS.md` names as the current focus. It
  is not a correctness bug and is out of scope here.

Per `AGENTS.md`, `docs/DEVELOPMENT_PLAN.md` remains the priority source of
truth for anything acted on from those two notes.

## Test Change Required

**Yes — E2E helper only (plus one spec-level guard).** Classification:
`E2E helperのみ` (+ `specのみ` for the guard). Not `production change不要`
alone, because the current helper is actively wrong; not
`Flutter production UI修正必要`.

Files in scope: `e2e/helpers/artifacts.ts`, `e2e/tests/portable-wheel-fallback.spec.ts`,
and (for the guard) `e2e/tests/phase-3b1-fit-reason.spec.ts`.

## Risks

| Risk | Severity | Note |
|---|---|---|
| Merging PR #85 as-is reads as "WebKit CTA reachability fixed" when it is not | **High** | Title/diff imply a fix; CI shows none. Future work will build on a false premise. |
| The new `return` disables the previous fallback stage | Medium | Matching flaky transition on `beginner-mode-waiting-and-recruitment` (1 observation). |
| +132 s/run of no-op scrolling on WebKit | Low-Medium | Pure cost, no benefit. |
| `continue-on-error: true` hides a persistently red WebKit job | **High** | Structural, pre-dates this PR; the real WebKit signal is invisible at run level. |
| The decisive artifacts are unreadable from a policy-restricted session | Medium | 330 MB behind a denied host. Any future investigation hits the same wall. |
| Claim 3 rests on deduction | Medium | If the offer genuinely never generates on WebKit, the fix direction changes entirely. Cheap to settle — see *Tests Required*. |

## Recommended Fix

Ordered. Step 0 is the one that must happen first — it is what turns this
review from **B** into **A** or **C**, and it is cheap.

**0. Make the evidence readable without downloading 330 MB.**
On failure, print the failing screen's `ariaSnapshot()` (and the
`weeksWaited` / `offerAccepted` values) into the job log via the existing
`writeArtifacts` / `buildResultJson` path, or `testInfo.attach` a small text
file. One CI run then answers directly whether `面談依頼` was present-but-
unmaterialized, absent, or on screen but unbuttoned. Do this before any fix.

**1. Repair the mobile-WebKit scroll for real, in `installPortableWheelFallback`.**
Target: a scroll that Flutter genuinely processes, so it lays out the next
slivers and the CTA enters the semantics tree as an actionable button.

- Prefer driving the **real UI**, not the semantics container: a synthetic
  pointer drag (`mouse.move` → `mouse.down` → several `mouse.move` steps →
  `mouse.up`) over the list, which Flutter Web's `PointerBinding` consumes as
  an ordinary drag-scroll. This is the closest analogue to what a real iPhone
  player does and needs no assumption about Flutter's semantics-scroll
  internals or gesture mode.
- If the semantics-container route is kept instead, it must actually move
  `scrollTop` away from Flutter's neutral offset (and let the browser's own
  `scroll` event fire) rather than dispatching a zero-delta synthetic
  `Event('scroll')`.
- **Do not `return` early.** Try each strategy in turn and stop at the first
  one that demonstrably moved something.
- **Verify and report.** Have the fallback observe an effect
  (`scrollTop` / `window.scrollY` / a changed semantics fingerprint) and make
  "nothing moved" loud instead of silent.

**2. Make `scrollUntilButtonFound` fail loudly on an inert scroll.**
`everChanged === false` after `maxSteps` currently returns a normal snapshot,
so a completely dead scroll path is indistinguishable from "the button isn't
there". Throwing a named error there would have surfaced this WebKit defect at
PR #85's first CI run instead of hiding it behind a generic assertion. This
*strengthens* an assertion; it is not a weakening, a skip, or a retry.

**3. Cover the new code path.**
Give `portable-wheel-fallback.spec.ts` a fixture that actually contains a
`flt-semantics`-shaped scroller (an element with `overflow-y: scroll`, a real
scrollable range, and a scroll listener), so the branch under test is entered
and its effect asserted. The current plain-`div` fixture cannot fail.

**4. Then re-evaluate the spec line.**
`snap = await scrollUntilButtonFound(page, PROCEED_TO_INTERVIEW);` at
`phase-3b1-fit-reason.spec.ts:328` is correct *given* a working scroll. Keep
it; it costs ~0 on Chromium and is the right shape. It just cannot carry the
fix on its own.

**5. Housekeeping.** Restore the trailing newline at the end of
`phase-3b1-fit-reason.spec.ts`.

**6. Separately, and not as part of this PR:** once WebKit is genuinely green,
remove `continue-on-error: true` from the `e2e-webkit` job, as that
workflow's own comment already instructs.

**Explicitly NOT recommended:** raising `MAX_WEEKS_TO_WAIT_FOR_OFFER`, adding
retries or sleeps, skipping or excluding the WebKit project, weakening or
deleting the `offerAccepted` assertion, or touching GameEngine / RNG /
gameplay. None of those would address anything found here, and all are
forbidden by the brief.

## Tests Required

1. **Diagnostic run (blocking, do first).** `phase-3b1-fit-reason`, seed
   100001, mobile-webkit, with the failure-time ARIA snapshot in the job log
   (Recommended Fix 0). Settles Claim 3 outright.
2. **Fallback unit coverage.** `portable-wheel-fallback.spec.ts` extended per
   Recommended Fix 3, and it must be seen to **fail** against today's
   `installPortableWheelFallback` before it is allowed to pass against the
   repaired one.
3. **Inert-scroll guard.** A focused test that `scrollUntilButtonFound` throws
   when the snapshot fingerprint never changes.
4. **Full mobile-webkit suite** at the fix commit: `phase-3b1-fit-reason` must
   pass, and `beginner-mode-waiting-and-recruitment` must pass **without a
   retry** (it is the other wheel caller and went flaky at PR #85 HEAD).
5. **Full mobile-chromium suite** unchanged: 59 passed, `phase-3b1-fit-reason`
   still ~1.3m — proof the fix is WebKit-scoped and costs Chromium nothing.
6. **Timing check.** `phase-3b1-fit-reason` on mobile-webkit must not carry
   the 6.6 s-per-iteration no-op signature. A genuinely working scroll exits
   early; ~2.5m is itself evidence of failure.
7. `flutter analyze` + `flutter test` (`validate` job) unaffected — no
   production change is proposed.

## Merge Recommendation

### CHANGES REQUIRED

PR #85 is a well-intentioned, constraint-respecting change that does not
achieve its stated goal, and whose helper commit is unvalidated, measurably
costly, and narrows an existing code path. Merging it now would record a fix
that CI shows does not exist.

The minimum bar to merge:

- **Either** repair the mobile-WebKit scroll so `phase-3b1-fit-reason` is
  actually green on mobile-webkit (Recommended Fix 1–3), keeping the spec
  line;
- **or** drop commit `23e5b68` (the `flt-semantics` helper branch), keep
  `a6bc636` (the spec line) on its own merits, and state plainly in the PR
  body that WebKit remains red pending the scroll repair.

Reverting the helper commit alone is a legitimate, low-risk landing: the spec
line is free on Chromium and correct once scrolling works, while the helper
branch is the part carrying risk with no demonstrated benefit.

I did not push any change to `agent/e2e-interview-offer-scroll-reachability`.
The reviewed HEAD `23e5b68` is untouched, per the brief.

## Recommended Next Task

**`SES_WEBKIT-SCROLL-1` — make mobile-WebKit scrolling real, and observable.**

Scope, in order:

1. Add failure-time ARIA-snapshot logging to the E2E harness (Recommended
   Fix 0) and run `phase-3b1-fit-reason` seed 100001 on mobile-webkit once.
   Publish the snapshot. **This single run upgrades this review's verdict from
   B to A or C and must precede any fix.**
2. Depending on that snapshot:
   - CTA text present, no button node → confirm the materialization root
     cause; proceed to (3).
   - CTA entirely absent → the root cause is *different* (offer generation or
     action sequence divergence on WebKit) and the whole fix direction must be
     re-planned, not patched.
3. Rewrite `installPortableWheelFallback`'s mobile-WebKit path around a real
   pointer-drag scroll, with effect verification and no early `return`
   (Recommended Fix 1).
4. Add the two missing tests (Recommended Fix 2–3), each demonstrated to fail
   before it passes.
5. Land PR #85's spec line on top of a working scroll; drop or rewrite
   `23e5b68`.
6. Once mobile-webkit is green on a full run, remove `continue-on-error: true`
   from the `e2e-webkit` job so the signal stops being invisible.

Constraints carried forward unchanged: no retry increase, no arbitrary
waits/sleeps, no skips, no WebKit exclusion, no assertion weakening, no
scenario deletion, no week-limit increase, no GameEngine / RNG / gameplay
change.

---

### Appendix — verdict rationale

| Option | Assessment |
|---|---|
| **A. ROOT CAUSE CONFIRMED** | Rejected. The decisive artifacts (trace, screenshot, `error-context.md` ARIA snapshot) were blocked by egress policy. Claim 3 rests on deduction, and this review does not certify a root cause it could not observe. |
| **B. ROOT CAUSE PARTIALLY CONFIRMED** | **Selected.** The failure, its pre-existence, its browser split, and the inertness of the WebKit scroll path are all confirmed from CI. The specific mechanism — CTA present in game state but unmaterialized in semantics — is strongly supported by determinism, viewport, and `ListView` structure, but not directly observed. |
| **C. DIFFERENT ROOT CAUSE** | Not selected, but not eliminated. If the diagnostic snapshot shows the CTA never appears at all on WebKit, C becomes correct and the fix direction changes. Recommended Next Task step 2 is written to catch exactly that. |
| **D. INSUFFICIENT EVIDENCE** | Rejected. Enough was established from logs and source alone to answer the practical question the review was called for: PR #85 does not fix the failure, and its WebKit scroll path provably does nothing. |
