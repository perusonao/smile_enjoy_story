# SES First Fun Quarter — Mission Phase 4: Recruitment Missions + Document Screening — Result Report

Status: **COMPLETE — implemented, tested, self-reviewed**

## Base

- `origin/main` at session start: `7c5b663d9c6e388e81d1e2696d8dde0db335ca44` (PR #267 merge commit, Mission Phase 3) — fetched explicitly (`git fetch origin main`), not read from the repository's default branch (which currently points at a stale `claude/ses-game-core-phase-0-h7e8om` ref) — exact match to the task's stated expected SHA, no drift.
- PR #267 confirmed `merged: true` via the GitHub API before starting.
- Working branch: `claude/ses-phase4-document-screening-ir36n1`, created fresh from `origin/main`.

## Fast CI #705 (CI Gate)

- `main` Fast CI #705 (the PR #267 merge commit's own CI run) was **`in_progress`** at Fresh Audit start. Per task instruction, proceeded with Fresh Audit only; production implementation did not begin until #705 resolved.
- `replay-unit` job: `success`. `validate` job (`flutter analyze` + `flutter test` + web build): `success`.
- Result: **run `success`, both jobs green** — implementation began only after this was confirmed.

## Fresh Audit

Read-only audit against `origin/main` @ `7c5b663d`, before any implementation. Numbered per the task's own 20-point checklist.

1. **Recruitment media start** — `PublicDemoAggregate.recruit(medium)` (`public_demo_aggregate.dart`), gated by `!state.isFinanciallyRestricted`, once/month via `PublicDemoRecruitmentCalculation`. UI entry: Sales tab "求人媒体を選ぶ" card, visible `s.month >= 5` (`_recruitmentMediaCardVisible`), though domain itself allows April onward (`PublicDemoState.isRecruitmentMediaWindowMonth`, April–August).
2. **Applicant generation** — `PublicDemoSeededRecruitmentGenerator` via `PublicDemoRecruitmentCalculation.execute`; generated applicants start at `PublicDemoApplicantStage.applied`.
3. **Applicant persistence** — `PublicDemoApplicant.toJson`/`fromJson` (`public_demo_recruitment.dart`); no schema-version dependency, every field has an explicit reader; unforgeable records (`bindingOffer`, `interviewRecordApplicantId`, `joinRecordApplicantId`) round-trip by id, with an identity cross-check (`interviewId != id` throws).
4. **Applicant status/state machine** — `PublicDemoApplicantStage` (14 values: `applied, resumeReviewed, interviewed, rejected, offerAccepted, offerDeclined, preEntrySkillSheet, preEntrySelling, preEntryIntroduced, preEntryPartnerPassed, preEntryPartnerFailed, preEntryClientPassed, preEntryClientFailed, juneOrdered`). **`rejected` already exists on the enum** (has existed "since WORKFLOW-STATE-1" per its own code comment) and is already wired to one production command, `PublicDemoWorkflowState.rejectApplicant` — but that command's precondition (`from: {interviewed}`) currently only reaches it from the *post*-interview interactive-interview "見送る" outcome (`PublicDemoAggregate.concludeInterviewSession`). There is **no existing production path to `rejected` from `resumeReviewed`** (pre-interview) — this is Required Feature A's actual gap, not a missing enum value.
5. **SkillSheet display (applicant)** — `PublicDemoCandidateSkillSheetSheet.show(context, applicant:)`, opened atomically together with the `applied → resumeReviewed` transition by `_reviewResumeAndOpenSkillSheet` (the sole production path off `applied`). Unrelated to and unaffected by this phase (no changes to this file).
6. **Interview start condition** — `PublicDemoAggregate.startInterviewSession` requires `applicant.hasBeenInterviewed` (the unforgeable paperwork-interview record minted by `completeInterview`) and no existing session; genuinely gated, not stage-alone.
7. **Interview result** — `PublicDemoAggregate.concludeInterviewSession(applicantId, outcome)`, requires the session to be `conversationComplete`; `InterviewOutcome.hired` marks `qaEvaluationApplies`; `InterviewOutcome.rejected` calls `workflow.rejectApplicant` in the same commit.
8. **Reject authority** — `PublicDemoWorkflowState.rejectApplicant` → `_transitionApplicantStage(from: {interviewed}, to: rejected)`, itself gated on `!applicant.hasJoined`. **Gap found**: (a) the `from` set does not include `resumeReviewed`, so a pre-interview "見送る" has no production entry point; (b) a rejected-pre-interview applicant would still pass `PublicDemoAggregate.completeInterview`'s only guard (`!applicant.hasBeenInterviewed`, which is still `false` for a never-interviewed rejectee) and consume a real sales slot to re-enter `interviewed` — `PublicDemoApplicant.completeInterview` itself has no stage precondition, only an idempotency check. Both are fixed in this phase (see "Document-screening authority" below); the existing post-interview-only path and its `!hasJoined`/`hasBindingOffer` protections are otherwise reused verbatim.
9. **Hire authority** — no separate "hire" command exists; the domain-observable "hire decision" fact is `PublicDemoApplicant.hasBindingOffer`, minted only by `PublicDemoOfferAcceptance.accept` when `offer.accepted`. This already refuses `applicant.stage == rejected` explicitly (`WORKFLOW-STATE-1... §built-in guard`) and separately requires `hasBeenInterviewed` — so once Required Feature A widens the reject path, a document-rejected applicant is *already* doubly blocked from ever obtaining a binding offer, no new guard needed here.
10. **Offer/accept authority** — `PublicDemoOfferAcceptance.accept` (`public_demo_binding_offer.dart`): idempotent (`alreadyDecided` if `bindingOffer != null`), requires `hasBeenInterviewed`, refuses `stage == rejected`, mints `PublicDemoBindingOffer` only on `offer.accepted`.
11. **入社 (join) timing** — `PublicDemoApplicant.join` requires `!hasJoined`, `stage != offerDeclined`, a `bindingOffer` whose `applicantId`/`fiscalCloseId` match; called via `PublicDemoJoinTransaction.join`, invoked at month close (`joinAndKeepOnly` — May-only cohort cutoff — and `joinAcceptedForFiscalClose` — every month-close from June on, no pruning). A rejected applicant can never carry a `bindingOffer` (per #9/#10), so `join` is already unreachable for them without any new guard.
12. **Applicant → engineer conversion** — out of this phase's touched-file set entirely; not read or modified. Existing `public_demo_issue248_applicant_engineer_continuity_test.dart` covers it and is run as part of this phase's regression pass.
13. **SkillSheet preservation** — same: no touched file overlaps the applicant→engineer SkillSheet-carryover path. Verified unaffected by running the full `test/game/public_demo` + `test/ui/public_demo` suites after implementation, not by code inspection alone.
14. **Salary authority** — `PublicDemoSalaryOfferEvaluator`/`PublicDemoOfferAcceptance` unchanged; a document-screening reject happens strictly before any salary offer is ever evaluated for that applicant (offer requires `hasBeenInterviewed`), so there is no salary-authority interaction to guard.
15. **Recruitment cost authority** — `PublicDemoRecruitmentCalculation` charges once, at the `recruit()` call, independent of any individual applicant's later fate. The domain has **no refund mechanic of any kind** today (rejecting, at any stage, has never refunded anything) — Required Feature A's "recruitment cost refund無し" is satisfied by *not adding* a refund path, not by adding a new guard.
16. **Month boundary** — `joinAndKeepOnly` (May→June only) prunes the applicant list down to `applicantIds` (those who reach June with an accepted-and-fiscal-close-matching offer); a rejected applicant (whether rejected before or after interview) is not in that set and is dropped from the roster at that one cutover, identically to today's post-interview-reject behavior — pre-existing, unrelated to this phase's own scope, not a new interaction. `joinAcceptedForFiscalClose` (every June-onward close) never prunes and never resets `stage` — a June+ -recruited, document-rejected applicant remains visible, permanently `rejected`, for the rest of the playthrough. No stage is ever reset back off `rejected` by any month-close path — confirmed by reading every call site of `PublicDemoWorkflowState.applicants` mutation in `public_demo_aggregate.dart`'s month-close methods; none touches `stage` for an already-decided applicant.
17. **Duplicate action prevention** — `_transitionApplicantStage`'s `from.contains(applicant.stage)` check makes every transition (including the widened `rejectApplicant`) naturally idempotent: a second `rejectApplicant` call on an already-`rejected` applicant finds `rejected ∉ from`, changes nothing (same pattern every other stage transition in this file already relies on — not a new mechanism).
18. **Mission resolver** — `PublicDemoMissionResolver`/`public_demo_mission_resolver.dart` is Public Demo's one established "derive Mission progress from existing authority, no BuildContext, no mutation" resolver, already carrying the April 8-step chain (`publicDemoAprilMissionChain`). This phase adds a second, independent chain (`publicDemoRecruitmentMissionChain`) in the same file, sharing the same `PublicDemoMissionId`/`PublicDemoMissionStatus`/`PublicDemoMissionStatusEntry` types rather than inventing a parallel type hierarchy — see "Mission design" below.
19. **Domain-derived recruitment facts available today** — `workflow.applicants.isNotEmpty` (media used at least once), `applicant.stage != applied` (SkillSheet reviewed), a stage-set membership test for "screened" (moved past `resumeReviewed` in either direction), `applicant.hasBeenInterviewed` (interview genuinely happened), `applicant.hasBindingOffer` (hire decided), `applicant.hasJoined` (joined) — every fact the Recruitment Mission chain needs already exists and is already save-durable; nothing new needs to be computed or persisted.
20. **Legacy save** — no field this phase touches is new. `PublicDemoApplicantStage.rejected` has been a valid enum value (and thus a valid save value) since before this session; widening which production command can *produce* it does not change what a save containing it decodes to. `_hasConsistentAuthorityFacts` (`public_demo_save_codec.dart`) has **no applicant-specific cross-check at all** (grepped confirmed) — a `rejected`-stage applicant with no `interviewRecordApplicantId` (the new, pre-interview-reject shape) decodes exactly as cleanly as today's post-interview-reject shape. **No schema bump, no new field, no new codec test category** — a `flutter test test/game/public_demo/public_demo_save_codec_test.dart` regression run after implementation is the sufficient legacy check.

### "面接前のreject" — can the existing domain model express it safely?

**Yes, with two additive fixes, no new state:**

1. Widen `PublicDemoWorkflowState.rejectApplicant`'s precondition from `{interviewed}` to `{resumeReviewed, interviewed}`. Every existing downstream guard (`hasBeenInterviewed`-gated offer, `!hasJoined`-gated join, the idempotent `_transitionApplicantStage` re-entry check) already treats `rejected` as fully terminal regardless of which stage it was reached from — none of them special-case "how did we get here."
2. Close the one real gap this widening would otherwise open: `PublicDemoAggregate.completeInterview` only ever checked `hasBeenInterviewed` (true only *after* a genuine interview) before consuming a real sales slot and minting `interviewed` — it never checked the applicant's current `stage`. A pre-interview-rejected applicant has `hasBeenInterviewed == false` (they were never interviewed), so without a fix they could still be walked through `completeInterview` — consuming a real slot to "un-reject" them into `interviewed`. Fixed by adding an explicit `stage == rejected` short-circuit **before** the sales-slot consumption (both in `PublicDemoAggregate.completeInterview`, so no slot is ever spent on the no-op, and defense-in-depth in `PublicDemoApplicant.completeInterview` itself, mirroring this codebase's established "guard at both the aggregate boundary and the model" convention used everywhere else in this file).

No new enum value, no new field, no schema change.

## Document-screening authority (Required Feature A)

| File | Change |
|---|---|
| `lib/game/public_demo/public_demo_workflow_state.dart` | `rejectApplicant`'s `from` set widened to `{resumeReviewed, interviewed}`. Doc comment updated. |
| `lib/game/public_demo/public_demo_recruitment.dart` | `PublicDemoApplicant.completeInterview` also short-circuits on `stage == rejected` (defense-in-depth). |
| `lib/game/public_demo/public_demo_aggregate.dart` | New `rejectApplicant(applicantId)` passthrough (mirrors `reviewResume`'s own shape). `completeInterview` gains an explicit `stage == rejected` check before slot consumption, returning a new `PublicDemoInterviewCompletionStatus.rejected` (no behavior change to any other status; no exhaustive `switch` over this enum exists elsewhere in the codebase, confirmed by grep). |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | Applicant card (`ac(i)`) gains a "見送る" `OutlinedButton` alongside the existing "採用面談" `FilledButton`, shown only at `PublicDemoApplicantStage.resumeReviewed`. Calls a new `_rejectApplicant(applicantId)` wrapper → `_game.rejectApplicant(id)` → `_commitAggregate`. No confirmation dialog (matches this screen's existing no-confirmation convention for every other stage-transition button). |

Every requirement from the task's Required Feature A checklist is satisfied by existing, already-tested authority plus the two additive guards above — restated:

- reject is a domain action (`PublicDemoWorkflowState.rejectApplicant`, not a UI-only flag) — ✓ pre-existing shape, only the precondition widened.
- not UI-only — ✓ same.
- survives save/reload — ✓ `stage` already round-trips; no applicant-specific save validation to update.
- reject blocks interview — ✓ new `completeInterview` stage guard.
- reject blocks hire — ✓ already enforced by `PublicDemoOfferAcceptance.accept`'s existing `stage == rejected` check, for both reject sources.
- no double-reject — ✓ `_transitionApplicantStage`'s existing `from.contains` idempotency.
- no recruitment-cost refund — ✓ no refund mechanic exists anywhere in the domain; not adding one.
- no revival at month boundary — ✓ confirmed no month-close path resets `stage` off `rejected`.

## Mission design (Required Feature B)

A second, independent chain in the same resolver file — `publicDemoRecruitmentMissionChain` — reusing `PublicDemoMissionId`/`PublicDemoMissionStatus`/`PublicDemoMissionStatusEntry` rather than a parallel type. New `PublicDemoMissionId` values: `postRecruitmentMedium`, `viewApplicantSkillSheet`, `screenApplicantResume`, `conductHiringInterview`, `decideHiring`, `applicantJoined` — none collide with the April chain's 8 existing ids, and the April chain (`publicDemoAprilMissionChain`) itself is untouched (per the task's own "Aprilの8 Missionを無理に巨大化させない").

