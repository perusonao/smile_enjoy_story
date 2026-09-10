import 'package:flutter/material.dart';

import '../../presentation/home/models/home_navigator_display.dart';
import '../theme.dart';

/// FIRST-FUN-YEAR P1 (Issue #229): Public Demo's Opening Context — shown
/// once, before a brand-new playthrough's first April, so a first-time
/// player understands what the game asks of them before the normal monthly
/// operations begin.
///
/// Pure presentation: every figure it shows ([startingCash],
/// [monthlyFixedCost]) is supplied by the caller, which reads them straight
/// from the existing Finance/Payroll authority
/// (`PublicDemoState.aprilStart().cash` /
/// `PublicDemoSalary.baselineMonthlyExpenses`) — this widget never computes,
/// estimates, or hardcodes either value, and it introduces no new
/// gameplay/balance rule of its own (Issue #229's "金額や倒産までの月数を
/// copyへハードコードしないこと"). It never reads [PublicDemoAggregate],
/// [PublicDemoState], or any save — the owning screen resolves everything
/// this widget needs before building it.
///
/// The navigator is 佐倉ひより, the Public Demo's existing 総務/navigator
/// character (see [HomeNavigatorIdentity]) — not a new character or a fresh
/// placeholder image.
class PublicDemoOpeningContextScreen extends StatelessWidget {
  const PublicDemoOpeningContextScreen({
    super.key,
    required this.startingCash,
    required this.monthlyFixedCost,
    required this.onStart,
  });

  /// The company's cash at company founding, verbatim from
  /// `PublicDemoState.aprilStart().cash` — never a value this widget itself
  /// derives.
  final int startingCash;

  /// The company's baseline monthly fixed cost (founding salaries + other
  /// fixed cost), verbatim from `PublicDemoSalary.baselineMonthlyExpenses`.
  final int monthlyFixedCost;

  /// Dismisses the Opening Context and proceeds into April. The owning
  /// screen is responsible for recording that this browser has seen it
  /// (`PublicDemoOpeningMarker.markSeen`) — this widget only ever calls it.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('public-demo-opening-context-screen'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          children: [
            _NavigatorIntro(),
            const SizedBox(height: 16),
            Text(
              '経営を始める前に',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const _OpeningSection(
              key: Key('public-demo-opening-goal'),
              icon: Icons.flag_outlined,
              title: '目的',
              body: '技術者を案件へ参画させ、取引先から売上を得ながら、'
                  '1年間(4月〜翌3月)会社を経営していくことが目標です。',
            ),
            const SizedBox(height: 10),
            _OpeningSection(
              key: const Key('public-demo-opening-cash'),
              icon: Icons.account_balance_wallet_outlined,
              title: '初期資金',
              body: '会社の現預金は ${formatYen(startingCash)} からスタートします。',
            ),
            const SizedBox(height: 10),
            _OpeningSection(
              key: const Key('public-demo-opening-fixed-cost'),
              icon: Icons.receipt_long_outlined,
              title: '毎月の固定費',
              body: '給与や家賃などの固定費として、毎月 ${formatYen(monthlyFixedCost)} '
                  '前後の支出がかかります。',
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
            const SizedBox(height: 10),
            const _OpeningSection(
              key: Key('public-demo-opening-first-step'),
              icon: Icons.play_circle_outline,
              title: '最初にすること',
              body: 'まずは4月、社員の状況を確認しながら、案件への参画や営業を進めていきましょう。',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('public-demo-opening-start-button'),
                onPressed: onStart,
                child: const Text('4月の経営を始める'),
              ),
            ),
          ],
        ),
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

/// The ひより portrait/name introduction, at the top of the Opening Context.
///
/// Reuses [HomeNavigatorIdentity]'s existing name/role/portrait constants —
/// the same face and name HOME's own [HomeNavigatorSection] already shows —
/// rather than introducing a new character or a placeholder image. Falls
/// back to a plain icon if the bundled asset fails to decode, the same
/// degrade path [HomeNavigatorSection]'s own portrait already uses.
class _NavigatorIntro extends StatelessWidget {
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
                'はじめまして。総務の佐倉です。これからこの会社の経営を一緒に進めましょう。'
                'まずは経営の前提を簡単にご案内します。',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
