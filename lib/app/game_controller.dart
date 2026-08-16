import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../game/game.dart';
import '../domain/domain.dart';
import '../game/persistence/save_service.dart';

/// UI-facing façade over [GameEngine]: holds the current [GameState],
/// applies player actions through the (pure) engine, autosaves after every
/// mutation, and notifies listeners so widgets rebuild.
class GameController extends ChangeNotifier {
  GameController({SaveService? saveService, this.debugSeed})
    : _saveService = saveService ?? const SaveService() {
    _bootstrap();
  }

  final SaveService _saveService;

  /// QA/E2E-only market seed override (Playwright harness, `?seed=`
  /// launch param — see `main.dart`). `null` for every real player, in
  /// which case [chooseBeginnerStart]/[restartBeginnerMode] keep drawing a
  /// fresh random seed exactly as before this field existed. Never read by
  /// any gameplay/balance logic — only threaded into the existing
  /// `PrologueEngine.newGame`/`restart` `seed` parameter so an E2E run can
  /// reproduce a specific playthrough on demand (§17 of the E2E brief).
  final int? debugSeed;

  GameState _state = GameEngine.newGame();
  bool _isLoading = true;
  bool _showStartChoice = false;

  GameState get state => _state;
  bool get isLoading => _isLoading;

  /// True right after boot when this is a brand-new game with no prior
  /// save — shows the "ガイド付きで開始 / 自由に開始" picker once (§41-42).
  /// Not persisted: it only ever matters for the very first frame of a
  /// fresh playthrough.
  bool get showStartChoice => _showStartChoice;

