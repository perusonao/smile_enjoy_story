# EVENT-UI PR #87 — Reintegration Review

**Mode:** Review only. No code, workflow, or PR state was modified.
**Reviewer run date:** 2026-08-29
**Repository:** `perusonao/smile_enjoy_story`

---

## 1. Head-line finding (corrects the review premise)

> **PR #87 is still cleanly mergeable against current `main`. There are no merge conflicts.**

The task framing assumed PR #87 "is no longer cleanly mergeable." That is not what the
repository shows. A three-way merge of the PR head into current `main` succeeds with a
clean tree and no conflicted paths:

```
$ git merge-tree --write-tree origin/main beee6ecf421f94c2b2cf046d3965f3225382853e
201e74beaeaa7c59ae548742cd9c69709fdaa376      # exit 0, no conflict output
```

`main` has advanced **17 commits** past the PR's merge base, but it touched **zero** of the
four files PR #87 changes.

What is actually red is **CI**, not the merge. GitHub reports
`mergeable_state: "unstable"`, which means *mergeable, but a check is failing* — it is not
the `dirty` state that indicates a conflict. Section 4 shows the failing check is a
stale-base failure that `main` has already fixed.

---

## 2. Current SHAs and PR metadata

| Item | Value |
|---|---|
| **Current `main` SHA** | `adf1325ed0770d3f8330c8de25d95417e0cc5c2a` ("Merge pull request #99 … PAYROLL-1A") |
| **PR #87 HEAD** | `beee6ecf421f94c2b2cf046d3965f3225382853e` |
| **PR #87 base (recorded)** | `ea0a4f24a9f55916122b9644aaf6ff65c2e0b57c` |
| **Merge base (`main` ↔ head)** | `ea0a4f24a9f55916122b9644aaf6ff65c2e0b57c` — identical to recorded base; the branch has not been rebased |
| **Branch** | `agent/event-ui-1-phase-1` |
| **State** | open, not draft, not merged |
| **Mergeability** | `mergeable_state: "unstable"` → **mergeable**, CI red |
| **Size** | 4 files, +345 / −63, 4 commits |
| **`main` ahead by** | 17 commits |

PR commits:

```
beee6ec test(ui): cover GameEventModal shell
f6f2eea feat(ui): migrate PublicDemoEventDialog to GameEventModal
6e1a9f4 feat(ui): add event image presentation mapper
9d6c02e feat(ui): add GameEventModal presentation shell
```

---

## 3. Conflict inventory

**Textual conflicts: none.** Mechanical or semantic.

Files touched by PR #87, cross-referenced against everything `main` changed since the
merge base:

| File | PR #87 | Touched by `main` since base? | Conflict |
|---|---|---|---|
| `lib/ui/widgets/game_event_modal.dart` | new (+184) | no — file does not exist on `main` | none |
| `lib/ui/widgets/event_image_mapper.dart` | new (+27) | no — file does not exist on `main` | none |
| `lib/ui/public_demo/public_demo_event_dialog.dart` | modified (+22/−63) | **no** | none |
| `test/ui/game_event_modal_test.dart` | new (+112) | no | none |

`git log ea0a4f2..origin/main -- <those four paths>` returns **empty**. The two change
sets are disjoint at the file level, which is why the merge is clean.

For completeness, what `main` *did* change since the base (16 files) — none of it overlaps:

```
.github/workflows/e2e.yml, public-demo-preview.yml, public-demo-validation.yml
docs/design/SES_EMPLOYEE-DATA-1_Expansion_Design.md
docs/design/SES_PAYROLL-1B_Integration_Design.md
e2e/helpers/artifacts.ts
lib/game/engine/engine.dart, payroll_engine.dart
lib/presentation/build_info.dart
lib/ui/engineers/engineer_detail_route_screen.dart, engineer_list_screen.dart
lib/ui/public_demo/public_demo_01_placeholder_screen.dart
lib/ui/public_demo/public_demo_home_presentation_components.dart
test/game/payroll_engine_test.dart
test/presentation/build_info_test.dart
test/ui/public_demo_home_presentation_components_test.dart
```

### Near-miss worth naming

