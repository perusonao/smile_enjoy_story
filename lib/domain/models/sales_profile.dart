import 'programming_language.dart';
import 'tech_skill_levels.dart';

enum Industry { finance, manufacturing, logistics, publicSector, telecom, ecommerce, healthcare, other }
enum ResidenceArea { tokyo, kanagawa, chiba, saitama, remote }
enum EmployeeAbility { interviewExpert, fieldSales, fastLearner, toughUnderPressure, leaderType, clientFriendly, interviewPoor, commuteSensitive }
enum SalesStatus { notSelling, selling, interviewing, offered, assigned }

class SkillSheet {
  static const int maxExperienceInflationMonths = 36;
  static const int maxSkillInflation = 2;

  final String employeeId;
  final Map<ProgrammingLanguage, int> displayedLanguageExperience;
  final int displayedDatabase;
  final int displayedNetwork;
  final int displayedInfrastructure;
  final int displayedFrontend;
  final int displayedBackend;
  final int displayedLeader;
  final int displayedManager;
  final Map<Industry, int> displayedIndustryExperience;
  final List<String> displayedRoles;
  final int updatedWeek;

  const SkillSheet({required this.employeeId, required this.displayedLanguageExperience, required this.displayedDatabase, required this.displayedNetwork, required this.displayedInfrastructure, required this.displayedFrontend, required this.displayedBackend, required this.displayedLeader, required this.displayedManager, this.displayedIndustryExperience = const {}, this.displayedRoles = const [], required this.updatedWeek});

  factory SkillSheet.fromActual({required String employeeId, required Map<ProgrammingLanguage, int> languageMonths, required TechSkillLevels skills, Map<Industry, int> industryExperience = const {}, required int week}) => SkillSheet(employeeId: employeeId, displayedLanguageExperience: languageMonths, displayedDatabase: skills.database, displayedNetwork: skills.network, displayedInfrastructure: skills.infrastructure, displayedFrontend: skills.frontend, displayedBackend: skills.backend, displayedLeader: skills.leader, displayedManager: skills.manager, displayedIndustryExperience: industryExperience, displayedRoles: const [], updatedWeek: week);

  SkillSheet copyWith({Map<ProgrammingLanguage, int>? displayedLanguageExperience, int? displayedDatabase, int? displayedNetwork, int? displayedInfrastructure, int? displayedFrontend, int? displayedBackend, int? displayedLeader, int? displayedManager, Map<Industry, int>? displayedIndustryExperience, List<String>? displayedRoles, int? updatedWeek}) => SkillSheet(employeeId: employeeId, displayedLanguageExperience: displayedLanguageExperience ?? this.displayedLanguageExperience, displayedDatabase: displayedDatabase ?? this.displayedDatabase, displayedNetwork: displayedNetwork ?? this.displayedNetwork, displayedInfrastructure: displayedInfrastructure ?? this.displayedInfrastructure, displayedFrontend: displayedFrontend ?? this.displayedFrontend, displayedBackend: displayedBackend ?? this.displayedBackend, displayedLeader: displayedLeader ?? this.displayedLeader, displayedManager: displayedManager ?? this.displayedManager, displayedIndustryExperience: displayedIndustryExperience ?? this.displayedIndustryExperience, displayedRoles: displayedRoles ?? this.displayedRoles, updatedWeek: updatedWeek ?? this.updatedWeek);

  Map<String, dynamic> toJson() => {'employeeId': employeeId, 'displayedLanguageExperience': displayedLanguageExperience.map((k,v) => MapEntry(k.name,v)), 'displayedDatabase': displayedDatabase, 'displayedNetwork': displayedNetwork, 'displayedInfrastructure': displayedInfrastructure, 'displayedFrontend': displayedFrontend, 'displayedBackend': displayedBackend, 'displayedLeader': displayedLeader, 'displayedManager': displayedManager, 'displayedIndustryExperience': displayedIndustryExperience.map((k,v) => MapEntry(k.name,v)), 'displayedRoles': displayedRoles, 'updatedWeek': updatedWeek};
  factory SkillSheet.fromJson(Map<String,dynamic> json) => SkillSheet(employeeId: json['employeeId'] as String, displayedLanguageExperience: (json['displayedLanguageExperience'] as Map<String,dynamic>).map((k,v) => MapEntry(ProgrammingLanguage.fromJson(k), v as int)), displayedDatabase: json['displayedDatabase'] as int, displayedNetwork: json['displayedNetwork'] as int, displayedInfrastructure: json['displayedInfrastructure'] as int, displayedFrontend: json['displayedFrontend'] as int, displayedBackend: json['displayedBackend'] as int, displayedLeader: json['displayedLeader'] as int, displayedManager: json['displayedManager'] as int, displayedIndustryExperience: (json['displayedIndustryExperience'] as Map<String,dynamic>? ?? {}).map((k,v) => MapEntry(Industry.values.byName(k), v as int)), displayedRoles: (json['displayedRoles'] as List? ?? const []).cast<String>(), updatedWeek: json['updatedWeek'] as int);
}
