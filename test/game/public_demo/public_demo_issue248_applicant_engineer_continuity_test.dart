// Issue #248 FIRST-FUN-YEAR: Applicant->Engineer Data Preservation.
//
// Before this fix, PublicDemoEngineerRuntime.fromApplicant unconditionally
// hard-coded primaryLanguage to ProgrammingLanguage.java and techSkills to
// TechSkillLevels.zero() for every experienced hire, regardless of which
// language/tech profile ApplicantGenerator actually produced for them. This
// silently replaced every hired person's real technology identity with a
// generic placeholder that then propagated into the employee roster's skill
// bar (`_primarySkillDisplayFor`), the SkillSheet's primary-language chip and
// experience comparison (`PublicDemoSkillSheetDisplayFactory`), and
// Matching's language/tech-domain fit dimensions
// (`PublicDemoEngineerProjectFit._placeholderEngineerFor`) -- exactly the
// "generic replacement" this issue exists to close.
//
// The fix reads the same full domain Applicant the recruitment-interview
// step already recovers via
// `PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant`
// (`(runSeed, applicant.id)`, no new save data) and threads its real
// mainLanguage/languageSkills/techSkills through fromApplicant. Passing no
// sourceApplicant (the legacy pool app-01/app-02/free-template-* cannot be
// regenerated this way) reproduces the exact pre-existing behavior, so no
// existing save/test is affected.
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_matching_fit.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_candidate_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_skill_sheet_display_projection.dart';

