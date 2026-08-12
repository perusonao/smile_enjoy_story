import 'dart:math';

/// Picks a key from [weights] with probability proportional to its value.
///
/// Weights do not need to sum to 1.0 — they are normalized internally. Zero
/// or negative entries are treated as "never selected". Throws if every
/// weight is zero/negative (i.e. nothing is selectable).
T pickWeighted<T>(Map<T, double> weights, Random rng) {
  final total = weights.values.fold<double>(
    0,
    (sum, w) => sum + (w > 0 ? w : 0),
  );
  if (total <= 0) {
    throw ArgumentError('pickWeighted: no positive weights to choose from');
  }
  var roll = rng.nextDouble() * total;
  for (final entry in weights.entries) {
    if (entry.value <= 0) continue;
    if (roll < entry.value) return entry.key;
    roll -= entry.value;
  }
  // Floating point edge case: fall back to the last positive-weight entry.
  return weights.entries.lastWhere((e) => e.value > 0).key;
}

/// Picks [count] distinct keys from [weights] without replacement, each
/// draw weighted by the remaining candidates' weights.
List<T> pickWeightedDistinct<T>(Map<T, double> weights, int count, Random rng) {
  final pool = Map<T, double>.from(weights)..removeWhere((_, w) => w <= 0);
  final result = <T>[];
  while (result.length < count && pool.isNotEmpty) {
    final picked = pickWeighted(pool, rng);
    result.add(picked);
    pool.remove(picked);
  }
  return result;
}
