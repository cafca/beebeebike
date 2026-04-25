import 'package:ferrostar_flutter/src/models/trip_progress.dart';
import 'package:ferrostar_flutter/src/models/user_location.dart';
import 'package:ferrostar_flutter/src/models/visual_instruction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'navigation_state.freezed.dart';
part 'navigation_state.g.dart';

/// High-level lifecycle of a navigation session.
enum TripStatus {
  /// No active trip — controller created but no location updates yet.
  @JsonValue('idle')
  idle,

  /// Trip in progress; the user is moving toward the destination.
  @JsonValue('navigating')
  navigating,

  /// Final waypoint reached; the trip has finished.
  @JsonValue('complete')
  complete,
}

/// Lightweight reference to the route step the user is currently on.
@freezed
class StepRef with _$StepRef {
  /// Creates a [StepRef].
  const factory StepRef({
    /// Human-readable name of the road for the current step.
    @JsonKey(name: 'road_name') required String roadName,

    /// Zero-based index of the step within the active route, when known.
    int? index,
  }) = _StepRef;

  /// Decodes a step reference from its JSON representation.
  factory StepRef.fromJson(Map<String, dynamic> json) =>
      _$StepRefFromJson(json);
}

/// Snapshot of the navigation core's current state. Emitted on
/// `FerrostarController.stateStream` after each location update.
@freezed
class NavigationState with _$NavigationState {
  /// Creates a [NavigationState].
  const factory NavigationState({
    /// Current trip lifecycle status.
    required TripStatus status,

    /// True while the user is past the deviation thresholds set in
    /// `NavigationConfig`.
    @JsonKey(name: 'is_off_route') required bool isOffRoute,

    /// User location snapped to the route polyline (null if snapping is
    /// disabled or no fix has been pushed yet).
    @JsonKey(name: 'snapped_location') UserLocation? snappedLocation,

    /// Distance/time progress for the trip, when available.
    TripProgress? progress,

    /// Visual instruction for the upcoming maneuver, if any.
    @JsonKey(name: 'current_visual') VisualInstruction? currentVisual,

    /// Reference to the step the user is currently on, if any.
    @JsonKey(name: 'current_step') StepRef? currentStep,
  }) = _NavigationState;

  /// Decodes a navigation state from its JSON representation.
  factory NavigationState.fromJson(Map<String, dynamic> json) =>
      _$NavigationStateFromJson(json);
}
