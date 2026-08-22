/// Recruitment media supported by Public Demo 0.1.
enum PublicDemoRecruitmentMedium {
  free,
  engineer;

  int get cost => switch (this) {
    PublicDemoRecruitmentMedium.free => 0,
    PublicDemoRecruitmentMedium.engineer => 100000,
  };

  int get applicantCount => switch (this) {
    PublicDemoRecruitmentMedium.free => 1,
    PublicDemoRecruitmentMedium.engineer => 2,
  };
}
