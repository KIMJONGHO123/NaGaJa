// =============================================================================
// settings_screen.dart — 개인 설정 화면
//
// [설정 항목]
//   1. 시간표   — 요일별 첫 수업 시각 (TimePicker로 입력)
//   2. 위치     — 출발지(집)·목적지(학교) 주소 입력
//   3. 교통수단 — 버스·지하철·도보 중 선택 (선택에 따라 이동시간 보정 방식이 달라짐)
//   4. 준비시간 — 세면·옷 입기 등 개인 준비시간 (슬라이더, 10~90분)
//   5. 기기연결 — 라즈베리파이 물리 알람시계 BLE 연결 관리
//
// [데이터 흐름 계획]
//   현재: StatefulWidget 내부 변수에만 보관 (앱 재시작 시 초기화)
//   추후: Firebase Firestore에 저장 → 앱 재시작 후에도 설정값 유지
// =============================================================================

import 'package:flutter/material.dart';

// 교통수단 선택지
// 종류별로 시간 계산 엔진에서 다른 보정 방식이 적용됨
enum TransportMode { bus, subway, walk }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // TextEditingController: TextField의 입력값을 읽고 메모리를 관리
  // dispose()에서 반드시 해제해야 메모리 누수가 없음
  final _homeController = TextEditingController(text: '부산시 사상구');
  final _schoolController = TextEditingController(text: '동의대학교');

  TransportMode _transport = TransportMode.bus; // 선택된 교통수단
  int _prepMinutes = 30;                        // 개인 준비시간 (분)

  // 요일별 첫 수업 시각 (1=월 ~ 5=금)
  // null이면 해당 요일에 수업 없음 → 알람 미발송
  final Map<int, TimeOfDay?> _schedule = {
    1: const TimeOfDay(hour: 9, minute: 0),   // 월요일 09:00
    2: const TimeOfDay(hour: 10, minute: 30), // 화요일 10:30
    3: const TimeOfDay(hour: 9, minute: 0),   // 수요일 09:00
    4: null,                                   // 목요일 수업 없음
    5: const TimeOfDay(hour: 13, minute: 0),  // 금요일 13:00
  };

  @override
  void dispose() {
    // TextEditingController는 위젯 소멸 시 명시적으로 해제해야 함
    _homeController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 저장 버튼 — 추후 Firestore 저장 로직 연결 예정
          TextButton(
            onPressed: _save,
            child: const Text('저장'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header('시간표'),
          _buildScheduleCard(),   // 요일별 수업 시각 선택
          const SizedBox(height: 16),
          _header('위치'),
          _buildLocationCard(),   // 출발지·목적지 입력
          const SizedBox(height: 16),
          _header('교통수단'),
          _buildTransportCard(),  // 버스·지하철·도보 선택
          const SizedBox(height: 16),
          _header('개인 설정'),
          _buildPrepTimeCard(),   // 준비시간 슬라이더
          const SizedBox(height: 16),
          _header('기기 연결'),
          _buildDeviceCard(),     // BLE 물리 시계 연결
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // 추후 Firestore에 저장하는 로직 연결 예정
  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('설정이 저장되었습니다')),
    );
  }

  // 섹션 헤더 (회색 소제목)
  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
      ),
    );
  }

  // 공통 카드 컨테이너 (흰 배경 + 둥근 모서리 + 그림자)
  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: child,
    );
  }

  // ── 시간표 카드 ───────────────────────────────────────────────────────────
  // 요일을 탭하면 Flutter 내장 TimePicker가 열려 수업 시각을 선택
  Widget _buildScheduleCard() {
    const days = ['월', '화', '수', '목', '금'];
    return _card(
      child: Column(
        children: List.generate(5, (i) {
          final weekday = i + 1;
          final time = _schedule[weekday];
          return Column(
            children: [
              ListTile(
                title: Text(days[i]),
                trailing: GestureDetector(
                  onTap: () async {
                    // Flutter 내장 시간 선택 다이얼로그
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          time ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    // null이면 사용자가 취소한 것 → 기존 값 유지
                    if (picked != null) {
                      setState(() => _schedule[weekday] = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      // 수업이 있으면 파란색, 없으면 회색 배경
                      color: time != null
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      time != null
                          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                          : '없음',
                      style: TextStyle(
                        color: time != null ? Colors.blue : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              if (i < 4) const Divider(height: 1, indent: 16),
            ],
          );
        }),
      ),
    );
  }

  // ── 위치 카드 ─────────────────────────────────────────────────────────────
  // 출발지·목적지 텍스트 입력 (추후 카카오 주소 검색 API 연동 예정)
  Widget _buildLocationCard() {
    return _card(
      child: Column(
        children: [
          _locationTile('출발지 (집)', _homeController, Icons.home_outlined),
          const Divider(height: 1, indent: 56),
          _locationTile(
              '목적지 (학교)', _schoolController, Icons.school_outlined),
        ],
      ),
    );
  }

  Widget _locationTile(
      String label, TextEditingController controller, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      // TextField에 controller를 연결해 입력값을 프로그래밍으로 읽을 수 있게 함
      subtitle: TextField(
        controller: controller,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  // ── 교통수단 카드 ─────────────────────────────────────────────────────────
  // 선택된 교통수단에 따라 시간 계산 엔진의 보정 방식이 달라짐:
  //   버스     → 배차 대기시간 추가 (평균 5~10분)
  //   지하철   → 정시성이 높아 보정 없음
  //   도보     → 날씨(강수·폭염) 영향을 가장 크게 반영
  Widget _buildTransportCard() {
    final desc = switch (_transport) {
      TransportMode.bus    => '버스: 배차 대기시간이 이동시간에 추가됩니다',
      TransportMode.subway => '지하철: 정시성이 높아 보정 없이 적용됩니다',
      TransportMode.walk   => '도보: 날씨 영향이 가장 크게 반영됩니다',
    };
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('주 교통수단',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 12),
            // Material 3 SegmentedButton: 단일 선택 토글 버튼 그룹
            SegmentedButton<TransportMode>(
              segments: const [
                ButtonSegment(
                    value: TransportMode.bus,
                    icon: Icon(Icons.directions_bus),
                    label: Text('버스')),
                ButtonSegment(
                    value: TransportMode.subway,
                    icon: Icon(Icons.train),
                    label: Text('지하철')),
                ButtonSegment(
                    value: TransportMode.walk,
                    icon: Icon(Icons.directions_walk),
                    label: Text('도보')),
              ],
              selected: {_transport},
              onSelectionChanged: (s) =>
                  setState(() => _transport = s.first),
            ),
            const SizedBox(height: 10),
            // 선택에 따라 안내 문구 변경
            Text(desc,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ── 준비시간 카드 ─────────────────────────────────────────────────────────
  // 세면·옷 입기 등 '집을 나서기까지' 걸리는 개인 준비시간
  // 이 값이 시간 계산 엔진의 핵심 입력값이 됨: 출발시각 = 수업시각 - 이동 - 준비
  Widget _buildPrepTimeCard() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('개인 준비시간',
                    style: TextStyle(fontSize: 15)),
                // 슬라이더 값과 동기화된 현재 준비시간 표시
                Text('$_prepMinutes분',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            // 슬라이더: 10분~90분 범위, 5분 단위(divisions: 16)
            Slider(
              value: _prepMinutes.toDouble(),
              min: 10,
              max: 90,
              divisions: 16, // (90-10)/5 = 16 단계
              label: '$_prepMinutes분',
              onChanged: (v) => setState(() => _prepMinutes = v.round()),
            ),
            Text('세면, 옷 입기 등 집을 나서기까지 걸리는 시간',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ── BLE 기기 연결 카드 ────────────────────────────────────────────────────
  // 라즈베리파이 기반 물리 알람시계와 Bluetooth Low Energy로 연결
  // 추후 flutter_blue_plus 패키지로 실제 BLE 스캔·연결 구현 예정
  Widget _buildDeviceCard() {
    return _card(
      child: ListTile(
        leading: const Icon(Icons.bluetooth, color: Colors.blue),
        title: const Text('물리 알람시계'),
        subtitle: const Text('연결되지 않음',
            style: TextStyle(color: Colors.grey)),
        trailing: ElevatedButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            // 추후: BLE 스캔 → 디바이스 목록 표시 → 연결 처리
            const SnackBar(content: Text('BLE 스캔 중...')),
          ),
          style: ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('연결'),
        ),
      ),
    );
  }
}