| Mission | Completion signal (already-existing authority) |
|---|---|
| 求人媒体を利用する | `workflow.applicants.isNotEmpty` |
| 応募者のSkillSheetを確認する | any applicant `stage != applied` (the atomic `_reviewResumeAndOpenSkillSheet` is the only production path off `applied`) |
| 書類選考する | any applicant has left `{applied, resumeReviewed}` for any later stage — **true whether that applicant was advanced to interview or rejected pre-interview**, matching the task's explicit "面接へ進める または見送る のどちらでも screening action として成立" |
| 面接する | any applicant `hasBeenInterviewed` (unforgeable record — only true if the interview route was actually taken) |
| 採用を決める | any applicant `hasBindingOffer` (only true if an offer was actually extended and accepted) |
| 入社する | any applicant `hasJoined` |

Locked/available/completed banding reuses the April chain's own linear rule (`available` once the previous step is `completed`) via a small shared private helper, factored out of `resolve`/`resolveRecruitment` to avoid duplicating the loop.

**Start condition**: the chain is resolved and shown only once `state.month >= 5` — the same threshold the Sales tab's own 求人媒体 card already uses (`_recruitmentMediaCardVisible`), i.e. "the moment the player could actually see this chain's first step" rather than an arbitrary new constant. Below month 5 the caller passes an empty list and the Mission screen shows nothing for it (falls back to the existing April-complete placeholder).

