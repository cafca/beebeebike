// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'spoken_instruction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SpokenInstruction _$SpokenInstructionFromJson(Map<String, dynamic> json) {
  return _SpokenInstruction.fromJson(json);
}

/// @nodoc
mixin _$SpokenInstruction {
  String get uuid => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  String? get ssml => throw _privateConstructorUsedError;
  @JsonKey(name: 'trigger_distance_m')
  double get triggerDistanceM => throw _privateConstructorUsedError;
  @JsonKey(name: 'emitted_at_ms')
  int get emittedAtMs => throw _privateConstructorUsedError;

  /// Serializes this SpokenInstruction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SpokenInstruction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SpokenInstructionCopyWith<SpokenInstruction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpokenInstructionCopyWith<$Res> {
  factory $SpokenInstructionCopyWith(
    SpokenInstruction value,
    $Res Function(SpokenInstruction) then,
  ) = _$SpokenInstructionCopyWithImpl<$Res, SpokenInstruction>;
  @useResult
  $Res call({
    String uuid,
    String text,
    String? ssml,
    @JsonKey(name: 'trigger_distance_m') double triggerDistanceM,
    @JsonKey(name: 'emitted_at_ms') int emittedAtMs,
  });
}

/// @nodoc
class _$SpokenInstructionCopyWithImpl<$Res, $Val extends SpokenInstruction>
    implements $SpokenInstructionCopyWith<$Res> {
  _$SpokenInstructionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SpokenInstruction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uuid = null,
    Object? text = null,
    Object? ssml = freezed,
    Object? triggerDistanceM = null,
    Object? emittedAtMs = null,
  }) {
    return _then(
      _value.copyWith(
            uuid: null == uuid
                ? _value.uuid
                : uuid // ignore: cast_nullable_to_non_nullable
                      as String,
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            ssml: freezed == ssml
                ? _value.ssml
                : ssml // ignore: cast_nullable_to_non_nullable
                      as String?,
            triggerDistanceM: null == triggerDistanceM
                ? _value.triggerDistanceM
                : triggerDistanceM // ignore: cast_nullable_to_non_nullable
                      as double,
            emittedAtMs: null == emittedAtMs
                ? _value.emittedAtMs
                : emittedAtMs // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SpokenInstructionImplCopyWith<$Res>
    implements $SpokenInstructionCopyWith<$Res> {
  factory _$$SpokenInstructionImplCopyWith(
    _$SpokenInstructionImpl value,
    $Res Function(_$SpokenInstructionImpl) then,
  ) = __$$SpokenInstructionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String uuid,
    String text,
    String? ssml,
    @JsonKey(name: 'trigger_distance_m') double triggerDistanceM,
    @JsonKey(name: 'emitted_at_ms') int emittedAtMs,
  });
}

/// @nodoc
class __$$SpokenInstructionImplCopyWithImpl<$Res>
    extends _$SpokenInstructionCopyWithImpl<$Res, _$SpokenInstructionImpl>
    implements _$$SpokenInstructionImplCopyWith<$Res> {
  __$$SpokenInstructionImplCopyWithImpl(
    _$SpokenInstructionImpl _value,
    $Res Function(_$SpokenInstructionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SpokenInstruction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uuid = null,
    Object? text = null,
    Object? ssml = freezed,
    Object? triggerDistanceM = null,
    Object? emittedAtMs = null,
  }) {
    return _then(
      _$SpokenInstructionImpl(
        uuid: null == uuid
            ? _value.uuid
            : uuid // ignore: cast_nullable_to_non_nullable
                  as String,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        ssml: freezed == ssml
            ? _value.ssml
            : ssml // ignore: cast_nullable_to_non_nullable
                  as String?,
        triggerDistanceM: null == triggerDistanceM
            ? _value.triggerDistanceM
            : triggerDistanceM // ignore: cast_nullable_to_non_nullable
                  as double,
        emittedAtMs: null == emittedAtMs
            ? _value.emittedAtMs
            : emittedAtMs // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SpokenInstructionImpl implements _SpokenInstruction {
  const _$SpokenInstructionImpl({
    required this.uuid,
    required this.text,
    this.ssml,
    @JsonKey(name: 'trigger_distance_m') required this.triggerDistanceM,
    @JsonKey(name: 'emitted_at_ms') required this.emittedAtMs,
  });

  factory _$SpokenInstructionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SpokenInstructionImplFromJson(json);

  @override
  final String uuid;
  @override
  final String text;
  @override
  final String? ssml;
  @override
  @JsonKey(name: 'trigger_distance_m')
  final double triggerDistanceM;
  @override
  @JsonKey(name: 'emitted_at_ms')
  final int emittedAtMs;

  @override
  String toString() {
    return 'SpokenInstruction(uuid: $uuid, text: $text, ssml: $ssml, triggerDistanceM: $triggerDistanceM, emittedAtMs: $emittedAtMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SpokenInstructionImpl &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.ssml, ssml) || other.ssml == ssml) &&
            (identical(other.triggerDistanceM, triggerDistanceM) ||
                other.triggerDistanceM == triggerDistanceM) &&
            (identical(other.emittedAtMs, emittedAtMs) ||
                other.emittedAtMs == emittedAtMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, uuid, text, ssml, triggerDistanceM, emittedAtMs);

  /// Create a copy of SpokenInstruction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SpokenInstructionImplCopyWith<_$SpokenInstructionImpl> get copyWith =>
      __$$SpokenInstructionImplCopyWithImpl<_$SpokenInstructionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SpokenInstructionImplToJson(this);
  }
}

abstract class _SpokenInstruction implements SpokenInstruction {
  const factory _SpokenInstruction({
    required final String uuid,
    required final String text,
    final String? ssml,
    @JsonKey(name: 'trigger_distance_m') required final double triggerDistanceM,
    @JsonKey(name: 'emitted_at_ms') required final int emittedAtMs,
  }) = _$SpokenInstructionImpl;

  factory _SpokenInstruction.fromJson(Map<String, dynamic> json) =
      _$SpokenInstructionImpl.fromJson;

  @override
  String get uuid;
  @override
  String get text;
  @override
  String? get ssml;
  @override
  @JsonKey(name: 'trigger_distance_m')
  double get triggerDistanceM;
  @override
  @JsonKey(name: 'emitted_at_ms')
  int get emittedAtMs;

  /// Create a copy of SpokenInstruction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SpokenInstructionImplCopyWith<_$SpokenInstructionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
