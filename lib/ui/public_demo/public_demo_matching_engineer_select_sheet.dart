import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../../game/public_demo/public_demo_project_generator.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../widgets/fit_badge.dart';

/// CORE-GAMEPLAY Phase 5 (Matching): step 2 of the required player flow
/// ("社員を選ぶ") for [candidate] — a mobile-first bottom sheet listing
/// available engineers, each with only the bucketed ◎○△× [FitBadge]
/// (never the raw score — see this Issue's own "do not show only a number"
/// rule) computed by the caller via `MatchingEngine.computeFit` through
/// `PublicDemoMatchingProfile`. Purely presentational: selecting a row only
/// reports [onSelect].
class PublicDemoMatchingEngineerSelectSheet extends StatelessWidget {
  const PublicDemoMatchingEngineerSelectSheet({
    super.key,
    required this.candidate,
    required this.entries,
    required this.onSelect,
  });

  final PublicDemoProjectCandidate candidate;
  final List<PublicDemoMatchingEngineerEntry> entries;
  final ValueChanged<PublicDemoEngineerSales> onSelect;

  static Future<void> show(
    BuildContext context, {
    required PublicDemoProjectCandidate candidate,
    required List<PublicDemoMatchingEngineerEntry> entries,
    required ValueChanged<PublicDemoEngineerSales> onSelect,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PublicDemoMatchingEngineerSelectSheet(
      candidate: candidate,
      entries: entries,
      onSelect: onSelect,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return Container(
      key: const Key('public-demo-matching-engineer-select-sheet'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                candidate.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '社員を選んで、この案件との相性を確認します。',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ),
          ),
          Flexible(
            child: entries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('現在、提案できる社員がいません。'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Card(
                        key: Key(
                          'public-demo-matching-engineer-row-${entry.engineer.id}',
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(entry.engineer.name),
                          subtitle: Text(
                            entry.engineer.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: FitBadge(fit: entry.fit),
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(entry.engineer);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// One row's worth of already-computed, already-bucketed data for
/// [PublicDemoMatchingEngineerSelectSheet] — the screen computes [fit] via
/// `PublicDemoMatchingProfile.engineerForMatching` +
/// `MatchingEngine.computeFit` so this widget never touches the Matching
/// authority itself, only renders its already-bucketed result.
class PublicDemoMatchingEngineerEntry {
  const PublicDemoMatchingEngineerEntry({
    required this.engineer,
    required this.fit,
  });

  final PublicDemoEngineerSales engineer;
  final PlayerVisibleFit fit;
}
