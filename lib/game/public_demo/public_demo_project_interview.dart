import '../../domain/domain.dart';
import '../engine/client_interview_engine.dart';
import '../engine/project_interview_engine.dart';
import '../models/client_interview.dart';
import 'public_demo_engineer_runtime.dart';
import 'public_demo_matching_fit.dart';
import 'public_demo_project_generator.dart';
import 'public_demo_rng.dart';
import 'public_demo_state.dart';

/// Public Demo's adapter onto the main game's authoritative project/client
/// interview engines (`lib/game/engine/client_interview_engine.dart`,
/// `lib/game/engine/project_interview_engine.dart`) — reused as-is, not
/// reimplemented (CORE-GAMEPLAY Phase 6), exactly mirroring how
/// `public_demo_recruitment_interview.dart` is the sole gateway onto
/// [RecruitmentInterviewEngine] and `public_demo_matching_fit.dart` is the
/// sole gateway onto [MatchingEngine]. There is no second,
/// Public-Demo-only interview success formula anywhere in this file: every
/// question, answer, follow-up evaluation, and final pass/fail roll below
/// is a direct [ClientInterviewEngine]/[ProjectInterviewEngine] call.
///
/// The (engineer, project) pair driving every call here is always Phase 5's
/// real handoff: [PublicDemoEngineerProjectFit.engineerFor] (the same
/// placeholder [Engineer] Matching itself scored) and the genuine [Project]
/// [PublicDemoSeededProjectGenerator.regenerate] resolves from the player's
/// own [PublicDemoMatchingProposal] — never a fabricated stand-in.
class PublicDemoProjectInterview {
  const PublicDemoProjectInterview._();

  /// The exact placeholder [Engineer] Phase 5's own fit computation used
  /// for [runtime] — see [PublicDemoEngineerProjectFit.engineerFor]'s own
  /// doc for why this must never be rebuilt independently here.
  static Engineer engineerFor(PublicDemoEngineerRuntime runtime) =>
      PublicDemoEngineerProjectFit.engineerFor(runtime);

  /// A [SkillSheet] built from [runtime]'s own genuine, confirmed data —
  /// never inflated/fabricated. Public Demo employees (unlike a fresh
  /// recruitment candidate) have no "displayed vs. actual" résumé gap of
  /// their own once hired, so every field here is the runtime's real,
  /// current capability: only [PublicDemoEngineerRuntime.confirmedLanguages]
  /// contribute a language-experience entry (mirrors
  /// [PublicDemoEngineerProjectFit]'s own "only a confirmed language is
  /// real" rule), and `displayedLeader`/`displayedManager`/industry
  /// experience read straight from [runtime.techSkills]/
  /// [runtime.industryExperience].
  static SkillSheet skillSheetFor(
    PublicDemoEngineerRuntime runtime, {
    required int week,
  }) {
    final confirmedLanguageMonths = <ProgrammingLanguage, int>{
      for (final skill in runtime.languageSkills.values)
        if (runtime.confirmedLanguages.contains(skill.language))
          skill.language: skill.actualExperienceMonths,
    };
    return SkillSheet.fromActual(
      employeeId: runtime.engineerId,
      languageMonths: confirmedLanguageMonths,
      skills: runtime.techSkills,
      industryExperience: runtime.industryExperience,
      week: week,
    );
  }

  /// One `(runSeed, month, engineerId, projectId)`-derived seed, reused for
  /// this engineer/project pair's whole interview — question selection,
  /// every follow-up's deep-dive draw, and the final pass/fail roll all key
  /// off variants of this same stream via [PublicDemoRng], never a second
  /// independent seed source, so a save reload always recomputes the exact
  /// same values (SEEDED-RNG-REUSE-1).
  static int _seed({
    required int runSeed,
    required int month,
    required String engineerId,
    required String projectId,
  }) => PublicDemoRng.derivedSeed(
    runSeed: runSeed,
    month: month,
    namespace: PublicDemoRngNamespace.projectInterview,
    identifier: '$engineerId:$projectId',
  );

  /// Starts a fresh interview session for `(runtime.engineerId, candidate)`
  /// — mirrors [GameEngine.startClientInterview]'s own shape (question
  /// list drawn, first answer pre-computed) via
  /// [ClientInterviewEngine.questions]/[ClientInterviewEngine.answer].
  static ClientInterviewSession start({
    required PublicDemoState state,
    required PublicDemoEngineerRuntime runtime,
    required PublicDemoProjectCandidate candidate,
  }) {
    final engineer = engineerFor(runtime);
    final sheet = skillSheetFor(runtime, week: state.month);
    final seed = _seed(
      runSeed: state.runSeed,
      month: state.month,
      engineerId: runtime.engineerId,
      projectId: candidate.id,
    );
    final questions = ClientInterviewEngine.questions(
      seed: seed,
      employee: engineer,
      project: candidate.project,
      sheet: sheet,
    );
    final first = ClientInterviewEngine.answer(
      engineer,
      candidate.project,
      questions.first,
    );
    return ClientInterviewSession(
      id: 'public-demo-project-interview:${runtime.engineerId}:${candidate.id}',
      applicationId: candidate.id,
      employeeId: runtime.engineerId,
      projectId: candidate.id,
      clientId: candidate.client.id,
      startedWeek: state.month,
      questions: questions,
      employeeAnswers: [first],
    );
  }

