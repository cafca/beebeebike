import 'package:freezed_annotation/freezed_annotation.dart';

part 'spoken_instruction.freezed.dart';
part 'spoken_instruction.g.dart';

@freezed
class SpokenInstruction with _$SpokenInstruction {
  const factory SpokenInstruction({
    required String uuid,
    required String text,
    String? ssml,
    @JsonKey(name: 'trigger_distance_m') required double triggerDistanceM,
    @JsonKey(name: 'emitted_at_ms') required int emittedAtMs,
  }) = _SpokenInstruction;

  factory SpokenInstruction.fromJson(Map<String, dynamic> json) =>
      _$SpokenInstructionFromJson(json);
}
