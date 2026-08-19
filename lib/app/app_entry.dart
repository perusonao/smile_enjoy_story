import 'app_experience.dart';

/// Resolves the app-level experience without introducing a Navigator 2.0
/// router. Hash URLs are static-host-safe on GitHub Pages: the server still
/// receives the existing app root, while the Flutter app receives the
/// fragment locally.
AppExperience resolveAppExperience(Uri uri) {
  final fragmentPath = uri.fragment.split('?').first.replaceFirst(RegExp(r'^/'), '');
  return switch (fragmentPath) {
    'public-demo-01' => AppExperience.publicDemo01,
    _ => AppExperience.development,
  };
}
