import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import '../widgets/fit_badge.dart';
import '../widgets/selection_stepper.dart';
import '../widgets/skill_chip.dart';
import '../widgets/status_chip.dart';
import '../projects/client_interview_screen.dart';

/// Tech-skill tags for the 技術スキル header (Playable 0.4C.3 §3) — the same
/// levels the row-list below already shows, just scannable at a glance.
List<Widget> _techSkillChips(TechSkillLevels skills) {
  final chips = <Widget>[];
  void add(String label, int level, {IconData? icon, Color color = Colors.teal}) {
    if (level >= 2) chips.add(SkillChip('$label Lv.$level', icon: icon, color: color));
  }

  add('Frontend', skills.frontend);
  add('Backend', skills.backend);
  add('DB', skills.database);
  add('Network', skills.network);
  add('Infrastructure', skills.infrastructure);
  add('Leader', skills.leader, icon: Icons.star_outline, color: Colors.deepPurple);
  add('Manager', skills.manager, icon: Icons.star_outline, color: Colors.deepPurple);
  return chips;
}

/// 社員詳細 (§19): salary, status, skills, personality, current project,
/// waiting weeks + cost, and (if assigned) the project rate / monthly
/// profit estimate.
class EngineerDetailScreen extends StatelessWidget {
  const EngineerDetailScreen({super.key, required this.engineerId});

