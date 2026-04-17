// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geocode_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

GeocodeResult _$GeocodeResultFromJson(Map<String, dynamic> json) {
  return _GeocodeResult.fromJson(json);
}

/// @nodoc
mixin _$GeocodeResult {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  double get lng => throw _privateConstructorUsedError;
  double get lat => throw _privateConstructorUsedError;

  /// Serializes this GeocodeResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GeocodeResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GeocodeResultCopyWith<GeocodeResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GeocodeResultCopyWith<$Res> {
  factory $GeocodeResultCopyWith(
          GeocodeResult value, $Res Function(GeocodeResult) then) =
      _$GeocodeResultCopyWithImpl<$Res, GeocodeResult>;
  @useResult
  $Res call({String id, String name, String label, double lng, double lat});
}

/// @nodoc
class _$GeocodeResultCopyWithImpl<$Res, $Val extends GeocodeResult>
    implements $GeocodeResultCopyWith<$Res> {
  _$GeocodeResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GeocodeResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? label = null,
    Object? lng = null,
    Object? lat = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      lng: null == lng
          ? _value.lng
          : lng // ignore: cast_nullable_to_non_nullable
              as double,
      lat: null == lat
          ? _value.lat
          : lat // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GeocodeResultImplCopyWith<$Res>
    implements $GeocodeResultCopyWith<$Res> {
  factory _$$GeocodeResultImplCopyWith(
          _$GeocodeResultImpl value, $Res Function(_$GeocodeResultImpl) then) =
      __$$GeocodeResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String name, String label, double lng, double lat});
}

/// @nodoc
class __$$GeocodeResultImplCopyWithImpl<$Res>
    extends _$GeocodeResultCopyWithImpl<$Res, _$GeocodeResultImpl>
    implements _$$GeocodeResultImplCopyWith<$Res> {
  __$$GeocodeResultImplCopyWithImpl(
      _$GeocodeResultImpl _value, $Res Function(_$GeocodeResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of GeocodeResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? label = null,
    Object? lng = null,
    Object? lat = null,
  }) {
    return _then(_$GeocodeResultImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      lng: null == lng
          ? _value.lng
          : lng // ignore: cast_nullable_to_non_nullable
              as double,
      lat: null == lat
          ? _value.lat
          : lat // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GeocodeResultImpl implements _GeocodeResult {
  const _$GeocodeResultImpl(
      {required this.id,
      required this.name,
      required this.label,
      required this.lng,
      required this.lat});

  factory _$GeocodeResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$GeocodeResultImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String label;
  @override
  final double lng;
  @override
  final double lat;

  @override
  String toString() {
    return 'GeocodeResult(id: $id, name: $name, label: $label, lng: $lng, lat: $lat)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GeocodeResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.lat, lat) || other.lat == lat));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, label, lng, lat);

  /// Create a copy of GeocodeResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GeocodeResultImplCopyWith<_$GeocodeResultImpl> get copyWith =>
      __$$GeocodeResultImplCopyWithImpl<_$GeocodeResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GeocodeResultImplToJson(
      this,
    );
  }
}

abstract class _GeocodeResult implements GeocodeResult {
  const factory _GeocodeResult(
      {required final String id,
      required final String name,
      required final String label,
      required final double lng,
      required final double lat}) = _$GeocodeResultImpl;

  factory _GeocodeResult.fromJson(Map<String, dynamic> json) =
      _$GeocodeResultImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get label;
  @override
  double get lng;
  @override
  double get lat;

  /// Create a copy of GeocodeResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GeocodeResultImplCopyWith<_$GeocodeResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
