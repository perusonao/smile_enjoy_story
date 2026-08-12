import '../../domain/domain.dart';
import '../models/models.dart';
import 'project_interview_engine.dart';
import 'recruitment_engine.dart';
import 'rng.dart';

/// Orchestrates the whole Playable 0.1 simulation: new-game setup, the
/// weekly turn, and the player actions that can happen between turns
/// (interview, hire/reject, propose, post recruitment media).
///
/// Every method is a pure function: `GameState -> GameState`. Nothing here
/// touches Flutter, `DateTime.now()`, or any other non-deterministic input
/// except [newGame]'s market seed (only when the caller doesn't supply one).
class GameEngine {
  const GameEngine._();

  /// Fixed seed for the two founding engineers/projects, so every new game
  /// starts from the same roster regardless of the chosen market [seed]
  /// (§22).
  static const int founderApplicantSeed = 20260101;
  static const int founderProjectSeed = 20260102;

  // ---------------------------------------------------------------------
  // New game
  // ---------------------------------------------------------------------

  static GameState newGame({int? seed, String companyName = 'あなたのSES会社'}) {
    final marketSeed = seed ?? (DateTime.now().millisecondsSinceEpoch & 0x7fffffff);

    final founderApplicants = ApplicantGenerator(
      seed: founderApplicantSeed,
    ).generate(2);
    final founderProjects = ProjectGenerator(
      seed: founderProjectSeed,
      clients: sampleClients,
    ).generate(2, baseWeek: 1);

    final engineers = <Engineer>[];
    final assignments = <ActiveAssignment>[];
    for (var i = 0; i < 2; i++) {
      final applicant = founderApplicants[i];
      final project = founderProjects[i];
      final engineer = Engineer(
        id: 'engineer-founder-$i',
        sourceApplicantId: applicant.id,
        profile: applicant,
        salary: applicant.desiredMonthlySalary,
        employmentWeek: 1,
        status: EngineerStatus.assigned,
      );
      engineers.add(engineer);
      assignments.add(
        ActiveAssignment(
          engineerId: engineer.id,
          project: project,
          remainingWeeks: project.durationWeeks,
          assignedWeek: 1,
        ),
      );
    }

    final initialClientIds = sampleClients.take(2).map((c) => c.id).toList();
    final company = Company(
      id: 'company-player',
      name: companyName,
      cash: startingCash,
      credit: startingCredit,
      currentWeek: 1,
      engineerIds: engineers.map((e) => e.id).toList(),
      clientIds: initialClientIds,
    );

    final founderNames = engineers.map((e) => e.profile.name).join('、');
    final initialLog = [
      GameLogEntry(week: 1, message: 'S.E.S. 経営を開始しました。(seed: $marketSeed)'),
      GameLogEntry(week: 1, message: '創業メンバー $founderNames が既存案件に参画済みです。'),
    ];

    return GameState(
      seed: marketSeed,
      company: company,
      engineers: engineers,
      applicants: const [],
      interviewedApplicantIds: const {},
      openProjects: const [],
      listings: const [],
      proposals: const [],
      activeAssignments: assignments,
      pendingHires: const [],
      events: initialLog,
      stats: const GameStats.zero(),
      status: GameStatus.playing,
    );
  }

  // ---------------------------------------------------------------------
  // Player actions (between turns)
  // ---------------------------------------------------------------------

  static GameState interviewApplicant(GameState state, String applicantId) {
    if (state.interviewedApplicantIds.contains(applicantId)) return state;
    return state.copyWith(
      interviewedApplicantIds: {
        ...state.interviewedApplicantIds,
        applicantId,
      },
    );
  }

  static GameState rejectApplicant(GameState state, String applicantId) {
    final index = state.applicants.indexWhere(
      (e) => e.applicant.id == applicantId,
    );
    if (index == -1) return state;
    final entry = state.applicants[index];
    final remaining = [...state.applicants]..removeAt(index);
    return state.copyWith(applicants: remaining).withLog(
      '${entry.applicant.name} を不採用としました。',
    );
  }

