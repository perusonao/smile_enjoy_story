import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';

void main(){
 test('healthy project offers next month order',(){expect(publicDemoInitialAssignments.first.willOfferNextMonth,isTrue);});
 test('strained project can end without next month order',(){expect(publicDemoInitialAssignments.last.willOfferNextMonth,isFalse);});
 test('order can be accepted explicitly',(){final a=publicDemoInitialAssignments.first.copyWith(nextOrderStatus:PublicDemoNextOrderStatus.accepted);expect(a.nextOrderStatus,PublicDemoNextOrderStatus.accepted);});
}
