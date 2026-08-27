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
    test('Available translates the resolved action deterministically', () {
      final slot = HomeRecommendedActionAvailable(
        _candidate(
          HomeRecommendedActionKind.employeeSkillSheetReview,
          subjectName: '佐藤 健',
        ),
      );
      final first = navigatorAdviceFor(slot);
      final second = navigatorAdviceFor(slot);
      expect(first!.message, '今は「佐藤 健のSkillSheetを確認」を進めるのがおすすめです。');
      expect(first.semantic, HomeNavigatorAdviceSemantic.neutral);
      expect(second!.message, first.message);
    });

    test('cash-shortage candidate maps to caution', () {
      final advice = navigatorAdviceFor(
        HomeRecommendedActionAvailable(
          _candidate(HomeRecommendedActionKind.cashShortageResponse),
        ),
      );
      expect(advice!.semantic, HomeNavigatorAdviceSemantic.caution);
    });

    test('None is neutral and Suppressed hides advice', () {
      expect(
        navigatorAdviceFor(const HomeRecommendedActionNone()),
        same(HomeNavigatorAdvice.neutral),
      );
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
