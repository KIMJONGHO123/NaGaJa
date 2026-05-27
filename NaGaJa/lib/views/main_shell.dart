// =============================================================================
// main_shell.dart — 앱 전체 화면을 감싸는 네비게이션 쉘
//
// [역할]
//   앱의 3개 주요 탭(홈·캘린더·설정)을 하단 NavigationBar로 전환하는 뼈대 위젯.
//   실제 각 화면 구현은 HomeScreen, CalendarScreen, SettingsScreen에서 담당.
// =============================================================================

import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 현재 선택된 탭 인덱스 (0=홈, 1=캘린더, 2=설정)
  int _index = 0;

  // [핵심 설계]
  // 화면 목록을 const로 미리 생성해 둡니다.
  // IndexedStack이 이 목록을 사용해 화면을 전환합니다.
  final _screens = const [
    HomeScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [IndexedStack 선택 이유]
      // Navigator.push/pop 방식과 달리, IndexedStack은 모든 화면을 메모리에
      // 유지한 채 보이는 화면만 전환합니다.
      // → 탭을 오갈 때 스크롤 위치·입력값 등 각 화면의 상태가 초기화되지 않음.
      body: IndexedStack(index: _index, children: _screens),

      // Material 3 기반 하단 네비게이션 바
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        // 탭 선택 시 setState로 _index를 바꿔 IndexedStack이 해당 화면을 표시
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home), // 선택됐을 때 채워진 아이콘으로 교체
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '캘린더',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
