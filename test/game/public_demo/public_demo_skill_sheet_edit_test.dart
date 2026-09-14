import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/models/programming_language.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';

/// SES First Fun Quarter Mission Phase 3 (SkillSheet Editing): domain-level
/// coverage for [PublicDemoAggregate.confirmSkillSheetEdit] /
/// [PublicDemoState.updateDisplayedExperience] /
/// [PublicDemoEngineerSales.salesProfileEditConfirmed] — the authority this
/// feature adds. Mirrors every other Public Demo domain test's own
/// convention: real command chains from [PublicDemoAggregate.initial],
/// never a hand-built state shortcut, plus a real save-codec round-trip for
/// persistence coverage.
void main() {
  group('updateDisplayedExperience only ever touches the displayed figure', () {
    test(
      'eng-01: displayed experience changes, actual experience/capability/'
      'techSkills/interview profile/Fit-relevant fields do not',
      () {
        final before = PublicDemoAggregate.initial();
        final beforeRuntime = before.state.runtimeFor('eng-01');
        final beforeSkill = beforeRuntime.languageSkills[ProgrammingLanguage.java]!;

        final after = before.confirmSkillSheetEdit(
          engineerId: 'eng-01',
          displayedMonths: 60,
        );
        final afterRuntime = after.state.runtimeFor('eng-01');
        final afterSkill = afterRuntime.languageSkills[ProgrammingLanguage.java]!;

        expect(afterSkill.displayedExperienceMonths, 60);
        expect(afterSkill.actualExperienceMonths, beforeSkill.actualExperienceMonths);
        expect(afterSkill.actualSkill, beforeSkill.actualSkill);
        expect(afterRuntime.actualCapability, beforeRuntime.actualCapability);
        expect(afterRuntime.techSkills.toJson(), beforeRuntime.techSkills.toJson());
        expect(afterRuntime.totalItExperienceMonths, beforeRuntime.totalItExperienceMonths);

        final beforeEngineer = before.workflow.engineers.firstWhere(
          (e) => e.id == 'eng-01',
        );
        final afterEngineer = after.workflow.engineers.firstWhere(
          (e) => e.id == 'eng-01',
        );
        expect(afterEngineer.interviewProfile.skillFit, beforeEngineer.interviewProfile.skillFit);
        expect(afterEngineer.interviewProfile.humanity, beforeEngineer.interviewProfile.humanity);
        expect(afterEngineer.interviewProfile.morale, beforeEngineer.interviewProfile.morale);
        expect(
          afterEngineer.interviewProfile.clientTrust,
          beforeEngineer.interviewProfile.clientTrust,
        );
        expect(afterEngineer.stage, beforeEngineer.stage);
      },
    );

    test('a value above the inflation ceiling is clamped, never rejected', () {
      final aggregate = PublicDemoAggregate.initial().confirmSkillSheetEdit(
        engineerId: 'eng-01',
        displayedMonths: 999999,
      );
      final skill = aggregate.state
          .runtimeFor('eng-01')
          .languageSkills[ProgrammingLanguage.java]!;
      expect(
        skill.displayedExperienceMonths,
        skill.actualExperienceMonths +
            PublicDemoEngineerRuntime.maxDisplayedExperienceInflationMonths,
      );
    });

    test('a negative value is clamped to 0, never stored negative', () {
      final aggregate = PublicDemoAggregate.initial().confirmSkillSheetEdit(
        engineerId: 'eng-01',
        displayedMonths: -50,
      );
      expect(
        aggregate.state
            .runtimeFor('eng-01')
            .languageSkills[ProgrammingLanguage.java]!
            .displayedExperienceMonths,
        0,
      );
    });

    test('an unknown engineer id is a no-op on both halves of the aggregate', () {
      final before = PublicDemoAggregate.initial();
      final after = before.confirmSkillSheetEdit(
        engineerId: 'no-such-engineer',
        displayedMonths: 60,
      );
      expect(after.state.toJson(), before.state.toJson());
      expect(after.workflow.toJson(), before.workflow.toJson());
    });
  });

  group('engineer A/B independence', () {
    test('editing eng-01 never touches eng-02\'s displayed experience or confirmed flag', () {
      final before = PublicDemoAggregate.initial();
      final after = before.confirmSkillSheetEdit(
        engineerId: 'eng-01',
        displayedMonths: 60,
      );

      final eng02Before = before.state
          .runtimeFor('eng-02')
          .languageSkills[ProgrammingLanguage.javascript]!;
      final eng02After = after.state
          .runtimeFor('eng-02')
          .languageSkills[ProgrammingLanguage.javascript]!;
      expect(eng02After.displayedExperienceMonths, eng02Before.displayedExperienceMonths);

      expect(
        after.workflow.engineers.firstWhere((e) => e.id == 'eng-02').salesProfileEditConfirmed,
        isFalse,
      );
      expect(
        after.workflow.engineers.firstWhere((e) => e.id == 'eng-01').salesProfileEditConfirmed,
        isTrue,
      );
    });
  });

  group('salesProfileEditConfirmed authority', () {
    test('false by default, for every founding engineer, before any edit', () {
      final aggregate = PublicDemoAggregate.initial();
      expect(
        aggregate.workflow.engineers.every((e) => !e.salesProfileEditConfirmed),
        isTrue,
      );
    });

    test('confirmSkillSheetEdit sets it true even when the saved value equals the old one', () {
      final before = PublicDemoAggregate.initial();
      final unchanged = before.state
          .runtimeFor('eng-01')
          .languageSkills[ProgrammingLanguage.java]!
          .displayedExperienceMonths;
      final after = before.confirmSkillSheetEdit(
        engineerId: 'eng-01',
        displayedMonths: unchanged,
      );
      expect(
        after.state
            .runtimeFor('eng-01')
            .languageSkills[ProgrammingLanguage.java]!
            .displayedExperienceMonths,
        unchanged,
      );
      expect(
        after.workflow.engineers.firstWhere((e) => e.id == 'eng-01').salesProfileEditConfirmed,
        isTrue,
      );
    });

    test('never set by any other engineer command (beginSelling alone does not confirm it)', () {
      final aggregate = PublicDemoAggregate.initial()
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01');
      expect(
        aggregate.workflow.engineers.firstWhere((e) => e.id == 'eng-01').salesProfileEditConfirmed,
        isFalse,
      );
    });
  });

  group('save/reload persistence (no schema bump — additive fields only)', () {
    const codec = PublicDemoSaveCodec();

    test('displayedExperienceMonths and salesProfileEditConfirmed both survive a round trip', () {
      final aggregate = PublicDemoAggregate.initial().confirmSkillSheetEdit(
        engineerId: 'eng-01',
        displayedMonths: 60,
      );
      final restored = codec.decode(codec.encode(aggregate));
      expect(restored, isNotNull);
      expect(
        restored!.state
            .runtimeFor('eng-01')
            .languageSkills[ProgrammingLanguage.java]!
            .displayedExperienceMonths,
        60,
      );
      expect(
        restored.workflow.engineers.firstWhere((e) => e.id == 'eng-01').salesProfileEditConfirmed,
        isTrue,
      );
    });

    test(
      'a legacy engineer JSON with no salesProfileEditConfirmed key at all '
      'decodes to false, not a crash — additive default, no migration flag '
      'needed for the field this feature already reused',
      () {
        final aggregate = PublicDemoAggregate.initial();
        final envelope = codec.toJson(aggregate);
        final aggregateJson = (envelope['aggregate'] as Map).cast<String, dynamic>();
        final workflowJson = (aggregateJson['workflow'] as Map).cast<String, dynamic>();
        final engineersJson = (workflowJson['engineers'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        for (final engineer in engineersJson) {
          engineer.remove('salesProfileEditConfirmed');
        }
        workflowJson['engineers'] = engineersJson;
        aggregateJson['workflow'] = workflowJson;
        envelope['aggregate'] = aggregateJson;

        final restored = PublicDemoAggregate.fromJson(aggregateJson);
        expect(
          restored.workflow.engineers.every((e) => !e.salesProfileEditConfirmed),
          isTrue,
        );
      },
    );

    test(
      'a malformed legacy displayedExperienceMonths (negative) is rejected '
      'by decode() as a whole, exactly like any other corrupt save — never '
      'a crash and never a silently-accepted negative experience figure',
      () {
        final aggregate = PublicDemoAggregate.initial();
        final envelope = codec.toJson(aggregate);
        final aggregateJson = (envelope['aggregate'] as Map).cast<String, dynamic>();
        final stateJson = (aggregateJson['state'] as Map).cast<String, dynamic>();
        final runtimesJson = (stateJson['engineerRuntimes'] as List)
            .map((r) => (r as Map).cast<String, dynamic>())
            .toList();
        final eng01Runtime = runtimesJson.firstWhere(
          (r) => r['engineerId'] == 'eng-01',
        );
        final languageSkillsJson = (eng01Runtime['languageSkills'] as Map)
            .cast<String, dynamic>();
        final javaSkillJson = (languageSkillsJson['java'] as Map)
            .cast<String, dynamic>();
        javaSkillJson['displayedExperienceMonths'] = -12;
        languageSkillsJson['java'] = javaSkillJson;
        eng01Runtime['languageSkills'] = languageSkillsJson;
        stateJson['engineerRuntimes'] = runtimesJson;
        aggregateJson['state'] = stateJson;
        envelope['aggregate'] = aggregateJson;

        final restored = codec.decode(jsonEncode(envelope));
        expect(restored, isNull);
      },
    );
  });
}
