/// Central registry of bundled UI image asset paths — the S.E.S. UI asset
/// import (characters/events/locations crops from the UI material design
/// image; see pubspec.yaml's `assets:` section and README under
/// assets/images/ for provenance). Screens should reference these
/// constants instead of writing `'assets/images/...'` string literals
/// directly, so a renamed or moved file only needs updating here.
///
/// Scope note: this is asset-path bookkeeping only. Nothing here wires an
/// image into a screen, assigns a portrait to an [Applicant]/[Engineer],
/// or touches save schema — no `portraitId` field exists yet, and none is
/// added by this file.
///
/// 画像付きイベントモーダル Phase 1 wired 4 of the 5 event constants below into
/// `FoundingEventDialog`/`showFoundingEventDialog`
/// (lib/ui/widgets/founding_dialogs.dart) for the events that clearly match
/// one — see that file for the mapping. [eventSystemIncident] stays
/// registered-but-unused: no システム障害 event exists in the game yet, so
/// wiring it to a dialog would mean inventing a new event, out of scope for
/// a presentation-layer PR. Character/location wiring is still planned for
/// a later PR; those 12 constants simply make the bundled images loadable
/// and give call sites a stable name to use once that wiring lands.
class AssetPaths {
  const AssetPaths._();

  static const String _charactersDir = 'assets/images/characters';
  static const String _eventsDir = 'assets/images/events';
  static const String _locationsDir = 'assets/images/locations';

  // Characters (8) — portrait crops for sales/recruiter/client-side and
  // engineer/applicant personas.
  static const String salesMale = '$_charactersDir/sales_male.jpg';
  static const String salesFemale = '$_charactersDir/sales_female.jpg';
  static const String clientContactPerson = '$_charactersDir/client_contact_person.jpg';
  static const String recruiter = '$_charactersDir/recruiter.jpg';
  static const String engineerJunior = '$_charactersDir/engineer_junior.jpg';
  static const String engineerMidlevel = '$_charactersDir/engineer_midlevel.jpg';
  static const String engineerVeteran = '$_charactersDir/engineer_veteran.jpg';
  static const String applicantEngineer = '$_charactersDir/applicant_engineer.jpg';

  // Events (5) — wired into the image-backed event modal
  // (lib/ui/widgets/founding_dialogs.dart) by 画像付きイベントモーダル
  // Phase 1, except eventSystemIncident (no matching event exists yet —
  // reserved for when one does).
  static const String eventCompanyManagement = '$_eventsDir/company_management.jpg';
  static const String eventClientInterview = '$_eventsDir/client_interview.jpg';
  static const String eventClientContact = '$_eventsDir/client_contact.jpg';
  static const String eventRecruitmentApplication = '$_eventsDir/recruitment_application.jpg';
  static const String eventSystemIncident = '$_eventsDir/system_incident.jpg';

  // Locations (4) — for future office/meeting/night-trouble backgrounds.
  static const String locationOfficeDay = '$_locationsDir/office_day.jpg';
  static const String locationMeetingRoom = '$_locationsDir/meeting_room.jpg';
  static const String locationOfficeNight = '$_locationsDir/office_night.jpg';
  static const String locationCafeMeeting = '$_locationsDir/cafe_meeting.jpg';

  /// All 17 paths, for tests/tooling that want to iterate every bundled
  /// image (e.g. an "every registered asset actually loads" check)
  /// without hand-maintaining a second list.
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
    locationOfficeDay,
    locationMeetingRoom,
    locationOfficeNight,
    locationCafeMeeting,
  ];
}
