// SES ISSUE-235 PHASE B-1: coverage for the 社員一覧 compensation line
// (経験年数/月給/単金) added to `_employeeRosterCard`, per the Fresh Audit
// (`docs/reports/SES_FIRST-FUN-YEAR_Employee-Roster-Management-Data_Fresh-Audit.md`)
// and the issue's own Phase B-1 scope: 氏名/月給/スキル/経験年数/参画状況 wired
// onto the card via pre-existing authority, no save-schema change.
//
// PR #236 Codex Broad Review P2 fix ("Use project-backed rates instead of
// always showing a dash"): 単金 now shows the real project rate
// (PublicDemoSeededProjectGenerator.regenerate(...).monthlyRate) for a
// genuinely currently-assigned engineer whose PublicDemoAssignment carries a
// real, resolvable projectId, and truthfully falls back to '—' for a waiting
// employee, a legacy/generic assignment with no projectId, or an
// unresolvable id — never PublicDemoRevenue.ratePerAssignedEngineer's flat
// company-wide constant, never a guessed number.
//
// Every fixture below is built by chaining the same real domain commands the
// existing roster suites (`public_demo_employee_ui_phase1_test.dart`,
// `public_demo_employee_visual_complete_test.dart`,
// `public_demo_career_history_writer_test.dart`'s own genuine-project-pass
// technique) already use — never a hand-built/UI-driven fixture — so no test
// here can pass by asserting a value this app does not actually compute.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/widgets/labels.dart';

import '../../game/public_demo/test_support/public_demo_recovery_test_helpers.dart';
import 'public_demo_tab_test_helpers.dart';

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

Key rosterRowKey(String engineerId) =>
    Key('public-demo-employee-roster-row-$engineerId');

Key compensationKey(String engineerId) =>
    Key('public-demo-employee-roster-compensation-$engineerId');

/// The compensation line's own text, read directly off the `Text` widget
/// found by its key. Not a `find.descendant(of: find.byKey(...), ...)`
/// search — the key sits on the `Text` widget itself, which has no `Text`
/// descendant of its own (it renders to a `RichText`, not a nested `Text`).
String compensationTextFor(WidgetTester tester, String engineerId) =>
    tester.widget<Text>(find.byKey(compensationKey(engineerId))).data ?? '';

Future<void> pumpDemoWith(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
}

/// eng-01 genuinely ordered-then-Recovery-assigned (real 参画中); eng-02
/// stays waiting. Same fixture shape the Phase 1 / Visual Complete suites
/// already use.
PublicDemoAggregate oneAssignedOneWaitingAtMonth(int month) {
  var aggregate = publicDemoAggregateAtMonth(month);
  aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
  aggregate = aggregate.recoverAssignment('eng-01');
  return aggregate;
}

/// Hires [applicantId] via the real `completeInterview`/`acceptOffer`
/// commands (`acceptanceScore: 100` forces acceptance), the same technique
/// `public_demo_employee_visual_complete_test.dart`'s own `_hireApplicant`
/// uses — never a reconstruction shortcut.
PublicDemoAggregate _hireApplicant(
  PublicDemoAggregate aggregate,
  String applicantId,
) {
  final applicant = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == applicantId,
  );
  final interviewed = aggregate.completeInterview(applicant.id).aggregate;
  final offer = PublicDemoSalaryOffer(
    requestedMonthlySalary: applicant.requestedMonthlySalary,
    offeredMonthlySalary: applicant.requestedMonthlySalary,
    acceptanceScore: 100,
    motivationDelta: 0,
    trustDelta: 0,
  );
  return interviewed.acceptOffer(
    applicantId: applicant.id,
    offer: offer,
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(interviewed.state.month),
  );
}

/// A single recruited/joined engineer (distinct from the two founding
/// engineers), joined via real recruitment/hiring commands, so this fixture
/// exercises `PublicDemoEngineerRuntime.fromApplicant`/
/// `PublicDemoApplicant.acceptedMonthlySalary` rather than the founding
/// literal constants.
({PublicDemoAggregate aggregate, String recruitedId}) recruitedEmployeeFixture() {
  var aggregate = PublicDemoAggregate.initial();
  aggregate = aggregate.closeApril(monthlyExpenses: 800000);
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);
  assert(recruited.isSuccess, 'fixture sanity: April cash affords engineer medium');
  aggregate = recruited.aggregate!;
  final applicantId = recruited.generatedApplicants.first.id;
  aggregate = _hireApplicant(aggregate, applicantId);
  aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 800000);
  final recruitedEngineer = aggregate.workflow.engineers.firstWhere(
    (e) => e.id != 'eng-01' && e.id != 'eng-02',
  );
  return (aggregate: aggregate, recruitedId: recruitedEngineer.id);
}

