import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_enjoy_story/app/app_experience.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/game/persistence/save_service.dart';

void main() {
  test('Development and Public Demo saves are fully isolated', () async {
    SharedPreferences.setMockInitialValues({});
    final development = SaveService.forExperience(AppExperience.development);
    final publicDemo = SaveService.forExperience(AppExperience.publicDemo01);
    final stateA = GameEngine.newGame(seed: 101, companyName: 'Development A');
    final stateB = GameEngine.newGame(seed: 202, companyName: 'Public Demo B');

    expect(development.key, SaveService.developmentKey);
    expect(development.key, 'ses_playable_save_v1');
    expect(const SaveService().key, 'ses_playable_save_v1');
    expect(publicDemo.key, SaveService.publicDemo01Key);
    expect(publicDemo.key, 'ses_public_demo_01_save_v1');

    await development.save(stateA);
    await publicDemo.save(stateB);
    expect((await development.load())!.company.name, 'Development A');
    expect((await publicDemo.load())!.company.name, 'Public Demo B');

    await publicDemo.clear();
    expect(await publicDemo.load(), isNull);
    expect((await development.load())!.company.name, 'Development A');

    await development.clear();
    expect(await development.load(), isNull);
  });

  test('Public Demo never reads a Development-only stored save', () async {
    final developmentState = GameEngine.newGame(
      seed: 303,
      companyName: 'Development only',
    );
    SharedPreferences.setMockInitialValues({
      SaveService.developmentKey:
          '{"schemaVersion":${developmentState.schemaVersion},"seed":303}',
    });

    final publicDemo = SaveService.forExperience(AppExperience.publicDemo01);
    expect(await publicDemo.load(), isNull);
  });
}
