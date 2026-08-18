import '../../domain/domain.dart';
import '../../game/game.dart';

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

const Map<SelectionStep, String> selectionStepLabels = {
  SelectionStep.documentScreening: '書類選考',
  SelectionStep.upperCompanyInterview: '上位会社面談',
  SelectionStep.technicalInterview: '技術面談',
  SelectionStep.clientInterview: '客先面談',
  SelectionStep.finalInterview: '最終面談',
  // Playable 0.4C.3 §44-46: "参画オファー" everywhere in the UI, never a
  // bare "Offer" — the internal enum value name stays unchanged.
  SelectionStep.offer: '参画オファー',
};

const Map<SelectionStep, String> selectionStepShortLabels = {
  SelectionStep.documentScreening: '書類',
  SelectionStep.upperCompanyInterview: '上位',
  SelectionStep.technicalInterview: '技術',
  SelectionStep.clientInterview: '客先',
  SelectionStep.finalInterview: '最終',
  SelectionStep.offer: 'オファー',
};

const Map<ClientSpecialty, String> clientSpecialtyLabels = {
  ClientSpecialty.javaBusiness: 'Java業務系',
  ClientSpecialty.webFrontend: 'Web/フロントエンド',
  ClientSpecialty.infrastructure: 'インフラ',
  ClientSpecialty.general: '総合',
};

/// 商流 (Phase 3B-1 §3.3 "案件を選ぶ"): how many layers of subcontracting sit
/// between the player's company and the end client. Shallower (元請 →
/// 3次請け) generally means better conditions — [ProjectComparisonScreen]
/// surfaces this as a short caveat next to the raw value, never re-labels
/// the enum itself.
const Map<CommercialFlow, String> commercialFlowLabels = {
  CommercialFlow.prime: '元請',
  CommercialFlow.firstTier: '1次請け',
  CommercialFlow.secondTier: '2次請け',
  CommercialFlow.thirdTier: '3次請け',
};

/// Looks up a sample client's display name by id, falling back to the id
/// itself if somehow unknown.
String clientNameById(String clientId) {
  for (final c in sampleClients) {
    if (c.id == clientId) return c.name;
  }
  return clientId;
}

/// Same lookup as [clientNameById], but returns `null` instead of echoing
/// the raw id when [clientId] doesn't resolve to a real client — so prose
/// that embeds the name (e.g. "○○から面談依頼が届きました") can render a
/// sensible fallback sentence instead of silently interpolating an empty
/// string or an internal id (Playable Phase 3A UX review, P1-2: a project
/// that had already left `GameState.openProjects` by the time a dialog
/// rendered previously produced "から面談依頼が届きました" with the company
/// name missing entirely). Callers should always pass a durable field like
/// `InterviewOffer.clientId`/`AccountsReceivable.clientId` — never a value
/// re-derived from a project lookup that might have already gone stale.
String? clientDisplayNameOrNull(String clientId) {
  for (final c in sampleClients) {
    if (c.id == clientId) return c.name;
  }
  return null;
}

/// 支払サイト (Playable 0.3A §14): a client's payment term in days, falling
/// back to 30 if somehow unknown.
int paymentTermDaysById(String clientId) {
  for (final c in sampleClients) {
    if (c.id == clientId) return c.paymentTermDays;
  }
  return 30;
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

const Map<TechDomain, String> techDomainLabels = {
  TechDomain.database: 'DB',
  TechDomain.network: 'Network',
  TechDomain.infrastructure: 'Infra',
  TechDomain.frontend: 'Frontend',
  TechDomain.backend: 'Backend',
  TechDomain.leader: 'Leader',
  TechDomain.manager: 'Manager',
};

/// Localizes a single [FitDetailItem]'s label for the Fit breakdown display
/// (§9), e.g. `Java`, `Backend`, `経験年数`, `コミュ力`, `日本語`.
String fitDetailLabel(FitDetailItem item) => switch (item.dimension) {
  FitDimension.language =>
    item.language != null
        ? (languageLabels[item.language] ?? item.language!.name)
        : '言語',
  FitDimension.techDomain =>
    item.techDomain != null
        ? (techDomainLabels[item.techDomain] ?? '技術')
        : '技術',
  FitDimension.experience => '経験年数',
  FitDimension.communication => 'コミュ力',
  FitDimension.japanese => '日本語',
};

/// Formats a total-IT-experience month count as e.g. `3年2ヶ月`.
String formatExperience(int months) {
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return '$rest ヶ月';
  if (rest == 0) return '$years 年';
  return '$years 年 $rest ヶ月';
}
