// =============================================================================
// home_screen.dart — 메인 홈 화면
// 최소 실행은 위한 코드
// =============================================================================

import "package:flutter/material.dart";

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nagaja Home"), centerTitle: true),
      body: const Center(
        child: Text(
          "최소 실행 화면",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
