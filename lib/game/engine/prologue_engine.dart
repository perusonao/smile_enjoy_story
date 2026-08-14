import 'dart:math';

import '../../domain/domain.dart';
import '../models/models.dart';
import 'finance_engine.dart';
import 'game_engine.dart';
import 'matching_engine.dart';
import 'progression_engine.dart';
import 'recruitment_engine.dart';
import 'rng.dart';
import 'sales_engine.dart';

/// Male- and female-coded given names drawn from [givenNamePool] (Playable
/// 0.5A §17): purely cosmetic name presentation for the two March Week 2
/// candidates. No ability ever reads from this split — see [Applicant],
/// which has no gender field at all, so there is nothing here for a
/// mechanical bias to attach to.
const List<String> _maleGivenNames = ['翔太', '大輝', '蓮', '悠斗', '大輔', '直樹', '健太', '拓也', '和也', '亮太', '亮', '弘樹'];
const List<String> _femaleGivenNames = ['陽菜', '結衣', '美咲', '花子', '真由', '智子', '沙織', '愛'];

/// Flavor lines for the 総務 navigator card (§67) — purely cosmetic.
const List<String> _navigatorFlavors = [
  '数字にはうるさいタイプです。',
  '面倒見がよく、社員から頼られています。',
  '慎重派で、リスクには早めに気づきます。',
  '明るく、社内の雰囲気を和ませてくれます。',
  '几帳面で、書類仕事はいつも完璧です。',
];

/// Orchestrates the Founding Prologue (Playable 0.5A): a scripted March →
/// April sequence that drives the *existing* recruitment / interview /
/// selection / sales engines instead of adding a parallel simulation (§2,
/// §85). [GameEngine] still owns every individual mechanic (interview
/// question, selection-step roll, offer accept, ...); this class only
/// decides *when* to call them and generates the two candidates + the first
/// project deterministically so the scripted path can't dead-end (§71).
///
/// March runs on [PrologueState.prologueWeek] (1-4), deliberately never
/// touching `company.currentWeek` — the real 48-week fiscal year (week 1 =
/// April, [GameCalendar]) only starts the moment [enterAprilWeek1] fires, so
/// every existing week-indexed system keeps working completely unmodified
/// (§83).
class PrologueEngine {
  const PrologueEngine._();

  static const int generalAffairsSalary = 280000;

  /// Mobile-friendly cap for the free-text president-name field (§5, §79).
  static const int presidentNameMaxLength = 20;

  // ---------------------------------------------------------------------
  // New game
  // ---------------------------------------------------------------------

  /// A freshly-founded Beginner Mode company (§4-8): president + one 総務
  /// employee, zero engineers, no open projects yet. Cash starts at the same
  /// [startingCash] as Free Mode — March's only burn is rent + other fixed
  /// cost + the navigator's salary (no engineer salary exists yet), so
  /// runway is *less* pressured than a Free Mode start, not more (§78).
  static GameState newGame({int? seed}) {
    final marketSeed = seed ?? (DateTime.now().millisecondsSinceEpoch & 0x7fffffff);
    final navigator = _generateNavigator(marketSeed);
    final initialClientIds = sampleClients.take(2).map((c) => c.id).toList();
    final clientRelations = sampleClients.indexed
        .map((item) => ClientRelation(clientId: item.$2.id, unlocked: item.$1 < 2, trust: item.$1 < 2 ? 50 : 0))
        .toList();

    final company = Company(
      id: 'company-player',
      name: 'あなたのSES会社',
      cash: startingCash,
      credit: startingCredit,
      currentWeek: 1,
      engineerIds: const [],
      clientIds: initialClientIds,
    );

    return GameState(
      seed: marketSeed,
      company: company,
      officeType: OfficeType.smallOffice,
      engineers: const [],
      applicants: const [],
      interviewedApplicantIds: const {},
      openProjects: const [],
      listings: const [],
      proposals: const [],
      skillSheets: const [],
      clientRelations: clientRelations,
      activeAssignments: const [],
      pendingHires: const [],
      events: [GameLogEntry(week: 1, message: '${navigator.name}さんが総務として入社しました。')],
      stats: const GameStats.zero(),
      status: GameStatus.playing,
      gameMode: GameMode.beginner,
      prologueState: PrologueState.beginnerStart,
      generalAffairsStaff: navigator,
    );
  }

