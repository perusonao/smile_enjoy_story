import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_project_generator.dart';
import 'public_demo_matching_project_card.dart';

/// CORE-GAMEPLAY Phase 5 (Matching): step 1 of the required player flow
/// ("案件を見る") — a mobile-first bottom sheet listing this month's real
/// Phase 4 project candidates ([candidates], from
/// `PublicDemoAggregate.projectCandidatesForMonth`). Purely presentational:
/// selecting a card only reports [onSelect]; it commits nothing itself.
class PublicDemoMatchingProjectListSheet extends StatelessWidget {
  const PublicDemoMatchingProjectListSheet({
    super.key,
    required this.candidates,
    required this.onSelect,
  });

  final List<PublicDemoProjectCandidate> candidates;
  final ValueChanged<PublicDemoProjectCandidate> onSelect;

  static Future<void> show(
    BuildContext context, {
    required List<PublicDemoProjectCandidate> candidates,
    required ValueChanged<PublicDemoProjectCandidate> onSelect,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PublicDemoMatchingProjectListSheet(
      candidates: candidates,
      onSelect: onSelect,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return Container(
      key: const Key('public-demo-matching-project-list-sheet'),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '今月の案件',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '案件を選ぶと、社員を選んで適合度を確認できます。',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
          Flexible(
            child: candidates.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('今月表示できる案件がありません。'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      return PublicDemoMatchingProjectCard(
                        key: Key(
                          'public-demo-matching-project-card-${candidate.id}',
                        ),
                        candidate: candidate,
                        onTap: () {
                          Navigator.pop(context);
                          onSelect(candidate);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
