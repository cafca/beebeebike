import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/api/locations_api.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationsApiProvider = Provider<LocationsApi>(
  (ref) => LocationsApi(ref.watch(dioProvider)),
);

final homeLocationProvider =
    AsyncNotifierProvider<HomeLocationController, Location?>(HomeLocationController.new);

class HomeLocationController extends AsyncNotifier<Location?> {
  @override
  Future<Location?> build() async {
    final auth = ref.watch(authControllerProvider);
    final user = auth.valueOrNull;
    if (user == null || user.accountType == 'anonymous') return null;
    return ref.read(locationsApiProvider).getHome();
  }

  Future<void> save(Location location) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(locationsApiProvider).setHome(location));
  }

  Future<void> clear() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(locationsApiProvider).deleteHome();
      return null;
    });
  }
}
