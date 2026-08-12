import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';

void main() {
  group('ApplicantGenerator validity (1000 samples)', () {
    final applicants = ApplicantGenerator(seed: 1).generate(1000);

    test('age is within the range defined for the applicant type', () {
      for (final a in applicants) {
        final range = ageRangeByType[a.type]!;
        expect(
          a.age,
          inInclusiveRange(range.min, range.max),
          reason: '${a.type} age ${a.age} out of [${range.min}, ${range.max}]',
        );
      }
    });

    test('IT experience never exceeds age - 20 years', () {
      for (final a in applicants) {
        final maxAllowedMonths = (a.age - itExperienceStartAge) * 12;
        expect(
          a.totalItExperienceMonths,
          lessThanOrEqualTo(maxAllowedMonths),
          reason:
              '${a.id}: ${a.totalItExperienceMonths}mo IT exp at age ${a.age}',
        );
        expect(a.totalItExperienceMonths, greaterThanOrEqualTo(0));
      }
    });

    test(
      'no language experience exceeds total IT experience (displayed or actual)',
      () {
        for (final a in applicants) {
          for (final skill in a.languageSkills.values) {
            expect(
              skill.actualExperienceMonths,
              lessThanOrEqualTo(a.totalItExperienceMonths),
              reason:
                  '${a.id} ${skill.language} actual exp exceeds total IT exp',
            );
            expect(
              skill.displayedExperienceMonths,
              lessThanOrEqualTo(a.totalItExperienceMonths),
              reason:
                  '${a.id} ${skill.language} displayed exp exceeds total IT exp',
            );
          }
        }
      },
    );

    test('personal ability fields stay within 1-5', () {
      for (final a in applicants) {
        final p = a.personality;
        for (final v in [
          p.looks,
          p.cleanliness,
          p.communication,
          p.alcoholTolerance,
          p.seriousness,
          p.dishonesty,
        ]) {
          expect(v, inInclusiveRange(1, 5));
        }
      }
    });

    test('hidden parameters stay within their declared ranges', () {
      for (final a in applicants) {
        final h = a.hidden;
        expect(h.growthPotential, inInclusiveRange(1, 5));
        expect(h.stressTolerance, inInclusiveRange(1, 5));
        expect(h.retention, inInclusiveRange(1, 5));
        expect(h.projectInterviewSkill, inInclusiveRange(1, 5));
        expect(h.turnoverIntent, inInclusiveRange(0, 100));
      }
    });

    test('tech skill levels stay within 0-5', () {
      for (final a in applicants) {
        final t = a.techSkills;
        for (final v in [
          t.database,
          t.network,
          t.infrastructure,
          t.frontend,
          t.backend,
          t.leader,
          t.manager,
        ]) {
          expect(v, inInclusiveRange(0, 5));
        }
      }
    });

    test('desired monthly salary is always positive', () {
      for (final a in applicants) {
        expect(a.desiredMonthlySalary, greaterThan(0));
      }
    });

    test('mainLanguage never appears in subLanguages', () {
      for (final a in applicants) {
        expect(a.subLanguages, isNot(contains(a.mainLanguage)));
      }
    });

    test('subLanguages never contains duplicates', () {
      for (final a in applicants) {
        expect(a.subLanguages.toSet().length, a.subLanguages.length);
        expect(a.subLanguages.length, lessThanOrEqualTo(2));
      }
    });

    test('actualSkill stays within 0-100 for every language', () {
      for (final a in applicants) {
        for (final skill in a.languageSkills.values) {
          expect(skill.actualSkill, inInclusiveRange(0, 100));
        }
      }
    });

    test('dishonesty-inflated résumés stay internally consistent', () {
      for (final a in applicants) {
        for (final skill in a.languageSkills.values) {
          // Displayed experience never understates the truth...
          expect(
            skill.displayedExperienceMonths,
            greaterThanOrEqualTo(skill.actualExperienceMonths),
          );
          // ...and never contradicts age or total IT experience.
          expect(
            skill.displayedExperienceMonths,
            lessThanOrEqualTo(a.totalItExperienceMonths),
          );
          final maxAllowedMonths = (a.age - itExperienceStartAge) * 12;
          expect(
            skill.displayedExperienceMonths,
            lessThanOrEqualTo(maxAllowedMonths),
          );
        }
      }
    });

    test('japaneseLevel and englishLevel stay within 1-5', () {
      for (final a in applicants) {
        expect(a.japaneseLevel, inInclusiveRange(1, 5));
        expect(a.englishLevel, inInclusiveRange(1, 5));
      }
    });

    test('no untrained (未経験者) applicants are generated', () {
      // ApplicantType has no "inexperienced/未経験" member at all in Phase 0;
      // this documents the invariant explicitly rather than relying only on
      // the type system.
      const forbiddenNames = {'inexperienced', 'untrained', 'newGraduate'};
      for (final a in applicants) {
        expect(forbiddenNames.contains(a.type.name), isFalse);
        expect(a.totalItExperienceMonths, greaterThanOrEqualTo(12));
      }
    });

    test('no PM/manager-track applicants are generated', () {
      const forbiddenNames = {'pm', 'projectManager'};
      for (final a in applicants) {
        expect(forbiddenNames.contains(a.type.name), isFalse);
      }
    });

    test('every applicant has an id and every generated id is unique', () {
      final ids = applicants.map((a) => a.id).toSet();
      expect(ids.length, applicants.length);
    });
  });
}
