import 'package:flutter/material.dart';
import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../widgets/founding_dialogs.dart';

class ClientInterviewScreen extends StatelessWidget{
  const ClientInterviewScreen({super.key,required this.applicationId,this.step=SelectionStep.clientInterview,this.onResultContinue});
  final String applicationId;
  /// [SelectionStep.upperCompanyInterview] reuses this exact screen for the
  /// Founding Prologue's shorter, player-attended round (Playable 0.5A
  /// §45-49) — same mechanism, fewer questions, different labels.
  final SelectionStep step;
  /// Overrides the result screen's default "戻る" action — the Prologue
  /// needs to continue its own scripted flow instead of just popping (§48-52).
  final VoidCallback? onResultContinue;
  bool get _isUpper => step==SelectionStep.upperCompanyInterview;
  @override Widget build(BuildContext context){final state=context.game.state;final p=state.proposals.where((p)=>p.id==applicationId).firstOrNull;if(p==null)return const Scaffold(body:Center(child:Text('案件が見つかりません')));final e=state.engineerById(p.engineerId);final sessions=state.clientInterviews.where((s)=>s.applicationId==applicationId && s.step==step).toList();if(sessions.isEmpty){WidgetsBinding.instance.addPostFrameCallback((_){context.game.startClientInterview(applicationId,step:step);});return const Scaffold(body:Center(child:CircularProgressIndicator()));}final s=sessions.last;final label=_isUpper?'上位会社面談':'客先面談';if(s.completed){
    if(!_isUpper && !state.foundingProgress.hasSeen(OneTimeEvent.clientInterviewCelebration)){
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final controller=context.game;
        final dialog=buildFoundingEventDialog(OneTimeEvent.clientInterviewCelebration,controller.state);
        controller.markTutorialSeen(OneTimeEvent.clientInterviewCelebration);
        if(dialog!=null && context.mounted) await showFoundingEventDialog(context,dialog);
      });
    }
    return _Result(session:s,employeeName:e.profile.name,projectTitle:p.project.title,label:label,onContinue:onResultContinue);
  }
    final q=s.questions[s.currentQuestionIndex],a=s.employeeAnswers[s.currentQuestionIndex];return Scaffold(appBar:AppBar(title:Text(label)),body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[Text('質問 ${s.currentQuestionIndex+1} / ${s.questions.length}',style:Theme.of(context).textTheme.titleLarge),Text('案件: ${p.project.title}'),Text('社員: ${e.profile.name}'),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('面接官',style:TextStyle(fontWeight:FontWeight.bold)),Text('「${q.text}」'),const SizedBox(height:12),Text(e.profile.name,style:const TextStyle(fontWeight:FontWeight.bold)),Text('「${a.text}」')]))),if(s.interviewerReactions.isNotEmpty)...[Card(color:Colors.orange.shade50,child:Padding(padding:const EdgeInsets.all(12),child:Text(s.interviewerReactions.last))),if(s.deepDiveText!=null)Text('深掘り: ${s.deepDiveText}')],const SizedBox(height:10),const Text('営業として何を補足しますか？',style:TextStyle(fontWeight:FontWeight.bold)),for(final choice in ClientInterviewEngine.choices(q))Padding(padding:const EdgeInsets.only(top:8),child:OutlinedButton(key:ValueKey('follow-${choice.name}'),style:OutlinedButton.styleFrom(alignment:Alignment.centerLeft,padding:const EdgeInsets.all(14)),onPressed:()=>context.game.chooseClientInterviewFollowUp(s.id,choice),child:Text(clientInterviewFollowUpLabels[choice]!))),if(s.currentQuestionIndex>0)ExpansionTile(title:Text('過去の質問 (${s.currentQuestionIndex})'),children:[for(var i=0;i<s.currentQuestionIndex;i)ListTile(title:Text(s.questions[i].text),subtitle:Text(s.employeeAnswers[i].text))])])));}
}
class _Result extends StatelessWidget{const _Result({required this.session,required this.employeeName,required this.projectTitle,required this.label,this.onContinue});final ClientInterviewSession session;final String employeeName,projectTitle,label;final VoidCallback? onContinue;@override Widget build(BuildContext context){final passed=session.result==ClientInterviewResult.passed;return Scaffold(appBar:AppBar(title:Text('$label結果')),body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[Text(employeeName,style:Theme.of(context).textTheme.titleLarge),Text(projectTitle),const SizedBox(height:16),Text(passed?'合格':'不合格',style:TextStyle(fontSize:30,fontWeight:FontWeight.bold,color:passed?Colors.green:Colors.red)),const SizedBox(height:12),Text(passed?'評価:\n・案件に沿った経験が評価された\n・受け答えが安定していた\n\n次: 選考の次ステップ':'主な理由:\n・${session.mismatchFailure?'SkillSheet記載に対して具体的な経験が不足':'他候補がより案件要件に合致'}\n\n営業メモ:\n「強調する経験の見せ方を見直しましょう」'),const SizedBox(height:20),FilledButton(onPressed:onContinue??()=>Navigator.pop(context),child:Text(onContinue==null?'社員を見る':'続ける'))])));}}
extension _FirstOrNull<T> on Iterable<T>{T? get firstOrNull=>isEmpty?null:first;}
