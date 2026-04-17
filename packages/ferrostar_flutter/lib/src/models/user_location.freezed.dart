// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_location.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UserLocation _$UserLocationFromJson(Map<String, dynamic> json) {
  return _UserLocation.fromJson(json);
}

/// @nodoc
mixin _$UserLocation {
  double get lat => throw _privateConstructorUsedError;
  double get lng => throw _privateConstructorUsedError;
  @JsonKey(name: 'horizontal_accuracy_m')
  double get horizontalAccuracyM => throw _privateConstructorUsedError;
  @JsonKey(name: 'course_deg')
  double? get courseDeg => throw _privateConstructorUsedError;
  @JsonKey(name: 'speed_mps')
  double? get speedMps => throw _privateConstructorUsedError;
  @JsonKey(name: 'timestamp_ms')
  int get timestampMs => throw _privateConstructorUsedError;

  /// Serializes this UserLocation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserLocationCopyWith<UserLocation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserLocationCopyWith<$Res> {
  factory $UserLocationCopyWith(
    UserLocation value,
    $Res Function(UserLocation) then,
  ) = _$UserLocationCopyWithImpl<$Res, UserLocation>;
  @useResult
  $Res call({
    double lat,
    double lng,
    @JsonKey(name: 'horizontal_accuracy_m') double horizontalAccuracyM,
    @JsonKey(name: 'course_deg') double? courseDeg,
    @JsonKey(name: 'speed_mps') double? speedMps,
    @JsonKey(name: 'timestamp_ms') int timestampMs,
  });
}

