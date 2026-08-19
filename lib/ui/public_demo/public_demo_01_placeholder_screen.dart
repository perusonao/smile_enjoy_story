import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_interview.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../../game/public_demo/public_demo_state.dart';

class PublicDemo01PlaceholderScreen extends StatefulWidget {
  const PublicDemo01PlaceholderScreen({super.key});

  @override
  State<PublicDemo01PlaceholderScreen> createState() => _PublicDemo01PlaceholderScreenState();
}

class _PublicDemo01PlaceholderScreenState extends State<PublicDemo01PlaceholderScreen> {
  static const _mvpMonthlyExpenses = 800000;
  PublicDemoState _state = PublicDemoState.aprilStart();
  List<PublicDemoEngineerSales> _engineers = publicDemoInitialEngineers;

  String _yen(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '¥$buffer';
  }

  String _stageLabel(PublicDemoSalesStage stage) => switch (stage) {
        PublicDemoSalesStage.waiting => '待機',
        PublicDemoSalesStage.skillSheet => 'SkillSheet確認済み',
        PublicDemoSalesStage.selling => '営業中',
        PublicDemoSalesStage.introduced => '案件紹介あり',
        PublicDemoSalesStage.partnerInterviewFailed => '上位会社面談 不合格',
        PublicDemoSalesStage.partnerInterviewPassed => '上位会社面談 合格',
        PublicDemoSalesStage.clientInterviewFailed => '客先面談 不合格',
        PublicDemoSalesStage.clientInterviewPassed => '客先面談 合格',
        PublicDemoSalesStage.ordered => '5月分 受注済み',
      };

  void _setStage(int index, PublicDemoSalesStage stage) {
    setState(() {
      final next = [..._engineers];
      next[index] = next[index].copyWith(stage: stage);
      _engineers = next;
    });
  }

  void _runInterview(int index, PublicDemoInterviewType type) {
    if (type == PublicDemoInterviewType.partner && _state.salesRemaining <= 0) return;
    final engineer = _engineers[index];
    final result = PublicDemoInterviewEvaluator.evaluate(
      type: type,
      profile: engineer.interviewProfile,
    );
    setState(() {
      if (type == PublicDemoInterviewType.partner) _state = _state.useSalesSlot();
      final next = [..._engineers];
      next[index] = engineer.copyWith(
        stage: switch ((type, result.passed)) {
          (PublicDemoInterviewType.partner, true) => PublicDemoSalesStage.partnerInterviewPassed,
          (PublicDemoInterviewType.partner, false) => PublicDemoSalesStage.partnerInterviewFailed,
          (PublicDemoInterviewType.client, true) => PublicDemoSalesStage.clientInterviewPassed,
          (PublicDemoInterviewType.client, false) => PublicDemoSalesStage.clientInterviewFailed,
        },
        lastInterviewScore: result.score,
      );
      _engineers = next;
    });
  }

  Widget _engineerCard(int index) {
    final engineer = _engineers[index];
    final failed = engineer.stage == PublicDemoSalesStage.partnerInterviewFailed ||
        engineer.stage == PublicDemoSalesStage.clientInterviewFailed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(engineer.name, style: Theme.of(context).textTheme.titleMedium),
            Text(engineer.summary),
            const SizedBox(height: 6),
            Text('状態：${_stageLabel(engineer.stage)}'),
            if (engineer.lastInterviewScore != null) Text('直近面談評価：${engineer.lastInterviewScore}'),
            const SizedBox(height: 10),
            if (engineer.stage == PublicDemoSalesStage.waiting)
              FilledButton.tonal(onPressed: () => _setStage(index, PublicDemoSalesStage.skillSheet), child: const Text('SkillSheetを確認')),
            if (engineer.stage == PublicDemoSalesStage.skillSheet)
              FilledButton(onPressed: () => _setStage(index, PublicDemoSalesStage.selling), child: const Text('営業を開始')),
            if (engineer.stage == PublicDemoSalesStage.selling)
              FilledButton.tonal(onPressed: () => _setStage(index, PublicDemoSalesStage.introduced), child: const Text('案件紹介を確認')),
            if (engineer.stage == PublicDemoSalesStage.introduced)
              FilledButton(
                onPressed: _state.salesRemaining == 0 ? null : () => _runInterview(index, PublicDemoInterviewType.partner),
                child: const Text('上位会社面談（営業1枠）'),
              ),
            if (engineer.stage == PublicDemoSalesStage.partnerInterviewPassed)
              FilledButton.tonal(
                onPressed: () => _runInterview(index, PublicDemoInterviewType.client),
                child: const Text('客先面談を実施（自動）'),
              ),
            if (engineer.stage == PublicDemoSalesStage.clientInterviewPassed)
              FilledButton(onPressed: () => _setStage(index, PublicDemoSalesStage.ordered), child: const Text('5月分の発注を受注')),
            if (failed)
              FilledButton.tonal(
                onPressed: () => _setStage(index, PublicDemoSalesStage.selling),
                child: const Text('別案件の営業へ戻る'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('S.E.S. Public Demo 0.1')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${_state.month}月', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('現預金 ${_yen(_state.cash)}'),
                  Text('在籍 技術者${_state.engineerCount}名 / 総務${_state.adminCount}名'),
                  Text('待機技術者 ${_state.engineersWaiting}名'),
                  const SizedBox(height: 8),
                  Text('営業対応 ${_state.salesUsed}/${_state.salesCapacity}（残り${_state.salesRemaining}枠）'),
                ]),
              ),
            ),
            if (_state.month == 4) ...[
              const SizedBox(height: 12),
              Text('技術者', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (var i = 0; i < _engineers.length; i++) _engineerCard(i),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() => _state = _state.advanceToMay(monthlyExpenses: _mvpMonthlyExpenses)),
                child: const Text('4月を終了して5月へ'),
              ),
              const SizedBox(height: 8),
              const Text('暫定月間支出：¥800,000（バランス調整対象）'),
            ] else ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('5月を開始しました。4月に案件を獲得できなかった技術者は待機状態で継続します。'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
