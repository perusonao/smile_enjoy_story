import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_interview.dart';
import '../../game/public_demo/public_demo_recruitment.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../../game/public_demo/public_demo_state.dart';

class PublicDemo01PlaceholderScreen extends StatefulWidget {
  const PublicDemo01PlaceholderScreen({super.key});
  @override
  State<PublicDemo01PlaceholderScreen> createState() => _PublicDemo01PlaceholderScreenState();
}

class _PublicDemo01PlaceholderScreenState extends State<PublicDemo01PlaceholderScreen> {
  static const _mvpMonthlyExpenses = 800000;
  PublicDemoState _state = PublicDemoState.aprilStart();
  List<PublicDemoEngineerSales> _engineers = publicDemoInitialEngineers;
  List<PublicDemoApplicant> _applicants = publicDemoMayApplicants;

  String _yen(int value) => '¥$value';
  void _setEngineerStage(int i, PublicDemoSalesStage stage) => setState(() { final n=[..._engineers]; n[i]=n[i].copyWith(stage:stage); _engineers=n; });
  void _setApplicantStage(int i, PublicDemoApplicantStage stage) => setState(() { final n=[..._applicants]; n[i]=n[i].copyWith(stage:stage); _applicants=n; });

  void _runEngineerInterview(int i, PublicDemoInterviewType type) {
    if (type == PublicDemoInterviewType.partner && _state.salesRemaining <= 0) return;
    final e=_engineers[i]; final r=PublicDemoInterviewEvaluator.evaluate(type:type, profile:e.interviewProfile);
    setState(() { if(type==PublicDemoInterviewType.partner) _state=_state.useSalesSlot(); final n=[..._engineers]; n[i]=e.copyWith(stage:switch((type,r.passed)){(PublicDemoInterviewType.partner,true)=>PublicDemoSalesStage.partnerInterviewPassed,(PublicDemoInterviewType.partner,false)=>PublicDemoSalesStage.partnerInterviewFailed,(PublicDemoInterviewType.client,true)=>PublicDemoSalesStage.clientInterviewPassed,(PublicDemoInterviewType.client,false)=>PublicDemoSalesStage.clientInterviewFailed},lastInterviewScore:r.score); _engineers=n; });
  }

  void _finishApril() { final ordered=_engineers.where((e)=>e.stage==PublicDemoSalesStage.ordered).length; setState(()=>_state=_state.advanceToMay(monthlyExpenses:_mvpMonthlyExpenses,orderedEngineers:ordered)); }
  void _interviewApplicant(int i) { if(_state.salesRemaining<=0)return; setState(()=>_state=_state.useSalesSlot()); _setApplicantStage(i,PublicDemoApplicantStage.interviewed); }
  void _offerApplicant(int i) { final a=_applicants[i]; _setApplicantStage(i,a.acceptanceScore>=60?PublicDemoApplicantStage.offerAccepted:PublicDemoApplicantStage.offerDeclined); }

  void _preEntryPartnerInterview(int i) {
    if(_state.salesRemaining<=0)return; final a=_applicants[i];
    setState(() { _state=_state.useSalesSlot(); final n=[..._applicants]; n[i]=a.copyWith(stage:a.salesSkillFit>=60?PublicDemoApplicantStage.preEntryPartnerPassed:PublicDemoApplicantStage.preEntryPartnerFailed); _applicants=n; });
  }
  void _preEntryClientInterview(int i) {
    final a=_applicants[i];
    // Client interview is unattended by sales and consumes no sales slot.
    final passed=a.salesSkillFit>=65;
    _setApplicantStage(i,passed?PublicDemoApplicantStage.preEntryClientPassed:PublicDemoApplicantStage.preEntryClientFailed);
  }

