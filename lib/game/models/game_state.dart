import '../../domain/domain.dart';
import 'applicant_entry.dart';
import 'game_log_entry.dart';
import 'game_stats.dart';
import 'game_status.dart';
import 'project_entry.dart';
import 'project_proposal.dart';
import 'recruitment_media.dart';

const int totalGameWeeks = 26;
const int startingCash = 5000000;
const int startingCredit = 20;
const int weeklyFixedCost = 50000;

/// Number of recent [GameLogEntry] rows kept around (older ones are dropped
/// so save data doesn't grow without bound over 26 weeks).
const int maxLogEntries = 60;

/// The full, serializable state of one playthrough.
///
/// This is the single source of truth the UI renders from; every mutation
/// goes through `GameEngine`, which always returns a brand-new [GameState]
/// rather than mutating in place.
class GameState {
  final int seed;
  final Company company;
  final List<Engineer> engineers;
  final List<ApplicantEntry> applicants;
  final Set<String> interviewedApplicantIds;
  final List<ProjectEntry> openProjects;
  final List<RecruitmentListing> listings;
  final List<ProjectProposal> proposals;
  final List<ActiveAssignment> activeAssignments;
  final List<PendingHire> pendingHires;
  final List<GameLogEntry> events;
  final GameStats stats;
  final GameStatus status;

  /// Consecutive weeks each currently-waiting engineer has been waiting
  /// (Playable 0.2 §17-18). Keyed by engineer id; an engineer who isn't
  /// waiting doesn't appear here.
  final Map<String, int> waitingStreak;

  /// Ad-hoc spending (recruitment media) incurred since the last weekly
  /// tick; folded into the next tick's expense total and then reset.
  final int pendingMiscExpense;

  final int lastWeekRevenue;
  final int lastWeekExpense;

  /// Expense sub-totals for [lastWeekExpense], so Home can show a
  /// breakdown (§7). Fixed cost isn't stored separately since it's always
  /// the [weeklyFixedCost] constant.
  final int lastWeekSalary;
  final int lastWeekRecruitmentCost;

  final int? bankruptWeek;
  final String? bankruptCause;

  /// Monotonic counter used to mint deterministic, collision-free ids for
  /// listings/proposals/pending-hires created during play.
  final int idCounter;

