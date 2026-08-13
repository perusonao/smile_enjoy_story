import '../../domain/domain.dart';
import '../models/models.dart';
import 'finance_engine.dart';
import 'project_interview_engine.dart';
import 'recruitment_engine.dart';
import 'rng.dart';

/// Orchestrates the whole simulation: new-game setup, the weekly turn, and
/// the player actions that can happen between turns (interview, hire/reject,
/// propose, post recruitment media).
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

  /// A freshly-founded company (Playable 0.3A §1-2): two engineers, both
  /// `waiting` — no pre-assigned contracts — a starting cash cushion sized
  /// to last a few months of pure salary+rent burn, and two open project
  /// listings already on the market so there's something to propose them to
  /// on Week 1.
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
    for (var i = 0; i < 2; i++) {
      final applicant = founderApplicants[i];
      engineers.add(
        Engineer(
          id: 'engineer-founder-$i',
          sourceApplicantId: applicant.id,
          profile: applicant,
          salary: applicant.desiredMonthlySalary,
          employmentWeek: 1,
          status: EngineerStatus.waiting,
        ),
      );
    }
    final openProjects = founderProjects
        .map((p) => ProjectEntry(project: p, postedWeek: 1))
        .toList();

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
      GameLogEntry(
        week: 1,
        message: '創業メンバー $founderNames が入社しました(待機中)。まずは案件を確認し、提案しましょう。',
      ),
    ];

    return GameState(
      seed: marketSeed,
      company: company,
      officeType: OfficeType.smallOffice,
      engineers: engineers,
      applicants: const [],
      interviewedApplicantIds: const {},
      openProjects: openProjects,
      listings: const [],
      proposals: const [],
      activeAssignments: const [],
      pendingHires: const [],
      accountsReceivable: const [],
      monthlyClosings: const [],
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
  /// to have been interviewed first, and blocks when the current office is
  /// already at capacity (Playable 0.3A §6).
  static GameState hireApplicant(GameState state, String applicantId) {
    if (!state.interviewedApplicantIds.contains(applicantId)) return state;
    final index = state.applicants.indexWhere(
      (e) => e.applicant.id == applicantId,
    );
    if (index == -1) return state;

    if (!FinanceEngine.hasOfficeCapacity(state)) {
      return state.withLog('現在のオフィスではこれ以上採用できません');
    }

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
      return next.withLog(
        '${applicant.name} は内定を辞退しました。',
        category: GameLogCategory.offerDeclined,
      );
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
        .withLog(
          '${applicant.name} が内定を承諾しました。($joinWeek 週目に入社予定)',
          category: GameLogCategory.offerAccepted,
        );
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
    final updatedWaitingStreak = {...afterMint.waitingStreak}
      ..remove(engineerId);
    return afterMint
        .copyWith(
          engineers: updatedEngineers,
          proposals: [...afterMint.proposals, proposal],
          stats: stats,
          waitingStreak: updatedWaitingStreak,
        )
        .withLog('${engineer.profile.name} を「${entry.project.title}」へ提案しました。');
  }

  /// Posts a recruitment listing, deducting its cost immediately and
  /// folding it into this month's not-yet-closed recruitment spend (§21).
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
  // Weekly turn (§3-§9, §19-20)
  // ---------------------------------------------------------------------

  static GameState advanceWeek(GameState state) {
    if (state.status != GameStatus.playing) return state;
    final newWeek = state.week + 1;
    final seed = state.seed;
    final logs = <(String message, GameLogCategory? category)>[];
    void log(String message, [GameLogCategory? category]) {
      logs.add((message, category));
    }

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
      log(
        '新しい応募者が${newApplicantEntries.length}名届きました。',
        GameLogCategory.applicantsArrived,
      );
    }

    // 求人掲載終了の検出 (§3) -------------------------------------------------
    final expiringListings = state.listings.where(
      (l) => l.isActiveOn(state.week) && !l.isActiveOn(newWeek),
    );
    for (final listing in expiringListings) {
      final label = recruitmentMediaConfigs[listing.type]!.label;
      log('$label の掲載期間が終了しました。', GameLogCategory.listingExpired);
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
      log('新着案件が${newProjectEntries.length}件届きました。', GameLogCategory.newProjects);
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
      log('${hire.applicant.name} が入社しました(待機)。', GameLogCategory.engineerJoined);
    }

    // 4/5. 提案進行・案件面談進行 -------------------------------------------
    // Failed proposals stay visible for exactly the week they resolve in
    // (so "案件面談結果" can show them), then get dropped here so the list
    // doesn't grow without bound over the year.
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
        log(
          '${engineer.profile.name} は「${proposal.project.title}」の案件面談に合格しました。',
          GameLogCategory.interviewPassed,
        );
        // Stays non-waiting until the assignment actually starts next week.
        engineersById[engineer.id] = engineer.copyWith(
          status: EngineerStatus.interviewScheduled,
        );
      } else {
        log(
          '${engineer.profile.name} は「${proposal.project.title}」の案件面談に不合格でした。',
          GameLogCategory.interviewFailed,
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
        log(
          '${engineer.profile.name} が「${proposal.project.title}」に参画しました。',
          GameLogCategory.assignmentStarted,
        );
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
        log(
          '${engineer.profile.name} が「${a.project.title}」の契約を終了しました(待機)。',
          GameLogCategory.contractEnded,
        );
      }
    }

    // 9. 当月の参画実績を月次会計スナップショットへ反映 (§9, §13) -----------
    // Every engineer who held an assignment at any point this week counts
    // toward this month's revenue accrual at month-end — dedup by engineer
    // id, keeping the latest project they were on.
    final monthAccrualSnapshot = {...state.monthAccrualSnapshot};
    for (final a in allActiveThisWeek) {
      monthAccrualSnapshot[a.engineerId] = a;
    }

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

    final engineers = engineersById.values.toList();
    final waitingCountThisWeek = engineersById.values
        .where((e) => e.status == EngineerStatus.waiting)
        .length;

    // Non-money stats update every week regardless of month-end.
    var stats = state.stats.copyWith(
      hires: state.stats.hires + hiresDelta,
      projectInterviewCount:
          state.stats.projectInterviewCount + interviewCountDelta,
      projectInterviewSuccess:
          state.stats.projectInterviewSuccess + interviewSuccessDelta,
      assignmentsStarted: state.stats.assignmentsStarted + newAssignments.length,
      waitingWeeks: state.stats.waitingWeeks + waitingCountThisWeek,
    );

    // 待機延べ週数の更新 (§17-18): まだ待機中の社員は連続待機週数を+1、
    // 待機を抜けた社員は履歴をクリアする。
    final newWaitingStreak = <String, int>{
      for (final e in engineers)
        if (e.status == EngineerStatus.waiting)
          e.id: (state.waitingStreak[e.id] ?? 0) + 1,
    };

    // ---------------------------------------------------------------------
    // 月次会計 (§8-9, §20): 4週目のみ実行。給与・家賃・固定費・売上計上・
    // 入金処理はすべて月末にまとめて処理する。
    // ---------------------------------------------------------------------
    final isMonthEnd = GameCalendar.isMonthEnd(newWeek);
    var newCash = state.company.cash;
    var accountsReceivable = state.accountsReceivable;
    var monthlyClosings = state.monthlyClosings;
    var pendingMiscExpense = state.pendingMiscExpense;
    var status = GameStatus.playing;
    int? bankruptWeek;
    String? bankruptCause;
    var nextMonthAccrualSnapshot = monthAccrualSnapshot;

    if (isMonthEnd) {
      final currentMonth = GameCalendar.absoluteMonth(newWeek);

      // 1) 案件売上を売掛金として計上 -----------------------------------
      final newAr = <AccountsReceivable>[];
      for (final a in monthAccrualSnapshot.values) {
        final client = FinanceEngine.clientById(a.project.clientId);
        final arId = mintId('ar');
        newAr.add(
          AccountsReceivable(
            id: arId,
            clientId: client.id,
            projectId: a.project.id,
            employeeId: a.engineerId,
            amount: a.project.monthlyRate,
            generatedMonth: currentMonth,
            dueMonth: FinanceEngine.dueMonthFor(
              generatedMonth: currentMonth,
              paymentTermDays: client.paymentTermDays,
            ),
          ),
        );
      }
      final projectRevenue = newAr.fold<int>(0, (sum, ar) => sum + ar.amount);

      // 2) 支払サイトが到来した売掛金を入金 -------------------------------
      var cashCollected = 0;
      final updatedExistingAr = state.accountsReceivable.map((ar) {
        if (ar.status == ArStatus.pending && ar.dueMonth <= currentMonth) {
          cashCollected += ar.amount;
          return ar.copyWith(status: ArStatus.paid);
        }
        return ar;
      }).toList();
      accountsReceivable = [...updatedExistingAr, ...newAr];

      // 3) 給与 (待機中も満額) / 4) 家賃 / 5) その他固定費 -----------------
      final salaryPaid = engineers.fold<int>(0, (sum, e) => sum + e.salary);
      final rentPaid = officeConfigs[state.officeType]!.monthlyRent;
      const fixedCostPaid = otherMonthlyFixedCost;

      // 6) 今月の採用費 ---------------------------------------------------
      final recruitmentCost = pendingMiscExpense;

      // 7) 会計上利益 / 8) 現金増減 ----------------------------------------
      final accountingProfit =
          projectRevenue - salaryPaid - rentPaid - fixedCostPaid - recruitmentCost;
      final cashDelta =
          cashCollected - salaryPaid - rentPaid - fixedCostPaid - recruitmentCost;
      final cashBefore = state.company.cash;
      final cashAfter = cashBefore + cashDelta;
      newCash = cashAfter;

      final label =
          '${GameCalendar.calendarYear(newWeek)}年${GameCalendar.monthName(newWeek)}';
      final closing = MonthlyClosing(
        month: currentMonth,
        week: newWeek,
        label: label,
        projectRevenue: projectRevenue,
        accountsReceivableGenerated: projectRevenue,
        cashCollected: cashCollected,
        salaryPaid: salaryPaid,
        rentPaid: rentPaid,
        otherFixedCost: fixedCostPaid,
        recruitmentCost: recruitmentCost,
        accountingProfit: accountingProfit,
        cashDelta: cashDelta,
        cashBefore: cashBefore,
        cashAfter: cashAfter,
      );
      final updatedClosings = [...state.monthlyClosings, closing];
      monthlyClosings = updatedClosings.length > maxMonthlyClosings
          ? updatedClosings.sublist(updatedClosings.length - maxMonthlyClosings)
          : updatedClosings;

      stats = stats.copyWith(
        cumulativeRevenue: stats.cumulativeRevenue + projectRevenue,
        cumulativeCashCollected: stats.cumulativeCashCollected + cashCollected,
        cumulativeSalary: stats.cumulativeSalary + salaryPaid,
        cumulativeRent: stats.cumulativeRent + rentPaid,
        cumulativeFixedCost: stats.cumulativeFixedCost + fixedCostPaid,
        cumulativeRecruitmentCost:
            stats.cumulativeRecruitmentCost + recruitmentCost,
      );

      log(
        '$label 月次決算: 売上¥$projectRevenue / 入金¥$cashCollected / 給与¥$salaryPaid / '
        '家賃¥$rentPaid / 固定費¥$fixedCostPaid / 求人費¥$recruitmentCost / '
        '利益${accountingProfit >= 0 ? '+' : ''}¥$accountingProfit / '
        '現金 ¥$cashBefore → ¥$cashAfter',
      );

      // 9) 倒産判定 (月末のみ) ---------------------------------------------
      if (newCash < 0) {
        status = GameStatus.bankrupt;
        bankruptWeek = newWeek;
        bankruptCause =
            '$label の月次決算で支出(給与¥$salaryPaid + 家賃¥$rentPaid + 固定費¥$fixedCostPaid'
            '${recruitmentCost > 0 ? ' + 求人費¥$recruitmentCost' : ''})が'
            '入金(¥$cashCollected)を上回り、資金がショートしました。';
        log('資金がマイナスになりました。倒産しました。', GameLogCategory.bankrupt);
      } else if (newWeek >= totalGameWeeks) {
        status = GameStatus.finished;
        log('1年間(48週間)の経営期間が終了しました。', GameLogCategory.gameFinished);
      }

      pendingMiscExpense = 0;
      nextMonthAccrualSnapshot = const {};
    }

    final events = [
      ...state.events,
      ...logs.map((l) => GameLogEntry(week: newWeek, message: l.$1, category: l.$2)),
    ];
    final trimmedEvents = events.length > maxLogEntries
        ? events.sublist(events.length - maxLogEntries)
        : events;

    final company = state.company.copyWith(
      cash: newCash,
      currentWeek: newWeek,
      engineerIds: engineers.map((e) => e.id).toList(),
    );

    var next = state.copyWith(
      company: company,
      engineers: engineers,
      applicants: applicants,
      openProjects: openProjects,
      listings: activeListings,
      proposals: activeProposals,
      activeAssignments: stillActive,
      pendingHires: pendingHires,
      accountsReceivable: accountsReceivable,
      monthlyClosings: monthlyClosings,
      events: trimmedEvents,
      stats: stats,
      status: status,
      waitingStreak: newWaitingStreak,
      monthAccrualSnapshot: nextMonthAccrualSnapshot,
      pendingMiscExpense: pendingMiscExpense,
      bankruptWeek: bankruptWeek,
      bankruptCause: bankruptCause,
      idCounter: idCounter,
    );

    if (isMonthEnd) {
      final runway = FinanceEngine.cashRunwayMonths(next);
      next = next.copyWith(stats: next.stats.withRunwaySample(runway));
    }

    return next;
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

  /// A lightweight, cosmetic "company type" read for the result screen
  /// (§23). Order matters: waiting-heavy is checked first since it's the
  /// clearest sign of a struggling run, then the positive archetypes.
  static CompanyType classifyCompanyType(GameState state) {
    final weeks = state.displayWeek.clamp(1, totalGameWeeks);
    final engineerWeeks = state.engineers.isEmpty ? 1 : state.engineers.length * weeks;
    final waitingRatio = state.stats.waitingWeeks / engineerWeeks;

    if (waitingRatio > 0.25) return CompanyType.overstaffedWaiting;
    if (state.utilizationPercent >= 85) return CompanyType.highUtilization;
    if (state.stats.hires >= 5) return CompanyType.aggressiveHiring;
    if (state.stats.cumulativeProfit >= startingCash * 0.5) {
      return CompanyType.highProfit;
    }
    return CompanyType.steady;
  }

  static Map<String, dynamic> playtestLog(GameState state) => {
    'seed': state.seed,
    'weeksPlayed': state.displayWeek,
    'initialCash': startingCash,
    'finalCash': state.company.cash,
    'accountsReceivable': state.accountsReceivable
        .map((ar) => ar.toJson())
        .toList(),
    'totalRevenueRecognized': state.stats.cumulativeRevenue,
    'totalCashCollected': state.stats.cumulativeCashCollected,
    'totalSalaryPaid': state.stats.cumulativeSalary,
    'totalRentPaid': state.stats.cumulativeRent,
    'totalFixedCost': state.stats.cumulativeFixedCost,
    'monthlyClosings': state.monthlyClosings.map((c) => c.toJson()).toList(),
    'hires': state.stats.hires,
    'proposalCount': state.stats.proposalCount,
    'projectInterviewCount': state.stats.projectInterviewCount,
    'projectInterviewSuccess': state.stats.projectInterviewSuccess,
    'waitingWeeks': state.stats.waitingWeeks,
    'finalEmployees': state.engineers.length,
    'bankruptcy': state.status == GameStatus.bankrupt,
    if (state.bankruptWeek != null) 'bankruptWeek': state.bankruptWeek,
    if (state.bankruptWeek != null)
      'bankruptMonth': GameCalendar.absoluteMonth(state.bankruptWeek!),
    if (state.stats.averageCashRunwayMonths != null)
      'averageCashRunway': state.stats.averageCashRunwayMonths,
  };
}
