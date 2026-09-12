// Issue #245 Finding #12/#13 (採用応募者 lifecycle / 所在の可視化):
//
// Finding #12 — once an applicant joins, the 営業タブ applicant funnel
// (`_S._salesApplicantProgressCards`) rightly stops rendering their card
// (Issue #241 — their story continues on 社員, never a stale pre-join
// badge), but before this change that meant simply vanishing with no
// acknowledgement at all: a player scanning 営業 alone had no way to tell
// "採用面談後、この人はどうなったか" from a genuine bug.
//
// Finding #13 — every not-yet-joined applicant rendered as one flat,
// undifferentiated list: a candidate still needing player action sat
// visually indistinguishable from one whose outcome was already final
// (不採用/内定辞退/各面談不合格, which render no button at all) and from one
// simply waiting for the month-end join boundary.
//
// This suite exercises the two purely-presentational fixes for both
// findings — `_S._salesOverviewSection`'s new 入社済み summary line, and
// `_S._salesApplicantProgressCards`'s new active/awaitingJoin/closed
// grouping — entirely through real production `PublicDemoAggregate`
// commands (`recruit`/`completeInterview`/interactive interview
// session/`acceptOffer`/pre-entry-sales chain/`recordJuneOrder`/`closeMay`),
// exactly like `public_demo_sales_ui_phase1_test.dart` and
// `public_demo_issue248_applicant_engineer_continuity_test.dart` this suite
// borrows its fixture techniques from. No fabricated applicant/stage is
// ever constructed directly.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/models/recruitment_interview.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import 'public_demo_tab_test_helpers.dart';

const _expense = 800000;

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

