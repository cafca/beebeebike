// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_deviation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RouteDeviation _$RouteDeviationFromJson(Map<String, dynamic> json) {
  return _RouteDeviation.fromJson(json);
}

/// @nodoc
mixin _$RouteDeviation {
  @JsonKey(name: 'deviation_m')
  double get deviationM => throw _privateConstructorUsedError;
  @JsonKey(name: 'duration_off_route_ms')
  int get durationOffRouteMs => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_location')
  UserLocation get userLocation => throw _privateConstructorUsedError;

  /// Serializes this RouteDeviation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RouteDeviation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RouteDeviationCopyWith<RouteDeviation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RouteDeviationCopyWith<$Res> {
  factory $RouteDeviationCopyWith(
    RouteDeviation value,
    $Res Function(RouteDeviation) then,
  ) = _$RouteDeviationCopyWithImpl<$Res, RouteDeviation>;
  @useResult
  $Res call({
    @JsonKey(name: 'deviation_m') double deviationM,
    @JsonKey(name: 'duration_off_route_ms') int durationOffRouteMs,
    @JsonKey(name: 'user_location') UserLocation userLocation,
  });

  $UserLocationCopyWith<$Res> get userLocation;
}

/// @nodoc
class _$RouteDeviationCopyWithImpl<$Res, $Val extends RouteDeviation>
    implements $RouteDeviationCopyWith<$Res> {
  _$RouteDeviationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RouteDeviation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviationM = null,
    Object? durationOffRouteMs = null,
    Object? userLocation = null,
  }) {
    return _then(
      _value.copyWith(
            deviationM: null == deviationM
                ? _value.deviationM
                : deviationM // ignore: cast_nullable_to_non_nullable
                      as double,
            durationOffRouteMs: null == durationOffRouteMs
                ? _value.durationOffRouteMs
                : durationOffRouteMs // ignore: cast_nullable_to_non_nullable
                      as int,
            userLocation: null == userLocation
                ? _value.userLocation
                : userLocation // ignore: cast_nullable_to_non_nullable
                      as UserLocation,
          )
          as $Val,
    );
  }

  /// Create a copy of RouteDeviation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserLocationCopyWith<$Res> get userLocation {
    return $UserLocationCopyWith<$Res>(_value.userLocation, (value) {
      return _then(_value.copyWith(userLocation: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RouteDeviationImplCopyWith<$Res>
    implements $RouteDeviationCopyWith<$Res> {
  factory _$$RouteDeviationImplCopyWith(
    _$RouteDeviationImpl value,
    $Res Function(_$RouteDeviationImpl) then,
  ) = __$$RouteDeviationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'deviation_m') double deviationM,
    @JsonKey(name: 'duration_off_route_ms') int durationOffRouteMs,
    @JsonKey(name: 'user_location') UserLocation userLocation,
  });

  @override
  $UserLocationCopyWith<$Res> get userLocation;
}

/// @nodoc
class __$$RouteDeviationImplCopyWithImpl<$Res>
    extends _$RouteDeviationCopyWithImpl<$Res, _$RouteDeviationImpl>
    implements _$$RouteDeviationImplCopyWith<$Res> {
  __$$RouteDeviationImplCopyWithImpl(
    _$RouteDeviationImpl _value,
    $Res Function(_$RouteDeviationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RouteDeviation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviationM = null,
    Object? durationOffRouteMs = null,
    Object? userLocation = null,
  }) {
    return _then(
      _$RouteDeviationImpl(
        deviationM: null == deviationM
            ? _value.deviationM
            : deviationM // ignore: cast_nullable_to_non_nullable
                  as double,
        durationOffRouteMs: null == durationOffRouteMs
            ? _value.durationOffRouteMs
            : durationOffRouteMs // ignore: cast_nullable_to_non_nullable
                  as int,
        userLocation: null == userLocation
            ? _value.userLocation
            : userLocation // ignore: cast_nullable_to_non_nullable
                  as UserLocation,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RouteDeviationImpl implements _RouteDeviation {
  const _$RouteDeviationImpl({
    @JsonKey(name: 'deviation_m') required this.deviationM,
    @JsonKey(name: 'duration_off_route_ms') required this.durationOffRouteMs,
    @JsonKey(name: 'user_location') required this.userLocation,
  });

  factory _$RouteDeviationImpl.fromJson(Map<String, dynamic> json) =>
      _$$RouteDeviationImplFromJson(json);

  @override
  @JsonKey(name: 'deviation_m')
  final double deviationM;
  @override
  @JsonKey(name: 'duration_off_route_ms')
  final int durationOffRouteMs;
  @override
  @JsonKey(name: 'user_location')
  final UserLocation userLocation;

  @override
  String toString() {
    return 'RouteDeviation(deviationM: $deviationM, durationOffRouteMs: $durationOffRouteMs, userLocation: $userLocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RouteDeviationImpl &&
            (identical(other.deviationM, deviationM) ||
                other.deviationM == deviationM) &&
            (identical(other.durationOffRouteMs, durationOffRouteMs) ||
                other.durationOffRouteMs == durationOffRouteMs) &&
            (identical(other.userLocation, userLocation) ||
                other.userLocation == userLocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, deviationM, durationOffRouteMs, userLocation);

  /// Create a copy of RouteDeviation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RouteDeviationImplCopyWith<_$RouteDeviationImpl> get copyWith =>
      __$$RouteDeviationImplCopyWithImpl<_$RouteDeviationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RouteDeviationImplToJson(this);
  }
}

abstract class _RouteDeviation implements RouteDeviation {
  const factory _RouteDeviation({
    @JsonKey(name: 'deviation_m') required final double deviationM,
    @JsonKey(name: 'duration_off_route_ms')
    required final int durationOffRouteMs,
    @JsonKey(name: 'user_location') required final UserLocation userLocation,
  }) = _$RouteDeviationImpl;

  factory _RouteDeviation.fromJson(Map<String, dynamic> json) =
      _$RouteDeviationImpl.fromJson;

  @override
  @JsonKey(name: 'deviation_m')
  double get deviationM;
  @override
  @JsonKey(name: 'duration_off_route_ms')
  int get durationOffRouteMs;
  @override
  @JsonKey(name: 'user_location')
  UserLocation get userLocation;

  /// Create a copy of RouteDeviation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RouteDeviationImplCopyWith<_$RouteDeviationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
