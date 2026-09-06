import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/models/hidden_parameters.dart';
import 'package:smile_enjoy_story/domain/models/language_skill.dart';
import 'package:smile_enjoy_story/domain/models/programming_language.dart';
import 'package:smile_enjoy_story/domain/models/tech_skill_levels.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_year_end_display_data.dart';

/// SES YEAR-END-PHASE-1: pure unit coverage for
/// [PublicDemoYearEndDisplayData.fromPublicDemoState] and
/// [publicDemoYearEndHiyoriSummary] — every value must trace back to a
/// hand-built, authoritative [PublicDemoState] with no widget involved.
void main() {
  /// A runtime carrying [capability] as `eng-01`/`eng-02`'s current
  /// capability — same shape [publicDemoInitialEngineerRuntimes] itself
  /// uses, just with an overridden skill so growth is observable.
  PublicDemoEngineerRuntime runtimeWithCapability(
    String engineerId,
    ProgrammingLanguage language,
    int capability,
  ) => PublicDemoEngineerRuntime(
    engineerId: engineerId,
    primaryLanguage: language,
    languageSkills: {
      language: LanguageSkill(
        language: language,
        displayedExperienceMonths: 36,
        actualExperienceMonths: 36,
        actualSkill: capability,
      ),
    },
    techSkills: const TechSkillLevels.zero(),
    hidden: const HiddenParameters(
      growthPotential: 3,
      stressTolerance: 3,
      retention: 3,
      projectInterviewSkill: 3,
      turnoverIntent: 50,
    ),
  );

  group('PublicDemoYearEndDisplayData.fromPublicDemoState', () {
    test('maps every field verbatim/by simple arithmetic from state, with '
        'no fabricated value', () {
      final state = PublicDemoState(
        month: 15,
        cash: 5200000,
        engineerCount: 3, // 2 founders + 1 hire
        adminCount: 1,
        salesCapacity: 4,
        salesUsed: 0,
        engineersWaiting: 1,
        engineersAssigned: 2,
        joinedApplicantIds: const ['app-01'],
        engineerRuntimes: [
          runtimeWithCapability('eng-01', ProgrammingLanguage.java, 90),
          runtimeWithCapability(
            'eng-02',
            ProgrammingLanguage.javascript,
            52,
          ),
        ],
        fiscalYearCompleted: true,
      );

      final data = PublicDemoYearEndDisplayData.fromPublicDemoState(state);

      expect(
        data.startingCash,
        PublicDemoState.aprilStart().cash,
        reason: 'starting cash is the same canonical constant a replay uses',
      );
      expect(data.finalCash, 5200000);
      expect(data.cashDelta, 5200000 - PublicDemoState.aprilStart().cash);
      expect(
        data.finalEmployeeCount,
        4,
        reason: 'engineerCount(3) + adminCount(1), matching the existing '
            'HOME total-headcount composition (Issue #122)',
      );
      expect(data.annualHireCount, 1);
      expect(data.finalParticipatingCount, 2);
      expect(data.finalWaitingCount, 1);

      expect(data.founderGrowth, hasLength(2));
      final sato = data.founderGrowth.firstWhere(
        (f) => f.engineerId == 'eng-01',
      );
      expect(sato.name, '佐藤 健');
      expect(sato.initialCapability, 78);
      expect(sato.currentCapability, 90);
      expect(sato.capabilityDelta, 12);

      final suzuki = data.founderGrowth.firstWhere(
        (f) => f.engineerId == 'eng-02',
      );
      expect(suzuki.name, '鈴木 葵');
      expect(suzuki.initialCapability, 52);
      expect(suzuki.currentCapability, 52);
      expect(suzuki.capabilityDelta, 0);
    });

    test('falls back to the founding baseline if a founder runtime is '
        'somehow missing, never throwing or inventing growth', () {
      final state = PublicDemoState(
        month: 15,
        cash: PublicDemoState.aprilStart().cash,
        engineerCount: 2,
        adminCount: 1,
        salesCapacity: 4,
        salesUsed: 0,
        engineersWaiting: 2,
        engineersAssigned: 0,
        engineerRuntimes: const [],
        fiscalYearCompleted: true,
      );

      final data = PublicDemoYearEndDisplayData.fromPublicDemoState(state);

      expect(data.cashDelta, 0);
      expect(data.annualHireCount, 0);
      for (final founder in data.founderGrowth) {
        expect(founder.capabilityDelta, 0);
      }
    });

    test('never appears for a state that has not completed the fiscal '
        'year — callers gate construction on fiscalYearCompleted, but the '
        'factory itself does not require success either way', () {
      final state = PublicDemoState.aprilStart().copyWith(
        month: 15,
        financialStatus: PublicDemoFinancialStatus.bankruptcy,
      );
      expect(state.fiscalYearCompleted, isFalse);

      // The factory is a pure projection — it does not itself branch on
      // fiscalYearCompleted (the UI's `if (s.fiscalYearCompleted)` guard
      // owns that decision) — but it must still never throw or fabricate
      // data for a state that reached this month via bankruptcy.
      final data = PublicDemoYearEndDisplayData.fromPublicDemoState(state);
      expect(data.finalCash, state.cash);
    });
  });

  group('publicDemoYearEndHiyoriSummary', () {
    test('states cash increase, hires, participation and growth as facts, '
        'never inventing revenue/sales/crisis/recovery counts', () {
      const data = PublicDemoYearEndDisplayData(
        startingCash: 4000000,
        finalCash: 5000000,
        finalEmployeeCount: 4,
        annualHireCount: 1,
        finalParticipatingCount: 2,
        finalWaitingCount: 1,
        founderGrowth: [
          PublicDemoFounderGrowthDisplay(
            engineerId: 'eng-01',
            name: '佐藤 健',
            initialCapability: 78,
            currentCapability: 90,
          ),
          PublicDemoFounderGrowthDisplay(
            engineerId: 'eng-02',
            name: '鈴木 葵',
            initialCapability: 52,
            currentCapability: 52,
          ),
        ],
      );

      final summary = publicDemoYearEndHiyoriSummary(data);

      expect(summary, contains('¥4,000,000'));
      expect(summary, contains('¥5,000,000'));
      expect(summary, contains('1名を新たに採用'));
      expect(summary, contains('2名が案件に参画'));
      expect(summary, contains('1名が待機中'));
      expect(summary, contains('佐藤 健'));
      expect(summary, isNot(contains('鈴木 葵')), reason: 'only the founder '
          'who actually grew is named as having grown');

      for (final forbidden in ['売上', '営業回数', '危機', '回復回数']) {
        expect(
          summary,
          isNot(contains(forbidden)),
          reason: 'the summary must never claim a value Public Demo does '
              'not retain as a year-spanning total',
        );
      }
    });

    test('states a cash decrease and zero hires/growth honestly', () {
      const data = PublicDemoYearEndDisplayData(
        startingCash: 4000000,
        finalCash: 3000000,
        finalEmployeeCount: 3,
        annualHireCount: 0,
        finalParticipatingCount: 0,
        finalWaitingCount: 2,
        founderGrowth: [
          PublicDemoFounderGrowthDisplay(
            engineerId: 'eng-01',
            name: '佐藤 健',
            initialCapability: 78,
            currentCapability: 78,
          ),
        ],
      );

      final summary = publicDemoYearEndHiyoriSummary(data);

      expect(summary, contains('¥1,000,000減って'));
      expect(summary, contains('新規採用はありませんでした'));
      expect(summary, contains('0名が案件に参画'));
      expect(summary, contains('大きくは変わっていません'));
    });
  });
}