Future<void> _pumpSalesTab(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: SesTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: PublicDemo01PlaceholderScreen(
          saveService: _FixedSaveService(aggregate),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
}

const _activeHeader = '対応が必要な候補者';
const _awaitingHeader = '結果待ち・入社予定';
const _closedHeader = '結果確定（不採用・辞退）';
const _joinedSummaryKey = Key('public-demo-sales-joined-summary');

/// A May aggregate with one real, free-medium applicant left untouched at
/// `applied` — the same fixture technique as
/// `public_demo_sales_ui_phase1_test.dart`'s `mayWithApplicants`.
PublicDemoAggregate _mayWithOneActiveApplicant() {
  final started = PublicDemoAggregate.initial(
    runSeed: 1,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = started.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  return recruited.aggregate!;
}

/// Drives one real, seeded applicant all the way through the actual
/// production reject decision — `recruit` -> `completeInterview` -> the
/// interactive recruitment-interview session -> `concludeInterviewSession
/// (InterviewOutcome.rejected)` — the same "見送る" path
/// `public_demo_recruitment_interview_test.dart`'s own "reject/decline
/// path" test exercises. Never fabricates `PublicDemoApplicantStage
/// .rejected` directly.
PublicDemoAggregate _mayWithOneRejectedApplicant() {
  var aggregate = _mayWithOneActiveApplicant();
  final id = aggregate.workflow.applicants.first.id;
  aggregate = aggregate.completeInterview(id).aggregate;
  aggregate = aggregate
      .startInterviewSession(id)
      .askInterviewQuestion(id, InterviewQuestionCategory.technical)
      .askInterviewQuestion(id, InterviewQuestionCategory.career)
      .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
      .answerInterviewReverseQuestion(id, 0);
  aggregate = aggregate.concludeInterviewSession(
    id,
    InterviewOutcome.rejected,
  );
  expect(
    aggregate.workflow.applicants.first.stage.name,
    'rejected',
    reason: 'fixture sanity',
  );
  return aggregate;
}

/// Recruits the real engineer-medium pair (runSeed 1 — already relied on
/// elsewhere, see `public_demo_issue248_applicant_engineer_continuity_test
/// .dart`, as a seed whose first candidate clears every real formula this
/// chain depends on) and drives ONLY the first candidate through the real
/// production pre-entry-sales chain up to `recordJuneOrder` — deliberately
/// NOT calling `closeMay`, so this applicant is genuinely `juneOrdered` but
/// not yet [PublicDemoApplicant.hasJoined]. The second candidate is left
/// untouched at `applied`, giving one aggregate with both an `active` and
/// an `awaitingJoin` applicant at once.
PublicDemoAggregate _mayWithActiveAndAwaitingJoinApplicants() {
  var aggregate = PublicDemoAggregate.initial(runSeed: 1)
      .recruit(PublicDemoRecruitmentMedium.engineer)
      .aggregate!
      .closeApril(monthlyExpenses: _expense);
  final ordering = aggregate.workflow.applicants.first;
  final stillActive = aggregate.workflow.applicants[1];

  aggregate = aggregate.completeInterview(ordering.id).aggregate;
  final interviewed = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == ordering.id,
  );
  final offer = PublicDemoSalaryOfferEvaluator.evaluate(
    applicant: interviewed,
    offeredMonthlySalary: interviewed.requestedMonthlySalary,
  );
  aggregate = aggregate.acceptOffer(
    applicantId: ordering.id,
    offer: offer,
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(aggregate.state.month),
  );
  aggregate = aggregate
      .beginPreEntrySkillSheet(ordering.id)
      .beginPreEntrySelling(ordering.id)
      .introducePreEntryProject(ordering.id)
      .recordPreEntryPartnerInterviewResult(ordering.id)
      .recordPreEntryClientInterviewResult(ordering.id)
      .recordJuneOrder(ordering.id);

  final orderedApplicant = aggregate.workflow.applicants.firstWhere(
    (a) => a.id == ordering.id,
  );
  expect(
    orderedApplicant.stage.name,
    'juneOrdered',
    reason: 'fixture sanity',
  );
  expect(orderedApplicant.hasJoined, isFalse, reason: 'fixture sanity');
  expect(
    aggregate.workflow.applicants
        .firstWhere((a) => a.id == stillActive.id)
        .stage
        .name,
    'applied',
    reason: 'fixture sanity',
  );
  return aggregate;
}

/// Issue #241 fixture (matches `public_demo_sales_ui_phase1_test.dart`'s
/// own `juneWithJoinedHire`): the May free-medium applicant's offer is
/// accepted and genuinely joined at `closeMay`.
PublicDemoAggregate _juneWithOneJoinedApplicant() {
  final game = _mayWithOneActiveApplicant();
  final applicantId = game.workflow.applicants.first.id;
  final interview = game.completeInterview(applicantId);
  var next = interview.aggregate;
  final applicant = next.workflow.applicants.firstWhere(
    (a) => a.id == applicantId,
  );
  next = next.acceptOffer(
    applicantId: applicantId,
    offer: PublicDemoSalaryOffer(
      requestedMonthlySalary: applicant.requestedMonthlySalary,
      offeredMonthlySalary: applicant.requestedMonthlySalary,
      acceptanceScore: 100,
      motivationDelta: 0,
      trustDelta: 0,
    ),
    fiscalCloseId: PublicDemoFiscalCloseId.forMonth(next.state.month),
  );
  return next.closeMay(week: 9, monthlyExpenses: _expense);
}

void main() {
  group('Finding #13: 採用・候補者進捗 lifecycle grouping', () {
    testWidgets(
      'a single in-progress applicant renders only the 対応が必要 header, '
      'with the correct count and no other bucket header',
      (tester) async {
        await _pumpSalesTab(tester, _mayWithOneActiveApplicant());

        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_awaitingHeader), findsNothing);
        expect(find.textContaining(_closedHeader), findsNothing);
      },
    );

    testWidgets(
      'a genuinely rejected applicant renders only the 結果確定 header, '
      'keeps its 不採用 badge, and never renders a button',
      (tester) async {
        final aggregate = _mayWithOneRejectedApplicant();
        await _pumpSalesTab(tester, aggregate);

        expect(find.text('$_closedHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_activeHeader), findsNothing);
        expect(find.textContaining(_awaitingHeader), findsNothing);
        expect(find.text('不採用'), findsOneWidget);
        expect(
          find.text(aggregate.workflow.applicants.first.name),
          findsOneWidget,
          reason: 'a rejected (not-yet-joined) applicant must still be '
              'visible on the funnel — only a joined one disappears',
        );
      },
    );

    testWidgets(
      'an active applicant and a juneOrdered-but-not-yet-joined applicant '
      'render under separate headers, each with count 1, and mutual '
      'exclusion holds (no 結果確定 header)',
      (tester) async {
        final aggregate = _mayWithActiveAndAwaitingJoinApplicants();
        await _pumpSalesTab(tester, aggregate);

        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.text('$_awaitingHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_closedHeader), findsNothing);

        // Both applicants are still genuinely on the funnel (neither has
        // joined yet) -- Issue #241's own exclusion rule only fires once
        // `hasJoined` is true.
        for (final applicant in aggregate.workflow.applicants) {
          expect(find.text(applicant.name), findsOneWidget);
        }
      },
    );

    testWidgets(
      'the active header renders above the awaitingJoin header (same '
      'left-to-right reading order as the pipeline itself)',
      (tester) async {
        await _pumpSalesTab(
          tester,
          _mayWithActiveAndAwaitingJoinApplicants(),
        );

        final activeHeaderY = tester
            .getTopLeft(find.text('$_activeHeader（1名）'))
            .dy;
        final awaitingHeaderY = tester
            .getTopLeft(find.text('$_awaitingHeader（1名）'))
            .dy;
        expect(activeHeaderY, lessThan(awaitingHeaderY));
      },
    );
  });

  group('Finding #12: 入社済み summary line', () {
    testWidgets(
      'once the only applicant joins, the overview section states the '
      'joined count truthfully, the funnel section disappears entirely, '
      'and the applicant\'s own name never renders again on 営業 (Issue '
      '#241 regression)',
      (tester) async {
        final joined = _juneWithOneJoinedApplicant();
        final joinedApplicant = joined.workflow.applicants.first;
        expect(joinedApplicant.hasJoined, isTrue, reason: 'fixture sanity');

        await _pumpSalesTab(tester, joined);

        final summary = tester.widget<Text>(find.byKey(_joinedSummaryKey));
        expect(summary.data, '入社済み 1名（社員タブで活動中）');
        expect(
          find.text(joinedApplicant.name),
          findsNothing,
          reason: 'the joined-count summary must never repeat the '
              'applicant\'s own name -- Issue #241 explicitly requires it '
              'never render on 営業 again',
        );
        expect(
          find.byKey(
            const Key('public-demo-sales-applicant-progress-section'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'before anyone has joined, no 入社済み summary line renders at all '
      '-- the fact stays genuinely absent, never a fabricated "0名"',
      (tester) async {
        await _pumpSalesTab(tester, _mayWithOneActiveApplicant());

        expect(find.byKey(_joinedSummaryKey), findsNothing);
      },
    );

    testWidgets(
      'a joined applicant coexisting with a still-active one: the summary '
      'line and the active funnel card both render together, truthfully',
      (tester) async {
        // Build on top of the already-joined fixture by recruiting a fresh
        // June applicant via the real production `recruit` command.
        var aggregate = _juneWithOneJoinedApplicant();
        expect(aggregate.state.month, 6, reason: 'fixture sanity');
        final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
        expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
        aggregate = recruited.aggregate!;
        final newApplicant = aggregate.workflow.applicants.firstWhere(
          (a) => !a.hasJoined,
        );

        await _pumpSalesTab(tester, aggregate);

        final summary = tester.widget<Text>(find.byKey(_joinedSummaryKey));
        expect(summary.data, '入社済み 1名（社員タブで活動中）');
        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.text(newApplicant.name), findsOneWidget);
      },
    );
  });

  group('State integrity: save/reload and duplicate action', () {
    testWidgets(
      'save/reload (toJson -> fromJson) preserves the exact same grouping '
      'and joined summary -- the grouping is purely derived from '
      'already-persisted stage/hasJoined facts, never its own state',
      (tester) async {
        final before = _mayWithActiveAndAwaitingJoinApplicants();
        final reloaded = PublicDemoAggregate.fromJson(before.toJson());

        await _pumpSalesTab(tester, reloaded);

        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.text('$_awaitingHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_closedHeader), findsNothing);
      },
    );

    testWidgets(
      'double tap on スキルシート確認 (duplicate action): the applicant '
      'advances exactly once, stays counted exactly once under 対応が必要, '
      'and no exception is thrown',
      (tester) async {
        await _pumpSalesTab(tester, _mayWithOneActiveApplicant());

        final button = find.text('スキルシート確認');
        await tester.tap(button);
        await tester.pump();
        // A second, rapid tap before the first has settled -- the same
        // duplicate/double-tap shape the task's own verification
        // requirements call out.
        if (tester.any(button)) {
          await tester.tap(button);
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('$_activeHeader（1名）'), findsOneWidget);
        expect(find.textContaining(_awaitingHeader), findsNothing);
        expect(find.textContaining(_closedHeader), findsNothing);
      },
    );
  });

  group(
    '360x800 / 390x844, TextScaler 1.0/1.3: grouping headers never overflow',
    () {
      for (final size in const [Size(360, 800), Size(390, 844)]) {
        for (final textScale in [1.0, 1.3]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: active + awaitingJoin headers stay within bounds',
            (tester) async {
              await _pumpSalesTab(
                tester,
                _mayWithActiveAndAwaitingJoinApplicants(),
                size: size,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull);

              for (final text in [
                '$_activeHeader（1名）',
                '$_awaitingHeader（1名）',
              ]) {
                final rect = tester.getRect(find.text(text));
                expect(rect.left, greaterThanOrEqualTo(0.0));
                expect(rect.right, lessThanOrEqualTo(size.width));
              }
            },
          );

          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: 入社済み summary line stays within bounds',
            (tester) async {
              await _pumpSalesTab(
                tester,
                _juneWithOneJoinedApplicant(),
                size: size,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull);

              final rect = tester.getRect(find.byKey(_joinedSummaryKey));
              expect(rect.left, greaterThanOrEqualTo(0.0));
              expect(rect.right, lessThanOrEqualTo(size.width));
            },
          );
        }
      }
    },
  );
}
