import 'package:flutter/material.dart';

import '../theme.dart';
import 'public_demo_sales_visual.dart';

/// SES First Fun Quarter AI Replay Audit #2 P1-3 Fresh Audit fix.
///
/// Before this fix, [PublicDemoAggregate.acceptOffer] (invoked by `offer(i)`
/// in `public_demo_01_placeholder_screen.dart`) already deterministically
/// decided 内定承諾/内定辞退 the moment the player chose a salary — but
/// nothing displayed that outcome. Browsing to 営業 afterward showed the
/// updated `applicantStatus(a)` badge, so a player who happened to look
/// could tell; a player who reached this same action through HOME's guided
/// "次にやること" card never did, since HOME's own recommended-action
/// ranking simply moved on to the next candidate the moment this
/// applicant's `stage` left `interviewed` — an accepted offer looks the
/// same as a declined one from HOME's perspective, an entirely silent
/// "nothing left to do for this person" until the player separately
/// checked 営業.
///
/// This dialog is a pure, read-only presentation of a decision the domain
/// already made and already committed to state before this dialog is ever
/// shown (see `_showOfferResultIfDecided`'s own doc) — it recomputes
/// nothing, mints no second judgement, and is shown identically regardless
/// of which entry point (HOME's card or 営業 tab's own button) triggered
/// `offer(i)`, so there is exactly one accept/decline authority and exactly
/// one place a player sees its outcome described.
class PublicDemoOfferResultDialog extends StatelessWidget {
  const PublicDemoOfferResultDialog({
    super.key,
    required this.applicantName,
    required this.portraitAssetPath,
    required this.accepted,
    required this.offeredMonthlySalary,
    required this.reason,
  });

  final String applicantName;
  final String? portraitAssetPath;
  final bool accepted;

  /// [PublicDemoApplicant.acceptedMonthlySalary] — recorded for a declined
  /// offer too (see [PublicDemoSalaryOffer.applyTo]'s own doc), so this is
  /// never `null` for an applicant this dialog is shown for.
  final int offeredMonthlySalary;

  /// [PublicDemoApplicant.salaryRelationshipReason] — the existing, already
  /// player-facing short explanation
  /// ([PublicDemoSalaryOffer.relationshipReason]) computed at decision time,
  /// never a new one invented for this dialog.
  final String reason;

  @override
  Widget build(BuildContext context) {
    final resultLabel = accepted ? '内定承諾' : '内定辞退';
    final nextAction = accepted ? '入社に向けた準備に進みます。' : '他の候補者の選考を進めましょう。';
    return AlertDialog(
      key: Key('public-demo-offer-result-dialog-$applicantName'),
      title: Text(resultLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PublicDemoSalesAvatar(assetPath: portraitAssetPath, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      applicantName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('提示給与 ${formatYen(offeredMonthlySalary)}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(reason),
          const SizedBox(height: 8),
          Text(nextAction, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        FilledButton(
          key: const Key('public-demo-offer-result-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
