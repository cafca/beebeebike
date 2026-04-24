// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'paint_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PaintResponse _$PaintResponseFromJson(Map<String, dynamic> json) {
  return _PaintResponse.fromJson(json);
}

/// @nodoc
mixin _$PaintResponse {
  @JsonKey(name: 'created_id')
  int? get createdId => throw _privateConstructorUsedError;
  @JsonKey(name: 'clipped_count')
  int get clippedCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'deleted_count')
  int get deletedCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'can_undo')
  bool get canUndo => throw _privateConstructorUsedError;
  @JsonKey(name: 'can_redo')
  bool get canRedo => throw _privateConstructorUsedError;

  /// Serializes this PaintResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaintResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaintResponseCopyWith<PaintResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaintResponseCopyWith<$Res> {
  factory $PaintResponseCopyWith(
          PaintResponse value, $Res Function(PaintResponse) then) =
      _$PaintResponseCopyWithImpl<$Res, PaintResponse>;
  @useResult
  $Res call(
      {@JsonKey(name: 'created_id') int? createdId,
      @JsonKey(name: 'clipped_count') int clippedCount,
      @JsonKey(name: 'deleted_count') int deletedCount,
      @JsonKey(name: 'can_undo') bool canUndo,
      @JsonKey(name: 'can_redo') bool canRedo});
}

/// @nodoc
class _$PaintResponseCopyWithImpl<$Res, $Val extends PaintResponse>
    implements $PaintResponseCopyWith<$Res> {
  _$PaintResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaintResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdId = freezed,
    Object? clippedCount = null,
    Object? deletedCount = null,
    Object? canUndo = null,
    Object? canRedo = null,
  }) {
    return _then(_value.copyWith(
      createdId: freezed == createdId
          ? _value.createdId
          : createdId // ignore: cast_nullable_to_non_nullable
              as int?,
      clippedCount: null == clippedCount
          ? _value.clippedCount
          : clippedCount // ignore: cast_nullable_to_non_nullable
              as int,
      deletedCount: null == deletedCount
          ? _value.deletedCount
          : deletedCount // ignore: cast_nullable_to_non_nullable
              as int,
      canUndo: null == canUndo
          ? _value.canUndo
          : canUndo // ignore: cast_nullable_to_non_nullable
              as bool,
      canRedo: null == canRedo
          ? _value.canRedo
          : canRedo // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaintResponseImplCopyWith<$Res>
    implements $PaintResponseCopyWith<$Res> {
  factory _$$PaintResponseImplCopyWith(
          _$PaintResponseImpl value, $Res Function(_$PaintResponseImpl) then) =
      __$$PaintResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'created_id') int? createdId,
      @JsonKey(name: 'clipped_count') int clippedCount,
      @JsonKey(name: 'deleted_count') int deletedCount,
      @JsonKey(name: 'can_undo') bool canUndo,
      @JsonKey(name: 'can_redo') bool canRedo});
}

/// @nodoc
class __$$PaintResponseImplCopyWithImpl<$Res>
    extends _$PaintResponseCopyWithImpl<$Res, _$PaintResponseImpl>
    implements _$$PaintResponseImplCopyWith<$Res> {
  __$$PaintResponseImplCopyWithImpl(
      _$PaintResponseImpl _value, $Res Function(_$PaintResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaintResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdId = freezed,
    Object? clippedCount = null,
    Object? deletedCount = null,
    Object? canUndo = null,
    Object? canRedo = null,
  }) {
    return _then(_$PaintResponseImpl(
      createdId: freezed == createdId
          ? _value.createdId
          : createdId // ignore: cast_nullable_to_non_nullable
              as int?,
      clippedCount: null == clippedCount
          ? _value.clippedCount
          : clippedCount // ignore: cast_nullable_to_non_nullable
              as int,
      deletedCount: null == deletedCount
          ? _value.deletedCount
          : deletedCount // ignore: cast_nullable_to_non_nullable
              as int,
      canUndo: null == canUndo
          ? _value.canUndo
          : canUndo // ignore: cast_nullable_to_non_nullable
              as bool,
      canRedo: null == canRedo
          ? _value.canRedo
          : canRedo // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaintResponseImpl implements _PaintResponse {
  const _$PaintResponseImpl(
      {@JsonKey(name: 'created_id') this.createdId,
      @JsonKey(name: 'clipped_count') this.clippedCount = 0,
      @JsonKey(name: 'deleted_count') this.deletedCount = 0,
      @JsonKey(name: 'can_undo') this.canUndo = false,
      @JsonKey(name: 'can_redo') this.canRedo = false});

  factory _$PaintResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaintResponseImplFromJson(json);

  @override
  @JsonKey(name: 'created_id')
  final int? createdId;
  @override
  @JsonKey(name: 'clipped_count')
  final int clippedCount;
  @override
  @JsonKey(name: 'deleted_count')
  final int deletedCount;
  @override
  @JsonKey(name: 'can_undo')
  final bool canUndo;
  @override
  @JsonKey(name: 'can_redo')
  final bool canRedo;

  @override
  String toString() {
    return 'PaintResponse(createdId: $createdId, clippedCount: $clippedCount, deletedCount: $deletedCount, canUndo: $canUndo, canRedo: $canRedo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaintResponseImpl &&
            (identical(other.createdId, createdId) ||
                other.createdId == createdId) &&
            (identical(other.clippedCount, clippedCount) ||
                other.clippedCount == clippedCount) &&
            (identical(other.deletedCount, deletedCount) ||
                other.deletedCount == deletedCount) &&
            (identical(other.canUndo, canUndo) || other.canUndo == canUndo) &&
            (identical(other.canRedo, canRedo) || other.canRedo == canRedo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, createdId, clippedCount, deletedCount, canUndo, canRedo);

  /// Create a copy of PaintResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaintResponseImplCopyWith<_$PaintResponseImpl> get copyWith =>
      __$$PaintResponseImplCopyWithImpl<_$PaintResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaintResponseImplToJson(
      this,
    );
  }
}

abstract class _PaintResponse implements PaintResponse {
  const factory _PaintResponse(
      {@JsonKey(name: 'created_id') final int? createdId,
      @JsonKey(name: 'clipped_count') final int clippedCount,
      @JsonKey(name: 'deleted_count') final int deletedCount,
      @JsonKey(name: 'can_undo') final bool canUndo,
      @JsonKey(name: 'can_redo') final bool canRedo}) = _$PaintResponseImpl;

  factory _PaintResponse.fromJson(Map<String, dynamic> json) =
      _$PaintResponseImpl.fromJson;

  @override
  @JsonKey(name: 'created_id')
  int? get createdId;
  @override
  @JsonKey(name: 'clipped_count')
  int get clippedCount;
  @override
  @JsonKey(name: 'deleted_count')
  int get deletedCount;
  @override
  @JsonKey(name: 'can_undo')
  bool get canUndo;
  @override
  @JsonKey(name: 'can_redo')
  bool get canRedo;

  /// Create a copy of PaintResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaintResponseImplCopyWith<_$PaintResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