  final String engineerId;

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;
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
    if (!state.foundingProgress.has(FoundingMilestone.inspectEmployee)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.state.foundingProgress.has(FoundingMilestone.inspectEmployee)) {
          controller.recordMilestone(FoundingMilestone.inspectEmployee);
        }
      });
    }
    if (ProgressionEngine.currentStage(state) == FoundingStage.welfare &&
        !state.foundingProgress.has(FoundingMilestone.welfareIntroSeen)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.state.foundingProgress.has(FoundingMilestone.welfareIntroSeen)) {
          controller.recordMilestone(FoundingMilestone.welfareIntroSeen);
        }
      });
    }
    final profile = engineer.profile;
    final workflowState = EmployeeWorkflowEngine.forEngineer(state, engineerId);
    final assignment = state.assignmentForEngineer(engineerId);
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
    final guided = ProgressionEngine.guidedAction(state);
    final isGuideTarget = guided != null && guided.targetType == TaskTargetType.employeeDetail && guided.targetId == engineerId;

    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          if (guided != null) ...[
            _GuideBanner(
              action: guided,
              highlighted: isGuideTarget,
              // Only wired for the two cases that are genuine navigation
              // shortcuts (opening a modal / a different screen) — every
              // other guided sub-case already has its matching button
              // inline on this same screen (SkillSheet/sales-start card,
              // the InterviewOffer/Offer cards), so duplicating that
              // wiring here would risk drifting out of sync with
              // [ProgressionEngine.guidedAction]'s own sub-case logic.
              onCta: !isGuideTarget
                  ? null
                  : switch (guided.stage) {
                      FoundingStage.skillSheet => () => _editSkillSheet(context, engineer!, skillSheet),
                      FoundingStage.clientInterview when state.proposalForEngineer(engineerId)?.currentStep == SelectionStep.clientInterview =>
                        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientInterviewScreen(applicationId: state.proposalForEngineer(engineerId)!.id))),
                      _ => null,
                    },
            ),
            const SizedBox(height: 12),
          ],
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
              EngineerStatusChip(state: workflowState),
            ],
          ),
          const SizedBox(height: 10),
          // "現在の状況" first, above skills/personality/history — a
          // first-time player needs one glance to know what this employee
          // is doing right now, not a scroll (Playable 0.4C.3 §27-32).
          _CurrentStatusCard(state: state, engineer: engineer, workflowState: workflowState),
          const SizedBox(height: 12),
          if (workflowState == EmployeeWorkflowState.waiting)
            _WaitingWarningBanner(
              weeks: waitingWeeks,
              monthlySalary: engineer.salary,
            ),
          _ConditionCard(engineer: engineer, state: state),
          const SizedBox(height: 12),
          if (assignment != null && assignment.remainingWeeks <= 4 && assignment.contractDecision == ContractDecision.undecided) ...[
            _ContractPreferenceHint(engineer: engineer, assignment: assignment, currentWeek: state.week),
            const SizedBox(height: 12),
          ],
          _SectionCard(title:'スキルシート / 営業',children:[
            _Row('会社信頼',engineer.companyTrust >= 70 ? '高い' : engineer.companyTrust >= 45 ? '普通' : '低下中'),
            _Row(languageLabels[profile.mainLanguage] ?? profile.mainLanguage.name,'実際 ${formatExperience(profile.skillFor(profile.mainLanguage).actualExperienceMonths)} / 記載 ${formatExperience(skillSheet.displayedLanguageExperience[profile.mainLanguage] ?? 0)}'),
            _Row('Backend','実際 Lv.${profile.techSkills.backend} / 記載 Lv.${skillSheet.displayedBackend}'),
            _Row('Leader','実際 Lv.${profile.techSkills.leader} / 記載 Lv.${skillSheet.displayedLeader}'),
            _Row('営業状態',engineer.salesStatus==SalesStatus.selling?'営業中（公開先 ${state.unlockedClientCount}社）':EmployeeWorkflowEngine.labels[workflowState]!),
            _Row('参画可能','Week ${engineer.availableFromWeek}〜'),
            const Text('会社信頼が低い社員は、現場の増員情報を持ち帰りにくくなります。',style:TextStyle(fontSize:12,color:Colors.black54)),
            Row(children:[Expanded(child:OutlinedButton(onPressed:()=>_editSkillSheet(context,engineer!,skillSheet),child:const Text('営業用記載を編集'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:engineer.salesStatus==SalesStatus.selling?null:()=>_confirmSalesStart(context,engineer!,skillSheet),child:const Text('営業を開始する')))]),
          ]),
          if(interviewOffers.isNotEmpty)...[const SizedBox(height:12),_SectionCard(title:'面談依頼',children:[for(final offer in interviewOffers) _InterviewOfferCard(offer:offer,project:state.openProjects.firstWhere((e)=>e.project.id==offer.projectId).project)])],
          if(assignment != null && assignment.remainingWeeks <= 4 && assignment.contractDecision==ContractDecision.undecided)...[const SizedBox(height:12),_SectionCard(title:'契約更新判断（終了4週前）',children:[Text('${assignment.project.title} / 残り${assignment.remainingWeeks}週'),Row(children:[Expanded(child:FilledButton(onPressed:(){context.game.decideContract(engineerId,extend:true);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${assignment.project.title}の契約延長を決めました')));},child:const Text('延長する'))),const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:(){context.game.decideContract(engineerId,extend:false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${assignment.project.title}は満了で撤退します')));},child:const Text('撤退する')))])])],
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
              SkillChipRow(chips: _techSkillChips(profile.techSkills)),
              const SizedBox(height: 10),
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
            title:
                '営業状況  並行営業 ${applications.length} / $maxParallelProposalsPerEmployee',
            children: [
              if (applications.isEmpty) const Text('営業中の案件はありません。'),
              for (final application in applications) ...[
                _ApplicationRow(application: application),
                const Divider(height: 18),
              ],
              if (applications.isEmpty && engineer.salesStatus == SalesStatus.selling)
                Text('面談依頼待ち\n現在${state.unlockedClientCount}社へ公開中です。条件に合う案件が見つかると面談依頼が届きます。'),
            ],
          ),
          if (pendingOffers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: '参画オファー比較・回答',
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
    context.game.recordMilestone(FoundingMilestone.inspectSkillSheet);
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
    final accepted=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('${engineer.profile.name}の営業を開始します'),content:Text('公開先:\n$clients\n\n参画可能: ${engineer.availableFromWeek<=state.week?'現在':'Week ${engineer.availableFromWeek}'}\nスキルシート: ${SalesEngine.riskLabel(SalesEngine.riskFor(engineer,sheet))}\n\n条件に合う案件があると、取引先から面談依頼が届きます。'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('戻る')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('営業開始'))]));
    if(accepted==true&&context.mounted)context.game.startSales(engineer.id);
  }
}

