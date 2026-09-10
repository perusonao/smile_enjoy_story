// SES NON-HOME-UI EMPLOYEE Visual Complete: coverage for the new
// Reference-style visual structure added on top of SES EMPLOYEE-UI-PHASE-1's
// existing 4-section information architecture (unchanged — see
// public_demo_employee_ui_phase1_test.dart) — the roster card's avatar/
// status-badge tone/skill bar, the 全員/待機中/参画中 filter, and the
// restyled Section 3 (参画中案件) metric bars. Every value asserted here is
// read from the same authoritative fixtures the Phase 1 suite already
// builds via real domain commands.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_employee_visual.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

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

Future<void> pumpDemoWith(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
}

/// Same fixture shape as the Phase 1 suite: eng-01 genuinely
/// ordered-then-Recovery-assigned (real 参画中), eng-02 left waiting.
PublicDemoAggregate oneAssignedOneWaitingAtMonth(int month) {
  var aggregate = publicDemoAggregateAtMonth(month);
  aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
  aggregate = aggregate.recoverAssignment('eng-01');
  return aggregate;
}

/// SES HUMAN-REPLAY PRE-FIX P1: hires [applicantId] via the same real
/// `completeInterview`/`acceptOffer` production commands
/// `public_demo_aggregate_test.dart`'s own `hireApplicant` fixture uses
/// (`acceptanceScore: 100` forces acceptance so this fixture does not also
/// have to satisfy the real evaluator's threshold) — never a reconstruction
/// shortcut.
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

/// A genuine post-hire multi-employee state: the 2 founding engineers plus
/// 2 recruited applicants (CORE-GAMEPLAY Phase 4.5: [PublicDemoAggregate
/// .initial] no longer pre-seeds any applicant, so this recruits via the
/// same real `recruit` command production code uses, engineer medium, count
/// 2), hired and joined via the real April->May close chain (matching
/// `public_demo_aggregate_test.dart`'s "D/G" fixture) — 4 employees total
/// in `workflow.engineers` by month 6.
PublicDemoAggregate fourEmployeesAtMonth6() {
  var aggregate = PublicDemoAggregate.initial();
  aggregate = aggregate.closeApril(monthlyExpenses: 800000);
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);
  assert(recruited.isSuccess, 'fixture sanity: April cash affords engineer medium');
  aggregate = recruited.aggregate!;
  final poolIds = recruited.generatedApplicants.map((a) => a.id).toList();
  for (final id in poolIds) {
    aggregate = _hireApplicant(aggregate, id);
  }
  aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 800000);
  return aggregate;
}

