import '../../domain/domain.dart';
import 'accounts_receivable.dart';
import 'applicant_entry.dart';
import 'game_log_entry.dart';
import 'game_stats.dart';
import 'game_status.dart';
import 'monthly_closing.dart';
import 'office.dart';
import 'project_entry.dart';
import 'project_proposal.dart';
import 'recruitment_media.dart';
import 'recruitment_interview.dart';
import 'sales_models.dart';

/// Bumped whenever a save-incompatible change is made to [GameState]'s
/// shape (Playable 0.3A §26). [SaveService] resets to a new game rather
/// than crashing when a loaded save's version doesn't match.
const int currentSchemaVersion = 5;
const int maxParallelProposalsPerEmployee = 3;
const int maxActiveCompanyProposals = 6;

/// 1 turn = 1 week, 4 weeks = 1 month, 48 weeks = 1 fiscal year (§3).
const int totalGameWeeks = 48;

const int startingCash = 3500000;
const int startingCredit = 20;

/// 家賃とは別枠の月額固定費 (§8).
const int otherMonthlyFixedCost = 100000;

/// Number of recent [GameLogEntry] rows kept around (older ones are dropped
/// so save data doesn't grow without bound over a full year).
const int maxLogEntries = 60;

/// Number of recent [MonthlyClosing] records kept around.
const int maxMonthlyClosings = 24;

/// The full, serializable state of one playthrough.
///
/// This is the single source of truth the UI renders from; every mutation
/// goes through `GameEngine`, which always returns a brand-new [GameState]
/// rather than mutating in place.
class GameState {
  final int schemaVersion;
  final int seed;
  final Company company;
  final OfficeType officeType;
  final List<Engineer> engineers;
  final List<ApplicantEntry> applicants;
  final Set<String> interviewedApplicantIds;
  final List<RecruitmentInterviewSession> recruitmentInterviews;
  final List<ProjectEntry> openProjects;
  final List<RecruitmentListing> listings;
  final List<ProjectProposal> proposals;
  final List<Offer> offers;
  final List<SkillSheet> skillSheets;
  final List<ClientRelation> clientRelations;
  final List<InterviewOffer> interviewOffers;
  final List<ActiveAssignment> activeAssignments;
  final List<PendingHire> pendingHires;
  final List<AccountsReceivable> accountsReceivable;
  final List<MonthlyClosing> monthlyClosings;
  final List<GameLogEntry> events;
  final GameStats stats;
  final GameStatus status;

  /// Consecutive weeks each currently-waiting engineer has been waiting
  /// (Playable 0.2 §17-18). Keyed by engineer id; an engineer who isn't
  /// waiting doesn't appear here.
  final Map<String, int> waitingStreak;

  /// Every engineer who has held an [ActiveAssignment] at any point during
  /// the current (not-yet-closed) month, keyed by engineer id — the
  /// month-end accounting run reads this to accrue revenue/AR without
  /// needing per-day proration (Playable 0.3A §9, §13).
  final Map<String, ActiveAssignment> monthAccrualSnapshot;

  /// Ad-hoc spending (recruitment media) incurred since the last monthly
  /// close; folded into that month's closing report and then reset.
  final int pendingMiscExpense;

  final int? bankruptWeek;
  final String? bankruptCause;

  /// Monotonic counter used to mint deterministic, collision-free ids for
  /// listings/proposals/pending-hires/AR records created during play.
  final int idCounter;

  const GameState({
    this.schemaVersion = currentSchemaVersion,
    required this.seed,
    required this.company,
    this.officeType = OfficeType.smallOffice,
    required this.engineers,
    required this.applicants,
    required this.interviewedApplicantIds,
    this.recruitmentInterviews = const [],
    required this.openProjects,
    required this.listings,
    required this.proposals,
    this.offers = const [],
    this.skillSheets = const [],
    this.clientRelations = const [],
    this.interviewOffers = const [],
    required this.activeAssignments,
    required this.pendingHires,
    this.accountsReceivable = const [],
    this.monthlyClosings = const [],
    required this.events,
    required this.stats,
    required this.status,
    this.waitingStreak = const {},
    this.monthAccrualSnapshot = const {},
    this.pendingMiscExpense = 0,
    this.bankruptWeek,
    this.bankruptCause,
    this.idCounter = 0,
  });

