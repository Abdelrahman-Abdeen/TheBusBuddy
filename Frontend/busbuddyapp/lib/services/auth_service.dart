import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final String baseUrl;
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthService({this.baseUrl = 'https://fastapi-app-53203255780.me-central1.run.app/'}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  // ------------------- API methods -------------------

  Future<String> parentLogin(String phoneNumber, String password) async {
    try {
      final resp = await _dio.post('/parent/login', data: {
        'phone_number': phoneNumber,
        'password': password,
        'role': 'parent',
      });
      return resp.data['access_token'] as String;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Invalid phone number or password';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw 'Server response timeout. Please try again';
      } else {
        throw 'Login failed. Please try again later';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again';
    }
  }

  Future<String> adminLogin(String phoneNumber, String password) async {
    try {
      final resp = await _dio.post('/admin/login', data: {
        'phone_number': phoneNumber,
        'password': password,
      });
      return resp.data['access_token'] as String;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Invalid phone number or password';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw 'Server response timeout. Please try again';
      } else {
        throw 'Login failed. Please try again later';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again';
    }
  }

  Future<void> storeToken(String token) =>
      _storage.write(key: 'access_token', value: token);

  Future<String?> getToken() => _storage.read(key: 'access_token');

  Future<void> clearToken() => _storage.delete(key: 'access_token');

  Future<void> updateDeviceToken(String userId, String deviceToken) async {
    try {
      final token = await getToken();
      if (token == null) throw 'Not authenticated';

      final response = await _dio.patch(
        '/users/$userId/update_token',
        data: {
          'device_token': deviceToken,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update device token: ${response.data}');
      }
    } catch (e) {
      throw Exception('Error updating device token: $e');
    }
  }

  Future<Map<String, dynamic>> getParentInfo(String parentId) async {
    try {
      final token = await getToken();
      if (token == null) throw 'Not authenticated';

      final response = await _dio.get(
        '/parents/$parentId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      final parentData = response.data as Map<String, dynamic>;

      // Check if device token exists in the response
      if (parentData['device_token'] == null) {
        // Get FCM token
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          // Update device token in backend
          await updateDeviceToken(parentId, fcmToken);
          // Update local data with new device token
          parentData['device_token'] = fcmToken;
        }
      }

      return parentData;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw 'Parent not found';
      } else {
        throw 'Failed to fetch parent information';
      }
    } catch (e) {
      throw 'An unexpected error occurred';
    }
  }

  Future<String?> getUserDeviceToken(String userId) async {
    try {
      final token = await getToken();
      if (token == null) throw 'Not authenticated';

      final response = await _dio.get(
        '/users/$userId/device_token',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      return response.data['device_token'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      } else {
        throw 'Failed to fetch device token';
      }
    } catch (e) {
      throw 'An unexpected error occurred';
    }
  }
}
