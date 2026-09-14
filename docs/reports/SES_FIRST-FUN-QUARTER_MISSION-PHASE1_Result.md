# SES First Fun Quarter — Mission System Phase 1 (April Main Mission) — Implementation Result

## Scope

Implements Phase 1 of
`docs/design/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md`
§3 (the Mission System foundation and the April headline mission), per the
task's own instruction. Both design documents this task references —

- `docs/reports/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Fresh-Audit.md`
- `docs/design/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md`

— were read in full before implementation and are added to the repository
verbatim by this same PR (byte-identical to the user-supplied versions,
diffed to confirm before adding).

**Explicitly out of scope** (per the task's own instruction, and per the
Implementation Plan's own phase split): SkillSheet editing, training
missions, recruitment missions, document screening, pre-entry sales
missions, accounting/bonus missions, Opening Context conversational
redesign, SkillSheet English-label fix, "実力" label change, character/event
image changes, HOME body layout changes, Bottom Navigation changes. None of
these were touched.

## Base main SHA

The working branch (`claude/mission-system-phase1-2yp09r`) was found
pointing at a stale ancestor commit (`f4ca78f`, "Phase 0A/0B: SES domain
models and random generators") far behind `origin/main` — the same
stale-branch symptom recorded in prior sessions' Result reports (e.g.
`SES_TEST-STRATEGY-1_CI-Optimization_Result.md`). `git fetch origin main`
confirmed `origin/main` had advanced to a fully-merged history with no
divergent commits from the stale branch tip
(`git merge-base --is-ancestor f4ca78f origin/main` → yes), so the branch
was reset to `origin/main`'s tip with no discarded work
(`git checkout -B claude/mission-system-phase1-2yp09r origin/main`).

`origin/main` SHA at session start: **`dfb272619b92219853203a2f72eba4c785c0f66f`**
(matches the Fresh Audit's own audited SHA — `origin/main` had not advanced
further since that audit).

## Implemented missions (April chain, per Fresh Audit §5)

| # | Mission | `PublicDemoMissionId` | Completion signal (Fresh Audit §3 citation) |
|---|---|---|---|
| 1 | 技術者のSkillSheetを確認する | `viewSkillSheet` | any engineer's `stage != waiting` |
| 3 | 技術者の営業を行う | `beginSelling` | any engineer's stage reached `selling` or later (exhaustive switch) |
| 4 | 技術者を案件に提案する | `proposeToProject` | any engineer's stage reached `introduced` or later (exhaustive switch) |
| 5 | 上位会社面談を通過する | `passPartnerInterview` | any engineer's stage reached `partnerInterviewPassed` or later — NOT `partnerInterviewFailed` alone (exhaustive switch) |
| 6 | 客先面談を通過する | `passClientInterview` | any engineer's `hasGenuineInterviewRecord` — the one unforgeable record, never bare stage |
| 7 | 案件を受注する | `winOrder` | any engineer's `stage == ordered` |
| 8 | 技術者を案件に参画させる（headline） | `assignToProject` | `workflow.assignedEngineerIds(month: state.month).isNotEmpty` — the same SSOT Revenue/roster/HOME already agree on, read with the resolver's OWN current month, never a captured one |

Mission 22 (売上が発生する, Fresh Audit §2.3) was **not** implemented as a
separate mission — its causal explanation ("参画すると売上が発生します。
ただし、入金は後になります。") is folded into Mission 8's own
`assignToProject` completion copy, and repeated in the MISSION COMPLETE
banner shown when the whole chain finishes, exactly as the task and the
Implementation Plan instruct.

## Authority mapping (design discipline followed)

- `lib/game/public_demo/public_demo_mission_resolver.dart` is a pure
  function file (`PublicDemoMissionResolver.resolve`), mirroring
  `PublicDemoEmployeeStatusResolver`'s own convention: no `BuildContext`, no
  `PublicDemoAggregate` mutation, no new domain enum/field. It takes
  `PublicDemoWorkflowState`/`PublicDemoState` and returns
  `List<PublicDemoMissionStatusEntry>`.
- Every "has this engineer reached at least stage X" check is an explicit
  exhaustive `switch` over all 9 `PublicDemoSalesStage` values — never
  `.index` comparison (the enum interleaves `partnerInterviewFailed`/
  `clientInterviewFailed` with their "Passed" counterparts, so declaration
  order is not pipeline-progress order).
- `passClientInterview` reads `PublicDemoEngineerSales
  .hasGenuineInterviewRecord` — the one unforgeable record the domain
  itself already refuses to trust bare stage for (Fresh Audit §3 row 6).
- `assignToProject` reads `PublicDemoWorkflowState.assignedEngineerIds`
  with `state.month` at call time — never a stale/captured month (Fresh
  Audit §10.6).
- Locked/available/completed banding is a simple linear gate on top of the
  domain's own real gates (Implementation Plan §3.3): `available` the
  moment the previous chain step is `completed`, `completed` per the
  authority checks above, `locked` otherwise. This is advisory UI state
  only — the resolver never disables a real domain action (SkillSheet
  gate, sales-slot budget, etc. are all unchanged and independently
  enforced exactly as before).
- Company-level, not per-engineer: each mission collapses "does ANY
  engineer/founder satisfy this" to one status (task's own framing:
  "技術者1名を案件に参画させる" is a single company goal). Each
  `PublicDemoMissionStatusEntry` still carries an `engineerId` naming the
  first engineer whose state satisfies a `completed` mission — design
  headroom for a future per-engineer view, per the task's explicit request,
  without a schema change.

## Save compatibility

**No new persisted field of any kind, and `PublicDemoSaveCodec
.schemaVersion` is unchanged (still `1`).** Mission progress is 100%
derived from state the save codec already serializes. Verified directly:
a test round-trips a genuinely `ordered`+assigned engineer's aggregate
through the REAL `PublicDemoSaveCodec.encode`/`decode` (not a
reconstruction shortcut) and confirms every prerequisite mission (1, 3–8)
shows `completed` on the very first resolve after decode — no re-play
required, matching Fresh Audit §10.5's retroactive-detection design goal.

## Mission Entry Point / Screen

- `lib/ui/public_demo/public_demo_mission_screen.dart` (new): a read-only,
  full-route (`Navigator.push`) screen — April headline header with
  progress `N / 7`, the 7-step chain each showing 目的/次の操作/ひより's
  comment per its current status, and a `MISSION COMPLETE` banner replacing
  the header once the whole chain is `completed`, plus a
  "次の経営目標は今後解放されます。" placeholder line (no Phase-1-out-of-scope
  mission invented).
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`: minimal,
  additive diff only — one new `AppBar.actions` `IconButton` (key
  `public-demo-app-bar-mission`) next to the existing 🔔 notifications
  button, and one new private method (`_openMissionScreen`) that resolves
  fresh against the currently-committed aggregate and pushes the Mission
  screen. **HOME Freeze interpretation**: per Fresh Audit §9 Option E / §11
  risk 2, the `AppBar` is Scaffold-level chrome shared across every tab,
  not HOME's own content area — this button is visible on every tab (not
  just HOME), confirmed by a dedicated widget test, and HOME's own body/KPI
  card layout is untouched (also confirmed by widget test — see "HOME
  Freeze regression" below). This reading was not escalated for separate
  human sign-off given the Fresh Audit itself already reasoned through the
  ambiguity and recommended this exact option as the only Freeze-compliant,
  non-6-tab choice; if this interpretation is later rejected, Fresh Audit
  §9 names Option C (メニュー内Mission入口) as the documented fallback.
- No existing "became assigned" dialog exists in this codebase (assignment
  happens silently at month-close, folded into the Monthly Management
  Report's own generic revenue/cash figures) — per the Implementation
  Plan's own §3.5 fallback guidance, the causal 参画→売上 explanation was
  placed **only** inside the Mission screen's own copy (Mission 8's tile
  and the MISSION COMPLETE banner), never as a new standalone auto-popup.
  `_maybeShowMonthlyReport` (the one existing month-close dialog) was not
  touched at all — zero risk of a double dialog.

## Files changed

- `lib/game/public_demo/public_demo_mission_resolver.dart` (new)
- `lib/ui/public_demo/public_demo_mission_screen.dart` (new)
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (+39 lines:
  2 new imports, 1 new `AppBar.actions` `IconButton`, 1 new private method)
- `test/game/public_demo/public_demo_mission_resolver_test.dart` (new, 14 tests)
- `test/ui/public_demo/public_demo_mission_screen_test.dart` (new, 15 tests)
- `test/ui/public_demo/public_demo_mission_appbar_entry_test.dart` (new, 9 tests)
- `docs/reports/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Fresh-Audit.md` (new — added verbatim)
- `docs/design/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md` (new — added verbatim)
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` (Update history entry + "Relationship to existing documents" line)
- `docs/reports/SES_FIRST-FUN-QUARTER_MISSION-PHASE1_Result.md` (this file)

`docs/DEVELOPMENT_PLAN.md` was checked and contains no Public Demo Mission
System content to synchronize (its one Public Demo mention is unrelated) —
no change made there, matching the task's own "必要なら" (only if
necessary) instruction.

