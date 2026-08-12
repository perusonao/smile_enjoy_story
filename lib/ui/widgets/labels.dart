import '../../domain/domain.dart';

/// Japanese display labels for domain enums, centralized so every screen
/// renders the same wording.
const Map<ProgrammingLanguage, String> languageLabels = {
  ProgrammingLanguage.java: 'Java',
  ProgrammingLanguage.csharp: 'C#',
  ProgrammingLanguage.php: 'PHP',
  ProgrammingLanguage.python: 'Python',
  ProgrammingLanguage.javascript: 'JavaScript',
  ProgrammingLanguage.typescript: 'TypeScript',
};

const Map<ApplicantType, String> applicantTypeLabels = {
  ApplicantType.juniorProgrammer: '若手プログラマー',
  ApplicantType.midLevelEngineer: '中堅エンジニア',
  ApplicantType.seniorEngineer: 'シニアエンジニア',
  ApplicantType.frontendSpecialist: 'フロントエンド専門',
  ApplicantType.infrastructureSpecialist: 'インフラ専門',
  ApplicantType.plCandidate: 'PL候補',
};

const Map<Education, String> educationLabels = {
  Education.highSchool: '高校卒',
  Education.vocationalSchool: '専門学校卒',
  Education.technicalCollege: '高専卒',
  Education.university: '大学卒',
  Education.graduateSchool: '大学院卒',
};

const Map<Major, String> majorLabels = {
  Major.informationTechnology: '情報系',
  Major.scienceEngineering: '理工系',
  Major.humanities: '人文系',
  Major.other: 'その他',
};

const Map<WorkStyle, String> workStyleLabels = {
  WorkStyle.onsite: '常駐希望',
  WorkStyle.hybrid: 'ハイブリッド希望',
  WorkStyle.fullRemote: 'フルリモート希望',
};

const Map<RemotePolicy, String> remotePolicyLabels = {
  RemotePolicy.onsite: '常駐',
  RemotePolicy.hybrid: 'ハイブリッド',
  RemotePolicy.remote: 'フルリモート',
};

const Map<ProjectType, String> projectTypeLabels = {
  ProjectType.javaBusiness: 'Java業務システム',
  ProjectType.webBackend: 'Webバックエンド',
  ProjectType.frontend: 'フロントエンド',
  ProjectType.infrastructure: 'インフラ',
  ProjectType.testSupport: 'テスト支援',
  ProjectType.pl: 'PL/リーダー',
};

const Map<ProjectRank, String> projectRankLabels = {
  ProjectRank.entry: 'エントリー',
  ProjectRank.junior: 'ジュニア',
  ProjectRank.middle: 'ミドル',
  ProjectRank.senior: 'シニア',
  ProjectRank.lead: 'リード',
};

const Map<ClientSpecialty, String> clientSpecialtyLabels = {
  ClientSpecialty.javaBusiness: 'Java業務系',
  ClientSpecialty.webFrontend: 'Web/フロントエンド',
  ClientSpecialty.infrastructure: 'インフラ',
  ClientSpecialty.general: '総合',
};

/// Looks up a sample client's display name by id, falling back to the id
/// itself if somehow unknown.
String clientNameById(String clientId) {
  for (final c in sampleClients) {
    if (c.id == clientId) return c.name;
  }
  return clientId;
}

/// The single highest-required tech-domain skill on a project, e.g.
/// `Backend Lv.3`, used as the "主要求スキル" summary in list views.
String topRequiredSkillLabel(Project project) {
  final entries = <String, int>{
    'DB': project.requiredDatabase,
    'Network': project.requiredNetwork,
    'Infra': project.requiredInfrastructure,
    'Frontend': project.requiredFrontend,
    'Backend': project.requiredBackend,
    'Leader': project.requiredLeader,
    'Manager': project.requiredManager,
  };
  final best = entries.entries.reduce((a, b) => a.value >= b.value ? a : b);
  if (best.value <= 0) return '特になし';
  return '${best.key} Lv.${best.value}';
}

/// Formats a total-IT-experience month count as e.g. `3年2ヶ月`.
String formatExperience(int months) {
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return '$rest ヶ月';
  if (rest == 0) return '$years 年';
  return '$years 年 $rest ヶ月';
}
