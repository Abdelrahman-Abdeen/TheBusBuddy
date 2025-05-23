import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/auth_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/parent_service.dart';
import '../../../services/websocket_service.dart';

class TrackBus extends StatefulWidget {
  const TrackBus({Key? key}) : super(key: key);
  @override
  _TrackBusState createState() => _TrackBusState();
}

class _TrackBusState extends State<TrackBus> {
  final AuthService _auth = AuthService();
  final TrackingService _tracker = TrackingService();
  final ParentService _parentService = ParentService();
  final WebSocketService _wsService = WebSocketService();

  final Completer<GoogleMapController> _mapCtl = Completer();
  LatLng _busLocation = const LatLng(31.9941135, 35.8307002);
  Set<Marker> _markers = {};
  StreamSubscription<LatLng>? _locationSubscription;
  final _mapKey = GlobalKey();

  int _currentStudentIndex = 0;
  List<Map<String, dynamic>> _students = [];
  Map<int, Map<String, dynamic>> _busDetails = {};
  Map<int, String?> _studentETAs = {};
  bool _isLoading = true;
  String? _error;
  bool _canTrack = false;
  String _trackingMessage = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  Future<void> _checkTrackingConditions() async {
    if (_students.isEmpty) return;
    
    final currentStudent = _students[_currentStudentIndex];
    final busId = int.parse(currentStudent['bus_id'].toString());
    final studentId = currentStudent['id'];

    try {
      final busDetails = await _parentService.getBusDetails(busId);
      final isMonitoringEnabled = busDetails['is_monitoring_enabled'] ?? false;
      final routeMode = busDetails['route_mode'] ?? '';

      if (!isMonitoringEnabled) {
        setState(() {
          _canTrack = false;
          _trackingMessage = 'Bus tracking is not enabled';
        });
        return;
      }

      if (routeMode == 'MORNING') {
        setState(() {
          _canTrack = true;
          _trackingMessage = 'Morning route - Tracking enabled';
        });
        return;
      }

      if (routeMode == 'EVENING') {
        // Check if student is in bus
        final studentsInBus = await _parentService.getStudentsInBus(busId);
        final isStudentInBus = studentsInBus.any((student) => student['id'] == studentId);
        
        setState(() {
          _canTrack = isStudentInBus;
          _trackingMessage = isStudentInBus 
            ? 'Evening route - Student is in bus' 
            : 'Evening route - Student is not in bus';
        });
        return;
      }

      setState(() {
        _canTrack = false;
        _trackingMessage = 'Unknown route mode';
      });
    } catch (e) {
      print('Error checking tracking conditions: $e');
      setState(() {
        _canTrack = false;
        _trackingMessage = 'Error checking tracking status';
      });
    }
  }

  Future<void> _loadStudents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final students = await _parentService.getStudents();
      setState(() {
        _students = students;
      });

