import '../../domain/models/career_history_entry.dart';
import '../../domain/models/sales_profile.dart' show EmployeeAbility, Industry;
import '../../game/public_demo/public_demo_assignment.dart';
import '../../game/public_demo/public_demo_engineer_runtime.dart';
import '../../game/public_demo/public_demo_interview.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../widgets/labels.dart';

/// SKILLSHEET-UX-2A Phase A: a read-only display projection of the
/// SkillSheet sheet's content.
///
/// This is presentation-only. It introduces no new domain field and
/// computes no new gameplay value — every field here is read verbatim from
/// an authoritative Public Demo source the screen already holds
/// ([PublicDemoEngineerSales], [PublicDemoEngineerRuntime],
/// [PublicDemoAssignment]) and nothing produced here is ever written back
/// into [PublicDemoAggregate]. A parameter the current Public Demo model has
/// no authoritative source for (e.g. certifications, desired role) is
/// simply not shown, rather than invented.
class PublicDemoSkillSheetDisplayData {
  const PublicDemoSkillSheetDisplayData({
    required this.engineerId,
    required this.name,
    required this.primaryLanguageLabel,
    required this.statusLabel,
    required this.summaryHeading,
    required this.summaryText,
    required this.summaryChips,
    required this.interviewProfile,
    required this.abilityChips,
    required this.techSkillChips,
    required this.experienceComparisons,
    required this.industryExperienceChips,
    required this.careerHistory,
    required this.currentAssignment,
  });

  final String engineerId;
  final String name;
  final String? primaryLanguageLabel;
  final String statusLabel;

  /// Preserves the #117 heading/content pairing verbatim: the
  /// '経歴・スキル要約' heading paired with [PublicDemoEngineerSales.summary].
  final String summaryHeading;
  final String summaryText;

  /// Quick-glance chips for the summary band, shown once near the top.
  /// Deliberately different wording from the interview-profile labels below
  /// so no label string in the sheet is duplicated (the #117 widget test
  /// asserts each of those labels appears exactly once).
  final List<String> summaryChips;

  final PublicDemoInterviewProfile interviewProfile;
  final List<String> abilityChips;
  final List<PublicDemoSkillSheetTechSkillItem> techSkillChips;
  final List<PublicDemoSkillSheetExperienceComparison> experienceComparisons;
  final List<String> industryExperienceChips;
  final List<CareerHistoryEntry> careerHistory;
  final PublicDemoSkillSheetAssignmentDisplay? currentAssignment;
}

class PublicDemoSkillSheetTechSkillItem {
  const PublicDemoSkillSheetTechSkillItem({
    required this.label,
    required this.level,
  });

  final String label;
  final int level;
}

/// A single "実経験 vs SkillSheet記載" row (SKILLSHEET-UX-2A "Actual facts
/// vs sales-facing representation"). [actualMonths] and [displayedMonths]
/// are read verbatim from the same authoritative `LanguageSkill` and are
/// never merged into a single value — they intentionally differ in meaning
/// (ground-truth vs what the résumé/SkillSheet shows).
class PublicDemoSkillSheetExperienceComparison {
  const PublicDemoSkillSheetExperienceComparison({
    required this.languageLabel,
    required this.actualMonths,
    required this.displayedMonths,
  });

  final String languageLabel;
  final int actualMonths;
  final int displayedMonths;
}

class PublicDemoSkillSheetAssignmentDisplay {
  const PublicDemoSkillSheetAssignmentDisplay({
    required this.projectName,
    required this.deliveryPressure,
    required this.budgetHealth,
    required this.humanity,
    required this.nextOrderStatusLabel,
  });

  final String projectName;
  final int deliveryPressure;
  final int budgetHealth;
  final int humanity;

  /// Null when there is nothing decided yet worth surfacing
  /// ([PublicDemoNextOrderStatus.undecided]).
  final String? nextOrderStatusLabel;
}

const Map<Industry, String> _industryLabels = {
  Industry.finance: '金融',
  Industry.manufacturing: '製造',
  Industry.logistics: '物流',
  Industry.publicSector: '公共',
  Industry.telecom: '通信',
  Industry.ecommerce: 'EC',
  Industry.healthcare: '医療',
  Industry.other: 'その他',
};

const Map<EmployeeAbility, String> _abilityLabels = {
  EmployeeAbility.interviewExpert: '面談巧者',
  EmployeeAbility.fieldSales: '現場営業向き',
  EmployeeAbility.fastLearner: '成長が早い',
  EmployeeAbility.toughUnderPressure: 'プレッシャーに強い',
  EmployeeAbility.leaderType: 'リーダー気質',
  EmployeeAbility.clientFriendly: '顧客受けが良い',
  EmployeeAbility.interviewPoor: '面談がやや苦手',
  EmployeeAbility.commuteSensitive: '通勤条件に敏感',
};

const Map<String, String> _techSkillDomainLabels = {
  'database': 'DB',
  'network': 'Network',
  'infrastructure': 'Infra',
  'frontend': 'Frontend',
  'backend': 'Backend',
  'leader': 'Leader',
  'manager': 'Manager',
};

