import 'package:flutter/material.dart';
import '../../app/game_scope.dart';
import '../../app/nav_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../main_shell.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/founding_dialogs.dart';
import '../widgets/outcome_card.dart';
import '../widgets/result_reveal.dart';
import 'recruitment_interview_widgets.dart';

class RecruitmentInterviewScreen extends StatelessWidget {
  const RecruitmentInterviewScreen({super.key, required this.applicantId});
  final String applicantId;
  @override Widget build(BuildContext context) {
    final c=context.game, state=c.state;
    final found=state.applicants.where((e)=>e.applicant.id==applicantId).toList();
    // Transient, not a genuine error (Phase 3A UX review, P1-3) — mirrors
    // PrologueInterviewScreen's identical fix: this route is only pushed
    // while the applicant is present, and `found` empties out the moment
    // the hire/reject decision clears `state.applicants`, which can persist
    // for a real, player-observable stretch (the result dialog sits on top
    // of this same route until dismissed). A blank Scaffold, not the old
    // alarming "見つかりません" error and not a spinner either (nothing is
    // actually loading — the dialog on top is the only thing that matters
    // here).
    if(found.isEmpty) return const Scaffold(body: SizedBox.shrink());
    final applicant=found.first.applicant;
    final sessions=state.recruitmentInterviews.where((s)=>s.applicantId==applicantId).toList();
    if(sessions.isEmpty){ WidgetsBinding.instance.addPostFrameCallback((_){c.interviewApplicant(applicantId);}); return const Scaffold(body: Center(child:CircularProgressIndicator())); }
    final s=sessions.last;
    return Scaffold(appBar:AppBar(title:Text('${applicant.name}との面接')),body:SafeArea(child: s.questionsComplete ? (s.companyAnswer==null ? _Reverse(applicantId:applicantId,applicant:applicant,s:s) : _Summary(applicantId:applicantId,applicant:applicant,s:s)) : _Questions(applicantId:applicantId,applicant:applicant,s:s)));
  }
}

class _Questions extends StatelessWidget {
  const _Questions({required this.applicantId,required this.applicant,required this.s}); final String applicantId; final Applicant applicant; final RecruitmentInterviewSession s;
  @override Widget build(BuildContext context)=>ListView(key:ValueKey(s.selectedQuestions.length),padding:const EdgeInsets.fromLTRB(16,16,16,28),children:[
    ApplicantPersonaHeader(applicant: applicant, companyImpression: s.companyImpression),
    const SizedBox(height: 14),
    QuestionProgress(asked: s.selectedQuestions.length),
    const SizedBox(height: 4),
    const Text('何を知りたいか選んでください。すべては聞けません。', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
    if(s.applicantAnswers.isNotEmpty)...[
      const SizedBox(height:12),
      ReactionLine(companyImpression: s.companyImpression),
      const SizedBox(height: 8),
      TalkCard(name:applicant.name,a:s.applicantAnswers.last,o:s.observations.last),
      if(s.applicantAnswers.length>1)ExpansionTile(title:Text('過去の回答 (${s.applicantAnswers.length-1})'),children:[for(var i=0;i<s.applicantAnswers.length-1;i++)TalkCard(name:applicant.name,a:s.applicantAnswers[i],o:s.observations[i])]),
    ],
    const SizedBox(height:14),
    for(final q in InterviewQuestionCategory.values)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: QuestionCard(
          category: q,
          used: s.selectedQuestions.contains(q),
          onTap: s.selectedQuestions.contains(q) ? null : () => context.game.askRecruitmentQuestion(applicantId, q),
        ),
      ),
  ]);
}

class _Reverse extends StatelessWidget { const _Reverse({required this.applicantId,required this.applicant,required this.s});final String applicantId;final Applicant applicant;final RecruitmentInterviewSession s;
  @override Widget build(BuildContext context){final choices=companyAnswerChoices[s.reverseQuestion]!;return ListView(key:const ValueKey('reverse'),padding:const EdgeInsets.fromLTRB(16,16,16,28),children:[
    ApplicantPersonaHeader(applicant: applicant, companyImpression: s.companyImpression),
    const SizedBox(height: 14),
    Text('応募者からの質問',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(16),child:Text('「${reverseQuestionTexts[s.reverseQuestion]}」'))),const SizedBox(height:12),const Text('会社としてどう答えますか？'),for(var i=0;i<choices.length;i++)Padding(padding:const EdgeInsets.only(top:8),child:FilledButton.tonal(onPressed:()=>context.game.answerRecruitmentReverseQuestion(applicantId,i),style:FilledButton.styleFrom(alignment:Alignment.centerLeft,padding:const EdgeInsets.all(16)),child:Text(choices[i].text)))]);}
}
class _Summary extends StatelessWidget {
  const _Summary({required this.applicantId,required this.applicant,required this.s});
  final String applicantId; final Applicant applicant; final RecruitmentInterviewSession s;

