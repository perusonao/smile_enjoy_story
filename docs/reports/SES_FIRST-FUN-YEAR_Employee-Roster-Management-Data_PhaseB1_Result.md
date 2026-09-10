# SES FIRST-FUN-YEAR P1: Employee Roster Management Data — Phase B-1 Result

Issue: #235
Status: **Phase B-1 implemented, tests green, ready for review**
Base: `origin/main` (fetched explicitly, default branch NOT used)
Base SHA: `160b78ab972b00d787dc827620c23e1335144728`

## 0. Current status

Phase B-1 is implemented, tested, and pushed. The 社員一覧 (`_employeeRosterCard`,
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`) now shows, per employee, a
compact compensation line — 経験年数 (experience) ・ 月給 (monthly salary) ・ 単金
(unit price) — below the existing name/status-badge row and skill capability bar. All
three values are read from pre-existing, already-tested authority; no new domain rule, no
save-schema change, and no UI-local placeholder/guessed value was added. 単金 reads `—`
for every employee, assigned or not, because — as Phase A's Fresh Audit found — no
per-employee/per-assignment unit-price authority exists anywhere in this repository.

## 0.1 Next action

Human review of this PR, then merge. Phase B-2 (年齢/性別, product decision required
first) and Phase B-3 (単金 real per-employee authority, product decision required first)
remain independent, unstarted follow-ups per the issue's own §7 split — neither is part of
this Phase B-1 scope.

If PR #233 (Issue #231 Package B — the roster's own 営業可能/研修が必要 captions) merges
before this PR, this branch should be rebased onto it and the two cards' line order/overflow
re-verified together (see §7 "Known limitations").

## 0.2 Actual elapsed time / Revised ETA

- Actual elapsed time for this session (Phase A carry-forward + Phase B-1 implementation,
  tests, docs, SSOT sync): a single continuous session, well within the issue's own P1
  sizing (Phase A was previously audited in ~6–7 minutes in a separate session; Phase B-1
  itself — a presentation-only, no-schema-change change — took a small fraction of a
  standard AI processing-time budget unit per the governing plan's sizing table).
- Revised ETA: none — Phase B-1 is complete. Phase B-2/B-3 remain unestimated pending their
  own product decisions (Fresh Audit §5.1/§5.2/§5.3), unchanged from Phase A's own estimate.

## 1. Base / Head

- Base: `origin/main` @ `160b78ab972b00d787dc827620c23e1335144728` (explicitly fetched at
  session start; this SHA is identical to Phase A's own audited SHA — no commits landed on
  `origin/main` between the audit and this implementation).
- Head: see the commit this report ships with (`git log -1 --format=%H`), pushed to
  `claude/ses-issue-235-phase-b1-upu7vj`.

## 2. What changed

One production file, one new focused test file, the Fresh Audit doc carried forward from
its own (unmerged, PR-less) audit branch, and this Result Report / SSOT sync:

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — `_employeeRosterCard()`
  only. Added a `Text` row (key
  `public-demo-employee-roster-compensation-<engineerId>`) rendering
  `経験 <formatExperience> ｜ 月給 <amount>万円 ｜ 単金 —`, reading:
  - `s.runtimeForOrNull(e.id)?.totalItExperienceMonths` (経験年数) — the exact runtime
    lookup the existing skill bar already makes; formatted with the app's existing
    `formatExperience()` (`lib/ui/widgets/labels.dart`), reused verbatim, not reimplemented.
  - `PublicDemoSalary.currentMonthlySalaryFor(e.id, applicants: workflow.applicants, month:
    s.month)` (月給) — the same accessor `bonusEligibleMonthlySalaryTotal` is built from;
    `null` (should not occur for any roster-listed engineer, but never assumed) renders as
    `—`, never a fabricated amount.
  - 単金: a literal `'単金 —'` — there is no field to read (Fresh Audit §2 row 8), so this
    is not a computed value at all, truthfully constant until Phase B-3 adds real
    per-employee/per-assignment authority.
  - No existing widget, key, section, eligibility check, or the name/skill/status-badge
    content was touched.
- `test/ui/public_demo/public_demo_employee_roster_phase_b1_test.dart` (new) — 9
  `testWidgets` blocks / 12 executed test cases (see §5).
- `docs/reports/SES_FIRST-FUN-YEAR_Employee-Roster-Management-Data_Fresh-Audit.md` (new to
  `origin/main`) — Phase A's own audit, carried forward verbatim from its own separate,
  PR-less audit branch (commit `a2d62ad`, 2026-09-10T14:03Z) so this document — which the
  issue itself and this Phase B-1 both depend on — is actually part of `origin/main`'s
  history rather than only existing on a branch nobody merged.
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — one new Update history entry
  (2026-09-10, Issue #235 Phase A + Phase B-1) recording status, scope, and the Package B
  (PR #233, still open as of this base SHA) regression note. `Current execution order` /
  `Prioritized backlog` table structure unchanged, per the doc's own convention for
  same-track incremental entries.

No file under `lib/game/`, `lib/presentation/home/`, or any Finance/Assignment/
Sales/Recruitment/save-codec file was touched. `schemaVersion` stays `1`.

## 3. Authority used for each displayed field

| Field | Authority | New field/computation? |
|---|---|---|
| 氏名 | `PublicDemoEngineerSales.name` (already displayed pre-Phase-B-1) | No — unchanged |
| スキル | `s.runtimeForOrNull(id)` → `PublicDemoEngineerRuntime.primaryLanguage`/`.actualCapability` via existing `_primarySkillDisplayFor` (already displayed) | No — unchanged |
| 参画状況 | `_currentlyAssignedEngineerIds`/`s.trainingSelections` via existing `_currentEmployeeStatusLabel`/`_employeeStatusTone` (already displayed) | No — unchanged |
| 経験年数 | `PublicDemoEngineerRuntime.totalItExperienceMonths`, formatted with existing `formatExperience()` | No — new **display**, existing authority/formatter reused verbatim |
| 月給 | `PublicDemoSalary.currentMonthlySalaryFor(employeeId, applicants:, month:)` | No — new **display**, existing accessor reused verbatim |
| 単金 | **None exists.** Literal `'—'` for every employee, per Fresh Audit §2 row 8 / §5.3 — displaying `PublicDemoRevenue.ratePerAssignedEngineer` (¥600,000 flat) as if it were a per-employee negotiated rate was explicitly rejected as a misrepresentation, per the issue's own instruction | N/A — not computed; the absence itself is the truthful display |
| 年齢 | Not implemented (issue scope) | N/A |
| 性別 | Not implemented (issue scope) | N/A |

No UI-local threshold, placeholder, or duplicated status-deriving switch was added. No
second experience/salary formatter was created.

## 4. UX

360x800 / 390x844 prioritized, per the issue. The roster card stays at 3 content rows:
1) name + status badge (unchanged), 2) skill capability bar (unchanged, shown only when a
runtime exists), 3) the new 経験/月給/単金 line. Example (eng-01, fresh April):

```text
佐藤 健                                    待機
Java 78
経験 3 年 ｜ 月給 30万円 ｜ 単金 —
```

SkillSheet detail (career history, certifications, per-tech experience breakdown) is not
pulled into the card — the existing "スキルシートを見る" icon button (unchanged) remains
the route to `PublicDemoSkillSheetSheet`.

## 5. Tests

Environment note: no Flutter SDK was preinstalled in this session's container; Flutter
3.44.9 (stable, matching this repo's own CI `subosito/flutter-action` pin) was downloaded
and installed locally to run the commands below.

- `flutter analyze` (whole project): **No issues found.**
- New focused test file, `test/ui/public_demo/public_demo_employee_roster_phase_b1_test.dart`
  — 12 test cases, all green:
  - founding employee (eng-01): compensation line reads existing authority verbatim,
    単金 `—`.
  - recruited employee: a genuinely hired applicant (via real
    `recruit`/`completeInterview`/`acceptOffer` commands) shows their own
    applicant-sourced salary/experience, not eng-01/eng-02's founding literals.
  - waiting vs. assigned (eng-01 genuinely Recovery-assigned 参画中, eng-02 待機): both
    read 単金 `—` — assigned status does not fabricate a rate, and the flat ¥600,000
    constant never leaks onto the card as a per-employee figure.
  - salary display: eng-01 (30万円) / eng-02 (25万円) — distinct, not duplicated.
  - experience display: eng-01 (`formatExperience(36)`) / eng-02 (`formatExperience(24)`)
    — distinct, not duplicated.
  - skill display: the existing capability bar keeps rendering alongside the new line
    (not replaced by it).
  - Package B (営業可能/研修が必要 caption) regression: see §7 — asserts the
    pre-existing Section 2 sales-readiness clarity (営業準備OK / lock banner) this
    issue's regression rule protects is unaffected.
  - save/reload: `PublicDemoSaveCodec().encode()`/`.decode()` round trip, re-pumped —
    exact same compensation text as the pre-save aggregate.
  - 360x800 / 390x844 × TextScaler 1.0/1.3: no overflow exception; both the roster row
    and the new compensation-line `Text` stay within the screen's left/right bounds.
- Existing roster suites re-run unmodified and still green:
  `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` (18 tests, including its
  own 360x800/390x844 × TextScaler 1.0/1.3/2.0 overflow suite) and
  `test/ui/public_demo/public_demo_employee_visual_complete_test.dart` (17 tests) — 35
  tests total, all green, confirming the new line did not disturb any pre-existing
  key/text/layout assertion (including the pre-existing TextScaler 2.0 coverage those
  suites already carry).
- `test/game/public_demo/` (full domain suite, unaffected by this UI-only change,
  run as a sanity check): **842 tests, all green.**
- `test/ui/public_demo/` (full Public Demo UI suite, includes the two suites and the new
  focused file counted above): **533 tests, all green.**
- `git diff --check`: clean, no whitespace errors.

## 6. Visual verification

360x800 and 390x844 (issue's prioritized breakpoints) were verified via the new focused
test file's own overflow assertions (rect bounds check on both the roster row and the new
compensation-line text, at TextScaler 1.0 and 1.3) plus the pre-existing
`public_demo_employee_ui_phase1_test.dart` suite's own 360x800/390x844 × TextScaler
1.0/1.3/2.0 sweep, which now also renders the new line without exception. No manual
screenshot capture was performed in this text-only environment; all visual-bounds claims
above are backed by `tester.getRect()` assertions against the actual rendered widget tree,
not visual inspection.

## 7. Known limitations / Unresolved items

1. **Package B (PR #233) was not merged into `origin/main` as of this Phase B-1's base
   SHA.** The issue's regression rule ("既存Package Bの「営業可能」「研修が必要」理由
   captionは維持してください") assumes this feature already exists on `origin/main`; it
   does not, as of `160b78ab972b00d787dc827620c23e1335144728` (confirmed via the GitHub
   API at implementation time — PR #233 state: `open`, `merged: false`, base SHA identical
   to this Phase B-1's own base). There is therefore nothing on this base to regress; the
   requirement is vacuously satisfied. If PR #233 merges first, this branch needs a rebase
   and a fresh combined visual check (both new lines on the same card, no combined
   overflow) — flagged here rather than silently assumed safe.
2. **単金 is always `—` in Phase B-1.** This is not a partial implementation bug — it is
   the truthful, audited state of the domain: no employee, in any state, has a
   per-employee/per-assignment unit-price fact anywhere in this repository today. Phase
   B-3 (Fresh Audit §5.3/§7) is the follow-up that would give this field real, varying
   values, and requires an explicit product decision (persist the order-time candidate
   rate vs. display the flat company-wide constant, honestly labeled) before it can start.
3. **年齢・性別 remain unimplemented**, per the issue's own instruction — Fresh Audit
   §5.1/§5.2 already recorded the minimal-extension proposals and the open product
   question (whether 性別 should be displayed at all, given the domain's deliberate
   gender-blind design) for a future Phase B-2, not decided here.

## 8. PR

<!-- FILLED IN AFTER PUSH -->
