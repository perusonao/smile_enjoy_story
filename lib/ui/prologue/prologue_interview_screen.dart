import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../game/game.dart';

/// The Founding Prologue's March Week 2 recruitment interview (Playable
/// 0.5A §21-29): the same [RecruitmentInterviewSession] flow as the
/// existing recruitment tab, just with a decision step that calls
/// [GameController.decidePrologueCandidate] (hires straight into a real
/// Engineer, §27) instead of the general [GameController.hireApplicant]
/// (which creates a randomly-delayed [PendingHire], not what the scripted
/// April Week 1 join needs).
class PrologueInterviewScreen extends StatelessWidget {
  const PrologueInterviewScreen({super.key, required this.applicantId});
  final String applicantId;

  @override
  Widget build(BuildContext context) {
    final c = context.game, state = c.state;
    final found = state.applicants.where((e) => e.applicant.id == applicantId).toList();
    if (found.isEmpty) return const Scaffold(body: Center(child: Text('応募者が見つかりません')));
    final applicant = found.first.applicant;
    final sessions = state.recruitmentInterviews.where((s) => s.applicantId == applicantId).toList();
    if (sessions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => c.selectPrologueCandidate(applicantId));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = sessions.last;
    return Scaffold(
      appBar: AppBar(title: Text('${applicant.name}との面接')),
      body: SafeArea(
        child: s.questionsComplete
            ? (s.companyAnswer == null ? _Reverse(applicantId: applicantId, name: applicant.name, s: s) : _Summary(applicantId: applicantId, name: applicant.name, s: s))
            : _Questions(applicantId: applicantId, name: applicant.name, s: s),
      ),
    );
  }
}

class _Questions extends StatelessWidget {
  const _Questions({required this.applicantId, required this.name, required this.s});
  final String applicantId, name;
  final RecruitmentInterviewSession s;
  @override
  Widget build(BuildContext context) => ListView(
    key: ValueKey(s.selectedQuestions.length),
    padding: const EdgeInsets.all(16),
    children: [
      Text('質問 ${s.selectedQuestions.length + 1} / 3', style: Theme.of(context).textTheme.titleLarge),
      const Text('すべては聞けません。何を重視するか決めてください。'),
      if (s.applicantAnswers.isNotEmpty) ...[
        const SizedBox(height: 12),
        _Talk(name: name, a: s.applicantAnswers.last, o: s.observations.last),
      ],
      const SizedBox(height: 12),
      for (final q in InterviewQuestionCategory.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            onPressed: s.selectedQuestions.contains(q) ? null : () => context.game.askRecruitmentQuestion(applicantId, q),
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(interviewQuestionLabels[q]!, style: const TextStyle(fontWeight: FontWeight.bold)), Text(interviewQuestionTexts[q]!)],
            ),
          ),
        ),
    ],
  );
}

class _Talk extends StatelessWidget {
  const _Talk({required this.name, required this.a, required this.o});
  final String name;
  final ApplicantAnswer a;
  final InterviewObservation o;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('あなた', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('「${a.question}」'),
          const SizedBox(height: 10),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('「${a.answer}」'),
          const Divider(),
          Text('観察・${o.confidence == ObservationConfidence.high ? 'かなり確信' : o.confidence == ObservationConfidence.medium ? 'ややそう感じる' : 'まだ不確か'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
          Text(o.text),
        ],
      ),
    ),
  );
}

class _Reverse extends StatelessWidget {
  const _Reverse({required this.applicantId, required this.name, required this.s});
  final String applicantId, name;
  final RecruitmentInterviewSession s;
  @override
  Widget build(BuildContext context) {
    final choices = companyAnswerChoices[s.reverseQuestion]!;
    return ListView(
      key: const ValueKey('reverse'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('応募者からの質問', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('$name\n「${reverseQuestionTexts[s.reverseQuestion]}」'))),
        const SizedBox(height: 12),
        const Text('会社としてどう答えますか？'),
        for (var i = 0; i < choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonal(
              onPressed: () => context.game.answerRecruitmentReverseQuestion(applicantId, i),
              style: FilledButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(16)),
              child: Text(choices[i].text),
            ),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.applicantId, required this.name, required this.s});
  final String applicantId, name;
  final RecruitmentInterviewSession s;

  /// Rejection and offer-decline are both real, dead-end-free routes
  /// (Playable 0.5A.1 §5): the dialog always says what happens next —
  /// remaining candidates this week, or "wait for next week" when
  /// [PrologueEngine.canInterviewThisWeek] is already blocked (the P0 fix on
  /// the Home card behind this screen covers the actual action; this dialog
  /// just tells the player what to expect before they see it).
  Future<void> _decide(BuildContext context, InterviewOutcome outcome) async {
    final controller = context.game;
    final navigator = Navigator.of(context);
    controller.completeRecruitmentInterview(applicantId, outcome);
    final before = controller.state.engineers.length;
    controller.decidePrologueCandidate(applicantId, hire: outcome == InterviewOutcome.hired);
    final after = controller.state;
    final hired = outcome == InterviewOutcome.hired && after.engineers.length > before;
    final remainingCandidates = after.applicants.isNotEmpty;
    final canInterviewMore = PrologueEngine.canInterviewThisWeek(after);
    final nextStepText = hired
        ? ''
        : remainingCandidates && canInterviewMore
            ? '\n\n残りの候補者と面談するか、このまま次の週へ進めることもできます。'
            : remainingCandidates
                ? '\n\n今週の面談は終わりました。残りの候補者とは来週以降に面談できます。「次の週へ」で進めましょう。'
                : '\n\n今週の面談は終わりました。「次の週へ」で募集を続けましょう。';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(outcome == InterviewOutcome.rejected ? '不採用' : hired ? '内定承諾！' : '内定辞退'),
        content: Text(
          outcome == InterviewOutcome.rejected
              ? '$nameさんは今回採用しませんでした。$nextStepText'
              : hired
                  ? '$nameさんが入社を承諾しました。\n\n4月1週に入社予定です。'
                  : '$nameさんは内定を辞退しました。$nextStepText',
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('戻る'))],
      ),
    );
    if (!navigator.mounted) return;
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final assessment = RecommendationEngine.postInterviewAssessment(s);
    return ListView(
      key: const ValueKey('summary'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('面接まとめ', style: Theme.of(context).textTheme.headlineSmall),
        Text(name, style: Theme.of(context).textTheme.titleLarge),
        for (final o in s.observations) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.visibility_outlined), title: Text(interviewQuestionLabels[o.category]!), subtitle: Text(o.text)),
        const Divider(),
        Text('採用判断', style: Theme.of(context).textTheme.titleMedium),
        if (assessment.good.isNotEmpty) Text('良い材料\n・${assessment.good.join('\n・')}'),
        if (assessment.cautions.isNotEmpty) Text('注意\n・${assessment.cautions.join('\n・')}'),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('人物像の理解'), subtitle: Text(RecruitmentInterviewEngine.knowledgeLabel(s.candidateKnowledge))),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('本人の会社への反応'), subtitle: Text('${RecruitmentInterviewEngine.impressionLabel(s.companyImpression)}\n${s.applicantReaction}')),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => _decide(context, InterviewOutcome.rejected), child: const Text('不採用'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () => _decide(context, InterviewOutcome.hired), child: const Text('採用する'))),
          ],
        ),
      ],
    );
  }
}
