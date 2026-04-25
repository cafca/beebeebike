import 'package:beebeebike/models/user.dart';
import 'package:dio/dio.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<User> anonymous() async =>
      User.fromJson((await _dio.post<dynamic>('/api/auth/anonymous')).data as Map<String, dynamic>);

  Future<User> me() async =>
      User.fromJson((await _dio.get<dynamic>('/api/auth/me')).data as Map<String, dynamic>);

  Future<User> login(String email, String password) async => User.fromJson(
        (await _dio.post<dynamic>('/api/auth/login', data: <String, dynamic>{
          'email': email,
          'password': password,
        }))
            .data as Map<String, dynamic>,
      );

  Future<User> register(String email, String password, String? displayName) async =>
      User.fromJson(
        (await _dio.post<dynamic>('/api/auth/register', data: <String, dynamic>{
          'email': email,
          'password': password,
          'display_name': displayName,
        }))
            .data as Map<String, dynamic>,
      );

  Future<void> logout() async {
    await _dio.post<dynamic>('/api/auth/logout');
  }

  Future<void> deleteAccount() async {
    await _dio.delete<dynamic>('/api/auth/account');
  }
}
