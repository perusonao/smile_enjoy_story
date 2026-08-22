import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  test(
    'runtime serializes and round-trips without changing actual capability',
    () {
      final state = PublicDemoState.aprilStart();
      final loaded = PublicDemoState.fromJson(state.toJson());

      expect(loaded.runtimeFor('eng-01').actualCapability, 78);
      expect(loaded.toJson(), state.toJson());
    },
  );

  test(
    'old Public Demo state JSON receives deterministic runtime defaults',
    () {
      final oldSave = PublicDemoState.aprilStart().toJson()
        ..remove('engineerRuntimes');
      final loaded = PublicDemoState.fromJson(oldSave);

      expect(loaded.runtimeFor('eng-01').actualCapability, 78);
      expect(loaded.runtimeFor('eng-02').actualCapability, 52);
    },
  );

  test(
    'project evaluation reads runtime capability instead of assignment copy',
    () {
      final state = PublicDemoState.aprilStart();
      final assignment = publicDemoInitialAssignments.first;

      expect(
        assignment.willOfferNextMonthFor(
          state.runtimeFor(assignment.engineerId).actualCapability,
        ),
        isTrue,
      );
      expect(assignment.willOfferNextMonthFor(0), isFalse);
    },
  );
}
