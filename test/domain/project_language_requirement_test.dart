// Playable 0.2 §21 audit: verify project types with a real language
// requirement (Java業務系 / Webバックエンド / フロントエンド / PL) never come
// out "言語不問" — only Infra / テスト支援 are allowed to omit a language.

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';

void main() {
  test('javaBusiness / webBackend / frontend / pl projects always require a language', () {
    final projects = ProjectGenerator(
      seed: 99001,
      clients: sampleClients,
    ).generate(4000, baseWeek: 1);

    final byType = <ProjectType, List<Project>>{};
    for (final p in projects) {
      byType.putIfAbsent(p.type, () => []).add(p);
    }

    for (final type in [
      ProjectType.javaBusiness,
      ProjectType.webBackend,
      ProjectType.frontend,
      ProjectType.pl,
    ]) {
      final ofType = byType[type] ?? const [];
      expect(ofType, isNotEmpty, reason: 'expected at least one $type sample');
      final unspecified = ofType.where((p) => p.requiredLanguages.isEmpty);
      expect(
        unspecified,
        isEmpty,
        reason: '$type projects should always require a language, found ${unspecified.length} without one',
      );
    }
  });

  test('infrastructure and testSupport projects may legitimately have no required language', () {
    final projects = ProjectGenerator(
      seed: 99002,
      clients: sampleClients,
    ).generate(4000, baseWeek: 1);

    final infra = projects.where((p) => p.type == ProjectType.infrastructure);
    final testSupport = projects.where((p) => p.type == ProjectType.testSupport);

    // Not asserting a specific ratio — just documenting/confirming that
    // "no language" is a real, expected outcome for these two types so a
    // future balance change can catch a regression either direction.
    expect(infra.any((p) => p.requiredLanguages.isEmpty), isTrue);
    expect(testSupport.any((p) => p.requiredLanguages.isEmpty), isTrue);
  });
}
