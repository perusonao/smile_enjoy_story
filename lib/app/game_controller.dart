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
  GameController({SaveService? saveService})
    : _saveService = saveService ?? const SaveService() {
    _bootstrap();
  }

  final SaveService _saveService;

  GameState _state = GameEngine.newGame();
  bool _isLoading = true;

  GameState get state => _state;
  bool get isLoading => _isLoading;

  Future<void> _bootstrap() async {
    final loaded = await _saveService.load();
    if (loaded != null) {
      _state = loaded;
    }
    _isLoading = false;
    notifyListeners();
  }

  void _apply(GameState Function(GameState) mutate) {
    _state = mutate(_state);
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
  void startClientInterview(String applicationId) => _apply((s)=>GameEngine.startClientInterview(s,applicationId));
  void chooseClientInterviewFollowUp(String sessionId,ClientInterviewFollowUp choice) => _apply((s)=>GameEngine.chooseClientInterviewFollowUp(s,sessionId,choice));
  void autoResolveClientInterview(String applicationId) => _apply((s)=>GameEngine.autoResolveClientInterview(s,applicationId));
  void decideContract(String employeeId,{required bool extend}) => _apply((s)=>GameEngine.decideContract(s,employeeId,extend));

  // --- Welfare ---------------------------------------------------------

  void upgradePc(String employeeId, PcTier tier) => _apply((s)=>GameEngine.upgradePc(s,employeeId,tier));
  void conductHealthCheck(HealthCheckTier tier) => _apply((s)=>GameEngine.conductHealthCheck(s,tier));
  void payBonus(BonusPlan plan) => _apply((s)=>GameEngine.payBonus(s,plan));
  void conductCompanyTrip(CompanyTripType type) => _apply((s)=>GameEngine.conductCompanyTrip(s,type));

  // --- Turn ----------------------------------------------------------------

  void advanceWeek() => _apply(GameEngine.advanceWeek);

  // --- Meta ------------------------------------------------------------

  Future<void> restart({int? seed}) async {
    await _saveService.clear();
    _state = GameEngine.newGame(seed: seed);
    notifyListeners();
    unawaited(_saveService.save(_state));
  }

  GameRank get rank => GameEngine.computeRank(_state);

  String playtestLogJson() => const JsonEncoder.withIndent(
    '  ',
  ).convert(GameEngine.playtestLog(_state));
}
