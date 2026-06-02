import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/alarm_service.dart';
import 'services/background_audio_service.dart';
import 'services/daily_plan_service.dart';
import 'services/settings_service.dart';
import 'views/auth/login_screen.dart';
import 'views/main_shell.dart';
import 'views/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AlarmService.instance.initialize();
  runApp(const NagajaApp());
}

class NagajaApp extends StatefulWidget {
  const NagajaApp({super.key});

  @override
  State<NagajaApp> createState() => _NagajaAppState();
}

class _NagajaAppState extends State<NagajaApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AlarmService.instance.startChecking(); // 포그라운드/백그라운드 모두 체크
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AlarmService.instance.stopChecking();
    BackgroundAudioService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        BackgroundAudioService.instance.start();
        break;
      case AppLifecycleState.resumed:
        BackgroundAudioService.instance.stop();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        BackgroundAudioService.instance.stop();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

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

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) return const LoginScreen();
        return const _UserRouter();
      },
    );
  }
}

/// 로그인 후: Firestore 확인 → 신규 유저면 users 문서 생성 → 스케줄 없으면 온보딩
class _UserRouter extends StatefulWidget {
  const _UserRouter();

  @override
  State<_UserRouter> createState() => _UserRouterState();
}

class _UserRouterState extends State<_UserRouter> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    SettingsService.instance.addListener(_onSettingsChanged);
    _init();
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    final svc = SettingsService.instance;

    // users 문서가 없으면 신규 생성
    final exists = await svc.userExists();
    if (!exists) {
      await svc.createNewUser();
    } else {
      await svc.reloadFromFirestore();
    }

    // 스케줄이 있으면 오늘의 dailyPlan 생성 (백그라운드)
    if (svc.schedules.isNotEmpty) {
      DailyPlanService.instance.generateDailyPlan().ignore();
    }

    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 스케줄이 하나도 없으면 → 온보딩
    if (SettingsService.instance.schedules.isEmpty) {
      return const OnboardingScreen();
    }

    return const MainShell();
  }
}
