// SES SALES-UI-PHASE-1: the 営業タブ is reorganized into four
// information-hierarchy sections — 1) 現在の営業・採用状況
// (`_S._salesOverviewSection`, new), 2) 今やるべき営業アクション
// (`_S._salesNextActionCards` — the recruitment-media card), 3)
// 採用・候補者進捗 (`_S._salesApplicantProgressCards` — the May applicant
// funnel), 4) 案件・参画/継続状況 (`_S._salesProjectStatusCards` — June's
// assignment decision cards and July's closing narrative) — instead of one
// flat "card list, else empty state" body. Every card/key/eligibility check
// is moved verbatim from the prior single flat list (see
// `public_demo_01_home_ui_3c_density_test.dart` for the pre-existing empty-
// state coverage, deliberately left unmodified and still passing unchanged).
//
// Every fixture here is built by chaining the SAME real domain commands
// production code uses — `PublicDemoAggregate.initial()` plus
// `closeApril`/`closeMay`/`closeJune`/`closeJuly`/`closeOrdinaryMonth`/
// `recruit` — matching the established technique in this suite (see
// `public_demo_employee_ui_phase1_test.dart`'s own class doc). No fabricated
// project/candidate/salary data is ever introduced.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

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

const _expense = 10000;

PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

PublicDemoWorkflowState currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

Future<void> pumpSalesTab(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
}

/// April, closed with nobody run through the sales pipeline — the same
/// `publicDemoAggregateAtMonth` recovery-suite helper reaching any month
/// 4-15 with both founding engineers left economically waiting and no
/// applicant/assignment ever created. Used here for the truthful
/// no-action months (April before May exists, August-February, March).
PublicDemoAggregate emptyPipelineAtMonth(int month) =>
    publicDemoAggregateAtMonth(month, monthlyExpenses: _expense);

/// Reaches May before the recruitment-media flow has been used this month.
/// CORE-GAMEPLAY Phase 4.5: [PublicDemoWorkflowState.initial] no longer
/// pre-seeds any applicant, so `workflow.applicants` is genuinely empty here
/// — this fixture exists purely so the recruitment-media CTA itself is
/// still enabled/unused.
PublicDemoAggregate mayBeforeRecruiting() =>
    PublicDemoAggregate.initial().closeApril(monthlyExpenses: _expense);

/// Reaches May with the recruitment-media flow already used once (the
/// `free` medium, the same `PublicDemoAggregate.recruit` command
/// `_openRecruitmentMedia`'s own sheet commits) — the only source of any
/// applicant here, per CORE-GAMEPLAY Phase 4.5.
PublicDemoAggregate mayWithApplicants() {
  final game = mayBeforeRecruiting();
  final recruited = game.recruit(PublicDemoRecruitmentMedium.free);
  expect(
    recruited.isSuccess,
    isTrue,
    reason: 'fixture sanity: April cash must afford the free medium',
  );
  return recruited.aggregate!;
}

/// Sells the first founding engineer through April's real pipeline and
/// closes it — the same chain the pre-existing density suite uses to reach
/// later months with a genuine assignment on the books.
PublicDemoAggregate sellFirstEngineerAndCloseApril(PublicDemoAggregate game) {
  final engineerId = game.workflow.engineers[0].id;
  game = game.startSkillSheetReview(engineerId);
  game = game.beginSelling(engineerId);
  game = game.introduceProject(engineerId);
  game = game.recordEngineerInterviewResult(
    engineerId: engineerId,
    type: PublicDemoInterviewType.partner,
  );
  game = game.recordEngineerInterviewResult(
    engineerId: engineerId,
    type: PublicDemoInterviewType.client,
  );
  game = game.recordOrder(engineerId);
  return game.closeApril(monthlyExpenses: _expense);
}

/// Reaches June with one real, undecided assignment on the books.
PublicDemoAggregate juneWithAssignment() {
  var game = PublicDemoAggregate.initial();
  game = sellFirstEngineerAndCloseApril(game);
  game = game.closeMay(week: 9, monthlyExpenses: _expense);
  return game;
}

/// Reaches July's closing narrative with the one engineer's July
/// continuation already accepted in June. Stops right after `closeJune`
/// (which itself advances the month to 7) — `closeJuly` itself would already
/// advance past the month whose narrative this fixture is meant to show,
/// exactly as the pre-existing density suite's own July fixture does.
PublicDemoAggregate julyWithResult() {
  var game = juneWithAssignment();
  final engineerId = game.workflow.engineers[0].id;
  game = game.withAssignmentUpdate(
    engineerId,
    nextOrderStatus: PublicDemoNextOrderStatus.accepted,
  );
  return game.closeJune(assignedInJuly: 1, monthlyExpenses: _expense);
}

