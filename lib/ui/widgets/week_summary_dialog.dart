import 'package:flutter/material.dart';
import '../../game/game.dart';
import '../theme.dart';

/// True when [showWeekSummaryDialog] would actually have something to show
/// (Phase 3A UX review, P2-2): a genuinely uneventful week — no
/// [WeeklySummaryEngine] result worth calling out, and no guided-tutorial
/// next-step reminder — previously still interrupted "次の週へ" with a
/// modal that only ever said "特に大きな変化はありませんでした". That's
/// exactly the "informational, nothing to decide" case this review asked to
/// stop treating as blocking: the full log is always still on Home's "最近
/// の出来事" for anyone who wants to check it, so nothing is lost by not
/// popping a dialog for it.
bool weekSummaryHasContent(GameState state, {GuidedAction? guidedAction}) =>
    guidedAction != null || WeeklySummaryEngine.importantFor(state).isNotEmpty;

/// [guidedAction] simplifies the summary during the founding tutorial
/// (Playable 0.4C.2 §44): only the single most important event, plus a
/// reminder of what to do next instead of a full recap.
Future<void> showWeekSummaryDialog(BuildContext context, GameState state, {GuidedAction? guidedAction}) => showDialog<void>(context:context,barrierDismissible:false,builder:(_)=>_WeekSummaryDialog(state:state,guidedAction:guidedAction));

class _WeekSummaryDialog extends StatefulWidget { const _WeekSummaryDialog({required this.state,this.guidedAction}); final GameState state; final GuidedAction? guidedAction; @override State<_WeekSummaryDialog> createState()=>_WeekSummaryDialogState(); }
class _WeekSummaryDialogState extends State<_WeekSummaryDialog>{
  bool expanded=false;
  @override Widget build(BuildContext context){
    final tutorial=widget.guidedAction!=null;
    final cap=tutorial?1:WeeklySummaryEngine.maxImportantResults;
    final all=WeeklySummaryEngine.resultsFor(widget.state); final important=all.where((r)=>r.priority<100).take(cap).toList(); final hidden=all.where((r)=>!important.contains(r)).toList();
    return AlertDialog(title:Text('Week ${widget.state.displayWeek}'),content:SizedBox(width:330,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('今週の重要な変化',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),if(important.isEmpty)const Text('特に大きな変化はありませんでした。') else for(var i=0;i<important.length;i++)_ResultCard(index:i+1,result:important[i]),if(hidden.isNotEmpty)...[TextButton(onPressed:()=>setState(()=>expanded=!expanded),child:Text(expanded?'その他を閉じる':'その他 ${hidden.length}件　すべて見る')),if(expanded)for(final result in hidden)Padding(padding:const EdgeInsets.only(bottom:5),child:Text('・${result.event.message}',style:const TextStyle(fontSize:12,color:Colors.black54)))],if(tutorial)...[const Divider(height:20),Text('次: ${widget.guidedAction!.title}',style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.indigo))]]))),actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('閉じる'))]);
  }
}
class _ResultCard extends StatelessWidget{const _ResultCard({required this.index,required this.result});final int index;final WeeklyResult result;@override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:SesTheme.primaryBlue.withValues(alpha:.06),borderRadius:BorderRadius.circular(8),border:Border.all(color:SesTheme.primaryBlue.withValues(alpha:.25))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$index  ${result.event.message}',style:const TextStyle(fontWeight:FontWeight.bold)),if(result.actionLabel!=null)Align(alignment:Alignment.centerRight,child:Text('→ ${result.actionLabel}',style:const TextStyle(color:SesTheme.primaryBlue,fontSize:12,fontWeight:FontWeight.bold)))]));}
