// SES ISSUE-235 PHASE B-1: coverage for the 社員一覧 compensation line
// (経験年数/月給/単金) added to `_employeeRosterCard`, per the Fresh Audit
// (`docs/reports/SES_FIRST-FUN-YEAR_Employee-Roster-Management-Data_Fresh-Audit.md`)
// and the issue's own Phase B-1 scope: 氏名/月給/スキル/経験年数/参画状況 wired
// onto the card via pre-existing authority, no save-schema change, and 単金
// truthfully reading '—' for every employee (no per-employee/per-assignment
// unit-price authority exists anywhere in the repo — confirmed by the audit).
//
// Every fixture below is built by chaining the same real domain commands the
// existing roster suites (`public_demo_employee_ui_phase1_test.dart`,
// `public_demo_employee_visual_complete_test.dart`) already use — never a
// hand-built/UI-driven fixture — so no test here can pass by asserting a
// value this app does not actually compute.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
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

  group('waiting vs assigned: 単金 stays "—" regardless of 参画状況', () {
    testWidgets(
      'August: eng-01 is genuinely 参画中 (Recovery-assigned) and eng-02 is '
      '待機 — both still truthfully read 単金 "—", never a guessed/flat rate',
      (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
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
              'assigned but no per-employee/per-assignment rate authority '
              'exists — must not display PublicDemoRevenue.ratePerAssignedEngineer '
              'or any other guessed number as this employee\'s unit price',
        );
        expect(compensationTextFor(tester, 'eng-02'), contains('単金 —'));
        // Never a fabricated flat rate leaking onto the card as if it were
        // a per-employee figure.
        expect(compensationTextFor(tester, 'eng-01'), isNot(contains('60万')));
      },
    );
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

  group('Package B (営業可能/研修が必要 caption) regression', () {
    testWidgets(
      'April: Section 2\'s existing sales-readiness clarity '
      '(営業準備OK / the not-ready lock banner) — the same clarity feature '
      'this issue\'s regression rule protects — still renders unchanged '
      'alongside the new roster compensation line',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        // NOTE: PR #233 (Issue #231 Package B), which adds the roster's own
        // 営業可能/研修が必要 badge text this issue names, is not yet merged
        // into origin/main as of this Phase B-1's base SHA (confirmed via
        // the GitHub API at implementation time) — so there is no such
        // roster-card text on this base to regress. This asserts the
        // pre-existing Section 2 sales-readiness clarity (営業準備OK / the
        // not-yet-ready lock banner) — the feature #233 itself extends —
        // is untouched by Phase B-1's compensation line.
        expect(find.text('営業準備OK'), findsOneWidget);
        expect(
          find.byKey(const Key('public-demo-field-sales-lock-eng-02')),
          findsOneWidget,
        );
      },
    );
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
