import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_location.dart';
import 'trip_progress.dart';
import 'visual_instruction.dart';

part 'navigation_state.freezed.dart';
part 'navigation_state.g.dart';

enum TripStatus {
  @JsonValue('idle') idle,
  @JsonValue('navigating') navigating,
  @JsonValue('complete') complete,
}

@freezed
class StepRef with _$StepRef {
  const factory StepRef({
    int? index,
    @JsonKey(name: 'road_name') required String roadName,
  }) = _StepRef;

  factory StepRef.fromJson(Map<String, dynamic> json) =>
      _$StepRefFromJson(json);
}

@freezed
class NavigationState with _$NavigationState {
  const factory NavigationState({
    required TripStatus status,
    @JsonKey(name: 'is_off_route') required bool isOffRoute,
    @JsonKey(name: 'snapped_location') UserLocation? snappedLocation,
    TripProgress? progress,
    @JsonKey(name: 'current_visual') VisualInstruction? currentVisual,
    @JsonKey(name: 'current_step') StepRef? currentStep,
  }) = _NavigationState;

  factory NavigationState.fromJson(Map<String, dynamic> json) =>
      _$NavigationStateFromJson(json);
}
