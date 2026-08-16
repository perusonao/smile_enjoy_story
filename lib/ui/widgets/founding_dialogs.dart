import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import 'labels.dart';

/// Content for a one-time founding-tutorial dialog (celebration or
/// contextual explanation, §13-14, §19-20, §25, §37, §39, §47).
class FoundingEventDialog {
  final String title;
  final String body;
  final String primaryLabel;
  final bool celebration;

  /// Extra structured content shown under [body] (Playable 0.4C.3 §9) —
  /// used by the first-assignment celebration to surface unit price /
  /// gross margin / payment terms / first-payment estimate without
  /// cramming numbers into the plain-text body.
  final Widget? extra;

  const FoundingEventDialog({
    required this.title,
    required this.body,
    this.primaryLabel = 'OK',
    this.celebration = false,
    this.extra,
  });
}

/// Builds the dialog copy for [event] from the current [state]. Returns
/// `null` if there's nothing sensible to show (defensive — callers only
/// invoke this for events [ProgressionEngine.pendingEvents] already
/// confirmed are true).
FoundingEventDialog? buildFoundingEventDialog(OneTimeEvent event, GameState state) {
  switch (event) {
    case OneTimeEvent.interviewOfferCelebration:
      final offer = state.interviewOffers.where((o) => o.status == InterviewOfferStatus.pending).firstOrNull
          ?? state.interviewOffers.firstOrNull;
      if (offer == null) return null;
      final employee = state.engineers.where((e) => e.id == offer.employeeId).firstOrNull;
      final project = state.openProjects.where((e) => e.project.id == offer.projectId).firstOrNull?.project;
      return FoundingEventDialog(
        title: '🎉 面談依頼が届きました！',
        body: '${clientNameById(project?.clientId ?? '')}から\n'
            '${employee?.profile.name ?? '社員'}さんへ面談依頼があります。\n\n'
            '案件:\n${project?.title ?? ''}',
        primaryLabel: '面談依頼を見る',
        celebration: true,
      );
    case OneTimeEvent.firstAssignmentCelebration:
      final assignment = state.activeAssignments.firstOrNull;
      final employee = assignment == null ? null : state.engineers.where((e) => e.id == assignment.engineerId).firstOrNull;
      return FoundingEventDialog(
        title: '🎉 初案件参画！',
        body: 'あなたの会社で初めての売上が生まれます。\n\n'
            '${employee?.profile.name ?? '社員'}さんが\n'
            '${assignment?.project.title ?? '案件'}へ参画しました。',
        primaryLabel: '会社状況を見る',
        celebration: true,
        extra: assignment == null || employee == null ? null : _FirstAssignmentBreakdown(assignment: assignment, employee: employee, week: state.week),
      );
    case OneTimeEvent.recruitmentUnlockCelebration:
      return const FoundingEventDialog(
        title: '🎉 新機能解放: 採用',
        body: '会社を拡大するため、新しいエンジニアを採用できるようになりました。',
        primaryLabel: '採用を見る',
        celebration: true,
      );
    case OneTimeEvent.clientInterviewCelebration:
      return const FoundingEventDialog(
        title: '初めての客先面談が終わりました',
        body: '営業では不合格になることもあります。\n'
            'SkillSheetを見直すか、次の面談依頼を待ちましょう。',
        primaryLabel: 'OK',
      );
    case OneTimeEvent.recruitmentInterviewCelebration:
      return const FoundingEventDialog(
        title: '初めての採用面接が終わりました',
        body: '採用面接の結果をもとに、内定を出すか判断できます。',
        primaryLabel: 'OK',
      );
    case OneTimeEvent.welfareUnlockCelebration:
      return const FoundingEventDialog(
        title: '🎉 新機能解放: 社員環境 / 福利厚生',
        body: '会社は社員に案件を用意するだけではありません。\n'
            'PC、健康診断、賞与などへ投資すると、Moraleや会社へのTrustに影響します。',
        primaryLabel: '社員環境を見る',
        celebration: true,
      );
    case OneTimeEvent.firstOfferTutorial:
      return const FoundingEventDialog(
        title: '参画オファーとは',
        body: '選考を通過すると、正式な参画オファーが届きます。\n'
            '回答期限までに受諾するか辞退するか判断してください。',
      );
    case OneTimeEvent.firstArTutorial:
      final ar = state.accountsReceivable.lastOrNull;
      if (ar == null) return null;
      final client = FinanceEngine.clientById(ar.clientId);
      return FoundingEventDialog(
        title: '売上が発生しました',
        body: 'ただし売上はすぐ現金になるとは限りません。\n\n'
            '${client.name}の支払サイト: ${client.paymentTermDays}日\n'
            '今回の売上は ${GameCalendar.monthEndLabel(ar.dueMonth)} に入金されます。',
      );
    case OneTimeEvent.fieldLeadTutorial:
      return const FoundingEventDialog(
        title: 'Field Lead とは',
        body: '現場に参画している社員から、増員予定などの案件情報が届くことがあります。\n'
            '会社への信頼が高い社員ほど、情報を持ち帰りやすくなります。',
      );
    case OneTimeEvent.contractRenewalTutorial:
      return const FoundingEventDialog(
        title: '契約更新の判断',
        body: '契約終了の4週間前になると、延長するか撤退するかを判断できます。\n'
            '本人の希望と異なる判断をすると、モチベーションや信頼に影響することがあります。',
      );
    case OneTimeEvent.clientUnlockTutorial:
      return const FoundingEventDialog(
        title: '新規取引先が増えました',
        body: '実績や信頼を積むことで、取引可能な会社が増えていきます。\n'
            '取引先が増えるほど、案件の選択肢も広がります。',
      );
  }
}

/// Shows [dialog] and returns `true` if the player tapped the primary
/// action (used by callers that then navigate somewhere on confirm).
Future<bool> showFoundingEventDialog(BuildContext context, FoundingEventDialog dialog) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        dialog.title,
        style: dialog.celebration ? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold) : null,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dialog.body),
            if (dialog.extra != null) ...[const SizedBox(height: 14), dialog.extra!],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialog.primaryLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Unit price / gross margin / payment terms / first-payment estimate for
/// the first assignment (Playable 0.4C.3 §9) — makes "契約成立 ≠ 即現金
/// 増加" concrete with an actual date instead of just the general reminder
/// text every assignment celebration already carried.
class _FirstAssignmentBreakdown extends StatelessWidget {
  const _FirstAssignmentBreakdown({required this.assignment, required this.employee, required this.week});

  final ActiveAssignment assignment;
  final Engineer employee;
  final int week;

  @override
  Widget build(BuildContext context) {
    final project = assignment.project;
    final profit = MatchingEngine.monthlyProfit(employee, project);
    final paymentTermDays = paymentTermDaysById(project.clientId);
    final generatedMonth = GameCalendar.absoluteMonth(assignment.contractStartWeek);
    final dueMonth = FinanceEngine.dueMonthFor(generatedMonth: generatedMonth, paymentTermDays: paymentTermDays);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('月額単価', formatYen(project.monthlyRate)),
          _row('月間想定粗利', formatYen(profit)),
          _row('支払サイト', '$paymentTermDays日'),
          _row('初回入金予定', GameCalendar.monthEndLabel(dueMonth)),
          const Divider(height: 18),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 15, color: Colors.black54),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '契約成立=即現金増加ではありません。売上は毎月発生しますが、\n'
                  '現金は上の入金予定まで入ってきません。',
                  style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black54))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
      ],
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