  Future<void> _decide(BuildContext context, InterviewOutcome outcome) async {
    if (outcome == InterviewOutcome.rejected) {
      final confirmed = await confirmIrreversibleAction(
        context,
        title: '不採用にしますか？',
        message: '${applicant.name}さんを不採用にします。この判断は取り消せません。',
        confirmLabel: '不採用にする',
      );
      if (!confirmed || !context.mounted) return;
    }
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
    // Hiring is the only genuinely uncertain branch here (the candidate
    // decides whether to actually join) — that's the one worth a "確認して
    // います" beat (§7). Rejecting is the player's own decision playing back
    // instantly is fine.
    final showSuspense = outcome == InterviewOutcome.hired;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: SizedBox(
          width: 320,
          child: showSuspense
              ? ResultReveal(builder: (_) => _DecisionResult(name: applicant.name, outcome: outcome, accepted: accepted))
              : _DecisionResult(name: applicant.name, outcome: outcome, accepted: accepted),
        ),
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
    // The decision row lives *outside* the scrollable list, pinned to the
    // bottom (Playable 0.4C.4 §25-26 fix): §7/§11/§13 added real vertical
    // content above it (persona header, info gauge, conclusion chips), and
    // a plain trailing-row-inside-ListView placement meant the CTA simply
    // wasn't mounted at all on some renderers at typical scroll positions
    // (confirmed failing on WebKit in CI — an empty accessibility button
    // list on this exact screen). Pinning it guarantees "今やること" is
    // never buried, regardless of how long the summary above it grows.
    return Column(
      children: [
        Expanded(
          child: ListView(key:const ValueKey('summary'),padding:const EdgeInsets.fromLTRB(16,16,16,16),children:[
            Text('面接まとめ',style:Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            ApplicantPersonaHeader(applicant: applicant, companyImpression: s.companyImpression),
            const SizedBox(height: 8),
            ReactionLine(companyImpression: s.companyImpression),
            const SizedBox(height: 14),
            // 結論 (Playable 0.4C.4 §13): visual gauge + per-question chips
            // first — the free-text detail below is optional reading, not
            // the entry point.
            InterviewInfoGauge(session: s),
            const SizedBox(height: 10),
            InterviewConclusionSummary(session: s),
            const SizedBox(height: 16),
            const Divider(),
            Text('詳細', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54)),
            const SizedBox(height: 4),
            for(final o in s.observations)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ObservationSummaryTile(observation: o, answer: s.applicantAnswers.firstWhere((a) => a.category == o.category)),
              ),
            const Divider(), Text('採用判断', style: Theme.of(context).textTheme.titleMedium),
            if (assessment.good.isNotEmpty) Text('良い材料\n・${assessment.good.join('\n・')}'),
            if (assessment.cautions.isNotEmpty) Text('注意\n・${assessment.cautions.join('\n・')}'),
            if (s.applicantReaction != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('本人の反応: ${s.applicantReaction}', style: const TextStyle(fontSize: 12.5, color: Colors.black54))),
          ]),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
            child: Row(children:[
              Expanded(child:OutlinedButton(key:const ValueKey('decision-reject'),style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),onPressed:()=>_decide(context,InterviewOutcome.rejected),child:const Text('不採用'))),
              const SizedBox(width:10),
              Expanded(child:FilledButton(key:const ValueKey('decision-hire'),style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),onPressed:()=>_decide(context,InterviewOutcome.hired),child:const Text('採用する'))),
            ]),
          ),
        ),
      ],
    );
  }
}

/// The 内定承諾/内定辞退/不採用 outcome, reframed via [OutcomeCard] so
/// failure states always say what happens next (Playable 0.4C.3 §8-9).
class _DecisionResult extends StatelessWidget {
  const _DecisionResult({required this.name, required this.outcome, required this.accepted});
  final String name;
  final InterviewOutcome outcome;
  final bool accepted;

  @override
  Widget build(BuildContext context) {
    if (outcome == InterviewOutcome.rejected) {
      return OutcomeCard(
        success: false,
        title: '不採用',
        details: '$nameさんは今回採用しませんでした。',
        nextStep: '他の応募者の面接を続けるか、次週また新しい応募を待つことができます。',
      );
    }
    if (accepted) {
      return const OutcomeCard(
        success: true,
        celebration: true,
        title: '内定承諾！',
        details: '入社を承諾しました。',
        nextStep: '次: 入社後、案件を探しましょう。',
      );
    }
    return OutcomeCard(
      success: false,
      title: '内定辞退',
      details: '$nameさんは内定を辞退しました。\n会社への印象や条件が影響した可能性があります。',
      nextStep: '求人媒体や条件を見直しつつ、次の応募者を待つことができます。',
    );
  }
}
