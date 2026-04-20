import 'package:freezed_annotation/freezed_annotation.dart';

import 'location.dart';
import 'route_preview.dart';

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
