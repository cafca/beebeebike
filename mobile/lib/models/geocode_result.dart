import 'package:freezed_annotation/freezed_annotation.dart';

part 'geocode_result.freezed.dart';
part 'geocode_result.g.dart';

@freezed
class GeocodeResult with _$GeocodeResult {
  const factory GeocodeResult({
    required String id,
    required String name,
    required String label,
    required double lng,
    required double lat,
  }) = _GeocodeResult;

  factory GeocodeResult.fromJson(Map<String, dynamic> json) =>
      _$GeocodeResultFromJson(json);
}