  int get week => company.currentWeek;

  /// Returns `(newState, mintedId)`: bumps [idCounter] and formats a fresh
  /// id as `prefix-<counter>`.
  (GameState, String) mintId(String prefix) {
    final id = '$prefix-$idCounter';
    return (copyWith(idCounter: idCounter + 1), id);
  }

  int get displayWeek => week > totalGameWeeks ? totalGameWeeks : week;

  /// The most recently closed month's accounting breakdown, or `null`
  /// before Week 4's close (§20).
  MonthlyClosing? get latestClosing =>
      monthlyClosings.isEmpty ? null : monthlyClosings.last;

  Engineer engineerById(String id) => engineers.firstWhere((e) => e.id == id);
  SkillSheet skillSheetFor(String id) => skillSheets.firstWhere((s) => s.employeeId == id);
  ClientRelation relationFor(String id) => clientRelations.firstWhere((r) => r.clientId == id);
  int get unlockedClientCount => clientRelations.where((r)=>r.unlocked).length;

  ActiveAssignment? assignmentForEngineer(String engineerId) {
    for (final a in activeAssignments) {
      if (a.engineerId == engineerId) return a;
    }
    return null;
  }

  ProjectProposal? proposalForEngineer(String engineerId) {
    for (final p in proposals) {
      if (p.engineerId == engineerId) return p;
    }
    return null;
  }

  List<ProjectProposal> applicationsForEngineer(String engineerId) =>
      proposals.where((proposal) => proposal.engineerId == engineerId).toList();

  int activeProposalCountFor(String engineerId) => proposals
      .where(
        (proposal) =>
            proposal.engineerId == engineerId &&
            (proposal.status == ApplicationStatus.active ||
                proposal.status == ApplicationStatus.offered),
      )
      .length;

  int get activeCompanyProposalCount => proposals
      .where(
        (proposal) =>
            proposal.status == ApplicationStatus.active ||
            proposal.status == ApplicationStatus.offered,
      )
      .length;

  bool canPropose(String engineerId, String projectId) =>
      activeProposalCountFor(engineerId) < maxParallelProposalsPerEmployee &&
      activeCompanyProposalCount < maxActiveCompanyProposals &&
      !proposals.any(
        (proposal) =>
            proposal.engineerId == engineerId &&
            proposal.project.id == projectId &&
            (proposal.status == ApplicationStatus.active ||
                proposal.status == ApplicationStatus.offered),
      ) &&
      !activeAssignments.any(
        (assignment) => assignment.engineerId == engineerId,
      );

  bool isProjectOpenForProposal(String projectId) {
    final hasLegacyProposal = proposals.any(
      (p) =>
          p.project.id == projectId &&
          p.project.interviewCount != p.project.selectionFlow.interviewCount &&
          p.status == ApplicationStatus.active,
    );
    final isAssigned = activeAssignments.any((a) => a.project.id == projectId);
    return !hasLegacyProposal && !isAssigned;
  }

  /// How many consecutive weeks [engineerId] has been waiting, or 0 if
  /// they aren't currently waiting.
  int waitingStreakFor(String engineerId) => waitingStreak[engineerId] ?? 0;

  int get waitingEngineerCount =>
      engineers.where((e) => e.status == EngineerStatus.waiting).length;

  int get assignedEngineerCount =>
      engineers.where((e) => e.status == EngineerStatus.assigned).length;

  int get utilizationPercent => engineers.isEmpty
      ? 0
      : ((assignedEngineerCount / engineers.length) * 100).round();