      // Load bus details for each student
      for (var student in students) {
        if (student['bus_id'] != null) {
          try {
            final busDetails = await _parentService.getBusDetails(student['bus_id']);
            setState(() {
              _busDetails[student['bus_id']] = busDetails;
            });
          } catch (e) {
            debugPrint('Error loading bus details: $e');
          }
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (students.isNotEmpty) {
        await _checkTrackingConditions();
        if (_canTrack) {
          _startLocationTracking();
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _startLocationTracking() async {
    if (_students.isEmpty) return;

    // Cancel existing subscription if any
    await _locationSubscription?.cancel();
    await _wsService.disconnect();

    final currentStudent = _students[_currentStudentIndex];
    final busId = int.parse(currentStudent['bus_id'].toString());
    final studentId = currentStudent['id'];

    try {
      final token = await _auth.getToken();
      if (token == null) {
        print('No auth token available');
        return;
      }

      // Connect to WebSocket
      await _wsService.connect(busId, token);

      // Subscribe to location updates
      _locationSubscription = _wsService.locationStream.listen(
        (latLng) async {
          // Update ETA for evening route
          final busDetails = _busDetails[busId];
          final routeMode = busDetails?['route_mode'] ?? '';
          
          if (routeMode == 'EVENING') {
            try {
              final studentsInBus = await _parentService.getStudentsInBus(busId);
              final isStudentInBus = studentsInBus.any((student) => student['id'] == studentId);
              
              if (isStudentInBus) {
                final eta = await _parentService.getStudentETA(studentId);
                setState(() {
                  _studentETAs[studentId] = eta;
                });
              } else {
                setState(() {
                  _studentETAs[studentId] = null;
                });
              }
            } catch (e) {
              print('Error loading student ETA: $e');
              setState(() {
                _studentETAs[studentId] = null;
              });
            }
          }

          // Update map with new location
          if (_mapCtl.isCompleted) {
            final controller = await _mapCtl.future;
            // Update marker position without rebuilding the entire map
            setState(() {
              _markers = {
                Marker(
                  markerId: const MarkerId('bus'),
                  position: latLng,
                  infoWindow: InfoWindow(
                    title: 'Bus #$busId',
                    snippet: '${currentStudent['first_name']} ${currentStudent['last_name']}',
                  ),
                ),
              };
            });
            
            // Smoothly animate camera to new position
            controller.animateCamera(
              CameraUpdate.newLatLng(latLng),
            );
          } else {
            // If map controller is not ready, just update the state
            setState(() {
              _busLocation = latLng;
              _markers = {
                Marker(
                  markerId: const MarkerId('bus'),
                  position: latLng,
                  infoWindow: InfoWindow(
                    title: 'Bus #$busId',
                    snippet: '${currentStudent['first_name']} ${currentStudent['last_name']}',
                  ),
                ),
              };
            });
          }
        },
        onError: (error) {
          print('Error in location stream: $error');
          // Attempt to reconnect after a short delay
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _canTrack) {
              _startLocationTracking();
            }
          });
        },
      );
    } catch (e) {
      print('Error starting location tracking: $e');
    }
  }

  void _switchStudent(bool next) {
    if (_students.isEmpty) return;
    
    setState(() {
      if (next) {
        _currentStudentIndex = (_currentStudentIndex + 1) % _students.length;
      } else {
        _currentStudentIndex = (_currentStudentIndex - 1 + _students.length) % _students.length;
      }
      // Reset bus location to default position
      _busLocation = const LatLng(31.9941135, 35.8307002);
      _markers = {};
    });

    // Check tracking conditions for the new student
    _checkTrackingConditions().then((_) {
      if (_canTrack) {
        _startLocationTracking();
      }
    });
  }

  Future<void> _makePhoneCall() async {
    if (_students.isEmpty) return;
    
    final busId = int.parse(_students[_currentStudentIndex]['bus_id'].toString());
    final busDetails = _busDetails[busId];
    if (busDetails == null || busDetails['driver_phone'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
      return;
    }

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: busDetails['driver_phone'],
    );
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Loading tracking information...',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: 
            [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStudents,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_students.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No students found'),
        ),
      );
    }

    final currentStudent = _students[_currentStudentIndex];
    final busId = int.parse(currentStudent['bus_id'].toString());
    final busDetails = _busDetails[busId];
    final studentId = currentStudent['id'];
    final eta = _studentETAs[studentId];
    final routeMode = busDetails?['route_mode'] ?? '';
    final isEveningRoute = routeMode == 'EVENING';

    // If tracking is not enabled, show a different screen
    if (!_canTrack) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_bus,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 20),
              Text(
                _trackingMessage,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                '${currentStudent['first_name']} ${currentStudent['last_name']}',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tracking is enabled, show the full tracking interface
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Google Map
          SizedBox(
            key: _mapKey,
            width: screenWidth,
            height: screenHeight * 0.58,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _busLocation,
                    zoom: 15,
                  ),
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapCtl.complete(controller);
                  },
                ),
                // Student Name Badge (Overlaid on Map)
                Positioned(
                  top: screenHeight * 0.04,
                  left: screenWidth * 0.15,
                  right: screenWidth * 0.15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () => _switchStudent(false),
                          child: Icon(Icons.arrow_back,
                              color: Colors.white, size: screenWidth * 0.06),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${currentStudent['first_name']} ${currentStudent['last_name']}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _switchStudent(true),
                          child: Icon(Icons.arrow_forward,
                              color: Colors.white, size: screenWidth * 0.06),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Driver Info Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_bus, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Bus $busId',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        busDetails?['driver_name'] ?? 'Unknown Driver',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _makePhoneCall,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      width: screenWidth * 0.2,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call,
                              color: Colors.white,
                              size: screenWidth * 0.05),
                          const SizedBox(width: 5),
                          Text(
                            'Call',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.03),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Estimated Time Box - Only show in evening route when student is in bus
          if (isEveningRoute && eta != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: int.tryParse(eta) != null
                      ? int.parse(eta) > 20
                          ? Colors.red
                          : int.parse(eta) >= 10
                              ? Colors.orange
                              : Colors.green
                      : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Estimated Time: $eta minutes",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}