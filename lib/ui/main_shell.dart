import 'package:flutter/material.dart';

import 'engineers/engineer_list_screen.dart';
import 'home/home_screen.dart';
import 'others/others_screen.dart';
import 'projects/project_list_screen.dart';
import 'recruitment/recruitment_screen.dart';
import 'widgets/phone_frame.dart';

/// Root shell: bottom navigation across the five Playable 0.1 tabs (§6).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

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
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(index: _index, children: _screens),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: _destinations,
        ),
      ),
    );
  }
}
