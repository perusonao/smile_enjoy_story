// Shared builders for hand-crafted domain/game objects in engine tests.
//
// Keeps individual test files focused on behavior instead of the large
// number of required constructor fields on `Applicant`/`Project`.

import 'package:smile_enjoy_story/domain/domain.dart';

Applicant buildApplicant({
  String id = 'test-applicant',
  ApplicantType type = ApplicantType.midLevelEngineer,
  String name = 'テスト太郎',
  int age = 30,
  int totalItExperienceMonths = 36,
  int desiredMonthlySalary = 400000,
  WorkStyle desiredWorkStyle = WorkStyle.hybrid,
  int japaneseLevel = 3,
  int englishLevel = 2,
  Map<ProgrammingLanguage, LanguageSkill>? languageSkills,
  ProgrammingLanguage mainLanguage = ProgrammingLanguage.java,
  List<ProgrammingLanguage> subLanguages = const [],
  TechSkillLevels techSkills = const TechSkillLevels.zero(),
  PersonalityTraits personality = const PersonalityTraits(
    looks: 3,
    cleanliness: 3,
    communication: 3,
    alcoholTolerance: 3,
    seriousness: 3,
    dishonesty: 3,
  ),
  HiddenParameters hidden = const HiddenParameters(
    growthPotential: 3,
    stressTolerance: 3,
    retention: 3,
    projectInterviewSkill: 3,
    turnoverIntent: 30,
  ),
  int mainLanguageActualSkill = 60,
}) {
  return Applicant(
    id: id,
    type: type,
    name: name,
    age: age,
    nationality: '日本',
    education: Education.university,
    major: Major.informationTechnology,
    totalItExperienceMonths: totalItExperienceMonths,
    jobChangeCount: 1,
    desiredMonthlySalary: desiredMonthlySalary,
    desiredWorkStyle: desiredWorkStyle,
    japaneseLevel: japaneseLevel,
    englishLevel: englishLevel,
    qualifications: const [],
    languageSkills:
        languageSkills ??
        {
          mainLanguage: LanguageSkill(
            language: mainLanguage,
            displayedExperienceMonths: totalItExperienceMonths,
            actualExperienceMonths: totalItExperienceMonths,
            actualSkill: mainLanguageActualSkill,
          ),
        },
    mainLanguage: mainLanguage,
    subLanguages: subLanguages,
    techSkills: techSkills,
    personality: personality,
    hidden: hidden,
  );
}

Engineer buildEngineer({
  String id = 'test-engineer',
  Applicant? profile,
  int salary = 400000,
  int employmentWeek = 1,
  EngineerStatus status = EngineerStatus.waiting,
}) {
  final p = profile ?? buildApplicant();
  return Engineer(
    id: id,
    sourceApplicantId: p.id,
    profile: p,
    salary: salary,
    employmentWeek: employmentWeek,
    status: status,
  );
}

Project buildProject({
  String id = 'test-project',
  String clientId = 'client-test',
  String title = 'テスト案件',
  ProjectType type = ProjectType.webBackend,
  ProjectRank rank = ProjectRank.middle,
  int monthlyRate = 600000,
  int durationWeeks = 12,
  int applicationDeadlineWeek = 10,
  List<ProgrammingLanguage> requiredLanguages = const [ProgrammingLanguage.java],
  int requiredDatabase = 0,
  int requiredNetwork = 0,
  int requiredInfrastructure = 0,
  int requiredFrontend = 0,
  int requiredBackend = 3,
  int requiredLeader = 0,
  int requiredManager = 0,
  int requiredJapaneseLevel = 3,
  RemotePolicy remotePolicy = RemotePolicy.hybrid,
  int interviewCount = 1,
  int difficulty = 3,
  ResidenceArea location = ResidenceArea.tokyo,
}) {
  return Project(
    id: id,
    clientId: clientId,
    title: title,
    type: type,
    rank: rank,
    monthlyRate: monthlyRate,
    durationWeeks: durationWeeks,
    applicationDeadlineWeek: applicationDeadlineWeek,
    requiredLanguages: requiredLanguages,
    requiredDatabase: requiredDatabase,
    requiredNetwork: requiredNetwork,
    requiredInfrastructure: requiredInfrastructure,
    requiredFrontend: requiredFrontend,
    requiredBackend: requiredBackend,
    requiredLeader: requiredLeader,
    requiredManager: requiredManager,
    requiredJapaneseLevel: requiredJapaneseLevel,
    remotePolicy: remotePolicy,
    interviewCount: interviewCount,
    difficulty: difficulty,
    location: location,
  );
}
