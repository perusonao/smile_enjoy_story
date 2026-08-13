import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main(){
  group('Playable 0.4A SkillSheet',(){
    test('actual and displayed are separated, clamped, trusted and JSON safe',(){
      var state=GameEngine.newGame(seed:40); final e=state.engineers.first; final original=state.skillSheetFor(e.id); final lang=e.profile.mainLanguage; final actual=e.profile.skillFor(lang).actualExperienceMonths;
      final edited=original.copyWith(displayedLanguageExperience:{...original.displayedLanguageExperience,lang:actual+120},displayedBackend:5);
      state=GameEngine.editSkillSheet(state,edited); final saved=state.skillSheetFor(e.id);
      expect(e.profile.skillFor(lang).actualExperienceMonths,actual); expect(saved.displayedLanguageExperience[lang],actual+SkillSheet.maxExperienceInflationMonths); expect(state.engineerById(e.id).companyTrust,lessThan(e.companyTrust)); expect(SkillSheet.fromJson(saved.toJson()).toJson(),saved.toJson());
    });
  });
  group('employee-first sales',(){
    test('starts selling and only unlocked clients can produce offers deterministically',(){
      GameState run(int seed){ var s=GameEngine.newGame(seed:seed); s=GameEngine.startSales(s,s.engineers.first.id); for(var i=0;i<10 && s.interviewOffers.isEmpty;i++){s=GameEngine.advanceWeek(s);} return s; }
      final a=run(91),b=run(91); expect(a.engineers.first.salesStatus,SalesStatus.selling); expect(a.clientRelations.take(2).every((r)=>r.unlocked),isTrue); expect(a.clientRelations.skip(2).every((r)=>!r.unlocked),isTrue); expect(a.interviewOffers.map((o)=>o.toJson()).toList(),b.interviewOffers.map((o)=>o.toJson()).toList()); expect(a.interviewOffers.every((o)=>a.relationFor(o.clientId).unlocked),isTrue);
    });
    test('accepting interview offer skips document screening and joins SelectionFlow',(){
      var s=GameEngine.newGame(seed:3); final e=s.engineers.first, p=s.openProjects.first.project; s=s.copyWith(interviewOffers:[InterviewOffer(id:'io',employeeId:e.id,projectId:p.id,clientId:p.clientId,generatedWeek:1,expiresWeek:2,skillSheetMatch:80)]); s=GameEngine.acceptInterviewOffer(s,'io'); expect(s.interviewOffers.single.status,InterviewOfferStatus.accepted); expect(s.proposals.single.currentStepIndex,p.selectionFlow.steps.length>1?1:0);
    });
    test('decline closes interview offer',(){ var s=GameEngine.newGame(seed:3); final e=s.engineers.first,p=s.openProjects.first.project; s=s.copyWith(interviewOffers:[InterviewOffer(id:'io',employeeId:e.id,projectId:p.id,clientId:p.clientId,generatedWeek:1,expiresWeek:2,skillSheetMatch:80)]); expect(GameEngine.declineInterviewOffer(s,'io').interviewOffers.single.status,InterviewOfferStatus.declined); });
  });
  group('client and contract',(){
    test('initial relations and trust round-trip',(){final s=GameEngine.newGame(seed:4);expect(s.clientRelations.where((r)=>r.unlocked).length,2);expect(ClientRelation.fromJson(s.clientRelations.first.toJson()).trust,50);});
    test('four week decision extends contract',(){var s=GameEngine.newGame(seed:5);final e=s.engineers.first,p=s.openProjects.first.project;final a=ActiveAssignment(engineerId:e.id,project:p,remainingWeeks:4,assignedWeek:1,contractEndWeek:5);s=s.copyWith(activeAssignments:[a],engineers:[e.copyWith(status:EngineerStatus.assigned),...s.engineers.skip(1)]);expect(TaskEngine.generateTasks(s).any((t)=>t.id.startsWith('contract-ending')),isTrue);final n=GameEngine.decideContract(s,e.id,true);expect(n.activeAssignments.single.remainingWeeks,greaterThan(4));expect(n.activeAssignments.single.contractDecision,ContractDecision.extend);});
    test('withdrawal exposes next availability and allows next sales',(){var s=GameEngine.newGame(seed:6);final e=s.engineers.first,p=s.openProjects.first.project;final a=ActiveAssignment(engineerId:e.id,project:p,remainingWeeks:4,assignedWeek:1,contractEndWeek:5);s=s.copyWith(activeAssignments:[a],engineers:[e.copyWith(status:EngineerStatus.assigned),...s.engineers.skip(1)]);s=GameEngine.decideContract(s,e.id,false);s=GameEngine.startSales(s,e.id);expect(s.engineerById(e.id).availableFromWeek,6);expect(s.engineerById(e.id).salesStatus,SalesStatus.selling);});
  });
  test('recommendations include sales and interview offer',(){var s=GameEngine.newGame(seed:8);expect(TaskEngine.generateTasks(s).any((t)=>t.id.startsWith('sales-start')),isTrue);final e=s.engineers.first,p=s.openProjects.first.project;s=s.copyWith(interviewOffers:[InterviewOffer(id:'io',employeeId:e.id,projectId:p.id,clientId:p.clientId,generatedWeek:1,expiresWeek:2,skillSheetMatch:70)]);expect(TaskEngine.generateTasks(s).any((t)=>t.id.startsWith('interview-offer')),isTrue);});
  test('field lead rolls are seed reproducible',(){GameState run(){var s=GameEngine.newGame(seed:123);final e=s.engineers.first.copyWith(status:EngineerStatus.assigned,companyTrust:100,talkSkill:5,abilities:{EmployeeAbility.clientFriendly});final p=s.openProjects.first.project;s=s.copyWith(engineers:[e,...s.engineers.skip(1)],activeAssignments:[ActiveAssignment(engineerId:e.id,project:p,remainingWeeks:20,assignedWeek:-5)]);for(var i=0;i<5;i++){s=GameEngine.advanceWeek(s);}return s;}expect(run().events.map((e)=>e.message),run().events.map((e)=>e.message));});
}
