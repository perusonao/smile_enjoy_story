import 'package:shared_preferences/shared_preferences.dart';

import '../public_demo/public_demo_aggregate.dart';
import 'public_demo_save_codec.dart';

/// Isolated local persistence for Public Demo 0.1's aggregate root.
///
/// Flutter Web's shared_preferences implementation uses browser localStorage.
/// This key intentionally differs from both normal GameState keys so a Public
/// Demo payload can never be decoded as a Development save, or vice versa.
class PublicDemoSaveService {
  static const key = 'ses_public_demo_01_aggregate_v1';

  const PublicDemoSaveService({this.codec = const PublicDemoSaveCodec()});

  final PublicDemoSaveCodec codec;

  Future<void> save(PublicDemoAggregate aggregate) async {
    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 100),
      );
      await preferences
          .setString(key, codec.encode(aggregate))
          .timeout(const Duration(milliseconds: 100));
    } catch (_) {
      // Persistence remains best-effort, exactly like normal SaveService.
    }
  }

  Future<PublicDemoAggregate?> load() async {
    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 100),
      );
      final raw = preferences.getString(key);
      return raw == null ? null : codec.decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Removes the isolated Public Demo aggregate.
  ///
  /// Unlike save/load, restart needs to know whether this completed: replacing
  /// an in-memory terminal session after a failed clear would falsely claim a
  /// fresh start while the old authoritative aggregate can still return on a
  /// later launch.
  Future<bool> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 100),
      );
      return await preferences
          .remove(key)
          .timeout(const Duration(milliseconds: 100));
    } catch (_) {
      return false;
    }
  }
}
