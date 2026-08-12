import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Local-storage save/load for [GameState] (§25).
///
/// Uses `shared_preferences`, which is backed by `window.localStorage` on
/// Flutter Web — the game keeps playing after a page reload.
class SaveService {
  static const _key = 'ses_playable_save_v1';

  const SaveService();

  Future<void> save(GameState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (_) {
      // Best-effort: persistence must never crash gameplay (e.g. running
      // outside a browser/without the plugin wired up, such as some test
      // harnesses).
    }
  }

  Future<GameState?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Ignore — see [save].
    }
  }
}
