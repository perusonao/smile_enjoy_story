import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_assignment.dart';
import '../../game/public_demo/public_demo_engineer_runtime.dart';
import '../../game/public_demo/public_demo_sales.dart';
import 'public_demo_skill_sheet_display_projection.dart';
import 'public_demo_skill_sheet_sections.dart';

/// SKILLSHEET-UX-2A Phase A: the redesigned SkillSheet review sheet.
///
/// A mobile-first bottom sheet — replacing the #117 [AlertDialog] — meant to
/// read like a compact sales document rather than a shrunk desktop table.
/// Purely presentational: it reads [PublicDemoEngineerSales],
/// [PublicDemoEngineerRuntime] and [PublicDemoAssignment] (via
/// [PublicDemoSkillSheetDisplayFactory]) and never mutates or recomputes any
/// of them.
///
/// Preserves every #117 semantic:
///  * root [Key] `public-demo-skill-sheet-<id>`, Back [Key]
///    `public-demo-skill-sheet-cancel-<id>`, confirm [Key]
///    `public-demo-skill-sheet-confirm-<id>`.
///  * [Navigator.pop] with `true` only from the explicit confirm button;
///    Back pops `false`; a barrier dismiss (tap outside / swipe down)
///    resolves the sheet's future to `null`. The caller
///    (`_openSkillSheetReview` in public_demo_01_placeholder_screen.dart)
///    already treats `false` and `null` identically as "do not advance", so
///    Back/dismiss never progresses the workflow and the sheet can be
///    reopened freely.
class PublicDemoSkillSheetSheet extends StatelessWidget {
  const PublicDemoSkillSheetSheet({
    super.key,
    required this.engineer,
    required this.statusLabel,
    required this.runtime,
    required this.currentAssignment,
  });

  final PublicDemoEngineerSales engineer;
  final String statusLabel;
  final PublicDemoEngineerRuntime? runtime;
  final PublicDemoAssignment? currentAssignment;

  /// Opens the sheet and returns the same `Future<bool?>` shape the #117
  /// `showDialog<bool>` call used to: `true` on explicit confirm, `false` on
  /// Back, `null` on barrier dismiss.
  static Future<bool?> show(
    BuildContext context, {
    required PublicDemoEngineerSales engineer,
    required String statusLabel,
    required PublicDemoEngineerRuntime? runtime,
    required PublicDemoAssignment? currentAssignment,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PublicDemoSkillSheetSheet(
        engineer: engineer,
        statusLabel: statusLabel,
        runtime: runtime,
        currentAssignment: currentAssignment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = PublicDemoSkillSheetDisplayFactory.create(
      engineer: engineer,
      statusLabel: statusLabel,
      runtime: runtime,
      currentAssignment: currentAssignment,
    );

    // Bounded rather than full-screen, so the sheet reads as a document the
    // player scrolls within, and the CTA row below stays reachable without
    // ever being pushed off-screen by section content
    // (SKILLSHEET-UX-2A "CTAが画面外へ消えて操作不能にならない").
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Container(
      key: Key('public-demo-skill-sheet-${engineer.id}'),
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
              child: PublicDemoSkillSheetBody(data: data),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: Key('public-demo-skill-sheet-cancel-${engineer.id}'),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('戻る'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: Key(
                        'public-demo-skill-sheet-confirm-${engineer.id}',
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('内容を確認'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
