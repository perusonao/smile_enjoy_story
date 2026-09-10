import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';

import 'test_support/public_demo_strategy_bot.dart';

/// Issue #223 (FIRST-FUN-YEAR Seeded Balance Fix): deterministic regression
/// coverage for [PublicDemoStrategyBot] — the Fresh Audit's four named
/// decision policies (Conservative/Balanced/Growth/Poor decisions) — across
/// the issue's own required guardrail seeds (0, 1, 42, 13, 666, 315,
/// 2147483000), mirroring the coverage shape
/// `public_demo_seeded_balance_regression_test.dart` already established for
/// the single-policy [PublicDemoSeededPlaythroughBot].
///
/// See `docs/reports/SES_FIRST-FUN-YEAR_Seeded-Balance-Fix_Result.md` for
/// the full Fresh Audit (broader seed sweep, authoritative economy table,
/// tuning rationale). This file locks only the required-seed exact outcomes
/// plus the qualitative design-target invariants Issue #223 itself demands:
/// Conservative/Balanced reliably complete, Growth/Poor decisions carry real
/// (but not total) risk, and Poor decisions is never better than a
/// disciplined Growth policy playing the same recruiting aggressiveness.
void main() {
  const requiredSeeds = [0, 1, 42, 13, 666, 315, 2147483000];

  group('determinism: byte-identical on a second run, per policy', () {
    for (final policy in PublicDemoStrategyPolicy.all) {
      for (final seed in requiredSeeds) {
        test('${policy.kind.name} seed $seed', () {
          final first = PublicDemoStrategyBot.run(seed, policy);
          final second = PublicDemoStrategyBot.run(seed, policy);
          expect(
            second.finalAggregate.toJson().toString(),
            first.finalAggregate.toJson().toString(),
          );
          expect(second.cashByMonth, first.cashByMonth);
          expect(second.reachedMarch, first.reachedMarch);
          expect(second.terminalStatus, first.terminalStatus);
        });
      }
    }
  });

  group('Conservative: never recruits, always reaches March on every '
      'required seed — a viable strategy exists with zero hiring risk', () {
    for (final seed in requiredSeeds) {
      test('seed $seed', () {
        final r = PublicDemoStrategyBot.run(
          seed,
          PublicDemoStrategyPolicy.conservative,
        );
        expect(r.reachedMarch, isTrue, reason: 'seed $seed');
        expect(r.totalHires, 0, reason: 'seed $seed');
        expect(r.finalAggregate.state.cash, 4480000, reason: 'seed $seed');
      });
    }
  });

  group('required-seed exact outcomes per policy (characterization lock)', () {
    const expected = {
      PublicDemoStrategyKind.conservative: {
        0: (reachedMarch: true, terminal: null, finalCash: 4480000),
        1: (reachedMarch: true, terminal: null, finalCash: 4480000),
        42: (reachedMarch: true, terminal: null, finalCash: 4480000),
        13: (reachedMarch: true, terminal: null, finalCash: 4480000),
        666: (reachedMarch: true, terminal: null, finalCash: 4480000),
        315: (reachedMarch: true, terminal: null, finalCash: 4480000),
        2147483000: (reachedMarch: true, terminal: null, finalCash: 4480000),
      },
      PublicDemoStrategyKind.balanced: {
        0: (reachedMarch: true, terminal: null, finalCash: 920000),
        1: (reachedMarch: true, terminal: null, finalCash: 2370000),
        42: (reachedMarch: true, terminal: null, finalCash: 870000),
        13: (reachedMarch: true, terminal: null, finalCash: 6280000),
        666: (reachedMarch: true, terminal: null, finalCash: 480000),
        315: (reachedMarch: true, terminal: null, finalCash: 1430000),
        2147483000: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -720000,
        ),
      },
      PublicDemoStrategyKind.growth: {
        0: (reachedMarch: true, terminal: null, finalCash: 5490000),
        1: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -1090000,
        ),
        42: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -800000,
        ),
        13: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -90000,
        ),
        666: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -1200000,
        ),
        315: (reachedMarch: true, terminal: null, finalCash: 5250000),
        2147483000: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -1300000,
        ),
      },
      PublicDemoStrategyKind.poorDecisions: {
        0: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -380000,
        ),
        1: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -1260000,
        ),
        42: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -1320000,
        ),
        13: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -450000,
        ),
        666: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -1690000,
        ),
        315: (reachedMarch: true, terminal: null, finalCash: 1060000),
        2147483000: (
          reachedMarch: false,
          terminal: PublicDemoFinancialStatus.bankruptcy,
          finalCash: -2280000,
        ),
      },
    };

    for (final policy in PublicDemoStrategyPolicy.all) {
      for (final seed in requiredSeeds) {
        final e = expected[policy.kind]![seed]!;
        test('${policy.kind.name} seed $seed: reachedMarch=${e.reachedMarch} '
            'terminal=${e.terminal} finalCash=${e.finalCash}', () {
          final r = PublicDemoStrategyBot.run(seed, policy);
          expect(r.reachedMarch, e.reachedMarch, reason: 'seed $seed');
          expect(r.terminalStatus, e.terminal, reason: 'seed $seed');
          expect(
            r.finalAggregate.state.cash,
            e.finalCash,
            reason: 'seed $seed',
          );
        });
      }
    }
  });

  group('design-target invariants across the required seeds', () {
    test('Balanced reaches March on at least 6 of the 7 required seeds — '
        'the design target that a selective, once-in-May hire is reliably '
        'completable (matches the broader 2,000-seed sweep: ~91% survival), '
        'not a guaranteed win on every single seed — a real, if small, risk '
        'remains even for a disciplined strategy', () {
      final outcomes = requiredSeeds
          .map(
            (seed) => PublicDemoStrategyBot.run(
              seed,
              PublicDemoStrategyPolicy.balanced,
            ).reachedMarch,
          )
          .toList();
      expect(outcomes.where((reached) => reached).length, greaterThanOrEqualTo(6));
    });

    test('Growth reaches March on at least one required seed but not all — '
        'early aggressive hiring is genuinely risky (bankrupts more often '
        'than it survives here) yet not structurally impossible, matching '
        '"Growthにもそれぞれ成立するSeed/状況があり" — no single strategy is '
        'either a guaranteed win or a guaranteed loss', () {
      final outcomes = requiredSeeds
          .map(
            (seed) => PublicDemoStrategyBot.run(
              seed,
              PublicDemoStrategyPolicy.growth,
            ).reachedMarch,
          )
          .toList();
      expect(outcomes.any((reached) => reached), isTrue);
      expect(outcomes.any((reached) => !reached), isTrue);
    });

    test('Poor decisions never outperforms Growth on any required seed, and '
        'strictly underperforms it in aggregate final cash — recruiting '
        'just as aggressively without training/cash-discipline/re-entry is '
        'a strictly worse decision, not merely a different one', () {
      var poorTotal = 0;
      var growthTotal = 0;
      for (final seed in requiredSeeds) {
        final poor = PublicDemoStrategyBot.run(
          seed,
          PublicDemoStrategyPolicy.poorDecisions,
        );
        final growth = PublicDemoStrategyBot.run(
          seed,
          PublicDemoStrategyPolicy.growth,
        );
        poorTotal += poor.finalAggregate.state.cash;
        growthTotal += growth.finalAggregate.state.cash;
        expect(
          poor.finalAggregate.state.cash,
          lessThanOrEqualTo(growth.finalAggregate.state.cash),
          reason: 'seed $seed',
        );
      }
      expect(poorTotal, lessThan(growthTotal));
    });

    test('no strategy is the literal only way to survive: Conservative '
        'reaches March on every required seed via zero hires, Balanced on '
        'most of them via a genuinely different decision (one selective '
        'hire) — and on the one seed Balanced does not survive (2147483000), '
        'Conservative still does, showing the zero-hire fallback is never '
        'itself eliminated by choosing to hire selectively', () {
      for (final seed in requiredSeeds) {
        final conservative = PublicDemoStrategyBot.run(
          seed,
          PublicDemoStrategyPolicy.conservative,
        );
        expect(conservative.reachedMarch, isTrue, reason: 'seed $seed');
      }
      final balancedOutcomes = requiredSeeds
          .map(
            (seed) => PublicDemoStrategyBot.run(
              seed,
              PublicDemoStrategyPolicy.balanced,
            ).reachedMarch,
          )
          .toList();
      // Balanced and Conservative are genuinely different policies with
      // genuinely different risk profiles, not two labels for the same
      // outcome.
      expect(balancedOutcomes.any((reached) => reached), isTrue);
      expect(balancedOutcomes.any((reached) => !reached), isTrue);
    });
  });
}
