import 'package:smile_enjoy_story/ui/asset_paths.dart';

/// Pure presentation mapping for image-backed event-modal categories.
///
/// Categories are UI labels, not game state. Keeping their asset selection
/// here prevents presentation assets from becoming gameplay or save data.
class EventImageMapper {
  const EventImageMapper._();

  static String? imageAssetForCategory(String? category) => switch (category) {
    '取引先からの連絡' => AssetPaths.eventClientContact,
    '案件面談' => AssetPaths.eventClientInterview,
    '採用・応募' => AssetPaths.eventRecruitmentApplication,
    '会社経営' => AssetPaths.eventCompanyManagement,
    _ => null,
  };
}
