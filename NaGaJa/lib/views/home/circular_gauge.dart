import 'dart:math' as math;
import 'package:flutter/material.dart';

class CircularGauge extends StatelessWidget {
  final DateTime? classTime;
  final DateTime now;
  final int prepMinutes;
  final int travelMinutes;

  const CircularGauge({
    super.key,
    required this.classTime,
    required this.now,
    required this.prepMinutes,
    required this.travelMinutes,
  });

  static const double _size = 300;
  static const double _stroke = 26;
  static const double _arcRadius = 100;
  static const Offset _center = Offset(_size / 2, _size / 2);

  static const _green = Color(0xFF4CAF50);
  static const _orange = Color(0xFFFF9800);
  static const _red = Color(0xFFF44336);

  @override
  Widget build(BuildContext context) {
    if (classTime == null) {
      return SizedBox(
        width: _size,
        height: _size,
        child: Center(
          child: Text('예정된 수업 없음',
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ),
      );
    }

    final goNowBoundaryMin = prepMinutes + travelMinutes + 10;
    final lateMin = travelMinutes;
    final windowMin = goNowBoundaryMin * 2.0;
    final freeMin = windowMin - goNowBoundaryMin;
    final goNowMin = goNowBoundaryMin - lateMin;

    final remaining = classTime!.difference(now);
    final remainingMin = remaining.inSeconds / 60.0;
    final dotProgress = ((windowMin - remainingMin) / windowMin).clamp(0.0, 1.0);

    final freeAngle = freeMin / windowMin * 2 * math.pi;
    final goNowAngle = goNowMin / windowMin * 2 * math.pi;
    final lateAngle = lateMin / windowMin * 2 * math.pi;

    final goNowBoundaryTime = classTime!.subtract(Duration(minutes: goNowBoundaryMin));
    final lateBoundaryTime = classTime!.subtract(Duration(minutes: lateMin));
    final shouldDepartAt =
        classTime!.subtract(Duration(minutes: prepMinutes + travelMinutes));

    final bool isLate = remainingMin < lateMin;
    final bool isGoNow = !isLate && remainingMin <= goNowBoundaryMin;

    Color statusColor;
    String statusLabel, timeDisplay, subtext;

    if (isLate) {
      statusColor = _red;
      statusLabel = '지각 위기';
      timeDisplay = _fmt(remaining.isNegative ? Duration.zero : remaining);
      subtext = remaining.isNegative ? '이미 지각했습니다' : '지금 출발해도 지각';
    } else if (isGoNow) {
      statusColor = _orange;
      statusLabel = '나가자!';
      timeDisplay = _fmt(remaining);
      subtext = '수업까지 남은 시간';
    } else {
      statusColor = _green;
      statusLabel = '여유';
      final untilDepart = shouldDepartAt.difference(now);
      timeDisplay = _fmt(untilDepart.isNegative ? Duration.zero : untilDepart);
      subtext = '출발까지 남은 시간';
    }

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(_size, _size),
            painter: _GaugePainter(
              freeAngle: freeAngle,
              goNowAngle: goNowAngle,
              lateAngle: lateAngle,
              dotProgress: dotProgress,
              classTime: classTime!,
              goNowBoundaryTime: goNowBoundaryTime,
              lateBoundaryTime: lateBoundaryTime,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(statusLabel,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(
                timeDisplay,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  letterSpacing: 4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(subtext,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _GaugePainter extends CustomPainter {
  final double freeAngle;
  final double goNowAngle;
  final double lateAngle;
  final double dotProgress;
  final DateTime classTime;
  final DateTime goNowBoundaryTime;
  final DateTime lateBoundaryTime;

  static const _stroke = CircularGauge._stroke;
  static const _r = CircularGauge._arcRadius;
  static const _c = CircularGauge._center;

  const _GaugePainter({
    required this.freeAngle,
    required this.goNowAngle,
    required this.lateAngle,
    required this.dotProgress,
    required this.classTime,
    required this.goNowBoundaryTime,
    required this.lateBoundaryTime,
  });

  static const double _startAngle = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    // ── 세 개의 호 그리기 ──────────────────────────────────────────────────────
    _drawArc(canvas, _startAngle, freeAngle, const Color(0xFF4CAF50));
    _drawArc(canvas, _startAngle + freeAngle, goNowAngle, const Color(0xFFFF9800));
    _drawArc(canvas, _startAngle + freeAngle + goNowAngle, lateAngle,
        const Color(0xFFF44336));

    // ── 이동 점 ──────────────────────────────────────────────────────────────
    final dotA = _startAngle + dotProgress * 2 * math.pi;
    final dx = _c.dx + _r * math.cos(dotA);
    final dy = _c.dy + _r * math.sin(dotA);
    canvas.drawCircle(
        Offset(dx, dy), _stroke / 2 + 4, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(dx, dy), _stroke / 2, Paint()..color = Colors.black87);

    // ── 경계 시각 라벨 ─────────────────────────────────────────────────────────
    _drawTimePill(canvas, _startAngle, _fmtTime(classTime));
    _drawTimePill(canvas, _startAngle + freeAngle, _fmtTime(goNowBoundaryTime));
    _drawTimePill(
        canvas, _startAngle + freeAngle + goNowAngle, _fmtTime(lateBoundaryTime));

    // ── 구역 이름 라벨 ─────────────────────────────────────────────────────────
    if (freeAngle > 0.4) {
      _drawZoneLabel(canvas, _startAngle + freeAngle / 2, '여유',
          const Color(0xFF4CAF50));
    }
    if (goNowAngle > 0.4) {
      _drawZoneLabel(canvas, _startAngle + freeAngle + goNowAngle / 2, '나가자',
          const Color(0xFFFF9800));
    }
    if (lateAngle > 0.4) {
      _drawZoneLabel(
          canvas,
          _startAngle + freeAngle + goNowAngle + lateAngle / 2,
          '지각',
          const Color(0xFFF44336));
    }
  }

  void _drawArc(Canvas canvas, double start, double sweep, Color color) {
    if (sweep <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: _c, radius: _r),
      start, sweep, false,
      Paint()
        ..color = color
        ..strokeWidth = _stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt,
    );
  }

  // 시각 라벨: 검은 pill 배경에 흰 텍스트
  void _drawTimePill(Canvas canvas, double angle, String text) {
    final pillR = _r + _stroke / 2 + 16;
    final x = _c.dx + pillR * math.cos(angle);
    final y = _c.dy + pillR * math.sin(angle);

    final tp = _tp(text, Colors.white, 11, FontWeight.w600);
    const hPad = 7.0;
    const vPad = 4.0;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x, y),
          width: tp.width + hPad * 2,
          height: tp.height + vPad * 2),
      const Radius.circular(7),
    );
    canvas.drawRRect(bgRect, Paint()..color = Colors.black87);
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  // 구역 이름 라벨: 컬러 텍스트만
  void _drawZoneLabel(Canvas canvas, double angle, String text, Color color) {
    final labelR = _r + _stroke / 2 + 38;
    final x = _c.dx + labelR * math.cos(angle);
    final y = _c.dy + labelR * math.sin(angle);
    final tp = _tp(text, color, 13, FontWeight.w500);
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  TextPainter _tp(String text, Color color, double fs, FontWeight fw) {
    return TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: fs, fontWeight: fw)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  bool shouldRepaint(_GaugePainter old) =>
      freeAngle != old.freeAngle ||
      goNowAngle != old.goNowAngle ||
      lateAngle != old.lateAngle ||
      dotProgress != old.dotProgress;
}
