import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/app_experience.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/persistence/save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';

void main() {
  test('fresh Public Demo storage has no aggregate', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await const PublicDemoSaveService().load(), isNull);
  });

  test('corrupt and incompatible Public Demo storage falls back to null', () async {
    SharedPreferences.setMockInitialValues({
      PublicDemoSaveService.key: '{not json',
    });
    expect(await const PublicDemoSaveService().load(), isNull);

    SharedPreferences.setMockInitialValues({
      PublicDemoSaveService.key:
          '{"schemaVersion":2,"experience":"public-demo-01","aggregate":{}}',
    });
    expect(await const PublicDemoSaveService().load(), isNull);
  });

  test('Public Demo aggregate storage is isolated from normal GameState saves', () async {
    SharedPreferences.setMockInitialValues({});
    final development = SaveService.forExperience(AppExperience.development);
    final publicDemo = const PublicDemoSaveService();
    final normal = GameEngine.newGame(seed: 717, companyName: 'Development');
    final aggregate = PublicDemoAggregate.initial().startSkillSheetReview('eng-01');

    await development.save(normal);
    await publicDemo.save(aggregate);

    expect(PublicDemoSaveService.key, 'ses_public_demo_01_aggregate_v1');
    expect(PublicDemoSaveService.key, isNot(SaveService.developmentKey));
    expect(PublicDemoSaveService.key, isNot(SaveService.publicDemo01Key));
    expect((await development.load())!.company.name, 'Development');
    expect((await publicDemo.load())!.workflow.engineers.first.stage.name, 'skillSheet');

    await publicDemo.clear();

    expect(await publicDemo.load(), isNull);
    expect((await development.load())!.company.name, 'Development');
  });
}
