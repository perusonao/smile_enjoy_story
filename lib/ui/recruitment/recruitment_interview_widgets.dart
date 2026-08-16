import 'package:flutter/material.dart';

import '../../game/game.dart';
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
/// text next to it.
class QuestionProgress extends StatelessWidget {
  const QuestionProgress({super.key, required this.asked});
  final int asked;
  @override Widget build(BuildContext context) => Row(
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
    ],
  );
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
/// `companyImpression` number itself.
class ReactionLine extends StatelessWidget {
  const ReactionLine({super.key, required this.companyImpression});
  final int companyImpression;
  @override Widget build(BuildContext context) {
    final emoji = applicantReactionEmoji(companyImpression);
    final label = RecruitmentInterviewEngine.impressionLabel(companyImpression);
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black54, fontStyle: FontStyle.italic))),
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
