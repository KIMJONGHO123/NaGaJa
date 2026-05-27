import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SettingsService extends ChangeNotifier {
  static final instance = SettingsService._();
  SettingsService._();

  UserModel? userModel;

  /// 오늘 활성 schedules (dayOfWeek 기준으로 필터링해서 사용)
  List<ScheduleEntry> schedules = [];

  bool _loaded = false;

  // ── 편의 getter ──────────────────────────────────────────────────────────────
  int get prepMinutes => userModel?.prepMinutes ?? 30;
  int get defaultTravelMinutes => userModel?.defaultTravelMinutes ?? 20;

  /// 특정 요일(1=월~7=일)의 활성 스케줄 목록
  List<ScheduleEntry> schedulesForDay(int dayOfWeek) =>
      schedules.where((s) => s.dayOfWeek == dayOfWeek && s.isActive).toList();

  /// 오늘 이후 가장 가까운 수업의 ScheduleEntry
  ScheduleEntry? get nextSchedule {
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final weekday = date.weekday;
      final daySchedules = schedulesForDay(weekday);
      for (final s in daySchedules..sort((a, b) => a.classTime.compareTo(b.classTime))) {
        final parts = s.classTime.split(':');
        if (parts.length != 2) continue;
        final classTime = DateTime(
          date.year, date.month, date.day,
          int.parse(parts[0]), int.parse(parts[1]),
        );
        if (classTime.isAfter(now)) return s;
      }
    }
    return null;
  }

  static final _db = FirebaseFirestore.instance;
  User? get _user => FirebaseAuth.instance.currentUser;
  String? get _uid => _user?.uid;
  DocumentReference? get _userDoc =>
      _uid != null ? _db.collection('users').doc(_uid) : null;
  CollectionReference? get _schedulesCol =>
      _userDoc?.collection('schedules');

  // ── 앱 시작 시 로드 ──────────────────────────────────────────────────────────
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    if (_userDoc != null) {
      try {
        final snap = await _userDoc!.get();
        if (snap.exists) {
          userModel = UserModel.fromMap(snap.data() as Map<String, dynamic>);
          await _loadSchedulesFromFirestore();
          await _saveLocal();
          notifyListeners();
          return;
        }
      } catch (_) {}
    }

    await _loadLocal();
    notifyListeners();
  }

  // ── 로그인 후 재동기화 ───────────────────────────────────────────────────────
  Future<void> reloadFromFirestore() async {
    if (_userDoc == null) return;
    _loaded = false;
    await load();
  }

  // ── 최초 로그인: users 문서 생성 ─────────────────────────────────────────────
  Future<void> createNewUser() async {
    if (_userDoc == null || _user == null) return;
    final now = FieldValue.serverTimestamp();
    final model = UserModel(
      userId: _uid!,
      name: _user!.displayName ?? '',
      email: _user!.email ?? '',
      prepMinutes: 30,
      defaultTravelMinutes: 20,
      homeWifiSsids: [],
      schoolWifiSsids: [],
    );
    await _userDoc!.set({...model.toMap(), 'createdAt': now, 'updatedAt': now});
    userModel = model;
    schedules = [];
    notifyListeners();
  }

  /// users 문서가 존재하는지 여부
  Future<bool> userExists() async {
    if (_userDoc == null) return false;
    try {
      final snap = await _userDoc!.get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  // ── 온보딩 완료: users 문서 + schedules 서브컬렉션 저장 ─────────────────────
  Future<void> completeOnboarding({
    required int prepMinutes,
    required int defaultTravelMinutes,
    required List<String> homeWifiSsids,
    required List<String> schoolWifiSsids,
    required List<ScheduleEntry> newSchedules,
  }) async {
    userModel = (userModel ?? _defaultModel()).copyWith(
      prepMinutes: prepMinutes,
      defaultTravelMinutes: defaultTravelMinutes,
      homeWifiSsids: homeWifiSsids,
      schoolWifiSsids: schoolWifiSsids,
    );
    schedules = newSchedules;
    await _saveAll();
    notifyListeners();
  }

  // ── 설정 저장 ────────────────────────────────────────────────────────────────
  Future<void> saveUserSettings({
    required int prepMinutes,
    required int defaultTravelMinutes,
    List<String>? homeWifiSsids,
    List<String>? schoolWifiSsids,
  }) async {
    userModel = (userModel ?? _defaultModel()).copyWith(
      prepMinutes: prepMinutes,
      defaultTravelMinutes: defaultTravelMinutes,
      homeWifiSsids: homeWifiSsids,
      schoolWifiSsids: schoolWifiSsids,
    );
    await _saveAll();
    notifyListeners();
  }

  // ── 스케줄 추가/수정 ─────────────────────────────────────────────────────────
  Future<void> saveSchedule(ScheduleEntry entry) async {
    if (_schedulesCol == null) return;
    try {
      final now = FieldValue.serverTimestamp();
      final data = {...entry.toMap(), 'updatedAt': now};
      if (entry.scheduleId.isEmpty) {
        final ref = await _schedulesCol!.add({...data, 'createdAt': now});
        final newEntry = ScheduleEntry.fromMap(ref.id, {...entry.toMap(), 'scheduleId': ref.id});
        schedules.removeWhere((s) => s.scheduleId == ref.id);
        schedules.add(newEntry);
      } else {
        await _schedulesCol!.doc(entry.scheduleId).set(data, SetOptions(merge: true));
        schedules.removeWhere((s) => s.scheduleId == entry.scheduleId);
        schedules.add(entry);
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── 스케줄 삭제 ──────────────────────────────────────────────────────────────
  Future<void> deleteSchedule(String scheduleId) async {
    if (_schedulesCol == null) return;
    try {
      await _schedulesCol!.doc(scheduleId).delete();
      schedules.removeWhere((s) => s.scheduleId == scheduleId);
      notifyListeners();
    } catch (_) {}
  }

  // ── 준비 시간 기록 ───────────────────────────────────────────────────────────
  Future<void> savePrepLog({
    required DateTime startedAt,
    required DateTime departedAt,
    required String? scheduleId,
  }) async {
    if (_userDoc == null) return;
    final duration = departedAt.difference(startedAt).inMinutes;
    if (duration <= 0) return;
    try {
      await _userDoc!.collection('prepLogs').add({
        'startedAt': Timestamp.fromDate(startedAt),
        'departedAt': Timestamp.fromDate(departedAt),
        'scheduleId': scheduleId,
        'actualMinutes': duration,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── Firestore schedules 로드 ─────────────────────────────────────────────────
  Future<void> _loadSchedulesFromFirestore() async {
    if (_schedulesCol == null) return;
    try {
      final snap = await _schedulesCol!.get();
      schedules = snap.docs
          .map((d) => ScheduleEntry.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  // ── Firestore + SharedPreferences 동시 저장 ──────────────────────────────────
  Future<void> _saveAll() async {
    await _saveLocal();
    if (_userDoc == null || userModel == null) return;
    try {
      await _userDoc!.set(
        {...userModel!.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  // ── SharedPreferences 저장 ───────────────────────────────────────────────────
  Future<void> _saveLocal() async {
    if (userModel == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('prepMinutes', userModel!.prepMinutes);
    await prefs.setInt('defaultTravelMinutes', userModel!.defaultTravelMinutes);
    await prefs.setStringList('homeWifiSsids', userModel!.homeWifiSsids);
    await prefs.setStringList('schoolWifiSsids', userModel!.schoolWifiSsids);
  }

  // ── SharedPreferences 로드 ───────────────────────────────────────────────────
  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    userModel = UserModel(
      userId: _uid ?? '',
      name: _user?.displayName ?? '',
      email: _user?.email ?? '',
      prepMinutes: prefs.getInt('prepMinutes') ?? 30,
      defaultTravelMinutes: prefs.getInt('defaultTravelMinutes') ?? 20,
      homeWifiSsids: prefs.getStringList('homeWifiSsids') ?? [],
      schoolWifiSsids: prefs.getStringList('schoolWifiSsids') ?? [],
    );
    schedules = []; // 오프라인 시 스케줄 없음
  }

  UserModel _defaultModel() => UserModel(
        userId: _uid ?? '',
        name: _user?.displayName ?? '',
        email: _user?.email ?? '',
        prepMinutes: 30,
        defaultTravelMinutes: 20,
        homeWifiSsids: [],
        schoolWifiSsids: [],
      );
}
