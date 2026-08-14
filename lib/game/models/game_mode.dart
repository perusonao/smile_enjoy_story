/// Which onboarding path a playthrough started from (Playable 0.5A §3).
///
/// [beginner] drives the whole company through the scripted Founding
/// Prologue (creation → first hire → first assignment) before handing off to
/// free management. [free] skips straight to free management with every
/// system already unlocked, exactly like "自由に開始" did before 0.5A.
enum GameMode {
  beginner,
  free;

  String get jsonValue => name;

  static GameMode fromJson(String? value) => switch (value) {
    'beginner' => GameMode.beginner,
    _ => GameMode.free,
  };
}
