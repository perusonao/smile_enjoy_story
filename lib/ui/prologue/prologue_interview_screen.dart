import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../recruitment/recruitment_interview_widgets.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/outcome_card.dart';
import '../widgets/result_reveal.dart';

/// The Founding Prologue's March Week 2 recruitment interview (Playable
/// 0.5A §21-29): the same [RecruitmentInterviewSession] flow as the
/// existing recruitment tab, just with a decision step that calls
/// [GameController.decidePrologueCandidate] (hires straight into a real
/// Engineer, §27) instead of the general [GameController.hireApplicant]
/// (which creates a randomly-delayed [PendingHire], not what the scripted
/// April Week 1 join needs).
///
/// Shares its card/tag/reaction presentation with
/// recruitment/recruitment_interview_screen.dart (Playable 0.4C.3 §5-6,
/// extended 0.4C.4 §7-13) — this is most players' *first* interview (via
/// 【初心者モード】), so it gets the exact same question cards, persona
/// header, and information gauge, not a plainer fallback.
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
            ? (s.companyAnswer == null ? _Reverse(applicantId: applicantId, applicant: applicant, s: s) : _Summary(applicantId: applicantId, applicant: applicant, s: s))
            : _Questions(applicantId: applicantId, applicant: applicant, s: s),
      ),
    );
  }
}

