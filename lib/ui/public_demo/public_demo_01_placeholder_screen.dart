import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_interview.dart';
import '../../game/public_demo/public_demo_recruitment.dart';
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
  List<PublicDemoApplicant> _applicants = publicDemoMayApplicants;

  String _yen(int value) => '¥${value.toString()}';

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
    final result = PublicDemoInterviewEvaluator.evaluate(type: type, profile: engineer.interviewProfile);
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

  void _finishApril() {
    final ordered = _engineers.where((e) => e.stage == PublicDemoSalesStage.ordered).length;
    setState(() => _state = _state.advanceToMay(monthlyExpenses: _mvpMonthlyExpenses, orderedEngineers: ordered));
  }

  void _setApplicantStage(int index, PublicDemoApplicantStage stage) {
    setState(() {
      final next = [..._applicants];
      next[index] = next[index].copyWith(stage: stage);
      _applicants = next;
    });
  }

  void _interviewApplicant(int index) {
    if (_state.salesRemaining <= 0) return;
    setState(() {
      _state = _state.useSalesSlot();
      final next = [..._applicants];
      next[index] = next[index].copyWith(stage: PublicDemoApplicantStage.interviewed);
      _applicants = next;
    });
  }

  void _offerApplicant(int index) {
    final applicant = _applicants[index];
    _setApplicantStage(
      index,
      applicant.acceptanceScore >= 60 ? PublicDemoApplicantStage.offerAccepted : PublicDemoApplicantStage.offerDeclined,
    );
  }

  Widget _engineerCard(int index) {
    final e = _engineers[index];
    final failed = e.stage == PublicDemoSalesStage.partnerInterviewFailed || e.stage == PublicDemoSalesStage.clientInterviewFailed;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.name, style: Theme.of(context).textTheme.titleMedium), Text(e.summary), Text('状態：${e.stage.name}'),
      if (e.stage == PublicDemoSalesStage.waiting) FilledButton.tonal(onPressed: () => _setStage(index, PublicDemoSalesStage.skillSheet), child: const Text('SkillSheetを確認')),
      if (e.stage == PublicDemoSalesStage.skillSheet) FilledButton(onPressed: () => _setStage(index, PublicDemoSalesStage.selling), child: const Text('営業を開始')),
      if (e.stage == PublicDemoSalesStage.selling) FilledButton.tonal(onPressed: () => _setStage(index, PublicDemoSalesStage.introduced), child: const Text('案件紹介を確認')),
      if (e.stage == PublicDemoSalesStage.introduced) FilledButton(onPressed: _state.salesRemaining == 0 ? null : () => _runInterview(index, PublicDemoInterviewType.partner), child: const Text('上位会社面談（営業1枠）')),
      if (e.stage == PublicDemoSalesStage.partnerInterviewPassed) FilledButton.tonal(onPressed: () => _runInterview(index, PublicDemoInterviewType.client), child: const Text('客先面談を実施（自動）')),
      if (e.stage == PublicDemoSalesStage.clientInterviewPassed) FilledButton(onPressed: () => _setStage(index, PublicDemoSalesStage.ordered), child: const Text('5月分の発注を受注')),
      if (failed) FilledButton.tonal(onPressed: () => _setStage(index, PublicDemoSalesStage.selling), child: const Text('別案件の営業へ戻る')),
    ])));
  }

  Widget _applicantCard(int index) {
    final a = _applicants[index];
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(a.name, style: Theme.of(context).textTheme.titleMedium),
      Text(a.resumeSummary),
      Text('状態：${a.stage.name}'),
      if (a.stage == PublicDemoApplicantStage.applied) FilledButton.tonal(onPressed: () => _setApplicantStage(index, PublicDemoApplicantStage.resumeReviewed), child: const Text('経歴書を確認')),
      if (a.stage == PublicDemoApplicantStage.resumeReviewed) FilledButton(onPressed: _state.salesRemaining == 0 ? null : () => _interviewApplicant(index), child: const Text('採用面談（営業1枠）')),
      if (a.stage == PublicDemoApplicantStage.interviewed) ...[
        Text('面談評価：${a.interviewScore}'),
        Wrap(spacing: 8, children: [
          FilledButton(onPressed: a.interviewScore >= 60 ? () => _offerApplicant(index) : null, child: const Text('合格・内定')),
          OutlinedButton(onPressed: () => _setApplicantStage(index, PublicDemoApplicantStage.rejected), child: const Text('不採用')),
        ]),
      ],
      if (a.stage == PublicDemoApplicantStage.offerAccepted) const Text('内定承諾：6月入社予定。入社前営業可能'),
      if (a.stage == PublicDemoApplicantStage.offerDeclined) const Text('内定辞退'),
      if (a.stage == PublicDemoApplicantStage.rejected) const Text('不採用'),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('S.E.S. Public Demo 0.1')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${_state.month}月', style: Theme.of(context).textTheme.headlineMedium),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('現預金 ${_yen(_state.cash)}'), Text('在籍 技術者${_state.engineerCount}名 / 総務${_state.adminCount}名'),
          Text('参画 ${_state.engineersAssigned}名 / 待機 ${_state.engineersWaiting}名'),
          Text('営業対応 ${_state.salesUsed}/${_state.salesCapacity}（残り${_state.salesRemaining}枠）'),
        ]))),
        if (_state.month == 4) ...[
          Text('技術者', style: Theme.of(context).textTheme.titleLarge),
          for (var i = 0; i < _engineers.length; i++) _engineerCard(i),
          OutlinedButton(onPressed: _finishApril, child: const Text('4月を終了して5月へ')),
        ] else ...[
          const SizedBox(height: 12),
          Text('5月：応募者一覧', style: Theme.of(context).textTheme.titleLarge),
          const Text('応募者がいる限り、営業枠の範囲で経歴書確認→採用面談を繰り返せます。'),
          for (var i = 0; i < _applicants.length; i++) _applicantCard(i),
          const SizedBox(height: 12),
          Text('社員状況', style: Theme.of(context).textTheme.titleLarge),
          for (final e in _engineers) ListTile(title: Text(e.name), subtitle: Text(e.stage == PublicDemoSalesStage.ordered ? '5月：案件参画' : '5月：待機')),
        ],
      ])),
    );
  }
}
