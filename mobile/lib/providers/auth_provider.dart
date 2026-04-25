import 'package:beebeebike/api/auth_api.dart';
import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));

final authControllerProvider =
    AsyncNotifierProvider<AuthController, User?>(AuthController.new);

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final api = ref.read(authApiProvider);
    try {
      return await api.me();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        return api.anonymous();
      }
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authApiProvider).login(email, password));
  }

  Future<void> register(String email, String password, String? displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authApiProvider).register(email, password, displayName),
    );
  }

  Future<void> logout() async {
    await ref.read(authApiProvider).logout();
    state = await AsyncValue.guard(() => ref.read(authApiProvider).anonymous());
  }

  Future<void> deleteAccount() async {
    await ref.read(authApiProvider).deleteAccount();
    state = await AsyncValue.guard(() => ref.read(authApiProvider).anonymous());
  }
}
