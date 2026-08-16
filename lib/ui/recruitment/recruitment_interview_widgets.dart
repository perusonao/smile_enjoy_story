import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../game/game.dart';
import '../widgets/labels.dart';
import 'interview_presentation.dart';

/// Shared recruitment-interview presentation widgets (Playable 0.4C.3
/// §4-6) — used by both [lib/ui/recruitment/recruitment_interview_screen.dart]
/// (post-tutorial hiring) and [lib/ui/prologue/prologue_interview_screen.dart]
/// (the Founding Prologue's own hiring step for the second founder). Both
/// screens drive the exact same [RecruitmentInterviewSession] flow — a
/// player's very first interview experience is usually the Prologue's, so
/// this card/tag/reaction presentation has to live here once, not be
/// re-implemented per screen and risk drifting apart.

/// Question-count + used/available progress: a 3-box row makes "you only
/// get 3 of these 6" legible at a glance, not just from the "質問 X / 3"
/// text next to it. Adds a "残りN問" / "質問完了" sub-label (Playable
/// 0.4C.4 §9) so the countdown reads in plain words too, not just the box
/// row — important right before the last question, where "残り1問だから何
/// を確認しよう？" is the whole point of the card choice below it.
class QuestionProgress extends StatelessWidget {
  const QuestionProgress({super.key, required this.asked});
  final int asked;
  @override Widget build(BuildContext context) {
    final remaining = 3 - asked;
    final remainingLabel = remaining <= 0 ? '質問完了' : '残り$remaining問';
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              i < asked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: i < asked ? const Color(0xFF1565C0) : Colors.black26,
            ),
          ),
        const SizedBox(width: 6),
        Text('質問 ${asked + 1} / 3', style: const TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: remaining == 1 ? Colors.orange.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            remainingLabel,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: remaining == 1 ? Colors.orange.shade800 : Colors.black54),
          ),
        ),
      ],
    );
  }
}

/// Name + Avatar + brief profile + current expression as one persona header
/// (Playable 0.4C.4 §11) — a lightweight stand-in for the applicant, not
/// just a name string above a wall of text. [_PersonaAvatar] keys its color
/// off `applicant.id` only, so it stays stable across rebuilds without any
/// new persisted state; swapping it for real portrait art later only
/// touches this one widget.
class ApplicantPersonaHeader extends StatelessWidget {
  const ApplicantPersonaHeader({super.key, required this.applicant, required this.companyImpression});
  final Applicant applicant;
  final int companyImpression;

  @override
  Widget build(BuildContext context) {
    final years = (applicant.totalItExperienceMonths / 12).toStringAsFixed(1);
    final lang = languageLabels[applicant.mainLanguage] ?? applicant.mainLanguage.jsonValue;
    final type = applicantTypeLabels[applicant.type] ?? applicant.type.name;
    return Row(
      children: [
        _PersonaAvatar(seed: applicant.id, emoji: applicantReactionEmoji(companyImpression)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(applicant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('$lang / $type / 経験$years年', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonaAvatar extends StatelessWidget {
  const _PersonaAvatar({required this.seed, required this.emoji});
  final String seed;
  final String emoji;

  static const _palette = [Color(0xFF90CAF9), Color(0xFFA5D6A7), Color(0xFFFFCC80), Color(0xFFCE93D8), Color(0xFF80CBC4), Color(0xFFEF9A9A)];

  @override
  Widget build(BuildContext context) {
    final color = _palette[seed.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withValues(alpha: 0.45),
      child: Text(emoji, style: const TextStyle(fontSize: 20)),
    );
  }
}

/// A single interview-question card: category, question text, and what kind
/// of information it tends to surface — never the internal success rate or
/// hidden parameters behind it. Used cards go visibly inactive with a "済"
/// mark instead of just disappearing, so the "only 3 of 6" constraint stays
/// visible for the rest of the interview.
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.category, required this.used, required this.onTap});
  final InterviewQuestionCategory category;
  final bool used;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hints = questionInfoHints[category]!;
    return Opacity(
      opacity: used ? 0.55 : 1,
      child: Material(
        color: used ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('question-card-${category.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: used ? Colors.black12 : const Color(0xFF1565C0).withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(interviewQuestionLabels[category]!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                    ),
                    const Spacer(),
                    if (used)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 15, color: Colors.black45),
                          SizedBox(width: 3),
                          Text('済', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('「${interviewQuestionTexts[category]!}」', style: const TextStyle(fontSize: 14, height: 1.35)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [for (final hint in hints) _HintChip(text: hint)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.text});
  final String text;
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
  );
}

/// Applicant reaction: a face + a phrase pulled verbatim from
/// `RecruitmentInterviewEngine.impressionLabel` — never the raw
/// `companyImpression` number itself. The trailing 3-dot meter (Playable
/// 0.4C.4 §10) is deliberately coarse — which of 3 buckets (警戒/様子見/好
/// 印象), never a percentage — so it reinforces the phrase without smuggling
/// the underlying number back in through a progress bar.
class ReactionLine extends StatelessWidget {
  const ReactionLine({super.key, required this.companyImpression});
  final int companyImpression;
  @override Widget build(BuildContext context) {
    final emoji = applicantReactionEmoji(companyImpression);
    final label = RecruitmentInterviewEngine.impressionLabel(companyImpression);
    final bucket = companyImpression <= 40 ? 0 : companyImpression <= 60 ? 1 : 2;
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black54, fontStyle: FontStyle.italic))),
        for (var i = 0; i < 3; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(shape: BoxShape.circle, color: i <= bucket ? const Color(0xFF1565C0) : Colors.black12),
          ),
      ],
    );
  }
}

/// One Q&A exchange plus its observation tag (Playable 0.4C.3 §4).
class TalkCard extends StatelessWidget {
  const TalkCard({super.key, required this.name, required this.a, required this.o});
  final String name;
  final ApplicantAnswer a;
  final InterviewObservation o;
  @override Widget build(BuildContext context){
    final tag = observationTagFor(a, o);
    final style = observationTagStyle(tag);
    return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('あなた',style:TextStyle(fontWeight:FontWeight.bold)),Text('「${a.question}」'),
      const SizedBox(height:10),Text(name,style:const TextStyle(fontWeight:FontWeight.bold)),Text('「${a.answer}」'),
      const Divider(),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: style.color.withValues(alpha: 0.5))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(style.icon, size: 13, color: style.color),
              const SizedBox(width: 4),
              Text(style.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: style.color)),
            ]),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(o.text, style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
    ])));
  }
}

