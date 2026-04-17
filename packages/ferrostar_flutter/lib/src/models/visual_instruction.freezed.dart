// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'visual_instruction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

VisualInstruction _$VisualInstructionFromJson(Map<String, dynamic> json) {
  return _VisualInstruction.fromJson(json);
}

/// @nodoc
mixin _$VisualInstruction {
  @JsonKey(name: 'primary_text')
  String get primaryText => throw _privateConstructorUsedError;
  @JsonKey(name: 'secondary_text')
  String? get secondaryText => throw _privateConstructorUsedError;
  @JsonKey(name: 'maneuver_type')
  String get maneuverType => throw _privateConstructorUsedError;
  @JsonKey(name: 'maneuver_modifier')
  String? get maneuverModifier => throw _privateConstructorUsedError;
  @JsonKey(name: 'trigger_distance_m')
  double get triggerDistanceM => throw _privateConstructorUsedError;

  /// Serializes this VisualInstruction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VisualInstruction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VisualInstructionCopyWith<VisualInstruction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VisualInstructionCopyWith<$Res> {
  factory $VisualInstructionCopyWith(
    VisualInstruction value,
    $Res Function(VisualInstruction) then,
  ) = _$VisualInstructionCopyWithImpl<$Res, VisualInstruction>;
  @useResult
  $Res call({
    @JsonKey(name: 'primary_text') String primaryText,
    @JsonKey(name: 'secondary_text') String? secondaryText,
    @JsonKey(name: 'maneuver_type') String maneuverType,
    @JsonKey(name: 'maneuver_modifier') String? maneuverModifier,
    @JsonKey(name: 'trigger_distance_m') double triggerDistanceM,
  });
}

/// @nodoc
class _$VisualInstructionCopyWithImpl<$Res, $Val extends VisualInstruction>
    implements $VisualInstructionCopyWith<$Res> {
  _$VisualInstructionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VisualInstruction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? primaryText = null,
    Object? secondaryText = freezed,
    Object? maneuverType = null,
    Object? maneuverModifier = freezed,
    Object? triggerDistanceM = null,
  }) {
    return _then(
      _value.copyWith(
            primaryText: null == primaryText
                ? _value.primaryText
                : primaryText // ignore: cast_nullable_to_non_nullable
                      as String,
            secondaryText: freezed == secondaryText
                ? _value.secondaryText
                : secondaryText // ignore: cast_nullable_to_non_nullable
                      as String?,
            maneuverType: null == maneuverType
                ? _value.maneuverType
                : maneuverType // ignore: cast_nullable_to_non_nullable
                      as String,
            maneuverModifier: freezed == maneuverModifier
                ? _value.maneuverModifier
                : maneuverModifier // ignore: cast_nullable_to_non_nullable
                      as String?,
            triggerDistanceM: null == triggerDistanceM
                ? _value.triggerDistanceM
                : triggerDistanceM // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VisualInstructionImplCopyWith<$Res>
    implements $VisualInstructionCopyWith<$Res> {
  factory _$$VisualInstructionImplCopyWith(
    _$VisualInstructionImpl value,
    $Res Function(_$VisualInstructionImpl) then,
  ) = __$$VisualInstructionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'primary_text') String primaryText,
    @JsonKey(name: 'secondary_text') String? secondaryText,
    @JsonKey(name: 'maneuver_type') String maneuverType,
    @JsonKey(name: 'maneuver_modifier') String? maneuverModifier,
    @JsonKey(name: 'trigger_distance_m') double triggerDistanceM,
  });
}

