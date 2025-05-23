import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Admin pages/Admin_Home.dart';
import '../Admin pages/Notification pages/Admin_Create_Notification.dart';
import '../Parent pages/Parent_Log_In.dart';
import '../Admin pages/Notification pages/Admin_Bus_Events.dart';
import '../../services/bus_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';

class AdminTrackPage extends StatelessWidget {
  final int busId;

  const AdminTrackPage({Key? key, required this.busId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _AdminTrackPageContent(busId: busId);
  }
}

class _AdminTrackPageContent extends StatefulWidget {
  final int busId;
  final BusService busService = BusService();
  final AuthService authService = AuthService();

  _AdminTrackPageContent({Key? key, required this.busId}) : super(key: key);

  @override
  _AdminTrackPageContentState createState() => _AdminTrackPageContentState();
}

class _AdminTrackPageContentState extends State<_AdminTrackPageContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng _busLocation = const LatLng(31.9941135, 35.8307002);
  Set<Marker> _markers = {};
  Timer? _locationTimer;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _busDetails;
  List<dynamic> _studentsInBus = [];
  List<dynamic> _registeredStudents = [];
  List<dynamic> _fullStudentDetails = [];
  String? _busAddress;
  int _retryCount = 0;
  static const int maxRetries = 3;
  bool _isInitialized = false;
  bool _isMonitoringEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    if (_isInitialized) return;

    try {
      print('Initializing tracking for bus ${widget.busId}');
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // First, get bus details
      print('Fetching bus details...');
      final busDetails = await widget.busService.getBusDetails(widget.busId);
      print('Bus details loaded: $busDetails');

      if (busDetails == null || busDetails.isEmpty) {
        throw 'Failed to load bus details. Please try again.';
      }

      // Then get students in bus
      print('Fetching students in bus...');
      final studentsInBus =
          await widget.busService.getStudentsInBus(widget.busId);
      print('Students in bus loaded: $studentsInBus');

      // Get registered students from bus details
      final registeredStudents = busDetails['registered_students'] ?? [];
      print('Registered students loaded: $registeredStudents');

      // Get full student details
      print('Fetching full student details...');
      final fullStudentDetails =
          await widget.busService.getBusStudents(widget.busId);
      print('Full student details loaded: $fullStudentDetails');

      setState(() {
        _busDetails = busDetails;
        _studentsInBus = studentsInBus;
        _registeredStudents = registeredStudents;
        _fullStudentDetails = fullStudentDetails;
        _isLoading = false;
        _isInitialized = true;
        _isMonitoringEnabled = busDetails['is_monitoring_enabled'] ?? false;
      });

      // Start location updates
      _startLocationUpdates();
    } catch (e) {
      print('Error initializing tracking: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      _retryInitialization();
    }
  }

