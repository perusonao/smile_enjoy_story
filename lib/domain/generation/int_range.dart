import 'dart:math';

/// An inclusive integer range, e.g. `IntRange(1, 5)` covers 1,2,3,4,5.
///
/// Shared by both generators for anything expressed as "min-max" in the
/// Phase 0 design doc (ages, experience years, 0-5 skill levels, ...).
class IntRange {
  final int min;
  final int max;

  const IntRange(this.min, this.max) : assert(min <= max);

  /// Uniformly picks an integer in `[min, max]`.
  int pick(Random rng) => min == max ? min : min + rng.nextInt(max - min + 1);

  /// Clamps [value] into this range.
  int clamp(int value) => value.clamp(min, max);

  IntRange shifted(int amount, {int lowerBound = 0, int upperBound = 5}) {
    return IntRange(
      (min + amount).clamp(lowerBound, upperBound),
      (max + amount).clamp(lowerBound, upperBound),
    );
  }

  @override
  String toString() => 'IntRange($min, $max)';
}
