import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_mission_resolver.dart';
import '../theme.dart';

// SES First Fun Quarter — Mission System Phase 1 (April Main Mission),
// design docs:
//   docs/reports/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Fresh-Audit.md
//   docs/design/SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md
//
// A read-only, full-route Mission screen (Navigator.push, not a modal
// sheet — Fresh Audit §9 Option E) showing April's headline mission
// ("技術者1名を案件に参画させよう") and its 7-step chain, each step's status
// resolved by [PublicDemoMissionResolver] before this widget is built.
// This screen mutates nothing: it takes an already-resolved
// `List<PublicDemoMissionStatusEntry>`, never a live aggregate, mirroring
// every other Public Demo "display data" screen's own convention (e.g.
// [PublicDemoOfferComparisonScreen] reading live getters, never holding
// authority itself). No BuildContext-side game state is read here.

/// SES First Fun Quarter Mission System Phase 2 (Progressive Onboarding):
/// April's headline goal, in the exact wording shown on [_MainMissionHeader]
/// below. Extracted to a shared constant so the Opening Context's own
/// "4月の目標" page (`public_demo_opening_context_screen.dart`) can quote the
/// identical sentence rather than a second, hand-typed copy that could
/// silently drift from this screen's own headline — both surfaces read this
/// one string.
const String publicDemoAprilHeadlineGoal = '技術者1名を案件に参画させよう';

/// Short display copy for one Mission — 目的 (purpose) / 操作 (what to do
/// next) / a one-line Hiyori remark. Deliberately terse for Phase 1 (task
/// scope: "長いチュートリアル文章を入れすぎない").
class PublicDemoMissionCopy {
  const PublicDemoMissionCopy({
    required this.title,
    required this.purpose,
    required this.nextAction,
    required this.hiyoriComment,
  });

  final String title;
  final String purpose;
  final String nextAction;
  final String hiyoriComment;
}

/// The Phase 1 April chain's display copy, keyed by [PublicDemoMissionId].
/// Const, presentation-only — no authority, no state.
const Map<PublicDemoMissionId, PublicDemoMissionCopy>
publicDemoAprilMissionCopy = {
  PublicDemoMissionId.viewSkillSheet: PublicDemoMissionCopy(
    title: '技術者のSkillSheetを確認する',
    purpose: '案件との相性を自分で判断するために、まず技術者の経歴を確認します。',
    nextAction: '社員タブでSkillSheetを開きましょう。',
    hiyoriComment: 'まずは技術者のことを知るところから始めましょう。',
  ),
  // SES First Fun Quarter Mission Phase 3 (SkillSheet Editing).
  PublicDemoMissionId.editSkillSheet: PublicDemoMissionCopy(
    title: '技術者のSkillSheetを編集する',
    purpose: '営業を始める前に、取引先へ見せる表示経験を確認・調整しておきます。',
    nextAction: '社員タブで「スキルシートを編集」から表示経験を保存しましょう。',
    hiyoriComment: '実際の実務経験や実力は変わりません。あくまで見せ方の調整です。',
  ),
  PublicDemoMissionId.beginSelling: PublicDemoMissionCopy(
    title: '営業を開始する',
    purpose: 'SkillSheetを確認したら、案件を探すための営業を始めます。',
    nextAction: '営業タブから営業を開始しましょう。',
    hiyoriComment: '営業を開始すると、案件を紹介できるようになります。',
  ),
  PublicDemoMissionId.proposeToProject: PublicDemoMissionCopy(
    title: '案件に提案する',
    purpose: '技術者を実際の案件に紹介し、選考をスタートします。',
    nextAction: '案件を選んで提案しましょう。',
    hiyoriComment: '相性の良い案件を選ぶのがポイントです。',
  ),
  PublicDemoMissionId.passPartnerInterview: PublicDemoMissionCopy(
    title: '上位会社面談を通過する',
    purpose: 'SESでは元請け企業（上位会社）との面談が最初の関門になります。',
    nextAction: '上位会社面談に進みましょう。',
    hiyoriComment: 'ここを通過すると、いよいよ客先面談です。',
  ),
  PublicDemoMissionId.passClientInterview: PublicDemoMissionCopy(
    title: '客先面談を通過する',
    purpose: '実際に案件に参画する客先企業との面談です。ここを通過すれば受注が見えてきます。',
    nextAction: '客先面談に進みましょう。',
    hiyoriComment: 'お客様との相性も大事な確認ポイントです。',
  ),
  PublicDemoMissionId.winOrder: PublicDemoMissionCopy(
    title: '案件を受注する',
    purpose: '面談を通過した案件を正式に受注します。',
    nextAction: '受注の手続きを行いましょう。',
    hiyoriComment: 'あと少しで技術者が案件に参画できます！',
  ),
  PublicDemoMissionId.assignToProject: PublicDemoMissionCopy(
    title: '技術者を案件に参画させる',
    purpose: '受注した案件に技術者が参画すると、SES事業の売上が発生します。',
    nextAction: '月を進めて、参画を確定させましょう。',
    hiyoriComment:
        '参画すると売上が発生します。ただし、入金は後になります。入金予定も確認していきましょう。',
  ),
};

