import 'package:flutter/material.dart';

import '../../../ui/asset_paths.dart';
import '../models/employee_stage_display.dart';
import 'dashboard_section_card.dart';

/// Office / employee "stage" area of the home dashboard.
///
/// HOME-UI-1B integrates existing bundled image assets: a smartphone-portrait
/// office background plus up to 3 employee visual slots. No employee
/// selection, assignment, or payroll logic lives here — [employees] is a
/// plain external input (see [EmployeeStageDisplay]); an empty list (the
/// default) renders the same empty-slot fallback as HOME-UI-1A.
class OfficeStageSection extends StatelessWidget {
  const OfficeStageSection({
    super.key,
    this.officeImageAssetPath = AssetPaths.locationOfficeDay,
    this.employees = const [],
  });

  /// Background office image, or `null` to use the neutral fallback
  /// background without attempting to load an asset.
  final String? officeImageAssetPath;

  /// Up to 3 employees to feature on the stage. Extra entries beyond the
  /// first 3 are ignored — the HOME presentation slot count is fixed.
  final List<EmployeeStageDisplay> employees;

  static const int _slotCount = 3;

  @override
  Widget build(BuildContext context) {
    final visibleEmployees = employees.take(_slotCount).toList();
    return DashboardSectionCard(
      title: 'オフィス',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _OfficeBackground(imageAssetPath: officeImageAssetPath),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black45],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      for (var i = 0; i < _slotCount; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: KeyedSubtree(
                            key: ValueKey('office-stage-slot-$i'),
                            child: i < visibleEmployees.length
                                ? _EmployeeSlot(display: visibleEmployees[i])
                                : const _EmptyEmployeeSlot(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficeBackground extends StatelessWidget {
  const _OfficeBackground({required this.imageAssetPath});

  final String? imageAssetPath;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    final path = imageAssetPath;
    if (path == null) return fallback;
    return Semantics(
      label: 'オフィスの様子',
      image: true,
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _EmployeeSlot extends StatelessWidget {
  const _EmployeeSlot({required this.display});

  final EmployeeStageDisplay display;

  @override
  Widget build(BuildContext context) {
    final imagePath = display.imageAssetPath;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white24,
            border: Border.all(color: Colors.white70),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imagePath == null)
                const _PlaceholderIcon()
              else
                Semantics(
                  label: display.name,
                  image: true,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _PlaceholderIcon(),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ColoredBox(
                  color: Colors.black54,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    child: Text(
                      display.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyEmployeeSlot extends StatelessWidget {
  const _EmptyEmployeeSlot();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white24,
            border: Border.all(color: Colors.white70),
          ),
          child: const _PlaceholderIcon(),
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person_outline, color: Colors.white70, size: 28);
  }
}