/// @nodoc
class _$UserLocationCopyWithImpl<$Res, $Val extends UserLocation>
    implements $UserLocationCopyWith<$Res> {
  _$UserLocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lat = null,
    Object? lng = null,
    Object? horizontalAccuracyM = null,
    Object? courseDeg = freezed,
    Object? speedMps = freezed,
    Object? timestampMs = null,
  }) {
    return _then(
      _value.copyWith(
            lat: null == lat
                ? _value.lat
                : lat // ignore: cast_nullable_to_non_nullable
                      as double,
            lng: null == lng
                ? _value.lng
                : lng // ignore: cast_nullable_to_non_nullable
                      as double,
            horizontalAccuracyM: null == horizontalAccuracyM
                ? _value.horizontalAccuracyM
                : horizontalAccuracyM // ignore: cast_nullable_to_non_nullable
                      as double,
            courseDeg: freezed == courseDeg
                ? _value.courseDeg
                : courseDeg // ignore: cast_nullable_to_non_nullable
                      as double?,
            speedMps: freezed == speedMps
                ? _value.speedMps
                : speedMps // ignore: cast_nullable_to_non_nullable
                      as double?,
            timestampMs: null == timestampMs
                ? _value.timestampMs
                : timestampMs // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserLocationImplCopyWith<$Res>
    implements $UserLocationCopyWith<$Res> {
  factory _$$UserLocationImplCopyWith(
    _$UserLocationImpl value,
    $Res Function(_$UserLocationImpl) then,
  ) = __$$UserLocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double lat,
    double lng,
    @JsonKey(name: 'horizontal_accuracy_m') double horizontalAccuracyM,
    @JsonKey(name: 'course_deg') double? courseDeg,
    @JsonKey(name: 'speed_mps') double? speedMps,
    @JsonKey(name: 'timestamp_ms') int timestampMs,
  });
}

/// @nodoc
class __$$UserLocationImplCopyWithImpl<$Res>
    extends _$UserLocationCopyWithImpl<$Res, _$UserLocationImpl>
    implements _$$UserLocationImplCopyWith<$Res> {
  __$$UserLocationImplCopyWithImpl(
    _$UserLocationImpl _value,
    $Res Function(_$UserLocationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lat = null,
    Object? lng = null,
    Object? horizontalAccuracyM = null,
    Object? courseDeg = freezed,
    Object? speedMps = freezed,
    Object? timestampMs = null,
  }) {
    return _then(
      _$UserLocationImpl(
        lat: null == lat
            ? _value.lat
            : lat // ignore: cast_nullable_to_non_nullable
                  as double,
        lng: null == lng
            ? _value.lng
            : lng // ignore: cast_nullable_to_non_nullable
                  as double,
        horizontalAccuracyM: null == horizontalAccuracyM
            ? _value.horizontalAccuracyM
            : horizontalAccuracyM // ignore: cast_nullable_to_non_nullable
                  as double,
        courseDeg: freezed == courseDeg
            ? _value.courseDeg
            : courseDeg // ignore: cast_nullable_to_non_nullable
                  as double?,
        speedMps: freezed == speedMps
            ? _value.speedMps
            : speedMps // ignore: cast_nullable_to_non_nullable
                  as double?,
        timestampMs: null == timestampMs
            ? _value.timestampMs
            : timestampMs // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserLocationImpl implements _UserLocation {
  const _$UserLocationImpl({
    required this.lat,
    required this.lng,
    @JsonKey(name: 'horizontal_accuracy_m') required this.horizontalAccuracyM,
    @JsonKey(name: 'course_deg') this.courseDeg,
    @JsonKey(name: 'speed_mps') this.speedMps,
    @JsonKey(name: 'timestamp_ms') required this.timestampMs,
  });

  factory _$UserLocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserLocationImplFromJson(json);

  @override
  final double lat;
  @override
  final double lng;
  @override
  @JsonKey(name: 'horizontal_accuracy_m')
  final double horizontalAccuracyM;
  @override
  @JsonKey(name: 'course_deg')
  final double? courseDeg;
  @override
  @JsonKey(name: 'speed_mps')
  final double? speedMps;
  @override
  @JsonKey(name: 'timestamp_ms')
  final int timestampMs;

  @override
  String toString() {
    return 'UserLocation(lat: $lat, lng: $lng, horizontalAccuracyM: $horizontalAccuracyM, courseDeg: $courseDeg, speedMps: $speedMps, timestampMs: $timestampMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserLocationImpl &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.horizontalAccuracyM, horizontalAccuracyM) ||
                other.horizontalAccuracyM == horizontalAccuracyM) &&
            (identical(other.courseDeg, courseDeg) ||
                other.courseDeg == courseDeg) &&
            (identical(other.speedMps, speedMps) ||
                other.speedMps == speedMps) &&
            (identical(other.timestampMs, timestampMs) ||
                other.timestampMs == timestampMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    lat,
    lng,
    horizontalAccuracyM,
    courseDeg,
    speedMps,
    timestampMs,
  );

  /// Create a copy of UserLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserLocationImplCopyWith<_$UserLocationImpl> get copyWith =>
      __$$UserLocationImplCopyWithImpl<_$UserLocationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserLocationImplToJson(this);
  }
}

abstract class _UserLocation implements UserLocation {
  const factory _UserLocation({
    required final double lat,
    required final double lng,
    @JsonKey(name: 'horizontal_accuracy_m')
    required final double horizontalAccuracyM,
    @JsonKey(name: 'course_deg') final double? courseDeg,
    @JsonKey(name: 'speed_mps') final double? speedMps,
    @JsonKey(name: 'timestamp_ms') required final int timestampMs,
  }) = _$UserLocationImpl;

  factory _UserLocation.fromJson(Map<String, dynamic> json) =
      _$UserLocationImpl.fromJson;

  @override
  double get lat;
  @override
  double get lng;
  @override
  @JsonKey(name: 'horizontal_accuracy_m')
  double get horizontalAccuracyM;
  @override
  @JsonKey(name: 'course_deg')
  double? get courseDeg;
  @override
  @JsonKey(name: 'speed_mps')
  double? get speedMps;
  @override
  @JsonKey(name: 'timestamp_ms')
  int get timestampMs;

  /// Create a copy of UserLocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserLocationImplCopyWith<_$UserLocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
