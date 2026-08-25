import 'package:flutter/material.dart';

/// Month-end call-to-action area of the home dashboard.
///
/// Phase 1A renders a static, disabled banner only. Wiring this to the real
/// month-end flow (cash forecast, shortage/bankruptcy checks, ...) happens
/// in later phases.
class MonthEndCtaSection extends StatelessWidget {
  const MonthEndCtaSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.flag_outlined),
          label: const Text(
            '月末処理',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurfaceVariant,
            disabledBackgroundColor: colorScheme.surfaceContainerHighest,
            disabledForegroundColor: colorScheme.onSurfaceVariant,
            textStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
