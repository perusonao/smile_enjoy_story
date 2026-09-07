// SES NON-HOME-UI SALES Visual Complete: coverage for the new
// Reference-style visual structure added on top of SES SALES-UI-PHASE-1's
// existing 4-section information architecture (unchanged — see
// public_demo_sales_ui_phase1_test.dart) — the overview stat tiles, each
// pipeline card's avatar/status-badge tone, and the 求人媒体 card's icon.
// Every value asserted here is read from the same authoritative fixtures
// the Phase 1 suite already builds via real domain commands.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_sales_visual.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import 'public_demo_tab_test_helpers.dart';

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

const _expense = 10000;

Future<void> pumpSalesTab(
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

/// Same fixture shape as the Phase 1 suite: May reached before the
/// recruitment-media flow has been used this month — `workflow.applicants`
/// already carries `PublicDemoWorkflowState.initial`'s own baseline pool, so
/// the applicant funnel is genuinely non-empty.
PublicDemoAggregate mayBeforeRecruiting() =>
    PublicDemoAggregate.initial().closeApril(monthlyExpenses: _expense);

/// Sells the first founding engineer through April's real pipeline and
/// closes it — the same chain `public_demo_sales_ui_phase1_test.dart` uses
/// to reach later months with a genuine assignment on the books.
PublicDemoAggregate sellFirstEngineerAndCloseApril(PublicDemoAggregate game) {
  final engineerId = game.workflow.engineers[0].id;
  game = game.startSkillSheetReview(engineerId);
  game = game.beginSelling(engineerId);
  game = game.introduceProject(engineerId);
  game = game.recordEngineerInterviewResult(
    engineerId: engineerId,
    type: PublicDemoInterviewType.partner,
  );
  game = game.recordEngineerInterviewResult(
    engineerId: engineerId,
    type: PublicDemoInterviewType.client,
  );
  game = game.recordOrder(engineerId);
  return game.closeApril(monthlyExpenses: _expense);
}

/// Reaches June with one real, undecided assignment on the books.
PublicDemoAggregate juneWithAssignment() {
  var game = PublicDemoAggregate.initial();
  game = sellFirstEngineerAndCloseApril(game);
  game = game.closeMay(week: 9, monthlyExpenses: _expense);
  return game;
}

/// Reaches July's closing narrative with the one engineer's July
/// continuation already accepted in June (a positive/staffed outcome).
PublicDemoAggregate julyWithAcceptedResult() {
  var game = juneWithAssignment();
  final engineerId = game.workflow.engineers[0].id;
  game = game.withAssignmentUpdate(
    engineerId,
    nextOrderStatus: PublicDemoNextOrderStatus.accepted,
  );
  return game.closeJune(assignedInJuly: 1, monthlyExpenses: _expense);
}

/// Reaches July's closing narrative with the one engineer's assignment
/// genuinely left `notOffered` and no replacement yet ordered — the
/// truthful "still needs sales action" outcome (`待機（営業が必要）`), used to
/// verify the caution-toned badge with its longer label never overflows.
PublicDemoAggregate julyWithCautionResult() {
  var game = juneWithAssignment();
  final engineerId = game.workflow.engineers[0].id;
  game = game.withAssignmentUpdate(
    engineerId,
    nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
  );
  return game.closeJune(assignedInJuly: 0, monthlyExpenses: _expense);
}

void main() {
  group('Overview stat tiles (現在の営業・採用状況)', () {
    testWidgets(
      'May: 3 PublicDemoSalesStatTile widgets render inside the overview '
      'section, each carrying the same authoritative wording the prior '
      'plain-text summary used',
      (tester) async {
        final game = mayBeforeRecruiting();
        await pumpSalesTab(tester, game);

        final overview = find.byKey(
          const Key('public-demo-sales-overview-section'),
        );
        final tiles = find.descendant(
          of: overview,
          matching: find.byType(PublicDemoSalesStatTile),
        );
        expect(tiles, findsNWidgets(3));

        final widgets = tester
            .widgetList<PublicDemoSalesStatTile>(tiles)
            .toList();
        expect(widgets.any((w) => w.primaryText.startsWith('営業残')), isTrue);
        expect(widgets.any((w) => w.primaryText.startsWith('候補者')), isTrue);
        expect(widgets.any((w) => w.primaryText.startsWith('案件')), isTrue);
      },
    );

    testWidgets(
      'June with a pending assignment: the 案件 tile is emphasized and its '
      'secondary line states the pending count truthfully',
      (tester) async {
        final game = juneWithAssignment();
        await pumpSalesTab(tester, game);

        final overview = find.byKey(
          const Key('public-demo-sales-overview-section'),
        );
        final projectTile = tester
            .widgetList<PublicDemoSalesStatTile>(
              find.descendant(
                of: overview,
                matching: find.byType(PublicDemoSalesStatTile),
              ),
            )
            .firstWhere((w) => w.primaryText.startsWith('案件'));
        expect(projectTile.emphasize, isTrue);
        expect(projectTile.secondaryText, 'うち検討中 1件');
      },
    );
  });

  group('求人媒体 card (今やるべき営業アクション)', () {
    testWidgets('carries the campaign icon inside its own card', (
      tester,
    ) async {
      final game = mayBeforeRecruiting();
      await pumpSalesTab(tester, game);

      final card = find.byKey(const Key('public-demo-recruitment-media-card'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.campaign_outlined),
        ),
        findsOneWidget,
      );
    });
  });

  group('採用・候補者進捗 applicant card visual structure', () {
    testWidgets('May baseline applicant (未対応/応募 stage): avatar + status badge '
        'render, badge label matches the exact authoritative status text and '
        'tone reads inProgress (still moving through the pipeline)', (
      tester,
    ) async {
      final game = mayBeforeRecruiting();
      await pumpSalesTab(tester, game);

      expect(find.byType(PublicDemoSalesAvatar), findsWidgets);
      final badges = tester.widgetList<PublicDemoSalesStatusBadge>(
        find.byType(PublicDemoSalesStatusBadge),
      );
      expect(badges, isNotEmpty);
      expect(badges.first.label, '応募');
      expect(badges.first.tone, PublicDemoSalesStatusTone.inProgress);
    });

    testWidgets(
      '経歴書確認 advances the applicant, and the badge on screen updates to '
      'the new authoritative label while staying inProgress-toned',
      (tester) async {
        final game = mayBeforeRecruiting();
        await pumpSalesTab(tester, game);

        await tester.tap(find.text('経歴書確認').first);
        await tester.pumpAndSettle();

        final updatedBadge = tester
            .widgetList<PublicDemoSalesStatusBadge>(
              find.byType(PublicDemoSalesStatusBadge),
            )
            .firstWhere((b) => b.label == '書類確認済');
        expect(updatedBadge.tone, PublicDemoSalesStatusTone.inProgress);
      },
    );
  });

  group('案件・参画/継続状況 card visual structure', () {
    testWidgets(
      'June: the assignment card carries an avatar and a positive-toned '
      'badge (参画中/継続予定 both read as a staffed, positive outcome)',
      (tester) async {
        final game = juneWithAssignment();
        await pumpSalesTab(tester, game);

        expect(find.byType(PublicDemoSalesAvatar), findsWidgets);
        final badge = tester.widget<PublicDemoSalesStatusBadge>(
          find.byType(PublicDemoSalesStatusBadge).first,
        );
        expect(badge.tone, PublicDemoSalesStatusTone.positive);
        expect(badge.label, anyOf('参画中', '継続予定'));
      },
    );

    testWidgets(
      'July, accepted outcome: julyResult\'s own verbatim text renders in a '
      'positive-toned badge',
      (tester) async {
        final game = julyWithAcceptedResult();
        await pumpSalesTab(tester, game);

        final badge = tester
            .widgetList<PublicDemoSalesStatusBadge>(
              find.byType(PublicDemoSalesStatusBadge),
            )
            .firstWhere((b) => b.label == '現案件を継続');
        expect(badge.tone, PublicDemoSalesStatusTone.positive);
      },
    );

    testWidgets('July, not-yet-staffed outcome: julyResult\'s longer 待機（営業が必要） '
        'label renders in a caution-toned badge without overflowing', (
      tester,
    ) async {
      final game = julyWithCautionResult();
      await pumpSalesTab(tester, game, size: const Size(360, 800));

      expect(tester.takeException(), isNull);
      final badge = tester
          .widgetList<PublicDemoSalesStatusBadge>(
            find.byType(PublicDemoSalesStatusBadge),
          )
          .firstWhere((b) => b.label == '待機（営業が必要）');
      expect(badge.tone, PublicDemoSalesStatusTone.caution);
    });
  });

  group('PublicDemoSalesStatusBadge tone → color mapping is distinct', () {
    testWidgets('all 4 tones render distinct background colors', (
      tester,
    ) async {
      const tones = PublicDemoSalesStatusTone.values;
      final colors = <Color>{};
      for (final tone in tones) {
        await tester.pumpWidget(
          MaterialApp(
            home: PublicDemoSalesStatusBadge(label: 'テスト', tone: tone),
          ),
        );
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration! as BoxDecoration;
        colors.add(decoration.color!);
      }
      expect(
        colors.length,
        tones.length,
        reason: 'every tone must be visually distinct',
      );
    });
  });

  group('HOME Freeze regression', () {
    testWidgets(
      'none of the new visual widgets (avatar/badge/stat tile/card) leak '
      'into HOME',
      (tester) async {
        final game = mayBeforeRecruiting();
        await pumpSalesTab(tester, game);
        expect(find.byType(PublicDemoSalesAvatar), findsWidgets);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(find.byType(PublicDemoSalesAvatar), findsNothing);
        expect(find.byType(PublicDemoSalesStatusBadge), findsNothing);
        expect(find.byType(PublicDemoSalesStatTile), findsNothing);
        expect(find.byType(PublicDemoSalesCard), findsNothing);
      },
    );
  });

  group(
    '360x800 / 390x844, TextScaler 1.0/1.3/2.0: overview tiles and pipeline '
    'cards stay within screen bounds',
    () {
      for (final size in const [Size(360, 800), Size(390, 844)]) {
        for (final textScale in [1.0, 1.3, 2.0]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: May overview + applicant cards, no overflow',
            (tester) async {
              await pumpSalesTab(
                tester,
                mayBeforeRecruiting(),
                size: size,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull);

              for (final element
                  in find.byType(PublicDemoSalesStatTile).evaluate()) {
                final rect = tester.getRect(find.byWidget(element.widget));
                expect(rect.left, greaterThanOrEqualTo(0.0));
                expect(rect.right, lessThanOrEqualTo(size.width));
              }
              for (final element
                  in find.byType(PublicDemoSalesStatusBadge).evaluate()) {
                final rect = tester.getRect(find.byWidget(element.widget));
                expect(rect.left, greaterThanOrEqualTo(0.0));
                expect(rect.right, lessThanOrEqualTo(size.width));
              }
            },
          );

          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: July caution outcome (longest badge label), no '
            'overflow',
            (tester) async {
              await pumpSalesTab(
                tester,
                julyWithCautionResult(),
                size: size,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull);

              for (final badgeFinder
                  in find.byType(PublicDemoSalesStatusBadge).evaluate()) {
                final rect = tester.getRect(find.byWidget(badgeFinder.widget));
                expect(rect.left, greaterThanOrEqualTo(0.0));
                expect(rect.right, lessThanOrEqualTo(size.width));
              }
            },
          );
        }
      }
    },
  );
}