  static GeneralAffairsStaff _generateNavigator(int seed) {
    final rng = seededRandom(seed, 0, 'navigator');
    final surname = surnamePool[rng.nextInt(surnamePool.length)];
    final given = givenNamePool[rng.nextInt(givenNamePool.length)];
    final flavor = _navigatorFlavors[rng.nextInt(_navigatorFlavors.length)];
    return GeneralAffairsStaff(
      id: 'general-affairs-1',
      name: '$surname $given',
      salary: generalAffairsSalary,
      flavor: flavor,
    );
  }

  // ---------------------------------------------------------------------
  // President naming + intro (§5, §9-10)
  // ---------------------------------------------------------------------

  static GameState setPresidentName(GameState state, String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return state;
    final name = trimmed.length > presidentNameMaxLength ? trimmed.substring(0, presidentNameMaxLength) : trimmed;
    return state.copyWith(company: state.company.copyWith(presidentName: name)).withLog('$name社長のもと、会社を設立しました。');
  }

  static GameState markIntroSeen(GameState state) => state.copyWith(prologueState: state.prologueState.copyWith(introSeen: true));

  // ---------------------------------------------------------------------
  // March Week 1: free recruitment (§12-16)
  // ---------------------------------------------------------------------

  static GameState postFreeRecruitment(GameState state) => GameEngine.postRecruitmentMedia(state, RecruitmentMediaType.freeWork);

  // ---------------------------------------------------------------------
  // March Week 2: two candidates, one interview (§17-29)
  // ---------------------------------------------------------------------

  static GameState _ensureCandidates(GameState state) {
    if (state.prologueState.candidateAId != null || state.engineers.isNotEmpty) return state;
    if (state.applicants.isNotEmpty) return state;
    final rng = Random(weekSeed(state.seed, 0, 'beginner-candidates'));
    double salaryJitter() => 1.0 + (rng.nextDouble() - 0.5) * 0.08;
    int skillJitter() => rng.nextInt(7) - 3;

    final candidateA = _buildCandidate(
      seed: state.seed,
      salt: 'candidate-a',
      name: '${surnamePool[rng.nextInt(surnamePool.length)]} ${_maleGivenNames[rng.nextInt(_maleGivenNames.length)]}',
      type: ApplicantType.midLevelEngineer,
      age: 30,
      totalItExperienceMonths: 66,
      backend: (4 + skillJitter()).clamp(2, 5),
      frontend: 2,
      database: 2,
      mainSkill: (70 + skillJitter() * 2).clamp(50, 90),
      communication: 2,
      desiredMonthlySalary: (520000 * salaryJitter()).round(),
      japaneseLevel: 5,
      qualifications: const ['基本情報技術者'],
    );
    final candidateB = _buildCandidate(
      seed: state.seed,
      salt: 'candidate-b',
      name: '${surnamePool[rng.nextInt(surnamePool.length)]} ${_femaleGivenNames[rng.nextInt(_femaleGivenNames.length)]}',
      type: ApplicantType.juniorProgrammer,
      age: 26,
      totalItExperienceMonths: 30,
      backend: (2 + skillJitter()).clamp(1, 4),
      frontend: 2,
      database: 1,
      mainSkill: (50 + skillJitter() * 2).clamp(35, 70),
      communication: 4,
      desiredMonthlySalary: (380000 * salaryJitter()).round(),
      japaneseLevel: 5,
      qualifications: const [],
    );

    final entries = [
      ApplicantEntry(applicant: candidateA, appearedWeek: state.week, source: RecruitmentMediaType.freeWork),
      ApplicantEntry(applicant: candidateB, appearedWeek: state.week, source: RecruitmentMediaType.freeWork),
    ];
    return state
        .copyWith(
          applicants: [...state.applicants, ...entries],
          prologueState: state.prologueState.copyWith(candidateAId: candidateA.id, candidateBId: candidateB.id),
        )
        .withLog('応募者が2名届きました。');
  }