class PublicDemoSkillSheetDisplayFactory {
  const PublicDemoSkillSheetDisplayFactory._();

  /// Assembles [PublicDemoSkillSheetDisplayData] from the same authoritative
  /// objects the caller (`_openSkillSheetReview` in
  /// public_demo_01_placeholder_screen.dart) already holds. [runtime] and
  /// [currentAssignment] are nullable on purpose: a null runtime (should
  /// never happen post-EG-1, but is not assumed) and "not currently
  /// assigned" (the normal case for a SkillSheet still under review) both
  /// resolve to an explicit empty state rather than a crash or a fabricated
  /// value.
  static PublicDemoSkillSheetDisplayData create({
    required PublicDemoEngineerSales engineer,
    required String statusLabel,
    required PublicDemoEngineerRuntime? runtime,
    required PublicDemoAssignment? currentAssignment,
  }) {
    final techSkills = runtime?.techSkills;
    final techSkillChips = <PublicDemoSkillSheetTechSkillItem>[
      if (techSkills != null)
        for (final entry in <String, int>{
          'database': techSkills.database,
          'network': techSkills.network,
          'infrastructure': techSkills.infrastructure,
          'frontend': techSkills.frontend,
          'backend': techSkills.backend,
          'leader': techSkills.leader,
          'manager': techSkills.manager,
        }.entries)
          if (entry.value > 0)
            PublicDemoSkillSheetTechSkillItem(
              label: _techSkillDomainLabels[entry.key] ?? entry.key,
              level: entry.value,
            ),
    ];

    // SKILLSHEET-UX-2A P2 fix: only a confirmed language may be shown as
    // this employee's experience — a `languageSkills` entry can exist purely
    // to seed/track capability (see
    // [PublicDemoEngineerRuntime.confirmedLanguages]) without being
    // confirmed, real, language-specific experience data.
    final experienceComparisons = <PublicDemoSkillSheetExperienceComparison>[
      if (runtime != null)
        for (final skill in runtime.languageSkills.values)
          if (runtime.confirmedLanguages.contains(skill.language))
            PublicDemoSkillSheetExperienceComparison(
              languageLabel:
                  languageLabels[skill.language] ?? skill.language.name,
              actualMonths: skill.actualExperienceMonths,
              displayedMonths: skill.displayedExperienceMonths,
            ),
    ];

    final industryChips = <String>[
      if (runtime != null)
        for (final entry in runtime.industryExperience.entries)
          if (entry.value > 0)
            '${_industryLabels[entry.key] ?? entry.key.name} '
                '${formatExperience(entry.value)}',
    ];

    final abilityChips = <String>[
      if (runtime != null)
        for (final ability in runtime.abilities)
          _abilityLabels[ability] ?? ability.name,
    ];

    // Same rule as above: the header/summary chip must not claim a
    // language identity the runtime hasn't confirmed.
    final primaryLanguageLabel =
        (runtime == null ||
            !runtime.confirmedLanguages.contains(runtime.primaryLanguage))
        ? null
        : (languageLabels[runtime.primaryLanguage] ??
              runtime.primaryLanguage.name);

    final primaryExperienceYears = experienceComparisons.isEmpty
        ? null
        : formatExperience(experienceComparisons.first.displayedMonths);

    return PublicDemoSkillSheetDisplayData(
      engineerId: engineer.id,
      name: engineer.name,
      primaryLanguageLabel: primaryLanguageLabel,
      statusLabel: statusLabel,
      summaryHeading: '経歴・スキル要約',
      summaryText: engineer.summary,
      summaryChips: [
        if (primaryLanguageLabel != null) primaryLanguageLabel,
        if (primaryExperienceYears != null) '経験 $primaryExperienceYears',
        statusLabel,
      ],
      interviewProfile: engineer.interviewProfile,
      abilityChips: abilityChips,
      techSkillChips: techSkillChips,
      experienceComparisons: experienceComparisons,
      industryExperienceChips: industryChips,
      careerHistory: runtime?.careerHistory ?? const [],
      currentAssignment: currentAssignment == null
          ? null
          : PublicDemoSkillSheetAssignmentDisplay(
              projectName: currentAssignment.projectName,
              deliveryPressure: currentAssignment.deliveryPressure,
              budgetHealth: currentAssignment.budgetHealth,
              humanity: currentAssignment.humanity,
              nextOrderStatusLabel: _nextOrderStatusLabel(
                currentAssignment.nextOrderStatus,
              ),
            ),
    );
  }

  static String? _nextOrderStatusLabel(PublicDemoNextOrderStatus status) =>
      switch (status) {
        PublicDemoNextOrderStatus.undecided => null,
        PublicDemoNextOrderStatus.offered => '翌月オファーあり（回答待ち）',
        PublicDemoNextOrderStatus.accepted => '翌月も継続予定',
        PublicDemoNextOrderStatus.notOffered => '翌月オファーなし',
      };
}
