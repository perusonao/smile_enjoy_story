import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether this browser has already dismissed Public Demo's Opening
/// Context screen (Issue #229 — the "目的・資金・固定支出・倒産リスク" intro
/// shown before a brand-new playthrough's first April).
///
/// Deliberately isolated from [PublicDemoSaveCodec]/[PublicDemoSaveService]:
/// the Opening Context is UI-only, one-time-per-browser presentation state,
/// not a gameplay fact belonging in [PublicDemoState] or
/// [PublicDemoWorkflowState]. Folding it into either would mean widening
/// their strict save round-trip validation for something no finance/sales/
/// employee authority ever needs to read — see this Issue's "fake data /
/// duplicate authority禁止" / "不要なschema変更は避ける" constraints.
///
/// The plain (non-[persistent]) constructor is deliberately inert —
/// [hasSeenOpening] always resolves `true` ("already seen", i.e. never show
/// the Opening Context) and [markSeen]/[clear] are no-ops. This is the
/// default [PublicDemo01PlaceholderScreen.openingMarker], so every existing
/// widget test that constructs that screen directly — there is no single
/// shared mount helper across that suite, and dozens of tests build a fresh
/// screen and interact with HOME immediately — keeps landing straight on
/// the interactive HOME tab exactly as it did before this screen existed,
/// with no test-by-test opt-out required. `main.dart`, the one real browser
/// entry point, is the sole caller that opts into the persisted,
/// SharedPreferences-backed behavior below via
/// [PublicDemoOpeningMarker.persistent].
class PublicDemoOpeningMarker {
  const PublicDemoOpeningMarker() : _persistent = false;

  const PublicDemoOpeningMarker.persistent() : _persistent = true;

  final bool _persistent;

  /// Isolated from every other persisted key in this app (mirrors
  /// [PublicDemoSaveService.key]'s own isolation rationale) — this is a
  /// single boolean flag, never decoded as a save payload.
  static const key = 'ses_public_demo_01_opening_seen_v1';

  /// `true` once this browser has dismissed the Opening Context, or when
  /// this marker is the inert (non-[persistent]) default. Best-effort: an
  /// unavailable storage bridge or a slow read resolves `true` rather than
  /// ever blocking real gameplay behind a failed local read.
  Future<bool> hasSeenOpening() async {
    if (!_persistent) return true;
    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 300),
      );
      return preferences.getBool(key) ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Records that this browser has dismissed the Opening Context. A no-op
  /// for the inert default marker.
  Future<void> markSeen() async {
    if (!_persistent) return;
    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 300),
      );
      await preferences
          .setBool(key, true)
          .timeout(const Duration(milliseconds: 300));
    } catch (_) {
      // Persistence remains best-effort, exactly like PublicDemoSaveService.
    }
  }

  /// Clears the recorded "seen" state (Public Demo's "4月からやり直す"/"最初
  /// からやり直す" restart flows) so a fresh playthrough sees the Opening
  /// Context again. A no-op for the inert default marker.
  Future<void> clear() async {
    if (!_persistent) return;
    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 300),
      );
      await preferences.remove(key).timeout(const Duration(milliseconds: 300));
    } catch (_) {
      // Best-effort, same as above.
    }
  }
}
