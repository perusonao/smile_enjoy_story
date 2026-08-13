import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import '../widgets/fit_badge.dart';
import '../widgets/selection_stepper.dart';
import '../widgets/status_chip.dart';
import '../projects/client_interview_screen.dart';

/// 社員詳細 (§19): salary, status, skills, personality, current project,
/// waiting weeks + cost, and (if assigned) the project rate / monthly
/// profit estimate.
class EngineerDetailScreen extends StatelessWidget {
  const EngineerDetailScreen({super.key, required this.engineerId});

  final String engineerId;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    Engineer? engineer;
    for (final e in state.engineers) {
      if (e.id == engineerId) {
        engineer = e;
        break;
      }
    }
    if (engineer == null) {
      return const Scaffold(body: Center(child: Text('社員が見つかりません。')));
    }
    final profile = engineer.profile;
    final assignment = state.assignmentForEngineer(engineerId);
    final proposal = state.proposalForEngineer(engineerId);
    final applications = state
        .applicationsForEngineer(engineerId)
        .where(
          (application) =>
              application.status == ApplicationStatus.active ||
              application.status == ApplicationStatus.offered,
        )
        .toList();
    final pendingOffers = state.offers
        .where(
          (offer) =>
              offer.employeeId == engineerId &&
              offer.status == OfferStatus.pending,
        )
        .toList();
    final waitingWeeks = state.waitingStreakFor(engineerId);
    final skillSheet = state.skillSheetFor(engineerId);
    final interviewOffers = state.interviewOffers.where((o)=>o.employeeId==engineerId && o.status==InterviewOfferStatus.pending).toList();

    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              EngineerStatusChip(status: engineer.status),
            ],
          ),
          const SizedBox(height: 12),
          if (engineer.status == EngineerStatus.waiting)
            _WaitingWarningBanner(
              weeks: waitingWeeks,
              monthlySalary: engineer.salary,
            ),
          _SectionCard(title:'スキルシート / 営業',children:[
            _Row('会社信頼',engineer.companyTrust >= 70 ? '高い' : engineer.companyTrust >= 45 ? '普通' : '低下中'),
            _Row(languageLabels[profile.mainLanguage] ?? profile.mainLanguage.name,'実際 ${formatExperience(profile.skillFor(profile.mainLanguage).actualExperienceMonths)} / 記載 ${formatExperience(skillSheet.displayedLanguageExperience[profile.mainLanguage] ?? 0)}'),
            _Row('Backend','実際 Lv.${profile.techSkills.backend} / 記載 Lv.${skillSheet.displayedBackend}'),
            _Row('Leader','実際 Lv.${profile.techSkills.leader} / 記載 Lv.${skillSheet.displayedLeader}'),
            _Row('営業状態',engineer.salesStatus==SalesStatus.selling?'営業中（公開先 ${state.unlockedClientCount}社）':engineer.salesStatus.name),
            _Row('参画可能','Week ${engineer.availableFromWeek}〜'),
            const Text('会社信頼が低い社員は、現場の増員情報を持ち帰りにくくなります。',style:TextStyle(fontSize:12,color:Colors.black54)),
            Row(children:[Expanded(child:OutlinedButton(onPressed:()=>_editSkillSheet(context,engineer!,skillSheet),child:const Text('営業用記載を編集'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:engineer.salesStatus==SalesStatus.selling?null:()=>_confirmSalesStart(context,engineer!,skillSheet),child:const Text('営業を開始する')))]),
          ]),
          if(interviewOffers.isNotEmpty)...[const SizedBox(height:12),_SectionCard(title:'面談オファー',children:[for(final offer in interviewOffers) _InterviewOfferCard(offer:offer,project:state.openProjects.firstWhere((e)=>e.project.id==offer.projectId).project)])],
          if(assignment != null && assignment.remainingWeeks <= 4 && assignment.contractDecision==ContractDecision.undecided)...[const SizedBox(height:12),_SectionCard(title:'契約更新判断（終了4週前）',children:[Text('${assignment.project.title} / 残り${assignment.remainingWeeks}週'),Row(children:[Expanded(child:FilledButton(onPressed:()=>context.game.decideContract(engineerId,extend:true),child:const Text('延長する'))),const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:()=>context.game.decideContract(engineerId,extend:false),child:const Text('撤退する')))])])],
          _SectionCard(
            title: '基本情報',
            children: [
              _Row('月給', formatYen(engineer.salary)),
              _Row(
                '主言語',
                languageLabels[profile.mainLanguage] ??
                    profile.mainLanguage.name,
              ),
              if (profile.subLanguages.isNotEmpty)
                _Row(
                  '副言語',
                  profile.subLanguages
                      .map((l) => languageLabels[l] ?? l.name)
                      .join(' / '),
                ),
              _Row('IT経験', formatExperience(profile.totalItExperienceMonths)),
              _Row('日本語', 'Lv.${profile.japaneseLevel}'),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '技術スキル',
            children: [
              _Row('DB', 'Lv.${profile.techSkills.database}'),
              _Row('Network', 'Lv.${profile.techSkills.network}'),
              _Row('Infrastructure', 'Lv.${profile.techSkills.infrastructure}'),
              _Row('Frontend', 'Lv.${profile.techSkills.frontend}'),
              _Row('Backend', 'Lv.${profile.techSkills.backend}'),
              _Row('Leader', 'Lv.${profile.techSkills.leader}'),
              _Row('Manager', 'Lv.${profile.techSkills.manager}'),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '人物パラメータ',
            children: [
              _Row('ルックス', '★' * profile.personality.looks),
              _Row('清潔感', '★' * profile.personality.cleanliness),
              _Row('コミュ力', '★' * profile.personality.communication),
              _Row('アルコール耐性', '★' * profile.personality.alcoholTolerance),
              _Row('真面目度', '★' * profile.personality.seriousness),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '現在の状況',
            children: [
              if (assignment != null) ...[
                _Row('現在案件', assignment.project.title),
                _Row('残り期間', '${assignment.remainingWeeks}週'),
                _Row('案件単価', formatYen(assignment.project.monthlyRate)),
                _Row(
                  '月間想定粗利',
                  formatYen(
                    MatchingEngine.monthlyProfit(engineer, assignment.project),
                  ),
                ),
              ] else if (proposal != null) ...[
                _Row('提案先', proposal.project.title),
                _Row(
                  '状況',
                  proposal.stage == ProposalStage.interviewPassed
                      ? '面談合格・参画待ち'
                      : '面談待ち',
                ),
              ] else ...[
                _Row('現在案件', 'なし(待機中)'),
                _Row('待機週数', '$waitingWeeks 週目'),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title:
                '営業状況  並行営業 ${applications.length} / $maxParallelProposalsPerEmployee',
            children: [
              if (applications.isEmpty) const Text('営業中の案件はありません。'),
              for (final application in applications) ...[
                _ApplicationRow(application: application),
                const Divider(height: 18),
              ],
              if (applications.isEmpty && engineer.salesStatus == SalesStatus.selling)
                Text('面談オファー待ち\n現在${state.unlockedClientCount}社へ公開中です。条件に合う案件が見つかると面談オファーが届きます。'),
            ],
          ),
          if (pendingOffers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'オファー比較・回答',
              children: [
                for (final offer in pendingOffers)
                  _OfferRow(
                    offer: offer,
                    application: state.proposals.firstWhere(
                      (application) => application.id == offer.applicationId,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editSkillSheet(BuildContext context,Engineer engineer,SkillSheet original) async {
    var months=original.displayedLanguageExperience[engineer.profile.mainLanguage] ?? 0; var backend=original.displayedBackend; var leader=original.displayedLeader;
    await showDialog<void>(context:context,builder:(dialog)=>StatefulBuilder(builder:(context,setState){
      final actualMonths=engineer.profile.skillFor(engineer.profile.mainLanguage).actualExperienceMonths;
      final draft=original.copyWith(displayedLanguageExperience:{...original.displayedLanguageExperience,engineer.profile.mainLanguage:months},displayedBackend:backend,displayedLeader:leader);
      final risk=SalesEngine.riskFor(engineer,draft);
      Widget adjust(String label,int actual,int value,void Function(int) change,{String suffix=''})=>Row(children:[Expanded(child:Text('$label  実際 $actual$suffix / 記載 $value$suffix')),IconButton(onPressed:value>0?()=>setState(()=>change(value-1)):null,icon:const Icon(Icons.remove)),IconButton(onPressed:()=>setState(()=>change(value+1)),icon:const Icon(Icons.add))]);
      return AlertDialog(title:Text('${engineer.profile.name}\n営業用スキルシート'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('取引先へ公開する経歴です。強い記載は機会を増やしますが、実態との差にはリスクがあります。'),const SizedBox(height:10),Text('スキルシート信頼性\n${SalesEngine.riskLabel(risk)}',style:const TextStyle(fontWeight:FontWeight.bold)),Text(SalesEngine.employeeReaction(risk)),const Divider(),adjust(languageLabels[engineer.profile.mainLanguage] ?? engineer.profile.mainLanguage.name,actualMonths~/12,months~/12,(v)=>months=v*12,suffix:'年'),adjust('Backend',engineer.profile.techSkills.backend,backend,(v)=>backend=v),adjust('Leader',engineer.profile.techSkills.leader,leader,(v)=>leader=v),const Divider(),Text('営業機会: ${risk==SkillSheetRisk.honest?'→':risk==SkillSheetRisk.moderate?'↑':'↑↑'}'),Text('社員信頼リスク: ${risk==SkillSheetRisk.honest?'なし':risk==SkillSheetRisk.moderate?'小':risk==SkillSheetRisk.aggressive?'中':'大'}'),Text('面談リスク: ${risk==SkillSheetRisk.honest?'低い':risk==SkillSheetRisk.moderate?'やや上昇':'上昇'}')])),actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('キャンセル')),FilledButton(onPressed:()async{if(risk==SkillSheetRisk.aggressive||risk==SkillSheetRisk.extreme){final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('スキルシートを保存しますか？'),content:Text('実態との差が大きい項目があります。\n\n・${SalesEngine.inflationDetails(engineer,draft).join('\n・')}\n\n社員からの信頼や面談結果へ影響する可能性があります。'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('戻る')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('この内容で保存'))]));if(ok!=true)return;}if(context.mounted){context.game.editSkillSheet(draft);Navigator.pop(dialog);}},child:const Text('保存'))]);
    }));
  }

  Future<void> _confirmSalesStart(BuildContext context,Engineer engineer,SkillSheet sheet) async {
    final state=context.game.state; final clients=sampleClients.where((c)=>state.relationFor(c.id).unlocked).map((c)=>c.name).join('\n');
    final accepted=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('${engineer.profile.name}の営業を開始します'),content:Text('公開先:\n$clients\n\n参画可能: ${engineer.availableFromWeek<=state.week?'現在':'Week ${engineer.availableFromWeek}'}\nスキルシート: ${SalesEngine.riskLabel(SalesEngine.riskFor(engineer,sheet))}\n\n条件に合う案件があると、取引先から面談オファーが届きます。'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('戻る')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('営業開始'))]));
    if(accepted==true&&context.mounted)context.game.startSales(engineer.id);
  }
}

