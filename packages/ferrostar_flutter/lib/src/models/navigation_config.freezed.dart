// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'navigation_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NavigationConfig _$NavigationConfigFromJson(Map<String, dynamic> json) {
  return _NavigationConfig.fromJson(json);
}

/// @nodoc
mixin _$NavigationConfig {
  @JsonKey(name: 'deviation_threshold_m')
  double get deviationThresholdM => throw _privateConstructorUsedError;
  @JsonKey(name: 'deviation_duration_threshold_ms')
  int get deviationDurationThresholdMs => throw _privateConstructorUsedError;
  @JsonKey(name: 'snap_user_location_to_route')
  bool get snapUserLocationToRoute => throw _privateConstructorUsedError;

  /// Serializes this NavigationConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NavigationConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NavigationConfigCopyWith<NavigationConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NavigationConfigCopyWith<$Res> {
  factory $NavigationConfigCopyWith(
    NavigationConfig value,
    $Res Function(NavigationConfig) then,
  ) = _$NavigationConfigCopyWithImpl<$Res, NavigationConfig>;
  @useResult
  $Res call({
    @JsonKey(name: 'deviation_threshold_m') double deviationThresholdM,
    @JsonKey(name: 'deviation_duration_threshold_ms')
    int deviationDurationThresholdMs,
    @JsonKey(name: 'snap_user_location_to_route') bool snapUserLocationToRoute,
  });
}

/// @nodoc
class _$NavigationConfigCopyWithImpl<$Res, $Val extends NavigationConfig>
    implements $NavigationConfigCopyWith<$Res> {
  _$NavigationConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NavigationConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviationThresholdM = null,
    Object? deviationDurationThresholdMs = null,
    Object? snapUserLocationToRoute = null,
  }) {
    return _then(
      _value.copyWith(
            deviationThresholdM: null == deviationThresholdM
                ? _value.deviationThresholdM
                : deviationThresholdM // ignore: cast_nullable_to_non_nullable
                      as double,
            deviationDurationThresholdMs: null == deviationDurationThresholdMs
                ? _value.deviationDurationThresholdMs
                : deviationDurationThresholdMs // ignore: cast_nullable_to_non_nullable
                      as int,
            snapUserLocationToRoute: null == snapUserLocationToRoute
                ? _value.snapUserLocationToRoute
                : snapUserLocationToRoute // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NavigationConfigImplCopyWith<$Res>
    implements $NavigationConfigCopyWith<$Res> {
  factory _$$NavigationConfigImplCopyWith(
    _$NavigationConfigImpl value,
    $Res Function(_$NavigationConfigImpl) then,
  ) = __$$NavigationConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'deviation_threshold_m') double deviationThresholdM,
    @JsonKey(name: 'deviation_duration_threshold_ms')
    int deviationDurationThresholdMs,
    @JsonKey(name: 'snap_user_location_to_route') bool snapUserLocationToRoute,
  });
}

/// @nodoc
class __$$NavigationConfigImplCopyWithImpl<$Res>
    extends _$NavigationConfigCopyWithImpl<$Res, _$NavigationConfigImpl>
    implements _$$NavigationConfigImplCopyWith<$Res> {
  __$$NavigationConfigImplCopyWithImpl(
    _$NavigationConfigImpl _value,
    $Res Function(_$NavigationConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NavigationConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviationThresholdM = null,
    Object? deviationDurationThresholdMs = null,
    Object? snapUserLocationToRoute = null,
  }) {
    return _then(
      _$NavigationConfigImpl(
        deviationThresholdM: null == deviationThresholdM
            ? _value.deviationThresholdM
            : deviationThresholdM // ignore: cast_nullable_to_non_nullable
                  as double,
        deviationDurationThresholdMs: null == deviationDurationThresholdMs
            ? _value.deviationDurationThresholdMs
            : deviationDurationThresholdMs // ignore: cast_nullable_to_non_nullable
                  as int,
        snapUserLocationToRoute: null == snapUserLocationToRoute
            ? _value.snapUserLocationToRoute
            : snapUserLocationToRoute // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NavigationConfigImpl implements _NavigationConfig {
  const _$NavigationConfigImpl({
    @JsonKey(name: 'deviation_threshold_m') this.deviationThresholdM = 50.0,
    @JsonKey(name: 'deviation_duration_threshold_ms')
    this.deviationDurationThresholdMs = 10000,
    @JsonKey(name: 'snap_user_location_to_route')
    this.snapUserLocationToRoute = true,
  });

  factory _$NavigationConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$NavigationConfigImplFromJson(json);

  @override
  @JsonKey(name: 'deviation_threshold_m')
  final double deviationThresholdM;
  @override
  @JsonKey(name: 'deviation_duration_threshold_ms')
  final int deviationDurationThresholdMs;
  @override
  @JsonKey(name: 'snap_user_location_to_route')
  final bool snapUserLocationToRoute;

  @override
  String toString() {
    return 'NavigationConfig(deviationThresholdM: $deviationThresholdM, deviationDurationThresholdMs: $deviationDurationThresholdMs, snapUserLocationToRoute: $snapUserLocationToRoute)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NavigationConfigImpl &&
            (identical(other.deviationThresholdM, deviationThresholdM) ||
                other.deviationThresholdM == deviationThresholdM) &&
            (identical(
                  other.deviationDurationThresholdMs,
                  deviationDurationThresholdMs,
                ) ||
                other.deviationDurationThresholdMs ==
                    deviationDurationThresholdMs) &&
            (identical(
                  other.snapUserLocationToRoute,
                  snapUserLocationToRoute,
                ) ||
                other.snapUserLocationToRoute == snapUserLocationToRoute));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    deviationThresholdM,
    deviationDurationThresholdMs,
    snapUserLocationToRoute,
  );

  /// Create a copy of NavigationConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NavigationConfigImplCopyWith<_$NavigationConfigImpl> get copyWith =>
      __$$NavigationConfigImplCopyWithImpl<_$NavigationConfigImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NavigationConfigImplToJson(this);
  }
}

abstract class _NavigationConfig implements NavigationConfig {
  const factory _NavigationConfig({
    @JsonKey(name: 'deviation_threshold_m') final double deviationThresholdM,
    @JsonKey(name: 'deviation_duration_threshold_ms')
    final int deviationDurationThresholdMs,
    @JsonKey(name: 'snap_user_location_to_route')
    final bool snapUserLocationToRoute,
  }) = _$NavigationConfigImpl;

  factory _NavigationConfig.fromJson(Map<String, dynamic> json) =
      _$NavigationConfigImpl.fromJson;

  @override
  @JsonKey(name: 'deviation_threshold_m')
  double get deviationThresholdM;
  @override
  @JsonKey(name: 'deviation_duration_threshold_ms')
  int get deviationDurationThresholdMs;
  @override
  @JsonKey(name: 'snap_user_location_to_route')
  bool get snapUserLocationToRoute;

  /// Create a copy of NavigationConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NavigationConfigImplCopyWith<_$NavigationConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
