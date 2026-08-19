import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';

void main() {
  test('strong profile passes partner interview', () {
    final result = PublicDemoInterviewEvaluator.evaluate(
      type: PublicDemoInterviewType.partner,
      profile: const PublicDemoInterviewProfile(
        skillFit: 80,
        humanity: 70,
        morale: 70,
        clientTrust: 60,
      ),
    );
    expect(result.passed, isTrue);
    expect(result.score, greaterThanOrEqualTo(60));
  });

  test('weak profile fails client interview', () {
    final result = PublicDemoInterviewEvaluator.evaluate(
      type: PublicDemoInterviewType.client,
      profile: const PublicDemoInterviewProfile(
        skillFit: 45,
        humanity: 50,
        morale: 50,
        clientTrust: 40,
      ),
    );
    expect(result.passed, isFalse);
  });
}
