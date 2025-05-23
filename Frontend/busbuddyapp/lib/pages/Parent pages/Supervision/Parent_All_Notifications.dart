import 'package:flutter/material.dart';
import '../Parent_Home.dart';
import 'Parent_Track_Bus.dart';
import '../Management/Parent_View_Profile.dart';
import '../../../services/parent_service.dart';
import '../../../models/notification.dart';

class AllNotificationsPage extends StatefulWidget {
  const AllNotificationsPage({Key? key}) : super(key: key);

  @override
  _AllNotificationsPageState createState() => _AllNotificationsPageState();
}

class _AllNotificationsPageState extends State<AllNotificationsPage>
    with SingleTickerProviderStateMixin {
  final ParentService _parentService = ParentService();
  List<BusNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final notificationsData = await _parentService.getNotifications();
      final notifications = notificationsData
          .map((json) => BusNotification.fromJson(json))
          .toList();

      // Sort notifications by creation time (newest first)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  @override
  void dispose() {
    _parentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Color(0xFFFCB041),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Icon(Icons.notifications, color: Colors.black),
            SizedBox(width: 8),
            Text(
              "Notifications",
              style: TextStyle(
                  color: Colors.black,
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      SizedBox(height: 20),
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
                        "No Notifications Available",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "My Notifications",
                                  style: TextStyle(
                                      fontSize: screenWidth * 0.045,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                final notification = _notifications[index];
                                return Dismissible(
                                  key: Key(notification.id
                                      .toString()), // Use a unique key for each notification
                                  direction: DismissDirection
                                      .startToEnd, // Allow swipe to the right
                                  onDismissed: (direction) {
                                    setState(() {
                                      _notifications.removeAt(
                                          index); // Remove the notification from the list
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Notification removed')),
                                    );
                                  },
                                  background: Container(
                                    color: Colors.redAccent,
                                    alignment: Alignment.centerLeft,
                                    padding: EdgeInsets.only(left: 20),
                                    child:
                                        Icon(Icons.delete, color: Colors.white),
                                  ),
                                  child: NotificationCard(
                                    title: notification.title,
                                    description: notification.message,
                                    time: _getTimeAgo(notification.createdAt),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String title;
  final String description;
  final String time;

  const NotificationCard({
    Key? key,
    required this.title,
    required this.description,
    required this.time,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      height: screenHeight * 0.15,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: Colors.black,
            width: 1,
          ),
        ),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: screenWidth * 0.036,
                          fontWeight: FontWeight.bold)),
                  Text(time,
                      style: TextStyle(
                          fontSize: screenWidth * 0.026, color: Colors.black)),
                ],
              ),
              SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: screenWidth * 0.03)),
            ],
          ),
        ),
      ),
    );
  }
}
