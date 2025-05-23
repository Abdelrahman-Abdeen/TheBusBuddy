import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'auth_service.dart';

class NotificationService {
  final String baseUrl;
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const int maxRetries = 3;
  static const Duration timeout = Duration(seconds: 10);
  final AuthService _authService;

  NotificationService({
    this.baseUrl = 'https://fastapi-app-53203255780.me-central1.run.app/',
  })  : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://fastapi-app-53203255780.me-central1.run.app/',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            connectTimeout: timeout,
            receiveTimeout: timeout,
          ),
        ),
        _authService = AuthService();

  Future<void> _addAuthHeader() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<int> _getAdminIdFromToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw 'No token found';
    }

    try {
      final decodedToken = JwtDecoder.decode(token);
      final adminId = decodedToken['sub'];
      if (adminId == null) {
        throw 'No admin ID found in token';
      }
      return int.parse(adminId.toString());
    } catch (e) {
      throw 'Invalid token format';
    }
  }

  Future<T> _retryRequest<T>(Future<T> Function() request) async {
    int attempts = 0;
    while (true) {
      try {
        return await request();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: attempts));
      }
    }
  }

  /// Fetch notifications for the current admin
  Future<List<Map<String, dynamic>>> getNotifications() async {
    await _addAuthHeader();
    try {
      final adminId = await _getAdminIdFromToken();
      return await _retryRequest(() async {
        final response = await _dio.get('/$adminId/notifications');
        if (response.statusCode == 200 && response.data is List) {
          return (response.data as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        return [];
      });
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else if (e.response?.statusCode == 401) {
        throw 'Unauthorized access. Please login again';
      } else if (e.response?.statusCode == 404) {
        return [];
      } else {
        throw 'Failed to fetch notifications. Please try again later';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again';
    }
  }

  Future<Map<String, dynamic>> getEventDetails(int eventId) async {
    await _addAuthHeader();
    return await _retryRequest(() async {
      final resp = await _dio.get('/event/$eventId');
      return Map<String, dynamic>.from(resp.data as Map);
    });
  }

  Future<Map<String, dynamic>> getStudentDetails(int studentId) async {
    await _addAuthHeader();
    return await _retryRequest(() async {
      final resp = await _dio.get('/student/$studentId');
      return Map<String, dynamic>.from(resp.data as Map);
    });
  }

  Future<void> createNotification({
    required String title,
    required String message,
    required List<int> recipientIds,
  }) async {
    try {
      if (title.isEmpty || message.isEmpty || recipientIds.isEmpty) {
        throw 'Please fill all required fields';
      }

      final token = await _requireToken();
      final adminId = await _getAdminIdFromToken();

      final response = await _dio.post(
        '/$adminId/notifications/create',
        data: {
          'title': title,
          'message': message,
          'recipient_ids': recipientIds,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          followRedirects: false, // Block auto-following
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      if (response.statusCode == 307) {
        final redirectUrl = response.headers['location']?.first;
        if (redirectUrl != null) {
          final redirectedResponse = await _dio.post(
            redirectUrl,
            data: {
              'title': title,
              'message': message,
              'recipient_ids': recipientIds,
            },
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              followRedirects: true,
              validateStatus: (status) => status != null && status < 400,
            ),
          );

          if (redirectedResponse.statusCode != 200) {
            throw 'Failed to create notification: ${redirectedResponse.statusMessage}';
          }

          final responseData = redirectedResponse.data;
          if (responseData == null || responseData['status'] != 'success') {
            throw 'Failed to create notification: Invalid response';
          }
          return;
        } else {
          throw 'Redirect location not provided by the server';
        }
      }

      if (response.statusCode != 200) {
        throw 'Failed to create notification: ${response.statusMessage}';
      }

      final responseData = response.data;
      if (responseData == null || responseData['status'] != 'success') {
        throw 'Failed to create notification: Invalid response from server';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData['detail'] != null) {
          throw errorData['detail'];
        }
      }
      throw _friendlyDioMessage(e, 'create notification');
    } catch (e) {
      throw 'Failed to create notification: $e';
    }
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw 'Not authenticated';
    return token;
  }

  String _friendlyDioMessage(DioException e, String what) {
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Check your internet connection.';
    }
    return 'Failed to $what. Please try again later.';
  }
  
  Future<void> deleteNotification(int notificationId) async {
    await _addAuthHeader();
    final adminId = await _getAdminIdFromToken();
    
    return await _retryRequest(() async {
      try {
        final response = await _dio.delete('/$adminId/notifications/$notificationId');

        if (response.statusCode == 200) {
          return;
        } else if (response.statusCode == 404) {
          throw 'Notification not found';
        } else if (response.statusCode == 401) {
          throw 'Unauthorized access. Please login again';
        } else {
          throw 'Failed to delete notification: ${response.statusMessage}';
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionTimeout) {
          throw 'Connection timeout. Please check your internet connection';
        } else if (e.response?.statusCode == 401) {
          throw 'Unauthorized access. Please login again';
        } else if (e.response?.statusCode == 404) {
          throw 'Notification not found';
        } else {
          throw _friendlyDioMessage(e, 'delete notification');
        }
      } catch (e) {
        throw 'Failed to delete notification: $e';
      }
    });
  }

  void dispose() => _dio.close();
}
