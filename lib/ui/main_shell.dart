import 'package:flutter/material.dart';

import '../app/nav_scope.dart';
import 'engineers/engineer_list_screen.dart';
import 'home/home_screen.dart';
import 'others/others_screen.dart';
import 'projects/project_list_screen.dart';
import 'recruitment/recruitment_screen.dart';
import 'widgets/phone_frame.dart';

/// Bottom-nav tab indices, shared with anything that calls
/// `context.switchTab(...)` (Playable 0.2 §5 task navigation).
class SesTab {
  static const int home = 0;
  static const int employees = 1;
  static const int recruitment = 2;
  static const int projects = 3;
  static const int others = 4;
}

/// Root shell: bottom navigation across the five Playable 0.1 tabs (§6).
///
/// The selected tab lives in [NavScope] rather than local State, so any
/// screen can jump to another tab (e.g. tapping a Home task).
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _screens = [
    HomeScreen(),
    EngineerListScreen(),
    RecruitmentScreen(),
    ProjectListScreen(),
    OthersScreen(),
  ];

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'ホーム'),
    NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: '社員'),
    NavigationDestination(icon: Icon(Icons.person_search_outlined), selectedIcon: Icon(Icons.person_search), label: '採用'),
    NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: '案件'),
    NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'その他'),
  ];

  @override
  Widget build(BuildContext context) {
    final tabIndex = NavScope.of(context);
    return PhoneFrame(
      child: ValueListenableBuilder<int>(
        valueListenable: tabIndex,
        builder: (context, index, _) {
          return Scaffold(
            body: SafeArea(
              child: IndexedStack(index: index, children: _screens),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => tabIndex.value = i,
              destinations: _destinations,
            ),
          );
        },
      ),
    );
  }
}
