/// Minimal state for Public Demo 0.1 MVP-A.
class PublicDemoState {
  const PublicDemoState({required this.month,required this.cash,required this.engineerCount,required this.adminCount,required this.salesCapacity,required this.salesUsed,required this.engineersWaiting,required this.engineersAssigned});
  factory PublicDemoState.aprilStart()=>const PublicDemoState(month:4,cash:3000000,engineerCount:2,adminCount:1,salesCapacity:4,salesUsed:0,engineersWaiting:2,engineersAssigned:0);
  final int month,cash,engineerCount,adminCount,salesCapacity,salesUsed,engineersWaiting,engineersAssigned;
  int get salesRemaining=>salesCapacity-salesUsed;
  PublicDemoState useSalesSlot(){if(salesRemaining<=0)return this;return copyWith(salesUsed:salesUsed+1);}
  PublicDemoState advanceToMay({required int monthlyExpenses,required int orderedEngineers}){if(month!=4)return this;final assigned=orderedEngineers.clamp(0,engineerCount);return copyWith(month:5,cash:cash-monthlyExpenses,salesUsed:0,engineersAssigned:assigned,engineersWaiting:engineerCount-assigned);}
  PublicDemoState advanceToJune({required int monthlyExpenses,required int acceptedHires,required int hiredWithOrders}){if(month!=5)return this;final hires=acceptedHires<0?0:acceptedHires;final ordered=hiredWithOrders.clamp(0,hires);return copyWith(month:6,cash:cash-monthlyExpenses,salesUsed:0,engineerCount:engineerCount+hires,engineersAssigned:engineersAssigned+ordered,engineersWaiting:engineersWaiting+(hires-ordered));}
  PublicDemoState advanceToJuly({required int monthlyExpenses,required int assignedInJuly}){if(month!=6)return this;final assigned=assignedInJuly.clamp(0,engineerCount);return copyWith(month:7,cash:cash-monthlyExpenses,salesUsed:0,engineersAssigned:assigned,engineersWaiting:engineerCount-assigned);}
  PublicDemoState copyWith({int? month,int? cash,int? engineerCount,int? adminCount,int? salesCapacity,int? salesUsed,int? engineersWaiting,int? engineersAssigned})=>PublicDemoState(month:month??this.month,cash:cash??this.cash,engineerCount:engineerCount??this.engineerCount,adminCount:adminCount??this.adminCount,salesCapacity:salesCapacity??this.salesCapacity,salesUsed:salesUsed??this.salesUsed,engineersWaiting:engineersWaiting??this.engineersWaiting,engineersAssigned:engineersAssigned??this.engineersAssigned);
}
