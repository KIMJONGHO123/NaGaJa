import 'package:flutter/material.dart';

class ScheduleEntry {
  final int day; // 1=월 ~ 5=금
  final TimeOfDay? startTime;
  final String courseName;

  const ScheduleEntry({
    required this.day,
    required this.startTime,
    this.courseName = '',
  });

  // Firestore 문서 → 객체
  factory ScheduleEntry.fromMap(int day, Map<String, dynamic> data) {
    TimeOfDay? time;
    final raw = data['startTime'] as String?;
    if (raw != null && raw.length == 4) {
      time = TimeOfDay(
        hour: int.parse(raw.substring(0, 2)),
        minute: int.parse(raw.substring(2, 4)),
      );
    }
    return ScheduleEntry(
      day: day,
      startTime: time,
      courseName: (data['courseName'] as String?) ?? '',
    );
  }

  // 객체 → Firestore 저장용 Map
  Map<String, dynamic> toMap() => {
        'day': day,
        'startTime': startTime == null
            ? ''
            : '${startTime!.hour.toString().padLeft(2, '0')}${startTime!.minute.toString().padLeft(2, '0')}',
        'courseName': courseName,
      };
}

class UserModel {
  final String userId;
  final String name;
  final String email;
  final String homeAddress;
  final String schoolAddress;
  final String transport; // bus / subway / walk
  final int prepMinutes;
  final int defaultTravelMinutes;
  final bool isOnboardingComplete;

  const UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.homeAddress,
    required this.schoolAddress,
    required this.transport,
    required this.prepMinutes,
    required this.defaultTravelMinutes,
    required this.isOnboardingComplete,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) => UserModel(
        userId: (data['userId'] as String?) ?? '',
        name: (data['name'] as String?) ?? '',
        email: (data['email'] as String?) ?? '',
        homeAddress: (data['homeAddress'] as String?) ?? '',
        schoolAddress: (data['schoolAddress'] as String?) ?? '',
        transport: (data['transport'] as String?) ?? 'bus',
        prepMinutes: (data['prepMinutes'] as int?) ?? 30,
        defaultTravelMinutes: (data['defaultTravelMinutes'] as int?) ?? 20,
        isOnboardingComplete: (data['isOnboardingComplete'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'email': email,
        'homeAddress': homeAddress,
        'schoolAddress': schoolAddress,
        'transport': transport,
        'prepMinutes': prepMinutes,
        'defaultTravelMinutes': defaultTravelMinutes,
        'isOnboardingComplete': isOnboardingComplete,
      };

  UserModel copyWith({
    String? homeAddress,
    String? schoolAddress,
    String? transport,
    int? prepMinutes,
    int? defaultTravelMinutes,
    bool? isOnboardingComplete,
  }) =>
      UserModel(
        userId: userId,
        name: name,
        email: email,
        homeAddress: homeAddress ?? this.homeAddress,
        schoolAddress: schoolAddress ?? this.schoolAddress,
        transport: transport ?? this.transport,
        prepMinutes: prepMinutes ?? this.prepMinutes,
        defaultTravelMinutes: defaultTravelMinutes ?? this.defaultTravelMinutes,
        isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      );
}
