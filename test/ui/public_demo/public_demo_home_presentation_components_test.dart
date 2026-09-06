import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_presentation_components.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

/// WCAG 2.x relative luminance (sRGB, gamma-corrected) — see
/// https://www.w3.org/TR/WCAG21/#dfn-relative-luminance. [Color]'s `r`/`g`/`b`
/// are already 0.0-1.0 floats on this Flutter SDK.
double _srgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color color) =>
    0.2126 * _srgbToLinear(color.r) +
    0.7152 * _srgbToLinear(color.g) +
    0.0722 * _srgbToLinear(color.b);

/// The WCAG contrast ratio between two colors, in [1.0, 21.0] — 4.5 is the
/// AA threshold for normal-size text this suite pins the monthly CTA to.
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: SesTheme.build(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    ),
  ),
);

/// The fixed three-item "今月の重要タスク" list — the same shape the owning
/// screen always builds (PUBLIC-DEMO-HOME-UI-3A). Tests below use a small
/// helper to build fixture items rather than repeating the three literals.
List<PublicDemoImportantTaskItem> _tasks({
  required void Function() onSalesPressed,
  required void Function() onFinancePressed,
}) => [
  PublicDemoImportantTaskItem(
    title: '営業活動を進める',
    fact: '営業残: 4回',
    category: '営業',
    ctaLabel: '対応する',
    onPressed: onSalesPressed,
  ),
  PublicDemoImportantTaskItem(
    title: '採用・面談に対応する',
    fact: '待機: 2名',
    category: '採用',
    ctaLabel: '対応する',
    onPressed: onSalesPressed,
  ),
  PublicDemoImportantTaskItem(
    title: '資金計画を確認する',
    fact: '今月の固定費: ¥85,000',
    category: '資金',
    ctaLabel: '確認する',
    onPressed: onFinancePressed,
  ),
];

