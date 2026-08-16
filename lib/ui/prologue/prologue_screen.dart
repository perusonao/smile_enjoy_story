import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../projects/client_interview_screen.dart';
import '../theme.dart';
import '../widgets/first_contract_celebration.dart';
import '../widgets/labels.dart';
import '../widgets/management_hud.dart';
import '../widgets/navigator_card.dart';
import 'prologue_interview_screen.dart';

/// Root screen for the Founding Prologue (Playable 0.5A §12-64): Home During
/// the Prologue is always exactly one [NavigatorCard] (§66), driven by
/// [PrologueEngine.stage] rather than a UI-only flag, so a save/reload or a
/// widget dispose mid-flow always resumes at the right place (§71).
///
/// The AppBar also always carries a "最初からやり直す" reset action
/// (Playable 0.5A.1 §7) — reachable from every stage, not just a subset —
/// alongside the P0 dead-end invariant [PrologueEngine.canInterviewThisWeek]
/// enforces stage-by-stage below.
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
            actions: [
              IconButton(
                icon: const Icon(Icons.restart_alt),
                tooltip: '最初からやり直す',
                onPressed: () => _confirmRestart(context),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Visible from the very first Prologue screen (Playable
                // 0.4C.4 §2) — "how is my company doing" must never require
                // finishing the tutorial first. Same shared widget MainShell
                // uses post-Prologue, just with a 3月N週 label instead of the
                // fiscal-year WEEK counter (§83: `company.currentWeek` stays
                // 1 through all of March).
                ManagementHud(state: state, weekLabel: '3月${state.prologueState.prologueWeek.clamp(1, 4)}週'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    children: [_StageContent(stage: stage, state: state, navigatorName: navigatorName)],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Playable 0.5A.1 §7: always reachable, always confirmed before it fires —
/// a single mistap can never wipe a playthrough.
Future<void> _confirmRestart(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('初心者モードを最初からやり直しますか？'),
      content: const Text('現在の創業プロローグの進行状況(社長名・会社名・採用状況など)はすべて失われます。この操作は取り消せません。'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('キャンセル')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('やり直す'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await context.game.restartBeginnerMode();
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
        return _CompanySetup(navigatorName: navigatorName, seed: state.seed);
      case PrologueStage.intro:
        return _Intro(navigatorName: navigatorName, presidentName: state.company.presidentName, companyName: state.company.name);
      case PrologueStage.week1Recruitment:
        return _RecruitmentMediaSelect(navigatorName: navigatorName, state: state);
      case PrologueStage.week2AwaitingReply:
        return NavigatorCard(
          navigatorName: navigatorName,
          message: '募集を開始しました。応募が届くまで次の週へ進めましょう。',
          ctaLabel: '次の週へ',
          onCta: () => controller.advancePrologueWeek(),
          mood: navigatorMoodFor(state),
        );
      case PrologueStage.week2CandidateSelect:
        return _CandidateSelect(navigatorName: navigatorName, state: state);
      case PrologueStage.week2Interview:
      case PrologueStage.week2Decision:
        final id = state.prologueState.interviewingCandidateId;
        if (id == null) return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
        return _InterviewLauncher(applicantId: id);
      case PrologueStage.week3SkillSheet:
        return _SkillSheetConfirm(navigatorName: navigatorName, state: state);
      case PrologueStage.week3Sales:
        return NavigatorCard(
          navigatorName: navigatorName,
          message: '入社してから案件を探すと、参画までの間も給与が発生します。\n4月の入社に合わせて、今から営業を始めておきましょう。',
          secondaryMessage: '公開先: 現在取引できる会社(${state.unlockedClientCount}社)',
          ctaLabel: '営業を開始する',
          onCta: () => controller.startProloguePreJoiningSales(),
          mood: navigatorMoodFor(state),
        );
      case PrologueStage.week4AwaitingRequest:
        return NavigatorCard(
          navigatorName: navigatorName,
          message: state.prologueState.failedAttempts > 0
              ? '残念ながら今回の面談は不合格でした。SES営業では珍しいことではありません。\n${state.company.presidentName}社長、次の案件を探しましょう。'
              : '面談依頼を待ちましょう。次の週へ進めると、案件を探し直します。',
          ctaLabel: '次の週へ',
          onCta: () => controller.advancePrologueWeek(),
          mood: navigatorMoodFor(state),
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

/// Pushes [PrologueInterviewScreen] exactly once per interview (Playable
/// 0.4C.2 §1.2 ghost-transition fix).
///
/// Root cause: [PrologueScreen] is wrapped in an `AnimatedBuilder` that
/// rebuilds on *every* [GameController] change — including every question
/// answered inside the just-pushed interview screen itself. The previous
/// implementation scheduled `Navigator.push` from inside `_StageContent`'s
/// `build()` via a bare `addPostFrameCallback`, with no check for whether an
/// interview route was already on the stack — so each in-progress interview
/// action (`askRecruitmentQuestion`, the reverse-question answer, ...)
/// pushed *another* `PrologueInterviewScreen` on top of the still-live
/// previous one. Every one of those extra pushes played a full page-
/// transition animation, which is what showed up as "previous screen text
/// still visible, overlapping the next screen" in mobile E2E recordings —
/// a real widget-tree duplication, not a compositing/recording artifact.
///
/// A [StatefulWidget]'s [State] survives across `_StageContent` rebuilds at
/// the same tree position (same type, no key, same slot), so `_pushed` only
/// needs to go true once per interview — [didUpdateWidget] resets it if a
/// different candidate's [applicantId] ever lands in this same slot.
class _InterviewLauncher extends StatefulWidget {
  const _InterviewLauncher({required this.applicantId});
  final String applicantId;
  @override
  State<_InterviewLauncher> createState() => _InterviewLauncherState();
}

class _InterviewLauncherState extends State<_InterviewLauncher> {
  bool _pushed = false;

  @override
  void initState() {
    super.initState();
    _maybePush();
  }

  @override
  void didUpdateWidget(covariant _InterviewLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.applicantId != widget.applicantId) _pushed = false;
    _maybePush();
  }

  void _maybePush() {
    if (_pushed) return;
    _pushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrologueInterviewScreen(applicantId: widget.applicantId)));
    });
  }

  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
}

class _CompanySetup extends StatefulWidget {
  const _CompanySetup({required this.navigatorName, required this.seed});
  final String navigatorName;
  final int seed;
  @override
  State<_CompanySetup> createState() => _CompanySetupState();
}

/// Playable 0.4C.2 §5: both fields start pre-filled with a plausible random
/// name (deterministic per [_CompanySetup.seed], so a fixed-seed session/
/// widget test always sees the same initial value) — a first-time player can
/// tap "会社を設立する" immediately with no typing, or edit either field
/// first. "再生成" re-rolls both fields together with a fresh (still
/// reproducible: seed + attempt count) pair.
class _CompanySetupState extends State<_CompanySetup> {
  final _presidentController = TextEditingController();
  final _companyController = TextEditingController();
  int _regenerateAttempt = 0;

  @override
  void initState() {
    super.initState();
    _presidentController.text = PrologueEngine.generateRandomPresidentName(widget.seed);
    _companyController.text = PrologueEngine.generateRandomCompanyName(widget.seed);
  }

  @override
  void dispose() {
    _presidentController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _regenerate() {
    _regenerateAttempt++;
    setState(() {
      _presidentController.text = PrologueEngine.generateRandomPresidentName(widget.seed, attempt: _regenerateAttempt);
      _companyController.text = PrologueEngine.generateRandomCompanyName(widget.seed, attempt: _regenerateAttempt);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(
          navigatorName: widget.navigatorName,
          message: 'おはようございます。\n今日からいよいよ会社設立ですね。\n\n社長のお名前と会社名は仮の名前を入力しておきました。このまま設立しても、書き換えても大丈夫です。',
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('company-setup-president-name'),
          controller: _presidentController,
          maxLength: PrologueEngine.presidentNameMaxLength,
          decoration: const InputDecoration(labelText: '社長のお名前', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('company-setup-company-name'),
          controller: _companyController,
          maxLength: PrologueEngine.companyNameMaxLength,
          decoration: const InputDecoration(labelText: '会社名', border: OutlineInputBorder()),
          onSubmitted: (_) => _submit(context),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _regenerate,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('名前を再生成'),
          ),
        ),
        const SizedBox(height: 6),
        FilledButton(onPressed: () => _submit(context), child: const Text('会社を設立する')),
      ],
    );
  }

  void _submit(BuildContext context) {
    if (_presidentController.text.trim().isEmpty || _companyController.text.trim().isEmpty) return;
    context.game.confirmPrologueCompanySetup(presidentName: _presidentController.text, companyName: _companyController.text);
  }
}

class _Intro extends StatefulWidget {
  const _Intro({required this.navigatorName, required this.presidentName, required this.companyName});
  final String navigatorName, presidentName, companyName;
  @override
  State<_Intro> createState() => _IntroState();
}

class _IntroState extends State<_Intro> {
  int _index = 0;

  // Two screens, one theme each (Playable 0.4C.4 §4-5) — down from five.
  // The old §4 screen just *described* fixed costs in the abstract; now
  // that the Management HUD is visible above this card from the Prologue's
  // very first screen (§2), the second message can point at real numbers
  // the player is already looking at instead of re-explaining them in text.
  List<String> get _messages => [
    '${widget.presidentName}社長、あらためまして。\n「${widget.companyName}」を一緒に経営していきましょう。\nやることはシンプルです：技術者を採用し、案件へ参画させ、取引先から売上を得ます。',
    '事務所は小規模オフィス(家賃 月${formatCompactYen(officeConfigs[OfficeType.smallOffice]!.monthlyRent)})。\n社員がいなくても、家賃や総務の給与などの固定費は毎月かかります。\n上のHUDで、現預金と月末予想の動きを確認しながら進めましょう。',
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

/// March Week 1 (Playable 0.5A.1 §3): the player picks a recruitment medium
/// — nothing is ever auto-posted, even in Beginner Mode. The 総務 only
/// *recommends* 無料求人 via [secondaryMessage]; every option below stays a
/// real, tappable choice.
class _RecruitmentMediaSelect extends StatelessWidget {
  const _RecruitmentMediaSelect({required this.navigatorName, required this.state});
  final String navigatorName;
  final GameState state;

  static const _tendencyLabels = {
    RecruitmentMediaType.freeWork: '若手中心の応募が多い傾向',
    RecruitmentMediaType.engineerCareer: '経験者中心の応募が多い傾向',
    RecruitmentMediaType.directScout: '高スキル人材寄りの候補者を紹介',
  };

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final cash = state.company.cash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(
          navigatorName: navigatorName,
          message: '${state.company.presidentName}社長、まずは案件に参画してもらう技術者を採用しましょう。\nどの募集方法を使いますか？',
          secondaryMessage: 'おすすめ: 最初は資金を節約できる「無料求人」から始めるのが安心です。ただし選ぶのは社長次第です。',
        ),
        const SizedBox(height: 12),
        for (final type in RecruitmentMediaType.values)
          _MediaOptionCard(
            type: type,
            tendency: _tendencyLabels[type]!,
            affordable: cash >= recruitmentMediaConfigs[type]!.cost,
            onSelect: () => controller.postPrologueRecruitment(type),
          ),
      ],
    );
  }
}

class _MediaOptionCard extends StatelessWidget {
  const _MediaOptionCard({required this.type, required this.tendency, required this.affordable, required this.onSelect});
  final RecruitmentMediaType type;
  final String tendency;
  final bool affordable;
  final VoidCallback onSelect;

  static const _labels = {
    RecruitmentMediaType.freeWork: '無料求人',
    RecruitmentMediaType.engineerCareer: '有料求人サイト',
    RecruitmentMediaType.directScout: '人材紹介',
  };

  @override
  Widget build(BuildContext context) {
    final config = recruitmentMediaConfigs[type]!;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_labels[type]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                Text(config.cost == 0 ? '無料' : formatCompactYen(config.cost), style: TextStyle(fontWeight: FontWeight.bold, color: config.cost == 0 ? Colors.green.shade700 : Colors.black87)),
              ],
            ),
            const SizedBox(height: 4),
            Text(tendency, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: affordable ? onSelect : null,
                child: Text(affordable ? 'この方法で募集する' : '資金が足りません'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// March Week 2 (Playable 0.5A §17-29, Playable 0.5A.1 §1 P0 fix).
///
/// Every render includes a "次の週へ" fallback alongside the candidate
/// cards — [PrologueEngine.canInterviewThisWeek] can go false mid-stage
/// (after a reject/decline decision, §21's "1週間に1人まで" already blocks
/// the *other* candidate this same week) while [PrologueStage] itself stays
/// [PrologueStage.week2CandidateSelect]; without this fallback, that combo
/// was the P0 dead end (面接する looked enabled but silently no-opped, and
/// nothing else on screen advanced the game).
class _CandidateSelect extends StatelessWidget {
  const _CandidateSelect({required this.navigatorName, required this.state});
  final String navigatorName;
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final canInterview = PrologueEngine.canInterviewThisWeek(state);
    final single = state.applicants.length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(
          navigatorName: navigatorName,
          message: single ? '候補者が1名届きました。スキルシートを確認してから、面談するか決めましょう。' : '応募者が2名届きました。\n今週面談できるのは1人です。どちらと会うか決めましょう。',
          secondaryMessage: canInterview ? null : '今週はすでに面談を1件行いました。残りの候補者とは来週以降に面談できます。',
        ),
        const SizedBox(height: 12),
        for (final entry in state.applicants) _CandidateCard(applicant: entry.applicant, canInterview: canInterview),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: () => context.game.advancePrologueWeek(),
          child: const Text('次の週へ'),
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.applicant, required this.canInterview});
  final Applicant applicant;
  final bool canInterview;
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
            Text('${applicant.age}歳 / ${languageLabels[applicant.mainLanguage] ?? applicant.mainLanguage.jsonValue} 経験${(skill.displayedExperienceMonths / 12).toStringAsFixed(1)}年'),
            Text('希望年収: ${formatCompactYen(applicant.desiredMonthlySalary * 12)}'),
            Text('コミュニケーション: ${'★' * applicant.personality.communication}${'☆' * (5 - applicant.personality.communication)}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showCandidateSkillSheetDialog(context, applicant, canInterview: canInterview),
                    child: const Text('スキルシートを見る'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: canInterview ? () => context.game.selectPrologueCandidate(applicant.id) : null,
                    child: const Text('面接する'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Playable 0.5A.1 §4: the candidate SkillSheet modal. Shown from the
/// candidate card *and* re-openable here via "この人と面談する", so the
/// player can look at the SkillSheet first and decide from inside the modal
/// (§4's flow), without losing the option to just tap 面接する on the card
/// directly.
Future<void> showCandidateSkillSheetDialog(BuildContext context, Applicant applicant, {required bool canInterview}) {
  final tech = applicant.techSkills;
  String stars(int level) => '${'★' * level}${'☆' * (5 - level)}';
  final topDomain = [
    ('バックエンド', tech.backend),
    ('フロントエンド', tech.frontend),
    ('DB', tech.database),
  ].reduce((a, b) => a.$2 >= b.$2 ? a : b).$1;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${applicant.name} さんのスキルシート'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetRow('年齢', '${applicant.age}歳'),
              _SheetRow('希望年収', formatCompactYen(applicant.desiredMonthlySalary * 12)),
              _SheetRow('経験年数', formatExperience(applicant.totalItExperienceMonths)),
              const Divider(),
              const Text('言語', style: TextStyle(fontWeight: FontWeight.bold)),
              _SheetRow(languageLabels[applicant.mainLanguage] ?? applicant.mainLanguage.name, '${formatExperience(applicant.skillFor(applicant.mainLanguage).displayedExperienceMonths)} / ${stars((applicant.skillFor(applicant.mainLanguage).actualSkill / 20).round().clamp(0, 5))}'),
              for (final lang in applicant.subLanguages)
                _SheetRow(languageLabels[lang] ?? lang.name, formatExperience(applicant.skillFor(lang).displayedExperienceMonths)),
              const Divider(),
              const Text('DB / Infrastructure 等', style: TextStyle(fontWeight: FontWeight.bold)),
              _SheetRow('DB', stars(tech.database)),
              _SheetRow('Network', stars(tech.network)),
              _SheetRow('Infrastructure', stars(tech.infrastructure)),
              _SheetRow('Frontend', stars(tech.frontend)),
              _SheetRow('Backend', stars(tech.backend)),
              const Divider(),
              const Text('業界経験', style: TextStyle(fontWeight: FontWeight.bold)),
              _SheetRow('区分', applicantTypeLabels[applicant.type] ?? applicant.type.name),
              _SheetRow('IT業界経験', formatExperience(applicant.totalItExperienceMonths)),
              _SheetRow('転職回数', '${applicant.jobChangeCount}回'),
              const Divider(),
              const Text('役割経験', style: TextStyle(fontWeight: FontWeight.bold)),
              _SheetRow('主な役割', topDomain),
              _SheetRow('リーダー経験', stars(tech.leader)),
              _SheetRow('マネージャー経験', stars(tech.manager)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('閉じる')),
        FilledButton(
          onPressed: canInterview
              ? () {
                  Navigator.of(dialogContext).pop();
                  context.game.selectPrologueCandidate(applicant.id);
                }
              : null,
          child: const Text('この人と面談する'),
        ),
      ],
    ),
  );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12.5))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
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
        NavigatorCard(
          navigatorName: navigatorName,
          message: '${engineer.profile.name}さんが内定を承諾しました！\n入社は4月1週の予定です。',
          mood: navigatorMoodFor(state, base: NavigatorMood.firstHire),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SkillSheet(営業用経歴)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('主な技術: ${languageLabels[engineer.profile.mainLanguage] ?? engineer.profile.mainLanguage.jsonValue}'),
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
          onCta: () {
            // Capture the NavigatorState once, up front — not the
            // BuildContext (bug found via Playwright E2E, see e2e/README.md
            // "Findings"). ClientInterviewScreen's onResultContinue fires
            // *later*, by which point answering the interview's one
            // follow-up question has already mutated GameState: that
            // mutation makes PrologueScreen's own (currently-occluded)
            // AnimatedBuilder re-derive `stage()` and swap this exact
            // Element's widget out from under it — a passed/failed Upper
            // Company Interview changes `stage()` on the very same frame.
            // Re-deriving Navigator.of(context) from that now-stale context
            // inside onResultContinue risked resolving against a defunct
            // element. `navigator` is a State belonging to the ancestor
            // Navigator, unaffected by that swap, so capturing it once and
            // checking `.mounted` — the same pattern PrologueInterviewScreen
            // already uses for the identical hazard below — sidesteps it.
            final navigator = Navigator.of(context);
            navigator.push(MaterialPageRoute(
              builder: (_) => ClientInterviewScreen(
                applicationId: proposal.id,
                step: SelectionStep.upperCompanyInterview,
                onResultContinue: () {
                  if (navigator.mounted) navigator.pop();
                },
              ),
            ));
          },
        ),
      ],
    );
  }
}