**Mission screen**: `PublicDemoMissionScreen` gains an optional `recruitmentMissions` param; `_MissionTile` is generalized to take its copy map entry as a parameter (was a hardcoded `publicDemoAprilMissionCopy` lookup) so both chains render through the same tile widget. When `recruitmentMissions` is non-empty it renders as a second section below the April chain (own header, own progress line); the existing "次の経営目標は今後解放されます" placeholder is shown only when the April chain is complete AND there is nothing else (still month 4) to show — i.e. this phase's own chain is exactly the content that placeholder always promised.

No new persisted field: every signal above is already read by existing code elsewhere in the codebase.

## Persistence / atomicity

No schema-version bump; no new save field. The only atomicity-sensitive change is `completeInterview`'s new `rejected` short-circuit, which is placed **before** `state.useSalesSlotForInterview()` — a rejected applicant's no-op interview attempt never consumes a sales slot, consistent with every other no-op branch in that method (`unknownApplicant`, `alreadyInterviewed`) already returning before any mutation.

## Changed files

Production (`lib/`):

- `lib/game/public_demo/public_demo_workflow_state.dart` — `rejectApplicant`'s `from` set widened to `{resumeReviewed, interviewed}`.
- `lib/game/public_demo/public_demo_recruitment.dart` — `PublicDemoApplicant.completeInterview` defense-in-depth `stage == rejected` guard.
- `lib/game/public_demo/public_demo_aggregate.dart` — new `rejectApplicant(applicantId)` passthrough; `completeInterview` pre-slot-consumption `stage == rejected` guard + new `PublicDemoInterviewCompletionStatus.rejected`.
- `lib/game/public_demo/public_demo_mission_resolver.dart` — new `PublicDemoMissionId` values (`postRecruitmentMedium`, `viewApplicantSkillSheet`, `screenApplicantResume`, `conductHiringInterview`, `decideHiring`, `applicantJoined`), `publicDemoRecruitmentMissionChain`, `PublicDemoMissionResolver.resolveRecruitment`, shared `_band` helper (refactored out of `resolve`), `_hasScreened` exhaustive switch.
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — `_rejectApplicant` wrapper + "見送る" `OutlinedButton` on the `resumeReviewed` applicant card; `_recruitmentMissions` getter (`month >= 5` gate); `_openMissionScreen`/`_missionBadgeVisible` updated for the second chain; **two independently-tracked** badge-acknowledgement indices (`_missionBadgeAcknowledgedIndex`, new `_recruitmentMissionBadgeAcknowledgedIndex`) rather than one combined index — see Self-hardening below.
- `lib/ui/public_demo/public_demo_mission_screen.dart` — `publicDemoRecruitmentMissionCopy`; `PublicDemoMissionScreen.recruitmentMissions` param; `_RecruitmentMissionHeader`; `_MissionTile` generalized to take `copy` as a parameter instead of a hardcoded lookup.

