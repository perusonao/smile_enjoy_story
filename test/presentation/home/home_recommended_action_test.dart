// HOME-RUNTIME-2C: the pure half of the Recommended Action — the typed
// vocabulary and the presentation ranking.
//
// Everything here is deliberately fixture-driven, because everything here
// is deliberately free of game rules: the selector's whole contract is
// "given candidates, always pick the same one", and proving that needs no
// aggregate. The other half of the contract — that the candidates handed to
// it are exactly the actions on screen — is a property of the owner, and is
// pinned against the real screen in
// `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_recommended_action.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/recommended_action_section.dart';

HomeRecommendedActionCandidate candidate(
  HomeRecommendedActionKind kind, {
  String? subjectName,
  String? targetId,
  void Function()? invoke,
}) => HomeRecommendedActionCandidate(
  action: HomeRecommendedAction(
    kind: kind,
    subjectName: subjectName,
    targetId: targetId,
  ),
  invoke: invoke ?? () {},
);

void main() {
  group('recommended action layout', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      testWidgets('a two-line action headline and CTA fit at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecommendedActionSection(
                slot: HomeRecommendedActionAvailable(
                  candidate(
                    HomeRecommendedActionKind.employeeSkillSheetReview,
                    subjectName: '非常に長い氏名を持つ社員の推薦アクション表示テスト担当者',
                  ),
                ),
                monthGoalText: '',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final headline = tester.getRect(
          find.byKey(const Key('home-recommended-action-headline')),
        );
        final cta = tester.getRect(
          find.byKey(const Key('home-recommended-action-cta')),
        );
        expect(headline.height, greaterThan(20));
        expect(headline.right, lessThanOrEqualTo(size.width));
        expect(cta.right, lessThanOrEqualTo(size.width));
        expect(cta.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('presentation priority', () {
    test('every kind has a distinct priority, so the order is total', () {
      final priorities = HomeRecommendedActionKind.values
          .map((k) => k.presentationPriority)
          .toList();
      expect(
        priorities.toSet().length,
        priorities.length,
        reason:
            'two kinds sharing a rank would make selection depend on '
            'emission order across unrelated pipelines',
      );
    });

    test('the design table\'s bands are preserved exactly', () {
      int rank(HomeRecommendedActionKind k) => k.presentationPriority;

      // P0 outranks everything.
      expect(
        rank(HomeRecommendedActionKind.cashShortageResponse),
        lessThan(10),
      );

      // P1: the deadline/response pair, below P0 and above every P2.
      for (final k in [
        HomeRecommendedActionKind.summerBonusDecision,
        HomeRecommendedActionKind.raiseRequest,
      ]) {
        expect(rank(k), greaterThan(9));
        expect(rank(k), lessThan(20));
      }

      // P2: the four engineer rows the design names.
      for (final k in [
        HomeRecommendedActionKind.employeeAcceptOrder,
        HomeRecommendedActionKind.employeePartnerInterview,
        HomeRecommendedActionKind.employeeBeginSelling,
        HomeRecommendedActionKind.employeeSkillSheetReview,
      ]) {
        expect(rank(k), greaterThan(19));
        expect(rank(k), lessThan(50));
      }

      // P3: the two supporting rows the design names.
      for (final k in [
        HomeRecommendedActionKind.assignmentConfirmNextOrder,
        HomeRecommendedActionKind.recruitmentMedia,
      ]) {
        expect(rank(k), greaterThan(49));
      }
      // ...and the design's own P3 ordering within the band.
      expect(
        rank(HomeRecommendedActionKind.assignmentConfirmNextOrder),
        lessThan(rank(HomeRecommendedActionKind.recruitmentMedia)),
      );
    });

    test('an already-started pipeline outranks starting a new one', () {
      // The brief's rule, applied inside the P2 band: each step that is
      // closer to completing the engineer's sales pipeline outranks the
      // step before it.
      const descending = [
        HomeRecommendedActionKind.employeeAcceptOrder,
        HomeRecommendedActionKind.employeeClientInterview,
        HomeRecommendedActionKind.employeePartnerInterview,
        HomeRecommendedActionKind.employeeIntroduceProject,
        HomeRecommendedActionKind.employeeResumeSelling,
        HomeRecommendedActionKind.employeeBeginSelling,
        HomeRecommendedActionKind.employeeSkillSheetReview,
      ];
      for (var i = 1; i < descending.length; i++) {
        expect(
          descending[i - 1].presentationPriority,
          lessThan(descending[i].presentationPriority),
          reason:
              '${descending[i - 1].name} must outrank ${descending[i].name}',
        );
      }

      // Same rule down the pre-entry pipeline.
      const preEntryDescending = [
        HomeRecommendedActionKind.applicantJuneOrder,
        HomeRecommendedActionKind.applicantClientInterview,
        HomeRecommendedActionKind.applicantPartnerInterview,
        HomeRecommendedActionKind.applicantIntroduceProject,
        HomeRecommendedActionKind.applicantBeginPreEntrySelling,
        HomeRecommendedActionKind.applicantBeginPreEntrySkillSheet,
        HomeRecommendedActionKind.applicantSalaryOffer,
        HomeRecommendedActionKind.applicantInterview,
        HomeRecommendedActionKind.applicantReviewResume,
      ];
      for (var i = 1; i < preEntryDescending.length; i++) {
        expect(
          preEntryDescending[i - 1].presentationPriority,
          lessThan(preEntryDescending[i].presentationPriority),
        );
      }
    });

    test(
      'the month close and internal training are not recommendable at all',
      () {
        final names = HomeRecommendedActionKind.values.map((k) => k.name);
        expect(names, isNot(contains('monthClose')));
        expect(names, isNot(contains('internalTraining')));
      },
    );
  });

  // ===========================================================================
  // Issue #119 PLAYTHROUGH-BLOCKER-2: `isInformational` and the one
  // deliberate priority exception it motivates.
  // ===========================================================================
  group('informational classification (Issue #119)', () {
    test('cashShortageResponse is the only informational kind', () {
      for (final kind in HomeRecommendedActionKind.values) {
        expect(
          kind.isInformational,
          kind == HomeRecommendedActionKind.cashShortageResponse,
          reason:
              '${kind.name}.isInformational must be '
              '${kind == HomeRecommendedActionKind.cashShortageResponse}',
        );
      }
    });

    test(
      'recoveryAssignment is the one kind ranked above cashShortageResponse',
      () {
        expect(
          HomeRecommendedActionKind.recoveryAssignment.presentationPriority,
          lessThan(
            HomeRecommendedActionKind.cashShortageResponse.presentationPriority,
          ),
        );
        for (final kind in HomeRecommendedActionKind.values) {
          if (kind == HomeRecommendedActionKind.recoveryAssignment) continue;
          expect(
            kind.presentationPriority,
            greaterThanOrEqualTo(
              HomeRecommendedActionKind
                  .cashShortageResponse
                  .presentationPriority,
            ),
            reason:
                '${kind.name} must not also outrank cashShortageResponse — '
                'only recoveryAssignment is a deliberate exception',
          );
        }
      },
    );

    test('selection: a genuine Recovery candidate wins over the informational '
        'shortage card even though it is P0 by design', () {
      final shortage = candidate(
        HomeRecommendedActionKind.cashShortageResponse,
      );
      final recovery = candidate(
        HomeRecommendedActionKind.recoveryAssignment,
        subjectName: '佐藤 健',
      );
      for (final order in [
        [shortage, recovery],
        [recovery, shortage],
      ]) {
        expect(selectHomeRecommendedAction(order), same(recovery));
      }
    });
  });

  group('selection', () {
    test('no candidates selects nothing', () {
      expect(selectHomeRecommendedAction(const []), isNull);
    });

    test(
      'the highest-priority candidate wins regardless of emission order',
      () {
        final low = candidate(HomeRecommendedActionKind.recruitmentMedia);
        final high = candidate(HomeRecommendedActionKind.cashShortageResponse);
        final mid = candidate(HomeRecommendedActionKind.employeeBeginSelling);

        for (final order in [
          [low, high, mid],
          [high, mid, low],
          [mid, low, high],
        ]) {
          expect(selectHomeRecommendedAction(order), same(high));
        }
      },
    );

    test('ties break on emission order, and only on emission order', () {
      final first = candidate(
        HomeRecommendedActionKind.employeeSkillSheetReview,
        subjectName: '佐藤 健',
        targetId: 'eng-01',
      );
      final second = candidate(
        HomeRecommendedActionKind.employeeSkillSheetReview,
        subjectName: '鈴木 一郎',
        targetId: 'eng-02',
      );
      expect(selectHomeRecommendedAction([first, second]), same(first));
      expect(selectHomeRecommendedAction([second, first]), same(second));
    });

    test('selection is deterministic across repeated calls', () {
      final candidates = [
        candidate(HomeRecommendedActionKind.recruitmentMedia),
        candidate(
          HomeRecommendedActionKind.employeePartnerInterview,
          subjectName: '佐藤 健',
        ),
        candidate(
          HomeRecommendedActionKind.employeeSkillSheetReview,
          subjectName: '鈴木 一郎',
        ),
        candidate(HomeRecommendedActionKind.raiseRequest, subjectName: '田中'),
      ];
      final first = selectHomeRecommendedAction(candidates);
      for (var i = 0; i < 20; i++) {
        expect(selectHomeRecommendedAction(candidates), same(first));
      }
      expect(first!.action.kind, HomeRecommendedActionKind.raiseRequest);
    });

    test('the selected candidate carries the owner handler unchanged', () {
      var ran = 0;
      final selected = selectHomeRecommendedAction([
        candidate(HomeRecommendedActionKind.recruitmentMedia),
        candidate(
          HomeRecommendedActionKind.employeeAcceptOrder,
          invoke: () => ran++,
        ),
      ]);
      expect(ran, 0);
      selected!.invoke();
      expect(ran, 1);
    });
  });

  group('labels', () {
    test('a subject-specific headline names the person', () {
      const action = HomeRecommendedAction(
        kind: HomeRecommendedActionKind.employeeSkillSheetReview,
        subjectName: '佐藤 健',
        targetId: 'eng-01',
      );
      expect(action.headline, '佐藤 健のスキルシートを確認');
      expect(action.ctaLabel, 'スキルシートを確認');
      expect(action.kind.isSubjectSpecific, isTrue);
    });

    test('a company-level headline carries no placeholder', () {
      const action = HomeRecommendedAction(
        kind: HomeRecommendedActionKind.recruitmentMedia,
      );
      expect(action.headline, '求人媒体で候補者を追加');
      expect(action.kind.isSubjectSpecific, isFalse);
    });

    test('no kind can render a leftover placeholder or an empty label', () {
      for (final kind in HomeRecommendedActionKind.values) {
        expect(kind.ctaLabel, isNotEmpty, reason: kind.name);
        expect(kind.headlineFor('佐藤 健'), isNot(contains('{name}')));
        expect(kind.headlineFor('佐藤 健'), isNotEmpty, reason: kind.name);
        if (!kind.isSubjectSpecific) {
          expect(kind.headlineFor(null), isNot(contains('{name}')));
        }
      }
    });

    test('no CTA label is byte-identical to a legacy Public Demo control', () {
      // The HOME shortcut and the control it leads to are on screen
      // together; a player must be able to tell them apart.
      const legacy = {
        'SkillSheet確認',
        '営業開始',
        '案件紹介',
        '上位会社面談',
        '客先面談',
        '受注',
        '再営業',
        '経歴書確認',
        '採用面談',
        '合格・給与提示',
        '入社前SkillSheet',
        '入社前営業',
        '6月受注',
        '7月分の発注を確認',
        '受注する',
        '次案件の営業開始',
        '上位会社面談（1枠）',
        '客先面談（0枠）',
        '別案件へ',
        '7月分を受注',
        '昇給要求を確認',
        '夏季賞与を決める',
        '夏季賞与を変更',
        '求人媒体を選ぶ',
        '今月は利用済み',
        'この方法で募集する',
        '研修する',
        '確認',
        '給与を提示',
      };
      for (final kind in HomeRecommendedActionKind.values) {
        expect(
          legacy,
          isNot(contains(kind.ctaLabel)),
          reason: '${kind.name} reuses an existing control\'s label',
        );
      }
    });
  });

  group('equality', () {
    test('the descriptor is a value type', () {
      const a = HomeRecommendedAction(
        kind: HomeRecommendedActionKind.employeeBeginSelling,
        subjectName: '佐藤 健',
        targetId: 'eng-01',
      );
      const b = HomeRecommendedAction(
        kind: HomeRecommendedActionKind.employeeBeginSelling,
        subjectName: '佐藤 健',
        targetId: 'eng-01',
      );
      const differentTarget = HomeRecommendedAction(
        kind: HomeRecommendedActionKind.employeeBeginSelling,
        subjectName: '佐藤 健',
        targetId: 'eng-02',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differentTarget));
    });
  });
}
