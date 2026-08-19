import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_state.dart';

/// First playable slice of Public Demo 0.1.
///
/// This screen intentionally stays isolated from the development build while
/// the monthly demo loop is introduced incrementally.
class PublicDemo01PlaceholderScreen extends StatefulWidget {
  const PublicDemo01PlaceholderScreen({super.key});

  @override
  State<PublicDemo01PlaceholderScreen> createState() =>
      _PublicDemo01PlaceholderScreenState();
}

class _PublicDemo01PlaceholderScreenState
    extends State<PublicDemo01PlaceholderScreen> {
  static const _mvpMonthlyExpenses = 800000;
  PublicDemoState _state = PublicDemoState.aprilStart();

  String _yen(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '¥$buffer';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('S.E.S. Public Demo 0.1')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${_state.month}月',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('現預金 ${_yen(_state.cash)}'),
                    const SizedBox(height: 8),
                    Text('在籍 技術者${_state.engineerCount}名 / 総務${_state.adminCount}名'),
                    Text('待機技術者 ${_state.engineersWaiting}名'),
                    const SizedBox(height: 8),
                    Text(
                      '営業対応 ${_state.salesUsed}/${_state.salesCapacity} '
                      '（残り${_state.salesRemaining}枠）',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_state.month == 4) ...[
              const Text('4月のMVP-A'),
              const SizedBox(height: 8),
              const Text('SkillSheet・案件営業・面談は次の実装単位で接続します。'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _state.salesRemaining == 0
                    ? null
                    : () => setState(() => _state = _state.useSalesSlot()),
                child: const Text('営業枠を1回使う（仮）'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => setState(
                  () => _state = _state.advanceToMay(
                    monthlyExpenses: _mvpMonthlyExpenses,
                  ),
                ),
                child: const Text('4月を終了して5月へ（仮）'),
              ),
              const SizedBox(height: 8),
              const Text('暫定月間支出：¥800,000（バランス調整対象）'),
            ] else ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '5月を開始しました。\n'
                    '4月に案件を獲得できなかった場合も、技術者2名は待機状態のまま継続します。',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
