import 'package:freezed_annotation/freezed_annotation.dart';

part 'spoken_instruction.freezed.dart';
part 'spoken_instruction.g.dart';

/// A single voice prompt that has crossed its trigger distance and should be
/// spoken to the user (typically via a TTS engine).
@freezed
class SpokenInstruction with _$SpokenInstruction {
  /// Creates a [SpokenInstruction].
  const factory SpokenInstruction({
    /// Stable identifier for this instruction, used to deduplicate replays.
    required String uuid,

    /// Plain-text utterance to speak.
    required String text,

    /// Distance to the maneuver, in meters, at which this instruction was
    /// scheduled to be emitted.
    @JsonKey(name: 'trigger_distance_m') required double triggerDistanceM,

    /// Wall-clock time the native side emitted this instruction
    /// (milliseconds since epoch).
    @JsonKey(name: 'emitted_at_ms') required int emittedAtMs,

    /// Optional SSML form of [text], for engines that support markup.
    String? ssml,
  }) = _SpokenInstruction;

  /// Decodes a spoken instruction from its JSON representation.
  factory SpokenInstruction.fromJson(Map<String, dynamic> json) =>
      _$SpokenInstructionFromJson(json);
}