/// SES First Fun Quarter Mission Phase 4 — the Recruitment Mission chain's
/// display copy, keyed by [PublicDemoMissionId]. Const, presentation-only —
/// no authority, no state.
const Map<PublicDemoMissionId, PublicDemoMissionCopy>
publicDemoRecruitmentMissionCopy = {
  PublicDemoMissionId.postRecruitmentMedium: PublicDemoMissionCopy(
    title: '求人媒体を利用する',
    purpose: '新しい技術者を採用するには、まず求人媒体で応募者を集めます。',
    nextAction: '営業タブの求人媒体から応募者を集めましょう。',
    hiyoriComment: '求人媒体は月に1回まで利用できます。',
  ),
  PublicDemoMissionId.viewApplicantSkillSheet: PublicDemoMissionCopy(
    title: '応募者のSkillSheetを確認する',
    purpose: '応募者の経歴やスキルを確認してから、選考を進めるか判断します。',
    nextAction: '応募者カードからSkillSheetを確認しましょう。',
    hiyoriComment: '経歴を見てから、次に進むか見送るか判断しましょう。',
  ),
  PublicDemoMissionId.screenApplicantResume: PublicDemoMissionCopy(
    title: '書類選考する',
    purpose: '確認した内容をもとに、面接に進めるか、今回は見送るかを選びます。',
    nextAction: '応募者カードで「採用面談」または「見送る」を選びましょう。',
    hiyoriComment: '見送りも立派な経営判断です。',
  ),
  PublicDemoMissionId.conductHiringInterview: PublicDemoMissionCopy(
    title: '面接する',
    purpose: '書類選考を通過した応募者と面接を行います。',
    nextAction: '採用面談を実施しましょう。',
    hiyoriComment: '面接で人柄や適性を確認しましょう。',
  ),
  PublicDemoMissionId.decideHiring: PublicDemoMissionCopy(
    title: '採用を決める',
    purpose: '面接の結果をもとに、給与条件を提示して採用を決めます。',
    nextAction: '合格・給与提示から採用を決めましょう。',
    hiyoriComment: '条件に納得してもらえれば、入社が決まります。',
  ),
  PublicDemoMissionId.applicantJoined: PublicDemoMissionCopy(
    title: '入社する',
    purpose: '採用が決まった応募者が実際に入社し、新しい社員になります。',
    nextAction: '月を進めて、入社を確定させましょう。',
    hiyoriComment: '新しい仲間が増えると、できることも増えていきます。',
  ),
};

/// Full-route Mission screen (Fresh Audit §9 Option E / Implementation
/// Plan §3.4). A [StatelessWidget]: every status was already resolved by
/// the caller before `Navigator.push`, so this screen re-renders correctly
/// on its own without holding any live aggregate reference.
class PublicDemoMissionScreen extends StatelessWidget {
  const PublicDemoMissionScreen({
    super.key,
    required this.missions,
    this.recruitmentMissions = const [],
  });

  /// Already-resolved statuses, in [publicDemoAprilMissionChain] order —
  /// see [PublicDemoMissionResolver.resolve].
  final List<PublicDemoMissionStatusEntry> missions;

  /// SES First Fun Quarter Mission Phase 4 — already-resolved Recruitment
  /// Mission statuses, in [publicDemoRecruitmentMissionChain] order (see
  /// [PublicDemoMissionResolver.resolveRecruitment]). Empty (the default)
  /// hides the section entirely — the caller decides visibility (SES First
  /// Fun Quarter Mission Phase 4: `state.month >= 5`), this screen only
  /// ever renders what it is handed, same convention as [missions] itself.
  final List<PublicDemoMissionStatusEntry> recruitmentMissions;

  int get _completedCount => missions
      .where((entry) => entry.status == PublicDemoMissionStatus.completed)
      .length;

  bool get _isMainMissionComplete => missions.isNotEmpty && _completedCount == missions.length;

