import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final instance = SettingsService._();
  SettingsService._();

  Map<int, TimeOfDay?> schedule = {
    1: const TimeOfDay(hour: 9, minute: 0),
    2: const TimeOfDay(hour: 10, minute: 30),
    3: const TimeOfDay(hour: 9, minute: 0),
    4: null,
    5: const TimeOfDay(hour: 13, minute: 0),
  };
  int prepMinutes = 30;
  String transport = 'bus';
  String homeAddress = '부산시 사상구';
  String schoolAddress = '동의대학교';

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    for (int day = 1; day <= 5; day++) {
      final str = prefs.getString('schedule_$day');
      if (str == null) continue; // 저장된 값 없으면 기본값 유지
      if (str.isEmpty) {
        schedule[day] = null;
      } else {
        final parts = str.split(':');
        schedule[day] = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
    prepMinutes = prefs.getInt('prep_minutes') ?? 30;
    transport = prefs.getString('transport') ?? 'bus';
    homeAddress = prefs.getString('home_address') ?? '부산시 사상구';
    schoolAddress = prefs.getString('school_address') ?? '동의대학교';
  }

  Future<void> save({
    required Map<int, TimeOfDay?> schedule,
    required int prepMinutes,
    required String transport,
    required String homeAddress,
    required String schoolAddress,
  }) async {
    this.schedule = Map.from(schedule);
    this.prepMinutes = prepMinutes;
    this.transport = transport;
    this.homeAddress = homeAddress;
    this.schoolAddress = schoolAddress;

    final prefs = await SharedPreferences.getInstance();
    for (int day = 1; day <= 5; day++) {
      final time = schedule[day];
      await prefs.setString('schedule_$day', time == null ? '' : '${time.hour}:${time.minute}');
    }
    await prefs.setInt('prep_minutes', prepMinutes);
    await prefs.setString('transport', transport);
    await prefs.setString('home_address', homeAddress);
    await prefs.setString('school_address', schoolAddress);

    notifyListeners(); // 홈 화면 등 리스너에게 변경 알림
  }
}
