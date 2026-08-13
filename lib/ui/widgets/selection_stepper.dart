import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../theme.dart';
import 'labels.dart';

/// Compact, wrapping selection progress for mobile-first cards.
class SelectionStepper extends StatelessWidget {
  const SelectionStepper({
    super.key,
    required this.steps,
    required this.currentStepIndex,
    this.compact = false,
  });

  final List<SelectionStep> steps;
  final int currentStepIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 340;
        return Wrap(
          spacing: narrow ? 4 : 6,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              _Step(
                label: compact
                    ? selectionStepShortLabels[steps[index]]!
                    : selectionStepLabels[steps[index]]!,
                state: index < currentStepIndex
                    ? _StepState.complete
                    : index == currentStepIndex
                    ? _StepState.current
                    : _StepState.upcoming,
              ),
              if (index < steps.length - 1)
                const Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: Colors.black26,
                ),
            ],
          ],
        );
      },
    );
  }
}

enum _StepState { complete, current, upcoming }

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.complete => Colors.green.shade700,
      _StepState.current => SesTheme.primaryBlue,
      _StepState.upcoming => Colors.black38,
    };
    final icon = switch (state) {
      _StepState.complete => Icons.check_circle,
      _StepState.current => Icons.radio_button_checked,
      _StepState.upcoming => Icons.radio_button_unchecked,
    };
    return Semantics(
      label:
          '$label ${switch (state) {
            _StepState.complete => '完了',
            _StepState.current => '現在',
            _StepState.upcoming => '未実施',
          }}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: state == _StepState.current
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
