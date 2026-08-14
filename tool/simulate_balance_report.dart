// Dev-only reporting script — NOT part of the shipped app (Playable 0.4C.4
// §43, §61 confirmation simulation).
//
// Independent of tool/simulate_first_assignment.dart (which was used during
// root-causing): this drives three separate groups purely through
// legitimate GameEngine calls — Guided-Honest, Guided-Moderate (a slower,
// occasionally-distracted but still genuine player), and Free-Honest (tutorial
// skipped from the start, so the guided safety net never applies) — over a
// fresh, non-overlapping seed range, to independently confirm the ~90%
// Week-10 guided first-assignment target and to check Free Mode's 48-week
// survival rate is unaffected by the guided-only safety net.
//
// Run with:
//   dart run tool/simulate_balance_report.dart [gamesPerGroup] [seedOffset]
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

class GroupResult {
  int? firstInterviewRequestWeek;
  int? firstClientInterviewWeek;
  int? firstOfferWeek;
  int? firstAssignmentWeek;
  bool bankruptBeforeAssignment = false;
  bool finishedGame = false; // reached week 48 without bankruptcy
  int selectionFailureCount = 0;
}

GroupResult _simulate(int seed, {required bool guided, required bool moderate}) {
  final result = GroupResult();
  var s = GameEngine.newGame(seed: seed);
  if (!guided) s = GameEngine.skipFoundingTutorial(s);
  final focusId = guided ? ProgressionEngine.focusEmployeeId(s)! : s.engineers.first.id;
  s = GameEngine.startSales(s, focusId);

  // Deterministic per-seed "distraction" schedule for Guided-Moderate: a
  // genuine player who doesn't perfectly react every single week, but never
  // does anything invalid — just sometimes lets a week pass without acting
  // first, exactly like a real player checking in irregularly would.
  final distractionRoll = Random(seed * 7919 + 13);
  var lastRejectedProposalIds = <String>{};

  for (var i = 0; i < 60; i++) {
    // Pre-first-assignment guided play is deliberately confined to the
    // single tutorial focus employee (the guided tutorial's actual
    // framing); free mode and post-first-assignment guided play work every
    // engineer, matching how a rational player runs the whole roster once
    // they're not being walked through a single hire anymore.
    final activeIds = (!guided || result.firstAssignmentWeek != null)
        ? s.engineers.map((e) => e.id).toList()
        : [focusId];

    final distracted = moderate && distractionRoll.nextDouble() < 0.25;
    if (!distracted) {
      for (final offer in s.interviewOffers
          .where((o) => activeIds.contains(o.employeeId) && o.status == InterviewOfferStatus.pending)
          .toList()) {
        if (offer.employeeId == focusId) result.firstInterviewRequestWeek ??= offer.generatedWeek;
        s = GameEngine.acceptInterviewOffer(s, offer.id);
      }
      for (final p in s.proposals
          .where((p) =>
              activeIds.contains(p.engineerId) &&
              p.status == ApplicationStatus.active &&
              p.currentStep == SelectionStep.clientInterview &&
              !s.clientInterviews.any((sess) => sess.applicationId == p.id && sess.completed))
          .toList()) {
        if (p.engineerId == focusId) result.firstClientInterviewWeek ??= s.week;
        s = GameEngine.autoResolveClientInterview(s, p.id);
      }
      for (final offer in s.offers.where((o) => activeIds.contains(o.employeeId) && o.status == OfferStatus.pending).toList()) {
        if (offer.employeeId == focusId) result.firstOfferWeek ??= s.week;
        s = GameEngine.acceptOffer(s, offer.id);
      }
      for (final id in activeIds) {
        final e = s.engineerById(id);
        if (e.status == EngineerStatus.waiting && e.salesStatus == SalesStatus.notSelling) {
          s = GameEngine.startSales(s, id);
        }
      }
    } else {
      // Still recorded even on a distracted week — timing metrics reflect
      // when the opportunity *arrived*, not just when it was acted on.
      for (final offer in s.interviewOffers.where((o) => o.employeeId == focusId && o.status == InterviewOfferStatus.pending)) {
        result.firstInterviewRequestWeek ??= offer.generatedWeek;
      }
    }

    final rejectedNow = s.proposals
        .where((p) => p.engineerId == focusId && p.status == ApplicationStatus.rejected)
        .map((p) => p.id)
        .toSet();
    result.selectionFailureCount += rejectedNow.difference(lastRejectedProposalIds).length;
    lastRejectedProposalIds = rejectedNow;

    final assignment = s.assignmentForEngineer(focusId);
    if (assignment != null && result.firstAssignmentWeek == null) {
      result.firstAssignmentWeek = s.week;
    }

    if (s.status == GameStatus.bankrupt) {
      if (result.firstAssignmentWeek == null) result.bankruptBeforeAssignment = true;
      return result;
    }
    if (s.status == GameStatus.finished) {
      result.finishedGame = true;
      return result;
    }

    s = GameEngine.advanceWeek(s);
  }
  return result;
}

