// Issue #243 FIRST-FUN-YEAR P1: Month-start Status / Recommended Action —
// May/June founding engineer action gap.
//
// Fresh Audit source (SSOT for this fix):
// docs/reports/SES_FIRST-FUN-YEAR_Month-Start-Status-Recommended-Action_Fresh-Audit.md
// §5 Finding 1.
//
// Root cause: a founding engineer who does not reach `ordered` inside April
// had no `ec(i)` render site at all in May, and June only rendered it for a
// later-joined hire (`s.joinedApplicantIds`) — leaving that engineer with
// zero interactive control and zero HOME/Month-Guard recommended signal for
// two full months, resurfacing only once RECOVERY-LOOP-1's July window
// opened. Fixed by widening `_employeeNextActionsSection`'s `ec(i)` render
// gate, `_recommendedActionCandidates`'s matching engineer-stage loop, and
// `_fieldSalesActionReachableThisMonth` to cover May and June for any
// engineer not yet `ordered` and not currently assigned (the same filter
// shape RECOVERY-LOOP-1's own July-February loop already uses).
//
// This suite drives the real screen/domain via a fixed save-service
// fixture built by chaining real `PublicDemoAggregate` commands from
// `initial()` — never the interview mini-game UI (whose pass/fail an
// unseeded run cannot pin) — the same technique
// `public_demo_01_month_guard_recommended_test.dart` and
// `public_demo_issue231_employee_skillsheet_clarity_test.dart` already use.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_recommended_action.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';
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

final _expense = PublicDemoSalary.baselineMonthlyExpenses;

Future<void> _pump(WidgetTester tester, PublicDemoAggregate aggregate) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PublicDemoState _currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Finder get _sectionFinder => find.byType(PublicDemoHomeDashboardSection);

HomeRecommendedActionSlot _slot(WidgetTester tester) => tester
    .widget<PublicDemoHomeDashboardSection>(_sectionFinder)
    .recommendedAction;

/// The action currently recommended, or `null` when the slot is a fallback
/// or suppressed — mirrors `public_demo_01_home_recommended_action_test.dart`'s
/// own `recommended` helper.
HomeRecommendedAction? _recommended(WidgetTester tester) {
  final s = _slot(tester);
  return s is HomeRecommendedActionAvailable ? s.candidate.action : null;
}

Key _rosterRowKey(String engineerId) =>
    Key('public-demo-employee-roster-row-$engineerId');

/// Advances eng-01 through the real sales-pipeline domain commands up to
/// (but not including) [stopBefore] — never past it — leaving [game] at
/// whatever stage that implies. `null` leaves eng-01 untouched at `waiting`.
enum _StopAt { skillSheet, selling, introduced, partnerInterviewPassed }

PublicDemoAggregate _sellEng01To(PublicDemoAggregate game, _StopAt? stopAt) {
  if (stopAt == null) return game;
  final id = game.workflow.engineers[0].id;
  game = game.startSkillSheetReview(id);
  if (stopAt == _StopAt.skillSheet) return game;
  game = game.beginSelling(id);
  if (stopAt == _StopAt.selling) return game;
  game = game.introduceProject(id);
  if (stopAt == _StopAt.introduced) return game;
  game = game.recordEngineerInterviewResult(
    engineerId: id,
    type: PublicDemoInterviewType.partner,
  );
  return game;
}

/// Sells eng-01 all the way to `ordered` via the real domain commands —
/// never the interview mini-game UI.
PublicDemoAggregate _sellEng01ToOrdered(PublicDemoAggregate game) {
  final id = game.workflow.engineers[0].id;
  game = _sellEng01To(game, _StopAt.partnerInterviewPassed);
  game = game.recordEngineerInterviewResult(
    engineerId: id,
    type: PublicDemoInterviewType.client,
  );
  return game.recordOrder(id);
}

