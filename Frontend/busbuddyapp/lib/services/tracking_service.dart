// lib/services/tracking_service.dart

import 'package:dio/dio.dart';

class TrackingService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://fastapi-app-53203255780.me-central1.run.app/',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  /// Returns a JSON object { "latitude": double, "longitude": double }
  Future<Map<String, double>> getBusLocation(int busId, String token) async {
    final resp = await _dio.get(
      '/bus/$busId/location',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (resp.statusCode! ~/ 100 != 2) {
      throw 'Failed to fetch location: ${resp.statusCode}';
    }
    final data = resp.data as Map<String, dynamic>;
    return {
      'latitude': (data['latitude'] as num).toDouble(),
      'longitude': (data['longitude'] as num).toDouble(),
    };
  }
}
