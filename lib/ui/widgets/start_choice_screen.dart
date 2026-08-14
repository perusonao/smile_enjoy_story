import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../theme.dart';

/// New-game entry point (§41-42): pick guided onboarding or jump straight
/// into free management with every feature already unlocked.
class StartChoiceScreen extends StatelessWidget {
  const StartChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.business_center_outlined, size: 56, color: SesTheme.primaryBlue),
              const SizedBox(height: 16),
              Text(
                'S.E.S.\nSmile. Enjoy. Story.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.game.chooseBeginnerStart(),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('【初心者モード】おすすめ'),
              ),
              const SizedBox(height: 6),
              const Text(
                '創業プロローグから始めます。会社を立ち上げ、最初の技術者を採用し、最初の案件を獲得するまでを体験できます。初めての方はこちら。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.game.chooseFreeStart(),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('【自由モード】'),
              ),
              const SizedBox(height: 6),
              const Text(
                '最初から自由に経営します。案内なしで全ての機能を最初から使います。経験者向け。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
