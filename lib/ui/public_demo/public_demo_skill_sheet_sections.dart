import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_interview.dart';
import '../widgets/labels.dart';
import '../widgets/skill_chip.dart';
import 'public_demo_skill_sheet_display_projection.dart';

/// SKILLSHEET-UX-2A Phase A: presentation widgets for the redesigned
/// SkillSheet sheet ([PublicDemoSkillSheetSheet] in
/// public_demo_skill_sheet_sheet.dart). Pure, stateless, read-only —
/// everything here renders [PublicDemoSkillSheetDisplayData] fields
/// verbatim and never calls back into game state.
///
/// Kept in its own file rather than folded into the parent Public Demo
/// screen so that screen's diff for SKILLSHEET-UX-2A stays limited to the
/// single call site that builds this sheet (Issue #118 develops on a
/// sibling branch against the same file).

/// The full sheet body: header, summary band, then the five accordion
/// sections. A plain [Column] — the caller wraps this in the scroll view.
class PublicDemoSkillSheetBody extends StatelessWidget {
  const PublicDemoSkillSheetBody({super.key, required this.data});

  final PublicDemoSkillSheetDisplayData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.name}\n営業用SkillSheet',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 6),
        const Text(
          '取引先へ提示する営業用プロフィールです。内容を確認してから営業開始へ進みます。',
          style: TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        _SkillSheetHeaderFacts(data: data),
        const SizedBox(height: 14),
        if (data.summaryChips.isNotEmpty) ...[
          _SummaryBand(chips: data.summaryChips),
          const SizedBox(height: 14),
        ],
        Text(
          data.summaryHeading,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(data.summaryText),
        const SizedBox(height: 8),
        _Section(
          title: '基本プロフィール',
          child: _BasicProfileSection(data: data),
        ),
        _Section(
          title: '技術スキル',
          child: _TechSkillSection(data: data),
        ),
        _Section(
          title: '経験',
          child: _ExperienceSection(data: data),
        ),
        _Section(
          title: '案件/参画情報',
          child: _AssignmentSection(data: data),
        ),
        _Section(
          title: '営業・面談プロフィール',
          initiallyExpanded: true,
          child: _InterviewProfileSection(profile: data.interviewProfile),
        ),
      ],
    );
  }
}

/// The always-visible top-of-sheet facts: primary language and current
/// status, next to the employee name already shown above.
class _SkillSheetHeaderFacts extends StatelessWidget {
  const _SkillSheetHeaderFacts({required this.data});

  final PublicDemoSkillSheetDisplayData data;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (data.primaryLanguageLabel != null)
          SkillChip(data.primaryLanguageLabel!, icon: Icons.code),
        SkillChip(
          data.statusLabel,
          icon: Icons.timelapse,
          color: Colors.teal,
        ),
      ],
    );
  }
}

/// Quick-glance chips a sales rep can read without opening any section.
class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.chips});

  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SkillChipRow(
        chips: [for (final chip in chips) SkillChip(chip)],
      ),
    );
  }
}

/// A collapsible detail section. [maintainState] is forced to `true` so a
/// collapsed section's content stays mounted (and findable by widget tests)
/// rather than being removed from the tree — the #117 flow test relies on
/// this for the 営業・面談プロフィール section it did not have to expand.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}

/// A single label/value line, e.g. "案件スキル適合" / "78". Kept as two
/// separate [Text] widgets — matching the #117 dialog's original shape —
/// so each is independently findable by label and by value.
class SkillSheetMetricRow extends StatelessWidget {
  const SkillSheetMetricRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A muted one-line note for a section with nothing authoritative to show
/// yet. Never a fabricated value — only ever this fixed "not available"
/// text.
class SkillSheetEmptyState extends StatelessWidget {
  const SkillSheetEmptyState(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(fontSize: 12.5, color: Colors.black54),
    );
  }
}

/// 基本プロフィール: strengths (abilities) — the one "profile" fact the
/// current Public Demo runtime owns beyond what the header already shows.
class _BasicProfileSection extends StatelessWidget {
  const _BasicProfileSection({required this.data});

  final PublicDemoSkillSheetDisplayData data;

