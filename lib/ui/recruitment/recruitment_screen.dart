import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import 'applicant_detail_screen.dart';

class RecruitmentScreen extends StatelessWidget {
  const RecruitmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;
    final applicants = [...state.applicants]
      ..sort((a, b) => b.appearedWeek.compareTo(a.appearedWeek));

    return Scaffold(
      appBar: AppBar(title: const Text('採用')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Text('求人媒体', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final type in RecruitmentMediaType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MediaCard(type: type),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('応募者一覧', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              Text('(${applicants.length}名)', style: const TextStyle(color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 8),
          if (applicants.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: const Text('現在応募者はいません。求人媒体に掲載してみましょう。'),
            )
          else
            for (final entry in applicants)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ApplicantCard(entry: entry),
              ),
        ],
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.type});

  final RecruitmentMediaType type;

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;
    final config = recruitmentMediaConfigs[type]!;
    final active = state.listings
        .where((l) => l.type == type && l.isActiveOn(state.week))
        .toList();
    final isActive = active.isNotEmpty;
    final remainingWeeks = isActive
        ? active.first.postedWeek + active.first.durationWeeks - state.week
        : 0;
    final canAfford = state.company.cash >= config.cost;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(config.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text(
                config.cost == 0 ? '無料' : formatYen(config.cost),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: config.cost == 0 ? Colors.green.shade700 : SesTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(config.description, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            '掲載${config.durationWeeks}週間 / 週${config.weeklyApplicants.min}-${config.weeklyApplicants.max}名応募',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: isActive
                ? OutlinedButton(
                    onPressed: null,
                    child: Text('掲載中 (残り$remainingWeeks週)'),
                  )
                : FilledButton(
                    onPressed: canAfford
                        ? () => controller.postRecruitmentMedia(type)
                        : null,
                    child: Text(canAfford ? '掲載する' : '資金不足'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({required this.entry});

  final ApplicantEntry entry;

  @override
  Widget build(BuildContext context) {
    final applicant = entry.applicant;
    final state = context.game.state;
    final interviewed = state.interviewedApplicantIds.contains(
      applicant.id,
    );
    final assessment = RecommendationEngine.candidateAssessment(applicant, state);
    final recommendation = switch (assessment.level) {
      AssessmentLevel.attention => '◎ 注目',
      AssessmentLevel.candidate => '○ 候補',
      AssessmentLevel.cautious => '△ 慎重',
      AssessmentLevel.lowPriority => '× 見送り候補',
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ApplicantDetailScreen(applicantId: applicant.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    applicant.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (interviewed)
                  const _Tag(text: '面接済み', color: Colors.blue)
                else
                  const _Tag(text: '未面接', color: Colors.grey),
              ],
            ),
            const SizedBox(height: 4),
            Text(recommendation, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            if (assessment.good.isNotEmpty)
              Text('理由: ${assessment.good.join('・')}', style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 2),
            if (assessment.cautions.isNotEmpty)
              Text('注意: ${assessment.cautions.join('・')}', style: TextStyle(fontSize: 12, color: Colors.orange.shade800), maxLines: 2),
            Text(
              applicantTypeLabels[applicant.type] ?? applicant.type.name,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Bit('${applicant.age}歳'),
                _Bit(formatExperience(applicant.totalItExperienceMonths)),
                _Bit(languageLabels[applicant.mainLanguage] ?? applicant.mainLanguage.name),
                _Bit(formatYen(applicant.desiredMonthlySalary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bit extends StatelessWidget {
  const _Bit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 12.5));
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