  int get _recruitmentCompletedCount => recruitmentMissions
      .where((entry) => entry.status == PublicDemoMissionStatus.completed)
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ミッション')),
      body: SafeArea(
        child: ListView(
          key: const Key('public-demo-mission-screen-list'),
          padding: const EdgeInsets.all(16),
          children: [
            if (_isMainMissionComplete)
              _MissionCompleteBanner(key: const Key('public-demo-mission-complete-banner'))
            else
              _MainMissionHeader(
                completedCount: _completedCount,
                totalCount: missions.length,
              ),
            const SizedBox(height: 16),
            for (final entry in missions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MissionTile(
                  entry: entry,
                  copy: publicDemoAprilMissionCopy[entry.id],
                ),
              ),
            const SizedBox(height: 8),
            // SES First Fun Quarter Mission Phase 4: the Recruitment
            // Mission section replaces the generic placeholder below the
            // moment there is something real to show — this is exactly the
            // "次の経営目標" that placeholder always promised. Independent
            // of April chain completion: recruitment can genuinely run in
            // parallel from month 5 onward even while April is still in
            // progress.
            if (recruitmentMissions.isNotEmpty) ...[
              _RecruitmentMissionHeader(
                key: const Key('public-demo-mission-recruitment-header'),
                completedCount: _recruitmentCompletedCount,
                totalCount: recruitmentMissions.length,
              ),
              const SizedBox(height: 16),
              for (final entry in recruitmentMissions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MissionTile(
                    entry: entry,
                    copy: publicDemoRecruitmentMissionCopy[entry.id],
                  ),
                ),
            ] else if (_isMainMissionComplete)
              const _NextMissionPlaceholderCard(),
          ],
        ),
      ),
    );
  }
}

class _MainMissionHeader extends StatelessWidget {
  const _MainMissionHeader({required this.completedCount, required this.totalCount});

  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('public-demo-mission-main-header'),
      color: SesTheme.primaryBlue.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('4月の目標', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            const Text(
              publicDemoAprilHeadlineGoal,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              '進捗 $completedCount / $totalCount',
              key: const Key('public-demo-mission-progress-label'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCount == 0 ? 0 : completedCount / totalCount,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SES First Fun Quarter Mission Phase 4 — the Recruitment Mission
/// section's own header, mirroring [_MainMissionHeader]'s shape (title +
/// progress + bar) but visually distinct (no [SesTheme.primaryBlue] tint)
/// so the two chains read as separate goals, not one merged list.
class _RecruitmentMissionHeader extends StatelessWidget {
  const _RecruitmentMissionHeader({
    super.key,
    required this.completedCount,
    required this.totalCount,
  });

  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('public-demo-mission-recruitment-main-header'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('採用の目標', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            const Text(
              '技術者を新しく採用しよう',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              '進捗 $completedCount / $totalCount',
              key: const Key('public-demo-mission-recruitment-progress-label'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCount == 0 ? 0 : completedCount / totalCount,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionCompleteBanner extends StatelessWidget {
  const _MissionCompleteBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SesTheme.accentCyan.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.emoji_events, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MISSION COMPLETE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '初めての案件参画！',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 12),
            const Text(
              'ひより：\n'
              '「おめでとうございます！\n'
              '社員が案件に参画すると売上が発生します。\n'
              'ただし、売上と入金は同じタイミングではありません。\n'
              '入金予定も確認していきましょう。」',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextMissionPlaceholderCard extends StatelessWidget {
  const _NextMissionPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('public-demo-mission-next-placeholder'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '次の経営目標は今後解放されます。',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.entry, required this.copy});

  final PublicDemoMissionStatusEntry entry;

  /// SES First Fun Quarter Mission Phase 4: the caller looks this up from
  /// whichever chain's copy map applies ([publicDemoAprilMissionCopy] or
  /// [publicDemoRecruitmentMissionCopy]) — this widget itself no longer
  /// hardcodes a single map, so it renders either chain identically.
  final PublicDemoMissionCopy? copy;

  @override
  Widget build(BuildContext context) {
    // Local binding so Dart's flow analysis can promote it to non-null
    // inside the `copy != null` branch below — a `final` instance field
    // does not get the same promotion a local variable does.
    final copy = this.copy;
    final title = copy?.title ?? entry.id.name;
    final isCompleted = entry.status == PublicDemoMissionStatus.completed;
    final isLocked = entry.status == PublicDemoMissionStatus.locked;
    final isCurrent = entry.status == PublicDemoMissionStatus.available;

    final Widget statusIcon = switch (entry.status) {
      PublicDemoMissionStatus.completed => const Icon(Icons.check_circle, color: Colors.green),
      PublicDemoMissionStatus.available => const Icon(Icons.arrow_circle_right, color: Colors.blue),
      PublicDemoMissionStatus.locked => Icon(Icons.lock_outline, color: Colors.grey.shade500),
    };

    return Card(
      key: Key('public-demo-mission-tile-${entry.id.name}'),
      color: isCurrent ? SesTheme.primaryBlue.withValues(alpha: 0.05) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            statusIcon,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isLocked ? Colors.grey.shade600 : null,
                      decoration: isCompleted ? TextDecoration.none : null,
                    ),
                  ),
                  if (!isLocked && copy != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      copy.purpose,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 4),
                      Text(
                        '次に行う操作: ${copy.nextAction}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (isCompleted) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ひより: ${copy.hiyoriComment}',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
