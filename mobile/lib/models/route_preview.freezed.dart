// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_preview.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RoutePreview _$RoutePreviewFromJson(Map<String, dynamic> json) {
  return _RoutePreview.fromJson(json);
}

/// @nodoc
mixin _$RoutePreview {
  Map<String, dynamic> get geometry => throw _privateConstructorUsedError;
  double get distance => throw _privateConstructorUsedError;
  double get time => throw _privateConstructorUsedError;

  /// Serializes this RoutePreview to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RoutePreview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RoutePreviewCopyWith<RoutePreview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoutePreviewCopyWith<$Res> {
  factory $RoutePreviewCopyWith(
          RoutePreview value, $Res Function(RoutePreview) then) =
      _$RoutePreviewCopyWithImpl<$Res, RoutePreview>;
  @useResult
  $Res call({Map<String, dynamic> geometry, double distance, double time});
}

/// @nodoc
class _$RoutePreviewCopyWithImpl<$Res, $Val extends RoutePreview>
    implements $RoutePreviewCopyWith<$Res> {
  _$RoutePreviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RoutePreview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? geometry = null,
    Object? distance = null,
    Object? time = null,
  }) {
    return _then(_value.copyWith(
      geometry: null == geometry
          ? _value.geometry
          : geometry // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      distance: null == distance
          ? _value.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as double,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RoutePreviewImplCopyWith<$Res>
    implements $RoutePreviewCopyWith<$Res> {
  factory _$$RoutePreviewImplCopyWith(
          _$RoutePreviewImpl value, $Res Function(_$RoutePreviewImpl) then) =
      __$$RoutePreviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<String, dynamic> geometry, double distance, double time});
}

/// @nodoc
class __$$RoutePreviewImplCopyWithImpl<$Res>
    extends _$RoutePreviewCopyWithImpl<$Res, _$RoutePreviewImpl>
    implements _$$RoutePreviewImplCopyWith<$Res> {
  __$$RoutePreviewImplCopyWithImpl(
      _$RoutePreviewImpl _value, $Res Function(_$RoutePreviewImpl) _then)
      : super(_value, _then);

  /// Create a copy of RoutePreview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? geometry = null,
    Object? distance = null,
    Object? time = null,
  }) {
    return _then(_$RoutePreviewImpl(
      geometry: null == geometry
          ? _value._geometry
          : geometry // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      distance: null == distance
          ? _value.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as double,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RoutePreviewImpl implements _RoutePreview {
  const _$RoutePreviewImpl(
      {required final Map<String, dynamic> geometry,
      required this.distance,
      required this.time})
      : _geometry = geometry;

  factory _$RoutePreviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$RoutePreviewImplFromJson(json);

  final Map<String, dynamic> _geometry;
  @override
  Map<String, dynamic> get geometry {
    if (_geometry is EqualUnmodifiableMapView) return _geometry;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_geometry);
  }

  @override
  final double distance;
  @override
  final double time;

  @override
  String toString() {
    return 'RoutePreview(geometry: $geometry, distance: $distance, time: $time)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoutePreviewImpl &&
            const DeepCollectionEquality().equals(other._geometry, _geometry) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            (identical(other.time, time) || other.time == time));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_geometry), distance, time);

  /// Create a copy of RoutePreview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RoutePreviewImplCopyWith<_$RoutePreviewImpl> get copyWith =>
      __$$RoutePreviewImplCopyWithImpl<_$RoutePreviewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RoutePreviewImplToJson(
      this,
    );
  }
}

abstract class _RoutePreview implements RoutePreview {
  const factory _RoutePreview(
      {required final Map<String, dynamic> geometry,
      required final double distance,
      required final double time}) = _$RoutePreviewImpl;

  factory _RoutePreview.fromJson(Map<String, dynamic> json) =
      _$RoutePreviewImpl.fromJson;

  @override
  Map<String, dynamic> get geometry;
  @override
  double get distance;
  @override
  double get time;

  /// Create a copy of RoutePreview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RoutePreviewImplCopyWith<_$RoutePreviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