/// March Week 4, 客先面談 (Playable 0.5A §50-52, Playable 0.5A.1 §6).
///
/// Deliberately requires an explicit player tap between "客先面談が始まり
/// ました" and the pass/fail reveal — auto-resolving both in the same frame
/// (the previous behavior) was reported as "客先面談がなかったように感じ
/// る": nothing forced the player to actually notice the beat before the
/// result replaced it. The three-line rhythm below (総務の一言 → プレイヤー
/// 操作 → 総務のリアクション, §2) is what makes the client interview read
/// as a real, distinct step instead of a flash between two messages.
class _ClientInterviewAuto extends StatefulWidget {
  const _ClientInterviewAuto({required this.navigatorName, required this.state});
  final String navigatorName;
  final GameState state;
  @override
  State<_ClientInterviewAuto> createState() => _ClientInterviewAutoState();
}

class _ClientInterviewAutoState extends State<_ClientInterviewAuto> {
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final engineer = state.engineers.first;
    final proposal = state.proposals.firstWhere((p) => p.engineerId == engineer.id && p.status == ApplicationStatus.active);
    final session = state.clientInterviews.where((s) => s.applicationId == proposal.id && s.step == SelectionStep.clientInterview).toList();
    if (session.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigatorCard(
            navigatorName: widget.navigatorName,
            message: '上位会社面談 通過！\n\n次は客先面談です。社長であるあなたはこの面談に同席できません。${engineer.profile.name}さんに任せましょう。',
            ctaLabel: _resolving ? '結果を確認しています…' : '結果を確認する',
            onCta: _resolving
                ? null
                : () {
                    setState(() => _resolving = true);
                    context.game.autoResolveClientInterview(proposal.id);
                  },
          ),
        ],
      );
    }
    final s = session.first;
    final passed = s.result == ClientInterviewResult.passed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigatorCard(
          navigatorName: widget.navigatorName,
          message: passed
              ? '客先面談 合格！\n\n${engineer.profile.name}さんが選ばれました。'
              : '客先面談 不合格でした。\n\n残念でした。SES営業では珍しいことではありません。次の案件を探しましょう。',
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
        NavigatorCard(
          navigatorName: navigatorName,
          message: '${state.company.presidentName}社長、これで4月の入社と同時に案件へ参画できます！',
          mood: navigatorMoodFor(state, base: NavigatorMood.firstContract),
        ),
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

/// The Prologue's final beat (Playable 0.4C.4 §20): everything from company
/// setup through the client interview led here, so this uses the same
/// flagship [FirstContractCelebration] the "skip the tutorial" path shows
/// via [OneTimeEvent.firstAssignmentCelebration] — never a plainer,
/// prologue-only duplicate. `showPhaseTransition: false` because the
/// "会社経営スタート" line below already covers that beat with its own
/// paragraph.
class _Complete extends StatelessWidget {
  const _Complete({required this.state});
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final engineer = state.engineers.first;
    final assignment = state.activeAssignments.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FirstContractCelebration(assignment: assignment, employee: engineer, showPhaseTransition: false),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '━━━━━━━━━━━━\n「${state.company.name}」創業準備 完了 → 会社経営スタート\n━━━━━━━━━━━━',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Text('ここからは、社長の判断で会社を経営していきましょう。', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            // The "skip the tutorial" path's own first-assignment dialog
            // ([OneTimeEvent.firstAssignmentCelebration]) would otherwise
            // fire again the next time this player advances a week from
            // Home — this exact beat, shown a second time, right after
            // they already saw it above.
            context.game.markTutorialSeen(OneTimeEvent.firstAssignmentCelebration);
            context.game.completePrologue();
          },
          child: const Text('経営を始める'),
        ),
      ],
    );
  }
}
