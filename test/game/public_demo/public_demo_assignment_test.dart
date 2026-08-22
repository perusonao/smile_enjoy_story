import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';

void main() {
  test(
    'healthy project offers next month order for its employee capability',
    () {
      expect(
        publicDemoInitialAssignments.first.willOfferNextMonthFor(78),
        isTrue,
      );
    },
  );
  test(
    'strained project can end without next month order for its employee capability',
    () {
      expect(
        publicDemoInitialAssignments.last.willOfferNextMonthFor(52),
        isFalse,
      );
    },
  );
  test('order can be accepted explicitly', () {
    final a = publicDemoInitialAssignments.first.copyWith(
      nextOrderStatus: PublicDemoNextOrderStatus.accepted,
    );
    expect(a.nextOrderStatus, PublicDemoNextOrderStatus.accepted);
  });
}
