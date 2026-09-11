// SES FIRST-FUN-YEAR P1: Project / Order / Assignment Continuous Visibility.
// End-to-end widget coverage for the new project-context wiring
// (`_projectContextFor`/`_orderedProjectRosterSegment`/`_realProjectNameFor`
// in `public_demo_01_placeholder_screen.dart`, backed by the pure
// `PublicDemoProjectContextResolver`) across the real lifecycle:
// proposal/interview (Sales-pipeline card) → ordered-not-assigned (roster) →
// assigned (roster + activeProjectStatusCard + June's assignmentCard) →
// legacy/generic fallback (never fabricated).
//
// Every fixture is built by chaining the same real domain commands the
// existing roster/active-project suites already use (mirrors
// `public_demo_employee_roster_phase_b1_test.dart`'s own
// `genuineProjectBackedFixture` technique) — never a hand-built/UI-driven
// shortcut.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

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

Future<void> pumpDemoWith(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  PublicDemoTab tab = PublicDemoTab.employees,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, tab);
}

Key rosterCompensationKey(String engineerId) =>
    Key('public-demo-employee-roster-compensation-$engineerId');

Key ecProjectContextKey(String engineerId) =>
    Key('public-demo-employee-project-context-$engineerId');

/// Advances eng-01 to `partnerInterviewPassed` via the real sales pipeline.
PublicDemoAggregate _advanceToPartnerPassed(PublicDemoAggregate aggregate) {
  var next = aggregate.startSkillSheetReview('eng-01');
  next = next.beginSelling('eng-01');
  next = next.introduceProject('eng-01');
  return next.recordEngineerInterviewResult(
    engineerId: 'eng-01',
    type: PublicDemoInterviewType.partner,
  );
}

/// A real Phase 5 matching proposal for eng-01 against this month's first
/// genuine project candidate.
PublicDemoAggregate _withRealProposal(PublicDemoAggregate aggregate) {
  var next = _advanceToPartnerPassed(aggregate);
  final project = next.projectCandidatesForMonth(next.state.month).first;
  return next.proposeMatch(engineerId: 'eng-01', projectId: project.id);
}

/// Runs eng-01's real Phase 6 project interview to its formula-derived
/// conclusion.
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

/// A genuine, project-bound eng-01 fixture scanned across a bounded seed
/// range until the real formulas produce a client-interview pass — mirrors
/// `public_demo_employee_roster_phase_b1_test.dart`'s own
/// `genuineProjectBackedFixture`.
({PublicDemoAggregate afterInterviewPass, String projectId})?
_genuineInterviewPassFixture({int maxSeed = 40}) {
  for (var seed = 0; seed < maxSeed; seed++) {
    var aggregate = _withRealProposal(PublicDemoAggregate.initial(runSeed: seed));
    final projectId = aggregate.workflow.matchingProposalFor('eng-01')!.projectId;
    aggregate = _runInterviewToConclusion(aggregate);
    final engineer = aggregate.workflow.engineers.firstWhere(
      (e) => e.id == 'eng-01',
    );
    if (engineer.stage == PublicDemoSalesStage.clientInterviewPassed) {
      return (afterInterviewPass: aggregate, projectId: projectId);
    }
  }
  return null;
}

const _targetSizes = <Size>[Size(360, 800), Size(390, 844)];

