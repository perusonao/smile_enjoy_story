import 'package:flutter/material.dart';

/// The 5 top-level tabs of the app.
///
/// Phase 1A only renders the bar and tracks which tab is highlighted; the
/// other 4 destinations don't have screens yet, so selecting them does not
/// navigate anywhere.
enum HomeNavTab { home, employees, sales, recruiting, management }

class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final HomeNavTab selected;
  final ValueChanged<HomeNavTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: selected.index,
      onTap: (index) => onSelected(HomeNavTab.values[index]),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'ホーム',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.groups_outlined),
          activeIcon: Icon(Icons.groups),
          label: '社員',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.storefront_outlined),
          activeIcon: Icon(Icons.storefront),
          label: '営業',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_add_alt_outlined),
          activeIcon: Icon(Icons.person_add_alt),
          label: '採用',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.insights_outlined),
          activeIcon: Icon(Icons.insights),
          label: '経営',
        ),
      ],
    );
  }
}
