import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../game/game.dart';
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

  void rejectApplicant(String applicantId) =>
      _apply((s) => GameEngine.rejectApplicant(s, applicantId));

  void hireApplicant(String applicantId) =>
      _apply((s) => GameEngine.hireApplicant(s, applicantId));

  void postRecruitmentMedia(RecruitmentMediaType type) =>
      _apply((s) => GameEngine.postRecruitmentMedia(s, type));

  // --- Projects ------------------------------------------------------------

  void proposeEngineer(String engineerId, String projectId) =>
      _apply((s) => GameEngine.proposeEngineer(s, engineerId, projectId));

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

  String playtestLogJson() =>
      const JsonEncoder.withIndent('  ').convert(GameEngine.playtestLog(_state));
}
