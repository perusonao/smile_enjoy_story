import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/models/programming_language.dart';
import 'package:smile_enjoy_story/domain/models/sales_profile.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_growth_engine.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  PublicDemoState state() => PublicDemoState.aprilStart().copyWith(
    engineerRuntimes: [
      publicDemoInitialEngineerRuntimes.first,
      publicDemoInitialEngineerRuntimes[1].copyWith(
        industryExperience: const {Industry.finance: 4},
      ),
    ],
  );

  test('month close applies assigned and waiting growth exactly once', () {
    final before = state();
    final closed = before.applyMonthlyGrowth(
      assignedEngineerIds: const {'eng-01'},
      moraleByEngineerId: const {'eng-01': 72, 'eng-02': 64},
    );
    final assignedBefore = before.runtimeFor('eng-01');
    final assignedAfter = closed.runtimeFor('eng-01');
    final waitingBefore = before.runtimeFor('eng-02');
    final waitingAfter = closed.runtimeFor('eng-02');

    expect(
      assignedAfter
          .languageSkills[ProgrammingLanguage.java]!
          .actualExperienceMonths,
      assignedBefore
              .languageSkills[ProgrammingLanguage.java]!
              .actualExperienceMonths +
          1,
    );
    expect(
      waitingAfter
          .languageSkills[ProgrammingLanguage.javascript]!
          .actualExperienceMonths,
      waitingBefore
          .languageSkills[ProgrammingLanguage.javascript]!
          .actualExperienceMonths,
    );
    expect(
      assignedAfter.actualCapability,
      greaterThan(assignedBefore.actualCapability),
    );
    expect(
      waitingAfter.actualCapability,
      waitingBefore.actualCapability,
      reason: 'the deterministic waiting formula may round this month to 0',
    );
    expect(
      waitingAfter
          .languageSkills[ProgrammingLanguage.javascript]!
          .displayedExperienceMonths,
      waitingBefore
          .languageSkills[ProgrammingLanguage.javascript]!
          .displayedExperienceMonths,
      reason: 'SkillSheet display values are not runtime growth values',
    );
    expect(assignedAfter.industryExperience, isEmpty);
    expect(waitingAfter.industryExperience[Industry.finance], 4);

    final duplicate = closed.applyMonthlyGrowth(
      assignedEngineerIds: const {'eng-01'},
      moraleByEngineerId: const {'eng-01': 72, 'eng-02': 64},
    );
    expect(identical(duplicate, closed), isTrue);
    expect(closed.latestGrowthResults, hasLength(2));
    expect(
      closed.latestGrowthResults.first.source,
      PublicDemoGrowthSource.assignment,
    );
    expect(closed.latestGrowthResults.first.actualExperienceMonthsDelta, 1);
    expect(
      closed.latestGrowthResults[1].source,
      PublicDemoGrowthSource.waiting,
    );
    expect(closed.latestGrowthResults[1].actualExperienceMonthsDelta, 0);
  });

  test('growth results and guard round trip and old saves use defaults', () {
    final closed = state().applyMonthlyGrowth(
      assignedEngineerIds: const {'eng-01'},
      moraleByEngineerId: const {'eng-01': 72, 'eng-02': 64},
    );
    final restored = PublicDemoState.fromJson(closed.toJson());
    expect(restored.growthAppliedMonths, [4]);
    expect(
      restored.latestGrowthResults.first.capabilityAfter,
      closed.latestGrowthResults.first.capabilityAfter,
    );

    final oldJson = state().toJson()
      ..remove('latestGrowthResults')
      ..remove('growthAppliedMonths');
    final old = PublicDemoState.fromJson(oldJson);
    expect(old.latestGrowthResults, isEmpty);
    expect(old.growthAppliedMonths, isEmpty);
  });
}
