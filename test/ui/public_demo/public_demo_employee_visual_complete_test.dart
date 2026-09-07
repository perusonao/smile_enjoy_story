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
      'August: an assigned engineer\'s badge tone differs from a waiting '
      'one\'s (color only — the label text is still the exact, unchanged '
      '_currentEmployeeStatusLabel string)',
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
        expect(waitingBadge.label, '待機');
        expect(waitingBadge.tone, PublicDemoEmployeeStatusTone.waiting);
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