/// @nodoc
class __$$VisualInstructionImplCopyWithImpl<$Res>
    extends _$VisualInstructionCopyWithImpl<$Res, _$VisualInstructionImpl>
    implements _$$VisualInstructionImplCopyWith<$Res> {
  __$$VisualInstructionImplCopyWithImpl(
    _$VisualInstructionImpl _value,
    $Res Function(_$VisualInstructionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VisualInstruction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? primaryText = null,
    Object? secondaryText = freezed,
    Object? maneuverType = null,
    Object? maneuverModifier = freezed,
    Object? triggerDistanceM = null,
  }) {
    return _then(
      _$VisualInstructionImpl(
        primaryText: null == primaryText
            ? _value.primaryText
            : primaryText // ignore: cast_nullable_to_non_nullable
                  as String,
        secondaryText: freezed == secondaryText
            ? _value.secondaryText
            : secondaryText // ignore: cast_nullable_to_non_nullable
                  as String?,
        maneuverType: null == maneuverType
            ? _value.maneuverType
            : maneuverType // ignore: cast_nullable_to_non_nullable
                  as String,
        maneuverModifier: freezed == maneuverModifier
            ? _value.maneuverModifier
            : maneuverModifier // ignore: cast_nullable_to_non_nullable
                  as String?,
        triggerDistanceM: null == triggerDistanceM
            ? _value.triggerDistanceM
            : triggerDistanceM // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VisualInstructionImpl implements _VisualInstruction {
  const _$VisualInstructionImpl({
    @JsonKey(name: 'primary_text') required this.primaryText,
    @JsonKey(name: 'secondary_text') this.secondaryText,
    @JsonKey(name: 'maneuver_type') required this.maneuverType,
    @JsonKey(name: 'maneuver_modifier') this.maneuverModifier,
    @JsonKey(name: 'trigger_distance_m') required this.triggerDistanceM,
  });

  factory _$VisualInstructionImpl.fromJson(Map<String, dynamic> json) =>
      _$$VisualInstructionImplFromJson(json);

  @override
  @JsonKey(name: 'primary_text')
  final String primaryText;
  @override
  @JsonKey(name: 'secondary_text')
  final String? secondaryText;
  @override
  @JsonKey(name: 'maneuver_type')
  final String maneuverType;
  @override
  @JsonKey(name: 'maneuver_modifier')
  final String? maneuverModifier;
  @override
  @JsonKey(name: 'trigger_distance_m')
  final double triggerDistanceM;

  @override
  String toString() {
    return 'VisualInstruction(primaryText: $primaryText, secondaryText: $secondaryText, maneuverType: $maneuverType, maneuverModifier: $maneuverModifier, triggerDistanceM: $triggerDistanceM)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VisualInstructionImpl &&
            (identical(other.primaryText, primaryText) ||
                other.primaryText == primaryText) &&
            (identical(other.secondaryText, secondaryText) ||
                other.secondaryText == secondaryText) &&
            (identical(other.maneuverType, maneuverType) ||
                other.maneuverType == maneuverType) &&
            (identical(other.maneuverModifier, maneuverModifier) ||
                other.maneuverModifier == maneuverModifier) &&
            (identical(other.triggerDistanceM, triggerDistanceM) ||
                other.triggerDistanceM == triggerDistanceM));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    primaryText,
    secondaryText,
    maneuverType,
    maneuverModifier,
    triggerDistanceM,
  );

  /// Create a copy of VisualInstruction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VisualInstructionImplCopyWith<_$VisualInstructionImpl> get copyWith =>
      __$$VisualInstructionImplCopyWithImpl<_$VisualInstructionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$VisualInstructionImplToJson(this);
  }
}

abstract class _VisualInstruction implements VisualInstruction {
  const factory _VisualInstruction({
    @JsonKey(name: 'primary_text') required final String primaryText,
    @JsonKey(name: 'secondary_text') final String? secondaryText,
    @JsonKey(name: 'maneuver_type') required final String maneuverType,
    @JsonKey(name: 'maneuver_modifier') final String? maneuverModifier,
    @JsonKey(name: 'trigger_distance_m') required final double triggerDistanceM,
  }) = _$VisualInstructionImpl;

  factory _VisualInstruction.fromJson(Map<String, dynamic> json) =
      _$VisualInstructionImpl.fromJson;

  @override
  @JsonKey(name: 'primary_text')
  String get primaryText;
  @override
  @JsonKey(name: 'secondary_text')
  String? get secondaryText;
  @override
  @JsonKey(name: 'maneuver_type')
  String get maneuverType;
  @override
  @JsonKey(name: 'maneuver_modifier')
  String? get maneuverModifier;
  @override
  @JsonKey(name: 'trigger_distance_m')
  double get triggerDistanceM;

  /// Create a copy of VisualInstruction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VisualInstructionImplCopyWith<_$VisualInstructionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