Docs:

- `docs/reports/SES_FIRST-FUN-QUARTER_MISSION-PHASE4_Result.md` (this file, new).
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — Update history entry (Current execution order/Prioritized backlog left unchanged, per Phase 1–3 precedent).
- `docs/design/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md` — §7 marked COMPLETE with a "Superseded at implementation time" block for the two deviations from its original text.

Tests (`test/`):

- `test/game/public_demo/public_demo_aggregate_test.dart` — new group "document-screening reject (rejectApplicant, pre-interview)": reachable from `resumeReviewed`, no-op from `applied`, double-reject idempotency, `completeInterview` refusal + zero slot consumption, offer-acceptance refusal, no cost refund, save/reload round-trip, A/B isolation, month-boundary non-revival.
- `test/game/public_demo/public_demo_mission_resolver_test.dart` — new "recruitment chain" groups: fresh-start locked/available boundaries, document-screening (見送る) route reaching `screenApplicantResume` without `conductHiringInterview`/`decideHiring`/`applicantJoined`, interview route, decide-hiring/join (via `acceptTestOffer`/`PublicDemoJoinTransaction`), save/reload with no new field.
- `test/ui/public_demo/public_demo_document_screening_reject_test.dart` (new) — the "見送る" button's presence/absence by stage, a real tap committing the reject and clearing all CTAs, 360×800/390×844 × TextScaler 1.0/1.3 overflow matrix.
- `test/ui/public_demo/public_demo_mission_screen_test.dart` — new "Recruitment Mission section" group (hidden when empty, shown alongside/independent of the April chain), widened overflow matrix to include the Recruitment section.
- `test/ui/public_demo/public_demo_mission_appbar_entry_test.dart` — new regression test pinning the independent-badge-acknowledgement fix (see Self-hardening).

