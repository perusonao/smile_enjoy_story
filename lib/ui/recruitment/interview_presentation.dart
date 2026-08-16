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
/// shown on the question card (Playable 0.4C.3 §5, reworded Playable 0.4C.4
/// §8) so a player picks a question for a reason ("残り1問で何を聞こう？"),
/// without exposing the internal success-rate math behind it. An icon +
/// short "〜しやすい" phrase reads as a hint about *what you'll learn*, not
/// a number to optimize — deliberately never "技術情報：高" (looks like a
/// hidden stat) or a percentage. Order mirrors
/// `RecruitmentInterviewEngine.generateAnswer`'s dominant signal for each
/// category.
const questionInfoHints = <InterviewQuestionCategory, List<String>>{
  InterviewQuestionCategory.technical: ['🔍 技術情報を得やすい'],
  InterviewQuestionCategory.career: ['💼 実務での役割を把握しやすい'],
  InterviewQuestionCategory.reasonForChange: ['🏠 定着性を判断しやすい'],
  InterviewQuestionCategory.teamwork: ['👥 人柄・協調性を知りやすい'],
  InterviewQuestionCategory.futureCareer: ['🌱 成長意欲を確認しやすい'],
  InterviewQuestionCategory.workStyle: ['🏢 働き方の希望を確認しやすい'],
};

/// One of the four dimensions the interview summary's information gauge
/// (Playable 0.4C.4 §7) reports on. Deliberately coarser than the six
/// [InterviewQuestionCategory] values underneath — the player only ever
/// asks 3 of 6 questions, so collapsing to 4 player-facing dimensions keeps
/// "which ones did I actually cover" legible at a glance.
enum InfoDimension { technical, role, retention, personality }

const infoDimensionLabels = <InfoDimension, String>{
  InfoDimension.technical: '技術経験',
  InfoDimension.role: '役割経験',
  InfoDimension.retention: '定着性',
  InfoDimension.personality: '人物面',
};

/// Which [InfoDimension] each question's answer speaks to most directly —
/// asking it fills this dimension's confidence gauge to full.
const _primaryDimensionFor = <InterviewQuestionCategory, InfoDimension>{
  InterviewQuestionCategory.technical: InfoDimension.technical,
  InterviewQuestionCategory.career: InfoDimension.role,
  InterviewQuestionCategory.reasonForChange: InfoDimension.retention,
  InterviewQuestionCategory.teamwork: InfoDimension.personality,
  InterviewQuestionCategory.futureCareer: InfoDimension.role,
  InterviewQuestionCategory.workStyle: InfoDimension.retention,
};

/// The dimension each question's answer speaks to *second most* — asking it
/// only partially fills this dimension's gauge, reflecting that you learned
/// something about it incidentally, not that you asked about it directly.
const _secondaryDimensionFor = <InterviewQuestionCategory, InfoDimension>{
  InterviewQuestionCategory.technical: InfoDimension.personality,
  InterviewQuestionCategory.career: InfoDimension.personality,
  InterviewQuestionCategory.reasonForChange: InfoDimension.personality,
  InterviewQuestionCategory.teamwork: InfoDimension.role,
  InterviewQuestionCategory.futureCareer: InfoDimension.personality,
  InterviewQuestionCategory.workStyle: InfoDimension.personality,
};

/// Per-dimension read for the Information Confidence / Impression gauge
/// (Playable 0.4C.4 §7) — the two are tracked separately on purpose:
///
/// - [confidenceLevel] (0-5): *how much* was learned about this dimension —
///   full (5) once its question was asked directly, partial (3) when only
///   touched on incidentally by a different question, minimal (1) when
///   nothing about it came up at all ("情報不足", never literal zero so the
///   gauge always renders something).
/// - [impression]: *what* was learned, i.e. the same [ObservationTag] the
///   Talk Card already shows — `null` when there's no signal at all yet
///   (confidenceLevel stayed at 1), so the UI can render "不明" instead of
///   guessing a sentiment from zero data.
///
/// Neither field is a raw internal ability number — both are derived
/// entirely from what the player already asked and saw during this
/// interview.
class DimensionInfo {
  const DimensionInfo({required this.confidenceLevel, required this.impression});
  final int confidenceLevel;
  final ObservationTag? impression;
}

const int _fullConfidence = 5;
const int _partialConfidence = 3;
const int _minimalConfidence = 1;

Map<InfoDimension, DimensionInfo> computeInfoDimensions(RecruitmentInterviewSession session) {
  final confidence = {for (final d in InfoDimension.values) d: _minimalConfidence};
  final impression = <InfoDimension, ObservationTag?>{for (final d in InfoDimension.values) d: null};
  for (var i = 0; i < session.observations.length && i < session.applicantAnswers.length; i++) {
    final category = session.observations[i].category;
    final tag = observationTagFor(session.applicantAnswers[i], session.observations[i]);
    final primary = _primaryDimensionFor[category]!;
    final secondary = _secondaryDimensionFor[category]!;
    confidence[primary] = _fullConfidence;
    impression[primary] = tag;
    if (confidence[secondary]! < _partialConfidence) confidence[secondary] = _partialConfidence;
    impression[secondary] ??= tag;
  }
  return {for (final d in InfoDimension.values) d: DimensionInfo(confidenceLevel: confidence[d]!, impression: impression[d])};
}

String confidenceLabel(int level) => level >= _fullConfidence ? 'かなり把握' : level >= _partialConfidence ? 'やや把握' : '情報不足';
