// ignore_for_file: avoid_print
//
// Playable 0.4C playtest: compares a "generous" welfare strategy (health
// checks, bonuses, company trips, PC upgrades whenever affordable) against a
// "stingy" one (never spends on welfare) across many seeds, to check the
// trade-off actually bites — generous should cost cash but keep morale/trust
// higher and turnover risk lower; stingy should conserve cash but let morale
// and trust decay.
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  for (final strategy in ['generous', 'stingy']) {
    final m = _Metrics();
    for (var seed = 1; seed <= 150; seed++) {
      var s = GameEngine.newGame(seed: seed);
      for (final e in s.engineers) {
        s = GameEngine.startSales(s, e.id);
      }

      while (s.status == GameStatus.playing && s.week < 48) {
        for (final p in s.proposals.where((p) => p.status == ApplicationStatus.active && p.currentStep == SelectionStep.clientInterview).toList()) {
          if (!s.clientInterviews.any((session) => session.applicationId == p.id && session.completed)) {
            s = GameEngine.autoResolveClientInterview(s, p.id);
          }
        }
        for (final o in s.interviewOffers.where((o) => o.status == InterviewOfferStatus.pending).toList()) {
          s = GameEngine.acceptInterviewOffer(s, o.id);
        }
        for (final o in s.offers.where((o) => o.status == OfferStatus.pending).toList()) {
          s = GameEngine.acceptOffer(s, o.id);
        }
        for (final a in s.activeAssignments.where((a) => a.remainingWeeks <= 4 && a.contractDecision == ContractDecision.undecided).toList()) {
          s = GameEngine.decideContract(s, a.engineerId, true);
        }
        for (final e in s.engineers.where((e) => e.status == EngineerStatus.waiting && e.salesStatus != SalesStatus.selling)) {
          s = GameEngine.startSales(s, e.id);
        }

        if (strategy == 'generous') {
          final monthName = GameCalendar.monthName(s.week);
          if ((monthName == '6月' || monthName == '12月') && s.engineers.isNotEmpty) {
            final cost = WelfareEngine.bonusCost(BonusPlan.one, s.engineers.fold<int>(0, (n, e) => n + e.salary));
            if (s.company.cash - cost > 1000000) s = GameEngine.payBonus(s, BonusPlan.one);
          }
          if (monthName == '10月' && s.engineers.isNotEmpty) {
            final cost = WelfareEngine.healthCheckCost(HealthCheckTier.basic, s.engineers.length);
            if (s.company.cash - cost > 1000000) s = GameEngine.conductHealthCheck(s, HealthCheckTier.basic);
          }
          for (final e in s.engineers) {
            final tier = s.equipmentFor(e.id)?.pcTier;
            if (tier == PcTier.basicLaptop || tier == null) {
              final cost = WelfareEngine.pcUpgradeCost(PcTier.standardLaptop);
              if (s.company.cash - cost > 1000000) s = GameEngine.upgradePc(s, e.id, PcTier.standardLaptop);
            }
          }
        }

        s = GameEngine.advanceWeek(s);
      }

      m.runs++;
      m.cash += s.company.cash;
      if (s.engineers.isNotEmpty) {
        m.morale += s.engineers.fold<int>(0, (n, e) => n + e.morale) / s.engineers.length;
        m.trust += s.engineers.fold<int>(0, (n, e) => n + e.companyTrust) / s.engineers.length;
        m.highRisk += s.engineers.where((e) => MoraleEngine.turnoverRisk(e) == TurnoverRisk.high).length;
      }
      if (s.status != GameStatus.bankrupt) m.survived++;
    }
    m.report(strategy);
  }
}

class _Metrics {
  int runs = 0, highRisk = 0, survived = 0;
  double cash = 0, morale = 0, trust = 0;

  void report(String name) {
    print(
      '$name: avgCash=${(cash / runs).round()} avgMorale=${(morale / runs).toStringAsFixed(1)} '
      'avgTrust=${(trust / runs).toStringAsFixed(1)} highTurnoverRiskCount=${(highRisk / runs).toStringAsFixed(2)} '
      'survival=${(survived / runs * 100).toStringAsFixed(1)}%',
    );
  }
}