`main` **did** modify `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — the file
that contains every `PublicDemoEventDialog` call site. But the change (commit `3a999d3`,
build-revision label) only adds a `buildInfo` field and rewrites the `AppBar` title. It does
not touch lines 235–516 where the event dialogs are constructed. Had PR #87 modified those
call sites, this would have been a real conflict. It does not — the migration is entirely
inside `public_demo_event_dialog.dart`, so the constructor signature is unchanged and all
call sites keep compiling untouched.

---

## 4. Why CI is red — and why it is not PR #87's fault

Check runs on head `beee6ec`:

| Check | Result |
|---|---|
| `validate` (analyze / test / build) | ✅ success |
| `e2e-chromium` | ✅ success |
| `Public Demo only` | ✅ success |
| `Build Public Demo browser preview` | ✅ success |
| **`e2e-webkit`** | ❌ **failure** |
| `build`, `deploy`, `replay-package`, `check-latest` | skipped |

The single failure:

```
1 failed
  [mobile-webkit] › tests/phase-3b1-fit-reason.spec.ts:245:7 ›
    Phase 3B-1: Fitの理由を見る is reachable and correct in real UI (seed 100001)
1 flaky
  [mobile-webkit] › tests/beginner-mode-april-june.spec.ts:40:7 › Phase 3A …