  void _retryInitialization() {
    if (_retryCount < maxRetries) {
      _retryCount++;
      print('Retrying initialization (attempt $_retryCount)');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _initializeTracking();
        }
      });
    } else {
      setState(() {
        _error =
            'Failed to initialize after $maxRetries attempts. Please try again later.';
      });
    }
  }

  void _startLocationUpdates() {
    // Load location immediately
    _loadBusLocation();

    // Then update every 10 seconds
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadBusLocation();
      }
    });
  }

  Future<void> _loadBusLocation() async {
    if (!mounted) return;

    try {
      print('Loading bus location for bus ${widget.busId}');
      final location = await widget.busService.getBusLocation(widget.busId);
      print('Received location: $location');

      if (location == null ||
          location['latitude'] == null ||
          location['longitude'] == null) {
        print('Invalid location data received');
        return;
      }

      final newPosition = LatLng(location['latitude'], location['longitude']);
      print('New position: $newPosition');

      // Get address from coordinates
      String? address;
      try {
        address = await LocationService.getAddressFromCoordinates(
          location['latitude'],
          location['longitude'],
        );
        print('Address resolved: $address');
      } catch (e) {
        print('Error getting address: $e');
        address = 'Location: ${location['latitude']}, ${location['longitude']}';
      }

      if (!mounted) return;

      setState(() {
        _busLocation = newPosition;
        _busAddress = address;
        _markers = {
          Marker(
            markerId: MarkerId('bus_${widget.busId}'),
            position: newPosition,
            infoWindow: InfoWindow(
              title: 'Bus #${widget.busId}',
              snippet: _busAddress,
            ),
          ),
        };
      });

      // Update camera position
      if (_mapController.isCompleted) {
        final controller = await _mapController.future;
        if (mounted) {
          await controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: newPosition,
                zoom: 15,
              ),
            ),
          );
          print('Camera position updated');
        }
      }
    } catch (e) {
      print('Error loading bus location: $e');
      // Don't show error to user for location updates, just log it
    }
  }

  void _handleTabSelection() {
    if (_tabController.index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminHome()),
      );
    } else if (_tabController.index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CreateNotificationPage()),
      );
    } else if (_tabController.index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LogInScreen()),
      );
    }
  }

  // Student List Bottom Sheet
  void _showStudentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.2,
              maxChildSize: 0.8,
              builder: (context, scrollController) {
                return Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.drag_handle, size: 30, color: Colors.black54),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: _buildStudentList(context),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Student List Function
  List<Widget> _buildStudentList(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return _fullStudentDetails.map((student) {
      bool isInBus = student['current_status'] == 'in_bus';
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.face, size: 16, color: Colors.black54),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${student['first_name']} ${student['last_name']}',
                      style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Icon(isInBus ? Icons.check_circle : Icons.cancel,
                    color: isInBus ? Colors.green : Colors.red, size: 18),
                SizedBox(width: 4),
                Text(
                  isInBus ? 'In-Bus' : 'Off-Bus',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: isInBus ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(width: 15),
            GestureDetector(
              onTap: () async {
                final phoneNumber = student['phone_number'];
                if (phoneNumber != null) {
                  final Uri phoneUri = Uri(
                    scheme: 'tel',
                    path: phoneNumber,
                  );
                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Could not launch phone dialer')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone number not available')),
                  );
                }
              },
              child: Container(
                padding: EdgeInsets.all(4),
                width: screenWidth * 0.2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Icon(Icons.phone, color: Colors.black, size: 18),
                    Text(
                      'Call',
                      style: TextStyle(
                          color: Colors.black, fontSize: screenWidth * 0.03),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _toggleMonitoring(bool value) async {
    try {
      // Show confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Confirm Monitoring Change'),
            content: Text(
                'Are you sure you want to ${value ? 'enable' : 'disable'} monitoring for this bus?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        // Update monitoring status
        await widget.busService.updateBusMonitoring(widget.busId, value);

        setState(() {
          _isMonitoringEnabled = value;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Monitoring ${value ? 'enabled' : 'disabled'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // If user cancels, revert the switch to its previous state
        setState(() {
          _isMonitoringEnabled = !value;
        });
      }
    } catch (e) {
      // If there's an error, revert the switch to its previous state
      setState(() {
        _isMonitoringEnabled = !value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update monitoring status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: screenHeight * 0.05,
        backgroundColor: Color(0xFFFCB041),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_error != null)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.black),
              onPressed: () {
                setState(() {
                  _retryCount = 0;
                  _error = null;
                  _isInitialized = false;
                });
                _initializeTracking();
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading bus details...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _retryCount = 0;
                            _error = null;
                            _isInitialized = false;
                          });
                          _initializeTracking();
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Column(
                      children: [
                        // Top Section
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              color: Color(0xFFFCB041),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Students In Bus",
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.03,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "${_studentsInBus.length}/${_registeredStudents.length}",
                                        style: TextStyle(
                                            fontSize: screenWidth * 0.03),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.notification_add,
                                        color: Colors.black,
                                        size: screenWidth * 0.09),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CreateNotificationPage(
                                                  busName:
                                                      "Bus ${widget.busId}",
                                                  busId: widget.busId),
                                        ),
                                      );
                                    },
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Monitoring\nOn/Off",
                                        style: TextStyle(
                                            fontSize: screenWidth * 0.025,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Transform.scale(
                                        scale: 0.7,
                                        child: Switch(
                                          value: _isMonitoringEnabled,
                                          onChanged: _toggleMonitoring,
                                          activeColor: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Google Map
                        Container(
                          width: screenWidth,
                          height: screenHeight * 0.57,
                          child: GoogleMap(
                            mapType: MapType.normal,
                            initialCameraPosition: CameraPosition(
                              target: _busLocation,
                              zoom: 15,
                            ),
                            markers: _markers,
                            onMapCreated: (GoogleMapController controller) {
                              _mapController.complete(controller);
                            },
                          ),
                        ),
                        // Bus Info Section
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(15)),
                            padding: EdgeInsets.all(10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.directions_bus,
                                        color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      "${widget.busId}",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: screenWidth * 0.035),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      _busDetails?['driver_name'] ?? 'Unknown',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: screenWidth * 0.035),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final phoneNumber =
                                        _busDetails?['driver_phone'];
                                    if (phoneNumber != null) {
                                      final url = 'tel:$phoneNumber';
                                      if (await canLaunch(url)) {
                                        await launch(url);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Could not launch phone call')),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    width: screenWidth * 0.2,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.white, width: 1),
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.call,
                                            color: Colors.white,
                                            size: screenWidth * 0.05),
                                        SizedBox(width: 5),
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
                        // Buttons for Students & Events
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20)
                              .copyWith(
                                  top: 20,
                                  bottom: 30), // Added vertical padding
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _showStudentSheet(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    "Students",
                                    style: TextStyle(
                                        fontSize: screenWidth * 0.035),
                                  ),
                                ),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            BusEvents(busId: widget.busId),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    "Events",
                                    style: TextStyle(
                                        fontSize: screenWidth * 0.035),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
