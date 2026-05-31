import 'dart:math' as math;
import 'package:flutter/material.dart';

/// users/{userId}
class UserModel {
  final String userId;
  final String name;
  final String email;
  final int prepMinutes;
  final int defaultTravelMinutes;
  final List<String> homeWifiSsids;
  final List<String> schoolWifiSsids;

  const UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.prepMinutes,
    required this.defaultTravelMinutes,
    required this.homeWifiSsids,
    required this.schoolWifiSsids,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) => UserModel(
        userId: (data['userId'] as String?) ?? '',
        name: (data['name'] as String?) ?? '',
        email: (data['email'] as String?) ?? '',
        prepMinutes: (data['prepMinutes'] as int?) ?? 30,
        defaultTravelMinutes: (data['defaultTravelMinutes'] as int?) ?? 20,
        homeWifiSsids: List<String>.from(data['homeWifiSsids'] ?? []),
        schoolWifiSsids: List<String>.from(data['schoolWifiSsids'] ?? []),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'email': email,
        'prepMinutes': prepMinutes,
        'defaultTravelMinutes': defaultTravelMinutes,
        'homeWifiSsids': homeWifiSsids,
        'schoolWifiSsids': schoolWifiSsids,
      };

  UserModel copyWith({
    int? prepMinutes,
    int? defaultTravelMinutes,
    List<String>? homeWifiSsids,
    List<String>? schoolWifiSsids,
  }) =>
      UserModel(
        userId: userId,
        name: name,
        email: email,
        prepMinutes: prepMinutes ?? this.prepMinutes,
        defaultTravelMinutes: defaultTravelMinutes ?? this.defaultTravelMinutes,
        homeWifiSsids: homeWifiSsids ?? this.homeWifiSsids,
        schoolWifiSsids: schoolWifiSsids ?? this.schoolWifiSsids,
      );
}

/// users/{userId}/schedules/{scheduleId}
class ScheduleEntry {
  final String scheduleId;
  final String userId;
  final String title;       // 과목명 (예: "자료구조")
  final int dayOfWeek;      // 1=월 ~ 7=일
  final String classTime;   // "HH:MM" (예: "09:00")
  final String targetArrivalTime; // "HH:MM" (예: "08:55")
  final String startPlaceName;    // 예: "집"
  final String startAddress;
  final double? startLat;
  final double? startLng;
  final String destinationName;   // 예: "공학관"
  final String destinationAddress;
  final double? endLat;   // 백엔드 Schedule 타입 필드명과 일치
  final double? endLng;
  final String transportMode; // "BUS" | "SUBWAY" | "WALK"
  final bool isActive;

  const ScheduleEntry({
    required this.scheduleId,
    required this.userId,
    required this.title,
    required this.dayOfWeek,
    required this.classTime,
    required this.targetArrivalTime,
    required this.startPlaceName,
    required this.startAddress,
    this.startLat,
    this.startLng,
    required this.destinationName,
    required this.destinationAddress,
    this.endLat,
    this.endLng,
    required this.transportMode,
    required this.isActive,
  });

  factory ScheduleEntry.fromMap(String id, Map<String, dynamic> data) =>
      ScheduleEntry(
        scheduleId: id,
        userId: (data['userId'] as String?) ?? '',
        title: (data['title'] as String?) ?? '',
        dayOfWeek: (data['dayOfWeek'] as int?) ?? 1,
        classTime: (data['classTime'] as String?) ?? '09:00',
        targetArrivalTime: (data['targetArrivalTime'] as String?) ?? '08:55',
        startPlaceName: (data['startPlaceName'] as String?) ?? '집',
        startAddress: (data['startAddress'] as String?) ?? '',
        startLat: (data['startLat'] as num?)?.toDouble(),
        startLng: (data['startLng'] as num?)?.toDouble(),
        destinationName: (data['destinationName'] as String?) ?? '',
        destinationAddress: (data['destinationAddress'] as String?) ?? '',
        endLat: (data['endLat'] as num?)?.toDouble(),
        endLng: (data['endLng'] as num?)?.toDouble(),
        transportMode: (data['transportMode'] as String?) ?? 'BUS',
        isActive: (data['isActive'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'scheduleId': scheduleId,
      'userId': userId,
      'title': title,
      'dayOfWeek': dayOfWeek,
      'classTime': classTime,
      'targetArrivalTime': targetArrivalTime,
      'startPlaceName': startPlaceName,
      'startAddress': startAddress,
      'destinationName': destinationName,
      'destinationAddress': destinationAddress,
      'transportMode': transportMode,
      'isActive': isActive,
    };
    // 좌표가 있으면 함께 저장 → 백엔드가 지오코딩을 건너뜀 (geocoding 500 회피).
    // null이면 생략(merge) → 백엔드가 주소 기반으로 계산·캐시(기존 캐시 보존).
    if (startLat != null && startLng != null) {
      m['startLat'] = startLat;
      m['startLng'] = startLng;
      // 날씨용 기상청 격자도 함께 저장 (없으면 백엔드가 날씨 fallback 처리)
      final g = _toKmaGrid(startLat!, startLng!);
      m['startNx'] = g.$1;
      m['startNy'] = g.$2;
    }
    if (endLat != null && endLng != null) {
      m['endLat'] = endLat;
      m['endLng'] = endLng;
    }
    return m;
  }

  /// WGS84(lat,lng) → 기상청 단기예보 격자 (nx, ny).
  /// 백엔드 convertToGrid와 동일한 Lambert Conformal Conic 공식.
  static (int, int) _toKmaGrid(double lat, double lng) {
    const double re = 6371.00877 / 5.0; // RE / GRID
    final double degrad = math.pi / 180.0;
    final double slat1 = 30.0 * degrad, slat2 = 60.0 * degrad;
    final double olon = 126.0 * degrad, olat = 38.0 * degrad;
    double sn = math.tan(math.pi * 0.25 + slat2 * 0.5) /
        math.tan(math.pi * 0.25 + slat1 * 0.5);
    sn = math.log(math.cos(slat1) / math.cos(slat2)) / math.log(sn);
    double sf = math.tan(math.pi * 0.25 + slat1 * 0.5);
    sf = math.pow(sf, sn).toDouble() * math.cos(slat1) / sn;
    double ro = math.tan(math.pi * 0.25 + olat * 0.5);
    ro = re * sf / math.pow(ro, sn).toDouble();
    double ra = math.tan(math.pi * 0.25 + lat * degrad * 0.5);
    ra = re * sf / math.pow(ra, sn).toDouble();
    double theta = lng * degrad - olon;
    if (theta > math.pi) theta -= 2.0 * math.pi;
    if (theta < -math.pi) theta += 2.0 * math.pi;
    theta *= sn;
    final int nx = (ra * math.sin(theta) + 43.0 + 0.5).floor();
    final int ny = (ro - ra * math.cos(theta) + 136.0 + 0.5).floor();
    return (nx, ny);
  }

  /// "HH:MM" 문자열 → TimeOfDay
  TimeOfDay? get classTimeOfDay {
    final parts = classTime.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// TimeOfDay → "HH:MM" 문자열
  static String timeOfDayToString(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
