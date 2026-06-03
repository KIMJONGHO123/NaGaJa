import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AlarmService {
  AlarmService._();
  static final instance = AlarmService._();

  static const _notifId = 42;
  static const _channelId = 'nagaja_alarm';
  static const _channel = MethodChannel('com.nagaja.app/background_audio');

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _checkTimer;
  DateTime? _scheduledTime;
  bool _fired = false;

  bool get isAlarmFired => _fired;

  // 알람 발사 상태를 외부(main.dart)에 알려 AlarmScreen으로 navigate하게 함
  final alarmFiredNotifier = ValueNotifier<bool>(false);

  // ── 초기화 ──────────────────────────────────────────────────

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    // Android 알람 채널: AudioAttributesUsage.alarm → 방해금지 우회 + 알람 볼륨 사용
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        '기상 알람',
        description: '나가자 기상 알람',
        importance: Importance.max,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        playSound: true,
      );
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      // Android 14+에서 전체화면 인텐트 권한 요청
      await androidPlugin?.requestFullScreenIntentPermission();
    }

    // 앱이 알림 탭으로 실행된 경우 알람 발사 상태 복원
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _fired = true;
      alarmFiredNotifier.value = true;
    }
  }

  // ── OS 알람 예약 ───────────────────────────────────────────

  Future<void> scheduleAlarm(DateTime alarmTime) async {
    if (alarmTime.isBefore(DateTime.now())) return;
    _scheduledTime = alarmTime;
    _fired = false;
    await _plugin.cancel(_notifId);

    final tzTime = tz.TZDateTime.from(alarmTime, tz.local);
    await _plugin.zonedSchedule(
      _notifId,
      '기상 알람',
      '일어날 시간입니다! 나가자',
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          '기상 알람',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          actions: [
            AndroidNotificationAction(
              'dismiss',
              '알람 해제',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('[AlarmService] scheduled at $alarmTime');
  }

  // ── 백그라운드 타이머 (앱이 살아있을 때 30초마다 체크) ───────

  void startChecking() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  void stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void _check() {
    if (_scheduledTime == null || _fired) return;
    if (DateTime.now().isAfter(_scheduledTime!)) _fireAlarm();
  }

  void _fireAlarm() {
    _fired = true;
    alarmFiredNotifier.value = true;
    debugPrint('[AlarmService] alarm fired!');
    if (Platform.isAndroid) {
      // RingtoneManager로 기기 기본 알람음 재생 (content:// URI는 MethodChannel로 처리)
      _channel.invokeMethod('playAlarmSound').catchError((e) {
        debugPrint('[AlarmService] playAlarmSound error: $e');
      });
    }
    _showImmediateNotification();
  }

  // zonedSchedule은 앱이 완전히 종료됐을 때의 백업.
  // 앱이 살아있을 때는 여기서 즉시 발사해야 heads-up 팝업으로 표시됨.
  // playSound: false → 소리는 RingtoneManager가 이미 담당.
  Future<void> _showImmediateNotification() async {
    await _plugin.show(
      _notifId,
      '기상 알람 🔔',
      '일어날 시간입니다! 나가자',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          '기상 알람',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          playSound: false,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          actions: [
            AndroidNotificationAction(
              'dismiss',
              '알람 해제',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      ),
    );
  }

  // ── 알람 해제 ────────────────────────────────────────────────

  Future<void> dismissAlarm() async {
    _fired = false;
    _scheduledTime = null;
    alarmFiredNotifier.value = false;
    if (Platform.isAndroid) {
      await _channel.invokeMethod('stopAlarmSound').catchError((e) {
        debugPrint('[AlarmService] stopAlarmSound error: $e');
      });
    }
    await _plugin.cancel(_notifId);
    debugPrint('[AlarmService] dismissed');
  }
}

// 알림 탭/액션 콜백 — 앱이 살아있을 때 (포그라운드/백그라운드 모두)
void _onNotificationTap(NotificationResponse response) {
  if (response.actionId == 'dismiss') {
    // 알림 "알람 해제" 액션 버튼 → 바로 해제
    AlarmService.instance.dismissAlarm();
  } else {
    // 알림 본문 탭 → 아직 발사 안 됐으면 발사, 이미 발사됐으면 notifier 재트리거
    final svc = AlarmService.instance;
    if (!svc._fired) {
      svc._fireAlarm();
    } else {
      // 이미 발사 상태이지만 AlarmScreen이 없을 수 있으므로 다시 트리거
      svc.alarmFiredNotifier.value = false;
      svc.alarmFiredNotifier.value = true;
    }
  }
}

// 알림 탭/액션 콜백 — 앱이 완전히 종료된 상태에서 알림을 탭했을 때
// top-level 함수여야 하며 @pragma 필수
@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  if (response.actionId == 'dismiss') {
    AlarmService.instance.dismissAlarm();
  }
  // 본문 탭: initialize()의 getNotificationAppLaunchDetails()가 처리
}
