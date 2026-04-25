// =============================================================================
// home_screen.dart — 메인 홈 화면 (서비스의 핵심 화면)
//
// [화면 구성]
//   1. 실시간 시계       — 1초마다 갱신되는 현재 시각
//   2. 상태 게이지       — 여유 / 나가자 / 지각위기 3단계 색상 원형 UI
//   3. 정보 카드         — 준비시간·이동시간·권장 출발시각 요약
//   4. 택시 마지노선 카드 — 지각위기 상태일 때만 표시
//   5. 액션 버튼         — 준비시작 → 출발 → 도착 순서 흐름
//
// [상태 판별 공식 (계획서 기준)]
//   출발 시각       = 수업 시각 - (이동시간 + 준비시간)
//   준비 알림 시각  = 출발 시각 - 개인 준비시간
//   택시 마지노선   = 수업 시각 - (이동시간 × 0.7)  ← 택시는 약 30% 빠름
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../late_response/late_response_screen.dart';

// ---------------------------------------------------------------------------
// 3단계 상태 정의
//   free     (여유)     — 남은 시간 > 준비 + 이동 + 10분 버퍼
//   goNow    (나가자)   — 이동시간 ≤ 남은 시간 ≤ 준비 + 이동 + 10분
//   lateRisk (지각위기) — 남은 시간 < 이동시간  (지금 출발해도 지각)
// ---------------------------------------------------------------------------
enum _Status { free, goNow, lateRisk }