  /// A single, deterministic rescue candidate (§54-55, §71): if both original
  /// candidates decline (§27 caps acceptance at 95%, never 100%), the pool
  /// must never go empty with no one left to interview.
  static GameState _ensureRescueCandidateIfNeeded(GameState state) {
    // Only a *restock* after the original pair (§17-20) is already spent —
    // never fires on the Week 1 → 2 transition itself, which is
    // [_ensureCandidates]'s job.
    if (state.prologueState.candidateAId == null) return state;
    if (state.engineers.isNotEmpty) return state;
    if (state.applicants.isNotEmpty) return state;
    final rng = Random(weekSeed(state.seed, state.prologueState.prologueWeek, 'rescue-candidate'));
    final candidate = _buildCandidate(
      seed: state.seed,
      salt: 'candidate-rescue-${state.prologueState.prologueWeek}',
      name: '${surnamePool[rng.nextInt(surnamePool.length)]} ${(rng.nextBool() ? _maleGivenNames : _femaleGivenNames)[rng.nextInt(6)]}',
      type: ApplicantType.juniorProgrammer,
      age: 27,
      totalItExperienceMonths: 36,
      backend: 3,
      frontend: 2,
      database: 2,
      mainSkill: 55,
      communication: 3,
      desiredMonthlySalary: 400000,
      japaneseLevel: 5,
      qualifications: const [],
    );
    return state
        .copyWith(applicants: [...state.applicants, ApplicantEntry(applicant: candidate, appearedWeek: state.week, source: RecruitmentMediaType.freeWork)])
        .withLog('${candidate.name}さんから新たに応募がありました。');
  }

  static Applicant _buildCandidate({
    required int seed,
    required String salt,
    required String name,
    required ApplicantType type,
    required int age,
    required int totalItExperienceMonths,
    required int backend,
    required int frontend,
    required int database,
    required int mainSkill,
    required int communication,
    required int desiredMonthlySalary,
    required int japaneseLevel,
    required List<String> qualifications,
  }) {
    LanguageSkill lang(ProgrammingLanguage l, int months, int skill) => LanguageSkill(language: l, displayedExperienceMonths: months, actualExperienceMonths: months, actualSkill: skill);
    final languageSkills = <ProgrammingLanguage, LanguageSkill>{
      for (final l in ProgrammingLanguage.values) l: lang(l, 0, 0),
      ProgrammingLanguage.java: lang(ProgrammingLanguage.java, (totalItExperienceMonths * 0.8).round(), mainSkill),
      ProgrammingLanguage.python: lang(ProgrammingLanguage.python, (totalItExperienceMonths * 0.2).round(), (mainSkill * 0.6).round()),
    };
    return Applicant(
      id: 'applicant-prologue-$seed-$salt',
      type: type,
      name: name,
      age: age,
      nationality: '日本',
      education: Education.university,
      major: Major.informationTechnology,
      totalItExperienceMonths: totalItExperienceMonths,
      jobChangeCount: 1,
      desiredMonthlySalary: desiredMonthlySalary,
      desiredWorkStyle: WorkStyle.hybrid,
      japaneseLevel: japaneseLevel,
      englishLevel: 2,
      qualifications: qualifications,
      languageSkills: languageSkills,
      mainLanguage: ProgrammingLanguage.java,
      subLanguages: const [ProgrammingLanguage.python],
      techSkills: TechSkillLevels(database: database, network: 1, infrastructure: 1, frontend: frontend, backend: backend, leader: 0, manager: 0),
      personality: PersonalityTraits(looks: 3, cleanliness: 3, communication: communication, alcoholTolerance: 3, seriousness: 4, dishonesty: 1),
      hidden: const HiddenParameters(growthPotential: 3, stressTolerance: 3, retention: 4, projectInterviewSkill: 3, turnoverIntent: 20),
    );
  }

