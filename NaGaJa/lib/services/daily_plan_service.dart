import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import '../models/user_model.dart';

class DailyPlanModel {
  final String dailyPlanId;
  final String scheduleId;
  final DateTime finalDepartureTime;
  final DateTime finalAlarmTime;
  final int predictedTravelMinutes;
  final String displayColor; // GREEN | YELLOW | RED
  final String weatherType;
  final int congestionAdjustMinutes;
  final int weatherAdjustMinutes;
  final int remainingMarginMinutes;
  final String planStatus;
  final String? selectedRouteNo;
  final bool weatherApplied;
  final bool congestionApplied;
  final bool fallbackUsed;
  final DateTime? departedAt;
  final DateTime? arrivedAt;

  const DailyPlanModel({
    required this.dailyPlanId,
    required this.scheduleId,
    required this.finalDepartureTime,
    required this.finalAlarmTime,
    required this.predictedTravelMinutes,
    required this.displayColor,
    required this.weatherType,
    required this.congestionAdjustMinutes,
    required this.weatherAdjustMinutes,
    required this.remainingMarginMinutes,
    required this.planStatus,
    this.selectedRouteNo,
    required this.weatherApplied,
    required this.congestionApplied,
    required this.fallbackUsed,
    this.departedAt,
    this.arrivedAt,
  });

