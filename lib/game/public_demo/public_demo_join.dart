import 'public_demo_recruitment.dart';

/// The single sanctioned entry point for joining a Public Demo 0.1 applicant
/// (WORKFLOW-STATE-1 §12).
///
/// The caller supplies only identity and intent — [applicantId]/[week] — and
/// never a salary: [PublicDemoApplicant.join] resolves salary entirely from
/// the applicant's own authoritative [PublicDemoBindingOffer], so an
/// arbitrary caller-supplied salary is not just rejected, it is structurally
/// impossible (there is no parameter for it). Joining without a binding
/// offer, or joining twice, are both rejected explicitly below rather than
/// silently no-op'd, so callers can tell the difference.
class PublicDemoJoinTransaction {
  const PublicDemoJoinTransaction();

  PublicDemoJoinResult join({
    required PublicDemoApplicant applicant,
    required int week,
  }) {
    if (applicant.hasJoined) {
      return PublicDemoJoinResult._(
        applicant: applicant,
        status: PublicDemoJoinStatus.alreadyJoined,
      );
    }
    if (!applicant.hasBindingOffer) {
      return PublicDemoJoinResult._(
        applicant: applicant,
        status: PublicDemoJoinStatus.noBindingOffer,
      );
    }
    if (applicant.stage == PublicDemoApplicantStage.offerDeclined) {
      return PublicDemoJoinResult._(
        applicant: applicant,
        status: PublicDemoJoinStatus.notEligible,
      );
    }
    return PublicDemoJoinResult._(
      applicant: applicant.join(week: week),
      status: PublicDemoJoinStatus.joined,
    );
  }

  /// Joins every applicant in [applicants] whose id is in [applicantIds],
  /// each independently (one applicant's rejection never affects another's).
  List<PublicDemoJoinResult> joinAll({
    required Iterable<PublicDemoApplicant> applicants,
    required Set<String> applicantIds,
    required int week,
  }) => [
    for (final applicant in applicants)
      if (applicantIds.contains(applicant.id))
        join(applicant: applicant, week: week),
  ];
}

class PublicDemoJoinResult {
  const PublicDemoJoinResult._({required this.applicant, required this.status});

  final PublicDemoApplicant applicant;
  final PublicDemoJoinStatus status;

  bool get isJoined => status == PublicDemoJoinStatus.joined;
}

enum PublicDemoJoinStatus { joined, alreadyJoined, noBindingOffer, notEligible }
