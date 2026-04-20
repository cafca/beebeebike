import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';

/// Override this in main() with getApplicationSupportDirectory().path.
final cookieStoragePathProvider = Provider<String>(
  (_) => throw UnimplementedError('cookieStoragePathProvider not overridden'),
);

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final cookiePath = ref.watch(cookieStoragePathProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      headers: const {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(
    CookieManager(PersistCookieJar(storage: FileStorage('$cookiePath/.cookies/'))),
  );
  return dio;
});
