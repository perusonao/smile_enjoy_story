import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_mission_resolver.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';

/// SES First Fun Quarter Mission System Phase 1 (Fresh Audit §3/§5,
/// Implementation Plan §3.6): pure unit coverage for
/// [PublicDemoMissionResolver.resolve] — mirrors
/// `public_demo_employee_status_resolver_test.dart`'s own convention:
/// direct construction of [PublicDemoWorkflowState]/[PublicDemoEngineerSales]
/// fixtures for boundary-condition coverage, plus real-command aggregate
/// chains (matching every other Public Demo domain test's fixture
/// convention) for authority-regression pins.
void main() {
  PublicDemoMissionStatus statusOf(
    List<PublicDemoMissionStatusEntry> entries,
    PublicDemoMissionId id,
  ) => entries.firstWhere((entry) => entry.id == id).status;

  group('fresh April start — locked/available boundaries', () {
    test('only viewSkillSheet is available; every other mission is locked', () {
      final aggregate = PublicDemoAggregate.initial();
      final entries = PublicDemoMissionResolver.resolve(
        workflow: aggregate.workflow,
        state: aggregate.state,
      );
      expect(entries.length, publicDemoAprilMissionChain.length);
      expect(
        statusOf(entries, PublicDemoMissionId.viewSkillSheet),
        PublicDemoMissionStatus.available,
      );
      for (final id in publicDemoAprilMissionChain.skip(1)) {
        expect(
          statusOf(entries, id),
          PublicDemoMissionStatus.locked,
          reason: '$id should be locked before any engineer acts',
        );
      }
      expect(
        entries.every((e) => e.status != PublicDemoMissionStatus.completed),
        isTrue,
      );
    });
  });

  group('single-engineer April chain — each step flips exactly one mission', () {
    test('viewSkillSheet completes, beginSelling becomes available', () {
      final aggregate = PublicDemoAggregate.initial().startSkillSheetReview(
        'eng-01',
      );
      final entries = PublicDemoMissionResolver.resolve(
        workflow: aggregate.workflow,
        state: aggregate.state,
      );
      expect(
        statusOf(entries, PublicDemoMissionId.viewSkillSheet),
        PublicDemoMissionStatus.completed,
      );
      expect(
        entries.firstWhere((e) => e.id == PublicDemoMissionId.viewSkillSheet).engineerId,
        'eng-01',
      );
      expect(
        statusOf(entries, PublicDemoMissionId.beginSelling),
        PublicDemoMissionStatus.available,
      );
      expect(
        statusOf(entries, PublicDemoMissionId.proposeToProject),
        PublicDemoMissionStatus.locked,
      );
    });

    test('beginSelling completes, proposeToProject becomes available', () {
      final aggregate = PublicDemoAggregate.initial()
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01');
      final entries = PublicDemoMissionResolver.resolve(
        workflow: aggregate.workflow,
        state: aggregate.state,
      );
      expect(
        statusOf(entries, PublicDemoMissionId.beginSelling),
        PublicDemoMissionStatus.completed,
      );
      expect(
        statusOf(entries, PublicDemoMissionId.proposeToProject),
        PublicDemoMissionStatus.available,
      );
      expect(
        statusOf(entries, PublicDemoMissionId.passPartnerInterview),
        PublicDemoMissionStatus.locked,
      );
    });

    test(
      'introduceProject completes proposeToProject, passPartnerInterview '
      'becomes available',
      () {
        final aggregate = PublicDemoAggregate.initial()
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01');
        final entries = PublicDemoMissionResolver.resolve(
          workflow: aggregate.workflow,
          state: aggregate.state,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.proposeToProject),
          PublicDemoMissionStatus.completed,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.passPartnerInterview),
          PublicDemoMissionStatus.available,
        );
      },
    );

    test(
      'passing partner interview completes passPartnerInterview (eng-01, '
      'deterministic pass: actualCapability 78)',
      () {
        final aggregate = PublicDemoAggregate.initial()
            .startSkillSheetReview('eng-01')
            .beginSelling('eng-01')
            .introduceProject('eng-01')
            .recordEngineerInterviewResult(
              engineerId: 'eng-01',
              type: PublicDemoInterviewType.partner,
            );
        final entries = PublicDemoMissionResolver.resolve(
          workflow: aggregate.workflow,
          state: aggregate.state,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.passPartnerInterview),
          PublicDemoMissionStatus.completed,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.passClientInterview),
          PublicDemoMissionStatus.available,
        );
      },
    );

    test(
      'failing partner interview leaves passPartnerInterview NOT completed '
      '(eng-02, deterministic fail: actualCapability 52 → score 57 < 60)',
      () {
        final aggregate = PublicDemoAggregate.initial()
            .startSkillSheetReview('eng-02')
            .beginSelling('eng-02')
            .introduceProject('eng-02')
            .recordEngineerInterviewResult(
              engineerId: 'eng-02',
              type: PublicDemoInterviewType.partner,
            );
        expect(
          aggregate.workflow.engineers
              .firstWhere((e) => e.id == 'eng-02')
              .stage,
          PublicDemoSalesStage.partnerInterviewFailed,
        );
        final entries = PublicDemoMissionResolver.resolve(
          workflow: aggregate.workflow,
          state: aggregate.state,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.passPartnerInterview),
          PublicDemoMissionStatus.available,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.passClientInterview),
          PublicDemoMissionStatus.locked,
        );
      },
    );

    test(
      'retry after a genuine partner-interview failure: beginSelling '
      '(accepted from partnerInterviewFailed) re-enters the pipeline, and a '
      'later genuine pass completes passPartnerInterview — RECOVERY-LOOP-1\'s '
      'own re-entry, not a forged shortcut',
      () {
        var aggregate = PublicDemoAggregate.initial()
            .startSkillSheetReview('eng-02')
            .beginSelling('eng-02')
            .introduceProject('eng-02')
            .recordEngineerInterviewResult(
              engineerId: 'eng-02',
              type: PublicDemoInterviewType.partner,
            );
        expect(
          aggregate.workflow.engineers
              .firstWhere((e) => e.id == 'eng-02')
              .stage,
          PublicDemoSalesStage.partnerInterviewFailed,
        );
        var entries = PublicDemoMissionResolver.resolve(
          workflow: aggregate.workflow,
          state: aggregate.state,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.passPartnerInterview),
          isNot(PublicDemoMissionStatus.completed),
        );

        // A real re-entry (beginSelling accepts from partnerInterviewFailed
        // — public_demo_workflow_state.dart's own transition table) plus a
        // genuine capability improvement (the same shape real Growth would
        // produce) — never a caller-asserted outcome. Round-tripped through
        // the aggregate's own fromJson (never a reconstruction shortcut)
        // since [PublicDemoAggregate] deliberately exposes no generic
        // "withState" combinator.
        final raisedRuntime = publicDemoRecoveryRuntime('eng-02', capability: 90);
        final newState = aggregate.state.copyWith(
          engineerRuntimes: [
            for (final runtime in aggregate.state.engineerRuntimes)
              if (runtime.engineerId == 'eng-02') raisedRuntime else runtime,
          ],
        );
        aggregate = PublicDemoAggregate.fromJson({
          'state': newState.toJson(),
          'workflow': aggregate.workflow.toJson(),
        });
        aggregate = aggregate
            .beginSelling('eng-02')
            .introduceProject('eng-02')
            .recordEngineerInterviewResult(
              engineerId: 'eng-02',
              type: PublicDemoInterviewType.partner,
            );
        expect(
          aggregate.workflow.engineers
              .firstWhere((e) => e.id == 'eng-02')
              .stage,
          PublicDemoSalesStage.partnerInterviewPassed,
          reason: 'sanity: the raised capability must genuinely clear the '
              'score >= 60 threshold this time',
        );

        entries = PublicDemoMissionResolver.resolve(
          workflow: aggregate.workflow,
          state: aggregate.state,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.passPartnerInterview),
          PublicDemoMissionStatus.completed,
        );
      },
    );

    test(
      'a genuine client-interview pass completes passClientInterview via '
      'the unforgeable record, winOrder becomes available',
      () {
        final aggregate = publicDemoAdvanceEngineerToOrdered(
          PublicDemoAggregate.initial(),
          'eng-01',
        );
        // publicDemoAdvanceEngineerToOrdered already calls recordOrder, so
        // by this point winOrder itself is already completed too — assert
        // both, matching the real reachable sequence.
        final entries = PublicDemoMissionResolver.resolve(
          workflow: aggregate.workflow,
          state: aggregate.state,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.passClientInterview),
          PublicDemoMissionStatus.completed,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.winOrder),
          PublicDemoMissionStatus.completed,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.assignToProject),
          PublicDemoMissionStatus.available,
        );
      },
    );
  });

  group(
    'authority regression pin: ordered + assigned (Fresh Audit §3 rows 7-8)',
    () {
      test(
        'closeApril assigns a genuinely-ordered engineer for May: winOrder '
        'AND assignToProject are both completed simultaneously',
        () {
          var aggregate = publicDemoAdvanceEngineerToOrdered(
            PublicDemoAggregate.initial(),
            'eng-01',
          );
          aggregate = aggregate.closeApril(monthlyExpenses: 800000);
          final entries = PublicDemoMissionResolver.resolve(
            workflow: aggregate.workflow,
            state: aggregate.state,
          );
          expect(
            statusOf(entries, PublicDemoMissionId.winOrder),
            PublicDemoMissionStatus.completed,
          );
          expect(
            statusOf(entries, PublicDemoMissionId.assignToProject),
            PublicDemoMissionStatus.completed,
          );
          expect(
            entries
                .firstWhere((e) => e.id == PublicDemoMissionId.assignToProject)
                .engineerId,
            'eng-01',
          );
          expect(
            entries.every((e) => e.status == PublicDemoMissionStatus.completed),
            isTrue,
            reason: 'the full April chain should be complete once assigned',
          );
        },
      );
    },
  );

  group('company-level reduction: any engineer satisfies a mission', () {
    test(
      'engineer A viewed SkillSheet, engineer B began selling — both '
      'missions read as completed at the company level',
      () {
        final aggregate = PublicDemoAggregate.initial()
            .startSkillSheetReview('eng-01')
            .startSkillSheetReview('eng-02')
            .beginSelling('eng-02');
        final entries = PublicDemoMissionResolver.resolve(
          workflow: aggregate.workflow,
          state: aggregate.state,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.viewSkillSheet),
          PublicDemoMissionStatus.completed,
        );
        expect(
          statusOf(entries, PublicDemoMissionId.beginSelling),
          PublicDemoMissionStatus.completed,
        );
        expect(
          entries
              .firstWhere((e) => e.id == PublicDemoMissionId.beginSelling)
              .engineerId,
          'eng-02',
        );
      },
    );
  });

  group('month boundary — no stale-month read (Fresh Audit §10.6)', () {
    test(
      'assignToProject reflects the resolver call\'s OWN state.month, not a '
      'value captured earlier',
      () {
        var aggregate = publicDemoAdvanceEngineerToOrdered(
          PublicDemoAggregate.initial(),
          'eng-01',
        );
        aggregate = aggregate.closeApril(monthlyExpenses: 800000);
        aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 800000);
        // June's own continuation decision — the real command the June UI
        // uses (`withAssignmentUpdate`) — must actually mark eng-01
        // `accepted` before close, or assignedEngineerIds' July filter
        // (nextOrderStatus == accepted) would correctly show nobody
        // assigned; this is what makes the test genuinely exercise the
        // "current month, not stale" concern rather than trivially passing.
        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.accepted,
        );
        aggregate = aggregate.closeJune(
          assignedInJuly: 1,
          monthlyExpenses: 800000,
        );
        final entries = PublicDemoMissionResolver.resolve(
          workflow: aggregate.workflow,
          state: aggregate.state,
        );
        expect(aggregate.state.month, 7);
        expect(
          statusOf(entries, PublicDemoMissionId.assignToProject),
          PublicDemoMissionStatus.completed,
        );
      },
    );
  });

  group('legacy save compatibility (Fresh Audit §10.5)', () {
    test(
      'a save predating the Mission System, with an engineer already '
      'ordered+assigned, resolves the full chain as completed the moment '
      'it is loaded into a Mission-System-aware build — no new field, no '
      're-play required',
      () {
        var aggregate = publicDemoAdvanceEngineerToOrdered(
          PublicDemoAggregate.initial(),
          'eng-01',
        );
        aggregate = aggregate.closeApril(monthlyExpenses: 800000);

        // Round-trip through the REAL save codec (encode/decode), exactly
        // as a genuine "load an old save" would — this is the save format
        // that existed before the Mission System, since the codec itself
        // was never touched by this feature (no new field, no
        // schemaVersion bump).
        const codec = PublicDemoSaveCodec();
        final restored = codec.decode(codec.encode(aggregate));
        expect(restored, isNotNull);

        final entries = PublicDemoMissionResolver.resolve(
          workflow: restored!.workflow,
          state: restored.state,
        );
        expect(
          entries.every((e) => e.status == PublicDemoMissionStatus.completed),
          isTrue,
        );
      },
    );
  });

  group('malformed/forged stage cannot fake Mission completion', () {
    test(
      'stage forged to ordered with NO genuine interview record: winOrder '
      '(bare-stage authority) reads completed, but passClientInterview and '
      'assignToProject (unforgeable-record / roster-membership authority) '
      'correctly do not',
      () {
        final forged = PublicDemoEngineerSales(
          id: 'eng-01',
          name: '佐藤 健',
          summary: 'forged',
          interviewProfile: const PublicDemoInterviewProfile(
            skillFit: 78,
            humanity: 70,
            morale: 72,
            clientTrust: 60,
          ),
          stage: PublicDemoSalesStage.ordered,
          // interviewRecord deliberately omitted (null) — a stage claiming
          // `ordered` with no genuine client-interview pass behind it,
          // exactly the "stage/lastInterviewScore alone are NOT proof"
          // case PublicDemoEngineerSales's own doc warns about.
        );
        final workflow = PublicDemoWorkflowState(
          applicants: const <PublicDemoApplicant>[],
          engineers: [forged],
        );
        final state = PublicDemoState.aprilStart();
        final entries = PublicDemoMissionResolver.resolve(
          workflow: workflow,
          state: state,
        );
        expect(forged.hasGenuineInterviewRecord, isFalse);
        expect(
          statusOf(entries, PublicDemoMissionId.winOrder),
          PublicDemoMissionStatus.completed,
          reason:
              'Fresh Audit §3 row 7: winOrder is documented Category A, '
              'trusting bare stage==ordered exactly like the domain\'s own '
              'recordOrder precondition chain does',
        );
        expect(
          statusOf(entries, PublicDemoMissionId.passClientInterview),
          isNot(PublicDemoMissionStatus.completed),
          reason:
              'Fresh Audit §3 row 6: must read hasGenuineInterviewRecord, '
              'never stage alone',
        );
        expect(
          statusOf(entries, PublicDemoMissionId.assignToProject),
          isNot(PublicDemoMissionStatus.completed),
          reason:
              'a forged stage was never run through the real '
              'closeApril/assignment flow, so assignedEngineerIds is '
              'correctly still empty',
        );
      },
    );
  });

  group('duplicate-completion safety: re-resolving is idempotent', () {
    test('resolving twice in a row for the same aggregate is identical', () {
      var aggregate = publicDemoAdvanceEngineerToOrdered(
        PublicDemoAggregate.initial(),
        'eng-01',
      );
      aggregate = aggregate.closeApril(monthlyExpenses: 800000);
      final first = PublicDemoMissionResolver.resolve(
        workflow: aggregate.workflow,
        state: aggregate.state,
      );
      final second = PublicDemoMissionResolver.resolve(
        workflow: aggregate.workflow,
        state: aggregate.state,
      );
      for (var i = 0; i < first.length; i++) {
        expect(first[i].id, second[i].id);
        expect(first[i].status, second[i].status);
        expect(first[i].engineerId, second[i].engineerId);
      }
    });
  });
}
