import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';

/// Tiny inline OSM attribution. Sits under the primary CTA on each sheet
/// so OSM's attribution requirement is always visible without any floating
/// chrome. Tap launches the copyright page. OSM's guidance is to keep the
/// string in English across locales, so it is hardcoded.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.manrope(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: BbbColors.inkFaint,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            const TextSpan(text: 'Map data '),
            TextSpan(
              text: '© OpenStreetMap contributors',
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
            ),
          ],
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}
