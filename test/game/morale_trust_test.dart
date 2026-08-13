import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

/// A clean-slate state (no founder engineers/projects) so each test can set
/// up exactly the scenario it needs.
GameState _emptyState({int seed = 42}) {
  final base = GameEngine.newGame(seed: seed);
  return base.copyWith(
    engineers: const [],
    activeAssignments: const [],
    applicants: const [],
    openProjects: const [],
    listings: const [],
    proposals: const [],
    pendingHires: const [],
    equipment: const [],
  );
}

void main() {
  group('MoraleEngine labels', () {
    test('moraleLabel/trustLabel bucket 0-100 into the five tiers', () {
      expect(MoraleEngine.moraleLabel(90), '非常に高い');
      expect(MoraleEngine.moraleLabel(65), '高い');
      expect(MoraleEngine.moraleLabel(50), '普通');
      expect(MoraleEngine.moraleLabel(25), '低い');
      expect(MoraleEngine.moraleLabel(5), 'かなり低い');

      expect(MoraleEngine.trustLabel(90), '非常に信頼');
      expect(MoraleEngine.trustLabel(65), '信頼');
      expect(MoraleEngine.trustLabel(50), '普通');
      expect(MoraleEngine.trustLabel(25), '不信');
      expect(MoraleEngine.trustLabel(5), 'かなり不信');
    });

    test('turnoverRisk is high only when both morale and trust are very low', () {
      final e = buildEngineer();
      expect(MoraleEngine.turnoverRisk(e.copyWith(morale: 80, companyTrust: 80)), TurnoverRisk.low);
      expect(MoraleEngine.turnoverRisk(e.copyWith(morale: 35, companyTrust: 80)), TurnoverRisk.medium);
      expect(MoraleEngine.turnoverRisk(e.copyWith(morale: 25, companyTrust: 25)), TurnoverRisk.high);
    });
  });

  group('MoraleEngine.applyDelta', () {
    test('clamps to 0-100 and records a reason, trimmed to the last 5 events', () {
      var e = buildEngineer().copyWith(morale: 5, companyTrust: 98);
      e = MoraleEngine.applyDelta(e, week: 1, reason: 'テスト', moraleDelta: -10, trustDelta: 10);
      expect(e.morale, 0);
      expect(e.companyTrust, 100);
      expect(e.relationshipHistory, hasLength(1));
      expect(e.relationshipHistory.single.reason, 'テスト');

      for (var week = 2; week <= 7; week++) {
        e = MoraleEngine.applyDelta(e, week: week, reason: 'イベント$week', moraleDelta: 1);
      }
      expect(e.relationshipHistory, hasLength(maxRelationshipHistory));
      expect(e.relationshipHistory.first.reason, 'イベント3');
      expect(e.relationshipHistory.last.reason, 'イベント7');
    });

    test('a zero-delta call is a no-op (no dangling history row)', () {
      final e = buildEngineer();
      final unchanged = MoraleEngine.applyDelta(e, week: 5, reason: 'no-op');
      expect(unchanged, same(e));
    });
  });

  group('MoraleEngine.weeklyUpdate', () {
    test('a long-waiting engineer drifts morale down with an attributed reason', () {
      final engineer = buildEngineer(status: EngineerStatus.waiting).copyWith(morale: 65);
      final updated = MoraleEngine.weeklyUpdate(
        engineers: [engineer],
        officeType: OfficeType.smallOffice,
        week: 10,
        waitingStreak: {engineer.id: 5},
        assignmentByEngineer: const {},
      ).single;
      expect(updated.morale, lessThan(engineer.morale));
      expect(updated.relationshipHistory.last.reason, contains('待機'));
    });

    test('weekly drift never exceeds the ±3 step cap in a single week', () {
      final engineer = buildEngineer(status: EngineerStatus.waiting).copyWith(morale: 100);
      final updated = MoraleEngine.weeklyUpdate(
        engineers: [engineer],
        officeType: OfficeType.homeOffice,
        week: 20,
        waitingStreak: {engineer.id: 20},
        assignmentByEngineer: const {},
      ).single;
      expect(engineer.morale - updated.morale, lessThanOrEqualTo(3));
    });

    test('a well-fitting assignment nudges morale up toward the fit target', () {
      final applicant = buildApplicant(mainLanguage: ProgrammingLanguage.java, mainLanguageActualSkill: 95);
      final engineer = buildEngineer(profile: applicant, status: EngineerStatus.assigned)
          .copyWith(morale: 40, residenceArea: ResidenceArea.tokyo);
      final project = buildProject(requiredLanguages: const [ProgrammingLanguage.java], location: ResidenceArea.tokyo, requiredBackend: 0);
      final assignment = ActiveAssignment(engineerId: engineer.id, project: project, remainingWeeks: 20, assignedWeek: 1);
      final updated = MoraleEngine.weeklyUpdate(
        engineers: [engineer],
        officeType: OfficeType.smallOffice,
        week: 2,
        waitingStreak: const {},
        assignmentByEngineer: {engineer.id: assignment},
      ).single;
      expect(updated.morale, greaterThan(engineer.morale));
    });

    test('office type shifts the target: mediumOffice pulls morale up relative to homeOffice', () {
      final engineer = buildEngineer(status: EngineerStatus.waiting).copyWith(morale: 60);
      final inHome = MoraleEngine.weeklyUpdate(
        engineers: [engineer],
        officeType: OfficeType.homeOffice,
        week: 5,
        waitingStreak: {engineer.id: 1},
        assignmentByEngineer: const {},
      ).single;
      final inMedium = MoraleEngine.weeklyUpdate(
        engineers: [engineer],
        officeType: OfficeType.mediumOffice,
        week: 5,
        waitingStreak: {engineer.id: 1},
        assignmentByEngineer: const {},
      ).single;
      expect(inMedium.morale, greaterThan(inHome.morale));
    });
  });

  group('MoraleEngine.commutePenalty', () {
    test('same residence area or remote work means no commute burden', () {
      final engineer = buildEngineer().copyWith(residenceArea: ResidenceArea.tokyo);
      final sameArea = buildProject(location: ResidenceArea.tokyo, remotePolicy: RemotePolicy.onsite);
      final remoteProject = buildProject(location: ResidenceArea.chiba, remotePolicy: RemotePolicy.remote);
      expect(MoraleEngine.commutePenalty(engineer, sameArea), 0);
      expect(MoraleEngine.commutePenalty(engineer, remoteProject), 0);
    });

    test('a mismatched area costs more when commuteSensitive', () {
      final base = buildEngineer().copyWith(residenceArea: ResidenceArea.tokyo);
      final sensitive = base.copyWith(abilities: {EmployeeAbility.commuteSensitive});
      final farProject = buildProject(location: ResidenceArea.chiba, remotePolicy: RemotePolicy.onsite);
      expect(MoraleEngine.commutePenalty(sensitive, farProject), greaterThan(MoraleEngine.commutePenalty(base, farProject)));
    });
  });

  group('MoraleEngine.contractPreference', () {
    test('a high-fit, high-morale, no-commute assignment yields wantsExtend', () {
      final applicant = buildApplicant(mainLanguage: ProgrammingLanguage.java, mainLanguageActualSkill: 95);
      final engineer = buildEngineer(profile: applicant).copyWith(morale: 80, residenceArea: ResidenceArea.tokyo);
      final project = buildProject(requiredLanguages: const [ProgrammingLanguage.java], location: ResidenceArea.tokyo, requiredBackend: 0);
      final assignment = ActiveAssignment(engineerId: engineer.id, project: project, remainingWeeks: 2, assignedWeek: 1);
      expect(MoraleEngine.contractPreference(engineer, assignment, 3), ContractPreference.wantsExtend);
    });

    test('low morale + poor fit + commute burden yields wantsLeave', () {
      final applicant = buildApplicant(mainLanguage: ProgrammingLanguage.java, mainLanguageActualSkill: 5);
      final engineer = buildEngineer(profile: applicant).copyWith(morale: 20, residenceArea: ResidenceArea.tokyo);
      final project = buildProject(requiredLanguages: const [ProgrammingLanguage.python], location: ResidenceArea.chiba, remotePolicy: RemotePolicy.onsite, requiredBackend: 5);
      final assignment = ActiveAssignment(engineerId: engineer.id, project: project, remainingWeeks: 2, assignedWeek: 1);
      expect(MoraleEngine.contractPreference(engineer, assignment, 3), ContractPreference.wantsLeave);
    });
  });

  group('GameEngine welfare actions', () {
    test('upgradePc deducts cash, records equipment, and raises morale with a reason', () {
      final engineer = buildEngineer(status: EngineerStatus.waiting);
      var state = _emptyState().copyWith(engineers: [engineer]);
      final cashBefore = state.company.cash;

      state = GameEngine.upgradePc(state, engineer.id, PcTier.highPerformanceLaptop);

      expect(state.company.cash, cashBefore - pcTierConfigs[PcTier.highPerformanceLaptop]!.cost);
      expect(state.equipmentFor(engineer.id)!.pcTier, PcTier.highPerformanceLaptop);
      final updated = state.engineerById(engineer.id);
      expect(updated.morale, greaterThan(engineer.morale));
      expect(updated.relationshipHistory.last.reason, contains('PC'));
    });

    test('upgradePc is a no-op when cash is insufficient', () {
      final engineer = buildEngineer(status: EngineerStatus.waiting);
      final state = _emptyState().copyWith(engineers: [engineer]);
      final poor = state.copyWith(company: state.company.copyWith(cash: 100));
      final result = GameEngine.upgradePc(poor, engineer.id, PcTier.highPerformanceLaptop);
      expect(result, same(poor));
    });

    test('conductHealthCheck costs per-employee and raises morale/trust for everyone', () {
      final a = buildEngineer(id: 'a', status: EngineerStatus.waiting).copyWith(morale: 50, companyTrust: 50);
      final b = buildEngineer(id: 'b', status: EngineerStatus.waiting).copyWith(morale: 50, companyTrust: 50);
      var state = _emptyState().copyWith(engineers: [a, b]);
      final cashBefore = state.company.cash;

      state = GameEngine.conductHealthCheck(state, HealthCheckTier.premium);

      final config = healthCheckConfigs[HealthCheckTier.premium]!;
      expect(state.company.cash, cashBefore - config.costPerEmployee * 2);
      expect(state.lastHealthCheckWeek, state.week);
      for (final e in state.engineers) {
        expect(e.morale, 50 + config.moraleEffect);
        expect(e.companyTrust, 50 + config.trustEffect);
      }
    });

    test('payBonus(none) hurts morale/trust; a paid plan scales more for compensation-focused employees', () {
      final compensationFocused = buildEngineer(id: 'c', salary: 300000)
          .copyWith(preference: EmployeePreference.compensation, morale: 50);
      final stabilityFocused = buildEngineer(id: 's', salary: 300000)
          .copyWith(preference: EmployeePreference.stability, morale: 50);
      var state = _emptyState().copyWith(engineers: [compensationFocused, stabilityFocused]);
      final cashBefore = state.company.cash;

      final afterNone = GameEngine.payBonus(state, BonusPlan.none);
      for (final e in afterNone.engineers) {
        expect(e.morale, lessThan(50));
      }

      final afterOne = GameEngine.payBonus(state, BonusPlan.one);
      expect(afterOne.company.cash, cashBefore - (300000 * 2 * 1.0).round());
      expect(afterOne.lastBonusWeek, afterOne.week);
      final compAfter = afterOne.engineerById('c').morale;
      final stabAfter = afterOne.engineerById('s').morale;
      expect(compAfter - 50, greaterThan(stabAfter - 50));
    });

    test('payBonus is allowed to push cash negative (trade-off is the point, §21)', () {
      final engineer = buildEngineer(salary: 10000000);
      var state = _emptyState().copyWith(engineers: [engineer]);
      final result = GameEngine.payBonus(state, BonusPlan.two);
      expect(result.company.cash, lessThan(0));
    });

    test('conductCompanyTrip: a social employee gains more morale than a privateLife-focused one', () {
      final social = buildEngineer(id: 'soc').copyWith(preference: EmployeePreference.social, morale: 50);
      final privateLife = buildEngineer(id: 'priv').copyWith(preference: EmployeePreference.privateLife, morale: 50);
      var state = _emptyState().copyWith(engineers: [social, privateLife]);
      final cashBefore = state.company.cash;

      state = GameEngine.conductCompanyTrip(state, CompanyTripType.overnightDomestic);

      expect(state.company.cash, cashBefore - companyTripConfigs[CompanyTripType.overnightDomestic]!.costPerEmployee * 2);
      expect(state.lastCompanyTripWeek, state.week);
      final socialAfter = state.engineerById('soc').morale;
      final privateAfter = state.engineerById('priv').morale;
      expect(socialAfter, greaterThan(privateAfter));
    });
  });

  group('GameEngine.decideContract preference interaction', () {
    test('withdrawing against a wantsExtend employee costs morale and trust', () {
      final applicant = buildApplicant(mainLanguage: ProgrammingLanguage.java, mainLanguageActualSkill: 95);
      final engineer = buildEngineer(profile: applicant, status: EngineerStatus.assigned)
          .copyWith(morale: 80, companyTrust: 80, residenceArea: ResidenceArea.tokyo);
      final project = buildProject(requiredLanguages: const [ProgrammingLanguage.java], location: ResidenceArea.tokyo, requiredBackend: 0);
      final assignment = ActiveAssignment(engineerId: engineer.id, project: project, remainingWeeks: 2, assignedWeek: 1);
      final state = _emptyState().copyWith(engineers: [engineer], activeAssignments: [assignment]);

      final result = GameEngine.decideContract(state, engineer.id, false);
      final updated = result.engineerById(engineer.id);
      expect(updated.morale, lessThan(engineer.morale));
      expect(updated.companyTrust, lessThan(engineer.companyTrust));
    });
  });

  group('Engineer/GameState JSON round-trip', () {
    test('morale, preference and relationship history survive toJson/fromJson', () {
      final engineer = buildEngineer().copyWith(
        morale: 42,
        preference: EmployeePreference.growth,
        relationshipHistory: [const EmployeeRelationshipEvent(week: 3, reason: 'テスト', moraleDelta: 2, trustDelta: -1)],
      );
      final restored = Engineer.fromJson(engineer.toJson());
      expect(restored.morale, 42);
      expect(restored.preference, EmployeePreference.growth);
      expect(restored.relationshipHistory.single.reason, 'テスト');
    });

    test('GameState equipment and welfare timestamps survive toJson/fromJson', () {
      final state = GameEngine.newGame(seed: 7).copyWith(
        lastHealthCheckWeek: 4,
        lastBonusWeek: 8,
        lastCompanyTripWeek: 12,
      );
      final restored = GameState.fromJson(state.toJson());
      expect(restored.equipment, hasLength(state.equipment.length));
      expect(restored.lastHealthCheckWeek, 4);
      expect(restored.lastBonusWeek, 8);
      expect(restored.lastCompanyTripWeek, 12);
    });
  });

  group('New game founders', () {
    test('founders start with a morale value and a standard laptop', () {
      final state = GameEngine.newGame(seed: 99);
      for (final e in state.engineers) {
        expect(e.morale, inInclusiveRange(0, 100));
        expect(state.equipmentFor(e.id)?.pcTier, PcTier.standardLaptop);
      }
    });
  });
}
