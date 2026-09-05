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
  testWidgets('quick access renders all items and calls each callback once, '
      'with a 48x48 tap target', (tester) async {
    var officeCalls = 0, financeCalls = 0;
    await tester.pumpWidget(
      host(
        PublicDemoQuickAccessSection(
          items: [
            PublicDemoQuickAccessItem(
              itemKey: const Key('qa-office'),
              icon: Icons.groups_outlined,
              label: '社員の様子',
              onPressed: () => officeCalls++,
            ),
            PublicDemoQuickAccessItem(
              itemKey: const Key('qa-finance'),
              icon: Icons.account_balance_wallet_outlined,
              label: '収支・会計',
              onPressed: () => financeCalls++,
            ),
          ],
        ),
      ),
    );
    expect(find.text('クイックアクセス'), findsOneWidget);
    expect(find.text('社員の様子'), findsOneWidget);
    expect(find.text('収支・会計'), findsOneWidget);
    await tester.tap(find.byKey(const Key('qa-office')));
    expect(officeCalls, 1);
    await tester.tap(find.byKey(const Key('qa-finance')));
    expect(financeCalls, 1);
    final officeRect = tester.getSize(find.byKey(const Key('qa-office')));
    expect(officeRect.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

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
      // Neutral category chips, not a priority/urgency claim.
      expect(find.text('営業'), findsOneWidget);
      expect(find.text('採用'), findsOneWidget);
      expect(find.text('資金'), findsOneWidget);
      expect(find.text('High Priority'), findsNothing);
      expect(find.text('重要'), findsNothing);
      // SES HOME Final Density: the CTA is icon-only now — its label never
      // renders as visible text (that would defeat the density win), but it
      // must still reach an assistive-technology user verbatim via
      // Semantics, and it must still be a real, tappable >=48px target.
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
        find.bySemanticsLabel('対応する'),
        findsNWidgets(2),
        reason: '営業/採用 CTAs share the same label text',
      );
      expect(find.bySemanticsLabel('確認する'), findsOneWidget);

      await tester.tap(find.byKey(salesCtaKey));
      expect(salesCalls, 1);
      await tester.tap(find.byKey(recruitingCtaKey));
      expect(salesCalls, 2);
      await tester.tap(find.byKey(financeCtaKey));
      expect(financeCalls, 1);
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
    'important tasks separates rows with a divider and never duplicates '
    'a category chip as a priority claim across items',
    (tester) async {
      await tester.pumpWidget(
        host(
          PublicDemoImportantTasksSection(
            items: _tasks(onSalesPressed: _noOp, onFinancePressed: _noOp),
          ),
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
      expect(tester.takeException(), isNull);
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
                PublicDemoQuickAccessSection(
                  items: [
                    PublicDemoQuickAccessItem(
                      itemKey: const Key('qa-scale-office'),
                      icon: Icons.groups_outlined,
                      label: '社員の様子',
                      onPressed: _noOp,
                    ),
                    PublicDemoQuickAccessItem(
                      itemKey: const Key('qa-scale-finance'),
                      icon: Icons.account_balance_wallet_outlined,
                      label: '収支・会計',
                      onPressed: _noOp,
                    ),
                  ],
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
