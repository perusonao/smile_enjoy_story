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
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, codec.encode(aggregate));
    } catch (_) {
      // Persistence remains best-effort, exactly like normal SaveService.
    }
  }

  Future<PublicDemoAggregate?> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(key);
      return raw == null ? null : codec.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);
    } catch (_) {
      // Persistence cleanup must not break gameplay.
    }
  }
}
