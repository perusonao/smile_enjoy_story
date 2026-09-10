// Dev-only reporting script — NOT part of the shipped app.
//
// Issue #223 (FIRST-FUN-YEAR Seeded Balance Fix) Fresh Audit: drives
// `PublicDemoStrategyBot` (test/game/public_demo/test_support/
// public_demo_strategy_bot.dart) across the required guardrail seeds plus a
// broad sweep, once per named strategy (Conservative/Balanced/Growth/Poor
// decisions), and prints a comparison table — survival rate, bankruptcy
// rate, cash checkpoints, hiring timing — matching the existing
// `tool/simulate_public_demo_seeded_balance.dart` pattern (a real, plain
// GameEngine/PublicDemoAggregate command-driven playthrough, never a
// synthetic/random-number-only model).
//
// Run with:
//   dart run tool/simulate_public_demo_strategy_audit.dart [sweepCount] [seedOffset]
// ignore_for_file: avoid_print
import '../test/game/public_demo/test_support/public_demo_strategy_bot.dart';

const requiredSeeds = [0, 1, 42, 13, 666, 315, 2147483000];

void main(List<String> args) {
  final sweepCount = args.isNotEmpty ? int.parse(args[0]) : 300;
  final seedOffset = args.length > 1 ? int.parse(args[1]) : 2000000;

  for (final policy in PublicDemoStrategyPolicy.all) {
    print('');
    print('=== Strategy: ${policy.kind.name} ===');
    _reportRequiredSeeds(policy);
  }

  print('');
  print('=== Sweep (n=$sweepCount, seeds $seedOffset-${seedOffset + sweepCount - 1}) ===');
  for (final policy in PublicDemoStrategyPolicy.all) {
    _reportSweep(policy, sweepCount, seedOffset);
  }
}

void _reportRequiredSeeds(PublicDemoStrategyPolicy policy) {
  for (final seed in requiredSeeds) {
    final r = PublicDemoStrategyBot.run(seed, policy);
    final status = r.reachedMarch
        ? 'REACHED MARCH'
        : (r.terminalStatus?.name ?? 'unknown (loop ended early)');
    print(
      '  seed $seed: $status | finalCash=${r.finalAggregate.state.cash} '
      '| minCash=${r.minCash} | terminalMonth=${r.terminalMonth} '
      '| hires=${r.totalHires} (first@${r.firstHireMonth}) '
      '| recruitSpend=${r.totalRecruitmentSpend} | trainSpend=${r.totalTrainingSpend}',
    );
  }
}

void _reportSweep(PublicDemoStrategyPolicy policy, int count, int seedOffset) {
  final results = <PublicDemoStrategyPlaythroughResult>[
    for (var i = 0; i < count; i++) PublicDemoStrategyBot.run(seedOffset + i, policy),
  ];
  final n = results.length;
  final reachedMarch = results.where((r) => r.reachedMarch).length;
  final bankrupt = results.where((r) => r.wentBankrupt).length;
  final marchFailure = results.where((r) => r.failedMarchCashShortage).length;
  final avgHires = results.fold<int>(0, (a, r) => a + r.totalHires) / n;
  final avgMinCash = results.fold<int>(0, (a, r) => a + r.minCash) / n;
  final avgFinalCash =
      results.fold<int>(0, (a, r) => a + r.finalAggregate.state.cash) / n;

  print('  ${policy.kind.name.padRight(14)}: '
      'reachedMarch ${_pct(reachedMarch, n)} | bankrupt ${_pct(bankrupt, n)} '
      '| marchShortage ${_pct(marchFailure, n)} '
      '| avgHires ${avgHires.toStringAsFixed(2)} '
      '| avgMinCash ${avgMinCash.round()} | avgFinalCash ${avgFinalCash.round()}');
}

String _pct(int count, int total) {
  if (total == 0) return '0/0 (n/a)';
  final pct = (count / total * 100).toStringAsFixed(1);
  return '$count/$total ($pct%)';
}
