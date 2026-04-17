import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/route_provider.dart';
import '../screens/navigation_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/route_summary.dart';
import '../widgets/search_bar.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFDCE9DD)),
          BeeBeeBikeSearchBar(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
            onAvatarTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Consumer(
              builder: (context, ref, _) {
                final routeState = ref.watch(routeControllerProvider);
                final preview = routeState.preview;

                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: preview == null
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: SizedBox(width: 36, child: Divider(thickness: 4))),
                            SizedBox(height: 12),
                            Text('Home'),
                            Text('Saved places'),
                          ],
                        )
                      : RouteSummary(
                          durationMinutes: (preview.time / 60).round(),
                          distanceKm: preview.distance / 1000,
                          onStart: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NavigationScreen(),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