  Widget _engineerCard(int i) { final e=_engineers[i]; final failed=e.stage==PublicDemoSalesStage.partnerInterviewFailed||e.stage==PublicDemoSalesStage.clientInterviewFailed; return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(e.name,style:Theme.of(context).textTheme.titleMedium),Text(e.summary),Text('状態：${e.stage.name}'),
    if(e.stage==PublicDemoSalesStage.waiting)FilledButton.tonal(onPressed:()=>_setEngineerStage(i,PublicDemoSalesStage.skillSheet),child:const Text('SkillSheetを確認')),
    if(e.stage==PublicDemoSalesStage.skillSheet)FilledButton(onPressed:()=>_setEngineerStage(i,PublicDemoSalesStage.selling),child:const Text('営業を開始')),
    if(e.stage==PublicDemoSalesStage.selling)FilledButton.tonal(onPressed:()=>_setEngineerStage(i,PublicDemoSalesStage.introduced),child:const Text('案件紹介を確認')),
    if(e.stage==PublicDemoSalesStage.introduced)FilledButton(onPressed:_state.salesRemaining==0?null:()=>_runEngineerInterview(i,PublicDemoInterviewType.partner),child:const Text('上位会社面談（営業1枠）')),
    if(e.stage==PublicDemoSalesStage.partnerInterviewPassed)FilledButton.tonal(onPressed:()=>_runEngineerInterview(i,PublicDemoInterviewType.client),child:const Text('客先面談を実施（自動）')),
    if(e.stage==PublicDemoSalesStage.clientInterviewPassed)FilledButton(onPressed:()=>_setEngineerStage(i,PublicDemoSalesStage.ordered),child:const Text('5月分の発注を受注')),
    if(failed)FilledButton.tonal(onPressed:()=>_setEngineerStage(i,PublicDemoSalesStage.selling),child:const Text('別案件の営業へ戻る')),
  ])))); }

  Widget _applicantCard(int i) { final a=_applicants[i]; return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(a.name,style:Theme.of(context).textTheme.titleMedium),Text(a.resumeSummary),Text('状態：${a.stage.name}'),
    if(a.stage==PublicDemoApplicantStage.applied)FilledButton.tonal(onPressed:()=>_setApplicantStage(i,PublicDemoApplicantStage.resumeReviewed),child:const Text('経歴書を確認')),
    if(a.stage==PublicDemoApplicantStage.resumeReviewed)FilledButton(onPressed:_state.salesRemaining==0?null:()=>_interviewApplicant(i),child:const Text('採用面談（営業1枠）')),
    if(a.stage==PublicDemoApplicantStage.interviewed)...[Text('面談評価：${a.interviewScore}'),Wrap(spacing:8,children:[FilledButton(onPressed:a.interviewScore>=60?()=>_offerApplicant(i):null,child:const Text('合格・内定')),OutlinedButton(onPressed:()=>_setApplicantStage(i,PublicDemoApplicantStage.rejected),child:const Text('不採用'))])],
    if(a.stage==PublicDemoApplicantStage.offerAccepted)...[const Text('内定承諾：6月入社予定'),FilledButton.tonal(onPressed:()=>_setApplicantStage(i,PublicDemoApplicantStage.preEntrySkillSheet),child:const Text('入社前SkillSheetを確認'))],
    if(a.stage==PublicDemoApplicantStage.preEntrySkillSheet)FilledButton(onPressed:()=>_setApplicantStage(i,PublicDemoApplicantStage.preEntrySelling),child:const Text('入社前営業を開始')),
    if(a.stage==PublicDemoApplicantStage.preEntrySelling)FilledButton.tonal(onPressed:()=>_setApplicantStage(i,PublicDemoApplicantStage.preEntryIntroduced),child:const Text('6月案件の紹介を確認')),
    if(a.stage==PublicDemoApplicantStage.preEntryIntroduced)FilledButton(onPressed:_state.salesRemaining==0?null:()=>_preEntryPartnerInterview(i),child:const Text('上位会社面談（営業1枠）')),
    if(a.stage==PublicDemoApplicantStage.preEntryPartnerPassed)FilledButton.tonal(onPressed:()=>_preEntryClientInterview(i),child:const Text('客先面談（立会不可・営業枠0）')),
    if(a.stage==PublicDemoApplicantStage.preEntryPartnerFailed)FilledButton.tonal(onPressed:()=>_setApplicantStage(i,PublicDemoApplicantStage.preEntrySelling),child:const Text('別案件の営業へ戻る')),
    if(a.stage==PublicDemoApplicantStage.preEntryClientPassed)FilledButton(onPressed:()=>_setApplicantStage(i,PublicDemoApplicantStage.juneOrdered),child:const Text('6月分の発注を受注')),
    if(a.stage==PublicDemoApplicantStage.preEntryClientFailed)FilledButton.tonal(onPressed:()=>_setApplicantStage(i,PublicDemoApplicantStage.preEntrySelling),child:const Text('客先不合格：別案件の営業へ戻る')),
    if(a.stage==PublicDemoApplicantStage.juneOrdered)const Text('6月入社と同時に案件参画予定'),if(a.stage==PublicDemoApplicantStage.offerDeclined)const Text('内定辞退'),if(a.stage==PublicDemoApplicantStage.rejected)const Text('不採用'),
  ])))); }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('S.E.S. Public Demo 0.1')),body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
    Text('${_state.month}月',style:Theme.of(context).textTheme.headlineMedium),Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('現預金 ${_yen(_state.cash)}'),Text('在籍 技術者${_state.engineerCount}名 / 総務${_state.adminCount}名'),Text('参画 ${_state.engineersAssigned}名 / 待機 ${_state.engineersWaiting}名'),Text('営業対応 ${_state.salesUsed}/${_state.salesCapacity}（残り${_state.salesRemaining}枠）')]))),
    if(_state.month==4)...[Text('技術者',style:Theme.of(context).textTheme.titleLarge),for(var i=0;i<_engineers.length;i++)_engineerCard(i),OutlinedButton(onPressed:_finishApril,child:const Text('4月を終了して5月へ'))]else...[Text('5月：応募者一覧',style:Theme.of(context).textTheme.titleLarge),const Text('採用面談と上位会社面談は同じ月4営業枠。客先面談は営業枠を消費しません。'),for(var i=0;i<_applicants.length;i++)_applicantCard(i),const SizedBox(height:12),Text('社員状況',style:Theme.of(context).textTheme.titleLarge),for(final e in _engineers)ListTile(title:Text(e.name),subtitle:Text(e.stage==PublicDemoSalesStage.ordered?'5月：案件参画':'5月：待機'))]
  ])));
}
