import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/settings_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // 준비시간
  int _prepMinutes = 30;
  int _defaultTravelMinutes = 20;

  // 스케줄 목록 (온보딩 중 추가)
  final List<_ScheduleDraft> _drafts = [];

  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() => _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  void _prevPage() => _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  Future<void> _finish() async {
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수업을 최소 1개 추가해 주세요')),
      );
      return;
    }

    setState(() => _saving = true);

    final svc = SettingsService.instance;
    final uid = svc.userModel?.userId ?? '';

    final newSchedules = _drafts.map((d) => ScheduleEntry(
          scheduleId: '',
          userId: uid,
          title: d.title,
          dayOfWeek: d.dayOfWeek,
          classTime: d.classTime,
          targetArrivalTime: d.targetArrivalTime,
          startPlaceName: '집',
          startAddress: d.startAddress,
          destinationName: d.destinationName,
          destinationAddress: d.destinationAddress,
          transportMode: d.transportMode,
          isActive: true,
        )).toList();

    await svc.completeOnboarding(
      prepMinutes: _prepMinutes,
      defaultTravelMinutes: _defaultTravelMinutes,
      homeWifiSsids: [],
      schoolWifiSsids: [],
      newSchedules: newSchedules,
    );
    // SettingsService.notifyListeners() → _UserRouter가 MainShell로 전환
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPrepPage(),
                  _buildSchedulePage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(2, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == 0 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: i <= _currentPage ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 1페이지: 준비시간 설정 ──────────────────────────────────────────────────
  Widget _buildPrepPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('나가자에 오신걸 환영합니다!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('준비 시간을 설정해 주세요.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          const SizedBox(height: 40),
          _sliderCard(
            label: '개인 준비시간',
            desc: '세면, 옷 입기 등 집을 나서기까지 걸리는 시간',
            value: _prepMinutes,
            min: 10,
            max: 90,
            onChanged: (v) => setState(() => _prepMinutes = v),
          ),
          const SizedBox(height: 16),
          _sliderCard(
            label: '기본 이동시간',
            desc: '지도 API 연동 전 기본값으로 사용됩니다',
            value: _defaultTravelMinutes,
            min: 5,
            max: 60,
            onChanged: (v) => setState(() => _defaultTravelMinutes = v),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: _primaryStyle(),
              child: const Text('다음'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderCard({
    required String label,
    required String desc,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('$value분',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min) ~/ 5,
            label: '$value분',
            onChanged: (v) => onChanged(v.round()),
          ),
          Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ── 2페이지: 수업 추가 ──────────────────────────────────────────────────────
  Widget _buildSchedulePage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('시간표를 추가해 주세요',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('수업별로 출발지·목적지·교통수단을 따로 설정합니다.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              ..._drafts.asMap().entries.map((e) => _draftTile(e.key, e.value)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addSchedule,
                icon: const Icon(Icons.add),
                label: const Text('수업 추가'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _prevPage,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('이전'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _finish,
                            style: _primaryStyle(),
                            child: const Text('완료'),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _draftTile(int index, _ScheduleDraft draft) {
    const dayNames = ['', '월', '화', '수', '목', '금', '토', '일'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(dayNames[draft.dayOfWeek],
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(draft.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${draft.classTime} · ${draft.destinationName} · ${draft.transportMode}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => setState(() => _drafts.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Future<void> _addSchedule() async {
    final draft = await showModalBottomSheet<_ScheduleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ScheduleAddSheet(),
    );
    if (draft != null) setState(() => _drafts.add(draft));
  }

  ButtonStyle _primaryStyle() => ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      );
}

// ── 수업 추가 바텀 시트 ─────────────────────────────────────────────────────────
class _ScheduleAddSheet extends StatefulWidget {
  const _ScheduleAddSheet();

  @override
  State<_ScheduleAddSheet> createState() => _ScheduleAddSheetState();
}

class _ScheduleAddSheetState extends State<_ScheduleAddSheet> {
  final _titleCtrl = TextEditingController();
  final _startAddressCtrl = TextEditingController(text: '');
  final _destNameCtrl = TextEditingController();
  final _destAddressCtrl = TextEditingController();

  int _dayOfWeek = 1;
  TimeOfDay _classTime = const TimeOfDay(hour: 9, minute: 0);
  String _transportMode = 'BUS';

  static const _days = ['월', '화', '수', '목', '금'];
  static const _modes = ['BUS', 'SUBWAY', 'WALK'];
  static const _modeLabels = ['버스', '지하철', '도보'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _startAddressCtrl.dispose();
    _destNameCtrl.dispose();
    _destAddressCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _destNameCtrl.text.trim().isNotEmpty &&
      _destAddressCtrl.text.trim().isNotEmpty;

  String get _classTimeStr =>
      '${_classTime.hour.toString().padLeft(2, '0')}:${_classTime.minute.toString().padLeft(2, '0')}';

  // targetArrivalTime = classTime - 5분
  String get _targetArrivalStr {
    final total = _classTime.hour * 60 + _classTime.minute - 5;
    final h = (total ~/ 60).clamp(0, 23);
    final m = (total % 60).clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('수업 추가',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _field('과목명', _titleCtrl, hint: '예) 자료구조'),
                  const SizedBox(height: 16),
                  // 요일
                  const Text('요일',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final d = i + 1;
                      final sel = _dayOfWeek == d;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _dayOfWeek = d),
                          child: Container(
                            margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? Colors.blue
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(_days[i],
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  // 수업 시간
                  const Text('수업 시작 시간',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _classTime,
                      );
                      if (picked != null) setState(() => _classTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(_classTimeStr,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 교통수단
                  const Text('교통수단',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(3, (i) {
                      final sel = _transportMode == _modes[i];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _transportMode = _modes[i]),
                          child: Container(
                            margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? Colors.blue
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(_modeLabels[i],
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  _field('출발지 주소', _startAddressCtrl,
                      hint: '예) 부산광역시 사상구 학장로 123'),
                  const SizedBox(height: 16),
                  _field('강의실 건물명', _destNameCtrl, hint: '예) 공학관'),
                  const SizedBox(height: 16),
                  _field('강의실 주소', _destAddressCtrl,
                      hint: '예) 부산광역시 부산진구 시민공원로 73'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _valid
                        ? () {
                            Navigator.pop(
                              context,
                              _ScheduleDraft(
                                title: _titleCtrl.text.trim(),
                                dayOfWeek: _dayOfWeek,
                                classTime: _classTimeStr,
                                targetArrivalTime: _targetArrivalStr,
                                startAddress: _startAddressCtrl.text.trim(),
                                destinationName: _destNameCtrl.text.trim(),
                                destinationAddress:
                                    _destAddressCtrl.text.trim(),
                                transportMode: _transportMode,
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('추가'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ScheduleDraft {
  final String title;
  final int dayOfWeek;
  final String classTime;
  final String targetArrivalTime;
  final String startAddress;
  final String destinationName;
  final String destinationAddress;
  final String transportMode;

  const _ScheduleDraft({
    required this.title,
    required this.dayOfWeek,
    required this.classTime,
    required this.targetArrivalTime,
    required this.startAddress,
    required this.destinationName,
    required this.destinationAddress,
    required this.transportMode,
  });
}
