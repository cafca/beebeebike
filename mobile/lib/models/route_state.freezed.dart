// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RouteState {
  Location? get origin => throw _privateConstructorUsedError;
  Location? get destination => throw _privateConstructorUsedError;
  RoutePreview? get preview => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of RouteState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RouteStateCopyWith<RouteState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RouteStateCopyWith<$Res> {
  factory $RouteStateCopyWith(
          RouteState value, $Res Function(RouteState) then) =
      _$RouteStateCopyWithImpl<$Res, RouteState>;
  @useResult
  $Res call(
      {Location? origin,
      Location? destination,
      RoutePreview? preview,
      bool isLoading,
      String? error});

  $LocationCopyWith<$Res>? get origin;
  $LocationCopyWith<$Res>? get destination;
  $RoutePreviewCopyWith<$Res>? get preview;
}

/// @nodoc
class _$RouteStateCopyWithImpl<$Res, $Val extends RouteState>
    implements $RouteStateCopyWith<$Res> {
  _$RouteStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RouteState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? origin = freezed,
    Object? destination = freezed,
    Object? preview = freezed,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      origin: freezed == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as Location?,
      destination: freezed == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as Location?,
      preview: freezed == preview
          ? _value.preview
          : preview // ignore: cast_nullable_to_non_nullable
              as RoutePreview?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of RouteState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationCopyWith<$Res>? get origin {
    if (_value.origin == null) {
      return null;
    }

    return $LocationCopyWith<$Res>(_value.origin!, (value) {
      return _then(_value.copyWith(origin: value) as $Val);
    });
  }

  /// Create a copy of RouteState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationCopyWith<$Res>? get destination {
    if (_value.destination == null) {
      return null;
    }

    return $LocationCopyWith<$Res>(_value.destination!, (value) {
      return _then(_value.copyWith(destination: value) as $Val);
    });
  }

  /// Create a copy of RouteState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RoutePreviewCopyWith<$Res>? get preview {
    if (_value.preview == null) {
      return null;
    }

    return $RoutePreviewCopyWith<$Res>(_value.preview!, (value) {
      return _then(_value.copyWith(preview: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RouteStateImplCopyWith<$Res>
    implements $RouteStateCopyWith<$Res> {
  factory _$$RouteStateImplCopyWith(
          _$RouteStateImpl value, $Res Function(_$RouteStateImpl) then) =
      __$$RouteStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Location? origin,
      Location? destination,
      RoutePreview? preview,
      bool isLoading,
      String? error});

  @override
  $LocationCopyWith<$Res>? get origin;
  @override
  $LocationCopyWith<$Res>? get destination;
  @override
  $RoutePreviewCopyWith<$Res>? get preview;
}

/// @nodoc
class __$$RouteStateImplCopyWithImpl<$Res>
    extends _$RouteStateCopyWithImpl<$Res, _$RouteStateImpl>
    implements _$$RouteStateImplCopyWith<$Res> {
  __$$RouteStateImplCopyWithImpl(
      _$RouteStateImpl _value, $Res Function(_$RouteStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of RouteState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? origin = freezed,
    Object? destination = freezed,
    Object? preview = freezed,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_$RouteStateImpl(
      origin: freezed == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as Location?,
      destination: freezed == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as Location?,
      preview: freezed == preview
          ? _value.preview
          : preview // ignore: cast_nullable_to_non_nullable
              as RoutePreview?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$RouteStateImpl implements _RouteState {
  const _$RouteStateImpl(
      {this.origin,
      this.destination,
      this.preview,
      this.isLoading = false,
      this.error});

  @override
  final Location? origin;
  @override
  final Location? destination;
  @override
  final RoutePreview? preview;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString() {
    return 'RouteState(origin: $origin, destination: $destination, preview: $preview, isLoading: $isLoading, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RouteStateImpl &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.preview, preview) || other.preview == preview) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, origin, destination, preview, isLoading, error);

  /// Create a copy of RouteState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RouteStateImplCopyWith<_$RouteStateImpl> get copyWith =>
      __$$RouteStateImplCopyWithImpl<_$RouteStateImpl>(this, _$identity);
}

abstract class _RouteState implements RouteState {
  const factory _RouteState(
      {final Location? origin,
      final Location? destination,
      final RoutePreview? preview,
      final bool isLoading,
      final String? error}) = _$RouteStateImpl;

  @override
  Location? get origin;
  @override
  Location? get destination;
  @override
  RoutePreview? get preview;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of RouteState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RouteStateImplCopyWith<_$RouteStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
