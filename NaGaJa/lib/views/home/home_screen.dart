import 'dart:async';
import 'package:flutter/material.dart';
import '../late_response/late_response_screen.dart';

enum _Status { free, goNow, lateRisk }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  // 실제로는 Firebase/설정에서 로드. 지금은 mock 데이터
  late final DateTime _nextClassTime;
  final int _prepMinutes = 30;
  final int _travelMinutes = 20;

  bool _readyPressed = false;
  bool _departed = false;

  @override
  void initState() {
    super.initState();
    _nextClassTime = DateTime.now().add(const Duration(hours: 1, minutes: 10));
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  _Status get _status {
    final remaining = _nextClassTime.difference(_now).inMinutes;
    final needed = _prepMinutes + _travelMinutes;
    if (remaining > needed + 10) return _Status.free;
    if (remaining >= _travelMinutes) return _Status.goNow;
    return _Status.lateRisk;
  }

  Color get _statusColor => switch (_status) {
        _Status.free => const Color(0xFF4CAF50),
        _Status.goNow => const Color(0xFFFF9800),
        _Status.lateRisk => const Color(0xFFF44336),
      };

  String get _statusLabel => switch (_status) {
        _Status.free => '여유',
        _Status.goNow => '나가자!',
        _Status.lateRisk => '지각 위기',
      };

  String get _statusSubtext {
    final remaining = _nextClassTime.difference(_now).inMinutes;
    return switch (_status) {
      _Status.free => '${remaining - _travelMinutes - _prepMinutes}분 여유 있음',
      _Status.goNow => '지금 준비를 시작하세요',
      _Status.lateRisk => '택시 마지노선을 확인하세요',
    };
  }

  Duration get _remaining => _nextClassTime.difference(_now);

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDuration(Duration d) {
    if (d.isNegative) return '지각';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    if (m >= 60) return '${d.inHours}시간 ${m.remainder(60)}분';
    if (m > 0) return '${m}분 ${s}초';
    return '${s}초';
  }

  DateTime get _shouldDepartAt =>
      _nextClassTime.subtract(Duration(minutes: _prepMinutes + _travelMinutes));

  DateTime get _taxiDeadline =>
      _nextClassTime.subtract(Duration(minutes: (_travelMinutes * 0.7).round()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildClock(),
              const SizedBox(height: 32),
              _buildStatusGauge(),
              const SizedBox(height: 24),
              _buildInfoCard(),
              const SizedBox(height: 16),
              if (_status == _Status.lateRisk) ...[
                _buildLateWarningCard(),
                const SizedBox(height: 16),
              ],
              _buildActionButtons(),
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
          '다음 수업 ${_fmt(_nextClassTime)}',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStatusGauge() {
    final color = _statusColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 5),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 4),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color),
            child: Text(_statusLabel),
          ),
          const SizedBox(height: 8),
          Text(
            _fmtDuration(_remaining),
            style: TextStyle(
                fontSize: 18, color: color, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            _statusSubtext,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
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
          _infoItem('준비', '${_prepMinutes}분', Icons.coffee_outlined),
          _vertDivider(),
          _infoItem('이동', '${_travelMinutes}분', Icons.directions_bus_outlined),
          _vertDivider(),
          _infoItem('출발', _fmt(_shouldDepartAt), Icons.schedule),
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
    final isPast = _now.isAfter(_taxiDeadline);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LateResponseScreen(
            classTime: _nextClassTime,
            taxiDeadline: _taxiDeadline,
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
                        : '택시 마지노선: ${_fmt(_taxiDeadline)}',
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _readyPressed
                ? null
                : () {
                    setState(() => _readyPressed = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('준비 타이머가 시작됩니다!')),
                    );
                  },
            icon: const Icon(Icons.alarm_on),
            label: Text(_readyPressed ? '준비 중...' : '준비 시작'),
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
              setState(() => _departed = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('출발 시각 ${_fmt(_now)} 기록됨')),
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
