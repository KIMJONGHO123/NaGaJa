import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_model.dart';
import 'daily_plan_service.dart';
import 'settings_service.dart';

/// Wi-Fi 기반 자동 출결 감지.
///
/// - 집 Wi-Fi(homeWifiSsids)에서 벗어나면 → 출발(departedAt) 자동 기록
/// - 학교 Wi-Fi(schoolWifiSsids)에 연결되면 → 도착(arrivedAt) 자동 기록
///
/// [현재 범위] 1·2단계: 앱이 활성/포그라운드 서비스로 살아있는 동안 동작.
///   완전 종료 상태의 백그라운드 감지(네이티브 BroadcastReceiver / FGS location 타입)는
///   3단계에서 팀 협의 후 진행 예정.
///
/// 안전장치: 디바운스(깜빡임 무시) + 시간창 가드(알람~수업+2h) + 멱등성(중복 방지).
class WifiAttendanceService extends ChangeNotifier {
  WifiAttendanceService._();
  static final instance = WifiAttendanceService._();

  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _netInfo = NetworkInfo();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;
  Timer? _poll;
  bool _running = false;
  bool _checking = false; // _check 재진입 방지 (폴링·이벤트 동시 실행 시 중복 기록 차단)

  /// 집 Wi-Fi에 접속한 적이 있는지 (출발 오탐 방지: 집을 본 적 없으면 출발로 보지 않음).
  /// 앱이 백그라운드로 상시 생존하므로 날짜가 바뀌면 리셋한다(_seenHomeDate).
  bool _seenHomeWifi = false;
  DateTime? _seenHomeDate;

  /// SSID 변화가 깜빡일 때 오작동 방지용 디바운스 시간.
  static const Duration _debounceDuration = Duration(seconds: 20);

  /// 두 Wi-Fi 간 이동(연결 타입 변화 없음)도 잡기 위한 주기 폴링.
  static const Duration _pollInterval = Duration(seconds: 60);

  bool get isRunning => _running;

