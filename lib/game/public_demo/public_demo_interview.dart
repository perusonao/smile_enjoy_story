enum PublicDemoInterviewType { partner, client }

class PublicDemoInterviewProfile {
  const PublicDemoInterviewProfile({
    required this.skillFit,
    required this.humanity,
    required this.morale,
    required this.clientTrust,
  });

  final int skillFit;
  final int humanity;
  final int morale;
  final int clientTrust;
}

class PublicDemoInterviewResult {
  const PublicDemoInterviewResult({required this.score, required this.passed});

  final int score;
  final bool passed;
}

class PublicDemoInterviewEvaluator {
  const PublicDemoInterviewEvaluator._();

  static PublicDemoInterviewResult evaluate({
    required PublicDemoInterviewType type,
    required PublicDemoInterviewProfile profile,
    int? actualCapability,
  }) {
    final skillFit = actualCapability ?? profile.skillFit;
    final score = switch (type) {
      PublicDemoInterviewType.partner =>
        (skillFit * 45 +
                profile.humanity * 25 +
                profile.morale * 15 +
                profile.clientTrust * 15) ~/
            100,
      PublicDemoInterviewType.client =>
        (skillFit * 50 +
                profile.humanity * 20 +
                profile.morale * 10 +
                profile.clientTrust * 20) ~/
            100,
    };
    return PublicDemoInterviewResult(score: score, passed: score >= 60);
  }
}
