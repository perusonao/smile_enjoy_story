import 'package:flutter/material.dart';

import '../../game/game.dart';
import 'first_contract_celebration.dart';
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
      if (assignment == null || employee == null) return null;
      // Title/body left empty on purpose: for a player who reaches their
      // first assignment without playing the Founding Prologue (自由に開始),
      // this dialog *is* the flagship celebration the Prologue's own
      // completion screen otherwise gives (§20) — [FirstContractCelebration]
      // already carries its own headline, so a duplicate title here would
      // just repeat "🎉 初案件参画" twice in the same dialog.
      return FoundingEventDialog(
        title: '',
        body: '',
        primaryLabel: '会社状況を見る',
        celebration: true,
        extra: FirstContractCelebration(assignment: assignment, employee: employee),
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
///
/// Title/body are optional (Playable 0.4C.4 §20): a dialog whose [extra]
/// already carries its own headline (e.g. [FirstContractCelebration]) can
/// leave both empty rather than repeat itself above a second, identical
/// title.
Future<bool> showFoundingEventDialog(BuildContext context, FoundingEventDialog dialog) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: dialog.title.isEmpty
          ? null
          : Text(
              dialog.title,
              style: dialog.celebration ? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold) : null,
            ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dialog.body.isNotEmpty) Text(dialog.body),
            if (dialog.extra != null) ...[if (dialog.body.isNotEmpty) const SizedBox(height: 14), dialog.extra!],
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