  // ── 시작/중지 ──────────────────────────────────────────────────────────────
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _sub = _connectivity.onConnectivityChanged.listen((_) => _scheduleCheck());
    _poll = Timer.periodic(_pollInterval, (_) => _check());
    _scheduleCheck(); // 시작 시 1회
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    _debounce?.cancel();
    _debounce = null;
    _poll?.cancel();
    _poll = null;
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _check);
  }

  // ── 권한 / SSID 조회 (설정 등록 UI에서도 사용) ──────────────────────────────
  /// 위치 권한 요청 (Android는 SSID 조회에 위치 권한 필요). 허용되면 true.
  Future<bool> ensureLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// 백그라운드(앱 내림) 상태에서도 SSID를 읽기 위한 '항상 허용' 위치 권한 요청 (3-a).
  /// 선행 조건으로 전경 위치 권한이 먼저 허용돼야 한다. Android 11+는 OS가 설정 화면으로
  /// 유도하므로 즉시 허용되지 않을 수 있다(사용자가 "항상 허용" 선택 필요).
  /// 허용 실패해도 전경(앱 켜진 상태) 감지에는 영향 없음.
  Future<bool> ensureBackgroundLocationPermission() async {
    if (!await ensureLocationPermission()) return false;
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// 현재 연결된 Wi-Fi SSID. 권한/위치서비스/Wi-Fi 미연결 시 null.
  Future<String?> currentSsid() async {
    try {
      return _normalizeSsid(await _netInfo.getWifiName());
    } catch (_) {
      return null;
    }
  }

  /// Android는 SSID를 따옴표로 감싸 반환("name"). 따옴표 제거 + 무효값 정리.
  static String? _normalizeSsid(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      s = s.substring(1, s.length - 1);
    }
    if (s.isEmpty || s == '<unknown ssid>') return null;
    return s;
  }

  // ── 감지 본체 ──────────────────────────────────────────────────────────────
  // 한계(D): todayNextSchedule은 classTime이 아직 안 지난 수업만 반환하므로,
  // 수업 시작 후(지각) 도착은 그 수업에 자동으로 붙지 않을 수 있다.
  // 앱 전반이 todayNextSchedule에 의존하는 구조라 별도 개선 과제로 둔다.
  Future<void> _check() async {
    if (!_running || _checking) return; // (C) 재진입 방지
    _checking = true;
    try {
      final svc = SettingsService.instance;
      final user = svc.userModel;
      if (user == null) return;

      final home = user.homeWifiSsids;
      final school = user.schoolWifiSsids;
      if (home.isEmpty && school.isEmpty) return; // 등록된 SSID 없음

      final ScheduleEntry? sched = svc.todayNextSchedule;
      if (sched == null) return;
      final plan = DailyPlanService.instance.planForSchedule(sched.scheduleId);
      if (plan == null) return;

      final now = DateTime.now();
      final classStart = _classStart(sched, now);
      if (classStart == null) return;

      // 시간창 가드: 기상 알람 시각 ~ 수업 시작 +2시간 사이에서만 자동 처리
      final windowStart = plan.finalAlarmTime;
      final windowEnd = classStart.add(const Duration(hours: 2));
      if (now.isBefore(windowStart) || now.isAfter(windowEnd)) return;

      // (A) 날짜가 바뀌면 '집 Wi-Fi 본 적' 플래그 리셋 (백그라운드 상시 생존 대비)
      final today = DateTime(now.year, now.month, now.day);
      if (_seenHomeDate != today) {
        _seenHomeDate = today;
        _seenHomeWifi = false;
      }

      // (B) 연결 상태와 SSID를 함께 판단:
      //   - Wi-Fi 연결 중인데 ssid만 null = 읽기 실패 → 출발로 오인하지 않음
      //   - Wi-Fi 자체가 끊김(mobile/none) = 진짜 집을 떠난 신호
      final conn = await _connectivity.checkConnectivity();
      final onWifi = conn.contains(ConnectivityResult.wifi);
      final ssid = onWifi ? await currentSsid() : null;

      if (onWifi && ssid != null && home.contains(ssid)) _seenHomeWifi = true;

      // 도착: 학교 Wi-Fi 연결 + 아직 미도착
      if (plan.arrivedAt == null &&
          onWifi &&
          ssid != null &&
          school.contains(ssid)) {
        final resultStatus = now.isAfter(classStart) ? 'LATE' : 'ON_TIME';
        final dep = plan.departedAt;
        final actual = dep != null ? now.difference(dep).inMinutes : null;
        await DailyPlanService.instance.updateArrivedAt(
          sched.scheduleId,
          now,
          actualTravelMinutes: (actual != null && actual > 0) ? actual : null,
          resultStatus: resultStatus,
        );
        await DailyPlanService.instance.loadTodayPlans();
        if (kDebugMode) {
          debugPrint('[WifiAttendance] 도착 자동기록 ssid=$ssid status=$resultStatus');
        }
        notifyListeners();
        return;
      }

      // 출발: 집 Wi-Fi를 본 적 있고 + 미출발 + 실제로 집을 떠남
      //   (Wi-Fi 끊김 또는 집이 아닌 다른 Wi-Fi 접속. ssid만 null인 읽기 실패는 제외)
      final leftHome =
          _seenHomeWifi && (!onWifi || (ssid != null && !home.contains(ssid)));
      if (plan.departedAt == null && home.isNotEmpty && leftHome) {
        await DailyPlanService.instance.updateDepartedAt(sched.scheduleId, now);
        await DailyPlanService.instance.loadTodayPlans();
        if (kDebugMode) {
          debugPrint('[WifiAttendance] 출발 자동기록 (집 Wi-Fi 벗어남)');
        }
        notifyListeners();
      }
    } finally {
      _checking = false;
    }
  }

  DateTime? _classStart(ScheduleEntry sched, DateTime now) {
    final p = sched.classTime.split(':');
    if (p.length != 2) return null;
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(p[0]),
      int.parse(p[1]),
    );
  }
}
