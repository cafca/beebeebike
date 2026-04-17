import 'package:dio/dio.dart';

import '../models/user.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<User> anonymous() async =>
      User.fromJson((await _dio.post('/api/auth/anonymous')).data as Map<String, dynamic>);

  Future<User> me() async =>
      User.fromJson((await _dio.get('/api/auth/me')).data as Map<String, dynamic>);

  Future<User> login(String email, String password) async => User.fromJson(
        (await _dio.post('/api/auth/login', data: {
          'email': email,
          'password': password,
        }))
            .data as Map<String, dynamic>,
      );

  Future<User> register(String email, String password, String? displayName) async =>
      User.fromJson(
        (await _dio.post('/api/auth/register', data: {
          'email': email,
          'password': password,
          'display_name': displayName,
        }))
            .data as Map<String, dynamic>,
      );

  Future<void> logout() async {
    await _dio.post('/api/auth/logout');
  }
}