  /// Hire decision + offer-acceptance roll (§10-11). Requires the applicant
  /// to have been interviewed first.
  static GameState hireApplicant(GameState state, String applicantId) {
    if (!state.interviewedApplicantIds.contains(applicantId)) return state;
    final index = state.applicants.indexWhere(
      (e) => e.applicant.id == applicantId,
    );
    if (index == -1) return state;

    final applicant = state.applicants[index].applicant;
    final remainingApplicants = [...state.applicants]..removeAt(index);
    var next = state.copyWith(applicants: remainingApplicants);

    final rate = RecruitmentEngine.acceptanceRate(state.company.credit);
    final accepted = RecruitmentEngine.rollAcceptance(
      rate: rate,
      seed: state.seed,
      week: state.week,
      salt: 'hire-accept:$applicantId',
    );
    if (!accepted) {
      return next.withLog('${applicant.name} は内定を辞退しました。');
    }

    final delay = RecruitmentEngine.joinDelayWeeks(
      seed: state.seed,
      week: state.week,
      salt: 'hire-delay:$applicantId',
    );
    final joinWeek = state.week + delay;
    final (afterMint, id) = next.mintId('pending-hire');
    final pendingHire = PendingHire(
      id: id,
      applicant: applicant,
      salary: applicant.desiredMonthlySalary,
      decisionWeek: state.week,
      joinWeek: joinWeek,
    );
    return afterMint
        .copyWith(pendingHires: [...afterMint.pendingHires, pendingHire])
        .withLog('${applicant.name} が内定を承諾しました。($joinWeek 週目に入社予定)');
  }

  /// Proposes a waiting engineer for an open project (§16).
  static GameState proposeEngineer(
    GameState state,
    String engineerId,
    String projectId,
  ) {
    if (!state.isProjectOpenForProposal(projectId)) return state;
    final engIndex = state.engineers.indexWhere((e) => e.id == engineerId);
    if (engIndex == -1) return state;
    final engineer = state.engineers[engIndex];
    if (engineer.status != EngineerStatus.waiting) return state;

    ProjectEntry? entry;
    for (final e in state.openProjects) {
      if (e.project.id == projectId) {
        entry = e;
        break;
      }
    }
    if (entry == null) return state;
    if (state.week > entry.project.applicationDeadlineWeek) return state;

    final (afterMint, id) = state.mintId('proposal');
    final proposal = ProjectProposal(
      id: id,
      engineerId: engineerId,
      project: entry.project,
      proposedWeek: state.week,
      stage: ProposalStage.proposed,
    );
    final updatedEngineers = [...state.engineers];
    updatedEngineers[engIndex] = engineer.copyWith(
      status: EngineerStatus.proposed,
    );
    final stats = afterMint.stats.copyWith(
      proposalCount: afterMint.stats.proposalCount + 1,
    );
    return afterMint
        .copyWith(
          engineers: updatedEngineers,
          proposals: [...afterMint.proposals, proposal],
          stats: stats,
        )
        .withLog('${engineer.profile.name} を「${entry.project.title}」へ提案しました。');
  }

  /// Posts a recruitment listing, deducting its cost immediately (§21).
  static GameState postRecruitmentMedia(
    GameState state,
    RecruitmentMediaType type,
  ) {
    final config = recruitmentMediaConfigs[type]!;
    if (state.company.cash < config.cost) return state;
    final alreadyActive = state.listings.any(
      (l) => l.type == type && l.isActiveOn(state.week),
    );
    if (alreadyActive) return state;

    final (afterMint, id) = state.mintId('listing');
    final listing = RecruitmentListing(
      id: id,
      type: type,
      postedWeek: state.week,
      durationWeeks: config.durationWeeks,
    );
    final company = state.company.copyWith(
      cash: state.company.cash - config.cost,
    );
    return afterMint
        .copyWith(
          company: company,
          listings: [...afterMint.listings, listing],
          pendingMiscExpense: afterMint.pendingMiscExpense + config.cost,
        )
        .withLog('${config.label} に掲載しました。(-¥${config.cost})');
  }

