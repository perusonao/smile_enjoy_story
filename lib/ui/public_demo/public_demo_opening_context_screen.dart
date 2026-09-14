import 'package:flutter/material.dart';

import '../../presentation/home/models/home_navigator_display.dart';
import '../theme.dart';
import 'public_demo_mission_screen.dart' show publicDemoAprilHeadlineGoal;

/// FIRST-FUN-YEAR P1 (Issue #229) / SES First Fun Quarter Mission System
/// Phase 2 (Progressive Onboarding): Public Demo's Opening Context — shown
/// once, before a brand-new playthrough's first April, so a first-time
/// player understands what the game asks of them before the normal monthly
/// operations begin.
///
/// Phase 2 redesign (`docs/design/
/// SES_FIRST-FUN-QUARTER_MISSION-ONBOARDING_Implementation-Plan.md` §5.1,
/// per the governing task's own "会社設立 → ひよりの短い説明 → 4月の目標 →
/// 経営開始" flow): a short, "次へ" ("Next") paged sequence instead of one
/// long scrollable list. This is a **presentation-shape change only** — the
/// underlying facts shown ([startingCash], [monthlyFixedCost],
/// [founders].length) are still supplied by the caller and read straight
/// from existing Finance/Payroll/roster authority, never hardcoded or
/// recomputed here (Issue #229's "金額や倒産までの月数をcopyへハードコード
/// しないこと", extended to "社員人数をhard-codeしない" per the Phase 2 task).
/// This widget still never reads [PublicDemoAggregate], [PublicDemoState],
/// or any save — the owning screen resolves everything this widget needs
/// before building it.
///
/// Phase 2 "Critical change": the pre-Phase-2 screen offered two competing
/// CTAs ("まずSkillSheetで2人を確認する" / "4月の経営を始める"), which framed
/// SkillSheet confirmation as something to do *before* real play. There was
/// never an actual domain-level gate forcing SkillSheet confirmation before
/// management could start (both buttons already dismissed this screen and
/// let the player into HOME/社員); this Phase 2 redesign instead removes the
/// dual-CTA framing itself — a single CTA ("経営を始める") ends the flow, and
/// SkillSheet confirmation is surfaced only as April Mission #1 (see
/// `public_demo_mission_screen.dart`), reached "when it becomes necessary"
/// rather than presented as a pre-management checklist item.
///
/// The navigator is 佐倉ひより, the Public Demo's existing 総務/navigator
/// character (see [HomeNavigatorIdentity]) — not a new character or a fresh
/// placeholder image.
class PublicDemoOpeningContextScreen extends StatefulWidget {
  const PublicDemoOpeningContextScreen({
    super.key,
    required this.startingCash,
    required this.monthlyFixedCost,
    required this.founders,
    required this.onStart,
  });

  /// The company's cash at company founding, verbatim from
  /// `PublicDemoState.aprilStart().cash` — never a value this widget itself
  /// derives.
  final int startingCash;

  /// The company's baseline monthly fixed cost (founding salaries + other
  /// fixed cost), verbatim from `PublicDemoSalary.baselineMonthlyExpenses`.
  final int monthlyFixedCost;

  /// Issue #245 Finding #1: the founding engineer roster, verbatim from
  /// `publicDemoInitialEngineers` (`name`/`summary` only — both already
  /// player-facing in SkillSheet/Matching, never a hidden interview-profile
  /// value). This widget never invents a founder or a differentiator of its
  /// own; it only renders what the caller supplies. Its `.length` is also
  /// the single source for every "◯名の技術者" sentence below — never a
  /// separately hardcoded headcount.
  final List<PublicDemoOpeningFounder> founders;

  /// Dismisses the Opening Context and proceeds into April/HOME. The owning
  /// screen is responsible for recording that this browser has seen it
  /// (`PublicDemoOpeningMarker.markSeen`) — this widget only ever calls it.
  /// Phase 2: this is now the flow's only exit — see this file's top-of-file
  /// doc for why the former second ("SkillSheet-first") CTA was removed
  /// rather than kept alongside a paged redesign.
  final VoidCallback onStart;

  @override
  State<PublicDemoOpeningContextScreen> createState() =>
      _PublicDemoOpeningContextScreenState();
}

/// Builds one "次へ"-flow page's content. Each of
/// [_PublicDemoOpeningContextScreenState]'s `_build*Page` methods matches
/// this signature — see `_pages` below for the fixed page order.
typedef _PageBuilder = Widget Function(BuildContext context);

