// =============================================================================
// calendar_screen.dart — 출결 기록 캘린더 화면
//
// [화면 구성]
//   - 주간 뷰: 이번 주 7일을 가로로 나열, 날짜별 출결 도트 표시
//   - 월간 뷰: 달력 그리드 형태로 한 달 전체 출결 시각화
//   - 통계 카드: 정시·지각·결석 횟수 요약
//
// [출결 상태 3종]
//   onTime (정시) — 초록 도트
//   late   (지각) — 빨간 도트
//   absent (결석) — 회색 도트
//   none   (기록 없음) — 투명 (미래 날짜 등)
//
// [데이터 흐름 계획]
//   현재: Map<String, AttendanceStatus> 로컬 Mock 데이터
//   추후: Firebase Firestore에서 실시간 로드 예정
// =============================================================================

import 'package:flutter/material.dart';

// 출결 상태 enum
enum AttendanceStatus { onTime, late, absent, none }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _isWeekView = true;        // 주간/월간 뷰 전환 플래그
  DateTime _focusDate = DateTime.now(); // 현재 탐색 중인 날짜 기준점

  // ── Mock 출결 데이터 ──────────────────────────────────────────────────────
  // Key: 'YYYY-MM-DD' 형식 문자열, Value: 출결 상태
  // 추후 Firebase Firestore의 실제 출결 이력으로 교체 예정
  final Map<String, AttendanceStatus> _attendance = {
    '2026-04-20': AttendanceStatus.onTime,
    '2026-04-21': AttendanceStatus.onTime,
    '2026-04-22': AttendanceStatus.late,
    '2026-04-23': AttendanceStatus.onTime,
    '2026-04-24': AttendanceStatus.absent,
  };
  // ──────────────────────────────────────────────────────────────────────────

  // DateTime → 'YYYY-MM-DD' 키 변환 (Map 조회용)
  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 특정 날짜의 출결 상태 조회 (없으면 none 반환)
  AttendanceStatus _statusOf(DateTime d) =>
      _attendance[_key(d)] ?? AttendanceStatus.none;

  // 출결 상태별 도트 색상 매핑
  Color _colorOf(AttendanceStatus s) => switch (s) {
        AttendanceStatus.onTime => const Color(0xFF4CAF50), // 초록
        AttendanceStatus.late   => const Color(0xFFF44336), // 빨강
        AttendanceStatus.absent => Colors.grey,
        AttendanceStatus.none   => Colors.transparent,      // 미래 날짜
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
          // 주간/월간 전환 버튼 (Material 3 SegmentedButton)
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
          _buildNavigator(), // 이전/다음 주(월) 이동 버튼
          const SizedBox(height: 12),
          // 뷰 모드에 따라 주간 또는 월간 캘린더 표시
          _isWeekView ? _buildWeekView() : _buildMonthView(),
          const SizedBox(height: 12),
          _buildLegend(), // 색상 범례 (정시·지각·결석)
          const SizedBox(height: 12),
          _buildStats(),  // 출결 통계 카드
        ],
      ),
    );
  }

  // 이전/다음 주(월) 이동 네비게이터
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
            // 주간 뷰: 7일 이동 / 월간 뷰: 1달 이동
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

  // 해당 날짜가 몇 주차인지 계산
  int _weekNumber(DateTime d) {
    final first = DateTime(d.year, d.month, 1);
    return ((d.day + first.weekday - 2) ~/ 7) + 1;
  }

  // ── 주간 뷰 ──────────────────────────────────────────────────────────────
  // _focusDate가 속한 주의 월~일 7개 날짜를 가로로 나열
  Widget _buildWeekView() {
    // 해당 주의 월요일 계산
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
          // 오늘 날짜는 파란 원형 테두리로 강조
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;

          return Column(
            children: [
              // 요일 레이블 (월·화·수...)
              Text(labels[i],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 10),
              // 날짜 숫자 (오늘이면 파란 원으로 강조)
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
              // 출결 상태 도트 — 색상으로 정시·지각·결석을 직관적으로 표현
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

  // ── 월간 뷰 ──────────────────────────────────────────────────────────────
  // 7열 GridView로 달력 형태 구현 (외부 패키지 없이 Flutter 기본 위젯만 사용)
  Widget _buildMonthView() {
    final firstDay = DateTime(_focusDate.year, _focusDate.month, 1);
    final daysInMonth =
        DateTime(_focusDate.year, _focusDate.month + 1, 0).day; // 해당 월의 총 일수
    final startPad = firstDay.weekday - 1; // 1일 앞의 빈 칸 수 (월=0, 화=1, ...)
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
          // 요일 헤더 (월~일)
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
          // 날짜 그리드 — startPad만큼 앞에 빈 칸을 넣어 요일을 맞춤
          GridView.builder(
            shrinkWrap: true, // ListView 안에 넣기 위해 스크롤 비활성화
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 1),
            itemCount: startPad + daysInMonth,
            itemBuilder: (_, index) {
              if (index < startPad) return const SizedBox(); // 앞 빈 칸
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
                  // 출결 도트
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

  // 색상 범례 위젯
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

  // ── 출결 통계 카드 ────────────────────────────────────────────────────────
  // 전체 출결 데이터에서 정시·지각·결석 횟수를 집계
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