## Tests

- `flutter analyze` (whole project): **No issues found.**
- `flutter test test/game/public_demo` + `flutter test test/ui/public_demo` (full suites, run together twice — once before, once after the self-hardening badge fix): **1904 tests, all passed** both times.
- Main-game regression (no shared file touched, verified anyway): `test/ui/fit_reason_widget_test.dart`, `test/game/matching_test.dart`, `test/presentation`, `test/domain`. One pre-existing failure, `test/presentation/home/home_dashboard_data_wiring_test.dart` ("the month-end CTA stays disabled even with real dashboard data") — confirmed **present on a clean `origin/main` checkout with none of this phase's changes applied** (`git stash` + re-run), i.e. a pre-existing sandbox-environment issue unrelated to this phase (this phase touches no `lib/presentation` or main-game HOME file at all). Every other main-game regression test passed.
- `git diff --check`: clean.
- Focused new/updated test files listed above.
- Two accidental, environment-only artifacts were found and reverted before committing, neither related to this phase's work: `pubspec.lock` drift from this sandbox's own package-resolution cache (Dart SDK/registry-state differences, not a dependency this phase added or changed), and 4 PNGs under `docs/reports/screenshots/` that `public_demo_seeded_recruitment_visual_test.dart` rewrites as a side effect of running it locally (a snapshot-capture test, not a golden-diff one) — confirmed via `git restore` back to their `origin/main` committed state.