void main() {
  group('Roster card visual structure', () {
    testWidgets(
      'April: each roster row carries a portrait avatar, a colored status '
      'badge, and a capability skill bar reading the real primary-language '
      'capability — not a fabricated number',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        for (final id in ['eng-01', 'eng-02']) {
          final row = find.byKey(rosterRowKey(id));
          expect(row, findsOneWidget);
          expect(
            find.descendant(
              of: row,
              matching: find.byType(PublicDemoEmployeeAvatar),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.byType(PublicDemoEmployeeStatusBadge),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.byType(PublicDemoEmployeeSkillBar),
            ),
            findsOneWidget,
          );
        }

        // eng-01's authoritative founding capability is 78 (Java) — see
        // publicDemoInitialEngineerRuntimes. The skill bar must show this
        // real value, not an invented one.
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.textContaining('Java 78'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-02')),
            matching: find.textContaining('JavaScript 52'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'August: an assigned engineer\'s badge tone differs from a still-'
      'waiting, not-yet-field-sales-ready one\'s (Issue #231 FIRST-FUN-YEAR '
      'P1: the waiting badge now reads 研修が必要, not the generic 待機, '
      'because eng-02\'s founding capability genuinely never reached the '
      'threshold in this fixture)',
      (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        await pumpDemoWith(tester, aggregate);

        final assignedBadge = tester.widget<PublicDemoEmployeeStatusBadge>(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.byType(PublicDemoEmployeeStatusBadge),
          ),
        );
        final waitingBadge = tester.widget<PublicDemoEmployeeStatusBadge>(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-02')),
            matching: find.byType(PublicDemoEmployeeStatusBadge),
          ),
        );
        expect(assignedBadge.label, '参画中');
        expect(assignedBadge.tone, PublicDemoEmployeeStatusTone.assigned);
        expect(waitingBadge.label, '研修が必要');
        expect(waitingBadge.tone, PublicDemoEmployeeStatusTone.training);
      },
    );
  });

  group('社員一覧 status filter (全員/待機中/参画中)', () {
    testWidgets(
      'August: default is 全員 (both rows visible); tapping 参画中 hides the '
      'waiting engineer\'s row, tapping 待機中 hides the assigned one\'s, '
      'and Section 2/3/4 content is unaffected by the filter', (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        await pumpDemoWith(tester, aggregate);

        expect(find.byKey(rosterRowKey('eng-01')), findsOneWidget);
        expect(find.byKey(rosterRowKey('eng-02')), findsOneWidget);
        // Section 3's APV card is present regardless of the roster filter.
        expect(
          find.byKey(const Key('public-demo-active-project-status-eng-01')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(
            const Key('public-demo-employee-status-filter-assigned'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(rosterRowKey('eng-01')), findsOneWidget);
        expect(find.byKey(rosterRowKey('eng-02')), findsNothing);
        // Filtering the roster never touches Section 3's own list.
        expect(
          find.byKey(const Key('public-demo-active-project-status-eng-01')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('public-demo-employee-status-filter-waiting')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(rosterRowKey('eng-01')), findsNothing);
        expect(find.byKey(rosterRowKey('eng-02')), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('public-demo-employee-status-filter-all')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(rosterRowKey('eng-01')), findsOneWidget);
        expect(find.byKey(rosterRowKey('eng-02')), findsOneWidget);
      },
    );

    testWidgets(
      'the summary sentence (PublicDemoState.engineersWaiting/Assigned) '
      'keeps rendering unchanged regardless of the filter selection',
      (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        await pumpDemoWith(tester, aggregate);

        expect(find.text('待機 1・参画中 1・合計 2'), findsOneWidget);
        await tester.tap(
          find.byKey(
            const Key('public-demo-employee-status-filter-assigned'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('待機 1・参画中 1・合計 2'), findsOneWidget);
      },
    );

    testWidgets(
      'SES HUMAN-REPLAY PRE-FIX P1: every filter chip\'s real hit-test box '
      '(the Material carrying the tap key) is at least 48x48dp',
      (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        await pumpDemoWith(tester, aggregate);

        for (final name in ['all', 'waiting', 'assigned']) {
          final rect = tester.getRect(
            find.byKey(Key('public-demo-employee-status-filter-$name')),
          );
          expect(
            rect.height,
            greaterThanOrEqualTo(48.0),
            reason: '$name chip height',
          );
          expect(
            rect.width,
            greaterThanOrEqualTo(48.0),
            reason: '$name chip width',
          );
        }
      },
    );
  });

  group('Section 3 (参画中案件) restyled metric bars', () {
    testWidgets(
      'August: the APV card shows the exact authoritative deliveryPressure '
      'and budgetHealth numbers from PublicDemoAssignment', (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        final assignment = aggregate.workflow.assignments.firstWhere(
          (a) => a.engineerId == 'eng-01',
        );
        await pumpDemoWith(tester, aggregate);

        final card = find.byKey(
          const Key('public-demo-active-project-status-eng-01'),
        );
        expect(card, findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text('${assignment.deliveryPressure}'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('${assignment.budgetHealth}'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('参画中案件：${assignment.projectName}'),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('HOME Freeze regression', () {
    testWidgets(
      'none of the new visual widgets (avatar/badge/skill bar/filter) leak '
      'into HOME', (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        await pumpDemoWith(tester, aggregate);
        expect(find.byType(PublicDemoEmployeeAvatar), findsWidgets);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(find.byType(PublicDemoEmployeeAvatar), findsNothing);
        expect(find.byType(PublicDemoEmployeeStatusBadge), findsNothing);
        expect(find.byType(PublicDemoEmployeeSkillBar), findsNothing);
        expect(
          find.byKey(const Key('public-demo-employee-status-filter')),
          findsNothing,
        );
      },
    );
  });

  group(
    'SES HUMAN-REPLAY PRE-FIX P1: post-hire multi-employee state (4 '
    'employees) — the compressed Section 2 cards still render every '
    'employee, with no overflow',
    () {
      testWidgets(
        'month 6, 4 genuinely joined/founding employees: Section 1 lists '
        'all 4 roster rows, Section 2 renders a card per employee with no '
        'duplicate-name overflow, and no exception is thrown',
        (tester) async {
          final aggregate = fourEmployeesAtMonth6();
          expect(
            aggregate.workflow.engineers.length,
            4,
            reason: 'fixture sanity: 2 founding + 2 genuinely joined',
          );
          await pumpDemoWith(tester, aggregate);

          expect(tester.takeException(), isNull);
          for (final e in aggregate.workflow.engineers) {
            expect(
              find.byKey(rosterRowKey(e.id)),
              findsOneWidget,
              reason: '${e.id} (${e.name}) must appear in Section 1',
            );
          }
          expect(find.text('今やるべき社員アクション'), findsOneWidget);
        },
      );

      for (final size in const [Size(360, 800), Size(390, 844)]) {
        for (final textScale in [1.0, 1.3, 2.0]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: no horizontal overflow with 4 employees',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(tester.view.reset);

              final aggregate = fourEmployeesAtMonth6();
              await tester.pumpWidget(
                MaterialApp(
                  theme: SesTheme.build(),
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
              for (final e in aggregate.workflow.engineers) {
                final rowRect = tester.getRect(find.byKey(rosterRowKey(e.id)));
                expect(rowRect.left, greaterThanOrEqualTo(0.0));
                expect(rowRect.right, lessThanOrEqualTo(size.width));
              }
            },
          );
        }
      }
    },
  );

  group('360x800 / 390x844, TextScaler 1.0/1.3/2.0: filter chips stay '
      'within screen bounds', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale: no overflow, filter chip row and roster cards stay '
          'within the screen width',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final aggregate = oneAssignedOneWaitingAtMonth(8);
            await tester.pumpWidget(
              MaterialApp(
                theme: SesTheme.build(),
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

            final filterRect = tester.getRect(
              find.byKey(const Key('public-demo-employee-status-filter')),
            );
            expect(filterRect.left, greaterThanOrEqualTo(0.0));
            expect(filterRect.right, lessThanOrEqualTo(size.width));

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
}
