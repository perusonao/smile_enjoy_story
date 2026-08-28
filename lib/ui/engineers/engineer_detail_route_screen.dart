import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import 'engineer_detail_screen.dart';

/// Route shell for [EngineerDetailScreen] that keeps blocking decisions in a
/// persistent bottom action area on narrow mobile viewports.
///
/// The detailed/read-only cards remain in [EngineerDetailScreen]. This shell
/// does not introduce a second gameplay authority: every action delegates to
/// the same GameController methods used by the existing cards. Its only job is
/// presentation priority so a pending interview/Offer never requires a
/// synthetic scroll before the player can respond.
class EngineerDetailRouteScreen extends StatelessWidget {
  const EngineerDetailRouteScreen({super.key, required this.engineerId});

  final String engineerId;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final interviewOffers = state.interviewOffers
        .where(
          (offer) =>
              offer.employeeId == engineerId &&
              offer.status == InterviewOfferStatus.pending,
        )
        .toList();
    final pendingOffers = state.offers
        .where(
          (offer) =>
              offer.employeeId == engineerId && offer.status == OfferStatus.pending,
        )
        .toList();

    return Scaffold(
      body: EngineerDetailScreen(engineerId: engineerId),
      bottomNavigationBar: interviewOffers.isNotEmpty
          ? _InterviewCriticalBar(offer: interviewOffers.first)
          : pendingOffers.isNotEmpty
              ? _FinalOfferCriticalBar(offer: pendingOffers.first)
              : null,
    );
  }
}

class _InterviewCriticalBar extends StatelessWidget {
  const _InterviewCriticalBar({required this.offer});

  final InterviewOffer offer;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final project = state.openProjects
        .where((entry) => entry.project.id == offer.projectId)
        .map((entry) => entry.project)
        .firstOrNull;
    if (project == null) return const SizedBox.shrink();

    void decline() {
      final messenger = ScaffoldMessenger.of(context);
      context.game.declineInterviewOffer(offer.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${project.title}の面談依頼を断りました')),
      );
    }

    void accept() {
      final messenger = ScaffoldMessenger.of(context);
      context.game.acceptInterviewOffer(offer.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${project.title}の選考に進みます')),
      );
    }

    return _CriticalActionSurface(
      eyebrow: '重要な対応',
      title: '面談依頼: ${project.title}',
      primary: FilledButton(
        onPressed: accept,
        child: const Text('面談へ進む'),
      ),
      secondary: OutlinedButton(
        onPressed: decline,
        child: const Text('断る'),
      ),
    );
  }
}

class _FinalOfferCriticalBar extends StatelessWidget {
  const _FinalOfferCriticalBar({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final application = state.proposals
        .where((proposal) => proposal.id == offer.applicationId)
        .firstOrNull;
    if (application == null) return const SizedBox.shrink();

    Future<void> accept() async {
      final controller = context.game;
      final stableContext = Navigator.of(context).context;
      controller.acceptOffer(offer.id);
      if (!stableContext.mounted) return;
      final engineer = controller.state.engineerById(offer.employeeId);
      await showDialog<void>(
        context: stableContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('参画オファーを受諾しました'),
          content: Text(
            '${engineer.profile.name}\n\n'
            '${application.project.title}\n\n'
            '月単価: ${formatYen(offer.monthlyRate)}\n'
            '参画開始: Week ${offer.startWeek}\n\n'
            '現在: 参画開始待ち',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    Future<void> decline() async {
      final messenger = ScaffoldMessenger.of(context);
      final confirmed = await confirmIrreversibleAction(
        context,
        title: '参画オファーを辞退しますか？',
        message:
            '「${application.project.title}」への参画オファーを辞退します。この判断は取り消せません。',
        confirmLabel: '辞退する',
      );
      if (!confirmed || !context.mounted) return;
      context.game.declineOffer(offer.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${application.project.title} の参画オファーを辞退しました')),
      );
    }

    return _CriticalActionSurface(
      eyebrow: '重要な対応',
      title: '参画オファー: ${application.project.title}',
      primary: FilledButton(
        onPressed: accept,
        child: const Text('受諾'),
      ),
      secondary: OutlinedButton(
        onPressed: decline,
        child: const Text('辞退'),
      ),
    );
  }
}

class _CriticalActionSurface extends StatelessWidget {
  const _CriticalActionSurface({
    required this.eyebrow,
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final String eyebrow;
  final String title;
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: secondary),
                  const SizedBox(width: 8),
                  Expanded(child: primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