/// Recruits, interviews, and accepts an offer for the first generated
/// applicant in whatever month [game] is currently at — mirrors
/// `public_demo_post_may_join_lifecycle_test.dart`'s own `recruitAndAccept`
/// fixture. `acceptanceScore: 100` always accepts regardless of the
/// generated applicant's own seed-dependent score.
({PublicDemoAggregate aggregate, String applicantId}) _recruitAndAccept(
  PublicDemoAggregate game,
) {
  final recruited = game.recruit(PublicDemoRecruitmentMedium.engineer);
  expect(recruited.isSuccess, isTrue);
  var next = recruited.aggregate!;
  final applicantId = next.workflow.applicants.first.id;
  final interview = next.completeInterview(applicantId);
  expect(interview.isCompleted, isTrue);
  next = interview.aggregate;
  final applicant = next.workflow.applicants.firstWhere(
    (candidate) => candidate.id == applicantId,
  );
  final offer = PublicDemoSalaryOffer(
    requestedMonthlySalary: applicant.requestedMonthlySalary,
    offeredMonthlySalary: applicant.requestedMonthlySalary,
    acceptanceScore: 100,
    motivationDelta: 0,
    trustDelta: 0,
  );
  final beforeAccept = next.state.month;
  next = next.acceptOffer(
    applicantId: applicantId,
    offer: offer,
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(beforeAccept),
  );
  return (aggregate: next, applicantId: applicantId);
}