  /// The player's available follow-up choices for [session]'s current
  /// question — verbatim [ClientInterviewEngine.choices].
  static List<ClientInterviewFollowUp> choicesFor(
    ClientInterviewSession session,
  ) => ClientInterviewEngine.choices(
    session.questions[session.currentQuestionIndex],
  );

  /// Applies the player's follow-up choice to [session]'s current question,
  /// then — mirroring [GameEngine.chooseClientInterviewFollowUp] exactly —
  /// either advances to the next question (pre-computing its answer) or
  /// leaves the session ready for [conclude] once every question has a
  /// chosen follow-up. Never touches `completed`/`result` itself: those are
  /// only ever set by [conclude], exactly like the main game's own
  /// `_completeClientInterview`.
  static ClientInterviewSession chooseFollowUp({
    required int runSeed,
    required PublicDemoEngineerRuntime runtime,
    required Project project,
    required ClientInterviewSession session,
    required ClientInterviewFollowUp followUp,
  }) {
    final engineer = engineerFor(runtime);
    final question = session.questions[session.currentQuestionIndex];
    final answer = session.employeeAnswers[session.currentQuestionIndex];
    final seed = _seed(
      runSeed: runSeed,
      month: session.startedWeek,
      engineerId: runtime.engineerId,
      projectId: project.id,
    );
    final outcome = ClientInterviewEngine.evaluate(
      engineer,
      question,
      answer,
      followUp,
      seed,
      session.id,
    );
    var updated = session.copyWith(
      playerFollowUps: [...session.playerFollowUps, followUp],
      interviewerReactions: [...session.interviewerReactions, outcome.reaction],
      accumulatedEvaluation: session.accumulatedEvaluation.add(
        technical: outcome.evaluation.technical,
        experience: outcome.evaluation.experience,
        communication: outcome.evaluation.communication,
        credibility: outcome.evaluation.credibility,
        clientFit: outcome.evaluation.clientFit,
      ),
      deepDiveOccurred: session.deepDiveOccurred || outcome.deepDive,
      mismatchFailure:
          session.mismatchFailure || (outcome.deepDive && question.mismatch >= 2),
    );
    if (session.currentQuestionIndex < session.questions.length - 1) {
      final nextIndex = session.currentQuestionIndex + 1;
      final nextAnswer = ClientInterviewEngine.answer(
        engineer,
        project,
        session.questions[nextIndex],
      );
      updated = updated.copyWith(
        currentQuestionIndex: nextIndex,
        employeeAnswers: [...updated.employeeAnswers, nextAnswer],
      );
    }
    return updated;
  }

  /// Whether every question in [session] has already received a
  /// player-chosen follow-up — [conclude] refuses to run before this holds.
  static bool isReadyToConclude(ClientInterviewSession session) =>
      session.playerFollowUps.length >= session.questions.length;

  /// The final, deterministic pass/fail decision for a fully-answered
  /// [session] — [ClientInterviewEngine.finalRate] (fit + personality +
  /// trust/track-record-derived accumulated evaluation, clamped [5, 95])
  /// rolled via [ProjectInterviewEngine.roll]'s small seeded RNG. The same
  /// `(runSeed, session, project, choices)` always reproduces the same
  /// `(passed, score)` — the roll's salt folds in every
  /// [session.playerFollowUps] choice by name, so a different choice
  /// sequence can change the outcome even when it does not change the
  /// clamped rate itself. Never a coin flip: [rate] alone already reflects
  /// fit/choices/trust before any randomness is applied, and callers must
  /// never surface [rate] itself to the player (HIDDEN-PARAMS-1) — only the
  /// resulting `passed` and, on failure, [failureReasons].
  static ({bool passed, int score}) conclude({
    required int runSeed,
    required PublicDemoEngineerRuntime runtime,
    required Project project,
    required ClientInterviewSession session,
  }) {
    final engineer = engineerFor(runtime);
    final rate = ClientInterviewEngine.finalRate(engineer, project, session);
    final seed = _seed(
      runSeed: runSeed,
      month: session.startedWeek,
      engineerId: runtime.engineerId,
      projectId: project.id,
    );
    final passed = ProjectInterviewEngine.roll(
      rate: rate,
      seed: seed,
      week: session.startedWeek,
      salt:
          'public-demo-project-interview-result:${session.id}:'
          '${session.playerFollowUps.map((choice) => choice.name).join(',')}',
    );
    return (passed: passed, score: rate);
  }

  /// The 1-2 most plausible, truthful reasons a failed interview did not
  /// pass — verbatim [ProjectInterviewEngine.failureReasons], never an
  /// invented cause outside the real [MatchingEngine] fit breakdown.
  static List<String> failureReasons(
    PublicDemoEngineerRuntime runtime,
    Project project,
  ) => ProjectInterviewEngine.failureReasons(engineerFor(runtime), project);
}
