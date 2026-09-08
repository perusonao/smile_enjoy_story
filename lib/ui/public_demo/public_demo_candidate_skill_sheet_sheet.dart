import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_recruitment.dart';
import 'public_demo_candidate_skill_sheet_display_projection.dart';
import 'public_demo_skill_sheet_sections.dart' show SkillSheetMetricRow;

/// CORE-GAMEPLAY Phase 4.5: the pre-hire counterpart to
/// [PublicDemoSkillSheetSheet] (public_demo_skill_sheet_sheet.dart) — a
/// read-only bottom sheet showing an applicant's own SkillSheet content
/// before they join. Reuses the same mobile-first bottom-sheet shape and
/// [SkillSheetMetricRow] primitive as the employee sheet; the *content*
/// differs because [PublicDemoApplicant] has no runtime/tech-skill/career
/// data yet (see [PublicDemoCandidateSkillSheetDisplayFactory]'s own doc).
///
/// Purely presentational: never mutates or recomputes [applicant]. Every
/// caller (`_reviewResume`/`_beginPreEntrySkillSheet` in
/// public_demo_01_placeholder_screen.dart) commits its own existing stage
/// transition separately, exactly as before this phase — this sheet only
/// decides what to *show*, never what to advance.
class PublicDemoCandidateSkillSheetSheet extends StatelessWidget {
  const PublicDemoCandidateSkillSheetSheet({super.key, required this.applicant});

  final PublicDemoApplicant applicant;

  /// Opens the sheet. Unlike [PublicDemoSkillSheetSheet] (whose confirm
  /// button also commits a stage transition the caller decided in advance),
  /// this sheet is pure display — closing it any way (back, barrier dismiss)
  /// never carries a meaning the caller needs to distinguish, so this
  /// returns `void` rather than a tri-state bool.
  static Future<void> show(
    BuildContext context, {
    required PublicDemoApplicant applicant,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          PublicDemoCandidateSkillSheetSheet(applicant: applicant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = PublicDemoCandidateSkillSheetDisplayFactory.create(
      applicant: applicant,
    );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Container(
      key: Key('public-demo-candidate-skill-sheet-${data.applicantId}'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.name}\nスキルシート',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '応募時点でわかっている情報です。面談で判明する情報はここには含まれません。',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Text(data.summaryText),
                  const SizedBox(height: 8),
                  SkillSheetMetricRow('経験', data.experienceLabel),
                  SkillSheetMetricRow('希望給与', data.requestedMonthlySalaryLabel),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: Key(
                    'public-demo-candidate-skill-sheet-close-${data.applicantId}',
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
