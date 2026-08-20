import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_experience.dart';
import '../models/models.dart';

/// Local-storage save/load for [GameState] (§25).
///
/// Uses `shared_preferences`, which is backed by `window.localStorage` on
/// Flutter Web — the game keeps playing after a page reload.
class SaveService {
  /// The original Development key. It must remain stable so existing player
  /// saves continue to load without migration.
  static const developmentKey = 'ses_playable_save_v1';
  static const publicDemo01Key = 'ses_public_demo_01_save_v1';

  const SaveService({this.key = developmentKey});

  factory SaveService.forExperience(AppExperience experience) => SaveService(
    key: switch (experience) {
      AppExperience.development => developmentKey,
      AppExperience.publicDemo01 => publicDemo01Key,
    },
  );

  /// Exposed for narrowly-scoped persistence tests and diagnostics.
  final String key;

  Future<void> save(GameState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(state.toJson()));
    } catch (_) {
      // Best-effort: persistence must never crash gameplay (e.g. running
      // outside a browser/without the plugin wired up, such as some test
      // harnesses).
    }
  }

  Future<GameState?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final state = GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      // A save from an older, incompatible schema (e.g. Playable 0.2's
      // weekly-accounting model) can't be replayed under the new monthly
      // rules — start a fresh game rather than risk crashing on it (§26).
      if (state.schemaVersion != currentSchemaVersion) return null;
      return state;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {
      // Ignore — see [save].
    }
  }
}
