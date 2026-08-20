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

  static const String salesMale = '$_charactersDir/sales_male.jpg';
  static const String salesFemale = '$_charactersDir/sales_female.jpg';
  static const String clientContactPerson = '$_charactersDir/client_contact_person.jpg';
  static const String recruiter = '$_charactersDir/recruiter.jpg';
  static const String engineerJunior = '$_charactersDir/engineer_junior.jpg';
  static const String engineerMidlevel = '$_charactersDir/engineer_midlevel.jpg';
  static const String engineerVeteran = '$_charactersDir/engineer_veteran.jpg';
  static const String applicantEngineer = '$_charactersDir/applicant_engineer.jpg';

  static const String eventCompanyManagement = '$_eventsDir/company_management.jpg';
  static const String eventClientInterview = '$_eventsDir/client_interview.jpg';
  static const String eventClientContact = '$_eventsDir/client_contact.jpg';
  static const String eventRecruitmentApplication = '$_eventsDir/recruitment_application.jpg';
  static const String eventSystemIncident = '$_eventsDir/system_incident.jpg';
  static const String eventOrderDecision = '$_eventsDir/order_decision.jpg';
  static const String eventFirstAssignment = '$_eventsDir/first_assignment.jpg';

  static const String locationOfficeDay = '$_locationsDir/office_day.jpg';
  static const String locationMeetingRoom = '$_locationsDir/meeting_room.jpg';
  static const String locationOfficeNight = '$_locationsDir/office_night.jpg';
  static const String locationCafeMeeting = '$_locationsDir/cafe_meeting.jpg';

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
    locationMeetingRoom,
    locationOfficeNight,
    locationCafeMeeting,
  ];
}