No other file in the 6,721-line `public_demo_01_placeholder_screen.dart`
needed to change — confirmed by `git diff --stat`, which shows only the
39-line additive hunk above.

## Tests

### Resolver unit tests (`public_demo_mission_resolver_test.dart`, 14 tests)

- Fresh April start: only `viewSkillSheet` available, everything else locked.
- Each single-engineer chain step (viewSkillSheet → beginSelling →
  proposeToProject → passPartnerInterview → passClientInterview → winOrder)
  flips exactly the expected mission from `available` to `completed` and
  unlocks the next.
- Deterministic partner-interview **failure** (eng-02, capability 52 →
  score 57 < 60): `passPartnerInterview` correctly stays not-completed.
- **Retry after failure**: a real re-entry via `beginSelling` (accepted
  from `partnerInterviewFailed`, the domain's own transition table) plus a
  genuine capability increase (the same shape real Growth would produce,
  applied via a real save round-trip, never a caller-asserted outcome) —
  the retried interview genuinely passes and `passPartnerInterview` then
  reads `completed`.
- **Authority regression pin**: `closeApril` assigning a genuinely-ordered
  engineer shows `winOrder` AND `assignToProject` both `completed`
  simultaneously.
- **Company-level reduction**: engineer A viewing SkillSheet and engineer B
  beginning selling (different engineers) both read as company-level
  `completed` — the exact edge case the task calls out.
- **Month boundary**: June→July with a real continuation decision
  (`withAssignmentUpdate(nextOrderStatus: accepted)`) shows
  `assignToProject` still `completed` in July, proving the resolver reads
  its own current month rather than a stale one.
- **Legacy save compatibility**: a genuinely ordered+assigned aggregate
  round-tripped through the real `PublicDemoSaveCodec` resolves the full
  chain as `completed` on first load.
- **Malformed/forged stage cannot fake completion**: an engineer directly
  constructed with `stage: ordered` and NO `interviewRecord` (the exact
  "stage/lastInterviewScore alone are NOT proof" case the domain's own doc
  warns about) shows `winOrder` completed (documented Category A, bare
  stage, matching `recordOrder`'s own precondition chain) but
  `passClientInterview` and `assignToProject` correctly do NOT — proving
  the resolver cannot be fooled by a forged stage for the two missions
  whose authority actually depends on an unforgeable fact.
- **Idempotency**: resolving twice against the same aggregate produces
  identical output.

### UI tests

- `public_demo_mission_screen_test.dart` (15 tests): fresh/partial/complete
  chain rendering; MISSION COMPLETE banner + causal Hiyori text shown
  exactly once on completion, with no duplicate header; the "next goal"
  placeholder line; a 360×800/390×844 × TextScaler 1.0/1.3 matrix (fresh,
  partial, and complete chains) asserting zero exceptions.
- `public_demo_mission_appbar_entry_test.dart` (9 tests): the AppBar button
  is present and opens the Mission screen with the correct fresh-state
  copy; present on **every** tab (HOME/社員/営業/会計/メニュー), not only
  HOME; resolves against the currently-committed aggregate (an
  already-assigned save shows MISSION COMPLETE immediately); reopening the
  screen twice never accumulates duplicate MISSION COMPLETE banners; and a
  **HOME Freeze regression** check confirming HOME's own title/KPI text is
  present unchanged, the bottom nav still has exactly 5
  `NavigationDestination`s (no 6th tab), and the Mission chain copy never
  leaks into HOME's own body.

### Full suite results

- `flutter analyze` (whole repo): **No issues found.**
- `flutter test test/game/public_demo`: **1042/1042 passed** (1028 baseline
  + 14 new).
- `flutter test test/ui/public_demo`: **800/800 passed** (776 baseline + 24
  new).
- `git diff --check`: clean (no whitespace/conflict-marker issues).

(Flutter SDK was not present in this session's container; installed
`3.44.9` stable — the exact version pinned by
`.github/workflows/e2e.yml`/`e2e-heavy.yml` — to match CI exactly.)

## Self-hardening (Broad Self Review)

One Broad Self Review pass was run after implementation, focused on:
save compatibility, authority, stage forgery, stale month, duplicate
completion, retry, month transition, overflow, and double-dialog risk with
existing notifications.

**P1 found and fixed in this same session**: the `MISSION COMPLETE`
banner's heading `Row` (trophy icon + "MISSION COMPLETE" text) had no
`Expanded`/`Flexible` around the text — at 360px width with TextScaler 1.3
this produced a `RenderFlex overflowed by 45 pixels` error, caught directly
by the widget-test overflow matrix. Fixed by wrapping the text in
`Expanded`; the full 360×800/390×844 × TextScaler 1.0/1.3 matrix (12 cases,
3 chain states) now passes with zero exceptions.

Every other reviewed concern was already covered by a passing test (see
"Tests" above) and needed no further fix:

- **Save compatibility** — no new field, verified via a real codec
  round-trip test.
- **Authority / stage forgery** — verified via the explicit forged-stage
  test distinguishing bare-stage-trusted missions from the
  unforgeable-record-gated one.
- **Stale month** — verified via the June→July boundary test.
- **Duplicate completion** — verified via the idempotent-resolve test and
  the reopen-twice widget test; no reward/economy hook exists to
  double-grant in the first place (Fresh Audit §10.3's own recommendation
  against Mission rewards was followed — none were added).
- **Retry** — verified via the fail→retry→pass test.
- **Month transition** — verified via the June→July test and the existing
  `assignedEngineerIds` filter (unchanged, only read correctly).
- **Existing notification double-dialog** — no new auto-popup was added;
  `_maybeShowMonthlyReport` is untouched.

No P0 was found.

## Unresolved issues

None known for Phase 1's own scope. Two items intentionally deferred, both
already flagged by the source documents rather than newly discovered here:

1. The Fresh Audit's own §11 risk 2 (HOME Freeze / AppBar interpretation)
   is implemented per its own recommended reading (Option E) rather than
   separately re-confirmed with a human — see "Mission Entry Point /
   Screen" above for the reasoning and the documented fallback if this
   reading is ever rejected.
2. Mission 5's "retry after a genuine partner-interview failure that
   happens AFTER an already-genuine client-interview failure" (i.e. a
   client-interview failure sends the engineer all the way back through
   `selling`→`introduced`→partner-interview-again, per
   `beginSelling`'s own transition table accepting from
   `clientInterviewFailed`) is a real, intentional domain re-entry — during
   that specific replay window, `passPartnerInterview`/`proposeToProject`
   would correctly read as `available` again (not `completed`) until the
   partner interview is re-passed, mirroring the "real re-entry, not a bug"
   philosophy `PublicDemoEmployeeStatusResolver` already applies to
   `releaseFromAssignment`. This is consistent with Fresh Audit §3's own
   Category-A/monotonic classification (which itself only promises
   monotonicity relative to a single successful attempt cycle, not across
   a full pipeline restart) and was not flagged as a defect — noted here
   for visibility rather than left silent.

## Phase 2 recommendation

Proceed with Phase 2 (progressive/conversational onboarding —
`PublicDemoOpeningContextScreen` paged-flow redesign + event-driven
explanation triggers, Implementation Plan §5) as the next Mission-adjacent
session, per the Implementation Plan's own dependency graph (Phase 2
depends only on Phase 1's resolver/unlock signals, both now shipped). Phase
1b (Mission 9 / training-completion persistence — the one Mission needing a
genuinely new save field) can run independently/in parallel per the plan's
own note, since it does not touch the resolver shape Phase 1 just shipped.

## FINAL VERDICT

**GO — Phase 1 shipped as scoped.** `flutter analyze` clean, 1042+800
tests passing (38 new, 0 regressions), `git diff --check` clean, no new
save field, `schemaVersion` unchanged, HOME body/bottom-nav verified
unchanged by widget test, and the one self-review finding (a text-overflow
P1) was fixed and re-verified in this same session before finishing.

## Base main SHA

`dfb272619b92219853203a2f72eba4c785c0f66f`

## Final HEAD SHA

`b4a999e40340717fb7f49776dce4ce3534b25112` — the single commit on this
branch on top of the base SHA above (self-referential note: amending this
same commit to record its own hash changes the hash again; this is the
value after the last amend made purely to update this section's text, and
is also the SHA pushed to the PR — see chat reply / PR for confirmation).