class _InterviewOfferCard extends StatelessWidget { const _InterviewOfferCard({required this.offer,required this.project}); final InterviewOffer offer; final Project project; @override Widget build(BuildContext context){final good=<String>[if(offer.skillSheetMatch>=70)'スキルシートとの相性が高い',if(project.paymentTermDays==30)'30日サイト'];final cautions=<String>[if(project.competitionLevel>=4)'競争度が高い',if(project.difficulty>=4)'要求水準が高い'];return Card(color:Colors.blue.shade50,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('面談オファー！',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),Text('${clientNameById(project.clientId)}  ${project.title}',style:const TextStyle(fontWeight:FontWeight.bold)),Text('単価 ${formatYen(project.monthlyRate)} / ${project.location.name} / ${project.industry.name}'),Text('契約 ${project.contractTermMonths}か月 / 支払 ${project.paymentTermDays}日'),if(good.isNotEmpty)Text('良い点\n・${good.take(2).join('\n・')}'),if(cautions.isNotEmpty)Text('注意点\n・${cautions.take(2).join('\n・')}'),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>context.game.declineInterviewOffer(offer.id),child:const Text('断る'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:()=>context.game.acceptInterviewOffer(offer.id),child:const Text('面談へ進む')))])]))); } }

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({required this.application});

  final ProjectApplication application;

  @override
  Widget build(BuildContext context) {
    final engineer = context.game.state.engineerById(application.engineerId);
    final profit = MatchingEngine.monthlyProfit(engineer, application.project);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          application.project.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 3),
        Text(
          '現在: ${selectionStepLabels[application.currentStep]}',
          style: const TextStyle(
            color: SesTheme.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          application.status == ApplicationStatus.active
              ? '結果待ち・次週に判定されます'
              : application.status == ApplicationStatus.offered
                  ? 'Offer獲得・今週中に回答してください'
                  : '選考終了',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: application.status == ApplicationStatus.active ? Colors.orange.shade800 : Colors.black54),
        ),
        if (application.status == ApplicationStatus.active && application.currentStepIndex + 1 < application.project.selectionFlow.steps.length)
          Text('次: ${selectionStepLabels[application.project.selectionFlow.steps[application.currentStepIndex + 1]]}', style: const TextStyle(fontSize: 12.5)),
        const SizedBox(height: 6),
        SelectionStepper(
          steps: application.project.selectionFlow.steps,
          currentStepIndex: application.currentStepIndex,
          compact: true,
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 10,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${formatYen(application.project.monthlyRate)} / 月',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            FitBadge(fit: PlayerVisibleFit.fromScore(application.fitScore)),
            Text(
              '${paymentTermDaysById(application.project.clientId)}日サイト',
              style: const TextStyle(fontSize: 12.5),
            ),
            Text(
              '粗利 ${profit >= 0 ? '+' : ''}${formatYen(profit)}',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            Text(
              '競争度 ${'★' * application.project.competitionLevel}',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ],
        ),
        if (application.stepHistory.isNotEmpty)
          Text(
            application.stepHistory
                .map(
                  (history) =>
                      'Week ${history.week} ${selectionStepLabels[history.step]} ${history.result == SelectionStepResult.passed ? '通過' : '終了'}',
                )
                .join('\n'),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        if(application.status==ApplicationStatus.active&&application.currentStep==SelectionStep.clientInterview)...[const SizedBox(height:8),const Text('操作: 面談をプレイできます',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.deepOrange)),Row(children:[Expanded(child:FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ClientInterviewScreen(applicationId:application.id))),child:const Text('面談をプレイ'))),const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:()=>context.game.autoResolveClientInterview(application.id),child:const Text('社員に任せる')))])],
      ],
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer, required this.application});

  final Offer offer;
  final ProjectApplication application;

  @override
  Widget build(BuildContext context) {
    final deadline = offer.responseDeadlineWeek == context.game.state.week
        ? '今週中'
        : 'Week ${offer.responseDeadlineWeek}';
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              application.project.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '月単価 ${formatYen(offer.monthlyRate)} / Fit ${application.fitScore}',
            ),
            Text(
              '支払 ${paymentTermDaysById(application.project.clientId)}日 / 回答期限 $deadline',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.game.acceptOffer(offer.id),
                    child: const Text('受諾'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.game.declineOffer(offer.id),
                    child: const Text('辞退'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingWarningBanner extends StatelessWidget {
  const _WaitingWarningBanner({
    required this.weeks,
    required this.monthlySalary,
  });

  final int weeks;
  final int monthlySalary;

  @override
  Widget build(BuildContext context) {
    final critical = weeks >= 3;
    final color = critical
        ? Colors.red
        : (weeks >= 2 ? Colors.orange : Colors.blueGrey);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '待機$weeks週目です。案件が決まらなくても月給 ${formatYen(monthlySalary)} は月末に満額発生します。',
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: SesTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
