import 'package:smile_enjoy_story/domain/models/hidden_parameters.dart';
import 'package:smile_enjoy_story/domain/models/language_skill.dart';
import 'package:smile_enjoy_story/domain/models/programming_language.dart';
import 'package:smile_enjoy_story/domain/models/tech_skill_levels.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';

/// RECOVERY-LOOP-1 test support: builds a [PublicDemoAggregate] at
/// [targetMonth] (4-15) by chaining the SAME real month-close commands
/// production code uses, starting from [PublicDemoAggregate.initial] —
/// never a reconstruction shortcut, matching every other Public Demo test
/// fixture in this suite (see public_demo_aggregate_test.dart's own class
/// doc).
///
/// No engineer or applicant is ever run through the sales/pre-entry
/// pipeline by this helper, and no hire is ever accepted — both founding
/// engineers stay economically waiting at every month this returns, which
/// is exactly the starting condition a Recovery scenario needs.
///
/// [monthlyExpenses] defaults to a deliberately small value: with nobody
/// ever assigned, every close here books zero revenue, so a
/// production-realistic expense figure (e.g. ¥800,000/month) would drive
/// the company into cashShortage/bankruptcy well before February purely as
/// an artifact of this fixture — not anything Recovery-specific — silently
/// freezing `state.month` and making later months unreachable. Callers
/// testing Finance behavior pass their own realistic value to the specific
/// close they exercise afterward instead.
PublicDemoAggregate publicDemoAggregateAtMonth(
  int targetMonth, {
  int monthlyExpenses = 10000,
}) {
  assert(
    targetMonth >= 4 && targetMonth <= 15,
    'targetMonth must be within Public Demo 0.1\'s fiscal year (4-15)',
  );
  var aggregate = PublicDemoAggregate.initial();
  if (targetMonth == 4) return aggregate;
  aggregate = aggregate.closeApril(monthlyExpenses: monthlyExpenses);
  if (targetMonth == 5) return aggregate;
  aggregate = aggregate.closeMay(week: 9, monthlyExpenses: monthlyExpenses);
  if (targetMonth == 6) return aggregate;
  aggregate = aggregate.closeJune(
    assignedInJuly: 0,
    monthlyExpenses: monthlyExpenses,
  );
  if (targetMonth == 7) return aggregate;
  aggregate = aggregate.closeJuly(monthlyExpenses: monthlyExpenses);
  for (var month = 8; month < targetMonth; month++) {
    aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: monthlyExpenses);
  }
  return aggregate;
}

/// Advances [engineerId] through the real, unchanged engineer sales
/// pipeline — `startSkillSheetReview` → `beginSelling` → `introduceProject`
/// → partner interview → client interview → `recordOrder` — to
/// [PublicDemoSalesStage.ordered] with a genuine
/// [PublicDemoEngineerSales.hasGenuineInterviewRecord]. None of these
/// commands are month-gated, so this works identically whether called in
/// April or in December — the same chain Recovery relies on being usable
/// again after May.
PublicDemoAggregate publicDemoAdvanceEngineerToOrdered(
  PublicDemoAggregate aggregate,
  String engineerId,
) => aggregate
    .startSkillSheetReview(engineerId)
    .beginSelling(engineerId)
    .introduceProject(engineerId)
    .recordEngineerInterviewResult(
      engineerId: engineerId,
      type: PublicDemoInterviewType.partner,
    )
    .recordEngineerInterviewResult(
      engineerId: engineerId,
      type: PublicDemoInterviewType.client,
    )
    .recordOrder(engineerId);

/// A runtime with `actualCapability == capability` for [engineerId] — high
/// enough (default 80) to always clear
/// [PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement] (60).
PublicDemoEngineerRuntime publicDemoRecoveryRuntime(
  String engineerId, {
  int capability = 80,
}) => PublicDemoEngineerRuntime(
  engineerId: engineerId,
  primaryLanguage: ProgrammingLanguage.java,
  languageSkills: {
    ProgrammingLanguage.java: LanguageSkill(
      language: ProgrammingLanguage.java,
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
