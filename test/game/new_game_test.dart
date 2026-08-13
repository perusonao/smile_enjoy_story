import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  group('New game initial state (§2)', () {
    test('starts with 2 engineers, both waiting, 0 assigned', () {
      final state = GameEngine.newGame(seed: 1);
      expect(state.engineers, hasLength(2));
      expect(state.waitingEngineerCount, 2);
      expect(state.assignedEngineerCount, 0);
      expect(state.activeAssignments, isEmpty);
      for (final e in state.engineers) {
        expect(e.status, EngineerStatus.waiting);
      }
    });

    test('starts with cash ¥3,500,000, credit 20, week 1, smallOffice', () {
      final state = GameEngine.newGame(seed: 1);
      expect(state.company.cash, 3500000);
      expect(startingCash, 3500000);
      expect(state.company.credit, 20);
      expect(state.company.currentWeek, 1);
      expect(state.week, 1);
      expect(state.officeType, OfficeType.smallOffice);
    });

    test('starts with two already-open project listings to propose the founders to', () {
      final state = GameEngine.newGame(seed: 1);
      expect(state.openProjects, hasLength(2));
      for (final entry in state.openProjects) {
        expect(entry.postedWeek, 1);
        expect(state.isProjectOpenForProposal(entry.project.id), isTrue);
      }
    });

    test('starts with no accounts receivable and an empty monthly closing history', () {
      final state = GameEngine.newGame(seed: 1);
      expect(state.accountsReceivable, isEmpty);
      expect(state.monthlyClosings, isEmpty);
      expect(state.latestClosing, isNull);
    });

    test('starts on the current save schema version', () {
      final state = GameEngine.newGame(seed: 1);
      expect(state.schemaVersion, currentSchemaVersion);
    });
  });

  group('Balance sanity check (§30)', () {
    // Simulates the worst case the spec calls out explicitly: both founders
    // sit fully idle (no proposals, no hires) for the whole game. Starting
    // cash should last roughly 3-4 months under that burn, per §2's target.
    test('if both founders stay fully waiting, starting cash lasts roughly 3-4 months', () {
      var state = GameEngine.newGame(seed: 1).copyWith(
        // Strip the marketplace/recruitment noise so nothing except
        // salary/rent/fixed-cost ever touches cash.
        openProjects: const [],
        listings: const [],
        proposals: const [],
        pendingHires: const [],
      );

      final monthlyBurn = FinanceEngine.projectedMonthlyBurn(state);
      // Sanity: this is the founders' full salary + smallOffice rent +
      // otherMonthlyFixedCost, and should be a meaningfully large monthly
      // number (not accidentally zero from a broken wiring).
      expect(monthlyBurn, greaterThan(500000));

      var monthsSurvived = 0;
      while (state.status == GameStatus.playing && monthsSurvived < 24) {
        final beforeWeek = state.week;
        state = GameEngine.advanceWeek(state);
        if (GameCalendar.isMonthEnd(state.week) && state.week > beforeWeek) {
          monthsSurvived++;
        }
        if (state.status == GameStatus.bankrupt) break;
      }

      expect(state.status, GameStatus.bankrupt);
      // §2's target: "約3〜4か月" of runway when fully idle.
      expect(monthsSurvived, inInclusiveRange(2, 5));
    });

    test('staffing engineers reasonably promptly (by Fit) keeps the company solvent through week 48', () {
      // Two projects are already open at Week 1 specifically so the player
      // can staff both founders immediately (§2, §17-18). Simulate a
      // reasonably-attentive player using the Fit comparison the game
      // already surfaces at proposal time (Playable 0.2 §9): every week,
      // propose each waiting engineer to their best-fit proposable open
      // project (including re-proposing after an interview failure)
      // instead of leaving them idle or picking blindly.
      var state = GameEngine.newGame(seed: 5);

      for (var i = 0; i < totalGameWeeks && state.status == GameStatus.playing; i++) {
        for (final offer in state.offers.where((o) => o.status == OfferStatus.pending).toList()) {
          state = GameEngine.acceptOffer(state, offer.id);
        }
        for (final engineer in state.engineers) {
          if (engineer.status != EngineerStatus.waiting) continue;
          final target = _bestFitProposableProject(state, engineer);
          if (target == null) continue;
          state = GameEngine.proposeEngineer(state, engineer.id, target);
        }
        state = GameEngine.advanceWeek(state);
      }

      expect(state.status, isNot(GameStatus.bankrupt));
    });
  });
}

String? _bestFitProposableProject(GameState state, Engineer engineer) {
  String? bestId;
  var bestScore = -1;
  for (final entry in state.openProjects) {
    if (!state.isProjectOpenForProposal(entry.project.id)) continue;
    final score = MatchingEngine.computeFit(engineer, entry.project).total;
    if (score > bestScore) {
      bestScore = score;
      bestId = entry.project.id;
    }
  }
  return bestId;
}
