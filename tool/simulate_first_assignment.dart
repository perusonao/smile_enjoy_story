// Dev-only reporting script — NOT part of the shipped app (Playable 0.4C.4
// §4-6 root-cause simulation).
//
// Drives many guided-honest playthroughs purely through legitimate
// GameEngine calls (mirroring the "employee-first loop" pattern from
// test/game/founding_progression_e2e_test.dart) and reports the metrics the
// balance investigation needs *before* any fix is written: first
// interview-request/client-interview/offer/assignment week, pre-assignment
// bankruptcy rate, selection-failure counts, Fit distribution at the point
// each interview offer is accepted, and payment terms. No GameState
// cheating, no fixed success rates — just honest repeated play.
//
// Run with:
//   dart run tool/simulate_first_assignment.dart [gameCount]
// ignore_for_file: avoid_print
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

class GameResult {
  int? firstInterviewRequestWeek;
  int? firstClientInterviewWeek;
  int? firstOfferWeek;
  int? firstAssignmentWeek;
  bool bankruptBeforeAssignment = false;
  bool reachedWeek48WithoutAssignment = false;
  int selectionFailureCount = 0;
  int clientInterviewFailureCount = 0;
  int interviewRequestsAcceptedCount = 0;
  final List<int> fitsAtInterviewOfferAcceptance = [];
  int? finalPaymentTermDays;
  SelectionFlowType? firstAcceptedFlowType;
}

GameResult _simulateOneGame(int seed) {
  final result = GameResult();
  var s = GameEngine.newGame(seed: seed);
  final focusId = ProgressionEngine.focusEmployeeId(s)!;
  s = GameEngine.startSales(s, focusId);

  var lastRejectedProposalIds = <String>{};
  var lastFailedClientInterviewIds = <String>{};

  for (var i = 0; i < 60; i++) {
    // Accept every pending interview request (guided-honest: never declines).
    for (final offer in s.interviewOffers
        .where((o) => o.employeeId == focusId && o.status == InterviewOfferStatus.pending)
        .toList()) {
      result.firstInterviewRequestWeek ??= offer.generatedWeek;
      final entry = s.openProjects.where((e) => e.project.id == offer.projectId).firstOrNull;
      if (entry != null) {
        result.fitsAtInterviewOfferAcceptance.add(
          MatchingEngine.computeFit(s.engineerById(focusId), entry.project).total,
        );
        result.firstAcceptedFlowType ??= entry.project.selectionFlow.type;
      }
      s = GameEngine.acceptInterviewOffer(s, offer.id);
      result.interviewRequestsAcceptedCount++;
    }

    // Auto-resolve every pending client interview.
    for (final p in s.proposals
        .where((p) =>
            p.engineerId == focusId &&
            p.status == ApplicationStatus.active &&
            p.currentStep == SelectionStep.clientInterview &&
            !s.clientInterviews.any((sess) => sess.applicationId == p.id && sess.completed))
        .toList()) {
      result.firstClientInterviewWeek ??= s.week;
      s = GameEngine.autoResolveClientInterview(s, p.id);
    }

    // Accept every pending final offer.
    for (final offer in s.offers
        .where((o) => o.employeeId == focusId && o.status == OfferStatus.pending)
        .toList()) {
      result.firstOfferWeek ??= s.week;
      s = GameEngine.acceptOffer(s, offer.id);
    }

    // Restart sales whenever genuinely idle (mirrors a rational guided
    // player following the "営業を再開しましょう" GuidedAction fallback).
    final focus = s.engineerById(focusId);
    if (focus.status == EngineerStatus.waiting && focus.salesStatus == SalesStatus.notSelling) {
      s = GameEngine.startSales(s, focusId);
    }

    // Tally new selection failures (rejected proposals) and client-interview
    // failures since last week, by id-set diff (proposals/sessions persist
    // once created, so this only counts each failure once).
    final rejectedNow = s.proposals
        .where((p) => p.engineerId == focusId && p.status == ApplicationStatus.rejected)
        .map((p) => p.id)
        .toSet();
    result.selectionFailureCount += rejectedNow.difference(lastRejectedProposalIds).length;
    lastRejectedProposalIds = rejectedNow;

    final failedSessionsNow = s.clientInterviews
        .where((sess) => sess.employeeId == focusId && sess.completed && sess.result == ClientInterviewResult.failed)
        .map((sess) => sess.id)
        .toSet();
    result.clientInterviewFailureCount += failedSessionsNow.difference(lastFailedClientInterviewIds).length;
    lastFailedClientInterviewIds = failedSessionsNow;

    final assignment = s.assignmentForEngineer(focusId);
    if (assignment != null) {
      result.firstAssignmentWeek = s.week;
      result.finalPaymentTermDays = _paymentTermDaysById(assignment.project.clientId);
      return result;
    }

    if (s.status == GameStatus.bankrupt) {
      result.bankruptBeforeAssignment = true;
      return result;
    }

    s = GameEngine.advanceWeek(s);
  }

  result.reachedWeek48WithoutAssignment = true;
  return result;
}

