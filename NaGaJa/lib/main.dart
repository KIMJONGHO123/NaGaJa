import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'services/alarm_service.dart';
import 'services/background_audio_service.dart';
import 'services/settings_service.dart';
import 'views/alarm/alarm_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/main_shell.dart';
import 'views/onboarding/onboarding_screen.dart';

// 도커로 테스트 할 때만 추가
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// 도커로 테스트 할 때만 추가

// 앱 전역 NavigatorKey — AlarmService에서 컨텍스트 없이 AlarmScreen으로 navigate할 때 사용
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 로드 (KAKAO_REST_API_KEY 등). 파일이 없어도 앱이 죽지 않도록 무시.
  await dotenv.load(fileName: '.env').catchError((_) {});
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firebase.initializeApp() 직후 삽입 도커로 테스트할 때만 추가
  if (kDebugMode) {
    // Android 에뮬레이터 전용 loopback 주소 (호스트 PC의 localhost를 가리킴)
    // 실제 스마트폰: PC의 IPv4 주소 (ipconfig로 확인)
    const host = '10.0.2.2';
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  }
  //도커로 테스트할 때만 추가

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
    AlarmService.instance.alarmFiredNotifier.addListener(_onAlarmFired);
    // initialize()가 runApp() 이전에 실행됐을 경우 초기값 체크
    if (AlarmService.instance.alarmFiredNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onAlarmFired());
    }
  }

  @override
  void dispose() {
    AlarmService.instance.alarmFiredNotifier.removeListener(_onAlarmFired);
    WidgetsBinding.instance.removeObserver(this);
    AlarmService.instance.stopChecking();
    BackgroundAudioService.instance.stop();
    super.dispose();
  }

  bool _alarmScreenShowing = false;

  void _onAlarmFired() {
    if (!AlarmService.instance.alarmFiredNotifier.value) return;
    if (_alarmScreenShowing) return;
    _alarmScreenShowing = true;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const AlarmScreen()),
    ).then((_) => _alarmScreenShowing = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        AlarmService.instance.setAppInForeground(false);
        BackgroundAudioService.instance.start();
        break;
      case AppLifecycleState.resumed:
        AlarmService.instance.setAppInForeground(true);
        BackgroundAudioService.instance.stop();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        AlarmService.instance.setAppInForeground(false);
        BackgroundAudioService.instance.stop();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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

    // dailyPlan 생성은 백엔드 스케줄러(4시 + 알람 30분 전 계산) 담당.
    // 앱은 생성하지 않고 loadTodayPlans로 조회만 한다.

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