/// The single "what is this employee doing right now" block, driven by
/// [EmployeeWorkflowState] — the same derived state Home and the employee
/// list use (Playable 0.4C.3 §12-17, §27-32). Deliberately placed right
/// under the header so a first-time player never has to scroll to find it.
class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({required this.state, required this.engineer, required this.workflowState});

  final GameState state;
  final Engineer engineer;
  final EmployeeWorkflowState workflowState;

  @override
  Widget build(BuildContext context) {
    final color = switch (workflowState) {
      EmployeeWorkflowState.assigned => Colors.blue,
      EmployeeWorkflowState.finalOfferPending => Colors.red,
      EmployeeWorkflowState.assignmentScheduled => Colors.purple,
      EmployeeWorkflowState.clientInterviewActionRequired => Colors.deepOrange,
      EmployeeWorkflowState.waitingSelectionResult => Colors.orange,
      EmployeeWorkflowState.interviewRequestPending => Colors.deepOrange,
      EmployeeWorkflowState.selling => Colors.teal,
      EmployeeWorkflowState.waiting => Colors.red,
    };

    String detail;
    Widget? action;
    switch (workflowState) {
      case EmployeeWorkflowState.assigned:
        final a = state.assignmentForEngineer(engineer.id)!;
        detail = '${a.project.title}\n'
            '残り${a.remainingWeeks}週 / 単価 ${formatYen(a.project.monthlyRate)}\n'
            '月間想定粗利 ${formatYen(MatchingEngine.monthlyProfit(engineer, a.project))}';
      case EmployeeWorkflowState.assignmentScheduled:
        final p = state.proposals.firstWhere((p) => p.engineerId == engineer.id && p.status == ApplicationStatus.accepted);
        detail = '${p.project.title}\n'
            'Week ${p.assignWeek} から参画開始\n'
            '参画開始までは待機給与が発生します。';
      case EmployeeWorkflowState.finalOfferPending:
        final o = state.offers.firstWhere((o) => o.employeeId == engineer.id && o.status == OfferStatus.pending);
        detail = '${state.proposals.firstWhere((p) => p.id == o.applicationId).project.title}\n'
            '月単価 ${formatYen(o.monthlyRate)}\n'
            '下記「参画オファー比較・回答」から回答してください。';
      case EmployeeWorkflowState.clientInterviewActionRequired:
        final p = state.proposals.firstWhere((p) =>
            p.engineerId == engineer.id &&
            p.status == ApplicationStatus.active &&
            p.currentStep == SelectionStep.clientInterview);
        detail = '${p.project.title}\n今週中に面談をプレイするか、社員に任せてください。';
        action = FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClientInterviewScreen(applicationId: p.id)),
          ),
          child: const Text('面談をプレイ'),
        );
      case EmployeeWorkflowState.waitingSelectionResult:
        final p = state.proposals.firstWhere((p) => p.engineerId == engineer.id && p.status == ApplicationStatus.active);
        detail = '${p.project.title}\n'
            '現在: ${selectionStepLabels[p.currentStep]}\n'
            '次の週へ進めると選考が進みます。';
      case EmployeeWorkflowState.interviewRequestPending:
        detail = '下記「面談依頼」から回答してください。';
      case EmployeeWorkflowState.selling:
        detail = 'SkillSheet公開先 ${state.unlockedClientCount}社\n面談依頼待ちです。';
      case EmployeeWorkflowState.waiting:
        detail = '営業を開始すると、案件の面談依頼が届くようになります。';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            EmployeeWorkflowEngine.labels[workflowState]!,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color.withValues(alpha: 0.95)),
          ),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(fontSize: 12.5, height: 1.4)),
          if (action != null) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ),
    );
  }
}

/// 社員コンディション (Playable 0.4C §6, §11-15, §38): Morale/Trust labels,
/// preference, turnover-risk warning, current PC + upgrade action, and the
/// last few morale/trust change reasons.
class _ConditionCard extends StatelessWidget {
  const _ConditionCard({required this.engineer, required this.state});