  const GameState({
    required this.seed,
    required this.company,
    required this.engineers,
    required this.applicants,
    required this.interviewedApplicantIds,
    required this.openProjects,
    required this.listings,
    required this.proposals,
    required this.activeAssignments,
    required this.pendingHires,
    required this.events,
    required this.stats,
    required this.status,
    this.waitingStreak = const {},
    this.pendingMiscExpense = 0,
    this.lastWeekRevenue = 0,
    this.lastWeekExpense = 0,
    this.lastWeekSalary = 0,
    this.lastWeekRecruitmentCost = 0,
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

  /// 今週収支 (§7): positive when last week's revenue beat its expenses.
  int get lastWeekProfit => lastWeekRevenue - lastWeekExpense;

  Engineer engineerById(String id) => engineers.firstWhere((e) => e.id == id);

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

  bool isProjectOpenForProposal(String projectId) {
    final hasActiveProposal = proposals.any(
      (p) => p.project.id == projectId && p.stage == ProposalStage.proposed,
    );
    final isPassedAwaitingAssignment = proposals.any(
      (p) =>
          p.project.id == projectId && p.stage == ProposalStage.interviewPassed,
    );
    final isAssigned = activeAssignments.any((a) => a.project.id == projectId);
    return !hasActiveProposal && !isPassedAwaitingAssignment && !isAssigned;
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
    int? seed,
    Company? company,
    List<Engineer>? engineers,
    List<ApplicantEntry>? applicants,
    Set<String>? interviewedApplicantIds,
    List<ProjectEntry>? openProjects,
    List<RecruitmentListing>? listings,
    List<ProjectProposal>? proposals,
    List<ActiveAssignment>? activeAssignments,
    List<PendingHire>? pendingHires,
    List<GameLogEntry>? events,
    GameStats? stats,
    GameStatus? status,
    Map<String, int>? waitingStreak,
    int? pendingMiscExpense,
    int? lastWeekRevenue,
    int? lastWeekExpense,
    int? lastWeekSalary,
    int? lastWeekRecruitmentCost,
    int? bankruptWeek,
    String? bankruptCause,
    int? idCounter,
  }) {
    return GameState(
      seed: seed ?? this.seed,
      company: company ?? this.company,
      engineers: engineers ?? this.engineers,
      applicants: applicants ?? this.applicants,
      interviewedApplicantIds:
          interviewedApplicantIds ?? this.interviewedApplicantIds,
      openProjects: openProjects ?? this.openProjects,
      listings: listings ?? this.listings,
      proposals: proposals ?? this.proposals,
      activeAssignments: activeAssignments ?? this.activeAssignments,
      pendingHires: pendingHires ?? this.pendingHires,
      events: events ?? this.events,
      stats: stats ?? this.stats,
      status: status ?? this.status,
      waitingStreak: waitingStreak ?? this.waitingStreak,
      pendingMiscExpense: pendingMiscExpense ?? this.pendingMiscExpense,
      lastWeekRevenue: lastWeekRevenue ?? this.lastWeekRevenue,
      lastWeekExpense: lastWeekExpense ?? this.lastWeekExpense,
      lastWeekSalary: lastWeekSalary ?? this.lastWeekSalary,
      lastWeekRecruitmentCost:
          lastWeekRecruitmentCost ?? this.lastWeekRecruitmentCost,
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
    'seed': seed,
    'company': company.toJson(),
    'engineers': engineers.map((e) => e.toJson()).toList(),
    'applicants': applicants.map((e) => e.toJson()).toList(),
    'interviewedApplicantIds': interviewedApplicantIds.toList(),
    'openProjects': openProjects.map((e) => e.toJson()).toList(),
    'listings': listings.map((e) => e.toJson()).toList(),
    'proposals': proposals.map((e) => e.toJson()).toList(),
    'activeAssignments': activeAssignments.map((e) => e.toJson()).toList(),
    'pendingHires': pendingHires.map((e) => e.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'stats': stats.toJson(),
    'status': status.jsonValue,
    'waitingStreak': waitingStreak,
    'pendingMiscExpense': pendingMiscExpense,
    'lastWeekRevenue': lastWeekRevenue,
    'lastWeekExpense': lastWeekExpense,
    'lastWeekSalary': lastWeekSalary,
    'lastWeekRecruitmentCost': lastWeekRecruitmentCost,
    'bankruptWeek': bankruptWeek,
    'bankruptCause': bankruptCause,
    'idCounter': idCounter,
  };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    seed: json['seed'] as int,
    company: Company.fromJson(json['company'] as Map<String, dynamic>),
    engineers: (json['engineers'] as List)
        .map((e) => Engineer.fromJson(e as Map<String, dynamic>))
        .toList(),
    applicants: (json['applicants'] as List)
        .map((e) => ApplicantEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    interviewedApplicantIds: (json['interviewedApplicantIds'] as List)
        .cast<String>()
        .toSet(),
    openProjects: (json['openProjects'] as List)
        .map((e) => ProjectEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    listings: (json['listings'] as List)
        .map((e) => RecruitmentListing.fromJson(e as Map<String, dynamic>))
        .toList(),
    proposals: (json['proposals'] as List)
        .map((e) => ProjectProposal.fromJson(e as Map<String, dynamic>))
        .toList(),
    activeAssignments: (json['activeAssignments'] as List)
        .map((e) => ActiveAssignment.fromJson(e as Map<String, dynamic>))
        .toList(),
    pendingHires: (json['pendingHires'] as List)
        .map((e) => PendingHire.fromJson(e as Map<String, dynamic>))
        .toList(),
    events: (json['events'] as List)
        .map((e) => GameLogEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    stats: GameStats.fromJson(json['stats'] as Map<String, dynamic>),
    status: GameStatus.fromJson(json['status'] as String),
    waitingStreak: (json['waitingStreak'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as int),
        ) ??
        const {},
    pendingMiscExpense: json['pendingMiscExpense'] as int? ?? 0,
    lastWeekRevenue: json['lastWeekRevenue'] as int? ?? 0,
    lastWeekExpense: json['lastWeekExpense'] as int? ?? 0,
    lastWeekSalary: json['lastWeekSalary'] as int? ?? 0,
    lastWeekRecruitmentCost: json['lastWeekRecruitmentCost'] as int? ?? 0,
    bankruptWeek: json['bankruptWeek'] as int?,
    bankruptCause: json['bankruptCause'] as String?,
    idCounter: json['idCounter'] as int? ?? 0,
  );
}
