// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trip_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TripProgress _$TripProgressFromJson(Map<String, dynamic> json) {
  return _TripProgress.fromJson(json);
}

/// @nodoc
mixin _$TripProgress {
  @JsonKey(name: 'distance_to_next_maneuver_m')
  double get distanceToNextManeuverM => throw _privateConstructorUsedError;
  @JsonKey(name: 'distance_remaining_m')
  double get distanceRemainingM => throw _privateConstructorUsedError;
  @JsonKey(name: 'duration_remaining_ms')
  int get durationRemainingMs => throw _privateConstructorUsedError;

  /// Serializes this TripProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TripProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TripProgressCopyWith<TripProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TripProgressCopyWith<$Res> {
  factory $TripProgressCopyWith(
    TripProgress value,
    $Res Function(TripProgress) then,
  ) = _$TripProgressCopyWithImpl<$Res, TripProgress>;
  @useResult
  $Res call({
    @JsonKey(name: 'distance_to_next_maneuver_m')
    double distanceToNextManeuverM,
    @JsonKey(name: 'distance_remaining_m') double distanceRemainingM,
    @JsonKey(name: 'duration_remaining_ms') int durationRemainingMs,
  });
}

/// @nodoc
class _$TripProgressCopyWithImpl<$Res, $Val extends TripProgress>
    implements $TripProgressCopyWith<$Res> {
  _$TripProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TripProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? distanceToNextManeuverM = null,
    Object? distanceRemainingM = null,
    Object? durationRemainingMs = null,
  }) {
    return _then(
      _value.copyWith(
            distanceToNextManeuverM: null == distanceToNextManeuverM
                ? _value.distanceToNextManeuverM
                : distanceToNextManeuverM // ignore: cast_nullable_to_non_nullable
                      as double,
            distanceRemainingM: null == distanceRemainingM
                ? _value.distanceRemainingM
                : distanceRemainingM // ignore: cast_nullable_to_non_nullable
                      as double,
            durationRemainingMs: null == durationRemainingMs
                ? _value.durationRemainingMs
                : durationRemainingMs // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TripProgressImplCopyWith<$Res>
    implements $TripProgressCopyWith<$Res> {
  factory _$$TripProgressImplCopyWith(
    _$TripProgressImpl value,
    $Res Function(_$TripProgressImpl) then,
  ) = __$$TripProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'distance_to_next_maneuver_m')
    double distanceToNextManeuverM,
    @JsonKey(name: 'distance_remaining_m') double distanceRemainingM,
    @JsonKey(name: 'duration_remaining_ms') int durationRemainingMs,
  });
}

/// @nodoc
class __$$TripProgressImplCopyWithImpl<$Res>
    extends _$TripProgressCopyWithImpl<$Res, _$TripProgressImpl>
    implements _$$TripProgressImplCopyWith<$Res> {
  __$$TripProgressImplCopyWithImpl(
    _$TripProgressImpl _value,
    $Res Function(_$TripProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TripProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? distanceToNextManeuverM = null,
    Object? distanceRemainingM = null,
    Object? durationRemainingMs = null,
  }) {
    return _then(
      _$TripProgressImpl(
        distanceToNextManeuverM: null == distanceToNextManeuverM
            ? _value.distanceToNextManeuverM
            : distanceToNextManeuverM // ignore: cast_nullable_to_non_nullable
                  as double,
        distanceRemainingM: null == distanceRemainingM
            ? _value.distanceRemainingM
            : distanceRemainingM // ignore: cast_nullable_to_non_nullable
                  as double,
        durationRemainingMs: null == durationRemainingMs
            ? _value.durationRemainingMs
            : durationRemainingMs // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TripProgressImpl implements _TripProgress {
  const _$TripProgressImpl({
    @JsonKey(name: 'distance_to_next_maneuver_m')
    required this.distanceToNextManeuverM,
    @JsonKey(name: 'distance_remaining_m') required this.distanceRemainingM,
    @JsonKey(name: 'duration_remaining_ms') required this.durationRemainingMs,
  });

  factory _$TripProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$TripProgressImplFromJson(json);

  @override
  @JsonKey(name: 'distance_to_next_maneuver_m')
  final double distanceToNextManeuverM;
  @override
  @JsonKey(name: 'distance_remaining_m')
  final double distanceRemainingM;
  @override
  @JsonKey(name: 'duration_remaining_ms')
  final int durationRemainingMs;

  @override
  String toString() {
    return 'TripProgress(distanceToNextManeuverM: $distanceToNextManeuverM, distanceRemainingM: $distanceRemainingM, durationRemainingMs: $durationRemainingMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TripProgressImpl &&
            (identical(
                  other.distanceToNextManeuverM,
                  distanceToNextManeuverM,
                ) ||
                other.distanceToNextManeuverM == distanceToNextManeuverM) &&
            (identical(other.distanceRemainingM, distanceRemainingM) ||
                other.distanceRemainingM == distanceRemainingM) &&
            (identical(other.durationRemainingMs, durationRemainingMs) ||
                other.durationRemainingMs == durationRemainingMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    distanceToNextManeuverM,
    distanceRemainingM,
    durationRemainingMs,
  );

  /// Create a copy of TripProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TripProgressImplCopyWith<_$TripProgressImpl> get copyWith =>
      __$$TripProgressImplCopyWithImpl<_$TripProgressImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TripProgressImplToJson(this);
  }
}

abstract class _TripProgress implements TripProgress {
  const factory _TripProgress({
    @JsonKey(name: 'distance_to_next_maneuver_m')
    required final double distanceToNextManeuverM,
    @JsonKey(name: 'distance_remaining_m')
    required final double distanceRemainingM,
    @JsonKey(name: 'duration_remaining_ms')
    required final int durationRemainingMs,
  }) = _$TripProgressImpl;

  factory _TripProgress.fromJson(Map<String, dynamic> json) =
      _$TripProgressImpl.fromJson;

  @override
  @JsonKey(name: 'distance_to_next_maneuver_m')
  double get distanceToNextManeuverM;
  @override
  @JsonKey(name: 'distance_remaining_m')
  double get distanceRemainingM;
  @override
  @JsonKey(name: 'duration_remaining_ms')
  int get durationRemainingMs;

  /// Create a copy of TripProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TripProgressImplCopyWith<_$TripProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