  // ---------------------------------------------------------------------
  // Weekly turn (§19)
  // ---------------------------------------------------------------------

  static GameState advanceWeek(GameState state) {
    if (state.status != GameStatus.playing) return state;
    final newWeek = state.week + 1;
    final seed = state.seed;
    final logs = <String>[];

    var idCounter = state.idCounter;
    String mintId(String prefix) {
      final id = '$prefix-$idCounter';
      idCounter++;
      return id;
    }

    final engineersById = <String, Engineer>{
      for (final e in state.engineers) e.id: e,
    };

    // 1. 新規応募者生成 -------------------------------------------------
    final activeListings = state.listings
        .where((l) => l.isActiveOn(newWeek))
        .toList();
    final newApplicantEntries = <ApplicantEntry>[];
    for (final listing in activeListings) {
      final generated = RecruitmentEngine.generateApplicants(
        type: listing.type,
        week: newWeek,
        seed: seed,
        listingId: listing.id,
      );
      for (final a in generated) {
        newApplicantEntries.add(
          ApplicantEntry(applicant: a, appearedWeek: newWeek, source: listing.type),
        );
      }
    }
    final applicants = [...state.applicants, ...newApplicantEntries];
    if (newApplicantEntries.isNotEmpty) {
      logs.add('新しい応募者が${newApplicantEntries.length}名届きました。');
    }

    // 2. 新規案件生成 -----------------------------------------------------
    final projectCountRng = seededRandom(seed, newWeek, 'project-count');
    final projectCount = 2 + projectCountRng.nextInt(3); // 2-4 / week
    final projectGenerator = ProjectGenerator(
      seed: weekSeed(seed, newWeek, 'projects'),
      clients: sampleClients,
    );
    final newProjectEntries = projectGenerator
        .generate(projectCount, baseWeek: newWeek)
        .map((p) => ProjectEntry(project: p, postedWeek: newWeek))
        .toList();
    if (newProjectEntries.isNotEmpty) {
      logs.add('新着案件が${newProjectEntries.length}件届きました。');
    }

    // 3. 入社予定者処理 ---------------------------------------------------
    final joiningNow = state.pendingHires
        .where((h) => h.joinWeek == newWeek)
        .toList();
    final pendingHires = state.pendingHires
        .where((h) => h.joinWeek != newWeek)
        .toList();
    var hiresDelta = 0;
    for (final hire in joiningNow) {
      final id = mintId('engineer');
      final engineer = Engineer(
        id: id,
        sourceApplicantId: hire.applicant.id,
        profile: hire.applicant,
        salary: hire.salary,
        employmentWeek: newWeek,
        status: EngineerStatus.waiting,
      );
      engineersById[id] = engineer;
      hiresDelta++;
      logs.add('${hire.applicant.name} が入社しました(待機)。');
    }

    // 4/5. 提案進行・案件面談進行 -------------------------------------------
    // Failed proposals stay visible for exactly the week they resolve in
    // (so "案件面談結果" can show them), then get dropped here so the list
    // doesn't grow without bound over 26 weeks.
    final proposalsCarriedIn = state.proposals.where((p) {
      final isStaleFailure =
          p.stage == ProposalStage.interviewFailed &&
          (p.interviewWeek ?? 0) < newWeek;
      return !isStaleFailure;
    }).toList();

    final resolvedProposals = <ProjectProposal>[];
    final stillPendingProposals = <ProjectProposal>[];
    var interviewCountDelta = 0;
    var interviewSuccessDelta = 0;
    for (final proposal in proposalsCarriedIn) {
      if (proposal.stage != ProposalStage.proposed) {
        stillPendingProposals.add(proposal);
        continue;
      }
      final engineer = engineersById[proposal.engineerId];
      if (engineer == null) continue;

      final rate = ProjectInterviewEngine.successRate(engineer, proposal.project);
      final passed = ProjectInterviewEngine.roll(
        rate: rate,
        seed: seed,
        week: newWeek,
        salt: 'interview:${proposal.id}',
      );
      interviewCountDelta++;
      if (passed) interviewSuccessDelta++;

      resolvedProposals.add(
        proposal.copyWith(
          stage: passed
              ? ProposalStage.interviewPassed
              : ProposalStage.interviewFailed,
          interviewWeek: newWeek,
          interviewSuccessRate: rate,
          assignWeek: passed ? newWeek + 1 : null,
        ),
      );

      if (passed) {
        logs.add(
          '${engineer.profile.name} は「${proposal.project.title}」の案件面談に合格しました。',
        );
        // Stays non-waiting until the assignment actually starts next week.
        engineersById[engineer.id] = engineer.copyWith(
          status: EngineerStatus.interviewScheduled,
        );
      } else {
        logs.add(
          '${engineer.profile.name} は「${proposal.project.title}」の案件面談に不合格でした。',
        );
        engineersById[engineer.id] = engineer.copyWith(
          status: EngineerStatus.waiting,
        );
      }
    }

    // 6. 新規参画 ---------------------------------------------------------
    final carriedProposals = [...stillPendingProposals, ...resolvedProposals];
    final newAssignments = <ActiveAssignment>[];
    final finalizedProposalIds = <String>{};
    for (final proposal in carriedProposals) {
      if (proposal.stage == ProposalStage.interviewPassed &&
          proposal.assignWeek == newWeek) {
        final engineer = engineersById[proposal.engineerId];
        if (engineer == null) continue;
        newAssignments.add(
          ActiveAssignment(
            engineerId: proposal.engineerId,
            project: proposal.project,
            remainingWeeks: proposal.project.durationWeeks,
            assignedWeek: newWeek,
          ),
        );
        engineersById[engineer.id] = engineer.copyWith(
          status: EngineerStatus.assigned,
        );
        finalizedProposalIds.add(proposal.id);
        logs.add('${engineer.profile.name} が「${proposal.project.title}」に参画しました。');
      }
    }
    final activeProposals = carriedProposals
        .where((p) => !finalizedProposalIds.contains(p.id))
        .toList();

    // 7/8. 案件残期間減少・終了案件処理 ---------------------------------------
    final decrementedExisting = state.activeAssignments
        .map((a) => a.copyWith(remainingWeeks: a.remainingWeeks - 1))
        .toList();
    final allActiveThisWeek = [...decrementedExisting, ...newAssignments];
    final completed = allActiveThisWeek
        .where((a) => a.remainingWeeks <= 0)
        .toList();
    final stillActive = allActiveThisWeek
        .where((a) => a.remainingWeeks > 0)
        .toList();
    for (final a in completed) {
      final engineer = engineersById[a.engineerId];
      if (engineer != null) {
        engineersById[a.engineerId] = engineer.copyWith(
          status: EngineerStatus.waiting,
        );
        logs.add('${engineer.profile.name} が「${a.project.title}」の契約を終了しました(待機)。');
      }
    }

    // 9. 売上計上 -----------------------------------------------------------
    final revenue = allActiveThisWeek.fold<int>(
      0,
      (sum, a) => sum + (a.project.monthlyRate / 4).round(),
    );

    // 10. 給与支払 ----------------------------------------------------------
    final salaryTotal = engineersById.values.fold<int>(
      0,
      (sum, e) => sum + (e.salary / 4).round(),
    );

    // 11. 固定費支払 --------------------------------------------------------
    const fixedCost = weeklyFixedCost;

    // Open-project marketplace bookkeeping ---------------------------------
    final activeProjectIds = {for (final a in allActiveThisWeek) a.project.id};
    final inFlightProjectIds = {
      for (final p in activeProposals) p.project.id,
    };
    final survivingOpenProjects = state.openProjects.where((entry) {
      final id = entry.project.id;
      if (activeProjectIds.contains(id)) return false;
      if (inFlightProjectIds.contains(id)) return true;
      return entry.project.applicationDeadlineWeek >= newWeek;
    }).toList();
    final openProjects = [...survivingOpenProjects, ...newProjectEntries];

    // 12. week + 1 (applied via Company below) + cash/stats -----------------
    final newCash = state.company.cash + revenue - salaryTotal - fixedCost;
    final waitingCountThisWeek = engineersById.values
        .where((e) => e.status == EngineerStatus.waiting)
        .length;

    final stats = state.stats.copyWith(
      cumulativeRevenue: state.stats.cumulativeRevenue + revenue,
      cumulativeSalary: state.stats.cumulativeSalary + salaryTotal,
      cumulativeFixedCost: state.stats.cumulativeFixedCost + fixedCost,
      cumulativeRecruitmentCost:
          state.stats.cumulativeRecruitmentCost + state.pendingMiscExpense,
      hires: state.stats.hires + hiresDelta,
      projectInterviewCount:
          state.stats.projectInterviewCount + interviewCountDelta,
      projectInterviewSuccess:
          state.stats.projectInterviewSuccess + interviewSuccessDelta,
      assignmentsStarted: state.stats.assignmentsStarted + newAssignments.length,
      waitingWeeks: state.stats.waitingWeeks + waitingCountThisWeek,
    );

    final engineers = engineersById.values.toList();
    final company = state.company.copyWith(
      cash: newCash,
      currentWeek: newWeek,
      engineerIds: engineers.map((e) => e.id).toList(),
    );

    var status = GameStatus.playing;
    int? bankruptWeek;
    String? bankruptCause;
    if (newCash < 0) {
      status = GameStatus.bankrupt;
      bankruptWeek = newWeek;
      bankruptCause =
          '週間支出(給与¥$salaryTotal + 固定費¥$fixedCost)が売上(¥$revenue)を上回り、資金がショートしました。';
      logs.add('資金がマイナスになりました。倒産しました。');
    } else if (newWeek >= totalGameWeeks) {
      status = GameStatus.finished;
      logs.add('$totalGameWeeks 週間の経営期間が終了しました。');
    }

    final events = [
      ...state.events,
      ...logs.map((m) => GameLogEntry(week: newWeek, message: m)),
    ];
    final trimmedEvents = events.length > maxLogEntries
        ? events.sublist(events.length - maxLogEntries)
        : events;

    return state.copyWith(
      company: company,
      engineers: engineers,
      applicants: applicants,
      openProjects: openProjects,
      listings: activeListings,
      proposals: activeProposals,
      activeAssignments: stillActive,
      pendingHires: pendingHires,
      events: trimmedEvents,
      stats: stats,
      status: status,
      pendingMiscExpense: 0,
      lastWeekRevenue: revenue,
      lastWeekExpense: salaryTotal + fixedCost + state.pendingMiscExpense,
      bankruptWeek: bankruptWeek,
      bankruptCause: bankruptCause,
      idCounter: idCounter,
    );
  }