  Future<void> _bootstrap() async {
    final loaded = await _saveService.load();
    if (loaded != null) {
      // Reconcile on load (Playable 0.4C.2 §7, §50): a refreshed/reopened
      // save must never resume a tutorial stage behind what the saved
      // GameState already shows happened. PrologueEngine.reconcileState
      // (Playable 0.5A.1 §7) additionally repairs a broken/older-schema
      // PrologueState so a corrupted save can never strand the player.
      _state = BeginnerModeEngine.reconcile(ProgressionEngine.reconcile(PrologueEngine.reconcileState(loaded)));
    } else {
      _showStartChoice = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// "ガイド付きで開始" (§41): just dismiss the picker, tutorial stays on.
  void chooseGuidedStart() {
    _showStartChoice = false;
    notifyListeners();
  }

  /// "自由に開始" (§41-42): unlock everything immediately, for experienced
  /// players / testing.
  void chooseFreeStart() {
    _showStartChoice = false;
    _apply(GameEngine.skipFoundingTutorial);
  }

  /// "創業プロローグから始めます" (Playable 0.5A §3): replaces the previous
  /// "ガイド付きで開始" with a full scripted founding sequence, starting from
  /// zero engineers instead of two already-employed founders (§4).
  void chooseBeginnerStart() {
    _showStartChoice = false;
    _state = BeginnerModeEngine.reconcile(ProgressionEngine.reconcile(PrologueEngine.newGame(seed: debugSeed)));
    notifyListeners();
    unawaited(_saveService.save(_state));
  }

  void _apply(GameState Function(GameState) mutate) {
    // Reconcile after every mutation (§7): the single point every player
    // action and every weekly turn passes through, so a milestone can never
    // silently fall behind the GameState that actually earned it.
    // PrologueEngine.reconcileState runs first (Playable 0.5A.1 §7): a
    // repaired PrologueState is what ProgressionEngine.reconcile should
    // then read milestones from, not the other way around.
    _state = BeginnerModeEngine.reconcile(ProgressionEngine.reconcile(PrologueEngine.reconcileState(mutate(_state))));
    notifyListeners();
    unawaited(_saveService.save(_state));
  }

  // --- Recruitment -------------------------------------------------------

  void interviewApplicant(String applicantId) =>
      _apply((s) => GameEngine.interviewApplicant(s, applicantId));

  void askRecruitmentQuestion(String applicantId, InterviewQuestionCategory category) =>
      _apply((s) => GameEngine.askRecruitmentQuestion(s, applicantId, category));

  void answerRecruitmentReverseQuestion(String applicantId, int choiceIndex) =>
      _apply((s) => GameEngine.answerRecruitmentReverseQuestion(s, applicantId, choiceIndex));

  void completeRecruitmentInterview(String applicantId, InterviewOutcome outcome) =>
      _apply((s) => GameEngine.completeRecruitmentInterview(s, applicantId, outcome));

  void rejectApplicant(String applicantId) =>
      _apply((s) => GameEngine.rejectApplicant(s, applicantId));

  void hireApplicant(String applicantId) =>
      _apply((s) => GameEngine.hireApplicant(s, applicantId));

  void postRecruitmentMedia(RecruitmentMediaType type) =>
      _apply((s) => GameEngine.postRecruitmentMedia(s, type));

  // --- Projects ------------------------------------------------------------

  void proposeEngineer(String engineerId, String projectId) =>
      _apply((s) => GameEngine.proposeEngineer(s, engineerId, projectId));

  void acceptOffer(String offerId) =>
      _apply((s) => GameEngine.acceptOffer(s, offerId));

  void declineOffer(String offerId) =>
      _apply((s) => GameEngine.declineOffer(s, offerId));

  void editSkillSheet(SkillSheet sheet) => _apply((s)=>GameEngine.editSkillSheet(s,sheet));
  void startSales(String employeeId) => _apply((s)=>GameEngine.startSales(s,employeeId));
  void acceptInterviewOffer(String offerId) => _apply((s)=>GameEngine.acceptInterviewOffer(s,offerId));
  void declineInterviewOffer(String offerId) => _apply((s)=>GameEngine.declineInterviewOffer(s,offerId));
  void startClientInterview(String applicationId, {SelectionStep step = SelectionStep.clientInterview}) => _apply((s)=>GameEngine.startClientInterview(s,applicationId,step:step,questionCount: step==SelectionStep.upperCompanyInterview?1:3));
  void chooseClientInterviewFollowUp(String sessionId,ClientInterviewFollowUp choice) => _apply((s)=>GameEngine.chooseClientInterviewFollowUp(s,sessionId,choice));
  void autoResolveClientInterview(String applicationId, {SelectionStep step = SelectionStep.clientInterview}) => _apply((s)=>GameEngine.autoResolveClientInterview(s,applicationId,step:step));
  void decideContract(String employeeId,{required bool extend}) => _apply((s)=>GameEngine.decideContract(s,employeeId,extend));

  // --- Welfare ---------------------------------------------------------

  void upgradePc(String employeeId, PcTier tier) => _apply((s)=>GameEngine.upgradePc(s,employeeId,tier));
  void conductHealthCheck(HealthCheckTier tier) => _apply((s)=>GameEngine.conductHealthCheck(s,tier));
  void payBonus(BonusPlan plan) => _apply((s)=>GameEngine.payBonus(s,plan));
  void conductCompanyTrip(CompanyTripType type) => _apply((s)=>GameEngine.conductCompanyTrip(s,type));

  // --- Guided founding (Playable 0.4C.1) --------------------------------

  void recordMilestone(FoundingMilestone milestone) =>
      _apply((s) => GameEngine.recordMilestone(s, milestone));

  void markTutorialSeen(OneTimeEvent event) =>
      _apply((s) => GameEngine.markTutorialSeen(s, event));

  // --- Beginner Mode Phase 3A (April-June) ------------------------------

  void markBeginnerMilestoneShown(BeginnerMilestone milestone) =>
      _apply((s) => BeginnerModeEngine.markShown(s, milestone));

  void skipFoundingTutorial() =>
      _apply(GameEngine.skipFoundingTutorial);

  void completeFoundingTutorial() =>
      _apply(GameEngine.completeFoundingTutorial);

  // --- Founding Prologue (Playable 0.5A) --------------------------------

  void setPresidentName(String name) => _apply((s) => PrologueEngine.setPresidentName(s, name));
  void setCompanyName(String name) => _apply((s) => PrologueEngine.setCompanyName(s, name));
  void confirmPrologueCompanySetup({required String presidentName, required String companyName}) =>
      _apply((s) => PrologueEngine.confirmCompanySetup(s, presidentName: presidentName, companyName: companyName));
  void markPrologueIntroSeen() => _apply(PrologueEngine.markIntroSeen);
  void postPrologueFreeRecruitment() => _apply(PrologueEngine.postFreeRecruitment);
  void postPrologueRecruitment(RecruitmentMediaType type) => _apply((s) => PrologueEngine.postRecruitment(s, type));
  void selectPrologueCandidate(String applicantId) => _apply((s) => PrologueEngine.selectCandidateForInterview(s, applicantId));
  void decidePrologueCandidate(String applicantId, {required bool hire}) => _apply((s) => PrologueEngine.decideCandidate(s, applicantId, hire: hire));
  void confirmPrologueSkillSheet() => _apply(PrologueEngine.confirmSkillSheet);
  void startProloguePreJoiningSales() => _apply(PrologueEngine.startPreJoiningSales);
  void acceptPrologueInterviewRequest() => _apply(PrologueEngine.acceptPrologueInterviewRequest);
  void finalizePrologueContractIfReady() => _apply(PrologueEngine.finalizeContractIfReady);
  void advancePrologueWeek() => _apply(PrologueEngine.advanceWeek);
  void completePrologue() => _apply(PrologueEngine.completePrologue);

  /// "初心者モードを最初からやり直す" (Playable 0.5A.1 §7) — always
  /// reachable from within the Founding Prologue. Clears the save first so a
  /// crash/reload mid-restart can't resurrect the abandoned playthrough,
  /// same ordering as [restart].
  Future<void> restartBeginnerMode({int? seed}) async {
    await _saveService.clear();
    _state = BeginnerModeEngine.reconcile(ProgressionEngine.reconcile(PrologueEngine.restart(seed: seed ?? debugSeed)));
    notifyListeners();
    unawaited(_saveService.save(_state));
  }

  // --- Turn ----------------------------------------------------------------

  void advanceWeek() => _apply(GameEngine.advanceWeek);

  // --- Meta ------------------------------------------------------------

  Future<void> restart({int? seed}) async {
    await _saveService.clear();
    _state = GameEngine.newGame(seed: seed);
    _showStartChoice = true;
    notifyListeners();
    unawaited(_saveService.save(_state));
  }

  GameRank get rank => GameEngine.computeRank(_state);

  String playtestLogJson() => const JsonEncoder.withIndent(
    '  ',
  ).convert(GameEngine.playtestLog(_state));
}