void main(List<String> args) {
  final gamesPerGroup = args.isNotEmpty ? int.parse(args[0]) : 600;
  final seedOffset = args.length > 1 ? int.parse(args[1]) : 500000;

  final guidedHonest = <GroupResult>[];
  final guidedModerate = <GroupResult>[];
  final freeHonest = <GroupResult>[];
  for (var i = 0; i < gamesPerGroup; i++) {
    final seed = seedOffset + i;
    guidedHonest.add(_simulate(seed, guided: true, moderate: false));
    guidedModerate.add(_simulate(seed, guided: true, moderate: true));
    freeHonest.add(_simulate(seed, guided: false, moderate: false));
  }

  print('=== Playable 0.4C.4 confirmation simulation (n=$gamesPerGroup/group, seeds $seedOffset-${seedOffset + gamesPerGroup - 1}) ===');
  _reportGroup('Guided-Honest', guidedHonest);
  _reportGroup('Guided-Moderate', guidedModerate);
  _reportGroup('Free-Honest', freeHonest);
}

void _reportGroup(String label, List<GroupResult> results) {
  final n = results.length;
  print('');
  print('-- $label --');
  void weekStats(String name, List<int?> weeks) {
    final present = weeks.whereType<int>().toList()..sort();
    if (present.isEmpty) {
      print('  $name: never');
      return;
    }
    final avg = present.reduce((a, b) => a + b) / present.length;
    print('  $name: avg ${avg.toStringAsFixed(1)}, median ${present[present.length ~/ 2]} (n=${present.length}/$n)');
  }

  weekStats('first interview request week', results.map((r) => r.firstInterviewRequestWeek).toList());
  weekStats('first client interview week', results.map((r) => r.firstClientInterviewWeek).toList());
  weekStats('first offer week', results.map((r) => r.firstOfferWeek).toList());
  weekStats('first assignment week', results.map((r) => r.firstAssignmentWeek).toList());

  final w10 = results.where((r) => r.firstAssignmentWeek != null && r.firstAssignmentWeek! <= 10).length;
  final w12 = results.where((r) => r.firstAssignmentWeek != null && r.firstAssignmentWeek! <= 12).length;
  final bankrupt = results.where((r) => r.bankruptBeforeAssignment).length;
  final finished = results.where((r) => r.finishedGame).length;
  final avgFailures = results.map((r) => r.selectionFailureCount).reduce((a, b) => a + b) / n;
  print('  assignment by Week 10: ${_pct(w10, n)}');
  print('  assignment by Week 12: ${_pct(w12, n)}');
  print('  pre-assignment bankruptcy: ${_pct(bankrupt, n)}');
  print('  48-week survival (reached week 48 without bankruptcy): ${_pct(finished, n)}');
  print('  avg selection-step failures per game: ${avgFailures.toStringAsFixed(2)}');
}

String _pct(int count, int total) {
  final pct = (count / total * 100).toStringAsFixed(1);
  return '${count.toString().padLeft(5)}/$total  ($pct%)';
}
