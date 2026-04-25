import 'package:ferrostar_flutter/src/models/visual_instruction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VisualInstruction with all fields round-trips', () {
    final json = {
      'primary_text': 'Turn left onto Kastanienallee',
      'secondary_text': 'then continue for 1.2 km',
      'maneuver_type': 'turn',
      'maneuver_modifier': 'left',
      'trigger_distance_m': 200.0,
    };
    final v = VisualInstruction.fromJson(json);
    expect(v.primaryText, 'Turn left onto Kastanienallee');
    expect(v.secondaryText, 'then continue for 1.2 km');
    expect(v.maneuverType, 'turn');
    expect(v.maneuverModifier, 'left');
    expect(v.triggerDistanceM, 200.0);
    expect(v.toJson(), json);
  });

  test('VisualInstruction with null modifier + secondary parses', () {
    final v = VisualInstruction.fromJson({
      'primary_text': 'Continue straight',
      'secondary_text': null,
      'maneuver_type': 'continue',
      'maneuver_modifier': null,
      'trigger_distance_m': 500.0,
    });
    expect(v.secondaryText, isNull);
    expect(v.maneuverModifier, isNull);
  });
}
