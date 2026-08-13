/// 売掛金 (accounts receivable) tracking for Playable 0.3A (§13-15).
///
/// Revenue is recognized in the month an assigned engineer works, but the
/// cash for it only arrives once the client's payment term elapses. Each
/// month of work for a given engineer/project produces one
/// [AccountsReceivable] record; month-end processing collects cash for any
/// record whose [dueMonth] has been reached.
enum ArStatus {
  pending,
  paid;

  String get jsonValue => name;

  static ArStatus fromJson(String value) => ArStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown ArStatus: $value'),
  );
}

class AccountsReceivable {
  final String id;
  final String clientId;
  final String projectId;
  final String employeeId;
  final int amount;

  /// Absolute month number (see [GameCalendar.absoluteMonth]) the revenue
  /// was recognized in.
  final int generatedMonth;

  /// Absolute month number cash for this record is expected/collected in.
  final int dueMonth;

  final ArStatus status;

  const AccountsReceivable({
    required this.id,
    required this.clientId,
    required this.projectId,
    required this.employeeId,
    required this.amount,
    required this.generatedMonth,
    required this.dueMonth,
    this.status = ArStatus.pending,
  });

  AccountsReceivable copyWith({ArStatus? status}) => AccountsReceivable(
    id: id,
    clientId: clientId,
    projectId: projectId,
    employeeId: employeeId,
    amount: amount,
    generatedMonth: generatedMonth,
    dueMonth: dueMonth,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'projectId': projectId,
    'employeeId': employeeId,
    'amount': amount,
    'generatedMonth': generatedMonth,
    'dueMonth': dueMonth,
    'status': status.jsonValue,
  };

  factory AccountsReceivable.fromJson(Map<String, dynamic> json) =>
      AccountsReceivable(
        id: json['id'] as String,
        clientId: json['clientId'] as String,
        projectId: json['projectId'] as String,
        employeeId: json['employeeId'] as String,
        amount: json['amount'] as int,
        generatedMonth: json['generatedMonth'] as int,
        dueMonth: json['dueMonth'] as int,
        status: ArStatus.fromJson(json['status'] as String? ?? 'pending'),
      );
}
