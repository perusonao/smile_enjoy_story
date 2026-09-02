import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_month_guard.dart';

void main() {
  group('PublicDemoMonthGuard (Issue #119 PR1)', () {
    test('July with no bonus decision returns REQUIRED summer-bonus-decision', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 7,
        monthCloseApplicable: true,
        summerBonusDecisionConfirmed: false,
      );
      expect(items, hasLength(1));
      expect(
        items.single.id,
        PublicDemoMonthGuard.summerBonusDecisionItemId,
      );
      expect(items.single.level, PublicDemoMonthGuardLevel.required);
    });

    test('July with bonus decision confirmed returns no required item', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 7,
        monthCloseApplicable: true,
        summerBonusDecisionConfirmed: true,
      );
      expect(items, isEmpty);
    });

    test('non-July months never return a summer-bonus required item', () {
      for (final month in [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15]) {
        final items = PublicDemoMonthGuard.evaluate(
          month: month,
          monthCloseApplicable: true,
          summerBonusDecisionConfirmed: false,
        );
        expect(items, isEmpty, reason: 'month $month must not require it');
      }
    });

    test('month close not applicable (e.g. blocked) yields no items even '
        'in July with an unconfirmed decision', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 7,
        monthCloseApplicable: false,
        summerBonusDecisionConfirmed: false,
      );
      expect(items, isEmpty);
    });

    test(
      'the guard is a pure function of month/applicability/decision-'
      'confirmed only — it takes no success-state parameters (cash, '
      'sales, recruiting, assignment), so it structurally cannot inspect '
      'or require unrelated success state',
      () {
        // This is enforced by the API shape itself: `evaluate` only accepts
        // `month`, `monthCloseApplicable`, and `summerBonusDecisionConfirmed`.
        // Exercise the full boolean matrix to pin that contract down.
        for (final applicable in [true, false]) {
          for (final confirmed in [true, false]) {
            final items = PublicDemoMonthGuard.evaluate(
              month: 7,
              monthCloseApplicable: applicable,
              summerBonusDecisionConfirmed: confirmed,
            );
            final expectRequired = applicable && !confirmed;
            expect(items.isNotEmpty, expectRequired);
          }
        }
      },
    );
  });

  // ===========================================================================
  // Issue #119 remaining scope: the `recommended` level.
  // ===========================================================================
  group('PublicDemoMonthGuard recommended level (Issue #119)', () {
    test('no-task: nothing outstanding and no required decision yields no '
        'items at all', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 9,
        monthCloseApplicable: true,
        summerBonusDecisionConfirmed: true,
        outstandingRecommendedActions: const [],
      );
      expect(items, isEmpty);
    });

    test('recommended-task: each outstanding candidate becomes its own '
        'recommended item, truthfully naming that candidate\'s action', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 9,
        monthCloseApplicable: true,
        summerBonusDecisionConfirmed: true,
        outstandingRecommendedActions: const [
          PublicDemoMonthGuardCandidate(
            id: 'employeeSkillSheetReview:eng-02',
            actionName: '鈴木 一郎のSkillSheetを確認',
          ),
          PublicDemoMonthGuardCandidate(
            id: 'recoveryAssignment:app-01',
            actionName: '高橋 翔を案件へ復帰させる',
          ),
        ],
      );
      expect(items, hasLength(2));
      expect(
        items.every((item) => item.level == PublicDemoMonthGuardLevel.recommended),
        isTrue,
      );
      expect(items[0].id, 'employeeSkillSheetReview:eng-02');
      expect(items[0].message, contains('鈴木 一郎のSkillSheetを確認'));
      expect(items[1].id, 'recoveryAssignment:app-01');
      expect(items[1].message, contains('高橋 翔を案件へ復帰させる'));
    });

    test('required-task: July\'s required item and any recommended '
        'candidates can coexist in the same evaluate() call — the caller '
        'decides how to sequence resolving them, this file only classifies', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 7,
        monthCloseApplicable: true,
        summerBonusDecisionConfirmed: false,
        outstandingRecommendedActions: const [
          PublicDemoMonthGuardCandidate(
            id: 'raiseRequest:app-02',
            actionName: '田中 美咲の昇給要求を確認',
          ),
        ],
      );
      expect(items, hasLength(2));
      expect(
        items.where((i) => i.level == PublicDemoMonthGuardLevel.required),
        hasLength(1),
      );
      expect(
        items.where((i) => i.level == PublicDemoMonthGuardLevel.recommended),
        hasLength(1),
      );
    });

    test('terminal state: month close not applicable suppresses every '
        'item, required and recommended alike', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 9,
        monthCloseApplicable: false,
        summerBonusDecisionConfirmed: true,
        outstandingRecommendedActions: const [
          PublicDemoMonthGuardCandidate(
            id: 'recoveryAssignment:app-01',
            actionName: '高橋 翔を案件へ復帰させる',
          ),
        ],
      );
      expect(items, isEmpty);
    });

    test('an empty outstandingRecommendedActions list is the default, so '
        'every PR1 call site (which never passed it) is unaffected', () {
      final items = PublicDemoMonthGuard.evaluate(
        month: 9,
        monthCloseApplicable: true,
        summerBonusDecisionConfirmed: true,
      );
      expect(items, isEmpty);
    });
  });
}
