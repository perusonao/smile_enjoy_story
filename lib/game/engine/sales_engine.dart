import '../../domain/domain.dart';
import '../models/models.dart';
import 'project_interview_engine.dart';

class SalesEngine {
  const SalesEngine._();
  static const int offerThreshold = 55;

  static SkillSheetRisk riskFor(Engineer engineer, SkillSheet sheet) {
    final points = inflationPoints(engineer, sheet);
    if (points == 0) return SkillSheetRisk.honest;
    if (points <= 4) return SkillSheetRisk.moderate;
    if (points <= 10) return SkillSheetRisk.aggressive;
    return SkillSheetRisk.extreme;
  }

  static String riskLabel(SkillSheetRisk risk) => switch (risk) {
    SkillSheetRisk.honest => '◎ 実態に忠実',
    SkillSheetRisk.moderate => '○ 少し強め',
    SkillSheetRisk.aggressive => '△ かなり強め',
    SkillSheetRisk.extreme => '！ 実態との乖離が大きい',
  };

  static String employeeReaction(SkillSheetRisk risk) => switch (risk) {
    SkillSheetRisk.honest => '「この内容なら問題ありません」',
    SkillSheetRisk.moderate => '「少し強めですが、このくらいなら…」',
    SkillSheetRisk.aggressive => '「これは実際の経験とかなり違いませんか？」',
    SkillSheetRisk.extreme => '「この内容で営業されるのは不安です」',
  };

  static List<String> inflationDetails(Engineer engineer, SkillSheet sheet) {
    final details=<String>[];
    for(final item in sheet.displayedLanguageExperience.entries){final actual=engineer.profile.skillFor(item.key).actualExperienceMonths;final delta=item.value-actual;if(delta>0)details.add('${item.key.name} +${delta~/12}年');}
    final actual=engineer.profile.techSkills;
    if(sheet.displayedBackend>actual.backend)details.add('Backend +${sheet.displayedBackend-actual.backend}');
    if(sheet.displayedLeader>actual.leader)details.add('Leader +${sheet.displayedLeader-actual.leader}');
    return details;
  }

  static int skillSheetMatch(SkillSheet s, Project p) {
    var earned = 0.0, possible = 0.0;
    void score(int value, int required, [double weight = 1]) { if (required <= 0) return; possible += weight; earned += (value / required).clamp(0,1) * weight; }
    for (final language in p.requiredLanguages) { score((s.displayedLanguageExperience[language] ?? 0) ~/ 12, 2, 2); }
    score(s.displayedDatabase,p.requiredDatabase); score(s.displayedNetwork,p.requiredNetwork); score(s.displayedInfrastructure,p.requiredInfrastructure); score(s.displayedFrontend,p.requiredFrontend); score(s.displayedBackend,p.requiredBackend); score(s.displayedLeader,p.requiredLeader); score(s.displayedManager,p.requiredManager);
    if (p.industry != Industry.other) score((s.displayedIndustryExperience[p.industry] ?? 0) ~/ 12, 1, 1.5);
    return possible == 0 ? 70 : (earned / possible * 100).round();
  }

  static int inflationPoints(Engineer e, SkillSheet s) {
    var points = 0;
    for (final item in s.displayedLanguageExperience.entries) { final actual=e.profile.skillFor(item.key).actualExperienceMonths; if(item.value>actual) points += ((item.value-actual)/12).ceil(); }
    final a=e.profile.techSkills;
    final displayed=[s.displayedDatabase,s.displayedNetwork,s.displayedInfrastructure,s.displayedFrontend,s.displayedBackend,s.displayedLeader,s.displayedManager];
    final actual=[a.database,a.network,a.infrastructure,a.frontend,a.backend,a.leader,a.manager];
    for(var i=0;i<displayed.length;i++){ if(displayed[i]>actual[i]) points += (displayed[i]-actual[i])*2; }
    return points;
  }

  static SkillSheet clampSheet(Engineer e, SkillSheet s, int week) {
    final langs=<ProgrammingLanguage,int>{};
    for(final lang in ProgrammingLanguage.values){ final actual=e.profile.skillFor(lang).actualExperienceMonths; langs[lang]=(s.displayedLanguageExperience[lang] ?? actual).clamp(0,actual+SkillSheet.maxExperienceInflationMonths); }
    int c(int value,int actual)=>value.clamp(0,(actual+SkillSheet.maxSkillInflation).clamp(0,5)); final a=e.profile.techSkills;
    return s.copyWith(displayedLanguageExperience:langs,displayedDatabase:c(s.displayedDatabase,a.database),displayedNetwork:c(s.displayedNetwork,a.network),displayedInfrastructure:c(s.displayedInfrastructure,a.infrastructure),displayedFrontend:c(s.displayedFrontend,a.frontend),displayedBackend:c(s.displayedBackend,a.backend),displayedLeader:c(s.displayedLeader,a.leader),displayedManager:c(s.displayedManager,a.manager),updatedWeek:week);
  }

  static List<InterviewOffer> generateOffers(GameState state, int week, String Function(String) mintId) {
    final result=<InterviewOffer>[];
    final unlocked=state.clientRelations.where((r)=>r.unlocked).map((r)=>r.clientId).toSet();
    for(final engineer in state.engineers.where((e)=>e.salesStatus==SalesStatus.selling)){
      if(!state.skillSheets.any((s)=>s.employeeId==engineer.id)) continue;
      final pendingCount=state.interviewOffers.where((o)=>o.employeeId==engineer.id && o.status==InterviewOfferStatus.pending).length;
      final risk=riskFor(engineer,state.skillSheetFor(engineer.id));
      final offerSlots=switch(risk){SkillSheetRisk.honest=>1,SkillSheetRisk.moderate=>2,SkillSheetRisk.aggressive||SkillSheetRisk.extreme=>3};
      if(pendingCount>=offerSlots) continue;
      final sheet=state.skillSheetFor(engineer.id);
      final candidates=state.openProjects.where((e)=>unlocked.contains(e.project.clientId) && e.project.applicationDeadlineWeek>=week && e.project.availableStartWeek<=engineer.availableFromWeek+8 && !state.proposals.any((p)=>p.employeeId==engineer.id&&p.projectId==e.project.id)).toList();
      candidates.sort((a,b)=>skillSheetMatch(sheet,b.project).compareTo(skillSheetMatch(sheet,a.project)));
      if(candidates.isEmpty) continue;
      final project=candidates[pendingCount.clamp(0,candidates.length-1)].project; final match=skillSheetMatch(sheet,project);
      final rate=((match-offerThreshold)*2+35).clamp(5,85);
      if(match>=offerThreshold && ProjectInterviewEngine.roll(rate:rate,seed:state.seed,week:week,salt:'sales:${engineer.id}:${project.id}')) result.add(InterviewOffer(id:mintId('interview-offer'),employeeId:engineer.id,projectId:project.id,clientId:project.clientId,generatedWeek:week,expiresWeek:week+1,skillSheetMatch:match));
    }
    return result;
  }
}

enum SkillSheetRisk { honest, moderate, aggressive, extreme }