  static GameState selectCandidateForInterview(GameState state, String applicantId) {
    if (state.prologueState.interviewingCandidateId != null) return state;
    if (!state.applicants.any((e) => e.applicant.id == applicantId)) return state;
    final withSession = GameEngine.interviewApplicant(state, applicantId);
    return withSession.copyWith(prologueState: withSession.prologueState.copyWith(interviewingCandidateId: applicantId));
  }

  /// 85-95% acceptance for the Prologue's first hire (§27) — deliberately not
  /// [RecruitmentEngine.acceptanceRate] (tuned for a mature company's credit,
  /// which would read far lower for a brand-new one). Hiring materializes a
  /// real [Engineer] immediately rather than a [PendingHire]: nothing is on
  /// payroll yet ([FinanceEngine] is never asked to include them until
  /// [enterAprilWeek1]'s one lump March close), but Week 3's pre-joining
  /// sales (§32-37) needs a real Engineer to run the existing Sales/Selection
  /// engines against (§2, §85).
  static GameState decideCandidate(GameState state, String applicantId, {required bool hire}) {
    if (!state.interviewedApplicantIds.contains(applicantId)) return state;
    if (!hire) {
      return GameEngine.rejectApplicant(state, applicantId).copyWith(
        prologueState: state.prologueState.copyWith(interviewingCandidateId: null),
      );
    }
    final entry = state.applicants.where((e) => e.applicant.id == applicantId).firstOrNull;
    if (entry == null) return state;
    final applicant = entry.applicant;
    final session = state.recruitmentInterviews.where((s) => s.applicantId == applicantId && s.completed).lastOrNull;
    final impression = session?.companyImpression ?? 50;
    final rate = (88 + (impression - 50) * 0.14).round().clamp(85, 95);
    final accepted = RecruitmentEngine.rollAcceptance(rate: rate, seed: state.seed, week: state.week, salt: 'prologue-hire:$applicantId');
    final clearedInterviewing = state.prologueState.copyWith(interviewingCandidateId: null);
    if (!accepted) {
      return GameEngine.rejectApplicant(state, applicantId).copyWith(prologueState: clearedInterviewing).withLog('${applicant.name} は内定を辞退しました。');
    }

    final engineerId = 'engineer-prologue-1';
    final engineer = Engineer(
      id: engineerId,
      sourceApplicantId: applicant.id,
      profile: applicant,
      salary: applicant.desiredMonthlySalary,
      employmentWeek: 1,
      status: EngineerStatus.waiting,
      companyTrust: 60,
      morale: 65,
      talkSkill: 3,
    );
    final sheet = SkillSheet.fromActual(employeeId: engineerId, languageMonths: applicant.languageSkills.map((k, v) => MapEntry(k, v.actualExperienceMonths)), skills: applicant.techSkills, week: state.week);
    return state
        .copyWith(
          engineers: [...state.engineers, engineer],
          skillSheets: [...state.skillSheets, sheet],
          applicants: const [],
          prologueState: clearedInterviewing,
          company: state.company.copyWith(engineerIds: [...state.company.engineerIds, engineerId]),
        )
        .withLog('${applicant.name} が内定を承諾しました。(4月1週に入社予定)', category: GameLogCategory.offerAccepted);
  }

  // ---------------------------------------------------------------------
  // March Week 3: SkillSheet confirm + pre-joining sales (§32-38)
  // ---------------------------------------------------------------------

  static GameState confirmSkillSheet(GameState state) => state.copyWith(prologueState: state.prologueState.copyWith(skillSheetConfirmed: true));

  static String? _hiredEngineerId(GameState state) => state.engineers.firstOrNull?.id;

