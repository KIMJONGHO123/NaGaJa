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
  int defaultTravelMinutes = 20;
  String transport = 'bus';
  String homeAddress = '부산시 사상구';
  String schoolAddress = '동의대학교';

  bool _loaded = false;

  static final _firestore = FirebaseFirestore.instance;

  User? get _user => FirebaseAuth.instance.currentUser;
  String? get _uid => _user?.uid;
  DocumentReference? get _userDoc =>
      _uid != null ? _firestore.collection('users').doc(_uid) : null;

  // ── 불러오기: Firestore 우선, 실패 시 SharedPreferences ─────────────────────
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    if (_userDoc != null) {
      try {
        final snap = await _userDoc!.get();
        if (snap.exists) {
          _applyMap(snap.data() as Map<String, dynamic>);
          await _saveLocal();
          return;
        }
      } catch (_) {}
    }

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

    await _saveLocal();

    if (_userDoc != null) {
      try {
        final now = FieldValue.serverTimestamp();
        final data = _toMap();

        // 문서가 없으면 createdAt 포함해서 생성, 있으면 updatedAt만 갱신
        final snap = await _userDoc!.get();
        if (!snap.exists) {
          data['createdAt'] = now;
        }
        data['updatedAt'] = now;

        await _userDoc!.set(data, SetOptions(merge: true));
      } catch (_) {}
    }

    notifyListeners();
  }

  // ── 로그인 후 Firestore에서 최신 설정 재로드 ────────────────────────────────
  Future<void> reloadFromFirestore() async {
    if (_userDoc == null) return;
    try {
      final snap = await _userDoc!.get();
      if (snap.exists) {
        _applyMap(snap.data() as Map<String, dynamic>);
        await _saveLocal();
      } else {
        // 첫 로그인: 기본값으로 유저 문서 생성
        await _createUserDoc();
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── 첫 로그인 시 유저 문서 생성 ─────────────────────────────────────────────
  Future<void> _createUserDoc() async {
    if (_userDoc == null || _user == null) return;
    final now = FieldValue.serverTimestamp();
    await _userDoc!.set({
      ..._toMap(),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  // ── Firestore 문서 → 메모리 ──────────────────────────────────────────────────
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
    prepMinutes = (data['prepMinutes'] as int?) ?? prepMinutes;
    defaultTravelMinutes =
        (data['defaultTravelMinutes'] as int?) ?? defaultTravelMinutes;
    transport = (data['transport'] as String?) ?? transport;
    homeAddress = (data['homeAddress'] as String?) ?? homeAddress;
    schoolAddress = (data['schoolAddress'] as String?) ?? schoolAddress;
  }

  // ── 메모리 → Firestore Map (camelCase) ──────────────────────────────────────
  Map<String, dynamic> _toMap() {
    final map = <String, dynamic>{
      'userId': _uid ?? '',
      'name': _user?.displayName ?? '',
      'email': _user?.email ?? '',
      'prepMinutes': prepMinutes,
      'defaultTravelMinutes': defaultTravelMinutes,
      'transport': transport,
      'homeAddress': homeAddress,
      'schoolAddress': schoolAddress,
    };
    for (int day = 1; day <= 5; day++) {
      final time = schedule[day];
      map['schedule_$day'] = time == null ? '' : '${time.hour}:${time.minute}';
    }
    return map;
  }

  // ── 로컬 저장 (SharedPreferences) ───────────────────────────────────────────
  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    for (int day = 1; day <= 5; day++) {
      final time = schedule[day];
      await prefs.setString(
          'schedule_$day', time == null ? '' : '${time.hour}:${time.minute}');
    }
    await prefs.setInt('prepMinutes', prepMinutes);
    await prefs.setInt('defaultTravelMinutes', defaultTravelMinutes);
    await prefs.setString('transport', transport);
    await prefs.setString('homeAddress', homeAddress);
    await prefs.setString('schoolAddress', schoolAddress);
  }

  // ── 로컬 불러오기 ────────────────────────────────────────────────────────────
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
    prepMinutes = prefs.getInt('prepMinutes') ?? 30;
    defaultTravelMinutes = prefs.getInt('defaultTravelMinutes') ?? 20;
    transport = prefs.getString('transport') ?? 'bus';
    homeAddress = prefs.getString('homeAddress') ?? '부산시 사상구';
    schoolAddress = prefs.getString('schoolAddress') ?? '동의대학교';
  }
}
