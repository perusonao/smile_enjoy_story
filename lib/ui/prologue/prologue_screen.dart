import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../projects/client_interview_screen.dart';
import '../theme.dart';
import '../widgets/navigator_card.dart';
import 'prologue_interview_screen.dart';

/// Root screen for the Founding Prologue (Playable 0.5A §12-64): Home During
/// the Prologue is always exactly one [NavigatorCard] (§66), driven by
/// [PrologueEngine.stage] rather than a UI-only flag, so a save/reload or a
/// widget dispose mid-flow always resumes at the right place (§71).
class PrologueScreen extends StatelessWidget {
  const PrologueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: context.game,
      builder: (context, _) {
        final controller = context.game;
        final state = controller.state;
        final stage = PrologueEngine.stage(state);
        final navigatorName = state.generalAffairsStaff?.name ?? '総務';
        return Scaffold(
          appBar: AppBar(
            title: Text('創業プロローグ ・ 3月${state.prologueState.prologueWeek.clamp(1, 4)}週'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [_StageContent(stage: stage, state: state, navigatorName: navigatorName)],
            ),
          ),
        );
      },
    );
  }
}

class _StageContent extends StatelessWidget {
  const _StageContent({required this.stage, required this.state, required this.navigatorName});
  final PrologueStage stage;
  final GameState state;
  final String navigatorName;

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    switch (stage) {
      case PrologueStage.presidentNaming:
        return _PresidentNaming(navigatorName: navigatorName);
      case PrologueStage.intro:
        return _Intro(navigatorName: navigatorName, presidentName: state.company.presidentName);
      case PrologueStage.week1Recruitment:
        return NavigatorCard(
          navigatorName: navigatorName,
          message: 'まずは案件に参画してもらう技術者を採用しましょう。\n最初は資金を節約するため、無料の募集から始めてみましょう。',
          secondaryMessage: '無料募集: ¥0 / 有料募集: 掲載費はかかりますが応募数や質にメリットがあります(将来使えます)。',
          ctaLabel: '無料で技術者を募集する',
          onCta: () => controller.postPrologueFreeRecruitment(),
        );
      case PrologueStage.week2AwaitingReply:
        return NavigatorCard(
          navigatorName: navigatorName,
          message: '募集を開始しました。応募が届くまで次の週へ進めましょう。',
          ctaLabel: '次の週へ',
          onCta: () => controller.advancePrologueWeek(),
        );
      case PrologueStage.week2CandidateSelect:
        return _CandidateSelect(navigatorName: navigatorName, state: state);
      case PrologueStage.week2Interview:
      case PrologueStage.week2Decision:
        final id = state.prologueState.interviewingCandidateId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || id == null) return;
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrologueInterviewScreen(applicantId: id)));
        });
        return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
      case PrologueStage.week3SkillSheet:
        return _SkillSheetConfirm(navigatorName: navigatorName, state: state);
      case PrologueStage.week3Sales:
        return NavigatorCard(
          navigatorName: navigatorName,
          message: '入社してから案件を探すと、参画までの間も給与が発生します。\n4月の入社に合わせて、今から営業を始めておきましょう。',
          secondaryMessage: '公開先: 現在取引できる会社(${state.unlockedClientCount}社)',
          ctaLabel: '営業を開始する',
          onCta: () => controller.startProloguePreJoiningSales(),
        );
      case PrologueStage.week4AwaitingRequest:
        return NavigatorCard(
          navigatorName: navigatorName,
          message: state.prologueState.failedAttempts > 0 ? '残念でした。SES営業では珍しいことではありません。\n次の案件を探しましょう。' : '面談依頼を待ちましょう。',
          ctaLabel: '次の週へ',
          onCta: () => controller.advancePrologueWeek(),
        );
      case PrologueStage.week4InterviewRequest:
        return _InterviewRequest(navigatorName: navigatorName, state: state);
      case PrologueStage.week4UpperInterview:
        return _UpperInterviewIntro(navigatorName: navigatorName, state: state);
      case PrologueStage.week4ClientInterview:
        return _ClientInterviewAuto(navigatorName: navigatorName, state: state);
      case PrologueStage.week4Contract:
        return _Contract(navigatorName: navigatorName, state: state);
      case PrologueStage.complete:
        return _Complete(state: state);
      case PrologueStage.freeManagement:
        return const SizedBox.shrink();
    }
  }
}

class _PresidentNaming extends StatefulWidget {
  const _PresidentNaming({required this.navigatorName});
  final String navigatorName;
  @override
  State<_PresidentNaming> createState() => _PresidentNamingState();
}