  // ---------------------------------------------------------------------
  // End-of-game summaries (§23, §27)
  // ---------------------------------------------------------------------

  static GameRank computeRank(GameState state) {
    if (state.status == GameStatus.bankrupt) return GameRank.d;
    final cashScore = state.company.cash / 500000.0;
    final utilScore = state.utilizationPercent / 2.0;
    final hireScore = state.stats.hires * 3.0;
    final assignScore = state.stats.assignmentsStarted * 2.0;
    return GameRank.fromScore(cashScore + utilScore + hireScore + assignScore);
  }

  static Map<String, dynamic> playtestLog(GameState state) => {
    'seed': state.seed,
    'weeksPlayed': state.displayWeek,
    'finalCash': state.company.cash,
    'revenue': state.stats.cumulativeRevenue,
    'expenses': state.stats.cumulativeExpense,
    'hires': state.stats.hires,
    'proposalCount': state.stats.proposalCount,
    'projectInterviewCount': state.stats.projectInterviewCount,
    'projectInterviewSuccess': state.stats.projectInterviewSuccess,
    'waitingWeeks': state.stats.waitingWeeks,
    'finalEmployees': state.engineers.length,
    'bankruptcy': state.status == GameStatus.bankrupt,
    if (state.bankruptWeek != null) 'bankruptWeek': state.bankruptWeek,
  };
}
