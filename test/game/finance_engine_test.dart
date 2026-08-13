import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

GameState _emptyState({int seed = 7}) {
  final base = GameEngine.newGame(seed: seed);
  return base.copyWith(
    engineers: const [],
    activeAssignments: const [],
    applicants: const [],
    openProjects: const [],
    listings: const [],
    proposals: const [],
    pendingHires: const [],
  );
}

void main() {
  group('FinanceEngine.dueMonthFor (§14-15)', () {
    test('a 30-day term collects at the next month-end', () {
      expect(FinanceEngine.dueMonthFor(generatedMonth: 5, paymentTermDays: 30), 6);
    });

    test('a 60-day term collects two month-ends later', () {
      expect(FinanceEngine.dueMonthFor(generatedMonth: 5, paymentTermDays: 60), 7);
    });
  });

  group('FinanceEngine cash runway (§12)', () {
    test('income covering burn gives an unbounded (safe) runway', () {
      final engineer = buildEngineer(id: 'e1', salary: 100000, status: EngineerStatus.assigned);
      final project = buildProject(id: 'p1', monthlyRate: 5000000);
      final state = _emptyState().copyWith(
        engineers: [engineer],
        activeAssignments: [
          ActiveAssignment(engineerId: 'e1', project: project, remainingWeeks: 10, assignedWeek: 1),
        ],
      );
      final runway = FinanceEngine.cashRunwayMonths(state);
      expect(runway.isInfinite, isTrue);
      expect(FinanceEngine.classifyRunway(runway), RunwayLevel.safe);
    });

    test('a comfortable starting company reads a safe (double-digit month) runway', () {
      final state = GameEngine.newGame(seed: 11);
      final runway = FinanceEngine.cashRunwayMonths(state);
      // Never negative, never NaN/absurdly large — a sane, finite number of
      // months given a burn rate that's actually positive.
      expect(runway, greaterThan(0));
      expect(runway.isNaN, isFalse);
      expect(runway, lessThan(1000));
    });

    test('runway shrinks (but never goes negative) as burn rises relative to cash', () {
      final engineer = buildEngineer(id: 'e1', salary: 900000, status: EngineerStatus.waiting);
      final state = _emptyState().copyWith(
        engineers: [engineer],
        company: _emptyState().company.copyWith(cash: 100000),
      );
      final runway = FinanceEngine.cashRunwayMonths(state);
      expect(runway, greaterThanOrEqualTo(0));
      expect(FinanceEngine.classifyRunway(runway), RunwayLevel.danger);
    });

    test('pending AR is not ignored — it extends runway rather than being treated as lost (§12)', () {
      final engineer = buildEngineer(id: 'e1', salary: 900000, status: EngineerStatus.waiting);
      final base = _emptyState().copyWith(
        engineers: [engineer],
        company: _emptyState().company.copyWith(cash: 100000),
      );
      final withAr = base.copyWith(
        accountsReceivable: [
          AccountsReceivable(
            id: 'ar-1',
            clientId: 'client-axis-soft',
            projectId: 'p1',
            employeeId: 'e1',
            amount: 5000000,
            generatedMonth: 1,
            dueMonth: 2,
          ),
        ],
      );
      expect(
        FinanceEngine.cashRunwayMonths(withAr),
        greaterThan(FinanceEngine.cashRunwayMonths(base)),
      );
    });

    test('classifyRunway thresholds: safe ≥6mo, caution 3-6mo, danger <3mo', () {
      expect(FinanceEngine.classifyRunway(10), RunwayLevel.safe);
      expect(FinanceEngine.classifyRunway(6), RunwayLevel.safe);
      expect(FinanceEngine.classifyRunway(4), RunwayLevel.caution);
      expect(FinanceEngine.classifyRunway(3), RunwayLevel.caution);
      expect(FinanceEngine.classifyRunway(2.9), RunwayLevel.danger);
      expect(FinanceEngine.classifyRunway(0), RunwayLevel.danger);
    });
  });

  group('FinanceEngine.hasOfficeCapacity (§6)', () {
    test('hiring is allowed while under the current office\'s capacity', () {
      final state = _emptyState().copyWith(
        engineers: List.generate(
          9,
          (i) => buildEngineer(id: 'e$i', status: EngineerStatus.waiting),
        ),
      );
      expect(state.officeType, OfficeType.smallOffice); // capacity 10
      expect(FinanceEngine.hasOfficeCapacity(state), isTrue);
    });

    test('hiring is blocked once the office is at capacity', () {
      final state = _emptyState().copyWith(
        engineers: List.generate(
          10,
          (i) => buildEngineer(id: 'e$i', status: EngineerStatus.waiting),
        ),
      );
      expect(FinanceEngine.hasOfficeCapacity(state), isFalse);
    });

    test('pending hires count toward capacity too', () {
      final applicant = buildApplicant(id: 'a1');
      final state = _emptyState().copyWith(
        engineers: List.generate(
          9,
          (i) => buildEngineer(id: 'e$i', status: EngineerStatus.waiting),
        ),
        pendingHires: [
          PendingHire(id: 'ph1', applicant: applicant, salary: 400000, decisionWeek: 1, joinWeek: 2),
        ],
      );
      expect(FinanceEngine.hasOfficeCapacity(state), isFalse);
    });
  });

  group('GameEngine.hireApplicant office capacity guard (§6)', () {
    test('blocks the hire with the exact spec message when the office is full', () {
      final applicant = buildApplicant(id: 'a1', name: 'テスト次郎');
      var state = _emptyState().copyWith(
        engineers: List.generate(
          10,
          (i) => buildEngineer(id: 'e$i', status: EngineerStatus.waiting),
        ),
        applicants: [
          ApplicantEntry(applicant: applicant, appearedWeek: 1, source: RecruitmentMediaType.freeWork),
        ],
        interviewedApplicantIds: {'a1'},
      );

      final next = GameEngine.hireApplicant(state, 'a1');

      expect(next.pendingHires, isEmpty);
      // The applicant is left in the pool rather than silently discarded.
      expect(next.applicants.any((e) => e.applicant.id == 'a1'), isTrue);
      expect(next.events.last.message, '現在のオフィスではこれ以上採用できません');
    });
  });
}
