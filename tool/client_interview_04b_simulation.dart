// ignore_for_file: avoid_print
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main(List<String> args) {
  final games = args.isEmpty ? 200 : int.parse(args.first);
  for (final strategy in _Strategy.values) {
    final m = _Metrics();
    for (var seed = 1; seed <= games; seed++) {
      var s = GameEngine.newGame(seed: seed);
      for (final e in s.engineers) {
        if (strategy == _Strategy.aggressive) {
          final sheet = s.skillSheetFor(e.id),
              language = e.profile.mainLanguage;
          s = GameEngine.editSkillSheet(
            s,
            sheet.copyWith(
              displayedLanguageExperience: {
                ...sheet.displayedLanguageExperience,
                language:
                    (sheet.displayedLanguageExperience[language] ?? 0) + 36,
              },
              displayedLeader: 5,
            ),
          );
        }
        s = GameEngine.startSales(s, e.id);
      }
      int? firstAssignment;
      while (s.status == GameStatus.playing && s.week < 48) {
        for (final o
            in s.interviewOffers
                .where((o) => o.status == InterviewOfferStatus.pending)
                .toList()) {
          s = GameEngine.acceptInterviewOffer(s, o.id);
        }
        for (final p
            in s.proposals
                .where(
                  (p) =>
                      p.status == ApplicationStatus.active &&
                      p.currentStep == SelectionStep.clientInterview,
                )
                .toList()) {
          if (strategy == _Strategy.noIntervention) {
            s = GameEngine.autoResolveClientInterview(s, p.id);
          } else {
            s = GameEngine.startClientInterview(s, p.id);
            for (var i = 0; i < 3; i++) {
              final session = s.clientInterviews.last,
                  q = session.questions[session.currentQuestionIndex];
              final choice = strategy == _Strategy.safe
                  ? (q.mismatch > 0
                        ? ClientInterviewFollowUp.adjustExpectation
                        : _safe(q))
                  : _aggressive(q);
              s = GameEngine.chooseClientInterviewFollowUp(
                s,
                session.id,
                choice,
              );
            }
          }
        }
        for (final o
            in s.offers
                .where((o) => o.status == OfferStatus.pending)
                .toList()) {
          s = GameEngine.acceptOffer(s, o.id);
        }
        for (final a
            in s.activeAssignments
                .where(
                  (a) =>
                      a.remainingWeeks <= 4 &&
                      a.contractDecision == ContractDecision.undecided,
                )
                .toList()) {
          s = GameEngine.decideContract(s, a.engineerId, true);
        }
        for (final e in s.engineers.where(
          (e) =>
              e.status == EngineerStatus.waiting &&
              e.salesStatus != SalesStatus.selling,
        )) {
          s = GameEngine.startSales(s, e.id);
        }
        s = GameEngine.advanceWeek(s);
        if (firstAssignment == null && s.activeAssignments.isNotEmpty) {
          firstAssignment = s.week;
        }
      }
      m.add(s, firstAssignment);
    }
    m.report(strategy.name);
  }
}

ClientInterviewFollowUp _safe(ClientInterviewQuestion q) =>
    switch (q.category) {
      ClientInterviewQuestionCategory.technicalExperience =>
        ClientInterviewFollowUp.emphasizeTechnical,
      ClientInterviewQuestionCategory.industryExperience =>
        ClientInterviewFollowUp.emphasizeIndustry,
      ClientInterviewQuestionCategory.leadership =>
        ClientInterviewFollowUp.emphasizeLeadership,
      _ => ClientInterviewFollowUp.letEmployeeHandle,
    };
ClientInterviewFollowUp _aggressive(ClientInterviewQuestion q) =>
    switch (q.category) {
      ClientInterviewQuestionCategory.industryExperience =>
        ClientInterviewFollowUp.emphasizeIndustry,
      ClientInterviewQuestionCategory.leadership =>
        ClientInterviewFollowUp.emphasizeLeadership,
      _ => ClientInterviewFollowUp.emphasizeTechnical,
    };

enum _Strategy { noIntervention, safe, aggressive }

class _Metrics {
  int games = 0,
      interviews = 0,
      passes = 0,
      deep = 0,
      mismatch = 0,
      offers = 0,
      survived = 0,
      firstAssignment = 0,
      assigned = 0;
  double trust = 0;
  void add(GameState s, int? first) {
    games++;
    interviews += s.clientInterviews.length;
    passes += s.clientInterviews
        .where((x) => x.result == ClientInterviewResult.passed)
        .length;
    deep += s.clientInterviews.where((x) => x.deepDiveOccurred).length;
    mismatch += s.clientInterviews
        .where(
          (x) => x.mismatchFailure && x.result == ClientInterviewResult.failed,
        )
        .length;
    trust +=
        s.engineers.fold<int>(0, (n, e) => n + e.companyTrust) /
        s.engineers.length;
    offers += s.stats.offersReceived;
    if (first != null) {
      firstAssignment += first;
      assigned++;
    }
    if (s.status != GameStatus.bankrupt) survived++;
  }

  void report(String name) {
    print(
      '$name clientInterviews=$interviews passRate=${interviews == 0 ? 0 : passes / interviews * 100} deepDiveRate=${interviews == 0 ? 0 : deep / interviews * 100} mismatchFailureRate=${interviews == 0 ? 0 : mismatch / interviews * 100} averageTrust=${trust / games} offers=$offers firstAssignmentWeek=${assigned == 0 ? 'N/A' : firstAssignment / assigned} survival48=${survived / games * 100}',
    );
  }
}
