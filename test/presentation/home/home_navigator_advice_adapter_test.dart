import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_navigator_display.dart';
import 'package:smile_enjoy_story/presentation/home/models/home_recommended_action.dart';

HomeRecommendedActionCandidate _candidate(
  HomeRecommendedActionKind kind, {
  String? subjectName,
  void Function()? invoke,
}) => HomeRecommendedActionCandidate(
  action: HomeRecommendedAction(kind: kind, subjectName: subjectName),
  invoke: invoke ?? () {},
);

void main() {
  group('NAVIGATOR-1C deterministic advice adapter', () {
    test('1D maps neutral and missing semantics to normal', () {
      expect(
        navigatorExpressionFor(HomeNavigatorAdviceSemantic.neutral),
        NavigatorExpression.normal,
      );
      expect(navigatorExpressionFor(null), NavigatorExpression.normal);
    });

    test('1D maps caution to worried', () {
      expect(
        navigatorExpressionFor(HomeNavigatorAdviceSemantic.caution),
        NavigatorExpression.worried,
      );
    });

    test('Available translates the resolved sales-start path deterministically', () {
      final slot = HomeRecommendedActionAvailable(
        _candidate(
          HomeRecommendedActionKind.employeeSkillSheetReview,
          subjectName: '佐藤 健',
        ),
      );
      final first = navigatorAdviceFor(slot);
      final second = navigatorAdviceFor(slot);
      expect(first!.headline, '佐藤 健のスキルシートを確認');
      expect(first.message, 'スキルシートの内容を確認しましょう。');
      expect(first.explanation, 'スキルシートは、経験やスキルを案件へ伝えるための資料です。内容を確認して次の手続きに備えます。');
      expect(first.semantic, HomeNavigatorAdviceSemantic.neutral);
      expect(second!.headline, first.headline);
      expect(second.message, first.message);
      expect(second.explanation, first.explanation);
    });

    test('cash-shortage candidate maps to caution', () {
      final advice = navigatorAdviceFor(
        HomeRecommendedActionAvailable(
          _candidate(HomeRecommendedActionKind.cashShortageResponse),
        ),
      );
      expect(advice!.semantic, HomeNavigatorAdviceSemantic.caution);
      expect(advice.explanation, '事業を続けるには、必要な対応を確認してから次の手続きを進めることが大切です。');
    });

    test('None is neutral and Suppressed hides advice', () {
      expect(
        navigatorAdviceFor(const HomeRecommendedActionNone()),
        same(HomeNavigatorAdvice.neutral),
      );
      final none = navigatorAdviceFor(const HomeRecommendedActionNone())!;
      expect(none.semantic, HomeNavigatorAdviceSemantic.neutral);
      expect(none.explanation, isNotNull);
      expect(none.ctaLabel, isNull);
      expect(none.onCtaPressed, isNull);
      expect(
        navigatorAdviceFor(const HomeRecommendedActionSuppressed()),
        isNull,
      );
    });

    test('Available forwards the exact existing owner callback', () {
      var calls = 0;
      void ownerCallback() => calls++;
      final candidate = _candidate(
        HomeRecommendedActionKind.employeeAcceptOrder,
        invoke: ownerCallback,
      );
      final advice = navigatorAdviceFor(
        HomeRecommendedActionAvailable(candidate),
      );
      expect(identical(advice!.onCtaPressed, candidate.invoke), isTrue);
      expect(calls, 0);
      advice.onCtaPressed!();
      expect(calls, 1);
    });
  });
}
