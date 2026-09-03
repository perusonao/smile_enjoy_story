// HOME-UI-1C: unit coverage for the read-only home dashboard projection.
//
// `HomeDashboardDisplayData.fromPublicDemoState` is a pure presentation
// projection over the authoritative Public Demo finance state
// (`PublicDemoState`). These tests exercise it against real domain
// fixtures — built via the same production state-transition methods
// (`advanceToMay`/`advanceToJune`) and the real `PublicDemoAggregate`
// command surface — rather than fakes, and assert the specific boundaries
// HOME-UI-1C must not cross: pendingRevenue never folds into cash,
// applicants never leak into employeeCount, and waiting employees never
// leak into assignedEmployeeCount.

import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_month_label.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_revenue.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_dashboard_display_data.dart';

void main() {
  group('year/month projection', () {
    test('April start projects year 1 and the real calendar month label', () {
      final data = HomeDashboardDisplayData.fromPublicDemoState(
        PublicDemoState.aprilStart(),
      );

      expect(data.year, 1);
      expect(data.monthLabel, publicDemoMonthLabel(4));
      expect(data.monthLabel, '4月');
    });

    test(
      'a later internal month (13 = January) reuses the real conversion',
      () {
        final state = PublicDemoState.aprilStart().copyWith(month: 13);

        final data = HomeDashboardDisplayData.fromPublicDemoState(state);

        // Must exactly match the existing authoritative conversion — HOME
        // does not reimplement the internal-month -> calendar-month mapping.
        expect(data.monthLabel, publicDemoMonthLabel(13));
        expect(data.monthLabel, '1月');
      },
    );
  });

  group('cash projection', () {
    test('cash is read verbatim, never recomputed from opening cash', () {
      final state = PublicDemoState.aprilStart().copyWith(cash: 1234567);

      final data = HomeDashboardDisplayData.fromPublicDemoState(state);

      expect(data.cash, 1234567);
      expect(data.cash, state.cash);
    });
  });

  group('revenue projection', () {
    test(
      'revenue uses the existing PublicDemoRevenue formula on engineersAssigned',
      () {
        final state = PublicDemoState.aprilStart().advanceToMay(
          monthlyExpenses: 800000,
          orderedEngineers: 1,
        );
        expect(state.engineersAssigned, 1);

        final data = HomeDashboardDisplayData.fromPublicDemoState(state);

        expect(
          data.revenue,
          PublicDemoRevenue.monthlyRevenueForAssignedCount(
            state.engineersAssigned,
          ),
        );
        expect(data.revenue, greaterThan(0));
      },
    );

    test('zero assigned engineers projects zero revenue', () {
      final data = HomeDashboardDisplayData.fromPublicDemoState(
        PublicDemoState.aprilStart(),
      );

      expect(PublicDemoState.aprilStart().engineersAssigned, 0);
      expect(data.revenue, 0);
    });
  });

  group('pendingRevenue projection', () {
    test('pendingRevenue is read verbatim and never folded into cash', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 500000,
        pendingRevenue: 900000,
      );

      final data = HomeDashboardDisplayData.fromPublicDemoState(state);

      expect(data.pendingRevenue, 900000);
      expect(data.cash, 500000, reason: 'cash must not include pendingRevenue');
      expect(data.cash + 0, isNot(data.cash + data.pendingRevenue));
    });
  });

  group('employeeCount projection', () {
    test('employeeCount is engineerCount, not engineersAssigned/Waiting', () {
      final state = PublicDemoState.aprilStart().copyWith(
        engineerCount: 5,
        engineersAssigned: 2,
        engineersWaiting: 3,
      );

      final data = HomeDashboardDisplayData.fromPublicDemoState(state);

      expect(data.employeeCount, 5);
    });

    test('applicants/candidates never leak into employeeCount', () {
      // A real recruitment purchase adds genuine applicants to the
      // workflow side of the aggregate — employeeCount must stay derived
      // from PublicDemoState.engineerCount alone, which this action never
      // touches.
      var aggregate = PublicDemoAggregate.initial();
      final employeeCountBefore = HomeDashboardDisplayData.fromPublicDemoState(
        aggregate.state,
      ).employeeCount;

      final result = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);
      expect(result.isSuccess, isTrue);
      aggregate = result.aggregate!;
      expect(result.generatedApplicants, isNotEmpty);

      final data = HomeDashboardDisplayData.fromPublicDemoState(
        aggregate.state,
      );

      expect(
        data.employeeCount,
        employeeCountBefore,
        reason:
            'newly generated applicants must not increase employeeCount '
            'before they actually join as employees',
      );
      expect(data.employeeCount, aggregate.state.engineerCount);
    });
  });

  group('assignedEmployeeCount projection', () {
    test('assignedEmployeeCount excludes waiting employees', () {
      final state = PublicDemoState.aprilStart().copyWith(
        engineerCount: 4,
        engineersAssigned: 1,
        engineersWaiting: 3,
      );

      final data = HomeDashboardDisplayData.fromPublicDemoState(state);

      expect(data.assignedEmployeeCount, 1);
      expect(data.assignedEmployeeCount, isNot(state.engineerCount));
      expect(data.assignedEmployeeCount, isNot(state.engineersWaiting));
    });

    test('assignedEmployeeCount reflects a real May close, not a UI guess', () {
      final state = PublicDemoState.aprilStart().advanceToMay(
        monthlyExpenses: 800000,
        orderedEngineers: 1,
      );

      final data = HomeDashboardDisplayData.fromPublicDemoState(state);

      expect(data.assignedEmployeeCount, state.engineersAssigned);
      expect(data.assignedEmployeeCount, 1);
      expect(state.engineersWaiting, 1);
    });
  });

  group('monthGoalText — July (7) through March (15)', () {
    // SES-FIRST-FUN-YEAR-P0-1 (Issue #125): before this change, every one
    // of these nine months collapsed onto the same generic fallback line.
    // This guards that regression directly rather than only asserting each
    // month's own text.
    const genericFallback = '今月の経営状況を確認し、翌月への準備をしましょう';

    const expectedByMonth = {
      7: '夏季賞与の対応を終えたら、待機中の技術者がいれば案件復帰できないか確認しましょう',
      8: '今月の営業活動の状況と、待機中の技術者がいないか確認しましょう',
      9: '下半期に入りました。資金の増減と案件の稼働状況を見直しましょう',
      10: '案件の稼働状況を確認し、待機中の技術者がいれば案件復帰を検討しましょう',
      11: '資金の増減を確認し、年度末までの運転資金を意識しましょう',
      12: '年内最後の月です。ここまでの稼働状況と資金の推移を振り返りましょう',
      13: '年度末まで残り3か月。案件と待機中の技術者の状況を点検しましょう',
      14: '待機中の技術者を案件へ戻せる最後の月です。復帰できないか確認しましょう',
      15: '年度末の月です。今月の締めで一年間の経営結果が確定します',
    };

    for (final entry in expectedByMonth.entries) {
      test('month ${entry.key} projects its own month-specific goal', () {
        final state = PublicDemoState.aprilStart().copyWith(month: entry.key);

        final data = HomeDashboardDisplayData.fromPublicDemoState(state);

        expect(data.monthGoalText, entry.value);
        expect(
          data.monthGoalText,
          isNot(genericFallback),
          reason:
              'month ${entry.key} must not fall back to the single '
              'generic July-March placeholder',
        );
      });
    }

    test('no two months among July-March share the same text', () {
      final texts = expectedByMonth.values.toSet();

      expect(
        texts.length,
        expectedByMonth.length,
        reason: 'each of the nine months must have distinct guidance',
      );
    });

    test(
      'July-March never point at recruitment media or contract renewal',
      () {
        // Issue #125 scope: recruitment media's own UI never reappears
        // after May and no transition past advanceToJune ever increases
        // engineerCount, so a July-March hint that names hiring/media
        // would point at a structurally unreachable path. Likewise there
        // is no per-month assignment-renewal decision to point at.
        for (final entry in expectedByMonth.entries) {
          final state = PublicDemoState.aprilStart().copyWith(
            month: entry.key,
          );
          final text = HomeDashboardDisplayData.fromPublicDemoState(
            state,
          ).monthGoalText;

          expect(text, isNot(contains('求人')));
          expect(text, isNot(contains('採用')));
          expect(text, isNot(contains('更新')));
        }
      },
    );
  });

  group('monthGoalText — April-June unaffected by the July-March table', () {
    test('April, May, June keep their existing pre-P0-1 text', () {
      const expectedByMonth = {
        4: '待機中の技術者を営業し、5月の案件参画を決めましょう',
        5: '応募者を採用し、入社前から6月の案件獲得を目指しましょう',
        6: '翌月の発注を確認し、7月も稼働できる状態を作りましょう',
      };

      for (final entry in expectedByMonth.entries) {
        final state = PublicDemoState.aprilStart().copyWith(month: entry.key);
        final data = HomeDashboardDisplayData.fromPublicDemoState(state);
        expect(data.monthGoalText, entry.value);
      }
    });
  });

  group('projection does not mutate domain state', () {
    test('building the projection twice from the same state agrees', () {
      final state = PublicDemoState.aprilStart().advanceToMay(
        monthlyExpenses: 800000,
        orderedEngineers: 1,
      );

      final first = HomeDashboardDisplayData.fromPublicDemoState(state);
      final second = HomeDashboardDisplayData.fromPublicDemoState(state);

      expect(first, second);
      // The source state itself is untouched by projecting it.
      expect(state.cash, PublicDemoState.aprilStart().cash - 800000);
      expect(state.engineersAssigned, 1);
    });
  });
}