  final Engineer engineer;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final risk = MoraleEngine.turnoverRisk(engineer);
    final pcTier = state.equipmentFor(engineer.id)?.pcTier ?? PcTier.standardLaptop;
    final recent = engineer.relationshipHistory.reversed.take(maxRelationshipHistory).toList();
    return _SectionCard(
      title: '社員コンディション',
      children: [
        _Row('モチベーション', '${MoraleEngine.moraleEmoji(engineer.morale)} ${MoraleEngine.moraleLabel(engineer.morale)}'),
        _Row('会社への信頼', '${MoraleEngine.trustSymbol(engineer.companyTrust)} ${MoraleEngine.trustLabel(engineer.companyTrust)}'),
        _Row('重視すること', engineer.preference.label),
        if (risk != TurnoverRisk.low)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '⚠ 退職リスク: ${MoraleEngine.turnoverRiskLabel(risk)}',
              style: TextStyle(
                color: risk == TurnoverRisk.high ? Colors.red.shade700 : Colors.orange.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        const Divider(height: 18),
        Row(
          children: [
            Expanded(child: _Row('貸与PC', pcTierConfigs[pcTier]!.label)),
            OutlinedButton(
              onPressed: () => _showPcUpgradeDialog(context, engineer, pcTier),
              child: const Text('アップグレード'),
            ),
          ],
        ),
        if (recent.isNotEmpty) ...[
          const Divider(height: 18),
          const Text('最近の変化', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          const SizedBox(height: 4),
          for (final event in recent) _RelationshipHistoryRow(event: event),
        ],
      ],
    );
  }
}

class _RelationshipHistoryRow extends StatelessWidget {
  const _RelationshipHistoryRow({required this.event});

  final EmployeeRelationshipEvent event;

  @override
  Widget build(BuildContext context) {
    String signed(int delta) => delta == 0 ? '' : (delta > 0 ? '+$delta' : '$delta');
    final parts = <String>[
      if (event.moraleDelta != 0) 'モチベ${signed(event.moraleDelta)}',
      if (event.trustDelta != 0) '信頼${signed(event.trustDelta)}',
    ];
    final positive = event.moraleDelta + event.trustDelta >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        'W${event.week}  ${parts.join(' / ')}  ${event.reason}',
        style: TextStyle(
          fontSize: 12,
          color: positive ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

Future<void> _showPcUpgradeDialog(BuildContext context, Engineer engineer, PcTier current) async {
  final chosen = await showDialog<PcTier>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text('${engineer.profile.name}さんのPCをアップグレード'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tier in PcTier.values)
            ListTile(
              leading: Icon(tier == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(pcTierConfigs[tier]!.label),
              subtitle: Text('${formatYen(pcTierConfigs[tier]!.cost)}${tier == current ? ' (現在)' : ''}'),
              onTap: tier == current ? null : () => Navigator.pop(dialog, tier),
            ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('閉じる'))],
    ),
  );
  if (chosen != null && chosen != current && context.mounted) {
    context.game.upgradePc(engineer.id, chosen);
  }
}

class _ContractPreferenceHint extends StatelessWidget {
  const _ContractPreferenceHint({required this.engineer, required this.assignment, required this.currentWeek});

  final Engineer engineer;
  final ActiveAssignment assignment;
  final int currentWeek;

  @override
  Widget build(BuildContext context) {
    final preference = MoraleEngine.contractPreference(engineer, assignment, currentWeek);
    if (preference == ContractPreference.neutral) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '本人の希望: ${MoraleEngine.contractPreferenceLabel(preference)}',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InterviewOfferCard extends StatelessWidget { const _InterviewOfferCard({required this.offer,required this.project}); final InterviewOffer offer; final Project project; @override Widget build(BuildContext context){
  // `Project.paymentTermDays` is never populated by ProjectGenerator (it
  // just sits at the class default of 30) — `paymentTermDaysById` looks up
  // the real, canonical value from the client instead. Reading the dead
  // field here was why this card could show "30日" while Selection/Offer
  // screens correctly showed the client's actual (possibly 60-day) term
  // for the very same project (Playable 0.4C.3 §22-26).
  final paymentTermDays=paymentTermDaysById(project.clientId);
  final good=<String>[if(offer.skillSheetMatch>=70)'スキルシートとの相性が高い',if(paymentTermDays==30)'30日サイト'];final cautions=<String>[if(project.competitionLevel>=4)'競争度が高い',if(project.difficulty>=4)'要求水準が高い'];
  // Both mutations remove `offer` from the pending list this card is built
  // from, unmounting the card itself — capture the messenger first (same
  // stale-context class of bug as `_OfferRow._accept`/`_decline`).
  void decline(){final messenger=ScaffoldMessenger.of(context);context.game.declineInterviewOffer(offer.id);messenger.showSnackBar(SnackBar(content:Text('${project.title}の面談依頼を断りました')));}
  void accept(){final messenger=ScaffoldMessenger.of(context);context.game.acceptInterviewOffer(offer.id);messenger.showSnackBar(SnackBar(content:Text('${project.title}の選考に進みます')));}
  return Card(color:Colors.blue.shade50,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('面談依頼！',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),Text('${clientNameById(project.clientId)}  ${project.title}',style:const TextStyle(fontWeight:FontWeight.bold)),Text('単価 ${formatYen(project.monthlyRate)} / ${project.location.name} / ${project.industry.name}'),Text('契約 ${project.contractTermMonths}か月 / 支払 $paymentTermDays日'),if(good.isNotEmpty)Text('良い点\n・${good.take(2).join('\n・')}'),if(cautions.isNotEmpty)Text('注意点\n・${cautions.take(2).join('\n・')}'),Row(children:[Expanded(child:OutlinedButton(onPressed:decline,child:const Text('断る'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:accept,child:const Text('面談へ進む')))])]))); } }

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
              ? (application.currentStep == SelectionStep.clientInterview
                  // Client interviews resolve immediately when played/auto
                  // -resolved, not on next week's tick — saying "次週に判定
                  // されます" here directly contradicted the action buttons
                  // shown below for the same card (Playable 0.4C.3 §17-20).
                  ? '操作が必要・客先面談を進めてください'
                  : '結果待ち・次週に判定されます')
              : application.status == ApplicationStatus.offered
                  ? 'Offer獲得・今週中に回答してください'
                  : '選考終了',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: application.status != ApplicationStatus.active
                ? Colors.black54
                : application.currentStep == SelectionStep.clientInterview
                    ? Colors.deepOrange
                    : Colors.orange.shade800,
          ),
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

