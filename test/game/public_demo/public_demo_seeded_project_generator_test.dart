import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';

/// CORE-GAMEPLAY Phase 4 (Random Projects): coverage specific to
/// [PublicDemoSeededProjectGenerator] -- the seeded reuse of the main
/// engine's `ProjectGenerator`/`Project` for Public Demo project candidates.
/// See `docs/reports/SES_CORE-GAMEPLAY_Phase4_Random-Projects_Result.md`.
void main() {
  group('same seed -> same candidates', () {
    test('identical (runSeed, month) reproduces byte-identical candidates '
        'on every call', () {
      final first = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 12345,
        month: 4,
        count: 4,
      );
      final second = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 12345,
        month: 4,
        count: 4,
      );

      expect(
        first.map((c) => c.project.toJson()).toList(),
        second.map((c) => c.project.toJson()).toList(),
      );
      expect(
        first.map((c) => c.client.id).toList(),
        second.map((c) => c.client.id).toList(),
      );
    });

    test('reload semantics: calling forMonth() again later (as a reload '
        'would) yields the same candidates, never a re-roll', () {
      List<String> titlesFor(int runSeed) =>
          PublicDemoSeededProjectGenerator.forMonth(
            runSeed: runSeed,
            month: 6,
            count: 3,
          ).map((c) => c.title).toList();

      final before = titlesFor(555);
      // Simulate "time passing"/other draws happening elsewhere before the
      // player reloads and looks at the same listing again.
      PublicDemoSeededProjectGenerator.forMonth(runSeed: 1, month: 4, count: 4);
      final afterReload = titlesFor(555);

      expect(afterReload, before);
    });
  });

  group('different seed -> candidate variation', () {
    test('different runSeed changes the generated project composition', () {
      final seedA = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 1,
        month: 4,
        count: 4,
      );
      final seedB = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 2,
        month: 4,
        count: 4,
      );

      expect(
        seedA.map((c) => c.project.toJson()).toList(),
        isNot(seedB.map((c) => c.project.toJson()).toList()),
      );
    });

    test('a spread of runSeeds produces more than one distinct project '
        'title for the same month/slot -- variety is real', () {
      final titles = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        final candidates = PublicDemoSeededProjectGenerator.forMonth(
          runSeed: seed,
          month: 4,
          count: 1,
        );
        titles.add(candidates.single.title);
      }
      expect(titles.length, greaterThan(1));
    });
  });

  group('generation order independence', () {
    test('a later slot never perturbs an earlier slot\'s own draw', () {
      final withOne = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 42,
        month: 4,
        count: 1,
      );
      final withMany = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 42,
        month: 4,
        count: 5,
      );

      expect(withMany.first.project.toJson(), withOne.single.project.toJson());
    });

    test('a middle slot is identical whether requested alone or as part of '
        'a larger batch', () {
      final alone = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 7,
        month: 8,
        count: 3,
      );
      final larger = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 7,
        month: 8,
        count: 6,
      );

      expect(larger[2].project.toJson(), alone[2].project.toJson());
    });
  });

  group('stable unique IDs', () {
    test('id encodes (month, slot) and does not depend on runSeed', () {
      final withSeedA = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 10,
        month: 7,
        count: 2,
      );
      final withSeedB = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 999,
        month: 7,
        count: 2,
      );

      expect(withSeedA[0].id, 'project-7-1');
      expect(withSeedA[1].id, 'project-7-2');
      expect(withSeedB[0].id, withSeedA[0].id);
      expect(withSeedB[1].id, withSeedA[1].id);
    });

    test('ids within one month are unique across slots', () {
      final candidates = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 3,
        month: 4,
        count: 6,
      );
      final ids = candidates.map((c) => c.id).toSet();
      expect(ids.length, candidates.length);
    });
  });

  group('regeneration by id', () {
    test('regenerate(id) recovers the exact candidate forMonth produced', () {
      final generated = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 321,
        month: 9,
        count: 4,
      );
      for (final candidate in generated) {
        final recovered = PublicDemoSeededProjectGenerator.regenerate(
          runSeed: 321,
          projectId: candidate.id,
        );
        expect(recovered, isNotNull);
        expect(recovered!.project.toJson(), candidate.project.toJson());
        expect(recovered.client.id, candidate.client.id);
      }
    });

    test('regenerate() returns null for an id this generator did not mint', () {
      expect(
        PublicDemoSeededProjectGenerator.regenerate(
          runSeed: 1,
          projectId: 'not-a-project-id',
        ),
        isNull,
      );
      expect(
        PublicDemoSeededProjectGenerator.regenerate(
          runSeed: 1,
          projectId: 'project-abc-1',
        ),
        isNull,
      );
    });
  });

  group('sensible Project projection', () {
    test('every generated candidate carries the minimum required fields '
        'with sane values', () {
      for (var seed = 0; seed < 20; seed++) {
        final candidates = PublicDemoSeededProjectGenerator.forMonth(
          runSeed: seed,
          month: 4,
          count: 4,
        );
        for (final candidate in candidates) {
          expect(candidate.title, isNotEmpty);
          expect(candidate.monthlyRate, greaterThan(0));
          expect(candidate.requiredExperienceMonths, greaterThanOrEqualTo(0));
          expect(candidate.difficulty, inInclusiveRange(1, 5));
          expect(sampleClients.map((c) => c.id), contains(candidate.client.id));
          expect(candidate.clientName, candidate.client.name);
          expect(candidate.clientTendency, candidate.client.specialty);
        }
      }
    });

    test('requiredExperienceMonths matches the canonical rank mapping', () {
      final candidates = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 55,
        month: 4,
        count: 10,
      );
      for (final candidate in candidates) {
        expect(
          candidate.requiredExperienceMonths,
          projectRankMinimumExperienceMonths[candidate.rank],
        );
      }
    });
  });

  group('April viable-project guard (Balance Guard)', () {
    bool isRealisticallyTargetable(Project project, PublicDemoEngineerRuntime engineer) {
      final experience =
          engineer.languageSkills[engineer.primaryLanguage]?.actualExperienceMonths ?? 0;
      if (project.requiredExperienceMonths > experience) return false;
      if (project.requiredLanguages.isNotEmpty &&
          !project.requiredLanguages.contains(engineer.primaryLanguage)) {
        return false;
      }
      final tech = engineer.techSkills;
      final requirements = [
        (project.requiredDatabase, tech.database),
        (project.requiredNetwork, tech.network),
        (project.requiredInfrastructure, tech.infrastructure),
        (project.requiredFrontend, tech.frontend),
        (project.requiredBackend, tech.backend),
        (project.requiredLeader, tech.leader),
        (project.requiredManager, tech.manager),
      ];
      return requirements.every((pair) => pair.$1 <= pair.$2);
    }

    test('every runSeed in a wide sweep offers at least one April project '
        'a founding employee could realistically target', () {
      for (var seed = 0; seed < 500; seed++) {
        final candidates = PublicDemoSeededProjectGenerator.forMonth(
          runSeed: seed,
          month: 4,
        );
        final hasViableProject = candidates.any(
          (candidate) => publicDemoInitialEngineerRuntimes.any(
            (engineer) => isRealisticallyTargetable(candidate.project, engineer),
          ),
        );
        expect(
          hasViableProject,
          isTrue,
          reason: 'runSeed=$seed produced no realistically-targetable April project',
        );
      }
    });

    test('the guaranteed slot (slot 0) alone is always realistically '
        'targetable in April, independent of any other slot', () {
      for (var seed = 0; seed < 200; seed++) {
        final candidates = PublicDemoSeededProjectGenerator.forMonth(
          runSeed: seed,
          month: 4,
          count: 1,
        );
        final slotZero = candidates.single.project;
        final viable = publicDemoInitialEngineerRuntimes.any(
          (engineer) => isRealisticallyTargetable(slotZero, engineer),
        );
        expect(viable, isTrue, reason: 'runSeed=$seed slot 0 not viable');
      }
    });
  });

  group('persistence / reload compatibility', () {
    const codec = PublicDemoSaveCodec();

    test('a save/reload round trip changes nothing about the persisted '
        'aggregate JSON (no new fields added for project generation)', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 777);
      final before = codec.toJson(aggregate);
      final reloaded = codec.decode(codec.encode(aggregate));
      expect(reloaded, isNotNull);
      expect(codec.toJson(reloaded!), before);
    });

    test('projectCandidatesForMonth() is identical before and after a save/ '
        'reload round trip, purely because it is re-derived from runSeed, '
        'never persisted', () {
      final aggregate = PublicDemoAggregate.initial(runSeed: 2026);
      final before = aggregate
          .projectCandidatesForMonth(4)
          .map((c) => c.project.toJson())
          .toList();

      final reloaded = codec.decode(codec.encode(aggregate))!;
      final after = reloaded
          .projectCandidatesForMonth(4)
          .map((c) => c.project.toJson())
          .toList();

      expect(after, before);
    });

    test('legacy save compatibility: a save encoded before this generator '
        'existed (no project-related key of any kind) still decodes and '
        'immediately supports projectCandidatesForMonth()', () {
      // Every existing save is already "legacy" by construction here: this
      // phase added zero new persisted fields anywhere in the envelope, so
      // any aggregate encoded by the pre-Phase-4 codec shape (which is
      // exactly what `codec.encode` still produces, unchanged) exercises
      // the same guarantee a save from before this phase would.
      final aggregate = PublicDemoAggregate.initial(runSeed: 4242);
      final raw = codec.encode(aggregate);

      final reloaded = codec.decode(raw);
      expect(reloaded, isNotNull);
      expect(reloaded!.projectCandidatesForMonth(4), isNotEmpty);
    });
  });
}