class _PresidentNamingState extends State<_PresidentNaming> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(
          navigatorName: widget.navigatorName,
          message: 'おはようございます。\n今日からいよいよ会社設立ですね。\n\nまず、社長のお名前を教えていただけますか？',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          maxLength: PrologueEngine.presidentNameMaxLength,
          decoration: const InputDecoration(labelText: '社長のお名前', border: OutlineInputBorder()),
          onSubmitted: (_) => _submit(context),
        ),
        FilledButton(onPressed: () => _submit(context), child: const Text('会社を設立する')),
      ],
    );
  }

  void _submit(BuildContext context) {
    if (_controller.text.trim().isEmpty) return;
    context.game.setPresidentName(_controller.text);
  }
}

class _Intro extends StatefulWidget {
  const _Intro({required this.navigatorName, required this.presidentName});
  final String navigatorName, presidentName;
  @override
  State<_Intro> createState() => _IntroState();
}

class _IntroState extends State<_Intro> {
  int _index = 0;
  List<String> get _messages => [
    '${widget.presidentName}社長、あらためまして。\nこれから一緒に会社を経営していきます。',
    'この会社でやることはシンプルです。\n・技術者を採用する\n・案件へ参画させる\n・取引先から売上を得る',
    '取引実績を積んで信頼を得て、新しい取引先を増やし、会社を成長させましょう。\nただし、現金が尽きると経営は続けられません。',
    '続いて事務所についてです。\n現在の事務所は小規模オフィス、家賃は月${formatCompactYen(officeConfigs[OfficeType.smallOffice]!.monthlyRent)}です。',
    '社員がいなくても、家賃や光熱費・通信費などの固定費は毎月かかります。\n私、総務の給与も毎月発生しています。\n\n社員がいなくても、毎月現金が減っていくことを覚えておいてください。',
  ];

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _messages.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(
          navigatorName: widget.navigatorName,
          message: _messages[_index],
          ctaLabel: isLast ? '次へ進む' : '次へ',
          onCta: () {
            if (isLast) {
              context.game.markPrologueIntroSeen();
            } else {
              setState(() => _index++);
            }
          },
        ),
      ],
    );
  }
}

class _CandidateSelect extends StatelessWidget {
  const _CandidateSelect({required this.navigatorName, required this.state});
  final String navigatorName;
  final GameState state;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(navigatorName: navigatorName, message: '応募者が2名届きました。\n今週面談できるのは1人です。どちらと会うか決めましょう。'),
        const SizedBox(height: 12),
        for (final entry in state.applicants) _CandidateCard(applicant: entry.applicant),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.applicant});
  final Applicant applicant;
  @override
  Widget build(BuildContext context) {
    final skill = applicant.skillFor(applicant.mainLanguage);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(applicant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${applicant.age}歳 / ${applicant.mainLanguage.jsonValue} 経験${(skill.displayedExperienceMonths / 12).toStringAsFixed(1)}年'),
            Text('希望年収: ${formatCompactYen(applicant.desiredMonthlySalary * 12)}'),
            Text('コミュニケーション: ${'★' * applicant.personality.communication}${'☆' * (5 - applicant.personality.communication)}'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => context.game.selectPrologueCandidate(applicant.id), child: const Text('面接する')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillSheetConfirm extends StatelessWidget {
  const _SkillSheetConfirm({required this.navigatorName, required this.state});
  final String navigatorName;
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final engineer = state.engineers.first;
    final sheet = state.skillSheetFor(engineer.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(navigatorName: navigatorName, message: '${engineer.profile.name}さんが内定を承諾しました！\n入社は4月1週の予定です。'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SkillSheet(営業用経歴)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('主な技術: ${engineer.profile.mainLanguage.jsonValue}'),
                Text('Backend: ${sheet.displayedBackend} / DB: ${sheet.displayedDatabase} / Frontend: ${sheet.displayedFrontend}'),
                const SizedBox(height: 8),
                const Text('取引先へ見せる営業用経歴です。実態より強く記載することもできますが、差が大きいと面談リスクや信頼低下につながります。\n最初は実態に忠実な内容で営業してみましょう。', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => context.game.confirmPrologueSkillSheet(), child: const Text('SkillSheetを確認しました')),
      ],
    );
  }
}

class _InterviewRequest extends StatelessWidget {
  const _InterviewRequest({required this.navigatorName, required this.state});
  final String navigatorName;
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final engineer = state.engineers.first;
    final offer = state.interviewOffers.where((o) => o.employeeId == engineer.id && o.status == InterviewOfferStatus.pending).first;
    final project = state.openProjects.firstWhere((e) => e.project.id == offer.projectId).project;
    final client = FinanceEngine.clientById(project.clientId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(navigatorName: navigatorName, message: '${client.name}から面談依頼が届きました。\nこの案件は面談が2回あります(上位会社面談 → 客先面談)。今回はこの案件で進めてみましょう。'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('会社: ${client.name}'),
                Text('月単価: ${formatCompactYen(project.monthlyRate)}'),
                Text('契約期間: ${project.durationWeeks}週'),
                Text('支払サイト: ${client.paymentTermDays}日'),
                const Text('参画開始予定: 4月1週'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => context.game.acceptPrologueInterviewRequest(), child: const Text('面談へ進む')),
      ],
    );
  }
}

class _UpperInterviewIntro extends StatelessWidget {
  const _UpperInterviewIntro({required this.navigatorName, required this.state});
  final String navigatorName;
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final engineer = state.engineers.first;
    final proposal = state.proposals.firstWhere((p) => p.engineerId == engineer.id && p.status == ApplicationStatus.active);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(
          navigatorName: navigatorName,
          message: 'まずは上位会社(協力会社)との面談です。\n${engineer.profile.name}さんが質問へ回答します。あなたは営業として、必要に応じてフォローしてください。',
          ctaLabel: '面談へ進む',
          onCta: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ClientInterviewScreen(applicationId: proposal.id, step: SelectionStep.upperCompanyInterview, onResultContinue: () => Navigator.pop(context)),
          )),
        ),
      ],
    );
  }
}

