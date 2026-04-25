import 'dart:async';
import 'package:flutter/material.dart';

class LateResponseScreen extends StatefulWidget {
  final DateTime classTime;
  final DateTime taxiDeadline;

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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  bool get _isPastDeadline => _now.isAfter(widget.taxiDeadline);

  @override
  Widget build(BuildContext context) {
    final isPast = _isPastDeadline;

    return Scaffold(
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
              if (!isPast) ...[
                const Text(
                  '택시 마지노선',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
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
