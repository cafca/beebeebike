// ignore_for_file: invalid_annotation_target, freezed/json_serializable produce annotations on getters that this rule otherwise flags.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    @JsonKey(name: 'account_type') required String accountType, String? email,
    @Default('') @JsonKey(name: 'display_name') String displayName,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
