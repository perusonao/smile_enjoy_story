// Dev-only reporting script — NOT part of the shipped app.
//
// CORE-GAMEPLAY Phase 8 (Seeded Balance Verification, Issue #217): drives
// `PublicDemoSeededPlaythroughBot` (test/game/public_demo/test_support/
// public_demo_seeded_playthrough_bot.dart) across a broad seed range and
// prints aggregate statistics — First Fun Year completion rate, bankruptcy
// rate, cash checkpoints, and no-order-streak distribution — matching the
// existing `tool/simulate_balance_report.dart` pattern (a real, plain
// `GameEngine`/`PublicDemoAggregate` command-driven playthrough, never a
// synthetic/random-number-only model).
//
// Run with:
//   dart run tool/simulate_public_demo_seeded_balance.dart [count] [seedOffset]
// ignore_for_file: avoid_print
import '../test/game/public_demo/test_support/public_demo_seeded_playthrough_bot.dart';

void main(List<String> args) {
  final count = args.isNotEmpty ? int.parse(args[0]) : 300;
  final seedOffset = args.length > 1 ? int.parse(args[1]) : 1000000;

  final results = <PublicDemoSeededPlaythroughResult>[
    for (var i = 0; i < count; i++) PublicDemoSeededPlaythroughBot.run(seedOffset + i),
  ];

  final n = results.length;
  final reachedMarch = results.where((r) => r.reachedMarch).length;
  final bankrupt = results.where((r) => r.wentBankrupt).length;
  final marchFailure = results.where((r) => r.failedMarchCashShortage).length;

  print('=== CORE-GAMEPLAY Phase 8 seeded balance sweep '
      '(n=$n, seeds $seedOffset-${seedOffset + n - 1}) ===');
  print('First Fun Year reached (fiscalYearCompleted): ${_pct(reachedMarch, n)}');
  print('Bankruptcy: ${_pct(bankrupt, n)}');
  print('March cash-shortage failure: ${_pct(marchFailure, n)}');

  void cashStats(String label, int month) {
    final values = results
        .where((r) => r.cashByMonth.containsKey(month))
        .map((r) => r.cashByMonth[month]!)
        .toList()
      ..sort();
    if (values.isEmpty) {
      print('  $label: no data (nobody reached month $month)');
      return;
    }
    final avg = values.reduce((a, b) => a + b) / values.length;
    print(
      '  $label: min ${values.first} / p10 ${values[(values.length * 0.10).floor()]} '
      '/ median ${values[values.length ~/ 2]} / avg ${avg.round()} / max ${values.last} '
      '(n=${values.length}/$n)',
    );
  }

  print('Cash checkpoints:');
  for (final month in [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]) {
    cashStats('month $month', month);
  }

  // No-order streak distribution, only over engineers who actually appear
  // on the roster (founding + real May hires) — never a placeholder.
  final allStreaks = <int>[];
  var streakGe4 = 0;
  var streakGe5 = 0;
  var engineerMonthPairs = 0;
  for (final r in results) {
    for (final id in r.engagementByEngineerMonth.keys) {
      final streak = r.longestNoOrderStreak(id);
      allStreaks.add(streak);
      if (streak >= 4) streakGe4 += 1;
      if (streak >= 5) streakGe5 += 1;
      engineerMonthPairs += 1;
    }
  }
  allStreaks.sort();
  print('No-order streak (longest run per engineer-playthrough, '
      'n=$engineerMonthPairs engineer-playthroughs):');
  print('  >=4 consecutive months: ${_pct(streakGe4, engineerMonthPairs)}');
  print('  >=5 consecutive months: ${_pct(streakGe5, engineerMonthPairs)}');
  if (allStreaks.isNotEmpty) {
    print(
      '  min ${allStreaks.first} / median ${allStreaks[allStreaks.length ~/ 2]} '
      '/ max ${allStreaks.last}',
    );
  }

  final joinedInMayCounts = <int, int>{};
  for (final r in results) {
    joinedInMayCounts[r.engineersJoinedInMay] =
        (joinedInMayCounts[r.engineersJoinedInMay] ?? 0) + 1;
  }
  print('May hires joined (0/1/2 applicants generated per '
      'PublicDemoRecruitmentMedium.engineer):');
  for (final entry in (joinedInMayCounts.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key)))) {
    print('  ${entry.key} joined: ${_pct(entry.value, n)}');
  }
}

String _pct(int count, int total) {
  if (total == 0) return '   0/0  (n/a)';
  final pct = (count / total * 100).toStringAsFixed(1);
  return '${count.toString().padLeft(5)}/$total  ($pct%)';
}
