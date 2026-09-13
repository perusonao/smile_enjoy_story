/// Central registry of bundled UI image asset paths — the S.E.S. UI asset
/// import (characters/events/locations crops from the UI material design
/// image; see pubspec.yaml's `assets:` section and README under
/// assets/images/ for provenance). Screens should reference these
/// constants instead of writing `'assets/images/...'` string literals
/// directly, so a renamed or moved file only needs updating here.
class AssetPaths {
  const AssetPaths._();

  static const String _charactersDir = 'assets/images/characters';
  static const String _eventsDir = 'assets/images/events';
  static const String _locationsDir = 'assets/images/locations';
  static const String _navigatorDir = 'assets/images/navigator';

  static const String salesMale = '$_charactersDir/sales_male.jpg';
  static const String salesFemale = '$_charactersDir/sales_female.jpg';
  static const String clientContactPerson =
      '$_charactersDir/client_contact_person.jpg';
  static const String recruiter = '$_charactersDir/recruiter.jpg';
  static const String engineerJunior = '$_charactersDir/engineer_junior.jpg';
  static const String engineerMidlevel =
      '$_charactersDir/engineer_midlevel.jpg';
  static const String engineerVeteran = '$_charactersDir/engineer_veteran.jpg';
  static const String applicantEngineer =
      '$_charactersDir/applicant_engineer.jpg';

  static const String eventCompanyManagement =
      '$_eventsDir/company_management.jpg';

  /// The two-businessmen handshake photo. FIRST-FUN-QUARTER-VISUAL-POLISH:
  /// no longer referenced by any interview screen — every 上位会社面談/
  /// 客先面談 surface now shows [locationMeetingRoom]/[locationCafeMeeting]
  /// instead, so this same photo could be freed up as [eventOrderDecision]'s
  /// replacement image (a handshake reads as "a deal was made" — a natural
  /// fit for 受注成功 — and is a strictly better, and now unique, use of the
  /// asset than being the one interchangeable photo behind every interview
  /// step). Kept as its own named constant since it is still a distinct,
  /// valid piece of art in the catalogue, independent of which event(s)
  /// reference it.
  static const String eventClientInterview = '$_eventsDir/client_interview.jpg';
  static const String eventClientContact = '$_eventsDir/client_contact.jpg';
  static const String eventRecruitmentApplication =
      '$_eventsDir/recruitment_application.jpg';
  static const String eventSystemIncident = '$_eventsDir/system_incident.jpg';

  /// FIRST-FUN-QUARTER-VISUAL-POLISH P1-B: the original `order_decision.jpg`
  /// this constant pointed to is corrupt on disk (a truncated JPEG missing
  /// its SOF marker — confirmed with a manual marker walk and with Pillow's
  /// decoder, both of which fail to identify it as an image at all).
  /// `Image.asset` therefore never decoded it and every "受注成功" moment
  /// (`_recordEngineerOrder`/`_recordOfferCandidateOrder`/
  /// `_recordApplicantJuneOrder` in `public_demo_01_placeholder_screen.dart`)
  /// silently fell back to `GameEventModal`'s generic bell-icon
  /// `errorBuilder` — the single biggest visual gap this audit found, and
  /// invisible to `test/ui/asset_paths_test.dart`'s own smoke test, which
  /// only checks the bundled bytes are non-empty, never that they decode.
  /// Repointed to reuse [eventClientInterview]'s handshake photo (see that
  /// constant's own doc for why it was free to reuse) rather than
  /// fabricating a new placeholder image; the broken source file has been
  /// deleted from `assets/images/events/`.
  static const String eventOrderDecision = '$_eventsDir/client_interview.jpg';
  static const String eventFirstAssignment = '$_eventsDir/first_assignment.jpg';

  static const String locationOfficeDay = '$_locationsDir/office_day.jpg';

  /// FIRST-FUN-QUARTER-VISUAL-POLISH P1-A: 上位会社面談 (the formal
  /// negotiation with the prime/partner company one pipeline stage before
  /// the end client) — a boardroom conference table, distinct from
  /// [locationCafeMeeting]'s more relaxed client-facing setting below.
  static const String locationMeetingRoom = '$_locationsDir/meeting_room.jpg';
  static const String locationOfficeNight = '$_locationsDir/office_night.jpg';

  /// FIRST-FUN-QUARTER-VISUAL-POLISH P1-A: 客先面談 (the interview with the
  /// actual end client) — previously indistinguishable from 上位会社面談,
  /// which shared the exact same [eventClientInterview] handshake photo
  /// regardless of interview type. Every interview surface (the legacy
  /// `PublicDemoInterviewResultDialog` and the interactive
  /// `PublicDemoProjectInterviewDialog`) now picks between this and
  /// [locationMeetingRoom] by `PublicDemoInterviewType`, so the two events
  /// read as visually distinct at a glance.
  static const String locationCafeMeeting = '$_locationsDir/cafe_meeting.jpg';

  /// HOME-COMPACT-1B.3 — a dedicated wide-aspect office banner for the
  /// compact "社員の様子" summary (`HomeOfficeStageSection`), replacing
  /// [locationOfficeDay] as that section's default background. Sourced from
  /// `SES_HOME_COMPACT_Assets_v1.zip`'s
  /// `location_office_day_home_banner_v1.png`, resized/re-encoded to match
  /// this catalogue's existing small-file convention. No text is baked into
  /// the image — every label the section shows is drawn by Flutter on top.
  static const String locationOfficeDayHomeBanner =
      '$_locationsDir/office_day_home_banner.jpg';

  /// NAVIGATOR-1A — 佐倉 ひより's normal-expression portrait, cropped from
  /// the character reference for use at small circular sizes. Resolved
  /// through `HomeNavigatorIdentity.portraitAssetFor`, never referenced as
  /// a literal, and never stored in a domain model or a save file.
  static const String navigatorNormal = '$_navigatorDir/navigator_normal.webp';
  static const String navigatorCaution =
      '$_navigatorDir/navigator_caution.webp';

  /// HOME-COMPACT-1B.3 — an alternate normal-expression portrait sized and
  /// cropped specifically for HOME's compact circular avatar
  /// (`char_hiyori_home_compact_v1.png` in `SES_HOME_COMPACT_Assets_v1.zip`,
  /// resized/re-encoded to match this catalogue's existing convention).
  /// Used only for [NavigatorExpression.normal] — the distinct
  /// [navigatorCaution] artwork is untouched, so the caution/normal visual
  /// distinction the cash-advice integration relies on is preserved.
  static const String navigatorHomeCompact =
      '$_navigatorDir/navigator_home_compact.webp';

  static const List<String> all = [
    salesMale,
    salesFemale,
    clientContactPerson,
    recruiter,
    engineerJunior,
    engineerMidlevel,
    engineerVeteran,
    applicantEngineer,
    eventCompanyManagement,
    eventClientInterview,
    eventClientContact,
    eventRecruitmentApplication,
    eventSystemIncident,
    eventOrderDecision,
    eventFirstAssignment,
    locationOfficeDay,
    locationOfficeDayHomeBanner,
    locationMeetingRoom,
    locationOfficeNight,
    locationCafeMeeting,
    navigatorNormal,
    navigatorHomeCompact,
    navigatorCaution,
  ];
}
