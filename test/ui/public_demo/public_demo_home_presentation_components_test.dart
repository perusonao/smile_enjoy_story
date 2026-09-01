import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_presentation_components.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

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

void main() {
  testWidgets(
    'important events hides its empty state, renders populated events, and calls CTA once',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(const PublicDemoImportantEventsSection(events: [])),
      );
      expect(
        find.byKey(const Key('public-demo-important-events-empty')),
        findsOneWidget,
      );
      expect(find.byType(Card), findsNothing);
      final events = [
        PublicDemoImportantEventItem(
          title: '長い重要イベントのタイトルでも画面からはみ出さずに内容を確認できます',
          summary: '対応内容の説明も十分に長い場合がありますが、プレゼンテーションコンポーネントは表示だけを行います。',
          category: '優先',
          ctaLabel: '確認する',
          onPressed: () => calls++,
          isHighPriority: true,
        ),
        const PublicDemoImportantEventItem(
          title: '月末処理',
          summary: '今月の処理を確認してください。',
          category: '経営',
          ctaLabel: '開く',
          onPressed: _noOp,
        ),
      ];
      await tester.pumpWidget(
        host(PublicDemoImportantEventsSection(events: events)),
      );
      expect(
        find.byKey(const Key('public-demo-important-events')),
        findsOneWidget,
      );
      expect(find.text('重要イベント'), findsOneWidget);
      expect(find.text('優先'), findsOneWidget);
      expect(find.text('月末処理'), findsOneWidget);
      await tester.tap(find.text('確認する'));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'finance summary renders payroll and fixed costs as large numeric '
    'values, and no longer carries cash/revenue/warning (HOME UI Phase 1 '
    'trimmed those as KPI/cash-shortage-card duplicates)',
    (tester) async {
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
      expect(find.text('¥1,234,567,890'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.startsWith('資金警告') ?? false),
        ),
        findsNothing,
      );
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
                PublicDemoImportantEventsSection(
                  events: [
                    PublicDemoImportantEventItem(
                      title: '長いイベント名',
                      summary: '長い説明文を表示しても安全です。',
                      category: '重要',
                      ctaLabel: '詳細を確認',
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