  GameState copyWith({
    int? schemaVersion,
    int? seed,
    Company? company,
    OfficeType? officeType,
    List<Engineer>? engineers,
    List<ApplicantEntry>? applicants,
    Set<String>? interviewedApplicantIds,
    List<RecruitmentInterviewSession>? recruitmentInterviews,
    List<ProjectEntry>? openProjects,
    List<RecruitmentListing>? listings,
    List<ProjectProposal>? proposals,
    List<Offer>? offers,
    List<SkillSheet>? skillSheets,
    List<ClientRelation>? clientRelations,
    List<InterviewOffer>? interviewOffers,
    List<ActiveAssignment>? activeAssignments,
    List<PendingHire>? pendingHires,
    List<AccountsReceivable>? accountsReceivable,
    List<MonthlyClosing>? monthlyClosings,
    List<GameLogEntry>? events,
    GameStats? stats,
    GameStatus? status,
    Map<String, int>? waitingStreak,
    Map<String, ActiveAssignment>? monthAccrualSnapshot,
    int? pendingMiscExpense,
    int? bankruptWeek,
    String? bankruptCause,
    int? idCounter,
  }) {
    return GameState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      seed: seed ?? this.seed,
      company: company ?? this.company,
      officeType: officeType ?? this.officeType,
      engineers: engineers ?? this.engineers,
      applicants: applicants ?? this.applicants,
      interviewedApplicantIds:
          interviewedApplicantIds ?? this.interviewedApplicantIds,
      recruitmentInterviews: recruitmentInterviews ?? this.recruitmentInterviews,
      openProjects: openProjects ?? this.openProjects,
      listings: listings ?? this.listings,
      proposals: proposals ?? this.proposals,
      offers: offers ?? this.offers,
      skillSheets: skillSheets ?? this.skillSheets,
      clientRelations: clientRelations ?? this.clientRelations,
      interviewOffers: interviewOffers ?? this.interviewOffers,
      activeAssignments: activeAssignments ?? this.activeAssignments,
      pendingHires: pendingHires ?? this.pendingHires,
      accountsReceivable: accountsReceivable ?? this.accountsReceivable,
      monthlyClosings: monthlyClosings ?? this.monthlyClosings,
      events: events ?? this.events,
      stats: stats ?? this.stats,
      status: status ?? this.status,
      waitingStreak: waitingStreak ?? this.waitingStreak,
      monthAccrualSnapshot: monthAccrualSnapshot ?? this.monthAccrualSnapshot,
      pendingMiscExpense: pendingMiscExpense ?? this.pendingMiscExpense,
      bankruptWeek: bankruptWeek ?? this.bankruptWeek,
      bankruptCause: bankruptCause ?? this.bankruptCause,
      idCounter: idCounter ?? this.idCounter,
    );
  }

  /// Appends a log line, trimming the oldest entries beyond [maxLogEntries].
  GameState withLog(String message, {GameLogCategory? category}) {
    final updated = [
      ...events,
      GameLogEntry(week: week, message: message, category: category),
    ];
    final trimmed = updated.length > maxLogEntries
        ? updated.sublist(updated.length - maxLogEntries)
        : updated;
    return copyWith(events: trimmed);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'seed': seed,
    'company': company.toJson(),
    'officeType': officeType.jsonValue,
    'engineers': engineers.map((e) => e.toJson()).toList(),
    'applicants': applicants.map((e) => e.toJson()).toList(),
    'interviewedApplicantIds': interviewedApplicantIds.toList(),
    'recruitmentInterviews': recruitmentInterviews.map((e) => e.toJson()).toList(),
    'openProjects': openProjects.map((e) => e.toJson()).toList(),
    'listings': listings.map((e) => e.toJson()).toList(),
    'proposals': proposals.map((e) => e.toJson()).toList(),
    'offers': offers.map((e) => e.toJson()).toList(),
    'skillSheets': skillSheets.map((e)=>e.toJson()).toList(),
    'clientRelations': clientRelations.map((e)=>e.toJson()).toList(),
    'interviewOffers': interviewOffers.map((e)=>e.toJson()).toList(),
    'activeAssignments': activeAssignments.map((e) => e.toJson()).toList(),
    'pendingHires': pendingHires.map((e) => e.toJson()).toList(),
    'accountsReceivable': accountsReceivable.map((e) => e.toJson()).toList(),
    'monthlyClosings': monthlyClosings.map((e) => e.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'stats': stats.toJson(),
    'status': status.jsonValue,
    'waitingStreak': waitingStreak,
    'monthAccrualSnapshot': monthAccrualSnapshot.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'pendingMiscExpense': pendingMiscExpense,
    'bankruptWeek': bankruptWeek,
    'bankruptCause': bankruptCause,
    'idCounter': idCounter,
  };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    schemaVersion: json['schemaVersion'] as int? ?? 1,
    seed: json['seed'] as int,
    company: Company.fromJson(json['company'] as Map<String, dynamic>),
    officeType: json['officeType'] == null
        ? OfficeType.smallOffice
        : OfficeType.fromJson(json['officeType'] as String),
    engineers: (json['engineers'] as List)
        .map((e) => Engineer.fromJson(e as Map<String, dynamic>))
        .toList(),
    applicants: (json['applicants'] as List)
        .map((e) => ApplicantEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    interviewedApplicantIds: (json['interviewedApplicantIds'] as List)
        .cast<String>()
        .toSet(),
    recruitmentInterviews: (json['recruitmentInterviews'] as List? ?? const [])
        .map((e) => RecruitmentInterviewSession.fromJson(e as Map<String, dynamic>)).toList(),
    openProjects: (json['openProjects'] as List)
        .map((e) => ProjectEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    listings: (json['listings'] as List)
        .map((e) => RecruitmentListing.fromJson(e as Map<String, dynamic>))
        .toList(),
    proposals: (json['proposals'] as List)
        .map((e) => ProjectProposal.fromJson(e as Map<String, dynamic>))
        .toList(),
    offers: (json['offers'] as List? ?? const [])
        .map((e) => Offer.fromJson(e as Map<String, dynamic>))
        .toList(),
    skillSheets: (json['skillSheets'] as List? ?? const []).map((e)=>SkillSheet.fromJson(e as Map<String,dynamic>)).toList(),
    clientRelations: (json['clientRelations'] as List? ?? const []).map((e)=>ClientRelation.fromJson(e as Map<String,dynamic>)).toList(),
    interviewOffers: (json['interviewOffers'] as List? ?? const []).map((e)=>InterviewOffer.fromJson(e as Map<String,dynamic>)).toList(),
    activeAssignments: (json['activeAssignments'] as List)
        .map((e) => ActiveAssignment.fromJson(e as Map<String, dynamic>))
        .toList(),
    pendingHires: (json['pendingHires'] as List)
        .map((e) => PendingHire.fromJson(e as Map<String, dynamic>))
        .toList(),
    accountsReceivable: (json['accountsReceivable'] as List? ?? const [])
        .map((e) => AccountsReceivable.fromJson(e as Map<String, dynamic>))
        .toList(),
    monthlyClosings: (json['monthlyClosings'] as List? ?? const [])
        .map((e) => MonthlyClosing.fromJson(e as Map<String, dynamic>))
        .toList(),
    events: (json['events'] as List)
        .map((e) => GameLogEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    stats: GameStats.fromJson(json['stats'] as Map<String, dynamic>),
    status: GameStatus.fromJson(json['status'] as String),
    waitingStreak:
        (json['waitingStreak'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as int),
        ) ??
        const {},
    monthAccrualSnapshot:
        (json['monthAccrualSnapshot'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            ActiveAssignment.fromJson(value as Map<String, dynamic>),
          ),
        ) ??
        const {},
    pendingMiscExpense: json['pendingMiscExpense'] as int? ?? 0,
    bankruptWeek: json['bankruptWeek'] as int?,
    bankruptCause: json['bankruptCause'] as String?,
    idCounter: json['idCounter'] as int? ?? 0,
  );
}