/// Interview-summary observation row with its tag chip (Playable 0.4C.3 §4).
class ObservationSummaryTile extends StatelessWidget {
  const ObservationSummaryTile({super.key, required this.observation, required this.answer});
  final InterviewObservation observation;
  final ApplicantAnswer answer;
  @override Widget build(BuildContext context) {
    final tag = observationTagFor(answer, observation);
    final style = observationTagStyle(tag);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(style.icon, color: style.color),
      title: Row(
        children: [
          Text(interviewQuestionLabels[observation.category]!),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(style.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: style.color)),
          ),
        ],
      ),
      subtitle: Text(observation.text),
    );
  }
}

/// The interview summary's "結論" row (Playable 0.4C.4 §13): one compact
/// chip per question actually asked, shown *above* the detailed
/// [ObservationSummaryTile] list — 結論 → 詳細, not the other way round.
/// Reuses the exact same [ObservationTag] styling as [TalkCard] so the
/// visual language stays identical between "during the interview" and "the
/// summary after it".
class InterviewConclusionSummary extends StatelessWidget {
  const InterviewConclusionSummary({super.key, required this.session});
  final RecruitmentInterviewSession session;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < session.observations.length && i < session.applicantAnswers.length; i++)
          _ConclusionChip(
            category: session.observations[i].category,
            tag: observationTagFor(session.applicantAnswers[i], session.observations[i]),
          ),
      ],
    );
  }
}

class _ConclusionChip extends StatelessWidget {
  const _ConclusionChip({required this.category, required this.tag});
  final InterviewQuestionCategory category;
  final ObservationTag tag;

  @override
  Widget build(BuildContext context) {
    final style = observationTagStyle(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: style.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 5),
          Text(interviewQuestionLabels[category]!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(style.label, style: TextStyle(fontSize: 11, color: style.color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Information Confidence vs Impression, per dimension (Playable 0.4C.4
/// §7) — two reads, never blended into one score:
///
/// - the bar: how much was actually learned about this dimension this
///   interview (confidence), independent of whether it was good news
/// - the trailing chip: what impression that information left (or "不明"
///   when nothing came up at all)
///
/// [computeInfoDimensions] derives both purely from questions the player
/// already asked — never the applicant's internal ability numbers.
class InterviewInfoGauge extends StatelessWidget {
  const InterviewInfoGauge({super.key, required this.session});
  final RecruitmentInterviewSession session;

  @override
  Widget build(BuildContext context) {
    final info = computeInfoDimensions(session);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final dim in InfoDimension.values) _DimensionRow(dimension: dim, info: info[dim]!)],
    );
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.dimension, required this.info});
  final InfoDimension dimension;
  final DimensionInfo info;

  @override
  Widget build(BuildContext context) {
    final style = info.impression == null ? null : observationTagStyle(info.impression!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(infoDimensionLabels[dimension]!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
              if (style != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 11, color: style.color),
                      const SizedBox(width: 3),
                      Text(style.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: style.color)),
                    ],
                  ),
                )
              else
                const Text('不明', style: TextStyle(fontSize: 10.5, color: Colors.black38)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  width: 16,
                  height: 7,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: i < info.confidenceLevel ? const Color(0xFF1565C0) : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              const SizedBox(width: 6),
              Text(confidenceLabel(info.confidenceLevel), style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}