  static GameState startPreJoiningSales(GameState state) {
    final id = _hiredEngineerId(state);
    if (id == null) return state;
    var next = GameEngine.startSales(state, id);
    final targetProjectId = _ensureTargetProject(next, id);
    return next.copyWith(prologueState: next.prologueState.copyWith(targetProjectId: targetProjectId));
  }

  /// Picks a well-fit, [SelectionFlowType.standard] project for [engineerId]
  /// (§40: "上位会社面談 → 客先面談", the exact 4-step standard flow, minus
  /// the already-cleared 書類選考) and makes sure it's on the open market so
  /// [GameEngine.acceptInterviewOffer] can find it. Generated from a fixed,
  /// game-seed-derived pool rather than the general weekly market (§74-78's
  /// simulation target is 80-90%+ first-assignment reliability, which needs a
  /// project genuinely reachable for *either* candidate archetype).
  static String _ensureTargetProject(GameState state, String engineerId) {
    final tried = state.prologueState.triedProjectIds.toSet();
    final engineer = state.engineerById(engineerId);
    final basePool = ProjectGenerator(seed: weekSeed(state.seed, 0, 'beginner-project-pool'), clients: sampleClients.take(2).toList()).generate(40, baseWeek: 1);
    // Always [SelectionFlowType.standard] (§43-45 needs the exact Upper
    // Company → Client Interview shape) — widened in steps if the curated
    // pool is exhausted, but never to a different flow shape, so [stage]'s
    // step-based branching can never see an unexpected step. Capped at
    // difficulty <= 2 and competitionLevel <= 3 (not just <= 3 difficulty,
    // §53-40 balance tuning, tool/simulate_prologue.dart): a genuinely easy,
    // low-competition first project is what keeps the *first-attempt*
    // Upper/Client Interview pass rate near the §76 80-90% April-Week-1
    // target, while the per-step roll itself stays real (never scripted,
    // §53) and the rescue retry (§54-56) still covers the rest.
    var candidates = basePool.where((p) => p.selectionFlow.type == SelectionFlowType.standard && p.difficulty <= 2 && p.competitionLevel <= 3 && !tried.contains(p.id)).toList();
    if (candidates.isEmpty) {
      candidates = basePool.where((p) => p.selectionFlow.type == SelectionFlowType.standard && p.difficulty <= 3 && !tried.contains(p.id)).toList();
    }
    if (candidates.isEmpty) {
      candidates = basePool.where((p) => p.selectionFlow.type == SelectionFlowType.standard && !tried.contains(p.id)).toList();
    }
    if (candidates.isEmpty) {
      // Every generated standard-flow project has already been tried (very
      // unlikely — needs 10+ consecutive failures) — reuse the best-fit one
      // rather than ever leaving the player with no request at all (§71).
      candidates = basePool.where((p) => p.selectionFlow.type == SelectionFlowType.standard).toList();
    }
    candidates.sort((a, b) => MatchingEngine.computeFit(engineer, b).total.compareTo(MatchingEngine.computeFit(engineer, a).total));
    if (candidates.isNotEmpty) return candidates.first.id;
    return ProjectGenerator(seed: weekSeed(state.seed, 0, 'beginner-project-fallback'), clients: sampleClients.take(2).toList()).generate(1, baseWeek: 1).first.id;
  }

  static Project _projectById(GameState state, String projectId) {
    final fromOpen = state.openProjects.where((e) => e.project.id == projectId).firstOrNull;
    if (fromOpen != null) return fromOpen.project;
    // Regenerate deterministically from the same fixed pool used to pick it.
    final pool = ProjectGenerator(seed: weekSeed(state.seed, 0, 'beginner-project-pool'), clients: sampleClients.take(2).toList()).generate(40, baseWeek: 1);
    final match = pool.where((p) => p.id == projectId).firstOrNull;
    if (match != null) return match;
    return ProjectGenerator(seed: weekSeed(state.seed, 0, 'beginner-project-fallback'), clients: sampleClients.take(2).toList()).generate(1, baseWeek: 1).first;
  }

