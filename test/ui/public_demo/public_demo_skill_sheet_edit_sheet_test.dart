import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/ui/public_demo/public_demo_skill_sheet_edit_sheet.dart';

/// SES First Fun Quarter Mission Phase 3 (SkillSheet Editing): widget
/// coverage for [PublicDemoSkillSheetEditSheet] in isolation — pumped
/// directly with fixed inputs, mirroring
/// `public_demo_mission_screen_test.dart`'s own "pump the presentation
/// widget with plain data, never a live aggregate" convention.
void main() {
  Future<int?> openSheet(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1.0,
    int actualMonths = 30,
    int initialDisplayedMonths = 30,
    int maxDisplayedMonths = 66,
  }) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await PublicDemoSkillSheetEditSheet.show(
                  context,
                  engineerId: 'eng-01',
                  engineerName: '佐藤 健',
                  languageLabel: 'Java',
                  actualMonths: actualMonths,
                  initialDisplayedMonths: initialDisplayedMonths,
                  maxDisplayedMonths: maxDisplayedMonths,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows actual experience and the initial displayed value', (tester) async {
    await openSheet(tester, actualMonths: 30, initialDisplayedMonths: 30);

    expect(
      find.byKey(const Key('public-demo-skill-sheet-edit-eng-01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('public-demo-skill-sheet-edit-actual-eng-01')),
      findsOneWidget,
    );
    expect(find.text('実務経験：2 年 6 ヶ月'), findsOneWidget);
    expect(
      find.byKey(const Key('public-demo-skill-sheet-edit-value-eng-01')),
      findsOneWidget,
    );
    expect(find.text('2 年 0 ヶ月'), findsOneWidget);
  });

  testWidgets(
    'increment/decrement adjust by whole years and clamp at 0 and the max',
    (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await PublicDemoSkillSheetEditSheet.show(
                  context,
                  engineerId: 'eng-01',
                  engineerName: '佐藤 健',
                  languageLabel: 'Java',
                  actualMonths: 0,
                  initialDisplayedMonths: 0,
                  maxDisplayedMonths: 24,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      const decrementKey = Key('public-demo-skill-sheet-edit-decrement-eng-01');
      const incrementKey = Key('public-demo-skill-sheet-edit-increment-eng-01');
      const valueKey = Key('public-demo-skill-sheet-edit-value-eng-01');

      // Already at the floor (0) — decrement must be disabled, never negative.
      expect(tester.widget<IconButton>(find.byKey(decrementKey)).onPressed, isNull);
      expect(find.text('0 年 0 ヶ月'), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(incrementKey));
        await tester.pump();
      }
      expect(find.text('2 年 0 ヶ月'), findsOneWidget);

      // maxDisplayedMonths: 24 → max 2 years — already at the ceiling.
      expect(tester.widget<IconButton>(find.byKey(incrementKey)).onPressed, isNull);

      await tester.tap(find.byKey(const Key('public-demo-skill-sheet-edit-save-eng-01')));
      await tester.pumpAndSettle();
      expect(result, 24);
      expect(find.byKey(valueKey), findsNothing);
    },
  );

  testWidgets('cancel resolves to null and never touches the draft', (tester) async {
    final result = await () async {
      int? value;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                value = await PublicDemoSkillSheetEditSheet.show(
                  context,
                  engineerId: 'eng-01',
                  engineerName: '佐藤 健',
                  languageLabel: 'Java',
                  actualMonths: 30,
                  initialDisplayedMonths: 30,
                  maxDisplayedMonths: 66,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('public-demo-skill-sheet-edit-increment-eng-01')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('public-demo-skill-sheet-edit-cancel-eng-01')),
      );
      await tester.pumpAndSettle();
      return value;
    }();
    expect(result, isNull);
  });

  group('390x844 / 360x800, TextScaler 1.0/1.3: renders without overflow', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale $textScale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await openSheet(
              tester,
              size: size,
              textScale: textScale,
              actualMonths: 30,
              initialDisplayedMonths: 42,
              maxDisplayedMonths: 66,
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
