import 'package:flutter/material.dart';

import '../../game/engine/client_interview_content.dart';
import '../../game/engine/client_interview_engine.dart';
import '../../game/models/client_interview.dart';
import '../../game/public_demo/public_demo_aggregate.dart';
import '../../game/public_demo/public_demo_interview.dart';
import '../../game/public_demo/public_demo_project_generator.dart';
import '../../game/public_demo/public_demo_project_interview.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../theme.dart';

/// CORE-GAMEPLAY Phase 6 (Project Interview Gameplay) / Issue #245 Phase B2
/// (Partner Interview Gameplay): the interactive 案件面談/上位会社面談 that
/// turns Phase 5's real matching-proposal handoff (a real engineer + a real
/// Phase 4 [PublicDemoProjectCandidate]) into an actual pass/fail outcome.
/// Mirrors [PublicDemoRecruitmentInterviewDialog]'s own shape (a modal, not
/// a pushed screen; every state-changing tap commits through [onCommit]
/// immediately, so closing and reopening this dialog resumes exactly where
/// the player left off — the session lives in [PublicDemoWorkflowState
/// .projectInterviewSessions], not local widget state) and the main game's
/// own `ClientInterviewScreen` for the question/follow-up/result
/// presentation itself, reusing [ClientInterviewEngine.choices]/
/// [clientInterviewFollowUpLabels] verbatim rather than inventing new copy.
///
/// [type] selects which leg of the sales pipeline this dialog drives —
/// [PublicDemoInterviewType.client] (default, unchanged from Phase 6) starts/
/// concludes via [PublicDemoAggregate.startProjectInterview]/
/// [concludeProjectInterview] (`partnerInterviewPassed` →
/// `clientInterviewPassed`/`clientInterviewFailed`);
/// [PublicDemoInterviewType.partner] starts/concludes via [PublicDemoAggregate
/// .startPartnerInterview]/[concludePartnerInterview] (`introduced` →
/// `partnerInterviewPassed`/`partnerInterviewFailed`) instead — the exact
/// same [ClientInterviewSession]/[ClientInterviewEngine] machinery, one
/// pipeline stage earlier, per Issue #245 Finding #3's "reuse the existing
/// interview engine, never a new formula" audit conclusion. Widget keys stay
/// prefixed `public-demo-project-interview-*` for the client leg (unchanged,
/// so every existing Phase 6 fixture/test keeps working verbatim) and
/// `public-demo-partner-interview-*` for the partner leg.
///
/// Never shows a raw score, hidden parameter, or fabricated failure reason:
/// only pass/fail, the interviewer's own natural-language reactions
/// (already non-numeric), and [PublicDemoAggregate
/// .projectInterviewFailureReasonsFor]'s truthful, [MatchingEngine]-derived
/// reasons.
class PublicDemoProjectInterviewDialog extends StatefulWidget {
  const PublicDemoProjectInterviewDialog({
    super.key,
    required this.engineerId,
    required this.aggregate,
    required this.onCommit,
    this.type = PublicDemoInterviewType.client,
  });

  final String engineerId;
  final PublicDemoAggregate aggregate;
  final ValueChanged<PublicDemoAggregate> onCommit;
  final PublicDemoInterviewType type;

  @override
  State<PublicDemoProjectInterviewDialog> createState() =>
      _PublicDemoProjectInterviewDialogState();
}