class _PublicDemoOpeningContextScreenState
    extends State<PublicDemoOpeningContextScreen> {
  int _pageIndex = 0;

  late final List<_PageBuilder> _pages = [
    _buildWelcomePage,
    _buildRosterPage,
    _buildGoalPage,
    _buildFinancePage,
    _buildFinalPage,
  ];

  void _next() {
    if (_pageIndex >= _pages.length - 1) return;
    setState(() => _pageIndex += 1);
  }

  void _back() {
    if (_pageIndex <= 0) return;
    setState(() => _pageIndex -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _pageIndex == _pages.length - 1;
    return Scaffold(
      key: const Key('public-demo-opening-context-screen'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${_pageIndex + 1} / ${_pages.length}',
                    key: const Key('public-demo-opening-page-indicator'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SingleChildScrollView(
                  key: ValueKey('public-demo-opening-page-$_pageIndex'),
                  child: _pages[_pageIndex](context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (_pageIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('public-demo-opening-back-button'),
                        onPressed: _back,
                        child: const Text('もどる'),
                      ),
                    ),
                  if (_pageIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: Key(
                        isLast
                            ? 'public-demo-opening-start-button'
                            : 'public-demo-opening-next-button',
                      ),
                      onPressed: isLast ? widget.onStart : _next,
                      child: Text(isLast ? '経営を始める' : '次へ'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1/5 — 会社設立 + ひよりの短い説明の導入。
  Widget _buildWelcomePage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _NavigatorIntro(),
        const SizedBox(height: 20),
        const _OpeningSection(
          key: Key('public-demo-opening-goal'),
          icon: Icons.flag_outlined,
          title: '会社設立、おめでとうございます！',
          body:
              '今日からSES会社の経営が始まります。技術者を案件へ参画させ、'
              '取引先から売上を得ながら、1年間(4月〜翌3月)会社を経営して'
              'いくことが目標です。',
        ),
      ],
    );
  }

  // 2/5 — 社員紹介。人数は founders.length から、名前は
  // publicDemoInitialEngineers 由来の founders から、それぞれ実データで表示。
  Widget _buildRosterPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OpeningSection(
          key: const Key('public-demo-opening-roster-intro'),
          icon: Icons.groups_outlined,
          title: '社員の紹介',
          body:
              '最初は${widget.founders.length}名の技術者と一緒にスタートします。'
              '社員の状況は『社員』タブからいつでも確認できます。',
        ),
        const SizedBox(height: 10),
        _FoundingRosterSection(founders: widget.founders),
      ],
    );
  }

  // 3/5 — 4月の目標。文言は Mission 画面の見出しと同一の定数
  // (publicDemoAprilHeadlineGoal) を参照し、二重管理によるdriftを防ぐ。
  Widget _buildGoalPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OpeningSection(
          key: const Key('public-demo-opening-goal-detail'),
          icon: Icons.emoji_events_outlined,
          title: '4月の目標',
          body: 'まずは$publicDemoAprilHeadlineGoal。'
              'SkillSheetの確認や営業など、必要な操作はMISSIONが順番に案内します。',
        ),
      ],
    );
  }

  // 4/5 — 資金。金額はすべて caller から渡された実データ。
  Widget _buildFinancePage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OpeningSection(
          key: const Key('public-demo-opening-cash'),
          icon: Icons.account_balance_wallet_outlined,
          title: '会社の資金',
          body:
              '会社には ${formatYen(widget.startingCash)} の資金があります。'
              '給与や営業費用として、毎月 ${formatYen(widget.monthlyFixedCost)} '
              '前後の支出がかかります。支出を考えながら経営してください。',
        ),
        const SizedBox(height: 10),
        const _OpeningSection(
          key: Key('public-demo-opening-risk'),
          icon: Icons.warning_amber_outlined,
          title: '注意',
          body: '売上がない月が続くと、固定費の分だけ資金が減っていきます。'
              '資金が尽きると倒産につながるため、早めに案件への参画を進めましょう。',
          tone: _OpeningSectionTone.caution,
        ),
      ],
    );
  }

  // 5/5 — MISSION の案内 + CTA。
  Widget _buildFinalPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _OpeningSection(
          key: Key('public-demo-opening-mission-guide'),
          icon: Icons.explore_outlined,
          title: '迷ったらMISSIONを確認',
          body: '画面右上のミッションアイコンから、次に何を目指せばよいか'
               'いつでも確認できます。',
        ),
      ],
    );
  }
}

/// Issue #245 Finding #1: a founding engineer's player-facing name/summary,
/// verbatim from `publicDemoInitialEngineers` — never a new field, never a
/// hidden interview-profile value.
class PublicDemoOpeningFounder {
  const PublicDemoOpeningFounder({required this.name, required this.summary});

  final String name;
  final String summary;
}

/// Introduces the founding engineers by name and their existing `summary`
/// text (already shown in SkillSheet/Matching) so a first-time player knows
/// who they are before being asked to open SkillSheet. Deliberately reuses
/// only already-truthful, already player-facing text — no new score, no
/// fabricated differentiator.
class _FoundingRosterSection extends StatelessWidget {
  const _FoundingRosterSection({required this.founders});

  final List<PublicDemoOpeningFounder> founders;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('public-demo-opening-founders'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                '創業メンバー',
                style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final founder in founders)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: founder.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const TextSpan(text: '　'),
                    TextSpan(
                      text: founder.summary,
                      style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _OpeningSectionTone { normal, caution }

class _OpeningSection extends StatelessWidget {
  const _OpeningSection({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.tone = _OpeningSectionTone.normal,
  });

  final IconData icon;
  final String title;
  final String body;
  final _OpeningSectionTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCaution = tone == _OpeningSectionTone.caution;
    final accent = isCaution ? const Color(0xFFB3261E) : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCaution
            ? const Color(0xFFB3261E).withValues(alpha: 0.06)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: accent),
                ),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The ひより portrait/name introduction, at the top of the first page.
///
/// Reuses [HomeNavigatorIdentity]'s existing name/role/portrait constants —
/// the same face and name HOME's own [HomeNavigatorSection] already shows —
/// rather than introducing a new character or a placeholder image. Falls
/// back to a plain icon if the bundled asset fails to decode, the same
/// degrade path [HomeNavigatorSection]'s own portrait already uses.
class _NavigatorIntro extends StatelessWidget {
  const _NavigatorIntro();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = HomeNavigatorIdentity.portraitAssetFor(
      NavigatorExpression.normal,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: path == null
                  ? Icon(Icons.person, color: scheme.onSurfaceVariant)
                  : Image.asset(
                      path,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, color: scheme.onSurfaceVariant),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${HomeNavigatorIdentity.role} ${HomeNavigatorIdentity.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'はじめまして。総務の佐倉です。これからこの会社の経営を一緒に'
                '進めましょう。まずは簡単にご案内しますね。',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
