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
    if (startLat != null) m['startLat'] = startLat;
    if (startLng != null) m['startLng'] = startLng;
    if (endLat != null) m['endLat'] = endLat;
    if (endLng != null) m['endLng'] = endLng;
    return m;
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