  factory DailyPlanModel.fromMap(Map<String, dynamic> data) {
    DateTime parseTs(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();

    return DailyPlanModel(
      dailyPlanId: data['dailyPlanId'] as String? ?? '',
      scheduleId: data['scheduleId'] as String? ?? '',
      finalDepartureTime: parseTs(data['finalDepartureTime']),
      finalAlarmTime: parseTs(data['finalAlarmTime']),
      predictedTravelMinutes:
          (data['predictedTravelMinutes'] as num?)?.toInt() ?? 0,
      displayColor: data['displayColor'] as String? ?? 'GREEN',
      weatherType: data['weatherType'] as String? ?? 'CLEAR',
      congestionAdjustMinutes:
          (data['congestionAdjustMinutes'] as num?)?.toInt() ?? 0,
      weatherAdjustMinutes:
          (data['weatherAdjustMinutes'] as num?)?.toInt() ?? 0,
      remainingMarginMinutes:
          (data['remainingMarginMinutes'] as num?)?.toInt() ?? 0,
      planStatus: data['planStatus'] as String? ?? 'CALCULATED',
      selectedRouteNo: data['selectedRouteNo'] as String?,
      weatherApplied: data['weatherApplied'] as bool? ?? false,
      congestionApplied: data['congestionApplied'] as bool? ?? false,
      fallbackUsed: data['fallbackUsed'] as bool? ?? false,
      departedAt: data['departedAt'] is Timestamp
          ? (data['departedAt'] as Timestamp).toDate()
          : null,
      arrivedAt: data['arrivedAt'] is Timestamp
          ? (data['arrivedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class DailyPlanService {
  static final instance = DailyPlanService._();
  DailyPlanService._();

  static const _baseUrl =
      'https://asia-northeast3-nagaja-a6a8b.cloudfunctions.net';

  static final _db = FirebaseFirestore.instance;
  User? get _user => FirebaseAuth.instance.currentUser;
  String? get _uid => _user?.uid;

  /// scheduleId → 오늘의 DailyPlan
  final Map<String, DailyPlanModel> _plans = {};

  DailyPlanModel? planForSchedule(String scheduleId) => _plans[scheduleId];

  bool get hasAnyPlan => _plans.isNotEmpty;

  /// generateDailyPlan Cloud Function 호출 → 실패 또는 플랜 미생성 시 로컬 계산으로 대체
  Future<bool> generateDailyPlan({String? scheduleId}) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final token = await _user!.getIdToken();
      final body = <String, dynamic>{'userId': uid};
      if (scheduleId != null) body['scheduleId'] = scheduleId;

      final response = await http.post(
        Uri.parse('$_baseUrl/generateDailyPlan'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      // ignore: avoid_print
      print('[DailyPlan] status=${response.statusCode} body=${response.body}');

      if (response.statusCode == 200) {
        await loadTodayPlans();
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DailyPlan] exception: $e');
    }

    // Cloud Function이 플랜을 만들지 못했으면 로컬 계산으로 대체
    if (_plans.isEmpty) {
      await _createLocalPlan(scheduleId: scheduleId);
    }
    return _plans.isNotEmpty;
  }

  /// 앱 데이터만으로 dailyPlan 계산 후 Firestore 저장 (fallbackUsed: true)
  Future<void> _createLocalPlan({String? scheduleId}) async {
    final uid = _uid;
    if (uid == null) return;

    final svc = SettingsService.instance;

    ScheduleEntry? schedule;
    // KST 기준 날짜 사용 (loadTodayPlans와 동일한 기준)
    final kstNow = DateTime.now().toUtc().add(const Duration(hours: 9));
    DateTime classDate = kstNow;

    if (scheduleId != null) {
      schedule = svc.schedules.where((s) => s.scheduleId == scheduleId).firstOrNull;
    } else {
      final todaySchedule = svc.todayNextSchedule;
      if (todaySchedule != null) {
        schedule = todaySchedule;
      } else {
        final next = svc.nextSchedule;
        if (next != null) {
          schedule = next;
          for (int i = 1; i <= 7; i++) {
            final date = kstNow.add(Duration(days: i));
            if (date.weekday == next.dayOfWeek) {
              classDate = date;
              break;
            }
          }
        }
      }
    }
    if (schedule == null) return;

    try {
      final today = '${classDate.year}-${classDate.month.toString().padLeft(2, '0')}-${classDate.day.toString().padLeft(2, '0')}';
      // KST 기준 현재 시각 (loadTodayPlans와 동일한 기준)
      final now = DateTime.now().toUtc().add(const Duration(hours: 9));

      final parts = schedule.targetArrivalTime.split(':');
      if (parts.length != 2) return;
      final targetArrivalAt = DateTime(
        classDate.year, classDate.month, classDate.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );

      final travelMin = svc.defaultTravelMinutes;
      final prepMin = svc.prepMinutes;
      final finalDepartureAt = targetArrivalAt.subtract(Duration(minutes: travelMin));
      final finalAlarmAt = finalDepartureAt.subtract(Duration(minutes: prepMin));

      // 당일 플랜: 지금부터 계산. 미래 날짜 플랜: Cloud Function이 당일 아침 실행 기준이므로
      // 로컬에서는 finalAlarmTime 기준 남은 시간(=prepMinutes)으로 대체
      final isToday = classDate.year == now.year &&
          classDate.month == now.month &&
          classDate.day == now.day;
      final remainingMargin = isToday
          ? targetArrivalAt.difference(now).inMinutes - travelMin
          : prepMin; // 미래 날짜: 준비시간만큼 여유로 설정
      final displayColor = remainingMargin > 15 ? 'GREEN' : remainingMargin >= 0 ? 'YELLOW' : 'RED';

      final nowTs = Timestamp.now();
      final data = {
        'scheduleId': schedule.scheduleId,
        'planDate': today,
        'title': schedule.title,
        'dayOfWeek': schedule.dayOfWeek,
        'classTime': schedule.classTime,
        'targetArrivalTime': schedule.targetArrivalTime,
        'startPlaceName': schedule.startPlaceName,
        'destinationName': schedule.destinationName,
        'transportMode': schedule.transportMode,
        'defaultTravelMinutes': travelMin,
        'prepMinutes': prepMin,
        'mapBaseTravelMinutes': travelMin,
        'predictedTravelMinutes': travelMin,
        'congestionAdjustMinutes': 0,
        'weatherAdjustMinutes': 0,
        'weatherType': 'CLEAR',
        'weatherApplied': false,
        'congestionApplied': false,
        'fallbackUsed': true,
        'selectedRouteNo': null,
        'planStatus': 'CALCULATED',
        'remainingMarginMinutes': remainingMargin,
        'displayColor': displayColor,
        'finalDepartureTime': Timestamp.fromDate(finalDepartureAt),
        'finalAlarmTime': Timestamp.fromDate(finalAlarmAt),
        'baseDepartureTime': Timestamp.fromDate(finalDepartureAt),
        'baseAlarmTime': Timestamp.fromDate(finalAlarmAt),
        'calculationTime': nowTs,
        'displayCheckedAt': nowTs,
        'weatherCheckedAt': nowTs,
        'updatedAt': nowTs,
      };

      final col = _db.collection('users').doc(uid).collection('dailyPlans');
      // 백엔드(getDailyPlanDocumentId)·updateDepartedAt/arrivedAt와 동일한 고정 ID 사용.
      // 고정 ID로 set하면 멱등 → 중복 생성 방지 + 출발/도착 업데이트 경로와 일치.
      final planId = '${today}_${schedule.scheduleId}';
      final ref = col.doc(planId);
      final existing = await ref.get();
      await ref.set({
        ...data,
        'dailyPlanId': planId,
        'createdAt': existing.exists ? (existing.get('createdAt') ?? nowTs) : nowTs,
      });

      _plans[schedule.scheduleId] = DailyPlanModel.fromMap({...data, 'dailyPlanId': planId});
      // ignore: avoid_print
      print('[DailyPlan] localPlan created scheduleId=${schedule.scheduleId}');
    } catch (e) {
      // ignore: avoid_print
      print('[DailyPlan] createLocalPlan error: $e');
    }
  }

  /// Firestore에서 오늘 + 다음 수업 날짜의 dailyPlans 로드
  Future<void> loadTodayPlans() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final svc = SettingsService.instance;
      final today = _todayStr();

      // 다음 수업 날짜도 함께 조회 (오늘 수업 없을 때 대비)
      final datesToLoad = <String>{today};
      final next = svc.nextSchedule;
      if (next != null) {
        final now = DateTime.now().toUtc().add(const Duration(hours: 9));
        for (int i = 0; i <= 7; i++) {
          final date = now.add(Duration(days: i));
          if (date.weekday == next.dayOfWeek) {
            datesToLoad.add(
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            );
            break;
          }
        }
      }

      _plans.clear();
      for (final dateStr in datesToLoad) {
        final snap = await _db
            .collection('users')
            .doc(uid)
            .collection('dailyPlans')
            .where('planDate', isEqualTo: dateStr)
            .get();
        // ignore: avoid_print
        print('[DailyPlan] loadTodayPlans date=$dateStr docs=${snap.docs.length}');
        for (final doc in snap.docs) {
          final data = doc.data();
          final plan = DailyPlanModel.fromMap(data);
          if (plan.scheduleId.isNotEmpty) {
            _plans[plan.scheduleId] = plan;
          }
        }
      }
      // ignore: avoid_print
      print('[DailyPlan] _plans keys=${_plans.keys.toList()}');
    } catch (e) {
      // ignore: avoid_print
      print('[DailyPlan] loadTodayPlans error: $e');
    }
  }

  /// dailyPlan.departedAt 업데이트 (출발 버튼)
  Future<void> updateDepartedAt(String scheduleId, DateTime departedAt) async {
    await _updateDailyPlanField(scheduleId, {
      'departedAt': Timestamp.fromDate(departedAt),
      'updatedAt': Timestamp.now(),
    });
  }

  /// dailyPlan.arrivedAt 업데이트 (도착 확인 버튼)
  Future<void> updateArrivedAt(
    String scheduleId,
    DateTime arrivedAt, {
    int? actualTravelMinutes,
    String? resultStatus,
  }) async {
    final fields = <String, dynamic>{
      'arrivedAt': Timestamp.fromDate(arrivedAt),
      'updatedAt': Timestamp.now(),
    };
    if (actualTravelMinutes != null && actualTravelMinutes > 0) {
      fields['actualTravelMinutes'] = actualTravelMinutes;
    }
    if (resultStatus != null) {
      fields['resultStatus'] = resultStatus; // 'ON_TIME' | 'LATE'
    }
    await _updateDailyPlanField(scheduleId, fields);
  }

  /// 캘린더용: 모든 dailyPlans → planDate별 출결 상태
  /// 반환값: { 'YYYY-MM-DD': 'ON_TIME' | 'LATE' | 'ABSENT' }
  Future<Map<String, String>> fetchAttendance() async {
    final uid = _uid;
    if (uid == null) return {};
    final result = <String, String>{};
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('dailyPlans')
          .get();
      final today = _todayStr();
      for (final doc in snap.docs) {
        final d = doc.data();
        final date = d['planDate'] as String?;
        if (date == null || date.isEmpty) continue;
        final rs = d['resultStatus'] as String?;
        String status;
        if (rs == 'ON_TIME') {
          status = 'ON_TIME';
        } else if (rs == 'LATE') {
          status = 'LATE';
        } else if (d['arrivedAt'] == null && date.compareTo(today) < 0) {
          status = 'ABSENT'; // 지난 날짜인데 도착 기록 없음
        } else {
          continue; // 오늘/미래의 미기록은 표시 안 함
        }
        result[date] = _mergeAttendance(result[date], status);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DailyPlan] fetchAttendance error: $e');
    }
    return result;
  }

  /// 같은 날 여러 수업: 나쁜 상태 우선 (LATE > ABSENT > ON_TIME)
  String _mergeAttendance(String? prev, String next) {
    if (prev == null) return next;
    const rank = {'LATE': 3, 'ABSENT': 2, 'ON_TIME': 1};
    return (rank[next] ?? 0) >= (rank[prev] ?? 0) ? next : prev;
  }

  Future<void> _updateDailyPlanField(
    String scheduleId,
    Map<String, dynamic> fields,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // 로드된 플랜의 실제 문서 ID 우선 사용 → 레거시 랜덤 ID/백엔드/폴백 고정 ID 모두 대응.
      // 없으면 백엔드 규칙과 동일한 고정 ID로 폴백.
      final loadedId = _plans[scheduleId]?.dailyPlanId ?? '';
      final docId = loadedId.isNotEmpty ? loadedId : '${_todayStr()}_$scheduleId';
      await _db
          .collection('users')
          .doc(uid)
          .collection('dailyPlans')
          .doc(docId)
          .update(fields);
    } catch (e) {
      // ignore: avoid_print
      print('[DailyPlan] updateField error: $e');
    }
  }

  // 에뮬레이터/서버 시간대 차이 보정: Cloud Functions(asia-northeast3)는 KST 기준
  static String _todayStr() {
    final n = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}
