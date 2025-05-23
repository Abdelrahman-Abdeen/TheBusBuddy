import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'auth_service.dart';
import 'student_service.dart';

class ParentService {
  final Dio _dio;
  final AuthService _authService;
  final StudentService _studentService;

  ParentService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://fastapi-app-53203255780.me-central1.run.app/',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 3),
          ),
        ),
        _authService = AuthService(),
        _studentService = StudentService();

  /* ─────────────────────── Students ─────────────────────── */

  Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      final token = await _requireToken();
      final parentId = _getParentIdFromToken(token);

      // First get student IDs from parent endpoint
      final resp = await _dio.get(
        '/parent/$parentId/students',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      _checkStatus(resp, 'student IDs');
      // Extract student IDs from response
      final studentIds = _extractStudentIds(resp.data);

      if (studentIds.isEmpty) {
        return [];
      }

      // Get complete student details using StudentService
      final students = await _studentService.getStudentsDetails(studentIds);

      return students;
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'students');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStudentDetails(int studentId) async {
    try {
      final token = await _requireToken();
      final resp = await _dio.get(
        '/student/$studentId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      _checkStatus(resp, 'student details');
      return _normalizeJsonList(resp.data).first;
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'student details');
    }
  }

  Future<List<Map<String, dynamic>>> getStudentEvents(int studentId) async {
    try {
      final token = await _requireToken();
      final resp = await _dio.get(
        '/student/$studentId/events',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      _checkStatus(resp, 'student events');
      return _normalizeJsonList(resp.data);
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'student events');
    }
  }

  Future<Map<String, dynamic>> getBusDetails(int busId) async {
    try {
      final token = await _requireToken();
      final resp = await _dio.get(
        '/bus/$busId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      _checkStatus(resp, 'bus details');
      return _normalizeJsonList(resp.data).first;
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'bus details');
    }
  }

  Future<String> getStudentETA(int studentId) async {
    try {
      final token = await _requireToken();
      print('Making ETA request for student: $studentId');

      final resp = await _dio.get(
        '/student/$studentId/eta',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (resp.statusCode == null || resp.statusCode! ~/ 100 != 2) {
        return 'Unknown';
      }

      // Handle different response types
      if (resp.data == null) {
        return 'Unknown';
      }

      if (resp.data is num) {
        print('Response is a number: ${resp.data}');
        return resp.data.toString();
      }
      return 'Unknown';
    } on DioException catch (e) {
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<List<Map<String, dynamic>>> getStudentsInBus(int busId) async {
    try {
      final token = await _requireToken();
      final resp = await _dio.get(
        '/bus/$busId/currently-in-bus-students',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      _checkStatus(resp, 'students in bus');
      return _normalizeJsonList(resp.data);
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'students in bus');
    }
  }

  /* ──────────────────── Notifications ───────────────────── */

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final token = await _requireToken();
      final parentId = _getParentIdFromToken(token);
      final resp = await _dio.get(
        '/parent/$parentId/notifications',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      _checkStatus(resp, 'notifications');
      return _normalizeJsonList(resp.data);
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'notifications');
    }
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final token = await _requireToken();
      final parentId = _getParentIdFromToken(token);

      final resp = await _dio.get(
        '/parent/$parentId/notification-preferences',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      _checkStatus(resp, 'notification preferences');

      final preferences = _normalizeJson(resp.data);

      // Merge API response with defaults, ensuring all keys exist
      return Map<String, bool>.from({
        ...Map<String, bool>.from(preferences),
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Session expired. Please log in again.';
      }
      throw _friendlyDioMessage(e, 'notification preferences');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateNotificationPreferences(
      Map<String, bool> preferences) async {
    try {
      final token = await _requireToken();
      final parentId = _getParentIdFromToken(token);

      final resp = await _dio.put(
        '/parent/$parentId/notification-preferences',
        data: preferences,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (resp.statusCode == 404) {
        throw 'Notification preferences not found';
      }

      _checkStatus(resp, 'notification preferences update');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Session expired. Please log in again.';
      }
      throw _friendlyDioMessage(e, 'notification preferences update');
    } catch (e) {
      rethrow;
    }
  }

  /* ──────────────────── Profile ───────────────────── */

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await _requireToken();
      final parentId = _getParentIdFromToken(token);

      final resp = await _dio.get(
        '/parent/$parentId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (resp.statusCode == 404) {
        throw 'Profile not found';
      }

      _checkStatus(resp, 'profile');

      final profile = _normalizeJson(resp.data);

      return profile;
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'profile');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await _requireToken();
      final parentId = _getParentIdFromToken(token);

      final resp = await _dio.patch(
        '/parent/$parentId/edit',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (resp.statusCode == 401) {
        throw 'Session expired. Please log in again.';
      }

      if (resp.statusCode == 403) {
        throw 'You are not allowed to edit another parent\'s profile.';
      }

      if (resp.statusCode == 404) {
        throw 'Profile not found.';
      }

      _checkStatus(resp, 'profile update');
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'profile update');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStudentDetails(
      int studentId, Map<String, dynamic> data) async {
    try {
      final token = await _requireToken();
      final resp = await _dio.patch(
        '/student/$studentId',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      _checkStatus(resp, 'student update');
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'student update');
    }
  }

  /* ──────────────────── Helpers & utils ─────────────────── */

  /// Ensure we have a token or throw "Not authenticated"
  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw 'Not authenticated';
    return token;
  }

  /// Extract parent id as **String** from JWT
  String _getParentIdFromToken(String jwt) {
    final decoded = JwtDecoder.decode(jwt);
    final sub = decoded['sub'];
    if (sub is! String || sub.isEmpty) throw 'Token missing parent ID';
    return sub;
  }

  /// Extract student IDs from response data
  List<int> _extractStudentIds(dynamic data) {
    if (data == null) {
      return [];
    }

    if (data is List) {
      final ids = data
          .map<int>((item) {
            if (item is int) {
              return item;
            }

            if (item is String) {
              final parsed = int.tryParse(item);
              return parsed ?? 0;
            }

            if (item is Map) {
              final id = item['id'];

              if (id is int) {
                return id;
              }

              if (id is String) {
                final parsed = int.tryParse(id);
                return parsed ?? 0;
              }
            }
            return 0;
          })
          .where((id) => id > 0)
          .toList();
      return ids;
    }
    return [];
  }

  /// Convert dynamic JSON (List | Map | other) → List<Map<String,dynamic>>
  List<Map<String, dynamic>> _normalizeJsonList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) return Map<String, dynamic>.from(item);
        if (item is String) return {'value': item};
        return {'value': item.toString()};
      }).toList();
    }
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return [
      {'value': data.toString()}
    ];
  }

  /// Convert dynamic JSON → Map<String,dynamic>
  Map<String, dynamic> _normalizeJson(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) return {'value': data};
    return {'value': data.toString()};
  }

  /// Throws if HTTP status is not 200-299
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

  /// Call when the service is no longer needed
  void dispose() {
    _dio.close();
    _studentService.dispose();
  }
}
