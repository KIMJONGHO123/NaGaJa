import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/daily_plan_service.dart';
import '../../services/kakao_address_service.dart';
import '../../services/settings_service.dart';
import '../widgets/address_search_field.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _prepMinutes = 30;
  int _defaultTravelMinutes = 20;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    SettingsService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    await SettingsService.instance.load();
    final svc = SettingsService.instance;
    setState(() {
      _prepMinutes = svc.prepMinutes;
      _defaultTravelMinutes = svc.defaultTravelMinutes;
      _loading = false;
    });
  }

  Future<void> _saveUserSettings() async {
    await SettingsService.instance.saveUserSettings(
      prepMinutes: _prepMinutes,
      defaultTravelMinutes: _defaultTravelMinutes,
    );
    DailyPlanService.instance.generateDailyPlan();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정이 저장되었습니다')));
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
          TextButton(onPressed: _saveUserSettings, child: const Text('저장')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header('시간표'),
          _buildScheduleList(),
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

  Widget _header(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
      ],
    ),
    child: child,
  );

  // ── 시간표 목록 ──────────────────────────────────────────────────────────────
  Widget _buildScheduleList() {
    final schedules = SettingsService.instance.schedules;
    final sorted = List<ScheduleEntry>.from(schedules)
      ..sort(
        (a, b) => a.dayOfWeek != b.dayOfWeek
            ? a.dayOfWeek.compareTo(b.dayOfWeek)
            : a.classTime.compareTo(b.classTime),
      );

    return _card(
      child: Column(
        children: [
          ...sorted.asMap().entries.map((e) {
            final s = e.value;
            final isLast = e.key == sorted.length - 1;
            return Column(
              children: [
                _scheduleTile(s),
                if (!isLast) const Divider(height: 1, indent: 16),
              ],
            );
          }),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('등록된 수업이 없습니다', style: TextStyle(color: Colors.grey)),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
            title: const Text(
              '수업 추가',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
            ),
            onTap: () => _openScheduleSheet(null),
          ),
        ],
      ),
    );
  }

  Widget _scheduleTile(ScheduleEntry s) {
    const dayNames = ['', '월', '화', '수', '목', '금', '토', '일'];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        child: Text(
          dayNames[s.dayOfWeek],
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${s.classTime} · ${s.destinationName} · ${s.transportMode}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: s.isActive, onChanged: (v) => _toggleActive(s, v)),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.grey),
            onPressed: () => _openScheduleSheet(s),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(ScheduleEntry s, bool active) async {
    final updated = ScheduleEntry(
      scheduleId: s.scheduleId,
      userId: s.userId,
      title: s.title,
      dayOfWeek: s.dayOfWeek,
      classTime: s.classTime,
      targetArrivalTime: s.targetArrivalTime,
      startPlaceName: s.startPlaceName,
      startAddress: s.startAddress,
      startLat: s.startLat,
      startLng: s.startLng,
      destinationName: s.destinationName,
      destinationAddress: s.destinationAddress,
      endLat: s.endLat,
      endLng: s.endLng,
      transportMode: s.transportMode,
      isActive: active,
    );
    await SettingsService.instance.saveSchedule(updated);
    DailyPlanService.instance.generateDailyPlan();
  }

  Future<void> _openScheduleSheet(ScheduleEntry? existing) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleEditSheet(existing: existing),
    );
    setState(() {});
  }

  // ── 준비시간 카드 ─────────────────────────────────────────────────────────────
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
                const Text('개인 준비시간', style: TextStyle(fontSize: 15)),
                Text(
                  '$_prepMinutes분',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
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
            Text(
              '세면, 옷 입기 등 집을 나서기까지 걸리는 시간',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('기본 이동시간', style: TextStyle(fontSize: 15)),
                Text(
                  '$_defaultTravelMinutes분',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Slider(
              value: _defaultTravelMinutes.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              label: '$_defaultTravelMinutes분',
              onChanged: (v) =>
                  setState(() => _defaultTravelMinutes = v.round()),
            ),
            Text(
              '지도 API 연동 전 기본값으로 사용됩니다',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
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
        subtitle: const Text('연결되지 않음', style: TextStyle(color: Colors.grey)),
        trailing: ElevatedButton(
          onPressed: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('BLE 스캔 중...'))),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('연결'),
        ),
      ),
    );
  }
}

// ── 수업 편집 바텀 시트 ─────────────────────────────────────────────────────────
class _ScheduleEditSheet extends StatefulWidget {
  final ScheduleEntry? existing;
  const _ScheduleEditSheet({this.existing});

  @override
  State<_ScheduleEditSheet> createState() => _ScheduleEditSheetState();
}

class _ScheduleEditSheetState extends State<_ScheduleEditSheet> {
  late final TextEditingController _titleCtrl;

  late int _dayOfWeek;
  late TimeOfDay _classTime;
  late String _transportMode;

