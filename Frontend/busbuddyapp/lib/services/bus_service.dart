import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_service.dart';

class BusService {
  final String baseUrl;
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AuthService _authService;

  BusService(
      {this.baseUrl = 'https://fastapi-app-53203255780.me-central1.run.app/'})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 3),
          ),
        ),
        _authService = AuthService();

  Future<void> _addAuthHeader() async {
    final token = await _authService.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  /// Get all buses
  Future<List<Map<String, dynamic>>> getAllBuses() async {
    try {
      await _addAuthHeader();

      final resp = await _dio.get('/buses');

      _checkStatus(resp, 'all buses');

      final buses = _normalizeJsonList(resp.data);

      return buses;
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'all buses');
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw 'Not authenticated';
    return token;
  }

  List<Map<String, dynamic>> _normalizeJsonList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) return Map<String, dynamic>.from(item);
        return {'value': item.toString()};
      }).toList();
    }
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return [
      {'value': data.toString()}
    ];
  }

  void _checkStatus(Response resp, String what) {
    if (resp.statusCode == null || resp.statusCode! ~/ 100 != 2) {
      throw 'Failed to fetch $what: ${resp.statusMessage ?? resp.statusCode}';
    }
  }

  String _friendlyDioMessage(DioException e, String what) {
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Check your internet connection.';
    }
    return 'Failed to fetch $what. Please try again later.';
  }

  Future<Map<String, dynamic>> getBusDetails(int busId) async {
    try {
      await _addAuthHeader();
      final response = await _dio.get('/bus/$busId');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Unauthorized access. Please login again';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else {
        throw 'Failed to fetch bus details. Please try again later';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again';
    }
  }

  Future<List<dynamic>> getStudentsInBus(int busId) async {
    try {
      await _addAuthHeader();
      final response = await _dio.get('/bus/$busId/currently-in-bus-students');
      if (response.data == null || response.data is! List) {
        return [];
      }
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Unauthorized access. Please login again';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else if (e.response?.statusCode == 404) {
        return [];
      } else {
        throw 'Failed to fetch students. Please try again later';
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getBusLocation(int busId) async {
    try {
      await _addAuthHeader();
      final response = await _dio.get('/bus/$busId/location');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Unauthorized access. Please login again';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else {
        throw 'Failed to fetch bus location. Please try again later';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again';
    }
  }

  Future<void> startTracking(int busId) async {
    try {
      await _addAuthHeader();
      await _dio.post('/bus/$busId/start-tracking');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Unauthorized access. Please login again';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else {
        throw 'Failed to start tracking. Please try again later';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again';
    }
  }

  Future<void> stopTracking(int busId) async {
    try {
      await _addAuthHeader();
      await _dio.post('/bus/$busId/stop-tracking');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Unauthorized access. Please login again';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else {
        throw 'Failed to stop tracking. Please try again later';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again';
    }
  }

  Future<void> updateBusMonitoring(int busId, bool isEnabled) async {
    try {
      await _addAuthHeader();
      await _dio.patch(
        '/bus/$busId',
        data: {'is_monitoring_enabled': isEnabled},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Unauthorized access. Please login again';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else {
        throw 'Failed to update monitoring status. Please try again later';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again';
    }
  }

  Future<List<dynamic>> getBusStudents(int busId) async {
    try {
      await _addAuthHeader();
      final response = await _dio.get('/bus/$busId/students');
      if (response.data == null || response.data is! List) {
        return [];
      }
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Unauthorized access. Please login again';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else if (e.response?.statusCode == 404) {
        return [];
      } else {
        throw 'Failed to fetch bus students. Please try again later';
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getBusEvents(int busId) async {
    try {
      await _addAuthHeader();
      final response = await _dio.get('/bus/$busId/events');
      if (response.data == null || response.data is! List) {
        return [];
      }
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Unauthorized access. Please login again';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout. Please check your internet connection';
      } else if (e.response?.statusCode == 404) {
        return [];
      } else {
        throw 'Failed to fetch bus events. Please try again later';
      }
    } catch (e) {
      return [];
    }
  }

  void dispose() => _dio.close();
}
