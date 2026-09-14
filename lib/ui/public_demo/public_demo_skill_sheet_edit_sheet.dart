import 'package:flutter/material.dart';

import '../widgets/labels.dart';

/// SES First Fun Quarter Mission Phase 3 (SkillSheet Editing): the one
/// screen that lets the player adjust a hired engineer's SkillSheet-facing
/// "表示経験" (what a client sees) before starting sales.
///
/// Deliberately narrow: the only value this sheet can produce is a new
/// displayed-experience month count for the engineer's own primary
/// language, in whole-year steps — mirroring the main game's own existing
/// SkillSheet editor (`engineer_detail_screen.dart`'s `_editSkillSheet`,
/// same `実際 X / 記載 Y` framing, same year-stepper shape) rather than
/// inventing a second UI convention for the same concept. It never reads or
/// writes [PublicDemoEngineerRuntime.actualCapability],
/// `languageSkills[...].actualExperienceMonths`/`actualSkill`,
/// [PublicDemoEngineerRuntime.techSkills], or anything Fit/Matching reads —
/// this widget only ever holds the four primitives its constructor takes
/// and the in-progress draft year count, nothing else.
///
/// Copy is deliberately neutral, never an encouragement to inflate: it
/// states what changes (the sales-facing figure) and what does not (real
/// experience/capability), the same disclosure the main game's own editor
/// already gives its player before any risk mechanic even existed there.
class PublicDemoSkillSheetEditSheet extends StatefulWidget {
  const PublicDemoSkillSheetEditSheet({
    super.key,
    required this.engineerId,
    required this.engineerName,
    required this.languageLabel,
    required this.actualMonths,
    required this.initialDisplayedMonths,
    required this.maxDisplayedMonths,
  });

  final String engineerId;
  final String engineerName;
  final String languageLabel;

  /// Ground-truth [LanguageSkill.actualExperienceMonths] — shown for
  /// comparison, never itself editable here.
  final int actualMonths;
  final int initialDisplayedMonths;

  /// Inclusive upper bound for the saved value — always
  /// `actualMonths + PublicDemoEngineerRuntime
  /// .maxDisplayedExperienceInflationMonths` at the one production call
  /// site, but taken as a plain int so this widget needs no import on that
  /// domain constant.
  final int maxDisplayedMonths;

  /// Opens the sheet. Resolves to the confirmed new displayed-months value
  /// on an explicit save, or `null` on Back/barrier-dismiss — the caller
  /// (`_openSkillSheetEdit` in public_demo_01_placeholder_screen.dart) only
  /// ever commits [PublicDemoAggregate.confirmSkillSheetEdit] for a non-null
  /// result, so cancelling never marks
  /// [PublicDemoEngineerSales.salesProfileEditConfirmed].
  static Future<int?> show(
    BuildContext context, {
    required String engineerId,
    required String engineerName,
    required String languageLabel,
    required int actualMonths,
    required int initialDisplayedMonths,
    required int maxDisplayedMonths,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PublicDemoSkillSheetEditSheet(
        engineerId: engineerId,
        engineerName: engineerName,
        languageLabel: languageLabel,
        actualMonths: actualMonths,
        initialDisplayedMonths: initialDisplayedMonths,
        maxDisplayedMonths: maxDisplayedMonths,
      ),
    );
  }

  @override
  State<PublicDemoSkillSheetEditSheet> createState() =>
      _PublicDemoSkillSheetEditSheetState();
}

class _PublicDemoSkillSheetEditSheetState
    extends State<PublicDemoSkillSheetEditSheet> {
  late int _years;

  int get _maxYears => widget.maxDisplayedMonths ~/ 12;

  @override
  void initState() {
    super.initState();
    // Whole-year granularity only, same simplification the main game's own
    // editor already makes (`v * 12` on save) — never a claim that the
    // pre-edit value was itself a whole number of years.
    _years = (widget.initialDisplayedMonths ~/ 12).clamp(0, _maxYears);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Container(
      key: Key('public-demo-skill-sheet-edit-${widget.engineerId}'),
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
                    '${widget.engineerName}\n営業用プロフィールを編集',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '取引先へ提示する表示経験（営業用プロフィール）を調整します。'
                    '実際の実務経験や実力が変わるわけではありません。',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '実務経験：${formatExperience(widget.actualMonths)}',
                    key: Key(
                      'public-demo-skill-sheet-edit-actual-${widget.engineerId}',
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.languageLabel}の営業用表示',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        key: Key(
                          'public-demo-skill-sheet-edit-decrement-'
                          '${widget.engineerId}',
                        ),
                        onPressed: _years > 0
                            ? () => setState(() => _years--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$_years 年 0 ヶ月',
                        key: Key(
                          'public-demo-skill-sheet-edit-value-'
                          '${widget.engineerId}',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        key: Key(
                          'public-demo-skill-sheet-edit-increment-'
                          '${widget.engineerId}',
                        ),
                        onPressed: _years < _maxYears
                            ? () => setState(() => _years++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '調整できる範囲：0 〜 $_maxYears 年',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
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
                      key: Key(
                        'public-demo-skill-sheet-edit-cancel-'
                        '${widget.engineerId}',
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: Key(
                        'public-demo-skill-sheet-edit-save-'
                        '${widget.engineerId}',
                      ),
                      onPressed: () => Navigator.pop(context, _years * 12),
                      child: const Text('この内容で保存'),
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
