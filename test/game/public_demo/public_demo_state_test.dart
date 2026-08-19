import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main(){group('PublicDemoState',(){
  test('April starts with baseline',(){final s=PublicDemoState.aprilStart();expect(s.month,4);expect(s.cash,3000000);expect(s.engineerCount,2);expect(s.engineersWaiting,2);expect(s.engineersAssigned,0);expect(s.salesRemaining,4);});
  test('sales capacity cannot exceed four',(){var s=PublicDemoState.aprilStart();for(var i=0;i<5;i++){s=s.useSalesSlot();}expect(s.salesUsed,4);expect(s.salesRemaining,0);});
  test('failed April starts May with two waiting',(){final s=PublicDemoState.aprilStart().advanceToMay(monthlyExpenses:800000,orderedEngineers:0);expect(s.month,5);expect(s.cash,2200000);expect(s.engineersAssigned,0);expect(s.engineersWaiting,2);expect(s.salesRemaining,4);});
  test('May order assigns only ordered engineer',(){final s=PublicDemoState.aprilStart().advanceToMay(monthlyExpenses:800000,orderedEngineers:1);expect(s.engineersAssigned,1);expect(s.engineersWaiting,1);});
  test('accepted hire joins in June and starts assigned with order',(){final may=PublicDemoState.aprilStart().advanceToMay(monthlyExpenses:800000,orderedEngineers:1);final june=may.advanceToJune(monthlyExpenses:800000,acceptedHires:1,hiredWithOrders:1);expect(june.month,6);expect(june.cash,1400000);expect(june.engineerCount,3);expect(june.engineersAssigned,2);expect(june.engineersWaiting,1);expect(june.salesRemaining,4);});
  test('accepted hire without order joins June waiting',(){final may=PublicDemoState.aprilStart().advanceToMay(monthlyExpenses:800000,orderedEngineers:1);final june=may.advanceToJune(monthlyExpenses:800000,acceptedHires:1,hiredWithOrders:0);expect(june.engineerCount,3);expect(june.engineersAssigned,1);expect(june.engineersWaiting,2);});
});}
