import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../game/game.dart';
import '../../game/public_demo/public_demo_aggregate.dart';
import '../../game/public_demo/public_demo_recruitment.dart';
import '../../game/public_demo/public_demo_recruitment_interview.dart';
import '../recruitment/recruitment_interview_widgets.dart';
import '../widgets/confirm_dialog.dart';

/// Public Demo's interactive recruitment-interview modal (CORE-GAMEPLAY
/// Phase 3). This is not a decorative result screen: the player picks 3 of
/// 6 [InterviewQuestionCategory] questions, reads the applicant's answer and
/// [RecommendationEngine]'s own observation for it, answers the applicant's
/// own reverse question, and only then decides "採用候補として進める" (the
/// existing 合格・給与提示 offer flow, unchanged) or "見送る" (a new,
/// domain-authoritative decline). Reuses every question/answer/observation
/// widget from `lib/ui/recruitment/recruitment_interview_widgets.dart`
/// verbatim -- the same cards the main game's own post-tutorial hiring
/// screen renders -- so this Public Demo modal never re-implements the main
/// game's interview presentation.
///
/// Every state-changing tap commits through [onCommit] immediately (mirrors
/// [PublicDemo01PlaceholderScreen]'s own "_commitAggregate on every command"
/// convention), so closing this dialog mid-interview (the header's close
/// button, or the barrier) and reopening it later resumes exactly where the
/// player left off -- the session lives in
/// [PublicDemoWorkflowState.interviewSessions], not local widget state.
class PublicDemoRecruitmentInterviewDialog extends StatefulWidget {
  const PublicDemoRecruitmentInterviewDialog({
    super.key,
    required this.applicantId,
    required this.aggregate,
    required this.onCommit,
  });

  final String applicantId;
  final PublicDemoAggregate aggregate;
  final ValueChanged<PublicDemoAggregate> onCommit;

  @override
  State<PublicDemoRecruitmentInterviewDialog> createState() =>
      _PublicDemoRecruitmentInterviewDialogState();
}

class _PublicDemoRecruitmentInterviewDialogState
    extends State<PublicDemoRecruitmentInterviewDialog> {
  late PublicDemoAggregate _aggregate;

  @override
  void initState() {
    super.initState();
    _aggregate = widget.aggregate.startInterviewSession(widget.applicantId);
    if (!identical(_aggregate, widget.aggregate)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onCommit(_aggregate),
      );
    }
  }

  PublicDemoApplicant get _applicant => _aggregate.workflow.applicants
      .firstWhere((candidate) => candidate.id == widget.applicantId);

  RecruitmentInterviewSession? get _session => _aggregate
      .workflow
      .interviewSessions
      .where((session) => session.applicantId == widget.applicantId)
      .firstOrNull;

  Applicant get _domainApplicant =>
      PublicDemoRecruitmentInterview.domainApplicantFor(
        runSeed: _aggregate.runSeed,
        applicant: _applicant,
      );

  void _commit(PublicDemoAggregate next) {
    setState(() => _aggregate = next);
    widget.onCommit(next);
  }

  void _ask(InterviewQuestionCategory category) =>
      _commit(_aggregate.askInterviewQuestion(widget.applicantId, category));

  void _answerReverse(int index) => _commit(
    _aggregate.answerInterviewReverseQuestion(widget.applicantId, index),
  );

  Future<void> _decide(InterviewOutcome outcome) async {
    if (outcome == InterviewOutcome.rejected) {
      final confirmed = await confirmIrreversibleAction(
        context,
        title: '見送りますか？',
        message: '${_applicant.name}さんを見送ります。この判断は取り消せません。',
        confirmLabel: '見送る',
      );
      if (!confirmed || !mounted) return;
    }
    _commit(_aggregate.concludeInterviewSession(widget.applicantId, outcome));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      // Should not happen in practice (initState always starts one when
      // missing) -- a defensive, silent close rather than a crash if some
      // future caller opens this dialog for an applicant that was never
      // eligible (not yet `hasBeenInterviewed`).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }
    final applicant = _domainApplicant;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.vertical - 48;
    return Dialog(
      key: const Key('public-demo-interview-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight < 320 ? 320 : maxHeight,
          maxWidth: 420,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogTitleBar(
              applicantName: applicant.name,
              onClose: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1),
            Flexible(
              child: !session.questionsComplete
                  ? _QuestionsPhase(
                      applicant: applicant,
                      session: session,
                      onAsk: _ask,
                    )
                  : session.companyAnswer == null
                  ? _ReversePhase(
                      applicant: applicant,
                      session: session,
                      onAnswer: _answerReverse,
                    )
                  : _SummaryPhase(applicant: applicant, session: session),
            ),
            if (session.conversationComplete) ...[
              const Divider(height: 1),
              _DecisionBar(onDecide: _decide),
            ],
          ],
        ),
      ),
    );
  }
}

