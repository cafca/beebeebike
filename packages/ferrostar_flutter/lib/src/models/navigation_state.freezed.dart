// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'navigation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

StepRef _$StepRefFromJson(Map<String, dynamic> json) {
  return _StepRef.fromJson(json);
}

/// @nodoc
mixin _$StepRef {
  int? get index => throw _privateConstructorUsedError;
  @JsonKey(name: 'road_name')
  String get roadName => throw _privateConstructorUsedError;

  /// Serializes this StepRef to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StepRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StepRefCopyWith<StepRef> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StepRefCopyWith<$Res> {
  factory $StepRefCopyWith(StepRef value, $Res Function(StepRef) then) =
      _$StepRefCopyWithImpl<$Res, StepRef>;
  @useResult
  $Res call({int? index, @JsonKey(name: 'road_name') String roadName});
}

/// @nodoc
class _$StepRefCopyWithImpl<$Res, $Val extends StepRef>
    implements $StepRefCopyWith<$Res> {
  _$StepRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StepRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? index = null, Object? roadName = null}) {
    return _then(
      _value.copyWith(
            index: null == index ? _value.index : index as int?,
            roadName: null == roadName
                ? _value.roadName
                : roadName // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StepRefImplCopyWith<$Res> implements $StepRefCopyWith<$Res> {
  factory _$$StepRefImplCopyWith(
    _$StepRefImpl value,
    $Res Function(_$StepRefImpl) then,
  ) = __$$StepRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int? index, @JsonKey(name: 'road_name') String roadName});
}

