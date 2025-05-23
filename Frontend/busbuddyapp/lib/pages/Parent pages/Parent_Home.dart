  import 'package:flutter/material.dart';
  import '../../services/parent_service.dart';
  import '../../models/student.dart';
  import '../../models/notification.dart';

  class HomeScreen extends StatefulWidget {
    const HomeScreen({Key? key}) : super(key: key);

    @override
    _HomeScreenState createState() => _HomeScreenState();
  }

  class _HomeScreenState extends State<HomeScreen> {
    final ParentService _parentService = ParentService();
    List<Student> _students = [];
    List<BusNotification> _notifications = [];
    bool _isLoading = true;
    String? _error;

    @override
    void initState() {
      super.initState();
      _loadData();
    }

    Future<void> _loadData() async {
      try {
        setState(() {
          _isLoading = true;
          _error = null;
        });

        final studentsData = await _parentService.getStudents();
        print("=============================================================");
        print('Students Data: $studentsData');
        print("=============================================================");
        final notificationsData = await _parentService.getNotifications();

        setState(() {
          _students = studentsData.map((json) => Student.fromJson(json)).toList();
          _notifications = notificationsData.map((json) => BusNotification.fromJson(json)).toList();
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
    Widget build(BuildContext context) {
      double screenWidth = MediaQuery.of(context).size.width;
      double screenHeight = MediaQuery.of(context).size.height;

      // Calculate available height for students and notifications
      final appBarHeight = AppBar().preferredSize.height;
      final statusBarHeight = MediaQuery.of(context).padding.top;
      final bottomNavHeight = 56.0; // Standard bottom navigation height
      final padding = 32.0; // Total padding (16 top + 16 bottom)
      final sectionSpacing = 30.0; // Spacing between sections
      final sectionHeaderHeight = 40.0; // Height for section headers
      final availableHeight = screenHeight - appBarHeight - statusBarHeight - bottomNavHeight - padding - (sectionSpacing * 2) - (sectionHeaderHeight * 2);

      // Calculate how many notifications can fit in the available space
      final notificationCardHeight = 80.0; // Approximate height of notification card
      final maxNotifications = ((availableHeight * 0.5) / notificationCardHeight).floor();

      return Scaffold(
        backgroundColor: const Color(0xFFF5F5FA),
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
                          onPressed: _loadData,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Students Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Students',
                              style: TextStyle(
                                  fontSize: screenWidth * 0.045,
                                  fontWeight: FontWeight.bold),
                            ),
                            Icon(Icons.school,
                                size: screenWidth * 0.06, color: Colors.black87),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Student Cards
                        Container(
                          height: availableHeight * 0.5,
                          child: SingleChildScrollView(
                            child: Column(
                              children: _students.map((student) => StudentCard(
                                name: student.name,
                                busNumber: student.busNumber,
                                status: student.isOnBus ? 'In-Bus' : 'Off-Bus',
                                statusColor: student.isOnBus ? Colors.green : Colors.red,
                                studentId: student.id,
                              )).toList(),
                            ),
                          ),
                        ),

                        // Notifications Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(
                                  fontSize: screenWidth * 0.045,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/allNotifications');
                              },
                              child: Text(
                                'See All',
                                style: TextStyle(
                                    color: Colors.blue, fontSize: screenWidth * 0.035),
                              ),
                            ),
                          ],
                        ),

                        // Notification Cards
                        Container(
                          width: screenWidth,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black26, blurRadius: 2, spreadRadius: 1),
                            ],
                          ),
                          child: Column(
                            children: [
                              ...(() {
                                final sortedNotifications = List<BusNotification>.from(_notifications)
                                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                                final notifications = sortedNotifications.take(maxNotifications).map((notification) => NotificationCard(
                                  title: notification.title,
                                  description: notification.message,
                                  time: _getTimeAgo(notification.createdAt),
                                )).toList();
                                
                                // Add dividers between notifications
                                List<Widget> notificationWidgets = [];
                                for (int i = 0; i < notifications.length; i++) {
                                  notificationWidgets.add(notifications[i]);
                                  if (i < notifications.length - 1) {
                                    notificationWidgets.add(
                                      Divider(
                                        color: Colors.grey[300],
                                        thickness: 1,
                                        height: 1,
                                      ),
                                    );
                                  }
                                }
                                return notificationWidgets;
                              })(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      );
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
  }

  class StudentCard extends StatelessWidget {
    final String name;
    final String busNumber;
    final String status;
    final Color statusColor;
    final int studentId;

    const StudentCard({
      Key? key,
      required this.name,
      required this.busNumber,
      required this.status,
      required this.statusColor,
      required this.studentId,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      double screenWidth = MediaQuery.of(context).size.width;

      return Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bus Number: $busNumber',
                    style: TextStyle(
                        fontSize: screenWidth * 0.033, color: Colors.black87),
                  ),
                  Row(
                    children: [
                      Text(
                        'Current Status: ',
                        style: TextStyle(fontSize: screenWidth * 0.033),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: screenWidth * 0.033,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context, 
                    '/studentHistory',
                    arguments: {'studentId': studentId},
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  width: screenWidth * 0.22,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'History',
                    style: TextStyle(
                        color: Colors.white, fontSize: screenWidth * 0.035),
                  ),
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
      double screenWidth = MediaQuery.of(context).size.width;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: screenWidth * 0.035, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style:
                  TextStyle(fontSize: screenWidth * 0.032, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style:
                    TextStyle(fontSize: screenWidth * 0.028, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }
  }
