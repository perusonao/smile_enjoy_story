import 'package:flutter/material.dart';
import '../../app/game_scope.dart';
import '../../app/nav_scope.dart';
import '../../game/game.dart';
import '../main_shell.dart';
import '../widgets/founding_dialogs.dart';

class RecruitmentInterviewScreen extends StatelessWidget {
  const RecruitmentInterviewScreen({super.key, required this.applicantId});
  final String applicantId;
  @override Widget build(BuildContext context) {
    final c=context.game, state=c.state;
    final found=state.applicants.where((e)=>e.applicant.id==applicantId).toList();
    if(found.isEmpty) return const Scaffold(body: Center(child: Text('応募者が見つかりません')));
    final applicant=found.first.applicant;
    final sessions=state.recruitmentInterviews.where((s)=>s.applicantId==applicantId).toList();
    if(sessions.isEmpty){ WidgetsBinding.instance.addPostFrameCallback((_){c.interviewApplicant(applicantId);}); return const Scaffold(body: Center(child:CircularProgressIndicator())); }
    final s=sessions.last;
    return Scaffold(appBar:AppBar(title:Text('${applicant.name}との面接')),body:SafeArea(child: s.questionsComplete ? (s.companyAnswer==null ? _Reverse(applicantId:applicantId,name:applicant.name,s:s) : _Summary(applicantId:applicantId,name:applicant.name,s:s)) : _Questions(applicantId:applicantId,name:applicant.name,s:s)));
  }
}

class _Questions extends StatelessWidget {
  const _Questions({required this.applicantId,required this.name,required this.s}); final String applicantId,name; final RecruitmentInterviewSession s;
  @override Widget build(BuildContext context)=>ListView(key:ValueKey(s.selectedQuestions.length),padding:const EdgeInsets.all(16),children:[
    Text('質問 ${s.selectedQuestions.length+1} / 3',style:Theme.of(context).textTheme.titleLarge),const Text('何を知りたいか選んでください。すべては聞けません。'),
    if(s.applicantAnswers.isNotEmpty)...[const SizedBox(height:12),_Talk(name:name,a:s.applicantAnswers.last,o:s.observations.last),if(s.applicantAnswers.length>1)ExpansionTile(title:Text('過去の回答 (${s.applicantAnswers.length-1})'),children:[for(var i=0;i<s.applicantAnswers.length-1;i++)_Talk(name:name,a:s.applicantAnswers[i],o:s.observations[i])])],
    const SizedBox(height:12),for(final q in InterviewQuestionCategory.values)Padding(padding:const EdgeInsets.only(bottom:8),child:OutlinedButton(onPressed:s.selectedQuestions.contains(q)?null:()=>context.game.askRecruitmentQuestion(applicantId,q),style:OutlinedButton.styleFrom(alignment:Alignment.centerLeft,padding:const EdgeInsets.all(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(interviewQuestionLabels[q]!,style:const TextStyle(fontWeight:FontWeight.bold)),Text(interviewQuestionTexts[q]!)])))
  ]);
}
class _Talk extends StatelessWidget { const _Talk({required this.name,required this.a,required this.o}); final String name;final ApplicantAnswer a;final InterviewObservation o;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('あなた',style:TextStyle(fontWeight:FontWeight.bold)),Text('「${a.question}」'),const SizedBox(height:10),Text(name,style:const TextStyle(fontWeight:FontWeight.bold)),Text('「${a.answer}」'),const Divider(),Text('観察・${o.confidence==ObservationConfidence.high?'かなり確信':o.confidence==ObservationConfidence.medium?'ややそう感じる':'まだ不確か'}',style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.deepOrange)),Text(o.text)])));
}
class _Reverse extends StatelessWidget { const _Reverse({required this.applicantId,required this.name,required this.s});final String applicantId,name;final RecruitmentInterviewSession s;
  @override Widget build(BuildContext context){final choices=companyAnswerChoices[s.reverseQuestion]!;return ListView(key:const ValueKey('reverse'),padding:const EdgeInsets.all(16),children:[Text('応募者からの質問',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(16),child:Text('$name\n「${reverseQuestionTexts[s.reverseQuestion]}」'))),const SizedBox(height:12),const Text('会社としてどう答えますか？'),for(var i=0;i<choices.length;i++)Padding(padding:const EdgeInsets.only(top:8),child:FilledButton.tonal(onPressed:()=>context.game.answerRecruitmentReverseQuestion(applicantId,i),style:FilledButton.styleFrom(alignment:Alignment.centerLeft,padding:const EdgeInsets.all(16)),child:Text(choices[i].text)))]);}
}
class _Summary extends StatelessWidget {
  const _Summary({required this.applicantId,required this.name,required this.s});
  final String applicantId,name; final RecruitmentInterviewSession s;

