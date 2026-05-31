import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/daily_plan_service.dart';
import '../../services/settings_service.dart';
import '../late_response/late_response_screen.dart';
import 'circular_gauge.dart';

enum _Status { free, goNow, lateRisk }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  DateTime? _nextClassTime;
  bool _departed = false;
  bool _arrived = false;
  bool _loading = true;
  bool _planRefreshing = false;
  DateTime? _prepStartedAt;
  DateTime? _departedAt;

  int get _prepMinutes => SettingsService.instance.prepMinutes;

  DailyPlanModel? get _activePlan {
    final id = (SettingsService.instance.todayNextSchedule ??
            SettingsService.instance.nextSchedule)
        ?.scheduleId;
    if (id == null || id.isEmpty) return null;
    return DailyPlanService.instance.planForSchedule(id);
  }

  /// DailyPlan이 있고 오늘 날짜 플랜이면 예측 이동시간, 아니면 기본값
  int get _travelMinutes {
    if (_nextClassTime == null) return SettingsService.instance.defaultTravelMinutes;
    final plan = _activePlan;
    if (plan != null) {
      final ft = plan.finalDepartureTime;
      final sameDay = ft.year == _nextClassTime!.year &&
          ft.month == _nextClassTime!.month &&
          ft.day == _nextClassTime!.day;
      if (sameDay) return plan.predictedTravelMinutes;
    }
    return SettingsService.instance.defaultTravelMinutes;
  }

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    SettingsService.instance.addListener(_onSettingsChanged);
    _initSettings();
  }

  Future<void> _initSettings() async {
    await SettingsService.instance.load();
    _recomputeNextClass();
    await DailyPlanService.instance.loadTodayPlans();
    _restoreDepartedState();
    _prepStartedAt = await SettingsService.instance.loadPrepStartedAt();
    if (mounted) setState(() => _loading = false);
  }

  void _restoreDepartedState() {
    final plan = _activePlan;
    if (plan == null) return;
    final today = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;
    if (plan.departedAt != null && isToday(plan.departedAt!)) {
      _departed = true;
      _departedAt = plan.departedAt;
    }
    if (plan.arrivedAt != null && isToday(plan.arrivedAt!)) {
      _arrived = true;
    }
  }

  void _onSettingsChanged() {
    _recomputeNextClass();
    if (mounted) setState(() {});
  }

  Future<void> _refreshPlan() async {
    if (_planRefreshing) return;
    setState(() => _planRefreshing = true);
    await DailyPlanService.instance.generateDailyPlan(
      scheduleId: (SettingsService.instance.todayNextSchedule ??
              SettingsService.instance.nextSchedule)
          ?.scheduleId,
    );
    if (mounted) {
      _recomputeNextClass();
      setState(() => _planRefreshing = false);
    }
  }

  void _recomputeNextClass() {
    final next = SettingsService.instance.todayNextSchedule;
    if (next == null) { _nextClassTime = null; return; }

    final now = DateTime.now();
    final parts = next.classTime.split(':');
    if (parts.length != 2) { _nextClassTime = null; return; }
    final classTime = DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
    _nextClassTime = classTime.isAfter(now) ? classTime : null;
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    SettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  _Status get _status {
    if (_nextClassTime == null) return _Status.free;
    final remaining = _nextClassTime!.difference(_now).inMinutes;
    // 게이지와 동일한 경계: 나가자 = travelMin+10 ~ travelMin+5, 지각 = travelMin+5 미만
    if (remaining > _travelMinutes + 10) return _Status.free;
    if (remaining > _travelMinutes + 5) return _Status.goNow;
    return _Status.lateRisk;
  }

  Color get _statusColor => switch (_status) {
    _Status.free     => const Color(0xFF4CAF50),
    _Status.goNow    => const Color(0xFFFF9800),
    _Status.lateRisk => const Color(0xFFF44336),
  };

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// DailyPlan의 finalDepartureTime 우선, 없으면 로컬 계산
  /// 단, 플랜 날짜가 오늘 수업 날짜와 같을 때만 사용 (오래된 플랜 방지)
  DateTime? get _shouldDepartAt {
    if (_nextClassTime == null) return null;
    final plan = _activePlan;
    if (plan != null) {
      final ft = plan.finalDepartureTime;
      final sameDay = ft.year == _nextClassTime!.year &&
          ft.month == _nextClassTime!.month &&
          ft.day == _nextClassTime!.day;
      if (sameDay) return ft;
    }
    return _nextClassTime!.subtract(Duration(minutes: _travelMinutes + 5));
  }

  DateTime? get _taxiDeadline =>
      _nextClassTime?.subtract(Duration(minutes: (_travelMinutes * 0.7).round()));

  String _buildClockSubtitle() {
    if (_nextClassTime != null) {
      final next = SettingsService.instance.todayNextSchedule;
      final name = (next?.title.isNotEmpty ?? false) ? ' · ${next!.title}' : '';
      return '다음 수업 ${_fmt(_nextClassTime!)}$name';
    }
    final upcoming = SettingsService.instance.nextSchedule;
    if (upcoming == null) return '예정된 수업 없음';
    const dayNames = ['', '월', '화', '수', '목', '금', '토', '일'];
    final day = dayNames[upcoming.dayOfWeek];
    final name = upcoming.title.isNotEmpty ? ' · ${upcoming.title}' : '';
    return '다음 수업 $day ${upcoming.classTime}$name';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildClock(),
              const SizedBox(height: 16),
              CircularGauge(
                classTime: _nextClassTime,
                now: _now,
                prepMinutes: _prepMinutes,
                travelMinutes: _travelMinutes,
                upcomingSchedule: _nextClassTime == null
                    ? SettingsService.instance.nextSchedule
                    : null,
              ),
              const SizedBox(height: 16),
              _buildInfoCard(),
              if (_nextClassTime != null &&
                  _activePlan != null &&
                  !_activePlan!.fallbackUsed) ...[
                const SizedBox(height: 12),
                _buildPlanCards(_activePlan!),
              ],
              const SizedBox(height: 16),
              if (_status == _Status.lateRisk && _nextClassTime != null) ...[
                _buildLateWarningCard(),
                const SizedBox(height: 16),
              ],
              _buildActionButtons(),
              if (_prepStartedAt != null) ...[
                const SizedBox(height: 12),
                _buildPrepTimer(),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClock() {
    final t = _now;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    return Column(
      children: [
        Text(
          timeStr,
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w200,
            letterSpacing: 6,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _buildClockSubtitle(),
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    // 오늘 수업이 없으면 출발 시각 표시 안 함
    final departStr = (_nextClassTime != null && _shouldDepartAt != null)
        ? _fmt(_shouldDepartAt!)
        : '--:--';
    final hasPlan = _activePlan != null && !_activePlan!.fallbackUsed;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoItem('준비', '$_prepMinutes분', Icons.coffee_outlined),
              _vertDivider(),
              _infoItem('이동', '$_travelMinutes분', Icons.directions_bus_outlined),
              _vertDivider(),
              _infoItem('출발', departStr, Icons.schedule),
            ],
          ),
          if (_nextClassTime != null) ...[
            const SizedBox(height: 12),
            _buildPlanRefreshRow(hasPlan),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanRefreshRow(bool hasPlan) {
    return GestureDetector(
      onTap: _planRefreshing ? null : _refreshPlan,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_planRefreshing)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Icon(
              hasPlan ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined,
              size: 14,
              color: Colors.grey[400],
            ),
          const SizedBox(width: 6),
          Text(
            _planRefreshing
                ? '경로 계산 중...'
                : hasPlan
                    ? (_activePlan?.selectedRouteNo != null
                        ? '${_activePlan!.selectedRouteNo}번 기준 · 새로고침'
                        : 'AI 예측 적용됨 · 새로고침')
                    : '실시간 경로 계산하기',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  /// 기상 알람 + 날씨/혼잡 보정 카드 (fallbackUsed=false일 때만 표시)
  Widget _buildPlanCards(DailyPlanModel plan) {
    return Column(
      children: [
        _alarmCard(plan),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _weatherCard(plan)),
            const SizedBox(width: 12),
            Expanded(child: _congestionCard(plan)),
          ],
        ),
      ],
    );
  }

  Widget _alarmCard(DailyPlanModel plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active,
              size: 20, color: Color(0xFFFBBC04)),
          const SizedBox(width: 10),
          Text('기상 알람',
              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          const Spacer(),
          Text(
            _fmt(plan.finalAlarmTime),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A73E8)),
          ),
        ],
      ),
    );
  }

  Widget _weatherCard(DailyPlanModel plan) {
    final (IconData icon, String label) = switch (plan.weatherType) {
      'RAIN' => (Icons.umbrella, '비'),
      'SNOW' => (Icons.ac_unit, '눈'),
      _ => (Icons.wb_sunny, '맑음'),
    };
    return _miniCard(
        icon, const Color(0xFFFFA726), label, '+${plan.weatherAdjustMinutes}분');
  }

  Widget _congestionCard(DailyPlanModel plan) {
    return _miniCard(Icons.traffic, const Color(0xFFEF5350), '혼잡도 보정',
        '+${plan.congestionAdjustMinutes}분');
  }

  Widget _miniCard(IconData icon, Color iconColor, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[500]),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _vertDivider() =>
      Container(width: 1, height: 48, color: Colors.grey[200]);

  Widget _buildLateWarningCard() {
    final isPast = _taxiDeadline != null && _now.isAfter(_taxiDeadline!);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LateResponseScreen(
            classTime: _nextClassTime!,
            taxiDeadline: _taxiDeadline!,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF9800)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_taxi, color: Color(0xFFFF6F00), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPast
                        ? '오늘은 포기하는 것도 방법입니다'
                        : '택시 마지노선: ${_fmt(_taxiDeadline!)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPast
                        ? '교수님께 연락해 보세요'
                        : '이 시각까지 택시를 타면 수업에 맞출 수 있습니다',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFFF9800)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrepTimer() {
    final elapsed = _now.difference(_prepStartedAt!);
    final m = elapsed.inMinutes;
    final s = elapsed.inSeconds.remainder(60);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            '준비 중 ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
            style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_arrived) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null, // 도착 완료 후 비활성 → 중복 기록 방지
          icon: const Icon(Icons.check_circle),
          label: const Text('도착 완료'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF4CAF50),
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    if (_departed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final arrivedAt = DateTime.now();
            final sched = SettingsService.instance.todayNextSchedule;
            final scheduleId = sched?.scheduleId;
            // 목표 도착 시각 대비 정시/지각 판정
            String? resultStatus;
            final tParts = sched?.targetArrivalTime.split(':');
            if (tParts != null && tParts.length == 2) {
              final target = DateTime(arrivedAt.year, arrivedAt.month,
                  arrivedAt.day, int.parse(tParts[0]), int.parse(tParts[1]));
              resultStatus = arrivedAt.isAfter(target) ? 'LATE' : 'ON_TIME';
            }
            SettingsService.instance.saveArrivalLog(
              arrivedAt: arrivedAt,
              scheduleId: scheduleId,
            );
            if (scheduleId != null) {
              final dep = _departedAt ?? _activePlan?.departedAt;
              final actualMinutes = dep != null
                  ? arrivedAt.difference(dep).inMinutes
                  : null;
              DailyPlanService.instance.updateArrivedAt(
                scheduleId,
                arrivedAt,
                actualTravelMinutes: actualMinutes,
                resultStatus: resultStatus,
              );
            }
            setState(() => _arrived = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resultStatus == 'LATE'
                    ? '지각으로 기록되었습니다.'
                    : resultStatus == 'ON_TIME'
                        ? '정시 도착! 수고하셨어요!'
                        : '도착이 기록되었습니다. 수고하셨어요!'),
              ),
            );
          },
          icon: const Icon(Icons.school),
          label: const Text('도착 확인'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _prepStartedAt != null
                ? null
                : () {
                    final startedAt = DateTime.now();
                    setState(() => _prepStartedAt = startedAt);
                    SettingsService.instance.savePrepStartedAt(startedAt);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('준비 타이머가 시작됩니다!')),
                    );
                  },
            icon: const Icon(Icons.alarm_on),
            label: Text(_prepStartedAt != null ? '준비 중...' : '준비 시작'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              final departedAt = DateTime.now();
              final scheduleId = SettingsService.instance.todayNextSchedule?.scheduleId;
              if (_prepStartedAt != null) {
                SettingsService.instance.savePrepLog(
                  startedAt: _prepStartedAt!,
                  departedAt: departedAt,
                  scheduleId: scheduleId,
                );
              }
              if (scheduleId != null) {
                DailyPlanService.instance.updateDepartedAt(scheduleId, departedAt);
              }
              SettingsService.instance.savePrepStartedAt(null); // 준비 타이머 종료
              setState(() {
                _departed = true;
                _departedAt = departedAt;
                _prepStartedAt = null; // 출발 후 준비 타이머 닫기
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('출발 시각 ${_fmt(departedAt)} 기록됨')),
              );
            },
            icon: const Icon(Icons.directions_run),
            label: const Text('출발'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _statusColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
