import 'package:smile_enjoy_story/game/models/founding_progress.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';

/// UI-only event-to-image mapping.
///
/// Asset paths deliberately stay out of domain/gameplay/save models.
class EventImageMapper {
  const EventImageMapper._();

  static String? forOneTimeEvent(OneTimeEvent event) => switch (event) {
        OneTimeEvent.interviewOfferCelebration => AssetPaths.eventClientContact,
        OneTimeEvent.firstAssignmentCelebration => AssetPaths.eventFirstAssignment,
        OneTimeEvent.recruitmentUnlockCelebration => AssetPaths.eventRecruitmentApplication,
        OneTimeEvent.clientInterviewCelebration => AssetPaths.eventClientInterview,
        OneTimeEvent.recruitmentInterviewCelebration => AssetPaths.eventRecruitmentApplication,
        OneTimeEvent.welfareUnlockCelebration => AssetPaths.eventCompanyManagement,
        _ => null,
      };

  static String? forCategory(String? category) => switch (category) {
        '取引先からの連絡' => AssetPaths.eventClientContact,
        '案件面談' => AssetPaths.eventClientInterview,
        '採用・応募' => AssetPaths.eventRecruitmentApplication,
        '会社経営' => AssetPaths.eventCompanyManagement,
        _ => null,
      };
}
