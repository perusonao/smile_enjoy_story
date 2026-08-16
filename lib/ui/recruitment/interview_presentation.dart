import 'package:flutter/material.dart';

import '../../game/game.dart';

/// Presentation-only helpers for the recruitment interview screen (Playable
/// 0.4C.3 §4, §6). Nothing here changes interview judgment logic — every
/// function is a pure re-labelling of values [RecruitmentInterviewEngine]
/// already computed, so the player reads "観察タグ" and "応募者の反応"
/// instead of raw confidence/impression numbers, without the interview
/// becoming easier or harder to read for the underlying mechanic.

/// An observation framed as "what did I notice", not "pass/fail" — §4:
/// never a plain green=correct/red=wrong signal.
enum ObservationTag { goodImpression, digDeeper, concerning, stillUnsure }

class ObservationTagStyle {
  const ObservationTagStyle({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
}

const _observationTagStyles = <ObservationTag, ObservationTagStyle>{
  ObservationTag.goodImpression: ObservationTagStyle(label: '好印象', icon: Icons.thumb_up_outlined, color: Color(0xFF2E7D32)),
  ObservationTag.digDeeper: ObservationTagStyle(label: '深掘りしたい', icon: Icons.search, color: Color(0xFF1565C0)),
  ObservationTag.concerning: ObservationTagStyle(label: '気になる', icon: Icons.error_outline, color: Color(0xFFE65100)),
  ObservationTag.stillUnsure: ObservationTagStyle(label: 'まだ不確か', icon: Icons.help_outline, color: Colors.blueGrey),
};

ObservationTagStyle observationTagStyle(ObservationTag tag) => _observationTagStyles[tag]!;

/// Derives a tag from the answer's own confidence/specificity gap and the
/// engine's [InterviewObservation.confidence] bucket — the same signals the
/// existing free-text observation already speaks from (see
/// `RecruitmentInterviewEngine.observe`), just surfaced as a short tag a
/// player can scan across 3 questions at a glance.
ObservationTag observationTagFor(ApplicantAnswer answer, InterviewObservation observation) {
  if (answer.confidence - answer.specificity > 28) return ObservationTag.digDeeper;
  return switch (observation.confidence) {
    ObservationConfidence.high => ObservationTag.goodImpression,
    ObservationConfidence.low => ObservationTag.concerning,
    ObservationConfidence.medium => ObservationTag.stillUnsure,
  };
}

/// Applicant reaction as a face + short phrase (Playable 0.4C.3 §6) —
/// reuses [RecruitmentInterviewEngine.impressionLabel] verbatim (so the
/// wording a player sees stays the single source of truth the engine
/// already owns) and only adds the emoji bucket on top. `companyImpression`
/// itself (a 0-100 int) is never rendered.
String applicantReactionEmoji(int companyImpression) {
  if (companyImpression <= 40) return '😟';
  if (companyImpression <= 60) return '😐';
  return '🙂';
}

/// What kind of understanding each question tends to surface — flavor text
/// shown on the question card (Playable 0.4C.3 §5) so a player picks a
/// question for a reason, without exposing the internal success-rate math
/// behind it. Order mirrors `RecruitmentInterviewEngine.generateAnswer`'s
/// dominant signal for each category.
const questionInfoHints = <InterviewQuestionCategory, List<String>>{
  InterviewQuestionCategory.technical: ['技術情報：高', '人物情報：低'],
  InterviewQuestionCategory.career: ['経歴情報：高', '人物情報：中'],
  InterviewQuestionCategory.reasonForChange: ['定着情報：高', '人物情報：中'],
  InterviewQuestionCategory.teamwork: ['チーム適性：高', '人物情報：中'],
  InterviewQuestionCategory.futureCareer: ['成長意欲：高', '人物情報：中'],
  InterviewQuestionCategory.workStyle: ['働き方傾向：高', '人物情報：低'],
};