void main(List<String> args) {
  final gameCount = args.isNotEmpty ? int.parse(args[0]) : 1000;
  final results = <GameResult>[];
  for (var seed = 1; seed <= gameCount; seed++) {
    results.add(_simulateOneGame(seed));
  }
  _report(results, gameCount);
  _reportInitialProjectFit();
}

void _report(List<GameResult> results, int gameCount) {
  print('=== Guided-Honest First-Assignment Simulation (n=$gameCount) ===');

  void weekStats(String label, List<int?> weeks) {
    final present = weeks.whereType<int>().toList();
    if (present.isEmpty) {
      print('  $label: never (0/$gameCount)');
      return;
    }
    present.sort();
    final avg = present.reduce((a, b) => a + b) / present.length;
    final median = present[present.length ~/ 2];
    print(
      '  $label: ${present.length}/$gameCount reached '
      '(avg week ${avg.toStringAsFixed(1)}, median $median, '
      'min ${present.first}, max ${present.last})',
    );
  }

  weekStats('first interview request', results.map((r) => r.firstInterviewRequestWeek).toList());
  weekStats('first client interview', results.map((r) => r.firstClientInterviewWeek).toList());
  weekStats('first final offer', results.map((r) => r.firstOfferWeek).toList());
  weekStats('first assignment', results.map((r) => r.firstAssignmentWeek).toList());

  final byWeek10 = results.where((r) => r.firstAssignmentWeek != null && r.firstAssignmentWeek! <= 10).length;
  final byWeek12 = results.where((r) => r.firstAssignmentWeek != null && r.firstAssignmentWeek! <= 12).length;
  final byWeek16 = results.where((r) => r.firstAssignmentWeek != null && r.firstAssignmentWeek! <= 16).length;
  final bankrupt = results.where((r) => r.bankruptBeforeAssignment).length;
  final neverAssigned = results.where((r) => r.reachedWeek48WithoutAssignment).length;

  print('  assignment by Week 10: ${_pct(byWeek10, gameCount)}');
  print('  assignment by Week 12: ${_pct(byWeek12, gameCount)}');
  print('  assignment by Week 16: ${_pct(byWeek16, gameCount)}');
  print('  pre-assignment bankruptcy: ${_pct(bankrupt, gameCount)}');
  print('  never assigned by Week 60 (no bankruptcy): ${_pct(neverAssigned, gameCount)}');

  final avgFailures = results.map((r) => r.selectionFailureCount).reduce((a, b) => a + b) / gameCount;
  final avgClientFailures = results.map((r) => r.clientInterviewFailureCount).reduce((a, b) => a + b) / gameCount;
  print('  avg selection-step failures per game: ${avgFailures.toStringAsFixed(2)}');
  print('  avg client-interview failures per game: ${avgClientFailures.toStringAsFixed(2)}');

  final allFits = results.expand((r) => r.fitsAtInterviewOfferAcceptance).toList()..sort();
  if (allFits.isNotEmpty) {
    final avgFit = allFits.reduce((a, b) => a + b) / allFits.length;
    print(
      '  Fit at interview-offer acceptance: avg ${avgFit.toStringAsFixed(1)}, '
      'median ${allFits[allFits.length ~/ 2]}, min ${allFits.first}, max ${allFits.last} (n=${allFits.length})',
    );
  }

  final flowCounts = <SelectionFlowType, int>{};
  for (final r in results) {
    if (r.firstAcceptedFlowType != null) {
      flowCounts[r.firstAcceptedFlowType!] = (flowCounts[r.firstAcceptedFlowType!] ?? 0) + 1;
    }
  }
  print('  first-accepted-project flow type distribution:');
  for (final type in SelectionFlowType.values) {
    print('    ${type.name.padRight(10)} ${_pct(flowCounts[type] ?? 0, results.length)}');
  }

  final paymentTerms = results.map((r) => r.finalPaymentTermDays).whereType<int>().toList();
  final termCounts = <int, int>{};
  for (final t in paymentTerms) {
    termCounts[t] = (termCounts[t] ?? 0) + 1;
  }
  print('  payment terms at first assignment: $termCounts');
}

void _reportInitialProjectFit() {
  print('');
  print('=== Deterministic initial roster/project fit (founder seeds fixed) ===');
  final s = GameEngine.newGame(seed: 1);
  for (final e in s.engineers) {
    for (final entry in s.openProjects) {
      final fit = MatchingEngine.computeFit(e, entry.project);
      final match = SalesEngine.skillSheetMatch(s.skillSheetFor(e.id), entry.project);
      print(
        '  ${e.profile.name} vs ${entry.project.title} (${entry.project.id}, '
        '${entry.project.selectionFlow.type.name}, difficulty ${entry.project.difficulty}, '
        'rank ${entry.project.rank.name}): Fit=${fit.total} skillSheetMatch=$match',
      );
    }
  }
  final focusId = ProgressionEngine.focusEmployeeId(s);
  print('  focusEmployeeId: $focusId');
}

String _pct(int count, int total) {
  final pct = (count / total * 100).toStringAsFixed(1);
  return '${count.toString().padLeft(5)}/$total  ($pct%)';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

int _paymentTermDaysById(String clientId) {
  for (final c in sampleClients) {
    if (c.id == clientId) return c.paymentTermDays;
  }
  return 30;
}
