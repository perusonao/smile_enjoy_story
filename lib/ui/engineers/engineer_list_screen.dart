import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import '../widgets/status_chip.dart';
import 'engineer_detail_screen.dart';

String _topTechSkillLabel(TechSkillLevels t) {
  final entries = <String, int>{
    'DB': t.database,
    'Network': t.network,
    'Infra': t.infrastructure,
    'Frontend': t.frontend,
    'Backend': t.backend,
    'Leader': t.leader,
    'Manager': t.manager,
  };
  final best = entries.entries.reduce((a, b) => a.value >= b.value ? a : b);
  if (best.value <= 0) return '-';
  return '${best.key} Lv.${best.value}';
}

class EngineerListScreen extends StatelessWidget {
  const EngineerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final engineers = [...state.engineers]
      ..sort((a, b) {
        int rank(EngineerStatus s) => switch (s) {
          EngineerStatus.waiting => 0,
          EngineerStatus.interviewScheduled => 1,
          EngineerStatus.proposed => 2,
          EngineerStatus.assigned => 3,
        };
        return rank(a.status).compareTo(rank(b.status));
      });

    return Scaffold(
      appBar: AppBar(title: const Text('社員')),
      body: engineers.isEmpty
          ? const Center(child: Text('社員がいません。'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              itemCount: engineers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _EngineerCard(engineer: engineers[i]),
            ),
    );
  }
}

class _EngineerCard extends StatelessWidget {
  const _EngineerCard({required this.engineer});

  final Engineer engineer;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final profile = engineer.profile;
    final workflowState = EmployeeWorkflowEngine.forEngineer(state, engineer.id);
    // "Idle" (red tint / border) means truly nothing is happening — not
    // merely unassigned. An employee who's selling, has a pending
    // interview request, or is mid-selection is doing something, and the
    // waiting-weeks badge is shown alongside that instead of being hidden
    // behind it (Playable 0.4C.3 §41-43).
    final isIdle = workflowState == EmployeeWorkflowState.waiting;
    final waitingWeeks = state.waitingStreakFor(engineer.id);

    final applications = state
        .applicationsForEngineer(engineer.id)
        .where(
          (application) =>
              application.status == ApplicationStatus.active ||
              application.status == ApplicationStatus.offered,
        )
        .toList();
    final pendingOffers = state.offers.where(
      (offer) =>
          offer.employeeId == engineer.id &&
          offer.status == OfferStatus.pending,
    );
    final pendingOffer = pendingOffers.isEmpty ? null : pendingOffers.first;
    ProjectApplication? offerApplication;
    if (pendingOffer != null) {
      offerApplication = state.proposals.firstWhere(
        (application) => application.id == pendingOffer.applicationId,
      );
    }

    String? currentProjectLabel;
    final assignment = state.assignmentForEngineer(engineer.id);
    if (assignment != null) {
      currentProjectLabel =
          '${assignment.project.title} (残${assignment.remainingWeeks}週)';
    }

    final waitingColor = waitingWeeks >= 3
        ? Colors.red
        : (waitingWeeks >= 2 ? Colors.orange : null);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EngineerDetailScreen(engineerId: engineer.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isIdle ? Colors.red.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isIdle
                ? Colors.red.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.outlineVariant,
            width: isIdle ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (waitingWeeks > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _WaitingBadge(
                      weeks: waitingWeeks,
                      color: waitingColor,
                    ),
                  ),
                EngineerStatusChip(state: workflowState),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _InfoBit(
                  icon: Icons.payments_outlined,
                  text: formatYen(engineer.salary),
                ),
                _InfoBit(
                  icon: Icons.code,
                  text:
                      languageLabels[profile.mainLanguage] ??
                      profile.mainLanguage.name,
                ),
                _InfoBit(
                  icon: Icons.star_outline,
                  text: _topTechSkillLabel(profile.techSkills),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (pendingOffer != null && offerApplication != null) ...[
              _OfferBanner(
                title: offerApplication.project.title,
                monthlyRate: pendingOffer.monthlyRate,
                deadlineThisWeek:
                    pendingOffer.responseDeadlineWeek == state.week,
              ),
              const SizedBox(height: 7),
            ],
            if (assignment == null) ...[
              if (workflowState == EmployeeWorkflowState.assignmentScheduled)
                _ScheduledBanner(
                  proposal: state.proposals.firstWhere(
                    (p) => p.engineerId == engineer.id && p.status == ApplicationStatus.accepted,
                  ),
                )
              else if(engineer.salesStatus==SalesStatus.selling)
                Container(width:double.infinity,padding:const EdgeInsets.all(8),margin:const EdgeInsets.only(bottom:6),color:Colors.blue.shade50,child:Text('営業中\n公開先 ${state.unlockedClientCount}社 / 参画可能 ${engineer.availableFromWeek<=state.week?'現在':'Week ${engineer.availableFromWeek}'}\n面談依頼待ち',style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold))),
              _SalesCapacity(count: applications.length),
              for (final application in applications.take(3))
                _ApplicationSummary(application: application),
            ] else if (currentProjectLabel != null)
              _ProjectLine(text: currentProjectLabel),
          ],
        ),
      ),
    );
  }
}

class _WaitingBadge extends StatelessWidget {
  const _WaitingBadge({required this.weeks, required this.color});

  final int weeks;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '待機$weeks週目',
        style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SalesCapacity extends StatelessWidget {
  const _SalesCapacity({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.workspaces_outline,
        size: 15,
        color: SesTheme.primaryBlue,
      ),
      const SizedBox(width: 5),
      Text(
        '並行営業 $count / $maxParallelProposalsPerEmployee',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
      ),
      const SizedBox(width: 8),
      for (var i = 0; i < maxParallelProposalsPerEmployee; i++)
        Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(
            i < count ? Icons.circle : Icons.circle_outlined,
            size: 9,
            color: i < count ? SesTheme.primaryBlue : Colors.black26,
          ),
        ),
    ],
  );
}

class _ApplicationSummary extends StatelessWidget {
  const _ApplicationSummary({required this.application});
  final ProjectApplication application;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            application.project.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          selectionStepLabels[application.currentStep]!,
          style: const TextStyle(
            fontSize: 12,
            color: SesTheme.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner({
    required this.title,
    required this.monthlyRate,
    required this.deadlineThisWeek,
  });
  final String title;
  final int monthlyRate;
  final bool deadlineThisWeek;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.notification_important, color: Colors.red, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '参画オファー',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${formatYen(monthlyRate)} / 月  回答期限: ${deadlineThisWeek ? '今週' : '確認してください'}',
                style: const TextStyle(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Shown instead of the "営業中" banner once a final Offer has been
/// accepted but the assignment hasn't started yet (Playable 0.4C.3 §5-7) —
/// the whole point being that "参画予定" is never just a status-chip word
/// with nothing backing it up on the card itself.
class _ScheduledBanner extends StatelessWidget {
  const _ScheduledBanner({required this.proposal});
  final ProjectApplication proposal;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    margin: const EdgeInsets.only(bottom: 6),
    color: Colors.purple.shade50,
    child: Text(
      '参画予定\n${proposal.project.title}\nWeek ${proposal.assignWeek} から参画',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

class _ProjectLine extends StatelessWidget {
  const _ProjectLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.work_outline, size: 15, color: Colors.black45),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
      ),
    ],
  );
}

class _InfoBit extends StatelessWidget {
  const _InfoBit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}
