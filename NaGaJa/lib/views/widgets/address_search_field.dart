import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/kakao_address_service.dart';

/// Kakao 장소/도로명주소 검색 입력 필드.
///
/// 설정의 수업 편집과 온보딩(기초정보 입력)에서 공유한다.
/// 검색 결과(`KakaoPlace`)는 장소명·도로명주소·좌표(lat/lng)를 포함하므로,
/// 선택 즉시 좌표가 확보되어 백엔드 재지오코딩(geocoding 500)을 피할 수 있다.
class AddressSearchField extends StatefulWidget {
  final String label;
  final String hint;
  final KakaoPlace? initialPlace;
  final ValueChanged<KakaoPlace?> onSelected;

  const AddressSearchField({
    super.key,
    required this.label,
    required this.hint,
    this.initialPlace,
    required this.onSelected,
  });

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  late final TextEditingController _ctrl;
  List<KakaoPlace> _results = [];
  KakaoPlace? _selected;
  Timer? _debounce;
  bool _loading = false;
  bool _noResults = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPlace;
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    setState(() => _noResults = false);
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final r = await KakaoAddressService.instance.search(q.trim());
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
        _noResults = r.isEmpty;
      });
    });
  }

  void _select(KakaoPlace p) {
    setState(() {
      _selected = p;
      _results = [];
      _noResults = false;
      _ctrl.clear();
    });
    widget.onSelected(p);
  }

  // API 키 없거나 결과 없을 때 입력한 텍스트를 그대로 저장
  void _confirmManual() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final p = KakaoPlace(
      placeName: text,
      roadAddress: text,
      address: text,
      lat: 0.0,
      lng: 0.0,
    );
    _select(p);
  }

  void _clear() {
    setState(() {
      _selected = null;
      _results = [];
      _noResults = false;
      _ctrl.clear();
    });
    widget.onSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_selected != null)
          _buildSelectedTile()
        else ...[
          TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search, size: 20),
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
          if (_results.isNotEmpty) _buildResultList(),
          if (_noResults) _buildNoResultRow(),
        ],
      ],
    );
  }

  Widget _buildSelectedTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selected!.placeName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_selected!.roadAddress.isNotEmpty)
                  Text(
                    _selected!.roadAddress,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _clear,
            child: Icon(Icons.close, size: 18, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _results.asMap().entries.map((e) {
          final p = e.value;
          final isLast = e.key == _results.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: () => _select(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.placeName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (p.roadAddress.isNotEmpty)
                              Text(
                                p.roadAddress,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 38),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoResultRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(
            '검색 결과 없음',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _confirmManual,
            child: Text(
              '직접 입력으로 저장',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
