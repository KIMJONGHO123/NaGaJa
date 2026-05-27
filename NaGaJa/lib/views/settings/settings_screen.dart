import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/settings_service.dart';

enum TransportMode { bus, subway, walk }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _homeController = TextEditingController();
  final _schoolController = TextEditingController();
  final Map<int, TextEditingController> _courseControllers = {
    for (int i = 1; i <= 5; i++) i: TextEditingController(),
  };

  TransportMode _transport = TransportMode.bus;
  int _prepMinutes = 30;
  final Map<int, TimeOfDay?> _times = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await SettingsService.instance.load();
    final svc = SettingsService.instance;
    setState(() {
      for (int day = 1; day <= 5; day++) {
        _times[day] = svc.scheduleTime(day);
        _courseControllers[day]!.text = svc.courseName(day);
      }
      _prepMinutes = svc.prepMinutes;
      _transport = switch (svc.transport) {
        'subway' => TransportMode.subway,
        'walk'   => TransportMode.walk,
        _        => TransportMode.bus,
      };
      _homeController.text = svc.homeAddress;
      _schoolController.text = svc.schoolAddress;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _homeController.dispose();
    _schoolController.dispose();
    for (final c in _courseControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final scheduleMap = <int, ScheduleEntry>{};
    for (int day = 1; day <= 5; day++) {
      scheduleMap[day] = ScheduleEntry(
        day: day,
        startTime: _times[day],
        courseName: _courseControllers[day]!.text.trim(),
      );
    }
    await SettingsService.instance.save(
      homeAddress: _homeController.text,
      schoolAddress: _schoolController.text,
      transport: switch (_transport) {
        TransportMode.bus    => 'bus',
        TransportMode.subway => 'subway',
        TransportMode.walk   => 'walk',
      },
      prepMinutes: _prepMinutes,
      scheduleMap: scheduleMap,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
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
          _buildScheduleCard(),
          const SizedBox(height: 16),
          _header('위치'),
          _buildLocationCard(),
          const SizedBox(height: 16),
          _header('교통수단'),
          _buildTransportCard(),
          const SizedBox(height: 16),
          _header('개인 설정'),
          _buildPrepTimeCard(),
          const SizedBox(height: 16),
          _header('기기 연결'),
          _buildDeviceCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600]),
      ),
    );
  }

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

  Widget _buildScheduleCard() {
    const days = ['월', '화', '수', '목', '금'];
    return _card(
      child: Column(
        children: List.generate(5, (i) {
          final day = i + 1;
          final time = _times[day];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(days[i],
                          style: const TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _courseControllers[day],
                        decoration: InputDecoration(
                          hintText: '과목명',
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
                      onLongPress: () =>
                          setState(() => _times[day] = null),
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
                            color:
                                time != null ? Colors.blue : Colors.grey,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 4) const Divider(height: 1, indent: 16),
            ],
          );
        }),
      ),
    );
  }

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
            Text(desc,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

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
                Text('$_prepMinutes분',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            Slider(
              value: _prepMinutes.toDouble(),
              min: 10,
              max: 90,
              divisions: 16,
              label: '$_prepMinutes분',
              onChanged: (v) =>
                  setState(() => _prepMinutes = v.round()),
            ),
            Text('세면, 옷 입기 등 집을 나서기까지 걸리는 시간',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    return _card(
      child: ListTile(
        leading: const Icon(Icons.bluetooth, color: Colors.blue),
        title: const Text('물리 알람시계'),
        subtitle: const Text('연결되지 않음',
            style: TextStyle(color: Colors.grey)),
        trailing: ElevatedButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
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
