import 'package:flutter/material.dart';
import '../Admin_Home.dart';
import '../Admin_Log_In.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/auth_service.dart'; // Import AuthService

class AdminNotifications extends StatefulWidget {
  const AdminNotifications({Key? key}) : super(key: key);

  @override
  _AdminNotificationsState createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<AdminNotifications>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService(); // Initialize AuthService
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(_handleTabSelection);
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await _notificationService.getNotifications();
      // Sort notifications by timestamp in descending order (newest first)
      notifications.sort((a, b) {
        final timeA = DateTime.parse(a['created_at'] ?? '');
        final timeB = DateTime.parse(b['created_at'] ?? '');
        return timeB.compareTo(timeA);
      });
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      if (_tabController.index == 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AdminHome()),
        );
      } else if (_tabController.index == 2) {
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
                        setState(() {
                          _tabController.index =
                              1; // Reset to Notifications tab
                        });
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
      await _authService.clearToken(); // Clear authentication token
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminLogInScreen()),
      );
    } catch (e) {
      // If token clearing fails, still navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminLogInScreen()),
      );
    }
  }

  String _getEventStatus(String title) {
    switch (title) {
      case 'unusual_enter':
        return 'Unusual Enter';
      case 'unusual_exit':
        return 'Unusual Exit';
      case 'enter':
        return 'Enter';
      case 'exit':
        return 'Exit';
      case 'enter_at_school':
        return 'Enter at School';
      default:
        return title;
    }
  }

  Color _getEventColor(String title) {
    // Normalize title to lowercase and underscores
    final normalized = title.trim().toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'unauthorized_enter':
      case 'Bus unauthorized_enter':
        return Colors.red;
      case 'unusual_enter':
      case 'unusual_exit':
        return Colors.yellow;
      case 'enter':
      case 'exit':
      case 'enter_at_school':
        return Colors.green;
      default:
        return const Color.fromARGB(255, 97, 139, 96);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFCB041),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          "Notifications",
          style: TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5),
            child: SizedBox(
              height: screenHeight * 0.05,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.filter_list, color: Colors.black),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadNotifications,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _notifications.isEmpty
                        ? Center(
                            child: Text(
                              "No notifications available.",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadNotifications,
                            child: ListView.builder(
                              padding: EdgeInsets.all(10),
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                var notif = _notifications[index];
                                final status = _getEventStatus(notif['title']);
                                final color = _getEventColor(notif['title']);
                                final time = _formatTime(notif['created_at']);

                                return Dismissible(
                                  key: Key(notif['id']
                                      .toString()), // Use a unique key for each notification
                                  direction: DismissDirection
                                      .startToEnd, // Swipe left to delete
                                  onDismissed: (direction) async {
                                    final notifId = notif['id'];
                                    try {
                                      await _notificationService.deleteNotification(notifId);
                                      setState(() {
                                        _notifications.removeAt(index);
                                      });

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Notification deleted')),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to delete notification: $e')),
                                      );
                                      // Optionally: reload notifications
                                      _loadNotifications();
                                    }
                                  },

                                  background: Container(
                                    color: Colors.redAccent,
                                    alignment: Alignment.centerLeft,
                                    padding: EdgeInsets.only(left: 20),
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.white),
                                        Spacer(), // Pushes the icon dynamically as the user swipes
                                      ],
                                    ),
                                  ),
                                  secondaryBackground: Container(
                                    color: Colors.redAccent,
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 20),
                                    child: Row(
                                      children: [
                                        Spacer(), // Pushes the icon dynamically as the user swipes
                                        Icon(Icons.delete, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                  child: SizedBox(
                                    height: screenHeight * 0.17,
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: screenWidth * 0.085,
                                            height: screenHeight * 0.17,
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                bottomLeft: Radius.circular(12),
                                              ),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                  Icons.warning_amber_rounded),
                                            ),
                                          ),
                                          Container(
                                            width: screenWidth * 0.4,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: BorderSide(
                                                  color: Colors.black,
                                                  width: 0.5,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontSize:
                                                        screenWidth * 0.028,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  time,
                                                  style: TextStyle(
                                                    fontSize:
                                                        screenWidth * 0.025,
                                                    color: Colors.black54,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8.0),
                                            child: SizedBox(
                                              width: screenWidth * 0.4,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  SizedBox(height: 5),
                                                  Flexible(
                                                    child: Center(
                                                      child: Text(
                                                        notif['message'] ??
                                                            "No message available",
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize:
                                                              screenWidth *
                                                                  0.027,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        overflow: TextOverflow
                                                            .visible,
                                                        maxLines: null,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
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
        ],
      ),
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

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Unknown time';
    try {
      final dateTime = DateTime.parse(timestamp);
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    } catch (e) {
      return 'Invalid time';
    }
  }
}
