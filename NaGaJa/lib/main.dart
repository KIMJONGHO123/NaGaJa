import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/settings_service.dart';
import 'views/auth/login_screen.dart';
import 'views/main_shell.dart';
import 'views/onboarding/onboarding_screen.dart';

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

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 로그인 상태 → 설정 로드 후 온보딩 여부 판단
        return _UserRouter(user: snapshot.data!);
      },
    );
  }
}

// 로그인된 유저의 Firestore 상태를 확인해 화면 분기
class _UserRouter extends StatefulWidget {
  final User user;
  const _UserRouter({required this.user});

  @override
  State<_UserRouter> createState() => _UserRouterState();
}

class _UserRouterState extends State<_UserRouter> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    SettingsService.instance.addListener(_onSettingsChanged);
    _checkOnboarding();
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkOnboarding() async {
    final svc = SettingsService.instance;
    await svc.reloadFromFirestore();

    if (svc.userModel == null) {
      await svc.createNewUser();
    }

    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!SettingsService.instance.isOnboardingComplete) {
      return const OnboardingScreen();
    }

    return const MainShell();
  }
}
