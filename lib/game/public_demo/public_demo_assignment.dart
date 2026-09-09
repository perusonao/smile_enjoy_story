enum PublicDemoNextOrderStatus { undecided, offered, accepted, notOffered }

enum PublicDemoReplacementStage {
  none,
  selling,
  introduced,
  partnerPassed,
  partnerFailed,
  clientPassed,
  clientFailed,
  ordered,
}

class PublicDemoAssignment {
  const PublicDemoAssignment({
    required this.engineerId,
    required this.engineerName,
    required this.projectName,
    required this.deliveryPressure,
    required this.budgetHealth,
    required this.humanity,
    this.nextOrderStatus = PublicDemoNextOrderStatus.undecided,
    this.replacementStage = PublicDemoReplacementStage.none,
    this.fieldEvaluation = 50,
    this.projectId,
  });
  final String engineerId, engineerName, projectName;
  final int deliveryPressure, budgetHealth, humanity;
  final PublicDemoNextOrderStatus nextOrderStatus;
  final PublicDemoReplacementStage replacementStage;
  final int fieldEvaluation;

  /// CORE-GAMEPLAY Phase 7A (Assignment Lifecycle): the real Phase 4/5/6
  /// [Project] id this assignment actually represents, when it was created
  /// from a genuine, project-bound Phase 6 project-interview pass (see
  /// [PublicDemoEngineerSales.genuineInterviewProjectId]). `null` for every
  /// assignment created before this field existed, and for one still built
  /// from the generic, project-agnostic interview path (a founding-engineer
  /// template, or an `evaluateInterview` pass with no [Project] concept at
  /// all) — a stable identity marker, resolvable back to the full
  /// [Project]/[Client] at any time via
  /// [PublicDemoSeededProjectGenerator.regenerate], exactly like
  /// [PublicDemoMatchingProposal.projectId] already is. Deliberately not a
  /// [copyWith] parameter: like [engineerId]/[projectName], this is
  /// identity fixed at creation, never a mutable per-month decision field.
  final String? projectId;
  bool willOfferNextMonthFor(int actualCapability) =>
      (actualCapability * 35 +
              humanity * 20 +
              budgetHealth * 30 +
              (100 - deliveryPressure) * 15) ~/
          100 >=
      60;
  int replacementPartnerScoreFor(int actualCapability) =>
      (actualCapability * 55 + humanity * 25 + budgetHealth * 20) ~/ 100;
  int replacementClientScoreFor(int actualCapability) =>
      (actualCapability * 60 + humanity * 25 + budgetHealth * 15) ~/ 100;
  PublicDemoAssignment copyWith({
    PublicDemoNextOrderStatus? nextOrderStatus,
    PublicDemoReplacementStage? replacementStage,
    int? fieldEvaluation,
  }) => PublicDemoAssignment(
    engineerId: engineerId,
    engineerName: engineerName,
    projectName: projectName,
    deliveryPressure: deliveryPressure,
    budgetHealth: budgetHealth,
    humanity: humanity,
    nextOrderStatus: nextOrderStatus ?? this.nextOrderStatus,
    replacementStage: replacementStage ?? this.replacementStage,
    fieldEvaluation: fieldEvaluation ?? this.fieldEvaluation,
    // Identity, not a mutable per-month decision field (see this field's
    // own doc) — always carried forward unchanged, exactly like
    // engineerId/projectName/deliveryPressure/budgetHealth/humanity above,
    // never one of copyWith's own parameters.
    projectId: projectId,
  );

  Map<String, dynamic> toJson() => {
    'engineerId': engineerId,
    'engineerName': engineerName,
    'projectName': projectName,
    'deliveryPressure': deliveryPressure,
    'budgetHealth': budgetHealth,
    'humanity': humanity,
    'nextOrderStatus': nextOrderStatus.name,
    'replacementStage': replacementStage.name,
    'fieldEvaluation': fieldEvaluation,
    // Additive (CORE-GAMEPLAY Phase 7A): `null` for any assignment with no
    // genuine Phase 6 project-bound pass behind it — never fabricated on
    // encode. See this field's own doc above.
    'projectId': projectId,
  };

  factory PublicDemoAssignment.fromJson(Map<String, dynamic> json) {
    T required<T>(String key) {
      final value = json[key];
      if (value is! T) throw FormatException('Invalid assignment $key');
      return value;
    }

    final nextOrderName = required<String>('nextOrderStatus');
    final replacementName = required<String>('replacementStage');
    final nextOrder = PublicDemoNextOrderStatus.values
        .where((value) => value.name == nextOrderName)
        .firstOrNull;
    final replacement = PublicDemoReplacementStage.values
        .where((value) => value.name == replacementName)
        .firstOrNull;
    if (nextOrder == null || replacement == null) {
      throw const FormatException('Invalid assignment state');
    }
    // Additive (CORE-GAMEPLAY Phase 7A): absent on any save written before
    // this field existed — `null` there, exactly reproducing the
    // no-genuine-project-link semantics every such assignment already had.
    // Present-but-non-string is rejected as malformed, matching this file's
    // own convention for every other typed field.
    final projectId = json['projectId'];
    if (projectId != null && projectId is! String) {
      throw const FormatException('Invalid assignment projectId');
    }
    return PublicDemoAssignment(
      engineerId: required<String>('engineerId'),
      engineerName: required<String>('engineerName'),
      projectName: required<String>('projectName'),
      deliveryPressure: required<int>('deliveryPressure'),
      budgetHealth: required<int>('budgetHealth'),
      humanity: required<int>('humanity'),
      nextOrderStatus: nextOrder,
      replacementStage: replacement,
      fieldEvaluation: required<int>('fieldEvaluation'),
      projectId: projectId as String?,
    );
  }

  /// Assignment fallback for any ordered employee, including a post-join hire.
  /// [projectId] (CORE-GAMEPLAY Phase 7A) is the real, genuine Phase 6
  /// project-bound pass this assignment represents, when the caller has one
  /// — see this class's own [projectId] doc; omitted (`null`) for the
  /// generic, project-agnostic path, exactly as before this field existed.
  factory PublicDemoAssignment.forOrderedEngineer({
    required String engineerId,
    required String engineerName,
    required int humanity,
    String? projectId,
  }) => PublicDemoAssignment(
    engineerId: engineerId,
    engineerName: engineerName,
    projectName: '新規開発支援',
    deliveryPressure: 50,
    budgetHealth: 70,
    humanity: humanity,
    projectId: projectId,
  );
}

const publicDemoInitialAssignments = <PublicDemoAssignment>[
  PublicDemoAssignment(
    engineerId: 'eng-01',
    engineerName: '佐藤 健',
    projectName: '販売管理システム開発',
    deliveryPressure: 45,
    budgetHealth: 75,
    humanity: 70,
  ),
  PublicDemoAssignment(
    engineerId: 'eng-02',
    engineerName: '鈴木 葵',
    projectName: '業務アプリ改修',
    deliveryPressure: 72,
    budgetHealth: 48,
    humanity: 66,
  ),
];
