import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';

void main() {
  group('JSON round-trips', () {
    test('Applicant toJson/fromJson round-trips exactly', () {
      final original = ApplicantGenerator(seed: 10).generate(5).first;
      final restored = Applicant.fromJson(original.toJson());
      expect(restored.toJson(), equals(original.toJson()));
    });

    test('Engineer toJson/fromJson round-trips exactly', () {
      final applicant = ApplicantGenerator(seed: 11).generate(1).first;
      final engineer = Engineer(
        id: 'engineer-1',
        sourceApplicantId: applicant.id,
        profile: applicant,
        salary: applicant.desiredMonthlySalary,
        employmentWeek: 3,
        status: EngineerStatus.waiting,
        careerHistory: const [
          CareerHistoryEntry(
            id: 'history-1',
            projectName: '金融基幹刷新',
            experienceMonths: 18,
            languages: [ProgrammingLanguage.java],
            technologies: ['Spring Boot', 'Oracle'],
            processes: ['基本設計', '実装'],
            role: 'SE',
            teamSize: 12,
            industry: Industry.finance,
            startWeek: 4,
            endWeek: 75,
            clientNameSnapshot: 'サンプル金融',
            summary: '勘定系APIの刷新を担当',
          ),
        ],
        certifications: const [
          EngineerCertification(
            key: 'aws-saa',
            displayName: 'AWS Solutions Architect Associate',
            category: EngineerCertificationCategory.cloudInfrastructure,
            acquiredWeek: 2,
          ),
        ],
      );
      final restored = Engineer.fromJson(engineer.toJson());
      expect(restored.toJson(), equals(engineer.toJson()));
    });

    test('Project toJson/fromJson round-trips exactly', () {
      final project = ProjectGenerator(
        seed: 12,
        clients: sampleClients,
      ).generate(5).first;
      final restored = Project.fromJson(project.toJson());
      expect(restored.toJson(), equals(project.toJson()));
    });

    test('Client toJson/fromJson round-trips exactly', () {
      for (final client in sampleClients) {
        final restored = Client.fromJson(client.toJson());
        expect(restored.toJson(), equals(client.toJson()));
      }
    });

    test('Company toJson/fromJson round-trips exactly', () {
      final company = Company.initial(id: 'company-1', name: 'テスト商事');
      final restored = Company.fromJson(company.toJson());
      expect(restored.toJson(), equals(company.toJson()));
      expect(company.cash, 5000000);
      expect(company.credit, 20);
      expect(company.currentWeek, 1);
    });
  });
}
