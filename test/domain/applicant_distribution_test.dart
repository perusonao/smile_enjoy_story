import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';

void main() {
  group('ApplicantGenerator distribution (10000 samples)', () {
    final applicants = ApplicantGenerator(seed: 42).generate(10000);
    final total = applicants.length;

    test('applicant type distribution roughly matches configured weights', () {
      final counts = <ApplicantType, int>{};
      for (final a in applicants) {
        counts[a.type] = (counts[a.type] ?? 0) + 1;
      }

      // Generous absolute tolerance (percentage points) — this is a sanity
      // check against a broken distribution, not a statistical proof.
      const tolerance = 0.05;
      applicantTypeWeights.forEach((type, expectedShare) {
        final actualShare = (counts[type] ?? 0) / total;
        expect(
          actualShare,
          closeTo(expectedShare, tolerance),
          reason:
              '$type expected ~${expectedShare * 100}%, got ${actualShare * 100}%',
        );
      });
    });

    test('main language distribution roughly matches type-level weights', () {
      for (final type in ApplicantType.values) {
        final ofType = applicants.where((a) => a.type == type).toList();
        if (ofType.isEmpty) continue;
        final counts = <ProgrammingLanguage, int>{};
        for (final a in ofType) {
          counts[a.mainLanguage] = (counts[a.mainLanguage] ?? 0) + 1;
        }
        const tolerance = 0.08;
        languageWeightsByType[type]!.forEach((lang, expectedShare) {
          final actualShare = (counts[lang] ?? 0) / ofType.length;
          expect(
            actualShare,
            closeTo(expectedShare, tolerance),
            reason:
                '$type/$lang expected ~${expectedShare * 100}%, got ${actualShare * 100}% (n=${ofType.length})',
          );
        });
      }
    });

    test('personality traits are not all clustered at the top', () {
      // Guards against "every applicant looks amazing" — the average
      // communication score should sit near the middle of 1-5, not near 5.
      final avgCommunication =
          applicants
              .map((a) => a.personality.communication)
              .reduce((a, b) => a + b) /
          total;
      expect(avgCommunication, inInclusiveRange(2.5, 3.6));
    });

    test('dishonesty distribution spans the full 1-5 range', () {
      final present = applicants.map((a) => a.personality.dishonesty).toSet();
      expect(present, containsAll([1, 2, 3, 4, 5]));
    });

    test('some, but not all, applicants have an inflated résumé', () {
      bool isInflated(Applicant a) => a.languageSkills.values.any(
        (s) => s.displayedExperienceMonths > s.actualExperienceMonths,
      );

      final inflatedCount = applicants.where(isInflated).length;
      expect(inflatedCount, greaterThan(0));
      expect(inflatedCount, lessThan(total));

      // dishonesty==1 applicants should very rarely be inflated.
      final lowDishonesty = applicants.where(
        (a) => a.personality.dishonesty == 1,
      );
      if (lowDishonesty.isNotEmpty) {
        final lowInflatedShare =
            lowDishonesty.where(isInflated).length / lowDishonesty.length;
        expect(lowInflatedShare, lessThan(0.15));
      }

      // dishonesty==5 applicants should be inflated more often than not, but
      // not universally ("even at 5, it's not guaranteed").
      final highDishonesty = applicants.where(
        (a) => a.personality.dishonesty == 5,
      );
      if (highDishonesty.isNotEmpty) {
        final highInflatedShare =
            highDishonesty.where(isInflated).length / highDishonesty.length;
        expect(highInflatedShare, greaterThan(0.3));
        expect(highInflatedShare, lessThan(1.0));
      }
    });

    test(
      'a bargain applicant (high ability, below-average salary) can occur',
      () {
        final byType = <ApplicantType, List<Applicant>>{};
        for (final a in applicants) {
          byType.putIfAbsent(a.type, () => []).add(a);
        }
        var foundBargain = false;
        byType.forEach((type, group) {
          final avgSalary =
              group.map((a) => a.desiredMonthlySalary).reduce((a, b) => a + b) /
              group.length;
          for (final a in group) {
            final skill = a.languageSkills[a.mainLanguage]!.actualSkill;
            if (skill >= 75 && a.desiredMonthlySalary < avgSalary * 0.85) {
              foundBargain = true;
            }
          }
        });
        expect(foundBargain, isTrue);
      },
    );
  });

  group('ApplicantGenerator seed reproducibility', () {
    test('same seed produces identical applicants in the same order', () {
      final a = ApplicantGenerator(seed: 777).generate(200);
      final b = ApplicantGenerator(seed: 777).generate(200);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].toJson(), equals(b[i].toJson()));
      }
    });

    test('different seeds produce different applicants', () {
      final a = ApplicantGenerator(seed: 1).generate(50);
      final b = ApplicantGenerator(seed: 2).generate(50);
      final differences = List.generate(
        50,
        (i) => a[i].toJson().toString() != b[i].toJson().toString(),
      ).where((d) => d).length;
      expect(differences, greaterThan(0));
    });
  });
}
