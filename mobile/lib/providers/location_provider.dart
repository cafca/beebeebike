import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/locations_api.dart';
import '../models/location.dart';

final locationsApiProvider = Provider<LocationsApi>(
  (ref) => LocationsApi(ref.watch(dioProvider)),
);

final homeLocationProvider =
    AsyncNotifierProvider<HomeLocationController, Location?>(HomeLocationController.new);

class HomeLocationController extends AsyncNotifier<Location?> {
  @override
  Future<Location?> build() => ref.read(locationsApiProvider).getHome();

  Future<void> save(Location location) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(locationsApiProvider).setHome(location));
  }

  Future<void> clear() async {
    await ref.read(locationsApiProvider).deleteHome();
    state = const AsyncData(null);
  }
}
