import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_preview.freezed.dart';
part 'route_preview.g.dart';

@freezed
class RoutePreview with _$RoutePreview {
  const factory RoutePreview({
    required Map<String, dynamic> geometry,
    required double distance,
    required double time,
  }) = _RoutePreview;

  factory RoutePreview.fromJson(Map<String, dynamic> json) =>
      _$RoutePreviewFromJson(json);
}