  Future<void> _decide(BuildContext context, InterviewOutcome outcome) async {
    final controller = context.game;
    final navigator = Navigator.of(context);
    final tabIndex = NavScope.of(context);
    controller.completeRecruitmentInterview(applicantId, outcome);
    var accepted = false;
    if (outcome == InterviewOutcome.hired) {
      final before = controller.state.pendingHires.length;
      controller.hireApplicant(applicantId);
      accepted = controller.state.pendingHires.length > before;
    } else {
      controller.rejectApplicant(applicantId);
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(outcome == InterviewOutcome.rejected ? '不採用' : accepted ? '内定承諾！' : '内定辞退'),
        content: Text(outcome == InterviewOutcome.rejected
            ? '$nameさんは今回採用しませんでした。'
            : accepted
                ? '$nameさんが入社を承諾しました。\n\n次: 入社後、案件を探しましょう。'
                : '$nameさんは内定を辞退しました。\n会社への印象や条件が影響した可能性があります。'),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('採用画面へ戻る'))],
      ),
    );
    // Use `navigator`'s own (stable) context, not the original `_Summary`
    // BuildContext — hiring/rejecting removes the applicant from
    // `state.applicants`, which unmounts `_Summary` on the next rebuild
    // (RecruitmentInterviewScreen falls back to its "not found" branch).
    final stableContext = navigator.context;
    for (final event in ProgressionEngine.pendingEvents(controller.state, const [
      OneTimeEvent.recruitmentInterviewCelebration,
      OneTimeEvent.welfareUnlockCelebration,
    ])) {
      if (!stableContext.mounted) break;
      final dialog = buildFoundingEventDialog(event, controller.state);
      controller.markTutorialSeen(event);
      if (dialog != null && stableContext.mounted) {
        await showFoundingEventDialog(stableContext, dialog);
      }
    }
    if (!stableContext.mounted) return;
    tabIndex.value = SesTab.recruitment;
    navigator.popUntil((route) => route.isFirst);
  }

  @override Widget build(BuildContext context) {
    final assessment = RecommendationEngine.postInterviewAssessment(s);
    return ListView(key:const ValueKey('summary'),padding:const EdgeInsets.all(16),children:[
      Text('面接まとめ',style:Theme.of(context).textTheme.headlineSmall),Text(name,style:Theme.of(context).textTheme.titleLarge),
      for(final o in s.observations)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.visibility_outlined),title:Text(interviewQuestionLabels[o.category]!),subtitle:Text(o.text)),
      const Divider(), Text('採用判断', style: Theme.of(context).textTheme.titleMedium),
      if (assessment.good.isNotEmpty) Text('良い材料\n・${assessment.good.join('\n・')}'),
      if (assessment.cautions.isNotEmpty) Text('注意\n・${assessment.cautions.join('\n・')}'),
      ListTile(contentPadding:EdgeInsets.zero,title:const Text('人物像の理解'),subtitle:Text(RecruitmentInterviewEngine.knowledgeLabel(s.candidateKnowledge))),
      ListTile(contentPadding:EdgeInsets.zero,title:const Text('本人の会社への反応'),subtitle:Text('${RecruitmentInterviewEngine.impressionLabel(s.companyImpression)}\n${s.applicantReaction}')),
      Row(children:[Expanded(child:OutlinedButton(onPressed:()=>_decide(context,InterviewOutcome.rejected),child:const Text('不採用'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:()=>_decide(context,InterviewOutcome.hired),child:const Text('採用する')))])
    ]);
  }
}
