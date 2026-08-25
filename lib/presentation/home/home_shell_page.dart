import 'package:flutter/material.dart';

import 'widgets/brand_header.dart';
import 'widgets/company_status_section.dart';
import 'widgets/home_bottom_nav.dart';
import 'widgets/key_events_section.dart';
import 'widgets/kpi_section.dart';
import 'widgets/month_end_cta_section.dart';
import 'widgets/month_header_bar.dart';
import 'widgets/office_stage_section.dart';

/// The static outer shell of the home / management dashboard.
///
/// This is Phase 1A: it lays out every region of the dashboard (month
/// header, brand area, KPIs, office stage, key events, company status,
/// month-end CTA, bottom navigation) with static placeholder content only.
/// No employee-selection, event-priority, or financial-forecast logic lives
/// here — those are Phase 1B–1E's job. This screen does not read from or
/// write to the domain/game-state layer.
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  HomeNavTab _selectedTab = HomeNavTab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MonthHeaderBar(),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BrandHeader(),
                    _SectionGap(),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: KpiSection(),
                    ),
                    _SectionGap(),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: OfficeStageSection(),
                    ),
                    _SectionGap(),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: KeyEventsSection(),
                    ),
                    _SectionGap(),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: CompanyStatusSection(),
                    ),
                    _SectionGap(),
                    MonthEndCtaSection(),
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
