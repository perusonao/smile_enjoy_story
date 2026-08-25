// HOME-UI-1B: image asset integration for the office stage section.
//
// `OfficeStageSection` renders a bundled office background image plus up to
// 3 employee visual slots. Employee data is a plain external input
// (`EmployeeStageDisplay`) — this section holds no employee/assignment
// authority and does not read Domain/Workflow state, so these tests only
// exercise the widget's own rendering/fallback behavior with data supplied
// directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/presentation/home/models/employee_stage_display.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/office_stage_section.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('office background image renders when configured', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const OfficeStageSection());

    final imageFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              AssetPaths.locationOfficeDay,
    );
    expect(imageFinder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'office background falls back cleanly when no asset is configured',
    (WidgetTester tester) async {
      await _pump(tester, const OfficeStageSection(officeImageAssetPath: null));

      expect(find.byType(Image), findsNothing);
      expect(find.byType(OfficeStageSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'office background falls back cleanly when the configured asset fails to load',
    (WidgetTester tester) async {
      await _pump(
        tester,
        const OfficeStageSection(
          officeImageAssetPath: 'assets/images/locations/does_not_exist.jpg',
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(OfficeStageSection), findsOneWidget);
    },
  );

  testWidgets('renders 3 empty employee slots when no employees are supplied', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const OfficeStageSection());

    expect(
      find.descendant(
        of: find.byType(OfficeStageSection),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('renders a supplied employee image and label', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const OfficeStageSection(
        employees: [
          EmployeeStageDisplay(
            name: 'エンジニア太郎',
            imageAssetPath: AssetPaths.engineerJunior,
          ),
        ],
      ),
    );

    expect(find.text('エンジニア太郎'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OfficeStageSection),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsNWidgets(2), // remaining 2 slots stay empty placeholders
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to placeholder icon when an employee has no image', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const OfficeStageSection(employees: [EmployeeStageDisplay(name: '総務花子')]),
    );

    expect(find.text('総務花子'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OfficeStageSection),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsNWidgets(3), // the nameless slot also falls back to the icon
    );
  });

  testWidgets(
    'falls back to placeholder icon when a supplied employee image fails to load',
    (WidgetTester tester) async {
      await _pump(
        tester,
        const OfficeStageSection(
          employees: [
            EmployeeStageDisplay(
              name: '欠損太郎',
              imageAssetPath: 'assets/images/characters/does_not_exist.jpg',
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('欠損太郎'), findsOneWidget);
    },
  );

  testWidgets(
    'renders at most 3 visual slots even when more employees are supplied',
    (WidgetTester tester) async {
      await _pump(
        tester,
        const OfficeStageSection(
          employees: [
            EmployeeStageDisplay(
              name: '社員1',
              imageAssetPath: AssetPaths.engineerJunior,
            ),
            EmployeeStageDisplay(
              name: '社員2',
              imageAssetPath: AssetPaths.engineerMidlevel,
            ),
            EmployeeStageDisplay(
              name: '社員3',
              imageAssetPath: AssetPaths.engineerVeteran,
            ),
            EmployeeStageDisplay(
              name: '社員4',
              imageAssetPath: AssetPaths.salesMale,
            ),
          ],
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is KeyedSubtree &&
              widget.key.toString().contains('office-stage-slot-'),
        ),
        findsNWidgets(3),
      );
      expect(find.text('社員4'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('does not overflow at 360x800 with 3 employees supplied', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      const OfficeStageSection(
        employees: [
          EmployeeStageDisplay(
            name: '長い名前のエンジニア太郎さん',
            imageAssetPath: AssetPaths.engineerJunior,
          ),
          EmployeeStageDisplay(
            name: '社員2',
            imageAssetPath: AssetPaths.engineerMidlevel,
          ),
          EmployeeStageDisplay(
            name: '社員3',
            imageAssetPath: AssetPaths.engineerVeteran,
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow at 390x844 with 3 employees supplied', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      const OfficeStageSection(
        employees: [
          EmployeeStageDisplay(
            name: '長い名前のエンジニア太郎さん',
            imageAssetPath: AssetPaths.engineerJunior,
          ),
          EmployeeStageDisplay(
            name: '社員2',
            imageAssetPath: AssetPaths.engineerMidlevel,
          ),
          EmployeeStageDisplay(
            name: '社員3',
            imageAssetPath: AssetPaths.engineerVeteran,
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
