import 'package:flutter/material.dart';
import 'Notification pages/Admin_Notifications.dart';
import '../Parent pages/Parent_Log_In.dart';
import 'Notification pages/Admin_Create_Notification.dart';
import 'Admin_Bus_Tracking.dart';
import '../../services/auth_service.dart';
import '../../services/bus_service.dart';
import '../../services/location_service.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({Key? key}) : super(key: key);

  @override
  _AdminHomeState createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final BusService _busService = BusService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Handle Tab Selection
  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      if (_tabController.index == 0) {
        // Stay on Home Page (no action needed)
      } else if (_tabController.index == 1) {
        // Navigate to Notifications Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AdminNotifications()),
        );
      } else if (_tabController.index == 2) {
        // Show confirmation dialog before logging out
        _showLogoutConfirmationDialog();
      }
    }
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Rounded corners
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout,
                  size: 60,
                  color: Colors.redAccent,
                ),
                SizedBox(height: 20),
                Text(
                  "Log Out",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Are you sure you want to log out? You will need to log in again to access your account.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        backgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the dialog
                      },
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the dialog
                        _handleLogout(); // Proceed with logout
                      },
                      child: Text(
                        "Log Out",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.clearToken();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LogInScreen()),
      );
    } catch (e) {
      // If token clearing fails, still navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LogInScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Removes the back button
        toolbarHeight: MediaQuery.of(context).size.height * 0.1,
        backgroundColor: Color(0xFFFCB041),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset('assets/bus_logo.png',
                height: MediaQuery.of(context).size.width * 0.15),
            Image.asset('assets/school_logo.png',
                height: MediaQuery.of(context).size.width * 0.17),
          ],
        ),
      ),
      body: AdminHomeContent(busService: _busService),
      bottomNavigationBar: Material(
        color: Color(0xFFFCB041),
        child: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.home), text: "Home"),
            Tab(icon: Icon(Icons.notifications), text: "Notifications"),
            Tab(icon: Icon(Icons.logout), text: "Log Out"),
          ],
        ),
      ),
    );
  }
}

class AdminHomeContent extends StatefulWidget {
  final BusService busService;

  const AdminHomeContent({Key? key, required this.busService})
      : super(key: key);

  @override
  _AdminHomeContentState createState() => _AdminHomeContentState();
}

class _AdminHomeContentState extends State<AdminHomeContent> {
  List<dynamic> buses = [];
  bool isLoading = true;
  String? errorMessage;
  Map<int, String> busLocations = {};

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    try {
      print('Loading buses...');
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final fetchedBuses = await widget.busService.getAllBuses();
      print('Fetched buses: $fetchedBuses');

      if (fetchedBuses.isEmpty) {
        setState(() {
          buses = [];
          isLoading = false;
        });
        return;
      }

      // Load locations for each bus
      for (var bus in fetchedBuses) {
        try {
          final location = bus['location'] ?? {};
          if (location['latitude'] != null && location['longitude'] != null) {
            final address = await LocationService.getAddressFromCoordinates(
              location['latitude'],
              location['longitude'],
            );
            setState(() {
              busLocations[bus['id']] = address;
            });
          }
        } catch (e) {
          print('Error loading location for bus ${bus['id']}: $e');
          setState(() {
            busLocations[bus['id']] = 'Location unavailable';
          });
        }
      }

      setState(() {
        fetchedBuses.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
        buses = fetchedBuses;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading buses: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.filter_alt_rounded),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateNotificationPage(),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    Icon(
                      Icons.notification_add,
                      color: Color(0xFFFCB041),
                      size: screenWidth * 0.09,
                    ),
                    Icon(
                      Icons.notification_add_outlined,
                      color: Colors.black,
                      size: screenWidth * 0.09,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isLoading)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading buses...'),
                ],
              ),
            ),
          )
        else if (errorMessage != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBuses,
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (buses.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No buses available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBuses,
              child: ListView.builder(
                itemCount: buses.length,
                itemBuilder: (context, index) {
                  var bus = buses[index];
                  final currentStudentsCount =
                      bus['currently_in_bus_students']?.length ?? 0;
                  final registeredStudentsCount =
                      bus['registered_students']?.length ?? 0;
                  final eventsCount = bus['events']?.length ?? 0;
                  final routeMode = bus['route_mode'] ??
                      'MORNING'; // Default to morning if not specified

                  // Calculate percentage and fill based on route mode
                  final studentsLeft = registeredStudentsCount - currentStudentsCount;
                  final isEvening = routeMode == 'EVENING';
                  final percentage = registeredStudentsCount > 0
                      ? (isEvening
                          ? (studentsLeft / registeredStudentsCount * 100)
                          : (currentStudentsCount / registeredStudentsCount * 100))
                          .toInt()
                      : 0;
                  final fillValue = registeredStudentsCount > 0
                      ? (isEvening
                          ? (registeredStudentsCount - currentStudentsCount) / registeredStudentsCount
                          : currentStudentsCount / registeredStudentsCount)
                      : 0.0;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdminTrackPage(busId: bus['id']),
                        ),
                      );
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "${bus['id']}",
                                  style: TextStyle(
                                      fontSize: screenWidth * 0.045,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(width: 10),
                                Image.asset('assets/bus_logo.png',
                                    height: screenHeight * 0.045),
                                SizedBox(width: 10),
                                // Route mode icon
                                Icon(
                                  (bus['route_mode'] ?? 'MORNING') == 'MORNING'
                                      ? Icons.wb_sunny
                                      : Icons.nightlight_round,
                                  color: (bus['route_mode'] ?? 'MORNING') ==
                                          'MORNING'
                                      ? Colors.orange
                                      : Colors.indigo,
                                  size: screenWidth * 0.05,
                                ),
                                SizedBox(width: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      color: eventsCount < 5
                                          ? Colors.yellow
                                          : Colors.red,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "$eventsCount",
                                      style: TextStyle(
                                          fontSize: screenWidth * 0.03,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 20),
                                Row(children: [
                                  Icon(Icons.people),
                                  SizedBox(width: 5),
                                  Text(
                                    "$currentStudentsCount/$registeredStudentsCount",
                                    style: TextStyle(
                                        fontSize: screenWidth * 0.03,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ]),
                                Spacer(),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: screenWidth * 0.12,
                                      height: screenHeight * 0.06,
                                      child: CircularProgressIndicator(
                                        backgroundColor: Colors.grey[350],
                                        value: fillValue,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Color(0xFFFCB041)),
                                      ),
                                    ),
                                    Text(
                                      "$percentage%",
                                      style: TextStyle(
                                          fontSize: screenWidth * 0.03,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: screenWidth * 0.04,
                                      color: Colors.grey[700],
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      bus['driver_name'] ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: screenWidth * 0.04,
                                      color: Colors.grey[700],
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      busLocations[bus['id']] ?? 'Loading...',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ]),
    );
  }
}