import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_workflow_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

void main() {
  const experiencedApplicant = PublicDemoApplicant(
    id: 'experienced',
    name: 'Experienced Applicant',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
    experienceMonths: 36,
  );

  test('established applicant templates retain nonzero experience', () {
    expect(
      publicDemoMayApplicants.map((applicant) => applicant.experienceMonths),
      everyElement(greaterThan(0)),
    );
  });

  test('established 高橋・田中 templates remain unchanged', () {
    expect(
      publicDemoMayApplicants
          .map(
            (applicant) => (
              applicant.id,
              applicant.name,
              applicant.interviewScore,
              applicant.acceptanceScore,
              applicant.requestedMonthlySalary,
              applicant.salesSkillFit,
              applicant.experienceMonths,
            ),
          )
          .toList(),
      equals([
        ('app-01', '高橋 翔', 74, 68, 320000, 76, 48),
        ('app-02', '田中 美咲', 58, 82, 300000, 62, 36),
      ]),
    );
  });

  test('zero experience identifies an inexperienced applicant', () {
    const applicant = PublicDemoApplicant(
      id: 'inexperienced',
      name: 'Inexperienced Applicant',
      resumeSummary: 'IT学習中',
      interviewScore: 50,
      acceptanceScore: 70,
      salesSkillFit: 40,
      experienceMonths: 0,
    );

    expect(applicant.isInexperienced, isTrue);
    expect(experiencedApplicant.isInexperienced, isFalse);
  });

  test('negative experience is rejected', () {
    expect(
      () => PublicDemoApplicant(
        id: 'invalid',
        name: 'Invalid Applicant',
        resumeSummary: '',
        interviewScore: 0,
        acceptanceScore: 0,
        salesSkillFit: 0,
        experienceMonths: -1,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('copying, offer application, and entry retain experience', () {
    final offered = experiencedApplicant.copyWith(
      acceptedMonthlySalary: 320000,
    );
    final entered = offered
        .copyWith(stage: PublicDemoApplicantStage.offerAccepted)
        .join(
          week: 9,
          currentFiscalCloseId: PublicDemoFiscalCloseId.forMonth(5),
        );

    expect(offered.experienceMonths, 36);
    expect(entered.experienceMonths, 36);
  });

  test('recruitment media preserves template experience', () {
    final transaction = PublicDemoRecruitmentWorkflowTransaction();
    final result = transaction.execute(
      state: PublicDemoState.aprilStart(),
      workflow: PublicDemoWorkflowState.initial(),
      medium: PublicDemoRecruitmentMedium.engineer,
    );

    expect(result.isSuccess, isTrue);
    expect(
      result.generatedApplicants.map((applicant) => applicant.experienceMonths),
      everyElement(greaterThan(0)),
    );
  });

  test('free pool has both experienced and inexperienced templates', () {
    expect(
      publicDemoFreeApplicants.any((applicant) => applicant.isInexperienced),
      isTrue,
    );
    expect(
      publicDemoFreeApplicants.any((applicant) => !applicant.isInexperienced),
      isTrue,
    );
  });
}
