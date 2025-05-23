import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/SplashScreen.dart';
import 'pages/Parent pages/Parent_Log_In.dart'; // Replace with your actual login page file
import 'pages/Parent pages/Supervision/ViewLocationPage.dart'; // Example of an existing page
// Parent pages
import 'pages/Parent pages/Parent_Home.dart';
import 'pages/Parent pages/Parent_Log_In.dart';
import 'pages/Parent pages/Supervision/Parent_Track_Bus.dart';
import 'pages/Parent pages/Supervision/Parent_Student_History.dart';
import 'pages/Parent pages/Supervision/Parent_View_Student_Event.dart';
import 'pages/Parent pages/Supervision/Parent_All_Notifications.dart';
import 'pages/Parent pages/Management/Parent_Manage_Students.dart';
import 'pages/Parent pages/Management/Parent_Update_Profile.dart';
import 'pages/Parent pages/Management/Parent_Update_Student_Information.dart';
import 'pages/Parent pages/Management/Parent_Manage_Notifications.dart';
import 'pages/Parent pages/Management/Parent_View_Profile.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // must match the one in AndroidManifest.xml
  'High Importance Notifications', // channel name
  description: 'Channel for BusBuddy notifications.',
  importance: Importance.high,
);
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print(' Handling background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(); // Load .env file from root
  await Firebase.initializeApp();

  // Ask permissions
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  // Create the notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) =>
            LogInScreen(), // Replace with your login page widget
        '/home': (context) => ViewLocationPage(
              latitude: 0.0,
              longitude: 0.0,
              eventType: 'Event',
              date: 'Date',
              location: 'Location',
            ), // Example route
        '/track': (context) => TrackBus(),
        '/profile': (context) => ProfileScreen(),
        '/studentHistory': (context) => StudentHistory(),
        '/viewStudentEvent': (context) {
          final Map<String, dynamic>? args = ModalRoute.of(context)
              ?.settings
              .arguments as Map<String, dynamic>?;
          if (args == null || !args.containsKey('event')) {
            throw 'Event data not provided';
          }
          return ParentViewStudentEvent(event: args['event']);
        },
        '/updateStudentInfo': (context) => ParentUpdateStudentInformation(
              studentData: {
                'name': '',
                'phone': '',
                'address': '',
              },
              onUpdate: (data) {},
            ),
        '/manageNotifications': (context) => ManageNotificationsPage(),
        '/allNotifications': (context) => AllNotificationsPage(),
        '/manageStudents': (context) => ManageStudentsPage(),
        '/updateProfile': (context) => ParentUpdateProfilePage(
              currentName: '',
              currentPhone: '',
              currentEmail: '',
            ),
      },
    );
  }
}

class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  MyHomeState createState() => MyHomeState();
}

class MyHomeState extends State<MyHome> with SingleTickerProviderStateMixin {
  late TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("BusBuddy"),
        backgroundColor: Color(0xFFFCB041),
      ),
      body: TabBarView(
        controller: controller,
        children: <Widget>[HomeScreen(), TrackBus(), ProfileScreen()],
      ),
      bottomNavigationBar: Material(
        color: Color(0xFFFCB041),
        child: TabBar(
          tabs: <Tab>[
            Tab(icon: Icon(Icons.home), text: "Home"),
            Tab(icon: Icon(Icons.location_on), text: "Track Bus"),
            Tab(icon: Icon(Icons.person), text: "Profile"),
          ],
          controller: controller,
        ),
      ),
    );
  }
}