const _overviewKey = Key('public-demo-sales-overview-section');
const _nextActionsKey = Key('public-demo-sales-next-actions-section');
const _applicantProgressKey = Key(
  'public-demo-sales-applicant-progress-section',
);
const _projectStatusKey = Key('public-demo-sales-project-status-section');
const _emptyStateKey = Key('public-demo-sales-empty-state');
const _emptyStateCtaKey = Key('public-demo-sales-empty-state-cta');
const _targetSizes = <Size>[Size(360, 800), Size(390, 844)];

void main() {
  group('Section 1 (現在の営業・採用状況): always renders a truthful overview', () {
    testWidgets(
      'April (before May exists): 営業残 is full capacity, and 候補者/案件 '
      'both read genuinely zero — no fabricated pipeline activity',
      (tester) async {
        final game = emptyPipelineAtMonth(4);
        await pumpSalesTab(tester, game);
        final state = currentState(tester);

        expect(find.byKey(_overviewKey), findsOneWidget);
        expect(
          find.textContaining('営業残 ${state.salesRemaining}回'),
          findsOneWidget,
        );
        expect(find.textContaining('候補者 0名'), findsOneWidget);
        expect(find.textContaining('案件 0件'), findsOneWidget);
      },
    );

    testWidgets(
      'May with real applicants: 候補者 count matches the in-pipeline '
      '(not-yet-joined) applicant count — the same fact ac(i) renders below',
      (tester) async {
        final game = mayWithApplicants();
        await pumpSalesTab(tester, game);
        final workflow = currentWorkflow(tester);
        final pipelineCount = workflow.applicants
            .where((a) => !a.hasJoined)
            .length;
        expect(pipelineCount, greaterThan(0), reason: 'fixture sanity');

        expect(
          find.textContaining('候補者 $pipelineCount名'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'June with a real assignment: 案件 count matches workflow.assignments '
      'and the pending-decision qualifier appears while undecided',
      (tester) async {
        final game = juneWithAssignment();
        await pumpSalesTab(tester, game);
        final workflow = currentWorkflow(tester);
        expect(workflow.assignments.length, 1, reason: 'fixture sanity');

        expect(find.textContaining('案件 1件'), findsOneWidget);
        expect(find.textContaining('うち検討中 1件'), findsOneWidget);
      },
    );
  });

  group('April empty/pre-sales state (before May exists)', () {
    testWidgets(
      'the truthful before-funnel empty state renders under the overview, '
      'and no action/applicant/project section header appears',
      (tester) async {
        final game = emptyPipelineAtMonth(4);
        await pumpSalesTab(tester, game);
        expect(currentState(tester).month, 4);

        expect(find.byKey(_overviewKey), findsOneWidget);
        expect(find.byKey(_emptyStateKey), findsOneWidget);
        expect(find.byKey(_nextActionsKey), findsNothing);
        expect(find.byKey(_applicantProgressKey), findsNothing);
        expect(find.byKey(_projectStatusKey), findsNothing);
      },
    );
  });

  group('May recruitment/applicant state', () {
    testWidgets(
      '今やるべき営業アクション shows the recruitment-media card and '
      '採用・候補者進捗 shows the real applicant funnel — no empty state',
      (tester) async {
        final game = mayWithApplicants();
        await pumpSalesTab(tester, game);
        expect(currentState(tester).month, 5);

        expect(find.byKey(_nextActionsKey), findsOneWidget);
        expect(
          find.byKey(const Key('public-demo-recruitment-media-card')),
          findsOneWidget,
        );
        expect(find.byKey(_applicantProgressKey), findsOneWidget);
        expect(find.byKey(_emptyStateKey), findsNothing);
        expect(find.byKey(_projectStatusKey), findsNothing);
      },
    );

    testWidgets(
      'existing CTA unchanged: the recruitment-media button still opens the '
      'real medium-selection sheet',
      (tester) async {
        final game = mayBeforeRecruiting();
        await pumpSalesTab(tester, game);

        await tester.tap(
          find.byKey(const Key('public-demo-open-recruitment-media')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('public-demo-recruitment-medium-free')),
          findsOneWidget,
          reason: 'the real medium-selection sheet must open',
        );
      },
    );

    testWidgets(
      'existing CTA/eligibility unchanged: スキルシート確認 still advances the '
      'real applicant stage (applied → resumeReviewed) via the unchanged '
      'reviewResume command',
      (tester) async {
        final game = mayWithApplicants();
        await pumpSalesTab(tester, game);
        final applicant = currentWorkflow(tester).applicants.first;
        expect(applicant.stage.name, 'applied', reason: 'fixture sanity');

        await tester.tap(find.text('スキルシート確認').first);
        await tester.pumpAndSettle();

        final updated = currentWorkflow(
          tester,
        ).applicants.firstWhere((a) => a.id == applicant.id);
        expect(updated.stage.name, 'resumeReviewed');
        expect(find.text('書類確認済'), findsWidgets);
      },
    );
  });

  group('June assignment state', () {
    testWidgets(
      '案件・参画/継続状況 shows the real assignment decision card — no '
      'empty state, no applicant-progress section',
      (tester) async {
        final game = juneWithAssignment();
        await pumpSalesTab(tester, game);
        expect(currentState(tester).month, 6);

        expect(find.byKey(_projectStatusKey), findsOneWidget);
        expect(find.text('7月分の発注を確認'), findsOneWidget);
        expect(find.byKey(_emptyStateKey), findsNothing);
        expect(find.byKey(_applicantProgressKey), findsNothing);
      },
    );
  });

  group('July result', () {
    testWidgets(
      '案件・参画/継続状況 shows the closing narrative — no empty state',
      (tester) async {
        final game = julyWithResult();
        await pumpSalesTab(tester, game);
        expect(currentState(tester).month, 7);

        expect(find.byKey(_projectStatusKey), findsOneWidget);
        expect(find.text('7月開始結果'), findsOneWidget);
        expect(find.byKey(_emptyStateKey), findsNothing);
      },
    );
  });

  group('Aug-Feb no-action / employee-routing state', () {
    for (final month in [8, 11, 14]) {
      testWidgets(
        'month $month with nothing outstanding: the truthful empty state '
        'renders under the always-visible overview, and its CTA still '
        'switches to 社員',
        (tester) async {
          final game = emptyPipelineAtMonth(month);
          await pumpSalesTab(tester, game);
          expect(currentState(tester).month, month);

          expect(find.byKey(_overviewKey), findsOneWidget);
          expect(find.byKey(_emptyStateKey), findsOneWidget);
          expect(find.byKey(_nextActionsKey), findsNothing);
          expect(find.byKey(_applicantProgressKey), findsNothing);
          expect(find.byKey(_projectStatusKey), findsNothing);

          await tester.tap(find.byKey(_emptyStateCtaKey));
          await tester.pumpAndSettle();
          final nav = tester.widget<NavigationBar>(
            find.byKey(const Key('public-demo-bottom-nav')),
          );
          expect(nav.selectedIndex, 1, reason: '社員 is tab index 1');
        },
      );
    }
  });

  group('March / month15', () {
    testWidgets(
      'month 15 with nothing outstanding: the same truthful empty state '
      'renders — 営業 introduces no Year-End-specific behavior of its own',
      (tester) async {
        final game = emptyPipelineAtMonth(15);
        await pumpSalesTab(tester, game);
        expect(currentState(tester).month, 15);

        expect(find.byKey(_overviewKey), findsOneWidget);
        expect(find.byKey(_emptyStateKey), findsOneWidget);
      },
    );
  });

  group('360x800 / 390x844, TextScaler 1.3 / 2.0: no horizontal overflow', () {
    for (final size in _targetSizes) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'May (richest content: overview + next-action + applicant '
          'progress) at ${size.width.toInt()}x${size.height.toInt()} / '
          'textScale $textScale',
          (tester) async {
            await pumpSalesTab(
              tester,
              mayWithApplicants(),
              size: size,
              textScale: textScale,
            );

            expect(tester.takeException(), isNull);
            for (final key in [
              _overviewKey,
              _nextActionsKey,
              _applicantProgressKey,
            ]) {
              final rect = tester.getRect(find.byKey(key));
              expect(rect.left, greaterThanOrEqualTo(0.0), reason: '$key');
              expect(
                rect.right,
                lessThanOrEqualTo(size.width),
                reason: '$key',
              );
            }
          },
        );

        testWidgets(
          'August (overview + empty state) at '
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale',
          (tester) async {
            await pumpSalesTab(
              tester,
              emptyPipelineAtMonth(8),
              size: size,
              textScale: textScale,
            );

            expect(tester.takeException(), isNull);
            for (final key in [_overviewKey, _emptyStateKey]) {
              final rect = tester.getRect(find.byKey(key));
              expect(rect.left, greaterThanOrEqualTo(0.0), reason: '$key');
              expect(
                rect.right,
                lessThanOrEqualTo(size.width),
                reason: '$key',
              );
            }
          },
        );
      }
    }
  });

  group('HOME Freeze / Employee UI regression', () {
    testWidgets(
      'switching 社員 → 営業 → ホーム and 営業 → 社員 leaves HOME/社員 exactly '
      'as before — no 営業-only key or section leaks into either',
      (tester) async {
        final game = mayWithApplicants();
        await tester.pumpWidget(
          MaterialApp(
            home: PublicDemo01PlaceholderScreen(
              saveService: _FixedSaveService(game),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(
          find.byKey(const Key('public-demo-employee-roster-section')),
          findsOneWidget,
        );

        await switchPublicDemoTab(tester, PublicDemoTab.sales);
        expect(find.byKey(_overviewKey), findsOneWidget);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(find.byKey(_overviewKey), findsNothing);
        expect(
          find.byKey(const Key('public-demo-employee-roster-section')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('public-demo-important-tasks')),
          findsOneWidget,
        );

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(find.byKey(_overviewKey), findsNothing);
        expect(
          find.byKey(const Key('public-demo-employee-roster-section')),
          findsOneWidget,
        );
      },
    );
  });
}