class _PublicDemoProjectInterviewDialogState
    extends State<PublicDemoProjectInterviewDialog> {
  late PublicDemoAggregate _aggregate;

  bool get _isPartner => widget.type == PublicDemoInterviewType.partner;

  /// Widget key prefix — see this dialog's own class doc for why the client
  /// leg's prefix must never change.
  String get _keyPrefix => _isPartner
      ? 'public-demo-partner-interview'
      : 'public-demo-project-interview';

  String get _interviewLabel => _isPartner ? '上位会社面談' : '案件面談';

  @override
  void initState() {
    super.initState();
    _aggregate = _isPartner
        ? widget.aggregate.startPartnerInterview(widget.engineerId)
        : widget.aggregate.startProjectInterview(widget.engineerId);
    if (!identical(_aggregate, widget.aggregate)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onCommit(_aggregate),
      );
    }
  }

  PublicDemoEngineerSales? get _engineer => _aggregate.workflow.engineers
      .where((candidate) => candidate.id == widget.engineerId)
      .firstOrNull;

  PublicDemoProjectCandidate? get _candidate =>
      _aggregate.projectInterviewCandidateFor(widget.engineerId);

  ClientInterviewSession? get _session =>
      _aggregate.projectInterviewSessionFor(widget.engineerId);

  void _commit(PublicDemoAggregate next) {
    setState(() => _aggregate = next);
    widget.onCommit(next);
  }

  /// [questionIndex] (Codex P2 fix, PR #214) must come from the specific
  /// [ClientInterviewSession] snapshot [build] actually rendered the
  /// pressed follow-up button from (see the `onChoose` wiring below) —
  /// never re-read from `_session`/`_aggregate` here, which may already
  /// reflect a prior tap's own advance by the time a second, stale tap on
  /// the same (not-yet-rebuilt) button is processed. The authority layer
  /// ([PublicDemoAggregate.chooseProjectInterviewFollowUp] →
  /// [PublicDemoProjectInterview.chooseFollowUp]) rejects the call outright
  /// once [questionIndex] no longer matches the session's actual current
  /// question, so this capture is what makes that rejection possible — a
  /// disabled button alone is not relied on to prevent a duplicate/stale
  /// submission.
  void _chooseFollowUp(int questionIndex, ClientInterviewFollowUp choice) =>
      _commit(
        _aggregate.chooseProjectInterviewFollowUp(
          widget.engineerId,
          questionIndex,
          choice,
        ),
      );

  void _conclude() => _commit(
    _isPartner
        ? _aggregate.concludePartnerInterview(widget.engineerId)
        : _aggregate.concludeProjectInterview(widget.engineerId),
  );

  @override
  Widget build(BuildContext context) {
    final engineer = _engineer;
    final candidate = _candidate;
    final session = _session;
    if (engineer == null || candidate == null || session == null) {
      // Should not happen in practice — initState always starts one when a
      // real proposal/runtime resolve. A defensive, silent close rather
      // than a crash if this dialog is ever opened without one (mirrors
      // PublicDemoRecruitmentInterviewDialog's own fallback).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    if (!session.completed &&
        PublicDemoProjectInterview.isReadyToConclude(session)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _conclude();
      });
    }

    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.vertical - 48;
    return Dialog(
      key: Key('$_keyPrefix-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight < 320 ? 320 : maxHeight,
          maxWidth: 420,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TitleBar(
              title: _interviewLabel,
              closeKey: Key('$_keyPrefix-close'),
              onClose: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1),
            Flexible(
              child: session.completed
                  ? _ResultPhase(
                      keyPrefix: _keyPrefix,
                      engineer: engineer,
                      candidate: candidate,
                      interviewLabel: _interviewLabel,
                      passContinuation: _isPartner
                          ? '${candidate.title} への提案が上位会社に評価されました。'
                                '次は客先面談へ進みます。'
                          : '${candidate.title} への参画に向けて、次は受注手続きへ進みます。',
                      session: session,
                      failureReasons: _aggregate
                          .projectInterviewFailureReasonsFor(widget.engineerId),
                      onContinue: () => Navigator.of(context).pop(),
                    )
                  : _QuestionPhase(
                      keyPrefix: _keyPrefix,
                      engineer: engineer,
                      candidate: candidate,
                      interviewLabel: _interviewLabel,
                      session: session,
                      // Codex P2 fix (PR #214): binds this exact rendered
                      // question's index into the closure at build time —
                      // see `_chooseFollowUp`'s own doc for why this must
                      // never be re-derived from `_session`/`_aggregate`
                      // when the tap actually fires.
                      onChoose: (choice) =>
                          _chooseFollowUp(session.currentQuestionIndex, choice),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.closeKey,
    required this.onClose,
  });

  final String title;
  final Key closeKey;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(key: closeKey, onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.engineerName,
    required this.projectTitle,
    required this.interviewLabel,
  });

  final String engineerName;
  final String projectTitle;
  final String interviewLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFB3E5FC),
          child: Icon(
            Icons.badge_outlined,
            color: SesTheme.primaryBlue,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                engineerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$projectTitle ・ $interviewLabel',
                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The active question/follow-up step — mirrors `ClientInterviewScreen`'s
/// own layout, condensed for a bounded dialog height and wrapped in a
/// scrolling [ListView] so a larger `TextScaler` grows content downward
/// (scrollable) rather than overflowing.
class _QuestionPhase extends StatelessWidget {
  const _QuestionPhase({
    required this.keyPrefix,
    required this.engineer,
    required this.candidate,
    required this.interviewLabel,
    required this.session,
    required this.onChoose,
  });

  final String keyPrefix;
  final PublicDemoEngineerSales engineer;
  final PublicDemoProjectCandidate candidate;
  final String interviewLabel;
  final ClientInterviewSession session;
  final ValueChanged<ClientInterviewFollowUp> onChoose;

  @override
  Widget build(BuildContext context) {
    final question = session.questions[session.currentQuestionIndex];
    final answer = session.employeeAnswers[session.currentQuestionIndex];
    // SingleChildScrollView rather than ListView: the handful of children
    // here never need viewport-based virtualization, and building the
    // whole subtree eagerly (unlike ListView's sliver-lazy children) means
    // every follow-up choice is always reachable by scrolling even at the
    // largest TextScaler on the smallest supported viewport.
    return SingleChildScrollView(
      key: Key('$keyPrefix-question-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            engineerName: engineer.name,
            projectTitle: candidate.title,
            interviewLabel: interviewLabel,
          ),
          const SizedBox(height: 12),
          Text(
            '質問 ${session.currentQuestionIndex + 1} / ${session.questions.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '面接官',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    '「${question.text}」',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    engineer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    '「${answer.text}」',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          if (session.interviewerReactions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  session.interviewerReactions.last,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            '営業として何を補足しますか？',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          for (final choice in ClientInterviewEngine.choices(question))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                key: Key('$keyPrefix-follow-${choice.name}'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(12),
                  minimumSize: const Size(0, 46),
                ),
                onPressed: () => onChoose(choice),
                child: Text(
                  clientInterviewFollowUpLabels[choice]!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pass/fail result. Never shows a raw score/rate/hidden parameter — only
/// the truthful, already-disclosed [failureReasons] on a failure, and a
/// safe next step in both directions (HIDDEN-PARAMS-1 / no dead end).
class _ResultPhase extends StatelessWidget {
  const _ResultPhase({
    required this.keyPrefix,
    required this.engineer,
    required this.candidate,
    required this.interviewLabel,
    required this.passContinuation,
    required this.session,
    required this.failureReasons,
    required this.onContinue,
  });

  final String keyPrefix;
  final PublicDemoEngineerSales engineer;
  final PublicDemoProjectCandidate candidate;
  final String interviewLabel;
  final String passContinuation;
  final ClientInterviewSession session;
  final List<String> failureReasons;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final passed = session.result == ClientInterviewResult.passed;
    final color = passed ? Colors.green.shade700 : Colors.red.shade700;
    // SingleChildScrollView, not ListView — see _QuestionPhase's own doc.
    return SingleChildScrollView(
      key: Key('$keyPrefix-result-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            engineerName: engineer.name,
            projectTitle: candidate.title,
            interviewLabel: interviewLabel,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      passed ? Icons.check_circle : Icons.cancel,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      passed ? '合格' : '不合格',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (passed) ...[
                  Text(passContinuation, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    '月額 ${formatYen(candidate.monthlyRate)} ・ ${candidate.clientName}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                    ),
                  ),
                ] else ...[
                  const Text(
                    '今回の主な理由:',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  for (final reason in failureReasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '・$reason',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${engineer.name}さんは営業状態へ戻ります。別の案件へ再営業できます。',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: Key('$keyPrefix-continue'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: onContinue,
              child: const Text('続ける'),
            ),
          ),
        ],
      ),
    );
  }
}
