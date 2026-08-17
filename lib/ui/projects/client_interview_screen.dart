import 'package:flutter/material.dart';
import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/founding_dialogs.dart';
import '../widgets/outcome_card.dart';
import '../widgets/result_reveal.dart';

/// Client Interview (客先面談) / Upper Company Interview (上位会社面談).
///
/// Playable 0.4C.4 §22 brought this screen's visuals in line with the
/// recruitment interview's Playable 0.4C.3 upgrade — a person/project
/// header, readable card layout, the same judging-beat/result presentation
/// — without changing any selection-flow game rule. Every string and
/// [ValueKey] the Playwright driver (e2e/helpers/ses-player.ts) matches on
/// — "面接官", "客先面談", "上位会社面談", "合格"/"不合格", "続ける",
/// `follow-${choice.name}` — stays exactly as it was.
class ClientInterviewScreen extends StatelessWidget {
  const ClientInterviewScreen({super.key, required this.applicationId, this.step = SelectionStep.clientInterview, this.onResultContinue});
  final String applicationId;

  /// [SelectionStep.upperCompanyInterview] reuses this exact screen for the
  /// Founding Prologue's shorter, player-attended round (Playable 0.5A
  /// §45-49) — same mechanism, fewer questions, different labels.
  final SelectionStep step;

  /// Overrides the result screen's default "戻る" action — the Prologue
  /// needs to continue its own scripted flow instead of just popping (§48-52).
  final VoidCallback? onResultContinue;

  bool get _isUpper => step == SelectionStep.upperCompanyInterview;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final p = state.proposals.where((p) => p.id == applicationId).firstOrNull;
    // Transient, not a genuine error (Phase 3A UX review, P1-3) — same
    // reasoning as PrologueInterviewScreen/RecruitmentInterviewScreen: this
    // route is only pushed while the proposal is active, and it stops
    // matching the moment the interview's own result finalizes the
    // proposal, which can persist for a real, player-observable stretch
    // (a result dialog on top until dismissed). A blank Scaffold, not the
    // old "見つかりません" error and not a spinner (nothing is actually
    // loading).
    if (p == null) return const Scaffold(body: SizedBox.shrink());
    final e = state.engineerById(p.engineerId);
    final sessions = state.clientInterviews.where((s) => s.applicationId == applicationId && s.step == step).toList();
    if (sessions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.game.startClientInterview(applicationId, step: step);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = sessions.last;
    final label = _isUpper ? '上位会社面談' : '客先面談';

    if (s.completed) {
      if (!_isUpper && !state.foundingProgress.hasSeen(OneTimeEvent.clientInterviewCelebration)) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Wait out the ResultReveal suspense beat first — otherwise this
          // tutorial dialog pops up over the still-pending "判定しています…"
          // spinner, and by the time the player closes it the result has
          // already silently revealed underneath, so the suspense beat this
          // release added is never actually seen (Codex review, PR #9).
          await Future.delayed(ResultReveal.defaultDuration);
          if (!context.mounted) return;
          final controller = context.game;
          final dialog = buildFoundingEventDialog(OneTimeEvent.clientInterviewCelebration, controller.state);
          controller.markTutorialSeen(OneTimeEvent.clientInterviewCelebration);
          if (dialog != null && context.mounted) await showFoundingEventDialog(context, dialog);
        });
      }
      return Scaffold(
        appBar: AppBar(title: Text('$label結果')),
        body: SafeArea(
          child: ResultReveal(
            pendingLabel: '$labelの結果を確認しています…',
            builder: (_) => _Result(session: s, employeeName: e.profile.name, projectTitle: p.project.title, label: label, onContinue: onResultContinue),
          ),
        ),
      );
    }

    final q = s.questions[s.currentQuestionIndex];
    final a = s.employeeAnswers[s.currentQuestionIndex];
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _ClientInterviewHeader(employeeName: e.profile.name, projectTitle: p.project.title, label: label),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('質問 ${s.currentQuestionIndex + 1} / ${s.questions.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('面接官', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('「${q.text}」'),
                    const SizedBox(height: 12),
                    Text(e.profile.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('「${a.text}」'),
                  ],
                ),
              ),
            ),
            if (s.interviewerReactions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Card(
                color: Colors.orange.shade50,
                child: Padding(padding: const EdgeInsets.all(12), child: Text(s.interviewerReactions.last)),
              ),
              if (s.deepDiveText != null) ...[
                const SizedBox(height: 6),
                Text('深掘り: ${s.deepDiveText}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
              ],
            ],
            const SizedBox(height: 12),
            const Text('営業として何を補足しますか？', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final choice in ClientInterviewEngine.choices(q))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  key: ValueKey('follow-${choice.name}'),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(14),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => context.game.chooseClientInterviewFollowUp(s.id, choice),
                  child: Text(clientInterviewFollowUpLabels[choice]!),
                ),
              ),
            if (s.currentQuestionIndex > 0)
              ExpansionTile(
                title: Text('過去の質問 (${s.currentQuestionIndex})'),
                children: [
                  for (var i = 0; i < s.currentQuestionIndex; i++) ListTile(title: Text(s.questions[i].text), subtitle: Text(s.employeeAnswers[i].text)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Person/project header (Playable 0.4C.4 §22) — the same "who, and for
/// what" framing the recruitment interview's [ApplicantPersonaHeader]
/// gives, sized for an employee + client pairing rather than a candidate.
class _ClientInterviewHeader extends StatelessWidget {
  const _ClientInterviewHeader({required this.employeeName, required this.projectTitle, required this.label});
  final String employeeName;
  final String projectTitle;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(radius: 20, backgroundColor: Color(0xFFB3E5FC), child: Icon(Icons.badge_outlined, color: SesTheme.primaryBlue, size: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
              Text('$projectTitle ・ $label', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pass/fail result, reframed via [OutcomeCard] (Playable 0.4C.3 §8): a
/// failed selection round always says where the employee goes next, not
/// just "不合格" and a red headline.
class _Result extends StatelessWidget {
  const _Result({required this.session, required this.employeeName, required this.projectTitle, required this.label, this.onContinue});
  final ClientInterviewSession session;
  final String employeeName, projectTitle, label;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final passed = session.result == ClientInterviewResult.passed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        _ClientInterviewHeader(employeeName: employeeName, projectTitle: projectTitle, label: label),
        const SizedBox(height: 18),
        OutcomeCard(
          success: passed,
          title: passed ? '合格' : '不合格',
          details: passed
              ? '評価:\n・案件に沿った経験が評価された\n・受け答えが安定していた'
              : '主な理由:\n・${session.mismatchFailure ? 'SkillSheet記載に対して具体的な経験が不足' : '他候補がより案件要件に合致'}\n\n営業メモ:\n「強調する経験の見せ方を見直しましょう」',
          nextStep: passed ? '次: 選考の次ステップへ進みます。' : '$employeeNameさんは営業状態へ戻ります。SkillSheetを見直すか、次の面談依頼を待つことができます。',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: onContinue ?? () => Navigator.pop(context),
            child: Text(onContinue == null ? '社員を見る' : '続ける'),
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
