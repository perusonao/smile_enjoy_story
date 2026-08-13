import '../../domain/domain.dart';
import '../models/models.dart';
import 'matching_engine.dart';

/// Playable 0.4C: computes weekly Morale drift and exposes the pure helpers
/// (labels, turnover risk, contract preference) the UI and [GameEngine] use.
///
/// Morale and Trust are deliberately kept independent (§5): this engine only
/// ever touches [Engineer.morale] on its own, and only touches
/// [Engineer.companyTrust] when a caller explicitly asks for a trust delta
/// (bonus/health-check/skill-sheet/etc. events elsewhere in [GameEngine]).
///
/// Every change is target-based rather than an unconditional +/- each week
/// (§7, §30): morale drifts a bounded step toward a "how conditions look
/// right now" target, so it self-limits instead of ratcheting to 0/100, and
/// every non-zero step is attributed to a concrete, player-visible reason
/// (§40 — no hidden random swings).
class MoraleEngine {
  const MoraleEngine._();

  static const int _weeklyStepCap = 3;
  static const int _baselineMorale = 60;
  static const int _boredomThresholdWeeks = 16;

  /// Records [reason] and clamps both scores to 0-100, trimming
  /// [Engineer.relationshipHistory] to [maxRelationshipHistory] (§38-39).
  static Engineer applyDelta(
    Engineer engineer, {
    required int week,
    required String reason,
    int moraleDelta = 0,
    int trustDelta = 0,
  }) {
    if (moraleDelta == 0 && trustDelta == 0) return engineer;
    final history = [
      ...engineer.relationshipHistory,
      EmployeeRelationshipEvent(
        week: week,
        reason: reason,
        moraleDelta: moraleDelta,
        trustDelta: trustDelta,
      ),
    ];
    final trimmed = history.length > maxRelationshipHistory
        ? history.sublist(history.length - maxRelationshipHistory)
        : history;
    return engineer.copyWith(
      morale: (engineer.morale + moraleDelta).clamp(0, 100),
      companyTrust: (engineer.companyTrust + trustDelta).clamp(0, 100),
      relationshipHistory: trimmed,
    );
  }

  /// One bounded step per engineer per week (§7-9, §17-18, §30).
  static List<Engineer> weeklyUpdate({
    required List<Engineer> engineers,
    required OfficeType officeType,
    required int week,
    required Map<String, int> waitingStreak,
    required Map<String, ActiveAssignment> assignmentByEngineer,
  }) {
    return engineers.map((e) {
      final (target, reason) = _target(
        e,
        officeType: officeType,
        week: week,
        waitingStreak: waitingStreak,
        assignment: assignmentByEngineer[e.id],
      );
      final step = (target - e.morale).clamp(-_weeklyStepCap, _weeklyStepCap);
      if (step == 0) return e;
      return applyDelta(e, week: week, reason: reason, moraleDelta: step);
    }).toList();
  }

  static (int target, String reason) _target(
    Engineer e, {
    required OfficeType officeType,
    required int week,
    required Map<String, int> waitingStreak,
    ActiveAssignment? assignment,
  }) {
    final officeShift = officeConfigs[officeType]!.moraleModifier * 3;
    var target = _baselineMorale + officeShift;

    if (e.status == EngineerStatus.waiting) {
      final streak = waitingStreak[e.id] ?? 0;
      final penalty = streak <= 1 ? 4 : (streak <= 3 ? 10 : 16);
      target -= penalty;
      return (target.clamp(0, 100), '待機$streak週目');
    }

    if (e.status == EngineerStatus.assigned && assignment != null) {
      final fit = MatchingEngine.computeFit(e, assignment.project).total;
      final commute = commutePenalty(e, assignment.project);
      final weeksOnProject = week - assignment.assignedWeek;
      final boredom = weeksOnProject >= _boredomThresholdWeeks ? 6 : 0;
      final fitShift = ((fit - 60) * 0.4).round();
      target += fitShift - commute - boredom;
      target = target.clamp(0, 100);

      if (boredom > 0 && boredom >= commute && boredom >= fitShift.abs()) {
        return (target, '長期案件で少し飽きている');
      }
      if (commute > 0 && commute >= fitShift.abs()) {
        return (target, '通勤負担');
      }
      if (fit >= 75) return (target, '案件Fitが良好');
      if (fit < 45) return (target, '案件Fitが低い');
      return (target, 'オフィス環境');
    }

    return (target.clamp(0, 100), 'オフィス環境');
  }

