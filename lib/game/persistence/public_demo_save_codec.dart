import 'dart:convert';

import '../public_demo/public_demo_aggregate.dart';

/// Versioned, self-contained persistence envelope for Public Demo 0.1.
///
/// This deliberately has no dependency on normal [GameState] persistence.
/// A payload is restored exactly as saved or rejected as a whole; decoding
/// never invokes gameplay reconciliation or derives replacement values.
class PublicDemoSaveCodec {
  static const schemaVersion = 1;
  static const _experience = 'public-demo-01';

  const PublicDemoSaveCodec();

  String encode(PublicDemoAggregate aggregate) => jsonEncode(toJson(aggregate));

  Map<String, dynamic> toJson(PublicDemoAggregate aggregate) => {
    'schemaVersion': schemaVersion,
    'experience': _experience,
    'aggregate': aggregate.toJson(),
  };

  /// Returns null for corrupt, foreign, incomplete, or incompatible saves.
  /// The caller can safely fall back to a new Public Demo session.
  PublicDemoAggregate? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  PublicDemoAggregate? fromJson(Map<String, dynamic> json) {
    try {
      if (json.keys.toSet().length != 3 ||
          !json.keys.toSet().containsAll(const {
            'schemaVersion',
            'experience',
            'aggregate',
          }) ||
          json['schemaVersion'] != schemaVersion ||
          json['experience'] != _experience ||
          json['aggregate'] is! Map) {
        return null;
      }
      final aggregate = PublicDemoAggregate.fromJson(
        (json['aggregate'] as Map).cast<String, dynamic>(),
      );

      // PublicDemoState's legacy decoder intentionally supplies defaults for
      // old normal-game data.  A Public Demo envelope must be stricter: this
      // round-trip comparison rejects missing fields, unknown enums, and any
      // payload that would otherwise be normalized during restoration.
      if (_canonicalJson(json) != _canonicalJson(toJson(aggregate))) {
        return null;
      }
      return aggregate;
    } catch (_) {
      return null;
    }
  }

  static String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.map((entry) {
        if (entry.key is! String) {
          throw const FormatException('Save object keys must be strings');
        }
        return MapEntry(entry.key as String, _canonicalize(entry.value));
      }).toList()..sort((left, right) => left.key.compareTo(right.key));
      return {for (final entry in entries) entry.key: entry.value};
    }
    if (value is List) return value.map(_canonicalize).toList();
    if (value is String || value is num || value is bool || value == null) {
      return value;
    }
    throw const FormatException('Unsupported save value');
  }
}
