import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/models/route_preview.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_state.freezed.dart';

@freezed
class RouteState with _$RouteState {
  const factory RouteState({
    Location? origin,
    Location? destination,
    RoutePreview? preview,
    @Default(false) bool isLoading,
    String? error,
  }) = _RouteState;
}
