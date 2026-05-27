import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SettingsService extends ChangeNotifier {
  static final instance = SettingsService._();
  SettingsService._();

  // ── 현재 메모리 상태 ────────────────────────────────────────────────────────
  UserModel? userModel;
  Map<int, ScheduleEntry> schedules = {}; // 1=월 ~ 5=금

  bool _loaded = false;
  bool get isOnboardingComplete => userModel?.isOnboardingComplete ?? false;

  // 편의 getter (HomeScreen 등에서 직접 사용)
  int get prepMinutes => userModel?.prepMinutes ?? 30;
  int get defaultTravelMinutes => userModel?.defaultTravelMinutes ?? 20;
  String get transport => userModel?.transport ?? 'bus';
  String get homeAddress => userModel?.homeAddress ?? '';
  String get schoolAddress => userModel?.schoolAddress ?? '';
  TimeOfDay? scheduleTime(int day) => schedules[day]?.startTime;
  String courseName(int day) => schedules[day]?.courseName ?? '';

  static final _db = FirebaseFirestore.instance;

  User? get _user => FirebaseAuth.instance.currentUser;
  String? get _uid => _user?.uid;
  DocumentReference? get _userDoc =>
      _uid != null ? _db.collection('users').doc(_uid) : null;
  CollectionReference? get _schedulesCol =>
      _userDoc?.collection('schedules');

  // ── 앱 시작 시 로드 (Firestore 우선, 실패 시 SharedPreferences) ────────────
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

  // ── 로그인 후 Firestore에서 재동기화 ────────────────────────────────────────
  Future<void> reloadFromFirestore() async {
    if (_userDoc == null) return;
    _loaded = false; // 강제 재로드
    await load();
  }

  // ── 최초 로그인: Users 문서 + 빈 schedules 서브컬렉션 생성 ──────────────────
  Future<void> createNewUser() async {
    if (_userDoc == null || _user == null) return;
    final now = FieldValue.serverTimestamp();
    final model = UserModel(
      userId: _uid!,
      name: _user!.displayName ?? '',
      email: _user!.email ?? '',
      homeAddress: '',
      schoolAddress: '',
      transport: 'bus',
      prepMinutes: 30,
      defaultTravelMinutes: 20,
      isOnboardingComplete: false,
    );
    await _userDoc!.set({
      ...model.toMap(),
      'createdAt': now,
      'updatedAt': now,
    });
    userModel = model;

    // 요일별 빈 스케줄 문서 생성 (1=월 ~ 5=금)
    final batch = _db.batch();
    for (int day = 1; day <= 5; day++) {
      final entry = ScheduleEntry(day: day, startTime: null);
      batch.set(_schedulesCol!.doc('$day'), entry.toMap());
      schedules[day] = entry;
    }
    await batch.commit();
    notifyListeners();
  }

  // ── 온보딩 완료 저장 ────────────────────────────────────────────────────────
  Future<void> completeOnboarding({
    required String homeAddress,
    required String schoolAddress,
    required String transport,
    required int prepMinutes,
    required Map<int, ScheduleEntry> scheduleMap,
  }) async {
    final updated = (userModel ?? _defaultModel()).copyWith(
      homeAddress: homeAddress,
      schoolAddress: schoolAddress,
      transport: transport,
      prepMinutes: prepMinutes,
      isOnboardingComplete: true,
    );
    userModel = updated;
    schedules = Map.from(scheduleMap);

    await _saveAll();
    notifyListeners();
  }

  // ── 설정 화면에서 저장 ──────────────────────────────────────────────────────
  Future<void> save({
    required String homeAddress,
    required String schoolAddress,
    required String transport,
    required int prepMinutes,
    required Map<int, ScheduleEntry> scheduleMap,
  }) async {
    userModel = (userModel ?? _defaultModel()).copyWith(
      homeAddress: homeAddress,
      schoolAddress: schoolAddress,
      transport: transport,
      prepMinutes: prepMinutes,
    );
    schedules = Map.from(scheduleMap);

    await _saveAll();
    notifyListeners();
  }

  // ── 준비 시간 기록 ──────────────────────────────────────────────────────────
  Future<void> savePrepLog({
    required DateTime startedAt,
    required DateTime departedAt,
    required DateTime? classTime,
  }) async {
    if (_userDoc == null) return;
    final duration = departedAt.difference(startedAt).inMinutes;
    if (duration <= 0) return;
    try {
      await _userDoc!.collection('prepLogs').add({
        'startedAt': Timestamp.fromDate(startedAt),
        'departedAt': Timestamp.fromDate(departedAt),
        'classTime': classTime != null ? Timestamp.fromDate(classTime) : null,
        'actualMinutes': duration,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── 평균 준비 시간 조회 ─────────────────────────────────────────────────────
  Future<int?> fetchAveragePrepMinutes() async {
    if (_userDoc == null) return null;
    try {
      final snap = await _userDoc!
          .collection('prepLogs')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      if (snap.docs.isEmpty) return null;
      final total = snap.docs.fold<int>(
          0, (acc, doc) => acc + ((doc.data()['actualMinutes'] as int?) ?? 0));
      return (total / snap.docs.length).round();
    } catch (_) {
      return null;
    }
  }

  // ── 내부: Firestore schedules 서브컬렉션 로드 ────────────────────────────────
  Future<void> _loadSchedulesFromFirestore() async {
    if (_schedulesCol == null) return;
    try {
      final snap = await _schedulesCol!.get();
      for (final doc in snap.docs) {
        final day = int.tryParse(doc.id);
        if (day == null) continue;
        schedules[day] =
            ScheduleEntry.fromMap(day, doc.data() as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  // ── 내부: Firestore + SharedPreferences 동시 저장 ────────────────────────────
  Future<void> _saveAll() async {
    await _saveLocal();

    if (_userDoc == null) return;
    try {
      final now = FieldValue.serverTimestamp();
      await _userDoc!.set({
        ...userModel!.toMap(),
        'updatedAt': now,
      }, SetOptions(merge: true));

      final batch = _db.batch();
      for (int day = 1; day <= 5; day++) {
        final entry = schedules[day] ?? ScheduleEntry(day: day, startTime: null);
        batch.set(_schedulesCol!.doc('$day'), entry.toMap());
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── 내부: SharedPreferences 저장 ─────────────────────────────────────────────
  Future<void> _saveLocal() async {
    if (userModel == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('homeAddress', userModel!.homeAddress);
    await prefs.setString('schoolAddress', userModel!.schoolAddress);
    await prefs.setString('transport', userModel!.transport);
    await prefs.setInt('prepMinutes', userModel!.prepMinutes);
    await prefs.setInt('defaultTravelMinutes', userModel!.defaultTravelMinutes);
    await prefs.setBool('isOnboardingComplete', userModel!.isOnboardingComplete);

    for (int day = 1; day <= 5; day++) {
      final entry = schedules[day];
      final time = entry?.startTime;
      await prefs.setString(
          'schedule_$day',
          time == null
              ? ''
              : '${time.hour.toString().padLeft(2, '0')}${time.minute.toString().padLeft(2, '0')}');
      await prefs.setString('courseName_$day', entry?.courseName ?? '');
    }
  }

  // ── 내부: SharedPreferences 로드 ─────────────────────────────────────────────
  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    userModel = UserModel(
      userId: _uid ?? '',
      name: _user?.displayName ?? '',
      email: _user?.email ?? '',
      homeAddress: prefs.getString('homeAddress') ?? '',
      schoolAddress: prefs.getString('schoolAddress') ?? '',
      transport: prefs.getString('transport') ?? 'bus',
      prepMinutes: prefs.getInt('prepMinutes') ?? 30,
      defaultTravelMinutes: prefs.getInt('defaultTravelMinutes') ?? 20,
      isOnboardingComplete: prefs.getBool('isOnboardingComplete') ?? false,
    );

    for (int day = 1; day <= 5; day++) {
      final str = prefs.getString('schedule_$day');
      TimeOfDay? time;
      if (str != null && str.length == 4) {
        time = TimeOfDay(
          hour: int.parse(str.substring(0, 2)),
          minute: int.parse(str.substring(2, 4)),
        );
      } else if (str != null && str.contains(':')) {
        // 구버전 H:M 하위 호환
        final parts = str.split(':');
        time = TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      schedules[day] = ScheduleEntry(
        day: day,
        startTime: time,
        courseName: prefs.getString('courseName_$day') ?? '',
      );
    }
  }

  UserModel _defaultModel() => UserModel(
        userId: _uid ?? '',
        name: _user?.displayName ?? '',
        email: _user?.email ?? '',
        homeAddress: '',
        schoolAddress: '',
        transport: 'bus',
        prepMinutes: 30,
        defaultTravelMinutes: 20,
        isOnboardingComplete: false,
      );
}