  Future<void> _accept(BuildContext context) async {
    final controller = context.game;
    // Capture a context that survives the coming rebuild — accepting
    // removes `offer` from `pendingOffers`, which unmounts this whole
    // "参画オファー比較・回答" section (and this widget's own `context`
    // with it) the instant `acceptOffer` calls notifyListeners. Same class
    // of bug as the recruitment-interview stale-context fix in 0.4C.1/§54.
    final stableContext = Navigator.of(context).context;
    controller.acceptOffer(offer.id);
    if (!stableContext.mounted) return;
    final engineer = controller.state.engineerById(offer.employeeId);
    // The whole point: the player must never wonder "did that work? when do
    // they start?" after accepting — say so immediately, explicitly
    // (Playable 0.4C.3 §5, §54).
    await showDialog<void>(
      context: stableContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('参画オファーを受諾しました'),
        content: Text(
          '${engineer.profile.name}\n\n'
          '${application.project.title}\n\n'
          '月単価: ${formatYen(offer.monthlyRate)}\n'
          '参画開始: Week ${offer.startWeek}\n\n'
          '現在: 参画開始待ち',
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
      ),
    );
  }

  void _decline(BuildContext context) {
    // Same reasoning as `_accept`: capture the messenger before the
    // mutation removes this row from the tree.
    final messenger = ScaffoldMessenger.of(context);
    context.game.declineOffer(offer.id);
    messenger.showSnackBar(
      SnackBar(content: Text('${application.project.title} の参画オファーを辞退しました')),
    );
  }

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
            Row(
              children: [
                Text('月単価 ${formatYen(offer.monthlyRate)} / '),
                FitBadge(fit: PlayerVisibleFit.fromScore(application.fitScore)),
              ],
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
                    onPressed: () => _accept(context),
                    child: const Text('受諾'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decline(context),
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

/// 創業ガイド banner (Playable 0.4C.2 §18, §38): a small "STEP n/total"
/// badge on every screen while the tutorial is active, plus — only on the
/// screen the current [GuidedAction] actually targets — the action itself,
/// so it never gets buried at the bottom of a long SkillSheet/営業 card.
class _GuideBanner extends StatelessWidget {
  const _GuideBanner({required this.action, required this.highlighted, required this.onCta});

  final GuidedAction action;
  final bool highlighted;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    if (!highlighted) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(20)),
          child: Text(
            '創業ガイド STEP ${action.stepNumber} / ${action.totalSteps}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '創業ガイド STEP ${action.stepNumber} / ${action.totalSteps}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
          ),
          const SizedBox(height: 4),
          Text(action.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 3),
          Text(action.description, style: const TextStyle(fontSize: 12.5, height: 1.4)),
          if (onCta != null) ...[
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: onCta, child: Text(action.ctaLabel ?? '確認する'))),
          ],
        ],
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
