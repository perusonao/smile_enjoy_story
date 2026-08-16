import 'package:flutter/material.dart';

/// Shared success/failure result presentation (Playable 0.4C.3 §8) for key
/// events — recruitment hire/reject, offer accept/decline, selection
/// pass/fail, contract signed, first assignment, founding complete.
///
/// Success gets a clear headline, a light checkmark treatment and (for the
/// biggest beats) a 🎉 celebration prefix. Failure is never just a red
/// screen: [nextStep] is required whenever [success] is false so the
/// Failure-safe Flow is visible in the UI, not just true underneath it.
class OutcomeCard extends StatelessWidget {
  const OutcomeCard({
    super.key,
    required this.success,
    required this.title,
    this.celebration = false,
    this.details,
    this.nextStep,
  }) : assert(success || nextStep != null, 'Failure outcomes must state the next step (Failure-safe Flow, §8).');

  final bool success;
  final String title;
  final bool celebration;

  /// Short factual lines (evaluation points, reasons) shown under the title.
  final String? details;

  /// "次に何をすればいいか" — always shown for failure, optional for success.
  final String? nextStep;

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF2E7D32) : Colors.red.shade700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.info_outline, color: color, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                celebration ? '🎉 $title' : title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
        if (details != null) ...[
          const SizedBox(height: 14),
          Text(details!, style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ],
        if (nextStep != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (success ? color : Colors.blueGrey).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (success ? color : Colors.blueGrey).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_forward, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Expanded(child: Text(nextStep!, style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