void main() {
  group('Fresh April regression (unaffected)', () {
    testWidgets(
      'April: the untouched founding engineer still opens on '
      'employeeSkillSheetReview, exactly as before this Issue',
      (tester) async {
        final game = PublicDemoAggregate.initial();
        await _pump(tester, game);

        expect(_currentState(tester).month, 4);
        final action = _recommended(tester);
        expect(action, isNotNull);
        expect(action!.kind, HomeRecommendedActionKind.employeeSkillSheetReview);
        expect(action.targetId, game.workflow.engineers[0].id);
      },
    );
  });

  group('May: a founding engineer stuck mid-pipeline now has a real action '
      '(Fresh Audit Finding 1)', () {
    testWidgets('waiting + sales-ready: employeeSkillSheetReview', (
      tester,
    ) async {
      final game = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: _expense,
      );
      expect(game.state.month, 5);
      await _pump(tester, game);

      final action = _recommended(tester);
      expect(action, isNotNull);
      expect(action!.kind, HomeRecommendedActionKind.employeeSkillSheetReview);
      expect(action.targetId, game.workflow.engineers[0].id);

      // Roster truthfulness: `営業可能` now appears because a reachable
      // control genuinely exists (the 社員 tab's own `ec(i)` card).
      await switchPublicDemoTab(tester, PublicDemoTab.employees);
      expect(
        find.descendant(
          of: find.byKey(_rosterRowKey(game.workflow.engineers[0].id)),
          matching: find.text('営業可能'),
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'スキルシート確認'), findsOneWidget);
    });

    for (final entry in {
      _StopAt.skillSheet: HomeRecommendedActionKind.employeeBeginSelling,
      _StopAt.selling: HomeRecommendedActionKind.employeeIntroduceProject,
      _StopAt.introduced: HomeRecommendedActionKind.employeePartnerInterview,
      _StopAt.partnerInterviewPassed:
          HomeRecommendedActionKind.employeeClientInterview,
    }.entries) {
      testWidgets('${entry.key.name} stage: ${entry.value.name}', (
        tester,
      ) async {
        var game = PublicDemoAggregate.initial();
        game = _sellEng01To(game, entry.key);
        game = game.closeApril(monthlyExpenses: _expense);
        expect(game.state.month, 5);
        await _pump(tester, game);

        final action = _recommended(tester);
        expect(action, isNotNull);
        expect(action!.kind, entry.value);
        expect(action.targetId, game.workflow.engineers[0].id);
      });
    }
  });

  group('June: a founding engineer still not ordered gets the same '
      'widened action (Fresh Audit Finding 1)', () {
    testWidgets('waiting + sales-ready: employeeSkillSheetReview', (
      tester,
    ) async {
      final game = publicDemoAggregateAtMonth(6);
      expect(game.state.month, 6);
      await _pump(tester, game);

      final action = _recommended(tester);
      expect(action, isNotNull);
      expect(action!.kind, HomeRecommendedActionKind.employeeSkillSheetReview);
      expect(action.targetId, game.workflow.engineers[0].id);
    });

    testWidgets(
      'a joined applicant not yet ordered — existing behavior unchanged',
      (tester) async {
        var game = PublicDemoAggregate.initial().closeApril(
          monthlyExpenses: _expense,
        );
        final hired = _recruitAndAccept(game);
        game = hired.aggregate.closeMay(week: 9, monthlyExpenses: _expense);
        expect(game.state.month, 6);
        final applicant = game.workflow.applicants.firstWhere(
          (a) => a.id == hired.applicantId,
        );
        expect(applicant.hasJoined, isTrue);
        expect(
          game.workflow.engineers
              .firstWhere((e) => e.id == hired.applicantId)
              .stage,
          PublicDemoSalesStage.waiting,
        );

        await _pump(tester, game);

        // A just-joined applicant is also immediately raise-request
        // eligible (`canRequestRaiseIn`, unrelated to this Issue), and that
        // candidate outranks the sales-pipeline one — HOME's single
        // Recommended Action slot is not the right place to observe this
        // population's own `ec(i)` reachability, so check the 社員 tab's
        // render site directly instead, exactly as before this Issue: the
        // old month-6 `joinedApplicantIds`-only loop already rendered this
        // same `スキルシート確認` button for this same population (now one
        // of two, since eng-01, untouched, also renders one — Finding 1's
        // own fix — not a regression for this joined applicant's own
        // card).
        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(
          find.widgetWithText(FilledButton, 'スキルシート確認'),
          findsNWidgets(2),
        );
        expect(
          find.descendant(
            of: find.byKey(_rosterRowKey(hired.applicantId)),
            matching: find.text('営業可能'),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('ordered/assigned engineers never get an invalid or duplicate '
      'candidate in May/June', () {
    testWidgets(
      'ordered-but-not-yet-assigned (ordered placed mid-May): no '
      'sales-pipeline candidate for them; roster reads 参画予定',
      (tester) async {
        var game = PublicDemoAggregate.initial().closeApril(
          monthlyExpenses: _expense,
        );
        expect(game.state.month, 5);
        // Sell fully to `ordered` from inside May itself — an order placed
        // mid-May is never auto-assigned before a later close, so this
        // engineer is genuinely ordered/not-assigned while still in May.
        game = _sellEng01ToOrdered(game);
        final id = game.workflow.engineers[0].id;
        expect(
          game.workflow.engineers.firstWhere((e) => e.id == id).stage,
          PublicDemoSalesStage.ordered,
        );
        expect(game.workflow.assignments.any((a) => a.engineerId == id), isFalse);

        await _pump(tester, game);

        final action = _recommended(tester);
        // Whatever the slot resolves to (a fallback, or eng-02/recruitment
        // media), it must never target the already-ordered engineer with a
        // sales-pipeline kind.
        if (action != null && action.targetId == id) {
          expect(
            action.kind,
            isNot(
              anyOf(
                HomeRecommendedActionKind.employeeSkillSheetReview,
                HomeRecommendedActionKind.employeeBeginSelling,
                HomeRecommendedActionKind.employeeIntroduceProject,
                HomeRecommendedActionKind.employeePartnerInterview,
                HomeRecommendedActionKind.employeeClientInterview,
                HomeRecommendedActionKind.employeeAcceptOrder,
                HomeRecommendedActionKind.employeeResumeSelling,
              ),
            ),
          );
        }

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(
          find.descendant(
            of: find.byKey(_rosterRowKey(id)),
            matching: find.text('参画予定'),
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'スキルシート確認'), findsNothing);
        expect(find.widgetWithText(FilledButton, '受注'), findsNothing);
      },
    );

    testWidgets(
      'assigned (sold fully within April, assigned for May via '
      'assignOrderedForMay): no sales-pipeline candidate for them; roster '
      'reads 参画中',
      (tester) async {
        var game = PublicDemoAggregate.initial();
        game = _sellEng01ToOrdered(game);
        game = game.closeApril(monthlyExpenses: _expense);
        expect(game.state.month, 5);
        final id = game.workflow.engineers[0].id;
        expect(
          game.workflow.engineers.firstWhere((e) => e.id == id).stage,
          PublicDemoSalesStage.ordered,
        );
        expect(
          game.workflow.assignedEngineerIds(month: game.state.month),
          contains(id),
        );

        await _pump(tester, game);

        final action = _recommended(tester);
        if (action != null && action.targetId == id) {
          expect(
            action.kind,
            isNot(
              anyOf(
                HomeRecommendedActionKind.employeeSkillSheetReview,
                HomeRecommendedActionKind.employeeBeginSelling,
                HomeRecommendedActionKind.employeeIntroduceProject,
                HomeRecommendedActionKind.employeePartnerInterview,
                HomeRecommendedActionKind.employeeClientInterview,
                HomeRecommendedActionKind.employeeAcceptOrder,
                HomeRecommendedActionKind.employeeResumeSelling,
              ),
            ),
          );
        }

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(
          find.descendant(
            of: find.byKey(_rosterRowKey(id)),
            matching: find.text('参画中'),
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'スキルシート確認'), findsNothing);
      },
    );
  });

  group('July onward: RECOVERY-LOOP-1 is unaffected, no double emission', () {
    testWidgets(
      'a still-waiting engineer in August gets exactly one recommended '
      'action, the same RECOVERY-LOOP-1 candidate as before this Issue',
      (tester) async {
        final game = publicDemoAggregateAtMonth(8);
        expect(game.state.month, 8);
        await _pump(tester, game);

        final action = _recommended(tester);
        expect(action, isNotNull);
        expect(action!.kind, HomeRecommendedActionKind.employeeSkillSheetReview);
        expect(action.targetId, game.workflow.engineers[0].id);

        // Only one card for this engineer's own action on 社員 — no
        // double emission from May/June's widened loop bleeding into July+.
        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(find.widgetWithText(FilledButton, 'スキルシート確認'), findsOneWidget);
      },
    );
  });

  group('Month Guard: the recommended-level warning now includes this '
      'population in May/June', () {
    testWidgets(
      'closing May with eng-01 stuck at waiting(ready) shows the '
      'recommended-level warning naming the outstanding SkillSheet review',
      (tester) async {
        final game = PublicDemoAggregate.initial().closeApril(
          monthlyExpenses: _expense,
        );
        expect(game.state.month, 5);
        await _pump(tester, game);

        final cta = find.byKey(const Key('public-demo-monthly-primary-cta'));
        await tester.ensureVisible(cta);
        await tester.pumpAndSettle();
        await tester.tap(cta);
        await tester.pumpAndSettle();

        final dialog = find.byKey(
          const Key('public-demo-month-guard-warning-dialog'),
        );
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(of: dialog, matching: find.textContaining('が未対応です')),
          findsOneWidget,
        );
        // The month has NOT advanced while the warning is open.
        expect(_currentState(tester).month, 5);
      },
    );
  });

  group('save/reload around the month transition preserves truthfulness', () {
    test(
      'a May, mid-pipeline aggregate round-trips through the save codec '
      'with the same stage and the same recommendable fact',
      () {
        const codec = PublicDemoSaveCodec();
        var game = PublicDemoAggregate.initial();
        game = _sellEng01To(game, _StopAt.skillSheet);
        game = game.closeApril(monthlyExpenses: _expense);
        expect(game.state.month, 5);
        final id = game.workflow.engineers[0].id;

        final restored = codec.decode(codec.encode(game));
        expect(restored, isNotNull);
        expect(restored!.state.month, 5);
        expect(
          restored.workflow.engineers.firstWhere((e) => e.id == id).stage,
          PublicDemoSalesStage.skillSheet,
        );
      },
    );
  });

  group('360x800 / 390x844, TextScaler 1.0 / 1.3: the widened May/June '
      '社員 tab renders with no overflow', () {
    const targetSizes = <Size>[Size(360, 800), Size(390, 844)];
    for (final size in targetSizes) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale: May, both founding engineers mid-pipeline (one '
          'stuck at waiting, one at selling) — no RenderFlex/RenderBox '
          'overflow exception',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            var game = PublicDemoAggregate.initial();
            final secondId = game.workflow.engineers[1].id;
            game = game.startSkillSheetReview(secondId);
            game = game.beginSelling(secondId);
            game = game.closeApril(monthlyExpenses: _expense);
            expect(game.state.month, 5);

            await tester.pumpWidget(
              MaterialApp(
                theme: SesTheme.build(),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: PublicDemo01PlaceholderScreen(
                    saveService: _FixedSaveService(game),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await switchPublicDemoTab(tester, PublicDemoTab.employees);

            expect(
              tester.takeException(),
              isNull,
              reason: 'a RenderFlex/RenderBox overflow at an enlarged '
                  'TextScaler surfaces as a FlutterError here',
            );
          },
        );
      }
    }
  });
}
