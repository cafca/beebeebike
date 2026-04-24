// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'paint_response.freezed.dart';
part 'paint_response.g.dart';

@freezed
class PaintResponse with _$PaintResponse {
  const factory PaintResponse({
    @JsonKey(name: 'created_id') int? createdId,
    @JsonKey(name: 'clipped_count') @Default(0) int clippedCount,
    @JsonKey(name: 'deleted_count') @Default(0) int deletedCount,
    @JsonKey(name: 'can_undo') @Default(false) bool canUndo,
    @JsonKey(name: 'can_redo') @Default(false) bool canRedo,
  }) = _PaintResponse;

  factory PaintResponse.fromJson(Map<String, dynamic> json) =>
      _$PaintResponseFromJson(json);
}
