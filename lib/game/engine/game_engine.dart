import '../../domain/domain.dart';
import '../models/models.dart';
import 'finance_engine.dart';
import 'matching_engine.dart';
import 'morale_engine.dart';
import 'progression_engine.dart';
import 'project_interview_engine.dart';
import 'recruitment_engine.dart';
import 'recruitment_interview_engine.dart';
import 'rng.dart';
import 'selection_engine.dart';
import 'sales_engine.dart';
import 'client_interview_engine.dart';
import 'welfare_engine.dart';

/// Orchestrates the whole simulation: new-game setup, the weekly turn, and
/// the player actions that can happen between turns (interview, hire/reject,
/// propose, post recruitment media).
///
/// Every method is a pure function: `GameState -> GameState`. Nothing here
/// touches Flutter, `DateTime.now()`, or any other non-deterministic input
/// except [newGame]'s market seed (only when the caller doesn't supply one).
class GameEngine {
  const GameEngine._();

  // ---------------------------------------------------------------------
  // Guided founding progression (Playable 0.4C.1)
  // ---------------------------------------------------------------------

  /// Marks [milestone] complete (idempotent — see
  /// [FoundingProgress.withMilestone]). Used both for state-driven
  /// milestones recorded internally below, and for the two purely
  /// UI-driven ones (`inspectEmployee`, `inspectSkillSheet`) that the
  /// controller calls directly when those screens are opened.
  static GameState recordMilestone(GameState state, FoundingMilestone milestone) =>
      state.copyWith(
        foundingProgress: state.foundingProgress.withMilestone(milestone, state.week),
      );

  /// Marks a one-time celebration/contextual-tutorial [event] as shown.
  static GameState markTutorialSeen(GameState state, OneTimeEvent event) =>
      state.copyWith(
        foundingProgress: state.foundingProgress.withTutorialSeen(event),
      );

  /// "自由に開始" at new-game start (§41-42): unlocks every feature and
  /// hides the founding-mission guidance for the rest of the playthrough.
  static GameState skipFoundingTutorial(GameState state) =>
      state.copyWith(
        foundingProgress: state.foundingProgress.withTutorialSkipped(),
      );

