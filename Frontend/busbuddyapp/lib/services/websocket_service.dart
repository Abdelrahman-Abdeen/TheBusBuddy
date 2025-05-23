import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _locationController = StreamController<LatLng>.broadcast();
  bool _isConnected = false;

  Stream<LatLng> get locationStream => _locationController.stream;

  Future<void> connect(int busId, String token) async {
    if (_isConnected) {
      await disconnect();
    }

    final wsUrl = 'wss://fastapi-app-53203255780.me-central1.run.app/ws/bus/$busId/location';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    // Add authorization header
    _channel?.sink.add(jsonEncode({
      'type': 'auth',
      'token': token,
    }));

    _channel?.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['latitude'] != null && data['longitude'] != null) {
            final latLng = LatLng(
              data['latitude'].toDouble(),
              data['longitude'].toDouble(),
            );
            _locationController.add(latLng);
          }
        } catch (e) {
          print('Error parsing WebSocket message: $e');
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        _isConnected = false;
        _locationController.addError(error);
      },
      onDone: () {
        print('WebSocket connection closed');
        _isConnected = false;
      },
    );

    _isConnected = true;
  }

  Future<void> disconnect() async {
    await _channel?.sink.close(status.goingAway);
    _channel = null;
    _isConnected = false;
  }

  bool get isConnected => _isConnected;
}
