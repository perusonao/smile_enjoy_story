import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';

/// Issue #120 (PUBLIC-DEMO-RECRUIT-1A): "no active recruiting => no
/// recruiting-generated applicant; active recruiting follows existing
/// configured rules" pinned as its own explicit, dedicated regression
/// contract — none of the existing suites asserted both halves of this
/// together against the real, unmodified production entry point
/// ([PublicDemoAggregate.initial]).
///
/// Investigation for #120 traced every applicant-generation path Public
/// Demo 0.1 has and found exactly one:
/// [PublicDemoAggregate.recruit]/[PublicDemoRecruitmentCalculation]
/// (committed via [PublicDemoWorkflowState.withGeneratedApplicants]) —
/// reachable in production only from the explicit recruiting-media
/// confirmation flow (`_openRecruitmentMedia` in
/// public_demo_01_placeholder_screen.dart, gated behind a player-dismissible
/// bottom sheet). No other call site anywhere under `lib/` invokes either.
///
/// [PublicDemoAggregate.initial]'s own two applicants
/// (`publicDemoMayApplicants` — 高橋 翔 `app-01` / 田中 美咲 `app-02`) are
/// deliberately NOT produced by that path: they are the foundational,
/// pre-recruiting-media May roster (see [PublicDemoWorkflowState.initial]'s
/// own doc — "matching the founding team and established applicant pool
/// that predate this class") and remain the documented, end-to-end-tested
/// primary May hiring route (`e2e/helpers/public-demo-player.ts`'s
/// `interviewAndOfferAppOne`), which "existing applicant/interview flows
/// remain intact" (#120's own acceptance criteria) requires this suite not
/// disturb. This file pins the actual, current, already-correct contract —
/// recruiting media never runs itself, and running it commits exactly its
/// configured cost/count, atomically — with explicit ids/counts so a future
/// change cannot blur either half silently.
void main() {
  group('Issue #120: recruiting-media applicant generation requires an '
      'explicit recruiting action', () {
    test('no recruiting action taken: nothing recruiting-media-generated is '
        'present, and the medium-usage guard is untouched', () {
      final aggregate = PublicDemoAggregate.initial();

      expect(aggregate.state.recruitmentMediumUsedMonth, isNull);
      expect(
        aggregate.workflow.applicants.where(
          (applicant) => applicant.id.startsWith('recruitment-'),
        ),
        isEmpty,
        reason:
            'a fresh game with zero PublicDemoAggregate.recruit calls '
            'must contain no recruiting-media-generated applicant',
      );
      expect(
        aggregate.workflow.applicants.map((applicant) => applicant.id),
        orderedEquals(publicDemoMayApplicants.map((applicant) => applicant.id)),
        reason:
            'the only applicants present before any recruiting action '
            'are the established, pre-existing May roster — never more, '
            'never fewer',
      );
    });

    test('active recruiting (paid engineer medium) adds exactly its '
        'configured count, atomically with its configured cost', () {
      final aggregate = PublicDemoAggregate.initial();
      const medium = PublicDemoRecruitmentMedium.engineer;
      final baselineIds = aggregate.workflow.applicants
          .map((applicant) => applicant.id)
          .toSet();

      final result = aggregate.recruit(medium);

      expect(result.isSuccess, isTrue);
      final committed = result.aggregate!;
      expect(
        committed.workflow.applicants.length,
        aggregate.workflow.applicants.length + medium.applicantCount,
      );
      expect(committed.state.cash, aggregate.state.cash - medium.cost);
      expect(committed.state.recruitmentMediumUsedMonth, aggregate.state.month);
      final newIds = committed.workflow.applicants
          .map((applicant) => applicant.id)
          .where((id) => !baselineIds.contains(id))
          .toSet();
      expect(newIds, hasLength(medium.applicantCount));
      expect(newIds, everyElement(startsWith('recruitment-')));
    });

    test('active recruiting (free medium) adds exactly its configured count '
        'at zero cost', () {
      final aggregate = PublicDemoAggregate.initial();
      const medium = PublicDemoRecruitmentMedium.free;

      final result = aggregate.recruit(medium);

      expect(result.isSuccess, isTrue);
      expect(
        result.aggregate!.workflow.applicants.length,
        aggregate.workflow.applicants.length + medium.applicantCount,
      );
      expect(result.aggregate!.state.cash, aggregate.state.cash);
    });

    test('a second recruiting attempt in the same month is rejected and '
        'generates nothing further', () {
      var aggregate = PublicDemoAggregate.initial();
      aggregate = aggregate
          .recruit(PublicDemoRecruitmentMedium.free)
          .aggregate!;
      final countAfterFirst = aggregate.workflow.applicants.length;

      final second = aggregate.recruit(PublicDemoRecruitmentMedium.engineer);

      expect(second.isSuccess, isFalse);
      expect(second.aggregate, isNull);
      expect(aggregate.workflow.applicants.length, countAfterFirst);
    });
  });
}
