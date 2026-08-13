enum InterviewQuestionCategory { technical, career, reasonForChange, teamwork, futureCareer, workStyle }

enum ReverseQuestionCategory { salary, projectChoice, waiting, remote, careerGrowth, overtime, companyStability }

enum ApplicantValue { salaryFocused, growthFocused, stabilityFocused, workLifeBalanceFocused, careerFocused }

enum ObservationConfidence { high, medium, low }

enum InterviewOutcome { hired, rejected }

class InterviewObservation {
  final InterviewQuestionCategory category;
  final String text;
  final ObservationConfidence confidence;
  const InterviewObservation({required this.category, required this.text, required this.confidence});
  Map<String, dynamic> toJson() => {'category': category.name, 'text': text, 'confidence': confidence.name};
  factory InterviewObservation.fromJson(Map<String, dynamic> json) => InterviewObservation(
    category: InterviewQuestionCategory.values.byName(json['category'] as String),
    text: json['text'] as String,
    confidence: ObservationConfidence.values.byName(json['confidence'] as String),
  );
}

class ApplicantAnswer {
  final InterviewQuestionCategory category;
  final String question;
  final String answer;
  final int specificity;
  final int consistency;
  final int confidence;
  final int credibility;
  const ApplicantAnswer({required this.category, required this.question, required this.answer, required this.specificity, required this.consistency, required this.confidence, required this.credibility});
  Map<String, dynamic> toJson() => {'category': category.name, 'question': question, 'answer': answer, 'specificity': specificity, 'consistency': consistency, 'confidence': confidence, 'credibility': credibility};
  factory ApplicantAnswer.fromJson(Map<String, dynamic> json) => ApplicantAnswer(
    category: InterviewQuestionCategory.values.byName(json['category'] as String), question: json['question'] as String,
    answer: json['answer'] as String, specificity: json['specificity'] as int, consistency: json['consistency'] as int,
    confidence: json['confidence'] as int, credibility: json['credibility'] as int,
  );
}

class RecruitmentInterviewSession {
  final String id;
  final String applicantId;
  final int startedWeek;
  final ApplicantValue applicantValue;
  final ApplicantValue? secondaryValue;
  final List<InterviewQuestionCategory> selectedQuestions;
  final List<ApplicantAnswer> applicantAnswers;
  final List<InterviewObservation> observations;
  final ReverseQuestionCategory? reverseQuestion;
  final String? companyAnswer;
  final String? applicantReaction;
  final int candidateKnowledge;
  final int companyImpression;
  final bool completed;
  final InterviewOutcome? outcome;

  const RecruitmentInterviewSession({required this.id, required this.applicantId, required this.startedWeek, required this.applicantValue, this.secondaryValue, this.selectedQuestions = const [], this.applicantAnswers = const [], this.observations = const [], this.reverseQuestion, this.companyAnswer, this.applicantReaction, this.candidateKnowledge = 0, required this.companyImpression, this.completed = false, this.outcome});

  bool get questionsComplete => selectedQuestions.length >= 3;
  bool get conversationComplete => questionsComplete && companyAnswer != null;

  RecruitmentInterviewSession copyWith({List<InterviewQuestionCategory>? selectedQuestions, List<ApplicantAnswer>? applicantAnswers, List<InterviewObservation>? observations, ReverseQuestionCategory? reverseQuestion, String? companyAnswer, String? applicantReaction, int? candidateKnowledge, int? companyImpression, bool? completed, InterviewOutcome? outcome}) => RecruitmentInterviewSession(
    id: id, applicantId: applicantId, startedWeek: startedWeek, applicantValue: applicantValue, secondaryValue: secondaryValue,
    selectedQuestions: selectedQuestions ?? this.selectedQuestions, applicantAnswers: applicantAnswers ?? this.applicantAnswers,
    observations: observations ?? this.observations, reverseQuestion: reverseQuestion ?? this.reverseQuestion,
    companyAnswer: companyAnswer ?? this.companyAnswer, applicantReaction: applicantReaction ?? this.applicantReaction,
    candidateKnowledge: candidateKnowledge ?? this.candidateKnowledge, companyImpression: companyImpression ?? this.companyImpression,
    completed: completed ?? this.completed, outcome: outcome ?? this.outcome,
  );

  Map<String, dynamic> toJson() => {'id': id, 'applicantId': applicantId, 'startedWeek': startedWeek, 'applicantValue': applicantValue.name, 'secondaryValue': secondaryValue?.name, 'selectedQuestions': selectedQuestions.map((e) => e.name).toList(), 'applicantAnswers': applicantAnswers.map((e) => e.toJson()).toList(), 'observations': observations.map((e) => e.toJson()).toList(), 'reverseQuestion': reverseQuestion?.name, 'companyAnswer': companyAnswer, 'applicantReaction': applicantReaction, 'candidateKnowledge': candidateKnowledge, 'companyImpression': companyImpression, 'completed': completed, 'outcome': outcome?.name};
  factory RecruitmentInterviewSession.fromJson(Map<String, dynamic> json) => RecruitmentInterviewSession(
    id: json['id'] as String, applicantId: json['applicantId'] as String, startedWeek: json['startedWeek'] as int,
    applicantValue: ApplicantValue.values.byName(json['applicantValue'] as String), secondaryValue: json['secondaryValue'] == null ? null : ApplicantValue.values.byName(json['secondaryValue'] as String),
    selectedQuestions: (json['selectedQuestions'] as List).map((e) => InterviewQuestionCategory.values.byName(e as String)).toList(),
    applicantAnswers: (json['applicantAnswers'] as List).map((e) => ApplicantAnswer.fromJson(e as Map<String, dynamic>)).toList(),
    observations: (json['observations'] as List).map((e) => InterviewObservation.fromJson(e as Map<String, dynamic>)).toList(),
    reverseQuestion: json['reverseQuestion'] == null ? null : ReverseQuestionCategory.values.byName(json['reverseQuestion'] as String),
    companyAnswer: json['companyAnswer'] as String?, applicantReaction: json['applicantReaction'] as String?, candidateKnowledge: json['candidateKnowledge'] as int,
    companyImpression: json['companyImpression'] as int, completed: json['completed'] as bool, outcome: json['outcome'] == null ? null : InterviewOutcome.values.byName(json['outcome'] as String),
  );
}
