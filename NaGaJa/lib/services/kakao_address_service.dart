import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/kakao_config.dart';

class KakaoPlace {
  final String placeName;
  final String roadAddress;
  final String address;
  final double lat;
  final double lng;

  const KakaoPlace({
    required this.placeName,
    required this.roadAddress,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class KakaoAddressService {
  KakaoAddressService._();
  static final instance = KakaoAddressService._();

  Future<List<KakaoPlace>> search(String query) async {
    if (query.trim().isEmpty || kakaoRestApiKey.isEmpty) return [];
    try {
      final uri = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
        'query': query.trim(),
        'size': '5',
      });
      final res = await http
          .get(uri, headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'})
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final docs = (body['documents'] as List?) ?? [];
      return docs.map<KakaoPlace>((d) {
        return KakaoPlace(
          placeName: d['place_name'] as String? ?? '',
          roadAddress: d['road_address_name'] as String? ?? '',
          address: d['address_name'] as String? ?? '',
          lat: double.tryParse(d['y'] as String? ?? '') ?? 0.0,
          lng: double.tryParse(d['x'] as String? ?? '') ?? 0.0,
        );
      }).where((p) => p.placeName.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
}
