import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  // scrollUntilVisible only guarantees the target exists in the tree, not
  // that it is within the current viewport (FINANCE-UX-1's monthly
  // cash-flow card made this screen's content tall enough for that gap to
  // matter) — ensureVisible explicitly scrolls it into the tappable area.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  // The button's handler now awaits _precacheEventImage(...) before opening
  // any event dialog (iOS rendering fix: decode the image before first
  // paint instead of after). In this Flutter SDK, MultiFrameImageStreamCompleter
  // only resolves via real wall-clock scheduling — the fake clock that
  // tester.pump()/pumpAndSettle() drives never completes it on its own — so
  // give the decode a real-time window via runAsync, interleaved with pumps
  // so a completion queued mid-wait still gets picked up. Looped rather than
  // one fixed delay since real wall-clock timing is noisier under parallel
  // test-file execution (CPU contention) than when a file runs alone.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Public Demo can be operated from April through July', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PublicDemo01PlaceholderScreen()),
    );
    expect(find.text('1年目 4月'), findsOneWidget);

    // April: advance without winning an order. The demo must still recover into May.
    await tapAndSettle(tester, '4月を終了して5月へ');
    // Issue #168: Sato (ready, untouched) is a genuine outstanding Month
    // Guard candidate here — this fixture's whole point is testing the
    // recovery route where nothing was done, so it proceeds past the
    // warning rather than resolving it, exactly as the Issue's own spec
    // allows ("プレイヤーが意図的に警告を無視して翌月へ進むこともできる").
    await dismissMonthGuardIfPresent(tester);
    // CORE-GAMEPLAY Phase 4.5: superseded Issue #168 Finding C's copy — a
    // new game now starts with zero applicants (no pre-seeded pool of any
    // kind to "確認できます"), so this states the one thing that stays true
    // regardless of what the player did in April: recruiting is a real
    // 求人媒体 action, not something that happens on its own.
    expect(find.text('採用は求人媒体から始まります'), findsOneWidget);
    expect(find.text('新しい応募が届きました'), findsNothing);
    expect(find.text('採用候補者の情報を確認できます'), findsNothing);
    expect(
      find.byKey(const Key('public-demo-recruitment-application-image')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, '確認'));
    await tester.pumpAndSettle();
    expect(find.text('1年目 5月'), findsOneWidget);
    // The completed April growth is visible without another modal — on 社員
    // now (PUBLIC-DEMO-HOME-UI-3B moved growth results off HOME). Both
    // engineers waited, so no practical experience is claimed.
    await switchPublicDemoTab(tester, PublicDemoTab.employees);
    expect(find.text('今月の成長'), findsOneWidget);
    expect(find.text('待機中の自己学習'), findsNWidgets(2));
    expect(find.textContaining('実務経験'), findsNothing);

    // May: advance without hiring. This is a valid failure/recovery route.
    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await tapAndSettle(tester, '5月を終了して6月へ');
    // CORE-GAMEPLAY Phase 4.5: recruitment media was never used this
    // playthrough, so there is no outstanding candidate of any kind to
    // review here — `dismissMonthGuardIfPresent` is a no-op if the guard
    // has nothing left to warn about, kept for robustness against fixture
    // changes (e.g. Sato/Suzuki-related warnings unrelated to recruiting).
    await dismissMonthGuardIfPresent(tester);
    expect(find.text('1年目 6月'), findsOneWidget);
    // PR #210 merge-blocker follow-up: 求人媒体 is no longer fixed to May
    // (`canUseRecruitmentMediaInMonth` spans April-August, see
    // `_salesNextActionCards`/`_addRecruitmentMediaCandidate`), and this
    // playthrough never used it — so it is still the eligible P3
    // Recommended Action candidate in June, outranking the plain month-goal
    // fallback (`翌月の発注を確認...`) that only rendered here before this
    // fix, when recruiting had no later entry point at all.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key == const Key('home-recommended-action-headline') &&
            w is Text &&
            w.data == '求人媒体で候補者を追加',
      ),
      findsOneWidget,
    );
    expect(find.text('6月を終了して7月へ'), findsOneWidget);

    // June: no assignments is valid; advance into July waiting state.
    await tapAndSettle(tester, '6月を終了して7月へ');
    expect(find.text('1年目 7月'), findsOneWidget);
    // SES-FIRST-FUN-YEAR-UI-PHASE-1: the July recap's own
    // "参画 X名 / 待機 Y名" line was removed as a duplicate of the always-
    // visible compact KPI's 参画/待機 tiles, which already carry this exact
    // fact on every build (see public_demo_01_placeholder_screen.dart's
    // July-block comment). Assert the fact through its one remaining home,
    // the KPI tile, rather than a line that no longer exists.
    expect(
      find.descendant(
        of: find.byKey(const Key('home-kpi-compact-assigned')),
        matching: find.text('0名'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home-kpi-compact-waiting')),
        matching: find.text('2名'),
      ),
      findsOneWidget,
    );

    // PR #210 merge-blocker follow-up: 求人媒体 is no longer fixed to May —
    // `canUseRecruitmentMediaInMonth`/`isRecruitmentMediaWindowMonth` both
    // span April-August, so July is still inside the recruiting window and
    // this playthrough never used it. The card and its funnel are separate
    // sections (`_salesNextActionCards` vs `_salesProjectStatusCards`), so
    // July's own assignment-result narrative ("7月開始結果") still renders
    // alongside it, not in place of it.
    await switchPublicDemoTab(tester, PublicDemoTab.sales);
    expect(
      find.byKey(const Key('public-demo-recruitment-media-card')),
      findsOneWidget,
    );
    expect(find.text('求人媒体を選ぶ'), findsOneWidget);
    expect(find.text('7月開始結果'), findsOneWidget);
    // 夏季賞与 is finance detail — moved to 会計.
    await switchPublicDemoTab(tester, PublicDemoTab.accounting);
    expect(find.text('夏季賞与'), findsOneWidget);

    // The default domain plan is none, but July still explicitly asks the
    // player to confirm that decision before it can be settled. The
    // month-close CTA is HOME's own monthly primary action.
    await switchPublicDemoTab(tester, PublicDemoTab.home);
    await tapAndSettle(tester, '7月を終了して8月へ');
    expect(
      find.byKey(const Key('public-demo-summer-bonus-none')),
      findsOneWidget,
    );
  });

  testWidgets('recruitment media adds applicants through the existing flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PublicDemo01PlaceholderScreen()),
    );
    await tapAndSettle(tester, '4月を終了して5月へ');
    await dismissMonthGuardIfPresent(tester);
    await tester.tap(find.widgetWithText(FilledButton, '確認'));
    await tester.pumpAndSettle();
    // The recruiting/applicant pipeline is on 営業 (PUBLIC-DEMO-HOME-UI-3B).
    await switchPublicDemoTab(tester, PublicDemoTab.sales);

    final recruitmentMediaButton = find.byKey(
      const Key('public-demo-open-recruitment-media'),
    );
    await tester.ensureVisible(recruitmentMediaButton);
    await tester.pumpAndSettle();
    await tester.tap(recruitmentMediaButton);
    await tester.pumpAndSettle();
    expect(find.text('無料求人'), findsOneWidget);
    expect(find.text('エンジニア求人'), findsOneWidget);
    expect(find.text('費用: ¥0 / 応募: 1名'), findsOneWidget);
    expect(find.text('費用: ¥100000 / 応募: 2名'), findsOneWidget);
    expect(find.text('利用後の現預金: ¥3100000'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('public-demo-recruitment-medium-engineer')),
    );
    await tester.pumpAndSettle();
    expect(find.text('現預金 ¥3100000'), findsWidgets);
    expect(
      find.byKey(const Key('public-demo-open-recruitment-media')),
      findsOneWidget,
    );
    expect(find.text('今月は利用済み'), findsOneWidget);
    expect(find.text('応募者2名を追加しました。'), findsOneWidget);
  });
}