void main() {
  group('Sales-pipeline card (ec(i)): project context while proposing/'
      'interviewing', () {
    testWidgets(
      'a real Phase 5 proposal (introduced, not yet interviewed) shows '
      '提案中の案件：{real title}（{real client}・月額{real rate}万円）', (tester) async {
        var aggregate = _advanceToPartnerPassed(PublicDemoAggregate.initial());
        final candidate = aggregate.projectCandidatesForMonth(4).first;
        aggregate = aggregate.proposeMatch(
          engineerId: 'eng-01',
          projectId: candidate.id,
        );

        await pumpDemoWith(tester, aggregate);

        final text = tester
            .widget<Text>(find.byKey(ecProjectContextKey('eng-01')))
            .data;
        expect(text, contains('提案中の案件'));
        expect(text, contains(candidate.title));
        expect(text, contains(candidate.clientName));
        expect(text, contains('${candidate.monthlyRate ~/ 10000}万円'));
      },
    );

    testWidgets(
      'no proposal yet (still selling) → no project-context line at all — '
      'nothing has been introduced, never a fabricated placeholder',
      (tester) async {
        var aggregate = PublicDemoAggregate.initial().startSkillSheetReview(
          'eng-01',
        );
        aggregate = aggregate.beginSelling('eng-01');

        await pumpDemoWith(tester, aggregate);

        expect(find.byKey(ecProjectContextKey('eng-01')), findsNothing);
      },
    );

    testWidgets(
      'a genuine client-interview pass (real Phase 6) shows the real '
      'project under the same 提案中の案件 label, using the interview\'s own '
      'project id rather than the (now potentially stale) proposal', (
        tester,
      ) async {
        final fixture = _genuineInterviewPassFixture();
        expect(fixture, isNotNull, reason: 'fixture sanity');
        final aggregate = fixture!.afterInterviewPass;
        final candidate = PublicDemoSeededProjectGenerator.regenerate(
          runSeed: aggregate.state.runSeed,
          projectId: fixture.projectId,
        )!;

        await pumpDemoWith(tester, aggregate);

        final text = tester
            .widget<Text>(find.byKey(ecProjectContextKey('eng-01')))
            .data;
        expect(text, contains('提案中の案件'));
        expect(text, contains(candidate.title));
      },
    );

    testWidgets(
      'ordered but not yet assigned (参画予定) shows 受注案件：{real title} on '
      'the Sales-pipeline card, using the genuine interview project id — '
      'materialization has not happened yet this same month', (tester) async {
        final fixture = _genuineInterviewPassFixture();
        expect(fixture, isNotNull, reason: 'fixture sanity');
        var aggregate = fixture!.afterInterviewPass;
        aggregate = aggregate.recordOrder('eng-01');
        expect(
          aggregate.workflow.assignments.any((a) => a.engineerId == 'eng-01'),
          isFalse,
          reason:
              'fixture sanity: assignOrderedForMay only runs at month-end '
              'close, so no assignment row exists yet this same month',
        );
        final candidate = PublicDemoSeededProjectGenerator.regenerate(
          runSeed: aggregate.state.runSeed,
          projectId: fixture.projectId,
        )!;

        await pumpDemoWith(tester, aggregate);

        final text = tester
            .widget<Text>(find.byKey(ecProjectContextKey('eng-01')))
            .data;
        expect(text, contains('受注案件'));
        expect(text, contains(candidate.title));

        // The roster's own minimal addition for 参画予定 (title + rate,
        // since 単金 itself is still "—" at this not-yet-earning stage).
        final compensation = tester
            .widget<Text>(find.byKey(rosterCompensationKey('eng-01')))
            .data;
        expect(compensation, contains('単金 —'));
        expect(compensation, contains('案件 ${candidate.title}'));
        expect(
          compensation,
          contains('月額${candidate.monthlyRate ~/ 10000}万円'),
        );
      },
    );
  });

  group('assigned (参画中): roster + activeProjectStatusCard + June '
      'assignmentCard all show the same real project identity', () {
    /// eng-01 assigned through the real April→May close flow — mirrors
    /// `public_demo_employee_roster_phase_b1_test.dart`'s own
    /// `genuineProjectBackedFixture`, reproduced here since that helper is
    /// private to its own file.
    ({PublicDemoAggregate aggregate, String projectId})?
    genuineAssignedFixture({int maxSeed = 40}) {
      final fixture = _genuineInterviewPassFixture(maxSeed: maxSeed);
      if (fixture == null) return null;
      var aggregate = fixture.afterInterviewPass.recordOrder('eng-01');
      aggregate = aggregate.closeApril(monthlyExpenses: 0);
      aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 0);
      final assignment = aggregate.workflow.assignments
          .where((a) => a.engineerId == 'eng-01')
          .firstOrNull;
      if (assignment?.projectId != fixture.projectId) return null;
      return (aggregate: aggregate, projectId: fixture.projectId);
    }

    testWidgets(
      '参画中: roster shows 案件 {real title} without repeating the rate '
      '単金 already shows, and the Sales-pipeline card no longer renders '
      'for this engineer at all', (tester) async {
        final fixture = genuineAssignedFixture();
        expect(fixture, isNotNull, reason: 'fixture sanity');
        final aggregate = fixture!.aggregate;
        final candidate = PublicDemoSeededProjectGenerator.regenerate(
          runSeed: aggregate.state.runSeed,
          projectId: fixture.projectId,
        )!;

        await pumpDemoWith(tester, aggregate);

        final compensation = tester
            .widget<Text>(find.byKey(rosterCompensationKey('eng-01')))
            .data;
        expect(
          compensation,
          contains('単金 ${candidate.monthlyRate ~/ 10000}万円'),
        );
        expect(compensation, contains('案件 ${candidate.title}'));
        // No repeated rate parenthetical for the already-assigned case.
        expect(compensation, isNot(contains('（月額')));

        expect(find.byKey(ecProjectContextKey('eng-01')), findsNothing);
      },
    );

    testWidgets(
      'activeProjectStatusCard (Section 3) shows the real Project.title, '
      'not the generic placeholder', (tester) async {
        final fixture = genuineAssignedFixture();
        expect(fixture, isNotNull, reason: 'fixture sanity');
        final aggregate = fixture!.aggregate;
        final candidate = PublicDemoSeededProjectGenerator.regenerate(
          runSeed: aggregate.state.runSeed,
          projectId: fixture.projectId,
        )!;
        expect(
          candidate.title,
          isNot('新規開発支援'),
          reason: 'fixture sanity: a real generated title, not the generic '
              'placeholder, by construction',
        );

        await pumpDemoWith(tester, aggregate);

        expect(
          find.descendant(
            of: find.byKey(
              const Key('public-demo-active-project-status-eng-01'),
            ),
            matching: find.textContaining(candidate.title),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(
              const Key('public-demo-active-project-status-eng-01'),
            ),
            matching: find.textContaining('新規開発支援'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'June\'s assignment-decision card also shows the real project title',
      (tester) async {
        final fixture = genuineAssignedFixture();
        expect(fixture, isNotNull, reason: 'fixture sanity');
        final aggregate = fixture!.aggregate;
        expect(aggregate.state.month, 6);
        final candidate = PublicDemoSeededProjectGenerator.regenerate(
          runSeed: aggregate.state.runSeed,
          projectId: fixture.projectId,
        )!;

        await pumpDemoWith(tester, aggregate, tab: PublicDemoTab.sales);

        expect(find.textContaining(candidate.title), findsWidgets);
      },
    );

    testWidgets('save/reload: the real project title survives a round trip', (
      tester,
    ) async {
      final fixture = genuineAssignedFixture();
      expect(fixture, isNotNull, reason: 'fixture sanity');
      final aggregate = fixture!.aggregate;
      final candidate = PublicDemoSeededProjectGenerator.regenerate(
        runSeed: aggregate.state.runSeed,
        projectId: fixture.projectId,
      )!;

      const codec = PublicDemoSaveCodec();
      final decoded = codec.decode(codec.encode(aggregate));
      expect(decoded, isNotNull, reason: 'fixture sanity: round trip decodes');

      await pumpDemoWith(tester, decoded!);

      expect(
        tester.widget<Text>(find.byKey(rosterCompensationKey('eng-01'))).data,
        contains('案件 ${candidate.title}'),
      );
    });
  });

  group('legacy/generic path (projectId == null): never fabricated, always '
      'the existing generic fallback', () {
    testWidgets(
      'eng-01 ordered+assigned via the generic pipeline only (never real '
      'Phase 5/6 matching) — roster shows no 案件 segment (単金 already "—" '
      'covers this case), activeProjectStatusCard falls back to the '
      'generic PublicDemoAssignment.projectName unchanged', (tester) async {
        var aggregate = PublicDemoAggregate.initial()
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01')
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.partner,
            )
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.client,
            )
            .recordOrder('eng-01');
        aggregate = aggregate.closeApril(monthlyExpenses: 0);
        final assignment = aggregate.workflow.assignments.firstWhere(
          (a) => a.engineerId == 'eng-01',
        );
        expect(
          assignment.projectId,
          isNull,
          reason: 'fixture sanity: the generic evaluateInterview path never '
              'mints a projectId',
        );

        await pumpDemoWith(tester, aggregate);

        final compensation = tester
            .widget<Text>(find.byKey(rosterCompensationKey('eng-01')))
            .data;
        expect(compensation, isNot(contains('案件 ')));

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(
          find.descendant(
            of: find.byKey(
              const Key('public-demo-active-project-status-eng-01'),
            ),
            matching: find.textContaining(assignment.projectName),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('360x800 / 390x844, TextScaler 1.0/1.3: the new project-context '
      'lines never overflow', () {
    for (final size in _targetSizes) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale: Sales-pipeline project-context line + roster 案件 '
          'segment both render with no overflow exception',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            var aggregate = _advanceToPartnerPassed(
              PublicDemoAggregate.initial(),
            );
            final candidate = aggregate.projectCandidatesForMonth(4).first;
            aggregate = aggregate.proposeMatch(
              engineerId: 'eng-01',
              projectId: candidate.id,
            );

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
            expect(find.byKey(ecProjectContextKey('eng-01')), findsOneWidget);
          },
        );
      }
    }
  });
}
