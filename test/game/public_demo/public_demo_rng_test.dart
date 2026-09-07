import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_rng.dart';

/// SEEDED-RNG-REUSE-1 Phase 1: [PublicDemoRng] is not called by any
/// production generator yet (recruitment/project generation stay on their
/// existing deterministic templates until Phase 2/3 rewires them — see
/// `PublicDemoRecruitmentCalculation._generateApplicants`'s own doc). These
/// tests exercise the adapter's own contract in isolation so Phase 2/3 can
/// rely on it without re-deriving these guarantees themselves.
void main() {
  group('PublicDemoRng.derivedSeed', () {
    test('same (runSeed, month, namespace, identifier) always agrees', () {
      final a = PublicDemoRng.derivedSeed(
        runSeed: 12345,
        month: 5,
        namespace: PublicDemoRngNamespace.recruitmentCandidate,
        identifier: 'app-01',
      );
      final b = PublicDemoRng.derivedSeed(
        runSeed: 12345,
        month: 5,
        namespace: PublicDemoRngNamespace.recruitmentCandidate,
        identifier: 'app-01',
      );

      expect(a, b);
    });

    test('a different runSeed changes the derived stream deterministically', () {
      final fromSeed1 = PublicDemoRng.derivedSeed(
        runSeed: 1,
        month: 5,
        namespace: PublicDemoRngNamespace.recruitmentCandidate,
        identifier: 'app-01',
      );
      final fromSeed2 = PublicDemoRng.derivedSeed(
        runSeed: 2,
        month: 5,
        namespace: PublicDemoRngNamespace.recruitmentCandidate,
        identifier: 'app-01',
      );

      expect(fromSeed1, isNot(fromSeed2));
      // Still deterministic for its own runSeed — not merely "different".
      expect(
        PublicDemoRng.derivedSeed(
          runSeed: 1,
          month: 5,
          namespace: PublicDemoRngNamespace.recruitmentCandidate,
          identifier: 'app-01',
        ),
        fromSeed1,
      );
    });

    test('a different month changes the derived stream', () {
      final month5 = PublicDemoRng.derivedSeed(
        runSeed: 999,
        month: 5,
        namespace: PublicDemoRngNamespace.recruitmentCandidate,
        identifier: 'app-01',
      );
      final month6 = PublicDemoRng.derivedSeed(
        runSeed: 999,
        month: 6,
        namespace: PublicDemoRngNamespace.recruitmentCandidate,
        identifier: 'app-01',
      );

      expect(month5, isNot(month6));
    });

    test('a different identifier changes the derived stream', () {
      final app01 = PublicDemoRng.derivedSeed(
        runSeed: 999,
        month: 5,
        namespace: PublicDemoRngNamespace.recruitmentCandidate,
        identifier: 'app-01',
      );
      final app02 = PublicDemoRng.derivedSeed(
        runSeed: 999,
        month: 5,
        namespace: PublicDemoRngNamespace.recruitmentCandidate,
        identifier: 'app-02',
      );

      expect(app01, isNot(app02));
    });

    test(
      'namespace independence: every namespace draws its own stream for the '
      'exact same month/identifier, so one future generator can never '
      'perturb another',
      () {
        final seeds = {
          for (final namespace in PublicDemoRngNamespace.values)
            namespace: PublicDemoRng.derivedSeed(
              runSeed: 42,
              month: 7,
              namespace: namespace,
              identifier: 'eng-01',
            ),
        };

        expect(seeds.values.toSet(), hasLength(PublicDemoRngNamespace.values.length));
      },
    );

    test(
      'order independence: interleaving draws from two namespaces never '
      'changes either one\'s own result — no shared mutable state',
      () {
        final candidateFirst = PublicDemoRng.derivedSeed(
          runSeed: 7,
          month: 4,
          namespace: PublicDemoRngNamespace.recruitmentCandidate,
          identifier: 'x',
        );
        final interviewFirst = PublicDemoRng.derivedSeed(
          runSeed: 7,
          month: 4,
          namespace: PublicDemoRngNamespace.recruitmentInterview,
          identifier: 'x',
        );
        // Re-derive in the opposite order — pure functions must agree.
        final interviewAgain = PublicDemoRng.derivedSeed(
          runSeed: 7,
          month: 4,
          namespace: PublicDemoRngNamespace.recruitmentInterview,
          identifier: 'x',
        );
        final candidateAgain = PublicDemoRng.derivedSeed(
          runSeed: 7,
          month: 4,
          namespace: PublicDemoRngNamespace.recruitmentCandidate,
          identifier: 'x',
        );

        expect(candidateAgain, candidateFirst);
        expect(interviewAgain, interviewFirst);
      },
    );
  });

  group('PublicDemoRng.random', () {
    test('two Random instances from identical inputs draw identical values', () {
      final r1 = PublicDemoRng.random(
        runSeed: 555,
        month: 9,
        namespace: PublicDemoRngNamespace.projectGeneration,
        identifier: 'proj-01',
      );
      final r2 = PublicDemoRng.random(
        runSeed: 555,
        month: 9,
        namespace: PublicDemoRngNamespace.projectGeneration,
        identifier: 'proj-01',
      );

      final drawn1 = List.generate(10, (_) => r1.nextInt(1000));
      final drawn2 = List.generate(10, (_) => r2.nextInt(1000));
      expect(drawn1, drawn2);
    });

    test('a different namespace draws a different sequence from the same '
        'runSeed/month/identifier', () {
      final candidate = PublicDemoRng.random(
        runSeed: 555,
        month: 9,
        namespace: PublicDemoRngNamespace.projectGeneration,
        identifier: 'proj-01',
      );
      final interview = PublicDemoRng.random(
        runSeed: 555,
        month: 9,
        namespace: PublicDemoRngNamespace.projectInterview,
        identifier: 'proj-01',
      );

      final drawnCandidate = List.generate(10, (_) => candidate.nextInt(1000));
      final drawnInterview = List.generate(10, (_) => interview.nextInt(1000));
      expect(drawnCandidate, isNot(drawnInterview));
    });
  });
}
