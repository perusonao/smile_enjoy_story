# SES FIRST-FUN-YEAR — Recruitment Lifecycle Visibility (Issue #245 Finding #12/#13) — Result Report

## STATUS

**Implemented, self-hardened, tests green. Both of PR #252's Codex review
P2 findings are now fixed**, across two follow-up rounds. Presentation-only
change on the existing 営業タブ (Recruitment/Sales surface). No new screen,
no save-schema change, no hiring-decision/authority change (interviewScore
threshold, stage transitions, and offer-acceptance formula are all
untouched). Codex broad review (already run once on PR #252, per the
task's own confirmation) was **not re-run** in either follow-up round, per
explicit instruction — only the two already-posted P2 findings were fixed.

## PR #252 Codex review round 1 — first P2 fix

PR: [#252](https://github.com/perusonao/smile_enjoy_story/pull/252)
(`claude/recruitment-lifecycle-visibility-qul91k` → `main`).

**Finding (P2, [discussion `r3995465859`](https://github.com/perusonao/smile_enjoy_story/pull/252#discussion_r3995465859)):**
`preEntryPartnerFailed`/`preEntryClientFailed` were classified as `closed`
("結果確定（不採用・辞退）"), but a failed pre-entry partner/client interview
never touches [PublicDemoApplicant.bindingOffer] (minted once, at offer
acceptance, before the pre-entry sales chain even starts) or excludes the
applicant from `PublicDemoApplicant.join`'s guard (which only excludes
`hasJoined` and `stage == offerDeclined`). `closeMay`'s own `accepted()`
predicate explicitly includes both failed stages in its joined set, and
later months' `joinAcceptedForFiscalClose` join every applicant
unconditionally except `offerDeclined`. So such an applicant **genuinely
still joins at month-end** — the player was being told, falsely, that their
employment outcome was final and negative.

**Fix**: `_S._applicantLifecycleBucket` now classifies
`preEntryPartnerFailed`/`preEntryClientFailed` as `awaitingJoin` (alongside
`juneOrdered` and an inexperienced accepted offer), not `closed`. `closed`
is now exactly `{rejected, offerDeclined}` — the only two stages where
`PublicDemoApplicant.join` genuinely never joins (confirmed independently
by re-reading `join()`'s guard and `closeMay`/`joinAcceptedForFiscalClose`
before editing). The card's own sales-failure status/tone is **byte-for-
byte unchanged** — `applicantStatus`'s "上位面談不合格"/"客先面談不合格" labels,
`_applicantStatusTone`'s negative (caution-colored) tone, and
`applicantStep`'s progress-bar position are untouched; only which lifecycle
group header the card renders under changed. This was independently
verified against `origin/main`'s live PR #252 HEAD (`04c5fd7bbfdb822ffcaa0db455b4f81728be5964`
— unchanged since the original push, confirmed via `pull_request_read`)
before editing, matching the review comment's own citation exactly.

A second P2 finding on the same PR round was left open at the end of this
round (out of its explicit scope) — see the next section for its fix, in a
further follow-up round.

## PR #252 Codex review round 2 — second P2 fix (this update)

**Finding (P2, [discussion `r3995477975`](https://github.com/perusonao/smile_enjoy_story/pull/252#discussion_r3995477975)):**
an applicant at `interviewed` whose interactive interview session was
decided "採用候補として進める" (`InterviewOutcome.hired`) while their real
`interviewScore` is below 60 hits a genuine dead end no `_applicantLifecycleBucket`
fallback accounted for: `ac(i)`'s own offer button renders but is
permanently disabled (`onPressed: a.interviewScore >= 60 ? () => offer(i)
: null`), and `_addApplicantStageCandidate`'s identical `interviewed`
branch (`if (a.interviewScore >= 60) emit(...)`) emits **no**
`HomeRecommendedActionKind` for this exact combination either — no legal
action exists anywhere on screen. `PublicDemoAggregate.concludeInterviewSession`
locks the session once `completed`, so the *other* `interviewed` branch
("面談を行う"/"面談を続ける", for a not-yet-decided session) never reappears
either. This state survives every later month close (`interviewed` is not
in `closeMay`'s own `accepted()` prune-survivor set either way, and every
later close uses `joinAcceptedForFiscalClose`, which never prunes) and
save/reload indefinitely, yet fell through `_applicantLifecycleBucket`'s
catch-all `_ => active`.

**Verification before editing (per the task's explicit instruction to
Fresh-audit the live PR HEAD first):** re-fetched
`claude/recruitment-lifecycle-visibility-qul91k` and confirmed local HEAD
matched the PR's live HEAD (`b3a03e2401ca8431fbd4531c17384bff4a6ca049`,
unchanged since the prior round's push) via `pull_request_read` before any
edit. Independently re-read `_interviewDecidedHired` (`workflow
.interviewSessions.any((s) => s.applicantId == id && s.completed && s
.outcome == InterviewOutcome.hired)`), `ac(i)`'s `interviewed` branch, and
`_addApplicantStageCandidate`'s identical branch to confirm the review's
claim of "no legal action" character-for-character before writing the fix,
not on faith.

**Fix**: `_applicantLifecycleBucket` gained one new guarded case —
`PublicDemoApplicantStage.interviewed when _interviewDecidedHired(a.id) &&
a.interviewScore < 60 => closed` — placed before the `juneOrdered`/
`preEntryPartnerFailed`/`preEntryClientFailed` case and the catch-all, so
it only ever matches this exact dead-end combination. Every other
`interviewed` applicant (not yet decided, or decided-hired with a real,
pressable offer button) is completely unaffected and still falls through
to `active`. `closed` was chosen over `awaitingJoin` because, unlike the
first P2 fix's two stages, this applicant genuinely never receives a
`bindingOffer` and never joins — `closed`'s existing semantic ("no legal
action, employment outcome will not happen") is the truthful one here, not
"waiting to become an employee." No `PublicDemoApplicantStage` value,
`interviewScore` threshold, `acceptOffer`/`concludeInterviewSession`
formula, or save-schema key was touched — this is a pure, presentation-time
reclassification, exactly as instructed.

## Issue / scope

- **Issue:** [#245](https://github.com/perusonao/smile_enjoy_story/issues/245)
  (FIRST-FUN-YEAR Human Replay UX Findings) — **Finding #12** (入社面談後の
  応募者がどうなったか分からない — player-facing lifecycle visibility after
  join, explicitly separated from #241's stale-CTA fix) and **Finding #13**
  (採用タブ内で応募者一覧/選考中/結果待ち/辞退/入社予定の所在が直感的でない).
- Findings #1, #2, #3, #8, #9, #11 were already implemented and merged
  before this session (`docs/reports/SES_FIRST-FUN-YEAR_Human-Replay-UX-PhaseA_Result.md`,
  Phase B partner-interview PR #247). #4 (parallel sales), #6 (monthly
  report polish), #7 (紹介会社/商流), #10 (interview modal density) remain
  explicitly out of scope for this Phase.
- Guardrail compliance (per this task's own instructions): no new large
  screen, no save-schema change, no hiring-decision-logic change. Every
  authoritative fact used below (`PublicDemoApplicantStage`,
  `PublicDemoApplicant.hasJoined`, `canEnterPreJoinSales`) already existed
  and was already read elsewhere on this same screen.

## Base / Freshness

`origin/main`'s repository-default-branch pointer (`git remote show origin`)
is **not** `main` in this repository (it reports
`claude/ses-game-core-phase-0-h7e8om`) — per the task's explicit instruction,
this was not trusted. `git fetch origin main` + `git rev-parse origin/main`
was run explicitly instead.

- **Audited/base `origin/main` SHA:** `b8a58dceb8ccc32d2e45661d46572b55af362b04`
  (PR #251 merge — the repository's actual latest history).
- The designated branch (`claude/recruitment-lifecycle-visibility-qul91k`)
  existed locally and on `origin`, but pointed at a single stale scaffold
  commit (`f4ca78f`, "Phase 0A/0B: SES domain models and random generators")
  that was already an ancestor of `origin/main` (0 commits ahead, 0 unique
  work, no PR ever opened for it — confirmed via `search_pull_requests`).
  Per the "already-merged/stale branch" restart rule, it was reset with
  `git checkout -B claude/recruitment-lifecycle-visibility-qul91k origin/main`
  before any new work.

## Fresh Audit — authority trace for Findings #12/#13

Traced directly against current `lib/game/public_demo/public_demo_recruitment.dart`
and `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (§营業タブ):

| # | Question | Authority | Finding |
|---|---|---|---|
| 1 | What is the applicant lifecycle state machine? | `PublicDemoApplicantStage` (14 values: applied → resumeReviewed → interviewed → {rejected \| offerAccepted → offerDeclined \| preEntry* chain → juneOrdered}) | Complete, already unforgeable at the terminal facts that matter (`hasBeenInterviewed`/`hasBindingOffer`/`hasJoined` are all backed by private, identity-checked record types — see `PublicDemoInterviewRecord`/`PublicDemoJoinRecord`/`PublicDemoBindingOffer`). No new state needed. |
| 2 | Does an applicant ever get removed/forgotten after joining? | `PublicDemoWorkflowState.applicants` (never pruned) + `PublicDemoApplicant.join()` (never nulls `stage`) | **No** — a joined applicant's record is retained forever with full history. The *only* thing that changes at join is `joinRecord`/`acceptedMonthlySalary`/morale/trust/`relationshipHistory`; `stage` is left exactly where it was (`juneOrdered` for the pre-entry-sales path, or unchanged for an inexperienced hire). The engineer id an applicant becomes is **the same id** (`PublicDemoWorkflowState._withAssignments`/`PublicDemoAggregate._joinAcceptedApplicants` both use `applicant.id` verbatim as `engineerId`). |
| 3 | Why did Finding #12's symptom exist despite #2's answer? | `_S._salesApplicantProgressCards` (Issue #241 fix) | Issue #241 correctly excludes `hasJoined` applicants from the funnel (their story continues on 社員, never a stale pre-join badge — verified by a locked regression test, `public_demo_sales_ui_phase1_test.dart`'s "never lingers on an already-joined applicant"). But excluding them meant **silently vanishing with zero on-screen acknowledgement** — indistinguishable, from the 営業 tab alone, from a bug. This is Finding #12's actual root cause: a correct exclusion with no compensating summary. |
| 4 | Why did Finding #13's symptom exist? | `_S._salesApplicantProgressCards` (pre-fix) | Every not-yet-joined applicant rendered as one flat list, in `workflow.applicants` order, with no grouping. A candidate still needing a player action (`applied`/`interviewed`/preEntry-in-progress) was visually indistinguishable from one whose outcome was already final and unsuccessful (`rejected`/`offerDeclined`/`preEntryPartnerFailed`/`preEntryClientFailed` — none of which render any button, per `ac(i)`'s own per-stage branches) and from one simply waiting for the month-end join boundary (`offerAccepted` + inexperienced, or `juneOrdered` — also no button). All three groups already exist as *facts* (`ac(i)`'s branch structure, `_applicantStatusTone`'s tone set) — only the **presentation** never grouped them. |
| 5 | Is a new stage/score/field needed to fix either finding? | — | **No.** Every fact used below is a read of `a.stage`/`a.hasJoined`/`a.canEnterPreJoinSales` — the exact same facts `applicantStatus`/`_applicantStatusTone`/`ac(i)`'s button branches already switch on. Confirmed no disagreement is possible between the new grouping and the existing per-card content, since both read the same switch input. |

## Implementation

Both changes are confined to
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — no other
production file touched, no domain/game-layer file touched.

### Finding #12 — 入社済み summary line (`_S._salesOverviewSection`)

Added one conditionally-rendered line below the existing 3-tile stat row
(`public-demo-sales-joined-summary` key): **`入社済み N名（社員タブで活動中）`**,
rendered only when `workflow.applicants.where((a) => a.hasJoined).length > 0`.

Deliberately **does not** name the joined applicant(s) — Issue #241's own
locked regression test (`public_demo_sales_ui_phase1_test.dart`) requires
that a joined applicant's name never render on the 営業 tab funnel again,
and this line does not need to violate that to answer the question: it
truthfully states *that* N people already joined and *where* their story
continues (社員タブ), without duplicating anything the 社員 roster already
shows in full (name, skills, salary, assignment).

### Finding #13 — active/awaitingJoin/closed grouping (`_S._salesApplicantProgressCards`)

Added `_ApplicantLifecycleBucket` (`active` / `awaitingJoin` / `closed`) and
`_S._applicantLifecycleBucket(PublicDemoApplicant)`, a pure presentation-time
classifier — **as corrected by the PR #252 Codex review P2 fix above**:

- **`closed`**: `rejected`, `offerDeclined` (the only two stages where
  `PublicDemoApplicant.join` genuinely never joins the applicant — a
  *final, unsuccessful employment outcome*, not merely a failed sales
  attempt), plus — since the second P2 fix — `interviewed` when
  `_interviewDecidedHired(a.id) && a.interviewScore < 60` (a completed
  interview decision with no legal offer button and no HOME action
  anywhere on screen; this applicant likewise never receives a
  `bindingOffer` and never joins).
- **`awaitingJoin`**: `juneOrdered`, `offerAccepted` when
  `!canEnterPreJoinSales` (an inexperienced hire waiting for the normal
  monthly join boundary), and — since the P2 fix — `preEntryPartnerFailed`/
  `preEntryClientFailed` (a failed pre-entry sales interview that does not
  cancel the already-minted binding offer, so the applicant still joins at
  month-end). All four cases are stages where `ac(i)` renders **no button
  at all**, but the *employment* outcome is not unsuccessful.
- **`active`**: everything else — every stage where `ac(i)` renders an
  actionable button (`applied`/`resumeReviewed`/`interviewed`/
  `offerAccepted`&&experienced/`preEntrySkillSheet`/`preEntrySelling`/
  `preEntryIntroduced`/`preEntryPartnerPassed`/`preEntryClientPassed`).

Note this bucket assignment is deliberately **not** identical to
`_applicantStatusTone`'s "negative" set — that tone is about the *sales/
interview* outcome (used for `applicantStatus`'s own badge color, left
unchanged) and still marks `preEntryPartnerFailed`/`preEntryClientFailed`
as negative-toned, correctly, since the pre-entry interview itself did
fail. The lifecycle bucket is about the *employment* outcome instead, and
the two deliberately disagree for exactly these two stages.

`_salesApplicantProgressCards()` now buckets every not-yet-joined applicant
by index, then renders three optional, count-labeled group headers —
**対応が必要な候補者（N名）**, **結果待ち・入社予定（N名）**,
**結果確定（不採用・辞退）（N名）** — each only when its bucket is non-empty,
followed by the *exact same* `ac(i)` cards (same widget, same key, same
button/eligibility, same order within each bucket) as before. When there
are zero not-yet-joined applicants, the returned list is empty exactly as
before, so the whole `採用・候補者進捗` section still does not render at all
(verified by the pre-existing "never lingers" test, still passing
unmodified).

## Guardrail compliance

- No new `PublicDemoApplicantStage` value, no new persisted field, no
  `toJson`/`fromJson` change — `_ApplicantLifecycleBucket` is a private,
  UI-file-local enum, never serialized.
- No Finance/Payroll/Matching/Interview-outcome formula touched.
- No hiring-decision logic touched — `_applicantLifecycleBucket` only
  *reads* `a.stage`/`a.canEnterPreJoinSales`, never writes either.
- No new screen/route/tab — both changes are inside the two existing
  営業タブ sections (`_salesOverviewSection`/`_salesApplicantProgressCards`).
- `ordered != assigned`, `revenue != cash receipt`, HOME Freeze (`_officeStageStatusFor`
  untouched) all preserved — none of this touched HOME or any Finance file.
- Issue #241's own regression contract (never re-render a joined applicant's
  name on 営業) is preserved and additionally exercised by 3 new tests.

## Tests

- `flutter analyze`: **No issues found** (all three rounds).
- `test/ui/public_demo/public_demo_issue245_recruitment_lifecycle_visibility_test.dart`
  now has **29 tests** across three rounds:
  - **Original 17** (implementation round) — active-only grouping,
    closed-only grouping (via a genuinely rejected applicant driven through
    the real production `completeInterview` → interactive interview
    session → `concludeInterviewSession(InterviewOutcome.rejected)` path,
    never a fabricated stage), active+awaitingJoin coexistence (via the
    real production pre-entry-sales chain up to `recordJuneOrder`,
    deliberately stopping short of `closeMay`), reading-order check, the
    joined-summary line's exact text and its absence/non-fabrication, a
    joined+still-active coexistence case, save/reload, a double-tap smoke
    test, and 8 360×800/390×844 × TextScaler 1.0/1.3 overflow checks.
  - **+7 for the first P2 fix** (preEntryPartnerFailed/preEntryClientFailed) —
    a genuine `preEntryPartnerFailed` applicant (`runSeed` 4's real
    free-medium May candidate, `salesSkillFit` 49, confirmed below the real
    60 threshold) renders under 結果待ち・入社予定 with its 上位面談不合格
    badge/tone unchanged; a genuine `preEntryClientFailed` applicant
    (`runSeed` 2, `salesSkillFit` 60 — clears the real partner threshold,
    fails the real client threshold of 65) renders under 結果待ち・入社予定
    with its 客先面談不合格 badge/tone unchanged; `rejected` and a genuinely
    declined offer (`offerDeclined`, forced via a real `acceptanceScore: 0`
    offer — same direct-construction technique the file's own
    `_juneWithOneJoinedApplicant` fixture already uses for the opposite
    outcome) still classify as 結果確定, and the declined applicant is
    confirmed never among the genuinely joined at `closeMay`; two tests
    drive `closeMay` on top of each failed fixture and confirm the
    applicant genuinely joins (`hasJoined == true`, `stage` still the
    failed value) and the overview's 入社済み summary line takes over; and a
    save/reload round-trip preserving the `preEntryPartnerFailed` →
    awaitingJoin classification.
  - **+5 for this round's (second) P2 fix** (below-threshold decided-hired
    `interviewed` applicants) — a genuinely stalled applicant (`runSeed`
    18's real free-medium May candidate, `interviewScore` 49 — confirmed
    below 60) decided "採用候補として進める" (`concludeInterviewSession
    (InterviewOutcome.hired)`, never a caller-supplied outcome bypass) is
    confirmed to render a genuinely `onPressed: null` offer button and is
    classified 結果確定, never 対応が必要; the non-stalled counterpart
    (`runSeed` 1, `interviewScore` 62 — clears the threshold) decided the
    same way keeps a real, pressable offer button and stays 対応が必要,
    proving the fix narrows `closed` to only the exact dead-end
    combination; a month-boundary test recruits in **June** specifically
    (`runSeed` 3, `interviewScore` 48) rather than May, because `closeMay`'s
    own `joinAndKeepOnly` one-time May-cohort prune would otherwise remove
    the applicant entirely and mask what the test wants to prove — drives
    through `closeJune` (which uses the non-pruning
    `joinAcceptedForFiscalClose`) and confirms the applicant survives and
    stays 結果確定 afterward; a save/reload round-trip preserving the same
    classification; and a confirmation this dead-end applicant never joins
    at either `closeMay` or `closeJune` (they never receive a
    `bindingOffer` at all, unlike the two pre-entry-failed stages from the
    first P2 fix).
- `flutter test test/game/public_demo`: **889 passed**, 0 failed — re-run
  after every round's edit (no game-layer file was ever touched across all
  three rounds; confirms zero regression each time).
- `flutter test test/ui/public_demo`: **741 passed**, 0 failed (712
  pre-existing + 29 in the new file — 736/24 after round 1's P2 fix,
  729/17 in the original implementation round).
- `git diff --check`: clean (all three rounds).
- Independently re-read `PublicDemoApplicant.join`'s own guard,
  `PublicDemoAggregate.closeMay`'s `accepted()` predicate, and
  `PublicDemoWorkflowState.joinAcceptedForFiscalClose` before editing —
  confirming the review comment's claim first, not just applying the
  suggested fix on faith.

### Screenshots regenerated as a side effect (expected, unchanged mechanism)

`test/ui/public_demo/public_demo_seeded_recruitment_visual_test.dart`
unconditionally rewrites
`docs/reports/screenshots/ses-core-gameplay-phase2-recruitment-seed{A,B}-{360x800,390x844}.png`
every time it runs (same pre-existing mechanism noted in PR #249's own
report). These 4 files changed by a few hundred bytes each, reflecting the
new "対応が必要な候補者（N名）" group header now visible above the applicant
card in that screenshot — an intentional, expected visual consequence of
this Phase's own change, not a side effect to revert.

## 360×800 / 390×844, TextScaler 1.0/1.3

Verified via the new suite's dedicated group (8 tests): the two new group
headers and the joined-summary line stay within screen bounds at both
target viewports and both required text scales, with no `takeException()`.

## State integrity checklist (per task instructions)

- **dismiss/back/reopen**: not applicable — this change touches no
  modal/dialog file (`public_demo_recruitment_interview_dialog.dart` etc.
  untouched). The existing suite's own dismiss/back/reopen regression tests
  (Issue #245 Phase A Finding #9) still pass unmodified.
- **save/reload**: covered by a new dedicated test — `toJson`/`fromJson`
  round-trip reproduces the identical grouping (purely derived from
  already-persisted `stage`/`hasJoined`, introduces no new state of its
  own).
- **duplicate/double tap**: covered by a new dedicated test — double-
  tapping スキルシート確認 advances the applicant exactly once and the
  active-bucket count stays at 1, no exception.
- **month boundary**: not touched — `_salesApplicantProgressCards`/
  `_salesOverviewSection` are re-evaluated fresh on every rebuild from
  `workflow`/`s`, with no month-keyed cache; the pre-existing month-
  boundary tests in `public_demo_sales_ui_phase1_test.dart` and
  `public_demo_01_fiscal_year_progression_test.dart` still pass unmodified.
- **joined/declined/pending**: exactly the three states this Phase's own
  grouping is built around (`awaitingJoin`/`closed`/`active` respectively,
  plus the joined-summary line for genuinely joined) — each traced back to
  real production commands in the new test file, not fabricated. **This
  round's own fix is itself a joined-vs-pending correctness fix**: a
  `preEntryPartnerFailed`/`preEntryClientFailed` applicant is genuinely
  `pending → joined` (their binding offer survives the failed pre-entry
  interview), not `declined` — confirmed by two new tests that drive
  `closeMay` on top of each and assert `hasJoined == true` afterward, and
  the overview's 入社済み summary line taking over from the funnel card at
  that point, exactly like any other accepted offer.

## Unresolved items / follow-ups

- **Both of PR #252's Codex review P2 findings are now fixed** (round 1:
  `preEntryPartnerFailed`/`preEntryClientFailed`; round 2, this update: the
  below-threshold decided-hired `interviewed` dead end). No known open
  Codex finding remains on this PR as of this report.
- The Issue's own originally-required Fresh Audit deliverable
  (`docs/reports/SES_FIRST-FUN-YEAR_Human-Replay-UX-Findings_Fresh-Audit.md`)
  does not exist on `origin/main` or any remote branch (confirmed by
  search) — Phase A's own report already flagged this same gap under a
  different branch that was never merged to main with that file. Not
  reproduced here; noted for visibility only, since Findings #12/#13's own
  authority trace above stands on its own regardless.
- `docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`'s
  "Recruitment lifecycle + next action clarity" line (item 6) was not
  edited this round — this task's instructions did not ask for a governing-
  plan sync, and no Codex broad review (the usual trigger for that sync,
  per PR #249's precedent) has run yet this session.
- Findings #4 (parallel sales/offer-selection gameplay), #6 (monthly report
  visual polish), #7 (紹介会社/商流 authority — none currently exists on
  `PublicDemoApplicant`/`Project`, would need a new field if pursued), and
  #10 (interview modal single-screen density) remain unimplemented, per
  this task's own scope (この Phase は #12/#13 のみ).
- No PR was opened this session (not requested by the task). Commits are
  pushed to `claude/recruitment-lifecycle-visibility-qul91k`.

## Current status

All three rounds complete. Original Finding #12/#13 implementation,
round 1's P2 fix, and round 2's (this update's) second P2 fix are all
self-hardened, tested, and pushed to PR #252's branch. Both of PR #252's
Codex review P2 findings are now resolved, each re-verified against the
live PR HEAD before editing rather than assumed from the review comment's
text alone. Codex broad review intentionally **not** re-run in either
follow-up round, per explicit instruction each time — only the already-
posted findings were addressed.

## Next action

Recommend, in order: (1) run the broad review now that both P2 findings on
PR #252 are resolved (still deferred, per explicit instruction across all
three rounds); (2) do **not** manually rerun the in-flight Fast CI #666 run
this session was explicitly told not to touch; (3) if the team wants
Finding #7 (紹介会社/商流) pursued, scope it separately as a schema-adding
task; (4) continue the still-open items from
`docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`.

## Actual elapsed time / Revised ETA

Actual elapsed time, this (second P2-fix) round: **~50min** (re-fetch/
verify PR HEAD and both review threads' current state, re-read
`_interviewDecidedHired`/`ac(i)`'s `interviewed` branch/
`_addApplicantStageCandidate`'s identical branch to independently confirm
the "no legal action" claim, implement, seed-search three real-formula
fixtures — May below-threshold, May above-threshold, June below-threshold
for the month-boundary case — write and pass 5 new tests, re-run the full
required matrix, update this report). Combined with the original
implementation round's ~2h and round 1's P2 fix's ~45min, total elapsed for
Issue #245 Finding #12/#13 end-to-end across all three rounds: **~3h35min**.
No revision to the Issue's own remaining-findings (#4/#6/#7/#10) estimate is
offered here.

## SHAs

- **Base (`origin/main`, explicit, not the repo's default-branch pointer):**
  `b8a58dceb8ccc32d2e45661d46572b55af362b04` (unchanged across all three
  rounds — every round only added commits on top of the same branch).
- **PR #252 HEAD verified before this round's fix (via `pull_request_read`,
  matching local `git fetch`/`git rev-parse` exactly):**
  `b3a03e2401ca8431fbd4531c17384bff4a6ca049` (round 1's final HEAD).
- **Final HEAD (pushed, this round):** recorded in the session's final chat
  answer (a report committed on this branch cannot embed the hash of the
  commit that contains it — same disclosed limitation as PR #244/#249's
  own reports).

## Changed files

Original implementation round:
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `test/ui/public_demo/public_demo_issue245_recruitment_lifecycle_visibility_test.dart`
  (new)
- `docs/reports/screenshots/ses-core-gameplay-phase2-recruitment-seed{A,B}-{360x800,390x844}.png`
  (regenerated side effect)
- `docs/reports/SES_FIRST-FUN-YEAR_Recruitment-Lifecycle-Visibility_Result.md`
  (this report)

Round 1's P2 fix (same two source files):
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` —
  `_applicantLifecycleBucket`'s `closed`/`awaitingJoin` mapping corrected
  for `preEntryPartnerFailed`/`preEntryClientFailed`.
- `test/ui/public_demo/public_demo_issue245_recruitment_lifecycle_visibility_test.dart` —
  +3 fixtures + 7 tests (24 total).

Round 2's P2 fix (this update, same two source files):
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` —
  `_applicantLifecycleBucket` gained one new guarded case:
  `PublicDemoApplicantStage.interviewed when _interviewDecidedHired(a.id)
  && a.interviewScore < 60 => closed`; doc comments on
  `_ApplicantLifecycleBucket` and `_salesApplicantProgressCards` updated to
  match.
- `test/ui/public_demo/public_demo_issue245_recruitment_lifecycle_visibility_test.dart` —
  +3 new fixtures (`_mayWithOneStalledBelowThresholdInterviewedApplicant`,
  `_mayWithOneDecidedHiredAboveThresholdApplicant`,
  `_juneWithOneStalledBelowThresholdApplicantAfterClose`, plus a small
  `_decidedHired` test-local mirror of the production check) + 5 new tests
  (29 total in the file, up from 24). No screenshot file changed this
  round either.

## PR URL

[https://github.com/perusonao/smile_enjoy_story/pull/252](https://github.com/perusonao/smile_enjoy_story/pull/252)