// StatefulWidget: Timer·상태 변수가 필요하므로 Stateful로 선언
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Timer _clockTimer; // 1초마다 UI를 갱신하는 타이머
  DateTime _now = DateTime.now(); // 현재 시각 (매초 갱신)

  // ── Mock 데이터 (추후 Firebase Firestore에서 로드 예정) ──────────────────
  late final DateTime _nextClassTime; // 오늘 다음 수업 시작 시각
  final int _prepMinutes = 30;        // 개인 준비시간 (설정값)
  final int _travelMinutes = 20;      // 이동시간 (Kakao Maps API 로드 예정)
  // ──────────────────────────────────────────────────────────────────────────

  // 버튼 흐름 상태: 준비시작 누름 여부 / 출발 누름 여부
  bool _readyPressed = false;
  bool _departed = false;

  @override
  void initState() {
    super.initState();
    // Mock: 지금으로부터 1시간 10분 뒤를 수업 시작으로 설정
    _nextClassTime = DateTime.now().add(const Duration(hours: 1, minutes: 10));

    // 1초 주기 타이머 — 매 틱마다 _now를 갱신해 시계와 상태를 재계산
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    // 위젯이 트리에서 제거될 때 타이머를 반드시 취소 (메모리 누수 방지)
    _clockTimer.cancel();
    super.dispose();
  }

  // ── 핵심 상태 판별 로직 ──────────────────────────────────────────────────
  // 매초 _now가 바뀔 때마다 재계산되어 게이지 색상·텍스트가 자동 갱신됩니다.
  _Status get _status {
    final remaining = _nextClassTime.difference(_now).inMinutes; // 수업까지 남은 분
    final needed = _prepMinutes + _travelMinutes;                 // 준비 + 이동 총 필요 시간

    if (remaining > needed + 10) return _Status.free;      // 10분 버퍼 이상 여유
    if (remaining >= _travelMinutes) return _Status.goNow; // 이동시간만큼은 남음
    return _Status.lateRisk;                               // 이동시간도 부족 → 지각 확실
  }
  // ──────────────────────────────────────────────────────────────────────────

  // 상태별 색상 매핑 (앱 화면과 물리 시계 LED가 동일한 색상 사용)
  Color get _statusColor => switch (_status) {
        _Status.free     => const Color(0xFF4CAF50), // 초록
        _Status.goNow    => const Color(0xFFFF9800), // 주황
        _Status.lateRisk => const Color(0xFFF44336), // 빨강
      };

  // 상태별 한글 레이블
  String get _statusLabel => switch (_status) {
        _Status.free     => '여유',
        _Status.goNow    => '나가자!',
        _Status.lateRisk => '지각 위기',
      };

  // 상태별 보조 안내 문구
  String get _statusSubtext {
    final remaining = _nextClassTime.difference(_now).inMinutes;
    return switch (_status) {
      _Status.free     => '${remaining - _travelMinutes - _prepMinutes}분 여유 있음',
      _Status.goNow    => '지금 준비를 시작하세요',
      _Status.lateRisk => '택시 마지노선을 확인하세요',
    };
  }

  // 수업까지 남은 시간 (Duration)
  Duration get _remaining => _nextClassTime.difference(_now);

  // HH:mm 형식 포맷터
  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // Duration → "X분 Y초" 형식 포맷터
  String _fmtDuration(Duration d) {
    if (d.isNegative) return '지각';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    if (m >= 60) return '${d.inHours}시간 ${m.remainder(60)}분';
    if (m > 0) return '${m}분 ${s}초';
    return '${s}초';
  }

  // 권장 출발 시각 = 수업 시각 - (준비 + 이동)
  DateTime get _shouldDepartAt =>
      _nextClassTime.subtract(Duration(minutes: _prepMinutes + _travelMinutes));

  // 택시 마지노선 = 수업 시각 - (이동시간 × 0.7)
  // 택시는 일반 버스 대비 약 30% 빠르다고 가정
  DateTime get _taxiDeadline =>
      _nextClassTime.subtract(Duration(minutes: (_travelMinutes * 0.7).round()));

  // ── UI 빌드 ──────────────────────────────────────────────────────────────
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
              _buildClock(),           // ① 현재 시각
              const SizedBox(height: 32),
              _buildStatusGauge(),     // ② 상태 게이지 (핵심 UI)
              const SizedBox(height: 24),
              _buildInfoCard(),        // ③ 준비·이동·출발 정보 카드
              const SizedBox(height: 16),
              // ④ 지각위기일 때만 택시 마지노선 카드 표시
              if (_status == _Status.lateRisk) ...[
                _buildLateWarningCard(),
                const SizedBox(height: 16),
              ],
              _buildActionButtons(),   // ⑤ 행동 버튼
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ① 현재 시각 위젯 — 초 단위까지 표시
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
            fontWeight: FontWeight.w200, // 얇은 폰트로 시계 느낌 강조
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

  // ② 상태 게이지 위젯
  // AnimatedContainer: 상태가 바뀔 때 색상·그림자가 400ms 동안 부드럽게 전환
  Widget _buildStatusGauge() {
    final color = _statusColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400), // 상태 전환 애니메이션 시간
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),  // 배경: 상태 색상 10% 불투명도
        border: Border.all(color: color, width: 5),
        boxShadow: [
          // 상태 색상 글로우 효과 — 위기감/안도감을 시각적으로 강화
          BoxShadow(
              color: color.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 4),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 상태 레이블 — 글자 스타일도 부드럽게 전환
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color),
            child: Text(_statusLabel),
          ),
          const SizedBox(height: 8),
          // D-time: 수업까지 남은 시간 카운트다운
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

  // ③ 정보 카드 — 준비시간 / 이동시간 / 권장 출발시각을 한눈에 표시
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
          // 권장 출발 시각 = 수업시각 - 준비 - 이동
          _infoItem('출발', _fmt(_shouldDepartAt), Icons.schedule),
        ],
      ),
    );
  }

  // 정보 항목 공통 위젯 (아이콘 + 값 + 레이블)
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

  // 세로 구분선
  Widget _vertDivider() =>
      Container(width: 1, height: 48, color: Colors.grey[200]);

  // ④ 택시 마지노선 카드 — 지각위기 상태일 때만 _build 로직에서 호출
  // 탭하면 LateResponseScreen으로 이동 (상세 대응 화면)
  Widget _buildLateWarningCard() {
    final isPast = _now.isAfter(_taxiDeadline); // 마지노선이 이미 지났는지 여부
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
                    // 마지노선 경과 전후로 메시지 자동 전환
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

  // ⑤ 액션 버튼 — 사용자 행동에 따라 3단계로 변화
  //   1단계: [준비 시작] + [출발]  ← 기본 상태
  //   2단계: [출발]만 활성          ← 준비시작 누른 후
  //   3단계: [도착 확인]            ← 출발 누른 후 (실측 이동시간 기록 목적)
  Widget _buildActionButtons() {
    // 출발 후에는 도착 확인 버튼만 표시
    if (_departed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            // 추후: 도착 시각을 Firestore에 저장 → 실측 이동시간 누적
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
            // 한 번 누르면 비활성화 — 중복 타이머 방지
            onPressed: _readyPressed
                ? null
                : () {
                    setState(() => _readyPressed = true);
                    // 추후: 준비 타이머 카운트다운 시작 + Firestore에 이벤트 기록
                    // 물리 시계(라즈베리파이)에도 Wi-Fi로 이벤트 전송 예정
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
              // 추후: 실제 출발 시각을 Firestore에 저장 → 지각 여부 판단에 활용
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('출발 시각 ${_fmt(_now)} 기록됨')),
              );
            },
            icon: const Icon(Icons.directions_run),
            label: const Text('출발'),
            // 출발 버튼 색상 = 현재 상태 색상 (여유=초록, 나가자=주황, 지각위기=빨강)
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
