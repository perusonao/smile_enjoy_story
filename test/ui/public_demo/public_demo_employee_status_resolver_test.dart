import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_employee_status_resolver.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_employee_visual.dart';

/// SES Employee Status Unified Display (Fresh Audit,
/// docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Fresh-Audit.md;
/// PR #238 review follow-up — the pipeline-stage collapse this file now
/// pins): pure unit coverage for [PublicDemoEmployeeStatusResolver.resolve]
/// — deliberately independent of any widget/pump, since the resolver takes
/// only primitives/enums and never reads [PublicDemoAggregate]/
/// [PublicDemoState] itself.
void main() {
  PublicDemoEmployeeStatusDisplay resolveFor({
    required PublicDemoSalesStage stage,
    bool isCurrentlyAssigned = false,
    bool isReadyForFieldSales = false,
    bool fieldSalesActionReachableThisMonth = false,
  }) => PublicDemoEmployeeStatusResolver.resolve(
    stage: stage,
    isCurrentlyAssigned: isCurrentlyAssigned,
    isReadyForFieldSales: isReadyForFieldSales,
    fieldSalesActionReachableThisMonth: fieldSalesActionReachableThisMonth,
  );

  group('each player-facing status (Fresh Audit §4 six-value taxonomy)', () {
    test('waiting + not ready → 研修が必要 / training tone', () {
      final display = resolveFor(
        stage: PublicDemoSalesStage.waiting,
        isReadyForFieldSales: false,
        fieldSalesActionReachableThisMonth: true,
      );
      expect(display.label, '研修が必要');
      expect(display.tone, PublicDemoEmployeeStatusTone.training);
    });

    test('waiting + ready + action reachable this month → 営業可能 / '
        'readyForSales tone', () {
      final display = resolveFor(
        stage: PublicDemoSalesStage.waiting,
        isReadyForFieldSales: true,
        fieldSalesActionReachableThisMonth: true,
      );
      expect(display.label, '営業可能');
      expect(display.tone, PublicDemoEmployeeStatusTone.readyForSales);
    });

    test('waiting + ready but action NOT reachable this month (May/March) '
        '→ 待機 / waiting tone — PR #233 Codex review (P2): never name an '
        'action with no reachable control', () {
      final display = resolveFor(
        stage: PublicDemoSalesStage.waiting,
        isReadyForFieldSales: true,
        fieldSalesActionReachableThisMonth: false,
      );
      expect(display.label, '待機');
      expect(display.tone, PublicDemoEmployeeStatusTone.waiting);
    });

    test('ordered + not yet currently assigned → 参画予定 / waiting tone — '
        'PR #238 review follow-up: the literal Fresh Audit §4 label, not '
        "the raw pipeline's own '翌月参画予定' text", () {
      final display = resolveFor(
        stage: PublicDemoSalesStage.ordered,
        isCurrentlyAssigned: false,
      );
      expect(display.label, '参画予定');
      expect(display.tone, PublicDemoEmployeeStatusTone.waiting);
    });

    test('ordered + currently assigned → 参画中 / assigned tone — the exact '
        'Fresh Audit §3 fix (must win even if the engineer would otherwise '
        'read as field-sales ready)', () {
      final display = resolveFor(
        stage: PublicDemoSalesStage.ordered,
        isCurrentlyAssigned: true,
        isReadyForFieldSales: true,
        fieldSalesActionReachableThisMonth: true,
      );
      expect(display.label, '参画中');
      expect(display.tone, PublicDemoEmployeeStatusTone.assigned);
    });

    for (final stage in [
      PublicDemoSalesStage.skillSheet,
      PublicDemoSalesStage.selling,
      PublicDemoSalesStage.introduced,
      PublicDemoSalesStage.partnerInterviewPassed,
      PublicDemoSalesStage.partnerInterviewFailed,
      PublicDemoSalesStage.clientInterviewPassed,
      PublicDemoSalesStage.clientInterviewFailed,
    ]) {
      test('$stage → collapses to 営業中 / waiting tone — PR #238 review '
          'follow-up: every non-waiting, non-ordered sales-pipeline '
          'sub-stage reads the same unified bucket, never its own raw '
          'per-sub-stage label (営業準備/案件紹介済/各面談通過・不合格)', () {
        final display = resolveFor(stage: stage);
        expect(display.label, '営業中');
        expect(display.tone, PublicDemoEmployeeStatusTone.waiting);
      });
    }
  });

  group('status priority (Fresh Audit §5/§6)', () {
    test('ordered + currently assigned must never read 営業可能, even '
        'though isReadyForFieldSales is genuinely true — 参画中 wins', () {
      final display = resolveFor(
        stage: PublicDemoSalesStage.ordered,
        isCurrentlyAssigned: true,
        isReadyForFieldSales: true,
        fieldSalesActionReachableThisMonth: true,
      );
      expect(display.label, isNot('営業可能'));
      expect(display.label, '参画中');
    });

    test('参画中 requires BOTH stage == ordered AND isCurrentlyAssigned — '
        'an engineer whose assignment was just ended mid-month while this '
        "month's revenue still counts them (PublicDemoWorkflowState"
        '.endAssignment’s documented pre-July "row kept, stage reset to '
        'waiting" case) is genuinely back at waiting, not still 参画中 — '
        'this closes a second, previously-undetected label/tone '
        'disagreement (the former _employeeStatusTone checked assignment '
        'membership alone, without the label’s own stage == ordered '
        'requirement)', () {
      final display = resolveFor(
        stage: PublicDemoSalesStage.waiting,
        isCurrentlyAssigned: true,
        isReadyForFieldSales: false,
      );
      expect(display.label, isNot('参画中'));
      expect(display.tone, isNot(PublicDemoEmployeeStatusTone.assigned));
      expect(display.label, '研修が必要');
      expect(display.tone, PublicDemoEmployeeStatusTone.training);
    });

    test('参画予定 must never be confused with a 営業中 pipeline sub-stage — '
        'ordered-not-assigned keeps its own distinct label/tone even '
        'though both currently share the waiting tone', () {
      final ordered = resolveFor(
        stage: PublicDemoSalesStage.ordered,
        isCurrentlyAssigned: false,
      );
      final selling = resolveFor(stage: PublicDemoSalesStage.selling);
      expect(ordered.label, '参画予定');
      expect(selling.label, '営業中');
      expect(ordered.label, isNot(selling.label));
    });
  });

  group(
    'Fresh Audit §3/§6 fix: trainingSelections is not a resolver input at '
    'all — it can never override label or tone',
    () {
      test(
        'a field-sales-ready waiting engineer stays 営業可能/readyForSales '
        'regardless of any month-training-selection fact the caller may '
        'separately hold — the resolver has no parameter through which '
        'trainingSelections could reach it, so this cannot regress',
        () {
          final display = resolveFor(
            stage: PublicDemoSalesStage.waiting,
            isReadyForFieldSales: true,
            fieldSalesActionReachableThisMonth: true,
          );
          expect(display.label, '営業可能');
          expect(display.tone, PublicDemoEmployeeStatusTone.readyForSales);
        },
      );

      test(
        'an engineer genuinely on the 営業中 pipeline (e.g. selling) stays '
        '営業中/waiting tone regardless of any month-training-selection '
        'fact — the resolver has no way to paint a training tone over a '
        'pipeline sub-stage label',
        () {
          final display = resolveFor(stage: PublicDemoSalesStage.selling);
          expect(display.label, '営業中');
          expect(display.tone, PublicDemoEmployeeStatusTone.waiting);
        },
      );
    },
  );
}
