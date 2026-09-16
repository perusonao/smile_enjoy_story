import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/app_experience.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/game/persistence/save_service.dart';

import 'test_helpers.dart';

GameState atClientInterview({int seed = 42, bool mismatch = false}) {
  var s = GameEngine.newGame(seed: seed);
  final e = s.engineers.first, p = s.openProjects.first.project;
  var sheet = s.skillSheetFor(e.id);
  if (mismatch && p.requiredLanguages.isNotEmpty) {
    final l = p.requiredLanguages.first;
    sheet = sheet.copyWith(
      displayedLanguageExperience: {
        ...sheet.displayedLanguageExperience,
        l: e.profile.skillFor(l).actualExperienceMonths + 36,
      },
      displayedLeader: 5,
    );
    s = s.copyWith(skillSheets: [sheet, ...s.skillSheets.skip(1)]);
  }
  final index = p.selectionFlow.steps.indexOf(SelectionStep.clientInterview);
  return s.copyWith(
    proposals: [
      ProjectProposal(
        id: 'client-app',
        engineerId: e.id,
        project: p,
        proposedWeek: s.week,
        stage: ProposalStage.proposed,
        currentStepIndex: index,
        fitScore: 70,
      ),
    ],
  );
}

void main() {
  test('client interview waits for manual decision and blocks week', () {
    final s = atClientInterview();
    final advanced = GameEngine.advanceWeek(s);
    expect(advanced.week, s.week);
    expect(
      TaskEngine.generateTasks(
        s,
      ).any((t) => t.id.startsWith('client-interview')),
      isTrue,
    );
  });
  test('play creates three deterministic SkillSheet-driven questions', () {
    final a = GameEngine.startClientInterview(
      atClientInterview(seed: 7, mismatch: true),
      'client-app',
    );
    final b = GameEngine.startClientInterview(
      atClientInterview(seed: 7, mismatch: true),
      'client-app',
    );
    expect(a.clientInterviews.single.questions.length, 3);
    expect(
      a.clientInterviews.single.toJson(),
      b.clientInterviews.single.toJson(),
    );
    expect(
      a.clientInterviews.single.questions.any(
        (q) =>
            q.category == ClientInterviewQuestionCategory.technicalExperience,
      ),
      isTrue,
    );
    expect(
      a.clientInterviews.single.questions.any((q) => q.mismatch > 0),
      isTrue,
    );
  });
  test(
    'actual ability drives answer while inflated sheet raises vague risk',
    () {
      final honest = GameEngine.startClientInterview(
        atClientInterview(seed: 8),
        'client-app',
      ).clientInterviews.single;
      final inflated = GameEngine.startClientInterview(
        atClientInterview(seed: 8, mismatch: true),
        'client-app',
      ).clientInterviews.single;
      final hi = inflated.questions.indexWhere((q) => q.mismatch > 0);
      expect(hi, isNonNegative);
      final ie = atClientInterview(seed: 8, mismatch: true).engineers.first,
          ip = atClientInterview(seed: 8, mismatch: true).proposals.first;
      final answer = ClientInterviewEngine.answer(
        ie,
        ip.project,
        inflated.questions[hi],
      );
      expect(answer.vague, isTrue);
      expect(
        honest.employeeAnswers.first.quality,
        greaterThanOrEqualTo(inflated.employeeAnswers.first.quality),
      );
    },
  );
  test('three follow-ups complete result and selection continues', () {
    var s = GameEngine.startClientInterview(
      atClientInterview(seed: 12),
      'client-app',
    );
    for (var i = 0; i < 3; i++) {
      final session = s.clientInterviews.single;
      s = GameEngine.chooseClientInterviewFollowUp(
        s,
        session.id,
        ClientInterviewFollowUp.letEmployeeHandle,
      );
    }
    expect(s.clientInterviews.single.completed, isTrue);
    expect(s.clientInterviews.single.playerFollowUps.length, 3);
    expect(
      s.proposals.single.status != ApplicationStatus.active ||
          s.proposals.single.currentStepIndex >
              atClientInterview(seed: 12).proposals.single.currentStepIndex,
      isTrue,
    );
  });
  test('auto resolve completes and save round-trips', () {
    final s = GameEngine.autoResolveClientInterview(
      atClientInterview(seed: 14),
      'client-app',
    );
    expect(s.clientInterviews.single.completed, isTrue);
    expect(
      s.clientInterviews.single.playerFollowUps,
      everyElement(ClientInterviewFollowUp.letEmployeeHandle),
    );
    expect(GameState.fromJson(s.toJson()).toJson(), s.toJson());
  });
  group(
    'SES First Fun Quarter AI Replay Audit #2 P1-1: requiredLanguages '
    'empty never leaks an internal enum identifier into player-facing text',
    () {
      test(
        'every question target — for every category, both 上位会社面談 and '
        '客先面談 share this same engine — is a human-readable label, never '
        'ClientInterviewQuestionCategory.name',
        () {
          // requiredLanguages empty is the exact root cause condition the
          // audit found; requiredLeader>0 and a displayedIndustryExperience
          // entry force every conditional category (leadership,
          // industryExperience) into the candidate list alongside the
          // unconditional ones, so count:8 exercises every category's
          // `_target` fallback in one pass, not just technicalExperience's.
          final project = buildProject(requiredLanguages: const [], requiredLeader: 2);
          final engineer = buildEngineer();
          final sheet = SkillSheet.fromActual(
            employeeId: engineer.id,
            languageMonths: {ProgrammingLanguage.java: 36},
            skills: engineer.profile.techSkills,
            industryExperience: {Industry.other: 12},
            week: 1,
          );

          final questions = ClientInterviewEngine.questions(
            seed: 1,
            employee: engineer,
            project: project,
            sheet: sheet,
            count: 8,
          );
          expect(questions.length, 8);

          for (final q in questions) {
            for (final c in ClientInterviewQuestionCategory.values) {
              expect(
                q.target,
                isNot(equals(c.name)),
                reason:
                    '${q.category} question target must never be a raw '
                    'ClientInterviewQuestionCategory identifier',
              );
            }
          }

          final technical = questions.firstWhere(
            (q) => q.category == ClientInterviewQuestionCategory.technicalExperience,
          );
          expect(technical.target, isNot('technicalExperience'));

          final answer = ClientInterviewEngine.answer(engineer, project, technical);
          expect(answer.text, isNot(contains('technicalExperience')));
          expect(answer.text, contains(technical.target));
        },
      );
    },
  );

  group(
    'SES First Fun Quarter AI Replay Audit #2 Codex Broad Review P1: '
    'legacy save sanitizes on load without touching authority',
    () {
      test(
        'a legacy save whose stored target/answer text embeds a raw '
        'technicalExperience enum identifier is sanitized on load — past, '
        'current, and next answers are all clean; quality/vague/mismatch/ '
        'category and eventual pass-fail are untouched; save/reload '
        'round-trips',
        () async {
          SharedPreferences.setMockInitialValues({});
          final saveService = SaveService.forExperience(
            AppExperience.development,
          );

          // A genuine session, advanced one follow-up so an already-answered
          // (index 0) and a freshly precomputed current (index 1) answer
          // both exist already — exactly what a legacy resumed session
          // would show.
          var control = GameEngine.startClientInterview(
            atClientInterview(seed: 7, mismatch: true),
            'client-app',
          );
          final sessionId = control.clientInterviews.single.id;
          control = GameEngine.chooseClientInterviewFollowUp(
            control,
            sessionId,
            ClientInterviewFollowUp.letEmployeeHandle,
          );
          final originalSession = control.clientInterviews.single;
          final originalQuestions = originalSession.questions;
          final originalAnswers = originalSession.employeeAnswers;

          // Simulate a legacy save: corrupt only the two presentation-only
          // fields the pre-fix `_target()` bug actually wrote (target/text)
          // — category/mismatch/quality/vague are left exactly as the real
          // engine produced them, matching what an old save genuinely
          // looked like (the bug never touched those fields).
          final json = control.toJson();
          final sessionsJson = (json['clientInterviews'] as List)
              .cast<Map<String, dynamic>>();
          final questionsJson = (sessionsJson[0]['questions'] as List)
              .cast<Map<String, dynamic>>();
          final answersJson = (sessionsJson[0]['employeeAnswers'] as List)
              .cast<Map<String, dynamic>>();
          questionsJson[0]['target'] = 'technicalExperience';
          answersJson[0]['text'] =
              'technicalExperienceの案件には参加しています。担当範囲はチームで対応することが多く、'
              '補助的に経験しました。';
          questionsJson[1]['target'] = 'technicalExperience';
          answersJson[1]['text'] =
              'technicalExperienceを使った開発で、設計から実装・単体試験まで担当しました。課題は'
              'チームと確認しながら具体的に解決しました。';

          await SharedPreferences.getInstance().then(
            (prefs) =>
                prefs.setString(SaveService.developmentKey, jsonEncode(json)),
          );

          final loaded = await saveService.load();
          expect(loaded, isNotNull);
          final loadedSession = loaded!.clientInterviews.single;

          // 6/7: past (index 0) and current (index 1) answers are clean.
          for (final categoryName
              in ClientInterviewQuestionCategory.values.map((c) => c.name)) {
            expect(loadedSession.questions[0].target, isNot(categoryName));
            expect(loadedSession.questions[1].target, isNot(categoryName));
          }
          expect(
            loadedSession.employeeAnswers[0].text,
            isNot(contains('technicalExperience')),
          );
          expect(
            loadedSession.employeeAnswers[1].text,
            isNot(contains('technicalExperience')),
          );

          // 9: quality/vague/mismatch/category — the authority fields —
          // are byte-identical to what the real engine originally produced,
          // never recomputed by sanitization.
          for (var i = 0; i < 2; i++) {
            expect(
              loadedSession.employeeAnswers[i].quality,
              originalAnswers[i].quality,
            );
            expect(
              loadedSession.employeeAnswers[i].vague,
              originalAnswers[i].vague,
            );
            expect(
              loadedSession.questions[i].mismatch,
              originalQuestions[i].mismatch,
            );
            expect(
              loadedSession.questions[i].category,
              originalQuestions[i].category,
            );
          }

          // 8: resuming — a freshly-computed "next" answer — is also clean.
          final resumedOnce = GameEngine.chooseClientInterviewFollowUp(
            loaded,
            sessionId,
            ClientInterviewFollowUp.letEmployeeHandle,
          );
          expect(
            resumedOnce.clientInterviews.single.employeeAnswers[2].text,
            isNot(contains('technicalExperience')),
          );

          // 10: score/pass-fail authority is unaffected by sanitization —
          // finishing the SAME sequence of follow-ups from the uncorrupted
          // control and from the sanitized/reloaded save must resolve
          // identically.
          final controlOnce = GameEngine.chooseClientInterviewFollowUp(
            control,
            sessionId,
            ClientInterviewFollowUp.letEmployeeHandle,
          );
          final resumedFinal = GameEngine.chooseClientInterviewFollowUp(
            resumedOnce,
            sessionId,
            ClientInterviewFollowUp.letEmployeeHandle,
          );
          final controlFinal = GameEngine.chooseClientInterviewFollowUp(
            controlOnce,
            sessionId,
            ClientInterviewFollowUp.letEmployeeHandle,
          );
          expect(
            resumedFinal.clientInterviews.single.completed,
            controlFinal.clientInterviews.single.completed,
          );
          expect(
            resumedFinal.clientInterviews.single.result,
            controlFinal.clientInterviews.single.result,
          );
          expect(
            resumedFinal.clientInterviews.single.accumulatedEvaluation.total,
            controlFinal.clientInterviews.single.accumulatedEvaluation.total,
          );

          // 11: save/reload round-trips — already-sanitized data is
          // unchanged by a second pass (idempotent).
          await saveService.save(resumedFinal);
          final reloaded = await saveService.load();
          expect(reloaded!.toJson(), resumedFinal.toJson());
        },
      );
    },
  );

  test('aggressive mismatch can deep dive and affects trust', () {
    var found = false;
    for (var seed = 1; seed < 100 && !found; seed++) {
      var s = GameEngine.startClientInterview(
        atClientInterview(seed: seed, mismatch: true),
        'client-app',
      );
      final before = s.engineers.first.companyTrust;
      for (var i = 0; i < 3; i++) {
        final session = s.clientInterviews.single;
        final q = session.questions[session.currentQuestionIndex];
        final choice = q.category == ClientInterviewQuestionCategory.leadership
            ? ClientInterviewFollowUp.emphasizeLeadership
            : q.category == ClientInterviewQuestionCategory.industryExperience
            ? ClientInterviewFollowUp.emphasizeIndustry
            : ClientInterviewFollowUp.emphasizeTechnical;
        s = GameEngine.chooseClientInterviewFollowUp(s, session.id, choice);
      }
      if (s.clientInterviews.single.deepDiveOccurred) {
        found = true;
        expect(s.engineers.first.companyTrust, lessThanOrEqualTo(before));
      }
    }
    expect(found, isTrue);
  });
}