## Self-hardening

One Claude Broad Self Review pass, focused on: save authority, state transition, Mission false-positive, duplicate action, month boundary, rejected-applicant resurrection, A/B contamination, applicant→engineer, legacy, overflow.

**P1 found and fixed in this session:**

- **Mission badge false-negative across the two independent chains.** The initial implementation tracked Mission-badge acknowledgement as one index over `[...aprilMissions, ...recruitmentMissions]` concatenated. Because `PublicDemoMissionFrontIndex` returns the position of the first non-`completed` entry, and the April chain always precedes the Recruitment chain in that concatenation, the combined front index can never advance past whatever position the April chain's own front sits at *until April is fully complete* — meaning any amount of genuine, live Recruitment-chain progress (求人媒体 used, SkillSheet reviewed, screened, interviewed, hired, joined) would silently fail to re-show the badge for as long as the April chain remained incomplete (e.g. a slow-progression playthrough where a founding engineer isn't assigned until well past May). Fixed by tracking each chain's own front index independently (`_missionBadgeAcknowledgedIndex` for April, new `_recruitmentMissionBadgeAcknowledgedIndex` for Recruitment) and showing the badge if *either* has moved past what was last acknowledged. Regression-pinned in `public_demo_mission_appbar_entry_test.dart` (April deliberately left stuck at its own front 0 throughout; a live "見送る" tap advances only the Recruitment chain; the badge is asserted to reappear — which fails under the old combined-index scheme and passes under the fix).

**No other P0/P1 findings.** Reviewed and confirmed correct, no change needed:

- **Save authority / legacy** — no new persisted field anywhere in this phase; `_hasConsistentAuthorityFacts` has no applicant-stage cross-check to update; confirmed via a hand-rolled save/reload test using the real `PublicDemoSaveCodec`.
- **State transition / duplicate action** — `rejectApplicant`'s widened precondition reuses the exact same `_transitionApplicantStage`/`from.contains` idempotency every other transition in this file already relies on; no new mechanism introduced.
- **Mission false-positive** — every Recruitment Mission signal reads an unforgeable fact (`hasBeenInterviewed`, `hasBindingOffer`, `hasJoined`) or a fact whose only production path is atomic with what it claims (`stage != applied` ⇔ SkillSheet was shown, confirmed by grep: `reviewResume` has exactly one caller, `_reviewResumeAndOpenSkillSheet`) — mirroring the April chain's own established discipline (Fresh Audit §3's `passClientInterview` precedent).
- **Month boundary / rejected-applicant resurrection** — confirmed by reading every `PublicDemoWorkflowState.applicants` mutation site reachable from a month-close command; none resets `stage` for an already-decided applicant. Test-pinned directly (aggregate test's month-boundary case) rather than only reasoned about.
- **A/B contamination** — `_withApplicant`/`_transitionApplicantStage` operate per-id via a list `map`; test-pinned directly (aggregate test's A/B isolation case).
- **applicant→engineer / SkillSheet preservation** — no touched file overlaps this path; verified by running the full pre-existing suite (`public_demo_issue248_applicant_engineer_continuity_test.dart` et al.) alongside the new tests, not by inspection alone.
- **Overflow** — 360×800/390×844 × TextScaler 1.0/1.3 matrices added for both the new reject button (on the existing applicant card) and the Mission screen's new Recruitment section (extended the pre-existing April-chain overflow matrix to include it).

## Unresolved / Known Issues

- **Pre-existing, unrelated test failure**: `test/presentation/home/home_dashboard_data_wiring_test.dart`'s "the month-end CTA stays disabled even with real dashboard data" fails in this sandbox on a clean `origin/main` checkout too (confirmed via `git stash`), i.e. before any of this phase's changes. Not investigated further — out of this phase's scope (main-game HOME/presentation layer, not Public Demo) and the task's own E2E policy treats a viewport/CI-environment-specific test issue as non-blocking for gameplay development.
- **Recruitment Mission chain does not carry its own "履歴" screen** — per Fresh Audit finding, the existing Sales-tab applicant list already shows a document-rejected (or any-stage-rejected) applicant with the pre-existing "不採用" badge indefinitely for any June-onward-recruited applicant (never pruned by any month-close path); only the original April/May founding cohort is pruned at the one-time May→June cutover (`joinAndKeepOnly`), identically for a pre-existing post-interview reject as for this phase's new pre-interview reject. No new history UI was built, per the task's own "現行UIを確認して判断" instruction — the existing list already serves this need.
- **Out of scope, confirmed untouched**: new recruitment media, referral hiring, SNS hiring, staffing agencies, recruitment PR, Applicant SkillSheet editing, trust penalty, interview-conversation overhaul, HOME redesign, Bottom Nav changes, image asset overhaul, Training Phase 1b — none of this phase's diff touches any of these.

## Git / PR

- Working branch: `claude/ses-phase4-document-screening-ir36n1`
- Final HEAD SHA: `7c3d997eea2355a6efdaf441c2fc81fd29d671c2`
- PR: [perusonao/smile_enjoy_story#268](https://github.com/perusonao/smile_enjoy_story/pull/268) → `main`

## FINAL VERDICT

**Ship.** Both required features (Document Screening, Recruitment Mission) are implemented as genuine domain actions/derived facts, reusing 100% of the existing `PublicDemoApplicantStage` enum and applicant authority — no new persisted field, no schema bump. `flutter analyze` clean; the full `test/game/public_demo` + `test/ui/public_demo` suites (1904 tests) pass; `git diff --check` clean; one Claude Broad Self Review pass found and fixed one real P1 (Mission badge false-negative across independent chains), regression-pinned. The one main-game test failure encountered is pre-existing on `origin/main` and unrelated to this phase's files.
