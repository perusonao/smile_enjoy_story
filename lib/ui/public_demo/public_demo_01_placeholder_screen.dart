import 'package:flutter/material.dart';

/// Deliberate PR #1 boundary: Public Demo owns a distinct entry and save
/// namespace, but its gameplay is introduced in later PRs.
class PublicDemo01PlaceholderScreen extends StatelessWidget {
  const PublicDemo01PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public_outlined, size: 56),
              SizedBox(height: 16),
              Text('S.E.S. Public Demo 0.1', textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text(
                'Public Demo本体は準備中です。',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
