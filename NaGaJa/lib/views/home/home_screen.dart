import 'dart:async';
import 'package:flutter/material.dart';
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
  final int _travelMinutes = 20; // 추후 Map API로 대체

  bool _departed = false;
  bool _loading = true;
  DateTime? _prepStartedAt;

  int get _prepMinutes => SettingsService.instance.prepMinutes;

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
    if (mounted) setState(() => _loading = false);
  }

  void _onSettingsChanged() {
    _recomputeNextClass();
    if (mounted) setState(() {});
  }

  // 오늘 이후 가장 가까운 수업 탐색 (최대 7일)
  void _recomputeNextClass() {
    final svc = SettingsService.instance;
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final weekday = date.weekday;
      if (weekday > 5) continue;
      final time = svc.scheduleTime(weekday);
      if (time == null) continue;
      final classTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (classTime.isAfter(now)) {
        _nextClassTime = classTime;
        return;
      }
    }
    _nextClassTime = null;
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
    final needed = _prepMinutes + _travelMinutes;
    if (remaining > needed + 10) return _Status.free;
    if (remaining >= _travelMinutes) return _Status.goNow;
    return _Status.lateRisk;
  }

  Color get _statusColor => switch (_status) {
        _Status.free     => const Color(0xFF4CAF50),
        _Status.goNow    => const Color(0xFFFF9800),
        _Status.lateRisk => const Color(0xFFF44336),
      };

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  DateTime? get _shouldDepartAt =>
      _nextClassTime?.subtract(Duration(minutes: _prepMinutes + _travelMinutes));

  DateTime? get _taxiDeadline =>
      _nextClassTime?.subtract(Duration(minutes: (_travelMinutes * 0.7).round()));

  String? get _nextCourseName {
    if (_nextClassTime == null) return null;
    final name = SettingsService.instance.courseName(_nextClassTime!.weekday);
    return name.isNotEmpty ? name : null;
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
              ),
              const SizedBox(height: 16),
              _buildInfoCard(),
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
          _nextClassTime != null
              ? '다음 수업 ${_fmt(_nextClassTime!)}${_nextCourseName != null ? ' · $_nextCourseName' : ''}'
              : '예정된 수업 없음',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final departStr = _shouldDepartAt != null ? _fmt(_shouldDepartAt!) : '--:--';
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _infoItem('준비', '$_prepMinutes분', Icons.coffee_outlined),
          _vertDivider(),
          _infoItem('이동', '$_travelMinutes분', Icons.directions_bus_outlined),
          _vertDivider(),
          _infoItem('출발', departStr, Icons.schedule),
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
    if (_departed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('도착이 기록되었습니다. 수고하셨어요!')),
          ),
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
                    setState(() => _prepStartedAt = DateTime.now());
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
              if (_prepStartedAt != null) {
                SettingsService.instance.savePrepLog(
                  startedAt: _prepStartedAt!,
                  departedAt: departedAt,
                  classTime: _nextClassTime,
                );
              }
              setState(() => _departed = true);
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