  /// §10: same area / remote → no burden; otherwise a small penalty,
  /// doubled for [EmployeeAbility.commuteSensitive]. Distance math is
  /// intentionally skipped per the prototype scope.
  static int commutePenalty(Engineer engineer, Project project) {
    if (engineer.residenceArea == ResidenceArea.remote ||
        project.remotePolicy == RemotePolicy.remote) {
      return 0;
    }
    if (engineer.residenceArea == project.location) return 0;
    return engineer.abilities.contains(EmployeeAbility.commuteSensitive)
        ? 6
        : 3;
  }

  static String moraleLabel(int morale) {
    if (morale >= 80) return '非常に高い';
    if (morale >= 60) return '高い';
    if (morale >= 40) return '普通';
    if (morale >= 20) return '低い';
    return 'かなり低い';
  }

  static String moraleEmoji(int morale) {
    if (morale >= 80) return '😄';
    if (morale >= 60) return '😊';
    if (morale >= 40) return '😐';
    if (morale >= 20) return '😟';
    return '😣';
  }

  static String trustLabel(int trust) {
    if (trust >= 80) return '非常に信頼';
    if (trust >= 60) return '信頼';
    if (trust >= 40) return '普通';
    if (trust >= 20) return '不信';
    return 'かなり不信';
  }

  static String trustSymbol(int trust) {
    if (trust >= 80) return '◎';
    if (trust >= 60) return '○';
    if (trust >= 40) return '△';
    if (trust >= 20) return '▽';
    return '×';
  }

  /// §36-37: a pure readiness signal for a future resignation system — no
  /// resignation event fires on this yet, it's only a warning label.
  static TurnoverRisk turnoverRisk(Engineer engineer) {
    if (engineer.morale < 30 && engineer.companyTrust < 30) {
      return TurnoverRisk.high;
    }
    if (engineer.morale < 40 || engineer.companyTrust < 40) {
      return TurnoverRisk.medium;
    }
    return TurnoverRisk.low;
  }

  static String turnoverRiskLabel(TurnoverRisk risk) => switch (risk) {
    TurnoverRisk.low => '低い',
    TurnoverRisk.medium => 'やや高い',
    TurnoverRisk.high => '高い',
  };

  /// §34-35: what the employee themselves would prefer at contract-decision
  /// time. The player can still override this — doing so costs
  /// morale/trust, applied by the caller (`GameEngine.decideContract`).
  static ContractPreference contractPreference(
    Engineer engineer,
    ActiveAssignment assignment,
    int currentWeek,
  ) {
    final fit = MatchingEngine.computeFit(engineer, assignment.project).total;
    final commute = commutePenalty(engineer, assignment.project);
    final weeksOnProject = currentWeek - assignment.assignedWeek;
    var score = 0;
    if (engineer.morale >= 60) {
      score++;
    } else if (engineer.morale < 40) {
      score--;
    }
    if (fit >= 70) {
      score++;
    } else if (fit < 45) {
      score--;
    }
    if (commute > 0) score--;
    if (weeksOnProject >= 20) score--;
    if (score >= 2) return ContractPreference.wantsExtend;
    if (score <= -2) return ContractPreference.wantsLeave;
    return ContractPreference.neutral;
  }

  static String contractPreferenceLabel(ContractPreference preference) =>
      switch (preference) {
        ContractPreference.wantsExtend => 'できれば延長したい',
        ContractPreference.wantsLeave => '次の案件へ移りたい',
        ContractPreference.neutral => 'どちらでも良い',
      };
}

enum TurnoverRisk { low, medium, high }

enum ContractPreference { wantsExtend, wantsLeave, neutral }
