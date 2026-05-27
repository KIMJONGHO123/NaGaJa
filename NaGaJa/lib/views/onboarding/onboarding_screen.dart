import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/settings_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 주소
  final _homeController = TextEditingController();
  final _schoolController = TextEditingController();

  // 교통수단 + 준비시간
  String _transport = 'bus';
  int _prepMinutes = 30;

  // 시간표
  final Map<int, TimeOfDay?> _times = {1: null, 2: null, 3: null, 4: null, 5: null};
  final Map<int, TextEditingController> _courseControllers = {
    for (int i = 1; i <= 5; i++) i: TextEditingController(),
  };

  bool _saving = false;

  static const _days = ['월요일', '화요일', '수요일', '목요일', '금요일'];

  @override
  void dispose() {
    _pageController.dispose();
    _homeController.dispose();
    _schoolController.dispose();
    for (final c in _courseControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _addressValid =>
      _homeController.text.trim().isNotEmpty &&
      _schoolController.text.trim().isNotEmpty;

  Future<void> _finish() async {
    setState(() => _saving = true);

    final scheduleMap = <int, ScheduleEntry>{};
    for (int day = 1; day <= 5; day++) {
      scheduleMap[day] = ScheduleEntry(
        day: day,
        startTime: _times[day],
        courseName: _courseControllers[day]!.text.trim(),
      );
    }

    await SettingsService.instance.completeOnboarding(
      homeAddress: _homeController.text.trim(),
      schoolAddress: _schoolController.text.trim(),
      transport: _transport,
      prepMinutes: _prepMinutes,
      scheduleMap: scheduleMap,
    );

    // completeOnboarding이 notifyListeners()를 호출하므로
    // main.dart의 _UserRouter가 리빌드되어 자동으로 MainShell로 전환됨
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildAddressPage(),
                  _buildTransportPage(),
                  _buildSchedulePage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (i) {
          final active = i <= _currentPage;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 1페이지: 주소 입력 ──────────────────────────────────────────────────────
  Widget _buildAddressPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('어디서 출발하시나요?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('집과 학교 주소를 입력해 주세요.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          const SizedBox(height: 32),
          _addressField(
            label: '집 주소',
            hint: '예) 부산시 사상구 학장로 123',
            icon: Icons.home_outlined,
            controller: _homeController,
          ),
          const SizedBox(height: 20),
          _addressField(
            label: '학교 주소',
            hint: '예) 동의대학교',
            icon: Icons.school_outlined,
            controller: _schoolController,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addressValid ? _nextPage : null,
              style: _primaryButtonStyle(),
              child: const Text('다음'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── 2페이지: 교통수단 + 준비시간 ────────────────────────────────────────────
  Widget _buildTransportPage() {
    final transportOptions = [
      ('bus', Icons.directions_bus_outlined, '버스', '배차 대기시간 포함'),
      ('subway', Icons.train_outlined, '지하철', '정시성이 높음'),
      ('walk', Icons.directions_walk_outlined, '도보', '날씨 영향 반영'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('이동 방법을 알려주세요',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('주로 사용하는 교통수단과 준비 시간을 설정해 주세요.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          const SizedBox(height: 32),
          const Text('주 교통수단',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...transportOptions.map((opt) {
            final (value, icon, label, desc) = opt;
            final selected = _transport == value;
            return GestureDetector(
              onTap: () => setState(() => _transport = value),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected ? Colors.blue.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.blue : Colors.grey[200]!,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        color: selected ? Colors.blue : Colors.grey[500]),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.blue : Colors.black87)),
                        Text(desc,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: Colors.blue, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('개인 준비시간',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('$_prepMinutes분',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15,
                      color: Colors.blue)),
            ],
          ),
          Slider(
            value: _prepMinutes.toDouble(),
            min: 10,
            max: 90,
            divisions: 16,
            label: '$_prepMinutes분',
            onChanged: (v) => setState(() => _prepMinutes = v.round()),
          ),
          Text('세면, 옷 입기 등 집을 나서기까지 걸리는 시간',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('이전'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: _primaryButtonStyle(),
                  child: const Text('다음'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3페이지: 시간표 입력 ────────────────────────────────────────────────────
  Widget _buildSchedulePage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('시간표를 입력해 주세요',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('수업이 없는 요일은 비워두세요. 나중에 설정에서 변경할 수 있어요.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildScheduleCard(),
              const SizedBox(height: 24),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                            style: _primaryButtonStyle(),
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

  Widget _buildScheduleCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: List.generate(5, (i) {
          final day = i + 1;
          final time = _times[day];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        _days[i].substring(0, 1), // 월, 화, 수...
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _courseControllers[day],
                        decoration: InputDecoration(
                          hintText: '과목명 (선택)',
                          hintStyle: TextStyle(
                              color: Colors.grey[400], fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              time ?? const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (picked != null) {
                          setState(() => _times[day] = picked);
                        }
                      },
                      onLongPress: () => setState(() => _times[day] = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
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
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 4) Divider(height: 1, color: Colors.grey[100]),
            ],
          );
        }),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() => ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      );
}
