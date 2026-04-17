// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'waypoint_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WaypointInput _$WaypointInputFromJson(Map<String, dynamic> json) {
  return _WaypointInput.fromJson(json);
}

/// @nodoc
mixin _$WaypointInput {
  double get lat => throw _privateConstructorUsedError;
  double get lng => throw _privateConstructorUsedError;
  WaypointKind get kind => throw _privateConstructorUsedError;

  /// Serializes this WaypointInput to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WaypointInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WaypointInputCopyWith<WaypointInput> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WaypointInputCopyWith<$Res> {
  factory $WaypointInputCopyWith(
    WaypointInput value,
    $Res Function(WaypointInput) then,
  ) = _$WaypointInputCopyWithImpl<$Res, WaypointInput>;
  @useResult
  $Res call({double lat, double lng, WaypointKind kind});
}

/// @nodoc
class _$WaypointInputCopyWithImpl<$Res, $Val extends WaypointInput>
    implements $WaypointInputCopyWith<$Res> {
  _$WaypointInputCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WaypointInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? lat = null, Object? lng = null, Object? kind = null}) {
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
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as WaypointKind,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WaypointInputImplCopyWith<$Res>
    implements $WaypointInputCopyWith<$Res> {
  factory _$$WaypointInputImplCopyWith(
    _$WaypointInputImpl value,
    $Res Function(_$WaypointInputImpl) then,
  ) = __$$WaypointInputImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double lat, double lng, WaypointKind kind});
}

/// @nodoc
class __$$WaypointInputImplCopyWithImpl<$Res>
    extends _$WaypointInputCopyWithImpl<$Res, _$WaypointInputImpl>
    implements _$$WaypointInputImplCopyWith<$Res> {
  __$$WaypointInputImplCopyWithImpl(
    _$WaypointInputImpl _value,
    $Res Function(_$WaypointInputImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WaypointInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? lat = null, Object? lng = null, Object? kind = null}) {
    return _then(
      _$WaypointInputImpl(
        lat: null == lat
            ? _value.lat
            : lat // ignore: cast_nullable_to_non_nullable
                  as double,
        lng: null == lng
            ? _value.lng
            : lng // ignore: cast_nullable_to_non_nullable
                  as double,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as WaypointKind,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WaypointInputImpl implements _WaypointInput {
  const _$WaypointInputImpl({
    required this.lat,
    required this.lng,
    this.kind = WaypointKind.breakPoint,
  });

  factory _$WaypointInputImpl.fromJson(Map<String, dynamic> json) =>
      _$$WaypointInputImplFromJson(json);

  @override
  final double lat;
  @override
  final double lng;
  @override
  @JsonKey()
  final WaypointKind kind;

  @override
  String toString() {
    return 'WaypointInput(lat: $lat, lng: $lng, kind: $kind)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WaypointInputImpl &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.kind, kind) || other.kind == kind));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, lat, lng, kind);

  /// Create a copy of WaypointInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WaypointInputImplCopyWith<_$WaypointInputImpl> get copyWith =>
      __$$WaypointInputImplCopyWithImpl<_$WaypointInputImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WaypointInputImplToJson(this);
  }
}

abstract class _WaypointInput implements WaypointInput {
  const factory _WaypointInput({
    required final double lat,
    required final double lng,
    final WaypointKind kind,
  }) = _$WaypointInputImpl;

  factory _WaypointInput.fromJson(Map<String, dynamic> json) =
      _$WaypointInputImpl.fromJson;

  @override
  double get lat;
  @override
  double get lng;
  @override
  WaypointKind get kind;

  /// Create a copy of WaypointInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WaypointInputImplCopyWith<_$WaypointInputImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