  @override
  Widget build(BuildContext context) {
    if (data.abilityChips.isEmpty) {
      return const SkillSheetEmptyState('特筆すべき特性の記録はまだありません。');
    }
    return SkillChipRow(
      chips: [
        for (final chip in data.abilityChips)
          SkillChip(chip, icon: Icons.star_outline, color: Colors.indigo),
      ],
    );
  }
}

/// 技術スキル: chip-formatted technical skill levels, per the issue's
/// request for readable chips over a shrunk desktop table.
class _TechSkillSection extends StatelessWidget {
  const _TechSkillSection({required this.data});

  final PublicDemoSkillSheetDisplayData data;

  @override
  Widget build(BuildContext context) {
    if (data.techSkillChips.isEmpty) {
      return const SkillSheetEmptyState('技術スキルの詳細情報はまだありません。');
    }
    return SkillChipRow(
      chips: [
        for (final item in data.techSkillChips)
          SkillChip('${item.label} Lv.${item.level}'),
      ],
    );
  }
}

/// 経験: the actual-vs-displayed experience comparison (see
/// [PublicDemoSkillSheetExperienceComparison]), plus industry experience and
/// project/career history when available.
class _ExperienceSection extends StatelessWidget {
  const _ExperienceSection({required this.data});

  final PublicDemoSkillSheetDisplayData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.experienceComparisons.isEmpty)
          const SkillSheetEmptyState('経験年数の記録を確認できません。')
        else
          for (final comparison in data.experienceComparisons)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${comparison.languageLabel}：実経験 '
                '${formatExperience(comparison.actualMonths)} → '
                'SkillSheet記載 '
                '${formatExperience(comparison.displayedMonths)}',
                softWrap: true,
              ),
            ),
        const SizedBox(height: 8),
        Text('業界経験', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        if (data.industryExperienceChips.isEmpty)
          const SkillSheetEmptyState('業界経験の記録はまだありません。')
        else
          SkillChipRow(
            chips: [
              for (final chip in data.industryExperienceChips) SkillChip(chip),
            ],
          ),
        const SizedBox(height: 8),
        Text('案件経歴', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        if (data.careerHistory.isEmpty)
          const SkillSheetEmptyState('案件経歴の記録はまだありません。')
        else
          for (final entry in data.careerHistory)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.projectName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    softWrap: true,
                  ),
                  if (entry.role.isNotEmpty)
                    Text(entry.role, softWrap: true),
                  Text(
                    formatExperience(entry.experienceMonths),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (entry.summary.isNotEmpty)
                    Text(entry.summary, softWrap: true),
                ],
              ),
            ),
      ],
    );
  }
}

/// 案件/参画情報: the current assignment when this engineer already has
/// one, otherwise an explicit empty state — the normal case for a SkillSheet
/// still under sales review, before any assignment exists.
class _AssignmentSection extends StatelessWidget {
  const _AssignmentSection({required this.data});

  final PublicDemoSkillSheetDisplayData data;

  @override
  Widget build(BuildContext context) {
    final assignment = data.currentAssignment;
    if (assignment == null) {
      return const SkillSheetEmptyState('現在参画中の案件はありません（営業準備中です）。');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(assignment.projectName, softWrap: true),
        const SizedBox(height: 4),
        SkillSheetMetricRow('納期プレッシャー', '${assignment.deliveryPressure}'),
        SkillSheetMetricRow('予算健全性', '${assignment.budgetHealth}'),
        SkillSheetMetricRow('現場との相性', '${assignment.humanity}'),
        if (assignment.nextOrderStatusLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              assignment.nextOrderStatusLabel!,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
      ],
    );
  }
}

/// 営業・面談プロフィール: preserved verbatim from the #117 dialog — same
/// heading text, same four rows, same label/value shape — so the existing
/// widget test (test/ui/public_demo/public_demo_01_skill_sheet_flow_test
/// .dart) keeps passing unmodified.
class _InterviewProfileSection extends StatelessWidget {
  const _InterviewProfileSection({required this.profile});

  final PublicDemoInterviewProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillSheetMetricRow('案件スキル適合', '${profile.skillFit}'),
        SkillSheetMetricRow('ヒューマンスキル', '${profile.humanity}'),
        SkillSheetMetricRow('モチベーション', '${profile.morale}'),
        SkillSheetMetricRow('取引先からの信頼', '${profile.clientTrust}'),
      ],
    );
  }
}