  // ---------------------------------------------------------------------
  // March Week 4: interview request → upper interview → client interview →
  // contract (§39-58)
  // ---------------------------------------------------------------------

  /// Posts the scripted Interview Request for the target project (§39-42) if
  /// the hired engineer is selling and doesn't already have one pending or a
  /// selection in progress. Bypasses [SalesEngine.generateOffers]'s
  /// probabilistic weekly roll on purpose — Playable 0.5A §76 wants Week 4
  /// arrival itself to be reliable so the *interviews themselves* stay the
  /// suspenseful part, not the market's whim (§53 still forbids a scripted
  /// pass on the interviews).
  static GameState ensureInterviewRequest(GameState state) {
    final id = _hiredEngineerId(state);
    if (id == null) return state;
    final engineer = state.engineerById(id);
    if (engineer.salesStatus != SalesStatus.selling) return state;
    if (state.interviewOffers.any((o) => o.employeeId == id && o.status == InterviewOfferStatus.pending)) return state;
    if (state.proposals.any((p) => p.engineerId == id && p.status == ApplicationStatus.active)) return state;
    if (state.activeAssignments.any((a) => a.engineerId == id)) return state;

    final projectId = state.prologueState.targetProjectId ?? _ensureTargetProject(state, id);
    final project = _projectById(state, projectId);
    final alreadyOpen = state.openProjects.any((e) => e.project.id == project.id);
    final openProjects = alreadyOpen ? state.openProjects : [...state.openProjects, ProjectEntry(project: project, postedWeek: state.week)];
    final sheet = state.skillSheetFor(id);
    final match = SalesEngine.skillSheetMatch(sheet, project);
    final triedProjectIds = state.prologueState.triedProjectIds.contains(project.id) ? state.prologueState.triedProjectIds : [...state.prologueState.triedProjectIds, project.id];
    final (next, offerId) = state.copyWith(openProjects: openProjects, prologueState: state.prologueState.copyWith(targetProjectId: project.id, triedProjectIds: triedProjectIds)).mintId('interview-offer');
    final offer = InterviewOffer(id: offerId, employeeId: id, projectId: project.id, clientId: project.clientId, generatedWeek: state.week, expiresWeek: state.week + 4, skillSheetMatch: match);
    return next.copyWith(interviewOffers: [...next.interviewOffers, offer]).withLog('「${project.title}」の面談依頼が届きました。');
  }

  static GameState acceptPrologueInterviewRequest(GameState state) {
    final id = _hiredEngineerId(state);
    if (id == null) return state;
    final offer = state.interviewOffers.where((o) => o.employeeId == id && o.status == InterviewOfferStatus.pending).firstOrNull;
    if (offer == null) return state;
    return GameEngine.acceptInterviewOffer(state, offer.id);
  }

  /// After a passed Client Interview leaves the proposal sitting on
  /// [SelectionStep.offer] (§52-56), mints the Offer immediately (normally
  /// only [GameEngine.advanceWeek]'s weekly batch does this) and
  /// auto-accepts it — the Prologue is player-paced, not week-paced, so
  /// "契約成立" reads as an immediate consequence of passing, not a wait
  /// (§56).
  static GameState finalizeContractIfReady(GameState state) {
    final id = _hiredEngineerId(state);
    if (id == null) return state;
    final proposal = state.proposals.where((p) => p.engineerId == id && p.status == ApplicationStatus.active && p.currentStep == SelectionStep.offer).firstOrNull;
    if (proposal == null) return state;
    final (next, offerId) = state.mintId('offer');
    final offer = Offer(id: offerId, applicationId: proposal.id, projectId: proposal.project.id, employeeId: id, monthlyRate: proposal.project.monthlyRate, startWeek: 1, responseDeadlineWeek: 1);
    final withOffer = next
        .copyWith(offers: [...next.offers, offer], proposals: [for (final p in next.proposals) if (p.id == proposal.id) p.copyWith(status: ApplicationStatus.offered, finalOfferId: offerId) else p])
        .withLog('「${proposal.project.title}」の参画オファーが届きました。');
    return GameEngine.acceptOffer(withOffer, offerId);
  }

