import 'package:flutter/material.dart';

enum AttendanceStatus { onTime, late, absent, none }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _isWeekView = true;
  DateTime _focusDate = DateTime.now();

  // Mock 출결 데이터 - 실제로는 Firebase에서 로드
  final Map<String, AttendanceStatus> _attendance = {
    '2026-04-20': AttendanceStatus.onTime,
    '2026-04-21': AttendanceStatus.onTime,
    '2026-04-22': AttendanceStatus.late,
    '2026-04-23': AttendanceStatus.onTime,
    '2026-04-24': AttendanceStatus.absent,
  };

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  AttendanceStatus _statusOf(DateTime d) =>
      _attendance[_key(d)] ?? AttendanceStatus.none;

  Color _colorOf(AttendanceStatus s) => switch (s) {
        AttendanceStatus.onTime => const Color(0xFF4CAF50),
        AttendanceStatus.late => const Color(0xFFF44336),
        AttendanceStatus.absent => Colors.grey,
        AttendanceStatus.none => Colors.transparent,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('출결 기록'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('주간')),
                ButtonSegment(value: false, label: Text('월간')),
              ],
              selected: {_isWeekView},
              onSelectionChanged: (s) =>
                  setState(() => _isWeekView = s.first),
              style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNavigator(),
          const SizedBox(height: 12),
          _isWeekView ? _buildWeekView() : _buildMonthView(),
          const SizedBox(height: 12),
          _buildLegend(),
          const SizedBox(height: 12),
          _buildStats(),
        ],
      ),
    );
  }

  Widget _buildNavigator() {
    final label = _isWeekView
        ? '${_focusDate.month}월 ${_weekNumber(_focusDate)}주'
        : '${_focusDate.year}년 ${_focusDate.month}월';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() {
            _focusDate = _isWeekView
                ? _focusDate.subtract(const Duration(days: 7))
                : DateTime(_focusDate.year, _focusDate.month - 1);
          }),
        ),
        Text(label,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() {
            _focusDate = _isWeekView
                ? _focusDate.add(const Duration(days: 7))
                : DateTime(_focusDate.year, _focusDate.month + 1);
          }),
        ),
      ],
    );
  }

  int _weekNumber(DateTime d) {
    final first = DateTime(d.year, d.month, 1);
    return ((d.day + first.weekday - 2) ~/ 7) + 1;
  }

  Widget _buildWeekView() {
    final monday = _focusDate.subtract(Duration(days: _focusDate.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final day = days[i];
          final status = _statusOf(day);
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;

          return Column(
            children: [
              Text(labels[i],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: isToday
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.blue : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorOf(status),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMonthView() {
    final firstDay = DateTime(_focusDate.year, _focusDate.month, 1);
    final daysInMonth =
        DateTime(_focusDate.year, _focusDate.month + 1, 0).day;
    final startPad = firstDay.weekday - 1;
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['월', '화', '수', '목', '금', '토', '일']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 1),
            itemCount: startPad + daysInMonth,
            itemBuilder: (_, index) {
              if (index < startPad) return const SizedBox();
              final day = index - startPad + 1;
              final date =
                  DateTime(_focusDate.year, _focusDate.month, day);
              final status = _statusOf(date);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? Colors.blue : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorOf(status)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot('정시', const Color(0xFF4CAF50)),
        const SizedBox(width: 20),
        _legendDot('지각', const Color(0xFFF44336)),
        const SizedBox(width: 20),
        _legendDot('결석', Colors.grey),
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStats() {
    final values = _attendance.values;
    final onTime =
        values.where((s) => s == AttendanceStatus.onTime).length;
    final late = values.where((s) => s == AttendanceStatus.late).length;
    final absent =
        values.where((s) => s == AttendanceStatus.absent).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('정시', onTime, const Color(0xFF4CAF50)),
          _statItem('지각', late, const Color(0xFFF44336)),
          _statItem('결석', absent, Colors.grey),
        ],
      ),
    );
  }

  Widget _statItem(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
