import 'dart:math';

/// A small, stable (non-`Object.hashCode`-dependent) string hash so seeded
/// randomness stays reproducible across Dart/Flutter versions.
///
/// FNV-1a, 32-bit, masked into the positive `int` range so it can feed
/// straight into [Random].
int stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7fffffff;
}

/// Derives a deterministic seed from a base [seed], the in-game [week], and
/// an arbitrary disambiguating [salt] (an index, an id, ...).
///
/// The same `(seed, week, salt)` triple always produces the same value, so
/// callers never need to persist `Random` instances themselves — every
/// week's market/roll can be recomputed on demand (including after a save
/// reload) purely from [GameState.seed] and the current week.
int weekSeed(int seed, int week, [Object salt = 0]) =>
    stableHash('$seed:$week:$salt');

/// Builds a fresh [Random] for a `(seed, week, salt)` triple.
Random seededRandom(int seed, int week, [Object salt = 0]) =>
    Random(weekSeed(seed, week, salt));