  /// Rescue path (§54-56): a failed Upper Company / Client Interview frees
  /// the engineer back to `selling` (existing logic in
  /// `GameEngine._completeClientInterview`) — this just makes sure a fresh
  /// Interview Request follows instead of leaving the player stalled.
  static GameState retryInterviewRequestIfNeeded(GameState state) {
    final id = _hiredEngineerId(state);
    if (id == null) return state;
    final failedJustNow = state.proposals.any((p) => p.engineerId == id && p.status == ApplicationStatus.rejected && p.targetProjectMatches(state.prologueState.targetProjectId));
    if (!failedJustNow) return state;
    final withCount = state.copyWith(prologueState: state.prologueState.copyWith(failedAttempts: state.prologueState.failedAttempts + 1, targetProjectId: null));
    return ensureInterviewRequest(withCount);
  }

  // ---------------------------------------------------------------------
  // Weekly progression (§16, §29, §38, §58)
  // ---------------------------------------------------------------------

  static GameState advanceWeek(GameState state) {
    var next = retryInterviewRequestIfNeeded(state);
    final week = next.prologueState.prologueWeek;
    if (week >= 4 && next.activeAssignments.isEmpty && _hiredEngineerId(next) != null) {
      final contractSecured = next.proposals.any((p) => p.engineerId == _hiredEngineerId(next) && p.status == ApplicationStatus.accepted);
      if (contractSecured) return enterAprilWeek1(next);
    }
    next = next.copyWith(prologueState: next.prologueState.copyWith(prologueWeek: week + 1));
    if (week + 1 == 2) {
      next = _ensureCandidates(next);
    } else if (week + 1 > 2) {
      next = _ensureRescueCandidateIfNeeded(next);
    }
    if (week + 1 >= 4) next = ensureInterviewRequest(next);
    return next;
  }

  /// April Week 1 (§59-62): joins the engineer for real and starts the
  /// assignment. `company.currentWeek` was never touched during March, so it
  /// is still 1 here — this literally *is* the real fiscal year's Week 1
  /// (§83), no reindexing needed.
  static GameState enterAprilWeek1(GameState state) {
    final id = _hiredEngineerId(state);
    if (id == null) return state;
    final proposal = state.proposals.where((p) => p.engineerId == id && p.status == ApplicationStatus.accepted && p.assignWeek == 1).firstOrNull;
    if (proposal == null) return state;
    final engineer = state.engineerById(id);
    final marchFixedCost = FinanceEngine.monthlyRent(state) + otherMonthlyFixedCost + (state.generalAffairsStaff?.salary ?? 0);
    final assignment = ActiveAssignment(engineerId: id, project: proposal.project, remainingWeeks: proposal.project.durationWeeks, assignedWeek: 1);
    final engineers = [
      for (final e in state.engineers)
        if (e.id == id) e.copyWith(status: EngineerStatus.assigned, salesStatus: SalesStatus.assigned, availableFromWeek: 1 + proposal.project.durationWeeks) else e,
    ];
    var next = state
        .copyWith(
          engineers: engineers,
          activeAssignments: [...state.activeAssignments, assignment],
          company: state.company.copyWith(cash: state.company.cash - marchFixedCost),
        )
        .withLog('${engineer.profile.name}さんが入社しました！', category: GameLogCategory.engineerJoined)
        .withLog('${engineer.profile.name}さんが「${proposal.project.title}」に参画しました！(-¥$marchFixedCost 3月分固定費)', category: GameLogCategory.assignmentStarted);
    next = GameEngine.recordMilestone(next, FoundingMilestone.inspectEmployee);
    next = GameEngine.recordMilestone(next, FoundingMilestone.inspectSkillSheet);
    next = GameEngine.recordMilestone(next, FoundingMilestone.welfareIntroSeen);
    return next;
  }