  KakaoPlace? _startPlace;
  KakaoPlace? _destPlace;

  static const _days = ['월', '화', '수', '목', '금'];
  static const _modes = ['BUS', 'SUBWAY', 'WALK'];
  static const _modeLabels = ['버스', '지하철', '도보'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _dayOfWeek = e?.dayOfWeek ?? 1;
    _classTime = e?.classTimeOfDay ?? const TimeOfDay(hour: 9, minute: 0);
    _transportMode = e?.transportMode ?? 'BUS';

    // 기존 데이터 pre-fill (주소만 있고 좌표 없는 구버전도 허용)
    if (e != null && e.startAddress.isNotEmpty) {
      _startPlace = KakaoPlace(
        placeName: e.startPlaceName,
        roadAddress: e.startAddress,
        address: e.startAddress,
        lat: e.startLat ?? 0.0,
        lng: e.startLng ?? 0.0,
      );
    }
    if (e != null && e.destinationAddress.isNotEmpty) {
      _destPlace = KakaoPlace(
        placeName: e.destinationName,
        roadAddress: e.destinationAddress,
        address: e.destinationAddress,
        lat: e.endLat ?? 0.0,
        lng: e.endLng ?? 0.0,
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _startPlace != null &&
      _destPlace != null;

  String get _classTimeStr =>
      '${_classTime.hour.toString().padLeft(2, '0')}:${_classTime.minute.toString().padLeft(2, '0')}';

  String get _targetArrivalStr {
    final totalMin = _classTime.hour * 60 + _classTime.minute - 5;
    // 자정 이전(음수)으로 넘어가는 경우 처리
    final adjusted = totalMin < 0 ? totalMin + 24 * 60 : totalMin;
    final h = (adjusted ~/ 60) % 24;
    final m = adjusted % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final svc = SettingsService.instance;
    final start = _startPlace!;
    final dest = _destPlace!;
    final startAddr = start.roadAddress.isNotEmpty
        ? start.roadAddress
        : start.address;
    final destAddr = dest.roadAddress.isNotEmpty
        ? dest.roadAddress
        : dest.address;
    final entry = ScheduleEntry(
      scheduleId: widget.existing?.scheduleId ?? '',
      userId: svc.userModel?.userId ?? '',
      title: _titleCtrl.text.trim(),
      dayOfWeek: _dayOfWeek,
      classTime: _classTimeStr,
      targetArrivalTime: _targetArrivalStr,
      startPlaceName: start.placeName,
      startAddress: startAddr,
      startLat: start.lat != 0.0 ? start.lat : null,
      startLng: start.lng != 0.0 ? start.lng : null,
      destinationName: dest.placeName,
      destinationAddress: destAddr,
      endLat: dest.lat != 0.0 ? dest.lat : null,
      endLng: dest.lng != 0.0 ? dest.lng : null,
      transportMode: _transportMode,
      isActive: widget.existing?.isActive ?? true,
    );
    final ok = await svc.saveSchedule(entry);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
      return;
    }
    DailyPlanService.instance.generateDailyPlan(
      scheduleId: entry.scheduleId.isNotEmpty ? entry.scheduleId : null,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final id = widget.existing?.scheduleId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('수업 삭제'),
        content: Text('"${widget.existing!.title}" 수업을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SettingsService.instance.deleteSchedule(id);
      if (mounted) Navigator.pop(context);
    }
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 16),
                Text(
                  widget.existing == null ? '수업 추가' : '수업 편집',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.existing != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _delete,
                  ),
                const SizedBox(width: 8),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  _field('과목명', _titleCtrl, hint: '예) 자료구조'),
                  const SizedBox(height: 16),
                  const Text(
                    '요일',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
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
                              color: sel ? Colors.blue : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _days[i],
                                style: TextStyle(
                                  color: sel ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '수업 시작 시간',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final p = await showTimePicker(
                        context: context,
                        initialTime: _classTime,
                      );
                      if (p != null) setState(() => _classTime = p);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _classTimeStr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '교통수단',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
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
                              color: sel ? Colors.blue : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _modeLabels[i],
                                style: TextStyle(
                                  color: sel ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  AddressSearchField(
                    label: '출발지',
                    hint: '장소명 또는 주소 검색 (예: 집, 서면역)',
                    initialPlace: _startPlace,
                    onSelected: (p) => setState(() => _startPlace = p),
                  ),
                  const SizedBox(height: 16),
                  AddressSearchField(
                    label: '목적지 (강의실)',
                    hint: '장소명 또는 주소 검색 (예: 공학관)',
                    initialPlace: _destPlace,
                    onSelected: (p) => setState(() => _destPlace = p),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _valid ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(widget.existing == null ? '추가' : '저장'),
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

  Widget _field(String label, TextEditingController ctrl, {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
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
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
