import 'package:flutter/material.dart';

import 'models/home_dashboard_display_data.dart';
import 'widgets/brand_header.dart';
import 'widgets/company_status_section.dart';
import 'widgets/home_bottom_nav.dart';
import 'widgets/key_events_section.dart';
import 'widgets/kpi_section.dart';
import 'widgets/month_end_cta_section.dart';
import 'widgets/month_header_bar.dart';
import 'widgets/office_stage_section.dart';

/// The outer shell of the home / management dashboard.
///
/// This started as Phase 1A's static layout (month header, brand area,
/// KPIs, office stage, key events, company status, month-end CTA, bottom
/// navigation) with placeholder content only. HOME-UI-1C: [dashboardData],
/// when supplied, threads a read-only [HomeDashboardDisplayData] projection
/// into the month header and KPI section so they can show real figures
/// instead of placeholders — event-priority, financial-forecast, and
/// employee-visual-projection logic are still later phases' job, and this
/// screen still never reads from or writes to the domain/game-state layer
/// itself (a caller builds [dashboardData] from authoritative state and
/// passes it in). [dashboardData] stays optional and defaults to `null`,
/// which keeps every existing placeholder-content behavior for callers that
/// don't pass it. This screen also remains unwired from the app's own
/// runtime/navigation (see lib/main.dart, which HOME-UI-1C does not touch).
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, this.dashboardData});

  final HomeDashboardDisplayData? dashboardData;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  HomeNavTab _selectedTab = HomeNavTab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MonthHeaderBar(data: widget.dashboardData),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(),
                    const _SectionGap(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: KpiSection(data: widget.dashboardData),
                    ),
                    const _SectionGap(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: OfficeStageSection(),
                    ),
                    const _SectionGap(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: KeyEventsSection(),
                    ),
                    const _SectionGap(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: CompanyStatusSection(),
                    ),
                    const _SectionGap(),
                    const MonthEndCtaSection(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: HomeBottomNav(
        selected: _selectedTab,
        onSelected: (tab) => setState(() => _selectedTab = tab),
      ),
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 16);
}