  static GameState completePrologue(GameState state) {
    // Reconciled explicitly here rather than relying on the caller (the
    // production [GameController] always reconciles after every action, but
    // this guarantees the invariant even when [PrologueEngine] is driven
    // directly, e.g. in tests or tooling) — otherwise milestones this
    // playthrough already earned purely as a side effect of engine calls
    // (receiveInterviewOffer, firstAssignment, ...) could still read as
    // not-yet-achieved right when `freeManagement` is recorded, leaving
    // [ProgressionEngine.currentStage] one step behind reality.
    var next = ProgressionEngine.reconcile(state.copyWith(prologueState: state.prologueState.copyWith(active: false, completed: true)));
    next = GameEngine.completeFoundingTutorial(next);
    return next;
  }

  // ---------------------------------------------------------------------
  // UI derivation (§66-71): mirrors [ProgressionEngine.currentStage] — the
  // stage is always recomputed from facts already in [GameState] /
  // [PrologueState], never a UI-only flag, so a save/reload or a widget
  // dispose mid-flow can never strand the player (§71).
  // ---------------------------------------------------------------------

  static PrologueStage stage(GameState state) {
    final ps = state.prologueState;
    if (state.company.presidentName.isEmpty) return PrologueStage.presidentNaming;
    if (!ps.introSeen) return PrologueStage.intro;

    final hiredId = _hiredEngineerId(state);
    if (hiredId == null) {
      if (ps.interviewingCandidateId != null) {
        final applicantId = ps.interviewingCandidateId!;
        final session = state.recruitmentInterviews.where((s) => s.applicantId == applicantId).lastOrNull;
        // `conversationComplete` (questions asked + reverse question
        // answered), not `completed` — the latter is only set by the
        // explicit hire/reject decision, which is exactly what
        // week2Decision exists to prompt (§21-29).
        if (session == null || !session.conversationComplete) return PrologueStage.week2Interview;
        return PrologueStage.week2Decision;
      }
      if (state.applicants.isNotEmpty) return PrologueStage.week2CandidateSelect;
      if (state.listings.isNotEmpty) return PrologueStage.week2AwaitingReply;
      return PrologueStage.week1Recruitment;
    }

    if (state.activeAssignments.isNotEmpty) return PrologueStage.complete;

    // The Week 3 screen shows the acceptance celebration (§30) and the
    // SkillSheet confirmation (§33-34) together, so a save from right after
    // hiring resolves here regardless of which half the player already saw.
    if (!ps.skillSheetConfirmed) return PrologueStage.week3SkillSheet;
    final engineer = state.engineerById(hiredId);
    if (engineer.salesStatus == SalesStatus.notSelling) return PrologueStage.week3Sales;

    final pendingOffer = state.interviewOffers.where((o) => o.employeeId == hiredId && o.status == InterviewOfferStatus.pending).firstOrNull;
    if (pendingOffer != null) return PrologueStage.week4InterviewRequest;

    final activeProposal = state.proposals.where((p) => p.engineerId == hiredId && p.status == ApplicationStatus.active).firstOrNull;
    if (activeProposal != null) {
      if (activeProposal.currentStep == SelectionStep.upperCompanyInterview) return PrologueStage.week4UpperInterview;
      if (activeProposal.currentStep == SelectionStep.clientInterview) return PrologueStage.week4ClientInterview;
      // currentStep == offer: passed the Client Interview, awaiting
      // [finalizeContractIfReady] to mint + auto-accept the Offer (§52-56).
      return PrologueStage.week4Contract;
    }
    final acceptedProposal = state.proposals.any((p) => p.engineerId == hiredId && p.status == ApplicationStatus.accepted);
    if (acceptedProposal) return PrologueStage.week4Contract;

    return PrologueStage.week4AwaitingRequest;
  }
}

extension _ProposalTargetMatch on ProjectProposal {
  bool targetProjectMatches(String? targetProjectId) => targetProjectId == null || project.id == targetProjectId;
}
