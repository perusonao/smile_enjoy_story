// CORE-GAMEPLAY Phase 2 (seeded recruitment): visual/overflow coverage for
// the Sales/Recruitment tab showing genuinely seed-varied candidates via
// PublicDemoSeededRecruitmentGenerator. Also saves the required
// 360x800/390x844 screenshots to docs/reports/screenshots/ so the Phase 2
// result report can show real candidate-to-candidate variety.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
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
final _screenshotKey = GlobalKey();

/// Reaches May with `count` seeded engineer-medium candidates already
/// generated for the given [runSeed] -- exercises the exact same
/// `PublicDemoAggregate.recruit` production path every real playthrough
/// uses, just with a fixed seed for a reproducible screenshot/assertion.
PublicDemoAggregate mayWithSeededEngineerCandidates(int runSeed) {
  final game = PublicDemoAggregate.initial(
    runSeed: runSeed,
  ).closeApril(monthlyExpenses: _expense);
  final result = game.recruit(PublicDemoRecruitmentMedium.engineer);
  if (!result.isSuccess) {
    throw StateError('fixture sanity: engineer medium must succeed in May');
  }
  return result.aggregate!;
}

Future<void> _pumpSalesTabWithBoundary(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  required Size size,
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
        child: RepaintBoundary(
          key: _screenshotKey,
          child: PublicDemo01PlaceholderScreen(
            saveService: _FixedSaveService(aggregate),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.sales);
  // Scroll the last seeded candidate into view so the capture below
  // reliably shows it even on a phone-sized viewport.
  await tester.ensureVisible(
    find.text(aggregate.workflow.applicants.last.name),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveScreenshot(WidgetTester tester, String fileName) async {
  // Force at least one more real, fully-settled frame right before capture
  // -- pumpAndSettle alone was observed to sometimes leave the previous
  // fixture's raster cached on the same RepaintBoundary layer when this
  // helper is called back-to-back for two different fixtures.
  await tester.pump();
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_screenshotKey),
  );
  // RenderRepaintBoundary.toImage() rasterizes on a real engine thread and
  // never resolves inside flutter_test's FakeAsync zone -- must run outside
  // it via tester.runAsync (a well-known flutter_test requirement for any
  // real image capture), or the test hangs forever.
  final bytes = await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  });
  final dir = Directory('docs/reports/screenshots');
  dir.createSync(recursive: true);
  File('${dir.path}/$fileName').writeAsBytesSync(bytes!);
}

void main() {
  group('seeded recruitment candidates render distinctly, no overflow', () {
    for (final size in const [Size(360, 800), Size(390, 844)]) {
      for (final textScale in [1.3, 2.0]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} / textScale '
            '$textScale: two seeded engineer candidates, no overflow', (
          tester,
        ) async {
          await _pumpSalesTabWithBoundary(
            tester,
            mayWithSeededEngineerCandidates(2024),
            size: size,
            textScale: textScale,
          );
          expect(tester.takeException(), isNull);

          for (final element in find.textContaining('歳').evaluate()) {
            final rect = tester.getRect(find.byWidget(element.widget));
            expect(rect.left, greaterThanOrEqualTo(0.0));
            expect(rect.right, lessThanOrEqualTo(size.width));
          }
        });
      }
    }
  });

  group('screenshots: candidate-to-candidate + seed-to-seed variety', () {
    // One testWidgets per (seed, size) combination -- each gets a fully
    // fresh widget tree/binding teardown between them, so there is no risk
    // of a later pumpWidget call within the same test reusing a previous
    // PublicDemo01PlaceholderScreen State (and its already-loaded aggregate)
    // instead of genuinely reloading the new fixture.
    for (final seedEntry in const {'seedA': 2024, 'seedB': 999999}.entries) {
      for (final size in const [Size(360, 800), Size(390, 844)]) {
        testWidgets('save screenshot for ${seedEntry.key} at '
            '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          await _pumpSalesTabWithBoundary(
            tester,
            mayWithSeededEngineerCandidates(seedEntry.value),
            size: size,
          );
          await _saveScreenshot(
            tester,
            'ses-core-gameplay-phase2-recruitment-${seedEntry.key}-'
            '${size.width.toInt()}x${size.height.toInt()}.png',
          );
        });
      }
    }

    testWidgets(
      'sanity: the two newly-*seeded* engineer-medium candidates are not '
      'textually identical, and differ again for a different runSeed',
      (tester) async {
        final gameA = mayWithSeededEngineerCandidates(2024);
        final seededA = gameA.workflow.applicants.toList();
        expect(seededA, hasLength(2));
        expect(seededA[0].name, isNot(seededA[1].name));
        expect(seededA[0].resumeSummary, isNot(seededA[1].resumeSummary));

        final gameB = mayWithSeededEngineerCandidates(999999);
        final seededB = gameB.workflow.applicants.toList();
        expect(
          seededA.map((a) => a.name).toList(),
          isNot(seededB.map((a) => a.name).toList()),
        );
      },
    );
  });
}