/// Advances eng-01 to `partnerInterviewPassed` via the real sales pipeline
/// (mirrors `public_demo_career_history_writer_test.dart`'s own
/// `_advanceToPartnerPassed`).
PublicDemoAggregate _advanceToPartnerPassed(PublicDemoAggregate aggregate) {
  var next = aggregate.startSkillSheetReview('eng-01');
  next = next.beginSelling('eng-01');
  next = next.introduceProject('eng-01');
  return next.recordEngineerInterviewResult(
    engineerId: 'eng-01',
    type: PublicDemoInterviewType.partner,
  );
}

/// Records a real Phase 5 matching proposal for eng-01 against this month's
/// first genuine project candidate.
PublicDemoAggregate _withRealProposal(PublicDemoAggregate aggregate) {
  var next = _advanceToPartnerPassed(aggregate);
  final project = next.projectCandidatesForMonth(next.state.month).first;
  return next.proposeMatch(engineerId: 'eng-01', projectId: project.id);
}

/// Runs eng-01's Phase 6 project interview to its real, formula-derived
/// conclusion (mirrors `public_demo_career_history_writer_test.dart`'s own
/// `_runInterviewToConclusion`).
PublicDemoAggregate _runInterviewToConclusion(PublicDemoAggregate aggregate) {
  aggregate = aggregate.startProjectInterview('eng-01');
  var session = aggregate.projectInterviewSessionFor('eng-01')!;
  while (session.playerFollowUps.length < session.questions.length) {
    final choice = PublicDemoProjectInterview.choicesFor(session).first;
    aggregate = aggregate.chooseProjectInterviewFollowUp(
      'eng-01',
      session.currentQuestionIndex,
      choice,
    );
    session = aggregate.projectInterviewSessionFor('eng-01')!;
  }
  return aggregate.concludeProjectInterview('eng-01');
}

/// A genuine, project-bound eng-01 assignment, assigned through the real
/// Phase 4/5/6/7A April→May flow — never a fabricated workflow. Scans a
/// bounded, deterministic seed range for one where the real formulas
/// produce a client-interview pass (mirrors
/// `public_demo_career_history_writer_test.dart`'s own
/// `_genuineAssignedAggregate`, reproduced here since that helper is
/// private to its own file). Returns `null` if no seed in range passes —
/// callers should treat that as a fixture problem, not silently skip the
/// assertion.
({PublicDemoAggregate aggregate, String projectId})? genuineProjectBackedFixture({
  int maxSeed = 40,
}) {
  for (var seed = 0; seed < maxSeed; seed++) {
    var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: seed));
    final projectId = aggregate.workflow.matchingProposalFor('eng-01')!.projectId;
    aggregate = _runInterviewToConclusion(aggregate);
    final engineer = aggregate.workflow.engineers.firstWhere(
      (e) => e.id == 'eng-01',
    );
    if (engineer.stage != PublicDemoSalesStage.clientInterviewPassed) continue;
    aggregate = aggregate.recordOrder('eng-01');
    aggregate = aggregate.closeApril(monthlyExpenses: 0);
    aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 0);
    final assignment = aggregate.workflow.assignments
        .where((a) => a.engineerId == 'eng-01')
        .firstOrNull;
    if (assignment?.projectId == projectId) {
      return (aggregate: aggregate, projectId: projectId);
    }
  }
  return null;
}

const _targetSizes = <Size>[Size(360, 800), Size(390, 844)];

