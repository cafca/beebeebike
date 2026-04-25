// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import '../config/berlin_bounds.dart';

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
    String? email,
    @Default('') @JsonKey(name: 'display_name') String displayName,
    @JsonKey(name: 'account_type') required String accountType,
    @_BboxConverter() Bbox? bbox,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
