import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current map bearing in degrees (0 = north). Updated from onCameraIdle
/// in MapScreen so the inline compass FAB can show/hide without prop
/// drilling through the sheet widgets.
final mapBearingProvider = StateProvider<double>((ref) => 0);