class _Questions extends StatelessWidget {
  const _Questions({required this.applicantId, required this.applicant, required this.s});
  final String applicantId;
  final Applicant applicant;
  final RecruitmentInterviewSession s;
  @override
  Widget build(BuildContext context) => ListView(
    key: ValueKey(s.selectedQuestions.length),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: [
      ApplicantPersonaHeader(applicant: applicant, companyImpression: s.companyImpression),
      const SizedBox(height: 14),
      QuestionProgress(asked: s.selectedQuestions.length),
      const SizedBox(height: 4),
      const Text('何を知りたいか選んでください。すべては聞けません。', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
      if (s.applicantAnswers.isNotEmpty) ...[
        const SizedBox(height: 12),
        ReactionLine(companyImpression: s.companyImpression),
        const SizedBox(height: 8),
        TalkCard(name: applicant.name, a: s.applicantAnswers.last, o: s.observations.last),
      ],
      const SizedBox(height: 14),
      for (final q in InterviewQuestionCategory.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: QuestionCard(
            category: q,
            used: s.selectedQuestions.contains(q),
            onTap: s.selectedQuestions.contains(q) ? null : () => context.game.askRecruitmentQuestion(applicantId, q),
          ),
        ),
    ],
  );
}

class _Reverse extends StatelessWidget {
  const _Reverse({required this.applicantId, required this.applicant, required this.s});
  final String applicantId;
  final Applicant applicant;
  final RecruitmentInterviewSession s;
  @override
  Widget build(BuildContext context) {
    final choices = companyAnswerChoices[s.reverseQuestion]!;
    return ListView(
      key: const ValueKey('reverse'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        ApplicantPersonaHeader(applicant: applicant, companyImpression: s.companyImpression),
        const SizedBox(height: 14),
        Text('応募者からの質問', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('「${reverseQuestionTexts[s.reverseQuestion]}」'))),
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
  const _Summary({required this.applicantId, required this.applicant, required this.s});
  final String applicantId;
  final Applicant applicant;
  final RecruitmentInterviewSession s;

  /// Rejection and offer-decline are both real, dead-end-free routes
  /// (Playable 0.5A.1 §5): the dialog always says what happens next —
  /// remaining candidates this week, or "wait for next week" when
  /// [PrologueEngine.canInterviewThisWeek] is already blocked (the P0 fix on
  /// the Home card behind this screen covers the actual action; this dialog
  /// just tells the player what to expect before they see it).
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
    controller.completeRecruitmentInterview(applicantId, outcome);
    final before = controller.state.engineers.length;
    controller.decidePrologueCandidate(applicantId, hire: outcome == InterviewOutcome.hired);
    final after = controller.state;
    final hired = outcome == InterviewOutcome.hired && after.engineers.length > before;
    final remainingCandidates = after.applicants.isNotEmpty;
    final canInterviewMore = PrologueEngine.canInterviewThisWeek(after);
    final nextStep = remainingCandidates && canInterviewMore
        ? '残りの候補者と面談するか、このまま次の週へ進めることもできます。'
        : remainingCandidates
            ? '今週の面談は終わりました。残りの候補者とは来週以降に面談できます。「次の週へ」で進めましょう。'
            : '今週の面談は終わりました。「次の週へ」で募集を続けましょう。';
    // Hiring is the only genuinely uncertain branch here (the candidate
    // decides whether to actually join) — that's the one worth a "確認して
    // います" beat (Playable 0.4C.3 §7). Rejecting is the player's own
    // decision playing back instantly is fine.
    final showSuspense = outcome == InterviewOutcome.hired;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: SizedBox(
          width: 320,
          child: showSuspense
              ? ResultReveal(builder: (_) => _PrologueDecisionResult(name: applicant.name, outcome: outcome, hired: hired, nextStep: nextStep))
              : _PrologueDecisionResult(name: applicant.name, outcome: outcome, hired: hired, nextStep: nextStep),
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
    // Decision row pinned outside the scrollable list (Playable 0.4C.4
    // §25-26 fix, mirroring recruitment_interview_screen.dart's identical
    // fix) — §7/§11/§13 added real vertical content above it, and a plain
    // trailing row inside the ListView meant the CTA wasn't even mounted
    // on some renderers (confirmed failing on WebKit in CI: an empty
    // accessibility button list on this exact screen).
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('summary'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Text('面接まとめ', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              ApplicantPersonaHeader(applicant: applicant, companyImpression: s.companyImpression),
              const SizedBox(height: 8),
              ReactionLine(companyImpression: s.companyImpression),
              const SizedBox(height: 14),
              // 結論 (Playable 0.4C.4 §13): visual gauge + per-question
              // chips first, free-text detail below — same ordering as the
              // regular recruitment tab's interview summary.
              InterviewInfoGauge(session: s),
              const SizedBox(height: 10),
              InterviewConclusionSummary(session: s),
              const SizedBox(height: 16),
              const Divider(),
              Text('詳細', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54)),
              const SizedBox(height: 4),
              for (final o in s.observations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ObservationSummaryTile(observation: o, answer: s.applicantAnswers.firstWhere((a) => a.category == o.category)),
                ),
              const Divider(),
              Text('採用判断', style: Theme.of(context).textTheme.titleMedium),
              if (assessment.good.isNotEmpty) Text('良い材料\n・${assessment.good.join('\n・')}'),
              if (assessment.cautions.isNotEmpty) Text('注意\n・${assessment.cautions.join('\n・')}'),
              if (s.applicantReaction != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('本人の反応: ${s.applicantReaction}', style: const TextStyle(fontSize: 12.5, color: Colors.black54))),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: () => _decide(context, InterviewOutcome.rejected), child: const Text('不採用'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: () => _decide(context, InterviewOutcome.hired), child: const Text('採用する'))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The 内定承諾/内定辞退/不採用 outcome, reframed via [OutcomeCard] so
/// failure states always say what happens next (Playable 0.4C.3 §8-9).
class _PrologueDecisionResult extends StatelessWidget {
  const _PrologueDecisionResult({required this.name, required this.outcome, required this.hired, required this.nextStep});
  final String name;
  final InterviewOutcome outcome;
  final bool hired;
  final String nextStep;

  @override
  Widget build(BuildContext context) {
    if (outcome == InterviewOutcome.rejected) {
      return OutcomeCard(success: false, title: '不採用', details: '$nameさんは今回採用しませんでした。', nextStep: nextStep);
    }
    if (hired) {
      return const OutcomeCard(
        success: true,
        celebration: true,
        title: '内定承諾！',
        details: '入社を承諾しました。',
        nextStep: '4月1週に入社予定です。',
      );
    }
    return OutcomeCard(success: false, title: '内定辞退', details: '$nameさんは内定を辞退しました。', nextStep: nextStep);
  }
}
