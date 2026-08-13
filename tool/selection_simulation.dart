// ignore_for_file: avoid_print

import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main(List<String> args) {
  final games = args.isEmpty ? 200 : int.parse(args.first);
  var proposals = 0;
  var parallelSamples = 0;
  var parallelTotal = 0;
  var selectionWeeks = 0.0;
  var offers = 0;
  var expired = 0;
  var survived = 0;
  var waitingWeeks = 0;

  for (var seed = 1; seed <= games; seed++) {
    var state = GameEngine.newGame(seed: seed);
    while (state.status == GameStatus.playing) {
      for (final offer
          in state.offers
              .where((offer) => offer.status == OfferStatus.pending)
              .toList()) {
        final application = state.proposals.firstWhere(
          (item) => item.id == offer.applicationId,
        );
        final betterActive = state.proposals.any(
          (item) =>
              item.engineerId == offer.employeeId &&
              item.status == ApplicationStatus.active &&
              item.project.monthlyRate > offer.monthlyRate + 80000,
        );
        if (offer.monthlyRate >= 700000 ||
            !betterActive ||
            application.fitScore >= 75) {
          state = GameEngine.acceptOffer(state, offer.id);
        }
      }
      for (final engineer in state.engineers.where(
        (engineer) => engineer.status != EngineerStatus.assigned,
      )) {
        final candidates =
            state.openProjects
                .where(
                  (entry) => state.canPropose(engineer.id, entry.project.id),
                )
                .toList()
              ..sort(
                (a, b) =>
                    b.project.monthlyRate.compareTo(a.project.monthlyRate),
              );
        for (final entry in candidates.take(
          maxParallelProposalsPerEmployee -
              state.activeProposalCountFor(engineer.id),
        )) {
          state = GameEngine.proposeEngineer(
            state,
            engineer.id,
            entry.project.id,
          );
        }
      }
      parallelTotal += state.activeCompanyProposalCount;
      parallelSamples++;
      state = GameEngine.advanceWeek(state);
    }
    proposals += state.stats.proposalCount;
    selectionWeeks += state.stats.averageSelectionWeeks;
    offers += state.stats.offersReceived;
    expired += state.stats.offersExpired;
    waitingWeeks += state.stats.waitingWeeks;
    if (state.status == GameStatus.finished) survived++;
  }

  String mean(num value) => (value / games).toStringAsFixed(2);
  print('games=$games');
  print('averageProposals=${mean(proposals)}');
  print(
    'averageParallel=${(parallelTotal / parallelSamples).toStringAsFixed(2)}',
  );
  print('averageSelectionWeeks=${mean(selectionWeeks)}');
  print('offersPerGame=${mean(offers)}');
  print(
    'offerExpiryRate=${offers == 0 ? '0.00' : (expired / offers * 100).toStringAsFixed(2)}%',
  );
  print('averageWaitingEngineerWeeks=${mean(waitingWeeks)}');
  print('week48SurvivalRate=${(survived / games * 100).toStringAsFixed(2)}%');
}