void main() {
  testWidgets(
    // PUBLIC-DEMO-HOME-UI-3A: replaces the former "重要イベント" section
    // (an invisible empty-state marker, or at most one month-close event)
    // with the approved visual target's "今月の重要タスク" — always exactly
    // the caller's items, no empty state, no fabricated priority/deadline.
    'important tasks always renders all items with neutral category chips '
    'and calls each CTA once',
    (tester) async {
      var salesCalls = 0, financeCalls = 0;
      await tester.pumpWidget(
        host(
          PublicDemoImportantTasksSection(
            items: _tasks(
              onSalesPressed: () => salesCalls++,
              onFinancePressed: () => financeCalls++,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const Key('public-demo-important-tasks')),
        findsOneWidget,
      );
      expect(find.text('今月の重要タスク'), findsOneWidget);
      expect(find.text('営業活動を進める'), findsOneWidget);
      expect(find.text('採用・面談に対応する'), findsOneWidget);
      expect(find.text('資金計画を確認する'), findsOneWidget);
      expect(find.text('営業残: 4回'), findsOneWidget);
      expect(find.text('待機: 2名'), findsOneWidget);
      expect(find.text('今月の固定費: ¥85,000'), findsOneWidget);
      // SES HOME Final Visual Match (structural pass): the Visual SSOT's
      // `icon → title → fact` tiles show a category icon, not a visible
      // category-name chip — [item.category] itself is unchanged and
      // still reaches assistive technology verbatim via Semantics.
      expect(find.text('営業'), findsNothing);
      expect(find.text('採用'), findsNothing);
      expect(find.text('資金'), findsNothing);
      expect(find.bySemanticsLabel('営業'), findsOneWidget);
      expect(find.bySemanticsLabel('採用'), findsOneWidget);
      expect(find.bySemanticsLabel('資金'), findsOneWidget);
      expect(find.text('High Priority'), findsNothing);
      expect(find.text('重要'), findsNothing);
      // SES HOME Final Density: the CTA is icon-only now — its label never
      // renders as visible text (that would defeat the density win), but it
      // must still reach an assistive-technology user verbatim via
      // Semantics, and it must still be a real, tappable >=48px target.
      //
      // SES HOME Final Touch: the tappable region is the whole tile now
      // (see [_ImportantTaskCell]'s own doc), keyed the same as the former
      // icon-only button, and its Semantics node's label carries
      // [ctaLabel] alongside the tile's own title/fact text — a real
      // device screenshot found the former small icon a fiddly target to
      // aim for on a tile this wide.
      expect(find.text('対応する'), findsNothing);
      expect(find.text('確認する'), findsNothing);
      final salesCtaKey = const Key('important-task-cta-営業活動を進める');
      final recruitingCtaKey = const Key('important-task-cta-採用・面談に対応する');
      final financeCtaKey = const Key('important-task-cta-資金計画を確認する');
      for (final key in [salesCtaKey, recruitingCtaKey, financeCtaKey]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
        expect(
          tester.getSize(find.byKey(key)).height,
          greaterThanOrEqualTo(48),
          reason: '$key',
        );
      }
      expect(
        find.bySemanticsLabel(RegExp('対応する')),
        findsNWidgets(2),
        reason: '営業/採用 CTAs share the same label text',
      );
      expect(find.bySemanticsLabel(RegExp('確認する')), findsOneWidget);

      await tester.tap(find.byKey(salesCtaKey));
      expect(salesCalls, 1);
      await tester.tap(find.byKey(recruitingCtaKey));
      expect(salesCalls, 2);
      await tester.tap(find.byKey(financeCtaKey));
      expect(financeCalls, 1);
      expect(tester.takeException(), isNull);

      // SES HOME Final Touch: tapping anywhere else in the tile — its
      // title, its fact, or its own whitespace, not only the trailing
      // arrow — must reach the exact same single [InkWell], never a
      // second recognizer that could double-fire the same action.
      await tester.tap(find.text('営業活動を進める'));
      expect(salesCalls, 3);
      await tester.tap(find.text('今月の固定費: ¥85,000'));
      expect(financeCalls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('finance summary renders large numeric values', (tester) async {
    await tester.pumpWidget(
      host(
        const PublicDemoFinanceSummarySection(
          summary: PublicDemoFinanceSummaryModel(
            payroll: 123456789,
            fixedCosts: 50000000,
          ),
        ),
      ),
    );
    expect(find.text('今月の支出予定'), findsOneWidget);
    expect(find.text('-¥123,456,789'), findsOneWidget);
    expect(find.text('-¥50,000,000'), findsOneWidget);
    // SES-FIRST-FUN-YEAR-UI-PHASE-1: cash/revenue/nextMonthEstimate and the
    // warning banner are gone from this section — they duplicated the
    // compact KPI and the shortage/bankruptcy cards composed above HOME.
    // See PublicDemoFinanceSummaryModel's class doc.
    expect(find.text('現金残高'), findsNothing);
    expect(find.text('今月売上'), findsNothing);
    expect(find.text('次回入金予定'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.startsWith('資金警告') == true,
      ),
      findsNothing,
    );
  });

  testWidgets(
    // SES HOME Final Visual Match: the former single vertical list
    // (separated by `Divider`s) is now a 2-column grid — the first two
    // items share one row, and a third starts a second row instead of
    // squeezing three columns into 360px.
    'important tasks lays items out two per row, in order, with no '
    'priority claim duplicated across items',
    (tester) async {
      await tester.pumpWidget(
        host(
          PublicDemoImportantTasksSection(
            items: _tasks(onSalesPressed: _noOp, onFinancePressed: _noOp),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final sales = tester.getRect(find.text('営業活動を進める'));
      final recruiting = tester.getRect(find.text('採用・面談に対応する'));
      final finance = tester.getRect(find.text('資金計画を確認する'));

      // Row 1: 営業/採用 share the same row, 営業 on the left.
      expect(sales.top, recruiting.top);
      expect(sales.left, lessThan(recruiting.left));
      // Row 2: 資金 starts a new row below both, on the left column.
      expect(finance.top, greaterThan(sales.bottom));
      expect(finance.left, sales.left);
    },
  );

  testWidgets(
    // SES HOME Final Touch: a real device screenshot found the left/right
    // tiles at different heights whenever one title/fact pair wrapped to
    // more lines than the other. Both tiles in a row must share the taller
    // one's own height — background included — not just line up at the
    // top.
    'important tasks: the left and right tiles in a row always share the '
    'same height, even when one wraps to more lines than the other',
    (tester) async {
      await tester.pumpWidget(
        host(
          PublicDemoImportantTasksSection(
            items: [
              PublicDemoImportantTaskItem(
                title: '営業活動を進める',
                fact: '営業残: 4回',
                category: '営業',
                ctaLabel: '対応する',
                onPressed: _noOp,
              ),
              // Deliberately much longer than the sibling tile's title/fact
              // pair, so it wraps to more lines and would — absent the
              // fix — leave the tile above shorter than this one.
              PublicDemoImportantTaskItem(
                title: '資金計画を確認する（今月と来月の両方）',
                fact: '今月の固定費: ¥1,234,567（給与・家賃・保険料を含む）',
                category: '資金',
                ctaLabel: '確認する',
                onPressed: _noOp,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final salesTile = tester.getRect(
        find.byKey(const Key('important-task-cta-営業活動を進める')),
      );
      final financeTile = tester.getRect(
        find.byKey(const Key('important-task-cta-資金計画を確認する（今月と来月の両方）')),
      );
      expect(salesTile.top, financeTile.top);
      expect(
        salesTile.height,
        financeTile.height,
        reason:
            'the shorter tile ($salesTile) must stretch to match the '
            'taller one ($financeTile), not keep its own shorter natural '
            'height',
      );
    },
  );

  testWidgets(
    // PR #182 Codex P2: a lone item used to still sit in a half-width
    // `Expanded` beside an empty, reserved right column. It now spans the
    // full row instead of leaving that half unused.
    'important tasks with a single item spans the full row width, not a '
    'half-width column with an empty reserved half',
    (tester) async {
      await tester.pumpWidget(
        host(
          PublicDemoImportantTasksSection(
            items: [
              PublicDemoImportantTaskItem(
                title: '資金計画を確認する',
                fact: '今月の固定費: ¥85,000',
                category: '資金',
                ctaLabel: '確認する',
                onPressed: _noOp,
              ),
            ],
          ),
        ),
      );
      expect(find.text('資金計画を確認する'), findsOneWidget);
      expect(find.text('今月の固定費: ¥85,000'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final section = tester.getRect(
        find.byKey(const Key('public-demo-important-tasks')),
      );
      final cta = tester.getRect(
        find.byKey(const Key('important-task-cta-資金計画を確認する')),
      );
      // The lone tile's own trailing CTA sits near the section's right
      // edge — proof the tile spans (close to) the full row — rather than
      // stopping around the midpoint the way an unused, still-reserved
      // right-hand `Expanded` would leave it at.
      expect(cta.right, greaterThan(section.left + section.width * 0.7));
    },
  );

  testWidgets(
    // PR #182 Codex P2: the 2-column grid's half-width cell used to
    // ellipsize the finance task's only supporting fact — the real April
    // production string ("今月の固定費: ¥50,000") — at both target widths.
    // `item.fact` is now allowed to wrap onto a 2nd line instead of
    // truncating, so the full amount stays readable.
    'important tasks: the finance fact stays fully readable (not '
    'ellipsized) in the 2-column grid at both target widths',
    (tester) async {
      for (final width in [360.0, 390.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          host(
            PublicDemoImportantTasksSection(
              items: [
                PublicDemoImportantTaskItem(
                  title: '営業活動を進める',
                  fact: '営業残: 4回',
                  category: '営業',
                  ctaLabel: '対応する',
                  onPressed: _noOp,
                ),
                PublicDemoImportantTaskItem(
                  title: '資金計画を確認する',
                  fact: '今月の固定費: ¥50,000',
                  category: '資金',
                  ctaLabel: '確認する',
                  onPressed: _noOp,
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.text('今月の固定費: ¥50,000'),
          findsOneWidget,
          reason:
              'the full amount must be readable at width $width, not '
              'ellipsized (e.g. "今月の固定費: ¥5…")',
        );
      }
    },
  );

  testWidgets(
    'monthly primary CTA handles enabled, disabled, long label, and calls once',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          PublicDemoMonthlyPrimaryCtaSection(
            action: PublicDemoMonthlyPrimaryCtaModel(
              label: '非常に長い月次主要アクションのラベルをここに表示する',
              description: '今月の主要な行動を説明します。',
              enabled: true,
              onPressed: () => calls++,
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const Key('public-demo-monthly-primary-cta')),
      );
      expect(calls, 1);
      await tester.pumpWidget(
        host(
          const PublicDemoMonthlyPrimaryCtaSection(
            action: PublicDemoMonthlyPrimaryCtaModel(
              label: '次の月へ進む',
              description: '月末処理が必要です。',
              enabled: false,
              onPressed: _noOp,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('public-demo-monthly-primary-cta')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    // HOME-COMPACT-1B.4 FIX2 (Codex P2): the enabled button's inherited
    // white foreground against the card's amber/orange accent background
    // used to measure ~3.08:1 — below WCAG AA's 4.5:1 minimum for
    // normal-size text. Pins the real, resolved (widget style merged with
    // the app's own FilledButtonTheme, exactly as ButtonStyleButton itself
    // resolves it) colors' contrast, not a hard-coded hex, so a future
    // theme or button-style change that quietly regresses this is caught
    // here rather than only by a design review.
    'monthly primary CTA (enabled) meets WCAG AA text contrast (>=4.5:1)',
    (tester) async {
      await tester.pumpWidget(
        host(
          const PublicDemoMonthlyPrimaryCtaSection(
            action: PublicDemoMonthlyPrimaryCtaModel(
              label: '4月を終了して5月へ',
              description: '今月の対応を終えたら、月末処理へ進みます。',
              enabled: true,
              onPressed: _noOp,
            ),
          ),
        ),
      );

      final buttonFinder = find.byKey(
        const Key('public-demo-monthly-primary-cta'),
      );
      final button = tester.widget<FilledButton>(buttonFinder);
      final theme = Theme.of(tester.element(buttonFinder));
      // The same precedence ButtonStyleButton itself resolves with: the
      // widget's own style (only backgroundColor/minimumSize/padding are
      // set — see PublicDemoMonthlyPrimaryCtaSection) wins per-property,
      // falling back to the ambient FilledButtonTheme (SesTheme's own
      // `foregroundColor: Colors.white`) for whatever it leaves null.
      final effectiveStyle =
          button.style?.merge(theme.filledButtonTheme.style) ??
          theme.filledButtonTheme.style;
      const enabled = <WidgetState>{};
      final background = effectiveStyle!.backgroundColor!.resolve(enabled)!;
      final foreground = effectiveStyle.foregroundColor!.resolve(enabled)!;

      final ratio = _contrastRatio(background, foreground);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'background=$background foreground=$foreground ratio=$ratio '
            'falls short of WCAG AA (4.5:1) for normal-size button text',
      );
    },
  );

  for (final width in [360.0, 390.0]) {
    testWidgets(
      'all presentation sections fit at ${width.toInt()}px with increased text scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          host(
            Column(
              children: [
                PublicDemoImportantTasksSection(
                  items: _tasks(onSalesPressed: _noOp, onFinancePressed: _noOp),
                ),
                const PublicDemoFinanceSummarySection(
                  summary: PublicDemoFinanceSummaryModel(
                    payroll: 600000,
                    fixedCosts: 50000,
                  ),
                ),
                const PublicDemoMonthlyPrimaryCtaSection(
                  action: PublicDemoMonthlyPrimaryCtaModel(
                    label: '月末処理を完了する',
                    description: '次の月へ進む前に確認してください。',
                    enabled: true,
                    onPressed: _noOp,
                  ),
                ),
              ],
            ),
            scale: 1.4,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'monthly primary CTA is in the initial ${width.toInt()}px viewport',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          host(
            const PublicDemoMonthlyPrimaryCtaSection(
              action: PublicDemoMonthlyPrimaryCtaModel(
                label: '月末処理を完了する',
                description: '次の月へ進む前に確認してください。',
                enabled: true,
                onPressed: _noOp,
              ),
            ),
          ),
        );

        final cta = find.byKey(const Key('public-demo-monthly-primary-cta'));
        expect(cta, findsOneWidget);
        expect(tester.getBottomRight(cta).dy, lessThanOrEqualTo(800));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _noOp() {}
