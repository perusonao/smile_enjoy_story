import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import 'recruitment_interview_screen.dart';

class ApplicantDetailScreen extends StatelessWidget {
  const ApplicantDetailScreen({super.key, required this.applicantId});

  final String applicantId;

  Future<void> _onInterviewPressed(BuildContext context, Applicant applicant) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecruitmentInterviewScreen(applicantId: applicantId)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;
    ApplicantEntry? entry;
    for (final e in state.applicants) {
      if (e.applicant.id == applicantId) {
        entry = e;
        break;
      }
    }

    if (entry == null) {
      // Already decided (hired/rejected) from another action — just go back.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final applicant = entry.applicant;
    final interviewed = state.recruitmentInterviews.any((s) => s.applicantId == applicantId && s.completed);
    final interviewStarted = state.recruitmentInterviews.any((s) => s.applicantId == applicantId && !s.completed);

    return Scaffold(
      appBar: AppBar(title: Text(applicant.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _SectionCard(
            title: '経歴書',
            children: [
              _Row('タイプ', applicantTypeLabels[applicant.type] ?? applicant.type.name),
              _Row('年齢', '${applicant.age}歳'),
              _Row('国籍', applicant.nationality),
              _Row('学歴', educationLabels[applicant.education] ?? applicant.education.name),
              _Row('IT経験', formatExperience(applicant.totalItExperienceMonths)),
              _Row('転職回数', '${applicant.jobChangeCount}回'),
              _Row(
                '主言語',
                '${languageLabels[applicant.mainLanguage]} '
                    '(${formatExperience(applicant.skillFor(applicant.mainLanguage).displayedExperienceMonths)})',
              ),
              if (applicant.subLanguages.isNotEmpty)
                _Row(
                  '副言語',
                  applicant.subLanguages
                      .map((l) => languageLabels[l] ?? l.name)
                      .join(' / '),
                ),
              _Row('DB', 'Lv.${applicant.techSkills.database}'),
              _Row('Network', 'Lv.${applicant.techSkills.network}'),
              _Row('Infrastructure', 'Lv.${applicant.techSkills.infrastructure}'),
              _Row('Frontend', 'Lv.${applicant.techSkills.frontend}'),
              _Row('Backend', 'Lv.${applicant.techSkills.backend}'),
              _Row('Leader', 'Lv.${applicant.techSkills.leader}'),
              _Row('Manager', 'Lv.${applicant.techSkills.manager}'),
              _Row('希望給与', formatYen(applicant.desiredMonthlySalary)),
              _Row('希望勤務形態', workStyleLabels[applicant.desiredWorkStyle] ?? ''),
              _Row('日本語', 'Lv.${applicant.japaneseLevel}'),
              _Row('英語', 'Lv.${applicant.englishLevel}'),
              if (applicant.qualifications.isNotEmpty)
                _Row('資格', applicant.qualifications.join(' / ')),
            ],
          ),
          const SizedBox(height: 14),
          if (!interviewed)
            _LockedPersonalityCard(
              onInterview: () => _onInterviewPressed(context, applicant),
              started: interviewStarted,
            )
          else
            _SectionCard(
              title: '面接済み',
              children: const [_Row('判断', '会話と観察をもとに採否を決定しました')],
            ),
        ],
      ),
    );
  }
}

class _LockedPersonalityCard extends StatelessWidget {
  const _LockedPersonalityCard({required this.onInterview, this.started = false});

  final VoidCallback onInterview;
  final bool started;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 32, color: Colors.black38),
          const SizedBox(height: 8),
          const Text(
            '人物パラメータは面接するまで確認できません。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onInterview,
              icon: const Icon(Icons.forum_outlined),
              label: Text(started ? '面接を再開する' : '面接する'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: SesTheme.primaryBlue),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
