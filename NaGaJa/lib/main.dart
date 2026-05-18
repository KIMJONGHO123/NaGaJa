import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/settings_service.dart';
import 'views/auth/login_screen.dart';
import 'views/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NagajaApp());
}

class NagajaApp extends StatelessWidget {
  const NagajaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nagaja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

// 로그인 상태를 스트림으로 감지해 화면을 자동으로 전환
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 아직 Firebase 응답 대기 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // 로그인 상태에 따라 화면 분기
        if (snapshot.hasData) {
          // 로그인 직후 Firestore에서 최신 설정 동기화
          SettingsService.instance.reloadFromFirestore();
          return const MainShell();
        }
        return const LoginScreen(); // 로그아웃 상태 → 로그인
      },
    );
  }
}
