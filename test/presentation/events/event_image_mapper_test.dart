import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/presentation/events/event_image_mapper.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';

void main() {
  group('EventImageMapper.imageAssetForCategory', () {
    const mappings = <String, String>{
      '取引先からの連絡': AssetPaths.eventClientContact,
      '案件面談': AssetPaths.eventClientInterview,
      '採用・応募': AssetPaths.eventRecruitmentApplication,
      '会社経営': AssetPaths.eventCompanyManagement,
    };

    for (final entry in mappings.entries) {
      test('${entry.key} maps to its event image asset', () {
        expect(EventImageMapper.imageAssetForCategory(entry.key), entry.value);
      });
    }

    test('returns null for an unknown category', () {
      expect(EventImageMapper.imageAssetForCategory('未知のカテゴリ'), isNull);
    });

    test('returns null for a null category', () {
      expect(EventImageMapper.imageAssetForCategory(null), isNull);
    });

    test('is deterministic across repeated calls', () {
      for (final entry in mappings.entries) {
        final first = EventImageMapper.imageAssetForCategory(entry.key);
        expect(
          List.generate(
            10,
            (_) => EventImageMapper.imageAssetForCategory(entry.key),
          ),
          everyElement(first),
        );
      }
    });

    test('does not map the HOME-3 dashboard monthly category', () {
      expect(EventImageMapper.imageAssetForCategory('月次'), isNull);
    });
  });
}
