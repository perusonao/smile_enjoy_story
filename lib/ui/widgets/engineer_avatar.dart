import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../asset_paths.dart';

/// Deterministic, UI-only portrait pick for an [Engineer]/[Applicant] roster
/// card (社員画面 Phase 2). No `portraitId` field exists on either model and
/// none is added here — [ApplicantType] is already a permanent, always-set
/// part of the hired profile, so keying off it gives every employee a
/// stable face across app restarts without any new persisted state or save
/// schema change.
String portraitAssetFor(ApplicantType type) => switch (type) {
  ApplicantType.juniorProgrammer => AssetPaths.engineerJunior,
  ApplicantType.midLevelEngineer => AssetPaths.engineerMidlevel,
  ApplicantType.frontendSpecialist => AssetPaths.engineerMidlevel,
  ApplicantType.infrastructureSpecialist => AssetPaths.engineerMidlevel,
  ApplicantType.seniorEngineer => AssetPaths.engineerVeteran,
  ApplicantType.plCandidate => AssetPaths.engineerVeteran,
};

/// Small circular portrait for an engineer roster card, backed by the
/// bundled `characters/engineer_*` assets ([AssetPaths]) instead of an
/// icon placeholder.
class EngineerAvatar extends StatelessWidget {
  const EngineerAvatar({super.key, required this.applicantType, this.radius = 22});

  final ApplicantType applicantType;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: AssetImage(portraitAssetFor(applicantType)),
    );
  }
}
