import '../models/models.dart';

class WeeklyResult {
  final GameLogEntry event;
  final int priority;
  final String? actionLabel;
  final TaskTargetType targetType;
  const WeeklyResult(this.event,{required this.priority,this.actionLabel,this.targetType=TaskTargetType.none});
}

class WeeklySummaryEngine {
  const WeeklySummaryEngine._();
  static const int maxImportantResults=3;
  static WeeklyResult classify(GameLogEntry event){
    return switch(event.category){
      GameLogCategory.offerReceived => WeeklyResult(event,priority:0,actionLabel:'Offerを見る',targetType:TaskTargetType.employeeDetail),
      GameLogCategory.interviewOffer => WeeklyResult(event,priority:1,actionLabel:'面談を見る',targetType:TaskTargetType.employeeDetail),
      GameLogCategory.interviewFailed => WeeklyResult(event,priority:2,actionLabel:'次案件営業を見る',targetType:TaskTargetType.employeeDetail),
      GameLogCategory.bankrupt => WeeklyResult(event,priority:3),
      GameLogCategory.clientUnlocked => WeeklyResult(event,priority:4,actionLabel:'取引先を見る',targetType:TaskTargetType.none),
      GameLogCategory.offerAccepted||GameLogCategory.offerDeclined => WeeklyResult(event,priority:5,actionLabel:'社員を見る',targetType:TaskTargetType.employeesTab),
      GameLogCategory.interviewPassed => WeeklyResult(event,priority:10,actionLabel:'社員を見る',targetType:TaskTargetType.employeesTab),
      GameLogCategory.fieldLead => WeeklyResult(event,priority:11,actionLabel:'市場を見る',targetType:TaskTargetType.projectsTab),
      GameLogCategory.engineerJoined||GameLogCategory.applicantsArrived => WeeklyResult(event,priority:12),
      GameLogCategory.welfareEvent => WeeklyResult(event,priority:13,actionLabel:'社員を見る',targetType:TaskTargetType.employeesTab),
      _ => WeeklyResult(event,priority:100),
    };
  }
  static List<WeeklyResult> resultsFor(GameState state){final rows=state.events.where((e)=>e.week==state.week).map(classify).toList();rows.sort((a,b)=>a.priority.compareTo(b.priority));return rows;}
  static List<WeeklyResult> importantFor(GameState state)=>resultsFor(state).where((r)=>r.priority<100).take(maxImportantResults).toList();
}
