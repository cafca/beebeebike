import 'package:dio/dio.dart';

import '../models/geocode_result.dart';

class GeocodeApi {
  GeocodeApi(this._dio);

  final Dio _dio;

  Future<List<GeocodeResult>> search(String query) async {
    final response = await _dio.get('/api/geocode', queryParameters: {'q': query});
    final features = (response.data['features'] as List).cast<Map<String, dynamic>>();
    return features.map((f) {
      final props = f['properties'] as Map<String, dynamic>;
      final coords = (f['geometry']?['coordinates'] as List?) ?? [0.0, 0.0];
      final rawName = (props['name'] as String?) ?? '';
      final street = (props['street'] as String?) ?? '';
      final housenumber = (props['housenumber'] as String?) ?? '';
      final String name;
      if (rawName.isNotEmpty) {
        name = rawName;
      } else if (street.isNotEmpty) {
        name = housenumber.isNotEmpty ? '$street $housenumber' : street;
      } else {
        name = '';
      }
      final parts = <String>[
        if (props['district'] != null) props['district'] as String
        else if (props['city'] != null) props['city'] as String,
        if (props['osm_value'] != null &&
            props['osm_value'] != 'yes' &&
            props['osm_value'] != 'primary' &&
            props['osm_value'] != 'residential')
          (props['osm_value'] as String).replaceAll('_', ' '),
      ];
      return GeocodeResult(
        id: '${props['osm_type'] ?? 'U'}:${props['osm_id'] ?? '0'}',
        name: name,
        label: parts.isEmpty ? name : parts.join(' · '),
        lng: (coords[0] as num).toDouble(),
        lat: (coords[1] as num).toDouble(),
        street: street.isEmpty ? null : street,
        housenumber: housenumber.isEmpty ? null : housenumber,
      );
    }).toList();
  }
}
