import 'package:flutter/foundation.dart' show immutable;

/// Presentation-only display data for one employee slot on the home office
/// stage.
///
/// HOME-UI-1B does not read from or compute Domain/Workflow employee state:
/// this is a plain, external-input record so a later phase can supply
/// already-resolved employee data without `OfficeStageSection` holding any
/// employee/assignment/payroll authority of its own. [imageAssetPath] is
/// nullable so a caller with no portrait yet still renders (see the
/// placeholder fallback in `office_stage_section.dart`).
@immutable
class EmployeeStageDisplay {
  const EmployeeStageDisplay({required this.name, this.imageAssetPath});

  final String name;
  final String? imageAssetPath;

  @override
  bool operator ==(Object other) =>
      other is EmployeeStageDisplay &&
      other.name == name &&
      other.imageAssetPath == imageAssetPath;

  @override
  int get hashCode => Object.hash(name, imageAssetPath);
}
