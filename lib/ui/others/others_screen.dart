import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';

class OthersScreen extends StatelessWidget {
  const OthersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;
    final office = officeConfigs[state.officeType]!;
    final occupancy = state.engineers.length + state.pendingHires.length;

    final upcomingAr = state.accountsReceivable
        .where((ar) => ar.status == ArStatus.pending)
        .toList()
      ..sort((a, b) => a.dueMonth.compareTo(b.dueMonth));

    return Scaffold(
      appBar: AppBar(title: const Text('その他')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _SectionCard(
            title: '会社情報',
            children: [
              _Row('会社名', state.company.name),
              _Row('資金', formatYen(state.company.cash)),
              _Row('信用', '${state.company.credit}'),
              _Row('Seed', '${state.seed}'),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'オフィス',
            children: [
              _Row('種別', office.label),
              _Row('家賃', '${formatYen(office.monthlyRent)}/月'),
              _Row('定員', '$occupancy / ${office.employeeCapacity}名'),
              _Row('モチベーション補正', office.moraleModifier > 0 ? 'プラス' : office.moraleModifier < 0 ? 'マイナス' : 'なし'),
            ],
          ),
          const SizedBox(height: 14),
          const _WelfareSection(),
          const SizedBox(height: 14),
          Text('入金予定 (${upcomingAr.length}件)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (upcomingAr.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: const Text('現在、入金待ちの売掛金はありません。', style: TextStyle(fontSize: 13, color: Colors.black54)),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  for (final ar in upcomingAr)
                    ListTile(
                      dense: true,
                      leading: Text(
                        GameCalendar.monthEndLabel(ar.dueMonth),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      title: Text(clientNameById(ar.clientId), style: const TextStyle(fontSize: 13)),
                      trailing: Text(
                        formatYen(ar.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text('取引先', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final client in sampleClients)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ClientCard(
                client: client,
                relation: state.relationFor(client.id),
              ),
            ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'デバッグ / プレイテスト',
            children: [
              const Text(
                'ここまでのプレイログをJSON形式でコピーできます。',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: controller.playtestLogJson()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('プレイログをコピーしました。')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('プレイログをコピー'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'セーブデータ',
            children: [
              const Text(
                'このゲームは端末のローカルストレージに自動保存されます。',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmRestart(context),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('最初からやり直す'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmRestart(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('最初からやり直しますか？'),
        content: const Text('現在の進行状況は失われます。新しい seed でゲームを開始します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.game.restart();
            },
            child: const Text('やり直す'),
          ),
        ],
      ),
    );
  }
}

/// 福利厚生 / 社員環境 (Playable 0.4C §28-29): a compact summary + the
/// three occasional welfare events. Deliberately event-driven, not a
/// weekly chore — day-to-day state stays on the employee detail screen.
class _WelfareSection extends StatelessWidget {
  const _WelfareSection();

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final pcCounts = <PcTier, int>{for (final tier in PcTier.values) tier: 0};
    for (final e in state.engineers) {
      final tier = state.equipmentFor(e.id)?.pcTier ?? PcTier.standardLaptop;
      pcCounts[tier] = (pcCounts[tier] ?? 0) + 1;
    }
    String lastLabel(int? week) =>
        week == null ? '未実施' : 'Week $week (${GameCalendar.displayLabel(week)})';
    final hasEmployees = state.engineers.isNotEmpty;

    return _SectionCard(
      title: '福利厚生 / 社員環境',
      children: [
        _Row(
          '貸与PC',
          pcCounts.entries.where((e) => e.value > 0).map((e) => '${pcTierConfigs[e.key]!.label}×${e.value}').join(' / '),
        ),
        const Text('PCのアップグレードは社員詳細画面から行えます。', style: TextStyle(fontSize: 11.5, color: Colors.black54)),
        const Divider(height: 22),
        _Row('健康診断', lastLabel(state.lastHealthCheckWeek)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: hasEmployees ? () => _showHealthCheckDialog(context) : null,
            child: const Text('健康診断を実施する'),
          ),
        ),
        const Divider(height: 22),
        _Row('賞与', lastLabel(state.lastBonusWeek)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: hasEmployees ? () => _showBonusDialog(context) : null,
            child: const Text('賞与を検討する'),
          ),
        ),
        const Divider(height: 22),
        _Row('社員旅行', lastLabel(state.lastCompanyTripWeek)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: hasEmployees ? () => _showCompanyTripDialog(context) : null,
            child: const Text('社員旅行を検討する'),
          ),
        ),
      ],
    );
  }
}

Future<void> _showHealthCheckDialog(BuildContext context) async {
  final state = context.game.state;
  var tier = HealthCheckTier.basic;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(builder: (context, setState) {
      final cost = WelfareEngine.healthCheckCost(tier, state.engineers.length);
      final config = healthCheckConfigs[tier]!;
      return AlertDialog(
        title: const Text('健康診断を実施'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in HealthCheckTier.values)
              _ChoiceTile(
                selected: t == tier,
                onTap: () => setState(() => tier = t),
                title: healthCheckConfigs[t]!.label,
                subtitle: '${formatYen(healthCheckConfigs[t]!.costPerEmployee)}/人  モチベーション+${healthCheckConfigs[t]!.moraleEffect} / 信頼+${healthCheckConfigs[t]!.trustEffect}',
              ),
            const Divider(),
            Text('対象: 全社員 ${state.engineers.length}名', style: const TextStyle(fontSize: 13)),
            Text('必要資金: ${formatYen(cost)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('現預金: ${formatYen(state.company.cash)} → ${formatYen(state.company.cash - cost)}'),
            Text('全社員 モチベーション+${config.moraleEffect} / 信頼+${config.trustEffect}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('キャンセル')),
          FilledButton(
            onPressed: state.company.cash < cost ? null : () => Navigator.pop(dialog, true),
            child: const Text('実施する'),
          ),
        ],
      );
    }),
  );
  if (confirmed == true && context.mounted) {
    context.game.conductHealthCheck(tier);
  }
}

Future<void> _showBonusDialog(BuildContext context) async {
  final state = context.game.state;
  var plan = BonusPlan.one;
  final totalSalary = state.engineers.fold<int>(0, (sum, e) => sum + e.salary);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(builder: (context, setState) {
      final cost = WelfareEngine.bonusCost(plan, totalSalary);
      final config = bonusPlanConfigs[plan]!;
      final cashAfter = state.company.cash - cost;
      final runwayBefore = FinanceEngine.cashRunwayMonths(state);
      final hypothetical = state.copyWith(company: state.company.copyWith(cash: cashAfter));
      final runwayAfter = FinanceEngine.cashRunwayMonths(hypothetical);
      String runwayText(double months) => months.isFinite ? '約${months.toStringAsFixed(1)}か月' : '減少せず';
      return AlertDialog(
        title: const Text('賞与を検討'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in BonusPlan.values)
                _ChoiceTile(
                  selected: p == plan,
                  onTap: () => setState(() => plan = p),
                  title: bonusPlanConfigs[p]!.label,
                ),
              const Divider(),
              Text('必要資金: ${formatYen(cost)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('現預金: ${formatYen(state.company.cash)} → ${formatYen(cashAfter)}', style: TextStyle(color: cashAfter < 0 ? Colors.red.shade700 : null, fontWeight: FontWeight.bold)),
              Text('予想資金余命: ${runwayText(runwayBefore)} → ${runwayText(runwayAfter)}'),
              const SizedBox(height: 6),
              Text('社員 モチベーション${config.moraleEffect >= 0 ? '+' : ''}${config.moraleEffect} / 信頼${config.trustEffect >= 0 ? '+' : ''}${config.trustEffect}(目安)', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
              if (cashAfter < 0) const Padding(padding: EdgeInsets.only(top: 8), child: Text('資金がマイナスになります。月末決算で倒産する可能性があります。', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12.5))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('この内容で支給')),
        ],
      );
    }),
  );
  if (confirmed == true && context.mounted) {
    context.game.payBonus(plan);
  }
}

Future<void> _showCompanyTripDialog(BuildContext context) async {
  final state = context.game.state;
  var type = CompanyTripType.dayTrip;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(builder: (context, setState) {
      final cost = WelfareEngine.companyTripCost(type, state.engineers.length);
      return AlertDialog(
        title: const Text('社員旅行を検討'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in CompanyTripType.values)
              _ChoiceTile(
                selected: t == type,
                onTap: () => setState(() => type = t),
                title: companyTripConfigs[t]!.label,
                subtitle: '${formatYen(companyTripConfigs[t]!.costPerEmployee)}/人',
              ),
            const Divider(),
            Text('対象: 全社員 ${state.engineers.length}名', style: const TextStyle(fontSize: 13)),
            Text('必要資金: ${formatYen(cost)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('現預金: ${formatYen(state.company.cash)} → ${formatYen(state.company.cash - cost)}'),
            const SizedBox(height: 6),
            const Text('反応は社員が重視すること（人間関係・プライベート・待遇など）によって異なります。', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('キャンセル')),
          FilledButton(
            onPressed: state.company.cash < cost ? null : () => Navigator.pop(dialog, true),
            child: const Text('実施する'),
          ),
        ],
      );
    }),
  );
  if (confirmed == true && context.mounted) {
    context.game.conductCompanyTrip(type);
  }
}

/// A radio-style selection row for the welfare dialogs, avoiding the
/// deprecated `RadioListTile.groupValue`/`onChanged` API.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.selected, required this.onTap, required this.title, this.subtitle});

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? SesTheme.primaryBlue : null),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.relation});

  final Client client;
  final ClientRelation relation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(client.id.contains('axis')?'金融・Java案件が多い':client.id.contains('future')?'Web・Frontend案件が多い':client.id.contains('nova')?'Infrastructure案件が多い':'幅広い業務案件',style:const TextStyle(fontSize:12)),
                Text(relation.unlocked ? '取引中 / trust ${relation.trust} / 参画実績 ${relation.successfulAssignments}' : '未取引企業',style:TextStyle(fontSize:12,color:relation.unlocked?Colors.green:Colors.grey)),
                if(!relation.unlocked) Text(client.id.contains('nova')?'解放条件: 社員5名以上 + インフラ経験社員':'解放条件: Axis Soft trust 60 + 参画成功3件',style:const TextStyle(fontSize:11,color:Colors.black54)),
                Text(
                  '${clientSpecialtyLabels[client.specialty] ?? client.specialty.name} ・ 支払${client.paymentTermDays}日',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (relation.unlocked)
            const Icon(Icons.handshake_outlined, color: SesTheme.primaryBlue, size: 20),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: SesTheme.primaryBlue),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
