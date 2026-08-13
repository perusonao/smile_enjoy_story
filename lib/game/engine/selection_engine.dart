import '../../domain/domain.dart';
import 'matching_engine.dart';
import 'project_interview_engine.dart';

class SelectionEngine {
  const SelectionEngine._();

  static int successRate(
    Engineer engineer,
    Project project,
    SelectionStep step,
  ) {
    final fit = MatchingEngine.computeFit(engineer, project);
    final profile = engineer.profile;
    final personality = profile.personality;
    final tech = profile.techSkills;
    final interview = profile.hidden.projectInterviewSkill;
    final competitionPenalty = (project.competitionLevel - 1) * 3;

    double raw;
    switch (step) {
      case SelectionStep.documentScreening:
        raw =
            fit.techScore * 1.05 +
            fit.experienceScore * 1.8 +
            fit.conditionScore +
            18 -
            project.difficulty * 3;
      case SelectionStep.upperCompanyInterview:
        raw =
            fit.total * .45 +
            personality.communication * 5 +
            personality.cleanliness * 4 +
            interview * 5 +
            12 -
            project.difficulty * 3 -
            competitionPenalty * .5;
      case SelectionStep.technicalInterview:
        final domain = [
          tech.database,
          tech.network,
          tech.infrastructure,
          tech.frontend,
          tech.backend,
        ].reduce((a, b) => a > b ? a : b);
        raw =
            fit.techScore * 1.15 +
            fit.experienceScore * 1.5 +
            domain * 4 +
            12 -
            project.difficulty * 4 -
            competitionPenalty;
      case SelectionStep.clientInterview:
        raw =
            fit.total * .55 +
            personality.communication * 4 +
            interview * 5 +
            12 -
            project.difficulty * 4 -
            competitionPenalty;
      case SelectionStep.finalInterview:
        raw =
            fit.total * .42 +
            personality.communication * 4 +
            tech.leader * 5 +
            tech.manager * 5 +
            interview * 3 +
            8 -
            project.difficulty * 4 -
            competitionPenalty;
      case SelectionStep.offer:
        return 95;
    }
    // Parallel selling should create meaningful choices rather than a wall
    // of early rejections. The prototype-wide calibration bonus keeps a
    // reasonable engineer around 70-85% per step while weak fits still fail.
    return (raw + 30).round().clamp(5, 95);
  }

  static bool roll({
    required int rate,
    required int seed,
    required int week,
    required Object salt,
  }) => ProjectInterviewEngine.roll(
    rate: rate,
    seed: seed,
    week: week,
    salt: salt,
  );

  static String rejectionReason(
    Engineer engineer,
    Project project,
    SelectionStep step,
  ) {
    final fit = MatchingEngine.computeFit(engineer, project);
    return switch (step) {
      SelectionStep.documentScreening =>
        fit.techScore < 35 ? '必須スキル・必要経験が不足していました' : '書類上の案件要件との一致度が不足していました',
      SelectionStep.upperCompanyInterview =>
        engineer.profile.personality.communication < 3
            ? 'コミュニケーション評価が基準に届きませんでした'
            : '経歴の信頼性に懸念がありました',
      SelectionStep.technicalInterview => '技術力または実務経験が基準に届きませんでした',
      SelectionStep.clientInterview =>
        project.competitionLevel >= 4
            ? '他候補者がより案件要件に適合していました'
            : '案件との総合適合度が不足していました',
      SelectionStep.finalInterview =>
        engineer.profile.techSkills.leader < 3
            ? 'リーダー経験が不足していました'
            : '顧客折衝経験が基準に届きませんでした',
      SelectionStep.offer => '募集が終了しました',
    };
  }
}