void main() {
  group('founding employee: compensation line reads existing authority', () {
    testWidgets(
      'April, eng-01 (waiting): 経験年数/月給 read '
      'PublicDemoEngineerRuntime/PublicDemoSalary verbatim, 単金 is "—" '
      '(no per-employee unit-price authority exists)',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        final runtime = aggregate.state.runtimeForOrNull('eng-01')!;
        final salary = PublicDemoSalary.currentMonthlySalaryFor(
          'eng-01',
          applicants: aggregate.workflow.applicants,
          month: aggregate.state.month,
        )!;
        expect(runtime.totalItExperienceMonths, 36);
        expect(salary, PublicDemoSalary.satoMonthlySalary);

        final expectedText =
            '経験 ${formatExperience(36)} ｜ 月給 ${salary ~/ 10000}万円 ｜ 単金 —';
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.byKey(compensationKey('eng-01')),
          ),
          findsOneWidget,
        );
        expect(compensationTextFor(tester, 'eng-01'), expectedText);
      },
    );
  });

  group('recruited employee: compensation line reads applicant-sourced '
      'authority, not the founding literal', () {
    testWidgets(
      'a hired applicant shows their own accepted salary/experience, '
      'distinct from eng-01/eng-02\'s founding constants', (tester) async {
        final fixture = recruitedEmployeeFixture();
        await pumpDemoWith(tester, fixture.aggregate);

        final recruitedId = fixture.recruitedId;
        final applicant = fixture.aggregate.workflow.applicants.firstWhere(
          (a) => a.id == recruitedId,
        );
        final runtime = fixture.aggregate.state.runtimeForOrNull(recruitedId)!;
        final salary = PublicDemoSalary.currentMonthlySalaryFor(
          recruitedId,
          applicants: fixture.aggregate.workflow.applicants,
          month: fixture.aggregate.state.month,
        )!;
        expect(salary, applicant.acceptedMonthlySalary);
        expect(runtime.totalItExperienceMonths, applicant.experienceMonths);

        final expectedText =
            '経験 ${formatExperience(runtime.totalItExperienceMonths)} ｜ '
            '月給 ${salary ~/ 10000}万円 ｜ 単金 —';
        expect(
          compensationTextFor(tester, recruitedId),
          expectedText,
          reason:
              'a recruited employee must read their own applicant-sourced '
              'salary/experience, not eng-01/eng-02\'s hardcoded literals',
        );
      },
    );
  });

  group('単金: waiting employee shows "—"', () {
    testWidgets(
      'April, both founding engineers waiting: 単金 is "—" for both — '
      'nobody is assigned, so there is nothing to resolve a rate from',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        expect(compensationTextFor(tester, 'eng-01'), contains('単金 —'));
        expect(compensationTextFor(tester, 'eng-02'), contains('単金 —'));
      },
    );
  });

  group('単金: legacy/generic assignment (projectId == null) shows "—"', () {
    testWidgets(
      'August: eng-01 is genuinely 参画中 via the generic sales pipeline + '
      'Recovery (`publicDemoAdvanceEngineerToOrdered`/`recoverAssignment` — '
      'never routed through Phase 5 matching/Phase 6 project interview, so '
      'the resulting PublicDemoAssignment.projectId is null) — 単金 still '
      'truthfully reads "—", never PublicDemoRevenue.ratePerAssignedEngineer '
      'or any other guessed number; eng-02 stays 待機 and also reads "—"',
      (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        expect(
          aggregate.workflow.assignments
              .firstWhere((a) => a.engineerId == 'eng-01')
              .projectId,
          isNull,
          reason:
              'fixture sanity: the generic pipeline + Recovery never binds '
              'a real project id',
        );
        await pumpDemoWith(tester, aggregate);

        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.text('参画中'),
          ),
          findsOneWidget,
          reason: 'fixture sanity: eng-01 is genuinely assigned',
        );
        expect(
          compensationTextFor(tester, 'eng-01'),
          contains('単金 —'),
          reason:
              'assigned, but this assignment has no projectId — must not '
              'display PublicDemoRevenue.ratePerAssignedEngineer or any '
              'other guessed number as this employee\'s unit price',
        );
        expect(compensationTextFor(tester, 'eng-02'), contains('単金 —'));
        // Never a fabricated flat rate leaking onto the card as if it were
        // a per-employee figure.
        expect(compensationTextFor(tester, 'eng-01'), isNot(contains('60万')));
      },
    );
  });

  group('単金: project-backed assignment shows the real project rate', () {
    testWidgets(
      'a genuinely currently-assigned eng-01, assigned through the real '
      'Phase 5 matching → Phase 6 project interview → order → April/May '
      'close flow, shows the exact PublicDemoSeededProjectGenerator '
      '.regenerate(...).monthlyRate for their real project — not '
      'PublicDemoRevenue.ratePerAssignedEngineer\'s flat ¥600,000 constant',
      (tester) async {
        final fixture = genuineProjectBackedFixture();
        expect(
          fixture,
          isNotNull,
          reason:
              'fixture sanity: at least one seed in range must produce a '
              'genuine client-interview pass',
        );
        final aggregate = fixture!.aggregate;
        final candidate = PublicDemoSeededProjectGenerator.regenerate(
          runSeed: aggregate.state.runSeed,
          projectId: fixture.projectId,
        )!;
        // Sanity: the real rate is never the flat per-headcount constant by
        // construction coincidence — if it were, the test below would pass
        // even with the old always-'—' (or a hypothetical always-flat-rate)
        // implementation, silently.
        expect(candidate.monthlyRate, isNot(600000));

        await pumpDemoWith(tester, aggregate);

        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.text('参画中'),
          ),
          findsOneWidget,
          reason: 'fixture sanity: eng-01 is genuinely assigned',
        );
        expect(
          compensationTextFor(tester, 'eng-01'),
          contains('単金 ${candidate.monthlyRate ~/ 10000}万円'),
        );
        expect(
          compensationTextFor(tester, 'eng-01'),
          isNot(contains('単金 —')),
        );
        // Never the flat per-headcount constant either.
        expect(compensationTextFor(tester, 'eng-01'), isNot(contains('60万')));
      },
    );

    testWidgets(
      'save/reload: the project-backed 単金 survives a round trip unchanged',
      (tester) async {
        final fixture = genuineProjectBackedFixture();
        expect(fixture, isNotNull);
        final aggregate = fixture!.aggregate;
        final candidate = PublicDemoSeededProjectGenerator.regenerate(
          runSeed: aggregate.state.runSeed,
          projectId: fixture.projectId,
        )!;

        const codec = PublicDemoSaveCodec();
        final decoded = codec.decode(codec.encode(aggregate));
        expect(decoded, isNotNull, reason: 'fixture sanity: round trip must decode');

        await pumpDemoWith(tester, decoded!);

        expect(
          compensationTextFor(tester, 'eng-01'),
          contains('単金 ${candidate.monthlyRate ~/ 10000}万円'),
        );
      },
    );
  });

  group('単金: an unresolvable project id never crashes, always falls back '
      'to "—"', () {
    // A full round trip through PublicDemoSaveCodec cannot construct this
    // case: `_hasConsistentAuthorityFacts` cross-checks every non-null
    // `PublicDemoAssignment.projectId` against the same engineer's own
    // `interviewRecord.projectId`, and a save missing the field entirely is
    // migrated to an explicit `null` (never a dangling/malformed string) —
    // see `public_demo_save_codec.dart`'s own migration doc. So any
    // non-null `projectId` that legitimately reaches this card is
    // guaranteed resolvable by construction; this test instead pins the
    // exact guard `_currentUnitPriceDisplayFor` depends on
    // (`PublicDemoSeededProjectGenerator.regenerate` returning `null` for
    // an id it did not mint — already covered at the domain level by
    // `public_demo_seeded_project_generator_test.dart`'s own "regenerate()
    // returns null for an id this generator did not mint"), so the roster
    // card's own defensive `if (candidate == null) return null;` fallback
    // is demonstrably reachable-and-safe, not merely assumed.
    test('PublicDemoSeededProjectGenerator.regenerate returns null (not a '
        'thrown exception) for a malformed/unminted id', () {
      expect(
        PublicDemoSeededProjectGenerator.regenerate(
          runSeed: 0,
          projectId: 'not-a-real-project-id',
        ),
        isNull,
      );
    });
  });

  group('salary display', () {
    testWidgets(
      'eng-01/eng-02 show their own distinct founding salaries '
      '(30万円 / 25万円), not a shared/duplicated value', (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        expect(PublicDemoSalary.satoMonthlySalary, 300000);
        expect(PublicDemoSalary.suzukiMonthlySalary, 250000);
        expect(compensationTextFor(tester, 'eng-01'), contains('月給 30万円'));
        expect(compensationTextFor(tester, 'eng-02'), contains('月給 25万円'));
      },
    );
  });

  group('experience display', () {
    testWidgets(
      'eng-01 (36 months) and eng-02 (24 months) show their own distinct '
      'formatExperience()-formatted values', (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        expect(
          compensationTextFor(tester, 'eng-01'),
          contains(formatExperience(36)),
        );
        expect(
          compensationTextFor(tester, 'eng-02'),
          contains(formatExperience(24)),
        );
      },
    );
  });

  group('skill display: unchanged by this phase', () {
    testWidgets(
      'the existing primary-skill capability bar keeps rendering alongside '
      'the new compensation line, not replaced by it', (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.textContaining('Java'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.byKey(compensationKey('eng-01')),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Package B (営業可能/研修が必要 caption) coexistence', () {
    testWidgets(
      'April: 氏名/参画状況(営業可能・研修が必要・理由caption)/スキル/経験年数/'
      '月給/単金 all coexist on the same roster row without dropping any '
      'existing text — eng-01 (ready) reads 営業可能, eng-02 (not ready) '
      'reads 研修が必要 plus its existing reason caption, and Section 2\'s '
      '営業準備OK/lock banner clarity this issue\'s regression rule protects '
      'still renders unchanged',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        // eng-01 (founding capability 78) is ready for field sales —
        // PR #233's own `_currentEmployeeStatusLabel` split.
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.text('営業可能'),
          ),
          findsOneWidget,
        );
        // eng-02 (founding capability 52, below the 60 threshold) is not —
        // both the badge label and PR #233's own reason caption line.
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-02')),
            matching: find.text('研修が必要'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-02')),
            matching: find.textContaining('営業には実力'),
          ),
          findsOneWidget,
          reason:
              'PR #233\'s own not-ready reason caption must still render '
              'alongside Phase B-1\'s compensation line, not be displaced '
              'by it',
        );
        // Phase B-1's own compensation line is still present on both rows.
        expect(compensationTextFor(tester, 'eng-01'), contains('月給 30万円'));
        expect(compensationTextFor(tester, 'eng-02'), contains('月給 25万円'));

        // Section 2's own, independent sales-readiness clarity (unchanged
        // by either PR) still renders.
        expect(find.text('営業準備OK'), findsOneWidget);
        expect(
          find.byKey(const Key('public-demo-field-sales-lock-eng-02')),
          findsOneWidget,
        );
      },
    );

    for (final size in _targetSizes) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale: eng-01 (営業可能) and eng-02 (研修が必要 + reason '
          'caption + compensation line) both render with no overflow',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final aggregate = PublicDemoAggregate.initial();
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: PublicDemo01PlaceholderScreen(
                    saveService: _FixedSaveService(aggregate),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await switchPublicDemoTab(tester, PublicDemoTab.employees);

            expect(tester.takeException(), isNull);

            for (final id in ['eng-01', 'eng-02']) {
              final rowRect = tester.getRect(find.byKey(rosterRowKey(id)));
              expect(rowRect.left, greaterThanOrEqualTo(0.0));
              expect(rowRect.right, lessThanOrEqualTo(size.width));
            }
          },
        );
      }
    }
  });

  group('save/reload: compensation line survives a round trip', () {
    testWidgets(
      'decoding a fresh save and re-pumping shows the exact same '
      'compensation text as the pre-save aggregate', (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        const codec = PublicDemoSaveCodec();
        final json = codec.encode(aggregate);
        final decoded = codec.decode(json);
        expect(decoded, isNotNull, reason: 'fixture sanity: round trip must decode');

        await pumpDemoWith(tester, decoded!);

        expect(compensationTextFor(tester, 'eng-01'), contains('単金 —'));
        expect(compensationTextFor(tester, 'eng-01'), contains('月給 30万円'));
        expect(
          compensationTextFor(tester, 'eng-01'),
          contains(formatExperience(36)),
        );
      },
    );
  });

  group('360x800 / 390x844, TextScaler 1.0/1.3: no overflow with the new '
      'compensation line', () {
    for (final size in _targetSizes) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale: compensation line stays within the roster row width',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final aggregate = oneAssignedOneWaitingAtMonth(8);
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: PublicDemo01PlaceholderScreen(
                    saveService: _FixedSaveService(aggregate),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await switchPublicDemoTab(tester, PublicDemoTab.employees);

            expect(tester.takeException(), isNull);

            for (final id in ['eng-01', 'eng-02']) {
              final rowRect = tester.getRect(find.byKey(rosterRowKey(id)));
              expect(rowRect.left, greaterThanOrEqualTo(0.0));
              expect(rowRect.right, lessThanOrEqualTo(size.width));

              final compRect = tester.getRect(
                find.byKey(compensationKey(id)),
              );
              expect(compRect.left, greaterThanOrEqualTo(0.0));
              expect(compRect.right, lessThanOrEqualTo(size.width));
            }
          },
        );
      }
    }
  });
}