  /// The player tapped "経営を続ける" on the final founding-mission step
  /// (§27-28) — moves to free management.
  static GameState completeFoundingTutorial(GameState state) =>
      recordMilestone(state, FoundingMilestone.freeManagement);

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
    final marketSeed =
        seed ?? (DateTime.now().millisecondsSinceEpoch & 0x7fffffff);

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
          companyTrust: 55 + i * 10,
          morale: 60 + i * 8,
          preference: EmployeePreference.values[i % EmployeePreference.values.length],
          industryExperience: {Industry.values[i]: applicant.totalItExperienceMonths ~/ 2},
          residenceArea: ResidenceArea.values[i],
          talkSkill: 3 + i,
          mental: 3,
          toughness: 3 + i,
          abilities: {i == 0 ? EmployeeAbility.clientFriendly : EmployeeAbility.fastLearner},
        ),
      );
    }
    final openProjects = founderProjects
        .map((p) => ProjectEntry(project: p, postedWeek: 1))
        .toList();
    final skillSheets = engineers.map((e)=>SkillSheet.fromActual(employeeId:e.id,languageMonths:e.profile.languageSkills.map((k,v)=>MapEntry(k,v.actualExperienceMonths)),skills:e.profile.techSkills,industryExperience:e.industryExperience,week:1)).toList();
    final equipment = engineers
        .map((e) => EmployeeEquipment(
              employeeId: e.id,
              pcTier: PcTier.standardLaptop,
              purchaseWeek: 1,
              purchaseCost: pcTierConfigs[PcTier.standardLaptop]!.cost,
            ))
        .toList();
    final clientRelations = sampleClients.indexed.map((item)=>ClientRelation(clientId:item.$2.id,unlocked:item.$1<2,trust:item.$1<2?50:0)).toList();

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
        message: '創業メンバー $founderNames が入社しました(待機中)。社員のスキルシートを確認し、営業を開始しましょう。',
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
      offers: const [],
      skillSheets: skillSheets,
      clientRelations: clientRelations,
      equipment: equipment,
      interviewOffers: const [],
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
    if (state.interviewedApplicantIds.contains(applicantId) || state.recruitmentInterviews.any((s) => s.applicantId == applicantId)) return state;
    final entry = state.applicants.where((e) => e.applicant.id == applicantId);
    if (entry.isEmpty) return state;
    final session = RecruitmentInterviewEngine.start(seed: state.seed, week: state.week, applicant: entry.first.applicant, companyCredit: state.company.credit, officeType: state.officeType, companySize: state.engineers.length);
    return state.copyWith(
      recruitmentInterviews: [...state.recruitmentInterviews, session],
      interviewedApplicantIds: {...state.interviewedApplicantIds, applicantId},
    );
  }

  static GameState askRecruitmentQuestion(GameState state, String applicantId, InterviewQuestionCategory category) {
    final sessionIndex = state.recruitmentInterviews.indexWhere((s) => s.applicantId == applicantId && !s.completed);
    final applicant = state.applicants.where((e) => e.applicant.id == applicantId);
    if (sessionIndex < 0 || applicant.isEmpty) return state;
    final sessions = [...state.recruitmentInterviews];
    sessions[sessionIndex] = RecruitmentInterviewEngine.ask(session: sessions[sessionIndex], applicant: applicant.first.applicant, seed: state.seed, category: category);
    return state.copyWith(recruitmentInterviews: sessions);
  }

  static GameState answerRecruitmentReverseQuestion(GameState state, String applicantId, int choiceIndex) {
    final index = state.recruitmentInterviews.indexWhere((s) => s.applicantId == applicantId && !s.completed);
    if (index < 0) return state;
    final sessions = [...state.recruitmentInterviews];
    sessions[index] = RecruitmentInterviewEngine.answerReverse(sessions[index], choiceIndex);
    return state.copyWith(recruitmentInterviews: sessions);
  }

  static GameState completeRecruitmentInterview(GameState state, String applicantId, InterviewOutcome outcome) {
    final index = state.recruitmentInterviews.indexWhere((s) => s.applicantId == applicantId && !s.completed);
    if (index < 0 || !state.recruitmentInterviews[index].conversationComplete) return state;
    final sessions = [...state.recruitmentInterviews];
    sessions[index] = sessions[index].copyWith(completed: true, outcome: outcome);
    return recordMilestone(state, FoundingMilestone.firstRecruitmentInterview).copyWith(recruitmentInterviews: sessions, interviewedApplicantIds: {...state.interviewedApplicantIds, applicantId});
  }

  static GameState rejectApplicant(GameState state, String applicantId) {
    final index = state.applicants.indexWhere(
      (e) => e.applicant.id == applicantId,
    );
    if (index == -1) return state;
    final entry = state.applicants[index];
    final remaining = [...state.applicants]..removeAt(index);
    return state
        .copyWith(applicants: remaining)
        .withLog('${entry.applicant.name} を不採用としました。');
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

    final session = state.recruitmentInterviews.where((s) => s.applicantId == applicantId && s.completed).toList();
    final rate = RecruitmentEngine.acceptanceRate(state.company.credit, companyImpression: session.isEmpty ? 50 : session.last.companyImpression);
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
    if (!state.canPropose(engineerId, projectId)) return state;
    final engIndex = state.engineers.indexWhere((e) => e.id == engineerId);
    if (engIndex == -1) return state;
    final engineer = state.engineers[engIndex];
    if (engineer.status == EngineerStatus.assigned) return state;

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
      fitScore: MatchingEngine.computeFit(engineer, entry.project).total,
    );
    final updatedEngineers = [...state.engineers];
    final legacySingleInterview =
        entry.project.interviewCount !=
        entry.project.selectionFlow.interviewCount;
    updatedEngineers[engIndex] = engineer.copyWith(
      status: legacySingleInterview
          ? EngineerStatus.proposed
          : EngineerStatus.waiting,
    );
    final stats = afterMint.stats.copyWith(
      proposalCount: afterMint.stats.proposalCount + 1,
      parallelProposalPeak: [
        afterMint.stats.parallelProposalPeak,
        afterMint.activeProposalCountFor(engineerId) + 1,
      ].reduce((a, b) => a > b ? a : b),
    );
    final updatedWaitingStreak = {...afterMint.waitingStreak};
    if (legacySingleInterview) {
      updatedWaitingStreak.remove(engineerId);
    }
    return afterMint
        .copyWith(
          engineers: updatedEngineers,
          proposals: [...afterMint.proposals, proposal],
          stats: stats,
          waitingStreak: updatedWaitingStreak,
        )
        .withLog('${engineer.profile.name} を「${entry.project.title}」へ提案しました。');
  }

  static GameState acceptOffer(GameState state, String offerId) {
    final offer = state.offers.where((item) => item.id == offerId).firstOrNull;
    if (offer == null ||
        offer.status != OfferStatus.pending ||
        state.week > offer.responseDeadlineWeek) {
      return state;
    }

    var cancelled = 0;
    final proposals = state.proposals.map((application) {
      if (application.id == offer.applicationId) {
        return application.copyWith(
          status: ApplicationStatus.accepted,
          stage: ProposalStage.interviewPassed,
          assignWeek: offer.startWeek,
        );
      }
      if (application.engineerId == offer.employeeId &&
          (application.status == ApplicationStatus.active ||
              application.status == ApplicationStatus.offered)) {
        cancelled++;
        return application.copyWith(
          status: ApplicationStatus.cancelled,
          rejectionReason: '他案件のオファーを受諾したため営業終了',
          stepHistory: [
            ...application.stepHistory,
            SelectionStepHistory(
              week: state.week,
              step: application.currentStep,
              result: SelectionStepResult.cancelled,
            ),
          ],
        );
      }
      return application;
    }).toList();
    final offers = state.offers.map((item) {
      if (item.id == offerId) {
        return item.copyWith(status: OfferStatus.accepted);
      }
      if (item.employeeId == offer.employeeId &&
          item.status == OfferStatus.pending) {
        return item.copyWith(status: OfferStatus.declined);
      }
      return item;
    }).toList();
    return state
        .copyWith(
          proposals: proposals,
          offers: offers,
          stats: state.stats.copyWith(
            offersAccepted: state.stats.offersAccepted + 1,
            proposalCancelledByOtherAssignment:
                state.stats.proposalCancelledByOtherAssignment + cancelled,
          ),
        )
        .withLog(
          '参画オファーを受諾しました。Week ${offer.startWeek} に参画予定です。',
          category: GameLogCategory.offerAccepted,
        );
  }

  static GameState declineOffer(GameState state, String offerId) {
    final offer = state.offers.where((item) => item.id == offerId).firstOrNull;
    if (offer == null || offer.status != OfferStatus.pending) return state;
    // Same fix as the offer-expiration path in advanceWeek (§4 case F):
    // without this, a declined offer leaves the engineer stuck at
    // `interviewing` forever, unable to restart sales or receive new
    // interview offers.
    final engineers = state.engineers.map((e) {
      if (e.id != offer.employeeId || e.salesStatus != SalesStatus.interviewing) return e;
      return e.copyWith(salesStatus: SalesStatus.selling);
    }).toList();
    return state
        .copyWith(
          engineers: engineers,
          offers: state.offers
              .map(
                (item) => item.id == offerId
                    ? item.copyWith(status: OfferStatus.declined)
                    : item,
              )
              .toList(),
          proposals: state.proposals
              .map(
                (application) => application.id == offer.applicationId
                    ? application.copyWith(status: ApplicationStatus.declined)
                    : application,
              )
              .toList(),
          stats: state.stats.copyWith(
            offersDeclined: state.stats.offersDeclined + 1,
          ),
        )
        .withLog('参画オファーを辞退しました。', category: GameLogCategory.offerDeclined);
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
    if (state.proposals.any((p)=>p.status==ApplicationStatus.active && p.currentStep==SelectionStep.clientInterview && !state.clientInterviews.any((s)=>s.applicationId==p.id && s.completed))) return state.withLog('客先面談が残っています。面談をプレイするか、社員に任せてください。');
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
    final skillSheets=[...state.skillSheets];

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
          ApplicantEntry(
            applicant: a,
            appearedWeek: newWeek,
            source: listing.type,
          ),
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
      log(
        '新着案件が${newProjectEntries.length}件届きました。',
        GameLogCategory.newProjects,
      );
    }

    // 3. 入社予定者処理 ---------------------------------------------------
    final joiningNow = state.pendingHires
        .where((h) => h.joinWeek == newWeek)
        .toList();
    final pendingHires = state.pendingHires
        .where((h) => h.joinWeek != newWeek)
        .toList();
    var hiresDelta = 0;
    final newEquipment = <EmployeeEquipment>[];
    for (final hire in joiningNow) {
      final id = mintId('engineer');
      final moraleRng = seededRandom(seed, newWeek, 'initial-morale:$id');
      final preferenceRng = seededRandom(seed, newWeek, 'preference:$id');
      final engineer = Engineer(
        id: id,
        sourceApplicantId: hire.applicant.id,
        profile: hire.applicant,
        salary: hire.salary,
        employmentWeek: newWeek,
        status: EngineerStatus.waiting,
        morale: 55 + moraleRng.nextInt(21),
        preference: EmployeePreference
            .values[preferenceRng.nextInt(EmployeePreference.values.length)],
      );
      engineersById[id] = engineer;
      skillSheets.add(SkillSheet.fromActual(employeeId:id,languageMonths:hire.applicant.languageSkills.map((k,v)=>MapEntry(k,v.actualExperienceMonths)),skills:hire.applicant.techSkills,week:newWeek));
      newEquipment.add(EmployeeEquipment(
        employeeId: id,
        pcTier: PcTier.standardLaptop,
        purchaseWeek: newWeek,
        purchaseCost: pcTierConfigs[PcTier.standardLaptop]!.cost,
      ));
      hiresDelta++;
      log(
        '${hire.applicant.name} が入社しました(待機)。',
        GameLogCategory.engineerJoined,
      );
    }

    // 4/5. Advance one selection step per week and create explicit offers.
    final carriedProposals = <ProjectProposal>[];
    final offers = state.offers.map((offer) {
      if (offer.status == OfferStatus.pending &&
          newWeek > offer.responseDeadlineWeek) {
        log('参画オファーの回答期限が切れました。', GameLogCategory.offerDeclined);
        return offer.copyWith(status: OfferStatus.expired);
      }
      return offer;
    }).toList();
    var interviewCountDelta = 0;
    var interviewSuccessDelta = 0;
    var screeningPassedDelta = 0;
    var upperPassedDelta = 0;
    var technicalPassedDelta = 0;
    var clientPassedDelta = 0;
    var finalPassedDelta = 0;
    var offersReceivedDelta = 0;
    final offersExpiredDelta =
        offers.where((o) => o.status == OfferStatus.expired).length -
        state.offers.where((o) => o.status == OfferStatus.expired).length;
    for (final proposal in state.proposals) {
      if (proposal.status != ApplicationStatus.active) {
        final expired =
            proposal.status == ApplicationStatus.offered &&
            offers.any(
              (offer) =>
                  offer.applicationId == proposal.id &&
                  offer.status == OfferStatus.expired,
            );
        carriedProposals.add(
          expired
              ? proposal.copyWith(
                  status: ApplicationStatus.declined,
                  rejectionReason: 'オファー回答期限切れ',
                )
              : proposal,
        );
        // An expired offer must return its engineer to `selling`, same as a
        // failed selection step does — otherwise `salesStatus` stays stuck
        // at `interviewing` forever: `startSales` refuses to restart anyone
        // already `interviewing`, and offer generation only considers
        // `selling` engineers, so the engineer becomes permanently
        // unreachable by new sales activity (Playable 0.4C.2 §4 case F).
        if (expired) {
          final engineer = engineersById[proposal.engineerId];
          if (engineer != null && engineer.salesStatus == SalesStatus.interviewing) {
            engineersById[proposal.engineerId] = engineer.copyWith(salesStatus: SalesStatus.selling);
          }
        }
        continue;
      }
      final engineer = engineersById[proposal.engineerId];
      if (engineer == null) continue;
      final legacySingleInterview =
          proposal.project.interviewCount !=
          proposal.project.selectionFlow.interviewCount;
      if (legacySingleInterview) {
        final rate = ProjectInterviewEngine.successRate(
          engineer,
          proposal.project,
        );
        final passed = ProjectInterviewEngine.roll(
          rate: rate,
          seed: seed,
          week: newWeek,
          salt: 'interview:${proposal.id}',
        );
        interviewCountDelta++;
        if (passed) interviewSuccessDelta++;
        carriedProposals.add(
          proposal.copyWith(
            status: passed
                ? ApplicationStatus.accepted
                : ApplicationStatus.rejected,
            stage: passed
                ? ProposalStage.interviewPassed
                : ProposalStage.interviewFailed,
            interviewWeek: newWeek,
            interviewSuccessRate: rate,
            assignWeek: passed ? newWeek + 1 : null,
          ),
        );
        engineersById[engineer.id] = engineer.copyWith(
          status: passed
              ? EngineerStatus.interviewScheduled
              : EngineerStatus.waiting,
        );
        engineersById[engineer.id] = engineer.copyWith(
          status: passed ? EngineerStatus.interviewScheduled : EngineerStatus.waiting,
          salesStatus: passed ? SalesStatus.interviewing : SalesStatus.selling,
        );
        log(
          '${engineer.profile.name} は「${proposal.project.title}」の案件面談に${passed ? '合格' : '不合格'}でした。',
          passed
              ? GameLogCategory.interviewPassed
              : GameLogCategory.interviewFailed,
        );
        continue;
      }
      final step = proposal.currentStep;
      if (step == SelectionStep.offer) {
        final offerId = mintId('offer');
        offers.add(
          Offer(
            id: offerId,
            applicationId: proposal.id,
            projectId: proposal.project.id,
            employeeId: proposal.engineerId,
            monthlyRate: proposal.project.monthlyRate,
            startWeek: newWeek + 1,
            responseDeadlineWeek: newWeek,
          ),
        );
        offersReceivedDelta++;
        carriedProposals.add(
          proposal.copyWith(
            status: ApplicationStatus.offered,
            finalOfferId: offerId,
            interviewWeek: newWeek,
          ),
        );
        log(
          '${engineer.profile.name} に「${proposal.project.title}」の参画オファーが届きました。回答期限は今週です。',
          GameLogCategory.offerReceived,
        );
        continue;
      }
      var rate = SelectionEngine.successRate(
        engineer,
        proposal.project,
        step,
      );
      if (proposal.fromInterviewOffer) {
        final penalty = ProgressionEngine.guidedSafetyNetActive(state, engineer.id) ? 25 : 35;
        rate = (rate - penalty).clamp(5, 95);
      }
      final passed = SelectionEngine.roll(
        rate: rate,
        seed: seed,
        week: newWeek,
        salt: 'selection:${proposal.id}:${step.name}',
      );
      if (step != SelectionStep.documentScreening) {
        interviewCountDelta++;
      }
      if (passed && step != SelectionStep.documentScreening) {
        interviewSuccessDelta++;
      }
      final history = SelectionStepHistory(
        week: newWeek,
        step: step,
        result: passed
            ? SelectionStepResult.passed
            : SelectionStepResult.failed,
        successRate: rate,
      );
      if (passed) {
        switch (step) {
          case SelectionStep.documentScreening:
            screeningPassedDelta++;
          case SelectionStep.upperCompanyInterview:
            upperPassedDelta++;
          case SelectionStep.technicalInterview:
            technicalPassedDelta++;
          case SelectionStep.clientInterview:
            clientPassedDelta++;
          case SelectionStep.finalInterview:
            finalPassedDelta++;
          case SelectionStep.offer:
            break;
        }
        carriedProposals.add(
          proposal.copyWith(
            currentStepIndex: proposal.currentStepIndex + 1,
            stepHistory: [...proposal.stepHistory, history],
            interviewWeek: newWeek,
            interviewSuccessRate: rate,
          ),
        );
        log(
          '${engineer.profile.name} は「${proposal.project.title}」の${step.name}を通過しました。',
          GameLogCategory.interviewPassed,
        );
      } else {
        final reason = SelectionEngine.rejectionReason(
          engineer,
          proposal.project,
          step,
        );
        carriedProposals.add(
          proposal.copyWith(
            status: ApplicationStatus.rejected,
            stage: ProposalStage.interviewFailed,
            stepHistory: [...proposal.stepHistory, history],
            rejectionReason: reason,
            interviewWeek: newWeek,
            interviewSuccessRate: rate,
          ),
        );
        engineersById[engineer.id] = engineer.copyWith(salesStatus: SalesStatus.selling);
        log(
          '${engineer.profile.name} は「${proposal.project.title}」で不合格：$reason',
          GameLogCategory.interviewFailed,
        );
      }
    }

    // 6. Start accepted assignments.
    final newAssignments = <ActiveAssignment>[];
    final finalizedProposalIds = <String>{};
    for (final proposal in carriedProposals) {
      if (proposal.status == ApplicationStatus.accepted &&
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
          salesStatus: SalesStatus.assigned,
          availableFromWeek: newWeek + proposal.project.durationWeeks,
        );
        finalizedProposalIds.add(proposal.id);
        log(
          '${engineer.profile.name} が「${proposal.project.title}」に参画しました。',
          GameLogCategory.assignmentStarted,
        );
      }
    }
    final filledProjectIds = newAssignments
        .map((assignment) => assignment.project.id)
        .toSet();
    final activeProposals = carriedProposals
        .where((p) => !finalizedProposalIds.contains(p.id))
        .map(
          (p) =>
              filledProjectIds.contains(p.project.id) &&
                  p.status == ApplicationStatus.active
              ? p.copyWith(
                  status: ApplicationStatus.cancelled,
                  rejectionReason: '募集枠が充足しました',
                )
              : p,
        )
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
          salesStatus: engineer.salesStatus == SalesStatus.selling ? SalesStatus.selling : SalesStatus.notSelling,
          availableFromWeek: newWeek,
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
    final inFlightProjectIds = {for (final p in activeProposals) p.project.id};
    final survivingOpenProjects = state.openProjects.where((entry) {
      final id = entry.project.id;
      if (activeProjectIds.contains(id)) return false;
      if (inFlightProjectIds.contains(id)) return true;
      return entry.project.applicationDeadlineWeek >= newWeek;
    }).toList();
    final openProjects = [...survivingOpenProjects, ...newProjectEntries];

    final engineers = engineersById.values.toList();
    var clientRelations=[...state.clientRelations];
    for(final assignment in newAssignments){ final ri=clientRelations.indexWhere((r)=>r.clientId==assignment.project.clientId); if(ri>=0){ final r=clientRelations[ri]; clientRelations[ri]=r.copyWith(trust:(r.trust+5).clamp(0,100),totalDeals:r.totalDeals+1,successfulAssignments:r.successfulAssignments+1,lastDealWeek:newWeek); } }
    // Field Lead (§32): trust (会社を信用しているか) drives whether an
    // engineer bothers bringing information back to the company at all;
    // morale contributes only a small nudge on top of that.
    for(final a in stillActive){ final e=engineersById[a.engineerId]!; final rate=(e.companyTrust~/3 + e.morale~/10 + e.talkSkill*2 + (e.abilities.contains(EmployeeAbility.clientFriendly)?10:0)).clamp(1,60); if(newWeek-a.assignedWeek>=4 && ProjectInterviewEngine.roll(rate:rate,seed:seed,week:newWeek,salt:'field-lead:${e.id}')) log('${e.profile.name}さんから「現場で増員予定がある」と案件情報が届きました',GameLogCategory.fieldLead); }
    for(var i=0;i<clientRelations.length;i++){
      final r=clientRelations[i]; if(r.unlocked)continue;
      final unlock=r.clientId=='client-nova-infra' ? engineers.length>=5 && engineers.any((e)=>e.profile.techSkills.infrastructure>=1) : r.clientId=='client-bright-solutions' ? clientRelations.firstWhere((x)=>x.clientId=='client-axis-soft').trust>=60 && clientRelations.fold<int>(0,(n,x)=>n+x.successfulAssignments)>=3 : false;
      if(unlock){clientRelations[i]=r.copyWith(unlocked:true,trust:30);log('新規取引開始！ ${sampleClients.firstWhere((c)=>c.id==r.clientId).name}',GameLogCategory.clientUnlocked);}
    }
    final expiredInterviewOffers=[for(final o in state.interviewOffers) if(o.status==InterviewOfferStatus.pending && o.expiresWeek<newWeek)o.copyWith(status:InterviewOfferStatus.expired) else o];
    final salesSnapshot=state.copyWith(engineers:engineers,openProjects:openProjects,clientRelations:clientRelations,interviewOffers:expiredInterviewOffers,idCounter:idCounter);
    final generatedInterviewOffers=SalesEngine.generateOffers(salesSnapshot,newWeek,mintId);
    for(final o in generatedInterviewOffers){ final project=openProjects.firstWhere((e)=>e.project.id==o.projectId).project; log('面談依頼！ ${engineers.firstWhere((e)=>e.id==o.employeeId).profile.name}さん / ${project.title}',GameLogCategory.interviewOffer); }
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
      assignmentsStarted:
          state.stats.assignmentsStarted + newAssignments.length,
      waitingWeeks: state.stats.waitingWeeks + waitingCountThisWeek,
      screeningPassed: state.stats.screeningPassed + screeningPassedDelta,
      upperCompanyInterviewPassed:
          state.stats.upperCompanyInterviewPassed + upperPassedDelta,
      technicalInterviewPassed:
          state.stats.technicalInterviewPassed + technicalPassedDelta,
      clientInterviewPassed:
          state.stats.clientInterviewPassed + clientPassedDelta,
      finalInterviewPassed: state.stats.finalInterviewPassed + finalPassedDelta,
      offersReceived: state.stats.offersReceived + offersReceivedDelta,
      offersExpired: state.stats.offersExpired + offersExpiredDelta,
      selectionWeeksTotal:
          state.stats.selectionWeeksTotal +
          state.proposals
              .where(
                (p) =>
                    p.status == ApplicationStatus.active &&
                    activeProposals.any(
                      (n) =>
                          n.id == p.id &&
                          n.status == ApplicationStatus.rejected,
                    ),
              )
              .fold<int>(0, (sum, p) => sum + newWeek - p.proposedWeek),
      completedSelections:
          state.stats.completedSelections +
          state.proposals
              .where(
                (p) =>
                    p.status == ApplicationStatus.active &&
                    activeProposals.any(
                      (n) =>
                          n.id == p.id &&
                          n.status == ApplicationStatus.rejected,
                    ),
              )
              .length,
    );

    // 待機延べ週数の更新 (§17-18): まだ待機中の社員は連続待機週数を+1、
    // 待機を抜けた社員は履歴をクリアする。
    final newWaitingStreak = <String, int>{
      for (final e in engineers)
        if (e.status == EngineerStatus.waiting)
          e.id: (state.waitingStreak[e.id] ?? 0) + 1,
    };

    // Morale / Trust: bounded weekly drift toward each engineer's current
    // conditions (office / waiting streak / assignment fit & commute),
    // always attributed to a concrete reason (Playable 0.4C §7-9, §30, §40).
    final assignmentByEngineer = {
      for (final a in stillActive) a.engineerId: a,
    };
    final engineersWithMorale = MoraleEngine.weeklyUpdate(
      engineers: engineers,
      officeType: state.officeType,
      week: newWeek,
      waitingStreak: newWaitingStreak,
      assignmentByEngineer: assignmentByEngineer,
    );

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

      // 3) 給与 (待機中も満額。総務も入社日から満額、Playable 0.4C.2 §2)
      // / 4) 家賃 / 5) その他固定費 -----------------------------------------
      final salaryPaid = engineers.fold<int>(0, (sum, e) => sum + e.salary) + (state.generalAffairsStaff?.salary ?? 0);
      final rentPaid = officeConfigs[state.officeType]!.monthlyRent;
      const fixedCostPaid = otherMonthlyFixedCost;

      // 6) 今月の採用費 (Playable 0.4C.2 §2: 求人媒体費はpostRecruitmentMedia
      // が掲載時点で即座にcashへ反映済みなので、ここではcashDeltaに二重計上
      // せず、会計上の月次実績(accountingProfit/recruitmentCostの内訳表示)
      // にのみ計上する) -----------------------------------------------------
      final recruitmentCost = pendingMiscExpense;

      // 7) 会計上利益 / 8) 現金増減 ----------------------------------------
      final accountingProfit =
          projectRevenue -
          salaryPaid -
          rentPaid -
          fixedCostPaid -
          recruitmentCost;
      final cashDelta =
          cashCollected -
          salaryPaid -
          rentPaid -
          fixedCostPaid;
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
        // Deliberately excludes recruitmentCost: postRecruitmentMedia
        // already took that cash out of Company.cash the moment the listing
        // was posted (well before this month-end check), so it's already
        // baked into cashBefore rather than part of this month-end's own
        // shortfall (Playable 0.4C.2 §2 fix — see cashDelta above).
        bankruptCause =
            '$label の月次決算で支出(給与¥$salaryPaid + 家賃¥$rentPaid + 固定費¥$fixedCostPaid)が'
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
      ...logs.map(
        (l) => GameLogEntry(week: newWeek, message: l.$1, category: l.$2),
      ),
    ];
    final trimmedEvents = events.length > maxLogEntries
        ? events.sublist(events.length - maxLogEntries)
        : events;

    final company = state.company.copyWith(
      cash: newCash,
      currentWeek: newWeek,
      engineerIds: engineersWithMorale.map((e) => e.id).toList(),
    );

    var next = state.copyWith(
      company: company,
      engineers: engineersWithMorale,
      skillSheets: skillSheets,
      applicants: applicants,
      openProjects: openProjects,
      listings: activeListings,
      proposals: activeProposals,
      offers: offers,
      clientRelations: clientRelations,
      equipment: [...state.equipment, ...newEquipment],
      interviewOffers: [...expiredInterviewOffers,...generatedInterviewOffers],
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

    if (generatedInterviewOffers.isNotEmpty) {
      next = recordMilestone(next, FoundingMilestone.receiveInterviewOffer);
    }
    if (newAssignments.isNotEmpty) {
      next = recordMilestone(next, FoundingMilestone.firstAssignment);
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
    final engineerWeeks = state.engineers.isEmpty
        ? 1
        : state.engineers.length * weeks;
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
    'recruitmentInterviews': state.recruitmentInterviews.where((s) => s.completed).length,
    'recruitmentQuestionsAsked': state.recruitmentInterviews.fold<int>(0, (n, s) => n + s.selectedQuestions.length),
    'reverseQuestionCategories': state.recruitmentInterviews.where((s) => s.reverseQuestion != null).map((s) => s.reverseQuestion!.name).toList(),
    'averageCandidateKnowledge': state.recruitmentInterviews.isEmpty ? 0 : state.recruitmentInterviews.fold<int>(0, (n, s) => n + s.candidateKnowledge) / state.recruitmentInterviews.length,
    'averageCompanyImpression': state.recruitmentInterviews.isEmpty ? 0 : state.recruitmentInterviews.fold<int>(0, (n, s) => n + s.companyImpression) / state.recruitmentInterviews.length,
    'offersMade': state.recruitmentInterviews.where((s) => s.outcome == InterviewOutcome.hired).length,
    'offerAcceptanceRate': (() {
      final made = state.recruitmentInterviews.where((s) => s.outcome == InterviewOutcome.hired).length;
      if (made == 0) return 0.0;
      final acceptedIds = <String>{
        ...state.pendingHires.map((h) => h.applicant.id),
        ...state.engineers.map((e) => e.sourceApplicantId),
      };
      final accepted = state.recruitmentInterviews.where((s) => s.outcome == InterviewOutcome.hired && acceptedIds.contains(s.applicantId)).length;
      return accepted / made;
    })(),
    'recruitmentQuestionCategoryCounts': {
      for (final category in InterviewQuestionCategory.values)
        category.name: state.recruitmentInterviews.fold<int>(0, (count, session) => count + session.selectedQuestions.where((q) => q == category).length),
    },
    'hiresAfterInterview': state.recruitmentInterviews.where((s) => s.outcome == InterviewOutcome.hired).length,
    'rejectsAfterInterview': state.recruitmentInterviews.where((s) => s.outcome == InterviewOutcome.rejected).length,
    'proposalCount': state.stats.proposalCount,
    'totalProposals': state.stats.proposalCount,
    'parallelProposalPeak': state.stats.parallelProposalPeak,
    'screeningPassed': state.stats.screeningPassed,
    'upperCompanyInterviewPassed': state.stats.upperCompanyInterviewPassed,
    'technicalInterviewPassed': state.stats.technicalInterviewPassed,
    'clientInterviewPassed': state.stats.clientInterviewPassed,
    'clientInterviewsPlayed': state.clientInterviews.where((s)=>s.completed&&s.playerFollowUps.any((f)=>f!=ClientInterviewFollowUp.letEmployeeHandle)).length,
    'clientInterviewsAutoResolved': state.clientInterviews.where((s)=>s.completed&&s.playerFollowUps.every((f)=>f==ClientInterviewFollowUp.letEmployeeHandle)).length,
    'clientInterviewPass': state.clientInterviews.where((s)=>s.result==ClientInterviewResult.passed).length,
    'clientInterviewFail': state.clientInterviews.where((s)=>s.result==ClientInterviewResult.failed).length,
    'followUpChoices': {for(final choice in ClientInterviewFollowUp.values)choice.name:state.clientInterviews.fold<int>(0,(n,s)=>n+s.playerFollowUps.where((f)=>f==choice).length)},
    'deepDiveCount': state.clientInterviews.where((s)=>s.deepDiveOccurred).length,
    'mismatchFailures': state.clientInterviews.where((s)=>s.mismatchFailure&&s.result==ClientInterviewResult.failed).length,
    'trustChangesFromInterview': state.clientInterviews.fold<int>(0,(n,s)=>n+(s.mismatchFailure?-2:(s.result==ClientInterviewResult.passed&&s.questions.every((q)=>q.mismatch<2)?1:0))),
    'finalInterviewPassed': state.stats.finalInterviewPassed,
    'offersReceived': state.stats.offersReceived,
    'offersAccepted': state.stats.offersAccepted,
    'offersDeclined': state.stats.offersDeclined,
    'offersExpired': state.stats.offersExpired,
    'proposalCancelledByOtherAssignment':
        state.stats.proposalCancelledByOtherAssignment,
    'averageSelectionWeeks': state.stats.averageSelectionWeeks,
    'projectInterviewCount': state.stats.projectInterviewCount,
    'projectInterviewSuccess': state.stats.projectInterviewSuccess,
    'waitingWeeks': state.stats.waitingWeeks,
    'skillSheetEdits': state.events.where((e)=>e.message.contains('スキルシート')).length,
    'skillSheetInflationAverage': state.engineers.isEmpty?0:state.engineers.fold<int>(0,(n,e)=>n+SalesEngine.inflationPoints(e,state.skillSheetFor(e.id)))/state.engineers.length,
    'employeeTrustChanges': state.engineers.fold<int>(0,(n,e)=>n+(60-e.companyTrust)),
    'salesStarted': state.events.where((e)=>e.message.contains('営業を開始')).length,
    'interviewOffersReceived': state.interviewOffers.length,
    'interviewOffersAccepted': state.interviewOffers.where((o)=>o.status==InterviewOfferStatus.accepted).length,
    'interviewOffersDeclined': state.interviewOffers.where((o)=>o.status==InterviewOfferStatus.declined).length,
    'clientUnlocks': state.clientRelations.where((r)=>r.unlocked).length-2,
    'fieldLeadsReceived': state.events.where((e)=>e.message.contains('増員予定')).length,
    'contractExtensions': state.activeAssignments.where((a)=>a.contractDecision==ContractDecision.extend).length,
    'contractWithdrawals': state.activeAssignments.where((a)=>a.contractDecision==ContractDecision.withdraw).length,
    'finalEmployees': state.engineers.length,
    'bankruptcy': state.status == GameStatus.bankrupt,
    if (state.bankruptWeek != null) 'bankruptWeek': state.bankruptWeek,
    if (state.bankruptWeek != null)
      'bankruptMonth': GameCalendar.absoluteMonth(state.bankruptWeek!),
    if (state.stats.averageCashRunwayMonths != null)
      'averageCashRunway': state.stats.averageCashRunwayMonths,
    // Guided founding (Playable 0.4C.1 §49) --------------------------------
    'tutorialEnabled': !state.foundingProgress.tutorialSkipped,
    'tutorialSkipped': state.foundingProgress.tutorialSkipped,
    'tutorialCompleted': ProgressionEngine.currentStage(state) == FoundingStage.freeManagement,
    'tutorialCompletionWeek': state.foundingProgress.milestoneWeeks[FoundingMilestone.freeManagement],
    'timeToFirstSalesStart': state.foundingProgress.milestoneWeeks[FoundingMilestone.startSales],
    'timeToFirstInterviewOffer': state.foundingProgress.milestoneWeeks[FoundingMilestone.receiveInterviewOffer],
    'timeToFirstClientInterview': state.foundingProgress.milestoneWeeks[FoundingMilestone.completeClientInterview],
    'timeToFirstAssignment': state.foundingProgress.milestoneWeeks[FoundingMilestone.firstAssignment],
    'timeToRecruitmentUnlock': state.foundingProgress.milestoneWeeks[FoundingMilestone.firstAssignment],
    'timeToWelfareUnlock': (() {
      final assignmentWeek = state.foundingProgress.milestoneWeeks[FoundingMilestone.firstAssignment];
      final interviewWeek = state.foundingProgress.milestoneWeeks[FoundingMilestone.firstRecruitmentInterview];
      if (assignmentWeek == null || interviewWeek == null) return null;
      return assignmentWeek > interviewWeek ? assignmentWeek : interviewWeek;
    })(),
  };
  static GameState editSkillSheet(GameState state, SkillSheet requested) {
    final index=state.engineers.indexWhere((e)=>e.id==requested.employeeId); if(index<0) return state;
    final engineer=state.engineers[index]; final old=state.skillSheetFor(engineer.id); final sheet=SalesEngine.clampSheet(engineer,requested,state.week);
    final increase=(SalesEngine.inflationPoints(engineer,sheet)-SalesEngine.inflationPoints(engineer,old)).clamp(0,99);
    final trustLoss=increase==0?0:(increase<=2?1:increase<=6?3:increase<=12?7:12);
    final engineers=[...state.engineers]; engineers[index]=engineer.copyWith(companyTrust:(engineer.companyTrust-trustLoss).clamp(0,100));
    return state.copyWith(engineers:engineers,skillSheets:[for(final s in state.skillSheets) if(s.employeeId==sheet.employeeId) sheet else s]).withLog('${engineer.profile.name}さんのスキルシートを更新しました${trustLoss>0?'（記載差に懸念）':''}');
  }

  static GameState startSales(GameState state,String employeeId){
    final index=state.engineers.indexWhere((e)=>e.id==employeeId); if(index<0) return state; final engineer=state.engineers[index];
    if(engineer.salesStatus==SalesStatus.selling || engineer.salesStatus==SalesStatus.interviewing) return state;
    final engineers=[...state.engineers]; engineers[index]=engineer.copyWith(salesStatus:SalesStatus.selling,availableFromWeek:engineer.status==EngineerStatus.assigned?state.assignmentForEngineer(employeeId)!.contractEndWeek+1:state.week);
    return recordMilestone(state.copyWith(engineers:engineers),FoundingMilestone.startSales).withLog('${engineer.profile.name}さんの営業を開始しました（公開先 ${state.unlockedClientCount}社）');
  }

  static GameState acceptInterviewOffer(GameState state,String offerId){
    final offer=state.interviewOffers.where((o)=>o.id==offerId).firstOrNull; if(offer==null||offer.status!=InterviewOfferStatus.pending||state.week>offer.expiresWeek)return state;
    final entry=state.openProjects.where((e)=>e.project.id==offer.projectId).firstOrNull;
    if(entry==null){
      // The underlying project can leave the marketplace (deadline/filled)
      // between when this offer was generated and when the player acts on
      // it. Without this, accepting silently did nothing and the offer sat
      // "pending" forever with no feedback (Playable 0.4C.2 §4 case D).
      return state.copyWith(interviewOffers:[for(final o in state.interviewOffers) if(o.id==offerId)o.copyWith(status:InterviewOfferStatus.expired) else o]).withLog('${FinanceEngine.clientById(offer.clientId).name}の面談依頼は案件の募集終了により無効になりました');
    }
    final (next,id)=state.mintId('proposal'); final proposal=ProjectProposal(id:id,engineerId:offer.employeeId,project:entry.project,proposedWeek:state.week,stage:ProposalStage.proposed,currentStepIndex:entry.project.selectionFlow.steps.length>1?1:0,fitScore:offer.skillSheetMatch,fromInterviewOffer:true);
    final engineers=[...next.engineers]; final i=engineers.indexWhere((e)=>e.id==offer.employeeId); engineers[i]=engineers[i].copyWith(salesStatus:SalesStatus.interviewing);
    return next.copyWith(engineers:engineers,interviewOffers:[for(final o in next.interviewOffers) if(o.id==offerId)o.copyWith(status:InterviewOfferStatus.accepted) else o],proposals:[...next.proposals,proposal],stats:next.stats.copyWith(proposalCount:next.stats.proposalCount+1)).withLog('${entry.project.title} の面談依頼を受けました');
  }

  static GameState declineInterviewOffer(GameState state,String offerId)=>state.copyWith(interviewOffers:[for(final o in state.interviewOffers) if(o.id==offerId)o.copyWith(status:InterviewOfferStatus.declined) else o]).withLog('面談依頼を辞退しました');

  static GameState startClientInterview(GameState state,String applicationId,{SelectionStep step=SelectionStep.clientInterview,int questionCount=3}){
    final existing=state.clientInterviews.where((s)=>s.applicationId==applicationId&&!s.completed&&s.step==step).firstOrNull;if(existing!=null)return state;
    final p=state.proposals.where((p)=>p.id==applicationId&&p.status==ApplicationStatus.active&&p.currentStep==step).firstOrNull;if(p==null)return state;
    final e=state.engineerById(p.engineerId),sheet=state.skillSheetFor(e.id);final (next,id)=state.mintId('client-interview');
    final qs=ClientInterviewEngine.questions(seed:state.seed,employee:e,project:p.project,sheet:sheet,count:questionCount);final first=ClientInterviewEngine.answer(e,p.project,qs.first);
    final label=step==SelectionStep.upperCompanyInterview?'上位会社面談':'客先面談';
    return next.copyWith(clientInterviews:[...next.clientInterviews,ClientInterviewSession(id:id,applicationId:p.id,employeeId:e.id,projectId:p.project.id,clientId:p.project.clientId,startedWeek:p.interviewWeek??state.week,questions:qs,employeeAnswers:[first],step:step)]).withLog('${e.profile.name}さんの$labelを開始しました');
  }

  /// Convenience wrapper for the Founding Prologue's Upper Company
  /// Interview (Playable 0.5A §45-48): the same mechanism as
  /// [startClientInterview], shortened to one question and gated on the
  /// [SelectionStep.upperCompanyInterview] step instead.
  static GameState startUpperCompanyInterview(GameState state,String applicationId)=>startClientInterview(state,applicationId,step:SelectionStep.upperCompanyInterview,questionCount:1);

  static GameState chooseClientInterviewFollowUp(GameState state,String sessionId,ClientInterviewFollowUp choice){
    final s=state.clientInterviews.where((s)=>s.id==sessionId&&!s.completed).firstOrNull;if(s==null)return state;final p=state.proposals.firstWhere((p)=>p.id==s.applicationId),e=state.engineerById(s.employeeId),q=s.questions[s.currentQuestionIndex],a=s.employeeAnswers[s.currentQuestionIndex];
    final outcome=ClientInterviewEngine.evaluate(e,q,a,choice,state.seed,s.id);var updated=s.copyWith(playerFollowUps:[...s.playerFollowUps,choice],interviewerReactions:[...s.interviewerReactions,outcome.reaction],accumulatedEvaluation:s.accumulatedEvaluation.add(technical:outcome.evaluation.technical,experience:outcome.evaluation.experience,communication:outcome.evaluation.communication,credibility:outcome.evaluation.credibility,clientFit:outcome.evaluation.clientFit),deepDiveOccurred:s.deepDiveOccurred||outcome.deepDive,mismatchFailure:s.mismatchFailure||(outcome.deepDive&&q.mismatch>=2),deepDiveText:outcome.deepDive?'「具体的な規模と、ご本人が担当した範囲を教えてください」':null);
    if(s.currentQuestionIndex<s.questions.length-1){final nextIndex=s.currentQuestionIndex+1;updated=updated.copyWith(currentQuestionIndex:nextIndex,employeeAnswers:[...updated.employeeAnswers,ClientInterviewEngine.answer(e,p.project,s.questions[nextIndex])]);return state.copyWith(clientInterviews:[for(final x in state.clientInterviews)if(x.id==s.id)updated else x]);}
    return _completeClientInterview(state,updated,p,e,played:true);
  }

  static GameState autoResolveClientInterview(GameState state,String applicationId,{SelectionStep step=SelectionStep.clientInterview,int questionCount=3}){final p=state.proposals.where((p)=>p.id==applicationId&&p.status==ApplicationStatus.active&&p.currentStep==step).firstOrNull;if(p==null)return state;final e=state.engineerById(p.engineerId),sheet=state.skillSheetFor(e.id);final (next,id)=state.mintId('client-interview');final qs=ClientInterviewEngine.questions(seed:state.seed,employee:e,project:p.project,sheet:sheet,count:questionCount);var s=ClientInterviewSession(id:id,applicationId:p.id,employeeId:e.id,projectId:p.project.id,clientId:p.project.clientId,startedWeek:state.week,questions:qs,step:step);for(var i=0;i<qs.length;i++){final a=ClientInterviewEngine.answer(e,p.project,qs[i]);final o=ClientInterviewEngine.evaluate(e,qs[i],a,ClientInterviewFollowUp.letEmployeeHandle,state.seed,id);s=s.copyWith(currentQuestionIndex:i,employeeAnswers:[...s.employeeAnswers,a],playerFollowUps:[...s.playerFollowUps,ClientInterviewFollowUp.letEmployeeHandle],interviewerReactions:[...s.interviewerReactions,o.reaction],accumulatedEvaluation:s.accumulatedEvaluation.add(technical:o.evaluation.technical,experience:o.evaluation.experience,communication:o.evaluation.communication,credibility:o.evaluation.credibility,clientFit:o.evaluation.clientFit));}return _completeClientInterview(next,s,p,e,played:false);}

  static GameState _completeClientInterview(GameState state,ClientInterviewSession s,ProjectProposal p,Engineer e,{required bool played}){final step=s.step;final interviewOfferPenalty=ProgressionEngine.guidedSafetyNetActive(state,e.id)?25:35;
    // Playable 0.5A §76-78 balance tuning (tool/simulate_prologue.dart):
    // a small, tightly-scoped bonus — Beginner Mode only, and only before
    // the Prologue's first assignment — on top of the existing
    // guidedSafetyNetActive penalty reduction. Needed because the Founding
    // Prologue's "assigned by April Week 1" reading requires *both* the
    // Upper Company and Client Interview to pass on the very first attempt
    // (a retry pushes the join into "April Week 2", §55); with only the
    // pre-existing 0.4C.4 safety net the two-step compound pass rate landed
    // near 68%, short of §76's 80-90% target, even though each individual
    // roll was already genuinely non-scripted (§53). Never applies to Free
    // Mode (gameMode is never beginner there) or to any later project.
    final beginnerFirstProjectBonus = state.gameMode==GameMode.beginner && !state.foundingProgress.has(FoundingMilestone.firstAssignment) ? 8 : 0;
    final rate=(ClientInterviewEngine.finalRate(e,p.project,s,fromInterviewOffer:p.fromInterviewOffer,interviewOfferPenalty:interviewOfferPenalty,step:step)+beginnerFirstProjectBonus).clamp(5,95);final passed=SelectionEngine.roll(rate:rate,seed:state.seed,week:s.startedWeek,salt:'client-conversation:${s.id}:${s.playerFollowUps.map((e)=>e.name).join(',')}');final result=passed?ClientInterviewResult.passed:ClientInterviewResult.failed;final history=SelectionStepHistory(week:state.week,step:step,result:passed?SelectionStepResult.passed:SelectionStepResult.failed,successRate:rate);final completed=s.copyWith(completed:true,result:result,mismatchFailure:s.mismatchFailure||(!passed&&s.questions.any((q)=>q.mismatch>=2)));final trustDelta=completed.mismatchFailure?-2:(passed&&s.questions.every((q)=>q.mismatch<2)?1:0);final engineers=[for(final x in state.engineers)if(x.id==e.id)x.copyWith(companyTrust:(x.companyTrust+trustDelta).clamp(0,100),salesStatus:passed?SalesStatus.interviewing:SalesStatus.selling)else x];final proposals=[for(final x in state.proposals)if(x.id==p.id)x.copyWith(currentStepIndex:passed?x.currentStepIndex+1:x.currentStepIndex,status:passed?ApplicationStatus.active:ApplicationStatus.rejected,stage:passed?x.stage:ProposalStage.interviewFailed,stepHistory:[...x.stepHistory,history],interviewWeek:state.week,interviewSuccessRate:rate,rejectionReason:passed?null:(completed.mismatchFailure?'SkillSheet記載に対して具体的な経験が不足していました':'他候補がより案件要件に合致しました'))else x];final label=step==SelectionStep.upperCompanyInterview?'上位会社面談':'客先面談';final withMilestone=step==SelectionStep.clientInterview?recordMilestone(state,FoundingMilestone.completeClientInterview):state;return withMilestone.copyWith(clientInterviews:[...state.clientInterviews.where((x)=>x.id!=s.id),completed],proposals:proposals,engineers:engineers,stats:state.stats.copyWith(projectInterviewCount:state.stats.projectInterviewCount+1,projectInterviewSuccess:state.stats.projectInterviewSuccess+(passed?1:0),clientInterviewPassed:state.stats.clientInterviewPassed+(passed&&step==SelectionStep.clientInterview?1:0))).withLog('$label ${passed?'通過！':'不合格'} ${e.profile.name} / ${p.project.title}',category:passed?GameLogCategory.interviewPassed:GameLogCategory.interviewFailed);}

  /// §34-35: the player can override the employee's own preference (visible
  /// via [MoraleEngine.contractPreference] in the UI) — doing so is a
  /// legitimate management call, but it costs Morale/Trust.
  static GameState decideContract(GameState state,String employeeId,bool extend){
    final i=state.activeAssignments.indexWhere((a)=>a.engineerId==employeeId); if(i<0)return state; final a=state.activeAssignments[i]; if(a.remainingWeeks>4)return state;
    final assignments=[...state.activeAssignments]; var engineers=[...state.engineers]; final ei=engineers.indexWhere((e)=>e.id==employeeId);
    final preference = MoraleEngine.contractPreference(engineers[ei], a, state.week);
    if(extend){ final weeks=a.contractTermMonths*4; assignments[i]=a.copyWith(remainingWeeks:a.remainingWeeks+weeks,contractEndWeek:a.contractEndWeek+weeks,contractDecision:ContractDecision.extend); engineers[ei]=engineers[ei].copyWith(availableFromWeek:a.contractEndWeek+weeks+1); }
    else { assignments[i]=a.copyWith(contractDecision:ContractDecision.withdraw); engineers[ei]=engineers[ei].copyWith(availableFromWeek:a.contractEndWeek+1,salesStatus:SalesStatus.notSelling); }
    if(extend && preference==ContractPreference.wantsLeave){ engineers[ei]=MoraleEngine.applyDelta(engineers[ei],week:state.week,reason:'本人の意向に反して延長',moraleDelta:-4,trustDelta:-3); }
    else if(!extend && preference==ContractPreference.wantsExtend){ engineers[ei]=MoraleEngine.applyDelta(engineers[ei],week:state.week,reason:'延長希望を無視して撤退',moraleDelta:-3,trustDelta:-2); }
    return state.copyWith(activeAssignments:assignments,engineers:engineers).withLog('${engineers[ei].profile.name}さんの契約を${extend?'延長':'満了で撤退'}します');
  }

  // ---------------------------------------------------------------------
  // Welfare (Playable 0.4C §11-27)
  // ---------------------------------------------------------------------

  /// §11-15: replaces the employee's lent PC. Cash-only, immediate expense —
  /// not a monthly fixed cost.
  static GameState upgradePc(GameState state, String employeeId, PcTier tier) {
    final index = state.engineers.indexWhere((e) => e.id == employeeId);
    if (index < 0) return state;
    final cost = WelfareEngine.pcUpgradeCost(tier);
    if (state.company.cash < cost) return state;
    var engineer = state.engineers[index];
    final current = state.equipmentFor(employeeId);
    if (current != null && current.pcTier == tier) return state;
    final moraleDelta = WelfareEngine.pcMoraleDelta(engineer, tier);
    engineer = MoraleEngine.applyDelta(
      engineer,
      week: state.week,
      reason: '${pcTierConfigs[tier]!.label}を支給',
      moraleDelta: moraleDelta,
    );
    final engineers = [...state.engineers];
    engineers[index] = engineer;
    final equipmentEntry = EmployeeEquipment(
      employeeId: employeeId,
      pcTier: tier,
      purchaseWeek: state.week,
      purchaseCost: cost,
    );
    final equipment = [
      for (final e in state.equipment)
        if (e.employeeId != employeeId) e,
      equipmentEntry,
    ];
    return state
        .copyWith(
          engineers: engineers,
          equipment: equipment,
          company: state.company.copyWith(cash: state.company.cash - cost),
        )
        .withLog(
          '${engineer.profile.name}さんに${pcTierConfigs[tier]!.label}を支給しました。(-¥$cost)',
          category: GameLogCategory.welfareEvent,
        );
  }

  /// §16-17: company-wide, once-in-a-while event. No hard yearly gate in
  /// the prototype — [RecommendationEngine] nudges the player instead.
  static GameState conductHealthCheck(GameState state, HealthCheckTier tier) {
    if (state.engineers.isEmpty) return state;
    final cost = WelfareEngine.healthCheckCost(tier, state.engineers.length);
    if (state.company.cash < cost) return state;
    final config = healthCheckConfigs[tier]!;
    final engineers = state.engineers
        .map((e) => MoraleEngine.applyDelta(
              e,
              week: state.week,
              reason: config.label,
              moraleDelta: config.moraleEffect,
              trustDelta: config.trustEffect,
            ))
        .toList();
    return state
        .copyWith(
          engineers: engineers,
          company: state.company.copyWith(cash: state.company.cash - cost),
          lastHealthCheckWeek: state.week,
        )
        .withLog(
          '${config.label}を実施しました。(-¥$cost / 全社員対象)',
          category: GameLogCategory.welfareEvent,
        );
  }

  /// §18-22: the player-facing preview (支給総額 / 支給後現預金 / 資金余命)
  /// is computed by the UI from [WelfareEngine.bonusCost] +
  /// [FinanceEngine.cashRunwayMonths] against a hypothetical post-bonus
  /// state — this method is the actual, committed payout.
  static GameState payBonus(GameState state, BonusPlan plan) {
    if (state.engineers.isEmpty) return state;
    final totalSalary = state.engineers.fold<int>(0, (sum, e) => sum + e.salary);
    final cost = WelfareEngine.bonusCost(plan, totalSalary);
    final config = bonusPlanConfigs[plan]!;
    final engineers = state.engineers.map((e) {
      final moraleDelta = WelfareEngine.bonusMoraleDelta(plan, e.preference);
      final reason = plan == BonusPlan.none ? '賞与なし' : '賞与 ${config.label}';
      return MoraleEngine.applyDelta(
        e,
        week: state.week,
        reason: reason,
        moraleDelta: moraleDelta,
        trustDelta: WelfareEngine.bonusTrustDelta(plan),
      );
    }).toList();
    final sampleReactions = engineers.take(2).map(
      (e) => '${e.profile.name}: ${WelfareEngine.bonusReaction(e.preference, plan)}',
    );
    var next = state
        .copyWith(
          engineers: engineers,
          company: state.company.copyWith(cash: state.company.cash - cost),
          lastBonusWeek: state.week,
        )
        .withLog(
          plan == BonusPlan.none
              ? '今回は賞与を見送りました。'
              : '賞与(${config.label})を支給しました。(-¥$cost)',
          category: GameLogCategory.welfareEvent,
        );
    for (final line in sampleReactions) {
      next = next.withLog(line, category: GameLogCategory.welfareEvent);
    }
    return next;
  }

  /// §23-27: `none` is intentionally not selectable here — skipping the
  /// trip is simply not calling this method.
  static GameState conductCompanyTrip(GameState state, CompanyTripType type) {
    if (state.engineers.isEmpty) return state;
    final cost = WelfareEngine.companyTripCost(type, state.engineers.length);
    if (state.company.cash < cost) return state;
    final config = companyTripConfigs[type]!;
    final engineers = state.engineers.map((e) {
      final moraleDelta = WelfareEngine.tripMoraleDelta(type, e.preference);
      return MoraleEngine.applyDelta(
        e,
        week: state.week,
        reason: config.label,
        moraleDelta: moraleDelta,
      );
    }).toList();
    final sampleReactions = engineers.take(2).map(
      (e) => '${e.profile.name}: ${WelfareEngine.tripReaction(e.preference)}',
    );
    var next = state
        .copyWith(
          engineers: engineers,
          company: state.company.copyWith(cash: state.company.cash - cost),
          lastCompanyTripWeek: state.week,
        )
        .withLog(
          '${config.label}を実施しました。(-¥$cost)',
          category: GameLogCategory.welfareEvent,
        );
    for (final line in sampleReactions) {
      next = next.withLog(line, category: GameLogCategory.welfareEvent);
    }
    return next;
  }
}
