import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  static final _firestore = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _userDoc =>
      _uid != null ? _firestore.collection('users').doc(_uid) : null;

  // ── 불러오기: Firestore 우선, 실패 시 SharedPreferences ─────────────────────
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    // Firestore에서 먼저 시도
    if (_userDoc != null) {
      try {
        final snap = await _userDoc!.get();
        if (snap.exists) {
          _applyMap(snap.data() as Map<String, dynamic>);
          await _saveLocal(); // 로컬 캐시 동기화
          return;
        }
      } catch (_) {
        // 오프라인 등 Firestore 실패 → 로컬로 폴백
      }
    }

    // 로컬 SharedPreferences
    await _loadLocal();
  }

  // ── 저장: Firestore + SharedPreferences 동시 저장 ───────────────────────────
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

    // 항상 로컬 저장
    await _saveLocal();

    // 로그인 상태면 Firestore에도 저장
    if (_userDoc != null) {
      try {
        await _userDoc!.set(_toMap(), SetOptions(merge: true));
      } catch (_) {
        // Firestore 저장 실패해도 로컬은 이미 저장됨
      }
    }

    notifyListeners();
  }

  // ── 로그인 후 호출: Firestore에서 최신 설정 재로드 ──────────────────────────
  Future<void> reloadFromFirestore() async {
    if (_userDoc == null) return;
    try {
      final snap = await _userDoc!.get();
      if (snap.exists) {
        _applyMap(snap.data() as Map<String, dynamic>);
        await _saveLocal();
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── 내부: Firestore 문서 → 메모리 ───────────────────────────────────────────
  void _applyMap(Map<String, dynamic> data) {
    for (int day = 1; day <= 5; day++) {
      final val = data['schedule_$day'] as String?;
      if (val == null) continue;
      if (val.isEmpty) {
        schedule[day] = null;
      } else {
        final parts = val.split(':');
        schedule[day] = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
    prepMinutes = (data['prep_minutes'] as int?) ?? prepMinutes;
    transport = (data['transport'] as String?) ?? transport;
    homeAddress = (data['home_address'] as String?) ?? homeAddress;
    schoolAddress = (data['school_address'] as String?) ?? schoolAddress;
  }

  // ── 내부: 메모리 → Firestore Map ────────────────────────────────────────────
  Map<String, dynamic> _toMap() {
    final map = <String, dynamic>{
      'prep_minutes': prepMinutes,
      'transport': transport,
      'home_address': homeAddress,
      'school_address': schoolAddress,
    };
    for (int day = 1; day <= 5; day++) {
      final time = schedule[day];
      map['schedule_$day'] = time == null ? '' : '${time.hour}:${time.minute}';
    }
    return map;
  }

  // ── 내부: 로컬 저장 ─────────────────────────────────────────────────────────
  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    for (int day = 1; day <= 5; day++) {
      final time = schedule[day];
      await prefs.setString(
          'schedule_$day', time == null ? '' : '${time.hour}:${time.minute}');
    }
    await prefs.setInt('prep_minutes', prepMinutes);
    await prefs.setString('transport', transport);
    await prefs.setString('home_address', homeAddress);
    await prefs.setString('school_address', schoolAddress);
  }

  // ── 내부: 로컬 불러오기 ─────────────────────────────────────────────────────
  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    for (int day = 1; day <= 5; day++) {
      final str = prefs.getString('schedule_$day');
      if (str == null) continue;
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
}
