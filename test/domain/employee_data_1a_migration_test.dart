import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import '../game/test_helpers.dart';

void main() {
  group('CareerHistoryEntry additive loading', () {
    test('legacy original fields survive with deterministic new defaults', () {
      final legacy = <String, dynamic>{
        'id': 'history-legacy',
        'projectName': '既存案件',
        'experienceMonths': 7,
        'languages': ['java'],
        'technologies': ['Spring'],
        'processes': ['実装'],
        'role': 'PG',
        'teamSize': 5,
      };

      final restored = CareerHistoryEntry.fromJson(legacy);

      expect(restored.id, 'history-legacy');
      expect(restored.projectName, '既存案件');
      expect(restored.experienceMonths, 7);
      expect(restored.languages, [ProgrammingLanguage.java]);
      expect(restored.technologies, ['Spring']);
      expect(restored.processes, ['実装']);
      expect(restored.role, 'PG');
      expect(restored.teamSize, 5);
      expect(restored.industry, isNull);
      expect(restored.startWeek, isNull);
      expect(restored.endWeek, isNull);
      expect(restored.clientNameSnapshot, isNull);
      expect(restored.summary, '');
    });

    test(
      'multiple entries preserve order and empty history remains stable',
      () {
        final engineer = buildEngineer(
          careerHistory: const [
            CareerHistoryEntry(
              id: 'first',
              projectName: '最初',
              experienceMonths: 3,
            ),
            CareerHistoryEntry(
              id: 'second',
              projectName: '次',
              experienceMonths: 6,
            ),
          ],
        );

        final restored = Engineer.fromJson(engineer.toJson());
        expect(restored.careerHistory.map((entry) => entry.id), [
          'first',
          'second',
        ]);

        final empty = buildEngineer();
        expect(Engineer.fromJson(empty.toJson()).careerHistory, isEmpty);
      },
    );

    test('unknown serialized industry falls back without throwing', () {
      final json = const CareerHistoryEntry(
        id: 'history-1',
        projectName: '案件',
        experienceMonths: 1,
      ).toJson()..['industry'] = 'futureIndustry';

      expect(CareerHistoryEntry.fromJson(json).industry, Industry.other);
    });
  });

  group('EngineerCertification additive loading', () {
    test('round-trips populated and nullable acquiredWeek records', () {
      const populated = EngineerCertification(
        key: 'fe',
        displayName: '基本情報技術者',
        category: EngineerCertificationCategory.general,
        acquiredWeek: 8,
      );
      const withoutWeek = EngineerCertification(
        key: 'ccna',
        displayName: 'CCNA',
        category: EngineerCertificationCategory.networkSecurity,
      );

      expect(
        EngineerCertification.fromJson(populated.toJson()).toJson(),
        populated.toJson(),
      );
      expect(
        EngineerCertification.fromJson(withoutWeek.toJson()).toJson(),
        withoutWeek.toJson(),
      );
      expect(
        EngineerCertification.fromJson(withoutWeek.toJson()).acquiredWeek,
        isNull,
      );
    });

    test('absent and unknown categories use the non-throwing fallback', () {
      final absent = <String, dynamic>{'key': 'legacy', 'displayName': '旧資格'};
      final unknown = <String, dynamic>{
        ...absent,
        'category': 'futureCategory',
      };

      expect(
        EngineerCertification.fromJson(absent).category,
        EngineerCertificationCategory.general,
      );
      expect(
        EngineerCertification.fromJson(unknown).category,
        EngineerCertificationCategory.general,
      );
    });
  });

  group('Engineer and GameState authority boundaries', () {
    test(
      'legacy Engineer keeps history and defaults certifications to empty',
      () {
        final original = buildEngineer(
          careerHistory: const [
            CareerHistoryEntry(
              id: 'existing',
              projectName: '保存済み案件',
              experienceMonths: 10,
              role: 'SE',
            ),
          ],
        );
        final legacyJson = original.toJson()..remove('certifications');
        final originalHistoryJson = legacyJson['careerHistory'];

        final restored = Engineer.fromJson(legacyJson);
        expect(restored.certifications, isEmpty);
        expect(
          restored.careerHistory.map((entry) => entry.toJson()).toList(),
          originalHistoryJson,
        );
      },
    );

    test(
      'legacy load fabricates neither history nor verified certifications',
      () {
        final state = GameEngine.newGame(seed: 31);
        final engineer = state.engineers.first;
        final assignment = ActiveAssignment(
          engineerId: engineer.id,
          project: state.openProjects.first.project,
          remainingWeeks: 8,
          assignedWeek: 1,
        );
        final legacyJson = state
            .copyWith(activeAssignments: [assignment])
            .toJson();
        final engineerJson =
            (legacyJson['engineers'] as List).first as Map<String, dynamic>;
        engineerJson
          ..remove('careerHistory')
          ..remove('certifications');

        final restored = GameState.fromJson(legacyJson);
        expect(restored.engineers.first.careerHistory, isEmpty);
        expect(restored.engineers.first.certifications, isEmpty);
        expect(restored.activeAssignments, hasLength(1));
      },
    );

    test('schema 6 and differing SkillSheet values survive round-trip', () {
      final state = GameEngine.newGame(seed: 32);
      final originalEngineer = state.engineers.first;
      final actual = originalEngineer.copyWith(
        careerHistory: const [
          CareerHistoryEntry(
            id: 'actual-history',
            projectName: '実案件',
            experienceMonths: 24,
            languages: [ProgrammingLanguage.java],
          ),
        ],
        certifications: const [
          EngineerCertification(key: 'verified-fe', displayName: '基本情報技術者'),
        ],
      );
      final salesFacing = state
          .skillSheetFor(originalEngineer.id)
          .copyWith(
            displayedLanguageExperience: const {ProgrammingLanguage.java: 60},
            displayedBackend: 5,
          );
      final changed = state.copyWith(
        engineers: [actual, ...state.engineers.skip(1)],
        skillSheets: [
          salesFacing,
          ...state.skillSheets.where(
            (sheet) => sheet.employeeId != originalEngineer.id,
          ),
        ],
      );

      final restored = GameState.fromJson(changed.toJson());
      expect(currentSchemaVersion, 6);
      expect(restored.schemaVersion, 6);
      expect(restored.skillSheetFor(actual.id).displayedLanguageExperience, {
        ProgrammingLanguage.java: 60,
      });
      expect(restored.skillSheetFor(actual.id).displayedBackend, 5);
      expect(
        restored.engineerById(actual.id).careerHistory.single.id,
        'actual-history',
      );
      expect(
        restored.engineerById(actual.id).certifications.single.key,
        'verified-fe',
      );
    });

    test('Applicant qualifications remain claims and are never copied', () {
      final applicant = buildApplicant(
        qualifications: const ['AWS認定（自己申告）', 'TOEIC 600'],
      );
      final engineer = buildEngineer(profile: applicant);

      final restored = Engineer.fromJson(engineer.toJson());
      expect(restored.profile.qualifications, applicant.qualifications);
      expect(restored.certifications, isEmpty);
    });
  });
}
