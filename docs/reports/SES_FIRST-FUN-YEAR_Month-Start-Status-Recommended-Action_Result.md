# SES FIRST-FUN-YEAR P1 — Month-start Status / Recommended Action — Result Report

Issue: [#243](https://github.com/perusonao/smile_enjoy_story/issues/243)

## 0. Metadata

| item | value |
|---|---|
| Base SHA (`origin/main`, fetched explicitly) | `8e64a1c8dda86f5848a3257dcffc3938323992ed` |
| Final HEAD SHA (this branch) | `d92142a7516edd3bdac964c294c31a2bfd5e9e56` |
| Branch | `claude/issue-243-implementation-rtd0jz` |
| Fresh Audit source (SSOT) | `docs/reports/SES_FIRST-FUN-YEAR_Month-Start-Status-Recommended-Action_Fresh-Audit.md` §5 Finding 1 — brought onto this branch (see Known Limitations) since it existed only on an unmerged branch at task start |
| Scope | Fresh Audit Finding 1 only, per Issue #243's own Scope/Out-of-Scope |

## 1. Fresh Audit source note

The Issue names the Fresh Audit report as required reading at
`docs/reports/SES_FIRST-FUN-YEAR_Month-Start-Status-Recommended-Action_Fresh-Audit.md`,
audited at base SHA `8e64a1c`. That report existed only on a separate,
unmerged branch (`claude/fresh-audit-result-report-1riple`, commit
`fafa284`) at the start of this task — not yet on `origin/main`. It was
read in full before any implementation, and brought onto this branch
unchanged (commit `e3f0630`) so the SSOT path exists here. No production
code was changed by that commit.

## 2. Finding 1 — before / after

**Root cause (before):** a founding engineer who did not reach `ordered`
inside April had no `ec(i)` render site at all in May, and June only
rendered it for a later-joined hire (`s.joinedApplicantIds`) — never a
founding engineer. That left such an engineer with:
- no interactive control on the 社員 tab,
- no HOME Recommended Action candidate,
- no Month Guard `recommended`-level signal,
- a roster `営業可能` label that could not appear even when the underlying
  fact (`isReadyForFieldSales`) was true (`_fieldSalesActionReachableThisMonth`
  returned `false` for May, and for June unless the engineer was a
  joined applicant),

for two full months, resurfacing only once RECOVERY-LOOP-1's July window
opened.

**After:** the same three render/decision sites are widened, in the exact
shape RECOVERY-LOOP-1's own July-February loop already uses (`stage !=
ordered && not currently assigned`), for May and June:
- `_employeeNextActionsSection`'s `ec(i)` render loop,
- `_recommendedActionCandidates`'s matching engineer-stage loop (same
  emission position as before, so June's existing tie-break order among
  same-priority candidates is unchanged),
- `_fieldSalesActionReachableThisMonth`, simplified to `true` for every
  month April through February (`s.month >= 4 && s.month <= 14`) — the
  one no-longer-reachable month is March (15), unchanged, matching
  RECOVERY-LOOP-1's own last-eligible-month boundary.

A founding engineer stuck at any pre-`ordered` stage in May or June now
has the same reachable next action, the same HOME Recommended Action
candidate (when it is the highest-priority one), the same Month Guard
`recommended` warning if ignored, and the same truthful `営業可能` roster
label as the population RECOVERY-LOOP-1 already covers from July on —
closing the gap without touching RECOVERY-LOOP-1's own window, filters, or
emission logic at all.

## 3. Changed files

### Production (`lib/`)

| file | change |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_employeeNextActionsSection`: widened the June-only, joined-applicant-only `ec(i)` loop to May+June, any not-yet-ordered/not-assigned engineer (`showTrainingCard: false`, matching RECOVERY-LOOP-1's own duplicate-key precaution against `_employeeGrowthSection`'s unconditional `s.month >= 5` training card). `_recommendedActionCandidates`: same widening, same emission position. `_fieldSalesActionReachableThisMonth`: simplified to `s.month >= 4 && s.month <= 14`. |
| `lib/ui/public_demo/public_demo_employee_status_resolver.dart` | Doc-only: updated the stale "March only" → correct "March only" note now that the reachable window is April-February (previously the doc said "May/March"). |

No `lib/game/**` file, no `PublicDemoSaveCodec` file, and no HOME layout
file was changed — matching the Fresh Audit's own §7/§10 prediction
exactly.

### Tests

| file | change |
|---|---|
| `test/ui/public_demo/public_demo_01_month_start_status_recommended_action_test.dart` (new) | Dedicated Finding 1 suite: April regression, May stage-by-stage candidate emission (waiting/skillSheet/selling/introduced/partnerInterviewPassed), June founding-engineer parity with the pre-existing joined-applicant case, ordered/assigned engineers producing no invalid or duplicate candidate, July+ RECOVERY-LOOP-1 no-double-emission, Month Guard `recommended` warning in May, save/reload round-trip, 360×800/390×844 × TextScaler 1.0/1.3 overflow check. |
| `test/ui/public_demo/public_demo_issue231_employee_skillsheet_clarity_test.dart` | Updated the May and June "no reachable action, roster falls back to 待機" assertions (this PR's own gap, now fixed) to the new truthful `営業可能`; narrowed the group's own doc to reflect that only March keeps the fallback. |
| `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart` | Two "no-hire route" June tests, and one May test, whose premise ("nothing sellable for a founding engineer") this fix genuinely changes — updated fixtures to sell/resolve the engineer first so each test still isolates the specific behavior (求人媒体 ranking, applicant-review ranking) it was written to prove. |
| `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` | Same "no-hire route" premise fix for test `14b`, including resolving the assigned engineer's July continuation so `assignmentConfirmNextOrder` (a genuine, unrelated pre-existing candidate) does not itself confound the scenario. |
| `test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart` | Same premise fix for the 採用-routing test (May, previously assumed no 営業 row exists at all). |
| `test/ui/public_demo/public_demo_01_playthrough_test.dart` | Updated the June headline assertion (求人媒体 → the now-correctly-ranked founding-engineer action) and added the now-genuine Month Guard dismissal at the June close. |
| `test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart` | Added the now-genuine Month Guard dismissal at the June close (Sato, left at `skillSheet` throughout this fixture, is now a real outstanding candidate there too). |

## 4. Authority / persistence impact

- **Save schema:** unchanged. No new field, no new enum value, no
  `toJson`/`fromJson` change (verified directly: the fix reads only
  already-persisted facts — `PublicDemoSalesStage`, assignment membership
  — that every other branch of the same two methods already reads; the
  save-codec round-trip test in the new suite pins this).
- **Domain authority:** unchanged. No new class, no new
  `HomeRecommendedActionKind` value (the emitted kinds —
  `employeeSkillSheetReview`/`employeeBeginSelling`/etc. — already
  existed with correct presentation priorities). `PublicDemoSalesStage`,
  `PublicDemoRecoveryEligibility`, `assignOrderedForMay` — all untouched.
- **`ordered != assigned`:** preserved — the widened loops explicitly
  exclude `stage == ordered` before ever reaching an `ordered`-specific
  branch, and separately exclude anyone already in
  `workflow.assignments`.
- **RECOVERY-LOOP-1 (July-February):** untouched — its own month window
  (`s.month >= 7 && s.month <= 14`), filter, and emission logic are
  unchanged; the new suite's own "no double emission" test confirms an
  engineer reaching August still gets exactly one card/candidate.
- **Finance / Payroll / Matching / Assignment:** untouched. `test/game/public_demo`
  is a zero-diff regression (861/861, see §5) — expected, since no
  `lib/game/**` file was touched.

## 5. Test results

- `flutter analyze`: **No issues found.**
- `flutter test test/game/public_demo`: **861/861 passed** (zero-diff
  regression — no domain file was changed by this fix).
- `flutter test test/ui/public_demo`: **{{UI_RESULT}}**
- `git diff --check`: clean (no whitespace errors).

### Verification matrix (Issue #243's own list)

| item | result |
|---|---|
| Fresh April regression | ✅ unaffected — new suite's own April test, plus `public_demo_01_home_recommended_action_test.dart` group 1-2/3's April tests |
| May founding engineer: waiting + sales-ready | ✅ now `employeeSkillSheetReview`, `営業可能` roster label |
| May founding engineer: skillSheet / selling / introduced / interview stages | ✅ each now yields the matching stage candidate (new suite, parameterized) |
| June founding engineer still not ordered | ✅ same as May, now consistent with the pre-existing joined-applicant case |
| June joined applicant not ordered — existing behavior unchanged | ✅ still reachable, same roster truthfulness (new suite; render-site check, since a just-joined applicant's own real `canRequestRaiseIn` eligibility — unrelated to this Issue — can outrank the sales-pipeline candidate for HOME's single top slot) |
| ordered engineer — no duplicate/invalid candidate | ✅ new suite: an order placed mid-May (before any further close) stays genuinely ordered/unassigned, and no sales-pipeline candidate targets them |
| assigned engineer — no invalid candidate | ✅ new suite: sold fully within April, assigned for May via `assignOrderedForMay` — no sales-pipeline candidate |
| July onward — Recovery Loop unchanged, no double emission | ✅ new suite + zero-diff `test/game/public_demo` |
| Month Guard recommended warning | ✅ new suite (May close) + `public_demo_01_playthrough_test.dart`/`public_demo_01_suzuki_sales_lock_test.dart` (June close, both genuinely new outstanding items this fix surfaces) |
| roster `営業可能` truthfulness | ✅ `public_demo_issue231_employee_skillsheet_clarity_test.dart` (May/June, updated) + new suite |
| save/reload around month transition | ✅ new suite's own `PublicDemoSaveCodec` round-trip test |
| 360x800 / 390x844, TextScaler 1.0 / 1.3 | ✅ new suite's own dedicated overflow check (社員 tab, May, both founding engineers mid-pipeline) — no new information was added to HOME itself, so HOME's own One-Screen budget is untouched (confirmed by the existing HOME viewport suites staying green) |
| `flutter analyze` | ✅ clean |
| focused tests | ✅ see above |
| `flutter test test/game/public_demo` | ✅ 861/861 |
| `flutter test test/ui/public_demo` | {{UI_RESULT_SHORT}} |
| `git diff --check` | ✅ clean |

## 6. Unresolved / Known Limitations

- **Fresh Audit report not yet on `origin/main`:** the SSOT audit report
  this Issue names was, at task start, committed only on an unmerged
  branch. It has been brought onto this implementation branch verbatim
  (commit `e3f0630`) so the PR includes it, but the repository owner
  should confirm whether that separate branch/PR is still wanted, or can
  be treated as superseded once this PR merges.
- **Pre-existing test premise updates:** six existing test files had a
  scenario built on "an untouched founding engineer has no May/June
  action" as their own fixture's premise (for an unrelated assertion —
  求人媒体 ranking, 採用 CTA routing, etc.), not as a test *of* Finding 1
  itself. Fixing Finding 1 necessarily changes what those fixtures need
  to set up first; each was updated to reach the same original scenario
  by excluding the founding engineer's now-real action explicitly (sold
  to `ordered`, and — where relevant — their July continuation also
  explicitly resolved, since `assignOrderedForMay` runs at both April's
  and May's close, so any order placed by either month is assigned
  entering June either way).
- **Finding 2 (dead-code HOME shell cleanup):** explicitly out of scope
  per the Issue, not touched.
- Every other Known Limitation the Fresh Audit itself already carried
  forward (Monthly Report not persisted, no 前月比 comparison, no
  入社予定月 figure, recruitment timing/copy gaps) is unchanged by this
  fix and remains open, as documented in the audit's own §11.

## 7. Actual elapsed time

Approximately 2.5-3 hours (implementation + self-hardening + the two full
`flutter test test/ui/public_demo` runs this fix's own scope required to
find and fix six pre-existing test premises the change legitimately
invalidates, beyond the original 1.5-2.5h estimate) — driven by that
verification-matrix requirement (`flutter test test/ui/public_demo` must
be green), not by unexpected domain/persistence scope.

## 8. PR

{{PR_URL}}

---

_Generated by [Claude Code](https://claude.ai/code)_