/// @nodoc
class __$$StepRefImplCopyWithImpl<$Res>
    extends _$StepRefCopyWithImpl<$Res, _$StepRefImpl>
    implements _$$StepRefImplCopyWith<$Res> {
  __$$StepRefImplCopyWithImpl(
    _$StepRefImpl _value,
    $Res Function(_$StepRefImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StepRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? index = null, Object? roadName = null}) {
    return _then(
      _$StepRefImpl(
        index: null == index ? _value.index : index as int?,
        roadName: null == roadName
            ? _value.roadName
            : roadName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StepRefImpl implements _StepRef {
  const _$StepRefImpl({
    this.index,
    @JsonKey(name: 'road_name') required this.roadName,
  });

  factory _$StepRefImpl.fromJson(Map<String, dynamic> json) =>
      _$$StepRefImplFromJson(json);

  @override
  final int? index;
  @override
  @JsonKey(name: 'road_name')
  final String roadName;

  @override
  String toString() {
    return 'StepRef(index: $index, roadName: $roadName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StepRefImpl &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.roadName, roadName) ||
                other.roadName == roadName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, index, roadName);

  /// Create a copy of StepRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StepRefImplCopyWith<_$StepRefImpl> get copyWith =>
      __$$StepRefImplCopyWithImpl<_$StepRefImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StepRefImplToJson(this);
  }
}

abstract class _StepRef implements StepRef {
  const factory _StepRef({
    final int? index,
    @JsonKey(name: 'road_name') required final String roadName,
  }) = _$StepRefImpl;

  factory _StepRef.fromJson(Map<String, dynamic> json) = _$StepRefImpl.fromJson;

  @override
  int? get index;
  @override
  @JsonKey(name: 'road_name')
  String get roadName;

  /// Create a copy of StepRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StepRefImplCopyWith<_$StepRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NavigationState _$NavigationStateFromJson(Map<String, dynamic> json) {
  return _NavigationState.fromJson(json);
}

/// @nodoc
mixin _$NavigationState {
  TripStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_off_route')
  bool get isOffRoute => throw _privateConstructorUsedError;
  @JsonKey(name: 'snapped_location')
  UserLocation? get snappedLocation => throw _privateConstructorUsedError;
  TripProgress? get progress => throw _privateConstructorUsedError;
  @JsonKey(name: 'current_visual')
  VisualInstruction? get currentVisual => throw _privateConstructorUsedError;
  @JsonKey(name: 'current_step')
  StepRef? get currentStep => throw _privateConstructorUsedError;

  /// Serializes this NavigationState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NavigationStateCopyWith<NavigationState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NavigationStateCopyWith<$Res> {
  factory $NavigationStateCopyWith(
    NavigationState value,
    $Res Function(NavigationState) then,
  ) = _$NavigationStateCopyWithImpl<$Res, NavigationState>;
  @useResult
  $Res call({
    TripStatus status,
    @JsonKey(name: 'is_off_route') bool isOffRoute,
    @JsonKey(name: 'snapped_location') UserLocation? snappedLocation,
    TripProgress? progress,
    @JsonKey(name: 'current_visual') VisualInstruction? currentVisual,
    @JsonKey(name: 'current_step') StepRef? currentStep,
  });

  $UserLocationCopyWith<$Res>? get snappedLocation;
  $TripProgressCopyWith<$Res>? get progress;
  $VisualInstructionCopyWith<$Res>? get currentVisual;
  $StepRefCopyWith<$Res>? get currentStep;
}

/// @nodoc
class _$NavigationStateCopyWithImpl<$Res, $Val extends NavigationState>
    implements $NavigationStateCopyWith<$Res> {
  _$NavigationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? isOffRoute = null,
    Object? snappedLocation = freezed,
    Object? progress = freezed,
    Object? currentVisual = freezed,
    Object? currentStep = freezed,
  }) {
    return _then(
      _value.copyWith(
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TripStatus,
            isOffRoute: null == isOffRoute
                ? _value.isOffRoute
                : isOffRoute // ignore: cast_nullable_to_non_nullable
                      as bool,
            snappedLocation: freezed == snappedLocation
                ? _value.snappedLocation
                : snappedLocation // ignore: cast_nullable_to_non_nullable
                      as UserLocation?,
            progress: freezed == progress
                ? _value.progress
                : progress // ignore: cast_nullable_to_non_nullable
                      as TripProgress?,
            currentVisual: freezed == currentVisual
                ? _value.currentVisual
                : currentVisual // ignore: cast_nullable_to_non_nullable
                      as VisualInstruction?,
            currentStep: freezed == currentStep
                ? _value.currentStep
                : currentStep // ignore: cast_nullable_to_non_nullable
                      as StepRef?,
          )
          as $Val,
    );
  }

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserLocationCopyWith<$Res>? get snappedLocation {
    if (_value.snappedLocation == null) {
      return null;
    }

    return $UserLocationCopyWith<$Res>(_value.snappedLocation!, (value) {
      return _then(_value.copyWith(snappedLocation: value) as $Val);
    });
  }

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TripProgressCopyWith<$Res>? get progress {
    if (_value.progress == null) {
      return null;
    }

    return $TripProgressCopyWith<$Res>(_value.progress!, (value) {
      return _then(_value.copyWith(progress: value) as $Val);
    });
  }

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VisualInstructionCopyWith<$Res>? get currentVisual {
    if (_value.currentVisual == null) {
      return null;
    }

    return $VisualInstructionCopyWith<$Res>(_value.currentVisual!, (value) {
      return _then(_value.copyWith(currentVisual: value) as $Val);
    });
  }

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StepRefCopyWith<$Res>? get currentStep {
    if (_value.currentStep == null) {
      return null;
    }

    return $StepRefCopyWith<$Res>(_value.currentStep!, (value) {
      return _then(_value.copyWith(currentStep: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$NavigationStateImplCopyWith<$Res>
    implements $NavigationStateCopyWith<$Res> {
  factory _$$NavigationStateImplCopyWith(
    _$NavigationStateImpl value,
    $Res Function(_$NavigationStateImpl) then,
  ) = __$$NavigationStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    TripStatus status,
    @JsonKey(name: 'is_off_route') bool isOffRoute,
    @JsonKey(name: 'snapped_location') UserLocation? snappedLocation,
    TripProgress? progress,
    @JsonKey(name: 'current_visual') VisualInstruction? currentVisual,
    @JsonKey(name: 'current_step') StepRef? currentStep,
  });

  @override
  $UserLocationCopyWith<$Res>? get snappedLocation;
  @override
  $TripProgressCopyWith<$Res>? get progress;
  @override
  $VisualInstructionCopyWith<$Res>? get currentVisual;
  @override
  $StepRefCopyWith<$Res>? get currentStep;
}

/// @nodoc
class __$$NavigationStateImplCopyWithImpl<$Res>
    extends _$NavigationStateCopyWithImpl<$Res, _$NavigationStateImpl>
    implements _$$NavigationStateImplCopyWith<$Res> {
  __$$NavigationStateImplCopyWithImpl(
    _$NavigationStateImpl _value,
    $Res Function(_$NavigationStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? isOffRoute = null,
    Object? snappedLocation = freezed,
    Object? progress = freezed,
    Object? currentVisual = freezed,
    Object? currentStep = freezed,
  }) {
    return _then(
      _$NavigationStateImpl(
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TripStatus,
        isOffRoute: null == isOffRoute
            ? _value.isOffRoute
            : isOffRoute // ignore: cast_nullable_to_non_nullable
                  as bool,
        snappedLocation: freezed == snappedLocation
            ? _value.snappedLocation
            : snappedLocation // ignore: cast_nullable_to_non_nullable
                  as UserLocation?,
        progress: freezed == progress
            ? _value.progress
            : progress // ignore: cast_nullable_to_non_nullable
                  as TripProgress?,
        currentVisual: freezed == currentVisual
            ? _value.currentVisual
            : currentVisual // ignore: cast_nullable_to_non_nullable
                  as VisualInstruction?,
        currentStep: freezed == currentStep
            ? _value.currentStep
            : currentStep // ignore: cast_nullable_to_non_nullable
                  as StepRef?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NavigationStateImpl implements _NavigationState {
  const _$NavigationStateImpl({
    required this.status,
    @JsonKey(name: 'is_off_route') required this.isOffRoute,
    @JsonKey(name: 'snapped_location') this.snappedLocation,
    this.progress,
    @JsonKey(name: 'current_visual') this.currentVisual,
    @JsonKey(name: 'current_step') this.currentStep,
  });

  factory _$NavigationStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$NavigationStateImplFromJson(json);

  @override
  final TripStatus status;
  @override
  @JsonKey(name: 'is_off_route')
  final bool isOffRoute;
  @override
  @JsonKey(name: 'snapped_location')
  final UserLocation? snappedLocation;
  @override
  final TripProgress? progress;
  @override
  @JsonKey(name: 'current_visual')
  final VisualInstruction? currentVisual;
  @override
  @JsonKey(name: 'current_step')
  final StepRef? currentStep;

  @override
  String toString() {
    return 'NavigationState(status: $status, isOffRoute: $isOffRoute, snappedLocation: $snappedLocation, progress: $progress, currentVisual: $currentVisual, currentStep: $currentStep)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NavigationStateImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isOffRoute, isOffRoute) ||
                other.isOffRoute == isOffRoute) &&
            (identical(other.snappedLocation, snappedLocation) ||
                other.snappedLocation == snappedLocation) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.currentVisual, currentVisual) ||
                other.currentVisual == currentVisual) &&
            (identical(other.currentStep, currentStep) ||
                other.currentStep == currentStep));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    status,
    isOffRoute,
    snappedLocation,
    progress,
    currentVisual,
    currentStep,
  );

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NavigationStateImplCopyWith<_$NavigationStateImpl> get copyWith =>
      __$$NavigationStateImplCopyWithImpl<_$NavigationStateImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NavigationStateImplToJson(this);
  }
}

abstract class _NavigationState implements NavigationState {
  const factory _NavigationState({
    required final TripStatus status,
    @JsonKey(name: 'is_off_route') required final bool isOffRoute,
    @JsonKey(name: 'snapped_location') final UserLocation? snappedLocation,
    final TripProgress? progress,
    @JsonKey(name: 'current_visual') final VisualInstruction? currentVisual,
    @JsonKey(name: 'current_step') final StepRef? currentStep,
  }) = _$NavigationStateImpl;

  factory _NavigationState.fromJson(Map<String, dynamic> json) =
      _$NavigationStateImpl.fromJson;

  @override
  TripStatus get status;
  @override
  @JsonKey(name: 'is_off_route')
  bool get isOffRoute;
  @override
  @JsonKey(name: 'snapped_location')
  UserLocation? get snappedLocation;
  @override
  TripProgress? get progress;
  @override
  @JsonKey(name: 'current_visual')
  VisualInstruction? get currentVisual;
  @override
  @JsonKey(name: 'current_step')
  StepRef? get currentStep;

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NavigationStateImplCopyWith<_$NavigationStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
