import 'dart:convert';

import '../public_demo/public_demo_aggregate.dart';

/// Versioned, self-contained persistence envelope for Public Demo 0.1.
///
/// This deliberately has no dependency on normal [GameState] persistence.
/// A payload is restored exactly as saved or rejected as a whole; decoding
/// never invokes gameplay reconciliation or derives replacement values.
class PublicDemoSaveCodec {
  static const schemaVersion = 1;
  static const _experience = 'public-demo-01';

  const PublicDemoSaveCodec();

  String encode(PublicDemoAggregate aggregate) => jsonEncode(toJson(aggregate));

  Map<String, dynamic> toJson(PublicDemoAggregate aggregate) => {
    'schemaVersion': schemaVersion,
    'experience': _experience,
    'aggregate': aggregate.toJson(),
  };

  /// Returns null for corrupt, foreign, incomplete, or incompatible saves.
  /// The caller can safely fall back to a new Public Demo session.
  PublicDemoAggregate? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  PublicDemoAggregate? fromJson(Map<String, dynamic> json) {
    try {
      if (json.keys.toSet().length != 3 ||
          !json.keys.toSet().containsAll(const {
            'schemaVersion',
            'experience',
            'aggregate',
          }) ||
          json['schemaVersion'] != schemaVersion ||
          json['experience'] != _experience ||
          json['aggregate'] is! Map ||
          !_hasConsistentAuthorityFacts(json)) {
        return null;
      }
      final aggregate = PublicDemoAggregate.fromJson(
        (json['aggregate'] as Map).cast<String, dynamic>(),
      );

      // PublicDemoState's legacy decoder intentionally supplies defaults for
      // old normal-game data.  A Public Demo envelope must be stricter: this
      // round-trip comparison rejects missing fields, unknown enums, and any
      // payload that would otherwise be normalized during restoration.
      if (_canonicalJson(json) != _canonicalJson(toJson(aggregate))) {
        return null;
      }
      return aggregate;
    } catch (_) {
      return null;
    }
  }

  /// Rejects combinations that are individually serializable but impossible
  /// to obtain from the authoritative Public Demo command path. Persistence
  /// must restore authority, not mint it from caller-controlled JSON fields.
  static bool _hasConsistentAuthorityFacts(Map<String, dynamic> envelope) {
    final aggregateRaw = envelope['aggregate'];
    if (aggregateRaw is! Map) return false;
    final aggregate = aggregateRaw.cast<String, dynamic>();
    final stateRaw = aggregate['state'];
    final workflowRaw = aggregate['workflow'];
    if (stateRaw is! Map || workflowRaw is! Map) return false;
    final state = stateRaw.cast<String, dynamic>();
    final workflow = workflowRaw.cast<String, dynamic>();

    final cash = state['cash'];
    final status = state['financialStatus'];
    final month = state['month'];
    final fiscalYearCompleted = state['fiscalYearCompleted'];
    final monthOpeningCash = state['monthOpeningCash'];
    final trainingSpent = state['monthTrainingSpent'];
    final recruitmentSpent = state['monthRecruitmentSpent'];
    final pendingRevenue = state['pendingRevenue'];
    if (cash is! int ||
        status is! String ||
        month is! int ||
        fiscalYearCompleted is! bool ||
        monthOpeningCash is! int ||
        trainingSpent is! int ||
        recruitmentSpent is! int ||
        pendingRevenue is! int) {
      return false;
    }

    const negativeStatuses = {
      'cashShortage',
      'bankruptcy',
      'marchCashShortageFailure',
    };
    if (cash < 0) {
      if (!negativeStatuses.contains(status)) return false;
    } else if (status != 'normal') {
      return false;
    }
    if (fiscalYearCompleted && (month != 15 || status != 'normal')) {
      return false;
    }
    if (trainingSpent < 0 ||
        recruitmentSpent < 0 ||
        cash != monthOpeningCash - trainingSpent - recruitmentSpent) {
      return false;
    }

    final latestFlowRaw = state['latestMonthlyCashFlow'];
    if (latestFlowRaw != null) {
      if (latestFlowRaw is! Map) return false;
      final flow = latestFlowRaw.cast<String, dynamic>();
      final openingCash = flow['openingCash'];
      final cashReceived = flow['cashReceived'];
      final salaryPaid = flow['salaryPaid'];
      final fixedCostsPaid = flow['fixedCostsPaid'];
      final bonusPaid = flow['bonusPaid'];
      final trainingCost = flow['trainingCost'];
      final recruitmentCost = flow['recruitmentCost'];
      final closingCash = flow['closingCash'];
      final revenue = flow['revenue'];
      final receivables = flow['receivables'];
      if (openingCash is! int ||
          cashReceived is! int ||
          salaryPaid is! int ||
          fixedCostsPaid is! int ||
          bonusPaid is! int ||
          trainingCost is! int ||
          recruitmentCost is! int ||
          closingCash is! int ||
          revenue is! int ||
          receivables is! int) {
        return false;
      }
      if (openingCash +
                  cashReceived -
                  salaryPaid -
                  fixedCostsPaid -
                  bonusPaid -
                  trainingCost -
                  recruitmentCost !=
              closingCash ||
          closingCash != monthOpeningCash ||
          revenue != receivables ||
          pendingRevenue != receivables) {
        return false;
      }
    }

    final engineersRaw = workflow['engineers'];
    final assignmentsRaw = workflow['assignments'];
    if (engineersRaw is! List || assignmentsRaw is! List) return false;
    final assignmentEngineerIds = <String>{};
    for (final entry in assignmentsRaw) {
      if (entry is! Map) return false;
      final engineerId = entry['engineerId'];
      if (engineerId is! String) return false;
      assignmentEngineerIds.add(engineerId);
    }

    for (final entry in engineersRaw) {
      if (entry is! Map) return false;
      final engineer = entry.cast<String, dynamic>();
      final id = engineer['id'];
      final stage = engineer['stage'];
      final score = engineer['lastInterviewScore'];
      final recordId = engineer['interviewRecordEngineerId'];
      if (id is! String || stage is! String) return false;

      final clientPassStage =
          stage == 'clientInterviewPassed' || stage == 'ordered';
      if (recordId != null) {
        if (recordId is! String ||
            recordId != id ||
            !clientPassStage ||
            score is! int ||
            score < 60) {
          return false;
        }
      }
      if (clientPassStage &&
          (recordId != id || score is! int || score < 60)) {
        return false;
      }
      if (stage == 'ordered' &&
          month >= 5 &&
          !assignmentEngineerIds.contains(id)) {
        return false;
      }
    }

    return true;
  }

  static String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.map((entry) {
        if (entry.key is! String) {
          throw const FormatException('Save object keys must be strings');
        }
        return MapEntry(entry.key as String, _canonicalize(entry.value));
      }).toList()..sort((left, right) => left.key.compareTo(right.key));
      return {for (final entry in entries) entry.key: entry.value};
    }
    if (value is List) return value.map(_canonicalize).toList();
    if (value is String || value is num || value is bool || value == null) {
      return value;
    }
    throw const FormatException('Unsupported save value');
  }
}
