import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

/// SEEDED-RNG-REUSE-1: [PublicDemoState.runSeed]'s own lifecycle —
/// generation, injection, survival across ordinary transitions and a save
/// round trip, and legacy-save migration. `public_demo_rng_test.dart`
/// covers the derived-stream adapter itself.
void main() {
  group('generation', () {
    test('aprilStart draws a runSeed when none is supplied', () {
      final state = PublicDemoState.aprilStart();

      expect(state.runSeed, isNonNegative);
    });

    test('aprilStart honors an injected fixed runSeed (test determinism)', () {
      final state = PublicDemoState.aprilStart(runSeed: 20260907);

      expect(state.runSeed, 20260907);
    });

    test(
      'PublicDemoAggregate.initial threads runSeed through to aprilStart',
      () {
        final aggregate = PublicDemoAggregate.initial(runSeed: 777);

        expect(aggregate.runSeed, 777);
        expect(aggregate.state.runSeed, 777);
      },
    );
  });

  group('survival across ordinary transitions', () {
    test('month-advancing commands never change runSeed', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 888)
          .closeApril(monthlyExpenses: 0)
          .closeMay(week: 9, monthlyExpenses: 0)
          .closeJune(assignedInJuly: 0, monthlyExpenses: 0);

      expect(aggregate.runSeed, 888);

      aggregate = aggregate.closeJuly(monthlyExpenses: 0);
      expect(aggregate.runSeed, 888);

      for (var i = 0; i < 7; i++) {
        aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 0);
      }
      expect(aggregate.runSeed, 888);
      expect(aggregate.state.month, 15);
    });

    test('an unrelated copyWith call never changes runSeed', () {
      final state = PublicDemoState.aprilStart(
        runSeed: 4242,
      ).copyWith(cash: 1000000, month: 6);

      expect(state.runSeed, 4242);
    });
  });

  group('save round trip', () {
    const codec = PublicDemoSaveCodec();

    test('runSeed round trips exactly through PublicDemoState JSON', () {
      final state = PublicDemoState.aprilStart(runSeed: 314159);
      final restored = PublicDemoState.fromJson(state.toJson());

      expect(restored.runSeed, 314159);
    });

    test('runSeed round trips exactly through the strict save codec', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 271828);
      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(restored!.runSeed, 271828);
    });

    test('reload after a mutating command still carries the same runSeed', () {
      final aggregate = PublicDemoAggregate.initial(
        runSeed: 161803,
      ).closeApril(monthlyExpenses: 0);
      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(restored!.runSeed, 161803);
      expect(restored.state.month, aggregate.state.month);
    });
  });

  group('legacy save migration (a save persisted before runSeed existed)', () {
    const codec = PublicDemoSaveCodec();

    test('a save envelope with no runSeed key at all is still accepted', () {
      final envelope = codec.toJson(PublicDemoAggregate.initial());
      final legacy = _removeRunSeed(envelope);

      final restored = codec.fromJson(legacy);

      expect(restored, isNotNull);
      expect(restored!.state.runSeed, isNonNegative);
    });

    test(
      'the same legacy payload always migrates to the exact same runSeed '
      '(deterministic — reload before any post-migration save still agrees)',
      () {
        final envelope = codec.toJson(PublicDemoAggregate.initial());
        final legacy = _removeRunSeed(envelope);

        final first = codec.fromJson(legacy);
        final second = codec.fromJson(legacy);

        expect(first, isNotNull);
        expect(second, isNotNull);
        expect(first!.state.runSeed, second!.state.runSeed);
      },
    );

    test(
      'two different legacy payloads migrate to two different runSeeds',
      () {
        final baseline = codec.toJson(PublicDemoAggregate.initial());
        final legacyA = _removeRunSeed(baseline);
        final legacyB = _removeRunSeed(
          _withCash(baseline, cash: 1234567),
        );

        final restoredA = codec.fromJson(legacyA);
        final restoredB = codec.fromJson(legacyB);

        expect(restoredA, isNotNull);
        expect(restoredB, isNotNull);
        expect(restoredA!.state.runSeed, isNot(restoredB!.state.runSeed));
      },
    );

    test(
      'every other field of a legacy save is preserved exactly, unchanged '
      'by migration',
      () {
        final aggregate = PublicDemoAggregate.initial()
            .startSkillSheetReview('eng-01')
            .closeApril(monthlyExpenses: 0);
        final legacy = _removeRunSeed(codec.toJson(aggregate));

        final restored = codec.fromJson(legacy);

        expect(restored, isNotNull);
        expect(restored!.state.month, aggregate.state.month);
        expect(restored.state.cash, aggregate.state.cash);
        expect(
          restored.workflow.engineers.first.stage,
          aggregate.workflow.engineers.first.stage,
        );
      },
    );

    test('a save that already has a genuine runSeed is unaffected', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 555);
      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(restored!.state.runSeed, 555);
    });

    test('a save with a corrupted (non-int) runSeed is migrated, not rejected', () {
      final envelope = codec.toJson(PublicDemoAggregate.initial());
      final corrupted = _withRunSeed(envelope, 'not-an-int');

      final restored = codec.fromJson(corrupted);

      expect(restored, isNotNull);
      expect(restored!.state.runSeed, isNonNegative);
    });

    test(
      'every OTHER kind of missing/normalized field is still rejected as a '
      'whole save, exactly as before this field existed',
      () {
        final envelope = codec.toJson(PublicDemoAggregate.initial());
        final normalized = _withPendingRevenue(envelope, -1);

        expect(codec.fromJson(normalized), isNull);
      },
    );
  });
}

Map<String, dynamic> _removeRunSeed(Map<String, dynamic> envelope) {
  final aggregate = Map<String, dynamic>.from(
    envelope['aggregate'] as Map<String, dynamic>,
  );
  final state = Map<String, dynamic>.from(
    aggregate['state'] as Map<String, dynamic>,
  )..remove('runSeed');
  return {...envelope, 'aggregate': {...aggregate, 'state': state}};
}

Map<String, dynamic> _withRunSeed(
  Map<String, dynamic> envelope,
  Object value,
) {
  final aggregate = Map<String, dynamic>.from(
    envelope['aggregate'] as Map<String, dynamic>,
  );
  final state = Map<String, dynamic>.from(
    aggregate['state'] as Map<String, dynamic>,
  )..['runSeed'] = value;
  return {...envelope, 'aggregate': {...aggregate, 'state': state}};
}

Map<String, dynamic> _withCash(
  Map<String, dynamic> envelope, {
  required int cash,
}) {
  final aggregate = Map<String, dynamic>.from(
    envelope['aggregate'] as Map<String, dynamic>,
  );
  final state = Map<String, dynamic>.from(
    aggregate['state'] as Map<String, dynamic>,
  )..['cash'] = cash
  ..['monthOpeningCash'] = cash;
  return {...envelope, 'aggregate': {...aggregate, 'state': state}};
}

Map<String, dynamic> _withPendingRevenue(
  Map<String, dynamic> envelope,
  int value,
) {
  final aggregate = Map<String, dynamic>.from(
    envelope['aggregate'] as Map<String, dynamic>,
  );
  final state = Map<String, dynamic>.from(
    aggregate['state'] as Map<String, dynamic>,
  )..['pendingRevenue'] = value;
  return {...envelope, 'aggregate': {...aggregate, 'state': state}};
}
