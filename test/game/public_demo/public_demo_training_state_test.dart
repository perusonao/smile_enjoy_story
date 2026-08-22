import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  group('PublicDemoState training selections', () {
    test('April start has no selections', () {
      expect(PublicDemoState.aprilStart().trainingSelections, isEmpty);
    });

    test('selects and replaces internal and external training', () {
      final internal = PublicDemoState.aprilStart().selectInternalTraining(
        'eng-01',
      );
      expect(
        internal.trainingSelections,
        {'eng-01': PublicDemoGrowthSource.internalTraining},
      );

      final external = internal.selectExternalTraining('eng-01');
      expect(
        external.trainingSelections,
        {'eng-01': PublicDemoGrowthSource.externalTraining},
      );
      expect(
        external.selectInternalTraining('eng-01').trainingSelections,
        {'eng-01': PublicDemoGrowthSource.internalTraining},
      );
    });

    test('cancel removes only its target', () {
      final state = PublicDemoState.aprilStart()
          .selectInternalTraining('eng-01')
          .selectExternalTraining('eng-02')
          .cancelTraining('eng-01');
      expect(
        state.trainingSelections,
        {'eng-02': PublicDemoGrowthSource.externalTraining},
      );
    });

    test('selection does not change financial, runtime, or growth state', () {
      final before = PublicDemoState.aprilStart().copyWith(
        growthAppliedMonths: const [4],
      );
      final after = before.selectInternalTraining('eng-01');
      expect(after.cash, before.cash);
      expect(after.engineerRuntimes, same(before.engineerRuntimes));
      expect(after.growthAppliedMonths, before.growthAppliedMonths);
    });

    test('JSON round trips multiple selections and defensively copies maps', () {
      final source = {
        'eng-01': PublicDemoGrowthSource.internalTraining,
        'eng-02': PublicDemoGrowthSource.externalTraining,
      };
      final state = PublicDemoState.aprilStart().copyWith(
        trainingSelections: source,
      );
      source['eng-01'] = PublicDemoGrowthSource.assignment;

      expect(
        state.trainingSelections['eng-01'],
        PublicDemoGrowthSource.internalTraining,
      );
      expect(
        PublicDemoState.fromJson(state.toJson()).trainingSelections,
        state.trainingSelections,
      );
    });

    test('old and malformed JSON safely use only valid training sources', () {
      final oldJson = PublicDemoState.aprilStart().toJson()
        ..remove('trainingSelections');
      expect(PublicDemoState.fromJson(oldJson).trainingSelections, isEmpty);

      final malformed = PublicDemoState.aprilStart().toJson()
        ..['trainingSelections'] = {
          'unknown-engineer': 'externalTraining',
          'eng-01': 'assignment',
          'eng-02': 'waiting',
          'eng-03': 'notARealSource',
          'eng-04': 123,
        };
      expect(PublicDemoState.fromJson(malformed).trainingSelections, {
        'unknown-engineer': PublicDemoGrowthSource.externalTraining,
      });
    });

    test('constructor and copyWith reject non-training sources', () {
      final state = PublicDemoState.aprilStart().copyWith(
        trainingSelections: const {
          'eng-01': PublicDemoGrowthSource.assignment,
          'eng-02': PublicDemoGrowthSource.waiting,
          'eng-03': PublicDemoGrowthSource.internalTraining,
        },
      );
      expect(state.trainingSelections, {
        'eng-03': PublicDemoGrowthSource.internalTraining,
      });
    });
  });
}
