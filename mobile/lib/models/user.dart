// ignore_for_file: invalid_annotation_target, freezed/json_serializable produce annotations on getters that this rule otherwise flags.
import 'package:beebeebike/config/berlin_bounds.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

class _BboxConverter implements JsonConverter<Bbox?, Map<String, dynamic>?> {
  const _BboxConverter();

  @override
  Bbox? fromJson(Map<String, dynamic>? json) =>
      json == null ? null : Bbox.fromJson(json);

  @override
  Map<String, dynamic>? toJson(Bbox? bbox) => bbox?.toJson();
}

@freezed
class User with _$User {
  const factory User({
    required String id,
    @JsonKey(name: 'account_type') required String accountType,
    String? email,
    @Default('') @JsonKey(name: 'display_name') String displayName,
    @_BboxConverter() Bbox? bbox,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
