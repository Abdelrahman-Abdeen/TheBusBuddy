import 'package:dio/dio.dart';
import 'auth_service.dart';

class StudentService {
  final Dio _dio;
  final AuthService _authService;

  StudentService()
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
        _authService = AuthService();

  /* ─────────────────────── Student Details ─────────────────────── */

  /// Fetch complete details for a single student
  Future<Map<String, dynamic>> getStudentDetails(int studentId) async {
    try {
      final token = await _requireToken();

      final resp = await _dio.get(
        '/student/$studentId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      _checkStatus(resp, 'student details');

      final details = _normalizeJson(resp.data);

      return details;
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'student details');
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch complete details for multiple students
  Future<List<Map<String, dynamic>>> getStudentsDetails(
      List<int> studentIds) async {
    try {
      final token = await _requireToken();

      List<Map<String, dynamic>> allStudents = [];

      // Make individual requests for each student
      for (int studentId in studentIds) {
        final resp = await _dio.get(
          '/student/$studentId',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        _checkStatus(resp, 'student details');

        final studentData = _normalizeJson(resp.data);
        allStudents.add(studentData);
      }

      print('All students details: $allStudents');
      return allStudents;
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'students details');
    } catch (e) {
      rethrow;
    }
  }

  /// Get all students
  Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      final token = await _requireToken();
      final resp = await _dio.get(
        '/students',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      _checkStatus(resp, 'all students');

      final students = _normalizeJsonList(resp.data);

      return students;
    } on DioException catch (e) {
      print('DioException in getAllStudents: ${e.message}');
      throw _friendlyDioMessage(e, 'all students');
    } catch (e) {
      rethrow;
    }
  }

  /// Get students currently in a specific bus
  Future<List<Map<String, dynamic>>> getStudentsInBus(int busId) async {
    try {
      final token = await _requireToken();

      final resp = await _dio.get(
        '/bus/$busId/students',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      _checkStatus(resp, 'students in bus');

      final students = _normalizeJsonList(resp.data);

      return students;
    } on DioException catch (e) {
      throw _friendlyDioMessage(e, 'students in bus');
    } catch (e) {
      rethrow;
    }
  }

  /* ──────────────────── Helpers & utils ─────────────────── */

  /// Ensure we have a token or throw "Not authenticated"
  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw 'Not authenticated';
    return token;
  }

  /// Convert dynamic JSON → Map<String,dynamic>
  Map<String, dynamic> _normalizeJson(dynamic data) {
    if (data == null) {
      return {};
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'value': data.toString()};
  }

  /// Convert dynamic JSON (List | Map | other) → List<Map<String,dynamic>>
  List<Map<String, dynamic>> _normalizeJsonList(dynamic data) {
    if (data == null) {
      return [];
    }
    if (data is List) {
      final result = data.map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) {
          return item;
        }
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        if (item is String) {
          return {'value': item};
        }
        return {'value': item.toString()};
      }).toList();
      return result;
    }
    if (data is Map) {
      return [Map<String, dynamic>.from(data)];
    }
    return [
      {'value': data.toString()}
    ];
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
  void dispose() => _dio.close();
}
