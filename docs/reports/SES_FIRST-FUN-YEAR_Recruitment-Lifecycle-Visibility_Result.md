# SES FIRST-FUN-YEAR — Recruitment Lifecycle Visibility (Issue #245 Finding #12/#13) — Result Report

## STATUS

**Implemented, self-hardened, tests green.** Presentation-only change on the
existing 営業タブ (Recruitment/Sales surface). No new screen, no save-schema
change, no hiring-decision/authority change. Codex broad review has **not**
been run this session, per the task's explicit instruction ("Broad Reviewは
まだ実施しないでください").

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
classifier:

- **`closed`**: `rejected`, `offerDeclined`, `preEntryPartnerFailed`,
  `preEntryClientFailed` — the exact same 4-value set
  `_applicantStatusTone` already calls "negative" (a final, unsuccessful
  outcome).
- **`awaitingJoin`**: `juneOrdered`, and `offerAccepted` when
  `!canEnterPreJoinSales` (an inexperienced hire waiting for the normal
  monthly join boundary) — both cases where `ac(i)` renders **no button at
  all**, but the outcome is not unsuccessful.
- **`active`**: everything else — every stage where `ac(i)` renders an
  actionable button (`applied`/`resumeReviewed`/`interviewed`/
  `offerAccepted`&&experienced/`preEntrySkillSheet`/`preEntrySelling`/
  `preEntryIntroduced`/`preEntryPartnerPassed`/`preEntryClientPassed`).

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

- `flutter analyze`: **No issues found.**
- New file:
  `test/ui/public_demo/public_demo_issue245_recruitment_lifecycle_visibility_test.dart`
  (**17 tests**) — active-only grouping, closed-only grouping (via a
  genuinely rejected applicant driven through the real production
  `completeInterview` → interactive interview session →
  `concludeInterviewSession(InterviewOutcome.rejected)` path, never a
  fabricated stage), active+awaitingJoin coexistence (via the real
  production pre-entry-sales chain up to `recordJuneOrder`, deliberately
  stopping short of `closeMay` so the applicant is genuinely `juneOrdered`
  but not yet joined), reading-order check, the joined-summary line's exact
  text and its absence before any join and its non-fabrication ("no 0名"),
  a joined+still-active coexistence case, a save/reload (`toJson`/
  `fromJson`) round-trip preserving the same grouping, a double-tap/
  duplicate-action smoke test, and 8 360×800/390×844 × TextScaler 1.0/1.3
  overflow checks. All fixtures are built by chaining real
  `PublicDemoAggregate` commands (`recruit`/`completeInterview`/interactive
  interview session/`acceptOffer`/pre-entry-sales chain/`recordJuneOrder`/
  `closeMay`) — the same technique this suite's neighboring test files
  (`public_demo_sales_ui_phase1_test.dart`,
  `public_demo_issue248_applicant_engineer_continuity_test.dart`) already
  use. No applicant/stage is ever constructed directly.
- `flutter test test/game/public_demo`: **889 passed**, 0 failed (fully
  pre-existing — no game-layer file was touched by this change; run to
  confirm zero regression).
- `flutter test test/ui/public_demo`: **729 passed**, 0 failed (712
  pre-existing + 17 new from this Phase). Re-run in full after the new test
  file was added.
- `git diff --check`: clean.
- Manually re-derived the exact bucket mapping against `ac(i)`'s own
  per-stage button branches line-by-line (see the Fresh Audit table above)
  to confirm the grouping can never disagree with the card content it
  groups.

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
  real production commands in the new test file, not fabricated.

## Unresolved items / follow-ups

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

Implementation complete, self-hardened (own re-derivation of the bucket
mapping against every `ac(i)` branch; re-ran the full required test/lint
matrix after the new test file was added), all required checks green,
committed and pushed to the designated branch. Codex/Claude broad review
intentionally **not** run this session per explicit instruction.

## Next action

Recommend, in order: (1) get a broad review (Codex or equivalent) on this
diff before it lands, since the task explicitly deferred it rather than
skipped it permanently; (2) if the team wants Finding #7 (紹介会社/商流)
pursued, scope it separately as a schema-adding task (today's `Project`/
`PublicDemoApplicant` genuinely carry no referral-source field — showing
one would be fabrication); (3) continue the still-open items from
`docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`.

## Actual elapsed time / Revised ETA

Actual elapsed time this session: **~2h** (Fresh Audit + implementation +
new 17-test suite + full required test/lint matrix, run twice). The
Issue's own estimate for the *overall* Fresh Audit phase was 45–90 minutes
for audit alone (13 findings); this single-Phase implementation for 2 of
those 13 findings fits inside that same order of magnitude. No revision to
the Issue's own remaining-findings estimate is offered here — out of this
Phase's scope.

## SHAs

- **Base (`origin/main`, explicit, not the repo's default-branch pointer):**
  `b8a58dceb8ccc32d2e45661d46572b55af362b04`
- **Final HEAD (pushed):** recorded in the session's final chat answer (a
  report committed on this branch cannot embed the hash of the commit that
  contains it — same disclosed limitation as PR #244/#249's own reports).

## Changed files

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (+117/-4)
- `test/ui/public_demo/public_demo_issue245_recruitment_lifecycle_visibility_test.dart`
  (new, 445 lines)
- `docs/reports/screenshots/ses-core-gameplay-phase2-recruitment-seed{A,B}-{360x800,390x844}.png`
  (regenerated side effect, see "Screenshots regenerated" above)
- `docs/reports/SES_FIRST-FUN-YEAR_Recruitment-Lifecycle-Visibility_Result.md`
  (this report)

## PR URL

Not created — not requested this session.
