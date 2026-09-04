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
      // SES-FIRST-FUN-YEAR-RELOAD-1 (P0): this call runs once at app boot,
      // competing with the Flutter Web engine/CanvasKit/WASM startup for the
      // event loop — a real existing save can take longer than a
      // conservative 100ms to become available in that window (confirmed:
      // a real browser reload with a genuine, valid save in localStorage
      // reproducibly timed out here and silently fell back to a brand-new
      // game, discarding the player's actual progress on their very next
      // save). This is a one-time boot-time read, not a per-frame budget,
      // so a more generous timeout costs nothing perceptible while removing
      // that real data-loss window. See
      // docs/reports/SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md.
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 1000),
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