class _DialogTitleBar extends StatelessWidget {
  const _DialogTitleBar({required this.applicantName, required this.onClose});
  final String applicantName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$applicantNameさんとの面談',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          key: const Key('public-demo-interview-close'),
          icon: const Icon(Icons.close),
          tooltip: '中断して閉じる',
          onPressed: onClose,
        ),
      ],
    ),
  );
}

class _QuestionsPhase extends StatelessWidget {
  const _QuestionsPhase({
    required this.applicant,
    required this.session,
    required this.onAsk,
  });
  final Applicant applicant;
  final RecruitmentInterviewSession session;
  final ValueChanged<InterviewQuestionCategory> onAsk;

  @override
  Widget build(BuildContext context) => ListView(
    key: ValueKey(
      'public-demo-interview-questions-${session.selectedQuestions.length}',
    ),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    children: [
      ApplicantPersonaHeader(
        applicant: applicant,
        companyImpression: session.companyImpression,
      ),
      const SizedBox(height: 12),
      QuestionProgress(asked: session.selectedQuestions.length),
      const SizedBox(height: 4),
      const Text(
        '何を知りたいか選んでください。すべては聞けません。',
        style: TextStyle(fontSize: 12.5, color: Colors.black54),
      ),
      if (session.applicantAnswers.isNotEmpty) ...[
        const SizedBox(height: 12),
        ReactionLine(companyImpression: session.companyImpression),
        const SizedBox(height: 8),
        TalkCard(
          name: applicant.name,
          a: session.applicantAnswers.last,
          o: session.observations.last,
        ),
      ],
      const SizedBox(height: 12),
      for (final category in InterviewQuestionCategory.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: QuestionCard(
            category: category,
            used: session.selectedQuestions.contains(category),
            onTap: session.selectedQuestions.contains(category)
                ? null
                : () => onAsk(category),
          ),
        ),
    ],
  );
}

class _ReversePhase extends StatelessWidget {
  const _ReversePhase({
    required this.applicant,
    required this.session,
    required this.onAnswer,
  });
  final Applicant applicant;
  final RecruitmentInterviewSession session;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final choices = companyAnswerChoices[session.reverseQuestion]!;
    return ListView(
      key: const ValueKey('public-demo-interview-reverse'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        ApplicantPersonaHeader(
          applicant: applicant,
          companyImpression: session.companyImpression,
        ),
        const SizedBox(height: 12),
        Text('応募者からの質問', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text('「${reverseQuestionTexts[session.reverseQuestion]}」'),
          ),
        ),
        const SizedBox(height: 10),
        const Text('会社としてどう答えますか？'),
        for (var i = 0; i < choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonal(
              key: ValueKey('public-demo-interview-reverse-choice-$i'),
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: () => onAnswer(i),
              child: Text(choices[i].text),
            ),
          ),
      ],
    );
  }
}

class _SummaryPhase extends StatelessWidget {
  const _SummaryPhase({required this.applicant, required this.session});
  final Applicant applicant;
  final RecruitmentInterviewSession session;

  @override
  Widget build(BuildContext context) {
    final assessment = RecommendationEngine.postInterviewAssessment(session);
    return ListView(
      key: const ValueKey('public-demo-interview-summary'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        ApplicantPersonaHeader(
          applicant: applicant,
          companyImpression: session.companyImpression,
        ),
        const SizedBox(height: 8),
        ReactionLine(companyImpression: session.companyImpression),
        const SizedBox(height: 14),
        InterviewInfoGauge(session: session),
        const SizedBox(height: 10),
        InterviewConclusionSummary(session: session),
        const SizedBox(height: 14),
        const Divider(),
        Text(
          '詳細',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 4),
        for (final observation in session.observations)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ObservationSummaryTile(
              observation: observation,
              answer: session.applicantAnswers.firstWhere(
                (answer) => answer.category == observation.category,
              ),
            ),
          ),
        const Divider(),
        Text('採用判断', style: Theme.of(context).textTheme.titleSmall),
        if (assessment.good.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('良い材料\n・${assessment.good.join('\n・')}'),
          ),
        if (assessment.cautions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('注意\n・${assessment.cautions.join('\n・')}'),
          ),
        if (session.applicantReaction != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '本人の反応: ${session.applicantReaction}',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
      ],
    );
  }
}

class _DecisionBar extends StatelessWidget {
  const _DecisionBar({required this.onDecide});
  final ValueChanged<InterviewOutcome> onDecide;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('public-demo-interview-decision-reject'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => onDecide(InterviewOutcome.rejected),
            child: const Text('見送る'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            key: const Key('public-demo-interview-decision-proceed'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => onDecide(InterviewOutcome.hired),
            child: const Text('採用候補として進める'),
          ),
        ),
      ],
    ),
  );
}
