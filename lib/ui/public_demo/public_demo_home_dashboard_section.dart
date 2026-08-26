import 'package:flutter/material.dart';

import '../../presentation/home/models/home_dashboard_display_data.dart';
import '../../presentation/home/widgets/kpi_section.dart';
import '../../presentation/home/widgets/month_header_bar.dart';

/// The Public Demo screen's read-only mount point for the new HOME
/// dashboard display (HOME-RUNTIME-READ-1).
///
/// This is the whole integration surface between the Public Demo runtime
/// and the new HOME presentation, and it is deliberately one-directional:
///
///  * It accepts an already-built [HomeDashboardDisplayData] — never a
///    `PublicDemoState`, never a `PublicDemoAggregate`. The projection is
///    derived by the authoritative owner
///    (`PublicDemo01PlaceholderScreen`) while it builds, from the
///    aggregate it owns, and injected here through the constructor. So no
///    raw authoritative state reaches HOME at all, and HOME cannot reach
///    back for more than the projected fields.
///  * It passes no callbacks, commands, or mutation APIs downstream. The
///    HOME widgets below are pure display; there is no path from anything
///    rendered here back into `PublicDemoAggregate`.
///  * It holds no state of its own. Every rebuild of the owning screen
///    (i.e. every `setState` after a domain command) produces a freshly
///    projected [data], so nothing here can go stale or become a second
///    source of truth.
///
/// The Public Demo screen keeps all of its existing UI — this section is
/// added alongside it, not in place of it, and `HomeShellPage` itself
/// remains unwired from the app's navigation.
class PublicDemoHomeDashboardSection extends StatelessWidget {
  const PublicDemoHomeDashboardSection({super.key, required this.data});

  /// The read-only projection to display. Rebuilt from authoritative state
  /// by the owning screen on every build — see the class doc.
  final HomeDashboardDisplayData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('public-demo-home-dashboard-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthHeaderBar(data: data),
        const SizedBox(height: 12),
        KpiSection(data: data),
        const SizedBox(height: 12),
      ],
    );
  }
}