57 passed (6.4m)
```

This is an **engineer-detail scrolling test on mobile WebKit**. It has nothing to do with
event dialogs, and PR #87 changes **zero** e2e files (`git diff --name-only ea0a4f2..beee6ec`
matches no path under `e2e/`).

`main` has since landed exactly the fix for this class of failure:

- **`c305ce6` — "test: harden Flutter WebKit detail scrolling"** (`e2e/helpers/artifacts.ts`,
  +69/−13). Rewrites the portable wheel fallback: dispatches the wheel event at the viewport
  centre with `clientX`/`clientY` so Flutter's pointer hit-test does not land in the fixed
  AppBar, then falls back to a settled synthetic touch swipe on mobile WebKit where
  Playwright's wheel API is unavailable.
- **PR #93** (`3d2a2d2`, `edab205`, `cd79567`) — "keep engineer critical actions above the
  fold" / "route engineer details through critical CTA shell", which removes the need to
  scroll to reach the Fit-reason CTA in the first place.

**Conclusion:** this is a textbook stale-base red. The PR was branched before the WebKit
scroll harness was hardened, and its e2e run therefore reproduces a failure that `main`
no longer has. Merging `main` forward into the branch is expected to clear it — no change
to PR #87's own code is required for this check.

---

## 5. Semantic overlap with current `main`

### 5.1 Did `main` supersede any part of PR #87? — **No.**

The obvious suspect is `lib/ui/public_demo/public_demo_home_presentation_components.dart`,
added by PR #94 (HOME-UI-1) — a parallel "presentation components" effort landed while
PR #87 sat open. It does **not** overlap. Its declarations are:

```
PublicDemoEmployeeStageItem, PublicDemoImportantEventItem,
PublicDemoFinanceSummaryModel, PublicDemoMonthlyPrimaryCtaModel,
PublicDemoEmployeeStageSection, PublicDemoImportantEventsSection,
PublicDemoFinanceSummarySection, PublicDemoMonthlyPrimaryCtaSection,
_ImportantEventCard, _FinanceRow, _StatusChip, _HomeSectionCard
```

It contains **no `AlertDialog`, no `showDialog`, and no modal shell of any kind** — it is
in-page HOME dashboard sections and cards. Different axis of the UI entirely. `GameEventModal`
(a modal shell) and these (page sections) do not compete, and neither supersedes the other.
Note also that HOME is explicitly out of scope for PR #87, so leaving this file alone is correct.

No other commit on `main` introduces a shared modal shell, an event-image mapper, or anything
that duplicates PR #87's contribution.

### 5.2 Do PR #87's dependencies still exist on `main`? — **Yes, all of them.**

`EventImageMapper` is the only file in the PR that reaches outside `lib/ui/widgets`. Every
symbol it consumes is intact on current `main`:

- `AssetPaths.eventClientContact`, `eventFirstAssignment`, `eventRecruitmentApplication`,
  `eventClientInterview`, `eventCompanyManagement` — all present (`lib/ui/asset_paths.dart:24–30`).
- `OneTimeEvent.{interviewOfferCelebration, firstAssignmentCelebration,
  recruitmentUnlockCelebration, clientInterviewCelebration, recruitmentInterviewCelebration,
  welfareUnlockCelebration}` — all present (`lib/game/models/founding_progress.dart:59–65`).

Neither `asset_paths.dart` nor `founding_progress.dart` was modified by `main` since the
merge base, so the branch is expected to compile unchanged.

> **Verification caveat:** the Flutter SDK is not installed in this review container
> (`flutter: command not found`), so `flutter analyze` and `flutter test` could **not** be
> executed locally. The compile claim above is a symbol-level static check, not a build.
> It must be confirmed by CI on the merged-forward branch.

### 5.3 Guardrail compliance — **clean**

PR #87 touches none of the forbidden engine files. The complete diff is 4 files, none of
which is `lib/game/engine/finance_engine.dart`, `lib/game/engine/game_engine.dart`, or
`lib/game/engine/payroll_engine.dart`. There is **no contact with PAYROLL work at any point**,
and no Domain / GameState / Finance / Save / workflow / e2e / asset changes.

---

## 6. Review of the change itself

Merge mechanics are the easy part here; these are the findings that actually matter.

### 6.1 `EventImageMapper` is unused dead code — **decision required**

A grep across the entire PR head finds no reference to `EventImageMapper` other than its own
declaration — not in `lib/`, not in `test/`:

```
$ git grep -n "EventImageMapper" beee6ec -- lib test
beee6ec:lib/ui/widgets/event_image_mapper.dart:7:class EventImageMapper {
beee6ec:lib/ui/widgets/event_image_mapper.dart:8:  const EventImageMapper._();
```

Nothing calls `forOneTimeEvent` or `forCategory`. `PublicDemoEventDialog` still receives
`imageAsset` from its call sites, exactly as before. The mapper ships **unwired and
untested** — it is a Phase-2 seed that arrived a phase early.

It *is* correctly layered (presentation-only: UI depends on the domain enum, the domain never
learns about asset paths — the file's own comment states this intent and honours it), so it
does not violate the scope boundary. But it is speculative surface area.

**Recommendation:** keep it only if Phase 2 lands imminently; otherwise defer it to the PR
that introduces its first consumer. If kept, it needs unit tests — every enum case and the
`_ => null` fallback — since nothing currently exercises it.

### 6.2 Image geometry changes — Public Demo visual regression risk

| | Before | After (shell) |
|---|---|---|
| Sizing | `AspectRatio(16/9)` | fixed `height: 180`, `width: double.infinity` |
| Corners | `ClipRRect(radius 14)`, inset | full-bleed, clipped by dialog `Clip.antiAlias` |
| Overlay | none | new bottom gradient scrim (40dp, `#4D000000`) |
| `insetPadding` | `h20 / v24` | `h10 / v40` |
| Message style | `titleMedium` | `bodyMedium`, `height: 1.5` |

On a ~360dp dialog, 16:9 is ≈197dp tall versus the new fixed 180dp, and the image is now
full-bleed rather than inset with rounded corners. Per the code comment being deleted, the
bundled event images are natively only ~160–220px wide, so a wider full-bleed frame at
`BoxFit.cover` changes crop and upscale behaviour.

This is a deliberate redesign, not a bug — but it is a **visible Public Demo change**, and
`AGENTS.md` states the current focus is precisely "a human/video UX review of that Phase 3A
slice." These deltas should go through that review rather than land silently.

### 6.3 Loss of institutional knowledge — should be restored

The migration deletes a ~20-line comment block in `public_demo_event_dialog.dart` recording
the **PR #36 iOS rendering investigation**: why `cacheWidth`, `filterQuality.low`, and
`gaplessPlayback` were each evaluated and rejected, plus the pointer to `_precacheEventImage`
in `public_demo_01_placeholder_screen.dart` as the real fix for image pop-in.

None of that reasoning is reproduced in `game_event_modal.dart`'s `_EventImage`. Without it,
a future agent optimising the shell will re-add exactly the three properties that were
already measured and rejected. **This comment should be carried over to `_EventImage`.**

### 6.4 Accessible-name mechanism changed — highest-risk behavioural delta

- **Before:** `AlertDialog(title: Text(title))`. Flutter wraps `title` with `namesRoute`,
  so the dialog's accessible name comes from the title widget.
- **After:** the title is a plain `Text` inside `content`; the dialog's name comes solely from
  `AlertDialog.semanticLabel` (`category == null ? title : '$category: $title'`).

For the Public Demo call sites `category` is null, so `semanticLabel == title` and the
resulting aria-label *should* be unchanged. But this is a real change of mechanism, and the
e2e a11y layer parses dialog nodes by name:

- `e2e/helpers/game-state.ts:103` — `if (role === 'dialog' || role === 'alertdialog') dialogIndent = indent;`
- `e2e/tests/game-state.ariaParsing.spec.ts:87` — asserts on `- alertdialog "🎉 新機能解放: 採用":`

**Mitigating fact:** that specific asserted dialog lives in `lib/ui/widgets/founding_dialogs.dart:106`,
which PR #87 does **not** migrate. So for Phase 1 the risk is **latent**; it becomes **acute**
in Phase 2 when `founding_dialogs.dart` moves onto the shell. No widget test in the PR asserts
the dialog's semantic label — that gap should be closed now, before Phase 2 depends on it.

### 6.5 What is safe

- The `確認` action button stays inside `AlertDialog.actions`, so it remains a descendant of
  the `dialog`/`alertdialog` a11y node and `dialogButtonNames` scoping (`game-state.ts:15–30`)
  continues to work. No e2e selector breakage expected.
- No e2e spec references the three Public Demo event titles (`案件を受注しました`,
  `新しい応募が届きました`, `入社・初参画！`) or the `次の行動` label, so the content
  restructuring is not observed by any current test.
- `imageAsset` is `required` and non-nullable on `PublicDemoEventDialog` but nullable on the
  shell — passing non-null into nullable is safe, and `hasImage` is always true at these call sites.
- Existing widget coverage is reasonable: single-fire action callback, image/badge/description/
  info rendering, long-Japanese-title wrap without ellipsis, and three actions reachable at
  360×800 with large text.

---

## 7. Safe to preserve / discard / rebuild

### Safe to preserve as-is
- `lib/ui/widgets/game_event_modal.dart` — the shell itself. Well-factored, presentation-only,
  no domain coupling, no gameplay callbacks. Keep.
- `test/ui/game_event_modal_test.dart` — keep; extend per §8.
- `lib/ui/public_demo/public_demo_event_dialog.dart` — keep the migration; constructor signature
  is unchanged so all six call sites remain valid.

### Preserve with amendment
- `public_demo_event_dialog.dart` / `game_event_modal.dart` — restore the PR #36 rendering-
  investigation comment onto `_EventImage` (§6.3).
- `game_event_modal.dart` — add a widget test pinning the dialog's semantic label (§6.4).

### Discard or defer (judgement call for the owner)
- `lib/ui/widgets/event_image_mapper.dart` — unused. Either add unit tests and keep it as an
  explicit Phase-2 seed, or drop it from this PR and reintroduce it with its first consumer.

### Rebuild
- **Nothing.** No part of this PR has been superseded, invalidated, or made uncompilable by `main`.

---

## 8. Minimal reintegration file set

Reintegration requires **no manual conflict resolution**. The complete set:

| # | File | Action |
|---|---|---|
| 1 | — | Merge `origin/main` (`adf1325`) into `agent/event-ui-1-phase-1`. Expected: clean, zero conflicts. This alone is expected to fix `e2e-webkit` by pulling in `c305ce6` + PR #93. |
| 2 | `lib/ui/widgets/game_event_modal.dart` | Restore the PR #36 image-rendering comment onto `_EventImage`. |
| 3 | `test/ui/game_event_modal_test.dart` | Add a semantic-label assertion (with and without `category`). |
| 4 | `lib/ui/widgets/event_image_mapper.dart` | Either add unit tests, or remove from this PR. |

Files **1–4 only**. No e2e file, no workflow file, no engine file, no call-site file needs to
change. `e2e/helpers/artifacts.ts` and `.github/workflows/e2e.yml` arrive via the merge —
they must **not** be hand-edited.

**Merge, not rebase.** `agent/event-ui-1-phase-1` is another author's branch; a merge commit
keeps existing checkouts valid, and the repo's history already uses merge commits
(`Merge pull request #NN from …`).

---

## 9. Required tests before merge

| Check | Why |
|---|---|
| `flutter analyze` | Confirms the branch compiles on current `main` — **not verified locally**, no Flutter SDK in the review container. Also flags `EventImageMapper` if it is kept unused. |
| `flutter test` | Full unit + widget suite, including the 4 new `game_event_modal_test.dart` cases and the new semantic-label case. |
| `e2e-chromium` | Was already green; must stay green. |
| **`e2e-webkit`** | **The gate.** Must be re-run after the merge-forward. Passing confirms the failure was the stale base, not PR #87. If `phase-3b1-fit-reason.spec.ts:245` still fails post-merge, the diagnosis in §4 is wrong and the PR needs real investigation. |
| `Public Demo only` / `Build Public Demo browser preview` | Public Demo is the surface actually changed. |
| Human/video UX review | Per `AGENTS.md` current focus — sign-off on the §6.2 visual deltas. |

---

## 10. Forbidden files — must not appear in any reintegration diff

- `lib/game/engine/finance_engine.dart`
- `lib/game/engine/game_engine.dart`
- `lib/game/engine/payroll_engine.dart`

Also out of scope for this work: Domain/GameState authority, Finance/Payroll, Save, gameplay
balance, HOME/Navigator (including `public_demo_home_presentation_components.dart`),
workflow/E2E weakening, and any new or replaced image asset.

PR #87 as it stands is **compliant with all of the above**.

---

## 11. Recommendation

# ✅ KEEP

**Merge `main` forward into `agent/event-ui-1-phase-1`; do not rebuild.**

Rationale:

1. **There is no conflict to resolve.** `git merge-tree` produces a clean tree; `main` touched
   none of the four files.
2. **Nothing was superseded.** The parallel HOME-UI-1 work is page sections, not a modal shell.
3. **All dependencies are intact** — every `AssetPaths` and `OneTimeEvent` symbol still exists.
4. **The red check is not this PR's.** `e2e-webkit` fails on a detail-scrolling spec the PR does
   not touch, and `main` already carries the fix.
5. **A rebuild would discard 345 lines of reviewed, mostly-green work** to solve a problem that
   does not exist. REBUILD, SUPERSEDE, and BLOCK are all unjustified by the evidence.

The four amendments in §8 are small, local, and presentational — they are polish on a sound
change, not a reason to restart it.

**Residual risk: low.** The one item to watch is the §6.4 accessible-name change, which is
latent in Phase 1 and must be pinned by a test before Phase 2 migrates `founding_dialogs.dart`.

---

## 12. Next implementation prompt outline (for Codex) — *outline only, not implemented*

> **Title:** EVENT-UI-1 Phase 1 — reintegrate PR #87 onto current `main`
>
> **Mode:** implementation. Branch `agent/event-ui-1-phase-1`, PR #87.
>
> **Step 1 — merge forward.**
> `git fetch origin main && git merge origin/main` on `agent/event-ui-1-phase-1`.
> Expect zero conflicts. If any conflict appears, **stop and report** — it contradicts this
> review and means the branch moved. Do not rebase; do not force-push.
>
> **Step 2 — restore the rendering rationale.**
> Move the PR #36 comment block (why `cacheWidth`, `filterQuality.low`, `gaplessPlayback` were
> rejected; the `_precacheEventImage` pointer) from the pre-migration
> `public_demo_event_dialog.dart` onto `_EventImage` in `lib/ui/widgets/game_event_modal.dart`.
> Comment only — no behaviour change.
>
> **Step 3 — pin the accessible name.**
> Add to `test/ui/game_event_modal_test.dart`: assert the dialog's semantic label equals the
> title when `category` is null, and `'$category: $title'` when it is set. This guards the
> `AlertDialog.title` → `semanticLabel` mechanism change before Phase 2 relies on it.
>
> **Step 4 — resolve `EventImageMapper`.** Pick one and say which:
> (a) keep + add unit tests covering all six `OneTimeEvent` cases, all four category strings,
> and both `_ => null` fallbacks; or
> (b) remove `lib/ui/widgets/event_image_mapper.dart` from this PR, to return with its first
> consumer in Phase 2.
>
> **Step 5 — validate, then push once.**
> `flutter analyze` and `flutter test` locally; both clean. Push, then confirm `validate`,
> `e2e-chromium`, and **`e2e-webkit`** are green. If `e2e-webkit` still fails on
> `phase-3b1-fit-reason.spec.ts`, report the failure — do **not** retry blindly, and do **not**
> skip, quarantine, or weaken any test or workflow.
>
> **Step 6 — flag for UX review.** Note the §6.2 visual deltas (fixed 180dp full-bleed image
> replacing the inset 16:9, new gradient scrim, wider `insetPadding`, `titleMedium` →
> `bodyMedium`) in the PR body for the human/video UX pass.
>
> **Hard constraints.** Touch only the four files in §8. Never modify
> `lib/game/engine/finance_engine.dart`, `lib/game/engine/game_engine.dart`, or
> `lib/game/engine/payroll_engine.dart`. No Domain/GameState/Finance/Save/gameplay-balance
> changes, no HOME/Navigator changes, no workflow or e2e edits, no new or replaced assets.
> Do not change `PublicDemoEventDialog`'s constructor signature — six call sites in
> `public_demo_01_placeholder_screen.dart` depend on it.

---

### Appendix — commands used

```bash
git rev-parse origin/main                                   # adf1325e…
git merge-base origin/main beee6ec                          # ea0a4f24… (== recorded base)
git merge-tree --write-tree origin/main beee6ec             # exit 0, clean tree
git log --oneline ea0a4f2..origin/main -- <PR's 4 paths>    # empty → no overlap
git rev-list --count ea0a4f2..origin/main                   # 17
git grep -n "EventImageMapper" beee6ec -- lib test          # declaration only → unused
```
