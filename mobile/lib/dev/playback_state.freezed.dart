// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$PlaybackState {
  bool get isPlaying => throw _privateConstructorUsedError;
  double get cumulativeM => throw _privateConstructorUsedError;
  double get speedMultiplier => throw _privateConstructorUsedError;
  LatLng? get overrideLatLng => throw _privateConstructorUsedError;
  double get routeLengthM => throw _privateConstructorUsedError;
  double get routeBaseSpeedMps => throw _privateConstructorUsedError;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlaybackStateCopyWith<PlaybackState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlaybackStateCopyWith<$Res> {
  factory $PlaybackStateCopyWith(
    PlaybackState value,
    $Res Function(PlaybackState) then,
  ) = _$PlaybackStateCopyWithImpl<$Res, PlaybackState>;
  @useResult
  $Res call({
    bool isPlaying,
    double cumulativeM,
    double speedMultiplier,
    LatLng? overrideLatLng,
    double routeLengthM,
    double routeBaseSpeedMps,
  });
}

/// @nodoc
class _$PlaybackStateCopyWithImpl<$Res, $Val extends PlaybackState>
    implements $PlaybackStateCopyWith<$Res> {
  _$PlaybackStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isPlaying = null,
    Object? cumulativeM = null,
    Object? speedMultiplier = null,
    Object? overrideLatLng = freezed,
    Object? routeLengthM = null,
    Object? routeBaseSpeedMps = null,
  }) {
    return _then(
      _value.copyWith(
            isPlaying:
                null == isPlaying
                    ? _value.isPlaying
                    : isPlaying // ignore: cast_nullable_to_non_nullable
                        as bool,
            cumulativeM:
                null == cumulativeM
                    ? _value.cumulativeM
                    : cumulativeM // ignore: cast_nullable_to_non_nullable
                        as double,
            speedMultiplier:
                null == speedMultiplier
                    ? _value.speedMultiplier
                    : speedMultiplier // ignore: cast_nullable_to_non_nullable
                        as double,
            overrideLatLng:
                freezed == overrideLatLng
                    ? _value.overrideLatLng
                    : overrideLatLng // ignore: cast_nullable_to_non_nullable
                        as LatLng?,
            routeLengthM:
                null == routeLengthM
                    ? _value.routeLengthM
                    : routeLengthM // ignore: cast_nullable_to_non_nullable
                        as double,
            routeBaseSpeedMps:
                null == routeBaseSpeedMps
                    ? _value.routeBaseSpeedMps
                    : routeBaseSpeedMps // ignore: cast_nullable_to_non_nullable
                        as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlaybackStateImplCopyWith<$Res>
    implements $PlaybackStateCopyWith<$Res> {
  factory _$$PlaybackStateImplCopyWith(
    _$PlaybackStateImpl value,
    $Res Function(_$PlaybackStateImpl) then,
  ) = __$$PlaybackStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool isPlaying,
    double cumulativeM,
    double speedMultiplier,
    LatLng? overrideLatLng,
    double routeLengthM,
    double routeBaseSpeedMps,
  });
}

/// @nodoc
class __$$PlaybackStateImplCopyWithImpl<$Res>
    extends _$PlaybackStateCopyWithImpl<$Res, _$PlaybackStateImpl>
    implements _$$PlaybackStateImplCopyWith<$Res> {
  __$$PlaybackStateImplCopyWithImpl(
    _$PlaybackStateImpl _value,
    $Res Function(_$PlaybackStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isPlaying = null,
    Object? cumulativeM = null,
    Object? speedMultiplier = null,
    Object? overrideLatLng = freezed,
    Object? routeLengthM = null,
    Object? routeBaseSpeedMps = null,
  }) {
    return _then(
      _$PlaybackStateImpl(
        isPlaying:
            null == isPlaying
                ? _value.isPlaying
                : isPlaying // ignore: cast_nullable_to_non_nullable
                    as bool,
        cumulativeM:
            null == cumulativeM
                ? _value.cumulativeM
                : cumulativeM // ignore: cast_nullable_to_non_nullable
                    as double,
        speedMultiplier:
            null == speedMultiplier
                ? _value.speedMultiplier
                : speedMultiplier // ignore: cast_nullable_to_non_nullable
                    as double,
        overrideLatLng:
            freezed == overrideLatLng
                ? _value.overrideLatLng
                : overrideLatLng // ignore: cast_nullable_to_non_nullable
                    as LatLng?,
        routeLengthM:
            null == routeLengthM
                ? _value.routeLengthM
                : routeLengthM // ignore: cast_nullable_to_non_nullable
                    as double,
        routeBaseSpeedMps:
            null == routeBaseSpeedMps
                ? _value.routeBaseSpeedMps
                : routeBaseSpeedMps // ignore: cast_nullable_to_non_nullable
                    as double,
      ),
    );
  }
}

/// @nodoc

class _$PlaybackStateImpl implements _PlaybackState {
  const _$PlaybackStateImpl({
    this.isPlaying = false,
    this.cumulativeM = 0.0,
    this.speedMultiplier = 1.0,
    this.overrideLatLng,
    this.routeLengthM = 0.0,
    this.routeBaseSpeedMps = 0.0,
  });

  @override
  @JsonKey()
  final bool isPlaying;
  @override
  @JsonKey()
  final double cumulativeM;
  @override
  @JsonKey()
  final double speedMultiplier;
  @override
  final LatLng? overrideLatLng;
  @override
  @JsonKey()
  final double routeLengthM;
  @override
  @JsonKey()
  final double routeBaseSpeedMps;

  @override
  String toString() {
    return 'PlaybackState(isPlaying: $isPlaying, cumulativeM: $cumulativeM, speedMultiplier: $speedMultiplier, overrideLatLng: $overrideLatLng, routeLengthM: $routeLengthM, routeBaseSpeedMps: $routeBaseSpeedMps)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlaybackStateImpl &&
            (identical(other.isPlaying, isPlaying) ||
                other.isPlaying == isPlaying) &&
            (identical(other.cumulativeM, cumulativeM) ||
                other.cumulativeM == cumulativeM) &&
            (identical(other.speedMultiplier, speedMultiplier) ||
                other.speedMultiplier == speedMultiplier) &&
            (identical(other.overrideLatLng, overrideLatLng) ||
                other.overrideLatLng == overrideLatLng) &&
            (identical(other.routeLengthM, routeLengthM) ||
                other.routeLengthM == routeLengthM) &&
            (identical(other.routeBaseSpeedMps, routeBaseSpeedMps) ||
                other.routeBaseSpeedMps == routeBaseSpeedMps));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    isPlaying,
    cumulativeM,
    speedMultiplier,
    overrideLatLng,
    routeLengthM,
    routeBaseSpeedMps,
  );

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlaybackStateImplCopyWith<_$PlaybackStateImpl> get copyWith =>
      __$$PlaybackStateImplCopyWithImpl<_$PlaybackStateImpl>(this, _$identity);
}

abstract class _PlaybackState implements PlaybackState {
  const factory _PlaybackState({
    final bool isPlaying,
    final double cumulativeM,
    final double speedMultiplier,
    final LatLng? overrideLatLng,
    final double routeLengthM,
    final double routeBaseSpeedMps,
  }) = _$PlaybackStateImpl;

  @override
  bool get isPlaying;
  @override
  double get cumulativeM;
  @override
  double get speedMultiplier;
  @override
  LatLng? get overrideLatLng;
  @override
  double get routeLengthM;
  @override
  double get routeBaseSpeedMps;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlaybackStateImplCopyWith<_$PlaybackStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
