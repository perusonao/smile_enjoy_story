import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_candidate_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';

/// CORE-GAMEPLAY Phase 2 (seeded recruitment): coverage specific to
/// [PublicDemoSeededRecruitmentGenerator] -- the seeded reuse of the main
/// engine's `ApplicantGenerator` that replaced
/// `PublicDemoRecruitmentCalculation`'s old fixed/cyclic template pool. See
/// `docs/reports/SES_CORE-GAMEPLAY_Phase2_Random-Recruitment_Result.md`.
void main() {
  group('same seed -> same candidates', () {
    test('identical (runSeed, month, medium) reproduces byte-identical '
        'candidates on every call', () {
      final first = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 12345,
        month: 4,
        medium: PublicDemoRecruitmentMedium.engineer,
        count: 2,
      );
      final second = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 12345,
        month: 4,
        medium: PublicDemoRecruitmentMedium.engineer,
        count: 2,
      );

      expect(
        first.map((a) => a.toJson()).toList(),
        second.map((a) => a.toJson()).toList(),
      );
    });

    test('reload semantics: calling generate() again later (as a reload '
        'would) yields the same candidate, never a re-roll', () {
      List<String> namesFor(int runSeed) =>
          PublicDemoSeededRecruitmentGenerator.generate(
            runSeed: runSeed,
            month: 6,
            medium: PublicDemoRecruitmentMedium.free,
            count: 1,
          ).map((a) => a.name).toList();

      final before = namesFor(555);
      // Simulate "time passing"/other draws happening elsewhere before the
      // player reloads and looks at the same listing again.
      PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 1,
        month: 4,
        medium: PublicDemoRecruitmentMedium.engineer,
        count: 2,
      );
      final afterReload = namesFor(555);

      expect(afterReload, before);
    });
  });

  group('different seed -> candidate variation', () {
    test('different runSeed changes the generated candidate composition', () {
      final seedA = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 1,
        month: 4,
        medium: PublicDemoRecruitmentMedium.engineer,
        count: 2,
      );
      final seedB = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 2,
        month: 4,
        medium: PublicDemoRecruitmentMedium.engineer,
        count: 2,
      );

      expect(
        seedA.map((a) => a.toJson()).toList(),
        isNot(seedB.map((a) => a.toJson()).toList()),
      );
    });

    test('a spread of runSeeds produces more than one distinct candidate '
        'name for the same (month, medium) -- variety is real, not a '
        'relabeled constant pool', () {
      final names = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        final applicants = PublicDemoSeededRecruitmentGenerator.generate(
          runSeed: seed,
          month: 4,
          medium: PublicDemoRecruitmentMedium.free,
          count: 1,
        );
        names.add(applicants.single.name);
      }
      expect(names.length, greaterThan(5));
    });
  });

  group('generation order independence', () {
    test('a later slot never perturbs an earlier slot\'s own draw', () {
      final withOne = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 42,
        month: 4,
        medium: PublicDemoRecruitmentMedium.engineer,
        count: 1,
      );
      final withTwo = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 42,
        month: 4,
        medium: PublicDemoRecruitmentMedium.engineer,
        count: 2,
      );

      expect(withTwo.first.toJson(), withOne.single.toJson());
    });
  });

  group('candidate stable ID', () {
    test('id encodes (month, medium, slot) in the pre-existing format', () {
      final applicants = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 10,
        month: 7,
        medium: PublicDemoRecruitmentMedium.engineer,
        count: 2,
      );
      expect(applicants[0].id, 'recruitment-7-engineer-1');
      expect(applicants[1].id, 'recruitment-7-engineer-2');
    });

    test('id does not depend on runSeed -- only the content does', () {
      final a = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 1,
        month: 4,
        medium: PublicDemoRecruitmentMedium.free,
        count: 1,
      ).single;
      final b = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 2,
        month: 4,
        medium: PublicDemoRecruitmentMedium.free,
        count: 1,
      ).single;
      expect(a.id, b.id);
    });
  });

  group('inexperienced-hire path stays reachable (existing authority)', () {
    test('free medium can still produce both an inexperienced and an '
        'experienced candidate across a spread of seeds/months', () {
      var sawInexperienced = false;
      var sawExperienced = false;
      for (
        var seed = 0;
        seed < 20 && !(sawInexperienced && sawExperienced);
        seed++
      ) {
        for (var month = 4; month <= 8; month++) {
          final applicant = PublicDemoSeededRecruitmentGenerator.generate(
            runSeed: seed,
            month: month,
            medium: PublicDemoRecruitmentMedium.free,
            count: 1,
          ).single;
          if (applicant.isInexperienced) {
            sawInexperienced = true;
          } else {
            sawExperienced = true;
          }
        }
      }
      expect(sawInexperienced, isTrue);
      expect(sawExperienced, isTrue);
    });

    test('engineer medium never produces an inexperienced candidate', () {
      for (var seed = 0; seed < 15; seed++) {
        final applicants = PublicDemoSeededRecruitmentGenerator.generate(
          runSeed: seed,
          month: 4,
          medium: PublicDemoRecruitmentMedium.engineer,
          count: 2,
        );
        expect(applicants.every((a) => !a.isInexperienced), isTrue);
      }
    });
  });

  group('generation never fails to produce the requested count', () {
    test('count is always exactly satisfied across mediums/seeds/months', () {
      for (final medium in PublicDemoRecruitmentMedium.values) {
        for (var seed = 0; seed < 10; seed++) {
          final applicants = PublicDemoSeededRecruitmentGenerator.generate(
            runSeed: seed,
            month: 4,
            medium: medium,
            count: medium.applicantCount,
          );
          expect(applicants, hasLength(medium.applicantCount));
        }
      }
    });
  });

  group(
    'balance compatibility: salary stays within the mapped economy band',
    () {
      test('engineer medium salary stays within the mapped 260k-420k band', () {
        for (var seed = 0; seed < 25; seed++) {
          final applicants = PublicDemoSeededRecruitmentGenerator.generate(
            runSeed: seed,
            month: 4,
            medium: PublicDemoRecruitmentMedium.engineer,
            count: 2,
          );
          for (final applicant in applicants) {
            expect(
              applicant.requestedMonthlySalary,
              inInclusiveRange(260000, 420000),
            );
          }
        }
      });

      test(
        'free medium salary stays within the mapped 220k-300k band, or is '
        'exactly the entry-level anchor (220k) for an inexperienced hire',
        () {
          for (var seed = 0; seed < 25; seed++) {
            final applicant = PublicDemoSeededRecruitmentGenerator.generate(
              runSeed: seed,
              month: 4,
              medium: PublicDemoRecruitmentMedium.free,
              count: 1,
            ).single;
            if (applicant.isInexperienced) {
              expect(applicant.requestedMonthlySalary, 220000);
            } else {
              expect(
                applicant.requestedMonthlySalary,
                inInclusiveRange(220000, 300000),
              );
            }
          }
        },
      );
    },
  );

  group('regenerateDomainApplicant (Phase 3 integration point)', () {
    test(
      'recovers the exact same domain Applicant from (runSeed, id) alone',
      () {
        final generated = PublicDemoSeededRecruitmentGenerator.generate(
          runSeed: 321,
          month: 4,
          medium: PublicDemoRecruitmentMedium.engineer,
          count: 2,
        );
        for (final applicant in generated) {
          final regenerated =
              PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
                runSeed: 321,
                applicantId: applicant.id,
              );
          expect(regenerated, isNotNull);
          expect(regenerated!.name, applicant.name);
        }
      },
    );

    test('returns null for a legacy/hand-authored fixture id', () {
      expect(
        PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
          runSeed: 1,
          applicantId: 'app-01',
        ),
        isNull,
      );
      expect(
        PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
          runSeed: 1,
          applicantId: 'free-template-inexperienced-01',
        ),
        isNull,
      );
    });

    test('regeneration is stable across repeated calls (candidate identity '
        'cannot drift mid-interview)', () {
      final generated = PublicDemoSeededRecruitmentGenerator.generate(
        runSeed: 99,
        month: 4,
        medium: PublicDemoRecruitmentMedium.free,
        count: 1,
      ).single;
      final first =
          PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
            runSeed: 99,
            applicantId: generated.id,
          );
      final second =
          PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
            runSeed: 99,
            applicantId: generated.id,
          );
      expect(first!.toJson(), second!.toJson());
    });
  });
}
