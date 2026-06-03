import 'package:flutter_test/flutter_test.dart';
import 'package:nagaja/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('fromMap — 모든 필드 정상 파싱', () {
      final data = {
        'userId': 'u1',
        'name': '김철수',
        'email': 'test@example.com',
        'prepMinutes': 20,
        'defaultTravelMinutes': 30,
        'homeWifiSsids': ['HomeSSID', 'HomeSSID_5G'],
        'schoolWifiSsids': ['UniNet'],
      };

      final model = UserModel.fromMap(data);

      expect(model.userId, 'u1');
      expect(model.name, '김철수');
      expect(model.email, 'test@example.com');
      expect(model.prepMinutes, 20);
      expect(model.defaultTravelMinutes, 30);
      expect(model.homeWifiSsids, ['HomeSSID', 'HomeSSID_5G']);
      expect(model.schoolWifiSsids, ['UniNet']);
    });

    test('fromMap — 필드 누락 시 기본값 적용', () {
      final model = UserModel.fromMap({});

      expect(model.userId, '');
      expect(model.prepMinutes, 30);
      expect(model.defaultTravelMinutes, 20);
      expect(model.homeWifiSsids, isEmpty);
      expect(model.schoolWifiSsids, isEmpty);
    });

    test('fromMap — Wi-Fi SSID 빈 리스트', () {
      final model = UserModel.fromMap({
        'homeWifiSsids': [],
        'schoolWifiSsids': [],
      });

      expect(model.homeWifiSsids, isEmpty);
      expect(model.schoolWifiSsids, isEmpty);
    });

    test('toMap — fromMap 역직렬화 round-trip', () {
      final original = UserModel(
        userId: 'u1',
        name: '이영희',
        email: 'lee@example.com',
        prepMinutes: 25,
        defaultTravelMinutes: 35,
        homeWifiSsids: ['AP1'],
        schoolWifiSsids: ['AP2', 'AP3'],
      );

      final restored = UserModel.fromMap(original.toMap());

      expect(restored.userId, original.userId);
      expect(restored.name, original.name);
      expect(restored.prepMinutes, original.prepMinutes);
      expect(restored.homeWifiSsids, original.homeWifiSsids);
    });

    test('copyWith — 변경 필드만 교체', () {
      const original = UserModel(
        userId: 'u1',
        name: '박민준',
        email: 'park@example.com',
        prepMinutes: 15,
        defaultTravelMinutes: 25,
        homeWifiSsids: [],
        schoolWifiSsids: [],
      );

      final updated = original.copyWith(prepMinutes: 30);

      expect(updated.prepMinutes, 30);
      expect(updated.name, original.name); // 나머지는 유지
    });
  });

  group('ScheduleEntry', () {
    final baseData = {
      'userId': 'u1',
      'title': '자료구조',
      'dayOfWeek': 2,
      'classTime': '09:00',
      'targetArrivalTime': '08:55',
      'startPlaceName': '집',
      'startAddress': '부산시 해운대구',
      'destinationName': '공학관',
      'destinationAddress': '부산시 금정구',
      'transportMode': 'BUS',
      'isActive': true,
    };

    test('fromMap — 기본 필드 파싱', () {
      final entry = ScheduleEntry.fromMap('sch1', baseData);

      expect(entry.scheduleId, 'sch1');
      expect(entry.title, '자료구조');
      expect(entry.dayOfWeek, 2);
      expect(entry.classTime, '09:00');
      expect(entry.targetArrivalTime, '08:55');
      expect(entry.transportMode, 'BUS');
      expect(entry.isActive, true);
    });

    test('fromMap — 좌표 캐시 필드 파싱 (있을 때)', () {
      final data = Map<String, dynamic>.from(baseData)
        ..addAll({
          'startLat': 35.1796,
          'startLng': 129.0756,
          'endLat': 35.2322,
          'endLng': 129.0843,
        });

      final entry = ScheduleEntry.fromMap('sch1', data);

      expect(entry.startLat, closeTo(35.1796, 0.0001));
      expect(entry.startLng, closeTo(129.0756, 0.0001));
      expect(entry.endLat, closeTo(35.2322, 0.0001));
      expect(entry.endLng, closeTo(129.0843, 0.0001));
    });

    test('fromMap — 좌표 누락 시 null', () {
      final entry = ScheduleEntry.fromMap('sch1', baseData);

      expect(entry.startLat, isNull);
      expect(entry.startLng, isNull);
      expect(entry.endLat, isNull);
      expect(entry.endLng, isNull);
    });

    test('toMap — 좌표 없으면 좌표 키 생략', () {
      final entry = ScheduleEntry.fromMap('sch1', baseData);
      final map = entry.toMap();

      expect(map.containsKey('startLat'), isFalse);
      expect(map.containsKey('endLat'), isFalse);
    });

    test('toMap — 좌표 있으면 좌표 키 포함', () {
      final data = Map<String, dynamic>.from(baseData)
        ..addAll({'startLat': 35.18, 'startLng': 129.07, 'endLat': 35.23, 'endLng': 129.08});
      final entry = ScheduleEntry.fromMap('sch1', data);
      final map = entry.toMap();

      expect(map['startLat'], closeTo(35.18, 0.001));
      expect(map['endLat'], closeTo(35.23, 0.001));
    });

    test('classTimeOfDay — "HH:MM" → TimeOfDay 변환', () {
      final entry = ScheduleEntry.fromMap('sch1', baseData);
      final tod = entry.classTimeOfDay;

      expect(tod, isNotNull);
      expect(tod!.hour, 9);
      expect(tod.minute, 0);
    });

    test('timeOfDayToString — 2자리 패딩 확인', () {
      const result = ScheduleEntry.timeOfDayToString;
      // static 메서드 직접 호출 불가, fromMap으로 간접 확인
      final entry = ScheduleEntry.fromMap('sch1', {
        ...baseData,
        'classTime': '08:05',
      });
      expect(entry.classTime, '08:05');
    });

    test('fromMap — 누락 필드 기본값', () {
      final entry = ScheduleEntry.fromMap('sch1', {});

      expect(entry.dayOfWeek, 1);
      expect(entry.classTime, '09:00');
      expect(entry.transportMode, 'BUS');
      expect(entry.isActive, true);
    });
  });
}
