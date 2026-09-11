// Issue #245 Finding #2 / Codex review (PR #246, thread
// PRRT_kwDOT2htY86hiMIf): 案件紹介 must show a SnackBar naming the real
// project a genuine PublicDemoMatchingProposal already resolves to — even
// when that proposal was made in an earlier month and the engineer only
// pressed 案件紹介 after the month advanced (still `selling`, per the
// review's own repro). Project ids encode their origin month
// (`project-<month>-<slot>`), so resolving through *this* month's candidate
// pool silently drops a persisted cross-month proposal; the fix resolves
// through PublicDemoAggregate.projectInterviewCandidateFor instead, which
// regenerates the proposal's own projectId regardless of the current month.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

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

const _expense = 100000;

/// Reaches May with 'eng-01' still `selling` and a genuine matching
/// proposal made back in April (month 4) — the exact cross-month shape the
/// Codex review flagged: the proposal survives `closeApril`, only the
/// current month moves on.
({PublicDemoAggregate aggregate, PublicDemoProjectCandidate aprilCandidate})
mayWithAprilProposalStillSelling({int runSeed = 7}) {
  var aggregate = PublicDemoAggregate.initial(runSeed: runSeed);
  aggregate = aggregate.startSkillSheetReview('eng-01');
  aggregate = aggregate.beginSelling('eng-01');
  final aprilCandidate = aggregate
      .projectCandidatesForMonth(aggregate.state.month)
      .first;
  aggregate = aggregate.proposeMatch(
    engineerId: 'eng-01',
    projectId: aprilCandidate.id,
  );
  aggregate = aggregate.closeApril(monthlyExpenses: _expense);
  return (aggregate: aggregate, aprilCandidate: aprilCandidate);
}

Future<void> _pumpEmployeesTab(
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

Future<void> _tapIntroduceProject(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, '案件紹介');
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets(
    'same-month: 案件紹介 shows the SnackBar with the real project name/'
    'client/rate',
    (tester) async {
      var aggregate = PublicDemoAggregate.initial(runSeed: 3);
      aggregate = aggregate.startSkillSheetReview('eng-01');
      aggregate = aggregate.beginSelling('eng-01');
      await _pumpEmployeesTab(tester, aggregate);

      await _tapIntroduceProject(tester);

      expect(
        find.byKey(const Key('public-demo-project-introduced-snackbar')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cross-month regression (Codex PRRT_kwDOT2htY86hiMIf): a proposal made '
    'in April still produces the SnackBar in May, naming the real April '
    'project — not silently skipped because it is absent from May\'s pool',
    (tester) async {
      final fixture = mayWithAprilProposalStillSelling();
      await _pumpEmployeesTab(tester, fixture.aggregate);

      await _tapIntroduceProject(tester);

      final snackbar = find.byKey(
        const Key('public-demo-project-introduced-snackbar'),
      );
      expect(snackbar, findsOneWidget);
      expect(
        find.descendant(
          of: snackbar,
          matching: find.textContaining(fixture.aprilCandidate.title),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: snackbar,
          matching: find.textContaining(fixture.aprilCandidate.clientName),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cross-month regression: the resolved candidate is genuinely the '
    'proposal\'s own April project id, not a same-named coincidence from '
    'May\'s own pool',
    (tester) async {
      final fixture = mayWithAprilProposalStillSelling(runSeed: 11);
      // Sanity: the April candidate's id is not present in May's own pool —
      // this is exactly the condition that made the pre-fix lookup fail.
      final mayIds = fixture.aggregate
          .projectCandidatesForMonth(fixture.aggregate.state.month)
          .map((c) => c.id)
          .toSet();
      expect(mayIds.contains(fixture.aprilCandidate.id), isFalse);

      await _pumpEmployeesTab(tester, fixture.aggregate);
      await _tapIntroduceProject(tester);

      expect(
        find.byKey(const Key('public-demo-project-introduced-snackbar')),
        findsOneWidget,
      );
    },
  );
}
