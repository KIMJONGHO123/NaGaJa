import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_service.dart';

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

  static final _db = FirebaseFirestore.instance;
  User? get _user => FirebaseAuth.instance.currentUser;
  String? get _uid => _user?.uid;

  /// scheduleId → 오늘의 DailyPlan
  final Map<String, DailyPlanModel> _plans = {};

  DailyPlanModel? planForSchedule(String scheduleId) => _plans[scheduleId];

  bool get hasAnyPlan => _plans.isNotEmpty;

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
