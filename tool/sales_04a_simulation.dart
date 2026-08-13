// ignore_for_file: avoid_print
import 'package:smile_enjoy_story/game/game.dart';

void main(){
  for(final mode in ['honest','slight','large']){
    var offerWeeks=0,assignmentWeeks=0,trust=0,survived=0,offers=0,assignedRuns=0;
    for(var seed=1;seed<=200;seed++){
      var s=GameEngine.newGame(seed:seed); final started=s.week;
      for(final engineer in s.engineers){
        var sheet=s.skillSheetFor(engineer.id);
        if(mode!='honest'){final delta=mode=='slight'?12:36;final lang=engineer.profile.mainLanguage;sheet=sheet.copyWith(displayedLanguageExperience:{...sheet.displayedLanguageExperience,lang:(sheet.displayedLanguageExperience[lang]??0)+delta},displayedBackend:sheet.displayedBackend+(mode=='slight'?1:2));s=GameEngine.editSkillSheet(s,sheet);}
        s=GameEngine.startSales(s,engineer.id);
      }
      int? firstOffer,firstAssignment;
      while(s.status==GameStatus.playing && s.week<48){
        for(final o in s.interviewOffers.where((o)=>o.status==InterviewOfferStatus.pending).toList()){firstOffer??=s.week;s=GameEngine.acceptInterviewOffer(s,o.id);offers++;}
        for(final o in s.offers.where((o)=>o.status==OfferStatus.pending).toList()){s=GameEngine.acceptOffer(s,o.id);}
        for(final a in s.activeAssignments.where((a)=>a.remainingWeeks<=4&&a.contractDecision==ContractDecision.undecided).toList()){s=GameEngine.decideContract(s,a.engineerId,seed.isEven);}
        s=GameEngine.advanceWeek(s); if(s.activeAssignments.isNotEmpty)firstAssignment??=s.week;
      }
      if(firstOffer!=null)offerWeeks+=firstOffer-started; if(firstAssignment!=null){assignmentWeeks+=firstAssignment-started;assignedRuns++;} trust+=s.engineers.fold<int>(0,(n,e)=>n+e.companyTrust)~/s.engineers.length; if(s.status!=GameStatus.bankrupt)survived++;
    }
    print('$mode: avgOfferWeek=${offerWeeks/200}, avgAssignmentWeek=${assignedRuns==0?0:assignmentWeeks/assignedRuns}, avgTrust=${trust/200}, offers=$offers, survival48=${survived/2}%');
  }
}
