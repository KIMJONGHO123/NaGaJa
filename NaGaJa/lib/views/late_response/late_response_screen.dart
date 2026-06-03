// =============================================================================
// late_response_screen.dart — 지각 대응 화면
//
// [진입 조건]
//   홈 화면에서 상태가 '지각위기'(_Status.lateRisk)일 때 택시 마지노선 카드를
//   탭하면 Navigator.push로 이 화면으로 이동합니다.
//
// [화면 로직]
//   taxiDeadline(택시 마지노선)을 기준으로 두 가지 모드로 자동 전환:
//
//   ① 마지노선 전  — 택시 호출을 권유, 마지노선 시각을 크게 표시
//   ② 마지노선 후  — "오늘은 포기" 메시지 + 돌아가기 버튼
//
// [택시 마지노선 계산 공식]
//   taxiDeadline = 수업 시각 - (이동시간 × 0.7)
//   (택시는 버스 대비 약 30% 빠름을 가정)
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';

class LateResponseScreen extends StatefulWidget {
  final DateTime classTime;    // 수업 시작 시각 (홈 화면에서 전달받음)
  final DateTime taxiDeadline; // 택시로 수업에 맞출 수 있는 마지막 시각

  const LateResponseScreen({
    super.key,
    required this.classTime,
    required this.taxiDeadline,
  });

  @override
  State<LateResponseScreen> createState() => _LateResponseScreenState();
}

class _LateResponseScreenState extends State<LateResponseScreen> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 1초마다 현재 시각 갱신 — 마지노선 경과 여부를 실시간으로 체크
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // 화면 이탈 시 타이머 반드시 해제
    super.dispose();
  }

  // HH:mm 형식 포맷터
  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // 현재 시각이 택시 마지노선을 지났는지 여부 (매초 재계산)
  bool get _isPastDeadline => _now.isAfter(widget.taxiDeadline);

  @override
  Widget build(BuildContext context) {
    final isPast = _isPastDeadline;

    return Scaffold(
      // 마지노선 경과 여부에 따라 배경색 자동 전환
      //   경과 전: 노란 계열 (긴박감)
      //   경과 후: 빨간 계열 (포기 모드)
      backgroundColor:
          isPast ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1),
      appBar: AppBar(
        title: const Text('지각 대응'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // 상태에 따라 아이콘 전환 (택시 → 슬픈 얼굴)
              Center(
                child: Icon(
                  isPast ? Icons.sentiment_dissatisfied : Icons.local_taxi,
                  size: 80,
                  color: isPast
                      ? Colors.red[300]
                      : const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(height: 32),

              // ── 마지노선 전 모드 ────────────────────────────────────────
              if (!isPast) ...[
                const Text(
                  '택시 마지노선',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                // 마지노선 시각을 크게 표시 — 사용자가 즉각 인지하도록
                Text(
                  _fmt(widget.taxiDeadline),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6F00),
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '이 시각까지 택시를 타면 ${_fmt(widget.classTime)} 수업에 맞출 수 있습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),

              // ── 마지노선 후 모드 (포기 권장) ──────────────────────────
              ] else ...[
                const Text(
                  '오늘은 포기',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '택시로도 ${_fmt(widget.classTime)} 수업 시작에 맞추기 어렵습니다.\n오늘은 쉬고 다음에 더 잘해봐요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey[700], height: 1.6),
                ),
              ],

              const Spacer(),

              // 마지노선 전에만 택시 호출 버튼 표시
              // 추후: 카카오T·우버 딥링크 연동 예정
              if (!isPast)
                ElevatedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('택시 앱을 실행합니다...')),
                  ),
                  icon: const Icon(Icons.local_taxi),
                  label: const Text('택시 호출하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              const SizedBox(height: 12),

              // 홈 화면으로 돌아가기 (Navigator.pop)
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('돌아가기'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
