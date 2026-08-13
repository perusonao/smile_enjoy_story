enum SelectionStep {
  documentScreening,
  upperCompanyInterview,
  technicalInterview,
  clientInterview,
  finalInterview,
  offer;

  String get jsonValue => name;

  static SelectionStep fromJson(String value) => values.firstWhere(
    (step) => step.name == value,
    orElse: () => throw ArgumentError('Unknown SelectionStep: $value'),
  );
}

enum SelectionFlowType { simple, standard, advanced }

class SelectionFlow {
  final SelectionFlowType type;
  final List<SelectionStep> steps;

  const SelectionFlow({required this.type, required this.steps});

  const SelectionFlow.simple()
    : type = SelectionFlowType.simple,
      steps = const [
        SelectionStep.documentScreening,
        SelectionStep.clientInterview,
        SelectionStep.offer,
      ];

  const SelectionFlow.standard()
    : type = SelectionFlowType.standard,
      steps = const [
        SelectionStep.documentScreening,
        SelectionStep.upperCompanyInterview,
        SelectionStep.clientInterview,
        SelectionStep.offer,
      ];

  const SelectionFlow.advanced()
    : type = SelectionFlowType.advanced,
      steps = const [
        SelectionStep.documentScreening,
        SelectionStep.upperCompanyInterview,
        SelectionStep.technicalInterview,
        SelectionStep.clientInterview,
        SelectionStep.finalInterview,
        SelectionStep.offer,
      ];

  int get interviewCount => steps
      .where(
        (step) =>
            step != SelectionStep.documentScreening &&
            step != SelectionStep.offer,
      )
      .length;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'steps': steps.map((step) => step.jsonValue).toList(),
  };

  factory SelectionFlow.fromJson(Map<String, dynamic> json) => SelectionFlow(
    type: SelectionFlowType.values.firstWhere(
      (type) => type.name == json['type'],
      orElse: () => SelectionFlowType.standard,
    ),
    steps: (json['steps'] as List)
        .map((step) => SelectionStep.fromJson(step as String))
        .toList(),
  );
}
