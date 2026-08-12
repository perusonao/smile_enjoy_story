import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';

void main() {
  final clientIds = sampleClients.map((c) => c.id).toSet();

  group('ProjectGenerator validity (1000 samples)', () {
    final projects = ProjectGenerator(
      seed: 1,
      clients: sampleClients,
    ).generate(1000);

    test('monthly rate is positive and within its rank\'s configured range', () {
      for (final p in projects) {
        final range = monthlyRateRangeByRank[p.rank]!;
        expect(p.monthlyRate, greaterThan(0));
        expect(
          p.monthlyRate,
          inInclusiveRange(range.min, range.max),
          reason:
              '${p.id} (${p.rank}) rate ${p.monthlyRate} out of [${range.min}, ${range.max}]',
        );
      }
    });

    test('duration in weeks is always positive', () {
      for (final p in projects) {
        expect(p.durationWeeks, greaterThan(0));
      }
    });

    test('required skill levels stay within their declared ranges', () {
      for (final p in projects) {
        for (final v in [
          p.requiredDatabase,
          p.requiredNetwork,
          p.requiredInfrastructure,
          p.requiredFrontend,
          p.requiredBackend,
          p.requiredLeader,
          p.requiredManager,
        ]) {
          expect(v, inInclusiveRange(0, 5));
        }
        expect(p.requiredJapaneseLevel, inInclusiveRange(1, 5));
        expect(p.difficulty, inInclusiveRange(1, 5));
        expect(p.interviewCount, greaterThanOrEqualTo(1));
      }
    });

    test('clientId always references a known client', () {
      for (final p in projects) {
        expect(
          clientIds.contains(p.clientId),
          isTrue,
          reason: 'unknown clientId ${p.clientId}',
        );
      }
    });

    test('rank and monthly rate never contradict each other', () {
      // Ranks are ordered by seniority; a strictly-lower rank must never
      // out-earn a strictly-higher one at the range level.
      for (var i = 0; i < projectRankOrder.length - 1; i++) {
        final lower = monthlyRateRangeByRank[projectRankOrder[i]]!;
        final higher = monthlyRateRangeByRank[projectRankOrder[i + 1]]!;
        expect(lower.min, lessThanOrEqualTo(higher.min));
      }
      // And every generated project's rate falls inside its own rank range
      // (already checked above), which together with the monotonic ranges
      // guarantees no large rank/rate mismatch can occur.
    });

    test('required skills line up with the project type', () {
      for (final p in projects) {
        switch (p.type) {
          case ProjectType.javaBusiness:
            expect(p.requiredLanguages, contains(ProgrammingLanguage.java));
            expect(p.requiredBackend, greaterThanOrEqualTo(2));
            break;
          case ProjectType.frontend:
            expect(p.requiredFrontend, greaterThanOrEqualTo(3));
            expect(
              p.requiredLanguages.any(
                (l) =>
                    l == ProgrammingLanguage.javascript ||
                    l == ProgrammingLanguage.typescript,
              ),
              isTrue,
            );
            break;
          case ProjectType.infrastructure:
            expect(p.requiredInfrastructure, greaterThanOrEqualTo(3));
            expect(p.requiredNetwork, greaterThanOrEqualTo(2));
            break;
          case ProjectType.webBackend:
            expect(p.requiredBackend, greaterThanOrEqualTo(2));
            expect(p.requiredLanguages, isNotEmpty);
            break;
          case ProjectType.testSupport:
            expect(p.difficulty, lessThanOrEqualTo(testSupportMaxDifficulty));
            break;
          case ProjectType.pl:
            expect(p.requiredLeader, greaterThanOrEqualTo(2));
            expect(p.requiredManager, greaterThanOrEqualTo(1));
            break;
        }
      }
    });

    test('every generated id is unique', () {
      final ids = projects.map((p) => p.id).toSet();
      expect(ids.length, projects.length);
    });
  });

  group('ProjectGenerator distribution (5000 samples)', () {
    final projects = ProjectGenerator(
      seed: 99,
      clients: sampleClients,
    ).generate(5000);

    test('project type distribution roughly matches configured base weights', () {
      // Sample against a single neutral client (no per-type bias) so the
      // base weights in project_distribution.dart are what's being checked.
      final neutralClient = sampleClients.firstWhere(
        (c) => c.projectTypeWeights.isEmpty,
      );
      final neutralProjects = ProjectGenerator(
        seed: 123,
        clients: [neutralClient],
      ).generate(5000);
      final counts = <ProjectType, int>{};
      for (final p in neutralProjects) {
        counts[p.type] = (counts[p.type] ?? 0) + 1;
      }
      const tolerance = 0.05;
      projectTypeWeights.forEach((type, expectedShare) {
        final actualShare = (counts[type] ?? 0) / neutralProjects.length;
        expect(
          actualShare,
          closeTo(expectedShare, tolerance),
          reason:
              '$type expected ~${expectedShare * 100}%, got ${actualShare * 100}%',
        );
      });
    });

    test(
      'every configured client appears at least once with enough samples',
      () {
        final seenClients = projects.map((p) => p.clientId).toSet();
        expect(seenClients.length, sampleClients.length);
      },
    );
  });

  group('ProjectGenerator seed reproducibility', () {
    test('same seed produces identical projects in the same order', () {
      final a = ProjectGenerator(
        seed: 555,
        clients: sampleClients,
      ).generate(200);
      final b = ProjectGenerator(
        seed: 555,
        clients: sampleClients,
      ).generate(200);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].toJson(), equals(b[i].toJson()));
      }
    });

    test('different seeds produce different projects', () {
      final a = ProjectGenerator(seed: 1, clients: sampleClients).generate(50);
      final b = ProjectGenerator(seed: 2, clients: sampleClients).generate(50);
      final differences = List.generate(
        50,
        (i) => a[i].toJson().toString() != b[i].toJson().toString(),
      ).where((d) => d).length;
      expect(differences, greaterThan(0));
    });
  });
}