class _ClientInterviewAuto extends StatelessWidget {
  const _ClientInterviewAuto({required this.navigatorName, required this.state});
  final String navigatorName;
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final engineer = state.engineers.first;
    final proposal = state.proposals.firstWhere((p) => p.engineerId == engineer.id && p.status == ApplicationStatus.active);
    final session = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.clientInterview).toList();
    if (session.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.game.autoResolveClientInterview(proposal.id);
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigatorCard(navigatorName: navigatorName, message: '上位会社面談 通過！\n\n次は実際の客先との面談です。今回は営業の私たちは同席できません。${engineer.profile.name}さんに任せて結果を待ちましょう。'),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final s = session.first;
    final passed = s.result == ClientInterviewResult.passed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(
          navigatorName: navigatorName,
          message: passed ? '客先面談 合格！\n\n${engineer.profile.name}さんが選ばれました。' : '客先面談 不合格でした。\n\n残念でした。SES営業では珍しいことではありません。次の案件を探しましょう。',
          ctaLabel: '続ける',
          onCta: () => context.game.advancePrologueWeek(),
        ),
      ],
    );
  }
}

class _Contract extends StatelessWidget {
  const _Contract({required this.navigatorName, required this.state});
  final String navigatorName;
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final engineer = state.engineers.first;
    final offerReady = state.proposals.any((p) => p.engineerId == engineer.id && p.status == ApplicationStatus.accepted);
    if (!offerReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.game.finalizePrologueContractIfReady();
      });
      return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
    }
    final proposal = state.proposals.firstWhere((p) => p.engineerId == engineer.id && p.status == ApplicationStatus.accepted);
    final client = FinanceEngine.clientById(proposal.project.clientId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(navigatorName: navigatorName, message: 'これで4月の入社と同時に案件へ参画できます！'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('契約成立', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                const SizedBox(height: 8),
                Text(proposal.project.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('会社: ${client.name}'),
                Text('月単価: ${formatCompactYen(proposal.project.monthlyRate)}'),
                Text('契約期間: ${proposal.project.durationWeeks}週'),
                Text('支払サイト: ${client.paymentTermDays}日'),
                const Text('参画開始: 4月1週'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => context.game.advancePrologueWeek(), child: const Text('次の週へ')),
      ],
    );
  }
}

class _Complete extends StatelessWidget {
  const _Complete({required this.state});
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final engineer = state.engineers.first;
    final assignment = state.activeAssignments.first;
    final client = FinanceEngine.clientById(assignment.project.clientId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${engineer.profile.name}さんが入社しました！', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                const Text('初案件参画！', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                Text('${assignment.project.title} / ${client.name}'),
                Text('月単価: ${formatCompactYen(assignment.project.monthlyRate)} / 支払サイト: ${client.paymentTermDays}日'),
                const SizedBox(height: 10),
                Text('これで会社に売上が立ちます。\nただし、この取引先は${client.paymentTermDays}日サイトのため、入金されるのは後になります。', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(child: Text('━━━━━━━━━━━━\n創業準備 完了\n━━━━━━━━━━━━', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        const Text('最初の社員を採用し、最初の案件を獲得しました。\nここからは、社長の判断で会社を経営していきましょう。', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => context.game.completePrologue(), child: const Text('経営を始める')),
      ],
    );
  }
}
