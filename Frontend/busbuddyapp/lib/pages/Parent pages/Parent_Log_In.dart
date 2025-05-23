import 'package:flutter/material.dart';
import '../../main.dart'; // MyHome
import '../Admin pages/Admin_Log_In.dart'; // Admin screen
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../Admin pages/Admin_Home.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/auth_service.dart';

final FlutterSecureStorage storage = FlutterSecureStorage(); // ✅ Your style
final AuthService authService = AuthService();

class LogInScreen extends StatefulWidget {
  const LogInScreen({Key? key}) : super(key: key);

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkTokenAndNavigate();
    getFCMToken();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', // id
              'High Importance Notifications', // title
              importance: Importance.high,
              priority: Priority.high,
              ticker: 'ticker',
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void getFCMToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    print(" FCM Token: $token");
  }

  Future<void> _checkTokenAndNavigate() async {
    final token = await authService.getToken();
    if (token != null && !JwtDecoder.isExpired(token)) {
      final decoded = JwtDecoder.decode(token);
      final role = decoded["role"];
      final userId = decoded["sub"];
      print("Token found ✅ | Role: $role | User ID: $userId");

      if (role == "parent") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MyHome()),
        );
      } else if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminHome()),
        );
      } else {
        print("❌ Unknown role in token");
      }
    } else {
      print("No valid token found ❌ → Stay on login screen");
    }
  }

  Future<void> _handleLogin() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await authService.parentLogin(
        _phoneController.text,
        _passwordController.text,
      );

      await authService.storeToken(token);

      // Get and store FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await storage.write(key: 'fcm_token', value: fcmToken);

        // Get user ID from token
        final decoded = JwtDecoder.decode(token);
        final userId = decoded["sub"];

        // Check current device token
        final currentToken = await authService.getUserDeviceToken(userId);

        // Update if token is null or different
        if (currentToken == null || currentToken != fcmToken) {
          try {
            await authService.updateDeviceToken(userId, fcmToken);
            print('Device token updated successfully');
          } catch (e) {
            print('Failed to update device token: $e');
            // Continue with navigation even if token update fails
          }
        }
      }

      final decoded = JwtDecoder.decode(token);
      final role = decoded["role"];

      if (role == "parent") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MyHome()),
        );
      } else if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminHome()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            SizedBox(height: screenHeight * 0.05),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Removed the "Check Token" button
                  Image.asset('assets/bus_logo.png',
                      height: screenHeight * 0.1),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AdminLogInScreen()),
                      );
                    },
                    child: Column(
                      children: [
                        Icon(Icons.person, size: 40, color: Colors.black),
                        Text(
                          "Admin",
                          style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // White section with wave
            ClipPath(
              clipper: CustomClipperPath(),
              child: Container(
                height: screenHeight * 0.9,
                width: screenWidth,
                color: Color(0xFFFCB041),
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Log In",
                              style: TextStyle(
                                  fontSize: screenWidth * 0.07,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                          SizedBox(height: 35),
                          Text("Phone Number",
                              style: TextStyle(fontSize: screenWidth * 0.035)),
                          SizedBox(height: 5),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                  borderSide: BorderSide(
                                      color: Colors.black, width: 1.5)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                  borderSide: BorderSide(
                                      color: Colors.black, width: 1.5)),
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Phone Number',
                            ),
                          ),
                          SizedBox(height: 10),
                          Text("Password",
                              style: TextStyle(fontSize: screenWidth * 0.035)),
                          SizedBox(height: 5),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                  borderSide: BorderSide(
                                      color: Colors.black, width: 1.5)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                  borderSide: BorderSide(
                                      color: Colors.black, width: 1.5)),
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Password',
                            ),
                          ),
                          SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: screenHeight * 0.055,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                              ),
                              child: _isLoading
                                  ? CircularProgressIndicator(
                                      color: Colors.white)
                                  : Text(
                                      'Log In',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.045,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 30),
                          Center(
                            child: Image.asset('assets/school_logo.png',
                                height: screenHeight * 0.12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomClipperPath extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.1);
    path.quadraticBezierTo(size.width * 0.15, size.height * 0.05,
        size.width * 0.45, size.height * 0.1);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.15, size.width, size.height * 0.1);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
