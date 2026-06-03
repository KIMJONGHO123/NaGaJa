import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaja/services/daily_plan_service.dart';

void main() {
  group('DailyPlanModel.fromMap', () {
    final baseTs = Timestamp.fromDate(DateTime(2026, 6, 3, 8, 0));

    final baseMap = <String, dynamic>{
      'dailyPlanId': '2026-06-03_sch1',
      'scheduleId': 'sch1',
      'finalDepartureTime': baseTs,
      'finalAlarmTime': baseTs,
      'predictedTravelMinutes': 47,
      'displayColor': 'GREEN',
      'weatherType': 'CLEAR',
      'congestionAdjustMinutes': 3,
      'weatherAdjustMinutes': 0,
      'remainingMarginMinutes': 20,
      'planStatus': 'CALCULATED',
      'selectedRouteNo': '1002',
      'weatherApplied': true,
      'congestionApplied': true,
      'fallbackUsed': false,
    };

    test('모든 필드 정상 파싱', () {
      final model = DailyPlanModel.fromMap(baseMap);

      expect(model.dailyPlanId, '2026-06-03_sch1');
      expect(model.scheduleId, 'sch1');
      expect(model.predictedTravelMinutes, 47);
      expect(model.displayColor, 'GREEN');
      expect(model.weatherType, 'CLEAR');
      expect(model.congestionAdjustMinutes, 3);
      expect(model.weatherAdjustMinutes, 0);
      expect(model.remainingMarginMinutes, 20);
      expect(model.planStatus, 'CALCULATED');
      expect(model.selectedRouteNo, '1002');
      expect(model.weatherApplied, isTrue);
      expect(model.congestionApplied, isTrue);
      expect(model.fallbackUsed, isFalse);
    });

    test('Timestamp → DateTime 변환', () {
      final model = DailyPlanModel.fromMap(baseMap);

      expect(model.finalDepartureTime, DateTime(2026, 6, 3, 8, 0));
      expect(model.finalAlarmTime, DateTime(2026, 6, 3, 8, 0));
    });

    test('Timestamp 필드 누락 시 DateTime.now() 폴백 (크래시 없음)', () {
      final map = Map<String, dynamic>.from(baseMap)
        ..remove('finalDepartureTime')
        ..remove('finalAlarmTime');

      final before = DateTime.now();
      final model = DailyPlanModel.fromMap(map);
      final after = DateTime.now();

      expect(model.finalDepartureTime.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(model.finalDepartureTime.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('departedAt / arrivedAt — Timestamp 있을 때 파싱', () {
      final departTs = Timestamp.fromDate(DateTime(2026, 6, 3, 8, 30));
      final arriveTs = Timestamp.fromDate(DateTime(2026, 6, 3, 9, 15));
      final map = Map<String, dynamic>.from(baseMap)
        ..['departedAt'] = departTs
        ..['arrivedAt'] = arriveTs;

      final model = DailyPlanModel.fromMap(map);

      expect(model.departedAt, DateTime(2026, 6, 3, 8, 30));
      expect(model.arrivedAt, DateTime(2026, 6, 3, 9, 15));
    });

    test('departedAt / arrivedAt — 없으면 null', () {
      final model = DailyPlanModel.fromMap(baseMap);

      expect(model.departedAt, isNull);
      expect(model.arrivedAt, isNull);
    });

    test('fallbackUsed: true 케이스', () {
      final map = Map<String, dynamic>.from(baseMap)
        ..['fallbackUsed'] = true
        ..['planStatus'] = 'CALCULATED';

      final model = DailyPlanModel.fromMap(map);

      expect(model.fallbackUsed, isTrue);
    });

    test('displayColor — YELLOW / RED 파싱', () {
      for (final color in ['YELLOW', 'RED', 'GREEN']) {
        final map = Map<String, dynamic>.from(baseMap)..['displayColor'] = color;
        final model = DailyPlanModel.fromMap(map);
        expect(model.displayColor, color);
      }
    });

    test('selectedRouteNo — null 허용', () {
      final map = Map<String, dynamic>.from(baseMap)..['selectedRouteNo'] = null;
      final model = DailyPlanModel.fromMap(map);
      expect(model.selectedRouteNo, isNull);
    });

    test('필드 누락 시 기본값', () {
      final model = DailyPlanModel.fromMap({});

      expect(model.dailyPlanId, '');
      expect(model.scheduleId, '');
      expect(model.predictedTravelMinutes, 0);
      expect(model.displayColor, 'GREEN');
      expect(model.weatherType, 'CLEAR');
      expect(model.planStatus, 'CALCULATED');
      expect(model.fallbackUsed, isFalse);
      expect(model.weatherApplied, isFalse);
      expect(model.congestionApplied, isFalse);
    });
  });
}