void main() {
  group('PublicDemoEngineerRuntime.fromApplicant: real technology identity', () {
    const experienced = PublicDemoApplicant(
      id: 'app-experienced',
      name: 'テスト応募者',
      resumeSummary: 'テスト',
      interviewScore: 80,
      acceptanceScore: 80,
      salesSkillFit: 70,
      experienceMonths: 48,
    );

    const inexperienced = PublicDemoApplicant(
      id: 'app-inexperienced',
      name: 'テスト未経験応募者',
      resumeSummary: 'テスト',
      interviewScore: 50,
      acceptanceScore: 50,
      salesSkillFit: 30,
      experienceMonths: 0,
    );

    const flavorApplicant = Applicant(
      id: 'flavor',
      type: ApplicantType.frontendSpecialist,
      name: 'フレーバー',
      age: 30,
      nationality: 'JP',
      education: Education.university,
      major: Major.informationTechnology,
      totalItExperienceMonths: 60,
      jobChangeCount: 0,
      desiredMonthlySalary: 350000,
      desiredWorkStyle: WorkStyle.hybrid,
      japaneseLevel: 5,
      englishLevel: 3,
      qualifications: [],
      languageSkills: {
        ProgrammingLanguage.python: LanguageSkill(
          language: ProgrammingLanguage.python,
          displayedExperienceMonths: 48,
          actualExperienceMonths: 60,
          actualSkill: 70,
        ),
      },
      mainLanguage: ProgrammingLanguage.python,
      subLanguages: [],
      techSkills: TechSkillLevels(
        database: 2,
        network: 0,
        infrastructure: 1,
        frontend: 4,
        backend: 3,
        leader: 0,
        manager: 0,
      ),
      personality: PersonalityTraits(
        looks: 3,
        cleanliness: 3,
        communication: 3,
        alcoholTolerance: 3,
        seriousness: 3,
        dishonesty: 3,
      ),
      hidden: HiddenParameters(
        growthPotential: 3,
        stressTolerance: 3,
        retention: 3,
        projectInterviewSkill: 3,
        turnoverIntent: 50,
      ),
    );

    test(
      'an experienced hire with a recoverable source applicant carries the '
      'real main language, its real LanguageSkill, and real techSkills '
      'through instead of a hard-coded Java/zero placeholder',
      () {
        final runtime = PublicDemoEngineerRuntime.fromApplicant(
          experienced,
          sourceApplicant: flavorApplicant,
        );

        expect(runtime.primaryLanguage, ProgrammingLanguage.python);
        expect(runtime.confirmedLanguages, {ProgrammingLanguage.python});
        expect(
          runtime.languageSkills[ProgrammingLanguage.python],
          flavorApplicant.skillFor(ProgrammingLanguage.python),
        );
        // The skill number itself is unchanged -- only its language
        // attribution is fixed. Continuity of the actual capability value.
        expect(runtime.actualCapability, experienced.salesSkillFit);
        expect(runtime.techSkills.toJson(), flavorApplicant.techSkills.toJson());
        // Data preservation only: no new stat, no schema change.
        expect(
          runtime.totalItExperienceMonths,
          experienced.experienceMonths,
          reason: 'aggregate experience authority is unchanged by this fix',
        );
      },
    );

    test(
      'an experienced hire with no recoverable source applicant (legacy '
      'app-01/app-02/free-template-* pool) reproduces the exact pre-existing '
      'placeholder behavior -- no regression for legacy saves',
      () {
        final runtime = PublicDemoEngineerRuntime.fromApplicant(experienced);

        expect(runtime.primaryLanguage, ProgrammingLanguage.java);
        expect(runtime.confirmedLanguages, isEmpty);
        expect(runtime.languageSkills[ProgrammingLanguage.java]?.actualSkill, 70);
        expect(runtime.techSkills.toJson(), const TechSkillLevels.zero().toJson());
      },
    );

    test(
      'a genuinely inexperienced hire never fabricates a language identity '
      'even when a source applicant is supplied -- the résumé itself never '
      'names a language for this hire',
      () {
        final withSource = PublicDemoEngineerRuntime.fromApplicant(
          inexperienced,
          sourceApplicant: flavorApplicant,
        );
        final withoutSource = PublicDemoEngineerRuntime.fromApplicant(
          inexperienced,
        );

        expect(withSource.primaryLanguage, ProgrammingLanguage.java);
        expect(withSource.confirmedLanguages, {ProgrammingLanguage.java});
        expect(withSource.toJson(), withoutSource.toJson());
      },
    );

    test(
      'toJson/fromJson round-trips unchanged -- no new save-schema key is '
      'introduced by carrying the real language/tech data through',
      () {
        final runtime = PublicDemoEngineerRuntime.fromApplicant(
          experienced,
          sourceApplicant: flavorApplicant,
        );
        final json = runtime.toJson();
        expect(
          json.keys.toSet(),
          {
            'engineerId',
            'primaryLanguage',
            'languageSkills',
            'techSkills',
            'hidden',
            'abilities',
            'industryExperience',
            'careerHistory',
            'confirmedLanguages',
            'totalItExperienceMonths',
          },
        );
        final reloaded = PublicDemoEngineerRuntime.fromJson(json);
        expect(reloaded.toJson(), json);
        expect(reloaded.primaryLanguage, ProgrammingLanguage.python);
      },
    );

    test(
      'the SkillSheet display projection now shows the real primary '
      'language and tech skills for this runtime, instead of the previous '
      'always-empty state every experienced hire showed before this fix',
      () {
        final runtime = PublicDemoEngineerRuntime.fromApplicant(
          experienced,
          sourceApplicant: flavorApplicant,
        );
        final sales = PublicDemoEngineerSales.fromApplicant(experienced);
        final display = PublicDemoSkillSheetDisplayFactory.create(
          engineer: sales,
          statusLabel: '待機',
          runtime: runtime,
          currentAssignment: null,
        );

        expect(display.primaryLanguageLabel, isNotNull);
        expect(display.experienceComparisons, isNotEmpty);
        expect(display.techSkillChips, isNotEmpty);
      },
    );

    test(
      'Matching now treats the real confirmed language as genuine '
      'experience instead of unmatched/poor for every experienced hire',
      () {
        final runtime = PublicDemoEngineerRuntime.fromApplicant(
          experienced,
          sourceApplicant: flavorApplicant,
        );
        final engineerProfile = PublicDemoEngineerProjectFit.engineerFor(runtime);

        expect(
          engineerProfile.profile.languageSkills[ProgrammingLanguage.python],
          isNotNull,
          reason:
              'the confirmed language now reaches the placeholder Engineer '
              'Matching itself scores, instead of being filtered out as '
              'unconfirmed',
        );
      },
    );
  });

  group('Issue #248: end-to-end recruit -> interview -> offer -> join -> '
      'Engineer materialization continuity (production aggregate path)', () {
    test(
      'a seeded, generated engineer-medium hire keeps their real main '
      'language and tech skills all the way through the actual production '
      'closeApril/closeMay join pipeline',
      () {
        // CORE-GAMEPLAY Phase 4.5: runSeed 1 is already relied on elsewhere
        // (public_demo_aggregate_test.dart) as one whose first
        // engineer-medium candidate clears the acceptance threshold at zero
        // salary delta, keeping this test deterministic.
        const runSeed = 1;
        // Mirrors public_demo_aggregate_test.dart's "TEST E: genuine
        // applicant happy path" exactly: recruit in April, close April
        // first (-> May), then interview/offer/pre-entry-sales/order all
        // happen against May's own fiscal close, so closeMay's join step
        // actually succeeds.
        var aggregate = PublicDemoAggregate.initial(runSeed: runSeed)
            .recruit(PublicDemoRecruitmentMedium.engineer)
            .aggregate!
            .closeApril(monthlyExpenses: 800000);
        final applicant = aggregate.workflow.applicants.first;
        final expectedDomainApplicant =
            PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
              runSeed: runSeed,
              applicantId: applicant.id,
            )!;

        aggregate = aggregate.completeInterview(applicant.id).aggregate;
        final interviewed = aggregate.workflow.applicants.firstWhere(
          (a) => a.id == applicant.id,
        );
        final offer = PublicDemoSalaryOfferEvaluator.evaluate(
          applicant: interviewed,
          offeredMonthlySalary: interviewed.requestedMonthlySalary,
        );
        aggregate = aggregate.acceptOffer(
          applicantId: applicant.id,
          offer: offer,
          fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
        );
        aggregate = aggregate
            .beginPreEntrySkillSheet(applicant.id)
            .beginPreEntrySelling(applicant.id)
            .introducePreEntryProject(applicant.id)
            .recordPreEntryPartnerInterviewResult(applicant.id)
            .recordPreEntryClientInterviewResult(applicant.id)
            .recordJuneOrder(applicant.id);

        final closedMay = aggregate.closeMay(week: 9, monthlyExpenses: 800000);
        expect(
          closedMay.workflow.applicants
              .firstWhere((a) => a.id == applicant.id)
              .hasJoined,
          isTrue,
          reason: 'fixture sanity: the join this test verifies must genuinely '
              'happen',
        );

        final runtime = closedMay.state.runtimeFor(applicant.id);
        expect(runtime.primaryLanguage, expectedDomainApplicant.mainLanguage);
        expect(
          runtime.confirmedLanguages,
          {expectedDomainApplicant.mainLanguage},
        );
        expect(runtime.actualCapability, applicant.salesSkillFit);
        expect(
          runtime.techSkills.toJson(),
          expectedDomainApplicant.techSkills.toJson(),
        );

        // Idempotency: re-deriving state.toJson()/fromJson() (a save then
        // reload immediately after join) must reproduce the exact same
        // runtime -- no drift, no duplicate materialization.
        final reloaded = PublicDemoState.fromJson(closedMay.state.toJson());
        expect(
          reloaded.runtimeFor(applicant.id).toJson(),
          runtime.toJson(),
        );
      },
    );
  });

  group(
    'Codex P1 fix on PR #249: an id shape alone is not proof of provenance',
    () {
      // A save created before CORE-GAMEPLAY Phase 2 (seeded recruitment) can
      // still carry a *pending* applicant whose id is already shaped like
      // `recruitment-<month>-<medium>-<slot>` -- the pre-Phase-2 fixed/
      // cyclic template pool used the exact same id scheme. Its stored
      // fields are whatever that old template pool assigned, which has no
      // relationship to what today's seeded generator would produce for the
      // same slot. This fixture stands in for that: a real id shape, but
      // deliberately mismatched résumé-visible fields.
      const runSeed = 1;
      const legacyStyleApplicant = PublicDemoApplicant(
        id: 'recruitment-4-engineer-1',
        name: '旧テンプレ応募者',
        resumeSummary: '旧テンプレート由来の履歴書',
        interviewScore: 80,
        // >= 60 so PublicDemoSalaryOfferEvaluator.evaluate genuinely
        // accepts the offer below — this fixture must reach a real join,
        // not merely resemble one.
        acceptanceScore: 90,
        // >= 65 so it genuinely clears both the pre-entry partner (>=60)
        // and client (>=65) interview thresholds below (mirrors
        // public_demo_aggregate_test.dart's own runSeed-1 comment) —
        // deliberately 68, not runSeed 1's real generated 73, so the
        // "genuinely mismatched" assertions below have something to prove.
        salesSkillFit: 68,
        experienceMonths: 999,
        requestedMonthlySalary: 999999,
      );

      test(
        'a genuinely fresh, seed-generated applicant is verified and its '
        'real source is used (the happy path this whole issue exists for)',
        () {
          final generated = PublicDemoSeededRecruitmentGenerator.generate(
            runSeed: runSeed,
            month: 4,
            medium: PublicDemoRecruitmentMedium.engineer,
            count: 1,
          ).single;

          final verified = PublicDemoSeededRecruitmentGenerator.verifiedSourceApplicantFor(
            runSeed: runSeed,
            applicant: generated,
          );

          expect(verified, isNotNull);
          expect(
            verified!.toJson(),
            PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
              runSeed: runSeed,
              applicantId: generated.id,
            )!.toJson(),
          );
        },
      );

      test(
        'an id-only match with a mismatched stored profile (the legacy '
        'pre-seeded-generator pending-applicant case) is rejected -- '
        'regenerateProjectedApplicant genuinely differs from what is stored',
        () {
          final projected = PublicDemoSeededRecruitmentGenerator.regenerateProjectedApplicant(
            runSeed: runSeed,
            applicantId: legacyStyleApplicant.id,
          );
          // Fixture sanity: the projected (seed-generated) candidate for
          // this exact id must genuinely differ from the legacy-style
          // fixture, or this test would not be exercising the mismatch path
          // at all.
          expect(projected, isNotNull);
          expect(projected!.salesSkillFit, isNot(legacyStyleApplicant.salesSkillFit));

          final verified = PublicDemoSeededRecruitmentGenerator.verifiedSourceApplicantFor(
            runSeed: runSeed,
            applicant: legacyStyleApplicant,
          );

          expect(
            verified,
            isNull,
            reason:
                'the id shape alone must never be trusted as provenance -- '
                'only a matching projected profile may be',
          );
        },
      );

      test(
        'fromApplicant falls back to the exact pre-existing placeholder '
        'behavior for such a mismatched legacy-style applicant -- it never '
        'adopts the unrelated regenerated profile\'s language/skill/tech',
        () {
          final unverifiedSource = PublicDemoSeededRecruitmentGenerator.verifiedSourceApplicantFor(
            runSeed: runSeed,
            applicant: legacyStyleApplicant,
          );
          final runtime = PublicDemoEngineerRuntime.fromApplicant(
            legacyStyleApplicant,
            sourceApplicant: unverifiedSource,
          );

          expect(runtime.primaryLanguage, ProgrammingLanguage.java);
          expect(runtime.confirmedLanguages, isEmpty);
          expect(runtime.techSkills.toJson(), const TechSkillLevels.zero().toJson());
          // Salary/experience authority is untouched by this fix either way
          // -- it never depended on sourceApplicant.
          expect(runtime.actualCapability, legacyStyleApplicant.salesSkillFit);
          expect(
            runtime.totalItExperienceMonths,
            legacyStyleApplicant.experienceMonths,
          );
        },
      );

      test(
        'end-to-end through the actual production join pipeline: a legacy '
        'pending applicant whose id collides with the seeded scheme still '
        'joins with its own real salary/experience and the safe placeholder '
        'technology profile -- never an unrelated regenerated identity',
        () {
          // Splices the legacy-style applicant into the JSON envelope
          // exactly the way `withLegacyFoundingApplicants`
          // (test_support/public_demo_legacy_applicant_test_helpers.dart)
          // simulates a pre-existing save, rather than fabricating a
          // production API to inject an applicant directly.
          final initialJson = PublicDemoAggregate.initial(
            runSeed: runSeed,
          ).toJson();
          final workflowJson = Map<String, dynamic>.from(
            initialJson['workflow'] as Map,
          );
          workflowJson['applicants'] = [legacyStyleApplicant.toJson()];
          // Mirrors TEST E in public_demo_aggregate_test.dart: close April
          // first (-> May) so the interview/offer/pre-entry-sales chain and
          // closeMay's own join step all run against the same (May) fiscal
          // close -- closeMay is a structural no-op while state.month != 5.
          var aggregate = PublicDemoAggregate.fromJson({
            ...initialJson,
            'workflow': workflowJson,
          }).closeApril(monthlyExpenses: 800000);

          aggregate = aggregate.completeInterview(legacyStyleApplicant.id).aggregate;
          final offer = PublicDemoSalaryOfferEvaluator.evaluate(
            applicant: aggregate.workflow.applicants.firstWhere(
              (a) => a.id == legacyStyleApplicant.id,
            ),
            offeredMonthlySalary: legacyStyleApplicant.requestedMonthlySalary,
          );
          aggregate = aggregate.acceptOffer(
            applicantId: legacyStyleApplicant.id,
            offer: offer,
            fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
          );
          aggregate = aggregate
              .beginPreEntrySkillSheet(legacyStyleApplicant.id)
              .beginPreEntrySelling(legacyStyleApplicant.id)
              .introducePreEntryProject(legacyStyleApplicant.id)
              .recordPreEntryPartnerInterviewResult(legacyStyleApplicant.id)
              .recordPreEntryClientInterviewResult(legacyStyleApplicant.id)
              .recordJuneOrder(legacyStyleApplicant.id);

          final closedMay = aggregate.closeMay(week: 9, monthlyExpenses: 800000);
          final joined = closedMay.workflow.applicants.firstWhere(
            (a) => a.id == legacyStyleApplicant.id,
          );
          expect(joined.hasJoined, isTrue, reason: 'fixture sanity');

          final runtime = closedMay.state.runtimeFor(legacyStyleApplicant.id);
          expect(runtime.primaryLanguage, ProgrammingLanguage.java);
          expect(runtime.confirmedLanguages, isEmpty);
          expect(runtime.techSkills.toJson(), const TechSkillLevels.zero().toJson());
          expect(runtime.actualCapability, legacyStyleApplicant.salesSkillFit);

          // Duplicate/retry: re-closing (a no-op month guard) and reloading
          // never re-materializes or drifts this runtime.
          final reloaded = PublicDemoState.fromJson(closedMay.state.toJson());
          expect(
            reloaded.runtimeFor(legacyStyleApplicant.id).toJson(),
            runtime.toJson(),
          );
          final retried = closedMay.closeMay(week: 9, monthlyExpenses: 800000);
          expect(
            retried.state.runtimeFor(legacyStyleApplicant.id).toJson(),
            runtime.toJson(),
          );
        },
      );
    },
  );
}
